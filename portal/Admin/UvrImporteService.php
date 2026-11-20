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

    private static function format(float $value): string
    {
        return number_format($value, 2, '.', '');
    }
}
