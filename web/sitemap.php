<?php

declare(strict_types=1);

/**
 * Sitemap del portal público (med.origen.ar/sitemap.xml).
 *
 * Se genera desde las rutas y locales REALMENTE implementados y publica las
 * canónicas que sirve cada página: prefijo de idioma para el portal y
 * `?lang=` para los documentos legacy Docs/UVR. No incluye DENTAR-AN/CL (su
 * exposición pública requiere aprobación explícita), secciones reservadas
 * (IN/PD/EQ), la ruta noindex `/search` ni la ruta rota `/cart`.
 */

require_once dirname(__DIR__) . '/portal/bootstrap.php';

use OrigenSalud\Portal\Config;
use OrigenSalud\Web\I18n;

$baseUrl = rtrim(Config::baseUrl(), '/');

/** Rutas con canonical `/{locale}/…`. */
$localizedPaths = ['/', '/dentar', '/oftar', '/browse', '/about', '/contact', '/terminos', '/privacidad'];
if (Config::serviceRequestLinkEnabled()) {
    $localizedPaths[] = '/solicitud';
}

/** Rutas standalone con canonical `?lang=`. */
$queryPaths = ['/docs', '/uvr'];

$locales = I18n::SUPPORTED;
$defaultLocale = I18n::DEFAULT_LOCALE;

$canonicalUrl = static function (string $path, string $locale) use ($baseUrl, $queryPaths): string {
    if (in_array($path, $queryPaths, true)) {
        return $baseUrl . $path . '?lang=' . rawurlencode($locale);
    }

    return $baseUrl . I18n::localizedPath($locale, $path);
};

$escape = static fn (string $value): string =>
    htmlspecialchars($value, ENT_XML1 | ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

header('Content-Type: application/xml; charset=UTF-8');
header('X-Content-Type-Options: nosniff');

echo '<?xml version="1.0" encoding="UTF-8"?>' . PHP_EOL;
echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"'
    . ' xmlns:xhtml="http://www.w3.org/1999/xhtml">' . PHP_EOL;

foreach (array_merge($localizedPaths, $queryPaths) as $path) {
    foreach ($locales as $locale) {
        echo '  <url>' . PHP_EOL;
        echo '    <loc>' . $escape($canonicalUrl($path, $locale)) . '</loc>' . PHP_EOL;

        foreach ($locales as $alternate) {
            $href = $canonicalUrl($path, $alternate);
            $hreflang = I18n::metadata($alternate)['hreflang'];
            echo '    <xhtml:link rel="alternate" hreflang="'
                . $escape($hreflang) . '" href="' . $escape($href) . '" />' . PHP_EOL;
        }

        echo '    <xhtml:link rel="alternate" hreflang="x-default" href="'
            . $escape($canonicalUrl($path, $defaultLocale)) . '" />' . PHP_EOL;
        echo '  </url>' . PHP_EOL;
    }
}

echo '</urlset>' . PHP_EOL;
