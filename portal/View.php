<?php

declare(strict_types=1);

namespace OrigenSalud\Portal;

use OrigenSalud\Web\I18n;

/**
 * Renderizado simple de plantillas PHP con layout compartido.
 */
final class View
{
    /** @param array<string, mixed> $data */
    public static function render(string $template, array $data = [], string $layout = 'main'): void
    {
        $locale = I18n::locale();
        $data['locale'] ??= $locale;
        $data['t'] ??= static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
        $data['baseUrl'] ??= Config::baseUrl();
        $data['year'] ??= date('Y');
        $data['contactMailto'] ??= 'mailto:' . Config::contactEmail();
        $data['accessMailto'] ??= $data['contactMailto'];
        $data['legalMailto'] ??= 'mailto:legal@origen.ar';

        extract($data, EXTR_SKIP);

        ob_start();
        require __DIR__ . '/Views/' . $template . '.php';
        $content = (string) ob_get_clean();

        require __DIR__ . '/Views/layouts/' . $layout . '.php';
    }
}
