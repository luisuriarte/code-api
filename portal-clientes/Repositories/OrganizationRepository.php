<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

final class OrganizationRepository
{
    /** @return array<string, mixed>|null */
    public static function findById(int $id): ?array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT * FROM os_customer.organization WHERE id = :id'
        );
        $statement->execute([':id' => $id]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    /** @return list<array<string, mixed>> */
    public static function findActiveForUser(int $userId): array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT o.*
               FROM os_customer.organization o
               JOIN os_customer.membership m ON m.organization_id = o.id
              WHERE m.user_id = :user_id
                AND m.status = \'active\'
                AND o.status = \'active\'
                AND m.valid_from <= now()
                AND (m.valid_to IS NULL OR m.valid_to > now())
              ORDER BY o.legal_name, o.id'
        );
        $statement->execute([':user_id' => $userId]);
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    /** @return list<array<string, mixed>> */
    public static function findAllActive(): array
    {
        $statement = CustomerDatabase::connection()->query(
            'SELECT id, code, display_name, legal_name
               FROM os_customer.organization
              WHERE status = \'active\'
              ORDER BY display_name, legal_name, id'
        );
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    public static function update(int $id, string $legalName, string $displayName, ?string $taxId): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.organization
                SET legal_name = :legal_name,
                    display_name = :display_name,
                    tax_id_normalized = :tax_id,
                    updated_at = now()
              WHERE id = :id'
        );
        $statement->execute([
            ':id' => $id,
            ':legal_name' => $legalName,
            ':display_name' => $displayName,
            ':tax_id' => $taxId,
        ]);
    }
}
