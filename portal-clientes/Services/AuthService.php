<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

use OrigenSalud\CustomerPortal\Config;
use OrigenSalud\CustomerPortal\Repositories\AuditRepository;
use OrigenSalud\CustomerPortal\Repositories\AuthThrottleRepository;
use OrigenSalud\CustomerPortal\Repositories\InvitationRepository;
use OrigenSalud\CustomerPortal\Repositories\MembershipRepository;
use OrigenSalud\CustomerPortal\Repositories\OrganizationRepository;
use OrigenSalud\CustomerPortal\Repositories\PasswordResetRepository;
use OrigenSalud\CustomerPortal\Repositories\SessionRepository;
use OrigenSalud\CustomerPortal\Repositories\UserRepository;

/** Flujos de autenticación del portal de clientes, con auditoría y throttle. */
final class AuthService
{
    /** @return array{ok: bool, error_key?: string} */
    public static function attemptLogin(string $email, string $password): array
    {
        $config = Config::auth();
        $email = trim($email);
        $subject = Token::fingerprint(mb_strtolower($email), $config['token_pepper']);

        $throttle = AuthThrottleRepository::hit(
            'login',
            $subject,
            $config['login_window'],
            $config['login_limit'],
            $config['lock_minutes']
        );

        if (self::isBlocked($throttle)) {
            AuditRepository::record(null, null, 'login.throttled', 'app_user', null, 'denied');

            return ['ok' => false, 'error_key' => 'customer.login.too_many_attempts'];
        }

        $user = UserRepository::findByEmail($email);
        $hasher = new PasswordHasher($config['password_pepper']);
        $valid = $user !== null && $hasher->verify($password, (string) ($user['password_hash'] ?? ''));

        if (!$valid) {
            AuditRepository::record(
                $user === null ? null : (int) $user['id'],
                null,
                'login.failure',
                'app_user',
                null,
                'failure'
            );

            return ['ok' => false, 'error_key' => 'customer.login.invalid'];
        }

        $status = (string) ($user['status'] ?? '');
        if ($status !== 'active') {
            AuditRepository::record((int) $user['id'], null, 'login.denied', 'app_user', null, 'denied');

            return ['ok' => false, 'error_key' => 'customer.login.suspended'];
        }

        $lockedUntil = $user['locked_until'] ?? null;
        if (is_string($lockedUntil) && strtotime($lockedUntil) > time()) {
            return ['ok' => false, 'error_key' => 'customer.login.locked'];
        }

        AuthThrottleRepository::clear('login', $subject);

        $raw = Token::random();
        $organizations = OrganizationRepository::findActiveForUser((int) $user['id']);
        $organizationId = isset($organizations[0]['id']) ? (int) $organizations[0]['id'] : null;
        $fingerprints = self::fingerprints();

        self::regenerateSession();

        $sessionId = SessionRepository::create(
            (int) $user['id'],
            Token::hash($raw),
            $organizationId,
            $fingerprints['ip'],
            $fingerprints['ua'],
            $config['session_ttl']
        );

        CustomerSession::set('customer_token', $raw);
        CustomerSession::set('customer_user_id', (int) $user['id']);
        CustomerSession::set('customer_session_id', $sessionId);
        CustomerCsrf::rotate();
        UserRepository::touchLogin((int) $user['id']);

        AuditRepository::record(
            (int) $user['id'],
            $organizationId,
            'login.success',
            'session',
            (string) $sessionId,
            'success'
        );

        return ['ok' => true];
    }

    public static function logout(): void
    {
        $current = AccessControl::current();

        if ($current !== null) {
            $userId = (int) $current['user_id'];
            $organizationId = AccessControl::organizationId($current);
            SessionRepository::revoke((int) $current['session_id']);
            AuditRepository::record(
                $userId,
                $organizationId,
                'logout.success',
                'session',
                (string) $current['session_id'],
                'success'
            );
        }

        CustomerSession::clear();
    }

    /**
     * @return array{key: string, delivered: bool}
     */
    public static function requestReset(string $email): array
    {
        $config = Config::auth();
        $email = trim($email);
        $subject = Token::fingerprint(mb_strtolower($email), $config['token_pepper']);

        $throttle = AuthThrottleRepository::hit(
            'reset_request',
            $subject,
            $config['login_window'],
            $config['login_limit'],
            $config['lock_minutes']
        );

        if (self::isBlocked($throttle)) {
            AuditRepository::record(null, null, 'password_reset.throttled', 'app_user', null, 'denied');

            return ['key' => 'customer.forgot.sent', 'delivered' => false];
        }

        $user = UserRepository::findByEmail($email);

        if ($user === null || ($user['status'] ?? '') !== 'active') {
            AuditRepository::record(null, null, 'password_reset.requested_unknown', 'app_user', null, 'failure');

            return ['key' => 'customer.forgot.sent', 'delivered' => false];
        }

        $raw = Token::random();
        $fingerprints = self::fingerprints();

        PasswordResetRepository::create(
            (int) $user['id'],
            Token::hash($raw),
            $config['reset_ttl'],
            $fingerprints['ip'],
            $fingerprints['ua']
        );

        $notification = CustomerNotification::passwordReset((string) $user['email'], $raw);

        if (!$notification['ok']) {
            PasswordResetRepository::revokeAllForUser((int) $user['id']);
            AuditRepository::record(
                (int) $user['id'],
                null,
                'password_reset.mail_failed',
                'app_user',
                (string) $user['id'],
                'failure'
            );

            // Respuesta idéntica a la de cuenta inexistente: el fallo SMTP se
            // audita, pero no se revela si el correo pertenece a un usuario.
            return ['key' => 'customer.forgot.sent', 'delivered' => false];
        }

        AuthThrottleRepository::clear('reset_request', $subject);
        AuditRepository::record((int) $user['id'], null, 'password_reset.requested', 'app_user', (string) $user['id'], 'success');

        return ['key' => 'customer.forgot.sent', 'delivered' => true];
    }

