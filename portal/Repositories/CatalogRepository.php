<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDO;
use PDOException;

/**
 * Repositorio de solo lectura del explorador de catálogos del portal.
 *
 * Las proyecciones SQL se derivan de api/services/TerminologySearchService.php
 * y de api/services/CatalogEngineService.php: no se inventan tablas ni
 * columnas. Todas las consultas son parametrizadas, los dominios y las tablas
 * pasan por whitelist y los errores de PDO se traducen a códigos seguros.
 */
final class CatalogRepository
{
    public const DOMAINS = [
        'snomed', 'cie10', 'anmat', 'laboratorio', 'vacunas', 'odontologia',
        'prestaciones', 'programas', 'imagenes', 'nomenclador', 'vademecum', 'loinc',
    ];

    public const DEFAULT_DOMAINS = ['snomed', 'cie10', 'anmat'];

    /** Catálogos DENTAR publicados que pueden usarse como filtro del explorador. */
    public const DENTAR_CATALOGS = ['dentar-pr', 'dentar-dx'];

    private const SNOMED_FSN = '900000000000003001';
    private const SNOMED_SYNONYM = '900000000000013009';
    private const MAX_OFFSET = 5000;

    /**
     * Mapeo del motor os_catalog a dominios ya aprobados por el portal.
     * No crea dominios nuevos: solo asocia domain_type existente con la
     * etiqueta de interfaz que ya figura en DOMAINS.
     *
     * @var array<string, list<string>>
     */
    private const OS_CATALOG_DOMAIN_TYPES = [
        'odontologia' => ['dental'],
        'laboratorio' => ['biochemical'],
        'prestaciones' => ['medical', 'mental_health'],
        'programas' => ['rehabilitation'],
        'vademecum' => ['pharma'],
    ];

    /** @var array<string, array{table: string, field: string}> */
    private const SOURCE_TABLE = [
        'snomed' => ['table' => 'snomed_descriptions', 'field' => 'term'],
        'cie10' => ['table' => 'cie10_descriptions', 'field' => 'descripcion'],
        'anmat' => ['table' => 'anmat_medicamentos', 'field' => 'nombre_comercial'],
        'loinc' => ['table' => 'loinc', 'field' => 'long_common_name'],
        'laboratorio' => ['table' => 'laboratorio_practicas', 'field' => 'nombre_prueba'],
        'vacunas' => ['table' => 'vacunas_catalogo', 'field' => 'nombre_comercial'],
        'odontologia' => ['table' => 'odontologia_prestaciones', 'field' => 'descripcion'],
        'prestaciones' => ['table' => 'prestaciones_medicas', 'field' => 'nombre'],
        'programas' => ['table' => 'programas_sociales', 'field' => 'nombre_programa'],
        'imagenes' => ['table' => 'imagenes_practicas', 'field' => 'nombre_estudio'],
        'nomenclador' => ['table' => 'nomencladores_argentina', 'field' => 'descripcion'],
        'vademecum' => ['table' => 'vademecum_comercial', 'field' => 'nombre_comercial'],
    ];

    /** Configuración copiada de TerminologySearchService::CATALOG_SOURCES. */
    private const CATALOG_SOURCES = [
        'laboratorio' => [
            'table' => 'laboratorio_practicas',
            'code' => 't.codigo_loinc',
            'term' => 't.nombre_prueba',
            'subtitle' => 't.unidad_medida',
            'kind' => 'lab_test',
            'filters' => ['t.nombre_prueba', 't.codigo_loinc', 't.unidad_medida'],
            'metadata' => ['loinc_code' => 't.codigo_loinc', 'unit' => 't.unidad_medida'],
        ],
        'vacunas' => [
            'table' => 'vacunas_catalogo',
            'code' => 't.codigo_vacuna_msal',
            'term' => 't.nombre_comercial',
            'subtitle' => 't.principio_activo',
            'kind' => 'vaccine',
            'filters' => ['t.nombre_comercial', 't.principio_activo', 't.codigo_vacuna_msal', 't.dosis_esquema'],
            'metadata' => [
                'msal_code' => 't.codigo_vacuna_msal',
                'active_ingredient' => 't.principio_activo',
                'schedule' => 't.dosis_esquema',
            ],
        ],
        'odontologia' => [
            'table' => 'odontologia_prestaciones',
            'code' => 't.codigo_nomenclador',
            'term' => 't.descripcion',
            'subtitle' => 't.capitulo',
            'kind' => 'dental_procedure',
            'filters' => ['t.descripcion', 't.codigo_nomenclador', 't.cdt_code', 'CAST(t.snomed_concept_id AS text)'],
            'metadata' => [
                'nomenclator_code' => 't.codigo_nomenclador',
                'cdt_code' => 't.cdt_code',
                'cdt_category' => 't.cdt_categoria',
                'cdt_category_name' => 't.cdt_categoria_es',
                'chapter' => 't.capitulo',
                'tooth_specification' => 't.requiere_pieza',
                'face_specification' => 't.face_specification',
                'pre_op_xray' => 't.requiere_rx_pre',
                'post_op_xray' => 't.requiere_rx_post',
                'dental_chart_required' => 't.ficha_odontologica',
                'periodontal_chart_required' => 't.ficha_periodontal',
                'material' => 't.material',
                'jaw' => 't.maxilar',
                'audit_rules' => 't.norma_particular',
            ],
        ],
        'prestaciones' => [
            'table' => 'prestaciones_medicas',
            'code' => 't.codigo_prestacion',
            'term' => 't.nombre',
            'subtitle' => 't.categoria',
            'kind' => 'medical_procedure',
            'filters' => ['t.nombre', 't.categoria', 't.codigo_prestacion'],
            'metadata' => ['procedure_code' => 't.codigo_prestacion', 'category' => 't.categoria'],
        ],
        'programas' => [
            'table' => 'programas_sociales',
            'code' => 't.codigo',
            'term' => 't.nombre_programa',
            'subtitle' => 'left(t.descripcion, 180)',
            'kind' => 'program',
            'filters' => ['t.nombre_programa', 't.codigo', 't.descripcion'],
            'metadata' => ['program_code' => 't.codigo', 'description' => 't.descripcion'],
        ],
        'imagenes' => [
            'table' => 'imagenes_practicas',
            'code' => 't.codigo_estudio',
            'term' => 't.nombre_estudio',
            'subtitle' => 't.modalidad_dicom',
            'kind' => 'imaging_procedure',
            'filters' => ['t.nombre_estudio', 't.modalidad_dicom', 't.codigo_estudio'],
            'metadata' => [
                'study_code' => 't.codigo_estudio',
                'dicom_modality' => 't.modalidad_dicom',
                'loinc_code' => 't.codigo_loinc',
                'requires_contrast' => 't.requiere_contraste',
            ],
        ],
        'nomenclador' => [
            'table' => 'nomencladores_argentina',
            'code' => 't.codigo',
            'term' => 't.descripcion',
            'subtitle' => "t.tipo_nomenclador || ' · ' || coalesce(t.capitulo, '')",
            'kind' => 'nomenclator_procedure',
            'filters' => ['t.descripcion', 't.codigo', 't.tipo_nomenclador', "coalesce(t.capitulo, '')", 'CAST(t.snomed_concept_id AS text)'],
            'metadata' => [
                'nomenclator_type' => 't.tipo_nomenclador',
                'procedure_code' => 't.codigo',
                'chapter' => 't.capitulo',
                'unit_type' => 't.unidad_tipo',
                'unit_value' => 'CAST(t.unidad_valor AS text)',
                'expenses_value' => 'CAST(t.gastos_valor AS text)',
                'loinc_code' => 't.codigo_loinc',
            ],
        ],
        'vademecum' => [
            'table' => 'vademecum_comercial',
            'code' => 't.numero_troquel',
            'term' => 't.nombre_comercial',
            'subtitle' => "t.monodroga || ' · ' || coalesce(t.presentacion, '')",
            'kind' => 'commercial_drug',
            'filters' => ['t.nombre_comercial', 't.monodroga', 't.numero_troquel', "coalesce(t.codigo_alfabeta, '')", "coalesce(t.codigo_kairos, '')", "coalesce(t.codigo_barras_gtin, '')", 'CAST(t.snomed_concept_id AS text)'],
            'metadata' => [
                'troquel_number' => 't.numero_troquel',
                'alfabeta_code' => 't.codigo_alfabeta',
                'kairos_code' => 't.codigo_kairos',
                'gtin_code' => 't.codigo_barras_gtin',
                'generic_name' => 't.monodroga',
                'commercial_name' => 't.nombre_comercial',
                'presentation' => 't.presentacion',
                'laboratory' => 't.laboratorio',
                'pharmacological_action' => 't.accion_farmacologica',
                'sale_type' => 't.tipo_venta',
                'anmat_certificate' => 't.anmat_certificado',
            ],
        ],
    ];

