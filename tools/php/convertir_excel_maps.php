#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Convierte los Excel de mapeo de SNOMED CT Argentina (NBU y GTIN) a TSV.
 *
 * Es el equivalente en PHP de `scripts/convertir_excel_maps.py` del proyecto
 * MariaDB, pero sin dependencias externas: lee el XLSX (que es un ZIP) y su
 * XML con las extensiones estándar de PHP (`zlib`, `dom`, `xml`). No requiere
 * `ext-zip`, `openpyxl` ni Python.
 *
 * Uso:
 *   php tools/php/convertir_excel_maps.php <carpeta|archivo.xlsx> [opciones]
 *
 * Ejemplos:
 *   php tools/php/convertir_excel_maps.php "D:\sct\20260820\Resources"
 *   php tools/php/convertir_excel_maps.php "D:\sct\...\Mapeo_NBU_SCT_Agosto26.xlsx"
 *   php tools/php/convertir_excel_maps.php Resources --salida=var/maps --solo-gtin
 *
 * Salida:
 *   - Mapeo_NBU_SCT_Agosto26.tsv        (sctid, codigo_nbu, determinacion)
 *   - MAP_GTIN_a_RPCD_comercializadas_20260820.tsv
 *                                       (gtin, condicion, rpcd_id, rpcd_fsn)
 *
 * Los TSV son UTF-8 sin BOM, con encabezado y separador tabulador. Se cargan
 * con tools/sql/snomed/05_map_excel.sql.
 *
 * Códigos de salida: 0 = OK, 1 = error de archivo/lectura, 2 = uso incorrecto.
 */

const EXIT_SUCCESS = 0;
const EXIT_RUNTIME_ERROR = 1;
const EXIT_USAGE_ERROR = 2;

const NBU_PATTERN = '/^Mapeo_NBU_SCT.*\.xlsx$/i';
const GTIN_PATTERN = '/^MAP_GTIN.*\.xlsx$/i';

const SPREADSHEET_NS = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const RELATIONSHIPS_NS = 'http://schemas.openxmlformats.org/package/2006/relationships';
const OFFICE_REL_NS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    exit("Este script solo puede ejecutarse desde la línea de comandos.\n");
}

/**
 * Error de uso: argumentos faltantes o inválidos.
 */
final class UsageError extends RuntimeException
{
}

/**
 * Lector mínimo de archivos ZIP/XLSX.
 *
 * XLSX es un ZIP con entradas XML. Se lee la tabla de contenidos central y se
 * descomprime cada entrada con `gzinflate`, sin depender de `ext-zip`.
 */
final class XlsxArchive
{
    /** @var array<string, array{method: int, size: int, offset: int}> */
    private array $entries = [];

    private string $data;

    public function __construct(string $path)
    {
        $data = @file_get_contents($path);

        if ($data === false) {
            throw new RuntimeException(sprintf('No se pudo leer el archivo: %s', $path));
        }

        $this->data = $data;
        $this->readCentralDirectory($path);
    }

    public function has(string $name): bool
    {
        return isset($this->entries[$name]);
    }

    /**
     * @return list<string>
     */
    public function names(): array
    {
        return array_keys($this->entries);
    }

    public function read(string $name): string
    {
        if (!isset($this->entries[$name])) {
            throw new RuntimeException(sprintf('El XLSX no contiene la entrada "%s".', $name));
        }

        $entry = $this->entries[$name];
        $offset = $entry['offset'];

        if (substr($this->data, $offset, 4) !== "PK\x03\x04") {
            throw new RuntimeException(sprintf('Cabecera ZIP inválida en "%s".', $name));
        }

        $nameLength = $this->uint16($offset + 26);
        $extraLength = $this->uint16($offset + 28);
        $dataOffset = $offset + 30 + $nameLength + $extraLength;
        $compressed = substr($this->data, $dataOffset, $entry['size']);

        if (strlen($compressed) !== $entry['size']) {
            throw new RuntimeException(sprintf('Entrada ZIP truncada: "%s".', $name));
        }

        if ($entry['method'] === 0) {
            return $compressed;
        }

        if ($entry['method'] === 8) {
            $uncompressed = @gzinflate($compressed);

            if ($uncompressed === false) {
                throw new RuntimeException(sprintf('No se pudo descomprimir "%s".', $name));
            }

            return $uncompressed;
        }

        throw new RuntimeException(sprintf(
            'Método de compresión ZIP no soportado (%d) en "%s".',
            $entry['method'],
            $name
        ));
    }

