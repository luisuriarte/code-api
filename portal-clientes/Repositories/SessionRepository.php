<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;
use OrigenSalud\CustomerPortal\Services\Token;

final class SessionRepository
{
    public static function create(
        int $userId,
        string $tokenHash,
        ?int $organizationId,
        ?string $ipHash,
        ?string $uaHash,
        int $ttlSeconds
    ): int {
        $statement = CustomerDatabase::connection()->prepare(
            'INSERT INTO os_customer.session
                (user_id, token_hash, context_organization_id, ip_hash, ua_hash, expires_at)
             VALUES
                (:user, :token, :org, :ip, :ua, now() + (:ttl::int * interval \'1 second\'))
             RETURNING id'
        );
        $statement->execute([
            ':user' => $userId,
            ':token' => $tokenHash,
            ':org' => $organizationId,
            ':ip' => $ipHash,
            ':ua' => $uaHash,
            ':ttl' => max(60, $ttlSeconds),
        ]);

        return (int) $statement->fetchColumn();
    }

    /** @return array<string, mixed>|null */
    public static function findActiveByRawToken(string $rawToken): ?array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT s.id AS session_id,
                    s.user_id,
                    s.context_organization_id,
                    s.expires_at,
                    s.last_seen_at,
                    u.email,
                    u.full_name,
                    u.status AS user_status
               FROM os_customer.session s
               JOIN os_customer.app_user u ON u.id = s.user_id
              WHERE s.token_hash = :token
                AND s.revoked_at IS NULL
                AND s.expires_at > now()
                AND u.status = \'active\''
        );
        $statement->execute([':token' => Token::hash($rawToken)]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    public static function touch(int $sessionId): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.session SET last_seen_at = now() WHERE id = :id'
        );
        $statement->execute([':id' => $sessionId]);
    }

    public static function setContext(int $sessionId, ?int $organizationId): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.session
                SET context_organization_id = :org, last_seen_at = now()
              WHERE id = :id'
        );
        $statement->execute([':id' => $sessionId, ':org' => $organizationId]);
    }

    public static function revoke(int $sessionId): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.session
                SET revoked_at = now(), last_seen_at = now()
              WHERE id = :id AND revoked_at IS NULL'
        );
        $statement->execute([':id' => $sessionId]);
    }

    public static function revokeAllForUser(int $userId): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.session
                SET revoked_at = now()
              WHERE user_id = :user AND revoked_at IS NULL'
        );
        $statement->execute([':user' => $userId]);
    }
}
