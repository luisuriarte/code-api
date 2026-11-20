<?php

declare(strict_types=1);

/**
 * Genera la carga PostgreSQL de CIE-10 en ambas bases del portal.
 *
 * Fuentes admitidas: CSV o ZIP con un CSV/TXT adentro. Se clasifican por
 *tipo (diagnóstico/procedimiento) e idioma (es/en), y se cargan todos en
 * `cie10_codes` + `cie10_descriptions`.
 *
 * El script NO se conecta a la base: solo escribe `02_carga.sql`.
 *
 * Uso con descubrimiento automático en una carpeta:
 *   php tools/php/generar_carga_cie10_pg.php /ruta/a/cie10 \
 *     --salida=tools/sql/cie10/02_carga.sql
 *
 * Uso explícito (recomendado si los nombres no son estándar):
 *   php tools/php/generar_carga_cie10_pg.php \
 *     --diag-es=/ruta/Diagnosticos_ES.csv \
 *     --proced-es=/ruta/Procedimientos_ES.csv \
 *     --diag-en=/ruta/Diagnosticos_EN.zip \
 *     --proced-en=/ruta/Procedimientos_EN.zip \
 *     --salida=tools/sql/cie10/02_carga.sql
 */

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "Este script se ejecuta por línea de comandos.\n");
    exit(1);
}

$defaults = [
    'salida' => dirname(__DIR__) . '/sql/cie10/02_carga.sql',
    'diag-es' => null,
    'proced-es' => null,
    'diag-en' => null,
    'proced-en' => null,
    'quiet' => false,
];
$options = $defaults;
$folder = null;

foreach (array_slice($argv, 1) as $arg) {
    if (str_starts_with($arg, '--')) {
        $parts = explode('=', substr($arg, 2), 2);
        $key = $parts[0];
        $value = $parts[1] ?? null;

        if ($key === 'quiet') {
            $options['quiet'] = true;
            continue;
        }
        if (!array_key_exists($key, $options)) {
            fwrite(STDERR, "Opción desconocida: --{$key}\n");
            exit(2);
        }
        if (in_array($key, ['diag-es', 'proced-es', 'diag-en', 'proced-en', 'salida'], true)) {
            if ($value === null || $value === '') {
                fwrite(STDERR, "Falta el valor de --{$key}\n");
                exit(2);
            }
            $options[$key] = $value;
            continue;
        }
        $options[$key] = true;
        continue;
    }
    if ($folder !== null) {
        fwrite(STDERR, "Indicó más de una carpeta de origen.\n");
        exit(2);
    }
    $folder = $arg;
}

$sources = [];
foreach (['diag-es', 'proced-es', 'diag-en', 'proced-en'] as $key) {
    if ($options[$key] !== null) {
        $sources[$key] = (string) $options[$key];
    }
}

if ($sources === [] && $folder !== null) {
    $discovered = discoverSources($folder, $options['quiet']);
    $sources = $discovered;
}

if ($sources === []) {
    fwrite(STDERR, <<<TXT
Uso: php tools/php/generar_carga_cie10_pg.php <carpeta> [opciones]
     php tools/php/generar_carga_cie10_pg.php [opciones]

  --diag-es=RUTA     CSV/ZIP de diagnósticos en español
  --proced-es=RUTA   CSV/ZIP de procedimientos en español
  --diag-en=RUTA     CSV/ZIP de diagnósticos en inglés
  --proced-en=RUTA   CSV/ZIP de procedimientos en inglés
  --salida=RUTA      SQL generado (por defecto tools/sql/cie10/02_carga.sql)
  --quiet            No imprime el detalle

TXT);
    exit(2);
}

if (isset($sources['diag-es']) && !is_readable($sources['diag-es'])) {
    fwrite(STDERR, "No se puede leer: {$sources['diag-es']}\n");
    exit(1);
}
if (isset($sources['proced-es']) && !is_readable($sources['proced-es'])) {
    fwrite(STDERR, "No se puede leer: {$sources['proced-es']}\n");
    exit(1);
}
if (isset($sources['diag-en']) && !is_readable($sources['diag-en'])) {
    fwrite(STDERR, "No se puede leer: {$sources['diag-en']}\n");
    exit(1);
}
if (isset($sources['proced-en']) && !is_readable($sources['proced-en'])) {
    fwrite(STDERR, "No se puede leer: {$sources['proced-en']}\n");
    exit(1);
}

