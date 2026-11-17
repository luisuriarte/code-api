<?php

declare(strict_types=1);

/**
 * Verificación estática de los reportes de Fase 12 posteriores a D-19.
 *
 * Ejecutar:
 *   php tools/php/verificar_fase12.php
 */

$root = dirname(__DIR__, 2);

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

$reporteBase = $read('sql/07_multilingue/12_fase12_validacion.sql');
$matriz = $read('sql/07_multilingue/14_d19_matriz_pendiente.sql');
$postD19 = $read('sql/07_multilingue/16_fase12_post_d19.sql');
$readme = $read('sql/07_multilingue/README.md');

$check($soloLectura($reporteBase), '12_fase12_validacion.sql debe seguir siendo solo lectura');
$check($soloLectura($matriz), '14_d19_matriz_pendiente.sql debe ser solo lectura');
$check($postD19 !== '', 'debe existir 16_fase12_post_d19.sql');
$check($soloLectura($postD19), '16_fase12_post_d19.sql debe contener solo SELECT');
$check(!str_contains($postD19, '\\copy') && !str_contains($postD19, '\i '), 'los reportes no deben usar meta-comandos de psql');
$check(str_contains($postD19, 'aprobadas_sin_os_field_review'), 'el reporte debe verificar revisiones D-19');
$check(str_contains($postD19, 'campos_no_vacios_sin_revision'), 'el reporte debe verificar cobertura por campo');
$check(str_contains($postD19, 'aprobaciones_con_hash_desactualizado'), 'el reporte debe verificar vigencia del hash');
$check(str_contains($postD19, 'approval_granted'), 'el reporte debe mostrar el evento de aprobación');
$check(str_contains($postD19, 'importer_run_id'), 'el reporte debe revisar identidad de importador');
$check(str_contains($postD19, 'DEBE SER 0'), 'los controles deben indicar explícitamente su valor esperado');
$check(str_contains($readme, '16_fase12_post_d19.sql'), 'el README de SQL debe registrar el reporte 16');

if ($errors !== []) {
    fwrite(STDERR, "Fase 12: fallos:\n - " . implode("\n - ", $errors) . "\n");
    exit(1);
}

echo "Fase 12: verificaciones OK\n";
