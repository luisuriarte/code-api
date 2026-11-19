<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Admin\AdminGuard;
use OrigenSalud\Portal\Admin\GovernanceService;
use OrigenSalud\Portal\Repositories\MembershipRepository;

/** Suspensión, revocación y grants de memberships (M2). */
final class AdminMembershipController
{
    public static function status(int $id): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'admin.memberships.manage']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin', 'csrf');

            return;
        }

        $membership = MembershipRepository::findById($id);
        $redirect = $membership !== null && $membership['organization_id'] !== null
            ? '/admin/organizations/' . (int) $membership['organization_id']
            : '/admin';

        $status = isset($_POST['status']) && is_string($_POST['status']) ? $_POST['status'] : '';
        $reason = isset($_POST['reason']) && is_string($_POST['reason']) ? $_POST['reason'] : '';

        try {
            (new GovernanceService())->setMembershipStatus($id, $status, $current, $reason);
        } catch (\Throwable $exception) {
            AdminForm::exception($redirect, $exception);

            return;
        }

        AdminForm::success($redirect, 'membership_updated');
    }

    public static function grant(int $id): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'admin.grants.manage']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin', 'csrf');

            return;
        }

        $membership = MembershipRepository::findById($id);
        $redirect = $membership !== null && $membership['organization_id'] !== null
            ? '/admin/organizations/' . (int) $membership['organization_id']
            : '/admin';

        try {
            (new GovernanceService())->setGrant($id, $_POST, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception($redirect, $exception);

            return;
        }

        AdminForm::success($redirect, 'grant_updated');
    }
}
