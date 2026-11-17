<?php

declare(strict_types=1);

namespace OrigenSalud\Tools\Php;

use InvalidArgumentException;
use LogicException;
use PDO;
use PDOException;
use PDOStatement;
use RuntimeException;
use Throwable;

/**
 * Importador por lotes de archivos RF2 de SNOMED-CT.
 *
 * Diseño:
 *  - Lectura en streaming: nunca se carga el archivo completo en memoria.
 *  - Un COMMIT por lote: una fila inválida no obliga a reimportar millones.
 *  - UPSERT idempotente (ON CONFLICT): reejecutar el mismo archivo es seguro.
 *  - Cabecera RF2 validada antes de tocar la base de datos.
 *  - Sentencias preparadas una sola vez por tamaño de lote, con CAST explícito
 *    para que PostgreSQL resuelva los tipos sin depender de la emulación de PDO.
 *
 * Orden de importación obligatorio: concept -> description -> relationship.
 * Las claves foráneas del esquema impiden importar descripciones o relaciones
 * antes que sus conceptos.
 *
 * @see sql/design.sql
 */
final class Rf2Importer
{
    public const MODE_CONCEPT = 'concept';
    public const MODE_DESCRIPTION = 'description';
    public const MODE_RELATIONSHIP = 'relationship';

    /** @var list<string> */
    public const MODES = [self::MODE_CONCEPT, self::MODE_DESCRIPTION, self::MODE_RELATIONSHIP];

    private const TYPE_BIGINT = 'bigint';
    private const TYPE_INTEGER = 'integer';
    private const TYPE_DATE = 'date';
    private const TYPE_BOOLEAN = 'boolean';
    private const TYPE_TEXT = 'text';

    private const MAX_BIGINT = '9223372036854775807';
    private const MAX_INTEGER = '2147483647';

    /**
     * Contrato de cada tipo de archivo RF2: tabla destino, columnas y orden de
     * la cabecera. El orden de "fields" es el orden real del TSV.
     *
     * @var array<string, array{
     *     table: string,
     *     conflict: string,
     *     fields: list<array{header: string, column: string, type: string}>
     * }>
     */
    private const SCHEMA = [
        self::MODE_CONCEPT => [
            'table' => 'snomed_concepts',
            'conflict' => 'id',
            'fields' => [
                ['header' => 'id', 'column' => 'id', 'type' => self::TYPE_BIGINT],
                ['header' => 'effectiveTime', 'column' => 'effective_time', 'type' => self::TYPE_DATE],
                ['header' => 'active', 'column' => 'active', 'type' => self::TYPE_BOOLEAN],
                ['header' => 'moduleId', 'column' => 'module_id', 'type' => self::TYPE_BIGINT],
                ['header' => 'definitionStatusId', 'column' => 'definition_status_id', 'type' => self::TYPE_BIGINT],
            ],
        ],
        self::MODE_DESCRIPTION => [
            'table' => 'snomed_descriptions',
            'conflict' => 'id',
            'fields' => [
                ['header' => 'id', 'column' => 'id', 'type' => self::TYPE_BIGINT],
                ['header' => 'effectiveTime', 'column' => 'effective_time', 'type' => self::TYPE_DATE],
                ['header' => 'active', 'column' => 'active', 'type' => self::TYPE_BOOLEAN],
                ['header' => 'moduleId', 'column' => 'module_id', 'type' => self::TYPE_BIGINT],
                ['header' => 'conceptId', 'column' => 'concept_id', 'type' => self::TYPE_BIGINT],
                ['header' => 'languageCode', 'column' => 'language_code', 'type' => self::TYPE_TEXT],
                ['header' => 'typeId', 'column' => 'type_id', 'type' => self::TYPE_BIGINT],
                ['header' => 'term', 'column' => 'term', 'type' => self::TYPE_TEXT],
                ['header' => 'caseSignificanceId', 'column' => 'case_significance_id', 'type' => self::TYPE_BIGINT],
            ],
        ],
        self::MODE_RELATIONSHIP => [
            'table' => 'snomed_relationships',
            'conflict' => 'id',
            'fields' => [
                ['header' => 'id', 'column' => 'id', 'type' => self::TYPE_BIGINT],
                ['header' => 'effectiveTime', 'column' => 'effective_time', 'type' => self::TYPE_DATE],
                ['header' => 'active', 'column' => 'active', 'type' => self::TYPE_BOOLEAN],
                ['header' => 'moduleId', 'column' => 'module_id', 'type' => self::TYPE_BIGINT],
                ['header' => 'sourceId', 'column' => 'source_id', 'type' => self::TYPE_BIGINT],
                ['header' => 'destinationId', 'column' => 'destination_id', 'type' => self::TYPE_BIGINT],
                ['header' => 'relationshipGroup', 'column' => 'relationship_group', 'type' => self::TYPE_INTEGER],
                ['header' => 'typeId', 'column' => 'type_id', 'type' => self::TYPE_BIGINT],
                ['header' => 'characteristicTypeId', 'column' => 'characteristic_type_id', 'type' => self::TYPE_BIGINT],
                ['header' => 'modifierId', 'column' => 'modifier_id', 'type' => self::TYPE_BIGINT],
            ],
        ],
    ];

