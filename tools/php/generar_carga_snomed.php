#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Generador del script de carga masiva de SNOMED CT (RF2) para PostgreSQL.
 *
 * Es el equivalente, para PostgreSQL, de los generadores de `LOAD DATA LOCAL
 * INFILE` que se usan en MySQL/MariaDB. En lugar de `LOAD DATA` escribe
 * sentencias `COPY`, que son la vía nativa y más rápida de PostgreSQL.
 *
 * Uso:
 *   php tools/php/generar_carga_snomed.php <zip|carpeta> [opciones]
 *
 * Ejemplos:
 *   php tools/php/generar_carga_snomed.php "D:\sct\20260820.zip"
 *   php tools/php/generar_carga_snomed.php "D:\sct\20260820" --ruta=/opt/sct/20260820
 *   php tools/php/generar_carga_snomed.php release.zip --cliente
 *
 * El generador:
 *   1. Si recibe un ZIP, extrae sólo Snapshot/Terminology y Snapshot/Refset
 *      (nunca Full/ ni Delta/).
 *   2. Detecta cada archivo RF2 por su nombre y valida la cabecera.
 *   3. Escribe un .sql con un COPY por archivo, con lista explícita de columnas.
 *
 * Ver "php tools/php/generar_carga_snomed.php --help".
 */

const EXIT_SUCCESS = 0;
const EXIT_RUNTIME_ERROR = 1;
const EXIT_USAGE_ERROR = 2;

const COPY_FORMAT = "FORMAT csv, DELIMITER E'\\t', QUOTE E'\\b', ESCAPE E'\\b', HEADER true, ENCODING 'UTF8'";

if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    exit("Este script solo puede ejecutarse desde la línea de comandos.\n");
}

/**
 * Contrato de cada archivo RF2.
 *
 * `headers` es el orden real del TSV. `columns` es el orden de la tabla
 * destino en `sct2`. COPY asigna por posición: por eso ambos deben coincidir
 * y la cabecera se valida antes de generar el script.
 *
 * @return array<string, array{
 *     pattern: string,
 *     table: string,
 *     columns: list<string>,
 *     headers: list<string>,
 *     optional: bool,
 *     essential: bool,
 *     label: string,
 *     force_not_null?: list<string>
 * }>
 */
