<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Services;

use OrigenSalud\Api\Http\ApiException;
use OrigenSalud\Api\Http\Request;
use PDO;

/**
 * Búsqueda unificada de terminología clínica.
 *
 * Fuentes físicas del esquema (sql/design.sql):
 *   - snomed_concepts / snomed_descriptions  -> SNOMED-CT
 *   - cie10_codes / cie10_descriptions       -> CIE-10
 *   - anmat_medicamentos                     -> catálogo ANMAT
 *   - laboratorio_practicas                  -> prácticas de laboratorio (LOINC)
 *   - vacunas_catalogo                       -> calendario de vacunas (NOMIVAC)
 *   - odontologia_prestaciones               -> nomenclador odontológico
 *   - prestaciones_medicas                   -> nomenclador PMO
 *   - programas_sociales                     -> programas y coberturas
 *   - imagenes_practicas                     -> prácticas de diagnóstico por imágenes
 *
 * Todas las fuentes se proyectan al mismo contrato de salida, de modo que el
 * cliente consume un único buscador sin conocer el origen físico del dato.
 * Agregar un catálogo nuevo solo requiere una entrada en CATALOG_SOURCES:
 * el contrato, el enrutador y la paginación no cambian.
 *
 * Nota: imagenes_estudios_pacs queda deliberadamente fuera del buscador porque
 * registra estudios de pacientes (PHI) y no terminología clínica.
 */
final class TerminologySearchService
{
    public const DOMAIN_SNOMED = 'snomed';
    public const DOMAIN_CIE10 = 'cie10';
    public const DOMAIN_ANMAT = 'anmat';
    public const DOMAIN_LABORATORIO = 'laboratorio';
    public const DOMAIN_VACUNAS = 'vacunas';
    public const DOMAIN_ODONTOLOGIA = 'odontologia';
    public const DOMAIN_PRESTACIONES = 'prestaciones';
    public const DOMAIN_PROGRAMAS = 'programas';
    public const DOMAIN_IMAGENES = 'imagenes';
    public const DOMAIN_NOMENCLADOR = 'nomenclador';
    public const DOMAIN_VADEMECUM = 'vademecum';
    public const DOMAIN_LOINC = 'loinc';
    public const DOMAIN_OFTAR = 'oftar';

    /** @var list<string> */
    public const DOMAINS = [
        self::DOMAIN_SNOMED,
        self::DOMAIN_CIE10,
        self::DOMAIN_ANMAT,
        self::DOMAIN_LABORATORIO,
        self::DOMAIN_VACUNAS,
        self::DOMAIN_ODONTOLOGIA,
        self::DOMAIN_PRESTACIONES,
        self::DOMAIN_PROGRAMAS,
        self::DOMAIN_IMAGENES,
        self::DOMAIN_NOMENCLADOR,
        self::DOMAIN_VADEMECUM,
        self::DOMAIN_LOINC,
        self::DOMAIN_OFTAR,
    ];

    /**
     * Dominios incluidos cuando el cliente no envía "domains".
     *
     * Se mantiene acotado a las tres fuentes núcleo para que la consulta por
     * defecto sea barata; el resto se pide explícitamente o con domains=all.
     */
    public const DEFAULT_DOMAINS = [
        self::DOMAIN_SNOMED,
        self::DOMAIN_CIE10,
        self::DOMAIN_ANMAT,
    ];

    private const MAX_OFFSET = 5000;
    private const MAX_DETAIL_RELATIONS = 50;
    private const MAX_REFSETS = 10;

    /** Caché por request de to_regclass() para no repetir consultas. */
    /** @var array<string, bool> */
    private array $tableChecks = [];

    /** @var list<string>|null */
    private ?array $refsetCodes = null;

    private ?LanguageCatalog $languageCatalog = null;

    private ?LanguageResolution $languageResolution = null;

    private const SNOMED_FSN = '900000000000003001';
    private const SNOMED_SYNONYM = '900000000000013009';

    /**
     * Catálogo público de dominios para GET /v1/domains.
     *
     * @var array<string, array{
     *     label: array{es: string, en: string},
     *     description: array{es: string, en: string},
     *     source: string,
     *     mode: string
     * }>
     */
    private const DOMAIN_CATALOG = [
        self::DOMAIN_SNOMED => [
            'label' => ['es' => 'SNOMED-CT', 'en' => 'SNOMED-CT'],
            'description' => [
                'es' => 'Ontología clínica completa: hallazgos, procedimientos, productos, sustancias y estructuras.',
                'en' => 'Full clinical ontology: findings, procedures, products, substances and body structures.',
            ],
            'source' => 'snomed',
            'mode' => 'full',
        ],
        self::DOMAIN_CIE10 => [
            'label' => ['es' => 'CIE-10', 'en' => 'ICD-10'],
            'description' => [
                'es' => 'Diagnósticos y procedimientos CIE-10 con descripciones bilingües y mapeo a SNOMED-CT.',
                'en' => 'ICD-10 diagnoses and procedures with bilingual descriptions and SNOMED-CT mappings.',
            ],
            'source' => 'cie10',
            'mode' => 'full',
        ],
        self::DOMAIN_ANMAT => [
            'label' => ['es' => 'ANMAT', 'en' => 'ANMAT'],
            'description' => [
                'es' => 'Catálogo argentino de medicamentos: nombre comercial, genérico, presentación y laboratorio.',
                'en' => 'Argentine medication catalog: commercial and generic names, presentation and laboratory.',
            ],
            'source' => 'anmat',
            'mode' => 'full',
        ],
        self::DOMAIN_LABORATORIO => [
            'label' => ['es' => 'Laboratorio', 'en' => 'Laboratory'],
            'description' => [
                'es' => 'Prácticas y determinaciones de laboratorio con código LOINC y vínculo SNOMED-CT.',
                'en' => 'Laboratory tests and measurements with LOINC codes and SNOMED-CT links.',
            ],
            'source' => 'laboratorio',
            'mode' => 'catalog',
        ],
        self::DOMAIN_VACUNAS => [
            'label' => ['es' => 'Vacunas', 'en' => 'Vaccines'],
            'description' => [
                'es' => 'Catálogo de vacunas e inmunizaciones con código oficial y esquema de dosis.',
                'en' => 'Vaccine and immunization catalog with official codes and dose schedules.',
            ],
            'source' => 'vacunas',
            'mode' => 'catalog',
        ],
        self::DOMAIN_ODONTOLOGIA => [
            'label' => ['es' => 'Odontología', 'en' => 'Dentistry'],
            'description' => [
                'es' => 'Nomenclador de prestaciones odontológicas y su vínculo con SNOMED-CT.',
                'en' => 'Dental procedure nomenclator and its SNOMED-CT links.',
            ],
            'source' => 'odontologia',
            'mode' => 'catalog',
        ],
        self::DOMAIN_PRESTACIONES => [
            'label' => ['es' => 'Prestaciones médicas', 'en' => 'Medical procedures'],
            'description' => [
                'es' => 'Nomenclador nacional / PMO de prestaciones médicas agrupadas por categoría.',
                'en' => 'National / PMO medical procedure nomenclator grouped by category.',
            ],
            'source' => 'prestaciones',
            'mode' => 'catalog',
        ],
        self::DOMAIN_PROGRAMAS => [
            'label' => ['es' => 'Programas sociales', 'en' => 'Social programs'],
            'description' => [
                'es' => 'Programas, coberturas y atributos poblacionales con código oficial.',
                'en' => 'Programs, coverage and population attributes with official codes.',
            ],
            'source' => 'programas',
            'mode' => 'catalog',
        ],
        self::DOMAIN_IMAGENES => [
            'label' => ['es' => 'Diagnóstico por imágenes', 'en' => 'Diagnostic imaging'],
            'description' => [
                'es' => 'Prácticas de imágenes con modalidad DICOM, LOINC y vínculo SNOMED-CT.',
                'en' => 'Imaging procedures with DICOM modality, LOINC and SNOMED-CT links.',
            ],
            'source' => 'imagenes',
            'mode' => 'catalog',
        ],
        self::DOMAIN_NOMENCLADOR => [
            'label' => ['es' => 'Nomencladores de Argentina', 'en' => 'Argentine Healthcare Nomenclators'],
            'description' => [
                'es' => 'Catálogo maestro de nomencladores argentinos: NN/PMO, NBU, NHPGD, ANDIS, Kinesiología y Salud Mental.',
                'en' => 'Master catalog of Argentine healthcare nomenclators: NN/PMO, NBU, NHPGD, ANDIS, Kinesiology and Mental Health.',
            ],
            'source' => 'nomencladores_argentina',
            'mode' => 'catalog',
        ],
        self::DOMAIN_VADEMECUM => [
            'label' => ['es' => 'Vademécum Comercial', 'en' => 'Commercial Drug Formulary'],
            'description' => [
                'es' => 'Vademécum farmacéutico comercial argentino con Número de Troquel, AlfaBeta, Kairos y GTIN.',
                'en' => 'Argentine commercial pharmaceutical formulary with Troquel, AlfaBeta, Kairos and GTIN.',
            ],
            'source' => 'vademecum_comercial',
            'mode' => 'catalog',
        ],
        self::DOMAIN_LOINC => [
            'label' => ['es' => 'LOINC (Observaciones y Laboratorio)', 'en' => 'LOINC (Observations & Laboratory)'],
            'description' => [
                'es' => 'Estándar internacional para pruebas de laboratorio, mediciones y observaciones clínicas con traducciones para Argentina y Latinoamérica.',
                'en' => 'International standard for identifying health measurements, observations, and laboratory documents with Argentine and Latin American translations.',
            ],
            'source' => 'loinc',
            'mode' => 'catalog',
        ],
        self::DOMAIN_OFTAR => [
            'label' => ['es' => 'OFTAR (Oftalmología)', 'en' => 'OFTAR (Ophthalmology)'],
            'description' => [
                'es' => 'Familia oftalmológica: OFTAR-PR (procedimientos con UVR) y OFTAR-DX (diagnósticos CIE-10 H00-H59, sin UVR).',
                'en' => 'Ophthalmic family: OFTAR-PR (procedures with UVR) and OFTAR-DX (CIE-10 H00-H59 diagnoses, no UVR).',
            ],
            'source' => 'oftar',
            'mode' => 'catalog',
        ],
    ];