    /** @var array<string, PDOStatement> */
    private array $statements = [];

    /** @var callable(string): void */
    private $logger;

    /**
     * @param PDO|null $db Conexión activa. Puede ser null solo en modo dry-run.
     * @param (callable(string): void)|null $logger Destino de los mensajes de progreso.
     */
    public function __construct(
        private readonly ?PDO $db,
        ?callable $logger = null
    ) {
        $this->logger = $logger ?? static function (string $message): void {
            fwrite(STDOUT, $message . PHP_EOL);
        };
    }

    /**
     * Cantidad de columnas que escribe un modo. La usa ImportOptions para
     * calcular el tamaño de lote máximo permitido.
     */
    public static function columnCount(string $mode): int
    {
        return count(self::SCHEMA[$mode]['fields'] ?? throw new InvalidArgumentException(
            'Modo de importación desconocido: ' . $mode
        ));
    }

    /**
     * Ejecuta la importación completa.
     *
     * @throws RuntimeException si el archivo, la cabecera o la escritura fallan.
     */
    public function import(ImportOptions $options): ImportResult
    {
        if ($options->dryRun === false && !$this->db instanceof PDO) {
            throw new LogicException('La importación real requiere una conexión PDO.');
        }

        $startedAt = hrtime(true);
        $handle = $this->openFile($options->filePath);

        try {
            $this->assertHeader($handle, $options);
            $this->prepareSession();

            $schema = self::SCHEMA[$options->mode];
            $expectedColumns = count($schema['fields']);

            $rowsRead = 0;
            $rowsValid = 0;
            $rowsImported = 0;
            $rowsSkipped = 0;
            $rowsFiltered = 0;
            $batches = 0;
            $lineNumber = 1;

            /** @var list<array{line: int, values: list<string>}> $batch */
            $batch = [];

            while (($line = fgets($handle)) !== false) {
                $lineNumber++;
                $line = rtrim($line, "\r\n");

                if ($line === '') {
                    continue;
                }

                if ($options->limit > 0 && $rowsRead >= $options->limit) {
                    break;
                }

                $rowsRead++;

                try {
                    $values = $this->parseLine($line, $options, $expectedColumns);

                    if ($values === null) {
                        // Descripción descartada por el filtro de idioma.
                        $rowsFiltered++;
                        continue;
                    }
                } catch (InvalidArgumentException $exception) {
                    if (!$options->skipInvalid) {
                        throw new RuntimeException(
                            sprintf('Línea %d inválida: %s', $lineNumber, $exception->getMessage()),
                            0,
                            $exception
                        );
                    }

                    $rowsSkipped++;
                    $this->log(sprintf('[omitida] Línea %d: %s', $lineNumber, $exception->getMessage()));
                    continue;
                }

                $rowsValid++;

                if ($options->dryRun) {
                    continue;
                }

                $batch[] = ['line' => $lineNumber, 'values' => $values];

                if (count($batch) >= $options->batchSize) {
                    $rowsImported += $this->persistBatch($options, $batch, $rowsSkipped);
                    $batches++;
                    $batch = [];
                    $this->logProgress($options, $rowsRead, $rowsValid, $rowsImported, $rowsSkipped, $startedAt);
                }
            }

            if (!$options->dryRun && $batch !== []) {
                $rowsImported += $this->persistBatch($options, $batch, $rowsSkipped);
                $batches++;
            }

            if ($rowsValid === 0) {
                throw new RuntimeException('El archivo no contiene filas de datos válidas.');
            }

            return new ImportResult(
                mode: $options->mode,
                filePath: $options->filePath,
                rowsRead: $rowsRead,
                rowsValid: $rowsValid,
                rowsImported: $rowsImported,
                rowsSkipped: $rowsSkipped,
                rowsFiltered: $rowsFiltered,
                batches: $batches,
                dryRun: $options->dryRun,
                seconds: round((hrtime(true) - $startedAt) / 1_000_000_000, 3)
            );
        } finally {
            fclose($handle);
        }
    }

