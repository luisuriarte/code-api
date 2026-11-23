<?php

declare(strict_types=1);

/**
 * Sitemap del portal público (med.origen.ar/sitemap.xml).
 *
 * Se genera desde las rutas y locales REALMENTE implementados. No incluye
 * DENTAR-AN/CL (su exposición pública requiere aprobación explícita), ni
 * secciones reservadas (IN/PD/EQ), la página metodológica UVR
 * (enlazada desde Docs) y la ruta rota /cart.
 */

require_once dirname(__DIR__) . '/portal/bootstrap.php';

use OrigenSalud\Portal\Config;
use OrigenSalud\Web\I18n;

$baseUrl = rtrim(Config::baseUrl(), '/');

/** Rutas públicas existentes en portal/Router.php (o en la capa legacy). */
$publicPaths = ['/', '/dentar', '/oftar', '/browse', '/docs', '/about', '/contact'];

$locales = I18n::SUPPORTED;

$escape = static fn (string $value): string =>
    htmlspecialchars($value, ENT_XML1 | ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

header('Content-Type: application/xml; charset=UTF-8');
header('X-Content-Type-Options: nosniff');

echo '<?xml version="1.0" encoding="UTF-8"?>' . PHP_EOL;
echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"'
    . ' xmlns:xhtml="http://www.w3.org/1999/xhtml">' . PHP_EOL;

foreach ($locales as $locale) {
    foreach ($publicPaths as $path) {
        $url = $baseUrl . I18n::localizedPath($locale, $path);

        echo '  <url>' . PHP_EOL;
        echo '    <loc>' . $escape($url) . '</loc>' . PHP_EOL;

        foreach ($locales as $alternate) {
            $href = $baseUrl . I18n::localizedPath($alternate, $path);
            $hreflang = I18n::metadata($alternate)['hreflang'];
            echo '    <xhtml:link rel="alternate" hreflang="'
                . $escape($hreflang) . '" href="' . $escape($href) . '" />' . PHP_EOL;
        }

        $defaultHref = $baseUrl . I18n::localizedPath(I18n::DEFAULT_LOCALE, $path);
        echo '    <xhtml:link rel="alternate" hreflang="x-default" href="'
            . $escape($defaultHref) . '" />' . PHP_EOL;
        echo '  </url>' . PHP_EOL;
    }
}

echo '</urlset>' . PHP_EOL;
