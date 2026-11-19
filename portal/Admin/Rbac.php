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
}
