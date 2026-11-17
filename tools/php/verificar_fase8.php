<?php

declare(strict_types=1);

/**
 * Verificación sin base de datos de los componentes de Fase 8.
 *
 * Ejecutar:
 *   php tools/php/verificar_fase8.php
 */

require_once dirname(__DIR__, 2) . '/api/http/Request.php';
require_once dirname(__DIR__, 2) . '/api/services/LanguageCatalog.php';
require_once dirname(__DIR__, 2) . '/api/services/LanguageResolution.php';
require_once dirname(__DIR__, 2) . '/api/services/LanguageResolver.php';
require_once dirname(__DIR__, 2) . '/api/services/FieldReviewRepository.php';
require_once dirname(__DIR__, 2) . '/api/services/LoincSourceLanguage.php';
require_once dirname(__DIR__, 2) . '/api/services/EditorialResult.php';
require_once dirname(__DIR__, 2) . '/api/services/EditorialEvaluator.php';

use OrigenSalud\Api\Http\Request;
use OrigenSalud\Api\Services\EditorialEvaluator;
use OrigenSalud\Api\Services\FieldReviewRepository;
use OrigenSalud\Api\Services\LanguageCatalog;
use OrigenSalud\Api\Services\LanguageResolver;

$errors = [];
$check = static function (bool $condition, string $message) use (&$errors): void {
    if (!$condition) {
        $errors[] = $message;
    }
};

$languages = [
    'es-AR' => ['code' => 'es-AR', 'display_name' => 'Español (Argentina)', 'primary_tag' => 'es', 'is_active' => true, 'is_source_only' => false],
    'en' => ['code' => 'en', 'display_name' => 'English', 'primary_tag' => 'en', 'is_active' => true, 'is_source_only' => false],
    'pt-BR' => ['code' => 'pt-BR', 'display_name' => 'Português (Brasil)', 'primary_tag' => 'pt', 'is_active' => true, 'is_source_only' => false],
    'es' => ['code' => 'es', 'display_name' => 'Español (origen)', 'primary_tag' => 'es', 'is_active' => false, 'is_source_only' => true],
    'es-MX' => ['code' => 'es-MX', 'display_name' => 'Español (México)', 'primary_tag' => 'es', 'is_active' => false, 'is_source_only' => true],
];

$aliases = ['es' => 'es-AR', 'pt' => 'pt-BR'];

$catalogLanguages = [
    1 => [
        'es-AR' => ['is_default' => true, 'is_fallback' => false, 'is_bridge' => false, 'coverage_status' => 'complete'],
        'en' => ['is_default' => false, 'is_fallback' => false, 'is_bridge' => true, 'coverage_status' => 'complete'],
    ],
];

$catalog = LanguageCatalog::fromArrays($languages, $aliases, $catalogLanguages);
$resolver = new LanguageResolver($catalog, 'es');

$request = static function (array $query, array $headers = []): Request {
    return new Request('GET', '/v1/domains', $query, $headers, 'verificacion-fase8');
};

// lang=es sigue resolviendo a es-AR como entrada (D-27).
$resolved = $resolver->resolve($request(['lang' => 'es']));
$check($resolved->requestedLanguage === 'es-AR', 'lang=es debe resolver a es-AR');
$check($resolved->candidates === ['es-AR'], 'lang=es debe producir solo es-AR');

// Accept-Language con q ordena candidatos y descarta q=0.
$resolved = $resolver->resolve($request([], ['accept-language' => 'es;q=0.4, en;q=0.9, pt;q=0']));
$check($resolved->candidates === ['en', 'es-AR'], 'Accept-Language debe ordenar por q y mapear es a es-AR');
$check(!$resolved->qZeroOnly, 'q=0 parcial no debe activar q_zero_only');

// Todas las entradas con q=0: default con motivo explícito.
$resolved = $resolver->resolve($request([], ['accept-language' => 'es;q=0, en;q=0']));
$check($resolved->qZeroOnly, 'q=0 en todas las entradas debe activar q_zero_only');
$check($resolved->fallbackReason === 'no_acceptable_language', 'motivo incorrecto para q=0');
$check($resolved->requestedLanguage === 'es-AR', 'default debe ser es-AR');

// es-MX no es alias: se rechaza como entrada (D-39).
$resolved = $resolver->resolve($request(['lang' => 'es-MX']));
$check($resolved->requestedLanguage === 'es-AR', 'es-MX no debe ser seleccionable');
$check(in_array('es-MX', $resolved->rejected, true), 'es-MX debe aparecer como rechazado');

