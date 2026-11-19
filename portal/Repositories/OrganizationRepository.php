<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDOException;

/** Organizaciones operativas de gobernanza (M2). Baja lógica, sin borrado. */
final class OrganizationRepository
{
    private const COLUMNS = 'id, name, code, legal_name, type, country_code,
                            contact_email, website, notes, is_active,
                            created_at, updated_at, deactivated_at';

    /** @return list<array<string, mixed>> */
    public static function all(bool $onlyActive = false): array
    {
        try {
            $where = $onlyActive ? 'WHERE o.is_active = true' : '';
            $statement = AdminDatabase::connection()->prepare(
                'SELECT o.id, o.name, o.code, o.type, o.country_code,
                        o.contact_email, o.is_active, o.created_at, o.deactivated_at,
                        (SELECT count(*) FROM os_admin.membership m
                          WHERE m.organization_id = o.id AND m.status = :status) AS members,
                        (SELECT count(*) FROM os_admin.invitation i
                          WHERE i.organization_id = o.id
                            AND i.accepted_at IS NULL AND i.revoked_at IS NULL) AS pending_invites
                   FROM os_admin.organization o
                   ' . $where . '
                  ORDER BY o.name, o.id'
            );
            $statement->execute([':status' => 'active']);

            return $statement->fetchAll();
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** @return array<string, mixed>|null */
    public static function find(int $id): ?array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT ' . self::COLUMNS . ' FROM os_admin.organization WHERE id = :id LIMIT 1'
            );
            $statement->execute([':id' => $id]);
            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** @return array<string, mixed>|null */
    public static function findByCode(string $code): ?array
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT ' . self::COLUMNS . '
                   FROM os_admin.organization WHERE lower(code) = lower(:code) LIMIT 1'
            );
            $statement->execute([':code' => $code]);
            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function nameExists(string $name, ?int $excludeId = null): bool
    {
        try {
            $sql = 'SELECT 1 FROM os_admin.organization WHERE lower(name) = lower(:name)';
            $params = [':name' => $name];

            if ($excludeId !== null) {
                $sql .= ' AND id <> :exclude';
                $params[':exclude'] = $excludeId;
            }

            $statement = AdminDatabase::connection()->prepare($sql . ' LIMIT 1');
            $statement->execute($params);

            return $statement->fetchColumn() !== false;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** @param array<string, mixed> $data */
    public static function create(array $data, int $actorId): int
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'INSERT INTO os_admin.organization (
                     code, name, legal_name, type, country_code,
                     contact_email, website, notes, is_active,
                     created_by_user_id, updated_by_user_id
                 ) VALUES (
                     :code, :name, :legal_name, :type, :country,
                     :contact, :website, :notes, true, :actor, :actor_updated
                 ) RETURNING id'
            );
            $statement->execute([
                ':code' => $data['code'],
                ':name' => $data['name'],
                ':legal_name' => $data['legal_name'] !== '' ? $data['legal_name'] : null,
                ':type' => $data['type'],
                ':country' => $data['country_code'],
                ':contact' => $data['contact_email'] !== '' ? $data['contact_email'] : null,
                ':website' => $data['website'] !== '' ? $data['website'] : null,
                ':notes' => $data['notes'] !== '' ? $data['notes'] : null,
                ':actor' => $actorId,
                ':actor_updated' => $actorId,
            ]);

            return (int) $statement->fetchColumn();
        } catch (PDOException) {
            throw new RepositoryException('organization_create_failed');
        }
    }

    /** @param array<string, mixed> $data */
    public static function update(int $id, array $data, int $actorId): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.organization
                    SET name = :name,
                        legal_name = :legal_name,
                        website = :website,
                        notes = :notes,
                        contact_email = :contact,
                        type = :type,
                        country_code = :country,
                        updated_by_user_id = :actor,
                        updated_at = now()
                  WHERE id = :id'
            );
            $statement->execute([
                ':id' => $id,
                ':name' => $data['name'],
                ':legal_name' => $data['legal_name'] !== '' ? $data['legal_name'] : null,
                ':website' => $data['website'] !== '' ? $data['website'] : null,
                ':notes' => $data['notes'] !== '' ? $data['notes'] : null,
                ':contact' => $data['contact_email'] !== '' ? $data['contact_email'] : null,
                ':type' => $data['type'],
                ':country' => $data['country_code'],
                ':actor' => $actorId,
            ]);
        } catch (PDOException) {
            throw new RepositoryException('organization_update_failed');
        }
    }

    public static function hasBlockingDependencies(int $id): bool
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT
                    (SELECT count(*) FROM os_admin.membership
                      WHERE organization_id = :org AND status = :status) +
                    (SELECT count(*) FROM os_admin.invitation
                      WHERE organization_id = :org2
                        AND accepted_at IS NULL AND revoked_at IS NULL) AS total'
            );
            $statement->execute([
                ':org' => $id,
                ':org2' => $id,
                ':status' => 'active',
            ]);

            return (int) $statement->fetchColumn() > 0;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function setActive(int $id, bool $active, int $actorId): void
    {
        $deactivatedAt = $active
            ? null
            : (new \DateTimeImmutable('now', new \DateTimeZone('UTC')))->format(\DateTimeInterface::ATOM);

        try {
            $statement = AdminDatabase::connection()->prepare(
                'UPDATE os_admin.organization
                    SET is_active = :active,
                        deactivated_at = :deactivated_at,
                        updated_by_user_id = :actor,
                        updated_at = now()
                  WHERE id = :id'
            );
            $statement->execute([
                ':id' => $id,
                ':active' => $active,
                ':deactivated_at' => $deactivatedAt,
                ':actor' => $actorId,
            ]);
        } catch (PDOException) {
            throw new RepositoryException('organization_update_failed');
        }
    }
}