    /** Etiquetas de interfaz: no son terminología clínica. */
    private const DOMAIN_LABELS = [
        'snomed' => ['es' => 'SNOMED-CT', 'en' => 'SNOMED-CT', 'pt' => 'SNOMED-CT'],
        'cie10' => ['es' => 'CIE-10', 'en' => 'ICD-10', 'pt' => 'CID-10'],
        'anmat' => ['es' => 'ANMAT', 'en' => 'ANMAT', 'pt' => 'ANMAT'],
        'laboratorio' => ['es' => 'Laboratorio', 'en' => 'Laboratory', 'pt' => 'Laboratório'],
        'vacunas' => ['es' => 'Vacunas', 'en' => 'Vaccines', 'pt' => 'Vacinas'],
        'odontologia' => ['es' => 'Odontología', 'en' => 'Dentistry', 'pt' => 'Odontologia'],
        'prestaciones' => ['es' => 'Prestaciones médicas', 'en' => 'Medical procedures', 'pt' => 'Procedimentos médicos'],
        'programas' => ['es' => 'Programas sociales', 'en' => 'Social programs', 'pt' => 'Programas sociais'],
        'imagenes' => ['es' => 'Imágenes', 'en' => 'Imaging', 'pt' => 'Imagens'],
        'nomenclador' => ['es' => 'Nomencladores', 'en' => 'Nomenclators', 'pt' => 'Nomencladores'],
        'vademecum' => ['es' => 'Vademécum', 'en' => 'Drug catalog', 'pt' => 'Catálogo de medicamentos'],
        'loinc' => ['es' => 'LOINC', 'en' => 'LOINC', 'pt' => 'LOINC'],
    ];

    /** @var array<string, bool> */
    private static array $tableChecks = [];

    /** @var array<string, string>|null */
    private static ?array $primaryTags = null;

    public static function available(): bool
    {
        return PortalDatabase::available();
    }

    public static function isValidDomain(string $domain): bool
    {
        return in_array($domain, self::DOMAINS, true);
    }

    public static function isValidCatalog(string $catalog): bool
    {
        return in_array($catalog, self::DENTAR_CATALOGS, true);
    }

    /** Normaliza el parámetro opcional de catálogo DENTAR. */
    public static function normalizeCatalog(?string $catalog): ?string
    {
        $catalog = $catalog === null ? '' : strtolower(trim($catalog));

        return self::isValidCatalog($catalog) ? $catalog : null;
    }

    /**
     * @return list<array{code: string, label: string}>
     */
    public static function domains(string $locale = 'es-AR'): array
    {
        $group = str_starts_with($locale, 'pt') ? 'pt' : (str_starts_with($locale, 'es') ? 'es' : 'en');
        $domains = [];

        foreach (self::DOMAINS as $domain) {
            $domains[] = [
                'code' => $domain,
                'label' => self::DOMAIN_LABELS[$domain][$group],
            ];
        }

        return $domains;
    }

    /**
     * @return array{items: list<array<string, mixed>>, total: int, has_more: bool}
     *
     * @throws RepositoryException
     */
    public static function search(
        string $query,
        string $domain,
        string $requestedLanguage,
        int $limit,
        int $offset,
        ?string $catalog = null
    ): array {
        $pdo = PortalDatabase::connection();
        $term = self::normalizeTerm($query);
        $language = self::contentLanguage($pdo, $requestedLanguage);
        $domains = $domain === '' ? self::DEFAULT_DOMAINS : [$domain];
        $catalog = self::normalizeCatalog($catalog);
        if ($catalog !== null) {
            // El filtro DENTAR implica el dominio odontología aunque el usuario
            // no haya elegido explícitamente ese dominio en el formulario.
            $domains = ['odontologia'];
        }
        $offset = max(0, min(self::MAX_OFFSET, $offset));

        if ($term === '') {
            return ['items' => [], 'total' => 0, 'has_more' => false];
        }

        [$union, $parameters] = self::buildUnion(
            $pdo,
            $domains,
            $term,
            $language,
            false,
            null,
            $requestedLanguage,
            $catalog
        );
        if ($union === '') {
            return ['items' => [], 'total' => 0, 'has_more' => false];
        }

        $exactTotal = self::countRows($pdo, $union, $parameters);

        $sql = "SELECT * FROM (\n{$union}\n) AS candidates\n"
            . " ORDER BY score DESC, length(term) ASC, term ASC\n"
            . ' LIMIT :page_limit OFFSET :page_offset';
        $statement = self::prepare($sql, $parameters + [
            ':page_limit' => $limit + 1,
            ':page_offset' => $offset,
        ]);
        $rows = $statement->fetchAll();

        $hasMore = count($rows) > $limit;
        if ($hasMore) {
            array_pop($rows);
        }

        $items = self::hydrateAll($pdo, $rows, $requestedLanguage, $language);
        $total = $exactTotal >= 0
            ? $exactTotal
            : $offset + count($items) + ($hasMore ? 1 : 0);

        return [
            'items' => $items,
            'total' => $total,
            'has_more' => $hasMore,
        ];
    }

    /**
     * @return array<string, mixed>|null
     *
     * @throws RepositoryException
     */
    public static function find(
        string $resultKey,
        string $requestedLanguage,
        ?string $catalog = null
    ): ?array {
        if (preg_match('/^([a-z0-9_]+):([A-Za-z0-9_.:-]{1,100})$/', $resultKey, $matches) !== 1) {
            return null;
        }

        $domain = $matches[1];
        $key = $matches[2];

        if (!self::isValidDomain($domain)) {
            return null;
        }

        $pdo = PortalDatabase::connection();
        $language = self::contentLanguage($pdo, $requestedLanguage);
        [$sql, $parameters] = self::buildUnion(
            $pdo,
            [$domain],
            '',
            $language,
            true,
            $key,
            $requestedLanguage,
            self::normalizeCatalog($catalog)
        );

        if ($sql === '') {
            return null;
        }

        $statement = self::prepare(
            "SELECT * FROM (\n{$sql}\n) AS candidates ORDER BY term ASC LIMIT 1",
            $parameters
        );
        $row = $statement->fetch();

        if (!is_array($row)) {
            return null;
        }

        $items = self::hydrateAll($pdo, [$row], $requestedLanguage, $language);

        return $items[0] ?? null;
    }

