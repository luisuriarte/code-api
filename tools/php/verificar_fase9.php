<?php

declare(strict_types=1);

/**
 * Verificación sin base de datos del cableado de Fase 9.
 *
 * Ejecutar:
 *   php tools/php/verificar_fase9.php
 */

$root = dirname(__DIR__, 2);

require_once $root . '/api/http/Request.php';
require_once $root . '/api/services/LanguageCatalog.php';
require_once $root . '/api/services/LanguageResolution.php';
require_once $root . '/api/services/LanguageResolver.php';
require_once $root . '/api/services/FieldReviewRepository.php';
require_once $root . '/api/services/LoincSourceLanguage.php';
require_once $root . '/api/services/EditorialResult.php';
require_once $root . '/api/services/EditorialEvaluator.php';

use OrigenSalud\Api\Services\EditorialEvaluator;
use OrigenSalud\Api\Services\FieldReviewRepository;
use OrigenSalud\Api\Services\LanguageCatalog;

$errors = [];
$check = static function (bool $condition, string $message) use (&$errors): void {
    if (!$condition) {
        $errors[] = $message;
    }
};

$read = static function (string $relative) use ($root): string {
    $path = $root . '/' . $relative;

    return is_file($path) ? (string) file_get_contents($path) : '';
};

$methodSource = static function (string $source, string $start, string $end): string {
    $from = strpos($source, $start);
    if ($from === false) {
        return '';
    }

    $to = strpos($source, $end, $from);

    return $to === false ? substr($source, $from) : substr($source, $from, $to - $from);
};

// ---------------------------------------------------------------------------
// Contrato estático del código cableado.
// ---------------------------------------------------------------------------
$catalogSource = $read('api/services/CatalogEngineService.php');
$getItemSource = $methodSource(
    $catalogSource,
    'public function getItem(',
    'public function searchMappings('
);

$check(
    str_contains($getItemSource, 'public function getItem(string $catalogCode, string $code, Request $request): array'),
    'getItem debe recibir Request'
);
$check(substr_count($getItemSource, 'LIMIT 1') === 1, 'getItem solo debe usar LIMIT 1 para resolver el catálogo');
$check(str_contains($getItemSource, 'LanguageResolver::fromPdo'), 'getItem debe resolver idioma por catálogo');
$check(str_contains($getItemSource, 'FieldReviewRepository::fromPdoForTargets'), 'getItem debe cargar revisiones por destino');
$check(str_contains($getItemSource, 'new EditorialEvaluator'), 'getItem debe evaluar campos editorialmente');
$check(str_contains($getItemSource, "\$meta['review_status'] = (string) \$preferred['version_review_status']"), 'getItem debe exponer review_status');

$indexSource = $read('api/index.php');
$check(str_contains($indexSource, 'function api_response_payload('), 'debe existir api_response_payload');
$check(str_contains($indexSource, 'function api_response_headers('), 'debe existir api_response_headers');
$check(
    substr_count($indexSource, 'Response::json(api_response_payload($request, [') === 29,
    'las 29 respuestas deben pasar por api_response_payload'
);
$check(!str_contains($indexSource, 'Response::json(['), 'no debe quedar Response::json sin enriquecer');
$check(
    str_contains($indexSource, 'getItem($matches[1], $matches[2], $request)'),
    'index.php debe pasar Request a getItem'
);
$check(str_contains($indexSource, "'Vary' => 'Accept-Language'"), 'toda respuesta debe anunciar Vary');

$searchSource = $read('api/services/TerminologySearchService.php');
$check(!str_contains($searchSource, 'readLanguage('), 'no debe quedar readLanguage');
$check(!str_contains($searchSource, 'normalizeLanguage('), 'no debe quedar normalizeLanguage');
$check(!str_contains($searchSource, "\\'es-AR\\'"), 'no debe quedar literal es-AR en SQL');
$check(substr_count($searchSource, ':language') >= 24, 'deben conservarse los parámetros :language y sus enlaces');
$check(str_contains($searchSource, 'function contentLanguage('), 'SNOMED/CIE deben usar tag primario');
$check(str_contains($searchSource, 'function requestedLanguage('), 'DENTAR debe usar etiqueta regional');

