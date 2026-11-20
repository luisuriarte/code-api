<?php

declare(strict_types=1);

/**
 * Extrae de un ZIP combinado (internacional + argentina) solo los archivos
 * RF2 Snapshot de la edición argentina.
 *
 * La edición argentina contiene los conceptos internacionales más las
 * extensiones locales y descripciones en español e inglés: no se filtra por
 * idioma, así que `03_postcarga.sql` publica ambos `language_code` en
 * `public.snomed_descriptions`.
 *
 * No se conecta a la base de datos. Deja una carpeta con la misma estructura
 * que espera tools/php/generar_carga_snomed.php:
 *
 *   <destino>/Terminology/sct2_Concept_Snapshot_....txt
 *   <destino>/Refset/....txt
 *
 * Uso:
 *   php tools/php/extraer_snomed_argentina.php \
 *     /var/www/html/origen.ar/code-api/SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z.zip \
 *     --destino=/var/www/html/origen.ar/code-api/sct_argentina
 */

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "Este script se ejecuta por línea de comandos.\n");
    exit(1);
}

if (!class_exists(ZipArchive::class)) {
    fwrite(STDERR, "Falta la extensión zip de PHP.\n");
    exit(2);
}

$source = null;
$destination = null;
$edition = 'argentina';
$quiet = false;

foreach (array_slice($argv, 1) as $arg) {
    if (str_starts_with($arg, '--')) {
        $parts = explode('=', substr($arg, 2), 2);
        $key = $parts[0];
        $value = $parts[1] ?? null;

        if (in_array($key, ['destino', 'edition'], true)) {
            if ($value === null || $value === '') {
                fwrite(STDERR, "Falta el valor de --{$key}\n");
                exit(2);
            }
            if ($key === 'destino') {
                $destination = $value;
            } else {
                $edition = strtolower($value);
            }
            continue;
        }
        if ($key === 'quiet') {
            $quiet = true;
            continue;
        }
        fwrite(STDERR, "Opción desconocida: --{$key}\n");
        exit(2);
    }
    if ($source !== null) {
        fwrite(STDERR, "Indicó más de un ZIP.\n");
        exit(2);
    }
    $source = $arg;
}

if ($source === null) {
    fwrite(STDERR, <<<TXT
Uso: php tools/php/extraer_snomed_argentina.php <zip> [opciones]

  --destino=RUTA   Carpeta de salida (por defecto: <carpeta del zip>/sct_argentina)
  --edition=TEXT   'argentina' (default) o 'international'
  --quiet          No imprime cada archivo extraído

TXT);
    exit(2);
}

if (!is_file($source)) {
    fwrite(STDERR, "No existe el ZIP: {$source}\n");
    exit(1);
}

$zip = new ZipArchive();
if ($zip->open($source) !== true) {
    fwrite(STDERR, "No se pudo abrir el ZIP: {$source}\n");
    exit(1);
}

$entries = [];
for ($i = 0; $i < $zip->numFiles; $i++) {
    $name = $zip->getNameIndex($i);
    if (!is_string($name)) {
        continue;
    }
    $normalized = str_replace('\\', '/', $name);
    if (preg_match('~Snapshot/(Terminology|Refset)/.+\.txt$~i', $normalized) !== 1) {
        continue;
    }
    if (preg_match('~/(Full|Delta)/~i', $normalized) === 1) {
        continue;
    }
    $entries[] = $name;
}

if ($entries === []) {
    $zip->close();
    fwrite(STDERR, "El ZIP no contiene archivos RF2 Snapshot reconocibles.\n");
    exit(1);
}

$wanted = str_contains($edition, 'arg') ? 'argentina' : 'international';

$matches = array_values(array_filter(
    $entries,
    static fn (string $name): bool => stripos($name, $wanted) !== false
));

if ($matches === []) {
    // Fallback: el ZIP suele traer solo "International" y "Argentina". Si no
    // encontramos la edición pedida, usamos la opuesta cuando es inequívoca.
    $other = $wanted === 'argentina' ? 'international' : 'argentina';
    $others = array_values(array_filter(
        $entries,
        static fn (string $name): bool => stripos($name, $other) !== false
    ));
    if ($others !== []) {
        $matches = array_values(array_diff($entries, $others));
    } else {
        $matches = $entries;
    }
}

if ($matches === []) {
    $zip->close();
    fwrite(STDERR, "No se pudo aislar la edición {$wanted} dentro del ZIP.\n");
    exit(1);
}

$root = $destination ?? (dirname($source) . DIRECTORY_SEPARATOR . 'sct_argentina');
$root = rtrim($root, '\\/');

$types = [];
foreach ($matches as $name) {
    $normalized = str_replace('\\', '/', $name);
    $relative = preg_replace('~^.*?Snapshot/~', '', $normalized);
    if (!is_string($relative) || $relative === '') {
        continue;
    }
    $base = basename($normalized);
    $type = preg_replace('~_Snapshot_.*$~i', '', $base);
    if (!is_string($type) || $type === '') {
        continue;
    }
    if (isset($types[$type])) {
        $zip->close();
        fwrite(STDERR, "Quedaron dos archivos para {$type}: {$types[$type]} y {$name}.\n");
        exit(1);
    }
    $types[$type] = $name;

    $target = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relative);
    $directory = dirname($target);
    if (!is_dir($directory) && !mkdir($directory, 0775, true) && !is_dir($directory)) {
        $zip->close();
        fwrite(STDERR, "No se pudo crear la carpeta: {$directory}\n");
        exit(1);
    }

    $input = $zip->getStream($name);
    $output = fopen($target, 'wb');
    if ($input === false || $output === false) {
        if ($input !== false) {
            fclose($input);
        }
        if ($output !== false) {
            fclose($output);
        }
        $zip->close();
        fwrite(STDERR, "No se pudo extraer: {$name}\n");
        exit(1);
    }
    stream_copy_to_stream($input, $output);
    fclose($input);
    fclose($output);

    if (!$quiet) {
        fwrite(STDOUT, '[extraído] ' . $relative . PHP_EOL);
    }
}

$zip->close();

foreach (['sct2_Concept', 'sct2_Description', 'sct2_Relationship'] as $required) {
    if (!isset($types[$required])) {
        fwrite(STDERR, "Falta el archivo obligatorio: {$required}\n");
        exit(1);
    }
}

fwrite(STDOUT, sprintf("OK: %d archivos RF2 extraídos en %s\n", count($types), $root));