    private function readCentralDirectory(string $path): void
    {
        $eocd = strrpos($this->data, "PK\x05\x06");

        if ($eocd === false) {
            throw new RuntimeException(sprintf('El archivo no es un ZIP/XLSX válido: %s', $path));
        }

        $totalEntries = $this->uint16($eocd + 10);
        $cdOffset = $this->uint32($eocd + 16);

        // ZIP64: los XLSX de estos mapeos no lo usan. Fallar claro si aparece.
        if ($totalEntries === 0xFFFF || $cdOffset === 0xFFFFFFFF) {
            throw new RuntimeException('El XLSX usa ZIP64, que este conversor no soporta.');
        }

        $position = $cdOffset;

        for ($i = 0; $i < $totalEntries; $i++) {
            if (substr($this->data, $position, 4) !== "PK\x01\x02") {
                throw new RuntimeException('Tabla de contenidos ZIP corrupta.');
            }

            $method = $this->uint16($position + 10);
            $compressedSize = $this->uint32($position + 20);
            $nameLength = $this->uint16($position + 28);
            $extraLength = $this->uint16($position + 30);
            $commentLength = $this->uint16($position + 32);
            $localOffset = $this->uint32($position + 42);
            $name = substr($this->data, $position + 46, $nameLength);

            if ($name === '') {
                throw new RuntimeException('Entrada ZIP sin nombre.');
            }

            $this->entries[$name] = [
                'method' => $method,
                'size' => $compressedSize,
                'offset' => $localOffset,
            ];

            $position += 46 + $nameLength + $extraLength + $commentLength;
        }
    }

    private function uint16(int $offset): int
    {
        $chunk = substr($this->data, $offset, 2);

        if (strlen($chunk) !== 2) {
            throw new RuntimeException('ZIP truncado.');
        }

        return unpack('v', $chunk)[1];
    }

    private function uint32(int $offset): int
    {
        $chunk = substr($this->data, $offset, 4);

        if (strlen($chunk) !== 4) {
            throw new RuntimeException('ZIP truncado.');
        }

        return unpack('V', $chunk)[1];
    }
}

/**
 * @return array{
 *     input: ?string,
 *     salida: ?string,
 *     solo_nbu: bool,
 *     solo_gtin: bool,
 *     quiet: bool,
 *     hoja: int,
 *     help: bool
 * }
 */
function parseArguments(array $argv): array
{
    $options = [
        'input' => null,
        'salida' => null,
        'solo_nbu' => false,
        'solo_gtin' => false,
        'quiet' => false,
        'hoja' => 0,
        'help' => false,
    ];

    $count = count($argv);

    for ($i = 1; $i < $count; $i++) {
        $arg = $argv[$i];

        if ($arg === '-h' || $arg === '--help') {
            $options['help'] = true;
            continue;
        }

        if ($arg === '--solo-nbu') {
            $options['solo_nbu'] = true;
            continue;
        }

        if ($arg === '--solo-gtin') {
            $options['solo_gtin'] = true;
            continue;
        }

        if ($arg === '--quiet') {
            $options['quiet'] = true;
            continue;
        }

        if ($arg === '--salida' || str_starts_with($arg, '--salida=')) {
            $value = $arg === '--salida'
                ? ($argv[++$i] ?? null)
                : substr($arg, strlen('--salida='));

            if ($value === null || $value === '') {
                throw new UsageError('--salida necesita una ruta.');
            }

            $options['salida'] = $value;
            continue;
        }

        if ($arg === '--hoja' || str_starts_with($arg, '--hoja=')) {
            $value = $arg === '--hoja'
                ? ($argv[++$i] ?? null)
                : substr($arg, strlen('--hoja='));

            if ($value === null || preg_match('/^\d+$/', $value) !== 1) {
                throw new UsageError('--hoja necesita un número entero (0 = primera hoja).');
            }

            $options['hoja'] = (int) $value;
            continue;
        }

        if (str_starts_with($arg, '-')) {
            throw new UsageError(sprintf('Opción desconocida: %s', $arg));
        }

        if ($options['input'] !== null) {
            throw new UsageError('Indicá una sola carpeta o un solo archivo XLSX.');
        }

        $options['input'] = $arg;
    }

    if ($options['solo_nbu'] && $options['solo_gtin']) {
        throw new UsageError('--solo-nbu y --solo-gtin no se pueden usar juntos.');
    }

    return $options;
}