    /**
     * Abre el archivo en modo binario: la codificación se valida fila por fila
     * y así se evita que una configuración regional del sistema la altere.
     *
     * @return resource
     */
    private function openFile(string $path)
    {
        if (!is_file($path)) {
            throw new RuntimeException('El archivo no existe: ' . $path);
        }

        if (!is_readable($path)) {
            throw new RuntimeException('El archivo no es legible: ' . $path);
        }

        $handle = @fopen($path, 'rb');

        if ($handle === false) {
            throw new RuntimeException('No se pudo abrir el archivo: ' . $path);
        }

        return $handle;
    }

    /**
     * Valida que la primera línea sea exactamente la cabecera RF2 esperada.
     *
     * @param resource $handle
     */
    private function assertHeader($handle, ImportOptions $options): void
    {
        $line = fgets($handle);

        if ($line === false) {
            throw new RuntimeException('El archivo está vacío.');
        }

        // Algunos editores agregan BOM; PostgreSQL rechazaría el primer nombre.
        $line = preg_replace('/^\xEF\xBB\xBF/', '', $line) ?? $line;
        $line = rtrim($line, "\r\n");
        $found = array_map(
            static fn (string $value): string => trim($value),
            explode($options->delimiter, $line)
        );

        $expected = array_column(self::SCHEMA[$options->mode]['fields'], 'header');

        if (count($found) !== count($expected)) {
            throw new RuntimeException(sprintf(
                'Cabecera inválida para %s: se esperaban %d columnas y se encontraron %d.',
                $options->mode,
                count($expected),
                count($found)
            ));
        }

        foreach ($expected as $index => $header) {
            if (strcasecmp($found[$index], $header) !== 0) {
                throw new RuntimeException(sprintf(
                    'Cabecera inválida para %s: columna %d es "%s", se esperaba "%s".',
                    $options->mode,
                    $index + 1,
                    $found[$index],
                    $header
                ));
            }
        }
    }

    /**
     * La API configura statement_timeout para requests HTTP. Un lote de
     * importación puede superar ese valor sin ser un problema, así que se
     * desactiva solo para esta conexión CLI.
     */
    private function prepareSession(): void
    {
        if (!$this->db instanceof PDO) {
            return;
        }

        $this->db->exec("SET statement_timeout = 0");
        $this->db->exec("SET application_name = 'origen-salud-rf2-import'");
    }

    /**
     * Convierte una línea TSV en valores normalizados para PostgreSQL.
     *
     * @return list<string>|null Null cuando la fila se descarta por el filtro
     *                           de idioma (solo descripciones).
     */
    private function parseLine(string $line, ImportOptions $options, int $expectedColumns): ?array
    {
        $fields = explode($options->delimiter, $line);

        if (count($fields) !== $expectedColumns) {
            throw new InvalidArgumentException(sprintf(
                'se esperaban %d columnas y se encontraron %d',
                $expectedColumns,
                count($fields)
            ));
        }

        $values = [];

        foreach (self::SCHEMA[$options->mode]['fields'] as $index => $field) {
            $value = $fields[$index];

            if ($field['column'] === 'language_code') {
                $value = $this->normalizeLanguage($value);

                if ($options->appliesLanguageFilter() && $value !== $options->normalizedLanguage()) {
                    return null;
                }
            }

            $values[] = $this->normalizeValue($field, $value);
        }

        return $values;
    }

    private function normalizeValue(array $field, string $raw): string
    {
        return match ($field['type']) {
            self::TYPE_BIGINT => $this->normalizeBigint($raw, $field['header']),
            self::TYPE_INTEGER => $this->normalizeInteger($raw, $field['header']),
            self::TYPE_DATE => $this->normalizeDate($raw),
            self::TYPE_BOOLEAN => $this->normalizeBoolean($raw),
            self::TYPE_TEXT => $this->normalizeText($raw, $field['column']),
            default => throw new LogicException('Tipo de campo no soportado: ' . $field['type']),
        };
    }

