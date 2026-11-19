<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDOException;

/** Grants globales y por membership. Una denegación explícita gana siempre. */
final class CatalogGrantRepository
{
    public static function setForMembership(
        int $userId,
        int $membershipId,
        string $catalogCode,
        string $operation,
        bool $allowed,
        int $actorId
    ): void {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'INSERT INTO os_admin.catalog_grant (
                     user_id, membership_id, catalog_code, operation, allowed, created_by_user_id
                 ) VALUES (
                     :user, :membership, :catalog, :operation, :allowed, :actor
                 )
                 ON CONFLICT (membership_id, catalog_code, operation)
                 WHERE membership_id IS NOT NULL
                 DO UPDATE SET allowed = EXCLUDED.allowed,
                               created_by_user_id = EXCLUDED.created_by_user_id,
                               updated_at = now()'
            );
            $statement->execute([
                ':user' => $userId,
                ':membership' => $membershipId,
                ':catalog' => $catalogCode,
                ':operation' => $operation,
                ':allowed' => $allowed,
                ':actor' => $actorId,
            ]);
        } catch (PDOException) {
            throw new RepositoryException('catalog_grant_update_failed');
        }
    }

    public static function setGlobal(
        int $userId,
        string $catalogCode,
        string $operation,
        bool $allowed,
        int $actorId
    ): void {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'INSERT INTO os_admin.catalog_grant (
                     user_id, catalog_code, operation, allowed, created_by_user_id
                 ) VALUES (
                     :user, :catalog, :operation, :allowed, :actor
                 )
                 ON CONFLICT (user_id, catalog_code, operation)
                 WHERE membership_id IS NULL
                 DO UPDATE SET allowed = EXCLUDED.allowed,
                               created_by_user_id = EXCLUDED.created_by_user_id,
                               updated_at = now()'
            );
            $statement->execute([
                ':user' => $userId,
                ':catalog' => $catalogCode,
                ':operation' => $operation,
                ':allowed' => $allowed,
                ':actor' => $actorId,
            ]);
        } catch (PDOException) {
            throw new RepositoryException('catalog_grant_update_failed');
        }
    }

    /** @return list<array{catalog_code: string, operation: string, allowed: bool}> */
    public static function forMembership(int $membershipId): array
    {
        return self::fetch(
            'SELECT catalog_code, operation, allowed
               FROM os_admin.catalog_grant WHERE membership_id = :id
              ORDER BY catalog_code, operation',
            [':id' => $membershipId]
        );
    }

    /** @return list<array{catalog_code: string, operation: string, allowed: bool}> */
    public static function globalForUser(int $userId): array
    {
        return self::fetch(
            'SELECT catalog_code, operation, allowed
               FROM os_admin.catalog_grant
              WHERE user_id = :user AND membership_id IS NULL
              ORDER BY catalog_code, operation',
            [':user' => $userId]
        );
    }

    /**
     * @param array<string, mixed> $params
     * @return list<array{catalog_code: string, operation: string, allowed: bool}>
     */
    private static function fetch(string $sql, array $params): array
    {
        try {
            $statement = AdminDatabase::connection()->prepare($sql);
            $statement->execute($params);

            return array_map(
                static fn (array $row): array => [
                    'catalog_code' => (string) $row['catalog_code'],
                    'operation' => (string) $row['operation'],
                    'allowed' => (bool) $row['allowed'],
                ],
                $statement->fetchAll()
            );
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }
}