function usage(): string
{
    return <<<'TXT'
Generador de TSV para los mapeos NBU y GTIN de SNOMED CT Argentina
Origen Salud · PostgreSQL

Uso:
  php tools/php/convertir_excel_maps.php <carpeta|archivo.xlsx> [opciones]

Busca, sin distinguir mayúsculas:
  Mapeo_NBU_SCT*.xlsx
  MAP_GTIN*.xlsx

Opciones:
  --salida=RUTA     Carpeta de salida (o archivo .tsv si hay un solo mapeo).
                    Default: la misma carpeta del XLSX.
  --solo-nbu        Convierte sólo el mapeo NBU.
  --solo-gtin       Convierte sólo el mapeo GTIN.
  --hoja=N          Hoja del XLSX a leer, base 0. Default: 0 (la primera).
  --quiet           No muestra el progreso.
  -h, --help        Esta ayuda.

Salida:
  Mapeo_NBU_SCT_Agosto26.tsv
  MAP_GTIN_a_RPCD_comercializadas_20260820.tsv

Códigos de salida:
  0  Conversión correcta.
  1  Error de archivo, ZIP/XLSX o escritura.
  2  Uso incorrecto de argumentos.

Después de convertir, cargar con psql desde la carpeta de los TSV
(el script usa \copy: los nombres son literales, no acepta -v ruta_*):
  cd RUTA
  psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/05_map_excel.sql
TXT;
}

/**
 * @param array{input:string, salida:?string, solo_nbu:bool, solo_gtin:bool, hoja:int} $options
 * @return list<array{kind: string, xlsx: string, out: string}>
 */
function resolveJobs(array $options): array
{
    $input = $options['input'];
    $jobs = [];

    if (is_dir($input)) {
        $nbu = findFile($input, NBU_PATTERN, 'NBU');
        $gtin = findFile($input, GTIN_PATTERN, 'GTIN');

        if ($nbu === null && $gtin === null) {
            throw new RuntimeException(sprintf(
                'No se encontraron Mapeo_NBU_SCT*.xlsx ni MAP_GTIN*.xlsx en: %s',
                $input
            ));
        }

        if (!$options['solo_gtin'] && $nbu !== null) {
            $jobs[] = ['kind' => 'nbu', 'xlsx' => $nbu, 'out' => ''];
        }

        if (!$options['solo_nbu'] && $gtin !== null) {
            $jobs[] = ['kind' => 'gtin', 'xlsx' => $gtin, 'out' => ''];
        }
    } elseif (is_file($input)) {
        $kind = null;

        if (preg_match(NBU_PATTERN, basename($input)) === 1) {
            $kind = 'nbu';
        } elseif (preg_match(GTIN_PATTERN, basename($input)) === 1) {
            $kind = 'gtin';
        }

        if ($kind === null) {
            throw new RuntimeException(sprintf(
                'El archivo no parece ser un mapeo NBU ni GTIN: %s',
                basename($input)
            ));
        }

        if (($kind === 'nbu' && $options['solo_gtin']) || ($kind === 'gtin' && $options['solo_nbu'])) {
            throw new UsageError('El archivo indicado no coincide con --solo-nbu/--solo-gtin.');
        }

        $jobs[] = ['kind' => $kind, 'xlsx' => $input, 'out' => ''];
    } else {
        throw new RuntimeException(sprintf('No existe la carpeta o el archivo: %s', $input));
    }

    $salida = $options['salida'];
    $multiple = count($jobs) > 1;

    if ($salida !== null && !$multiple && preg_match('/\.tsv$/i', $salida) === 1) {
        $jobs[0]['out'] = $salida;
    } else {
        $directory = $salida ?? null;

        if ($directory !== null) {
            if (!is_dir($directory) && !@mkdir($directory, 0775, true) && !is_dir($directory)) {
                throw new RuntimeException(sprintf('No se pudo crear la carpeta de salida: %s', $directory));
            }
        }

        foreach ($jobs as $index => $job) {
            $targetDirectory = $directory ?? dirname($job['xlsx']);
            $jobs[$index]['out'] = rtrim($targetDirectory, "/\\")
                . DIRECTORY_SEPARATOR
                . preg_replace('/\.xlsx$/i', '', basename($job['xlsx']))
                . '.tsv';
        }
    }

    return $jobs;
}

