<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Services;

/**
 * Evaluador editorial de publicación (D-30, etapa 2).
 *
 * Toma la lista de idiomas del resolvedor, la amplía con el idioma de origen y
 * la configuración del catálogo, descarta todo estado distinto de approved y
 * elige el primer candidato aprobado. No cae a la columna original cuando no
 * hay contenido aprobado (D-20): devuelve null + untranslated=true.
 */
final class EditorialEvaluator
{
    public function __construct(
        private readonly LanguageCatalog $catalog,
        private readonly FieldReviewRepository $reviews,
    ) {
    }

    /**
     * @param array{
     *     target_table: string,
     *     target_id: int,
     *     catalog_id?: int|null,
     *     release_id?: int|null,
     *     requested_language: string,
     *     source_language_code?: string|null,
     *     fields: array<string, list<array<string, mixed>>>
     * } $spec Cada variante puede traer `target_id` para no heredar revisiones
     * de otra fila (D-28).
     */
    public function evaluate(array $spec): EditorialResult
    {
        $targetTable = (string) ($spec['target_table'] ?? '');
        $targetId = (int) ($spec['target_id'] ?? 0);
        $catalogId = isset($spec['catalog_id']) && $spec['catalog_id'] !== null
            ? (int) $spec['catalog_id']
            : null;
        $releaseId = isset($spec['release_id']) && $spec['release_id'] !== null
            ? (int) $spec['release_id']
            : null;
        $requestedLanguage = (string) ($spec['requested_language'] ?? '');
        $sourceLanguage = isset($spec['source_language_code']) && $spec['source_language_code'] !== null
            ? (string) $spec['source_language_code']
            : null;
        $fields = is_array($spec['fields'] ?? null) ? $spec['fields'] : [];

        $candidates = $this->buildCandidates($requestedLanguage, $sourceLanguage, $catalogId);

        // El repositorio de revisiones se inyecta: así el evaluador se prueba
        // sin PDO y el resolvedor sigue sin tocar tablas de contenido.
        $values = [];
        $fieldLanguages = [];
        $available = [];

        foreach ($fields as $fieldName => $variants) {
            $selected = $this->selectVariant(
                (string) $fieldName,
                is_array($variants) ? $variants : [],
                $candidates,
                $requestedLanguage,
                $releaseId,
                $targetTable,
                $targetId
            );

            $values[$fieldName] = $selected['value'];
            $fieldLanguages[$fieldName] = $selected['language'];

            if ($selected['language']['effective_language'] !== null) {
                $code = (string) $selected['language']['effective_language'];
                $available[$code] = [
                    'code' => $code,
                    'selectable' => $this->catalog->isSelectable($code),
                ];
            }
        }

        $availableLanguages = array_values($available);
        usort(
            $availableLanguages,
            static fn (array $a, array $b): int => strcmp($a['code'], $b['code'])
        );

        $effectiveLanguages = array_column($fieldLanguages, 'effective_language');
        $sourceLanguages = array_column($fieldLanguages, 'source_language');
        $provenances = array_column($fieldLanguages, 'provenance');
        $approvalStates = array_column($fieldLanguages, 'approval_state');
        $fallbackReasons = array_filter(array_column($fieldLanguages, 'fallback_reason'));

        $uniformEffective = $this->uniform($effectiveLanguages);
        $meta = [
            'requested_language' => $requestedLanguage,
            'effective_language' => $uniformEffective,
            'source_language' => $this->uniform($sourceLanguages),
            'provenance' => $this->uniform($provenances),
            'approval_state' => $this->uniform($approvalStates),
            'fallback_applied' => in_array(true, array_column($fieldLanguages, 'fallback_applied'), true),
            'fallback_reason' => $this->uniform(array_values($fallbackReasons)),
            'untranslated' => in_array(true, array_column($fieldLanguages, 'untranslated'), true),
        ];

        return new EditorialResult(
            $values,
            $fieldLanguages,
            $meta,
            $availableLanguages,
            $uniformEffective,
        );
    }

