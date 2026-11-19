<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDO;
use PDOException;

/** Memberships globales y por organización, con suspensión y revocación. */
final class MembershipRepository
{
    /** @return array<string, mixed>|null */
    public static function findById(int $id): ?array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT m.id, m.user_id, m.organization_id, m.role_code, m.status,
                        m.valid_from, m.valid_to, m.revoked_at, m.revoke_reason,
                        u.email, u.full_name, o.name AS organization_name, o.code AS organization_code
                   FROM os_admin.membership m
                   JOIN os_admin.app_user u ON u.id = m.user_id
                   LEFT JOIN os_admin.organization o ON o.id = m.organization_id
                  WHERE m.id = :id LIMIT 1'
            );
            $statement->execute([':id' => $id]);
            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** @return list<array<string, mixed>> */
    public static function forOrganization(int $organizationId): array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT m.id, m.user_id, m.role_code, m.status, m.valid_from,
                        m.valid_to, m.revoked_at, m.revoke_reason,
                        u.email, u.full_name
                   FROM os_admin.membership m
                   JOIN os_admin.app_user u ON u.id = m.user_id
                  WHERE m.organization_id = :org
                  ORDER BY u.email, m.role_code'
            );
            $statement->execute([':org' => $organizationId]);

            return $statement->fetchAll();
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /**
     * Organizaciones activas donde el usuario tiene un membership vigente.
     *
     * La consulta con `code` es la de M2. Si la migración aún no se aplicó, se
     * usa la variante M1 (sin esa columna) para no romper el login existente.
     *
     * @return list<array{id: int, name: string, code: string|null}>
     */
    public static function activeContexts(int $userId): array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT DISTINCT o.id, o.name, o.code
                   FROM os_admin.membership m
                   JOIN os_admin.organization o ON o.id = m.organization_id
                  WHERE m.user_id = :user
                    AND m.status = :status
                    AND o.is_active = true
                    AND (m.valid_from IS NULL OR m.valid_from <= current_date)
                    AND (m.valid_to IS NULL OR m.valid_to >= current_date)
                  ORDER BY o.name, o.id'
            );
            $statement->execute([':user' => $userId, ':status' => 'active']);
        } catch (PDOException) {
            // M1: organization.code todavía no existe.
            try {
                $statement = AdminDatabase::connection()->prepare(
                    'SELECT DISTINCT o.id, o.name, NULL AS code
                       FROM os_admin.membership m
                       JOIN os_admin.organization o ON o.id = m.organization_id
                      WHERE m.user_id = :user
                        AND m.status = :status
                        AND o.is_active = true
                        AND (m.valid_from IS NULL OR m.valid_from <= current_date)
                        AND (m.valid_to IS NULL OR m.valid_to >= current_date)
                      ORDER BY o.name, o.id'
                );
                $statement->execute([':user' => $userId, ':status' => 'active']);
            } catch (PDOException) {
                throw new RepositoryException('admin_database_unavailable');
            }
        }

        return array_map(
            static fn (array $row): array => [
                'id' => (int) $row['id'],
                'name' => (string) $row['name'],
                'code' => $row['code'] === null ? null : (string) $row['code'],
            ],
            $statement->fetchAll()
        );
    }

    /** @return list<string> */
    public static function globalRoleCodes(int $userId): array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT m.role_code
                   FROM os_admin.membership m
                  WHERE m.user_id = :user
                    AND m.organization_id IS NULL
                    AND m.status = :status
                    AND (m.valid_from IS NULL OR m.valid_from <= current_date)
                    AND (m.valid_to IS NULL OR m.valid_to >= current_date)
                  ORDER BY m.role_code'
            );
            $statement->execute([':user' => $userId, ':status' => 'active']);

            return array_map('strval', array_column($statement->fetchAll(), 'role_code'));
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function hasActiveInOrganization(int $userId, int $organizationId): bool
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT 1
                   FROM os_admin.membership m
                   JOIN os_admin.organization o ON o.id = m.organization_id
                  WHERE m.user_id = :user
                    AND m.organization_id = :org
                    AND m.status = :status
                    AND o.is_active = true
                    AND (m.valid_from IS NULL OR m.valid_from <= current_date)
                    AND (m.valid_to IS NULL OR m.valid_to >= current_date)
                  LIMIT 1'
            );
            $statement->execute([
                ':user' => $userId,
                ':org' => $organizationId,
                ':status' => 'active',
            ]);

            return $statement->fetchColumn() !== false;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function countActiveGlobalSuperadmins(): int
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT count(*)
                   FROM os_admin.membership
                  WHERE organization_id IS NULL
                    AND role_code = :role
                    AND status = :status
                    AND (valid_from IS NULL OR valid_from <= current_date)
                    AND (valid_to IS NULL OR valid_to >= current_date)'
            );
            $statement->execute([':role' => 'superadmin', ':status' => 'active']);

            return (int) $statement->fetchColumn();
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /**
     * Crea o reactiva un membership. Devuelve la acción efectuada para auditar.
     *
     * @return array{id: int, action: string}
     */
    public static function upsert(
        int $userId,
        ?int $organizationId,
        string $roleCode,
        int $actorId
    ): array {
        $pdo = AdminDatabase::connection();

        try {
            $pdo->beginTransaction();
            $result = self::upsertWithin($pdo, $userId, $organizationId, $roleCode, $actorId);
            $pdo->commit();

            return $result;
        } catch (PDOException) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }

            throw new RepositoryException('membership_update_failed');
        }
    }

    /**
     * Versión reutilizable dentro de una transacción más amplia (aceptación
     * de invitación). No abre ni cierra la transacción.
     *
     * @return array{id: int, action: string}
     */
    public static function upsertWithin(
        PDO $pdo,
        int $userId,
        ?int $organizationId,
        string $roleCode,
        int $actorId
    ): array {
        $select = $pdo->prepare(
            'SELECT id, status
               FROM os_admin.membership
              WHERE user_id = :user
                AND organization_id IS NOT DISTINCT FROM :org
                AND role_code = :role
              FOR UPDATE
              LIMIT 1'
        );
        $select->execute([
            ':user' => $userId,
            ':org' => $organizationId,
            ':role' => $roleCode,
        ]);
        $existing = $select->fetch();

        if ($existing !== false) {
            $id = (int) $existing['id'];

            if ($existing['status'] === 'active') {
                return ['id' => $id, 'action' => 'unchanged'];
            }

            $update = $pdo->prepare(
                'UPDATE os_admin.membership
                    SET status = :status,
                        revoked_at = NULL,
                        revoked_by_user_id = NULL,
                        revoke_reason = NULL,
                        updated_at = now()
                  WHERE id = :id'
            );
            $update->execute([
                ':status' => 'active',
                ':id' => $id,
            ]);

            return ['id' => $id, 'action' => 'reactivated'];
        }

        $insert = $pdo->prepare(
            'INSERT INTO os_admin.membership (
                 user_id, organization_id, role_code, status,
                 created_by_user_id
             ) VALUES (
                 :user, :org, :role, :status, :actor
             ) RETURNING id'
        );
        $insert->execute([
            ':user' => $userId,
            ':org' => $organizationId,
            ':role' => $roleCode,
            ':status' => 'active',
            ':actor' => $actorId,
        ]);

        return ['id' => (int) $insert->fetchColumn(), 'action' => 'created'];
    }

    public static function setStatus(
        int $id,
        string $status,
        int $actorId,
        ?string $reason = null
    ): void {
        $revokedAt = $status === 'revoked'
            ? (new \DateTimeImmutable('now', new \DateTimeZone('UTC')))->format(\DateTimeInterface::ATOM)
            : null;
        $revokedBy = $revokedAt === null ? null : $actorId;

        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.membership
                    SET status = :status,
                        revoked_at = :revoked_at,
                        revoked_by_user_id = :revoked_by,
                        revoke_reason = :reason,
                        updated_at = now()
                  WHERE id = :id'
            );
            $statement->execute([
                ':id' => $id,
                ':status' => $status,
                ':revoked_at' => $revokedAt,
                ':revoked_by' => $revokedBy,
                ':reason' => $reason !== null && $reason !== '' ? mb_substr($reason, 0, 200) : null,
            ]);
        } catch (PDOException) {
            throw new RepositoryException('membership_update_failed');
        }
    }
}
