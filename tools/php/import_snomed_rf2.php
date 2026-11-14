#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Importador CLI de archivos RF2 de SNOMED-CT para Origen Salud.
 *
 * Uso:
 *   php tools/php/import_snomed_rf2.php <archivo> <concept|description|relationship> [opciones]
 *
 * Ejemplos:
 *   php tools/php/import_snomed_rf2.php ./rf2/sct2_Concept_Full_INT_20240131.txt concept
 *   php tools/php/import_snomed_rf2.php ./rf2/sct2_Description_Full-es_INT_20240131.txt description
 *   php tools/php/import_snomed_rf2.php ./rf2/sct2_Relationship_Full_INT_20240131.txt relationship
 *
 * Ver "php tools/php/import_snomed_rf2.php --help" para el detalle de opciones.
 *
 * El orden importa: concept -> description -> relationship. Cada lote se
 * confirma con su propia transacción y usa UPSERT, por lo que la corrida es
 * idempotente y se puede retomar reejecutando el mismo archivo.
 */

use OrigenSalud\Api\Config\Database;
use OrigenSalud\Tools\Php\ImportOptions;
use OrigenSalud\Tools\Php\ImportResult;
use OrigenSalud\Tools\Php\Rf2Importer;

require_once dirname(__DIR__, 2) . '/bootstrap.php';

const EXIT_SUCCESS = 0;
const EXIT_RUNTIME_ERROR = 1;
const EXIT_USAGE_ERROR = 2;
const EXIT_CONNECTION_ERROR = 3;

if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    exit("Este script solo puede ejecutarse desde la línea de comandos.\n");
}

/**
 * @param resource $stream
 */
function printUsage($stream): void
{
    $usage = <<<'TEXT'
    Importador RF2 de SNOMED-CT - Origen Salud

    Uso:
      php tools/php/import_snomed_rf2.php <archivo> <concept|description|relationship> [opciones]

    Argumentos:
      <archivo>     Ruta al archivo .txt RF2 (TSV con cabecera).
      <tipo>        concept     -> snomed_concepts
                    description -> snomed_descriptions
                    relationship-> snomed_relationships

    Opciones:
      --batch-size=N     Filas por transacción (default 2000).
      --limit=N          Procesa solo las primeras N filas de datos (0 = todas).
      --language=es      Solo descripciones de ese idioma (etiqueta primaria).
      --delimiter=X      Delimitador de columnas (default: tab; "tab" es alias).
      --skip-invalid     Omite filas inválidas en lugar de abortar.
      --dry-run          Valida y cuenta sin escribir en la base de datos.
      --quiet            No muestra el progreso por lote.
      -h, --help         Muestra esta ayuda.

    Códigos de salida:
      0  Importación completada.
      1  Error de archivo, validación o base de datos.
      2  Uso incorrecto de los argumentos.
      3  No se pudo conectar a PostgreSQL.

    TEXT;

    fwrite($stream, $usage . PHP_EOL);
}

/**
 * @param array<string, string|true> $options
 */
function buildOptions(array $positional, array $options): ImportOptions
{
    $filePath = $positional[0] ?? '';
    $mode = strtolower(trim($positional[1] ?? ''));

    $batchSize = parseIntegerOption($options, 'batch-size', ImportOptions::DEFAULT_BATCH_SIZE);
    $limit = parseIntegerOption($options, 'limit', 0);
    $language = isset($options['language']) ? (string) $options['language'] : null;
    $delimiter = isset($options['delimiter']) ? (string) $options['delimiter'] : "\t";

    if ($delimiter === 'tab') {
        $delimiter = "\t";
    }

    if ($language !== null && $mode !== Rf2Importer::MODE_DESCRIPTION) {
        throw new InvalidArgumentException('--language solo aplica al tipo "description".');
    }

    return new ImportOptions(
        filePath: $filePath,
        mode: $mode,
        batchSize: $batchSize,
        limit: $limit,
        language: $language,
        delimiter: $delimiter,
        dryRun: isset($options['dry-run']),
        skipInvalid: isset($options['skip-invalid']),
        quiet: isset($options['quiet'])
    );
}

/**
 * @param array<string, string|true> $options
 */