if (!isset($sources['diag-es']) && !isset($sources['diag-en'])) {
    fwrite(STDERR, "Falta al menos una fuente de diagnósticos.\n");
    exit(1);
}
if (!isset($sources['proced-es']) && !isset($sources['proced-en'])) {
    fwrite(STDERR, "Falta al menos una fuente de procedimientos.\n");
    exit(1);
}

$rows = [];
foreach ($sources as $key => $path) {
    [$tipo, $idioma] = explode('-', $key);
    $dbTipo = $tipo === 'diag' ? 'diagnostico' : 'procedimiento';
    $parsed = parseSource($path, $tipo, $idioma);
    foreach ($parsed as $row) {
        $rows[] = [$dbTipo, $idioma, $row[0], $row[1]];
    }
    if (!$options['quiet']) {
        fwrite(STDOUT, sprintf("[%s/%s] %d filas desde %s\n", $idioma, $tipo, count($parsed), $path));
    }
}

if ($rows === []) {
    fwrite(STDERR, "No se obtuvieron filas de ninguna fuente.\n");
    exit(1);
}

$lines = [];
$lines[] = '-- =============================================================================';
$lines[] = '-- Origen Salud · CIE-10 · carga PostgreSQL (es + en) · GENERADO, NO EDITAR';
$lines[] = '-- =============================================================================';
$lines[] = '-- Ejecutar con psql -v ON_ERROR_STOP=1 -f 02_carga.sql en origen_codes';
$lines[] = '-- y en origen_salud. No TRUNCATE: los INSERT son idempotentes por código';
$lines[] = '-- y por (cie10_id, language_code, descripcion).';
$lines[] = '-- =============================================================================';
$lines[] = '';
$lines[] = 'BEGIN;';
$lines[] = "SET client_encoding = 'UTF8';";
$lines[] = 'SET standard_conforming_strings = on;';
$lines[] = 'SET statement_timeout = 0;';
$lines[] = '';
$lines[] = 'CREATE TEMP TABLE _cie10_staging (';
$lines[] = '    tipo text NOT NULL,';
$lines[] = '    idioma text NOT NULL,';
$lines[] = '    codigo text NOT NULL,';
$lines[] = '    descripcion text NOT NULL';
$lines[] = ') ON COMMIT DROP;';
$lines[] = '';

$chunk = [];
foreach ($rows as $row) {
    $chunk[] = sprintf(
        " (%s, %s, %s, %s)",
        sqlText($row[0]),
        sqlText($row[1]),
        sqlText(substr($row[2], 0, 10)),
        sqlText($row[3])
    );
    if (count($chunk) >= 400) {
        $lines[] = 'INSERT INTO _cie10_staging (tipo, idioma, codigo, descripcion) VALUES';
        $lines[] = implode(",\n", $chunk) . ';';
        $lines[] = '';
        $chunk = [];
    }
}
if ($chunk !== []) {
    $lines[] = 'INSERT INTO _cie10_staging (tipo, idioma, codigo, descripcion) VALUES';
    $lines[] = implode(",\n", $chunk) . ';';
    $lines[] = '';
}