    /**
     * Proyección de los catálogos locales al contrato unificado.
     *
     * Cada entrada describe la tabla y las expresiones SQL que alimentan las
     * columnas comunes. "filters" son las columnas que participan del ILIKE;
     * "metadata" agrega campos propios de la fuente al objeto metadata.
     *
     * Las expresiones son constantes internas: nunca provienen del cliente.
     *
     * @var array<string, array{
     *     table: string,
     *     code: string,
     *     term: string,
     *     subtitle: string|null,
     *     kind: string,
     *     filters: list<string>,
     *     metadata: array<string, string>
     * }>
     */
    private const CATALOG_SOURCES = [
        self::DOMAIN_LABORATORIO => [
            'table' => 'laboratorio_practicas',
            'code' => 't.codigo_loinc',
            'term' => 't.nombre_prueba',
            'subtitle' => 't.unidad_medida',
            'kind' => 'lab_test',
            'filters' => ['t.nombre_prueba', 't.codigo_loinc', 't.unidad_medida'],
            'metadata' => [
                'loinc_code' => 't.codigo_loinc',
                'unit' => 't.unidad_medida',
            ],
        ],
        self::DOMAIN_VACUNAS => [
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
        self::DOMAIN_ODONTOLOGIA => [
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
        self::DOMAIN_PRESTACIONES => [
            'table' => 'prestaciones_medicas',
            'code' => 't.codigo_prestacion',
            'term' => 't.nombre',
            'subtitle' => 't.categoria',
            'kind' => 'medical_procedure',
            'filters' => ['t.nombre', 't.categoria', 't.codigo_prestacion'],
            'metadata' => [
                'procedure_code' => 't.codigo_prestacion',
                'category' => 't.categoria',
            ],
        ],
        self::DOMAIN_PROGRAMAS => [
            'table' => 'programas_sociales',
            'code' => 't.codigo',
            'term' => 't.nombre_programa',
            'subtitle' => 'left(t.descripcion, 180)',
            'kind' => 'program',
            'filters' => ['t.nombre_programa', 't.codigo', 't.descripcion'],
            'metadata' => [
                'program_code' => 't.codigo',
                'description' => 't.descripcion',
            ],
        ],
        self::DOMAIN_IMAGENES => [
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
        self::DOMAIN_NOMENCLADOR => [
            'table' => 'nomencladores_argentina',
            'code' => 't.codigo',
            'term' => 't.descripcion',
            'subtitle' => 't.tipo_nomenclador || \' · \' || coalesce(t.capitulo, \'\')',
            'kind' => 'nomenclator_procedure',
            'filters' => ['t.descripcion', 't.codigo', 't.tipo_nomenclador', 'coalesce(t.capitulo, \'\')', 'CAST(t.snomed_concept_id AS text)'],
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
        self::DOMAIN_VADEMECUM => [
            'table' => 'vademecum_comercial',
            'code' => 't.numero_troquel',
            'term' => 't.nombre_comercial',
            'subtitle' => 't.monodroga || \' · \' || coalesce(t.presentacion, \'\')',
            'kind' => 'commercial_drug',
            'filters' => ['t.nombre_comercial', 't.monodroga', 't.numero_troquel', 'coalesce(t.codigo_alfabeta, \'\')', 'coalesce(t.codigo_kairos, \'\')', 'coalesce(t.codigo_barras_gtin, \'\')', 'CAST(t.snomed_concept_id AS text)'],
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
        self::DOMAIN_OFTAR => [
            'table' => 'v_oftar_search_catalog',
            'code' => 't.codigo',
            'term' => 't.termino',
            'subtitle' => 't.subtitulo',
            'kind' => 'oftar_concept',
            'filters' => ['t.termino', 't.codigo', 't.codigo_permanente', 't.subtitulo'],
            'metadata' => [
                'catalog_code' => 't.catalogo',
                'permanent_code' => 't.codigo_permanente',
                'family_code' => 't.familia',
                'category' => 't.categoria',
                'language_code' => 't.idioma',
                'review_status' => 't.estado_revision',
            ],
        ],
    ];

    public function __construct(private readonly PDO $db)
    {
    }

    /**
     * Catálogo estático de dominios soportados.
     *
     * @return list<array{id: string, label: array{es: string, en: string}, description: array{es: string, en: string}, source: string, mode: string}>
     */
    public static function catalog(): array
    {
        $catalog = [];

        foreach (self::DOMAIN_CATALOG as $id => $metadata) {
            $catalog[] = ['id' => $id] + $metadata;
        }

        return $catalog;
    }

    /**
     * Catálogo de refsets publicados para filtrado (04_codigos_opcional.sql).
     *
     * Devuelve sólo los refsets con `filter_code`, porque son los únicos que
     * el parámetro `refset` de /v1/search acepta.
     *
     * @return array{data: list<array<string, mixed>>, meta: array<string, mixed>}
     */
    public function refsetCatalog(): array
    {
        if (!$this->tableExists('public.sct2_refset_catalog')) {
            return [
                'data' => [],
                'meta' => [
                    'available' => false,
                    'message' => 'Ejecutá 03_postcarga.sql para habilitar el catálogo de refsets.',
                ],
            ];
        }

        $hasMembers = $this->tableExists('public.snomed_refset_member');
        $memberJoin = $hasMembers
            ? 'LEFT JOIN public.snomed_refset_member m ON m.refset_id = c.refset_id'
            : '';
        $activeExpr = $hasMembers ? 'count(m.concept_id) FILTER (WHERE m.active)' : '0';
        $totalExpr = $hasMembers ? 'count(m.concept_id)' : '0';

        $sql = "SELECT c.refset_id,\n"
            . "       c.name,\n"
            . "       c.category,\n"
            . "       c.description,\n"
            . "       c.filter_code,\n"
            . "       {$activeExpr} AS active_members,\n"
            . "       {$totalExpr} AS total_members\n"
            . "  FROM public.sct2_refset_catalog c\n"
            . "  {$memberJoin}\n"
            . ' WHERE c.filter_code IS NOT NULL'
            . ' GROUP BY c.refset_id, c.name, c.category, c.description, c.filter_code'
            . ' ORDER BY c.category, c.name';

        $rows = $this->db->query($sql)->fetchAll(PDO::FETCH_ASSOC);

        $data = array_map(static fn (array $row): array => [
            'filter_code' => (string) $row['filter_code'],
            'refset_id' => (string) $row['refset_id'],
            'name' => (string) $row['name'],
            'category' => (string) $row['category'],
            'description' => (string) $row['description'],
            'active_members' => (int) $row['active_members'],
            'total_members' => (int) $row['total_members'],
        ], $rows);

        return [
            'data' => $data,
            'meta' => [
                'available' => true,
                'published' => $hasMembers,
                'count' => count($data),
            ],
        ];
    }

    /**
     * Busca términos en uno o más dominios clínicos.
     *
     * Parámetros de entrada: q, domains (o domain), lang, limit, offset,
     * cie10_type ("diagnostico" | "procedimiento") y refset (códigos de filtro
     * publicados por 04_codigos_opcional.sql, separados por coma).
     *
     * @return array{data: list<array<string, mixed>>, meta: array<string, mixed>}
     */
    public function search(Request $request, ?string $forcedDomain = null): array
    {
        $startedAt = hrtime(true);

        $term = $this->normalizeTerm($request->query['q'] ?? null);
        $domains = $this->normalizeDomains($this->readDomains($request, $forcedDomain));
        $language = $this->contentLanguage($request);
        $limit = $this->integerQuery($request, 'limit', 20, 1, $this->maxLimit());
        $offset = $this->integerQuery($request, 'offset', 0, 0, self::MAX_OFFSET);
        $cie10Type = $this->normalizeCie10Type($this->readCie10Type($request));
        $refsets = $this->readRefsets($request, $domains);

        $useTrigram = mb_strlen($term, 'UTF-8') >= 3;
        $escapedTerm = $this->escapeLike($term);
        $contains = '%' . $escapedTerm . '%';
        $prefix = $escapedTerm . '%';

        [$unionSql, $parameters] = $this->buildUnion(
            $domains,
            $term,
            $contains,
            $prefix,
            $language,
            $cie10Type,
            $useTrigram,
            $refsets
        );

        $data = [];
        $hasMore = false;

        if ($unionSql !== '') {
            $sql = "SELECT * FROM (\n{$unionSql}\n) AS candidates\n"
                . " ORDER BY score DESC, length(term) ASC, term ASC\n"
                . ' LIMIT :page_limit OFFSET :page_offset';

            $statement = $this->db->prepare($sql);

            foreach ($parameters as $name => $value) {
                $statement->bindValue($name, $value, is_int($value) ? PDO::PARAM_INT : PDO::PARAM_STR);
            }

            // Se solicita un registro extra para calcular has_more sin COUNT(*).
            $statement->bindValue(':page_limit', $limit + 1, PDO::PARAM_INT);
            $statement->bindValue(':page_offset', $offset, PDO::PARAM_INT);
            $statement->execute();

            $rows = $statement->fetchAll();
            $hasMore = count($rows) > $limit;

            if ($hasMore) {
                array_pop($rows);
            }

            $data = array_map(fn (array $row): array => $this->hydrateRow($row), $rows);
        }

        $pageCounts = [];

        foreach ($data as $row) {
            $domain = (string) $row['domain'];
            $pageCounts[$domain] = ($pageCounts[$domain] ?? 0) + 1;
        }

        return [
            'data' => $data,
            'meta' => [
                'query' => $term,
                'language' => $language,
                'domains' => $domains,
                'cie10_type' => $cie10Type,
                'refsets' => $refsets,
                'limit' => $limit,
                'offset' => $offset,
                'returned' => count($data),
                'has_more' => $hasMore,
                'next_offset' => $hasMore ? $offset + $limit : null,
                'page_counts' => $pageCounts,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Detalle de un registro de cualquiera de los catálogos locales.
     *
     * Devuelve la misma forma que un resultado de búsqueda, sin score, más el
     * concepto SNOMED-CT vinculado (si el catálogo lo declara).
     *
     * @return array{data: array<string, mixed>, meta: array<string, mixed>}
     */
    public function findCatalog(string $domain, int $id, Request $request): array
    {
        $startedAt = hrtime(true);
        $language = $this->contentLanguage($request);

        if (!isset(self::CATALOG_SOURCES[$domain])) {
            throw ApiException::notFound('El dominio solicitado no expone detalle de catálogo.');
        }

        if ($id < 1) {
            throw ApiException::badRequest('El identificador del catálogo no es válido.');
        }

        $config = self::CATALOG_SOURCES[$domain];
        $p = 'detail';
        $select = $this->catalogSelect($domain, $p, 'CAST(1.0 AS float8)');

        $statement = $this->db->prepare(
            "SELECT {$select}\n"
            . "  FROM {$config['table']} t\n"
            . " WHERE t.id = :{$p}_id\n"
            . "   AND t.activo = TRUE\n"
            . ' LIMIT 1'
        );
        $statement->execute([
            ":{$p}_id" => $id,
            ":{$p}_label_lang" => $language,
            ":{$p}_label_syn" => self::SNOMED_SYNONYM,
        ]);
        $row = $statement->fetch();

        if ($row === false) {
            throw ApiException::notFound(
                'No se encontró el registro de ' . self::DOMAIN_CATALOG[$domain]['label']['es'] . ' solicitado.'
            );
        }

        $data = $this->hydrateRow($row);
        $snomedId = $data['metadata']['snomed_concept_id'] ?? null;
        $snomedTerm = $data['metadata']['snomed_term'] ?? null;

        $data['snomed_concept'] = $snomedId !== null
            ? [
                'concept_id' => (string) $snomedId,
                'term' => $snomedTerm !== null ? (string) $snomedTerm : null,
            ]
            : null;

        $related = (new RelatedCodesResolver($this->db))->resolve(
            $snomedId !== null ? (int) $snomedId : null,
            $domain,
            null,
            isset($data['code']) ? (string) $data['code'] : null,
            $language
        );
        $data['related_codes'] = $related['codes'];
        $data['uvr'] = $related['uvr'];

        unset($data['score']);

        return [
            'data' => $data,
            'meta' => [
                'language' => $language,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Detalle de un código CIE-10 con sus descripciones y mapeos a SNOMED-CT.
     *
     * @return array{data: array<string, mixed>, meta: array<string, mixed>}
     */
    public function findCie10(string $code, Request $request): array
    {
        $startedAt = hrtime(true);
        $language = $this->contentLanguage($request);
        $code = strtoupper(trim($code));

        if (preg_match('/^[A-Z][0-9]{2}(?:\.[0-9A-Z]{1,4}|[0-9A-Z]{0,3})$/', $code) !== 1) {
            throw ApiException::badRequest('El código CIE-10 no tiene un formato válido.');
        }

        $normalizedCode = $this->normalizeCode($code);

        $statement = $this->db->prepare(
            'SELECT id, codigo, tipo
               FROM cie10_codes
              WHERE upper(codigo) = :code_exact
                 OR replace(upper(codigo), \'.\', \'\') = :code_normalized
              ORDER BY (upper(codigo) = :code_order) DESC, length(codigo) ASC
              LIMIT 1'
        );
        $statement->execute([
            ':code_exact' => $code,
            ':code_normalized' => $normalizedCode,
            ':code_order' => $code,
        ]);
        $row = $statement->fetch();

        if ($row === false) {
            throw ApiException::notFound('No se encontró el código CIE-10 solicitado.');
        }

        $descriptionsStatement = $this->db->prepare(
            'SELECT language_code, descripcion
               FROM cie10_descriptions
              WHERE cie10_id = :cie10_id
              ORDER BY language_code ASC, length(descripcion) ASC, descripcion ASC'
        );
        $descriptionsStatement->execute([':cie10_id' => (int) $row['id']]);

        $descriptions = [];

        foreach ($descriptionsStatement->fetchAll() as $description) {
            $descriptionLanguage = (string) $description['language_code'];
            $descriptions[$descriptionLanguage] ??= [];
            $descriptions[$descriptionLanguage][] = (string) $description['descripcion'];
        }

        $mappingsStatement = $this->db->prepare(
            'SELECT CAST(s.id AS text) AS concept_id,
                    (
                        SELECT d.term
                          FROM snomed_descriptions d
                         WHERE d.concept_id = s.id
                           AND d.active = TRUE
                           AND d.language_code = :language
                         ORDER BY (d.type_id = CAST(:synonym AS bigint)) DESC,
                                  length(d.term) ASC,
                                  d.term ASC
                         LIMIT 1
                    ) AS term
               FROM map_snomed_cie10 m
               INNER JOIN snomed_concepts s ON s.id = m.snomed_concept_id
              WHERE m.cie10_id = :cie10_id
                AND s.active = TRUE
              ORDER BY term ASC NULLS LAST
              LIMIT ' . self::MAX_DETAIL_RELATIONS
        );
        $mappingsStatement->execute([
            ':language' => $language,
            ':synonym' => self::SNOMED_SYNONYM,
            ':cie10_id' => (int) $row['id'],
        ]);

        return [
            'data' => [
                'domain' => self::DOMAIN_CIE10,
                'id' => (string) $row['id'],
                'code' => (string) $row['codigo'],
                'type' => (string) $row['tipo'],
                'descriptions' => $descriptions,
                'snomed_concepts' => array_map(
                    static fn (array $mapping): array => [
                        'concept_id' => (string) $mapping['concept_id'],
                        'term' => $mapping['term'] !== null ? (string) $mapping['term'] : null,
                    ],
                    $mappingsStatement->fetchAll()
                ),
            ],
            'meta' => [
                'language' => $language,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Detalle de un medicamento ANMAT y su vínculo opcional con SNOMED-CT.
     *
     * @return array{data: array<string, mixed>, meta: array<string, mixed>}
     */
    public function findAnmat(int $id, Request $request): array
    {
        $startedAt = hrtime(true);
        $language = $this->contentLanguage($request);

        if ($id < 1) {
            throw ApiException::badRequest('El identificador ANMAT no es válido.');
        }

        $statement = $this->db->prepare(
            'SELECT id,
                    certificado_number,
                    nombre_generico,
                    nombre_comercial,
                    forma_farmaceutica,
                    presentacion,
                    laboratorio,
                    CAST(snomed_concept_id AS text) AS snomed_concept_id
               FROM anmat_medicamentos
              WHERE id = :id
              LIMIT 1'
        );
        $statement->execute([':id' => $id]);
        $row = $statement->fetch();

        if ($row === false) {
            throw ApiException::notFound('No se encontró el medicamento ANMAT solicitado.');
        }

        $snomedConcept = null;

        if ($row['snomed_concept_id'] !== null) {
            $conceptStatement = $this->db->prepare(
                'SELECT CAST(s.id AS text) AS concept_id,
                        (
                            SELECT d.term
                              FROM snomed_descriptions d
                             WHERE d.concept_id = s.id
                               AND d.active = TRUE
                               AND d.language_code = :language
                             ORDER BY (d.type_id = CAST(:synonym AS bigint)) DESC,
                                      length(d.term) ASC,
                                      d.term ASC
                             LIMIT 1
                        ) AS term
                   FROM snomed_concepts s
                  WHERE s.id = CAST(:id AS bigint)
                    AND s.active = TRUE
                  LIMIT 1'
            );
            $conceptStatement->execute([
                ':language' => $language,
                ':synonym' => self::SNOMED_SYNONYM,
                ':id' => (string) $row['snomed_concept_id'],
            ]);
            $concept = $conceptStatement->fetch();

            if ($concept !== false) {
                $snomedConcept = [
                    'concept_id' => (string) $concept['concept_id'],
                    'term' => $concept['term'] !== null ? (string) $concept['term'] : null,
                ];
            }
        }

        return [
            'data' => [
                'domain' => self::DOMAIN_ANMAT,
                'id' => (string) $row['id'],
                'certificate' => (string) $row['certificado_number'],
                'commercial_name' => (string) $row['nombre_comercial'],
                'generic_name' => (string) $row['nombre_generico'],
                'pharmaceutical_form' => $row['forma_farmaceutica'] !== null
                    ? (string) $row['forma_farmaceutica']
                    : null,
                'presentation' => $row['presentacion'] !== null ? (string) $row['presentacion'] : null,
                'laboratory' => $row['laboratorio'] !== null ? (string) $row['laboratorio'] : null,
                'snomed_concept' => $snomedConcept,
            ],
            'meta' => [
                'language' => $language,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Catálogo clínico de diagnósticos odontológicos DENTAR-DX (CIE-10 / SNOMED-CT).
     * Permite filtrar por texto general (q), código SNOMED-CT (snomed) o código CIE-10 (cie10).
     *
     * @return array{data: list<array<string, mixed>>, meta: array<string, mixed>}
     */
    public function searchDentalDiagnoses(Request $request): array
    {
        $startedAt = hrtime(true);
        $language = $this->requestedLanguage($request);
        $query = trim((string) ($request->query['q'] ?? ''));
        $snomed = trim((string) ($request->query['snomed'] ?? $request->query['snomed_id'] ?? ''));
        $cie10 = trim((string) ($request->query['cie10'] ?? $request->query['cie10_code'] ?? ''));

        $sql = 'SELECT d.code AS dentar_diagnosis_code,
                       COALESCE(dtp.term, d.clinical_name) AS clinical_name,
                       dv.definition,
                       dv.clinical_criteria,
                       dcat.code AS category_code,
                       dcatv.name AS category_name,
                       m_cie.external_code AS cie10_code,
                       m_cie.external_display AS cie10_description,
                       m_sct.external_code AS snomed_concept_id,
                       m_sct.external_display AS snomed_term
                  FROM dentar_diagnosis d
                  JOIN dentar_catalog dcatl ON dcatl.id = d.catalog_id AND dcatl.code = \'dentar-dx\'
                  LEFT JOIN dentar_diagnosis_version dv
                    ON dv.diagnosis_id = d.id
                   AND dv.version_number = (
                       SELECT max(v2.version_number)
                         FROM dentar_diagnosis_version v2
                        WHERE v2.diagnosis_id = d.id
                          AND v2.approval_status = \'approved\'
                   )
                  LEFT JOIN LATERAL (
                       SELECT dt.term
                         FROM dentar_diagnosis_term dt
                        WHERE dt.diagnosis_id = d.id
                          AND dt.term_type = \'preferred\'
                          AND dt.language = :language
                        ORDER BY dt.id DESC
                        LIMIT 1
                  ) dtp ON TRUE
                  LEFT JOIN dentar_category dcat ON dcat.id = d.category_id
                  LEFT JOIN dentar_category_version dcatv
                    ON dcatv.category_id = dcat.id
                   AND dcatv.language = :language
                   AND dcatv.version_number = (
                       SELECT max(v2.version_number)
                         FROM dentar_category_version v2
                        WHERE v2.category_id = dcat.id
                          AND v2.language = :language
                   )
                  LEFT JOIN dentar_diagnosis_mapping m_cie ON m_cie.diagnosis_id = d.id AND m_cie.system_code = \'CIE-10\'
                  LEFT JOIN dentar_diagnosis_mapping m_sct ON m_sct.diagnosis_id = d.id AND m_sct.system_code = \'SNOMED-CT\'';

        $whereClauses = [];
        $params = [];

        if ($query !== '') {
            $escaped = '%' . $this->escapeLike($query) . '%';
            $whereClauses[] = '(COALESCE(dtp.term, d.clinical_name) ILIKE :q
                             OR d.code ILIKE :q
                             OR m_cie.external_code ILIKE :q
                             OR m_cie.external_display ILIKE :q
                             OR m_sct.external_code ILIKE :q
                             OR m_sct.external_display ILIKE :q
                             OR EXISTS (
                                 SELECT 1
                                   FROM dentar_diagnosis_term dtq
                                  WHERE dtq.diagnosis_id = d.id
                                    AND dtq.language = :language
                                    AND dtq.term ILIKE :q
                             ))';
            $params[':q'] = $escaped;
        }

        if ($snomed !== '') {
            $whereClauses[] = 'm_sct.external_code = :snomed_filter';
            $params[':snomed_filter'] = $snomed;
        }

        if ($cie10 !== '') {
            $cieExact = strtoupper($cie10);
            $cieNorm = $this->normalizeCode($cie10);
            $whereClauses[] = '(upper(m_cie.external_code) = :cie_exact OR replace(upper(m_cie.external_code), \'.\', \'\') = :cie_norm)';
            $params[':cie_exact'] = $cieExact;
            $params[':cie_norm'] = $cieNorm;
        }

        if (!empty($whereClauses)) {
            $sql .= ' WHERE ' . implode(' AND ', $whereClauses);
        }

        $sql .= ' ORDER BY d.id ASC';

        $params[':language'] = $language;

        try {
            $stmt = $this->db->prepare($sql);
            $stmt->execute($params);
            $rows = $stmt->fetchAll();
        } catch (\PDOException $e) {
            throw ApiException::internalError();
        }

        $results = [];
        foreach ($rows as $r) {
            $results[] = [
                'catalog' => 'DENTAR-DX',
                'code' => $r['dentar_diagnosis_code'],
                'clinical_name' => $r['clinical_name'],
                'definition' => $r['definition'],
                'clinical_criteria' => $r['clinical_criteria'],
                'category' => $r['category_name'] !== null ? [
                    'code' => $r['category_code'],
                    'name' => $r['category_name'],
                ] : null,
                'cie10' => $r['cie10_code'] !== null ? [
                    'code' => $r['cie10_code'],
                    'description' => $r['cie10_description'],
                ] : null,
                'snomed_ct' => $r['snomed_concept_id'] !== null ? [
                    'concept_id' => (string) $r['snomed_concept_id'],
                    'term' => $r['snomed_term'],
                ] : null,
            ];
        }

        return [
            'data' => $results,
            'meta' => [
                'total' => count($results),
                'query' => $query !== '' ? $query : null,
                'snomed' => $snomed !== '' ? $snomed : null,
                'cie10' => $cie10 !== '' ? $cie10 : null,
                'language' => $language,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Detalle de un diagnóstico odontológico DENTAR con sus prestaciones indicadas.
     * Admite búsqueda por SCTID (SNOMED-CT), código CIE-10 (K02), código DENTAR-DX (DNT-DX-000005) o ID.
     *
     * @return array{data: array<string, mixed>, meta: array<string, mixed>}
     */
    public function findDentalDiagnosis(string $identifier, Request $request): array
    {
        $startedAt = hrtime(true);
        $language = $this->requestedLanguage($request);
        $identifier = trim($identifier);

        if ($identifier === '') {
            throw ApiException::badRequest('El identificador del diagnóstico no puede estar vacío.');
        }

        $sql = 'SELECT d.id AS diagnosis_id,
                       d.code AS dentar_diagnosis_code,
                       COALESCE(dtp.term, d.clinical_name) AS clinical_name,
                       dv.definition,
                       dv.clinical_criteria,
                       dcat.code AS diagnosis_category_code,
                       dcatv.name AS diagnosis_category_name,
                       m_cie.external_code AS cie10_code,
                       m_cie.external_display AS cie10_description,
                       m_sct.external_code AS snomed_concept_id,
                       m_sct.external_display AS snomed_term,
                       c.code AS dentar_procedure_code,
                       t.term AS procedure_name,
                       pcat.name AS procedure_category,
                       m_ar.external_code AS nomenclador_argentino,
                       m_cdt.external_code AS cdt_code,
                       m_sct_proc.external_code AS snomed_procedure_code,
                       cd.relationship_type,
                       cd.clinical_rationale
                  FROM dentar_diagnosis d
                  JOIN dentar_catalog dl ON dl.id = d.catalog_id AND dl.code = \'dentar-dx\'
                  LEFT JOIN dentar_diagnosis_version dv
                    ON dv.diagnosis_id = d.id
                   AND dv.version_number = (
                       SELECT max(v2.version_number)
                         FROM dentar_diagnosis_version v2
                        WHERE v2.diagnosis_id = d.id
                          AND v2.approval_status = \'approved\'
                   )
                  LEFT JOIN LATERAL (
                       SELECT dt.term
                         FROM dentar_diagnosis_term dt
                        WHERE dt.diagnosis_id = d.id
                          AND dt.term_type = \'preferred\'
                          AND dt.language = :language
                        ORDER BY dt.id DESC
                        LIMIT 1
                  ) dtp ON TRUE
                  LEFT JOIN dentar_category dcat ON dcat.id = d.category_id
                  LEFT JOIN dentar_category_version dcatv
                    ON dcatv.category_id = dcat.id
                   AND dcatv.language = :language
                   AND dcatv.version_number = (
                       SELECT max(v2.version_number)
                         FROM dentar_category_version v2
                        WHERE v2.category_id = dcat.id
                          AND v2.language = :language
                   )
                  LEFT JOIN dentar_diagnosis_mapping m_cie ON m_cie.diagnosis_id = d.id AND m_cie.system_code = \'CIE-10\'
                  LEFT JOIN dentar_diagnosis_mapping m_sct ON m_sct.diagnosis_id = d.id AND m_sct.system_code = \'SNOMED-CT\'
                  LEFT JOIN dentar_concept_diagnosis cd ON cd.diagnosis_id = d.id
                  LEFT JOIN dentar_concept c
                    ON c.id = cd.concept_id
                   AND c.catalog_id = dentar_catalog_id(\'dentar-pr\')
                  LEFT JOIN LATERAL (
                       SELECT cv.id
                         FROM dentar_concept_version cv
                        WHERE cv.concept_id = c.id
                          AND cv.approval_status = \'approved\'
                        ORDER BY cv.version_number DESC
                        LIMIT 1
                  ) cv ON TRUE
                  LEFT JOIN LATERAL (
                       SELECT t.term
                         FROM dentar_term t
                        WHERE t.concept_version_id = cv.id
                          AND t.term_type = \'preferred\'
                          AND t.language = :language
                        ORDER BY t.id DESC
                        LIMIT 1
                  ) t ON TRUE
                  LEFT JOIN dentar_concept_category cc ON cc.concept_version_id = cv.id AND cc.is_primary = TRUE
                  LEFT JOIN dentar_category pdcat ON pdcat.id = cc.category_id
                  LEFT JOIN dentar_category_version pcat
                    ON pcat.category_id = pdcat.id
                   AND pcat.language = :language
                   AND pcat.version_number = (
                       SELECT max(v2.version_number)
                         FROM dentar_category_version v2
                        WHERE v2.category_id = pdcat.id
                          AND v2.language = :language
                   )
                  LEFT JOIN dentar_concept_mapping m_ar ON m_ar.concept_version_id = cv.id AND m_ar.system_code = \'NOMENCLADOR-AR\'
                  LEFT JOIN dentar_concept_mapping m_cdt ON m_cdt.concept_version_id = cv.id AND m_cdt.system_code = \'CDT-2025\'
                  LEFT JOIN dentar_concept_mapping m_sct_proc ON m_sct_proc.concept_version_id = cv.id AND m_sct_proc.system_code = \'SNOMED-CT\'
                 WHERE d.code = :ident
                    OR m_sct.external_code = :ident
                    OR upper(m_cie.external_code) = upper(:ident)
                    OR replace(upper(m_cie.external_code), \'.\', \'\') = :ident_clean
                    OR d.id = :ident_int
                 ORDER BY cd.relationship_type ASC, c.code ASC';

        $identClean = $this->normalizeCode($identifier);
        $identInt = ctype_digit($identifier) ? (int) $identifier : -1;

        try {
            $stmt = $this->db->prepare($sql);
            $stmt->execute([
                ':ident' => $identifier,
                ':ident_clean' => $identClean,
                ':ident_int' => $identInt,
                ':language' => $language,
            ]);
            $rows = $stmt->fetchAll();
        } catch (\PDOException $e) {
            throw ApiException::internalError();
        }

        if (empty($rows)) {
            throw ApiException::notFound(
                "No se encontró el diagnóstico odontológico solicitado para '{$identifier}'."
            );
        }

        $first = $rows[0];
        $indicatedProcedures = [];

        foreach ($rows as $r) {
            if ($r['dentar_procedure_code'] !== null) {
                $indicatedProcedures[] = [
                    'catalog' => 'DENTAR-PR',
                    'dentar_code' => $r['dentar_procedure_code'],
                    'name' => $r['procedure_name'],
                    'category' => $r['procedure_category'],
                    'nomenclador_argentino' => $r['nomenclador_argentino'],
                    'cdt_code' => $r['cdt_code'],
                    'snomed_concept_id' => $r['snomed_procedure_code'],
                    'relationship_type' => $r['relationship_type'],
                    'clinical_rationale' => $r['clinical_rationale'],
                ];
            }
        }

        return [
            'data' => [
                'catalog' => 'DENTAR-DX',
                'diagnosis' => [
                    'dentar_diagnosis_code' => $first['dentar_diagnosis_code'],
                    'clinical_name' => $first['clinical_name'],
                    'definition' => $first['definition'],
                    'clinical_criteria' => $first['clinical_criteria'],
                    'category' => $first['diagnosis_category_name'] !== null ? [
                        'code' => $first['diagnosis_category_code'],
                        'name' => $first['diagnosis_category_name'],
                    ] : null,
                    'cie10' => $first['cie10_code'] !== null ? [
                        'code' => $first['cie10_code'],
                        'description' => $first['cie10_description'],
                    ] : null,
                    'snomed_ct' => $first['snomed_concept_id'] !== null ? [
                        'concept_id' => (string) $first['snomed_concept_id'],
                        'term' => $first['snomed_term'],
                    ] : null,
                ],
                'indicated_procedures' => $indicatedProcedures,
            ],
            'meta' => [
                'total_indicated_procedures' => count($indicatedProcedures),
                'language' => $language,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Búsqueda integral odontológica por código SNOMED-CT (SCTID).
     * Devuelve tanto procedimientos/prácticas como diagnósticos bucales vinculados a ese SCTID.
     *
     * @return array{data: array<string, mixed>, meta: array<string, mixed>}
     */
    public function findDentalBySnomed(string $snomedId, Request $request): array
    {
        $startedAt = hrtime(true);
        $language = $this->requestedLanguage($request);
        $snomedId = trim($snomedId);

        if (preg_match('/^[0-9]{6,18}$/', $snomedId) !== 1) {
            throw ApiException::badRequest('El identificador no es un SCTID de SNOMED-CT válido.');
        }

        // 1. Buscar si corresponde a una o más prácticas odontológicas
        $procSql = 'SELECT DISTINCT
                           c.code AS dentar_code,
                           tp.term AS prestacion_nombre,
                           m_ar.external_code AS codigo_nomenclador_ar,
                           m_cdt.external_code AS codigo_cdt,
                           pcat.name AS categoria
                      FROM dentar_concept c
                      JOIN dentar_catalog cl ON cl.id = c.catalog_id AND cl.code = \'dentar-pr\'
                      JOIN LATERAL (
                           SELECT cv.id
                             FROM dentar_concept_version cv
                            WHERE cv.concept_id = c.id
                              AND cv.approval_status = \'approved\'
                            ORDER BY cv.version_number DESC
                            LIMIT 1
                      ) cv ON TRUE
                      JOIN LATERAL (
                           SELECT t.term
                             FROM dentar_term t
                            WHERE t.concept_version_id = cv.id
                              AND t.term_type = \'preferred\'
                              AND t.language = :language
                            ORDER BY t.id DESC
                            LIMIT 1
                      ) tp ON TRUE
                      LEFT JOIN dentar_concept_category cc ON cc.concept_version_id = cv.id AND cc.is_primary = TRUE
                      LEFT JOIN dentar_category pdcat ON pdcat.id = cc.category_id
                      LEFT JOIN dentar_category_version pcat
                        ON pcat.category_id = pdcat.id
                       AND pcat.language = :language
                       AND pcat.version_number = (
                           SELECT max(v2.version_number)
                             FROM dentar_category_version v2
                            WHERE v2.category_id = pdcat.id
                              AND v2.language = :language
                       )
                      LEFT JOIN dentar_concept_mapping m_ar ON m_ar.concept_version_id = cv.id AND m_ar.system_code = \'NOMENCLADOR-AR\'
                      LEFT JOIN dentar_concept_mapping m_cdt ON m_cdt.concept_version_id = cv.id AND m_cdt.system_code = \'CDT-2025\'
                      LEFT JOIN dentar_concept_mapping m_sct ON m_sct.concept_version_id = cv.id AND m_sct.system_code = \'SNOMED-CT\'
                     WHERE m_sct.external_code = :sct
                        OR EXISTS (
                            SELECT 1 FROM odontologia_prestaciones op
                             WHERE op.snomed_concept_id = CAST(:sct_num AS bigint)
                               AND op.codigo = m_ar.external_code
                        )
                     ORDER BY c.code ASC';

        // 2. Buscar si corresponde a uno o más diagnósticos odontológicos
        $diagSql = 'SELECT d.code AS dentar_diagnosis_code,
                           COALESCE(dtp.term, d.clinical_name) AS clinical_name,
                           dv.definition,
                           dv.clinical_criteria,
                           dcat.code AS category_code,
                           dcatv.name AS category_name,
                           m_cie.external_code AS cie10_code,
                           m_cie.external_display AS cie10_description,
                           m_sct.external_code AS snomed_concept_id,
                           m_sct.external_display AS snomed_term
                      FROM dentar_diagnosis d
                      JOIN dentar_catalog dl ON dl.id = d.catalog_id AND dl.code = \'dentar-dx\'
                      LEFT JOIN dentar_diagnosis_version dv
                        ON dv.diagnosis_id = d.id
                       AND dv.version_number = (
                           SELECT max(v2.version_number)
                             FROM dentar_diagnosis_version v2
                            WHERE v2.diagnosis_id = d.id
                              AND v2.approval_status = \'approved\'
                       )
                      LEFT JOIN LATERAL (
                           SELECT dt.term
                             FROM dentar_diagnosis_term dt
                            WHERE dt.diagnosis_id = d.id
                              AND dt.term_type = \'preferred\'
                              AND dt.language = :language
                            ORDER BY dt.id DESC
                            LIMIT 1
                      ) dtp ON TRUE
                      LEFT JOIN dentar_category dcat ON dcat.id = d.category_id
                      LEFT JOIN dentar_category_version dcatv
                        ON dcatv.category_id = dcat.id
                       AND dcatv.language = :language
                       AND dcatv.version_number = (
                           SELECT max(v2.version_number)
                             FROM dentar_category_version v2
                            WHERE v2.category_id = dcat.id
                              AND v2.language = :language
                       )
                      JOIN dentar_diagnosis_mapping m_sct ON m_sct.diagnosis_id = d.id AND m_sct.system_code = \'SNOMED-CT\'
                      LEFT JOIN dentar_diagnosis_mapping m_cie ON m_cie.diagnosis_id = d.id AND m_cie.system_code = \'CIE-10\'
                     WHERE m_sct.external_code = :sct
                     ORDER BY d.code ASC';

        try {
            $stmtProc = $this->db->prepare($procSql);
            $stmtProc->execute([
                ':sct' => $snomedId,
                ':sct_num' => $snomedId,
                ':language' => $language,
            ]);
            $procedures = $stmtProc->fetchAll();

            $stmtDiag = $this->db->prepare($diagSql);
            $stmtDiag->execute([':sct' => $snomedId, ':language' => $language]);
            $diagnoses = $stmtDiag->fetchAll();
        } catch (\PDOException $e) {
            throw ApiException::internalError();
        }

        if (empty($procedures) && empty($diagnoses)) {
            throw ApiException::notFound(
                "No se encontraron prácticas ni diagnósticos odontológicos vinculados al concepto SNOMED-CT '{$snomedId}'."
            );
        }

        $formattedProcedures = array_map(static fn (array $r): array => [
            'catalog' => 'DENTAR-PR',
            'dentar_code' => $r['dentar_code'],
            'name' => $r['prestacion_nombre'],
            'nomenclador_argentino' => $r['codigo_nomenclador_ar'],
            'cdt_code' => $r['codigo_cdt'],
            'category' => $r['categoria'],
        ], $procedures);

        $formattedDiagnoses = array_map(static fn (array $r): array => [
            'catalog' => 'DENTAR-DX',
            'dentar_diagnosis_code' => $r['dentar_diagnosis_code'],
            'clinical_name' => $r['clinical_name'],
            'definition' => $r['definition'],
            'clinical_criteria' => $r['clinical_criteria'],
            'category' => $r['category_name'] !== null ? [
                'code' => $r['category_code'],
                'name' => $r['category_name'],
            ] : null,
            'cie10' => $r['cie10_code'] !== null ? [
                'code' => $r['cie10_code'],
                'description' => $r['cie10_description'],
            ] : null,
            'snomed_ct' => [
                'concept_id' => (string) $r['snomed_concept_id'],
                'term' => $r['snomed_term'],
            ],
        ], $diagnoses);

        return [
            'data' => [
                'snomed_concept_id' => $snomedId,
                'has_procedures' => !empty($formattedProcedures),
                'has_diagnoses' => !empty($formattedDiagnoses),
                'procedures' => $formattedProcedures,
                'diagnoses' => $formattedDiagnoses,
            ],
            'meta' => [
                'procedures_count' => count($formattedProcedures),
                'diagnoses_count' => count($formattedDiagnoses),
                'language' => $language,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Obtiene los diagnósticos CIE-10 / SNOMED-CT asociados y la justificación clínica
     * de una prestación odontológica DENTAR / Nomenclador / CDT / SNOMED-CT.
     *
     * @return array{data: array<string, mixed>, meta: array<string, mixed>}
     */
    public function findDentalDiagnoses(string $identifier, Request $request): array
    {
        $startedAt = hrtime(true);
        $language = $this->contentLanguage($request);
        $identifier = trim($identifier);

        if ($identifier === '') {
            throw ApiException::badRequest('El identificador de la prestación no puede estar vacío.');
        }

        // Buscar en la vista v_dentar_procedimiento_diagnostico por:
        // 1. dentar_code (ej. DNT-PR-000001)
        // 2. codigo_nomenclador_ar (ej. 01.01)
        // 3. codigo_cdt (ej. D0150)
        // 4. snomed_ct_practica (ej. 424759004)
        // 5. Si es numérico corto, verificar si coincide con odontologia_prestaciones.id para obtener su código
        // 6. Si es numérico de 6 a 18 dígitos, verificar si coincide con odontologia_prestaciones.snomed_concept_id
        $procedureCode = $identifier;
        if (ctype_digit($identifier)) {
            if (strlen($identifier) >= 6) {
                $stmtSct = $this->db->prepare(
                    'SELECT codigo FROM odontologia_prestaciones WHERE snomed_concept_id = CAST(:sct AS bigint) LIMIT 1'
                );
                $stmtSct->execute([':sct' => $identifier]);
                $foundCode = $stmtSct->fetchColumn();
                if ($foundCode !== false) {
                    $procedureCode = (string) $foundCode;
                }
            } else {
                $stmtId = $this->db->prepare(
                    'SELECT codigo FROM odontologia_prestaciones WHERE id = :id LIMIT 1'
                );
                $stmtId->execute([':id' => (int) $identifier]);
                $foundCode = $stmtId->fetchColumn();
                if ($foundCode !== false) {
                    $procedureCode = (string) $foundCode;
                }
            }
        }

        $statement = $this->db->prepare(
            'SELECT catalogo_prestacion,
                    dentar_code,
                    prestacion_nombre,
                    codigo_nomenclador_ar,
                    codigo_cdt,
                    categoria,
                    catalogo_diagnostico,
                    codigo_diagnostico_dentar,
                    diagnostico_nombre,
                    cie10_codigo,
                    cie10_descripcion,
                    snomed_ct_codigo,
                    tipo_relacion,
                    justificacion_clinica
               FROM v_dentar_procedimiento_diagnostico
              WHERE dentar_code = :ident
                 OR codigo_nomenclador_ar = :ident
                 OR upper(codigo_cdt) = upper(:ident)
                 OR snomed_ct_practica = :ident
                 OR codigo_nomenclador_ar = :proc_code
              ORDER BY tipo_relacion ASC, cie10_codigo ASC'
        );

        try {
            $statement->execute([
                ':ident' => $identifier,
                ':proc_code' => $procedureCode,
            ]);
            $rows = $statement->fetchAll();
        } catch (\PDOException $e) {
            throw ApiException::internalError();
        }

        if (empty($rows)) {
            throw ApiException::notFound(
                "No se encontraron prestaciones o diagnósticos odontológicos para el identificador '{$identifier}'."
            );
        }

        $first = $rows[0];
        $diagnoses = [];
        foreach ($rows as $r) {
            if ($r['codigo_diagnostico_dentar'] !== null) {
                $diagnoses[] = [
                    'catalog' => 'DENTAR-DX',
                    'dentar_diagnosis_code' => $r['codigo_diagnostico_dentar'],
                    'name' => $r['diagnostico_nombre'],
                    'cie10' => $r['cie10_codigo'] !== null ? [
                        'code' => $r['cie10_codigo'],
                        'description' => $r['cie10_descripcion'],
                    ] : null,
                    'snomed_ct' => $r['snomed_ct_codigo'] !== null ? [
                        'concept_id' => (string) $r['snomed_ct_codigo'],
                    ] : null,
                    'relationship_type' => $r['tipo_relacion'],
                    'clinical_rationale' => $r['justificacion_clinica'],
                ];
            }
        }

        return [
            'data' => [
                'procedure' => [
                    'catalog' => 'DENTAR-PR',
                    'dentar_code' => $first['dentar_code'],
                    'name' => $first['prestacion_nombre'],
                    'nomenclador_argentino' => $first['codigo_nomenclador_ar'],
                    'cdt_code' => $first['codigo_cdt'],
                    'category' => $first['categoria'],
                ],
                'clinical_justifications' => $diagnoses,
            ],
            'meta' => [
                'total_diagnoses' => count($diagnoses),
                'language' => $language,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Búsqueda en Nomencladores Prestacionales de Argentina.
     * Tipos válidos: NN_PMO, NBU, NHPGD, ANDIS, KINESIOLOGIA, SALUD_MENTAL (o null para buscar en todos).
     *
     * @return array{data: list<array<string, mixed>>, meta: array<string, mixed>}
     */
    public function searchNomencladorArgentina(Request $request): array
    {
        $startedAt = hrtime(true);
        $language = $this->contentLanguage($request);
        $query = trim((string) ($request->query['q'] ?? ''));
        $tipo = trim((string) ($request->query['type'] ?? $request->query['tipo'] ?? ''));
        $limit = $this->readIntParam($request->query['limit'] ?? null, 20, 1, $this->maxLimit(), 'limit');

        $sql = 'SELECT t.id,
                       t.tipo_nomenclador,
                       t.codigo,
                       t.capitulo,
                       t.descripcion,
                       t.unidad_tipo,
                       CAST(t.unidad_valor AS text) AS unidad_valor,
                       CAST(t.gastos_valor AS text) AS gastos_valor,
                       CAST(t.snomed_concept_id AS text) AS snomed_concept_id,
                       t.codigo_loinc
                  FROM nomencladores_argentina t
                 WHERE t.activo = TRUE';

        $params = [];
        $where = [];

        if ($query !== '') {
            $escaped = '%' . $this->escapeLike($query) . '%';
            $where[] = '(t.descripcion ILIKE :term OR t.codigo ILIKE :term OR CAST(t.snomed_concept_id AS text) = :exact_code)';
            $params[':term'] = $escaped;
            $params[':exact_code'] = $query;
        }

        if ($tipo !== '') {
            $where[] = 'upper(t.tipo_nomenclador) = :tipo';
            $params[':tipo'] = strtoupper($tipo);
        }

        if (!empty($where)) {
            $sql .= ' AND ' . implode(' AND ', $where);
        }

        if ($query !== '') {
            $sql .= ' ORDER BY (t.codigo ILIKE :code_prefix) DESC, similarity(t.descripcion, :sim) DESC, t.id ASC';
            $params[':code_prefix'] = $this->escapeLike($query) . '%';
            $params[':sim'] = $query;
        } else {
            $sql .= ' ORDER BY t.tipo_nomenclador ASC, t.codigo ASC';
        }

        $sql .= ' LIMIT :limit';

        try {
            $stmt = $this->db->prepare($sql);
            foreach ($params as $k => $v) {
                $stmt->bindValue($k, $v);
            }
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();
            $rows = $stmt->fetchAll();
        } catch (\PDOException $e) {
            throw ApiException::internalError();
        }

        $results = [];
        foreach ($rows as $r) {
            $results[] = [
                'id' => (string) $r['id'],
                'nomenclator_type' => (string) $r['tipo_nomenclador'],
                'code' => (string) $r['codigo'],
                'chapter' => $r['capitulo'] !== null ? (string) $r['capitulo'] : null,
                'description' => (string) $r['descripcion'],
                'unit_type' => $r['unidad_tipo'] !== null ? (string) $r['unidad_tipo'] : null,
                'unit_value' => $r['unidad_valor'] !== null ? (float) $r['unidad_valor'] : null,
                'expenses_value' => $r['gastos_valor'] !== null ? (float) $r['gastos_valor'] : null,
                'snomed_concept_id' => $r['snomed_concept_id'] !== null ? (string) $r['snomed_concept_id'] : null,
                'loinc_code' => $r['codigo_loinc'] !== null ? (string) $r['codigo_loinc'] : null,
            ];
        }

        return [
            'data' => $results,
            'meta' => [
                'query' => $query !== '' ? $query : null,
                'type' => $tipo !== '' ? strtoupper($tipo) : null,
                'limit' => $limit,
                'returned' => count($results),
                'language' => $language,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Búsqueda en Vademécum Farmacéutico Comercial (Troquel, AlfaBeta, Kairos, GTIN, Monodroga o Marca).
     *
     * @return array{data: list<array<string, mixed>>, meta: array<string, mixed>}
     */
    public function searchVademecum(Request $request): array
    {
        $startedAt = hrtime(true);
        $language = $this->contentLanguage($request);
        $query = trim((string) ($request->query['q'] ?? ''));
        $troquel = trim((string) ($request->query['troquel'] ?? ''));
        $alfabeta = trim((string) ($request->query['alfabeta'] ?? ''));
        $kairos = trim((string) ($request->query['kairos'] ?? ''));
        $gtin = trim((string) ($request->query['gtin'] ?? ''));
        $limit = $this->readIntParam($request->query['limit'] ?? null, 20, 1, $this->maxLimit(), 'limit');

        $sql = 'SELECT id,
                       numero_troquel,
                       codigo_alfabeta,
                       codigo_kairos,
                       codigo_barras_gtin,
                       monodroga,
                       nombre_comercial,
                       presentacion,
                       laboratorio,
                       accion_farmacologica,
                       tipo_venta,
                       anmat_certificado,
                       CAST(snomed_concept_id AS text) AS snomed_concept_id
                  FROM vademecum_comercial
                 WHERE activo = TRUE';

        $where = [];
        $params = [];

        if ($troquel !== '') {
            $where[] = 'numero_troquel = :troquel';
            $params[':troquel'] = $troquel;
        }

        if ($alfabeta !== '') {
            $where[] = 'codigo_alfabeta = :alfabeta';
            $params[':alfabeta'] = $alfabeta;
        }

        if ($kairos !== '') {
            $where[] = 'codigo_kairos = :kairos';
            $params[':kairos'] = $kairos;
        }

        if ($gtin !== '') {
            $where[] = 'codigo_barras_gtin = :gtin';
            $params[':gtin'] = $gtin;
        }

        if ($query !== '') {
            $escaped = '%' . $this->escapeLike($query) . '%';
            $where[] = '(numero_troquel = :exact
                      OR codigo_alfabeta = :exact
                      OR codigo_kairos = :exact
                      OR codigo_barras_gtin = :exact
                      OR nombre_comercial ILIKE :term
                      OR monodroga ILIKE :term
                      OR laboratorio ILIKE :term)';
            $params[':exact'] = $query;
            $params[':term'] = $escaped;
        }

        if (!empty($where)) {
            $sql .= ' AND ' . implode(' AND ', $where);
        }

        if ($query !== '') {
            $sql .= ' ORDER BY (numero_troquel = :exact_order OR codigo_alfabeta = :exact_order OR codigo_kairos = :exact_order) DESC,
                               similarity(nombre_comercial, :sim_order) DESC, id ASC';
            $params[':exact_order'] = $query;
            $params[':sim_order'] = $query;
        } else {
            $sql .= ' ORDER BY nombre_comercial ASC';
        }

        $sql .= ' LIMIT :limit';

        try {
            $stmt = $this->db->prepare($sql);
            foreach ($params as $k => $v) {
                $stmt->bindValue($k, $v);
            }
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();
            $rows = $stmt->fetchAll();
        } catch (\PDOException $e) {
            throw ApiException::internalError();
        }

        $results = [];
        foreach ($rows as $r) {
            $results[] = [
                'id' => (string) $r['id'],
                'troquel' => (string) $r['numero_troquel'],
                'alfabeta_code' => $r['codigo_alfabeta'] !== null ? (string) $r['codigo_alfabeta'] : null,
                'kairos_code' => $r['codigo_kairos'] !== null ? (string) $r['codigo_kairos'] : null,
                'gtin' => $r['codigo_barras_gtin'] !== null ? (string) $r['codigo_barras_gtin'] : null,
                'generic_name' => (string) $r['monodroga'],
                'brand_name' => (string) $r['nombre_comercial'],
                'presentation' => (string) $r['presentacion'],
                'laboratory' => $r['laboratorio'] !== null ? (string) $r['laboratorio'] : null,
                'pharmacological_action' => $r['accion_farmacologica'] !== null ? (string) $r['accion_farmacologica'] : null,
                'sale_type' => $r['tipo_venta'] !== null ? (string) $r['tipo_venta'] : null,
                'anmat_certificate' => $r['anmat_certificado'] !== null ? (string) $r['anmat_certificado'] : null,
                'snomed_concept_id' => $r['snomed_concept_id'] !== null ? (string) $r['snomed_concept_id'] : null,
            ];
        }

        return [
            'data' => $results,
            'meta' => [
                'query' => $query !== '' ? $query : null,
                'troquel' => $troquel !== '' ? $troquel : null,
                'limit' => $limit,
                'returned' => count($results),
                'language' => $language,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Búsqueda en catálogo maestro LOINC (109.325 conceptos con variantes en español).
     *
     * @return array{data: list<array<string, mixed>>, meta: array<string, mixed>}
     */
    public function searchLoinc(Request $request): array
    {
        $startedAt = hrtime(true);
        $language = $this->contentLanguage($request);
        $query = trim((string) ($request->query['q'] ?? ''));
        $class = trim((string) ($request->query['class'] ?? ''));
        $status = trim((string) ($request->query['status'] ?? ''));
        $system = trim((string) ($request->query['system'] ?? ''));
        $limit = $this->readIntParam($request->query['limit'] ?? null, 20, 1, $this->maxLimit(), 'limit');
        $offset = $this->readIntParam($request->query['offset'] ?? null, 0, 0, self::MAX_OFFSET, 'offset');

        $sql = 'SELECT t.id,
                       t.loinc,
                       t.long_common_name,
                       t.display_name,
                       t.component,
                       t.property,
                       t.time_aspct,
                       t.system_type,
                       t.scale_type,
                       t.method_type,
                       t.class_type,
                       t.status,
                       t.shortname,
                       t.example_units,
                       t.example_ucum_units,
                       t.order_obs
                  FROM loinc t';

        $where = [];
        $params = [];

        if ($class !== '') {
            $where[] = 't.class_type ILIKE :class';
            $params[':class'] = '%' . $this->escapeLike($class) . '%';
        }

        if ($status !== '') {
            $where[] = 'upper(t.status) = :status';
            $params[':status'] = strtoupper($status);
        }

        if ($system !== '') {
            $where[] = 't.system_type ILIKE :system';
            $params[':system'] = '%' . $this->escapeLike($system) . '%';
        }

        if ($query !== '') {
            $escaped = '%' . $this->escapeLike($query) . '%';
            $where[] = '(t.loinc = :exact
                      OR t.loinc ILIKE :prefix
                      OR t.long_common_name ILIKE :term
                      OR t.display_name ILIKE :term
                      OR t.component ILIKE :term
                      OR t.shortname ILIKE :term
                      OR t.consumer_name ILIKE :term)';
            $params[':exact'] = $query;
            $params[':prefix'] = $this->escapeLike($query) . '%';
            $params[':term'] = $escaped;
        }

        if (!empty($where)) {
            $sql .= ' WHERE ' . implode(' AND ', $where);
        }

        if ($query !== '') {
            $sql .= ' ORDER BY (t.loinc = :exact_order) DESC,
                               (t.loinc ILIKE :prefix_order) DESC,
                               similarity(coalesce(nullif(t.long_common_name, \'\'), t.component), :sim_order) DESC,
                               t.id ASC';
            $params[':exact_order'] = $query;
            $params[':prefix_order'] = $this->escapeLike($query) . '%';
            $params[':sim_order'] = $query;
        } else {
            $sql .= ' ORDER BY t.loinc ASC';
        }

        $sql .= ' LIMIT :limit OFFSET :offset';

        try {
            $stmt = $this->db->prepare($sql);
            foreach ($params as $k => $v) {
                $stmt->bindValue($k, $v);
            }
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
            $stmt->execute();
            $rows = $stmt->fetchAll();
        } catch (\PDOException $e) {
            throw ApiException::internalError();
        }

        $results = [];
        foreach ($rows as $r) {
            $results[] = [
                'code' => (string) $r['loinc'],
                'long_common_name' => $r['long_common_name'] !== null ? (string) $r['long_common_name'] : null,
                'display_name' => $r['display_name'] !== null ? (string) $r['display_name'] : null,
                'component' => $r['component'] !== null ? (string) $r['component'] : null,
                'property' => $r['property'] !== null ? (string) $r['property'] : null,
                'time_aspect' => $r['time_aspct'] !== null ? (string) $r['time_aspct'] : null,
                'system' => $r['system_type'] !== null ? (string) $r['system_type'] : null,
                'scale' => $r['scale_type'] !== null ? (string) $r['scale_type'] : null,
                'method' => $r['method_type'] !== null ? (string) $r['method_type'] : null,
                'class' => $r['class_type'] !== null ? (string) $r['class_type'] : null,
                'status' => $r['status'] !== null ? (string) $r['status'] : null,
                'shortname' => $r['shortname'] !== null ? (string) $r['shortname'] : null,
                'example_units' => $r['example_units'] !== null ? (string) $r['example_units'] : null,
                'example_ucum_units' => $r['example_ucum_units'] !== null ? (string) $r['example_ucum_units'] : null,
                'order_obs' => $r['order_obs'] !== null ? (string) $r['order_obs'] : null,
            ];
        }

        return [
            'data' => $results,
            'meta' => [
                'query' => $query !== '' ? $query : null,
                'class' => $class !== '' ? $class : null,
                'status' => $status !== '' ? $status : null,
                'system' => $system !== '' ? $system : null,
                'limit' => $limit,
                'offset' => $offset,
                'returned' => count($results),
                'language' => $language,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Ficha técnica detallada de un código LOINC con sus mapeos (MapTo)
     * y correlación con Nomencladores Argentinos (NBU, NN/PMO).
     *
     * @return array{data: array<string, mixed>, meta: array<string, mixed>}
     */
    public function findLoinc(string $code, Request $request): array
    {
        $startedAt = hrtime(true);
        $code = trim($code);

        $sql = 'SELECT t.* FROM loinc t WHERE t.loinc = :code LIMIT 1';
        $stmt = $this->db->prepare($sql);
        $stmt->execute([':code' => $code]);
        $row = $stmt->fetch();

        if ($row === false) {
            throw ApiException::notFound("No se encontró el concepto LOINC '{$code}'.");
        }

        // Mapeos MapTo
        $mapStmt = $this->db->prepare('SELECT map, comment FROM loinc_map WHERE loinc = :code ORDER BY map ASC');
        $mapStmt->execute([':code' => $code]);
        $mapRows = $mapStmt->fetchAll();

        $mappings = array_map(static fn (array $m): array => [
            'target_code' => (string) $m['map'],
            'comment' => $m['comment'] !== null ? (string) $m['comment'] : null,
        ], $mapRows);

        // Vínculo con Nomencladores Argentinos (NBU, NN/PMO)
        $nomStmt = $this->db->prepare(
            'SELECT tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor
               FROM nomencladores_argentina
              WHERE codigo_loinc = :code
              ORDER BY tipo_nomenclador ASC, codigo ASC'
        );
        $nomStmt->execute([':code' => $code]);
        $nomRows = $nomStmt->fetchAll();

        $argentineNomenclators = array_map(static fn (array $n): array => [
            'nomenclator' => (string) $n['tipo_nomenclador'],
            'code' => (string) $n['codigo'],
            'description' => (string) $n['descripcion'],
            'unit_type' => (string) $n['unidad_tipo'],
            'unit_value' => $n['unidad_valor'] !== null ? (float) $n['unidad_valor'] : null,
        ], $nomRows);

        return [
            'data' => [
                'code' => (string) $row['loinc'],
                'long_common_name' => (string) ($row['long_common_name'] ?? ''),
                'display_name' => $row['display_name'] !== null ? (string) $row['display_name'] : null,
                'component' => $row['component'] !== null ? (string) $row['component'] : null,
                'property' => $row['property'] !== null ? (string) $row['property'] : null,
                'time_aspect' => $row['time_aspct'] !== null ? (string) $row['time_aspct'] : null,
                'system' => $row['system_type'] !== null ? (string) $row['system_type'] : null,
                'scale' => $row['scale_type'] !== null ? (string) $row['scale_type'] : null,
                'method' => $row['method_type'] !== null ? (string) $row['method_type'] : null,
                'class' => $row['class_type'] !== null ? (string) $row['class_type'] : null,
                'status' => $row['status'] !== null ? (string) $row['status'] : null,
                'shortname' => $row['shortname'] !== null ? (string) $row['shortname'] : null,
                'example_units' => $row['example_units'] !== null ? (string) $row['example_units'] : null,
                'example_ucum_units' => $row['example_ucum_units'] !== null ? (string) $row['example_ucum_units'] : null,
                'order_obs' => $row['order_obs'] !== null ? (string) $row['order_obs'] : null,
                'consumer_name' => $row['consumer_name'] !== null ? (string) $row['consumer_name'] : null,
                'definition' => $row['definition_description'] !== null ? (string) $row['definition_description'] : null,
                'formula' => $row['formula'] !== null ? (string) $row['formula'] : null,
                'version_last_changed' => $row['version_last_changed'] !== null ? (string) $row['version_last_changed'] : null,
                'version_first_released' => $row['version_first_released'] !== null ? (string) $row['version_first_released'] : null,
                'mappings_map_to' => $mappings,
                'argentine_nomenclators' => $argentineNomenclators,
            ],
            'meta' => [
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * Búsqueda en el Programa Médico Obligatorio (PMO - pmo_practicas).
     *
     * @return array{data: list<array<string, mixed>>, meta: array<string, mixed>}
     */
    public function searchPmoPracticas(Request $request): array
    {
        $startedAt = hrtime(true);
        $query = trim((string) ($request->query['q'] ?? ''));
        $capitulo = trim((string) ($request->query['capitulo'] ?? $request->query['cap_cod'] ?? ''));
        $condicionada = $request->query['cobertura_condicionada'] ?? null;
        $limit = $this->readIntParam($request->query['limit'] ?? null, 20, 1, $this->maxLimit(), 'limit');
        $offset = $this->readIntParam($request->query['offset'] ?? null, 0, 0, self::MAX_OFFSET, 'offset');

        $sql = 'SELECT id, codigo, cap_cod, capitulo, subcapitulo, practica, notas, cobertura_condicionada, revisar
                  FROM pmo_practicas';
        $where = [];
        $params = [];

        if ($query !== '') {
            $escaped = '%' . $this->escapeLike($query) . '%';
            // f_unaccent() es IMMUTABLE (wrapper de unaccent) para soportar búsqueda accent-insensitive
            // y usar los índices GIN funcionales: idx_pmo_practica_unaccent, idx_pmo_capitulo_unaccent
            $where[] = '(codigo ILIKE :exact OR codigo ILIKE :prefix'
                     . ' OR f_unaccent(practica) ILIKE f_unaccent(:term)'
                     . ' OR f_unaccent(capitulo) ILIKE f_unaccent(:term))';
            $params[':exact'] = $query;
            $params[':prefix'] = $this->escapeLike($query) . '%';
            $params[':term'] = $escaped;
        }

        if ($capitulo !== '') {
            $where[] = '(cap_cod = :cap_cod OR f_unaccent(capitulo) ILIKE f_unaccent(:cap_term))';
            $params[':cap_cod'] = $capitulo;
            $params[':cap_term'] = '%' . $this->escapeLike($capitulo) . '%';
        }

        if ($condicionada !== null && $condicionada !== '') {
            $where[] = 'cobertura_condicionada = :cond';
            $params[':cond'] = filter_var($condicionada, FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
        }

        if (!empty($where)) {
            $sql .= ' WHERE ' . implode(' AND ', $where);
        }

        if ($query !== '') {
            $sql .= ' ORDER BY (codigo = :exact_order) DESC, (codigo ILIKE :prefix_order) DESC,'
                  . ' similarity(f_unaccent(practica), f_unaccent(:sim_order)) DESC, id ASC';
            $params[':exact_order'] = $query;
            $params[':prefix_order'] = $this->escapeLike($query) . '%';
            $params[':sim_order'] = $query;
        } else {
            $sql .= ' ORDER BY codigo ASC';
        }

        $sql .= ' LIMIT :limit OFFSET :offset';

        $stmt = $this->db->prepare($sql);
        foreach ($params as $k => $v) {
            $stmt->bindValue($k, $v);
        }
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll();

        $results = [];
        foreach ($rows as $r) {
            $results[] = [
                'code' => (string) $r['codigo'],
                'chapter_code' => $r['cap_cod'] !== null ? (string) $r['cap_cod'] : null,
                'chapter' => $r['capitulo'] !== null ? (string) $r['capitulo'] : null,
                'subchapter' => $r['subcapitulo'] !== null ? (string) $r['subcapitulo'] : null,
                'practice' => (string) $r['practica'],
                'notes' => $r['notas'] !== '' && $r['notas'] !== null ? (string) $r['notas'] : null,
                'conditioned_coverage' => (int) $r['cobertura_condicionada'] === 1,
            ];
        }

        return [
            'data' => $results,
            'meta' => [
                'query' => $query !== '' ? $query : null,
                'chapter' => $capitulo !== '' ? $capitulo : null,
                'limit' => $limit,
                'offset' => $offset,
                'returned' => count($results),
                'took_ms' => round((hrtime(true) - $startedAt) / 1e6, 2),
            ],
        ];
    }

    /**
     * Obtiene el detalle de una práctica PMO por su código.
     *
     * @return array{data: array<string, mixed>, meta: array<string, mixed>}
     */
    public function findPmoPractica(string $code): array
    {
        $startedAt = hrtime(true);
        $code = trim($code);

        $stmt = $this->db->prepare('SELECT id, codigo, cap_cod, capitulo, subcapitulo, practica, notas, cobertura_condicionada, revisar
                                      FROM pmo_practicas
                                     WHERE codigo = :code
                                     LIMIT 1');
        $stmt->execute([':code' => $code]);
        $row = $stmt->fetch();

        if ($row === false) {
            $odontoStmt = $this->db->prepare('SELECT id, codigo, practica, descripcion FROM pmo_odontologia WHERE codigo = :code LIMIT 1');
            $odontoStmt->execute([':code' => $code]);
            $odontoRow = $odontoStmt->fetch();

            if ($odontoRow !== false) {
                return [
                    'data' => [
                        'type' => 'odontologia',
                        'code' => (string) $odontoRow['codigo'],
                        'practice' => (string) $odontoRow['practica'],
                        'description' => $odontoRow['descripcion'] !== '' ? (string) $odontoRow['descripcion'] : null,
                    ],
                    'meta' => ['took_ms' => round((hrtime(true) - $startedAt) / 1e6, 2)],
                ];
            }

            throw ApiException::notFound("No se encontró la práctica PMO con código: {$code}.");
        }

        return [
            'data' => [
                'type' => 'medica',
                'code' => (string) $row['codigo'],
                'chapter_code' => $row['cap_cod'] !== null ? (string) $row['cap_cod'] : null,
                'chapter' => $row['capitulo'] !== null ? (string) $row['capitulo'] : null,
                'subchapter' => $row['subcapitulo'] !== null ? (string) $row['subcapitulo'] : null,
                'practice' => (string) $row['practica'],
                'notes' => $row['notas'] !== '' && $row['notas'] !== null ? (string) $row['notas'] : null,
                'conditioned_coverage' => (int) $row['cobertura_condicionada'] === 1,
            ],
            'meta' => ['took_ms' => round((hrtime(true) - $startedAt) / 1e6, 2)],
        ];
    }

    /**
     * Búsqueda de medicamentos y precios de referencia del PMO.
     *
     * @return array{data: list<array<string, mixed>>, meta: array<string, mixed>}
     */
    public function searchPmoMedicamentos(Request $request): array
    {
        $startedAt = hrtime(true);
        $query = trim((string) ($request->query['q'] ?? ''));
        $atc = trim((string) ($request->query['atc'] ?? ''));
        $limit = $this->readIntParam($request->query['limit'] ?? null, 20, 1, $this->maxLimit(), 'limit');
        $offset = $this->readIntParam($request->query['offset'] ?? null, 0, 0, self::MAX_OFFSET, 'offset');

        $sql = 'SELECT p.id, p.principio_activo, p.presentacion, p.precio_ref, p.cobertura_40, p.pagina,
                       f.atc, f.nombre AS nombre_atc, f.notas AS notas_atc
                  FROM pmo_precios p
             LEFT JOIN pmo_formulario f ON f.nombre ILIKE \'%\' || p.principio_activo || \'%\' OR p.principio_activo ILIKE \'%\' || f.nombre || \'%\'';

        $where = [];
        $params = [];

        if ($query !== '') {
            $escaped = '%' . $this->escapeLike($query) . '%';
            $where[] = '(p.principio_activo ILIKE :term OR p.presentacion ILIKE :term OR f.atc ILIKE :term)';
            $params[':term'] = $escaped;
        }

        if ($atc !== '') {
            $where[] = 'f.atc ILIKE :atc';
            $params[':atc'] = $this->escapeLike($atc) . '%';
        }

        if (!empty($where)) {
            $sql .= ' WHERE ' . implode(' AND ', $where);
        }

        if ($query !== '') {
            $sql .= ' ORDER BY similarity(p.principio_activo, :sim) DESC, p.id ASC';
            $params[':sim'] = $query;
        } else {
            $sql .= ' ORDER BY p.principio_activo ASC, p.id ASC';
        }

        $sql .= ' LIMIT :limit OFFSET :offset';

        $stmt = $this->db->prepare($sql);
        foreach ($params as $k => $v) {
            $stmt->bindValue($k, $v);
        }
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll();

        $results = [];
        foreach ($rows as $r) {
            $results[] = [
                'active_ingredient' => (string) $r['principio_activo'],
                'presentation' => (string) $r['presentacion'],
                'reference_price' => $r['precio_ref'] !== null ? (float) $r['precio_ref'] : null,
                'coverage_40_percent' => $r['cobertura_40'] !== null ? (float) $r['cobertura_40'] : null,
                'atc_code' => $r['atc'] !== null ? (string) $r['atc'] : null,
                'atc_name' => $r['nombre_atc'] !== null ? (string) $r['nombre_atc'] : null,
                'pmo_resolution_notes' => $r['notas_atc'] !== '' && $r['notas_atc'] !== null ? (string) $r['notas_atc'] : null,
            ];
        }

        return [
            'data' => $results,
            'meta' => [
                'query' => $query !== '' ? $query : null,
                'atc' => $atc !== '' ? $atc : null,
                'limit' => $limit,
                'offset' => $offset,
                'returned' => count($results),
                'took_ms' => round((hrtime(true) - $startedAt) / 1e6, 2),
            ],
        ];
    }

    /**
     * Búsqueda en los textos normativos y resoluciones del PMO.
     *
     * @return array{data: list<array<string, mixed>>, meta: array<string, mixed>}
     */
    public function searchPmoNormativa(Request $request): array
    {
        $startedAt = hrtime(true);
        $query = trim((string) ($request->query['q'] ?? ''));
        $seccion = trim((string) ($request->query['seccion'] ?? ''));
        $limit = $this->readIntParam($request->query['limit'] ?? null, 20, 1, $this->maxLimit(), 'limit');

        $sql = 'SELECT id, seccion, numero, titulo, texto FROM pmo_texto';
        $where = [];
        $params = [];

        if ($query !== '') {
            $escaped = '%' . $this->escapeLike($query) . '%';
            $where[] = '(titulo ILIKE :term OR texto ILIKE :term)';
            $params[':term'] = $escaped;
        }

        if ($seccion !== '') {
            $where[] = 'seccion ILIKE :sec';
            $params[':sec'] = '%' . $this->escapeLike($seccion) . '%';
        }

        if (!empty($where)) {
            $sql .= ' WHERE ' . implode(' AND ', $where);
        }

        $sql .= ' ORDER BY id ASC LIMIT :limit';

        $stmt = $this->db->prepare($sql);
        foreach ($params as $k => $v) {
            $stmt->bindValue($k, $v);
        }
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll();

        $results = [];
        foreach ($rows as $r) {
            $results[] = [
                'section' => (string) $r['seccion'],
                'number' => (string) $r['numero'],
                'title' => (string) $r['titulo'],
                'text' => (string) $r['texto'],
            ];
        }

        return [
            'data' => $results,
            'meta' => [
                'query' => $query !== '' ? $query : null,
                'section' => $seccion !== '' ? $seccion : null,
                'limit' => $limit,
                'returned' => count($results),
                'took_ms' => round((hrtime(true) - $startedAt) / 1e6, 2),
            ],
        ];
    }

    /**
     * Construye las ramas UNION ALL del buscador. Solo se compilan las ramas
     * de los dominios efectivamente solicitados.
     *
     * @param list<string> $domains
     * @param list<string> $refsets Códigos de filtro; sólo aplican a SNOMED.
     *
     * @return array{0: string, 1: array<string, string|int>}
     */
    private function buildUnion(
        array $domains,
        string $term,
        string $contains,
        string $prefix,
        string $language,
        ?string $cie10Type,
        bool $useTrigram,
        array $refsets
    ): array {
        $branches = [];
        $parameters = [];
        $index = 0;

        if (in_array(self::DOMAIN_SNOMED, $domains, true)) {
            [$sql, $params] = $this->snomedBranch(
                $term,
                $contains,
                $prefix,
                $language,
                $useTrigram,
                $refsets,
                $index++
            );
            $branches[] = $sql;
            $parameters += $params;
        }

        if (in_array(self::DOMAIN_CIE10, $domains, true)) {
            [$sql, $params] = $this->cie10Branch(
                $term,
                $contains,
                $prefix,
                $language,
                $cie10Type,
                $useTrigram,
                $index++
            );
            $branches[] = $sql;
            $parameters += $params;
        }

        if (in_array(self::DOMAIN_ANMAT, $domains, true)) {
            [$sql, $params] = $this->anmatBranch($term, $contains, $prefix, $useTrigram, $index++);
            $branches[] = $sql;
            $parameters += $params;
        }

        if (in_array(self::DOMAIN_LOINC, $domains, true)) {
            [$sql, $params] = $this->loincBranch($term, $contains, $prefix, $language, $useTrigram, $index++);
            $branches[] = $sql;
            $parameters += $params;
        }

        foreach (self::CATALOG_SOURCES as $domain => $config) {
            if (!in_array($domain, $domains, true)) {
                continue;
            }

            [$sql, $params] = $this->catalogBranch(
                $domain,
                $config,
                $term,
                $contains,
                $prefix,
                $language,
                $useTrigram,
                $index++
            );
            $branches[] = $sql;
            $parameters += $params;
        }

        return [implode("\nUNION ALL\n", $branches), $parameters];
    }

    /**
     * Rama SNOMED-CT sobre descripciones activas de conceptos activos.
     *
     * Cuando se piden refsets, el concepto debe pertenecer a al menos uno de
     * los filtros. Se usa EXISTS para no duplicar la descripción si el
     * concepto está en varios refsets.
     *
     * @param list<string> $refsets
     *
     * @return array{0: string, 1: array<string, string>}
     */
    private function snomedBranch(
        string $term,
        string $contains,
        string $prefix,
        string $language,
        bool $useTrigram,
        array $refsets,
        int $index
    ): array {
        $p = 'sn' . $index;
        $fsn = self::SNOMED_FSN;
        $synonym = self::SNOMED_SYNONYM;
        $trigramSql = $useTrigram ? " OR d.term % :{$p}_trgm" : '';
        $refsetSql = '';
        $refsetParams = [];

        if ($refsets !== []) {
            $placeholders = [];

            foreach ($refsets as $position => $refset) {
                $name = ":{$p}_rf{$position}";
                $placeholders[] = $name;
                $refsetParams[$name] = $refset;
            }

            $refsetSql = "\n              AND EXISTS (\n"
                . "                  SELECT 1\n"
                . "                    FROM public.snomed_refset_member rm\n"
                . "                   WHERE rm.concept_id = d.concept_id\n"
                . "                     AND rm.active = TRUE\n"
                . '                     AND rm.filter_code IN (' . implode(', ', $placeholders) . ")\n"
                . '              )';
        }

        $sql = <<<SQL
            SELECT
                'snomed'                     AS domain,
                'snomed'                     AS source,
                'snomed:' || CAST(d.id AS text) AS result_key,
                CAST(d.concept_id AS text)   AS source_id,
                CAST(d.concept_id AS text)   AS code,
                d.term                       AS term,
                NULL                         AS subtitle,
                d.language_code              AS language,
                CASE
                    WHEN d.type_id = CAST({$fsn} AS bigint) THEN 'fsn'
                    WHEN d.type_id = CAST({$synonym} AS bigint) THEN 'synonym'
                    ELSE 'other'
                END                          AS kind,
                CAST(GREATEST(
                    CASE WHEN lower(d.term) = lower(:{$p}_exact) THEN CAST(1.0 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN d.term ILIKE :{$p}_prefix THEN CAST(0.90 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN d.term ILIKE :{$p}_contains THEN CAST(0.75 AS float8) ELSE CAST(0.0 AS float8) END,
                    CAST(similarity(d.term, :{$p}_sim) AS float8)
                ) AS float8)                 AS score,
                CAST(json_build_object(
                    'description_id', CAST(d.id AS text),
                    'concept_id', CAST(d.concept_id AS text),
                    'type_id', CAST(d.type_id AS text),
                    'term_type', CASE
                        WHEN d.type_id = CAST({$fsn} AS bigint) THEN 'fsn'
                        WHEN d.type_id = CAST({$synonym} AS bigint) THEN 'synonym'
                        ELSE 'other'
                    END
                ) AS text)                   AS metadata
            FROM snomed_descriptions d
            INNER JOIN snomed_concepts c ON c.id = d.concept_id
            WHERE d.active = TRUE
              AND c.active = TRUE
              AND d.language_code = :{$p}_lang
              AND (d.term ILIKE :{$p}_filter{$trigramSql}){$refsetSql}
            SQL;

        $params = [
            ":{$p}_exact" => $term,
            ":{$p}_prefix" => $prefix,
            ":{$p}_contains" => $contains,
            ":{$p}_sim" => $term,
            ":{$p}_lang" => $language,
            ":{$p}_filter" => $contains,
        ];

        if ($useTrigram) {
            $params[":{$p}_trgm"] = $term;
        }

        return [$sql, $params + $refsetParams];
    }

    /**
     * Rama CIE-10. Acepta coincidencias por descripción o por código, con o
     * sin punto (J18.9 / J189).
     *
     * @return array{0: string, 1: array<string, string>}
     */
    private function cie10Branch(
        string $term,
        string $contains,
        string $prefix,
        string $language,
        ?string $cie10Type,
        bool $useTrigram,
        int $index
    ): array {
        $p = 'ci' . $index;
        $trigramSql = $useTrigram ? " OR d.descripcion % :{$p}_trgm" : '';
        $typeSql = $cie10Type !== null ? " AND c.tipo = :{$p}_type" : '';
        $code = strtoupper($term);
        $normalizedCode = $this->normalizeCode($code);
        $escapedCode = $this->escapeLike($code);
        $escapedNormalizedCode = $this->escapeLike($normalizedCode);

        $sql = <<<SQL
            SELECT
                'cie10'                          AS domain,
                'cie10'                          AS source,
                'cie10:' || CAST(c.id AS text)   AS result_key,
                CAST(c.id AS text)               AS source_id,
                c.codigo                         AS code,
                d.descripcion                    AS term,
                c.tipo                           AS subtitle,
                d.language_code                  AS language,
                CASE c.tipo
                    WHEN 'procedimiento' THEN 'procedure'
                    ELSE 'diagnosis'
                END                              AS kind,
                CAST(GREATEST(
                    CASE WHEN upper(c.codigo) = upper(:{$p}_exact_code) THEN CAST(1.0 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN c.codigo ILIKE :{$p}_code_prefix THEN CAST(0.96 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN replace(upper(c.codigo), '.', '') ILIKE :{$p}_code_normalized THEN CAST(0.94 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN lower(d.descripcion) = lower(:{$p}_exact) THEN CAST(1.0 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN d.descripcion ILIKE :{$p}_prefix THEN CAST(0.90 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN d.descripcion ILIKE :{$p}_contains THEN CAST(0.75 AS float8) ELSE CAST(0.0 AS float8) END,
                    CAST(similarity(d.descripcion, :{$p}_sim) AS float8)
                ) AS float8)                     AS score,
                CAST(json_build_object(
                    'cie10_id', CAST(c.id AS text),
                    'code', c.codigo,
                    'type', c.tipo,
                    'language', d.language_code
                ) AS text)                       AS metadata
            FROM cie10_descriptions d
            INNER JOIN cie10_codes c ON c.id = d.cie10_id
            WHERE d.language_code = :{$p}_lang
              AND (
                    d.descripcion ILIKE :{$p}_filter
                 OR c.codigo ILIKE :{$p}_code_filter
                 OR replace(upper(c.codigo), '.', '') ILIKE :{$p}_code_norm_filter
                 {$trigramSql}
              )
              {$typeSql}
            SQL;

        $params = [
            ":{$p}_exact_code" => $code,
            ":{$p}_code_prefix" => $escapedCode . '%',
            ":{$p}_code_normalized" => '%' . $escapedNormalizedCode . '%',
            ":{$p}_exact" => $term,
            ":{$p}_prefix" => $prefix,
            ":{$p}_contains" => $contains,
            ":{$p}_sim" => $term,
            ":{$p}_lang" => $language,
            ":{$p}_filter" => $contains,
            ":{$p}_code_filter" => '%' . $escapedCode . '%',
            ":{$p}_code_norm_filter" => '%' . $escapedNormalizedCode . '%',
        ];

        if ($useTrigram) {
            $params[":{$p}_trgm"] = $term;
        }

        if ($cie10Type !== null) {
            $params[":{$p}_type"] = $cie10Type;
        }

        return [$sql, $params];
    }

    /**
     * @return array{0: string, 1: array<string, string>}
     */
    private function anmatBranch(
        string $term,
        string $contains,
        string $prefix,
        bool $useTrigram,
        int $index
    ): array {
        $p = 'an' . $index;
        $trigramSql = $useTrigram
            ? " OR a.nombre_comercial % :{$p}_trgm_c OR a.nombre_generico % :{$p}_trgm_g"
            : '';

        $sql = <<<SQL
            SELECT
                'anmat'                           AS domain,
                'anmat'                           AS source,
                'anmat:' || CAST(a.id AS text)    AS result_key,
                CAST(a.id AS text)                AS source_id,
                a.certificado_number              AS code,
                a.nombre_comercial                AS term,
                a.nombre_generico                 AS subtitle,
                'es'                              AS language,
                'medication'                      AS kind,
                CAST(GREATEST(
                    CASE WHEN lower(a.nombre_comercial) = lower(:{$p}_exact_c) THEN CAST(1.0 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN a.nombre_comercial ILIKE :{$p}_prefix_c THEN CAST(0.92 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN a.nombre_comercial ILIKE :{$p}_contains_c THEN CAST(0.78 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN lower(a.nombre_generico) = lower(:{$p}_exact_g) THEN CAST(1.0 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN a.nombre_generico ILIKE :{$p}_prefix_g THEN CAST(0.90 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN a.nombre_generico ILIKE :{$p}_contains_g THEN CAST(0.76 AS float8) ELSE CAST(0.0 AS float8) END,
                    CAST(similarity(a.nombre_comercial, :{$p}_sim_c) AS float8),
                    CAST(similarity(a.nombre_generico, :{$p}_sim_g) AS float8)
                ) AS float8)                      AS score,
                CAST(json_build_object(
                    'id', CAST(a.id AS text),
                    'certificate', a.certificado_number,
                    'generic_name', a.nombre_generico,
                    'laboratory', a.laboratorio,
                    'pharmaceutical_form', a.forma_farmaceutica,
                    'presentation', a.presentacion,
                    'snomed_concept_id', CAST(a.snomed_concept_id AS text)
                ) AS text)                        AS metadata
            FROM anmat_medicamentos a
            WHERE (
                    a.nombre_comercial ILIKE :{$p}_filter_c
                 OR a.nombre_generico ILIKE :{$p}_filter_g
                 {$trigramSql}
            )
            SQL;

        $params = [
            ":{$p}_exact_c" => $term,
            ":{$p}_prefix_c" => $prefix,
            ":{$p}_contains_c" => $contains,
            ":{$p}_exact_g" => $term,
            ":{$p}_prefix_g" => $prefix,
            ":{$p}_contains_g" => $contains,
            ":{$p}_sim_c" => $term,
            ":{$p}_sim_g" => $term,
            ":{$p}_filter_c" => $contains,
            ":{$p}_filter_g" => $contains,
        ];

        if ($useTrigram) {
            $params[":{$p}_trgm_c"] = $term;
            $params[":{$p}_trgm_g"] = $term;
        }

        return [$sql, $params];
    }

    /**
     * Rama LOINC para el buscador unificado.
     *
     * @return array{0: string, 1: array<string, string>}
     */
    private function loincBranch(
        string $term,
        string $contains,
        string $prefix,
        string $language,
        bool $useTrigram,
        int $index
    ): array {
        $p = 'lo' . $index;
        $trigramSql = $useTrigram ? " OR t.long_common_name % :{$p}_trgm OR t.component % :{$p}_trgm OR t.consumer_name % :{$p}_trgm" : '';

        $sql = <<<SQL
            SELECT
                'loinc'                                             AS domain,
                'loinc'                                             AS source,
                'loinc:' || t.loinc                                 AS result_key,
                t.loinc                                             AS source_id,
                t.loinc                                             AS code,
                coalesce(nullif(t.long_common_name, ''), nullif(t.display_name, ''), nullif(t.consumer_name, ''), t.component) AS term,
                t.component                                         AS subtitle,
                'es'                                                AS language,
                'loinc_observation'                                 AS kind,
                CAST(GREATEST(
                    CASE WHEN lower(t.loinc) = lower(:{$p}_exact) THEN CAST(1.0 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN t.loinc ILIKE :{$p}_prefix THEN CAST(0.96 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN lower(t.long_common_name) = lower(:{$p}_exact) THEN CAST(0.94 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN t.long_common_name ILIKE :{$p}_prefix THEN CAST(0.90 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN t.display_name ILIKE :{$p}_prefix THEN CAST(0.88 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN t.component ILIKE :{$p}_prefix THEN CAST(0.86 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN t.consumer_name ILIKE :{$p}_prefix THEN CAST(0.84 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN t.long_common_name ILIKE :{$p}_contains THEN CAST(0.78 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN t.display_name ILIKE :{$p}_contains THEN CAST(0.76 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN t.consumer_name ILIKE :{$p}_contains THEN CAST(0.75 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN t.component ILIKE :{$p}_contains THEN CAST(0.74 AS float8) ELSE CAST(0.0 AS float8) END,
                    CAST(similarity(coalesce(nullif(t.long_common_name, ''), t.component), :{$p}_sim) AS float8)
                ) AS float8)                                        AS score,
                CAST(json_build_object(
                    'loinc_code', t.loinc,
                    'class_type', t.class_type,
                    'system_type', t.system_type,
                    'scale_type', t.scale_type,
                    'method_type', t.method_type,
                    'status', t.status,
                    'consumer_name', t.consumer_name,
                    'example_ucum_units', t.example_ucum_units
                ) AS text)                                          AS metadata
            FROM loinc t
            WHERE (
                    t.loinc ILIKE :{$p}_prefix
                 OR t.long_common_name ILIKE :{$p}_contains
                 OR t.display_name ILIKE :{$p}_contains
                 OR t.component ILIKE :{$p}_contains
                 OR t.shortname ILIKE :{$p}_contains
                 OR t.consumer_name ILIKE :{$p}_contains
                 {$trigramSql}
            )
            SQL;

        $params = [
            ":{$p}_exact" => $term,
            ":{$p}_prefix" => $prefix,
            ":{$p}_contains" => $contains,
            ":{$p}_sim" => $term,
        ];

        if ($useTrigram) {
            $params[":{$p}_trgm"] = $term;
        }

        return [$sql, $params];
    }

    /**
     * Rama genérica para un catálogo local.
     *
     * @param array{
     *     table: string,
     *     code: string,
     *     term: string,
     *     subtitle: string|null,
     *     kind: string,
     *     filters: list<string>,
     *     metadata: array<string, string>
     * } $config
     *
     * @return array{0: string, 1: array<string, string>}
     */
    private function catalogBranch(
        string $domain,
        array $config,
        string $term,
        string $contains,
        string $prefix,
        string $language,
        bool $useTrigram,
        int $index
    ): array {
        $p = 'ct' . $index;
        $termSql = $config['term'];
        $codeSql = $config['code'];
        $subtitleSql = $config['subtitle'];
        $select = $this->catalogSelect($domain, $p, $this->catalogScoreSql($config, $p));

        $params = [
            ":{$p}_exact" => $term,
            ":{$p}_prefix" => $prefix,
            ":{$p}_contains" => $contains,
            ":{$p}_sim" => $term,
            ":{$p}_code_prefix" => $prefix,
            ":{$p}_label_lang" => $language,
            ":{$p}_label_syn" => self::SNOMED_SYNONYM,
        ];

        if ($subtitleSql !== null) {
            $params[":{$p}_sub_contains"] = $contains;
        }

        $filterSql = [];

        foreach ($config['filters'] as $position => $column) {
            $filterSql[] = "{$column} ILIKE :{$p}_f{$position}";
            $params[":{$p}_f{$position}"] = $contains;
        }

        $trigramSql = $useTrigram ? " OR {$termSql} % :{$p}_trgm" : '';

        if ($useTrigram) {
            $params[":{$p}_trgm"] = $term;
        }

        $filterClause = implode("\n                 OR ", $filterSql);
        $table = $config['table'];

        $sql = <<<SQL
            SELECT
                {$select}
            FROM {$table} t
            WHERE t.activo = TRUE
              AND (
                    {$filterClause}
                 {$trigramSql}
              )
            SQL;

        return [$sql, $params];
    }

    /**
     * Proyección SQL común de un catálogo al contrato unificado.
     *
     * Incluye el término SNOMED-CT vinculado, resuelto en el idioma pedido,
     * para que el cliente pueda navegar a la ontología sin otra llamada.
     */
    private function catalogSelect(string $domain, string $p, string $scoreSql): string
    {
        $config = self::CATALOG_SOURCES[$domain];
        $subtitleSql = $config['subtitle'] !== null
            ? $config['subtitle']
            : 'NULL';

        $metadataPairs = [];

        foreach ($config['metadata'] as $key => $expression) {
            $metadataPairs[] = "'{$key}', {$expression}";
        }

        $metadataPairs[] = "'snomed_concept_id', CAST(t.snomed_concept_id AS text)";
        $metadataPairs[] = <<<SQL
            'snomed_term', (
                SELECT sd.term
                  FROM snomed_descriptions sd
                 WHERE sd.concept_id = t.snomed_concept_id
                   AND sd.active = TRUE
                   AND sd.language_code = :{$p}_label_lang
                 ORDER BY (sd.type_id = CAST(:{$p}_label_syn AS bigint)) DESC,
                          length(sd.term) ASC,
                          sd.term ASC
                 LIMIT 1
            )
            SQL;

        $metadataSql = implode(",\n                    ", $metadataPairs);

        return <<<SQL
            '{$domain}'                       AS domain,
            '{$domain}'                       AS source,
            '{$domain}:' || CAST(t.id AS text) AS result_key,
            CAST(t.id AS text)                AS source_id,
            {$config['code']}                 AS code,
            {$config['term']}                 AS term,
            {$subtitleSql}                    AS subtitle,
            'es'                              AS language,
            '{$config['kind']}'               AS kind,
            {$scoreSql}                       AS score,
            CAST(json_build_object(
                    {$metadataSql}
            ) AS text)                        AS metadata
            SQL;
    }

    /**
     * Score textual de un catálogo: código exacto/por prefijo, nombre
     * exacto/por prefijo/contiene, subtítulo y similitud por trigramas.
     *
     * @param array{
     *     code: string,
     *     term: string,
     *     subtitle: string|null,
     *     metadata: array<string, string>
     * } $config
     */
    private function catalogScoreSql(array $config, string $p): string
    {
        $termSql = $config['term'];
        $codeSql = $config['code'];
        $subtitleScore = '';

        if ($config['subtitle'] !== null) {
            $subtitleScore = "CASE WHEN {$config['subtitle']} ILIKE :{$p}_sub_contains THEN CAST(0.70 AS float8) ELSE CAST(0.0 AS float8) END,";
        }

        return <<<SQL
            CAST(GREATEST(
                    CASE WHEN lower({$termSql}) = lower(:{$p}_exact) THEN CAST(1.0 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN {$codeSql} ILIKE :{$p}_code_prefix THEN CAST(0.96 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN {$termSql} ILIKE :{$p}_prefix THEN CAST(0.92 AS float8) ELSE CAST(0.0 AS float8) END,
                    CASE WHEN {$termSql} ILIKE :{$p}_contains THEN CAST(0.78 AS float8) ELSE CAST(0.0 AS float8) END,
                    {$subtitleScore}
                    CAST(similarity({$termSql}, :{$p}_sim) AS float8)
                ) AS float8)
            SQL;
    }

    /**
     * Convierte una fila SQL al contrato público de la API.
     *
     * @param array<string, mixed> $row
     *
     * @return array<string, mixed>
     */
    private function hydrateRow(array $row): array
    {
        $metadata = $row['metadata'] ?? null;
        $decoded = [];

        if (is_string($metadata) && $metadata !== '') {
            $decoded = json_decode($metadata, true);

            if (!is_array($decoded)) {
                $decoded = [];
            }
        }

        return [
            'domain' => (string) $row['domain'],
            'source' => (string) $row['source'],
            'id' => (string) $row['source_id'],
            'code' => $row['code'] !== null ? (string) $row['code'] : null,
            'term' => (string) $row['term'],
            'subtitle' => array_key_exists('subtitle', $row) && $row['subtitle'] !== null
                ? (string) $row['subtitle']
                : null,
            'language' => (string) $row['language'],
            'kind' => (string) $row['kind'],
            'score' => round((float) $row['score'], 4),
            'metadata' => $decoded,
        ];
    }

    /**
     * @return list<string>
     */
    private function readDomains(Request $request, ?string $forcedDomain): array
    {
        if ($forcedDomain !== null) {
            return [$forcedDomain];
        }

        $value = $request->query['domains'] ?? $request->query['domain'] ?? null;

        if ($value === null) {
            return [];
        }

        $rawValues = is_array($value) ? $value : [$value];
        $domains = [];

        foreach ($rawValues as $rawValue) {
            if (!is_string($rawValue)) {
                throw ApiException::badRequest(
                    'El parámetro domains es inválido.',
                    ['domains' => 'Enviá una lista separada por comas.']
                );
            }

            foreach (explode(',', $rawValue) as $domain) {
                $domain = trim($domain);

                if ($domain !== '') {
                    $domains[] = $domain;
                }
            }
        }

        return $domains;
    }

    /**
     * @param list<string> $domains
     *
     * @return list<string>
     */
    private function normalizeDomains(array $domains): array
    {
        if ($domains === []) {
            return self::DEFAULT_DOMAINS;
        }

        $normalized = [];

        foreach ($domains as $domain) {
            $domain = strtolower(trim($domain));

            if ($domain === 'all' || $domain === '*') {
                return self::DOMAINS;
            }

            if (!in_array($domain, self::DOMAINS, true)) {
                throw ApiException::badRequest(
                    'El dominio solicitado no es válido.',
                    ['domains' => 'Valores permitidos: ' . implode(', ', self::DOMAINS) . ', all.']
                );
            }

            $normalized[$domain] = $domain;
        }

        return array_values($normalized);
    }

    /**
     * Lee y valida el parámetro refset (alias refsets).
     *
     * El filtro se aplica sólo a la rama SNOMED; por eso exige que el dominio
     * snomed esté entre los solicitados.
     *
     * @param list<string> $domains
     *
     * @return list<string>
     */
    private function readRefsets(Request $request, array $domains): array
    {
        $value = $request->query['refset'] ?? $request->query['refsets'] ?? null;

        if ($value === null) {
            return [];
        }

        $rawValues = is_array($value) ? $value : [$value];
        $codes = [];

        foreach ($rawValues as $rawValue) {
            if (!is_string($rawValue)) {
                throw ApiException::badRequest(
                    'El parámetro refset es inválido.',
                    ['refset' => 'Enviá una lista de códigos separados por coma.']
                );
            }

            foreach (explode(',', $rawValue) as $code) {
                $code = strtoupper(trim($code));

                if ($code === '') {
                    continue;
                }

                if (preg_match('/^[A-Z0-9_]{2,24}$/', $code) !== 1) {
                    throw ApiException::badRequest(
                        'El código de refset no es válido.',
                        ['refset' => 'Usá mayúsculas, números y guion bajo (por ejemplo LABORATORIO).']
                    );
                }

                $codes[$code] = $code;
            }
        }

        $codes = array_values($codes);

        if ($codes === []) {
            return [];
        }

        if (count($codes) > self::MAX_REFSETS) {
            throw ApiException::badRequest(
                'Se pidieron demasiados refsets.',
                ['refset' => 'Máximo ' . self::MAX_REFSETS . ' por consulta.']
            );
        }

        if (!in_array(self::DOMAIN_SNOMED, $domains, true)) {
            throw ApiException::badRequest(
                'El filtro refset sólo aplica al dominio snomed.',
                ['refset' => 'Agregá snomed a domains o quitá el parámetro.']
            );
        }

        if (!$this->tableExists('public.snomed_refset_member')) {
            throw ApiException::badRequest(
                'Los refsets filtrables no están publicados en esta base.',
                ['refset' => 'Ejecutá 04_codigos_opcional.sql antes de usar este filtro.']
            );
        }

        $available = $this->availableRefsetCodes();
        $unknown = array_values(array_diff($codes, $available));

        if ($unknown !== []) {
            throw ApiException::badRequest(
                'Uno o más refsets no existen en el catálogo.',
                ['refset' => $unknown, 'disponibles' => $available]
            );
        }

        return $codes;
    }

    /**
     * Códigos de filtro publicados en el catálogo de refsets.
     *
     * @return list<string>
     */
    private function availableRefsetCodes(): array
    {
        if ($this->refsetCodes !== null) {
            return $this->refsetCodes;
        }

        if (!$this->tableExists('public.sct2_refset_catalog')) {
            return $this->refsetCodes = [];
        }

        $rows = $this->db->query(
            'SELECT filter_code FROM public.sct2_refset_catalog'
            . ' WHERE filter_code IS NOT NULL ORDER BY filter_code'
        )->fetchAll(PDO::FETCH_COLUMN);

        return $this->refsetCodes = array_map(static fn ($code): string => (string) $code, $rows);
    }

    private function tableExists(string $name): bool
    {
        if (array_key_exists($name, $this->tableChecks)) {
            return $this->tableChecks[$name];
        }

        $statement = $this->db->prepare('SELECT to_regclass(:name) IS NOT NULL');
        $statement->execute([':name' => $name]);

        return $this->tableChecks[$name] = (bool) $statement->fetchColumn();
    }

    private function languageCatalog(): LanguageCatalog
    {
        return $this->languageCatalog ??= LanguageCatalog::fromPdo($this->db, null);
    }

    private function languageResolution(Request $request): LanguageResolution
    {
        return $this->languageResolution ??= LanguageResolver::fromPdo(
            $this->db,
            null,
            (string) env('API_DEFAULT_LANG', 'es')
        )->resolve($request);
    }

    /**
     * Idioma para las tablas que guardan la etiqueta primaria ('es', 'en').
     * El cliente puede pedir es-AR; el contenido SNOMED/CIE sigue en 'es'.
     */
    private function contentLanguage(Request $request): string
    {
        $code = $this->languageResolution($request)->requestedLanguage;

        return $this->languageCatalog()->primaryTag($code) ?? 'es';
    }

    /**
     * Idioma para las tablas DENTAR, que guardan etiquetas regionales.
     */
    private function requestedLanguage(Request $request): string
    {
        return $this->languageResolution($request)->requestedLanguage;
    }

    private function readCie10Type(Request $request): ?string
    {
        $value = $request->query['cie10_type'] ?? null;

        if ($value === null || $value === '') {
            return null;
        }

        if (!is_string($value)) {
            throw ApiException::badRequest(
                'El parámetro cie10_type es inválido.',
                ['cie10_type' => 'Valores permitidos: diagnostico, procedimiento.']
            );
        }

        return $value;
    }

    private function normalizeCie10Type(?string $type): ?string
    {
        if ($type === null) {
            return null;
        }

        $type = strtolower(trim($type));

        if (!in_array($type, ['diagnostico', 'procedimiento'], true)) {
            throw ApiException::badRequest(
                'El parámetro cie10_type es inválido.',
                ['cie10_type' => 'Valores permitidos: diagnostico, procedimiento.']
            );
        }

        return $type;
    }

    private function normalizeTerm(mixed $value): string
    {
        if (!is_string($value)) {
            throw ApiException::badRequest(
                'El parámetro q es obligatorio.',
                ['q' => 'Enviá un término de búsqueda de entre 2 y 80 caracteres.']
            );
        }

        if (!mb_check_encoding($value, 'UTF-8')) {
            throw ApiException::badRequest(
                'El término de búsqueda no es UTF-8 válido.',
                ['q' => 'La codificación debe ser UTF-8.']
            );
        }

        if (preg_match('/[\x00-\x1F\x7F]/', $value) === 1) {
            throw ApiException::badRequest(
                'El término de búsqueda contiene caracteres no permitidos.',
                ['q' => 'No se permiten caracteres de control.']
            );
        }

        $term = trim((string) preg_replace('/\s+/u', ' ', $value));
        $length = mb_strlen($term, 'UTF-8');

        if ($length < 2 || $length > 80) {
            throw ApiException::badRequest(
                'El término de búsqueda debe tener entre 2 y 80 caracteres.',
                ['q' => 'Longitud recibida: ' . $length . '.']
            );
        }

        return $term;
    }

    private function integerQuery(Request $request, string $name, int $default, int $min, int $max): int
    {
        return $this->readIntParam($request->query[$name] ?? null, $default, $min, $max, $name);
    }

    private function readIntParam(mixed $value, int $default, int $min, int $max, string $name): int
    {
        if ($value === null) {
            return $default;
        }

        if (!is_string($value) && !is_int($value)) {
            throw ApiException::badRequest(
                'El parámetro ' . $name . ' es inválido.',
                [$name => 'Debe ser un número entero entre ' . $min . ' y ' . $max . '.']
            );
        }

        $validated = filter_var($value, FILTER_VALIDATE_INT, [
            'options' => ['min_range' => $min, 'max_range' => $max],
        ]);

        if ($validated === false) {
            throw ApiException::badRequest(
                'El parámetro ' . $name . ' es inválido.',
                [$name => 'Debe ser un número entero entre ' . $min . ' y ' . $max . '.']
            );
        }

        return (int) $validated;
    }

    private function maxLimit(): int
    {
        return max(1, min(100, (int) env('API_PAGE_LIMIT_MAX', 50)));
    }

    /**
     * Escapa comodines de LIKE/ILIKE para buscar el texto de forma literal.
     */
    private function escapeLike(string $value): string
    {
        return str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $value);
    }

    /**
     * Normaliza un posible código CIE-10 para comparar sin puntos ni espacios.
     */
    private function normalizeCode(string $value): string
    {
        return strtoupper(str_replace(['.', ' '], '', $value));
    }
}
