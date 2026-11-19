<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDOException;

/**
 * Validación de códigos de catálogo contra `public.os_catalog`.
 *
 * Usa la conexión pública de solo lectura: el rol origen_admin no recibe
 * ningún privilegio nuevo sobre os_catalog_*. Es una comprobación de
 * existencia; nunca escribe ni expone conceptos clínicos al panel.
 */
final class CatalogReferenceRepository
{
    public static function exists(string $code): bool
    {
        $code = trim($code);

        if ($code === '' || preg_match('/^[a-z0-9][a-z0-9-]{1,49}$/', $code) !== 1) {
            return false;
        }

        try {
            $statement = PortalDatabase::connection()->prepare(
                'SELECT 1 FROM public.os_catalog WHERE code = :code LIMIT 1'
            );
            $statement->execute([':code' => $code]);

            return $statement->fetchColumn() !== false;
        } catch (PDOException) {
            throw new RepositoryException('catalog_reference_unavailable');
        }
    }

    /**
     * Catálogos activos para poblar el selector de grants del panel.
     *
     * Solo lectura a través de la conexión pública; `origen_admin` no recibe
     * privilegios sobre os_catalog_*. La validación final sigue haciendo
     * `exists()` por si el código cambió entre render y envío.
     *
     * @return list<array{code: string, name: string, short_name: string}>
     */
    public static function all(): array
    {
        try {
            $statement = PortalDatabase::connection()->query(
                'SELECT code, name, short_name
                   FROM public.os_catalog
                  WHERE is_active = true
                  ORDER BY name, code'
            );

            return array_map(
                static fn (array $row): array => [
                    'code' => (string) $row['code'],
                    'name' => (string) $row['name'],
                    'short_name' => $row['short_name'] === null ? '' : (string) $row['short_name'],
                ],
                $statement->fetchAll()
            );
        } catch (PDOException) {
            throw new RepositoryException('catalog_reference_unavailable');
        }
    }
}