function rf2Types(): array
{
    return [
        'concept' => [
            'pattern' => '/^sct2_Concept_Snapshot_.*\.txt$/i',
            'table' => 'sct2.concept',
            'columns' => ['id', 'effective_time', 'active', 'module_id', 'definition_status_id'],
            'headers' => ['id', 'effectiveTime', 'active', 'moduleId', 'definitionStatusId'],
            'optional' => false,
            'essential' => true,
            'label' => 'Conceptos',
        ],
        'description' => [
            'pattern' => '/^sct2_Description_Snapshot_.*\.txt$/i',
            'table' => 'sct2.description',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'concept_id',
                'language_code', 'type_id', 'term', 'case_significance_id',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'conceptId',
                'languageCode', 'typeId', 'term', 'caseSignificanceId',
            ],
            'optional' => false,
            'essential' => true,
            'label' => 'Descripciones',
        ],
        'relationship' => [
            'pattern' => '/^sct2_Relationship_Snapshot_.*\.txt$/i',
            'table' => 'sct2.relationship',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'source_id',
                'destination_id', 'relationship_group', 'type_id',
                'characteristic_type_id', 'modifier_id',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'sourceId',
                'destinationId', 'relationshipGroup', 'typeId',
                'characteristicTypeId', 'modifierId',
            ],
            'optional' => false,
            'essential' => true,
            'label' => 'Relaciones inferidas',
        ],
        'stated_relationship' => [
            'pattern' => '/^sct2_StatedRelationship_Snapshot_.*\.txt$/i',
            'table' => 'sct2.stated_relationship',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'source_id',
                'destination_id', 'relationship_group', 'type_id',
                'characteristic_type_id', 'modifier_id',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'sourceId',
                'destinationId', 'relationshipGroup', 'typeId',
                'characteristicTypeId', 'modifierId',
            ],
            'optional' => true,
            'essential' => false,
            'label' => 'Relaciones declaradas',
        ],
        'text_definition' => [
            'pattern' => '/^sct2_TextDefinition_Snapshot_.*\.txt$/i',
            'table' => 'sct2.text_definition',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'concept_id',
                'language_code', 'type_id', 'term', 'case_significance_id',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'conceptId',
                'languageCode', 'typeId', 'term', 'caseSignificanceId',
            ],
            'optional' => true,
            'essential' => false,
            'label' => 'Definiciones textuales',
        ],
        'identifier' => [
            'pattern' => '/^sct2_Identifier_Snapshot_.*\.txt$/i',
            'table' => 'sct2.identifier',
            'columns' => [
                'alternate_identifier', 'effective_time', 'active', 'module_id',
                'identifier_scheme_id', 'referenced_component_id',
            ],
            'headers' => [
                'alternateIdentifier', 'effectiveTime', 'active', 'moduleId',
                'identifierSchemeId', 'referencedComponentId',
            ],
            'optional' => true,
            'essential' => false,
            'label' => 'Identificadores alternos',
        ],
        'relationship_concrete' => [
            'pattern' => '/^sct2_RelationshipConcreteValues_Snapshot_.*\.txt$/i',
            'table' => 'sct2.relationship_concrete',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'source_id',
                'concrete_value', 'relationship_group', 'type_id',
                'characteristic_type_id', 'modifier_id',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'sourceId',
                'value', 'relationshipGroup', 'typeId',
                'characteristicTypeId', 'modifierId',
            ],
            'optional' => true,
            'essential' => false,
            'label' => 'Relaciones con valor concreto',
        ],
        'refset_simple' => [
            'pattern' => '/^der2_Refset_SimpleSnapshot_.*\.txt$/i',
            'table' => 'sct2.refset_simple',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'refset_id',
                'referenced_component_id',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                'referencedComponentId',
            ],
            'optional' => false,
            'essential' => true,
            'label' => 'Refsets simples',
        ],
        'refset_language' => [
            'pattern' => '/^der2_cRefset_LanguageSnapshot_.*\.txt$/i',
            'table' => 'sct2.refset_language',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'refset_id',
                'referenced_component_id', 'acceptability_id',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                'referencedComponentId', 'acceptabilityId',
            ],
            'optional' => false,
            'essential' => true,
            'label' => 'Refsets de idioma',
        ],
        'refset_attribute_value' => [
            'pattern' => '/^der2_cRefset_AttributeValueSnapshot_.*\.txt$/i',
            'table' => 'sct2.refset_attribute_value',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'refset_id',
                'referenced_component_id', 'value_id',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                'referencedComponentId', 'valueId',
            ],
            'optional' => false,
            'essential' => true,
            'label' => 'Refsets de valor de atributo',
        ],
        'refset_association' => [
            'pattern' => '/^der2_cRefset_AssociationSnapshot_.*\.txt$/i',
            'table' => 'sct2.refset_association',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'refset_id',
                'referenced_component_id', 'target_component_id',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                'referencedComponentId', 'targetComponentId',
            ],
            'optional' => true,
            'essential' => false,
            'label' => 'Refsets de asociación',
        ],
        'refset_simple_map' => [
            'pattern' => '/^der2_sRefset_SimpleMapSnapshot_.*\.txt$/i',
            'table' => 'sct2.refset_simple_map',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'refset_id',
                'referenced_component_id', 'map_target',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                'referencedComponentId', 'mapTarget',
            ],
            'force_not_null' => ['map_target'],
            'optional' => true,
            'essential' => false,
            'label' => 'Mapas simples',
        ],
        'refset_extended_map' => [
            'pattern' => '/^der2_iisssccRefset_ExtendedMapSnapshot_.*\.txt$/i',
            'table' => 'sct2.refset_extended_map',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'refset_id',
                'referenced_component_id', 'map_group', 'map_priority',
                'map_rule', 'map_advice', 'map_target', 'correlation_id',
                'map_category_id',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                'referencedComponentId', 'mapGroup', 'mapPriority',
                'mapRule', 'mapAdvice', 'mapTarget', 'correlationId',
                'mapCategoryId',
            ],
            'force_not_null' => ['map_rule', 'map_advice'],
            'optional' => true,
            'essential' => false,
            'label' => 'Mapas extendidos (CIE-10)',
        ],
        'refset_medicinal_products' => [
            'pattern' => '/^der2_ccccccRefset_MedicinalProductsSnapshot_.*\.txt$/i',
            'table' => 'sct2.refset_medicinal_products',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'refset_id',
                'referenced_component_id', 'referenced_component_id_rcd',
                'referenced_component_id_cd_up', 'referenced_component_id_cd',
                'referenced_component_id_mpf_only',
                'referenced_component_id_mp_only', 'reference_component_id_mp',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                'referencedComponentId', 'referencedComponentIdRCD',
                'referencedComponentIdCD_UP', 'referencedComponentIdCD',
                'referencedComponentIdMPFonlyId',
                'referencedComponentIdMPonlyId', 'referenceComponentIdMP',
            ],
            'optional' => true,
            'essential' => false,
            'label' => 'Productos medicinales del DNM',
        ],
        'refset_owl' => [
            'pattern' => '/^sct2_sRefset_OWLExpressionSnapshot_.*\.txt$/i',
            'table' => 'sct2.refset_owl',
            'columns' => [
                'id', 'effective_time', 'active', 'module_id', 'refset_id',
                'referenced_component_id', 'owl_expression',
            ],
            'headers' => [
                'id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                'referencedComponentId', 'owlExpression',
            ],
            'optional' => true,
            'essential' => false,
            'label' => 'Expresiones OWL',
        ],
    ];
}

