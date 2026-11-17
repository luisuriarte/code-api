<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Services;

use PDO;

/**
 * Dual-read condicionado de os_concept_mapping (D-20, D-30, D-19).
 *
 * Los campos external_display y clinical_rationale se sirven desde la columna
 * original SOLO cuando existe una revisión aprobada vigente en os_field_review
 * (language_code='undet', sin release). Si no hay aprobación, o el texto cambió
 * y el hash ya no coincide, el valor es null y se informa untranslated=true.
 * Nunca se usa la columna original como atajo editorial.
 */
final class MappingReviewReader
{
    private const FIELDS = ['external_display', 'clinical_rationale'];

    public function __construct(
        private readonly PDO $db,
        private readonly LanguageCatalog $catalog,
    ) {
    }

    /**
     * @param list<array<string, mixed>> $rows
     * @return array<int, array{
     *     external_display: mixed,
     *     clinical_rationale: mixed,
     *     field_languages: array<string, array<string, mixed>>,
     *     untranslated: bool
     * }>
     */
    public function resolve(array $rows, string $requestedLanguage): array
    {
        $byId = [];

        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }

            $id = (int) ($row['id'] ?? 0);

            if ($id > 0) {
                $byId[$id] = $row;
            }
        }

        if ($byId === []) {
            return [];
        }

        $reviews = FieldReviewRepository::fromPdoForTargets(
            $this->db,
            ['os_concept_mapping'],
            array_keys($byId),
            self::FIELDS
        );
        $editorial = new EditorialEvaluator($this->catalog, $reviews);
        $resolved = [];

        foreach ($byId as $id => $row) {
            $values = [];
            $languages = [];
            $untranslated = false;

            foreach (self::FIELDS as $field) {
                $raw = $row[$field] ?? null;
                $value = $raw === null ? null : (string) $raw;

                if ($value === null || trim($value) === '') {
                    $values[$field] = null;
                    $languages[$field] = [
                        'effective_language' => null,
                        'source_language' => null,
                        'provenance' => null,
                        'approval_state' => null,
                        'fallback_applied' => false,
                        'fallback_reason' => null,
                        'untranslated' => false,
                        'dialect_determined' => false,
                    ];
                    continue;
                }

                $sourceReference = $row['source_reference'] ?? null;
                $variant = [
                    'language_code' => 'undet',
                    'review_status' => (string) ($row['review_status'] ?? 'unknown'),
                    'source_language_code' => $this->nonEmpty(
                        $row['source_language_code_display'] ?? null
                    ) ?? $this->nonEmpty($row['source_language_code'] ?? null),
                    'provenance' => (string) ($row['provenance'] ?? 'unknown'),
                    'language_evidence' => (string) ($row['language_evidence'] ?? 'undetermined'),
                    'content_hash' => $reviews->contentHash(
                        $value,
                        'undet',
                        $sourceReference === null ? null : (string) $sourceReference
                    ),
                    'target_id' => $id,
                    'value' => $value,
                ];

                $result = $editorial->evaluateUndet([
                    'target_id' => $id,
                    'requested_language' => $requestedLanguage,
                    'field_name' => $field,
                    'variants' => [$variant],
                ]);

                $values[$field] = $result->values()[$field] ?? null;
                $languages[$field] = $result->fieldLanguages()[$field];
                $untranslated = $untranslated
                    || ($result->fieldLanguages()[$field]['untranslated'] ?? false);
            }

            $resolved[$id] = [
                'external_display' => $values['external_display'],
                'clinical_rationale' => $values['clinical_rationale'],
                'field_languages' => $languages,
                'untranslated' => $untranslated,
            ];
        }

        return $resolved;
    }

    private function nonEmpty(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $text = trim((string) $value);

        return $text === '' ? null : $text;
    }
}
