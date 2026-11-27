<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

/**
 * Formateador numérico compartido por las vistas públicas y de administración.
 * es-AR y pt-BR usan 1.234,56; en usa 1,234.56. Los códigos de moneda y UVR
 * se mantienen literalmente: no se traducen ni se convierten aquí.
 */
$formatLocale = I18n::canonical($locale ?? null) ?? I18n::DEFAULT_LOCALE;
$formatNumber = static function (mixed $value, int $decimals = 2) use ($formatLocale): string {
    $decimalSeparator = $formatLocale === 'en' ? '.' : ',';
    $thousandsSeparator = $formatLocale === 'en' ? ',' : '.';

    return number_format((float) $value, $decimals, $decimalSeparator, $thousandsSeparator);
};