    /**
     * @param list<string> $domains
     * @param array<string, string|int> $extra
     *
     * @return array{0: string, 1: array<string, string|int>}
     *
     * @throws RepositoryException
     */
    private static function buildUnion(
        PDO $pdo,
        array $domains,
        string $term,
        string $language,
        bool $byKey,
        ?string $key,
        string $requestedLanguage = '',
        ?string $catalog = null
    ): array {
        $branches = [];
        $parameters = [];
        $index = 0;
        $catalog = self::normalizeCatalog($catalog);

        foreach ($domains as $domain) {
            if (!self::isValidDomain($domain)) {
                continue;
            }

            // Los catálogos DENTAR viven en os_catalog con domain_type 'dental'.
            // Con filtro de producto solo se consulta esa rama y se excluyen las
            // tablas nativas de odontología para no mezclar fuentes.
            if ($catalog !== null && $domain !== 'odontologia') {
                continue;
            }

            $source = self::SOURCE_TABLE[$domain];
            $nativeExists = self::tableExists($pdo, $source['table']);
            $osTypes = self::OS_CATALOG_DOMAIN_TYPES[$domain] ?? [];
            $osExists = $osTypes !== [] && self::osCatalogTablesExist($pdo);

            if (!$nativeExists && !$osExists) {
                continue;
            }

            if ($nativeExists && $catalog === null) {
                $p = 'p' . $index++;
                [$sql, $params] = self::branch(
                    $p,
                    $domain,
                    $term,
                    $language,
                    $byKey,
                    $key
                );
                $branches[] = $sql;
                $parameters += $params;
            }

            if ($osExists) {
                $p = 'p' . $index++;
                [$sql, $params] = self::osCatalogBranch(
                    $p,
                    $domain,
                    $osTypes,
                    $term,
                    $language,
                    $requestedLanguage,
                    $byKey,
                    $key,
                    $catalog
                );
                $branches[] = $sql;
                $parameters += $params;
            }
        }

        return [implode("\nUNION ALL\n", $branches), $parameters];
    }

    /**
     * @return array{0: string, 1: array<string, string|int>}
     */
    private static function branch(
        string $p,
        string $domain,
        string $term,
        string $language,
        bool $byKey,
        ?string $key
    ): array {
        if ($domain === 'snomed') {
            return self::snomedBranch($p, $term, $language, $byKey, $key);
        }

        if ($domain === 'cie10') {
            return self::cie10Branch($p, $term, $language, $byKey, $key);
        }

        if ($domain === 'anmat') {
            return self::anmatBranch($p, $term, $byKey, $key);
        }

        if ($domain === 'loinc') {
            return self::loincBranch($p, $term, $byKey, $key);
        }

        return self::catalogBranch($p, $domain, $term, $language, $byKey, $key);
    }

    private static function osCatalogTablesExist(PDO $pdo): bool
    {
        foreach (['os_catalog', 'os_catalog_item', 'os_catalog_item_version', 'os_catalog_release', 'os_catalog_identifier', 'os_catalog_term'] as $table) {
            if (!self::tableExists($pdo, $table)) {
                return false;
            }
        }

        return true;
    }

    /**
     * Rama de búsqueda sobre el motor os_catalog. Consulta solo tablas os_*
     * reales y respeta los dominios ya aprobados mediante OS_CATALOG_DOMAIN_TYPES.
     *
     * @param list<string> $domainTypes
     *
     * @return array{0: string, 1: array<string, string|int>}
     */
    private static function osCatalogBranch(
        string $p,
        string $domain,
        array $domainTypes,
        string $term,
        string $language,
        string $requestedLanguage,
        bool $byKey,
        ?string $key,
        ?string $catalog = null
    ): array {
        $catalog = self::normalizeCatalog($catalog);
        $typeNames = [];
        $params = [
            ":{$p}_lang" => $language,
            ":{$p}_req_lang" => $requestedLanguage !== '' ? $requestedLanguage : $language,
        ];
        if ($catalog !== null) {
            $params[":{$p}_catalog"] = $catalog;
        }

        foreach ($domainTypes as $i => $type) {
            $name = ":{$p}_type{$i}";
            $typeNames[] = $name;
            $params[$name] = $type;
        }

        $score = $byKey
            ? 'CAST(1.0 AS float8)'
            : self::scoreSql([
                "lower(ver.preferred_term) = lower(:{$p}_exact)" => '1.0',
                "item.permanent_code ILIKE :{$p}_code_prefix" => '0.96',
                "coalesce(ident.value, '') ILIKE :{$p}_code_prefix" => '0.96',
                "ver.preferred_term ILIKE :{$p}_prefix" => '0.92',
                "ver.preferred_term ILIKE :{$p}_contains" => '0.78',
                "similarity(ver.preferred_term, :{$p}_sim)" => null,
            ], $p);

        $where = $byKey
            ? "(item.permanent_code = :{$p}_key"
                . " OR coalesce(ident.value, '') = :{$p}_key"
                . " OR replace(coalesce(ident.value, ''), '.', '') = :{$p}_key_clean"
                . " OR 'os_catalog:' || cat.code || ':' || CAST(item.id AS text) = :{$p}_key"
                . " OR '{$domain}:os_catalog:' || cat.code || ':' || CAST(item.id AS text) = :{$p}_full_key)"
            : "(ver.preferred_term ILIKE :{$p}_contains"
                . " OR item.permanent_code ILIKE :{$p}_contains"
                . " OR coalesce(ident.value, '') ILIKE :{$p}_contains"
                . " OR EXISTS (SELECT 1 FROM os_catalog_term ot"
                . " WHERE ot.item_version_id = ver.id AND ot.term ILIKE :{$p}_contains))";

        $metadata = "CAST(json_build_object("
            . "'os_catalog', TRUE, "
            . "'catalog_code', cat.code, "
            . "'catalog_name', cat.name, "
            . "'item_id', CAST(item.id AS text), "
            . "'release_id', CAST(rel.id AS text), "
            . "'primary_code', coalesce(ident.value, item.permanent_code)"
            . ") AS text) AS metadata";

        $sql = "SELECT '{$domain}' AS domain, 'os_catalog' AS source,\n"
            . " '{$domain}:os_catalog:' || cat.code || ':' || CAST(item.id AS text) AS result_key,\n"
            . " CAST(item.id AS text) AS source_id,\n"
            . " coalesce(ident.value, item.permanent_code) AS code,\n"
            . " ver.preferred_term AS term,\n"
            . " cat.short_name AS subtitle,\n"
            . " ver.language_code AS language,\n"
            . " 'os_catalog_item' AS kind, {$score} AS score,\n"
            . " {$metadata}\n"
            . " FROM os_catalog_item item\n"
            . " JOIN os_catalog cat ON cat.id = item.catalog_id\n"
            . " JOIN os_catalog_release rel ON rel.id = (\n"
            . "     SELECT r.id FROM os_catalog_release r\n"
            . "      WHERE r.catalog_id = cat.id AND r.status = 'published'\n"
            . "      ORDER BY r.valid_from DESC, r.id DESC LIMIT 1\n"
            . " )\n"
            . " JOIN os_catalog_item_version ver ON ver.id = (\n"
            . "     SELECT v.id FROM os_catalog_item_version v\n"
            . "      WHERE v.item_id = item.id AND v.release_id = rel.id\n"
            . "      ORDER BY (v.language_code = :{$p}_req_lang) DESC,"
            . " (v.language_code = :{$p}_lang) DESC, v.id DESC LIMIT 1\n"
            . " )\n"
            . " LEFT JOIN os_catalog_identifier ident ON ident.id = (\n"
            . "     SELECT i.id FROM os_catalog_identifier i\n"
            . "      WHERE i.item_id = item.id AND i.is_primary = TRUE\n"
            . "      ORDER BY i.id LIMIT 1\n"
            . " )\n"
            . " WHERE cat.is_active = TRUE AND item.status = 'active'\n"
            . "   AND cat.domain_type IN (" . implode(', ', $typeNames) . ")\n"
            . ($catalog !== null ? "   AND cat.code = :{$p}_catalog\n" : '')
            . "   AND {$where}";

        if ($byKey) {
            $params[":{$p}_key"] = (string) $key;
            $params[":{$p}_key_clean"] = str_replace(['.', ' ', '-'], '', (string) $key);
            $params[":{$p}_full_key"] = str_starts_with((string) $key, 'os_catalog:')
                ? $domain . ':' . $key
                : (string) $key;
        } else {
            $params += self::termParams($p, $term);
            $params[":{$p}_code_prefix"] = self::escapeLike($term) . '%';
        }

        return [$sql, $params];
    }

