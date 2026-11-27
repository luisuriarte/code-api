<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

final class RoleRepository
{
    /** @return list<array<string, mixed>> */
    public static function all(): array
    {
        $rows = CustomerDatabase::connection()->query(
            'SELECT code, label FROM os_customer.role ORDER BY id'
        )->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    /** Roles que un administrador de organización puede asignar a miembros. */
    private const CUSTOMER_ASSIGNABLE = [
        'organization_admin',
        'technical_admin',
        'developer',
        'viewer',
    ];

    /** @return list<array<string, mixed>> */
    public static function assignable(): array
    {
        $placeholders = implode(', ', array_fill(0, count(self::CUSTOMER_ASSIGNABLE), '?'));
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT code, label FROM os_customer.role
              WHERE code IN (' . $placeholders . ')
              ORDER BY id'
        );
        $statement->execute(self::CUSTOMER_ASSIGNABLE);
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    /** @return list<string> */
    public static function permissionCodes(int $organizationId, int $userId): array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT p.code
               FROM os_customer.membership m
               JOIN os_customer.role r ON r.code = m.role_code
               JOIN os_customer.role_permission rp ON rp.role_id = r.id
               JOIN os_customer.permission p ON p.id = rp.permission_id
              WHERE m.organization_id = :org
                AND m.user_id = :user
                AND m.status = \'active\'
                AND m.valid_from <= now()
                AND (m.valid_to IS NULL OR m.valid_to > now())'
        );
        $statement->execute([':org' => $organizationId, ':user' => $userId]);

        $codes = [];
        foreach ($statement->fetchAll() as $row) {
            if (is_array($row) && is_string($row['code'] ?? null)) {
                $codes[] = $row['code'];
            }
        }

        return $codes;
    }
}
