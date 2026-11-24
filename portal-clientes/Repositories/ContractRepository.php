<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

/** Contratos verificados. Solo identificadores y estado, nunca importes. */
final class ContractRepository
{
    /** @return array<string, mixed>|null */
    public static function findById(int $id): ?array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT * FROM os_customer.contract WHERE id = :id'
        );
        $statement->execute([':id' => $id]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    /** @return list<array<string, mixed>> */
    public static function findByOrganization(int $organizationId): array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT id, status, commercial_condition, commercial_verified_at,
                    valid_from, valid_to, created_at
               FROM os_customer.contract
              WHERE organization_id = :org
              ORDER BY id DESC
              LIMIT 50'
        );
        $statement->execute([':org' => $organizationId]);
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    public static function create(int $organizationId, ?string $clientRef, ?string $itemRef): int
    {
        $statement = CustomerDatabase::connection()->prepare(
            'INSERT INTO os_customer.contract
                (organization_id, external_client_ref, external_item_ref, status, commercial_condition)
             VALUES (:org, :client, :item, \'pending\', \'payment_confirmed\')
             RETURNING id'
        );
        $statement->execute([
            ':org' => $organizationId,
            ':client' => $clientRef,
            ':item' => $itemRef,
        ]);

        return (int) $statement->fetchColumn();
    }

    /** Registra la verificación manual del pago por parte del superadministrador. */
    public static function markPaymentVerified(int $contractId, int $verifierUserId): bool
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.contract
                SET status = \'active\',
                    commercial_condition = \'payment_confirmed\',
                    commercial_verified_by = :verifier,
                    commercial_verified_at = now(),
                    updated_at = now()
              WHERE id = :id
                AND status = \'pending\'
                AND commercial_verified_at IS NULL'
        );
        $statement->execute([
            ':id' => $contractId,
            ':verifier' => $verifierUserId,
        ]);

        return $statement->rowCount() === 1;
    }

    /** Condición mínima para habilitar: pago verificado manualmente. */
    public static function paymentVerified(?int $contractId): bool
    {
        if ($contractId === null || $contractId <= 0) {
            return false;
        }

        $statement = CustomerDatabase::connection()->prepare(
            'SELECT 1
               FROM os_customer.contract
              WHERE id = :id
                AND status = \'active\'
                AND commercial_condition = \'payment_confirmed\'
                AND commercial_verified_by IS NOT NULL
                AND commercial_verified_at IS NOT NULL
                AND (valid_from IS NULL OR valid_from <= now())
                AND (valid_to IS NULL OR valid_to > now())'
        );
        $statement->execute([':id' => $contractId]);

        return $statement->fetchColumn() !== false;
    }
}