/**
 * @param resource $stream
 */
function printUsage($stream): void
{
    $usage = <<<'TEXT'
    Generador de carga SNOMED CT (RF2) para PostgreSQL - Origen Salud

    Uso:
      php tools/php/generar_carga_snomed.php <zip|carpeta> [opciones]

    Argumentos:
      <zip|carpeta>     ZIP oficial de la release o carpeta ya extraída.
                        Si es un ZIP se extraen sólo Snapshot/Terminology y
                        Snapshot/Refset (nunca Full/ ni Delta/).

    Opciones:
      --salida=RUTA      Archivo .sql a generar.
                         Default: tools/sql/snomed/02_carga.sql
      --destino=RUTA     Carpeta donde extraer el ZIP.
                         Default: <carpeta del ZIP>/sct_carga_<AAAAMMDD>
      --ruta=RUTA        Prefijo de ruta que se escribe en los COPY. Sirve para
                         generar el script en la PC y ejecutarlo en el servidor
                         (por ejemplo --ruta=/opt/sct/20260820).
      --cliente          Genera \copy (psql, lee los archivos en la máquina
                         cliente) en lugar de COPY del lado del servidor.
      --sin-opcionales   Omite stated, textdefinitions, identifier, concrete,
                         association, mapas, medicinales y OWL.
      --con-stated       Incluye relaciones declaradas aunque se use
                         --sin-opcionales.
      --quiet            No muestra el progreso.
      -h, --help         Muestra esta ayuda.

    Códigos de salida:
      0  Script generado.
      1  Error de archivo, cabecera o escritura.
      2  Uso incorrecto de los argumentos.

    TEXT;

    fwrite($stream, $usage . PHP_EOL);
}

/**
 * @param list<string> $arguments
 * @return array{positional: list<string>, options: array<string, string|true>}
 */
function parseArguments(array $arguments): array
{
    $positional = [];
    $options = [];
    $flags = ['cliente', 'sin-opcionales', 'con-stated', 'quiet'];
    $valued = ['salida', 'destino', 'ruta'];

    foreach ($arguments as $argument) {
        if (!str_starts_with($argument, '--')) {
            $positional[] = $argument;
            continue;
        }

        [$name, $value] = array_pad(explode('=', substr($argument, 2), 2), 2, null);

        if ($name === '') {
            throw new InvalidArgumentException("Opción inválida: {$argument}");
        }

        if (in_array($name, $flags, true)) {
            if ($value !== null) {
                throw new InvalidArgumentException("--{$name} no acepta un valor.");
            }

            $options[$name] = true;
            continue;
        }

        if (!in_array($name, $valued, true)) {
            throw new InvalidArgumentException("Opción desconocida: --{$name}");
        }

        if ($value === null || $value === '') {
            throw new InvalidArgumentException("--{$name} requiere un valor.");
        }

        $options[$name] = $value;
    }

    return ['positional' => $positional, 'options' => $options];
}

/**
 * @param array<string, array{pattern: string, table: string, columns: list<string>, headers: list<string>, optional: bool, essential: bool, label: string, force_not_null?: list<string>}> $types
 */
function matchType(string $basename, array $types): ?string
{
    foreach ($types as $key => $type) {
        if (preg_match($type['pattern'], $basename) === 1) {
            return $key;
        }
    }

    return null;
}

