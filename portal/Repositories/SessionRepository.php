<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDOException;

/** Sesiones del panel: solo hashes de token y huellas de red. */
final class SessionRepository
{
    public static function create(
        int $userId,
        string $tokenHash,
        string $expiresAt,
        ?string $ipHash,
        ?string $userAgentHash
    ): void {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'INSERT INTO os_admin.session
                    (user_id, token_hash, expires_at, ip_hash, user_agent_hash)
                 VALUES (:user, :token, :expires, :ip, :agent)'
            );
            $statement->execute([
                ':user' => $userId,
                ':token' => $tokenHash,
                ':expires' => $expiresAt,
                ':ip' => $ipHash,
                ':agent' => $userAgentHash,
            ]);
        } catch (PDOException) {
            throw new RepositoryException('admin_session_unavailable');
        }
    }

    /** @return array<string, mixed>|null */
    public static function findActive(string $tokenHash): ?array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT id, user_id, expires_at FROM os_admin.session
                  WHERE token_hash = :token AND revoked_at IS NULL AND expires_at > now()
                  LIMIT 1'
            );
            $statement->execute([':token' => $tokenHash]);

            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function touch(int $sessionId): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.session SET last_seen_at = now()
                  WHERE id = :id AND revoked_at IS NULL'
            );
            $statement->execute([':id' => $sessionId]);
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function revoke(string $tokenHash): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.session SET revoked_at = now()
                  WHERE token_hash = :token AND revoked_at IS NULL'
            );
            $statement->execute([':token' => $tokenHash]);
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function revokeAllForUser(int $userId): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.session SET revoked_at = now()
                  WHERE user_id = :user AND revoked_at IS NULL'
            );
            $statement->execute([':user' => $userId]);
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }
}
