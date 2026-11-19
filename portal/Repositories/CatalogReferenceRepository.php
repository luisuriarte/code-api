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
}