    /**
     * @return list<array{code: string, reason: string|null}>
     */
    private function buildCandidates(
        string $requestedLanguage,
        ?string $sourceLanguage,
        ?int $catalogId
    ): array {
        $candidates = [];

        $add = static function (array &$list, ?string $code, ?string $reason): void {
            if ($code === null || $code === '') {
                return;
            }

            foreach ($list as $entry) {
                if ($entry['code'] === $code) {
                    return;
                }
            }

            $list[] = ['code' => $code, 'reason' => $reason];
        };

        $add($candidates, $this->catalog->canonical($requestedLanguage), null);
        $add($candidates, $this->catalog->canonical($sourceLanguage), 'source_language');

        foreach ($this->catalog->configuredCodes($catalogId, 'is_fallback') as $code) {
            $add($candidates, $code, 'fallback_language');
        }

        foreach ($this->catalog->configuredCodes($catalogId, 'is_bridge') as $code) {
            $add($candidates, $code, 'bridge_language');
        }

        foreach ($this->catalog->configuredCodes($catalogId, 'is_default') as $code) {
            $add($candidates, $code, 'default_language');
        }

        $add($candidates, $this->catalog->canonical('es-AR'), 'global_default');

        return $candidates;
    }

    /**
     * Código de contenido. 'undet' es una etiqueta de ausencia de idioma, no un
     * código de os_language: se acepta literalmente para os_concept_mapping
     * (D-19) sin pasar por el catálogo ni inventar una variante regional.
     */
    private function contentCode(?string $input): ?string
    {
        if ($input !== null && strtolower(trim($input)) === 'undet') {
            return 'undet';
        }

        return $this->catalog->canonical($input);
    }

    /**
     * Publicación de un campo de os_concept_mapping aprobado bajo D-19.
     *
     * La tabla no tiene language_code: su revisión usa 'undet'. El texto solo
     * se devuelve si existe revisión aprobada y su hash coincide con el valor
     * actual; si no, se devuelve null + untranslated=true (D-20).
     *
     * @param array{
     *     target_id: int,
     *     requested_language: string,
     *     field_name: string,
     *     variants: list<array<string, mixed>>
     * } $spec
     */
    public function evaluateUndet(array $spec): EditorialResult
    {
        $fieldName = (string) ($spec['field_name'] ?? '');
        $targetId = (int) ($spec['target_id'] ?? 0);
        $requestedLanguage = (string) ($spec['requested_language'] ?? '');
        $variants = is_array($spec['variants'] ?? null) ? $spec['variants'] : [];

        $selected = $this->selectVariant(
            $fieldName,
            $variants,
            [['code' => 'undet', 'reason' => null]],
            $requestedLanguage,
            null,
            'os_concept_mapping',
            $targetId
        );

        // 'undet' no es un idioma seleccionable ni un fallback del cliente:
        // se declara con precisión, sin convertirlo en es-AR ni marcarlo como
        // traducción exitosa en otro idioma.
        if ($selected['language']['effective_language'] === 'undet') {
            $selected['language']['fallback_applied'] = false;
            $selected['language']['fallback_reason'] = null;
        }

        $values = [$fieldName => $selected['value']];
        $fieldLanguages = [$fieldName => $selected['language']];

        return new EditorialResult(
            $values,
            $fieldLanguages,
            [
                'requested_language' => $requestedLanguage,
                'effective_language' => $selected['language']['effective_language'],
                'source_language' => $selected['language']['source_language'],
                'provenance' => $selected['language']['provenance'],
                'approval_state' => $selected['language']['approval_state'],
                'fallback_applied' => $selected['language']['fallback_applied'],
                'fallback_reason' => $selected['language']['fallback_reason'],
                'untranslated' => $selected['language']['untranslated'],
            ],
            [],
            null
        );
    }