$controllerSource = $read('api/controllers/ConceptController.php');
$check(str_contains($controllerSource, 'requested_language'), 'ConceptController debe informar requested_language');
$check(str_contains($controllerSource, 'rf2_language_tag'), 'ConceptController debe informar rf2_language_tag');
$check(str_contains($controllerSource, 'dialect_determined'), 'ConceptController debe informar dialect_determined');
$check(str_contains($controllerSource, 'field_languages'), 'ConceptController debe informar field_languages');

$readme = $read('README-API.md');

foreach ([
    'Accept-Language',
    'requested_language',
    'available_languages',
    'field_languages',
    'rf2_language_tag',
    'dialect_determined',
    'Content-Language',
    '`Vary`',
] as $token) {
    $check(str_contains($readme, $token), 'README-API.md debe documentar ' . $token);
}

// ---------------------------------------------------------------------------
// Aislamiento de revisiones por target_id (D-28).
// ---------------------------------------------------------------------------
$languages = [
    'es-AR' => ['code' => 'es-AR', 'display_name' => 'Español (Argentina)', 'primary_tag' => 'es', 'is_active' => true, 'is_source_only' => false],
    'en' => ['code' => 'en', 'display_name' => 'English', 'primary_tag' => 'en', 'is_active' => true, 'is_source_only' => false],
    'pt-BR' => ['code' => 'pt-BR', 'display_name' => 'Português (Brasil)', 'primary_tag' => 'pt', 'is_active' => true, 'is_source_only' => false],
    'es' => ['code' => 'es', 'display_name' => 'Español (origen)', 'primary_tag' => 'es', 'is_active' => false, 'is_source_only' => true],
];

$catalog = LanguageCatalog::fromArrays($languages, ['es' => 'es-AR', 'pt' => 'pt-BR']);

$reviews = FieldReviewRepository::fromArrays([[
    // Aprobación de otra fila: NO debe habilitar la variante target_id=1.
    'target_table' => 'os_localized_text',
    'target_id' => 99,
    'field_name' => 'name',
    'language_code' => 'en',
    'scope_release_id' => null,
    'review_status' => 'approved',
    'content_hash' => 'hash-en',
    'provenance' => 'import',
    'source_language_code' => 'en',
    'language_evidence' => 'declared_by_source',
]]);

$variant = static function (string $language, string $value, string $status, string $hash, int $targetId): array {
    return [
        'language_code' => $language,
        'value' => $value,
        'review_status' => $status,
        'content_hash' => $hash,
        'target_id' => $targetId,
        'provenance' => 'origen_salud',
        'source_language_code' => $language,
        'language_evidence' => 'declared_by_source',
    ];
};

$result = (new EditorialEvaluator($catalog, $reviews))->evaluate([
    'target_table' => 'os_localized_text',
    'target_id' => 1,
    'requested_language' => 'en',
    'source_language_code' => 'es-AR',
    'fields' => [
        'name' => [
            $variant('en', 'EN no aprobado', 'unreviewed', 'hash-en', 1),
            $variant('es-AR', 'ES aprobado', 'approved', 'hash-es', 2),
        ],
    ],
]);

$check($result->values()['name'] === 'ES aprobado', 'una aprobación de otra fila no debe publicarse');
$check($result->meta()['requested_language'] === 'en', 'requested_language debe conservarse');
$check($result->meta()['effective_language'] === 'es-AR', 'debe caer al idioma de origen aprobado');
$check($result->meta()['fallback_applied'] === true, 'debe marcar fallback');
$check($result->meta()['untranslated'] === false, 'no debe marcar untranslated si hay contenido aprobado');
$check($result->availableLanguages() === [
    ['code' => 'es-AR', 'selectable' => true],
], 'available_languages debe reflejar solo idiomas aprobados');
$check($result->headers()['Content-Language'] === 'es-AR', 'Content-Language debe ser el idioma efectivo');

if ($errors !== []) {
    fwrite(STDERR, "Fase 9: fallos:\n - " . implode("\n - ", $errors) . "\n");
    exit(1);
}

echo "Fase 9: verificaciones OK\n";