/**
 * @param array<string, array{pattern: string, table: string, columns: list<string>, headers: list<string>, optional: bool, essential: bool, label: string, force_not_null?: list<string>}> $types
 * @return array<string, string> tipo => ruta absoluta
 */
function collectFiles(string $root, array $types): array
{
    $found = [];

    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS)
    );

    /** @var SplFileInfo $file */
    foreach ($iterator as $file) {
        if (!$file->isFile() || strtolower($file->getExtension()) !== 'txt') {
            continue;
        }

        $path = $file->getPathname();
        $normalized = str_replace('\\', '/', $path);

        // Nunca Full ni Delta: duplican identificadores y mezclan histórico.
        if (preg_match('~/(Full|Delta)/~i', $normalized) === 1) {
            continue;
        }

        $type = matchType($file->getBasename(), $types);

        if ($type === null) {
            continue;
        }

        if (isset($found[$type])) {
            throw new RuntimeException(sprintf(
                'Hay dos archivos para %s: %s y %s. Dejá una sola release en la carpeta.',
                $type,
                $found[$type],
                $path
            ));
        }

        $found[$type] = $path;
    }

    return $found;
}

/**
 * Extrae del ZIP sólo los .txt de Snapshot/Terminology y Snapshot/Refset.
 *
 * @param array<string, array{pattern: string, table: string, columns: list<string>, headers: list<string>, optional: bool, essential: bool, label: string, force_not_null?: list<string>}> $types
 * @return array{files: array<string, string>, root: string, release: string|null}
 */
function extractRelease(string $zipPath, ?string $destination, array $types, bool $quiet): array
{
    if (!class_exists(ZipArchive::class)) {
        throw new RuntimeException(
            'Falta la extensión zip de PHP. Descomprimí el ZIP a mano y pasá la carpeta, '
            . 'o instalá/enable php_zip.'
        );
    }

    $zip = new ZipArchive();

    if ($zip->open($zipPath) !== true) {
        throw new RuntimeException('No se pudo abrir el ZIP: ' . $zipPath);
    }

    try {
        $entries = [];

        for ($index = 0; $index < $zip->numFiles; $index++) {
            $name = $zip->getNameIndex($index);

            if (!is_string($name)) {
                continue;
            }

            $normalized = str_replace('\\', '/', $name);

            if (preg_match('~^(.+/)?Snapshot/(Terminology|Refset)/.+\.txt$~i', $normalized) !== 1) {
                continue;
            }

            if (preg_match('~/(Full|Delta)/~i', $normalized) === 1) {
                continue;
            }

            if (matchType(basename($normalized), $types) === null) {
                continue;
            }

            $entries[] = $normalized;
        }

        if ($entries === []) {
            throw new RuntimeException(
                'El ZIP no contiene archivos RF2 reconocibles en Snapshot/Terminology ni Snapshot/Refset.'
            );
        }

        $release = detectRelease($entries);
        $root = $destination;

        if ($root === null) {
            $root = dirname($zipPath) . DIRECTORY_SEPARATOR
                . 'sct_carga_' . ($release ?? 'release');
        }

        $root = rtrim($root, '\\/');
        $files = [];

        foreach ($entries as $entry) {
            if (str_contains($entry, '..') || str_starts_with($entry, '/') || preg_match('~^[A-Za-z]:~', $entry) === 1) {
                throw new RuntimeException('Entrada de ZIP insegura: ' . $entry);
            }

            $relative = preg_replace('~^.*?Snapshot/~', '', $entry);

            if (!is_string($relative) || $relative === '') {
                continue;
            }

            $target = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relative);
            $directory = dirname($target);

            if (!is_dir($directory) && !mkdir($directory, 0775, true) && !is_dir($directory)) {
                throw new RuntimeException('No se pudo crear la carpeta: ' . $directory);
            }

            $input = $zip->getStream($entry);

            if ($input === false) {
                throw new RuntimeException('No se pudo leer la entrada del ZIP: ' . $entry);
            }

            $output = fopen($target, 'wb');

            if ($output === false) {
                fclose($input);
                throw new RuntimeException('No se pudo escribir: ' . $target);
            }

            stream_copy_to_stream($input, $output);
            fclose($input);
            fclose($output);

            $type = matchType(basename($target), $types);

            if ($type !== null) {
                if (isset($files[$type])) {
                    throw new RuntimeException(sprintf(
                        'El ZIP trae dos archivos para %s: %s y %s. Dejá una sola release.',
                        $type,
                        $files[$type],
                        $target
                    ));
                }

                $files[$type] = $target;
            }

            if (!$quiet) {
                fwrite(STDOUT, '[extraído] ' . $relative . PHP_EOL);
            }
        }

        return ['files' => $files, 'root' => $root, 'release' => $release];
    } finally {
        $zip->close();
    }
}

