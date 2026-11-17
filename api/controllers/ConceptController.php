<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Controllers;

use OrigenSalud\Api\Http\ApiException;
use OrigenSalud\Api\Http\Request;
use OrigenSalud\Api\Services\LanguageCatalog;
use OrigenSalud\Api\Services\LanguageResolution;
use OrigenSalud\Api\Services\LanguageResolver;
use OrigenSalud\Api\Services\TerminologySearchService;
use PDO;

/**
 * Lógica de negocio de los endpoints de conceptos SNOMED-CT.
 *
 * Los SCTID se devuelven como strings para evitar la pérdida de precisión
 * que sufren los clientes JavaScript con enteros mayores a 2^53.
 */
final class ConceptController
{
    private const IS_A_RELATIONSHIP = '116680003';
    private const TYPE_FULLY_SPECIFIED_NAME = '900000000000003001';
    private const TYPE_SYNONYM = '900000000000013009';

    private const MAX_DETAIL_DESCRIPTIONS = 200;
    private const MAX_HIERARCHY_RESULTS = 50;
    private const MAX_CIE10_MAPPINGS = 50;

    private readonly TerminologySearchService $searchService;

    private ?LanguageCatalog $languageCatalog = null;

    private ?LanguageResolution $languageResolution = null;

    public function __construct(private readonly PDO $db)
    {
        $this->searchService = new TerminologySearchService($db);
    }

    /**
     * GET /v1/concepts/search?q=infarto&lang=es&limit=10&offset=0
     *
     * Se mantiene como alias compatible del dominio SNOMED del buscador
     * unificado. La lógica SQL vive en TerminologySearchService.
     *
     * @return array{data: list<array<string, mixed>>, meta: array<string, mixed>}
     */
    public function search(Request $request): array
    {
        $startedAt = hrtime(true);
        $result = $this->searchService->search($request, TerminologySearchService::DOMAIN_SNOMED);
        $data = [];

        foreach ($result['data'] as $row) {
            $metadata = $row['metadata'];

            $data[] = [
                'description_id' => (string) ($metadata['description_id'] ?? ''),
                'concept_id' => (string) ($metadata['concept_id'] ?? $row['id']),
                'term' => (string) $row['term'],
                'language' => (string) $row['language'],
                'term_type' => (string) ($metadata['term_type'] ?? $row['kind']),
                'type_id' => (string) ($metadata['type_id'] ?? ''),
                'score' => (float) $row['score'],
            ];
        }

        $meta = $result['meta'];
        $meta['requested_language'] = $this->languageContext($request)['resolution']->requestedLanguage;
        $meta['took_ms'] = round((hrtime(true) - $startedAt) / 1_000_000, 2);

        return [
            'data' => $data,
            'meta' => $meta,
            'headers' => ['Vary' => 'Accept-Language'],
        ];
    }