$emptyReviews = FieldReviewRepository::fromArrays([]);
$evaluator = new EditorialEvaluator($catalog, $emptyReviews);

$variant = static function (string $language, string $value, string $status, array $extra = []): array {
    return array_merge([
        'language_code' => $language,
        'value' => $value,
        'review_status' => $status,
        'content_hash' => 'hash-' . $language,
        'provenance' => 'origen_salud',
        'source_language_code' => $language,
        'language_evidence' => 'declared_by_source',
    ], $extra);
};

// Candidato aprobado en el idioma pedido.
$result = $evaluator->evaluate([
    'target_table' => 'os_catalog_item_version',
    'target_id' => 1,
    'catalog_id' => 1,
    'requested_language' => 'es-AR',
    'fields' => [
        'preferred_term' => [$variant('es-AR', 'Práctica', 'approved')],
    ],
]);
$check($result->values()['preferred_term'] === 'Práctica', 'debe servir el valor aprobado');
$check($result->meta()['effective_language'] === 'es-AR', 'efectivo debe ser es-AR');
$check($result->headers()['Content-Language'] === 'es-AR', 'Content-Language debe emitirse si hay un idioma');
$check(isset($result->headers()['Vary']), 'Vary: Accept-Language siempre presente');

// Solo es aprobado, sin tag regional: effective=es y motivo dialectal.
$result = $evaluator->evaluate([
    'target_table' => 'snomed_descriptions',
    'target_id' => 2,
    'requested_language' => 'es-AR',
    'source_language_code' => 'es',
    'fields' => [
        'description' => [$variant('es', 'Concepto SNOMED', 'approved', ['language_evidence' => 'undetermined'])],
    ],
]);
$field = $result->fieldLanguages()['description'];
$check($field['effective_language'] === 'es', 'es aprobado no debe reescribirse a es-AR');
$check($field['fallback_reason'] === 'rf2_dialect_undetermined', 'motivo dialectal incorrecto');
$check($field['dialect_determined'] === false, 'dialect_determined debe ser false sin evidencia regional');

// Sin aprobado: null + untranslated, sin caer a la columna original.
$result = $evaluator->evaluate([
    'target_table' => 'os_catalog_item_version',
    'target_id' => 3,
    'requested_language' => 'en',
    'fields' => [
        'definition' => [$variant('en', 'Texto sin aprobar', 'unreviewed')],
    ],
]);
$field = $result->fieldLanguages()['definition'];
$check($result->values()['definition'] === null, 'sin aprobado debe devolver null');
$check($field['untranslated'] === true, 'sin aprobado debe marcar untranslated');
$check($field['fallback_reason'] === 'no_approved_content', 'motivo no_approved_content incorrecto');

// Revisión individual con hash distinto invalida la aprobación (D-31).
$reviews = FieldReviewRepository::fromArrays([[
    'target_table' => 'os_catalog_item_version',
    'target_id' => 4,
    'field_name' => 'preferred_term',
    'language_code' => 'es-AR',
    'scope_release_id' => null,
    'review_status' => 'approved',
    'content_hash' => 'hash-antiguo',
    'provenance' => 'origen_salud',
    'source_language_code' => 'es-AR',
    'language_evidence' => 'declared_by_source',
]]);
$result = (new EditorialEvaluator($catalog, $reviews))->evaluate([
    'target_table' => 'os_catalog_item_version',
    'target_id' => 4,
    'requested_language' => 'es-AR',
    'fields' => [
        'preferred_term' => [$variant('es-AR', 'Texto cambiado', 'approved')],
    ],
]);
$check($result->values()['preferred_term'] === null, 'un hash cambiado no debe servir contenido');

// LOINC: source_language se deriva del archivo (D-40).
$result = $evaluator->evaluate([
    'target_table' => 'loinc_localized_text',
    'target_id' => 5,
    'requested_language' => 'es-AR',
    'fields' => [
        'value' => [$variant('es-AR', 'Glucosa', 'approved', [
            'source_file' => 'esAR7LinguisticVariant.csv',
        ])],
    ],
]);
$check($result->fieldLanguages()['value']['source_language'] === 'es-AR', 'source_language LOINC incorrecto');

if ($errors !== []) {
    fwrite(STDERR, "Fase 8: fallos:\n - " . implode("\n - ", $errors) . "\n");
    exit(1);
}

echo "Fase 8: verificaciones OK\n";
