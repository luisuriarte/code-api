<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;
use OrigenSalud\CustomerPortal\Services\Token;

final class PasswordResetRepository
{
    public static function create(
        int $userId,
        string $tokenHash,
        int $ttlSeconds,
        ?string $ipHash,
        ?string $uaHash
    ): int {
        $statement = CustomerDatabase::connection()->prepare(
            'INSERT INTO os_customer.password_reset
                (user_id, token_hash, ip_hash, ua_hash, expires_at)
             VALUES
                (:user, :token, :ip, :ua, now() + (:ttl::int * interval \'1 second\'))
             RETURNING id'
        );
        $statement->execute([
            ':user' => $userId,
            ':token' => $tokenHash,
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
            'SELECT pr.id, pr.user_id, pr.expires_at, u.email, u.full_name
               FROM os_customer.password_reset pr
               JOIN os_customer.app_user u ON u.id = pr.user_id
              WHERE pr.token_hash = :token
                AND pr.used_at IS NULL
                AND pr.expires_at > now()
                AND u.status = \'active\''
        );
        $statement->execute([':token' => Token::hash($rawToken)]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    public static function markUsed(int $id): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.password_reset SET used_at = now() WHERE id = :id AND used_at IS NULL'
        );
        $statement->execute([':id' => $id]);
    }

    public static function revokeAllForUser(int $userId): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.password_reset
                SET used_at = now()
              WHERE user_id = :user AND used_at IS NULL'
        );
        $statement->execute([':user' => $userId]);
    }
}