    private function normalizeBigint(string $raw, string $field): string
    {
        if (preg_match('/^\d{1,19}$/', $raw) !== 1) {
            throw new InvalidArgumentException($field . ' debe ser un entero positivo.');
        }

        if (strlen($raw) === 19 && strcmp($raw, self::MAX_BIGINT) > 0) {
            throw new InvalidArgumentException($field . ' excede el rango de BIGINT.');
        }

        return $raw;
    }

    private function normalizeInteger(string $raw, string $field): string
    {
        if (preg_match('/^\d{1,10}$/', $raw) !== 1) {
            throw new InvalidArgumentException($field . ' debe ser un entero no negativo.');
        }

        if (strlen($raw) === 10 && strcmp($raw, self::MAX_INTEGER) > 0) {
            throw new InvalidArgumentException($field . ' excede el rango de INTEGER.');
        }

        return $raw;
    }

    /**
     * RF2 usa fechas YYYYMMDD sin separadores.
     */
    private function normalizeDate(string $raw): string
    {
        if (preg_match('/^(\d{4})(\d{2})(\d{2})$/', $raw, $matches) !== 1) {
            throw new InvalidArgumentException('effectiveTime debe tener formato YYYYMMDD.');
        }

        [, $year, $month, $day] = $matches;

        if (!checkdate((int) $month, (int) $day, (int) $year)) {
            throw new InvalidArgumentException('effectiveTime no es una fecha válida: ' . $raw);
        }

        return $year . '-' . $month . '-' . $day;
    }

    private function normalizeBoolean(string $raw): string
    {
        return match (strtolower(trim($raw))) {
            '1', 'true' => 'true',
            '0', 'false' => 'false',
            default => throw new InvalidArgumentException('active debe ser 0 o 1.'),
        };
    }

    private function normalizeText(string $raw, string $column): string
    {
        if (!mb_check_encoding($raw, 'UTF-8')) {
            throw new InvalidArgumentException($column . ' no es UTF-8 válido.');
        }

        // Los caracteres de control romperían la salida JSON de la API.
        if (preg_match('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/', $raw) === 1) {
            throw new InvalidArgumentException($column . ' contiene caracteres de control.');
        }

        if ($column === 'term' && trim($raw) === '') {
            throw new InvalidArgumentException('term no puede estar vacío.');
        }

        return $raw;
    }

    private function normalizeLanguage(string $raw): string
    {
        $language = strtolower(trim($raw));

        if (preg_match('/^(?<primary>[a-z]{2,3})(?:-[a-z0-9]{2,8})*$/', $language, $matches) !== 1) {
            throw new InvalidArgumentException('languageCode inválido: ' . $raw);
        }

        return $matches['primary'];
    }

    /**
     * Escribe un lote y devuelve cuántas filas quedaron efectivamente
     * importadas. Con --skip-invalid, un lote fallido se reintenta fila por
     * fila para aislar el registro problemático sin perder el resto.
     *
     * @param list<array{line: int, values: list<string>}> $batch
     */
    private function persistBatch(ImportOptions $options, array $batch, int &$rowsSkipped): int
    {
        try {
            $this->insertRows($options->mode, $batch);
            return count($batch);
        } catch (RuntimeException $exception) {
            if (!$options->skipInvalid) {
                throw $exception;
            }

            $this->log(
                '[aviso] ' . $exception->getMessage()
                . ' Se reintentará fila por fila para aislar los registros inválidos.'
            );
        }

        $imported = 0;

        foreach ($batch as $row) {
            try {
                $this->insertRows($options->mode, [$row]);
                $imported++;
            } catch (RuntimeException $exception) {
                $rowsSkipped++;
                $this->log(sprintf('[omitida] Línea %d: %s', $row['line'], $exception->getMessage()));
            }
        }

        return $imported;
    }

    /**
     * @param list<array{line: int, values: list<string>}> $rows
     */
    private function insertRows(string $mode, array $rows): void
    {
        if (!$this->db instanceof PDO) {
            throw new LogicException('No hay conexión PDO para escribir.');
        }

        $rowCount = count($rows);
        $statement = $this->preparedStatement($mode, $rowCount);
        $parameter = 0;

        foreach ($rows as $row) {
            foreach ($row['values'] as $value) {
                $statement->bindValue(':p' . $parameter, $value, PDO::PARAM_STR);
                $parameter++;
            }
        }

        $firstLine = $rows[0]['line'];
        $lastLine = $rows[$rowCount - 1]['line'];

        try {
            $this->db->beginTransaction();
            ImporterIdentity::bind(
                $this->db,
                ImporterIdentity::newRunId('import_snomed_rf2')
            );

            try {
                $statement->execute();
                $this->db->commit();
            } catch (Throwable $exception) {
                if ($this->db->inTransaction()) {
                    $this->db->rollBack();
                }

                throw $exception;
            }
        } catch (PDOException $exception) {
            throw new RuntimeException(
                $this->describeDatabaseError($mode, $exception, $firstLine, $lastLine),
                0,
                $exception
            );
        }
    }