function findFile(string $directory, string $pattern, string $label): ?string
{
    $matches = [];

    foreach (scandir($directory) ?: [] as $entry) {
        if ($entry === '.' || $entry === '..') {
            continue;
        }

        $path = rtrim($directory, "/\\") . DIRECTORY_SEPARATOR . $entry;

        if (is_file($path) && preg_match($pattern, $entry) === 1) {
            $matches[] = $path;
        }
    }

    if (count($matches) > 1) {
        throw new RuntimeException(sprintf(
            'Hay más de un archivo %s en %s. Dejá uno solo o indicá el archivo.',
            $label,
            $directory
        ));
    }

    return $matches[0] ?? null;
}

/**
 * @param array{kind: string, xlsx: string, out: string} $job
 * @return array{rows: int, skipped: int}
 */
function convert(array $job, int $sheetIndex): array
{
    $archive = new XlsxArchive($job['xlsx']);
    $sharedStrings = readSharedStrings($archive);
    $sheetPath = worksheetPath($archive, $sheetIndex, $job['xlsx']);
    $sheetXml = $archive->read($sheetPath);

    $handle = @fopen($job['out'], 'wb');

    if ($handle === false) {
        throw new RuntimeException(sprintf('No se pudo escribir: %s', $job['out']));
    }

    try {
        $header = $job['kind'] === 'nbu'
            ? ['sctid', 'codigo_nbu', 'determinacion']
            : ['gtin', 'condicion', 'rpcd_id', 'rpcd_fsn'];

        writeTsvRow($handle, $header);

        $rows = 0;
        $skipped = 0;
        $rowNumber = 0;

        readSheetRows($sheetXml, $sharedStrings, function (array $cells) use (
            $job,
            $handle,
            &$rows,
            &$skipped,
            &$rowNumber
        ): void {
            $rowNumber++;

            // La primera fila es el encabezado del Excel: no se copia.
            if ($rowNumber === 1) {
                return;
            }

            $row = $job['kind'] === 'nbu' ? transformNbuRow($cells) : transformGtinRow($cells);

            if ($row === null) {
                if (array_filter($cells, static fn (string $value): bool => trim($value) !== '') !== []) {
                    $skipped++;
                }

                return;
            }

            writeTsvRow($handle, $row);
            $rows++;
        });
    } finally {
        fclose($handle);
    }

    return ['rows' => $rows, 'skipped' => $skipped];
}

/**
 * @param list<string> $cells
 * @return list<string>|null
 */