/**
 * @param list<string> $paths
 */
function detectRelease(array $paths): ?string
{
    $dates = [];

    foreach ($paths as $path) {
        if (preg_match('/_(\d{8})\.txt$/i', $path, $matches) === 1) {
            $dates[] = $matches[1];
        }
    }

    if ($dates === []) {
        return null;
    }

    rsort($dates);

    return $dates[0];
}

/**
 * @return list<string>
 */
function readHeader(string $path): array
{
    $handle = fopen($path, 'rb');

    if ($handle === false) {
        throw new RuntimeException('No se pudo abrir: ' . $path);
    }

    try {
        $line = fgets($handle);
    } finally {
        fclose($handle);
    }

    if ($line === false) {
        return [];
    }

    $line = preg_replace('/^\xEF\xBB\xBF/', '', $line) ?? $line;
    $line = rtrim($line, "\r\n");

    return array_map(
        static fn (string $value): string => trim($value),
        explode("\t", $line)
    );
}

/**
 * @param array{pattern: string, table: string, columns: list<string>, headers: list<string>, optional: bool, essential: bool, label: string, force_not_null?: list<string>} $type
 */
function validateHeader(string $typeKey, array $type, string $path): void
{
    $found = readHeader($path);
    $expected = $type['headers'];

    if (count($found) !== count($expected)) {
        throw new RuntimeException(sprintf(
            'Cabecera inválida en %s: se esperaban %d columnas y hay %d. Archivo: %s',
            $typeKey,
            count($expected),
            count($found),
            $path
        ));
    }

    foreach ($expected as $index => $header) {
        if (strcasecmp($found[$index], $header) !== 0) {
            throw new RuntimeException(sprintf(
                'Cabecera inválida en %s: columna %d es "%s", se esperaba "%s". Archivo: %s',
                $typeKey,
                $index + 1,
                $found[$index],
                $header,
                $path
            ));
        }
    }
}

function toSqlPath(string $path): string
{
    $normalized = str_replace('\\', '/', $path);

    return str_replace("'", "''", $normalized);
}

/**
 * @param array{pattern: string, table: string, columns: list<string>, headers: list<string>, optional: bool, essential: bool, label: string, force_not_null?: list<string>} $type
 */
function buildCopy(string $type, array $typeDefinition, string $path, bool $client): string
{
    $columns = implode(', ', $typeDefinition['columns']);
    $table = $typeDefinition['table'];
    $file = toSqlPath($path);
    $target = sprintf('%s (%s)', $table, $columns);
    $options = COPY_FORMAT;

    // En CSV un campo vacío se convierte en NULL. Estas columnas son NOT NULL
    // en RF2 y algunos archivos las traen vacías: forzarlas a cadena vacía
    // evita un fallo de carga por NOT NULL.
    if (($typeDefinition['force_not_null'] ?? []) !== []) {
        $options .= ', FORCE_NOT_NULL (' . implode(', ', $typeDefinition['force_not_null']) . ')';
    }

    if ($client) {
        return sprintf(
            "\\copy %s FROM '%s' WITH (%s)",
            $target,
            $file,
            $options
        );
    }

    return sprintf(
        "COPY %s\n  FROM '%s'\n  WITH (%s);",
        $target,
        $file,
        $options
    );
}

function relativePath(string $path, string $root): string
{
    $normalizedPath = str_replace('\\', '/', $path);
    $normalizedRoot = rtrim(str_replace('\\', '/', $root), '/') . '/';

    if (str_starts_with($normalizedPath, $normalizedRoot)) {
        return substr($normalizedPath, strlen($normalizedRoot));
    }

    return basename($normalizedPath);
}

function formatBytes(int $bytes): string
{
    $units = ['B', 'KB', 'MB', 'GB'];
    $value = (float) $bytes;
    $unit = 0;

    while ($value >= 1024 && $unit < count($units) - 1) {
        $value /= 1024;
        $unit++;
    }

    return number_format($value, $unit === 0 ? 0 : 1, ',', '.') . ' ' . $units[$unit];
}

