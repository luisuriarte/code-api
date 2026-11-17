<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

final class AboutController
{
    public static function index(string $locale, string $currentPath): void
    {
        $t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);

        View::render('about', [
            'pageTitle' => $t('about.title') . ' | Origen Salud',
            'pageDescription' => $t('about.lead'),
            'locale' => $locale,
            'currentPath' => $currentPath,
            'contactUrl' => I18n::localizedPath($locale, '/contact'),
            'browseUrl' => I18n::localizedPath($locale, '/browse'),
            'contactEmail' => Config::contactEmail(),
        ]);
    }
}
