<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Controllers;

use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Repositories\AuditRepository;
use OrigenSalud\CustomerPortal\Services\AccessControl;
use OrigenSalud\CustomerPortal\Services\ApiCredentialService;
use OrigenSalud\CustomerPortal\Services\CustomerCsrf;
use OrigenSalud\CustomerPortal\Services\CustomerSession;
use OrigenSalud\CustomerPortal\Services\Http;
use OrigenSalud\CustomerPortal\View;
use Throwable;

/** Etapa 8: self-service de credenciales de la API propia de code-api. */
final class CredentialController
{
    public static function index(): void
    {
        $context = AccessControl::requirePermission('credential.read');
        self::render($context);
    }

    public static function createSubmit(): void
    {
        self::assertPost();
        $context = self::requireWithAudit('credential.create', 'credential.create');

        // institution_name se deriva de la organización activa: nunca se acepta
        // texto libre del navegador para identificar al cliente de la API.
        $institutionName = trim((string) ($context['organization']['display_name'] ?? ''));
        if ($institutionName === '') {
            $institutionName = trim((string) ($context['organization']['legal_name'] ?? ''));
        }

        if ($institutionName === '') {
            CustomerSession::set('flash', ['key' => 'customer.credential.invalid', 'params' => []]);
            Http::redirect(CustomerI18n::locale() . '/credentials');
        }

        $result = ApiCredentialService::create(
            $context['organization_id'],
            (int) $context['user']['user_id'],
            mb_substr($institutionName, 0, 150)
        );

        if (!($result['ok'] ?? false)) {
            CustomerSession::set('flash', ['key' => (string) ($result['error'] ?? 'customer.credential.failed'), 'params' => []]);
            Http::redirect(CustomerI18n::locale() . '/credentials');
        }

        // Respuesta directa: el secreto se muestra una sola vez y no se guarda
        // en sesión, URL, metadatos ni logs.
        self::render($context, isset($result['secret']) && is_string($result['secret']) ? $result['secret'] : null);
    }

    public static function rotateSubmit(): void
    {
        self::assertPost();
        $context = self::requireWithAudit('credential.rotate', 'credential.rotate');
        $credentialId = (int) (Http::post()['credential_id'] ?? 0);

        $result = ApiCredentialService::rotate(
            $credentialId,
            $context['organization_id'],
            (int) $context['user']['user_id']
        );

        if (!($result['ok'] ?? false)) {
            CustomerSession::set('flash', ['key' => (string) ($result['error'] ?? 'customer.credential.failed'), 'params' => []]);
            Http::redirect(CustomerI18n::locale() . '/credentials');
        }

        self::render($context, isset($result['secret']) && is_string($result['secret']) ? $result['secret'] : null);
    }

    public static function revokeSubmit(): void
    {
        self::assertPost();
        $context = self::requireWithAudit('credential.revoke', 'credential.revoke');
        $credentialId = (int) (Http::post()['credential_id'] ?? 0);

        $result = ApiCredentialService::revoke(
            $credentialId,
            $context['organization_id'],
            (int) $context['user']['user_id']
        );

        CustomerSession::set('flash', [
            'key' => ($result['ok'] ?? false)
                ? 'customer.credential.revoked'
                : (string) ($result['error'] ?? 'customer.credential.failed'),
            'params' => [],
        ]);
        Http::redirect(CustomerI18n::locale() . '/credentials');
    }

    /** @param array<string, mixed> $context */
    private static function render(array $context, ?string $secret = null): void
    {
        $organizationId = (int) $context['organization_id'];

        View::render('credentials', [
            'title' => CustomerI18n::t('customer.credential.title'),
            'credentials' => ApiCredentialService::list($organizationId),
            'organization' => $context['organization'],
            'can_create' => AccessControl::can('credential.create', $organizationId, $context['user']),
            'can_rotate' => AccessControl::can('credential.rotate', $organizationId, $context['user']),
            'can_revoke' => AccessControl::can('credential.revoke', $organizationId, $context['user']),
            'available' => ApiCredentialService::available(),
            'secret' => $secret,
        ]);
    }

    /** @return array{user: array<string, mixed>, organization: array<string, mixed>, organization_id: int} */
    private static function requireWithAudit(string $permission, string $auditAction): array
    {
        $context = AccessControl::requireOrganization();
        $userId = (int) $context['user']['user_id'];

        if (!AccessControl::can($permission, $context['organization_id'], $context['user'])) {
            try {
                AuditRepository::record($userId, $context['organization_id'], $auditAction, 'api_credential', null, 'denied');
            } catch (Throwable) {
                // El rechazo debe seguir siendo 403 aunque la auditoría falle.
            }
            Http::abort(403, 'errors/denied');
        }

        return $context;
    }

    private static function assertPost(): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }
    }
}
