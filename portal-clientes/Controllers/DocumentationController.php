<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Controllers;

use OrigenSalud\CustomerPortal\Config;
use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Services\AccessControl;
use OrigenSalud\CustomerPortal\View;

/** Etapa 9: accesos a la documentación pública y a las credenciales propias. */
final class DocumentationController
{
    public static function index(): void
    {
        $user = AccessControl::requireUser();
        $locale = CustomerI18n::locale();

        View::render('documentation', [
            'title' => CustomerI18n::t('customer.docs.title'),
            'user' => $user,
            'docs_url' => Config::publicUrl($locale, 'docs'),
            'credentials_url' => Config::baseUrl() . '/' . $locale . '/credentials',
            'can_credentials' => AccessControl::can('credential.read'),
        ]);
    }
}