// =============================================================================
// Punto de entrada
// =============================================================================

$arguments = array_slice($argv, 1);

if (in_array('--help', $arguments, true) || in_array('-h', $arguments, true)) {
    printUsage(STDOUT);
    exit(EXIT_SUCCESS);
}

if ($arguments === []) {
    printUsage(STDERR);
    exit(EXIT_USAGE_ERROR);
}

try {
    ['positional' => $positional, 'options' => $options] = parseArguments($arguments);
} catch (InvalidArgumentException $exception) {
    fwrite(STDERR, 'Error: ' . $exception->getMessage() . PHP_EOL);
    printUsage(STDERR);
    exit(EXIT_USAGE_ERROR);
}

if (count($positional) !== 1) {
    fwrite(STDERR, 'Se esperaba exactamente 1 argumento posicional (ZIP o carpeta).' . PHP_EOL);
    printUsage(STDERR);
    exit(EXIT_USAGE_ERROR);
}

$quiet = isset($options['quiet']);
$client = isset($options['cliente']);
$includeOptional = !isset($options['sin-opcionales']);
$forceStated = isset($options['con-stated']);
$projectRoot = dirname(__DIR__, 2);
$outputPath = isset($options['salida'])
    ? (string) $options['salida']
    : $projectRoot . DIRECTORY_SEPARATOR . 'tools' . DIRECTORY_SEPARATOR . 'sql'
        . DIRECTORY_SEPARATOR . 'snomed' . DIRECTORY_SEPARATOR . '02_carga.sql';
$types = rf2Types();