function parseIntegerOption(array $options, string $name, int $default): int
{
    if (!isset($options[$name])) {
        return $default;
    }

    $value = $options[$name];

    if ($value === true || filter_var($value, FILTER_VALIDATE_INT) === false) {
        throw new InvalidArgumentException('--' . $name . ' requiere un número entero.');
    }

    return (int) $value;
}

/**
 * @param array<string, string|true> $options
 */
function formatSummary(ImportResult $result): string
{
    $number = static fn (int $value): string => number_format($value, 0, ',', '.');
    $mode = $result->dryRun ? ' (SIMULACIÓN, sin escrituras)' : '';

    return implode(PHP_EOL, [
        '',
        '=== Importación RF2 finalizada' . $mode . ' ===',
        'Tipo:             ' . $result->mode,
        'Archivo:          ' . $result->filePath,
        'Filas leídas:     ' . $number($result->rowsRead),
        'Filas válidas:    ' . $number($result->rowsValid),
        'Filas importadas: ' . $number($result->rowsImported),
        'Filas omitidas:   ' . $number($result->rowsSkipped),
        'Filas filtradas:  ' . $number($result->rowsFiltered),
        'Lotes:            ' . $number($result->batches),
        'Duración:         ' . number_format($result->seconds, 2, ',', '.') . ' s'
            . ' (' . $number((int) round($result->rowsPerSecond())) . ' filas/s)',
    ]);
}

$arguments = array_slice($argv, 1);

if (in_array('--help', $arguments, true) || in_array('-h', $arguments, true)) {
    printUsage(STDOUT);
    exit(EXIT_SUCCESS);
}

if ($arguments === []) {
    printUsage(STDERR);
    exit(EXIT_USAGE_ERROR);
}

$positional = [];
$options = [];

foreach ($arguments as $argument) {
    if (!str_starts_with($argument, '--')) {
        $positional[] = $argument;
        continue;
    }

    [$name, $value] = array_pad(explode('=', substr($argument, 2), 2), 2, null);

    if ($name === '') {
        fwrite(STDERR, "Opción inválida: {$argument}" . PHP_EOL);
        exit(EXIT_USAGE_ERROR);
    }

    $flags = ['dry-run', 'skip-invalid', 'quiet'];

    if (in_array($name, $flags, true)) {
        if ($value !== null) {
            fwrite(STDERR, "--{$name} no acepta un valor." . PHP_EOL);
            exit(EXIT_USAGE_ERROR);
        }

        $options[$name] = true;
        continue;
    }

    if (!in_array($name, ['batch-size', 'limit', 'language', 'delimiter'], true)) {
        fwrite(STDERR, "Opción desconocida: --{$name}" . PHP_EOL);
        printUsage(STDERR);
        exit(EXIT_USAGE_ERROR);
    }

    if ($value === null || $value === '') {
        fwrite(STDERR, "--{$name} requiere un valor." . PHP_EOL);
        exit(EXIT_USAGE_ERROR);
    }

    $options[$name] = $value;
}

if (count($positional) !== 2) {
    fwrite(STDERR, 'Se esperaban exactamente 2 argumentos posicionales.' . PHP_EOL);
    printUsage(STDERR);
    exit(EXIT_USAGE_ERROR);
}

try {
    $importOptions = buildOptions($positional, $options);
} catch (InvalidArgumentException $exception) {
    fwrite(STDERR, 'Error: ' . $exception->getMessage() . PHP_EOL);
    printUsage(STDERR);
    exit(EXIT_USAGE_ERROR);
}

set_time_limit(0);

$pdo = null;

if (!$importOptions->dryRun) {
    try {
        $pdo = Database::connection();
    } catch (Throwable $exception) {
        fwrite(STDERR, '[ERROR] No se pudo conectar a PostgreSQL: ' . $exception->getMessage() . PHP_EOL);
        exit(EXIT_CONNECTION_ERROR);
    }
}

$logger = $importOptions->quiet
    ? static function (string $message): void {
    }
    : static function (string $message): void {
        fwrite(STDOUT, $message . PHP_EOL);
    };

$importer = new Rf2Importer($pdo, $logger);

try {
    $result = $importer->import($importOptions);
} catch (Throwable $exception) {
    fwrite(STDERR, '[ERROR] ' . $exception->getMessage() . PHP_EOL);
    exit(EXIT_RUNTIME_ERROR);
}

fwrite(STDOUT, formatSummary($result) . PHP_EOL);

exit(EXIT_SUCCESS);
