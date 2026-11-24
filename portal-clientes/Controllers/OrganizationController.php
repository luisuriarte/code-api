<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Controllers;

use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Repositories\AuditRepository;
use OrigenSalud\CustomerPortal\Repositories\MembershipRepository;
use OrigenSalud\CustomerPortal\Repositories\OrganizationRepository;
use OrigenSalud\CustomerPortal\Repositories\SessionRepository;
use OrigenSalud\CustomerPortal\Services\AccessControl;
use OrigenSalud\CustomerPortal\Services\CustomerCsrf;
use OrigenSalud\CustomerPortal\Services\CustomerSession;
use OrigenSalud\CustomerPortal\Services\Http;
use OrigenSalud\CustomerPortal\View;

final class OrganizationController
{
    public static function index(): void
    {
        $context = AccessControl::requireOrganization();

        View::render('organizations', [
            'title' => CustomerI18n::t('customer.org.title'),
            'organization' => $context['organization'],
            'organizations' => OrganizationRepository::findActiveForUser((int) $context['user']['user_id']),
            'can_update' => AccessControl::can('org.update', $context['organization_id'], $context['user']),
        ]);
    }

    public static function switchSubmit(): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }

        $current = AccessControl::requireUser();
        $post = Http::post();
        $organizationId = (int) ($post['organization_id'] ?? 0);

        if ($organizationId <= 0 || MembershipRepository::findActive($organizationId, (int) $current['user_id']) === null) {
            AuditRepository::record((int) $current['user_id'], null, 'organization.switch_denied', 'organization', (string) $organizationId, 'denied');
            Http::abort(403, 'errors/denied');
        }

        $organization = OrganizationRepository::findById($organizationId);
        if ($organization === null || ($organization['status'] ?? '') !== 'active') {
            Http::abort(403, 'errors/denied');
        }

        SessionRepository::setContext(
            (int) $current['session_id'],
            $organizationId
        );
        AuditRepository::record((int) $current['user_id'], $organizationId, 'organization.switched', 'organization', (string) $organizationId, 'success');

        CustomerSession::set('flash', ['key' => 'customer.org.switched', 'params' => []]);
        Http::redirect(CustomerI18n::locale() . '/organizations');
    }

    public static function updateSubmit(): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }

        $context = AccessControl::requirePermission('org.update');
        $post = Http::post();

        $legalName = trim((string) ($post['legal_name'] ?? ''));
        $displayName = trim((string) ($post['display_name'] ?? ''));
        $taxId = trim((string) ($post['tax_id'] ?? ''));

        if ($legalName === '' || mb_strlen($legalName) > 200 || mb_strlen($displayName) > 200 || mb_strlen($taxId) > 32) {
            CustomerSession::set('flash', ['key' => 'customer.org.invalid', 'params' => []]);
            Http::redirect(CustomerI18n::locale() . '/organizations');
        }

        OrganizationRepository::update(
            $context['organization_id'],
            $legalName,
            $displayName === '' ? $legalName : $displayName,
            $taxId === '' ? null : $taxId
        );
        AuditRepository::record(
            (int) $context['user']['user_id'],
            $context['organization_id'],
            'organization.updated',
            'organization',
            (string) $context['organization_id'],
            'success'
        );

        CustomerSession::set('flash', ['key' => 'customer.org.saved', 'params' => []]);
        Http::redirect(CustomerI18n::locale() . '/organizations');
    }
}
