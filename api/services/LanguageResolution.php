<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Services;

/**
 * Resultado del resolvedor de idioma (D-30).
 *
 * Contiene solo idiomas seleccionables. Nunca incluye contenido ni estados
 * editoriales: esos los resuelve EditorialEvaluator.
 */
final class LanguageResolution
{
    /**
     * @param list<string> $candidates
     * @param list<string> $rejected
     */
    public function __construct(
        public readonly string $requestedLanguage,
        public readonly array $candidates,
        public readonly bool $fallbackApplied,
        public readonly ?string $fallbackReason,
        public readonly bool $qZeroOnly,
        public readonly array $rejected,
    ) {
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return [
            'requested_language' => $this->requestedLanguage,
            'candidates' => $this->candidates,
            'fallback_applied' => $this->fallbackApplied,
            'fallback_reason' => $this->fallbackReason,
            'q_zero_only' => $this->qZeroOnly,
            'rejected' => $this->rejected,
        ];
    }
}
