<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Admin;

/**
 * Reglas puras de control de acceso. Sin PDO: es probado de forma aislada.
 *
 * Los permisos se resuelven siempre en backend. El frontend solo oculta
 * controles; nunca es la fuente de la autorización.
 */
final class Rbac
{
    public const WILDCARD = '*';

    /** @var array<string, string> */
    public const PERMISSIONS = [
        'admin.view' => 'Ver el panel de administración',
        'admin.users.manage' => 'Gestionar usuarios y estados',
        'admin.roles.manage' => 'Gestionar roles y permisos',
        'catalog.view' => 'Ver catálogos habilitados',
        'catalog.propose' => 'Enviar propuestas de cambio',
        'catalog.edit_draft' => 'Editar borradores propios',
        'catalog.review' => 'Revisar propuestas ajenas',
        'catalog.approve' => 'Aprobar propuestas revisadas',
        'catalog.publish' => 'Publicar versiones aprobadas',
        'audit.view' => 'Consultar auditoría de acceso',
        'admin.orgs.manage' => 'Gestionar organizaciones',
        'admin.invites.manage' => 'Gestionar invitaciones de colaboradores',
        'admin.memberships.manage' => 'Gestionar memberships y roles',
        'admin.grants.manage' => 'Gestionar permisos por catálogo',
    ];

    /** Tipos de organización admitidos por la UI (D-02). */
    public const ORGANIZATION_TYPES = [
        'external', 'ministry', 'health_center', 'university',
        'professional_council', 'vendor', 'ngo', 'other',
    ];

    /** Operaciones válidas en un grant de catálogo. */
    public const CATALOG_OPERATIONS = [
        'view', 'propose', 'edit_draft', 'review', 'approve', 'publish',
    ];

    /** @var array<string, list<string>> */
    public const ROLE_PERMISSIONS = [
        'superadmin' => ['*'],
        'catalog_admin' => [
            'admin.view', 'catalog.view', 'catalog.propose', 'catalog.edit_draft',
            'catalog.review', 'catalog.publish', 'audit.view',
        ],
        'editor' => ['admin.view', 'catalog.view', 'catalog.propose', 'catalog.edit_draft'],
        'reviewer' => ['admin.view', 'catalog.view', 'catalog.review', 'catalog.approve', 'audit.view'],
        'publisher' => ['admin.view', 'catalog.view', 'catalog.publish', 'audit.view'],
        'collaborator' => ['admin.view', 'catalog.view', 'catalog.propose'],
        'auditor' => ['admin.view', 'audit.view'],
        'viewer' => ['admin.view', 'catalog.view'],
    ];

    /**
     * @param array<int, string> $permissions
     */
    public static function hasPermission(array $permissions, string $code): bool
    {
        if (!array_key_exists($code, self::PERMISSIONS)) {
            return false;
        }

        return in_array(self::WILDCARD, $permissions, true)
            || in_array($code, $permissions, true);
    }

    /**
     * Autorización por catálogo y operación. Una denegación explícita gana
     * siempre sobre un permiso amplio.
     *
     * @param array<int, array{catalog_code: string, operation: string, allowed: bool}> $grants
     */
    public static function canAccessCatalog(
        array $grants,
        string $catalogCode,
        string $operation,
        array $permissions = []
    ): bool {
        if (in_array(self::WILDCARD, $permissions, true)) {
            return true;
        }

        $decision = null;

        foreach ($grants as $grant) {
            if (!is_array($grant) || !isset($grant['catalog_code'], $grant['operation'])) {
                continue;
            }

            $catalog = (string) $grant['catalog_code'];
            $op = (string) $grant['operation'];

            $matchesCatalog = $catalog === self::WILDCARD || $catalog === $catalogCode;
            $matchesOperation = $op === self::WILDCARD || $op === $operation;

            if (!$matchesCatalog || !$matchesOperation) {
                continue;
            }

            $allowed = (bool) ($grant['allowed'] ?? false);

            if (!$allowed) {
                return false;
            }

            $decision = true;
        }

        return $decision === true;
    }

    /**
     * Separación de funciones: quien propone no puede aprobar su propia
     * propuesta, aunque tenga el permiso catalog.approve.
     */
    public static function canApprove(
        string $proposerId,
        string $reviewerId,
        array $permissions
    ): bool {
        return $proposerId !== $reviewerId
            && self::hasPermission($permissions, 'catalog.approve');
    }

    /** @return list<string> */
    public static function permissionsForRole(string $roleCode): array
    {
        return self::ROLE_PERMISSIONS[$roleCode] ?? [];
    }

    public static function isValidOrganizationType(string $type): bool
    {
        return in_array($type, self::ORGANIZATION_TYPES, true);
    }

    public static function isValidOperation(string $operation): bool
    {
        return in_array($operation, self::CATALOG_OPERATIONS, true);
    }

    public static function isValidOrganizationCode(string $code): bool
    {
        return preg_match('/^[a-z0-9][a-z0-9-]{1,39}$/', $code) === 1;
    }

    /**
     * Techo de permisos: nadie puede otorgar un rol con permisos que no tiene.
     *
     * El rol `superadmin` se representa con el comodín de código, por eso se
     * comprueba también la lista de roles del actor.
     *
     * @param array<int, string> $actorPermissions
     * @param array<int, string> $actorRoles
     */
    public static function canGrantRole(
        array $actorPermissions,
        array $actorRoles,
        string $targetRole
    ): bool {
        if (!array_key_exists($targetRole, self::ROLE_PERMISSIONS)) {
            return false;
        }

        $isSuperadmin = in_array(self::WILDCARD, $actorPermissions, true)
            || in_array('superadmin', $actorRoles, true);

        if ($isSuperadmin) {
            return true;
        }

        if ($targetRole === 'superadmin') {
            return false;
        }

        foreach (self::permissionsForRole($targetRole) as $permission) {
            if ($permission === self::WILDCARD) {
                return false;
            }

            if (!in_array($permission, $actorPermissions, true)) {
                return false;
            }
        }

        return true;
    }
}
