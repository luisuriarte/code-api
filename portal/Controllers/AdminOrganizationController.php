<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Admin\AdminGuard;
use OrigenSalud\Portal\Admin\GovernanceService;
use OrigenSalud\Portal\Admin\Rbac;
use OrigenSalud\Portal\Repositories\CatalogGrantRepository;
use OrigenSalud\Portal\Repositories\CatalogReferenceRepository;
use OrigenSalud\Portal\Repositories\InvitationRepository;
use OrigenSalud\Portal\Repositories\MembershipRepository;
use OrigenSalud\Portal\Repositories\OrganizationRepository;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/** CRUD de organizaciones y memberships (M2). */
final class AdminOrganizationController
{
    public static function index(): void
    {
        $current = AdminGuard::require(['permission' => 'admin.orgs.manage']);

        try {
            $organizations = OrganizationRepository::all();
        } catch (RepositoryException) {
            $organizations = [];
        }

        View::render('admin/organizations', [
            'pageTitle' => 'Organizaciones | Origen Salud',
            'pageDescription' => 'Gobernanza de organizaciones colaboradoras.',
            'currentPath' => '/admin/organizations',
            'adminUser' => $current['user'],
            'current' => $current,
            'organizations' => $organizations,
            'types' => Rbac::ORGANIZATION_TYPES,
            'flash' => AdminForm::pull(),
        ], 'admin');
    }

    public static function store(): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'admin.orgs.manage']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/organizations', 'csrf', self::values());

            return;
        }

        try {
            $id = (new GovernanceService())->createOrganization($_POST, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/organizations', $exception, self::values());

            return;
        }

        AdminForm::success('/admin/organizations/' . $id, 'org_created');
    }

    public static function show(int $id): void
    {
        $current = AdminGuard::require(['permission' => 'admin.orgs.manage']);

        try {
            $organization = OrganizationRepository::find($id);
            $members = $organization === null ? [] : MembershipRepository::forOrganization($id);
            $invitations = $organization === null ? [] : InvitationRepository::forOrganization($id);
            $catalogs = CatalogReferenceRepository::all();
        } catch (RepositoryException) {
            $organization = null;
            $members = [];
            $invitations = [];
            $catalogs = [];
        }

        foreach ($members as $index => $member) {
            try {
                $members[$index]['grants'] = CatalogGrantRepository::forMembership((int) $member['id']);
            } catch (RepositoryException) {
                $members[$index]['grants'] = [];
            }
        }

        if ($organization === null) {
            http_response_code(404);
            View::render('admin/denied', [
                'pageTitle' => 'No encontrado | Origen Salud',
                'pageDescription' => 'La organización no existe.',
                'currentPath' => '/admin/organizations',
                'adminUser' => $current['user'],
            ], 'admin');

            return;
        }

        View::render('admin/organization', [
            'pageTitle' => e((string) $organization['name']) . ' | Origen Salud',
            'pageDescription' => 'Detalle de la organización y sus colaboradores.',
            'currentPath' => '/admin/organizations/' . $id,
            'adminUser' => $current['user'],
            'current' => $current,
            'organization' => $organization,
            'members' => $members,
            'invitations' => $invitations,
            'roles' => self::roleCodes(),
            'catalogs' => $catalogs,
            'flash' => AdminForm::pull(),
        ], 'admin');
    }

    public static function update(int $id): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'admin.orgs.manage']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/organizations/' . $id, 'csrf');

            return;
        }

        try {
            (new GovernanceService())->updateOrganization($id, $_POST, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/organizations/' . $id, $exception);

            return;
        }

        AdminForm::success('/admin/organizations/' . $id, 'org_updated');
    }

    public static function deactivate(int $id): void
    {
        self::setActive($id, false, AdminGuard::require(['permission' => 'admin.orgs.manage']));
    }

    public static function reactivate(int $id): void
    {
        self::setActive($id, true, AdminGuard::require(['permission' => 'admin.orgs.manage']));
    }

    public static function assignMember(int $id): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'admin.memberships.manage']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/organizations/' . $id, 'csrf');

            return;
        }

        try {
            (new GovernanceService())->assignMembership($id, $_POST, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/organizations/' . $id, $exception);

            return;
        }

        AdminForm::success('/admin/organizations/' . $id, 'member_assigned');
    }

    /** @param array<string, mixed> $current */
    private static function setActive(int $id, bool $active, array $current): void
    {
        AdminForm::requirePost();

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/organizations/' . $id, 'csrf');

            return;
        }

        try {
            (new GovernanceService())->setOrganizationActive($id, $active, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/organizations/' . $id, $exception);

            return;
        }

        AdminForm::success(
            '/admin/organizations/' . $id,
            $active ? 'org_reactivated' : 'org_deactivated'
        );
    }

    /** @return array<string, mixed> */
    private static function values(): array
    {
        $keys = ['code', 'name', 'legal_name', 'type', 'country_code', 'contact_email', 'website', 'notes'];
        $values = [];

        foreach ($keys as $key) {
            $values[$key] = is_string($_POST[$key] ?? null) ? $_POST[$key] : '';
        }

        return $values;
    }

    /** @return list<string> */
    private static function roleCodes(): array
    {
        return array_keys(Rbac::ROLE_PERMISSIONS);
    }
}