$lines[] = 'INSERT INTO cie10_codes (codigo, tipo)';
$lines[] = 'SELECT DISTINCT codigo, tipo FROM _cie10_staging';
$lines[] = 'ON CONFLICT (codigo) DO UPDATE SET tipo = EXCLUDED.tipo;';
$lines[] = '';
$lines[] = 'INSERT INTO cie10_descriptions (cie10_id, language_code, descripcion)';
$lines[] = 'SELECT c.id, s.idioma, s.descripcion';
$lines[] = 'FROM (SELECT DISTINCT codigo, idioma, descripcion FROM _cie10_staging) s';
$lines[] = 'JOIN cie10_codes c ON c.codigo = s.codigo';
$lines[] = 'WHERE NOT EXISTS (';
$lines[] = '    SELECT 1 FROM cie10_descriptions d';
$lines[] = '    WHERE d.cie10_id = c.id';
$lines[] = '      AND d.language_code = s.idioma';
$lines[] = "      AND d.descripcion = s.descripcion";
$lines[] = ');';
$lines[] = '';
$lines[] = 'COMMIT;';
$lines[] = '';
$lines[] = '-- Verificación posterior (solo SELECT):';
$lines[] = '-- SELECT language_code, count(*) FROM cie10_descriptions GROUP BY 1 ORDER BY 1;';
$lines[] = '-- SELECT count(*) FROM cie10_codes;';
$lines[] = '';

$output = (string) $options['salida'];
$directory = dirname($output);
if (!is_dir($directory) && !mkdir($directory, 0775, true) && !is_dir($directory)) {
    fwrite(STDERR, "No se pudo crear la carpeta de salida: {$directory}\n");
    exit(1);
}
if (file_put_contents($output, implode("\n", $lines)) === false) {
    fwrite(STDERR, "No se pudo escribir: {$output}\n");
    exit(1);
}

fwrite(STDOUT, sprintf("OK: %d filas → %s\n", count($rows), $output));

/**
 * @return array<string, string>
 */
function discoverSources(string $folder, bool $quiet): array
{
    if (!is_dir($folder)) {
        fwrite(STDERR, "No existe la carpeta: {$folder}\n");
        exit(1);
    }

    $found = [];
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($folder, FilesystemIterator::SKIP_DOTS)
    );
    /** @var SplFileInfo $file */
    foreach ($iterator as $file) {
        if (!$file->isFile()) {
            continue;
        }
        $extension = strtolower($file->getExtension());
        if (!in_array($extension, ['csv', 'txt', 'zip'], true)) {
            continue;
        }
        $name = normalizeName($file->getBasename());

        if (str_contains($name, 'diag') || str_contains($name, 'diagnost')) {
            $tipo = 'diag';
        } elseif (str_contains($name, 'proced') || str_contains($name, 'pcs')) {
            $tipo = 'proced';
        } else {
            continue;
        }

        if (preg_match('~(^|[^a-z])(en|eng|english|ingles)([^a-z]|$)~', $name) === 1) {
            $idioma = 'en';
        } elseif (preg_match('~(^|[^a-z])(es|esp|espanol|spanish)([^a-z]|$)~', $name) === 1) {
            $idioma = 'es';
        } else {
            // En el juego actual: CSV = español, ZIP = inglés.
            $idioma = $extension === 'zip' ? 'en' : 'es';
        }

        $key = $tipo . '-' . $idioma;
        if (isset($found[$key])) {
            fwrite(STDERR, "Hay más de un archivo para {$key}: {$found[$key]} y {$file->getPathname()}. Use --{$key}=RUTA.\n");
            exit(1);
        }
        $found[$key] = $file->getPathname();

        if (!$quiet) {
            fwrite(STDOUT, "[detectado] {$key} → {$file->getPathname()}\n");
        }
    }

    return $found;
}

function normalizeName(string $value): string
{
    $value = str_replace(
        ['á', 'é', 'í', 'ó', 'ú', 'ü', 'ñ', 'Á', 'É', 'Í', 'Ó', 'Ú', 'Ü', 'Ñ'],
        ['a', 'e', 'i', 'o', 'u', 'u', 'n', 'a', 'e', 'i', 'o', 'u', 'u', 'n'],
        $value
    );

    $value = strtolower($value);

    return preg_replace('/[^a-z0-9]+/', ' ', $value) ?? $value;
}

/**
 * @return list<array{0: string, 1: string}>
 */
