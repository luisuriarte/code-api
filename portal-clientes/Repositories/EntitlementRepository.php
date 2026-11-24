<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

/** Persistencia de habilitaciones técnicas. */
final class EntitlementRepository
{
    /** @return array<string, mixed>|null */
    public static function findById(int $id): ?array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT e.*, s.code AS service_code, s.name AS service_name
               FROM os_customer.entitlement e
               JOIN os_customer.service s ON s.id = e.service_id
              WHERE e.id = :id'
        );
        $statement->execute([':id' => $id]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    /** @return list<array<string, mixed>> */
    public static function findByOrganization(int $organizationId): array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT e.id, e.status, e.decision_at, e.expires_at, e.contract_id,
                    s.code AS service_code, s.name AS service_name, s.api_route
               FROM os_customer.entitlement e
               JOIN os_customer.service s ON s.id = e.service_id
              WHERE e.organization_id = :org
              ORDER BY e.id DESC
              LIMIT 100'
        );
        $statement->execute([':org' => $organizationId]);
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    /** @return list<array<string, mixed>> */
    public static function findPending(): array
    {
        $statement = CustomerDatabase::connection()->query(
            'SELECT e.id, e.status, e.organization_id, e.contract_id,
                    o.code AS organization_code, o.display_name AS organization_name,
                    s.code AS service_code, s.name AS service_name
               FROM os_customer.entitlement e
               JOIN os_customer.organization o ON o.id = e.organization_id
               JOIN os_customer.service s ON s.id = e.service_id
              WHERE e.status = \'pending_activation\'
              ORDER BY e.id'
        );
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    public static function create(
        int $organizationId,
        int $serviceId,
        ?int $contractId,
        ?int $requestId
    ): int {
        $statement = CustomerDatabase::connection()->prepare(
            'INSERT INTO os_customer.entitlement
                (organization_id, service_id, contract_id, request_id, status)
             VALUES (:org, :service, :contract, :request, \'pending_activation\')
             RETURNING id'
        );
        $statement->execute([
            ':org' => $organizationId,
            ':service' => $serviceId,
            ':contract' => $contractId,
            ':request' => $requestId,
        ]);

        return (int) $statement->fetchColumn();
    }

    /** Activa solo si el contrato tiene pago verificado y no existe otra activa. */
    public static function activate(int $entitlementId, int $actorUserId): bool
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.entitlement e
                SET status = \'active\',
                    decision_by = :actor,
                    decision_at = now(),
                    reason = NULL,
                    updated_at = now()
              WHERE e.id = :id
                AND e.status = \'pending_activation\'
                AND EXISTS (
                    SELECT 1 FROM os_customer.contract c
                     WHERE c.id = e.contract_id
                       AND c.status = \'active\'
                       AND c.commercial_condition = \'payment_confirmed\'
                       AND c.commercial_verified_by IS NOT NULL
                       AND c.commercial_verified_at IS NOT NULL
                       AND (c.valid_from IS NULL OR c.valid_from <= now())
                       AND (c.valid_to IS NULL OR c.valid_to > now())
                )'
        );
        $statement->execute([
            ':id' => $entitlementId,
            ':actor' => $actorUserId,
        ]);

        return $statement->rowCount() === 1;
    }

    public static function changeStatus(
        int $entitlementId,
        string $from,
        string $to,
        ?int $actorUserId,
        ?string $reason
    ): bool {
        $allowed = [
            'active' => ['suspended', 'revoked', 'expired'],
            'suspended' => ['active', 'revoked', 'expired'],
            'pending_activation' => ['revoked'],
        ];
        if (!isset($allowed[$from]) || !in_array($to, $allowed[$from], true)) {
            return false;
        }

        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.entitlement
                SET status = :to,
                    decision_by = :actor,
                    decision_at = now(),
                    reason = :reason,
                    updated_at = now()
              WHERE id = :id
                AND status = :from'
        );
        $statement->execute([
            ':id' => $entitlementId,
            ':from' => $from,
            ':to' => $to,
            ':actor' => $actorUserId,
            ':reason' => $reason,
        ]);

        return $statement->rowCount() === 1;
    }
}
