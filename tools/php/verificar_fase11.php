<?php

declare(strict_types=1);

/**
 * Verificación sin base de datos del dual-read condicionado de Fase 11.
 *
 * Ejecutar:
 *   php tools/php/verificar_fase11.php
 */

$root = dirname(__DIR__, 2);
require_once $root . '/vendor/autoload.php';

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

$sinComentarios = static function (string $sql): string {
    return (string) preg_replace('/--[^\r\n]*/', '', $sql);
};

$sinDml = static function (string $sql) use ($sinComentarios): bool {
    return preg_match(
        '/\b(?:DROP|TRUNCATE|DELETE)\b/i',
        $sinComentarios($sql)
    ) !== 1;
};

// ---------------------------------------------------------------------------
// Aprobación D-19 registrada por script aditivo.
// ---------------------------------------------------------------------------
$sqlD19 = $read('sql/07_multilingue/15_d19_aprobacion_editorial.sql');
$check($sqlD19 !== '', 'debe existir 15_d19_aprobacion_editorial.sql');
$check(str_contains($sqlD19, 'BEGIN;') && str_contains($sqlD19, 'COMMIT;'), 'D-19 debe ir en transacción');
$check(str_contains($sqlD19, "'undet'"), 'D-19 debe usar la etiqueta undet sin inventar idioma');
$check(str_contains($sqlD19, "'approved'"), 'D-19 debe crear revisiones aprobadas');
$check(str_contains($sqlD19, "'approval_granted'"), 'D-19 debe registrar approval_granted');
$check(str_contains($sqlD19, 'ON CONFLICT DO NOTHING'), 'D-19 debe ser idempotente');
$check(str_contains($sqlD19, 'set_config('), 'D-19 debe fijar identidad de actor de aplicación');
$check($sinDml($sqlD19), 'D-19 no debe contener DROP/TRUNCATE/DELETE ejecutables');

$invalidacion = $read('sql/07_multilingue/18_fase11_invalidacion_mapeos.sql');
$check($invalidacion !== '', 'debe existir 18_fase11_invalidacion_mapeos.sql');
$check(str_contains($invalidacion, 'CREATE OR REPLACE FUNCTION'), 'la invalidación debe ser aditiva');
$check(str_contains($invalidacion, 'CREATE OR REPLACE TRIGGER'), 'la invalidación debe instalar un trigger');
$check(str_contains($invalidacion, "'approval_invalidated'"), 'la invalidación debe registrar approval_invalidated');
$check(str_contains($invalidacion, 'review_status = \'unreviewed\''), 'la invalidación debe retirar la aprobación');
$check($sinDml($invalidacion), 'la invalidación no debe contener DROP/TRUNCATE/DELETE ejecutables');

// ---------------------------------------------------------------------------
// Evaluador editorial y lectura condicionada de mapeos.
// ---------------------------------------------------------------------------
$fieldReviewSource = $read('api/services/FieldReviewRepository.php');
$evaluatorSource = $read('api/services/EditorialEvaluator.php');
$mappingReaderSource = $read('api/services/MappingReviewReader.php');
$catalogSource = $read('api/services/CatalogEngineService.php');

$check(str_contains($fieldReviewSource, 'public function contentHash('), 'FieldReviewRepository debe calcular el hash individual');
$check(str_contains($evaluatorSource, 'public function evaluateUndet('), 'EditorialEvaluator debe evaluar revisiones undet');
$check(str_contains($evaluatorSource, "=== 'undet'"), 'evaluateUndet debe aceptar la etiqueta undet sin pasar por os_language');
$check($mappingReaderSource !== '', 'debe existir MappingReviewReader.php');
$check(str_contains($mappingReaderSource, "'external_display', 'clinical_rationale'"), 'MappingReviewReader debe cubrir ambos campos de mapeo');
$check(str_contains($mappingReaderSource, 'untranslated'), 'MappingReviewReader debe informar untranslated');
$check(substr_count($catalogSource, 'new MappingReviewReader(') === 2, 'getItem y searchMappings deben usar MappingReviewReader');
$check(!str_contains($catalogSource, "'display' => \$m['external_display']"), 'getItem no debe servir display desde la columna original');
$check(!str_contains($catalogSource, "'target_display' => \$r['external_display']"), 'searchMappings no debe servir target_display desde la columna original');
$check(!str_contains($catalogSource, "'rationale' => \$m['clinical_rationale']"), 'getItem no debe servir rationale desde la columna original');
$check(!str_contains($catalogSource, "'rationale' => \$r['clinical_rationale']"), 'searchMappings no debe servir rationale desde la columna original');

