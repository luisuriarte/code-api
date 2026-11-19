<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use PDOException;

/** Solicitudes de reset: se guarda solo el hash del token. */
final class PasswordResetRepository
{
    public static function create(
        int $userId,
        string $tokenHash,
        int $ttlSeconds,
        ?string $ipHash
    ): void {
        $expiresAt = (new DateTimeImmutable('now', new DateTimeZone('UTC')))
            ->modify('+' . max(60, $ttlSeconds) . ' seconds')
            ->format(DateTimeInterface::ATOM);

        try {
            $statement = AdminDatabase::connection()->prepare(
                'INSERT INTO os_admin.password_reset
                    (user_id, token_hash, requested_ip_hash, expires_at)
                 VALUES (:user, :token, :ip, :expires)'
            );
            $statement->execute([
                ':user' => $userId,
                ':token' => $tokenHash,
                ':ip' => $ipHash,
                ':expires' => $expiresAt,
            ]);
        } catch (PDOException) {
            throw new RepositoryException('admin_reset_unavailable');
        }
    }

    /** @return array<string, mixed>|null */
    public static function findActive(string $tokenHash): ?array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT id, user_id, expires_at FROM os_admin.password_reset
                  WHERE token_hash = :token AND used_at IS NULL AND expires_at > now()
                  LIMIT 1'
            );
            $statement->execute([':token' => $tokenHash]);

            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function markUsed(int $resetId): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.password_reset SET used_at = now() WHERE id = :id AND used_at IS NULL'
            );
            $statement->execute([':id' => $resetId]);
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function revokeAllForUser(int $userId): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.password_reset SET used_at = now()
                  WHERE user_id = :user AND used_at IS NULL'
            );
            $statement->execute([':user' => $userId]);
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }
}
