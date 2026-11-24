<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Config;
use OrigenSalud\CustomerPortal\Services\CustomerDatabase;
use OrigenSalud\CustomerPortal\Services\Token;

/** Escritura append-only en os_customer.audit_log. Nunca actualiza ni borra. */
final class AuditRepository
{
    /** @param array<string, mixed> $context Solo identificadores/códigos, sin secretos ni datos personales. */
    public static function record(
        ?int $actorUserId,
        ?int $organizationId,
        string $action,
        ?string $objectType,
        ?string $objectId,
        string $result,
        array $context = []
    ): void {
        $auth = Config::auth();
        $pepper = $auth['token_pepper'];

        $ip = (string) ($_SERVER['REMOTE_ADDR'] ?? '');
        $ua = (string) ($_SERVER['HTTP_USER_AGENT'] ?? '');
        $ipHash = $ip === '' || $pepper === '' ? null : Token::fingerprint($ip, $pepper);
        $uaHash = $ua === '' || $pepper === '' ? null : Token::fingerprint($ua, $pepper);

        $requestId = (string) ($_SERVER['HTTP_X_REQUEST_ID'] ?? '');
        if ($requestId === '') {
            $requestId = bin2hex(random_bytes(8));
        }

        $statement = CustomerDatabase::connection()->prepare(
            'INSERT INTO os_customer.audit_log
                (actor_user_id, organization_id, action, object_type, object_id,
                 result, ip_hash, ua_hash, request_id, context)
             VALUES
                (:actor, :org, :action, :object_type, :object_id,
                 :result, :ip, :ua, :request_id, :context::jsonb)'
        );
        $statement->execute([
            ':actor' => $actorUserId,
            ':org' => $organizationId,
            ':action' => $action,
            ':object_type' => $objectType,
            ':object_id' => $objectId,
            ':result' => $result,
            ':ip' => $ipHash,
            ':ua' => $uaHash,
            ':request_id' => substr($requestId, 0, 64),
            ':context' => json_encode($context, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
        ]);
    }
}
