<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Controllers;

use OrigenSalud\CustomerPortal\Config;
use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Services\AccessControl;
use OrigenSalud\CustomerPortal\View;

/**
 * Etapa 9: enlace al portal nativo de facturación.
 *
 * No consulta ni crea facturas, productos, precios ni pagos. La URL se lee
 * del entorno del servidor; si no está configurada, la vista lo comunica.
 */
final class BillingController
{
    public static function index(): void
    {
        $context = AccessControl::requireOrganization();

        View::render('billing', [
            'title' => CustomerI18n::t('customer.billing.title'),
            'user' => $context['user'],
            'organization' => $context['organization'],
            'billing_url' => Config::billingPortalUrl(),
        ]);
    }
}
