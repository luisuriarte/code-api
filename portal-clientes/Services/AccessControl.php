<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

use OrigenSalud\CustomerPortal\Repositories\MembershipRepository;
use OrigenSalud\CustomerPortal\Repositories\OperatorRepository;
use OrigenSalud\CustomerPortal\Repositories\OrganizationRepository;
use OrigenSalud\CustomerPortal\Repositories\RoleRepository;
use OrigenSalud\CustomerPortal\Repositories\SessionRepository;
use OrigenSalud\CustomerPortal\I18n\CustomerI18n;

/** Sesión, contexto de organización y RBAC del portal de clientes. */
final class AccessControl
{
    /** @return array<string, mixed>|null */
    public static function current(): ?array
    {
        $raw = CustomerSession::get('customer_token');

        if (!is_string($raw) || $raw === '') {
            return null;
        }

        $session = SessionRepository::findActiveByRawToken($raw);

        if ($session === null) {
            CustomerSession::clear();

            return null;
        }

        SessionRepository::touch((int) $session['session_id']);
        CustomerSession::set('customer_user_id', (int) $session['user_id']);

        return $session;
    }

    /** @return array<string, mixed> */
    public static function requireUser(): array
    {
        $current = self::current();

        if ($current === null) {
            Http::redirect(CustomerI18n::locale() . '/login');
        }

        return $current;
    }

    public static function organizationId(?array $current = null): ?int
    {
        $current ??= self::current();

        if ($current === null) {
            return null;
        }

        $raw = $current['context_organization_id'] ?? null;
        if ($raw === null || $raw === '') {
            return null;
        }

        $organizationId = (int) $raw;
        $userId = (int) $current['user_id'];

        return MembershipRepository::findActive($organizationId, $userId) === null
            ? null
            : $organizationId;
    }

    /** @return array{user: array<string, mixed>, organization: array<string, mixed>, organization_id: int} */
    public static function requireOrganization(): array
    {
        $user = self::requireUser();
        $organizationId = self::organizationId($user);

        if ($organizationId === null) {
            Http::abort(403, 'errors/denied');
        }

        $organization = OrganizationRepository::findById($organizationId);

        if ($organization === null || ($organization['status'] ?? '') !== 'active') {
            Http::abort(403, 'errors/denied');
        }

        return [
            'user' => $user,
            'organization' => $organization,
            'organization_id' => $organizationId,
        ];
    }

    public static function can(
        string $permission,
        ?int $organizationId = null,
        ?array $current = null
    ): bool {
        $current ??= self::current();

        if ($current === null) {
            return false;
        }

        $organizationId ??= self::organizationId($current);

        if ($organizationId === null) {
            return false;
        }

        return in_array(
            $permission,
            RoleRepository::permissionCodes($organizationId, (int) $current['user_id']),
            true
        );
    }

    /** @return array{user: array<string, mixed>, organization: array<string, mixed>, organization_id: int} */
    public static function requirePermission(string $permission): array
    {
        $context = self::requireOrganization();

        if (!self::can($permission, $context['organization_id'], $context['user'])) {
            Http::abort(403, 'errors/denied');
        }

        return $context;
    }

    /** Superadministrador de Origen Salud, aprovisionado explícitamente en os_customer.operator. */
    public static function isSuperAdmin(?int $userId = null): bool
    {
        $current = self::current();
        if ($current === null) {
            return false;
        }

        $userId ??= (int) $current['user_id'];

        return OperatorRepository::isSuperAdmin($userId);
    }

    /** @return array<string, mixed> */
    public static function requireSuperAdmin(): array
    {
        $current = self::requireUser();

        if (!self::isSuperAdmin((int) $current['user_id'])) {
            Http::abort(403, 'errors/denied');
        }

        return $current;
    }
}
