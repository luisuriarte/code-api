<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/**
 * Hub de productos clínicos de Origen Salud.
 *
 * Reúne DENTAR y OFTAR en una sola página de entrada sin duplicar su contenido
 * ni crear un motor de búsqueda propio: los enlaces al explorador compartido
 * conservan el dominio y el catálogo de cada familia.
 */
final class ProductosController
{
    public static function index(string $locale, string $currentPath): void
    {
        $t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
        $browsePath = I18n::localizedPath($locale, '/browse');

        $structuredData = [[
            '@context' => 'https://schema.org',
            '@type' => 'WebPage',
            'name' => $t('products.meta_title'),
            'description' => $t('products.meta_description'),
            'url' => Config::baseUrl() . $currentPath,
            'inLanguage' => $locale,
            'publisher' => [
                '@type' => 'Organization',
                'name' => 'Origen Salud',
                'url' => Config::baseUrl(),
            ],
        ]];

        View::render('productos', [
            'pageTitle' => $t('products.meta_title'),
            'pageDescription' => $t('products.meta_description'),
            'locale' => $locale,
            'currentPath' => $currentPath,
            'activeNav' => 'products',
            'bodyClass' => 'page-products',
            'structuredData' => $structuredData,
            'browseUrl' => $browsePath,
            'dentarUrl' => I18n::localizedPath($locale, '/dentar'),
            'oftarUrl' => I18n::localizedPath($locale, '/oftar'),
            'browseDentarPrUrl' => $browsePath . '?domain=odontologia&catalog=dentar-pr',
            'browseDentarDxUrl' => $browsePath . '?domain=odontologia&catalog=dentar-dx',
            'browseOftarPrUrl' => $browsePath . '?domain=oftar&catalog=oftar-pr',
            'browseOftarDxUrl' => $browsePath . '?domain=oftar&catalog=oftar-dx',
            'docsUrl' => I18n::localizedPath($locale, '/docs'),
            'contactUrl' => I18n::localizedPath($locale, '/contact'),
        ]);
    }
}
