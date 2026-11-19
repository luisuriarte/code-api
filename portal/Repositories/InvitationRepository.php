<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use PDOException;

/** Invitaciones de colaboradores: token hasheado, un solo uso y auditoría. */
final class InvitationRepository
{
    /** @param list<array{catalog_code: string, operation: string, allowed: bool}> $grants */
    public static function create(
        string $email,
        int $organizationId,
        string $roleCode,
        string $tokenHash,
        int $actorId,
        int $ttlSeconds,
        ?string $message,
        array $grants
    ): int {
        $pdo = AdminDatabase::connection();

        try {
            $pdo->beginTransaction();

            $expiresAt = (new DateTimeImmutable('now', new DateTimeZone('UTC')))
                ->modify('+' . max(60, $ttlSeconds) . ' seconds')
                ->format(DateTimeInterface::ATOM);

            $statement = $pdo->prepare(
                'INSERT INTO os_admin.invitation (
                     email, organization_id, role_code, token_hash,
                     invited_by_user_id, message, expires_at, send_count, last_sent_at
                 ) VALUES (
                     :email, :org, :role, :token, :actor, :message,
                     :expires, 1, now()
                 ) RETURNING id'
            );
            $statement->execute([
                ':email' => $email,
                ':org' => $organizationId,
                ':role' => $roleCode,
                ':token' => $tokenHash,
                ':actor' => $actorId,
                ':message' => $message !== null && $message !== '' ? mb_substr($message, 0, 1000) : null,
                ':expires' => $expiresAt,
            ]);
            $id = (int) $statement->fetchColumn();

            self::insertGrants($pdo, $id, $grants);
            $pdo->commit();

            return $id;
        } catch (PDOException) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }

            throw new RepositoryException('invitation_create_failed');
        }
    }

    /** @return array<string, mixed>|null */
    public static function findByTokenHash(string $tokenHash): ?array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT i.id, i.email, i.organization_id, i.role_code, i.token_hash,
                        i.expires_at, i.accepted_at, i.revoked_at, i.revoke_reason,
                        i.message, i.send_count,
                        o.name AS organization_name, o.is_active AS organization_active,
                        r.name AS role_name
                   FROM os_admin.invitation i
                   JOIN os_admin.organization o ON o.id = i.organization_id
                   JOIN os_admin.role r ON r.code = i.role_code
                  WHERE i.token_hash = :token LIMIT 1'
            );
            $statement->execute([':token' => $tokenHash]);
            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** Bloqueo pesimista dentro de la transacción de aceptación. */
    public static function lockForUpdate(\PDO $pdo, int $id): void
    {
        $statement = $pdo->prepare('SELECT id FROM os_admin.invitation WHERE id = :id FOR UPDATE');
        $statement->execute([':id' => $id]);

        if ($statement->fetchColumn() === false) {
            throw new RepositoryException('invitation_not_found');
        }
    }

    /** @return array<string, mixed>|null */
    public static function findById(int $id): ?array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT i.id, i.email, i.organization_id, i.role_code,
                        i.expires_at, i.accepted_at, i.revoked_at, i.revoke_reason,
                        i.message, i.send_count, i.last_sent_at,
                        o.name AS organization_name,
                        r.name AS role_name,
                        u.email AS invited_by_email
                   FROM os_admin.invitation i
                   JOIN os_admin.organization o ON o.id = i.organization_id
                   JOIN os_admin.role r ON r.code = i.role_code
                   LEFT JOIN os_admin.app_user u ON u.id = i.invited_by_user_id
                  WHERE i.id = :id LIMIT 1'
            );
            $statement->execute([':id' => $id]);
            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** @return list<array<string, mixed>> */
    public static function all(string $status = 'all'): array
    {
        $filters = [
            'pending' => 'i.accepted_at IS NULL AND i.revoked_at IS NULL AND i.expires_at >= now()',
            'expired' => 'i.accepted_at IS NULL AND i.revoked_at IS NULL AND i.expires_at < now()',
            'accepted' => 'i.accepted_at IS NOT NULL',
            'revoked' => 'i.revoked_at IS NOT NULL',
            'all' => 'true',
        ];
        $where = $filters[$status] ?? $filters['all'];

        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT i.id, i.email, i.organization_id, i.role_code,
                        i.expires_at, i.accepted_at, i.revoked_at, i.revoke_reason,
                        i.send_count,
                        o.name AS organization_name,
                        r.name AS role_name
                   FROM os_admin.invitation i
                   JOIN os_admin.organization o ON o.id = i.organization_id
                   JOIN os_admin.role r ON r.code = i.role_code
                  WHERE ' . $where . '
                  ORDER BY i.created_at DESC, i.id DESC
                  LIMIT 200'
            );
            $statement->execute();

            return $statement->fetchAll();
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** @return list<array<string, mixed>> */
    public static function forOrganization(int $organizationId): array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT i.id, i.email, i.role_code, i.expires_at,
                        i.accepted_at, i.revoked_at, i.revoke_reason,
                        r.name AS role_name
                   FROM os_admin.invitation i
                   JOIN os_admin.role r ON r.code = i.role_code
                  WHERE i.organization_id = :org
                  ORDER BY i.created_at DESC, i.id DESC
                  LIMIT 100'
            );
            $statement->execute([':org' => $organizationId]);

            return $statement->fetchAll();
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** Revoca vencidas para liberar la unicidad de invitación pendiente. */
    public static function revokeExpired(int $actorId): int
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.invitation
                    SET revoked_at = now(),
                        revoked_by_user_id = :actor,
                        revoke_reason = :reason,
                        updated_at = now()
                  WHERE accepted_at IS NULL
                    AND revoked_at IS NULL
                    AND expires_at <= now()'
            );
            $statement->execute([':actor' => $actorId, ':reason' => 'expired']);

            return $statement->rowCount();
        } catch (PDOException) {
            throw new RepositoryException('invitation_update_failed');
        }
    }

    public static function hasPending(string $email, int $organizationId): bool
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT 1 FROM os_admin.invitation
                  WHERE lower(email) = lower(:email)
                    AND organization_id = :org
                    AND accepted_at IS NULL
                    AND revoked_at IS NULL
                  LIMIT 1'
            );
            $statement->execute([':email' => $email, ':org' => $organizationId]);

            return $statement->fetchColumn() !== false;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function revoke(int $id, int $actorId, string $reason): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.invitation
                    SET revoked_at = now(),
                        revoked_by_user_id = :actor,
                        revoke_reason = :reason,
                        updated_at = now()
                  WHERE id = :id AND accepted_at IS NULL AND revoked_at IS NULL'
            );
            $statement->execute([
                ':id' => $id,
                ':actor' => $actorId,
                ':reason' => mb_substr($reason, 0, 40),
            ]);
        } catch (PDOException) {
            throw new RepositoryException('invitation_update_failed');
        }
    }

    public static function revokePendingForEmail(
        string $email,
        int $organizationId,
        int $actorId,
        string $reason
    ): int {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.invitation
                    SET revoked_at = now(),
                        revoked_by_user_id = :actor,
                        revoke_reason = :reason,
                        updated_at = now()
                  WHERE lower(email) = lower(:email)
                    AND organization_id = :org
                    AND accepted_at IS NULL
                    AND revoked_at IS NULL'
            );
            $statement->execute([
                ':actor' => $actorId,
                ':reason' => mb_substr($reason, 0, 40),
                ':email' => $email,
                ':org' => $organizationId,
            ]);

            return $statement->rowCount();
        } catch (PDOException) {
            throw new RepositoryException('invitation_update_failed');
        }
    }

    public static function rotateToken(int $id, string $tokenHash, int $ttlSeconds): string
    {
        $expiresAt = (new DateTimeImmutable('now', new DateTimeZone('UTC')))
            ->modify('+' . max(60, $ttlSeconds) . ' seconds')
            ->format(DateTimeInterface::ATOM);

        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.invitation
                    SET token_hash = :token,
                        expires_at = :expires,
                        send_count = send_count + 1,
                        last_sent_at = now(),
                        updated_at = now()
                  WHERE id = :id AND accepted_at IS NULL AND revoked_at IS NULL'
            );
            $statement->execute([
                ':id' => $id,
                ':token' => $tokenHash,
                ':expires' => $expiresAt,
            ]);

            return $expiresAt;
        } catch (PDOException) {
            throw new RepositoryException('invitation_update_failed');
        }
    }

    public static function markAccepted(int $id, int $userId): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.invitation
                    SET accepted_at = now(),
                        accepted_by_user_id = :user,
                        updated_at = now()
                  WHERE id = :id AND accepted_at IS NULL AND revoked_at IS NULL'
            );
            $statement->execute([':id' => $id, ':user' => $userId]);
        } catch (PDOException) {
            throw new RepositoryException('invitation_update_failed');
        }
    }

    /** @return list<array{catalog_code: string, operation: string, allowed: bool}> */
    public static function grants(int $invitationId): array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT catalog_code, operation, allowed
                   FROM os_admin.invitation_grant WHERE invitation_id = :id
                  ORDER BY catalog_code, operation'
            );
            $statement->execute([':id' => $invitationId]);

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

    /**
     * @param \PDO $pdo
     * @param list<array{catalog_code: string, operation: string, allowed: bool}> $grants
     */
    private static function insertGrants(\PDO $pdo, int $invitationId, array $grants): void
    {
        $statement = $pdo->prepare(
            'INSERT INTO os_admin.invitation_grant
                 (invitation_id, catalog_code, operation, allowed)
             VALUES (:invitation, :catalog, :operation, :allowed)'
        );

        foreach ($grants as $grant) {
            $statement->execute([
                ':invitation' => $invitationId,
                ':catalog' => $grant['catalog_code'],
                ':operation' => $grant['operation'],
                ':allowed' => $grant['allowed'],
            ]);
        }
    }
}
