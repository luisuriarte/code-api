<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDOException;

/** Acceso a os_admin.app_user. Nunca devuelve el hash de contraseña a la vista. */
final class UserRepository
{
    private const COLUMNS = 'id, email, password_hash, full_name, status,
                            failed_login_count, locked_until, last_login_at,
                            email_verified_at, created_at';

    /** @return array<string, mixed>|null */
    public static function findByEmail(string $email): ?array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT ' . self::COLUMNS . ' FROM os_admin.app_user WHERE lower(email) = lower(:email) LIMIT 1'
            );
            $statement->execute([':email' => $email]);

            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** @return array<string, mixed>|null */
    public static function findById(int $id): ?array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT ' . self::COLUMNS . ' FROM os_admin.app_user WHERE id = :id LIMIT 1'
            );
            $statement->execute([':id' => $id]);

            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function create(string $email, string $passwordHash, string $fullName): int
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'INSERT INTO os_admin.app_user (email, password_hash, full_name, status)
                 VALUES (:email, :hash, :name, :status) RETURNING id'
            );
            $statement->execute([
                ':email' => $email,
                ':hash' => $passwordHash,
                ':name' => $fullName,
                ':status' => 'active',
            ]);

            return (int) $statement->fetchColumn();
        } catch (PDOException) {
            throw new RepositoryException('admin_user_create_failed');
        }
    }

    public static function assignRole(int $userId, string $roleCode, ?int $organizationId = null): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'INSERT INTO os_admin.membership (user_id, organization_id, role_code, status)
                 VALUES (:user, :org, :role, :status)
                 ON CONFLICT DO NOTHING'
            );
            $statement->execute([
                ':user' => $userId,
                ':org' => $organizationId,
                ':role' => $roleCode,
                ':status' => 'active',
            ]);
        } catch (PDOException) {
            throw new RepositoryException('admin_role_assign_failed');
        }
    }

    public static function recordFailure(int $userId, int $limit, int $lockMinutes): void
    {
        $lockUntil = (new \DateTimeImmutable('now', new \DateTimeZone('UTC')))
            ->modify('+' . max(1, $lockMinutes) . ' minutes')
            ->format(\DateTimeInterface::ATOM);

        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.app_user
                    SET failed_login_count = failed_login_count + 1,
                        locked_until = CASE
                            WHEN failed_login_count + 1 >= :limit THEN :lock_until::timestamptz
                            ELSE locked_until END,
                        updated_at = now()
                  WHERE id = :id AND status = :status'
            );
            $statement->execute([
                ':limit' => max(1, $limit),
                ':lock_until' => $lockUntil,
                ':id' => $userId,
                ':status' => 'active',
            ]);
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function recordSuccess(int $userId, string $ipHash): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.app_user
                    SET failed_login_count = 0, locked_until = NULL,
                        last_login_at = now(), last_login_ip_hash = :ip,
                        updated_at = now()
                  WHERE id = :id'
            );
            $statement->execute([':ip' => $ipHash, ':id' => $userId]);
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function setPasswordHash(int $userId, string $passwordHash): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.app_user SET password_hash = :hash, updated_at = now() WHERE id = :id'
            );
            $statement->execute([':hash' => $passwordHash, ':id' => $userId]);
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }
}