    /** @return array{0: string, 1: array<string, string|int>} */
    private static function snomedBranch(
        string $p,
        string $term,
        string $language,
        bool $byKey,
        ?string $key
    ): array {
        $kind = "CASE WHEN d.type_id = CAST(" . self::SNOMED_FSN . " AS bigint) THEN 'fsn'"
            . " WHEN d.type_id = CAST(" . self::SNOMED_SYNONYM . " AS bigint) THEN 'synonym'"
            . " ELSE 'other' END";
        $metadata = "CAST(json_build_object("
            . "'description_id', CAST(d.id AS text), "
            . "'concept_id', CAST(d.concept_id AS text), "
            . "'type_id', CAST(d.type_id AS text), "
            . "'term_type', {$kind}"
            . ") AS text) AS metadata";
        $score = $byKey
            ? 'CAST(1.0 AS float8)'
            : self::scoreSql([
                "lower(d.term) = lower(:{$p}_exact)" => '1.0',
                "d.term ILIKE :{$p}_prefix" => '0.90',
                "d.term ILIKE :{$p}_contains" => '0.75',
                "similarity(d.term, :{$p}_sim)" => null,
            ], $p);

        $where = $byKey
            ? 'CAST(d.id AS text) = :' . $p . '_key'
            : 'd.term ILIKE :' . $p . '_contains';

        $sql = "SELECT 'snomed' AS domain, 'snomed' AS source,\n"
            . " 'snomed:' || CAST(d.id AS text) AS result_key,\n"
            . " CAST(d.concept_id AS text) AS source_id,\n"
            . " CAST(d.concept_id AS text) AS code,\n"
            . " d.term AS term, NULL AS subtitle, d.language_code AS language,\n"
            . " {$kind} AS kind, {$score} AS score,\n"
            . " {$metadata}\n"
            . " FROM snomed_descriptions d\n"
            . " INNER JOIN snomed_concepts c ON c.id = d.concept_id\n"
            . " WHERE d.active = TRUE AND c.active = TRUE AND d.language_code = :{$p}_lang\n"
            . "   AND {$where}";

        $params = [":{$p}_lang" => $language];
        if ($byKey) {
            $params[":{$p}_key"] = (string) $key;
        } else {
            $params += self::termParams($p, $term);
        }

        return [$sql, $params];
    }

    /** @return array{0: string, 1: array<string, string|int>} */
    private static function cie10Branch(
        string $p,
        string $term,
        string $language,
        bool $byKey,
        ?string $key
    ): array {
        $code = strtoupper($term);
        $normalized = str_replace(['.', ' '], '', $code);
        $escaped = self::escapeLike($code);
        $escapedNormalized = self::escapeLike($normalized);
        $metadata = "CAST(json_build_object("
            . "'cie10_id', CAST(c.id AS text), "
            . "'code', c.codigo, "
            . "'type', c.tipo, "
            . "'language', d.language_code"
            . ") AS text) AS metadata";
        $score = $byKey
            ? 'CAST(1.0 AS float8)'
            : self::scoreSql([
                "upper(c.codigo) = upper(:{$p}_exact_code)" => '1.0',
                "c.codigo ILIKE :{$p}_code_prefix" => '0.96',
                "replace(upper(c.codigo), '.', '') ILIKE :{$p}_code_normalized" => '0.94',
                "lower(d.descripcion) = lower(:{$p}_exact)" => '1.0',
                "d.descripcion ILIKE :{$p}_prefix" => '0.90',
                "d.descripcion ILIKE :{$p}_contains" => '0.75',
                "similarity(d.descripcion, :{$p}_sim)" => null,
            ], $p);

        $where = $byKey
            ? 'CAST(c.id AS text) = :' . $p . '_key'
            : "(d.descripcion ILIKE :{$p}_contains"
                . " OR c.codigo ILIKE :{$p}_code_filter"
                . " OR replace(upper(c.codigo), '.', '') ILIKE :{$p}_code_norm_filter)";

        $sql = "SELECT 'cie10' AS domain, 'cie10' AS source,\n"
            . " 'cie10:' || CAST(c.id AS text) AS result_key,\n"
            . " CAST(c.id AS text) AS source_id,\n"
            . " c.codigo AS code, d.descripcion AS term, c.tipo AS subtitle,\n"
            . " d.language_code AS language,\n"
            . " CASE c.tipo WHEN 'procedimiento' THEN 'procedure' ELSE 'diagnosis' END AS kind,\n"
            . " {$score} AS score, {$metadata}\n"
            . " FROM cie10_descriptions d\n"
            . " INNER JOIN cie10_codes c ON c.id = d.cie10_id\n"
            . " WHERE d.language_code = :{$p}_lang AND {$where}";

        $params = [":{$p}_lang" => $language];
        if ($byKey) {
            $params[":{$p}_key"] = (string) $key;
        } else {
            $params += self::termParams($p, $term);
            $params[":{$p}_exact_code"] = $code;
            $params[":{$p}_code_prefix"] = $escaped . '%';
            $params[":{$p}_code_normalized"] = '%' . $escapedNormalized . '%';
            $params[":{$p}_code_filter"] = '%' . $escaped . '%';
            $params[":{$p}_code_norm_filter"] = '%' . $escapedNormalized . '%';
        }

        return [$sql, $params];
    }

    /** @return array{0: string, 1: array<string, string|int>} */
    private static function anmatBranch(
        string $p,
        string $term,
        bool $byKey,
        ?string $key
    ): array {
        $metadata = "CAST(json_build_object("
            . "'id', CAST(a.id AS text), "
            . "'certificate', a.certificado_number, "
            . "'generic_name', a.nombre_generico, "
            . "'laboratory', a.laboratorio, "
            . "'pharmaceutical_form', a.forma_farmaceutica, "
            . "'presentation', a.presentacion, "
            . "'snomed_concept_id', CAST(a.snomed_concept_id AS text)"
            . ") AS text) AS metadata";
        $score = $byKey
            ? 'CAST(1.0 AS float8)'
            : self::scoreSql([
                "lower(a.nombre_comercial) = lower(:{$p}_exact_c)" => '1.0',
                "a.nombre_comercial ILIKE :{$p}_prefix_c" => '0.92',
                "a.nombre_comercial ILIKE :{$p}_contains_c" => '0.78',
                "lower(a.nombre_generico) = lower(:{$p}_exact_g)" => '1.0',
                "a.nombre_generico ILIKE :{$p}_prefix_g" => '0.90',
                "a.nombre_generico ILIKE :{$p}_contains_g" => '0.76',
                "similarity(a.nombre_comercial, :{$p}_sim_c)" => null,
                "similarity(a.nombre_generico, :{$p}_sim_g)" => null,
            ], $p);

        $where = $byKey
            ? 'CAST(a.id AS text) = :' . $p . '_key'
            : "(a.nombre_comercial ILIKE :{$p}_filter_c OR a.nombre_generico ILIKE :{$p}_filter_g)";

        $sql = "SELECT 'anmat' AS domain, 'anmat' AS source,\n"
            . " 'anmat:' || CAST(a.id AS text) AS result_key,\n"
            . " CAST(a.id AS text) AS source_id,\n"
            . " a.certificado_number AS code, a.nombre_comercial AS term,\n"
            . " a.nombre_generico AS subtitle, 'es' AS language, 'medication' AS kind,\n"
            . " {$score} AS score, {$metadata}\n"
            . " FROM anmat_medicamentos a\n"
            . " WHERE {$where}";

        $params = [];
        if ($byKey) {
            $params[":{$p}_key"] = (string) $key;
        } else {
            $params += self::termParams($p, $term, ['_c', '_g']);
            $params[":{$p}_filter_c"] = '%' . self::escapeLike($term) . '%';
            $params[":{$p}_filter_g"] = '%' . self::escapeLike($term) . '%';
        }

        return [$sql, $params];
    }

