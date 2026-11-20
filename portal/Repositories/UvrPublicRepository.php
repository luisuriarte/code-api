<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

/**
 * Lectura pública de valoraciones UVR publicadas (U7-D).
 *
 * Solo consulta `v_os_uvr_prestacion_public`: la vista ya filtra valoraciones,
 * prestaciones, perfiles y vínculos publicados. El rol del portal no recibe
 * privilegios sobre las tablas base ni sobre conversiones. Si U7-B no está
 * aplicado, el repositorio devuelve una lista vacía sin exponer errores SQL.
 */
final class UvrPublicRepository
{
    private static ?bool $viewAvailable = null;

    /**
     * @return list<array<string, mixed>>
     */
    public static function publishedForItem(int $itemId, string $catalogCode): array
    {
        if ($itemId <= 0 || !preg_match('/^[a-z0-9][a-z0-9-]{1,49}$/', $catalogCode) === 1) {
            return [];
        }

        if (!PortalDatabase::available() || !self::hasView()) {
            return [];
        }

        try {
            $statement = PortalDatabase::connection()->prepare(
                'SELECT catalog_code, item_id, prestacion_code, prestacion_name,
                        profile_code, methodology, scope, jurisdiction, version_tag,
                        published_at, valid_from, valid_to, work_uvr,
                        practice_expense_uvr, professional_liability_uvr, total_uvr,
                        currency, importe_referencial
                   FROM public.v_os_uvr_prestacion_public
                  WHERE catalog_code = :catalog AND item_id = :item
                  ORDER BY published_at DESC, valuation_id DESC
                  LIMIT 5'
            );
            $statement->execute([':catalog' => $catalogCode, ':item' => $itemId]);
            $rows = $statement->fetchAll();

            return is_array($rows) ? $rows : [];
        } catch (\Throwable) {
            return [];
        }
    }

    private static function hasView(): bool
    {
        if (self::$viewAvailable !== null) {
            return self::$viewAvailable;
        }

        try {
            $statement = PortalDatabase::connection()->prepare(
                "SELECT to_regclass('public.v_os_uvr_prestacion_public') IS NOT NULL"
            );
            $statement->execute();
            self::$viewAvailable = (bool) $statement->fetchColumn();
        } catch (\Throwable) {
            self::$viewAvailable = false;
        }

        return self::$viewAvailable;
    }
}