    public static function resetPassword(string $rawToken, string $password): bool
    {
        $config = Config::auth();
        $subject = Token::fingerprint($rawToken, $config['token_pepper']);
        $throttle = AuthThrottleRepository::hit(
            'reset_submit',
            $subject,
            $config['login_window'],
            $config['login_limit'],
            $config['lock_minutes']
        );

        if (self::isBlocked($throttle) || !Token::isValidHex($rawToken)) {
            return false;
        }

        $reset = PasswordResetRepository::findActiveByRawToken($rawToken);

        if ($reset === null) {
            AuditRepository::record(null, null, 'password_reset.invalid_token', 'password_reset', null, 'denied');

            return false;
        }

        $userId = (int) $reset['user_id'];
        $hash = (new PasswordHasher(Config::auth()['password_pepper']))->hash($password);

        UserRepository::updatePassword($userId, $hash);
        PasswordResetRepository::revokeAllForUser($userId);
        PasswordResetRepository::markUsed((int) $reset['id']);
        SessionRepository::revokeAllForUser($userId);

        AuditRepository::record($userId, null, 'password_reset.completed', 'app_user', (string) $userId, 'success');

        return true;
    }

    /** @return array{ok: bool, error_key?: string, user_id?: int} */
    public static function acceptInvitation(string $rawToken, string $fullName, string $password): array
    {
        $config = Config::auth();
        $subject = Token::fingerprint($rawToken, $config['token_pepper']);
        $throttle = AuthThrottleRepository::hit(
            'invitation_accept',
            $subject,
            $config['login_window'],
            $config['login_limit'],
            $config['lock_minutes']
        );

        if (self::isBlocked($throttle) || !Token::isValidHex($rawToken)) {
            return ['ok' => false, 'error_key' => 'customer.invitation.invalid'];
        }

        $invitation = InvitationRepository::findPendingByHash(Token::hash($rawToken));

        if ($invitation === null) {
            return ['ok' => false, 'error_key' => 'customer.invitation.invalid'];
        }

        $organizationId = (int) $invitation['organization_id'];
        $email = (string) $invitation['email'];
        $existing = UserRepository::findByEmail($email);

        if ($existing !== null && ($existing['status'] ?? '') !== 'active') {
            return ['ok' => false, 'error_key' => 'customer.invitation.user_inactive'];
        }

        if ($existing !== null && MembershipRepository::findActive($organizationId, (int) $existing['id']) !== null) {
            InvitationRepository::markExpired((int) $invitation['id']);

            return ['ok' => false, 'error_key' => 'customer.invitation.already_member'];
        }

        $hash = (new PasswordHasher(Config::auth()['password_pepper']))->hash($password);

        if ($existing === null) {
            $userId = UserRepository::createActive($email, $fullName, $hash);
        } else {
            $userId = (int) $existing['id'];
        }

        MembershipRepository::create(
            $organizationId,
            $userId,
            (string) $invitation['role_code'],
            $invitation['invited_by'] === null ? null : (int) $invitation['invited_by']
        );
        InvitationRepository::markAccepted((int) $invitation['id'], $userId);

        AuditRepository::record(
            $userId,
            $organizationId,
            'invitation.accepted',
            'membership',
            (string) $organizationId,
            'success'
        );

        return ['ok' => true, 'user_id' => $userId];
    }

    /** Evita session fixation: el ID cambia antes de escribir datos autenticados. */
    private static function regenerateSession(): void
    {
        if (session_status() === PHP_SESSION_ACTIVE) {
            session_regenerate_id(true);
        }
    }

    /** @param array{attempts: int, blocked_until: string|null, blocked: bool} $throttle */
    private static function isBlocked(array $throttle): bool
    {
        if (!$throttle['blocked']) {
            return false;
        }

        $until = $throttle['blocked_until'];

        return !is_string($until) || strtotime($until) > time();
    }

    /** @return array{ip: string|null, ua: string|null} */
    private static function fingerprints(): array
    {
        $pepper = Config::auth()['token_pepper'];
        $ip = (string) ($_SERVER['REMOTE_ADDR'] ?? '');
        $ua = (string) ($_SERVER['HTTP_USER_AGENT'] ?? '');

        return [
            'ip' => $ip !== '' && $pepper !== '' ? Token::fingerprint($ip, $pepper) : null,
            'ua' => $ua !== '' && $pepper !== '' ? Token::fingerprint($ua, $pepper) : null,
        ];
    }
}
