<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Services;

use OrigenSalud\Api\Http\Request;
use PDO;

/**
 * Resolución de idioma de entrada (D-30, etapa 1).
 *
 * Orden: lang -> alias -> Accept-Language (q) -> API_DEFAULT_LANG.
 * Valida solo contra os_language.is_active, os_language_alias y
 * os_catalog_language. No consulta os_field_review, review_status ni
 * ninguna tabla de contenido. es-MX no es alias: se rechaza como entrada.
 */
final class LanguageResolver
{
    public function __construct(
        private readonly LanguageCatalog $catalog,
        private readonly string $defaultLang = 'es',
    ) {
    }

    public static function fromPdo(
        PDO $pdo,
        ?int $catalogId,
        string $defaultLang = 'es'
    ): self {
        return new self(LanguageCatalog::fromPdo($pdo, $catalogId), $defaultLang);
    }

    public function resolve(Request $request): LanguageResolution
    {
        $langInput = $request->query['lang'] ?? null;
        $langInput = is_scalar($langInput) ? trim((string) $langInput) : '';

        $acceptEntries = $this->parseAcceptLanguage($request->header('accept-language'));
        $qZeroOnly = $acceptEntries !== [] && $this->allQZero($acceptEntries);

        $rejected = [];
        $explicit = $this->selectableOrNull($langInput);

        if ($langInput !== '' && $explicit === null) {
            $rejected[] = $langInput;
        }

        $fromHeader = [];

        foreach ($acceptEntries as $entry) {
            if ($entry['q'] <= 0.0) {
                continue;
            }

            $code = $this->selectableOrNull($entry['range']);

            if ($code === null) {
                if ($entry['range'] !== '*') {
                    $rejected[] = $entry['range'];
                }

                continue;
            }

            if (!in_array($code, $fromHeader, true)) {
                $fromHeader[] = $code;
            }
        }

        $default = $this->selectableOrNull($this->defaultLang)
            ?? $this->catalog->activeCodes()[0]
            ?? 'es-AR';

        $candidates = [];

        foreach (array_merge([$explicit], $fromHeader) as $code) {
            if ($code !== null && !in_array($code, $candidates, true)) {
                $candidates[] = $code;
            }
        }

        $usedDefault = false;

        if ($candidates === []) {
            $candidates[] = $default;
            $usedDefault = true;
        }

        $fallbackReason = null;

        if ($qZeroOnly) {
            $fallbackReason = 'no_acceptable_language';
        } elseif ($usedDefault) {
            $fallbackReason = 'default_language';
        }

        return new LanguageResolution(
            $candidates[0],
            $candidates,
            $usedDefault || $qZeroOnly,
            $fallbackReason,
            $qZeroOnly,
            array_values(array_unique($rejected)),
        );
    }

    private function selectableOrNull(string $input): ?string
    {
        if ($input === '') {
            return null;
        }

        return $this->catalog->selectable($input);
    }

    /**
     * @return list<array{range: string, q: float, index: int}>
     */
    private function parseAcceptLanguage(?string $header): array
    {
        if ($header === null || trim($header) === '') {
            return [];
        }

        $entries = [];

        foreach (explode(',', $header) as $index => $part) {
            $segments = explode(';', trim($part));
            $range = trim((string) array_shift($segments));

            if ($range === '') {
                continue;
            }

            $q = 1.0;

            foreach ($segments as $segment) {
                if (preg_match('/^\s*q\s*=\s*([0-9]*\.?[0-9]+)\s*$/i', $segment, $matches) !== 1) {
                    continue;
                }

                $q = max(0.0, min(1.0, (float) $matches[1]));
                break;
            }

            $entries[] = ['range' => $range, 'q' => $q, 'index' => $index];
        }

        usort(
            $entries,
            static function (array $a, array $b): int {
                $byQ = $b['q'] <=> $a['q'];

                return $byQ !== 0 ? $byQ : $a['index'] <=> $b['index'];
            }
        );

        return $entries;
    }

    /**
     * @param list<array{range: string, q: float, index: int}> $entries
     */
    private function allQZero(array $entries): bool
    {
        foreach ($entries as $entry) {
            if ($entry['q'] > 0.0) {
                return false;
            }
        }

        return true;
    }
}