// ---------------------------------------------------------------------------
// Comportamiento: aprobado vigente se publica; hash desactualizado no.
// ---------------------------------------------------------------------------
$catalog = LanguageCatalog::fromArrays([
    'es-AR' => [
        'code' => 'es-AR',
        'display_name' => 'Español (Argentina)',
        'primary_tag' => 'es',
        'is_active' => true,
        'is_source_only' => false,
    ],
], [], []);

$hash = FieldReviewRepository::fromArrays([])->contentHash('ADA CDT 2025', 'undet', 'fuente-1');
$reviews = FieldReviewRepository::fromArrays([
    [
        'target_table' => 'os_concept_mapping',
        'target_id' => 7,
        'field_name' => 'external_display',
        'language_code' => 'undet',
        'scope_release_id' => null,
        'review_status' => 'approved',
        'content_hash' => $hash,
        'provenance' => 'unknown',
        'language_evidence' => 'undetermined',
        'source_language_code' => null,
        'source_reference' => 'fuente-1',
    ],
]);
$evaluator = new EditorialEvaluator($catalog, $reviews);
$variant = [
    'language_code' => 'undet',
    'review_status' => 'approved',
    'content_hash' => $hash,
    'target_id' => 7,
    'value' => 'ADA CDT 2025',
    'provenance' => 'unknown',
    'language_evidence' => 'undetermined',
];

$approved = $evaluator->evaluateUndet([
    'target_id' => 7,
    'requested_language' => 'es-AR',
    'field_name' => 'external_display',
    'variants' => [$variant],
]);
$approvedLanguage = $approved->fieldLanguages()['external_display'];
$check($approved->values()['external_display'] === 'ADA CDT 2025', 'con revisión vigente el texto aprobado se publica');
$check($approvedLanguage['effective_language'] === 'undet', 'el idioma efectivo debe ser undet, nunca es-AR');
$check($approvedLanguage['untranslated'] === false, 'con aprobación vigente untranslated debe ser false');
$check($approvedLanguage['fallback_applied'] === false, 'undet no es un fallback del cliente');

$sinRevision = (new EditorialEvaluator($catalog, FieldReviewRepository::fromArrays([])))
    ->evaluateUndet([
        'target_id' => 7,
        'requested_language' => 'es-AR',
        'field_name' => 'external_display',
        'variants' => [$variant],
    ]);
$check($sinRevision->values()['external_display'] === null, 'sin os_field_review no se publica aunque la fila diga approved');
$check($sinRevision->fieldLanguages()['external_display']['untranslated'] === true, 'sin revisión debe informarse untranslated=true');

$stale = $evaluator->evaluateUndet([
    'target_id' => 7,
    'requested_language' => 'es-AR',
    'field_name' => 'external_display',
    'variants' => [array_merge($variant, [
        'value' => 'ADA CDT 2025 (cambiado)',
        'content_hash' => $reviews->contentHash('ADA CDT 2025 (cambiado)', 'undet', 'fuente-1'),
    ])],
]);
$check($stale->values()['external_display'] === null, 'si cambió el texto no se publica la columna original');
$check($stale->fieldLanguages()['external_display']['untranslated'] === true, 'sin hash vigente debe informarse untranslated=true');

// ---------------------------------------------------------------------------
// Identidad de importador e interlock de Fase 13.
// ---------------------------------------------------------------------------
$dentar = $read('tools/php/import_dentar_csv.php');
$nomenclador = $read('tools/php/import_nomenclador_csv.php');
$rf2 = $read('tools/php/Rf2Importer.php');
$sync = $read('sql/03_dentar/sync_dentar_to_os.sql');
$identity = $read('tools/php/ImporterIdentity.php');

$check(str_contains($identity, "MODE_DUAL = 'dual'"), 'el modo por defecto debe ser dual');
$check(str_contains($identity, "'OS_IMPORT_MODE', self::MODE_DUAL"), 'OS_IMPORT_MODE debe default a dual');
$check(str_contains($identity, 'assertWritableMode'), 'debe existir la compuerta de corte');
$check(str_contains($dentar, 'ImporterIdentity::bind('), 'el importador DENTAR debe fijar importer_run_id');
$check(str_contains($dentar, 'ImporterIdentity::assertWritableMode('), 'el importador DENTAR debe respetar la compuerta');
$check(str_contains($nomenclador, 'ImporterIdentity::bind('), 'el importador de nomencladores debe fijar importer_run_id');
$check(str_contains($rf2, 'ImporterIdentity::bind('), 'el importador RF2 debe fijar importer_run_id');
$check(str_contains($sync, "set_config(\n    'app.importer_run_id'") || str_contains($sync, "set_config('app.importer_run_id'"), 'el sync DENTAR debe conservar/generar importer_run_id');

if ($errors !== []) {
    fwrite(STDERR, "Fase 11: fallos:\n - " . implode("\n - ", $errors) . "\n");
    exit(1);
}

echo "Fase 11: verificaciones OK\n";