    /** @return array{0: string, 1: array<string, string|int>} */
    private static function loincBranch(
        string $p,
        string $term,
        bool $byKey,
        ?string $key
    ): array {
        $termSql = "coalesce(nullif(t.long_common_name, ''), nullif(t.display_name, ''), nullif(t.consumer_name, ''), t.component)";
        $metadata = "CAST(json_build_object("
            . "'loinc_code', t.loinc, "
            . "'class_type', t.class_type, "
            . "'system_type', t.system_type, "
            . "'scale_type', t.scale_type, "
            . "'method_type', t.method_type, "
            . "'status', t.status, "
            . "'consumer_name', t.consumer_name, "
            . "'example_ucum_units', t.example_ucum_units"
            . ") AS text) AS metadata";
        $score = $byKey
            ? 'CAST(1.0 AS float8)'
            : self::scoreSql([
                "lower(t.loinc) = lower(:{$p}_exact)" => '1.0',
                "t.loinc ILIKE :{$p}_prefix" => '0.96',
                "lower(t.long_common_name) = lower(:{$p}_exact)" => '0.94',
                "t.long_common_name ILIKE :{$p}_prefix" => '0.90',
                "t.display_name ILIKE :{$p}_prefix" => '0.88',
                "t.component ILIKE :{$p}_prefix" => '0.86',
                "t.consumer_name ILIKE :{$p}_prefix" => '0.84',
                "t.long_common_name ILIKE :{$p}_contains" => '0.78',
                "t.display_name ILIKE :{$p}_contains" => '0.76',
                "t.consumer_name ILIKE :{$p}_contains" => '0.75',
                "t.component ILIKE :{$p}_contains" => '0.74',
                "similarity({$termSql}, :{$p}_sim)" => null,
            ], $p);

        $where = $byKey
            ? 't.loinc = :' . $p . '_key'
            : "(t.loinc ILIKE :{$p}_prefix"
                . " OR t.long_common_name ILIKE :{$p}_contains"
                . " OR t.display_name ILIKE :{$p}_contains"
                . " OR t.component ILIKE :{$p}_contains"
                . " OR t.shortname ILIKE :{$p}_contains"
                . " OR t.consumer_name ILIKE :{$p}_contains)";

        $sql = "SELECT 'loinc' AS domain, 'loinc' AS source,\n"
            . " 'loinc:' || t.loinc AS result_key,\n"
            . " t.loinc AS source_id, t.loinc AS code,\n"
            . " {$termSql} AS term, t.component AS subtitle,\n"
            . " 'es' AS language, 'loinc_observation' AS kind,\n"
            . " {$score} AS score, {$metadata}\n"
            . " FROM loinc t\n"
            . " WHERE {$where}";

        $params = [];
        if ($byKey) {
            $params[":{$p}_key"] = (string) $key;
        } else {
            $params += self::termParams($p, $term);
        }

        return [$sql, $params];
    }

    /** @return array{0: string, 1: array<string, string|int>} */
    private static function catalogBranch(
        string $p,
        string $domain,
        string $term,
        string $language,
        bool $byKey,
        ?string $key
    ): array {
        $config = self::CATALOG_SOURCES[$domain];
        $subtitle = $config['subtitle'] ?? 'NULL';
        $metadataPairs = [];

        foreach ($config['metadata'] as $name => $expression) {
            $metadataPairs[] = "'{$name}', {$expression}";
        }

        $metadataPairs[] = "'snomed_concept_id', CAST(t.snomed_concept_id AS text)";
        $metadataPairs[] = "'snomed_term', (SELECT sd.term FROM snomed_descriptions sd"
            . " WHERE sd.concept_id = t.snomed_concept_id AND sd.active = TRUE"
            . " AND sd.language_code = :{$p}_label_lang"
            . " ORDER BY (sd.type_id = CAST(:{$p}_label_syn AS bigint)) DESC,"
            . " length(sd.term) ASC, sd.term ASC LIMIT 1)";

        $score = $byKey ? 'CAST(1.0 AS float8)' : self::catalogScoreSql($config, $p);
        $where = $byKey
            ? 'CAST(t.id AS text) = :' . $p . '_key'
            : 't.activo = TRUE AND (' . implode(' OR ', array_map(
                static fn (string $column): string => $column . ' ILIKE :' . $p . '_contains',
                $config['filters']
            )) . ')';

        $sql = "SELECT '{$domain}' AS domain, '{$domain}' AS source,\n"
            . " '{$domain}:' || CAST(t.id AS text) AS result_key,\n"
            . " CAST(t.id AS text) AS source_id,\n"
            . " {$config['code']} AS code, {$config['term']} AS term,\n"
            . " {$subtitle} AS subtitle, 'es' AS language,\n"
            . " '{$config['kind']}' AS kind, {$score} AS score,\n"
            . " CAST(json_build_object(" . implode(', ', $metadataPairs) . ") AS text) AS metadata\n"
            . " FROM {$config['table']} t\n"
            . " WHERE {$where}";

        $params = [
            ":{$p}_label_lang" => $language,
            ":{$p}_label_syn" => self::SNOMED_SYNONYM,
        ];
        if ($byKey) {
            $params[":{$p}_key"] = (string) $key;
        } else {
            $params += self::termParams($p, $term);
            $params[":{$p}_code_prefix"] = self::escapeLike($term) . '%';
            if ($config['subtitle'] !== null) {
                $params[":{$p}_sub_contains"] = '%' . self::escapeLike($term) . '%';
            }
        }

        return [$sql, $params];
    }

    /** @param array<string, string|null> $cases */
    private static function scoreSql(array $cases, string $p): string
    {
        $parts = [];
        foreach ($cases as $condition => $weight) {
            $parts[] = $weight === null
                ? "CAST({$condition} AS float8)"
                : "CASE WHEN {$condition} THEN CAST({$weight} AS float8) ELSE CAST(0.0 AS float8) END";
        }

        return 'CAST(GREATEST(' . implode(', ', $parts) . ') AS float8)';
    }

    /** @param array{table: string, code: string, term: string, subtitle: string|null, metadata: array<string, string>} $config */
    private static function catalogScoreSql(array $config, string $p): string
    {
        $cases = [
            "lower({$config['term']}) = lower(:{$p}_exact)" => '1.0',
            "{$config['code']} ILIKE :{$p}_code_prefix" => '0.96',
            "{$config['term']} ILIKE :{$p}_prefix" => '0.92',
            "{$config['term']} ILIKE :{$p}_contains" => '0.78',
        ];
        if ($config['subtitle'] !== null) {
            $cases["{$config['subtitle']} ILIKE :{$p}_sub_contains"] = '0.70';
        }
        $cases["similarity({$config['term']}, :{$p}_sim)"] = null;

        return self::scoreSql($cases, $p);
    }

    /**
     * @param list<string> $suffixes
     *
     * @return array<string, string>
     */
    private static function termParams(string $p, string $term, array $suffixes = ['']): array
    {
        $escaped = self::escapeLike($term);
        $params = [];

        foreach ($suffixes as $suffix) {
            $params[":{$p}_exact{$suffix}"] = $term;
            $params[":{$p}_prefix{$suffix}"] = $escaped . '%';
            $params[":{$p}_contains{$suffix}"] = '%' . $escaped . '%';
            $params[":{$p}_sim{$suffix}"] = $term;
        }

        return $params;
    }

    /**
     * @param array<string, string|int> $parameters
     *
     * @throws RepositoryException
     */
    private static function prepare(string $sql, array $parameters): \PDOStatement
    {
        try {
            $statement = PortalDatabase::connection()->prepare($sql);
        } catch (PDOException) {
            throw new RepositoryException('error_query');
        }

        foreach ($parameters as $name => $value) {
            $statement->bindValue(
                $name,
                $value,
                is_int($value) ? PDO::PARAM_INT : PDO::PARAM_STR
            );
        }

        try {
            $statement->execute();
        } catch (PDOException) {
            throw new RepositoryException('error_query');
        }

        return $statement;
    }