    /**
     * @param list<array<string, mixed>> $variants
     * @param list<array{code: string, reason: string|null}> $candidates
     *
     * @return array{value: mixed, language: array<string, mixed>}
     */
    private function selectVariant(
        string $fieldName,
        array $variants,
        array $candidates,
        string $requestedLanguage,
        ?int $releaseId,
        string $targetTable,
        int $targetId
    ): array {
        $byLanguage = [];

        foreach ($variants as $variant) {
            if (!is_array($variant)) {
                continue;
            }

            $code = $this->contentCode(isset($variant['language_code'])
                ? (string) $variant['language_code']
                : null);

            if ($code === null) {
                continue;
            }

            $byLanguage[strtolower($code)] = $variant;
        }

        foreach ($candidates as $candidate) {
            $code = $candidate['code'];
            $variant = $byLanguage[strtolower($code)] ?? null;

            if ($variant === null) {
                continue;
            }

            $hash = isset($variant['content_hash']) ? (string) $variant['content_hash'] : '';
            $variantTargetId = isset($variant['target_id']) && $variant['target_id'] !== null
                ? (int) $variant['target_id']
                : $targetId;
            $review = $this->reviews->bestApproved($fieldName, $code, $releaseId, $hash, $variantTargetId);

            if ($code === 'undet' && $review === null) {
                // D-19/D-20: os_concept_mapping conserva un review_status
                // heredado 'approved', pero sin os_field_review NO es
                // publicable. La columna original no es evidencia editorial.
                continue;
            }

            if ($review === null && $this->reviews->hasBlockingReview(
                $fieldName,
                $code,
                $releaseId,
                $hash,
                $variantTargetId
            )) {
                continue;
            }

            if ($review === null && (string) ($variant['review_status'] ?? 'unknown') !== 'approved') {
                continue;
            }

            $effectiveLanguage = $this->contentCode(isset($variant['language_code'])
                ? (string) $variant['language_code']
                : $code) ?? $code;

            if ($targetTable === 'loinc_localized_text') {
                $sourceLanguage = LoincSourceLanguage::resolve(
                    $effectiveLanguage,
                    isset($variant['source_file']) ? (string) $variant['source_file'] : null
                );

                if ($sourceLanguage === null) {
                    // D-40: sin evidencia del archivo, la fila no se publica.
                    continue;
                }
            } else {
                $sourceLanguage = $review['source_language_code'] ?? null;

                if ($sourceLanguage === null) {
                    $sourceLanguage = isset($variant['source_language_code'])
                        ? (string) $variant['source_language_code']
                        : null;
                }

                if ($sourceLanguage === null || $sourceLanguage === '') {
                    $sourceLanguage = null;
                }
            }

            $evidence = $review['language_evidence'] ?? null;

            if ($evidence === null) {
                $evidence = isset($variant['language_evidence'])
                    ? (string) $variant['language_evidence']
                    : 'undetermined';
            }

            $provenance = $review['provenance'] ?? null;

            if ($provenance === null || $provenance === '') {
                $provenance = isset($variant['provenance'])
                    ? (string) $variant['provenance']
                    : 'unknown';
            }

            $fallbackApplied = $effectiveLanguage !== $requestedLanguage;
            $fallbackReason = $fallbackApplied ? $candidate['reason'] : null;

            $dialectDetermined = $evidence === 'declared_by_source'
                || str_contains($effectiveLanguage, '-');

            if ($effectiveLanguage === 'es' && $requestedLanguage === 'es-AR' && !$dialectDetermined) {
                $fallbackReason = 'rf2_dialect_undetermined';
            }

            if (!$fallbackApplied) {
                $fallbackReason = null;
            }

            return [
                'value' => $variant['value'] ?? null,
                'language' => [
                    'effective_language' => $effectiveLanguage,
                    'source_language' => $sourceLanguage,
                    'provenance' => $provenance,
                    'approval_state' => 'approved',
                    'fallback_applied' => $fallbackApplied,
                    'fallback_reason' => $fallbackReason,
                    'untranslated' => false,
                    'dialect_determined' => $dialectDetermined,
                ],
            ];
        }

        return [
            'value' => null,
            'language' => [
                'effective_language' => null,
                'source_language' => null,
                'provenance' => null,
                'approval_state' => null,
                'fallback_applied' => false,
                'fallback_reason' => 'no_approved_content',
                'untranslated' => true,
                'dialect_determined' => false,
            ],
        ];
    }

    /**
     * @param list<mixed> $values
     */
    private function uniform(array $values): mixed
    {
        if ($values === []) {
            return null;
        }

        $first = $values[0];

        foreach ($values as $value) {
            if ($value !== $first) {
                return null;
            }
        }

        return $first;
    }
}
