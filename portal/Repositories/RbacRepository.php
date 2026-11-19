<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDOException;

/**
 * Roles, permisos efectivos y grants por catálogo de un usuario.
 *
 * Desde M2 todos los métodos reciben el contexto activo:
 *   - null = plataforma (solo memberships globales);
 *   - entero = esa organización (globales + memberships de esa organización).
 * Los memberships de organizaciones no activas nunca se suman.
 */
final class RbacRepository
{
    /**
     * @return list<array{code: string, name: string}>
     */
    public static function rolesForUser(int $userId, ?int $organizationId = null): array
    {
        $clause = self::contextClause($organizationId);

        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT r.code, r.name
                   FROM os_admin.membership m
                   JOIN os_admin.role r ON r.code = m.role_code
                  WHERE m.user_id = :user
                    AND m.status = :status
                    AND (m.valid_from IS NULL OR m.valid_from <= current_date)
                    AND (m.valid_to IS NULL OR m.valid_to >= current_date)
                    AND (m.organization_id IS NULL OR EXISTS (
                        SELECT 1 FROM os_admin.organization o
                         WHERE o.id = m.organization_id AND o.is_active = true
                    ))
                    AND ' . $clause['sql'] . '
                  ORDER BY r.code'
            );
            $statement->execute($clause['params'] + [
                ':user' => $userId,
                ':status' => 'active',
            ]);

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
    public static function permissionsForUser(int $userId, ?int $organizationId = null): array
    {
        $clause = self::contextClause($organizationId);

        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT DISTINCT rp.permission_code
                   FROM os_admin.membership m
                   JOIN os_admin.role_permission rp ON rp.role_code = m.role_code
                  WHERE m.user_id = :user
                    AND m.status = :status
                    AND (m.valid_from IS NULL OR m.valid_from <= current_date)
                    AND (m.valid_to IS NULL OR m.valid_to >= current_date)
                    AND (m.organization_id IS NULL OR EXISTS (
                        SELECT 1 FROM os_admin.organization o
                         WHERE o.id = m.organization_id AND o.is_active = true
                    ))
                    AND ' . $clause['sql'] . '
                  ORDER BY rp.permission_code'
            );
            $statement->execute($clause['params'] + [
                ':user' => $userId,
                ':status' => 'active',
            ]);

            return array_map('strval', array_column($statement->fetchAll(), 'permission_code'));
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /**
     * @return list<array{catalog_code: string, operation: string, allowed: bool}>
     */
    public static function grantsForUser(int $userId, ?int $organizationId = null): array
    {
        $clause = self::contextClause($organizationId);

        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT catalog_code, operation, allowed
                   FROM os_admin.catalog_grant g
                  WHERE g.user_id = :user
                    AND (
                        g.membership_id IS NULL
                        OR g.membership_id IN (
                            SELECT m.id
                              FROM os_admin.membership m
                             WHERE m.user_id = :grant_user
                               AND m.status = :status
                               AND (m.valid_from IS NULL OR m.valid_from <= current_date)
                               AND (m.valid_to IS NULL OR m.valid_to >= current_date)
                               AND (m.organization_id IS NULL OR EXISTS (
                                   SELECT 1 FROM os_admin.organization o
                                    WHERE o.id = m.organization_id AND o.is_active = true
                               ))
                               AND ' . $clause['sql'] . '
                        )
                    )
                  ORDER BY g.catalog_code, g.operation'
            );
            $statement->execute($clause['params'] + [
                ':user' => $userId,
                ':grant_user' => $userId,
                ':status' => 'active',
            ]);

            return self::mapGrants($statement->fetchAll());
        } catch (PDOException) {
            // M2 no aplicado: los grants globales de M1 siguen siendo válidos.
            return self::legacyGrantsForUser($userId);
        }
    }

    /**
     * @return array{sql: string, params: array<string, int>}
     */
    private static function contextClause(?int $organizationId): array
    {
        if ($organizationId === null) {
            return ['sql' => 'm.organization_id IS NULL', 'params' => []];
        }

        return [
            'sql' => '(m.organization_id IS NULL OR m.organization_id = :org)',
            'params' => [':org' => $organizationId],
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $rows
     * @return list<array{catalog_code: string, operation: string, allowed: bool}>
     */
    private static function mapGrants(array $rows): array
    {
        return array_map(
            static fn (array $row): array => [
                'catalog_code' => (string) $row['catalog_code'],
                'operation' => (string) $row['operation'],
                'allowed' => (bool) $row['allowed'],
            ],
            $rows
        );
    }

    /** @return list<array{catalog_code: string, operation: string, allowed: bool}> */
    private static function legacyGrantsForUser(int $userId): array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT catalog_code, operation, allowed
                   FROM os_admin.catalog_grant WHERE user_id = :user
                  ORDER BY catalog_code, operation'
            );
            $statement->execute([':user' => $userId]);

            return self::mapGrants($statement->fetchAll());
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }
}
