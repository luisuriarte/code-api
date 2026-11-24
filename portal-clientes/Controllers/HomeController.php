<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Controllers;

use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Repositories\OrganizationRepository;
use OrigenSalud\CustomerPortal\Services\AccessControl;
use OrigenSalud\CustomerPortal\View;

final class HomeController
{
    public static function index(): void
    {
        $current = AccessControl::requireUser();
        $organizations = OrganizationRepository::findActiveForUser((int) $current['user_id']);
        $organizationId = AccessControl::organizationId($current);
        $organization = $organizationId === null ? null : OrganizationRepository::findById($organizationId);

        View::render('home', [
            'title' => CustomerI18n::t('customer.home.title'),
            'user' => $current,
            'organizations' => $organizations,
            'organization' => $organization,
            'organization_id' => $organizationId,
        ]);
    }
}
