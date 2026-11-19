<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Admin;

use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\Repositories\AuthThrottleRepository;
use OrigenSalud\Portal\Repositories\PasswordResetRepository;
use OrigenSalud\Portal\Repositories\RbacRepository;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\Repositories\SessionRepository;
use OrigenSalud\Portal\Repositories\UserRepository;
use OrigenSalud\Portal\Services\Csrf;
use OrigenSalud\Portal\Services\Session;
use OrigenSalud\Portal\Services\SmtpMailer;
use OrigenSalud\Portal\Services\Validator;

/**
 * Autenticación de usuarios humanos del panel.
 *
 * El estado de autenticación vive en la sesión PHP, pero el token de sesión
 * se valida contra os_admin.session en cada petición. Ningún método de esta
 * clase modifica tablas terminológicas ni la API pública.
 */
final class AuthService
{
    private PasswordHasher $hasher;

    /** @var array<string, mixed> */
    private array $config;

    /** @param array<string, mixed> $config */
    public function __construct(PasswordHasher $hasher, array $config)
    {
        $this->hasher = $hasher;
        $this->config = $config;
    }

    public static function create(): self
    {
        return new self(new PasswordHasher((string) Config::adminAuth()['pepper']), Config::adminAuth());
    }

    /**
     * @return array{ok: bool, error: ?string}
     */
    public function attempt(string $email, string $password): array
    {
        $email = Validator::email($email);
        $ip = self::server('REMOTE_ADDR');
        $agent = self::server('HTTP_USER_AGENT');
        $ipHash = $ip === '' ? null : Token::fingerprint($ip, self::pepper());
        $agentHash = $agent === '' ? null : Token::fingerprint($agent, self::pepper());

        if ($email === '' || !is_string($password) || $password === '' || mb_strlen($password) > 200) {
            AuditLogger::record('login_failed', ['reason' => 'invalid_input', 'ip_hash' => $ipHash]);

            return ['ok' => false, 'error' => 'invalid'];
        }

        $limit = (int) $this->config['login_limit'];
        $window = (int) $this->config['login_window'];

        if (!AuthThrottleRepository::checkAndHit(Token::hash(mb_strtolower($email) . '|' . $ip), $limit, $window)) {
            AuditLogger::record('login_throttled', ['actor_email' => $email, 'ip_hash' => $ipHash]);

            return ['ok' => false, 'error' => 'rate'];
        }

        $user = UserRepository::findByEmail($email);

        if ($user === null || $user['status'] !== 'active') {
            AuditLogger::record('login_failed', ['actor_email' => $email, 'reason' => 'unknown_user', 'ip_hash' => $ipHash]);

            return ['ok' => false, 'error' => 'invalid'];
        }

        $lockedUntil = $user['locked_until'] === null ? null : new DateTimeImmutable((string) $user['locked_until']);

        if ($lockedUntil !== null && $lockedUntil > new DateTimeImmutable('now', new DateTimeZone('UTC'))) {
            AuditLogger::record('login_failed', [
                'actor_user_id' => (int) $user['id'],
                'actor_email' => $email,
                'reason' => 'locked',
                'ip_hash' => $ipHash,
            ]);

            return ['ok' => false, 'error' => 'locked'];
        }

        if (!$this->hasher->verify($password, (string) $user['password_hash'])) {
            UserRepository::recordFailure((int) $user['id'], $limit, (int) $this->config['lock_minutes']);
            AuditLogger::record('login_failed', [
                'actor_user_id' => (int) $user['id'],
                'actor_email' => $email,
                'reason' => 'bad_password',
                'ip_hash' => $ipHash,
            ]);

            return ['ok' => false, 'error' => 'invalid'];
        }

        $rawToken = Token::random();
        $expiresAt = (new DateTimeImmutable('now', new DateTimeZone('UTC')))
            ->modify('+' . max(60, (int) $this->config['session_lifetime']) . ' seconds')
            ->format(DateTimeInterface::ATOM);

        SessionRepository::create((int) $user['id'], Token::hash($rawToken), $expiresAt, $ipHash, $agentHash);
        UserRepository::recordSuccess((int) $user['id'], $ipHash ?? '');

        if (session_status() === PHP_SESSION_ACTIVE) {
            session_regenerate_id(true);
        }

        Session::set('admin.user_id', (int) $user['id']);
        Session::set('admin.email', (string) $user['email']);
        Session::set('admin.token', $rawToken);
        Csrf::rotate();

        AuditLogger::record('login_success', [
            'actor_user_id' => (int) $user['id'],
            'actor_email' => (string) $user['email'],
            'ip_hash' => $ipHash,
        ]);

        return ['ok' => true, 'error' => null];
    }

    public function logout(): void
    {
        $token = Session::get('admin.token');
        $userId = Session::get('admin.user_id');
        $email = Session::get('admin.email');

        // Even if the audit database is unavailable, the local session must
        // always be cleared so the user is never trapped in a broken panel.
        try {
            if (is_string($token) && $token !== '') {
                SessionRepository::revoke(Token::hash($token));
            }

            AuditLogger::record('logout', [
                'actor_user_id' => is_int($userId) ? $userId : null,
                'actor_email' => is_string($email) ? $email : null,
            ]);
        } catch (RepositoryException) {
            // Fail closed locally; the token will expire server-side.
        }

        self::clear();
        Csrf::rotate();

        if (session_status() === PHP_SESSION_ACTIVE) {
            session_regenerate_id(true);
        }
    }

