<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDOException;

/** Roles, permisos efectivos y grants por catálogo de un usuario. */
final class RbacRepository
{
    /** @return list<array{code: string, name: string}> */
    public static function rolesForUser(int $userId): array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT r.code, r.name
                   FROM os_admin.membership m
                   JOIN os_admin.role r ON r.code = m.role_code
                  WHERE m.user_id = :user
                    AND m.status = :status
                    AND (m.valid_from IS NULL OR m.valid_from <= current_date)
                    AND (m.valid_to IS NULL OR m.valid_to >= current_date)
                  ORDER BY r.code'
            );
            $statement->execute([':user' => $userId, ':status' => 'active']);

            $rows = $statement->fetchAll();

            return array_map(
                static fn (array $row): array => ['code' => (string) $row['code'], 'name' => (string) $row['name']],
                $rows
            );
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** @return list<string> */
    public static function permissionsForUser(int $userId): array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT DISTINCT rp.permission_code
                   FROM os_admin.membership m
                   JOIN os_admin.role_permission rp ON rp.role_code = m.role_code
                  WHERE m.user_id = :user
                    AND m.status = :status
                    AND (m.valid_from IS NULL OR m.valid_from <= current_date)
                    AND (m.valid_to IS NULL OR m.valid_to >= current_date)
                  ORDER BY rp.permission_code'
            );
            $statement->execute([':user' => $userId, ':status' => 'active']);

            return array_map('strval', array_column($statement->fetchAll(), 'permission_code'));
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /**
     * @return list<array{catalog_code: string, operation: string, allowed: bool}>
     */
    public static function grantsForUser(int $userId): array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT catalog_code, operation, allowed FROM os_admin.catalog_grant WHERE user_id = :user'
            );
            $statement->execute([':user' => $userId]);

            $rows = $statement->fetchAll();

            return array_map(
                static fn (array $row): array => [
                    'catalog_code' => (string) $row['catalog_code'],
                    'operation' => (string) $row['operation'],
                    'allowed' => (bool) $row['allowed'],
                ],
                $rows
            );
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }
}
