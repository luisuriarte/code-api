<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Admin;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\Repositories\AuditRepository;
use OrigenSalud\Portal\Services\Session;

/**
 * Registra eventos de acceso en os_admin.audit_log.
 *
 * Las direcciones IP y los user-agent se guardan solo como hash con pepper;
 * nunca como texto plano. Si la auditoría falla, la operación que la originó
 * debe fallar también (fail closed).
 */
final class AuditLogger
{
    /** @param array<string, mixed> $context */
    public static function record(string $action, array $context = []): void
    {
        $pepper = (string) Config::adminAuth()['pepper'];
        $ip = self::server('REMOTE_ADDR');
        $agent = self::server('HTTP_USER_AGENT');
        $requestId = self::server('HTTP_X_REQUEST_ID');

        AuditRepository::append([
            'actor_user_id' => $context['actor_user_id'] ?? Session::get('admin.user_id'),
            'actor_email' => $context['actor_email'] ?? Session::get('admin.email'),
            'action' => $action,
            'entity_type' => $context['entity_type'] ?? null,
            'entity_id' => $context['entity_id'] ?? null,
            'catalog_code' => $context['catalog_code'] ?? null,
            'before_state' => $context['before_state'] ?? null,
            'after_state' => $context['after_state'] ?? null,
            'reason' => $context['reason'] ?? null,
            'ip_hash' => $ip === '' ? null : Token::fingerprint($ip, $pepper),
            'user_agent_hash' => $agent === '' ? null : Token::fingerprint($agent, $pepper),
            'request_id' => $requestId !== '' && preg_match('/^[A-Za-z0-9._:-]{1,80}$/', $requestId) === 1
                ? $requestId
                : Token::random(8),
        ]);
    }

    private static function server(string $key): string
    {
        $value = $_SERVER[$key] ?? '';

        return is_string($value) ? $value : '';
    }
}