    /**
     * @return array{
     *     user: array{id: int, email: string, full_name: string, status: string},
     *     roles: list<array{code: string, name: string}>,
     *     permissions: list<string>,
     *     grants: list<array{catalog_code: string, operation: string, allowed: bool}>
     * }|null
     */
    public function current(): ?array
    {
        $token = Session::get('admin.token');

        if (!is_string($token) || $token === '') {
            return null;
        }

        try {
            $sessionRow = SessionRepository::findActive(Token::hash($token));
        } catch (RepositoryException) {
            return null;
        }

        if ($sessionRow === null) {
            self::clear();

            return null;
        }

        try {
            $user = UserRepository::findById((int) $sessionRow['user_id']);
        } catch (RepositoryException) {
            return null;
        }

        if ($user === null || $user['status'] !== 'active') {
            self::clear();

            return null;
        }

        try {
            SessionRepository::touch((int) $sessionRow['id']);
            $roles = RbacRepository::rolesForUser((int) $user['id']);
            $permissions = RbacRepository::permissionsForUser((int) $user['id']);
            $grants = RbacRepository::grantsForUser((int) $user['id']);
        } catch (RepositoryException) {
            // Without fresh RBAC data we cannot authorize anything.
            return null;
        }

        return [
            'user' => [
                'id' => (int) $user['id'],
                'email' => (string) $user['email'],
                'full_name' => (string) $user['full_name'],
                'status' => (string) $user['status'],
            ],
            'roles' => $roles,
            'permissions' => $permissions,
            'grants' => $grants,
        ];
    }

    /** @return array{ok: bool} */
    public function requestReset(string $email): array
    {
        $email = Validator::email($email);
        $ip = self::server('REMOTE_ADDR');
        $ipHash = $ip === '' ? null : Token::fingerprint($ip, self::pepper());

        if (!AuthThrottleRepository::checkAndHit(
            Token::hash('reset|' . $ip),
            (int) $this->config['login_limit'],
            (int) $this->config['login_window']
        )) {
            AuditLogger::record('password_reset_throttled', ['ip_hash' => $ipHash]);

            return ['ok' => true];
        }

        $user = UserRepository::findByEmail($email);

        if ($user !== null && $user['status'] === 'active' && Config::smtp()['host'] !== '') {
            $rawToken = Token::random();
            PasswordResetRepository::create(
                (int) $user['id'],
                Token::hash($rawToken),
                (int) $this->config['reset_ttl'],
                $ipHash
            );

            $link = Config::baseUrl() . '/admin/reset?token=' . rawurlencode($rawToken);
            $text = "Solicitud de restablecimiento de contraseña.\n\n" . $link . "\n\n"
                . 'Si no fue usted, ignore este correo. El vínculo vence en '
                . (int) $this->config['reset_ttl'] . " segundos.\n";
            $mail = SmtpMailer::send($email, 'Origen Salud - restablecer contraseña', $text, nl2br(e($text), false));

            if (!$mail['ok']) {
                PasswordResetRepository::revokeAllForUser((int) $user['id']);
                AuditLogger::record('password_reset_mail_failed', ['actor_user_id' => (int) $user['id']]);
            }
        }

        AuditLogger::record('password_reset_requested', ['actor_email' => $email !== '' ? $email : null]);

        return ['ok' => true];
    }

    /** @return array{ok: bool, error: ?string} */
    public function reset(string $token, string $password): array
    {
        if (!Token::isValidHex($token) || !is_string($password)) {
            return ['ok' => false, 'error' => 'invalid'];
        }

        $length = mb_strlen($password);

        if ($length < 12 || $length > 200) {
            return ['ok' => false, 'error' => 'weak'];
        }

        $row = PasswordResetRepository::findActive(Token::hash($token));

        if ($row === null) {
            AuditLogger::record('password_reset_failed', ['reason' => 'invalid_token']);

            return ['ok' => false, 'error' => 'invalid'];
        }

        $userId = (int) $row['user_id'];
        $user = UserRepository::findById($userId);

        if ($user === null || $user['status'] !== 'active') {
            return ['ok' => false, 'error' => 'invalid'];
        }

        UserRepository::setPasswordHash($userId, $this->hasher->hash($password));
        SessionRepository::revokeAllForUser($userId);
        PasswordResetRepository::markUsed((int) $row['id']);
        Csrf::rotate();

        AuditLogger::record('password_reset_completed', [
            'actor_user_id' => $userId,
            'actor_email' => (string) $user['email'],
        ]);

        return ['ok' => true, 'error' => null];
    }

    private static function clear(): void
    {
        Session::set('admin.user_id', null);
        Session::set('admin.email', null);
        Session::set('admin.token', null);
    }

    private function pepper(): string
    {
        return (string) $this->config['pepper'];
    }

    private static function server(string $key): string
    {
        $value = $_SERVER[$key] ?? '';

        return is_string($value) ? $value : '';
    }
}
