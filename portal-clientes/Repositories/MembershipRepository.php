<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

final class MembershipRepository
{
    /** @return array<string, mixed>|null */
    public static function findActive(int $organizationId, int $userId): ?array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT m.*, r.label AS role_label
               FROM os_customer.membership m
               JOIN os_customer.role r ON r.code = m.role_code
              WHERE m.organization_id = :org
                AND m.user_id = :user
                AND m.status = \'active\'
                AND m.valid_from <= now()
                AND (m.valid_to IS NULL OR m.valid_to > now())'
        );
        $statement->execute([':org' => $organizationId, ':user' => $userId]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    /** @return list<array<string, mixed>> */
    public static function listForOrganization(int $organizationId): array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT m.id, m.role_code, m.status, m.accepted_at, m.created_at,
                    u.id AS user_id, u.email, u.full_name, u.status AS user_status
               FROM os_customer.membership m
               JOIN os_customer.app_user u ON u.id = m.user_id
              WHERE m.organization_id = :org
              ORDER BY u.email, m.id'
        );
        $statement->execute([':org' => $organizationId]);
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    public static function create(int $organizationId, int $userId, string $roleCode, ?int $invitedBy): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'INSERT INTO os_customer.membership
                (organization_id, user_id, role_code, status, invited_by, accepted_at)
             VALUES
                (:org, :user, :role, \'active\', :invited_by, now())
             ON CONFLICT (organization_id, user_id) DO UPDATE
                SET role_code = EXCLUDED.role_code,
                    status = \'active\',
                    accepted_at = now(),
                    valid_to = NULL,
                    updated_at = now()'
        );
        $statement->execute([
            ':org' => $organizationId,
            ':user' => $userId,
            ':role' => $roleCode,
            ':invited_by' => $invitedBy,
        ]);
    }

    public static function changeRole(int $organizationId, int $userId, string $roleCode): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.membership
                SET role_code = :role, updated_at = now()
              WHERE organization_id = :org AND user_id = :user'
        );
        $statement->execute([
            ':org' => $organizationId,
            ':user' => $userId,
            ':role' => $roleCode,
        ]);
    }

    public static function revoke(int $organizationId, int $userId): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.membership
                SET status = \'revoked\', valid_to = now(), updated_at = now()
              WHERE organization_id = :org AND user_id = :user'
        );
        $statement->execute([':org' => $organizationId, ':user' => $userId]);
    }
}
