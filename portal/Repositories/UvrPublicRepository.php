<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

/**
 * Lectura pública de valoraciones UVR publicadas (U7-D).
 *
 * Solo consulta vistas públicas ya filtradas: `v_os_uvr_prestacion_public`
 * (modelo transversal U7-B) y `v_os_uvr_valuation_public` (valoraciones legacy
 * sobre os_catalog). El rol del portal no recibe privilegios sobre las tablas
 * base ni sobre conversiones. Si alguna vista no está aplicada, se omite sin
 * exponer errores SQL.
 *
 * Los vínculos `os_prestacion_codigo` pueden grabarse por `item_id` (ítems de
 * os_catalog) o por `external_code` (SNOMED procedures, CIE-10, códigos
 * institucionales). Las vistas públicas exponen ambos, así que la resolución
 * pública también debe admitir los dos; si no, los procedimientos quedan
 * invisibles aunque tengan valoración publicada.
 */
final class UvrPublicRepository
{
    /** Modelo transversal: prestación + perfil + vínculo de catálogo. */
    private const VIEW_PRESTACION = 'public.v_os_uvr_prestacion_public';

    /** Modelo legacy: valoración sobre un código de os_catalog (DNT-PR, etc.). */
    private const VIEW_LEGACY = 'public.v_os_uvr_valuation_public';

    /** @var array<string, bool> */
    private static array $viewAvailable = [];

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

        if (!PortalDatabase::available()) {
            return [];
        }

        // Se construyen condiciones, nunca SQL con valores del usuario: todos
        // los datos van ligados por PDO. `catalog_code` es opcional porque las
        // ramas nativas (prestaciones, odontología, CIE-10, SNOMED) no tienen
        // catalog_code en la ficha del browser.
        $conditions = [];
        $params = [];

        if ($catalog !== '') {
            // El mismo código permanente puede estar publicado en más de un
            // catálogo (p. ej. DENTAR-PR y Nomenclador). Si Browse abrió un
            // ítem de otro catálogo con el mismo external_code, la UVR de la
            // prestación debe seguir siendo visible. dentar-dx queda excluido.
            if ($external !== '') {
                $conditions[] = '(catalog_code = :catalog'
                    . ' OR (btrim(external_code) = :external AND catalog_code <> :excluded))';
                $params[':excluded'] = 'dentar-dx';
            } else {
                $conditions[] = 'catalog_code = :catalog';
            }
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

        $where = ' WHERE ' . implode(' AND ', $conditions);
        $rows = [];

        // Ambos nombres son constantes de clase: nunca datos del usuario.
        foreach ([self::VIEW_PRESTACION, self::VIEW_LEGACY] as $view) {
            if (!self::hasView($view)) {
                continue;
            }

            try {
                $statement = PortalDatabase::connection()->prepare(
                    'SELECT valuation_id, catalog_code, item_id, external_code, prestacion_code, prestacion_name,
                            profile_code, methodology, scope, jurisdiction, version_tag,
                            published_at, valid_from, valid_to, work_uvr,
                            practice_expense_uvr, professional_liability_uvr, total_uvr,
                            currency, importe_referencial
                       FROM ' . $view . $where . '
                      ORDER BY published_at DESC, valuation_id DESC
                      LIMIT 5'
                );
                $statement->execute($params);
                $found = $statement->fetchAll();

                if (is_array($found)) {
                    $rows = array_merge($rows, $found);
                }
            } catch (\Throwable) {
                // Una vista ausente o sin permisos no invalida la otra rama.
                continue;
            }
        }

        usort($rows, static function (array $a, array $b): int {
            $byDate = strcmp(
                (string) ($b['published_at'] ?? ''),
                (string) ($a['published_at'] ?? '')
            );

            return $byDate !== 0
                ? $byDate
                : ((int) ($b['valuation_id'] ?? 0)) <=> ((int) ($a['valuation_id'] ?? 0));
        });

        return array_slice($rows, 0, 5);
    }

    private static function hasView(string $view): bool
    {
        if (array_key_exists($view, self::$viewAvailable)) {
            return self::$viewAvailable[$view];
        }

        try {
            $statement = PortalDatabase::connection()->prepare(
                'SELECT to_regclass(:name) IS NOT NULL'
            );
            $statement->execute([':name' => $view]);
            self::$viewAvailable[$view] = (bool) $statement->fetchColumn();
        } catch (\Throwable) {
            self::$viewAvailable[$view] = false;
        }

        return self::$viewAvailable[$view];
    }
}