    /**
     * @param array<string, string|int> $parameters
     *
     * @throws RepositoryException
     */
    private static function countRows(PDO $pdo, string $union, array $parameters): int
    {
        try {
            $statement = $pdo->prepare("SELECT count(*) FROM (\n{$union}\n) AS candidates");
            foreach ($parameters as $name => $value) {
                $statement->bindValue($name, $value, is_int($value) ? PDO::PARAM_INT : PDO::PARAM_STR);
            }
            $statement->execute();

            return (int) $statement->fetchColumn();
        } catch (PDOException) {
            return -1;
        }
    }

    private static function tableExists(PDO $pdo, string $table): bool
    {
        if (!preg_match('/^[a-z0-9_]+$/i', $table)) {
            return false;
        }

        if (array_key_exists($table, self::$tableChecks)) {
            return self::$tableChecks[$table];
        }

        try {
            $statement = $pdo->prepare('SELECT to_regclass(:name) IS NOT NULL');
            $statement->execute([':name' => 'public.' . $table]);
            $exists = (bool) $statement->fetchColumn();
        } catch (PDOException) {
            $exists = false;
        }

        return self::$tableChecks[$table] = $exists;
    }

    /**
     * Idioma de contenido: la etiqueta primaria de os_language (D-27).
     * Nunca se reescribe 'es' como 'es-AR'.
     */
    private static function contentLanguage(PDO $pdo, string $requested): string
    {
        $tags = self::primaryTags($pdo);
        $code = self::canonicalLanguageCode($requested);

        return $tags[$code] ?? 'es';
    }

    /** @return array<string, string> */
    private static function primaryTags(PDO $pdo): array
    {
        if (is_array(self::$primaryTags)) {
            return self::$primaryTags;
        }

        $tags = [
            'es-AR' => 'es',
            'en' => 'en',
            'pt-BR' => 'pt',
            'es' => 'es',
            'pt' => 'pt',
            'es-MX' => 'es',
        ];

        if (self::tableExists($pdo, 'os_language')) {
            try {
                $statement = $pdo->query('SELECT code, primary_tag FROM os_language');
                foreach ($statement->fetchAll() as $row) {
                    $code = (string) ($row['code'] ?? '');
                    $tag = (string) ($row['primary_tag'] ?? '');
                    if ($code !== '' && $tag !== '') {
                        $tags[$code] = $tag;
                    }
                }
            } catch (PDOException) {
                // Se conserva el mapa mínimo derivado de la siembra oficial.
            }
        }

        return self::$primaryTags = $tags;
    }

    private static function canonicalLanguageCode(string $requested): string
    {
        $code = strtolower(trim($requested));

        return match ($code) {
            'es', 'es-ar' => 'es-AR',
            'pt', 'pt-br' => 'pt-BR',
            default => 'en',
        };
    }

    private static function normalizeTerm(string $value): string
    {
        if (!mb_check_encoding($value, 'UTF-8')) {
            return '';
        }

        if (preg_match('/[\x00-\x1F\x7F]/', $value) === 1) {
            return '';
        }

        $term = trim((string) preg_replace('/\s+/u', ' ', $value));
        $length = mb_strlen($term, 'UTF-8');

        return $length >= 2 && $length <= 80 ? $term : '';
    }

