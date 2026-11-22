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

    /**
     * Catálogos de diagnóstico: no reciben UVR por existir (acta U7.7).
     * Se bloquea también en lectura para que un código CIE-10 no active la
     * valoración publicada de una prestación de otro catálogo.
     *
     * @var list<string>
     */
    private const DIAGNOSIS_CATALOGS = ['dentar-dx', 'oftar-dx'];

    /** @var array<string, bool> */
    private static array $viewAvailable = [];

    /**
     * @return list<array<string, mixed>>
     */
    public static function publishedForItem(
        int $itemId,
        string $catalogCode,
        ?string $externalCode = null,
        array $alternateCodes = []
    ): array {
        $catalog = trim($catalogCode);

        if (in_array($catalog, self::DIAGNOSIS_CATALOGS, true)) {
            return [];
        }

        // Un código puede estar publicado en otro catálogo: el ítem del
        // Nomenclador tiene 01.01 pero su identificador DENTAR-PR apunta a
        // DNT-PR-000001, que es el código con valoración publicada.
        $codes = [];
        foreach (array_merge([$externalCode], $alternateCodes) as $candidate) {
            $code = trim((string) ($candidate ?? ''));
            if ($code !== '' && !in_array($code, $codes, true)) {
                $codes[] = $code;
            }
        }

        if ($itemId <= 0 && $codes === []) {
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
        $codeParams = [];
        foreach ($codes as $index => $code) {
            $placeholder = $index === 0 ? ':external' : ':alternate' . $index;
            $codeParams[$code] = $placeholder;
            $params[$placeholder] = $code;
        }

        if ($catalog !== '') {
            // El mismo código permanente puede estar publicado en más de un
            // catálogo. Si Browse abrió un ítem de otro catálogo con un
            // identificador equivalente, la UVR debe seguir siendo visible.
            // dentar-dx y oftar-dx quedan excluidos por diseño: son
            // diagnósticos y no deben tomar UVR de otra prestación.
            if ($codeParams !== []) {
                $catalogParts = ['catalog_code = :catalog'];
                foreach ($codeParams as $placeholder) {
                    $catalogParts[] = '(btrim(external_code) = ' . $placeholder
                        . ' AND catalog_code <> :excluded'
                        . ' AND catalog_code <> :excluded_oftar)';
                }
                $conditions[] = '(' . implode(' OR ', $catalogParts) . ')';
                $params[':excluded'] = 'dentar-dx';
                $params[':excluded_oftar'] = 'oftar-dx';
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
        foreach ($codeParams as $placeholder) {
            $references[] = 'btrim(external_code) = ' . $placeholder;
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
