<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/**
 * Página principal de DENTAR como sección de primer nivel del portal.
 *
 * No consulta la API pública ni crea un segundo motor de búsqueda: los accesos
 * a DENTAR-PR y DENTAR-DX apuntan al explorador compartido con un filtro de
 * catálogo permitido.
 */
final class DentarController
{
    public static function index(string $locale, string $currentPath): void
    {
        $t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
        $browsePath = I18n::localizedPath($locale, '/browse');

        $structuredData = [[
            '@context' => 'https://schema.org',
            '@type' => 'WebPage',
            'name' => $t('dentar.meta_title'),
            'description' => $t('dentar.meta_description'),
            'url' => Config::baseUrl() . $currentPath,
            'inLanguage' => $locale,
            'publisher' => [
                '@type' => 'Organization',
                'name' => 'Origen Salud',
                'url' => Config::baseUrl(),
            ],
        ]];

        View::render('dentar', [
            'pageTitle' => $t('dentar.meta_title'),
            'pageDescription' => $t('dentar.meta_description'),
            'locale' => $locale,
            'currentPath' => $currentPath,
            'bodyClass' => 'page-dentar',
            'structuredData' => $structuredData,
            'browseUrl' => $browsePath,
            'browsePrUrl' => $browsePath . '?domain=odontologia&catalog=dentar-pr',
            'browseDxUrl' => $browsePath . '?domain=odontologia&catalog=dentar-dx',
            'docsUrl' => I18n::localizedPath($locale, '/docs'),
            'contactUrl' => I18n::localizedPath($locale, '/contact'),
        ]);
    }
}
