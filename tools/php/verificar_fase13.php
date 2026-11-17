<?php

declare(strict_types=1);

/**
 * Verificación estática de la preparación de Fase 13 (corte controlado).
 *
 * Ejecutar:
 *   php tools/php/verificar_fase13.php
 */

$root = dirname(__DIR__, 2);
require_once $root . '/vendor/autoload.php';

use OrigenSalud\Tools\Php\ImporterIdentity;

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

$soloLectura = static function (string $sql): bool {
    $sinComentarios = (string) preg_replace('/--[^\r\n]*/', '', $sql);

    return preg_match(
        '/\b(?:INSERT|UPDATE|DELETE|DROP|TRUNCATE|ALTER|CREATE)\b/i',
        $sinComentarios
    ) !== 1;
};

$final = $read('sql/07_multilingue/17_fase13_verificacion_final.sql');
$readmeSql = $read('sql/07_multilingue/README.md');
$readmeApi = $read('README-API.md');
$doc = $read('docs/architecture/corte-controlado-multilingue.md');
$identity = $read('tools/php/ImporterIdentity.php');

$check($final !== '', 'debe existir 17_fase13_verificacion_final.sql');
$check($soloLectura($final), '17_fase13_verificacion_final.sql debe contener solo SELECT');
$check(str_contains($final, 'information_schema.columns'), 'la verificación debe consultar information_schema.columns');
$check(str_contains($final, 'divergencias_totales'), 'la verificación debe exponer el total de divergencias');
$check(str_contains($final, 'undet_en_os_language'), 'la verificación debe comprobar que undet no es idioma seleccionable');
$check(str_contains($final, 'source_language_code'), 'D-36 debe verificar columnas nullable');
$check(str_contains($final, 'content_hash'), 'D-36 debe verificar columnas NOT NULL con DEFAULT');
$check(str_contains($final, 'OS_IMPORT_MODE=dual'), 'el reporte debe declarar que el corte no está activo');

foreach (['15_d19_aprobacion_editorial.sql', '18_fase11_invalidacion_mapeos.sql', '16_fase12_post_d19.sql', '17_fase13_verificacion_final.sql'] as $archivo) {
    $sql = $read('sql/07_multilingue/' . $archivo);
    $ejecutable = (string) preg_replace('/--[^\r\n]*/', '', $sql);
    $check(!preg_match('/\bSET\s+NOT\s+NULL\b/i', $ejecutable), "{$archivo} no debe aplicar SET NOT NULL");
    $check(!preg_match('/\b(?:DROP\s+TABLE|TRUNCATE|DELETE\s+FROM)\b/i', $ejecutable), "{$archivo} no debe destruir datos");
}

$check($doc !== '', 'debe existir el documento operativo de corte controlado');
$check(str_contains($doc, 'Sin Backups'), 'el documento debe respetar la decisión Sin Backups');
$check(str_contains($doc, 'OS_IMPORT_MODE=dual'), 'el documento debe fijar dual como modo vigente');
$check(str_contains($doc, 'no se activa automáticamente'), 'el documento debe impedir el corte automático');
$check(str_contains($doc, 'Reversión sin backup'), 'el documento debe describir reversión sin backup');
$check(str_contains($readmeSql, '17_fase13_verificacion_final.sql'), 'el README de SQL debe registrar la verificación final');
$check(str_contains($readmeApi, 'D-19'), 'README-API debe reflejar el estado D-19');

$check(ImporterIdentity::mode() === ImporterIdentity::MODE_DUAL, 'el modo por defecto debe ser dual');

putenv('OS_IMPORT_MODE=new_only');
try {
    ImporterIdentity::assertWritableMode();
    $errors[] = 'new_only debe fallar explícitamente hasta haber implementación write-only verificada';
} catch (RuntimeException $exception) {
    $check(str_contains($exception->getMessage(), 'no se activa automáticamente'), 'el error de new_only debe ser explícito');
} finally {
    putenv('OS_IMPORT_MODE');
}

$check(str_contains($identity, "'new_only'"), 'debe existir el modo new_only como compuerta');

if ($errors !== []) {
    fwrite(STDERR, "Fase 13: fallos:\n - " . implode("\n - ", $errors) . "\n");
    exit(1);
}

echo "Fase 13: verificaciones OK\n";
