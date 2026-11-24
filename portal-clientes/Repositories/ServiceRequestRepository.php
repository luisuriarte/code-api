<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

/** Solicitudes internas de servicios, sin precios ni condiciones comerciales. */
final class ServiceRequestRepository
{
    /** @param list<int> $serviceIds */
    public static function create(
        int $organizationId,
        int $requestedBy,
        array $serviceIds,
        ?string $note
    ): int {
        $connection = CustomerDatabase::connection();
        $connection->beginTransaction();
        try {
            $statement = $connection->prepare(
                'INSERT INTO os_customer.service_request
                    (organization_id, requested_by, status, note)
                 VALUES (:org, :user, \'received\', :note)
                 RETURNING id'
            );
            $statement->execute([
                ':org' => $organizationId,
                ':user' => $requestedBy,
                ':note' => $note,
            ]);
            $requestId = (int) $statement->fetchColumn();

            $item = $connection->prepare(
                'INSERT INTO os_customer.service_request_item (request_id, service_id)
                 VALUES (:request, :service)'
            );
            foreach ($serviceIds as $serviceId) {
                $item->execute([':request' => $requestId, ':service' => $serviceId]);
            }

            $connection->commit();

            return $requestId;
        } catch (\Throwable $e) {
            $connection->rollBack();

            throw $e;
        }
    }

    /** @return list<array<string, mixed>> */
    public static function findByOrganization(int $organizationId): array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT r.id, r.status, r.note, r.created_at,
                    count(i.service_id) AS service_count
               FROM os_customer.service_request r
               LEFT JOIN os_customer.service_request_item i ON i.request_id = r.id
              WHERE r.organization_id = :org
              GROUP BY r.id, r.status, r.note, r.created_at
              ORDER BY r.id DESC
              LIMIT 50'
        );
        $statement->execute([':org' => $organizationId]);
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }
}
