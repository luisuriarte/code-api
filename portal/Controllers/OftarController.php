<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/**
 * Página principal de OFTAR como sección de primer nivel del portal.
 *
 * No consulta la API pública ni crea un segundo motor de búsqueda: los accesos
 * a OFTAR-PR y OFTAR-DX apuntan al explorador compartido con un filtro de
 * catálogo permitido dentro del dominio único `oftar`.
 */
final class OftarController
{
    public static function index(string $locale, string $currentPath): void
    {
        $t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
        $browsePath = I18n::localizedPath($locale, '/browse');

        $structuredData = [[
            '@context' => 'https://schema.org',
            '@type' => 'WebPage',
            'name' => $t('oftar.meta_title'),
            'description' => $t('oftar.meta_description'),
            'url' => Config::baseUrl() . $currentPath,
            'inLanguage' => $locale,
            'publisher' => [
                '@type' => 'Organization',
                'name' => 'Origen Salud',
                'url' => Config::baseUrl(),
            ],
        ]];

        View::render('oftar', [
            'pageTitle' => $t('oftar.meta_title'),
            'pageDescription' => $t('oftar.meta_description'),
            'locale' => $locale,
            'currentPath' => $currentPath,
            'bodyClass' => 'page-oftar',
            'structuredData' => $structuredData,
            'browseUrl' => $browsePath,
            'browsePrUrl' => $browsePath . '?domain=oftar&catalog=oftar-pr',
            'browseDxUrl' => $browsePath . '?domain=oftar&catalog=oftar-dx',
            'docsUrl' => I18n::localizedPath($locale, '/docs'),
            'contactUrl' => I18n::localizedPath($locale, '/contact'),
        ]);
    }
}