function transformNbuRow(array $cells): ?array
{
    $sctid = extractLeadingDigits($cells[0] ?? '');
    $codigo = normalizeNumber($cells[1] ?? '');
    $determinacion = trim($cells[2] ?? '');

    // Las columnas destino son BIGINT/INTEGER: si la celda no trae un ID
    // numérico, la fila se omite para que COPY no aborte toda la carga.
    if (preg_match('/^\d+$/', $sctid) !== 1 || preg_match('/^\d+$/', $codigo) !== 1) {
        return null;
    }

    return [$sctid, $codigo, $determinacion];
}

/**
 * @param list<string> $cells
 * @return list<string>|null
 */
function transformGtinRow(array $cells): ?array
{
    $gtin = normalizeNumber($cells[0] ?? '');
    $condicion = trim($cells[1] ?? '');
    $rpcdId = extractLeadingDigits($cells[2] ?? '');
    $rpcdFsn = trim($cells[3] ?? '');

    // GTIN y RPCD son códigos numéricos; sin ambos la fila no sirve.
    if (preg_match('/^\d+$/', $gtin) !== 1 || preg_match('/^\d+$/', $rpcdId) !== 1) {
        return null;
    }

    return [$gtin, $condicion, $rpcdId, $rpcdFsn];
}

/**
 * @param resource $handle
 * @param list<string> $fields
 */
function writeTsvRow($handle, array $fields): void
{
    // Escape vacío = entrecomillado CSV estándar (comillas dobladas), que es
    // lo que espera COPY/\copy en modo CSV.
    if (fputcsv($handle, $fields, "\t", '"', '', "\n") === false) {
        throw new RuntimeException('No se pudo escribir una fila del TSV.');
    }
}

/**
 * @return list<string>
 */
function readSharedStrings(XlsxArchive $archive): array
{
    if (!$archive->has('xl/sharedStrings.xml')) {
        return [];
    }

    $dom = new DOMDocument();

    if (!@$dom->loadXML($archive->read('xl/sharedStrings.xml'), LIBXML_NONET | LIBXML_COMPACT)) {
        throw new RuntimeException('No se pudo interpretar xl/sharedStrings.xml.');
    }

    $xpath = new DOMXPath($dom);
    $xpath->registerNamespace('m', SPREADSHEET_NS);

    $strings = [];

    foreach ($xpath->query('//m:si') ?: [] as $si) {
        $text = '';

        // Texto simple y texto enriquecido; se omiten las anotaciones fonéticas.
        foreach ($xpath->query('./m:t | ./m:r/m:t', $si) ?: [] as $node) {
            $text .= $node->textContent;
        }

        $strings[] = $text;
    }

    return $strings;
}

function worksheetPath(XlsxArchive $archive, int $sheetIndex, string $source): string
{
    if ($sheetIndex < 0) {
        throw new UsageError('--hoja debe ser mayor o igual a 0.');
    }

    $workbookPath = 'xl/workbook.xml';
    $relsPath = 'xl/_rels/workbook.xml.rels';

    if (!$archive->has($workbookPath) || !$archive->has($relsPath)) {
        // Fallback para XLSX mínimos sin relaciones.
        $fallback = sprintf('xl/worksheets/sheet%d.xml', $sheetIndex + 1);

        if ($archive->has($fallback)) {
            return $fallback;
        }

        throw new RuntimeException(sprintf('El XLSX no tiene hoja de cálculo utilizable: %s', $source));
    }

    $workbook = new DOMDocument();

    if (!@$workbook->loadXML($archive->read($workbookPath), LIBXML_NONET | LIBXML_COMPACT)) {
        throw new RuntimeException('No se pudo interpretar xl/workbook.xml.');
    }

    $workbookXPath = new DOMXPath($workbook);
    $workbookXPath->registerNamespace('m', SPREADSHEET_NS);
    $workbookXPath->registerNamespace('r', OFFICE_REL_NS);

    $sheets = $workbookXPath->query('//m:sheets/m:sheet') ?: [];
    $sheet = $sheets->item($sheetIndex);

    if ($sheet === null) {
        throw new RuntimeException(sprintf(
            'El XLSX no tiene una hoja en la posición %d.',
            $sheetIndex
        ));
    }

    $relationshipId = $sheet->getAttributeNS(OFFICE_REL_NS, 'id');

    if ($relationshipId === '') {
        throw new RuntimeException('La hoja no tiene relación (r:id).');
    }

    $rels = new DOMDocument();

    if (!@$rels->loadXML($archive->read($relsPath), LIBXML_NONET | LIBXML_COMPACT)) {
        throw new RuntimeException('No se pudo interpretar xl/_rels/workbook.xml.rels.');
    }

    $relsXPath = new DOMXPath($rels);
    $relsXPath->registerNamespace('r', RELATIONSHIPS_NS);

    foreach ($relsXPath->query('//r:Relationship') ?: [] as $relationship) {
        if ($relationship->attributes?->getNamedItem('Id')?->nodeValue !== $relationshipId) {
            continue;
        }

        $target = $relationship->attributes?->getNamedItem('Target')?->nodeValue ?? '';

        if ($target === '') {
            break;
        }

        $path = resolveZipPath('xl', $target);

        if (!$archive->has($path)) {
            throw new RuntimeException(sprintf('El XLSX no contiene la hoja "%s".', $path));
        }

        return $path;
    }

    throw new RuntimeException(sprintf('No se encontró la relación de la hoja "%s".', $relationshipId));
}

