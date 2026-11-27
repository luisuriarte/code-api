<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

final class HomeController
{
    public static function index(string $locale, string $currentPath): void
    {
        $t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
        $apiLocale = I18n::metadata($locale)['api_language'];

        $exampleLanguage = $apiLocale === 'en' ? 'en' : 'es';
        $exampleFallback = $exampleLanguage !== $apiLocale;
        $exampleFallbackReason = $exampleFallback ? 'rf2_dialect_undetermined' : null;

        $exampleResponse = [
            'data' => [
                [
                    'description_id' => '138875005',
                    'concept_id' => '22298006',
                    'term' => $t('api.example_term'),
                    'language' => $exampleLanguage,
                    'term_type' => 'synonym',
                    'type_id' => '900000000000013009',
                    'score' => 0.9871,
                ],
            ],
            // Ejemplo derivado de la proyección real de /v1/concepts/search:
            // el wrapper común agrega items con provenance/approval_state null.
            'meta' => [
                'query' => $t('api.example_query'),
                'language' => $exampleLanguage,
                'domains' => ['snomed'],
                'cie10_type' => null,
                'refsets' => [],
                'limit' => 10,
                'offset' => 0,
                'returned' => 1,
                'has_more' => false,
                'next_offset' => null,
                'page_counts' => ['snomed' => 1],
                'took_ms' => 12.4,
                'requested_language' => $apiLocale,
                'effective_language' => $exampleLanguage,
                'source_language' => $exampleLanguage,
                'fallback_applied' => $exampleFallback,
                'fallback_reason' => $exampleFallbackReason,
                'untranslated' => false,
                'dialect_determined' => $exampleLanguage === 'en',
                'available_languages' => [
                    ['code' => 'es-AR', 'selectable' => true],
                    ['code' => 'en', 'selectable' => true],
                    ['code' => 'pt-BR', 'selectable' => true],
                ],
                'field_languages' => [
                    'items' => [
                        'effective_language' => $exampleLanguage,
                        'source_language' => $exampleLanguage,
                        'provenance' => null,
                        'approval_state' => null,
                        'fallback_applied' => $exampleFallback,
                        'fallback_reason' => $exampleFallbackReason,
                        'untranslated' => false,
                        'dialect_determined' => $exampleLanguage === 'en',
                    ],
                ],
            ],
            'request_id' => '7f3c9a1e8b2d4f60',
        ];

        $exampleJson = json_encode(
            $exampleResponse,
            JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
        ) ?: '{}';

        $contactEmail = Config::contactEmail();

        View::render('home', [
            'pageTitle' => $t('meta.title'),
            'pageDescription' => $t('meta.description'),
            'locale' => $locale,
            'currentPath' => $currentPath,
            'apiLocale' => $apiLocale,
            'exampleJson' => $exampleJson,
            'contactEmail' => $contactEmail,
            'accessMailto' => 'mailto:' . $contactEmail . '?subject=' . rawurlencode($t('nav.access_api')),
            'contactMailto' => 'mailto:' . $contactEmail,
            'legalMailto' => 'mailto:legal@origen.ar?subject=' . rawurlencode($t('footer.legal')),
            'year' => date('Y'),
        ]);
    }
}