    private static function escapeLike(string $value): string
    {
        return str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $value);
    }

    /**
     * @param list<array<string, mixed>> $rows
     *
     * @return list<array<string, mixed>>
     *
     * @throws RepositoryException
     */
    private static function hydrateAll(
        PDO $pdo,
        array $rows,
        string $requestedLanguage,
        string $contentLanguage
    ): array {
        $osVariants = self::loadOsCatalogVariants($pdo, $rows);
        $reviews = self::loadReviews($pdo, $rows, $osVariants);
        $languageChain = self::languageChain($pdo, $requestedLanguage, $contentLanguage);
        $items = [];

        foreach ($rows as $row) {
            $metadata = self::decodeMetadata($row['metadata'] ?? null);
            $isOsCatalog = !empty($metadata['os_catalog']);
            $itemId = (int) ($metadata['item_id'] ?? 0);
            $editorial = $isOsCatalog
                ? self::editorialOsCatalog(
                    $row,
                    $metadata,
                    $osVariants[$itemId] ?? ['versions' => [], 'terms' => []],
                    $reviews,
                    $languageChain,
                    $requestedLanguage
                )
                : self::editorial(
                    $row,
                    $metadata,
                    $reviews,
                    $languageChain,
                    $requestedLanguage
                );
            $item = [
                'id' => (string) ($row['result_key'] ?? ''),
                'source_id' => (string) ($row['source_id'] ?? ''),
                'code' => $row['code'] !== null ? (string) $row['code'] : null,
                'term' => $row['term'] !== null ? (string) $row['term'] : null,
                'subtitle' => $row['subtitle'] !== null ? (string) $row['subtitle'] : null,
                'domain' => (string) ($row['domain'] ?? ''),
                'kind' => (string) ($row['kind'] ?? ''),
                'score' => round((float) ($row['score'] ?? 0), 4),
                'description' => $editorial['description'] ?? self::description($metadata),
                'concept_id' => isset($metadata['concept_id']) ? (string) $metadata['concept_id'] : null,
                'catalog_code' => isset($metadata['catalog_code']) ? (string) $metadata['catalog_code'] : null,
            ] + $editorial;

            $items[] = $item;
        }

        return $items;
    }

    /** @return array<string, mixed> */
    private static function decodeMetadata(mixed $raw): array
    {
        if (!is_string($raw) || $raw === '') {
            return [];
        }

        $decoded = json_decode($raw, true);

        return is_array($decoded) ? $decoded : [];
    }

    /** @param array<string, mixed> $metadata */
    private static function description(array $metadata): ?string
    {
        foreach (['description', 'snomed_term', 'generic_name', 'active_ingredient', 'chapter', 'subtitle'] as $key) {
            $value = $metadata[$key] ?? null;
            if (is_string($value) && $value !== '') {
                return $value;
            }
        }

        return null;
    }

    /**
     * Carga todas las versiones y términos de los ítems os_catalog presentes en
     * la página. Así la evaluación editorial puede elegir un texto aprobado en
     * cualquier idioma declarado, sin asumir que la fila de búsqueda ya es la
     * versión aprobada (D-30).
     *
     * @param list<array<string, mixed>> $rows
     *
     * @return array<int, array{versions: list<array<string, mixed>>, terms: list<array<string, mixed>>}>
     *
     * @throws RepositoryException
     */
    private static function loadOsCatalogVariants(PDO $pdo, array $rows): array
    {
        $itemIds = [];
        foreach ($rows as $row) {
            $metadata = self::decodeMetadata($row['metadata'] ?? null);
            if (!empty($metadata['os_catalog']) && ctype_digit((string) ($metadata['item_id'] ?? ''))) {
                $itemIds[(int) $metadata['item_id']] = true;
            }
        }

        if ($itemIds === []) {
            return [];
        }

        $ids = array_keys($itemIds);
        $placeholders = implode(', ', array_fill(0, count($ids), '?'));
        $variants = [];

        foreach ($ids as $id) {
            $variants[$id] = ['versions' => [], 'terms' => []];
        }

        try {
            $versionSql = 'SELECT id, item_id, release_id, language_code, source_language_code,'
                . ' provenance, review_status, content_hash, preferred_term, definition,'
                . ' clinical_criteria, short_definition, lay_terms, clinical_scope'
                . ' FROM os_catalog_item_version'
                . ' WHERE item_id IN (' . $placeholders . ') ORDER BY item_id, id';
            $statement = $pdo->prepare($versionSql);
            $statement->execute($ids);
            foreach ($statement->fetchAll() as $row) {
                $itemId = (int) $row['item_id'];
                if (isset($variants[$itemId])) {
                    $variants[$itemId]['versions'][] = $row;
                }
            }

            $termSql = 'SELECT id, item_version_id, term, term_type, language_code,'
                . ' source_language_code, provenance, review_status, content_hash'
                . ' FROM os_catalog_term'
                . ' WHERE item_version_id IN ('
                . ' SELECT id FROM os_catalog_item_version WHERE item_id IN (' . $placeholders . ')'
                . ') ORDER BY item_version_id, id';
            $statement = $pdo->prepare($termSql);
            $statement->execute($ids);
            foreach ($statement->fetchAll() as $row) {
                foreach ($variants as $itemId => &$bucket) {
                    foreach ($bucket['versions'] as $version) {
                        if ((int) $version['id'] === (int) $row['item_version_id']) {
                            $row['release_id'] = $version['release_id'];
                            $bucket['terms'][] = $row;
                            break 2;
                        }
                    }
                }
                unset($bucket);
            }
        } catch (PDOException) {
            throw new RepositoryException('error_query');
        }

        return $variants;
    }

    /**
     * @param list<array<string, mixed>> $rows
     * @param array<int, array{versions: list<array<string, mixed>>, terms: list<array<string, mixed>>}> $osVariants
     *
     * @return array<string, array<string, list<array<string, mixed>>>>
     *
     * @throws RepositoryException
     */
    private static function loadReviews(PDO $pdo, array $rows, array $osVariants = []): array
    {
        if ($rows === [] || !self::tableExists($pdo, 'os_field_review')) {
            return [];
        }

        $targetTables = [];
        $targetIds = [];
        $fieldNames = [];

        foreach ($rows as $row) {
            $metadata = self::decodeMetadata($row['metadata'] ?? null);
            if (!empty($metadata['os_catalog']) && ctype_digit((string) ($metadata['item_id'] ?? ''))) {
                $itemId = (int) $metadata['item_id'];
                foreach ($osVariants[$itemId]['versions'] ?? [] as $variant) {
                    $targetTables['os_catalog_item_version'] = true;
                    $targetIds[(int) $variant['id']] = true;
                    $fieldNames['preferred_term'] = true;
                    $fieldNames['definition'] = true;
                    $fieldNames['clinical_criteria'] = true;
                    $fieldNames['short_definition'] = true;
                    $fieldNames['lay_terms'] = true;
                    $fieldNames['clinical_scope'] = true;
                }
                foreach ($osVariants[$itemId]['terms'] ?? [] as $variant) {
                    $targetTables['os_catalog_term'] = true;
                    $targetIds[(int) $variant['id']] = true;
                    $fieldNames['term'] = true;
                }
                continue;
            }

            $domain = (string) ($row['domain'] ?? '');
            $source = self::SOURCE_TABLE[$domain] ?? null;
            if ($source === null || !ctype_digit((string) ($row['source_id'] ?? ''))) {
                continue;
            }
            $targetTables[$source['table']] = true;
            $targetIds[(int) $row['source_id']] = true;
            $fieldNames[$source['field']] = true;
        }

        if ($targetTables === [] || $targetIds === [] || $fieldNames === []) {
            return [];
        }

        $tables = array_keys($targetTables);
        $ids = array_keys($targetIds);
        $fields = array_keys($fieldNames);
        $sql = 'SELECT target_table, target_id, field_name, language_code, scope_release_id,'
            . ' source_language_code, provenance, review_status, content_hash, source_reference'
            . ' FROM os_field_review'
            . ' WHERE target_table IN (' . implode(', ', array_fill(0, count($tables), '?')) . ')'
            . ' AND target_id IN (' . implode(', ', array_fill(0, count($ids), '?')) . ')'
            . ' AND field_name IN (' . implode(', ', array_fill(0, count($fields), '?')) . ')';

        try {
            $statement = $pdo->prepare($sql);
            $statement->execute(array_merge($tables, $ids, $fields));
            $reviews = $statement->fetchAll();
        } catch (PDOException) {
            throw new RepositoryException('error_query');
        }

        $indexed = [];
        foreach ($reviews as $review) {
            $key = (string) $review['target_table'] . '|' . (int) $review['target_id'] . '|' . (string) $review['field_name'];
            $indexed[$key][] = $review;
        }

        return $indexed;
    }

    /**
     * @return list<array{code: string, reason: ?string}>
     */
    private static function languageChain(PDO $pdo, string $requested, string $content): array
    {
        $tags = self::primaryTags($pdo);
        $chain = [];

        $add = static function (?string $code, ?string $reason) use (&$chain, $tags): void {
            if ($code === null || $code === '') {
                return;
            }
            foreach ($chain as $entry) {
                if ($entry['code'] === $code) {
                    return;
                }
            }
            $chain[] = ['code' => $code, 'reason' => $reason, 'primary' => $tags[$code] ?? strtolower($code)];
        };

        $requestedCode = self::canonicalLanguageCode($requested);
        $add($requestedCode, null);
        $add($content === 'es' ? 'es' : $content, $content !== $requestedCode ? 'primary_tag' : null);
        $add('es-AR', 'global_default');

        return $chain;
    }

    /**
     * @param array<string, list<array<string, mixed>>> $reviews
     * @param list<array{code: string, reason: ?string, primary: string}> $chain
     *
     * @return array<string, mixed>
     */
    private static function editorial(
        array $row,
        array $metadata,
        array $reviews,
        array $chain,
        string $requested
    ): array {
        $domain = (string) ($row['domain'] ?? '');
        $source = self::SOURCE_TABLE[$domain] ?? null;
        $term = $row['term'] !== null ? (string) $row['term'] : '';
        $rowLanguage = (string) ($row['language'] ?? 'es');
        $tags = self::primaryTags(PortalDatabase::connection());
        $requestedCode = self::canonicalLanguageCode($requested);
        $requestedPrimary = $tags[$requestedCode] ?? 'es';
        $rowPrimary = $tags[$rowLanguage] ?? strtolower($rowLanguage);

        $base = [
            'language' => $rowLanguage,
            'effective_language' => $rowLanguage,
            'source_language' => null,
            'provenance' => 'official_source',
            'approval_state' => null,
            'untranslated' => $rowPrimary !== $requestedPrimary,
            'fallback_applied' => false,
            'fallback_reason' => null,
            'dialect_determined' => str_contains($rowLanguage, '-') && $rowLanguage === $requestedCode,
        ];

        if ($source === null || !ctype_digit((string) ($row['source_id'] ?? ''))) {
            return $base;
        }

        $key = $source['table'] . '|' . (int) $row['source_id'] . '|' . $source['field'];
        $candidates = $reviews[$key] ?? [];
        $selected = null;
        $selectedPosition = PHP_INT_MAX;

        foreach ($chain as $position => $candidate) {
            foreach ($candidates as $review) {
                if (strtolower((string) $review['language_code']) !== strtolower($candidate['code'])) {
                    continue;
                }
                if ((string) $review['review_status'] !== 'approved') {
                    continue;
                }
                $hash = self::contentHash(
                    $term,
                    $candidate['code'],
                    isset($review['source_reference']) && $review['source_reference'] !== null
                        ? (string) $review['source_reference']
                        : null
                );
                $stored = (string) ($review['content_hash'] ?? '');
                if ($stored !== '' && $stored !== $hash) {
                    continue;
                }
                if ($position < $selectedPosition) {
                    $selected = $review;
                    $selectedPosition = $position;
                }
            }
        }

        if ($selected === null) {
            if ($base['untranslated']) {
                $base['term'] = null;
            }

            if ($rowPrimary === 'es' && $requestedPrimary === 'es' && $rowLanguage === 'es' && $requestedCode === 'es-AR') {
                $base['fallback_reason'] = 'rf2_dialect_undetermined';
            }

            return $base;
        }

        $language = (string) $selected['language_code'];
        $sameText = strtolower($language) === strtolower($rowLanguage);
        $provenance = (string) ($selected['provenance'] ?? 'unknown');

        return [
            'language' => $rowLanguage,
            'effective_language' => $language,
            'source_language' => $selected['source_language_code'] ?? null,
            'provenance' => in_array($provenance, [
                'unknown', 'official_source', 'official_translation', 'origen_salud', 'community', 'machine',
            ], true) ? $provenance : 'unknown',
            'approval_state' => 'approved',
            'untranslated' => !$sameText,
            'term' => $sameText ? $term : null,
            'fallback_applied' => $selectedPosition > 0,
            'fallback_reason' => $chain[$selectedPosition]['reason'] ?? null,
            'dialect_determined' => str_contains($language, '-') && $language === $requestedCode,
        ];
    }

    /**
     * Evaluación editorial específica del motor os_catalog (D-30).
     *
     * Selecciona el primer texto aprobado de la cadena de idiomas, validando
     * `os_field_review` vigente, ámbito de release y hash. No publica la columna
     * original cuando no hay revisión aprobada (D-20).
     *
     * @param array<string, mixed> $metadata
     * @param array{versions: list<array<string, mixed>>, terms: list<array<string, mixed>>} $variants
     * @param array<string, array<string, list<array<string, mixed>>>> $reviews
     * @param list<array{code: string, reason: ?string, primary: string}> $chain
     *
     * @return array<string, mixed>
     */
    private static function editorialOsCatalog(
        array $row,
        array $metadata,
        array $variants,
        array $reviews,
        array $chain,
        string $requested
    ): array {
        $rowLanguage = (string) ($row['language'] ?? 'es');
        $tags = self::primaryTags(PortalDatabase::connection());
        $requestedCode = self::canonicalLanguageCode($requested);
        $requestedPrimary = $tags[$requestedCode] ?? 'es';
        $rowPrimary = $tags[$rowLanguage] ?? strtolower($rowLanguage);
        $description = self::description($metadata);

        $base = [
            'language' => $rowLanguage,
            'effective_language' => $rowLanguage,
            'source_language' => null,
            'provenance' => 'official_source',
            'approval_state' => null,
            'untranslated' => $rowPrimary !== $requestedPrimary,
            'description' => $description,
            'fallback_applied' => false,
            'fallback_reason' => null,
            'dialect_determined' => str_contains($rowLanguage, '-') && $rowLanguage === $requestedCode,
        ];

        $candidates = [];

        foreach ($variants['versions'] as $variant) {
            $value = (string) ($variant['preferred_term'] ?? '');
            if ($value === '') {
                continue;
            }
            $candidates[] = [
                'table' => 'os_catalog_item_version',
                'id' => (int) $variant['id'],
                'field' => 'preferred_term',
                'value' => $value,
                'language' => (string) ($variant['language_code'] ?? 'es'),
                'source_language' => $variant['source_language_code'] ?? null,
                'provenance' => (string) ($variant['provenance'] ?? 'unknown'),
                'review_status' => (string) ($variant['review_status'] ?? 'unknown'),
                'content_hash' => (string) ($variant['content_hash'] ?? ''),
                'release_id' => (int) ($variant['release_id'] ?? 0),
                'description' => self::firstText([
                    $variant['definition'] ?? null,
                    $variant['clinical_criteria'] ?? null,
                    $variant['short_definition'] ?? null,
                    $variant['lay_terms'] ?? null,
                    $variant['clinical_scope'] ?? null,
                ]),
            ];
        }

        foreach ($variants['terms'] as $variant) {
            $value = (string) ($variant['term'] ?? '');
            if ($value === '') {
                continue;
            }
            $candidates[] = [
                'table' => 'os_catalog_term',
                'id' => (int) $variant['id'],
                'field' => 'term',
                'value' => $value,
                'language' => (string) ($variant['language_code'] ?? 'es'),
                'source_language' => $variant['source_language_code'] ?? null,
                'provenance' => (string) ($variant['provenance'] ?? 'unknown'),
                'review_status' => (string) ($variant['review_status'] ?? 'unknown'),
                'content_hash' => (string) ($variant['content_hash'] ?? ''),
                'release_id' => (int) ($variant['release_id'] ?? 0),
                'description' => null,
            ];
        }

        if ($candidates === []) {
            if ($base['untranslated']) {
                $base['term'] = null;
                $base['fallback_reason'] = 'no_approved_content';
            }

            return $base;
        }

        $searchOrder = [];
        foreach ($chain as $position => $entry) {
            $searchOrder[] = ['code' => $entry['code'], 'reason' => $entry['reason'], 'position' => $position];
        }
        foreach ($candidates as $candidate) {
            if ($candidate['source_language'] === null || $candidate['source_language'] === '') {
                continue;
            }
            $source = (string) $candidate['source_language'];
            foreach ($searchOrder as $entry) {
                if (strtolower($entry['code']) === strtolower($source)) {
                    continue 2;
                }
            }
            $searchOrder[] = [
                'code' => $source,
                'reason' => 'source_language',
                'position' => count($searchOrder),
            ];
        }

        $selected = null;
        $selectedPosition = PHP_INT_MAX;
        $selectedReason = null;

        foreach ($searchOrder as $want) {
            foreach ($candidates as $candidate) {
                if (strtolower($candidate['language']) !== strtolower($want['code'])) {
                    continue;
                }
                if ($candidate['review_status'] !== 'approved') {
                    continue;
                }
                $key = $candidate['table'] . '|' . $candidate['id'] . '|' . $candidate['field'];
                foreach ($reviews[$key] ?? [] as $review) {
                    if ((string) $review['review_status'] !== 'approved') {
                        continue;
                    }
                    $scope = $review['scope_release_id'] ?? null;
                    if ($scope !== null && (int) $scope !== $candidate['release_id']) {
                        continue;
                    }
                    $language = (string) $review['language_code'];
                    $sourceReference = $review['source_reference'] ?? null;
                    $hash = self::contentHash(
                        $candidate['value'],
                        $language,
                        $sourceReference !== null ? (string) $sourceReference : null
                    );
                    if ((string) ($review['content_hash'] ?? '') !== $hash) {
                        continue;
                    }
                    if ($want['position'] < $selectedPosition) {
                        $selectedPosition = $want['position'];
                        $selectedReason = $want['reason'];
                        $selected = [
                            'value' => $candidate['value'],
                            'language' => $language,
                            'source_language' => $review['source_language_code'] ?? $candidate['source_language'],
                            'provenance' => (string) ($review['provenance'] ?? $candidate['provenance']),
                            'description' => $candidate['description'],
                        ];
                    }
                }
            }
        }

        if ($selected === null) {
            if ($base['untranslated']) {
                $base['term'] = null;
                $base['fallback_reason'] = 'no_approved_content';
            }

            return $base;
        }

        $language = (string) $selected['language'];
        $effectivePrimary = $tags[$language] ?? strtolower($language);
        $provenance = (string) $selected['provenance'];

        return [
            'language' => $rowLanguage,
            'effective_language' => $language,
            'source_language' => $selected['source_language'] !== null
                ? (string) $selected['source_language']
                : null,
            'provenance' => in_array($provenance, [
                'unknown', 'official_source', 'official_translation', 'origen_salud', 'community', 'machine',
            ], true) ? $provenance : 'unknown',
            'approval_state' => 'approved',
            'untranslated' => $effectivePrimary !== $requestedPrimary,
            'term' => $selected['value'],
            'description' => $selected['description'] !== null && $selected['description'] !== ''
                ? $selected['description']
                : $description,
            'fallback_applied' => $selectedPosition > 0,
            'fallback_reason' => $selectedReason,
            'dialect_determined' => str_contains($language, '-') && $language === $requestedCode,
        ];
    }

    /** @param list<mixed> $values */
    private static function firstText(array $values): ?string
    {
        foreach ($values as $value) {
            if (is_string($value) && $value !== '') {
                return $value;
            }
        }

        return null;
    }

    private static function contentHash(string $value, string $language, ?string $sourceReference = null): string
    {
        return md5($value . "\x1f" . $language . "\x1f" . ($sourceReference ?? ''));
    }
}