function resolveZipPath(string $base, string $target): string
{
    if (str_starts_with($target, '/')) {
        return ltrim($target, '/');
    }

    $parts = explode('/', $base . '/' . $target);
    $resolved = [];

    foreach ($parts as $part) {
        if ($part === '' || $part === '.') {
            continue;
        }

        if ($part === '..') {
            array_pop($resolved);
            continue;
        }

        $resolved[] = $part;
    }

    return implode('/', $resolved);
}

/**
 * Recorre la hoja y entrega una fila por callback. No guarda toda la hoja en
 * memoria: el mapeo GTIN tiene 15.500 filas y puede crecer.
 *
 * @param list<string> $sharedStrings
 * @param callable(array<int, string>): void $onRow
 */
function readSheetRows(string $xml, array $sharedStrings, callable $onRow): void
{
    $reader = new XMLReader();

    if (!$reader->XML($xml, null, LIBXML_NONET | LIBXML_COMPACT)) {
        throw new RuntimeException('No se pudo interpretar la hoja de cálculo.');
    }

    $row = [];
    $inRow = false;
    $cellColumn = null;
    $cellType = 'n';
    $cellValue = null;
    $inlineText = null;
    $nextColumn = 0;

    while ($reader->read()) {
        if ($reader->nodeType === XMLReader::ELEMENT) {
            switch ($reader->localName) {
                case 'row':
                    $row = [];
                    $inRow = true;
                    $nextColumn = 0;
                    break;

                case 'c':
                    if (!$inRow) {
                        break;
                    }

                    $reference = $reader->getAttribute('r');

                    if ($reference !== null && $reference !== '') {
                        $cellColumn = columnIndex($reference);
                        $nextColumn = $cellColumn + 1;
                    } else {
                        $cellColumn = $nextColumn++;
                    }

                    $cellType = $reader->getAttribute('t') ?? 'n';
                    $cellValue = null;
                    $inlineText = null;

                    if ($reader->isEmptyElement) {
                        $row[$cellColumn] = '';
                        $cellColumn = null;
                    }

                    break;

                case 'v':
                    if ($cellColumn !== null) {
                        $cellValue = $reader->readString();
                    }
                    break;

                case 't':
                    if ($cellColumn !== null && $cellType === 'inlineStr') {
                        $inlineText = ($inlineText ?? '') . $reader->readString();
                    }
                    break;
            }

            continue;
        }

        if ($reader->nodeType !== XMLReader::END_ELEMENT) {
            continue;
        }

        if ($reader->localName === 'c' && $cellColumn !== null) {
            $raw = $cellType === 'inlineStr' ? ($inlineText ?? '') : ($cellValue ?? '');
            $row[$cellColumn] = normalizeCell($raw, $cellType, $sharedStrings);
            $cellColumn = null;
            continue;
        }

        if ($reader->localName === 'row' && $inRow) {
            ksort($row);
            $onRow($row);
            $row = [];
            $inRow = false;
        }
    }

    $reader->close();
}