    /**
     * GET /v1/concepts/{id}?lang=es
     *
     * Devuelve el concepto, sus descripciones agrupadas por idioma y sus
     * relaciones jerárquicas directas (padres e hijos).
     *
     * @return array{data: array<string, mixed>, meta: array<string, mixed>}
     */
    public function show(string $conceptId, Request $request): array
    {
        $startedAt = hrtime(true);

        if (preg_match('/^[0-9]{6,18}$/', $conceptId) !== 1) {
            throw ApiException::badRequest('El identificador del concepto no es un SCTID válido.');
        }

        $languageContext = $this->languageContext($request);
        $language = $languageContext['content_language'];
        $resolution = $languageContext['resolution'];
        $catalog = $languageContext['catalog'];

        $statement = $this->db->prepare(
            'SELECT CAST(id AS text)                  AS concept_id,
                    active,
                    CAST(effective_time AS text)      AS effective_time,
                    CAST(module_id AS text)           AS module_id,
                    CAST(definition_status_id AS text) AS definition_status_id
               FROM snomed_concepts
              WHERE id = CAST(:id AS bigint)
              LIMIT 1'
        );

        $statement->execute([':id' => $conceptId]);
        $concept = $statement->fetch();

        if ($concept === false) {
            throw ApiException::notFound('No se encontró el concepto SNOMED-CT solicitado.');
        }

        $descriptionsStatement = $this->db->prepare(
            'SELECT CAST(id AS text)       AS description_id,
                    term,
                    language_code         AS language,
                    CAST(type_id AS text) AS type_id
               FROM snomed_descriptions
              WHERE concept_id = CAST(:id AS bigint)
                AND active = TRUE
              ORDER BY language_code ASC,
                       (type_id = CAST(:synonym AS bigint)) DESC,
                       length(term) ASC,
                       term ASC
              LIMIT ' . self::MAX_DETAIL_DESCRIPTIONS
        );

        $descriptionsStatement->execute([
            ':id' => $conceptId,
            ':synonym' => self::TYPE_SYNONYM,
        ]);
        $descriptions = [];

        foreach ($descriptionsStatement->fetchAll() as $row) {
            $descriptionLanguage = (string) $row['language'];

            $descriptions[$descriptionLanguage] ??= [];
            $descriptions[$descriptionLanguage][] = [
                'description_id' => (string) $row['description_id'],
                'term' => (string) $row['term'],
                'term_type' => $this->termType((string) $row['type_id']),
                'type_id' => (string) $row['type_id'],
            ];
        }

        $data = [
            'concept_id' => (string) $concept['concept_id'],
            'active' => $this->toBool($concept['active']),
            'effective_time' => (string) $concept['effective_time'],
            'module_id' => (string) $concept['module_id'],
            'definition_status_id' => (string) $concept['definition_status_id'],
            'descriptions' => $descriptions,
            'parents' => $this->relatedConcepts($conceptId, $language, 'parents'),
            'children' => $this->relatedConcepts($conceptId, $language, 'children'),
            'cie10_codes' => $this->mappedCie10($conceptId, $language),
        ];

        $dental = $this->dentalMappings($conceptId, $language);
        if ($dental !== null) {
            $data['dental'] = $dental;
        }

        $requestedLanguage = $resolution->requestedLanguage;
        $fallbackApplied = $language !== $requestedLanguage;
        $fallbackReason = $fallbackApplied
            ? ($language === 'es' ? 'rf2_dialect_undetermined' : 'language_fallback')
            : null;
        $dialectDetermined = !($language === 'es' && $fallbackApplied);
        $available = [];

        foreach (array_merge(array_keys($descriptions), $catalog->activeCodes()) as $code) {
            $canonical = $catalog->canonical((string) $code) ?? (string) $code;
            $available[$canonical] = [
                'code' => $canonical,
                'selectable' => $catalog->isSelectable($canonical),
            ];
        }

        $availableLanguages = array_values($available);
        usort(
            $availableLanguages,
            static fn (array $a, array $b): int => strcmp($a['code'], $b['code'])
        );

        return [
            'data' => $data,
            'meta' => [
                'language' => $language,
                'requested_language' => $requestedLanguage,
                'effective_language' => $language,
                'rf2_language_tag' => $language,
                'dialect_determined' => $dialectDetermined,
                'fallback_applied' => $fallbackApplied,
                'fallback_reason' => $fallbackReason,
                'available_languages' => $availableLanguages,
                'field_languages' => [
                    'descriptions' => [
                        'effective_language' => $language,
                        'source_language' => $language,
                        'provenance' => 'rf2',
                        'approval_state' => null,
                        'fallback_applied' => $fallbackApplied,
                        'fallback_reason' => $fallbackReason,
                        'untranslated' => $descriptions === [],
                        'dialect_determined' => $dialectDetermined,
                    ],
                ],
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
            'headers' => [
                'Vary' => 'Accept-Language',
                'Content-Language' => $language,
            ],
        ];
    }

    /**
     * Obtiene los vínculos odontológicos (procedimientos DENTAR/Nomenclador/CDT y/o diagnósticos)
     * vinculados al concepto SNOMED-CT, si existen.
     *
     * @return array{procedures: list<array<string, mixed>>, diagnoses: list<array<string, mixed>>}|null
     */
    private function dentalMappings(string $conceptId, string $language): ?array
    {
        $procedures = [];
        $diagnoses = [];

        // 1. Procedimientos odontológicos asociados al concepto
        try {
            $stmtProc = $this->db->prepare(
                'SELECT DISTINCT
                        p.id,
                        p.codigo AS codigo_nomenclador,
                        p.descripcion,
                        p.capitulo,
                        p.cdt_code,
                        p.cdt_categoria,
                        m_dnt.dentar_code
                   FROM odontologia_prestaciones p
                   LEFT JOIN (
                       SELECT c.code AS dentar_code, m.external_code
                         FROM dentar_concept c
                         JOIN dentar_concept_version cv ON cv.concept_id = c.id
                         JOIN dentar_concept_mapping m ON m.concept_version_id = cv.id AND m.system_code = \'NOMENCLADOR-AR\'
                   ) m_dnt ON m_dnt.external_code = p.codigo
                  WHERE p.snomed_concept_id = CAST(:id AS bigint)
                     OR EXISTS (
                         SELECT 1 FROM dentar_concept_mapping sm
                          WHERE sm.system_code = \'SNOMED-CT\'
                            AND sm.external_code = :id_str
                            AND sm.concept_version_id IN (
                                SELECT cv2.id FROM dentar_concept_version cv2
                                  JOIN dentar_concept_mapping m2 ON m2.concept_version_id = cv2.id
                                 WHERE m2.system_code = \'NOMENCLADOR-AR\' AND m2.external_code = p.codigo
                            )
                     )
                  ORDER BY p.codigo ASC'
            );
            $stmtProc->execute([
                ':id' => $conceptId,
                ':id_str' => $conceptId,
            ]);
            foreach ($stmtProc->fetchAll() as $r) {
                $procedures[] = [
                    'id' => (string) $r['id'],
                    'dentar_code' => $r['dentar_code'] !== null ? (string) $r['dentar_code'] : null,
                    'nomenclator_code' => (string) $r['codigo_nomenclador'],
                    'description' => (string) $r['descripcion'],
                    'chapter' => $r['capitulo'] !== null ? (string) $r['capitulo'] : null,
                    'cdt_code' => $r['cdt_code'] !== null ? (string) $r['cdt_code'] : null,
                    'cdt_category' => $r['cdt_categoria'] !== null ? (string) $r['cdt_categoria'] : null,
                ];
            }
        } catch (\Throwable) {
            // Tablas opcionales si aún no migraron
        }

        // 2. Diagnósticos odontológicos asociados al concepto
        try {
            $stmtDiag = $this->db->prepare(
                'SELECT d.code AS dentar_diagnosis_code,
                        d.clinical_name,
                        m_cie.external_code AS cie10_code,
                        m_cie.external_display AS cie10_description
                   FROM dentar_diagnosis d
                   JOIN dentar_diagnosis_mapping m_sct ON m_sct.diagnosis_id = d.id AND m_sct.system_code = \'SNOMED-CT\'
                   LEFT JOIN dentar_diagnosis_mapping m_cie ON m_cie.diagnosis_id = d.id AND m_cie.system_code = \'CIE-10\'
                  WHERE m_sct.external_code = :id
                  ORDER BY d.code ASC'
            );
            $stmtDiag->execute([':id' => $conceptId]);
            foreach ($stmtDiag->fetchAll() as $r) {
                $diagnoses[] = [
                    'dentar_diagnosis_code' => (string) $r['dentar_diagnosis_code'],
                    'clinical_name' => (string) $r['clinical_name'],
                    'cie10' => $r['cie10_code'] !== null ? [
                        'code' => (string) $r['cie10_code'],
                        'description' => (string) $r['cie10_description'],
                    ] : null,
                ];
            }
        } catch (\Throwable) {
            // Tablas opcionales si aún no migraron
        }

        if (empty($procedures) && empty($diagnoses)) {
            return null;
        }

        return [
            'procedures' => $procedures,
            'diagnoses' => $diagnoses,
        ];
    }

    /**
     * Obtiene los códigos CIE-10 mapeados al concepto SNOMED.
     *
     * @return list<array{code: string, type: string, description: string|null}>
     */
    private function mappedCie10(string $conceptId, string $language): array
    {
        $limit = self::MAX_CIE10_MAPPINGS;

        $sql = <<<SQL
            SELECT c.codigo,
                   c.tipo,
                   (
                       SELECT d.descripcion
                         FROM cie10_descriptions d
                        WHERE d.cie10_id = c.id
                          AND d.language_code = :language
                        ORDER BY length(d.descripcion) ASC,
                                 d.descripcion ASC
                        LIMIT 1
                   ) AS description
              FROM map_snomed_cie10 m
              INNER JOIN cie10_codes c ON c.id = m.cie10_id
             WHERE m.snomed_concept_id = CAST(:id AS bigint)
             ORDER BY c.codigo ASC
             LIMIT {$limit}
            SQL;

        $statement = $this->db->prepare($sql);
        $statement->execute([
            ':language' => $language,
            ':id' => $conceptId,
        ]);

        return array_map(
            static fn (array $row): array => [
                'code' => (string) $row['codigo'],
                'type' => (string) $row['tipo'],
                'description' => $row['description'] !== null ? (string) $row['description'] : null,
            ],
            $statement->fetchAll()
        );
    }

    /**
     * Obtiene padres o hijos directos mediante la relación Is-A.
     *
     * @return list<array{concept_id: string, term: string|null, active: bool}>
     */
    private function relatedConcepts(string $conceptId, string $language, string $direction): array
    {
        $joinColumn = $direction === 'parents'
            ? 'destination_id'
            : 'source_id';

        $relatedColumn = $direction === 'parents'
            ? 'source_id'
            : 'destination_id';

        $limit = self::MAX_HIERARCHY_RESULTS;

        $sql = <<<SQL
            SELECT DISTINCT
                   CAST(p.id AS text) AS concept_id,
                   p.active,
                   (
                       SELECT d.term
                         FROM snomed_descriptions d
                        WHERE d.concept_id = p.id
                          AND d.active = TRUE
                          AND d.language_code = :language
                        ORDER BY (d.type_id = CAST(:synonym AS bigint)) DESC,
                                 length(d.term) ASC,
                                 d.term ASC
                        LIMIT 1
                   ) AS term
              FROM snomed_relationships r
              INNER JOIN snomed_concepts p ON p.id = r.{$joinColumn}
             WHERE r.{$relatedColumn} = CAST(:id AS bigint)
               AND r.type_id = CAST(:is_a AS bigint)
               AND r.active = TRUE
               AND p.active = TRUE
             ORDER BY term ASC NULLS LAST
             LIMIT {$limit}
            SQL;

        $statement = $this->db->prepare($sql);
        $statement->execute([
            ':id' => $conceptId,
            ':language' => $language,
            ':is_a' => self::IS_A_RELATIONSHIP,
            ':synonym' => self::TYPE_SYNONYM,
        ]);

        return array_map(
            fn (array $row): array => [
                'concept_id' => (string) $row['concept_id'],
                'term' => $row['term'] !== null ? (string) $row['term'] : null,
                'active' => $this->toBool($row['active']),
            ],
            $statement->fetchAll()
        );
    }

    /**
     * @return array{
     *     catalog: LanguageCatalog,
     *     resolution: LanguageResolution,
     *     content_language: string
     * }
     */
    private function languageContext(Request $request): array
    {
        $this->languageCatalog ??= LanguageCatalog::fromPdo($this->db, null);
        $this->languageResolution ??= LanguageResolver::fromPdo(
            $this->db,
            null,
            (string) env('API_DEFAULT_LANG', 'es')
        )->resolve($request);

        $requested = $this->languageResolution->requestedLanguage;

        return [
            'catalog' => $this->languageCatalog,
            'resolution' => $this->languageResolution,
            'content_language' => $this->languageCatalog->primaryTag($requested) ?? 'es',
        ];
    }

    private function termType(string $typeId): string
    {
        return match ($typeId) {
            self::TYPE_FULLY_SPECIFIED_NAME => 'fsn',
            self::TYPE_SYNONYM => 'synonym',
            default => 'other',
        };
    }

    private function toBool(mixed $value): bool
    {
        return $value === true
            || $value === 1
            || $value === '1'
            || $value === 't'
            || $value === 'true';
    }
}
