<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Services;

/**
 * Derivación determinista del idioma de origen de LOINC (D-40).
 *
 * Es la misma regla de loinc_source_language(language_code, source_file) en
 * sql/07_multilingue/07_fase5_loinc_tabla.sql. Si ambas cambian, deben cambiar
 * juntas: el archivo acredita la capa, no inventa un idioma distinto.
 */
final class LoincSourceLanguage
{
    public static function resolve(string $languageCode, ?string $sourceFile): ?string
    {
        if ($sourceFile === null) {
            return null;
        }

        $declared = [
            'en' => ['Loinc.csv', 'ConsumerName.csv'],
            'es-MX' => ['esMX28LinguisticVariant.csv'],
            'es-AR' => ['esAR7LinguisticVariant.csv'],
        ];

        return in_array($sourceFile, $declared[$languageCode] ?? [], true)
            ? $languageCode
            : null;
    }
}
