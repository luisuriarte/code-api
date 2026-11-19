<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Admin\AdminGuard;
use OrigenSalud\Portal\Admin\GovernanceService;
use OrigenSalud\Portal\Admin\Rbac;
use OrigenSalud\Portal\Admin\Token;
use OrigenSalud\Portal\Repositories\CatalogReferenceRepository;
use OrigenSalud\Portal\Repositories\InvitationRepository;
use OrigenSalud\Portal\Repositories\OrganizationRepository;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\Services\Session;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/** Invitaciones de colaboradores y aceptación pública por token. */
final class AdminInvitationController
{
    public static function index(): void
    {
        $current = AdminGuard::require(['permission' => 'admin.invites.manage']);
        $status = isset($_GET['status']) && is_string($_GET['status']) ? $_GET['status'] : 'pending';

        if (!in_array($status, ['pending', 'expired', 'accepted', 'revoked', 'all'], true)) {
            $status = 'pending';
        }

        try {
            $invitations = InvitationRepository::all($status);
            $organizations = OrganizationRepository::all(true);
            $catalogs = CatalogReferenceRepository::all();
        } catch (RepositoryException) {
            $invitations = [];
            $organizations = [];
            $catalogs = [];
        }

        View::render('admin/invitations', [
            'pageTitle' => 'Invitaciones | Origen Salud',
            'pageDescription' => 'Alta de colaboradores solo por invitación.',
            'currentPath' => '/admin/invitations',
            'adminUser' => $current['user'],
            'current' => $current,
            'invitations' => $invitations,
            'organizations' => $organizations,
            'roles' => self::invitableRoles($current),
            'status' => $status,
            'catalogs' => $catalogs,
            'flash' => AdminForm::pull(),
        ], 'admin');
    }

    public static function store(): void
    {
        AdminForm::requirePost();
        $current = AdminGuard::require(['permission' => 'admin.invites.manage']);

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/invitations', 'csrf');

            return;
        }

        try {
            (new GovernanceService())->createInvitation($_POST, $current);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/invitations', $exception);

            return;
        }

        AdminForm::success('/admin/invitations?status=pending', 'invite_created');
    }

    public static function resend(int $id): void
    {
        self::action($id, 'resend', AdminGuard::require(['permission' => 'admin.invites.manage']));
    }

    public static function revoke(int $id): void
    {
        self::action($id, 'revoke', AdminGuard::require(['permission' => 'admin.invites.manage']));
    }

    /** @param array<string, mixed> $current */
    private static function action(int $id, string $action, array $current): void
    {
        AdminForm::requirePost();

        if (!AdminForm::validCsrf()) {
            AdminForm::fail('/admin/invitations', 'csrf');

            return;
        }

        try {
            $service = new GovernanceService();

            if ($action === 'resend') {
                $service->resendInvitation($id, $current);
            } else {
                $service->revokeInvitation($id, $current);
            }
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/invitations', $exception);

            return;
        }

        AdminForm::success(
            '/admin/invitations?status=pending',
            $action === 'resend' ? 'invite_resent' : 'invite_revoked'
        );
    }

    /** Página pública de aceptación. El token en claro solo vive en la URL. */
    public static function showAccept(): void
    {
        $token = isset($_GET['token']) && is_string($_GET['token']) ? $_GET['token'] : '';
        $invitation = null;
        $valid = Token::isValidHex($token);

        if ($valid) {
            try {
                $candidate = InvitationRepository::findByTokenHash(Token::hash($token));

                if ($candidate !== null
                    && $candidate['accepted_at'] === null
                    && $candidate['revoked_at'] === null
                    && (bool) $candidate['organization_active']
                    && new \DateTimeImmutable((string) $candidate['expires_at'])
                        > new \DateTimeImmutable('now', new \DateTimeZone('UTC'))
                ) {
                    $invitation = $candidate;
                }
            } catch (RepositoryException) {
                $invitation = null;
            }
        }

        $sessionUserId = Session::get('admin.user_id');
        $sessionEmail = Session::get('admin.email');
        $requiresLogin = $invitation !== null
            && is_int($sessionUserId)
            && is_string($sessionEmail)
            && strtolower($sessionEmail) !== strtolower((string) $invitation['email']);

        header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
        header('Referrer-Policy: no-referrer');

        View::render('admin/invite', [
            'pageTitle' => 'Aceptar invitación | Origen Salud',
            'pageDescription' => 'Alta de colaborador por invitación.',
            'currentPath' => '/admin/invite',
            'adminUser' => null,
            'invitation' => $invitation,
            'token' => $invitation === null ? '' : $token,
            'requiresLogin' => $requiresLogin,
            'flash' => AdminForm::pull(),
        ], 'admin');
    }

    public static function accept(): void
    {
        AdminForm::requirePost();

        $token = isset($_POST['token']) && is_string($_POST['token']) ? $_POST['token'] : '';

        if (!Token::isValidHex($token)) {
            header('Cache-Control: no-store');
            AdminForm::fail('/admin/invite', 'invalid');

            return;
        }

        if (!AdminForm::validCsrf()) {
            header('Cache-Control: no-store');
            AdminForm::fail('/admin/invite?token=' . rawurlencode($token), 'csrf');

            return;
        }

        $sessionUserId = Session::get('admin.user_id');
        $userId = is_int($sessionUserId) ? $sessionUserId : null;

        try {
            (new GovernanceService())->acceptInvitation($token, $_POST, $userId);
        } catch (\Throwable $exception) {
            AdminForm::exception('/admin/invite?token=' . rawurlencode($token), $exception);

            return;
        }

        AdminForm::success('/admin/login?invited=1', 'invite_accepted');
    }

    /** @param array<string, mixed> $current @return list<string> */
    private static function invitableRoles(array $current): array
    {
        $roles = array_keys(Rbac::ROLE_PERMISSIONS);

        return array_values(array_filter(
            $roles,
            static fn (string $role): bool => $role !== 'superadmin'
                || in_array(Rbac::WILDCARD, $current['permissions'], true)
        ));
    }
}
