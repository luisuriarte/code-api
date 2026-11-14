<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Controllers;

use OrigenSalud\Api\Http\ApiException;
use OrigenSalud\Api\Http\Request;
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
        $meta['took_ms'] = round((hrtime(true) - $startedAt) / 1_000_000, 2);

        return [
            'data' => $data,
            'meta' => $meta,
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

        $language = $this->resolveLanguage($request);

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

        return [
            'data' => [
                'concept_id' => (string) $concept['concept_id'],
                'active' => $this->toBool($concept['active']),
                'effective_time' => (string) $concept['effective_time'],
                'module_id' => (string) $concept['module_id'],
                'definition_status_id' => (string) $concept['definition_status_id'],
                'descriptions' => $descriptions,
                'parents' => $this->relatedConcepts($conceptId, $language, 'parents'),
                'children' => $this->relatedConcepts($conceptId, $language, 'children'),
                'cie10_codes' => $this->mappedCie10($conceptId, $language),
            ],
            'meta' => [
                'language' => $language,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
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

    private function resolveLanguage(Request $request): string
    {
        $value = $request->query['lang'] ?? $this->defaultLanguage();

        if (!is_string($value) || trim($value) === '') {
            throw ApiException::badRequest(
                'El parámetro lang es inválido.',
                ['lang' => 'Valores permitidos: es, en.']
            );
        }

        // Acepta variantes regionales como es-AR o en-US y las normaliza.
        $primary = strtolower(explode('-', trim($value))[0]);

        if (!in_array($primary, ['es', 'en'], true)) {
            throw ApiException::badRequest(
                'El parámetro lang es inválido.',
                ['lang' => 'Valores permitidos: es, en.']
            );
        }

        return $primary;
    }

    private function defaultLanguage(): string
    {
        $configured = strtolower(trim((string) env('API_DEFAULT_LANG', 'es')));

        return in_array($configured, ['es', 'en'], true) ? $configured : 'es';
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
