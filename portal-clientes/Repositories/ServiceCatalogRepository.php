<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

/** Catálogo técnico verificable. No contiene precios ni datos comerciales. */
final class ServiceCatalogRepository
{
    /** @return list<array<string, mixed>> */
    public static function available(): array
    {
        $statement = CustomerDatabase::connection()->query(
            'SELECT id, code, name, description, domain, api_route, api_method,
                    auth_required, environment, verified_source
               FROM os_customer.service
              WHERE status = \'available\'
              ORDER BY code'
        );
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    /** @return array<string, mixed>|null */
    public static function findById(int $id): ?array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT * FROM os_customer.service WHERE id = :id'
        );
        $statement->execute([':id' => $id]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    /** @param list<int> $ids
     *  @return array<int, array<string, mixed>>
     */
    public static function findAvailableByIds(array $ids): array
    {
        $ids = array_values(array_unique(array_filter($ids, static fn ($id): bool => is_int($id) && $id > 0)));
        if ($ids === []) {
            return [];
        }

        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT id, code, name, api_route
               FROM os_customer.service
              WHERE status = \'available\'
                AND id IN (' . $placeholders . ')
              ORDER BY code'
        );
        $statement->execute($ids);
        $rows = $statement->fetchAll();
        $result = [];
        foreach (is_array($rows) ? $rows : [] as $row) {
            $result[(int) $row['id']] = $row;
        }

        return $result;
    }
}