    /**
     * Reutiliza la sentencia preparada para un modo y tamaño de lote. En una
     * importación normal solo existen dos variantes: lote completo y remanente.
     */
    private function preparedStatement(string $mode, int $rowCount): PDOStatement
    {
        $key = $mode . ':' . $rowCount;

        if (isset($this->statements[$key])) {
            return $this->statements[$key];
        }

        if (!$this->db instanceof PDO) {
            throw new LogicException('No hay conexión PDO para preparar la sentencia.');
        }

        $this->statements[$key] = $this->db->prepare($this->buildUpsertSql($mode, $rowCount));

        return $this->statements[$key];
    }

    private function buildUpsertSql(string $mode, int $rowCount): string
    {
        $schema = self::SCHEMA[$mode];
        $fields = $schema['fields'];
        $columns = array_column($fields, 'column');
        $parameter = 0;
        $tuples = [];

        for ($row = 0; $row < $rowCount; $row++) {
            $placeholders = [];

            foreach ($fields as $field) {
                $placeholders[] = sprintf(
                    'CAST(:p%d AS %s)',
                    $parameter++,
                    $this->castFor($field['type'])
                );
            }

            $tuples[] = '(' . implode(', ', $placeholders) . ')';
        }

        $updates = [];

        foreach ($columns as $column) {
            if ($column === $schema['conflict']) {
                continue;
            }

            $updates[] = $column . ' = EXCLUDED.' . $column;
        }

        return sprintf(
            "INSERT INTO %s (%s)\nVALUES %s\nON CONFLICT (%s) DO UPDATE SET\n    %s",
            $schema['table'],
            implode(', ', $columns),
            implode(",\n       ", $tuples),
            $schema['conflict'],
            implode(",\n    ", $updates)
        );
    }

    private function castFor(string $type): string
    {
        return match ($type) {
            self::TYPE_BIGINT => 'bigint',
            self::TYPE_INTEGER => 'integer',
            self::TYPE_DATE => 'date',
            self::TYPE_BOOLEAN => 'boolean',
            self::TYPE_TEXT => 'text',
            default => throw new LogicException('Tipo de campo no soportado: ' . $type),
        };
    }

    private function describeDatabaseError(
        string $mode,
        PDOException $exception,
        int $firstLine,
        int $lastLine
    ): string {
        $sqlState = is_string($exception->getCode()) ? $exception->getCode() : '';

        $hint = match ($sqlState) {
            '23503' => ' Importá primero el archivo de conceptos: las descripciones y relaciones dependen de él.',
            '23505' => ' Hay identificadores duplicados dentro del archivo.',
            '23502' => ' Falta un valor obligatorio en alguna fila.',
            '22001', '22003', '22007', '22P02' => ' Hay valores con formato o longitud inválidos.',
            default => '',
        };

        return sprintf(
            'Falló el lote %s (líneas %d-%d): %s.%s',
            $mode,
            $firstLine,
            $lastLine,
            $exception->getMessage(),
            $hint
        );
    }

    private function logProgress(
        ImportOptions $options,
        int $rowsRead,
        int $rowsValid,
        int $rowsImported,
        int $rowsSkipped,
        int $startedAt
    ): void {
        $elapsed = (hrtime(true) - $startedAt) / 1_000_000_000;
        $rate = $elapsed > 0 ? $rowsImported / $elapsed : 0.0;

        $this->log(sprintf(
            '[%s] leídas %s · válidas %s · importadas %s · omitidas %s · %.0f filas/s',
            $options->mode,
            $this->formatNumber($rowsRead),
            $this->formatNumber($rowsValid),
            $this->formatNumber($rowsImported),
            $this->formatNumber($rowsSkipped),
            $rate
        ));
    }

    private function formatNumber(int $value): string
    {
        return number_format($value, 0, ',', '.');
    }

    private function log(string $message): void
    {
        ($this->logger)($message);
    }
}
