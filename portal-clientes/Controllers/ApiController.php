<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Controllers;

use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Repositories\EntitlementRepository;
use OrigenSalud\CustomerPortal\Services\AccessControl;
use OrigenSalud\CustomerPortal\View;

/** Etapa 9: API habilitadas para la organización activa, sin medición de consumo. */
final class ApiController
{
    public static function index(): void
    {
        $context = AccessControl::requireOrganization();

        $entitlements = array_values(array_filter(
            EntitlementRepository::findByOrganization($context['organization_id']),
            static fn (array $row): bool => in_array((string) ($row['status'] ?? ''), ['active', 'suspended'], true)
        ));

        View::render('api', [
            'title' => CustomerI18n::t('customer.api.title'),
            'user' => $context['user'],
            'organization' => $context['organization'],
            'organization_id' => $context['organization_id'],
            'entitlements' => $entitlements,
            'can_credentials' => AccessControl::can('credential.read', $context['organization_id'], $context['user']),
        ]);
    }
}
