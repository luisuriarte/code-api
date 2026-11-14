<?php

declare(strict_types=1);

namespace OrigenSalud\Tools\Php;

use InvalidArgumentException;

/**
 * Opciones validadas de una importación RF2.
 *
 * Se construye una sola vez desde el CLI. Al ser un objeto inmutable, el
 * importador no puede alterar la configuración a mitad de una corrida.
 */
final readonly class ImportOptions
{
    public const DEFAULT_BATCH_SIZE = 2000;

    /**
     * Límite de parámetros por sentencia preparada en PostgreSQL es 65 535.
     * Se deja margen para no rozar el límite en versiones futuras del esquema.
     */
    public const MAX_PARAMETERS_PER_STATEMENT = 60000;

    public function __construct(
        public string $filePath,
        public string $mode,
        public int $batchSize = self::DEFAULT_BATCH_SIZE,
        public int $limit = 0,
        public ?string $language = null,
        public string $delimiter = "\t",
        public bool $dryRun = false,
        public bool $skipInvalid = false,
        public bool $quiet = false
    ) {
        if (trim($this->filePath) === '') {
            throw new InvalidArgumentException('La ruta del archivo RF2 es obligatoria.');
        }

        if (!in_array($this->mode, Rf2Importer::MODES, true)) {
            throw new InvalidArgumentException(
                'El tipo debe ser uno de: ' . implode(', ', Rf2Importer::MODES) . '.'
            );
        }

        if ($this->batchSize < 1) {
            throw new InvalidArgumentException('El tamaño de lote debe ser mayor que cero.');
        }

        $maxBatch = intdiv(self::MAX_PARAMETERS_PER_STATEMENT, Rf2Importer::columnCount($this->mode));

        if ($this->batchSize > $maxBatch) {
            throw new InvalidArgumentException(
                'El tamaño de lote máximo para ' . $this->mode . ' es ' . $maxBatch . '.'
            );
        }

        if ($this->limit < 0) {
            throw new InvalidArgumentException('El límite de filas no puede ser negativo.');
        }

        if ($this->delimiter === '') {
            throw new InvalidArgumentException('El delimitador no puede estar vacío.');
        }

        if ($this->language !== null && self::primaryLanguage($this->language) === null) {
            throw new InvalidArgumentException(
                'El idioma debe ser un código ISO como "es" o "en".'
            );
        }
    }

    /**
     * Solo las descripciones tienen idioma; en otros modos el filtro no aplica.
     */
    public function appliesLanguageFilter(): bool
    {
        return $this->language !== null && $this->mode === Rf2Importer::MODE_DESCRIPTION;
    }

    /**
     * Idioma normalizado a su etiqueta primaria ("es-AR" -> "es"), que es la
     * que almacena y consulta la API.
     */
    public function normalizedLanguage(): ?string
    {
        return $this->language === null ? null : self::primaryLanguage($this->language);
    }

    private static function primaryLanguage(string $language): ?string
    {
        $language = strtolower(trim($language));

        if (preg_match('/^(?<primary>[a-z]{2,3})(?:-[a-z0-9]{2,8})*$/', $language, $matches) !== 1) {
            return null;
        }

        return $matches['primary'];
    }
}