/**
 * @param list<string> $sharedStrings
 */
function normalizeCell(string $raw, string $type, array $sharedStrings): string
{
    if ($type === 's') {
        $index = (int) trim($raw);

        return $sharedStrings[$index] ?? '';
    }

    if ($type === 'inlineStr' || $type === 'str' || $type === 'd' || $type === 'e') {
        return $raw;
    }

    if ($type === 'b') {
        return trim($raw) === '1' ? '1' : '0';
    }

    return normalizeNumber($raw);
}

function normalizeNumber(string $value): string
{
    $value = trim($value);

    if ($value === '') {
        return '';
    }

    if (preg_match('/^[+-]?\d+$/', $value) === 1) {
        return ltrim($value, '+');
    }

    if (preg_match('/^([+-]?\d+)\.0+$/', $value, $matches) === 1) {
        return $matches[1];
    }

    if (is_numeric($value)) {
        $number = (float) $value;

        if (is_finite($number) && floor($number) === $number && abs($number) < 1.0e15) {
            return sprintf('%.0f', $number);
        }

        return rtrim(rtrim(sprintf('%.15F', $number), '0'), '.');
    }

    return $value;
}

/**
 * Extrae los dígitos iniciales. El Excel NBU trae celdas como
 * "879241000221101 |medición de acetona... (procedimiento)|".
 */
function extractLeadingDigits(string $value): string
{
    $value = trim($value);

    if (preg_match('/^(\d+)/', $value, $matches) === 1) {
        return $matches[1];
    }

    return $value;
}

function columnIndex(string $reference): int
{
    if (preg_match('/^([A-Z]+)/i', $reference, $matches) !== 1) {
        return 0;
    }

    $letters = strtoupper($matches[1]);
    $index = 0;

    for ($i = 0, $length = strlen($letters); $i < $length; $i++) {
        $index = $index * 26 + (ord($letters[$i]) - 64);
    }

    return $index - 1;
}

function main(array $argv): int
{
    try {
        $options = parseArguments($argv);
    } catch (UsageError $error) {
        fwrite(STDERR, 'ERROR: ' . $error->getMessage() . "\n\n" . usage() . "\n");

        return EXIT_USAGE_ERROR;
    }

    if ($options['help']) {
        echo usage(), "\n";

        return EXIT_SUCCESS;
    }

    if ($options['input'] === null) {
        fwrite(STDERR, "ERROR: falta la carpeta o el archivo XLSX.\n\n" . usage() . "\n");

        return EXIT_USAGE_ERROR;
    }

    try {
        $jobs = resolveJobs($options);

        foreach ($jobs as $job) {
            $result = convert($job, $options['hoja']);

            if (!$options['quiet']) {
                printf(
                    "[OK] %s: %d filas, %d omitidas -> %s\n",
                    strtoupper($job['kind']),
                    $result['rows'],
                    $result['skipped'],
                    $job['out']
                );
            }
        }
    } catch (UsageError $error) {
        fwrite(STDERR, 'ERROR: ' . $error->getMessage() . "\n\n" . usage() . "\n");

        return EXIT_USAGE_ERROR;
    } catch (Throwable $error) {
        fwrite(STDERR, 'ERROR: ' . $error->getMessage() . "\n");

        return EXIT_RUNTIME_ERROR;
    }

    if (!$options['quiet']) {
        echo "\nSiguiente paso: cd a la carpeta de los TSV y después psql -v ON_ERROR_STOP=1 -f tools/sql/snomed/05_map_excel.sql\n";
    }

    return EXIT_SUCCESS;
}

exit(main($argv));