function parseSource(string $path, string $tipo, string $idioma): array
{
    $contents = readSource($path);
    $contents = preg_replace('/^\xEF\xBB\xBF/', '', $contents) ?? $contents;
    $lines = preg_split('/\r\n|\n|\r/', $contents) ?: [];
    if ($lines === []) {
        return [];
    }

    $header = array_shift($lines);
    if (!is_string($header)) {
        return [];
    }
    $delimiter = detectDelimiter($header);
    $columns = array_map('trimCell', explode($delimiter, $header));
    $normalized = array_map('normalizeName', $columns);

    $codeIndex = findColumn($normalized, [
        'codigo', 'code', 'full code', 'codigo cie10', 'cie10 code',
        'diagnosis code', 'procedure code', 'dx code', 'pcs code',
    ], 'code');
    $descIndex = findColumn($normalized, [
        'descripcion', 'description', 'desc', 'name', 'title',
        'diagnosis description', 'procedure description', 'nombre',
    ], 'desc');

    if ($codeIndex === null || $descIndex === null) {
        fwrite(STDERR, "No se encontraron columnas de código/descripción en {$path}. Cabecera: {$header}\n");
        exit(1);
    }

    $rows = [];
    foreach ($lines as $line) {
        if (trim($line) === '') {
            continue;
        }
        $cells = array_map('trimCell', explode($delimiter, $line));
        $code = $cells[$codeIndex] ?? '';
        $description = $cells[$descIndex] ?? '';
        if ($code === '' || $description === '') {
            continue;
        }
        $rows[] = [$code, $description];
    }

    return $rows;
}

function readSource(string $path): string
{
    $extension = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    if ($extension !== 'zip') {
        $contents = file_get_contents($path);
        if ($contents === false) {
            fwrite(STDERR, "No se pudo leer: {$path}\n");
            exit(1);
        }

        return $contents;
    }

    if (!class_exists(ZipArchive::class)) {
        fwrite(STDERR, "Falta la extensión zip de PHP para leer: {$path}\n");
        exit(1);
    }

    $zip = new ZipArchive();
    if ($zip->open($path) !== true) {
        fwrite(STDERR, "No se pudo abrir el ZIP: {$path}\n");
        exit(1);
    }

    $entry = null;
    for ($i = 0; $i < $zip->numFiles; $i++) {
        $name = $zip->getNameIndex($i);
        if (is_string($name) && preg_match('~\.(csv|txt)$~i', $name) === 1) {
            $entry = $name;
            break;
        }
    }
    if ($entry === null) {
        $zip->close();
        fwrite(STDERR, "El ZIP no contiene CSV/TXT: {$path}\n");
        exit(1);
    }

    $stream = $zip->getStream($entry);
    if ($stream === false) {
        $zip->close();
        fwrite(STDERR, "No se pudo leer {$entry} desde {$path}\n");
        exit(1);
    }
    $contents = stream_get_contents($stream);
    fclose($stream);
    $zip->close();

    if ($contents === false || $contents === '') {
        fwrite(STDERR, "El archivo {$entry} está vacío.\n");
        exit(1);
    }

    return $contents;
}

function detectDelimiter(string $header): string
{
    $counts = [
        "\t" => substr_count($header, "\t"),
        ',' => substr_count($header, ','),
        ';' => substr_count($header, ';'),
    ];
    arsort($counts);
    $delimiter = (string) array_key_first($counts);

    return $counts[$delimiter] > 0 ? $delimiter : "\t";
}

function trimCell(string $value): string
{
    $value = trim($value, "\r\n");

    return trim($value, " \t\"");
}

/**
 * @param list<string> $normalized
 * @param list<string> $exact
 */
function findColumn(array $normalized, array $exact, string $fallback): ?int
{
    foreach ($exact as $candidate) {
        $index = array_search($candidate, $normalized, true);
        if ($index !== false) {
            return (int) $index;
        }
    }
    foreach ($normalized as $index => $name) {
        if (str_contains($name, $fallback)) {
            return (int) $index;
        }
    }

    return null;
}

function sqlText(string $value): string
{
    $value = str_replace("\0", '', $value);

    return "'" . str_replace("'", "''", $value) . "'";
}
