<?php

declare(strict_types=1);

namespace OrigenSalud\Tools\Php;

/**
 * Métricas de una corrida de importación.
 *
 * Los contadores permiten auditar exactamente qué pasó con cada fila:
 *  - rowsRead: líneas de datos leídas después de la cabecera.
 *  - rowsValid: filas que pasaron la validación de formato.
 *  - rowsImported: filas efectivamente escritas (0 en modo dry-run).
 *  - rowsSkipped: filas descartadas por errores, solo con --skip-invalid.
 *  - rowsFiltered: descripciones descartadas por el filtro --language.
 */
final readonly class ImportResult
{
    public function __construct(
        public string $mode,
        public string $filePath,
        public int $rowsRead,
        public int $rowsValid,
        public int $rowsImported,
        public int $rowsSkipped,
        public int $rowsFiltered,
        public int $batches,
        public bool $dryRun,
        public float $seconds
    ) {
    }

    public function rowsPerSecond(): float
    {
        return $this->seconds > 0.0 ? $this->rowsImported / $this->seconds : 0.0;
    }
}
