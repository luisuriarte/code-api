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
            'filters' => ['t.descripcion', 't.codigo_nomenclador', 't.cdt_code'],
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
        $language = $this->normalizeLanguage($this->readLanguage($request));
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
        $language = $this->normalizeLanguage($this->readLanguage($request));

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
        $language = $this->normalizeLanguage($this->readLanguage($request));
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
        $language = $this->normalizeLanguage($this->readLanguage($request));

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

    private function readLanguage(Request $request): string
    {
        $value = $request->query['lang'] ?? env('API_DEFAULT_LANG', 'es');

        if (!is_string($value) || trim($value) === '') {
            throw ApiException::badRequest(
                'El parámetro lang es inválido.',
                ['lang' => 'Valores permitidos: es, en.']
            );
        }

        return $value;
    }

    private function normalizeLanguage(string $language): string
    {
        $primary = strtolower(explode('-', trim($language))[0]);

        if (!in_array($primary, ['es', 'en'], true)) {
            throw ApiException::badRequest(
                'El parámetro lang es inválido.',
                ['lang' => 'Valores permitidos: es, en.']
            );
        }

        return $primary;
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
        $value = $request->query[$name] ?? null;

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