try {
    $source = realpath($positional[0]);

    if ($source === false) {
        throw new RuntimeException('No existe la ruta: ' . $positional[0]);
    }

    $release = null;
    $root = $source;
    $files = [];

    if (is_dir($source)) {
        $files = collectFiles($source, $types);
        $release = detectRelease(array_map('basename', array_values($files)));
    } elseif (is_file($source)) {
        if (strtolower(pathinfo($source, PATHINFO_EXTENSION)) !== 'zip') {
            throw new RuntimeException('El archivo debe ser un ZIP o una carpeta con la release extraída.');
        }

        $destination = isset($options['destino']) ? (string) $options['destino'] : null;
        $extracted = extractRelease($source, $destination, $types, $quiet);
        $files = $extracted['files'];
        $root = $extracted['root'];
        $release = $extracted['release'];
    } else {
        throw new RuntimeException('La ruta no es un archivo ni una carpeta: ' . $source);
    }

    if ($files === []) {
        throw new RuntimeException(
            'No se encontraron archivos RF2 Snapshot reconocibles. '
            . 'Verificá que la carpeta contenga Snapshot/Terminology y Snapshot/Refset.'
        );
    }

    foreach (['concept', 'description', 'relationship'] as $required) {
        if (!isset($files[$required])) {
            throw new RuntimeException(sprintf(
                'Falta el archivo obligatorio de %s. Sin conceptos, descripciones y relaciones no se puede cargar la release.',
                $types[$required]['label']
            ));
        }
    }

    $pathPrefix = isset($options['ruta']) ? rtrim((string) $options['ruta'], '\\/') : null;
    $lines = [];
    $lines[] = '-- =============================================================================';
    $lines[] = '-- Origen Salud · carga masiva de SNOMED CT (RF2 Snapshot) · PostgreSQL 18';
    $lines[] = '-- 02_carga.sql :: GENERADO AUTOMÁTICAMENTE, NO EDITAR A MANO';
    $lines[] = '-- =============================================================================';
    $lines[] = '--';
    $lines[] = '-- Generado por: tools/php/generar_carga_snomed.php';
    $lines[] = '-- Origen:       ' . str_replace('\\', '/', $root);
    $lines[] = '-- Release:      ' . ($release ?? 'no detectada');
    $lines[] = '-- Modo:         ' . ($client
        ? '\\copy (psql; los archivos se leen en la máquina cliente)'
        : 'COPY (el servidor PostgreSQL lee los archivos)');
    $lines[] = '--';
    $lines[] = '-- Antes de ejecutar: 01_esquema.sql.';
    $lines[] = '-- Después de ejecutar: 03_postcarga.sql y 99_verificacion.sql.';
    $lines[] = '--';
    $lines[] = '-- En modo COPY el usuario de PostgreSQL necesita permiso de lectura sobre';
    $lines[] = '-- las rutas (superusuario, pg_read_server_files o archivos del propio servidor).';
    $lines[] = '-- En modo \\copy se ejecuta con psql:';
    $lines[] = '--   psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/02_carga.sql';
    $lines[] = '--';
    $lines[] = '-- Los archivos RF2 son UTF-8, TSV y CRLF. QUOTE/ESCAPE con backspace';
    $lines[] = '-- desactiva el entrecomillado para que los términos se copien literales.';
    $lines[] = '-- =============================================================================';
    $lines[] = '';
    $lines[] = 'SET client_encoding = \'UTF8\';';
    $lines[] = 'SET statement_timeout = 0;';
    $lines[] = 'SET lock_timeout = 0;';
    $lines[] = '';

    $prepared = [];
    $warnings = [];

    foreach ($types as $key => $type) {
        if (!isset($files[$key])) {
            if ($type['essential']) {
                $warnings[] = 'Falta ' . $type['label'] . ' (' . $key . '): la carga quedará incompleta.';
            }

            continue;
        }

        $isOptional = $type['optional'];

        if ($isOptional && !$includeOptional && !($forceStated && $key === 'stated_relationship')) {
            continue;
        }

        $file = $files[$key];
        validateHeader($key, $type, $file);
        $size = filesize($file);

        if ($size === 0) {
            $warnings[] = 'El archivo ' . basename($file) . ' está vacío; se omitió.';
            continue;
        }

        $path = $pathPrefix !== null
            ? rtrim($pathPrefix, '/') . '/' . relativePath($file, $root)
            : $file;

        $prepared[$key] = [
            'sql' => buildCopy($key, $type, $path, $client),
            'size' => (int) $size,
            'path' => $path,
            'label' => $type['label'],
        ];
    }

    if (count($prepared) === 0) {
        throw new RuntimeException('No quedó ningún archivo para cargar después de aplicar las opciones.');
    }

    $loaded = [];

    foreach ($prepared as $key => $item) {
        if (isset($loaded[$key])) {
            continue;
        }

        $loaded[$key] = true;
        $lines[] = '-- ' . $item['label'];
        $lines[] = $item['sql'];
        $lines[] = '';
    }

    $outputDirectory = dirname($outputPath);

    if (!is_dir($outputDirectory) && !mkdir($outputDirectory, 0775, true) && !is_dir($outputDirectory)) {
        throw new RuntimeException('No se pudo crear la carpeta de salida: ' . $outputDirectory);
    }

    if (file_put_contents($outputPath, implode(PHP_EOL, $lines) . PHP_EOL) === false) {
        throw new RuntimeException('No se pudo escribir el script: ' . $outputPath);
    }

    if (!$quiet) {
        fwrite(STDOUT, PHP_EOL . '=== Script de carga generado ===' . PHP_EOL);
        fwrite(STDOUT, 'Salida:   ' . $outputPath . PHP_EOL);
        fwrite(STDOUT, 'Release:  ' . ($release ?? 'no detectada') . PHP_EOL);
        fwrite(STDOUT, 'Modo:     ' . ($client ? '\\copy (cliente)' : 'COPY (servidor)') . PHP_EOL);
        fwrite(STDOUT, 'Bloques:  ' . count($prepared) . PHP_EOL);
        fwrite(STDOUT, 'Tamaño:   ' . formatBytes(array_sum(array_column($prepared, 'size'))) . PHP_EOL);

        fwrite(STDOUT, PHP_EOL . 'Archivos incluidos:' . PHP_EOL);

        foreach ($prepared as $key => $item) {
            fwrite(STDOUT, sprintf(
                '  %-28s %10s  %s' . PHP_EOL,
                $key,
                formatBytes($item['size']),
                $item['path']
            ));
        }
    }

    foreach ($warnings as $warning) {
        fwrite(STDERR, '[AVISO] ' . $warning . PHP_EOL);
    }

    fwrite(STDERR, PHP_EOL . 'Siguiente paso: psql -d origen_salud -v ON_ERROR_STOP=1 -f '
        . str_replace('\\', '/', $outputPath) . PHP_EOL);

    exit(EXIT_SUCCESS);
} catch (Throwable $exception) {
    fwrite(STDERR, '[ERROR] ' . $exception->getMessage() . PHP_EOL);
    exit(EXIT_RUNTIME_ERROR);
}
