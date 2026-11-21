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
 *
 * Los vínculos `os_prestacion_codigo` pueden grabarse por `item_id` (ítems de
 * os_catalog) o por `external_code` (SNOMED procedures, CIE-10, códigos
 * institucionales). La vista pública expone ambos, así que la resolución
 * pública también debe admitir los dos; si no, los procedimientos quedan
 * invisibles aunque tengan valoración publicada.
 */
final class UvrPublicRepository
{
    private static ?bool $viewAvailable = null;

    /**
     * @return list<array<string, mixed>>
     */
    public static function publishedForItem(
        int $itemId,
        string $catalogCode,
        ?string $externalCode = null
    ): array {
        $external = trim((string) ($externalCode ?? ''));
        $catalog = trim($catalogCode);

        if ($itemId <= 0 && $external === '') {
            return [];
        }
        if ($catalog !== '' && preg_match('/^[a-z0-9][a-z0-9-]{1,49}$/', $catalog) !== 1) {
            return [];
        }

        if (!PortalDatabase::available() || !self::hasView()) {
            return [];
        }

        // Se construyen condiciones, nunca SQL con valores del usuario: todos
        // los datos van ligados por PDO. `catalog_code` es opcional porque las
        // ramas nativas (prestaciones, odontología, CIE-10, SNOMED) no tienen
        // catalog_code en la ficha del browser.
        $conditions = [];
        $params = [];

        if ($catalog !== '') {
            $conditions[] = 'catalog_code = :catalog';
            $params[':catalog'] = $catalog;
        }

        $references = [];
        if ($itemId > 0) {
            $references[] = 'item_id = :item';
            $params[':item'] = $itemId;
        }
        if ($external !== '') {
            $references[] = 'btrim(external_code) = :external';
            $params[':external'] = $external;
        }
        if ($references === []) {
            return [];
        }
        $conditions[] = '(' . implode(' OR ', $references) . ')';

        try {
            $statement = PortalDatabase::connection()->prepare(
                'SELECT catalog_code, item_id, external_code, prestacion_code, prestacion_name,
                        profile_code, methodology, scope, jurisdiction, version_tag,
                        published_at, valid_from, valid_to, work_uvr,
                        practice_expense_uvr, professional_liability_uvr, total_uvr,
                        currency, importe_referencial
                   FROM public.v_os_uvr_prestacion_public
                  WHERE ' . implode(' AND ', $conditions) . '
                  ORDER BY published_at DESC, valuation_id DESC
                  LIMIT 5'
            );
            $statement->execute($params);
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
