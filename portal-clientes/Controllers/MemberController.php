<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Controllers;

use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Repositories\AuditRepository;
use OrigenSalud\CustomerPortal\Repositories\InvitationRepository;
use OrigenSalud\CustomerPortal\Repositories\MembershipRepository;
use OrigenSalud\CustomerPortal\Repositories\RoleRepository;
use OrigenSalud\CustomerPortal\Config;
use OrigenSalud\CustomerPortal\Services\AccessControl;
use OrigenSalud\CustomerPortal\Services\CustomerCsrf;
use OrigenSalud\CustomerPortal\Services\CustomerSession;
use OrigenSalud\CustomerPortal\Services\Http;
use OrigenSalud\CustomerPortal\Services\CustomerNotification;
use OrigenSalud\CustomerPortal\Services\Token;
use OrigenSalud\CustomerPortal\View;

final class MemberController
{
    public static function index(): void
    {
        $context = AccessControl::requirePermission('member.read');

        View::render('members', [
            'title' => CustomerI18n::t('customer.member.title'),
            'members' => MembershipRepository::listForOrganization($context['organization_id']),
            'invitations' => InvitationRepository::listForOrganization($context['organization_id']),
            'roles' => RoleRepository::assignable(),
            'organization' => $context['organization'],
            'can_invite' => AccessControl::can('member.invite', $context['organization_id'], $context['user']),
            'can_update' => AccessControl::can('member.update', $context['organization_id'], $context['user']),
            'can_revoke' => AccessControl::can('member.revoke', $context['organization_id'], $context['user']),
            'current_user_id' => (int) $context['user']['user_id'],
        ]);
    }

    public static function inviteSubmit(): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }

        $context = AccessControl::requirePermission('member.invite');
        $post = Http::post();
        $email = trim((string) ($post['email'] ?? ''));
        $roleCode = (string) ($post['role_code'] ?? '');

        $assignable = array_column(RoleRepository::assignable(), 'code');
        if (filter_var($email, FILTER_VALIDATE_EMAIL) === false || !in_array($roleCode, $assignable, true)) {
            CustomerSession::set('flash', ['key' => 'customer.member.invalid', 'params' => []]);
            Http::redirect(CustomerI18n::locale() . '/members');
        }

        $raw = Token::random();
        $ttl = Config::auth()['invite_ttl'];
        $expiresAt = gmdate('Y-m-d H:i:s', time() + max(3600, $ttl)) . '+00';

        $invitationId = InvitationRepository::create(
            $context['organization_id'],
            $email,
            $roleCode,
            Token::hash($raw),
            $expiresAt,
            (int) $context['user']['user_id']
        );
        AuditRepository::record(
            (int) $context['user']['user_id'],
            $context['organization_id'],
            'invitation.created',
            'invitation',
            (string) $invitationId,
            'success'
        );

        $organization = (string) ($context['organization']['display_name']
            ?? $context['organization']['legal_name']
            ?? 'Origen Salud');
        $notification = CustomerNotification::invitation($email, $organization, $raw);

        if (!$notification['ok']) {
            InvitationRepository::markExpired($invitationId);
            AuditRepository::record(
                (int) $context['user']['user_id'],
                $context['organization_id'],
                'invitation.mail_failed',
                'invitation',
                (string) $invitationId,
                'failure'
            );
            CustomerSession::set('flash', ['key' => 'customer.member.invite_error', 'params' => []]);
            Http::redirect(CustomerI18n::locale() . '/members');
        }

        CustomerSession::set('flash', ['key' => 'customer.member.invite_created', 'params' => []]);
        Http::redirect(CustomerI18n::locale() . '/members');
    }

    public static function roleSubmit(): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }

        $context = AccessControl::requirePermission('member.update');
        $post = Http::post();
        $targetUserId = (int) ($post['user_id'] ?? 0);
        $roleCode = (string) ($post['role_code'] ?? '');
        $assignable = array_column(RoleRepository::assignable(), 'code');

        if ($targetUserId <= 0 || $targetUserId === (int) $context['user']['user_id']
            || !in_array($roleCode, $assignable, true)
            || MembershipRepository::findActive($context['organization_id'], $targetUserId) === null) {
            AuditRepository::record(
                (int) $context['user']['user_id'],
                $context['organization_id'],
                'membership.role_denied',
                'membership',
                (string) $targetUserId,
                'denied'
            );
            Http::abort(403, 'errors/denied');
        }

        MembershipRepository::changeRole($context['organization_id'], $targetUserId, $roleCode);
        AuditRepository::record(
            (int) $context['user']['user_id'],
            $context['organization_id'],
            'membership.role_changed',
            'membership',
            (string) $targetUserId,
            'success',
            ['role_code' => $roleCode]
        );

        CustomerSession::set('flash', ['key' => 'customer.member.role_saved', 'params' => []]);
        Http::redirect(CustomerI18n::locale() . '/members');
    }

    public static function revokeSubmit(): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }

        $context = AccessControl::requirePermission('member.revoke');
        $post = Http::post();
        $targetUserId = (int) ($post['user_id'] ?? 0);
        $membership = $targetUserId > 0
            ? MembershipRepository::findActive($context['organization_id'], $targetUserId)
            : null;

        if ($membership === null || $targetUserId === (int) $context['user']['user_id']
            || ($membership['role_code'] ?? '') === 'organization_owner') {
            AuditRepository::record(
                (int) $context['user']['user_id'],
                $context['organization_id'],
                'membership.revoke_denied',
                'membership',
                (string) $targetUserId,
                'denied'
            );
            Http::abort(403, 'errors/denied');
        }

        MembershipRepository::revoke($context['organization_id'], $targetUserId);
        AuditRepository::record(
            (int) $context['user']['user_id'],
            $context['organization_id'],
            'membership.revoked',
            'membership',
            (string) $targetUserId,
            'success'
        );

        CustomerSession::set('flash', ['key' => 'customer.member.revoked', 'params' => []]);
        Http::redirect(CustomerI18n::locale() . '/members');
    }
}
