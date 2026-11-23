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
        'oftar',
    ];

    public const DEFAULT_DOMAINS = ['snomed', 'cie10', 'anmat'];

    /**
     * Catálogos DENTAR publicados que pueden usarse como filtro del explorador.
     * `nomenclador-odontologico-ar` conserva la numeración histórica que hoy
     * usan los odontólogos; sus ítems se vinculan con DENTAR-PR por referencia
     * literal, no por equivalencia clínica asumida.
     */
    public const DENTAR_CATALOGS = ['dentar-pr', 'dentar-dx', 'nomenclador-odontologico-ar'];

    /**
     * Familia OFTAR: un único dominio (`oftar`) para los dos productos propios
     * y sus dos nomencladores de origen (CAO y referencia regional).
     * `oftar-dx` y los catálogos de origen quedan fuera de UVR; `oftar-pr` es
     * el único valorable.
     */
    public const OFTAR_CATALOGS = [
        'oftar-pr', 'oftar-dx',
        'nomenclador-oftalmologico-cao-ar', 'nomenclador-oftalmologico-regional-ar',
    ];

    /** Whitelist completa de catálogos publicados que acepta el explorador. */
    public const PUBLISHED_CATALOGS = [
        'dentar-pr', 'dentar-dx', 'nomenclador-odontologico-ar',
        'oftar-pr', 'oftar-dx',
        'nomenclador-oftalmologico-cao-ar', 'nomenclador-oftalmologico-regional-ar',
    ];

    private const SNOMED_FSN = '900000000000003001';
    private const SNOMED_SYNONYM = '900000000000013009';
    private const MAX_OFFSET = 5000;

    /**
     * Las secciones Relaciones y Valores consultan os_concept_mapping,
     * os_terminology_system, os_fee_* y os_pricing_unit únicamente con SELECT.
     * Autorizado por el usuario; los métodos comprueban que las tablas
     * existan y capturan PDOException, por lo que sin GRANT devuelven [] sin
     * exponer errores de base de datos.
     */
    private const ALLOW_RESTRICTED_SELECTS = true;

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
        // Los catálogos OFTAR también son `medical`; el ámbito se restringe
        // además por family_code = 'oftar' en osCatalogBranch().
        'oftar' => ['medical'],
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
        'oftar' => ['es' => 'OFTAR', 'en' => 'OFTAR', 'pt' => 'OFTAR'],
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
        return in_array($catalog, self::PUBLISHED_CATALOGS, true);
    }

    /** Normaliza el parámetro opcional de catálogo publicado. */
    public static function normalizeCatalog(?string $catalog): ?string
    {
        return self::normalizeCatalogs($catalog)[0] ?? null;
    }

    /**
     * Acepta uno o varios catálogos en un único parámetro CSV y devuelve una
     * lista canónica (sin duplicados y ordenada). Nunca interpolated valores
     * del request en SQL: solo pasan los códigos de la whitelist.
     *
     * @return list<string>
     */
    public static function normalizeCatalogs(?string $catalog): array
    {
        if ($catalog === null || trim($catalog) === '') {
            return [];
        }

        $values = [];
        foreach (explode(',', $catalog) as $candidate) {
            $code = strtolower(trim($candidate));
            if (self::isValidCatalog($code)) {
                $values[$code] = true;
            }
        }

        $values = array_keys($values);
        sort($values, SORT_STRING);

        return array_slice($values, 0, count(self::PUBLISHED_CATALOGS));
    }

    /**
     * Igual que normalizeCatalogs(), pero para dominios. Permite que el browser
     * combine SNOMED, CIE-10, LOINC, etc. en un único parámetro CSV.
     *
     * @return list<string>
     */
    public static function normalizeDomains(?string $domain): array
    {
        if ($domain === null || trim($domain) === '') {
            return [];
        }

        $values = [];
        foreach (explode(',', $domain) as $candidate) {
            $code = strtolower(trim($candidate));
            if (self::isValidDomain($code)) {
                $values[$code] = true;
            }
        }

        $values = array_keys($values);
        sort($values, SORT_STRING);

        return array_slice($values, 0, count(self::DOMAINS));
    }

    /**
     * Filtros estructurados. Los valores se validan contra whitelists o formatos
     * estrictos; la UI obtiene las opciones reales desde catalogFacets().
     *
     * @param array<string, mixed> $filters
     *
     * @return array<string, string>
     */
    public static function normalizeFilters(array $filters): array
    {
        $normalized = [];
        $allowed = [
            'family' => '/^[A-Za-z0-9_-]{1,50}$/',
            'type' => '/^[a-z_]{1,30}$/',
            'category' => '/^[A-Za-z0-9_.-]{1,50}$/',
            'version' => '/^[A-Za-z0-9_.-]{1,50}$/',
        ];

        foreach ($allowed as $key => $pattern) {
            $value = isset($filters[$key]) && is_scalar($filters[$key])
                ? trim((string) $filters[$key])
                : '';
            if ($value !== '' && preg_match($pattern, $value) === 1) {
                $normalized[$key] = $value;
            }
        }

        if (isset($filters['status']) && is_string($filters['status'])
            && self::isValidItemStatus($filters['status'])) {
            $normalized['status'] = $filters['status'];
        }

        if (isset($filters['validity']) && is_string($filters['validity'])
            && in_array($filters['validity'], ['all', 'current'], true)
            && $filters['validity'] !== 'all') {
            $normalized['validity'] = 'current';
        }

        return $normalized;
    }

    /** Estado de ítem permitido por el CHECK de os_catalog_item. */
    private static function isValidItemStatus(string $status): bool
    {
        return in_array($status, ['active', 'retired', 'superseded'], true);
    }

    /**
     * Opciones reales para los filtros, leídas de os_catalog. No inventa
     * valores: si no hay filas, la interfaz no muestra el filtro.
     *
     * @return array{families: list<array{code: string, label: string}>, types: list<array{code: string, label: string}>, categories: list<array{code: string, label: string}>, versions: list<array{code: string, label: string}>, statuses: list<array{code: string, label: string}>}
     */
    public static function catalogFacets(): array
    {
        $empty = ['families' => [], 'types' => [], 'categories' => [], 'versions' => [], 'statuses' => []];
        if (!self::available()) {
            return $empty;
        }

        $pdo = PortalDatabase::connection();
        $tables = ['os_catalog', 'os_catalog_release', 'os_catalog_category', 'os_catalog_item'];
        foreach ($tables as $table) {
            if (!self::tableExists($pdo, $table)) {
                return $empty;
            }
        }

        try {
            $rows = $pdo->query(
                'SELECT DISTINCT family_code FROM os_catalog'
                . ' WHERE is_active = TRUE AND family_code IS NOT NULL'
                . ' ORDER BY family_code ASC'
            )->fetchAll();
            $domainTypes = $pdo->query(
                'SELECT DISTINCT domain_type FROM os_catalog'
                . ' WHERE is_active = TRUE AND domain_type IS NOT NULL'
                . ' ORDER BY domain_type ASC'
            )->fetchAll();
            $categories = $pdo->query(
                'SELECT DISTINCT c.code, c.name FROM os_catalog_category c'
                . ' JOIN os_catalog cat ON cat.id = c.catalog_id'
                . ' WHERE cat.is_active = TRUE ORDER BY c.name ASC, c.code ASC'
            )->fetchAll();
            $versions = $pdo->query(
                'SELECT DISTINCT r.version_tag FROM os_catalog_release r'
                . ' JOIN os_catalog cat ON cat.id = r.catalog_id'
                . " WHERE cat.is_active = TRUE AND r.status = 'published'"
                . ' ORDER BY r.version_tag DESC'
            )->fetchAll();
            $statuses = $pdo->query(
                'SELECT DISTINCT status FROM os_catalog_item'
                . ' WHERE status IS NOT NULL ORDER BY status ASC'
            )->fetchAll();
        } catch (PDOException) {
            return $empty;
        }

        $families = [];
        $types = [];
        foreach ($rows as $row) {
            $family = (string) ($row['family_code'] ?? '');
            if ($family !== '' && !isset($families[$family])) {
                $families[$family] = ['code' => $family, 'label' => $family];
            }
        }
        foreach ($domainTypes as $row) {
            $type = (string) ($row['domain_type'] ?? '');
            if ($type !== '' && !isset($types[$type])) {
                $types[$type] = ['code' => $type, 'label' => $type];
            }
        }

        // En los nomencladores el "código" de categoría es el de la práctica
        // (010101, 010104...) y el nombre es el capítulo. Mostrar un radio por
        // código llenaba el facet con decenas de "01" y de
        // "Operaciones en el sistema nervioso": se agrupa por nombre y se
        // conserva el primer código como valor estable del parámetro.
        $categoryOptions = [];
        foreach ($categories as $row) {
            $code = (string) ($row['code'] ?? '');
            $label = trim((string) ($row['name'] ?? ''));
            if ($code === '') {
                continue;
            }
            if ($label === '') {
                $label = $code;
            }
            if (!isset($categoryOptions[$label])) {
                $categoryOptions[$label] = [
                    'code' => $code,
                    'label' => $label,
                ];
            }
        }

        $versionOptions = [];
        foreach ($versions as $row) {
            $code = (string) ($row['version_tag'] ?? '');
            if ($code !== '') {
                $versionOptions[] = ['code' => $code, 'label' => $code];
            }
        }

        $statusOptions = [];
        foreach ($statuses as $row) {
            $code = (string) ($row['status'] ?? '');
            if ($code !== '' && self::isValidItemStatus($code)) {
                $statusOptions[] = ['code' => $code, 'label' => $code];
            }
        }

        return [
            'families' => array_values($families),
            'types' => array_values($types),
            'categories' => array_values($categoryOptions),
            'versions' => $versionOptions,
            'statuses' => $statusOptions,
        ];
    }

    /**
     * Conteo de relaciones por ítem en una sola consulta (evita N+1).
     *
     * @param list<int> $itemIds
     *
     * @return array<int, int>
     */
    public static function relationCounts(array $itemIds): array
    {
        if (!self::ALLOW_RESTRICTED_SELECTS) {
            return [];
        }

        $itemIds = array_values(array_unique(array_filter(
            array_map('intval', $itemIds),
            static fn (int $id): bool => $id > 0
        )));
        if ($itemIds === []) {
            return [];
        }

        $pdo = PortalDatabase::connection();
        if (!self::tableExists($pdo, 'os_concept_mapping')) {
            return [];
        }

        $placeholders = implode(', ', array_fill(0, count($itemIds), '?'));
        try {
            $statement = $pdo->prepare(
                'SELECT item_id, count(*) AS total FROM os_concept_mapping'
                . " WHERE item_id IN ({$placeholders}) GROUP BY item_id"
            );
            $statement->execute($itemIds);
            $rows = $statement->fetchAll();
        } catch (PDOException) {
            return [];
        }

        $counts = [];
        foreach ($rows as $row) {
            $counts[(int) $row['item_id']] = (int) $row['total'];
        }

        return $counts;
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
        array $domains,
        string $requestedLanguage,
        int $limit,
        int $offset,
        ?string $catalog = null,
        array $filters = []
    ): array {
        $pdo = PortalDatabase::connection();
        $term = self::normalizeTerm($query);
        $language = self::contentLanguage($pdo, $requestedLanguage);
        // En el browser público, "Todos" significa todas las fuentes publicadas.
        // La API conserva su DEFAULT_DOMAINS acotado por coste; aquí un código
        // DENTAR (DNT-PR/DNT-DX) debe encontrarse sin necesidad de marcar un
        // catálogo a mano. Con catálogo o filtros el ámbito se reduce abajo.
        $domains = self::normalizeDomains(implode(',', $domains));
        if ($domains === []) {
            $domains = self::DOMAINS;
        }
        $catalogs = self::normalizeCatalogs($catalog);
        $filters = self::normalizeFilters($filters);
        if ($catalogs !== []) {
            // El filtro de catálogo implica su dominio aunque el usuario no
            // haya marcado explícitamente ese dominio en el formulario.
            $catalogDomains = [];
            foreach ($catalogs as $catalogCode) {
                $catalogDomains[] = in_array($catalogCode, self::OFTAR_CATALOGS, true)
                    ? 'oftar'
                    : 'odontologia';
            }
            $domains = array_values(array_unique(array_merge($domains, $catalogDomains)));
        } elseif ($filters !== []) {
            // Los filtros estructurados solo existen en el motor os_catalog.
            $domains = array_values(array_intersect(
                $domains,
                array_keys(self::OS_CATALOG_DOMAIN_TYPES)
            ));
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
            $catalogs,
            $filters
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
            self::normalizeCatalogs($catalog)
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
        array $catalogs = [],
        array $filters = []
    ): array {
        $branches = [];
        $parameters = [];
        $index = 0;
        $catalogs = self::normalizeCatalogs(implode(',', $catalogs));
        $filters = self::normalizeFilters($filters);

        foreach ($domains as $domain) {
            if (!self::isValidDomain($domain)) {
                continue;
            }

            // Los catálogos DENTAR y OFTAR viven en os_catalog. Con filtro de
            // producto solo se consultan esas ramas; las fuentes nativas
            // (SNOMED, CIE-10, LOINC…) se combinan sin duplicar resultados.
            if ($filters !== [] && !isset(self::OS_CATALOG_DOMAIN_TYPES[$domain])) {
                continue;
            }

            // OFTAR no tiene tabla nativa: su búsqueda pasa siempre por
            // osCatalogBranch() con family_code = 'oftar'.
            $source = self::SOURCE_TABLE[$domain] ?? ['table' => '', 'field' => ''];
            $nativeExists = $source['table'] !== '' && self::tableExists($pdo, $source['table']);
            $osTypes = self::OS_CATALOG_DOMAIN_TYPES[$domain] ?? [];
            $osExists = $osTypes !== [] && self::osCatalogTablesExist($pdo);

            if (!$nativeExists && !$osExists) {
                continue;
            }

            $nativeAllowed = $filters === []
                && ($catalogs === [] || !in_array($domain, ['odontologia', 'oftar'], true));
            if ($nativeExists && $nativeAllowed) {
                $p = 'p' . $index++;
                [$sql, $params] = self::branch(
                    $p,
                    $domain,
                    $term,
                    $language,
                    $requestedLanguage,
                    $byKey,
                    $key
                );
                $branches[] = $sql;
                $parameters += $params;
            }

            $osAllowed = $catalogs === [] || in_array($domain, ['odontologia', 'oftar'], true);
            if ($osExists && $osAllowed) {
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
                    $catalogs,
                    $filters
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
        string $requestedLanguage,
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
            return self::loincBranch($p, $term, $requestedLanguage, $byKey, $key);
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
        array $catalogs = [],
        array $filters = []
    ): array {
        $catalogs = self::normalizeCatalogs(implode(',', $catalogs));
        $filters = self::normalizeFilters($filters);
        $typeNames = [];
        $catalogNames = [];
        $params = [
            ":{$p}_lang" => $language,
            ":{$p}_req_lang" => $requestedLanguage !== '' ? $requestedLanguage : $language,
        ];
        foreach ($catalogs as $i => $code) {
            $name = ":{$p}_catalog{$i}";
            $catalogNames[] = $name;
            $params[$name] = $code;
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
                "EXISTS (SELECT 1 FROM os_catalog_identifier si WHERE si.item_id = item.id"
                    . " AND si.value ILIKE :{$p}_code_prefix)" => '0.96',
                "ver.preferred_term ILIKE :{$p}_prefix" => '0.92',
                "ver.preferred_term ILIKE :{$p}_contains" => '0.78',
                "similarity(ver.preferred_term, :{$p}_sim)" => null,
            ], $p);

        $releaseFilter = '';
        if (isset($filters['version'])) {
            $releaseFilter .= " AND r.version_tag = :{$p}_version";
            $params[":{$p}_version"] = $filters['version'];
        }
        if (isset($filters['validity'])) {
            $releaseFilter .= " AND r.valid_from <= :{$p}_today"
                . " AND (r.valid_to IS NULL OR r.valid_to >= :{$p}_today)";
            $params[":{$p}_today"] = gmdate('Y-m-d');
        }

        $extraWhere = '';
        // Un mismo producto no debe aparecer dos veces bajo "Todos": OFTAR
        // también tiene domain_type 'medical', igual que 'prestaciones'.
        if ($domain === 'oftar') {
            $extraWhere .= "   AND cat.family_code = 'oftar'\n";
        } else {
            $extraWhere .= "   AND (cat.family_code IS NULL OR cat.family_code <> 'oftar')\n";
        }
        if ($catalogNames !== []) {
            $extraWhere .= '   AND cat.code IN (' . implode(', ', $catalogNames) . ")\n";
        }
        foreach ([
            'family' => 'cat.family_code',
            'type' => 'cat.domain_type',
        ] as $filterKey => $column) {
            if (isset($filters[$filterKey])) {
                $name = ":{$p}_filter_{$filterKey}";
                $extraWhere .= "   AND {$column} = {$name}\n";
                $params[$name] = $filters[$filterKey];
            }
        }
        if (isset($filters['category'])) {
            // El facet agrupa por capítulo: el código representante se resuelve
            // a su nombre para traer todas las prácticas del mismo capítulo.
            $extraWhere .= "   AND catcat.name = (\n"
                . "         SELECT cc.name FROM os_catalog_category cc\n"
                . "          WHERE cc.code = :{$p}_filter_category\n"
                . "          ORDER BY cc.id ASC LIMIT 1\n"
                . "       )\n";
            $params[":{$p}_filter_category"] = $filters['category'];
        }
        $params[":{$p}_filter_status"] = $filters['status'] ?? 'active';

        // Cualquier identificador real debe ser buscable, no solo el que se
        // eligió para el badge. Esto cubre códigos del Nomenclador, CIE-10, CDT
        // y el propio DENTAR cuando conviven en un mismo ítem.
        $identifierWhere = $byKey
            ? " OR EXISTS (SELECT 1 FROM os_catalog_identifier ki"
                . " WHERE ki.item_id = item.id"
                . " AND (ki.value = :{$p}_key"
                . " OR replace(ki.value, '.', '') = :{$p}_key_clean))"
            : " OR EXISTS (SELECT 1 FROM os_catalog_identifier pi"
                . " WHERE pi.item_id = item.id AND pi.value ILIKE :{$p}_contains)";
        $where = $byKey
            ? "(item.permanent_code = :{$p}_key"
                . $identifierWhere
                . " OR 'os_catalog:' || cat.code || ':' || CAST(item.id AS text) = :{$p}_key"
                . " OR '{$domain}:os_catalog:' || cat.code || ':' || CAST(item.id AS text) = :{$p}_full_key)"
            : "(ver.preferred_term ILIKE :{$p}_contains"
                . " OR item.permanent_code ILIKE :{$p}_contains"
                . $identifierWhere
                . " OR EXISTS (SELECT 1 FROM os_catalog_term ot"
                . " WHERE ot.item_version_id = ver.id AND ot.term ILIKE :{$p}_contains))";

        $metadata = "CAST(json_build_object("
            . "'os_catalog', TRUE, "
            . "'catalog_code', cat.code, "
            . "'catalog_name', cat.name, "
            . "'item_id', CAST(item.id AS text), "
            . "'release_id', CAST(rel.id AS text), "
            . "'primary_code', item.permanent_code, "
            . "'official_code', ident.value, "
            . "'official_system', ident.system_name"
            . ") AS text) AS metadata";

        $sql = "SELECT '{$domain}' AS domain, 'os_catalog' AS source,\n"
            . " '{$domain}:os_catalog:' || cat.code || ':' || CAST(item.id AS text) AS result_key,\n"
            . " CAST(item.id AS text) AS source_id,\n"
            // El código visible es el permanente del catálogo (DNT-PR/DNT-DX).
            // El identificador externo (CIE-10, Nomenclador, CDT) se conserva
            // como metadata y sigue siendo buscable.
            . " item.permanent_code AS code,\n"
            . " ver.preferred_term AS term,\n"
            . " cat.short_name AS subtitle,\n"
            . " ver.language_code AS language,\n"
            . " 'os_catalog_item' AS kind, {$score} AS score,\n"
            . " {$metadata}\n"
            . " FROM os_catalog_item item\n"
            . " JOIN os_catalog cat ON cat.id = item.catalog_id\n"
            . " JOIN os_catalog_release rel ON rel.id = (\n"
            . "     SELECT r.id FROM os_catalog_release r\n"
            . "      WHERE r.catalog_id = cat.id AND r.status = 'published'{$releaseFilter}\n"
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
            . "      WHERE i.item_id = item.id\n"
            . "      ORDER BY i.is_primary DESC, i.id ASC LIMIT 1\n"
            . " )\n"
            . (isset($filters['category'])
                ? " JOIN os_catalog_category catcat ON catcat.id = ver.category_id\n"
                : '')
            . " WHERE cat.is_active = TRUE AND item.status = :{$p}_filter_status\n"
            . "   AND cat.domain_type IN (" . implode(', ', $typeNames) . ")\n"
            . $extraWhere
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

    /**
     * Cadena de idiomas LOINC para la resolución pública (D-39):
     * es -> es-AR -> es-MX -> en; en -> en -> es-AR -> es-MX.
     * pt-BR usa la rama española porque no hay capa portuguesa acreditada.
     *
     * @return list<string>
     */
    private static function loincLanguageChain(string $requested): array
    {
        return match (self::canonicalLanguageCode($requested)) {
            'en' => ['en', 'es-AR', 'es-MX'],
            default => ['es-AR', 'es-MX', 'en'],
        };
    }

    /**
     * La capa publicable se resuelve desde loinc_localized_text, nunca desde
     * public.loinc (esa tabla fue sobrescrita por el importador con es-MX y
     * después es-AR, así que ya no conserva todas las capas).
     *
     * @return array{0: string, 1: array<string, string|int>}
     */
    private static function loincBranch(
        string $p,
        string $term,
        string $requestedLanguage,
        bool $byKey,
        ?string $key
    ): array {
        [$l1, $l2, $l3] = self::loincLanguageChain($requestedLanguage);
        $searchFields = "'long_common_name','display_name','shortname','component',"
            . "'consumer_name','relatednames2'";
        $allFields = $searchFields
            . ",'class_type','system_type','scale_type','method_type'";

        // Conjunto conductor: solo los códigos con alguna capa de la cadena que
        // coincide (índice GIN trigram de value) o por código exacto. Se
        // expresa como tabla derivada del FROM, NO como WITH: un WITH después
        // de UNION ALL rompe la consulta completa porque loinc es el último
        // dominio de self::DOMAINS.
        // Los códigos LOINC siempre llevan dígitos (58258-5). Para términos de
        // texto se omite la rama por código: loinc no tiene índice trigram y
        // ILIKE '%texto%' obligaría a recorrer 1,1 M filas dos veces por
        // búsqueda (count + página).
        $codeLike = $byKey || preg_match('/[0-9]/', $term) === 1;
        $matched = $byKey
            ? "SELECT CAST(:{$p}_key AS VARCHAR(20)) AS loinc_code"
            : "SELECT DISTINCT l.loinc_code\n"
                . " FROM loinc_localized_text l\n"
                . " WHERE l.language_code IN (:{$p}_l1, :{$p}_l2, :{$p}_l3)\n"
                . "   AND l.source_release = '2.83'\n"
                . "   AND l.field_name IN ({$searchFields})\n"
                . "   AND l.value ILIKE :{$p}_contains";
        if ($codeLike && !$byKey) {
            $matched .= "\n UNION\n"
                . " SELECT t.loinc FROM loinc t WHERE t.loinc ILIKE :{$p}_contains";
        }

        // Un DISTINCT ON por campo: gana el primer idioma de la cadena y,
        // dentro de él, la prioridad D-33 de v_loinc_resolved. LATERAL lo
        // calcula una sola vez por código candidato.
        $localized = "SELECT\n"
            . " max(x.value) FILTER (WHERE x.field_name = 'long_common_name') AS loc_long_common_name,\n"
            . " max(x.value) FILTER (WHERE x.field_name = 'display_name') AS loc_display_name,\n"
            . " max(x.value) FILTER (WHERE x.field_name = 'shortname') AS loc_shortname,\n"
            . " max(x.value) FILTER (WHERE x.field_name = 'component') AS loc_component,\n"
            . " max(x.value) FILTER (WHERE x.field_name = 'consumer_name') AS loc_consumer_name,\n"
            . " max(x.value) FILTER (WHERE x.field_name = 'relatednames2') AS loc_relatednames2,\n"
            . " max(x.value) FILTER (WHERE x.field_name = 'class_type') AS loc_class_type,\n"
            . " max(x.value) FILTER (WHERE x.field_name = 'system_type') AS loc_system_type,\n"
            . " max(x.value) FILTER (WHERE x.field_name = 'scale_type') AS loc_scale_type,\n"
            . " max(x.value) FILTER (WHERE x.field_name = 'method_type') AS loc_method_type,\n"
            . " max(x.language_code) FILTER (WHERE x.field_name = 'long_common_name') AS loc_lang_long,\n"
            . " max(x.language_code) FILTER (WHERE x.field_name = 'display_name') AS loc_lang_display,\n"
            . " max(x.language_code) FILTER (WHERE x.field_name = 'shortname') AS loc_lang_short,\n"
            . " max(x.language_code) FILTER (WHERE x.field_name = 'component') AS loc_lang_component\n"
            . " FROM (\n"
            . "  SELECT DISTINCT ON (field_name) field_name, value, language_code\n"
            . "  FROM loinc_localized_text\n"
            . "  WHERE loinc_code = t.loinc\n"
            . "    AND language_code IN (:{$p}_l1, :{$p}_l2, :{$p}_l3)\n"
            . "    AND field_name IN ({$allFields})\n"
            . "    AND source_release = '2.83'\n"
            . "    AND NULLIF(btrim(value), '') IS NOT NULL\n"
            . "  ORDER BY field_name,\n"
            . "    CASE language_code WHEN :{$p}_l1 THEN 1 WHEN :{$p}_l2 THEN 2 ELSE 3 END,\n"
            . "    source_priority DESC, source_file ASC,\n"
            . "    version_last_changed DESC NULLS LAST\n"
            . " ) x";

        $termSql = "coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''),"
            . " nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''),"
            . " nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component)";
        $languageSql = "coalesce(l.loc_lang_long, l.loc_lang_display, l.loc_lang_short,"
            . " l.loc_lang_component, 'es-AR')";
        $subtitleSql = "coalesce(nullif(l.loc_component, ''), nullif(t.component, ''),"
            . " nullif(l.loc_shortname, ''), nullif(t.shortname, ''))";
        $altSql = "coalesce(nullif(l.loc_display_name, ''), nullif(l.loc_shortname, ''),"
            . " nullif(l.loc_component, ''))";
        $consumerSql = "coalesce(nullif(l.loc_consumer_name, ''), nullif(l.loc_relatednames2, ''))";

        $metadata = "CAST(json_build_object("
            . "'loinc_code', t.loinc, "
            . "'class_type', coalesce(nullif(l.loc_class_type, ''), t.class_type), "
            . "'system_type', coalesce(nullif(l.loc_system_type, ''), t.system_type), "
            . "'scale_type', coalesce(nullif(l.loc_scale_type, ''), t.scale_type), "
            . "'method_type', coalesce(nullif(l.loc_method_type, ''), t.method_type), "
            . "'status', t.status, "
            . "'consumer_name', coalesce(nullif(l.loc_consumer_name, ''), t.consumer_name), "
            . "'example_ucum_units', t.example_ucum_units"
            . ") AS text) AS metadata";

        $score = $byKey
            ? 'CAST(1.0 AS float8)'
            : self::scoreSql([
                "lower(t.loinc) = lower(:{$p}_exact)" => '1.0',
                "t.loinc ILIKE :{$p}_prefix" => '0.96',
                "lower({$termSql}) = lower(:{$p}_exact)" => '0.94',
                "{$termSql} ILIKE :{$p}_prefix" => '0.90',
                "{$altSql} ILIKE :{$p}_prefix" => '0.88',
                "l.loc_component ILIKE :{$p}_prefix" => '0.86',
                "l.loc_consumer_name ILIKE :{$p}_prefix" => '0.84',
                "{$termSql} ILIKE :{$p}_contains" => '0.78',
                "{$altSql} ILIKE :{$p}_contains" => '0.76',
                "{$consumerSql} ILIKE :{$p}_contains" => '0.75',
                "l.loc_component ILIKE :{$p}_contains" => '0.74',
                "similarity({$termSql}, :{$p}_sim)" => null,
            ], $p);

        // El filtro final se aplica sobre el término YA RESUELTO, para no
        // devolver aciertos de una capa que no es la que se va a mostrar.
        $where = $byKey
            ? 'true'
            : "({$termSql} ILIKE :{$p}_contains"
                . ($codeLike ? " OR t.loinc ILIKE :{$p}_contains" : '')
                . " OR {$altSql} ILIKE :{$p}_contains"
                . " OR {$consumerSql} ILIKE :{$p}_contains)";

        $sql = "SELECT 'loinc' AS domain, 'loinc' AS source,\n"
            . " 'loinc:' || t.loinc AS result_key,\n"
            . " t.loinc AS source_id, t.loinc AS code,\n"
            . " {$termSql} AS term, {$subtitleSql} AS subtitle,\n"
            . " {$languageSql} AS language, 'loinc_observation' AS kind,\n"
            . " {$score} AS score, {$metadata}\n"
            . " FROM ({$matched}) m\n"
            . " JOIN loinc t ON t.loinc = m.loinc_code\n"
            . " CROSS JOIN LATERAL ({$localized}) l\n"
            . " WHERE {$where}";

        $params = [
            ":{$p}_l1" => $l1,
            ":{$p}_l2" => $l2,
            ":{$p}_l3" => $l3,
        ];
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

        $relationIds = [];
        foreach ($rows as $candidate) {
            $candidateMetadata = self::decodeMetadata($candidate['metadata'] ?? null);
            if (!empty($candidateMetadata['os_catalog']) && !empty($candidateMetadata['item_id'])) {
                $relationIds[] = (int) $candidateMetadata['item_id'];
            }
        }
        $relationCounts = self::relationCounts($relationIds);

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
            $score = round((float) ($row['score'] ?? 0), 4);
            $item = [
                'id' => (string) ($row['result_key'] ?? ''),
                'source_id' => (string) ($row['source_id'] ?? ''),
                'code' => $row['code'] !== null ? (string) $row['code'] : null,
                'term' => $row['term'] !== null ? (string) $row['term'] : null,
                'subtitle' => $row['subtitle'] !== null ? (string) $row['subtitle'] : null,
                'domain' => (string) ($row['domain'] ?? ''),
                'kind' => (string) ($row['kind'] ?? ''),
                'score' => $score,
                'match_type' => $score >= 1.0 ? 'exact' : 'partial',
                'relation_count' => $isOsCatalog && $itemId > 0 ? ($relationCounts[$itemId] ?? 0) : 0,
                'description' => $editorial['description'] ?? self::description($metadata),
                'concept_id' => isset($metadata['concept_id']) ? (string) $metadata['concept_id'] : null,
                'catalog_code' => isset($metadata['catalog_code']) ? (string) $metadata['catalog_code'] : null,
                'official_code' => isset($metadata['official_code']) && $metadata['official_code'] !== null
                    ? (string) $metadata['official_code']
                    : null,
                'official_system' => isset($metadata['official_system']) && $metadata['official_system'] !== null
                    ? (string) $metadata['official_system']
                    : null,
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

    /**
     * Secciones de la ficha integral. Solo expone datos del repositorio real.
     * Si una tabla no existe o el rol no tiene SELECT, la sección queda vacía
     * y la vista omite la pestaña: nunca se rellena con datos inventados.
     *
     * @return array{concept: array<string, mixed>, relations: list<array<string, mixed>>, values: list<array<string, mixed>>, validity: list<array<string, mixed>>, clinical: array<string, mixed>, trace: array<string, mixed>}
     */
    public static function detailSections(
        string $resultKey,
        string $requestedLanguage,
        ?string $catalog = null
    ): array {
        $sections = [
            'concept' => [],
            'relations' => [],
            'values' => [],
            'validity' => [],
            'clinical' => [],
            'trace' => [],
        ];

        $item = self::find($resultKey, $requestedLanguage, $catalog);
        if ($item === null) {
            return $sections;
        }

        $sections['concept'] = [
            'code' => $item['code'] ?? null,
            'term' => $item['term'] ?? null,
            'catalog_code' => $item['catalog_code'] ?? null,
            'catalog_name' => $item['subtitle'] ?? null,
            'domain' => $item['domain'] ?? null,
            'kind' => $item['kind'] ?? null,
            'description' => $item['description'] ?? null,
            'language' => $item['language'] ?? null,
            'effective_language' => $item['effective_language'] ?? null,
            'source_language' => $item['source_language'] ?? null,
            'provenance' => $item['provenance'] ?? null,
            'approval_state' => $item['approval_state'] ?? null,
            'untranslated' => !empty($item['untranslated']),
            'fallback_applied' => !empty($item['fallback_applied']),
            'fallback_reason' => $item['fallback_reason'] ?? null,
            'dialect_determined' => !empty($item['dialect_determined']),
        ];

        $isOsCatalog = str_contains((string) ($item['id'] ?? ''), ':os_catalog:');
        $itemId = ctype_digit((string) ($item['source_id'] ?? '')) ? (int) $item['source_id'] : 0;
        if (!$isOsCatalog || $itemId === 0) {
            return $sections;
        }

        $rich = self::osCatalogDetail($itemId, $requestedLanguage, $item);
        $sections['concept'] = array_merge($sections['concept'], $rich['concept']);
        $sections['validity'] = $rich['validity'];
        $sections['clinical'] = $rich['clinical'];
        $sections['trace'] = $rich['trace'];
        $sections['relations'] = self::itemRelations($itemId, $requestedLanguage);
        $sections['values'] = self::itemValues($itemId);

        return $sections;
    }

    /**
     * @param array<string, mixed> $item
     *
     * @return array{concept: array<string, mixed>, validity: list<array<string, mixed>>, clinical: array<string, mixed>, trace: array<string, mixed>}
     *
     * @throws RepositoryException
     */
    private static function osCatalogDetail(int $itemId, string $requestedLanguage, array $item): array
    {
        $pdo = PortalDatabase::connection();
        $contentLanguage = self::contentLanguage($pdo, $requestedLanguage);
        $fakeRows = [[
            'metadata' => json_encode(['os_catalog' => true, 'item_id' => $itemId]),
            'domain' => (string) ($item['domain'] ?? ''),
            'source_id' => (string) $itemId,
        ]];
        $variants = self::loadOsCatalogVariants($pdo, $fakeRows);
        $reviews = self::loadReviews($pdo, $fakeRows, $variants);
        $chain = self::languageChain($pdo, $requestedLanguage, $contentLanguage);

        $fieldCandidates = [];
        $clinicalFields = [
            'definition',
            'clinical_criteria',
            'short_definition',
            'lay_terms',
            'clinical_scope',
        ];

        foreach ($variants['versions'] as $version) {
            foreach ($clinicalFields as $field) {
                $value = $version[$field] ?? null;
                if (!is_string($value) || $value === '') {
                    continue;
                }
                $fieldCandidates[] = [
                    'table' => 'os_catalog_item_version',
                    'id' => (int) $version['id'],
                    'field' => $field,
                    'value' => $value,
                    'language' => (string) ($version['language_code'] ?? 'es'),
                    'source_language' => $version['source_language_code'] ?? null,
                    'provenance' => (string) ($version['provenance'] ?? 'unknown'),
                    'review_status' => (string) ($version['review_status'] ?? 'unknown'),
                    'content_hash' => (string) ($version['content_hash'] ?? ''),
                    'release_id' => (int) ($version['release_id'] ?? 0),
                    'type' => null,
                ];
            }
        }

        $termCandidates = [];
        foreach ($variants['terms'] as $term) {
            $value = (string) ($term['term'] ?? '');
            if ($value === '') {
                continue;
            }
            $termCandidates[] = [
                'table' => 'os_catalog_term',
                'id' => (int) $term['id'],
                'field' => 'term',
                'value' => $value,
                'language' => (string) ($term['language_code'] ?? 'es'),
                'source_language' => $term['source_language_code'] ?? null,
                'provenance' => (string) ($term['provenance'] ?? 'unknown'),
                'review_status' => (string) ($term['review_status'] ?? 'unknown'),
                'content_hash' => (string) ($term['content_hash'] ?? ''),
                'release_id' => 0,
                'type' => (string) ($term['term_type'] ?? 'synonym'),
            ];
        }

        $clinical = [];
        foreach ($clinicalFields as $field) {
            $selected = self::selectApproved($fieldCandidates, $reviews, $chain, $field);
            if ($selected !== null) {
                $clinical[$field] = $selected;
            }
        }

        // Un cambio gobernado publicado actualiza os_catalog_item_version pero
        // no genera os_field_review: selectApproved() lo descarta y Browse
        // seguía mostrando el texto anterior (o ninguno). La versión más
        // reciente se muestra con estado pendiente de validación, nunca como
        // aprobada. Aplica a definición y a criterios clínicos.
        foreach (['definition', 'clinical_criteria'] as $fallbackField) {
            $latest = self::latestClinicalField($fieldCandidates, $chain, $fallbackField);
            if ($latest === null) {
                continue;
            }
            $selected = $clinical[$fallbackField] ?? null;
            $sameValue = $selected !== null
                && ($selected['value'] ?? null) === $latest['value'];

            if ($selected === null || !$sameValue) {
                $clinical[$fallbackField] = $latest;
            } else {
                $clinical[$fallbackField]['review_status'] = 'approved';
            }
        }

        $synonyms = [];
        $wanted = [];
        foreach ($chain as $entry) {
            $wanted[$entry['code']] = true;
        }
        foreach ($termCandidates as $candidate) {
            if ($candidate['source_language'] !== null && $candidate['source_language'] !== '') {
                $wanted[(string) $candidate['source_language']] = true;
            }
        }
        foreach (array_keys($wanted) as $language) {
            $selected = self::selectApproved($termCandidates, $reviews, $chain, null, (string) $language);
            if ($selected !== null) {
                $synonyms[] = [
                    'term' => $selected['value'],
                    'language' => $selected['language'],
                    'type' => $selected['type'] ?? 'synonym',
                    'source_language' => $selected['source_language'],
                ];
            }
        }

        $identifiers = [];
        $identifierPositions = [];
        try {
            $statement = $pdo->prepare(
                'SELECT system_name, value, is_primary FROM os_catalog_identifier'
                . ' WHERE item_id = ? ORDER BY is_primary DESC, id ASC'
            );
            $statement->execute([$itemId]);
            foreach ($statement->fetchAll() as $row) {
                $system = (string) $row['system_name'];
                $value = (string) $row['value'];
                $primary = (bool) $row['is_primary'];
                $key = self::canonicalIdentifierSystem($system) . '|' . $value;

                // El importador puede repetir el mismo identificador con y sin
                // marca de principal. Se conserva una sola entrada y se
                // preserva la marca cuando alguna de las filas la tiene.
                if (isset($identifierPositions[$key])) {
                    if ($primary) {
                        $identifiers[$identifierPositions[$key]]['primary'] = true;
                    }
                    continue;
                }

                $identifierPositions[$key] = count($identifiers);
                $identifiers[] = [
                    'system' => $system,
                    'value' => $value,
                    'primary' => $primary,
                ];
            }
        } catch (PDOException) {
            $identifiers = [];
        }

        // El espejo os_catalog_item_version puede no tener los textos clínicos
        // del DENTAR editorial. Se leen de la fuente original en solo lectura
        // y se marcan como pendientes de validación; nunca como aprobados.
        foreach (self::dentarClinicalFields($itemId, $item, $identifiers, $chain) as $field => $entry) {
            if (!array_key_exists($field, $clinical)) {
                $clinical[$field] = $entry;
            }
        }

        // Campos literales del Nomenclador Odontológico Nacional. La tabla es
        // opcional: si no fue cargada, la ficha no inventa indicadores.
        $sourceAttributes = [];
        if (self::tableExists($pdo, 'os_catalog_source_attribute')) {
            try {
                $statement = $pdo->prepare(
                    'SELECT attribute_code, attribute_label, attribute_value, is_boolean, display_order'
                    . ' FROM os_catalog_source_attribute'
                    . ' WHERE item_id = ? ORDER BY display_order, attribute_code'
                );
                $statement->execute([$itemId]);
                foreach ($statement->fetchAll() as $row) {
                    $sourceAttributes[] = [
                        'code' => (string) $row['attribute_code'],
                        'label' => (string) $row['attribute_label'],
                        'value' => (string) $row['attribute_value'],
                        'boolean' => (bool) $row['is_boolean'],
                    ];
                }
            } catch (PDOException) {
                $sourceAttributes = [];
            }
        }

        $validity = [];
        $itemRow = null;
        try {
            $statement = $pdo->prepare(
                'SELECT status, created_at, permanent_code FROM os_catalog_item WHERE id = ?'
            );
            $statement->execute([$itemId]);
            $row = $statement->fetch();
            $itemRow = is_array($row) ? $row : null;

            $statement = $pdo->prepare(
                'SELECT r.id AS release_id, r.version_tag, r.valid_from AS release_valid_from,'
                . ' r.valid_to AS release_valid_to, r.status AS release_status,'
                . ' r.official_norm_reference, v.id AS version_id, v.language_code,'
                . ' v.review_status, v.provenance, v.content_hash, v.source_language_code,'
                . ' v.valid_from AS version_valid_from, v.valid_to AS version_valid_to'
                . ' FROM os_catalog_item_version v'
                . ' JOIN os_catalog_release r ON r.id = v.release_id'
                . ' WHERE v.item_id = ?'
                . ' ORDER BY r.valid_from DESC NULLS LAST, v.id DESC'
            );
            $statement->execute([$itemId]);
            foreach ($statement->fetchAll() as $row) {
                $validity[] = [
                    'release_id' => (string) $row['release_id'],
                    'version' => (string) $row['version_tag'],
                    'release_status' => (string) $row['release_status'],
                    'release_valid_from' => $row['release_valid_from'] !== null ? (string) $row['release_valid_from'] : null,
                    'release_valid_to' => $row['release_valid_to'] !== null ? (string) $row['release_valid_to'] : null,
                    'normative' => $row['official_norm_reference'] !== null ? (string) $row['official_norm_reference'] : null,
                    'version_id' => (string) $row['version_id'],
                    'language' => (string) $row['language_code'],
                    'source_language' => $row['source_language_code'] !== null ? (string) $row['source_language_code'] : null,
                    'review_status' => (string) $row['review_status'],
                    'provenance' => (string) $row['provenance'],
                    'content_hash' => (string) $row['content_hash'],
                    'version_valid_from' => $row['version_valid_from'] !== null ? (string) $row['version_valid_from'] : null,
                    'version_valid_to' => $row['version_valid_to'] !== null ? (string) $row['version_valid_to'] : null,
                    'item_status' => $itemRow !== null ? (string) $itemRow['status'] : null,
                ];
            }
        } catch (PDOException) {
            $validity = [];
        }

        $primary = null;
        foreach ($identifiers as $identifier) {
            if ($identifier['primary']) {
                $primary = $identifier['value'];
                break;
            }
        }
        $firstVersion = $validity[0] ?? [];

        $trace = [
            'source' => $item['subtitle'] ?? $item['catalog_code'] ?? null,
            'system' => $item['catalog_code'] ?? null,
            'external_id' => $primary ?? ($itemRow['permanent_code'] ?? null),
            'version' => $firstVersion['version'] ?? null,
            'release_status' => $firstVersion['release_status'] ?? null,
            'normative' => $firstVersion['normative'] ?? null,
            'created_at' => $itemRow['created_at'] ?? null,
            'provenance' => $firstVersion['provenance'] ?? ($item['provenance'] ?? null),
            'review_status' => $firstVersion['review_status'] ?? null,
            'content_hash' => $firstVersion['content_hash'] ?? null,
        ];

        return [
            'concept' => [
                'definition' => $clinical['definition']['value'] ?? null,
                'definition_review_status' => $clinical['definition']['review_status'] ?? null,
                'definition_provenance' => $clinical['definition']['provenance'] ?? null,
                'short_definition' => $clinical['short_definition']['value'] ?? null,
                'synonyms' => $synonyms,
                'identifiers' => $identifiers,
                'source_attributes' => $sourceAttributes,
            ],
            'validity' => $validity,
            'clinical' => $clinical,
            'trace' => $trace,
        ];
    }

    /**
     * @param list<array<string, mixed>> $candidates
     * @param array<string, list<array<string, mixed>>> $reviews
     * @param list<array{code: string, reason: ?string, primary: string}> $chain
     *
     * @return array{value: string, language: string, source_language: ?string, provenance: string, review_status: string, type: ?string}|null
     */
    private static function selectApproved(
        array $candidates,
        array $reviews,
        array $chain,
        ?string $field = null,
        ?string $onlyLanguage = null
    ): ?array {
        $order = [];
        foreach ($chain as $position => $entry) {
            $order[] = ['code' => $entry['code'], 'position' => $position];
        }
        foreach ($candidates as $candidate) {
            $source = $candidate['source_language'] ?? null;
            if (!is_string($source) || $source === '') {
                continue;
            }
            foreach ($order as $entry) {
                if (strtolower($entry['code']) === strtolower($source)) {
                    continue 2;
                }
            }
            $order[] = ['code' => $source, 'position' => count($order)];
        }

        foreach ($order as $want) {
            if ($onlyLanguage !== null && strtolower($want['code']) !== strtolower($onlyLanguage)) {
                continue;
            }
            foreach ($candidates as $candidate) {
                if ($field !== null && $candidate['field'] !== $field) {
                    continue;
                }
                if (strtolower((string) $candidate['language']) !== strtolower($want['code'])) {
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
                    if ($scope !== null && $candidate['release_id'] !== 0 && (int) $scope !== $candidate['release_id']) {
                        continue;
                    }
                    $language = (string) $review['language_code'];
                    $reference = $review['source_reference'] ?? null;
                    $expected = self::contentHash(
                        (string) $candidate['value'],
                        $language,
                        $reference !== null ? (string) $reference : null
                    );
                    if ((string) ($review['content_hash'] ?? '') !== $expected) {
                        continue;
                    }

                    return [
                        'value' => (string) $candidate['value'],
                        'language' => $language,
                        'source_language' => $review['source_language_code'] ?? $candidate['source_language'],
                        'provenance' => (string) ($review['provenance'] ?? $candidate['provenance']),
                        'review_status' => 'approved',
                        'type' => $candidate['type'],
                    ];
                }
            }
        }

        return null;
    }

    /**
     * Último texto clínico publicado en el motor de catálogos.
     *
     * Se prioriza el idioma de la cadena solicitada y, dentro de él, la
     * versión/release más reciente. Se usa solo como respaldo cuando no hay
     * una revisión editorial aprobada o cuando el texto difiere de ella.
     *
     * @param list<array<string, mixed>> $candidates
     * @param list<array{code: string, reason: ?string, primary: string}> $chain
     *
     * @return array{value: string, language: string, source_language: ?string, provenance: string, review_status: string, type: ?string}|null
     */
    private static function latestClinicalField(array $candidates, array $chain, string $field): ?array
    {
        $definitions = [];
        foreach ($candidates as $candidate) {
            if (($candidate['field'] ?? '') !== $field) {
                continue;
            }
            $value = (string) ($candidate['value'] ?? '');
            if ($value === '') {
                continue;
            }
            $definitions[] = $candidate;
        }

        if ($definitions === []) {
            return null;
        }

        $rank = static function (array $candidate) use ($chain): array {
            $language = strtolower((string) ($candidate['language'] ?? ''));
            $position = count($chain);
            foreach ($chain as $index => $entry) {
                if (strtolower((string) $entry['code']) === $language) {
                    $position = $index;
                    break;
                }
            }

            return [
                $position,
                -(int) ($candidate['release_id'] ?? 0),
                -(int) ($candidate['id'] ?? 0),
            ];
        };

        usort($definitions, static function (array $left, array $right) use ($rank): int {
            return $rank($left) <=> $rank($right);
        });

        $selected = $definitions[0];

        return [
            'value' => (string) $selected['value'],
            'language' => (string) ($selected['language'] ?? ''),
            'source_language' => $selected['source_language'] ?? null,
            'provenance' => (string) ($selected['provenance'] ?? 'unknown'),
            'review_status' => 'draft',
            'type' => $selected['type'] ?? null,
        ];
    }

    /**
     * Normaliza el sistema de un identificador para agrupar alias que la ficha
     * muestra con la misma etiqueta (NOMENCLADOR_AR, NOMENCLADOR-AR y
     * nomenclador-odontologico-ar son el mismo sistema público).
     */
    private static function canonicalIdentifierSystem(string $system): string
    {
        $slug = strtolower((string) preg_replace('/[^a-z0-9]/i', '', trim($system)));

        if (str_contains($slug, 'nomenclador')) {
            return 'nomenclador';
        }
        if (str_contains($slug, 'dentarpr')) {
            return 'dentarpr';
        }

        return $slug;
    }

    /**
     * Respaldo de solo lectura sobre la fuente editorial DENTAR.
     *
     * Si el espejo os_catalog_item_version no contiene los textos clínicos,
     * Browse los toma de dentar_concept_version y los marca como pendientes de
     * validación editorial. No escribe en la fuente ni los presenta como
     * aprobados.
     *
     * @param list<array<string, mixed>> $identifiers
     *
     * @return array<string, array{value: string, language: string, source_language: ?string, provenance: string, review_status: string, type: ?string}>
     */
    private static function dentarClinicalFields(
        int $itemId,
        array $item,
        array $identifiers,
        array $chain
    ): array {
        if ($itemId <= 0) {
            return [];
        }

        $code = trim((string) ($item['code'] ?? ''));
        if ((string) ($item['catalog_code'] ?? '') !== 'dentar-pr') {
            foreach ($identifiers as $identifier) {
                if (self::canonicalIdentifierSystem((string) ($identifier['system'] ?? '')) !== 'dentarpr') {
                    continue;
                }
                $candidate = trim((string) ($identifier['value'] ?? ''));
                if ($candidate !== '') {
                    $code = $candidate;
                    break;
                }
            }
        }
        if ($code === '') {
            return [];
        }

        $pdo = PortalDatabase::connection();
        if (!self::tableExists($pdo, 'dentar_concept')
            || !self::tableExists($pdo, 'dentar_catalog')
            || !self::tableExists($pdo, 'dentar_concept_version')) {
            return [];
        }

        try {
            $statement = $pdo->prepare(
                'SELECT v.definition, v.clinical_criteria, v.short_definition, v.lay_terms,'
                . ' v.clinical_scope, v.version_number, v.approval_status'
                . ' FROM dentar_concept dc'
                . ' JOIN dentar_catalog cat ON cat.id = dc.catalog_id AND cat.code = \'dentar-pr\''
                . ' JOIN dentar_concept_version v ON v.concept_id = dc.id'
                . ' WHERE dc.code = ?'
                . ' ORDER BY (v.approval_status = \'approved\') DESC, v.version_number DESC, v.id DESC'
                . ' LIMIT 1'
            );
            $statement->execute([$code]);
            $row = $statement->fetch();
        } catch (PDOException) {
            return [];
        }
        if (!is_array($row)) {
            return [];
        }

        $language = (string) ($chain[0]['code'] ?? 'es-AR');
        $provenance = 'dentar_concept_version · v' . (string) ($row['version_number'] ?? '');
        $fields = [];
        foreach (['definition', 'clinical_criteria', 'short_definition', 'lay_terms', 'clinical_scope'] as $field) {
            $value = trim((string) ($row[$field] ?? ''));
            if ($value === '') {
                continue;
            }
            $fields[$field] = [
                'value' => $value,
                'language' => $language,
                'source_language' => null,
                'provenance' => $provenance,
                'review_status' => 'draft',
                'type' => null,
            ];
        }

        return $fields;
    }

    /**
     * Relaciones registradas en os_concept_mapping y en os_catalog_relation.
     * Sin SELECT sobre esas tablas (o sin filas) devuelve [] y la pestaña no
     * se muestra: nunca se rellena con datos inventados.
     *
     * @return list<array<string, mixed>>
     */
    public static function itemRelations(int $itemId, string $requestedLanguage = 'es-AR'): array
    {
        if (!self::ALLOW_RESTRICTED_SELECTS) {
            return [];
        }

        $pdo = PortalDatabase::connection();
        $hasMappingTables = self::tableExists($pdo, 'os_concept_mapping')
            && self::tableExists($pdo, 'os_terminology_system')
            && self::tableExists($pdo, 'os_catalog_identifier');
        $hasCatalogRelation = self::tableExists($pdo, 'os_catalog_relation');
        if ((!$hasMappingTables && !$hasCatalogRelation)
            || !self::tableExists($pdo, 'os_catalog_item')
            || !self::tableExists($pdo, 'os_catalog')) {
            return [];
        }

        $relations = [];

        if ($hasMappingTables) {
            try {
                $statement = $pdo->prepare(
                    'SELECT sys.code AS system_code, sys.uri AS system_uri,'
                    . ' sys.default_version AS system_version, m.external_code, m.external_display,'
                    . ' m.mapping_type, m.relationship_role, m.review_status, m.provenance,'
                    . ' linked.matches AS linked_matches, linked.item_id AS linked_item,'
                    . ' linked.catalog_code AS linked_catalog, linked.domain_type AS linked_domain_type'
                    . ' FROM os_concept_mapping m'
                    . ' JOIN os_terminology_system sys ON sys.id = m.terminology_system_id'
                    . ' LEFT JOIN LATERAL ('
                    . '   SELECT count(*) AS matches, min(li.item_id) AS item_id,'
                    . '          min(lcat.code) AS catalog_code, min(lcat.domain_type) AS domain_type'
                    . '   FROM os_catalog_identifier li'
                    . '   JOIN os_catalog_item litem ON litem.id = li.item_id'
                    . '   JOIN os_catalog lcat ON lcat.id = litem.catalog_id'
                    . '   WHERE li.value = m.external_code AND li.system_name = sys.code'
                    . ' AND lcat.is_active = TRUE'
                    . ' ) linked ON TRUE'
                    . ' WHERE m.item_id = ?'
                    . ' ORDER BY sys.code ASC, m.external_code ASC'
                );
                $statement->execute([$itemId]);
                $rows = $statement->fetchAll();
            } catch (PDOException) {
                $rows = [];
            }

            foreach ($rows as $row) {
                $targetKey = '';
                if ((int) ($row['linked_matches'] ?? 0) === 1) {
                    $targetKey = self::osCatalogResultKey(
                        (string) ($row['linked_domain_type'] ?? ''),
                        (string) ($row['linked_catalog'] ?? ''),
                        (int) ($row['linked_item'] ?? 0)
                    );
                }

                $relations[] = [
                    'system' => (string) $row['system_code'],
                    'uri' => $row['system_uri'] !== null ? (string) $row['system_uri'] : null,
                    'version' => $row['system_version'] !== null ? (string) $row['system_version'] : null,
                    'code' => (string) $row['external_code'],
                    'display' => $row['external_display'] !== null ? (string) $row['external_display'] : null,
                    'type' => (string) $row['mapping_type'],
                    'role' => (string) $row['relationship_role'],
                    'review_status' => (string) $row['review_status'],
                    'provenance' => $row['provenance'] !== null ? (string) $row['provenance'] : null,
                    'result_key' => $targetKey,
                ];
            }
        }

        if ($hasCatalogRelation) {
            try {
                $statement = $pdo->prepare(
                    'SELECT r.relation_type, r.source_system_code, r.source_field, r.source_value,'
                    . ' r.context_text, r.review_status, r.provenance,'
                    . " CASE WHEN r.source_item_id = ? THEN 'outgoing' ELSE 'incoming' END AS direction,"
                    . ' other.id AS other_item_id, other.permanent_code AS other_code,'
                    . ' cat.code AS other_catalog, cat.domain_type AS other_domain_type,'
                    . ' (SELECT iv.preferred_term FROM os_catalog_item_version iv'
                    . '   WHERE iv.item_id = other.id AND iv.language_code IN (?, \'es-AR\')'
                    . '   ORDER BY CASE WHEN iv.language_code = ? THEN 0 ELSE 1 END, iv.id DESC'
                    . '   LIMIT 1) AS other_display'
                    . ' FROM os_catalog_relation r'
                    . ' JOIN os_catalog_item other'
                    . '   ON other.id = CASE WHEN r.source_item_id = ?'
                    . '                      THEN r.target_item_id ELSE r.source_item_id END'
                    . ' JOIN os_catalog cat ON cat.id = other.catalog_id'
                    . ' WHERE r.source_item_id = ? OR r.target_item_id = ?'
                    . ' ORDER BY direction ASC, r.relation_type ASC, other.permanent_code ASC'
                );
                $statement->execute([
                    $itemId,
                    $requestedLanguage,
                    $requestedLanguage,
                    $itemId,
                    $itemId,
                    $itemId,
                ]);
                $relationRows = $statement->fetchAll();
            } catch (PDOException) {
                $relationRows = [];
            }

            foreach ($relationRows as $row) {
                $relations[] = [
                    'system' => (string) $row['source_system_code'],
                    'uri' => null,
                    'version' => null,
                    'code' => (string) $row['other_code'],
                    'display' => $row['other_display'] !== null ? (string) $row['other_display'] : null,
                    'type' => (string) $row['relation_type'],
                    'role' => (string) $row['direction'],
                    'review_status' => (string) $row['review_status'],
                    'provenance' => (string) $row['provenance'],
                    'result_key' => self::osCatalogResultKey(
                        (string) ($row['other_domain_type'] ?? ''),
                        (string) ($row['other_catalog'] ?? ''),
                        (int) ($row['other_item_id'] ?? 0)
                    ),
                    'source_field' => (string) $row['source_field'],
                    'source_value' => (string) $row['source_value'],
                    'context_text' => $row['context_text'] !== null ? (string) $row['context_text'] : null,
                    'direction' => (string) $row['direction'],
                ];
            }
        }

        return self::dedupeRelations($relations);
    }

    /**
     * Elimina relaciones espejo del mismo sistema/código/tipo.
     *
     * El importador del Nomenclador registra la referencia en ambos extremos:
     * entra como "Relación entrante" y sale como "Relación saliente". La ficha
     * debe mostrar una sola fila; se conserva la versión saliente (pertenece
     * al ítem abierto), o la que tenga mejor revisión/enlace.
     *
     * @param list<array<string, mixed>> $relations
     *
     * @return list<array<string, mixed>>
     */
    private static function dedupeRelations(array $relations): array
    {
        $unique = [];
        $positions = [];

        foreach ($relations as $relation) {
            if (!is_array($relation)) {
                $unique[] = $relation;
                continue;
            }

            $key = strtolower(trim((string) ($relation['system'] ?? '')))
                . '|' . strtolower(trim((string) ($relation['code'] ?? '')))
                . '|' . strtolower(trim((string) ($relation['type'] ?? '')));

            if (!isset($positions[$key])) {
                $positions[$key] = count($unique);
                $unique[] = $relation;
                continue;
            }

            $position = $positions[$key];
            if (self::relationRank($relation) > self::relationRank($unique[$position])) {
                $unique[$position] = $relation;
            }
        }

        return $unique;
    }

    /** @param array<string, mixed> $relation */
    private static function relationRank(array $relation): int
    {
        $rank = 0;
        if (in_array((string) ($relation['role'] ?? ''), ['outgoing', 'saliente'], true)) {
            $rank += 8;
        }
        if (in_array((string) ($relation['direction'] ?? ''), ['outgoing', 'saliente'], true)) {
            $rank += 8;
        }
        if ((string) ($relation['review_status'] ?? '') === 'approved') {
            $rank += 4;
        }
        if ((string) ($relation['result_key'] ?? '') !== '') {
            $rank += 2;
        }
        if (!empty($relation['display'])) {
            $rank++;
        }

        return $rank;
    }

    /**
     * Construye una clave navegable del portal solo si el dominio está aprobado.
     */
    private static function osCatalogResultKey(string $domainType, string $catalogCode, int $itemId): string
    {
        if ($itemId <= 0 || $catalogCode === '') {
            return '';
        }

        // OFTAR comparte `domain_type = medical` con prestaciones: el prefijo
        // del catálogo resuelve la ambigüedad antes de mirar el tipo.
        $domain = '';
        if (in_array($catalogCode, self::OFTAR_CATALOGS, true)) {
            $domain = 'oftar';
        } else {
            foreach (self::OS_CATALOG_DOMAIN_TYPES as $portalDomain => $types) {
                if (in_array($domainType, $types, true)) {
                    $domain = (string) $portalDomain;
                    break;
                }
            }
        }
        if ($domain === '' || !self::isValidDomain($domain)) {
            return '';
        }

        $candidate = $domain . ':os_catalog:' . $catalogCode . ':' . $itemId;
        return preg_match('/^[a-z0-9_]+:([A-Za-z0-9_.:-]{1,100})$/', $candidate) === 1
            ? $candidate
            : '';
    }

    /**
     * Valores vigentes e históricos del esquema arancelario. Sin SELECT sobre
     * esas tablas devuelve [] y la pestaña no se muestra.
     *
     * @return list<array<string, mixed>>
     */
    public static function itemValues(int $itemId): array
    {
        if (!self::ALLOW_RESTRICTED_SELECTS) {
            return [];
        }

        $pdo = PortalDatabase::connection();
        foreach (['os_fee_item', 'os_fee_schedule', 'os_pricing_unit'] as $table) {
            if (!self::tableExists($pdo, $table)) {
                return [];
            }
        }

        try {
            $statement = $pdo->prepare(
                'SELECT f.name AS schedule_name, f.currency, f.valid_from, f.valid_to,'
                . ' f.unit_monetary_value, p.code AS unit_code, p.name AS unit_name,'
                . ' fi.units_amount, fi.fixed_price, fi.expenses_amount'
                . ' FROM os_fee_item fi'
                . ' JOIN os_fee_schedule f ON f.id = fi.fee_schedule_id'
                . ' LEFT JOIN os_pricing_unit p ON p.id = fi.pricing_unit_id'
                . ' WHERE fi.item_id = ?'
                . ' ORDER BY f.valid_from DESC NULLS LAST, f.id DESC'
            );
            $statement->execute([$itemId]);
            $rows = $statement->fetchAll();
        } catch (PDOException) {
            return [];
        }

        $today = gmdate('Y-m-d');
        $values = [];
        foreach ($rows as $row) {
            $from = $row['valid_from'] !== null ? (string) $row['valid_from'] : null;
            $to = $row['valid_to'] !== null ? (string) $row['valid_to'] : null;
            $values[] = [
                'schedule' => (string) $row['schedule_name'],
                'currency' => (string) $row['currency'],
                'valid_from' => $from,
                'valid_to' => $to,
                'current' => ($from === null || $from <= $today) && ($to === null || $to >= $today),
                'unit_code' => $row['unit_code'] !== null ? (string) $row['unit_code'] : null,
                'unit_name' => $row['unit_name'] !== null ? (string) $row['unit_name'] : null,
                'units' => $row['units_amount'] !== null ? (string) $row['units_amount'] : null,
                'fixed_price' => $row['fixed_price'] !== null ? (string) $row['fixed_price'] : null,
                'expenses' => $row['expenses_amount'] !== null ? (string) $row['expenses_amount'] : null,
                'unit_monetary_value' => $row['unit_monetary_value'] !== null
                    ? (string) $row['unit_monetary_value']
                    : null,
            ];
        }

        return $values;
    }
}
