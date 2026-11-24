<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal;

use OrigenSalud\CustomerPortal\I18n\CustomerI18n;

/** Renderizado de plantillas del portal de clientes con layout propio. */
final class View
{
    /** @param array<string, mixed> $data */
    public static function render(string $template, array $data = [], ?string $layout = 'customer'): void
    {
        $locale = CustomerI18n::locale();
        $data['locale'] ??= $locale;
        $data['t'] ??= static fn (string $key, array $parameters = []): string => CustomerI18n::t($key, $parameters);
        $data['baseUrl'] ??= Config::baseUrl();
        $data['csrfToken'] ??= Services\CustomerCsrf::token();
        $data['flash'] ??= Services\CustomerSession::pull('flash');
        $data['year'] ??= date('Y');
        $data['title'] ??= CustomerI18n::t('customer.app.name');

        extract($data, EXTR_SKIP);

        ob_start();
        require __DIR__ . '/Views/' . $template . '.php';
        $content = (string) ob_get_clean();

        if ($layout !== null && $layout !== '') {
            require __DIR__ . '/Views/layouts/' . $layout . '.php';
        } else {
            echo $content;
        }
    }
}
