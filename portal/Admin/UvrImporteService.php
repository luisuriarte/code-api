<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Admin;

/**
 * Importe referencial UVR: siempre derivado, nunca almacenado.
 *
 * Acta U0: nombre visible `importe_referencial`; interno/FHIR
 * `estimated_payment`. Redondeo a dos decimales solo en presentación. Si no
 * existe conversión aprobada, el resultado es null: nunca se inventa un valor.
 */
final class UvrImporteService
{
    private const COMPONENTS = ['work_uvr', 'practice_expense_uvr', 'professional_liability_uvr'];

    /** @param array<string, mixed> $valuation @param array<string, mixed>|null $conversion */
    public static function calcular(array $valuation, ?array $conversion): ?array
    {
        if ($conversion === null) {
            return null;
        }

        $status = (string) ($conversion['review_status'] ?? 'unknown');

        if (!in_array($status, ['approved', 'published'], true)) {
            return null;
        }

        $uvrValue = (float) ($conversion['uvr_value'] ?? 0);

        if ($uvrValue <= 0) {
            return null;
        }

        $total = 0.0;

        foreach (self::COMPONENTS as $component) {
            $total += (float) ($valuation[$component] ?? 0);
        }

        $importe = round($total * $uvrValue, 2, PHP_ROUND_HALF_UP);

        return [
            'total_uvr' => self::format($total),
            'uvr_value' => self::format($uvrValue),
            'currency' => (string) ($conversion['currency'] ?? 'ARS'),
            'importe_referencial' => self::format($importe),
            'estimated_payment' => self::format($importe),
            'es_estimacion' => true,
        ];
    }

    /**
     * Normaliza un decimal escrito a mano en el panel.
     *
     * Acepta punto o coma como separador decimal, con punto o coma de miles:
     * `1.5`, `1,5`, `1.234,56`, `1,234.56`, `1 234,56`. Si aparecen ambos
     * separadores, el más a la derecha es el decimal. Varios separadores
     * iguales se tratan como miles. Devuelve null si el texto no es numérico.
     */
    public static function decimal(mixed $raw): ?float
    {
        if (is_int($raw) || is_float($raw)) {
            return is_finite((float) $raw) ? (float) $raw : null;
        }

        if (!is_string($raw)) {
            return null;
        }

        // Espacio ordinario, NBSP y espacio fino se usan como separador de miles.
        $text = trim(str_replace(["\u{00A0}", "\u{202F}", ' '], '', $raw));

        if ($text === '') {
            return null;
        }

        $lastDot = strrpos($text, '.');
        $lastComma = strrpos($text, ',');

        if ($lastDot !== false && $lastComma !== false) {
            if ($lastDot > $lastComma) {
                $text = str_replace(',', '', $text);
            } else {
                $text = str_replace(['.', ','], ['', '.'], $text);
            }
        } elseif ($lastComma !== false) {
            $text = substr_count($text, ',') > 1
                ? str_replace(',', '', $text)
                : str_replace(',', '.', $text);
        } elseif (substr_count($text, '.') > 1) {
            $text = str_replace('.', '', $text);
        }

        if (!is_numeric($text)) {
            return null;
        }

        $value = (float) $text;

        return is_finite($value) ? $value : null;
    }

    private static function format(float $value): string
    {
        return number_format($value, 2, '.', '');
    }
}
