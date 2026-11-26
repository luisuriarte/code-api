<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Controllers;

use OrigenSalud\CustomerPortal\Config;
use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Services\AccessControl;
use OrigenSalud\CustomerPortal\View;

/** Etapa 9: derivación al canal público de contacto, sin sistema de tickets propio. */
final class SupportController
{
    public static function index(): void
    {
        $user = AccessControl::requireUser();
        $locale = CustomerI18n::locale();

        View::render('support', [
            'title' => CustomerI18n::t('customer.support.title'),
            'user' => $user,
            'contact_url' => Config::publicUrl($locale, 'contact'),
            'docs_url' => Config::baseUrl() . '/' . $locale . '/documentation',
        ]);
    }
}
