<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Admin;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\Repositories\AdminDatabase;
use OrigenSalud\Portal\Repositories\CatalogGrantRepository;
use OrigenSalud\Portal\Repositories\CatalogReferenceRepository;
use OrigenSalud\Portal\Repositories\InvitationRepository;
use OrigenSalud\Portal\Repositories\MembershipRepository;
use OrigenSalud\Portal\Repositories\OrganizationRepository;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\Repositories\UserRepository;
use OrigenSalud\Portal\Services\SmtpMailer;
use OrigenSalud\Portal\Services\Validator;
use PDOException;

/**
 * Gestión de organizaciones, invitaciones y memberships (M2).
 *
 * Todas las decisiones se toman en backend: permisos, techo de permisos,
 * alcance por organización, protección del último superadministrador y
 * auditoría. Nunca modifica os_catalog_* ni la API pública.
 */
final class GovernanceService
{
    /** @param array<string, mixed> $input */
    public function createOrganization(array $input, array $actor): int
    {
        $this->requirePermission($actor, 'admin.orgs.manage');
        $data = $this->organizationData($input);

        if (OrganizationRepository::findByCode($data['code']) !== null) {
            throw new GovernanceException('org_duplicate');
        }

        $confirmed = $this->flag($input, 'confirm_duplicate');

        if (OrganizationRepository::nameExists($data['name']) && !$confirmed) {
            throw new GovernanceException('org_duplicate');
        }

        $actorId = $this->actorId($actor);
        $id = OrganizationRepository::create($data, $actorId);

        AuditLogger::record('organization_created', $this->actorContext($actor) + [
            'entity_type' => 'organization',
            'entity_id' => (string) $id,
            'after_state' => [
                'code' => $data['code'],
                'name' => $data['name'],
                'type' => $data['type'],
                'country_code' => $data['country_code'],
            ],
        ]);

        return $id;
    }

    /** @param array<string, mixed> $input */
    public function updateOrganization(int $id, array $input, array $actor): void
    {
        $this->requirePermission($actor, 'admin.orgs.manage');

        $before = OrganizationRepository::find($id);

        if ($before === null) {
            throw new GovernanceException('org_not_found');
        }

        $this->requireOrganizationScope($actor, $id);
        $data = $this->organizationData($input);

        if (OrganizationRepository::nameExists($data['name'], $id) && !$this->flag($input, 'confirm_duplicate')) {
            throw new GovernanceException('org_duplicate');
        }

        OrganizationRepository::update($id, $data, $this->actorId($actor));

        AuditLogger::record('organization_updated', $this->actorContext($actor) + [
            'entity_type' => 'organization',
            'entity_id' => (string) $id,
            'before_state' => [
                'name' => $before['name'],
                'type' => $before['type'],
                'country_code' => $before['country_code'],
            ],
            'after_state' => [
                'name' => $data['name'],
                'type' => $data['type'],
                'country_code' => $data['country_code'],
            ],
        ]);
    }

    public function setOrganizationActive(int $id, bool $active, array $actor, string $reason = ''): void
    {
        $this->requirePermission($actor, 'admin.orgs.manage');

        $organization = OrganizationRepository::find($id);

        if ($organization === null) {
            throw new GovernanceException('org_not_found');
        }

        $this->requireOrganizationScope($actor, $id);

        if (!$active && OrganizationRepository::hasBlockingDependencies($id)) {
            throw new GovernanceException('org_has_members');
        }

        OrganizationRepository::setActive($id, $active, $this->actorId($actor));

        AuditLogger::record($active ? 'organization_reactivated' : 'organization_deactivated',
            $this->actorContext($actor) + [
                'entity_type' => 'organization',
                'entity_id' => (string) $id,
                'reason' => $reason !== '' ? mb_substr($reason, 0, 200) : null,
            ]
        );
    }

    /** @param array<string, mixed> $input */
    public function createInvitation(array $input, array $actor): int
    {
        $this->requirePermission($actor, 'admin.invites.manage');

        $organizationId = $this->positiveInt($input['organization_id'] ?? null);

        if ($organizationId === null) {
            throw new GovernanceException('org_not_found');
        }

        $organization = OrganizationRepository::find($organizationId);

        if ($organization === null || !(bool) $organization['is_active']) {
            throw new GovernanceException('org_not_found');
        }

        $this->requireOrganizationScope($actor, $organizationId);

        $emailRaw = Validator::text($input['email'] ?? '', 254);
        $email = Validator::email($emailRaw);

        if ($emailRaw === '' || $email === '') {
            throw new GovernanceException('email');
        }

        $roleCode = Validator::text($input['role_code'] ?? '', 40);

        if (!array_key_exists($roleCode, \OrigenSalud\Portal\Admin\Rbac::ROLE_PERMISSIONS)
            || !Rbac::canGrantRole($actor['permissions'], $actor['roles'], $roleCode)
        ) {
            throw new GovernanceException('role');
        }

        $grants = $this->grantsFromInput($input);
        $actorId = $this->actorId($actor);
        $ttl = $this->invitationTtl($input);

        InvitationRepository::revokeExpired($actorId);

        if (InvitationRepository::hasPending($email, $organizationId)) {
            throw new GovernanceException('pending');
        }

        $token = Token::random();
        $id = InvitationRepository::create(
            $email,
            $organizationId,
            $roleCode,
            Token::hash($token),
            $actorId,
            $ttl,
            $this->nullableText($input['message'] ?? '', 1000),
            $grants
        );

        AuditLogger::record('invitation_created', $this->actorContext($actor) + [
            'entity_type' => 'invitation',
            'entity_id' => (string) $id,
            'after_state' => [
                'organization_id' => $organizationId,
                'role_code' => $roleCode,
                'expires_in' => $ttl,
                'grants' => count($grants),
            ],
        ]);

        $this->sendInvitationMail(
            $email,
            $organization['name'],
            $token,
            $id,
            $actor,
            $this->nullableText($input['message'] ?? '', 1000)
        );

        return $id;
    }

    public function resendInvitation(int $id, array $actor): void
    {
        $this->requirePermission($actor, 'admin.invites.manage');

        $invitation = InvitationRepository::findById($id);

        if ($invitation === null) {
            throw new GovernanceException('not_found');
        }

        $orgId = (int) $invitation['organization_id'];
        $this->requireOrganizationScope($actor, $orgId);

        if ($invitation['accepted_at'] !== null) {
            throw new GovernanceException('accepted');
        }

        if ($invitation['revoked_at'] !== null) {
            throw new GovernanceException('revoked');
        }

        $minimum = max(0, (int) Config::adminAuth()['invite_resend_min']);

        if ($invitation['last_sent_at'] !== null) {
            $last = new \DateTimeImmutable((string) $invitation['last_sent_at']);
            $allowedAt = $last->modify('+' . $minimum . ' seconds');

            if ($allowedAt > new \DateTimeImmutable('now', new \DateTimeZone('UTC'))) {
                throw new GovernanceException('resend_recent');
            }
        }

        $token = Token::random();
        $expiresAt = InvitationRepository::rotateToken(
            $id,
            Token::hash($token),
            $this->invitationTtl([])
        );

        AuditLogger::record('invitation_resent', $this->actorContext($actor) + [
            'entity_type' => 'invitation',
            'entity_id' => (string) $id,
            'after_state' => ['expires_at' => $expiresAt, 'send_count' => (int) $invitation['send_count'] + 1],
        ]);

        $this->sendInvitationMail(
            (string) $invitation['email'],
            (string) $invitation['organization_name'],
            $token,
            $id,
            $actor,
            $invitation['message'] === null ? null : (string) $invitation['message']
        );
    }

    public function revokeInvitation(int $id, array $actor, string $reason = 'revoked'): void
    {
        $this->requirePermission($actor, 'admin.invites.manage');

        $invitation = InvitationRepository::findById($id);

        if ($invitation === null) {
            throw new GovernanceException('not_found');
        }

        $this->requireOrganizationScope($actor, (int) $invitation['organization_id']);

        if ($invitation['accepted_at'] !== null || $invitation['revoked_at'] !== null) {
            throw new GovernanceException('not_found');
        }

        InvitationRepository::revoke($id, $this->actorId($actor), $reason);

        AuditLogger::record('invitation_revoked', $this->actorContext($actor) + [
            'entity_type' => 'invitation',
            'entity_id' => (string) $id,
            'reason' => mb_substr($reason, 0, 40),
        ]);
    }

    /**
     * Aceptación de invitación. El token en claro nunca se persiste ni se audita.
     *
     * @param array<string, mixed> $input
     * @return array{ok: bool, user_id: int}
     */
    public function acceptInvitation(string $token, array $input, ?int $sessionUserId): array
    {
        if (!Token::isValidHex($token)) {
            $this->auditAcceptFailure('invalid_token');

            throw new GovernanceException('invalid');
        }

        $invitation = InvitationRepository::findByTokenHash(Token::hash($token));

        if ($invitation === null) {
            $this->auditAcceptFailure('invalid_token');

            throw new GovernanceException('invalid');
        }

        $reason = $this->invitationBlockReason($invitation);

        if ($reason !== null) {
            $this->auditAcceptFailure($reason, (int) $invitation['id']);

            throw new GovernanceException($reason);
        }

        $email = (string) $invitation['email'];
        $newUser = $sessionUserId === null;
        $fullName = '';
        $passwordHash = '';

        if ($newUser) {
            $fullName = Validator::text($input['full_name'] ?? '', 180);
            $password = isset($input['password']) && is_string($input['password']) ? $input['password'] : '';
            $length = mb_strlen($password);

            if ($fullName === '' || $length < 12 || $length > 200) {
                throw new GovernanceException('weak');
            }

            if (UserRepository::findByEmail($email) !== null) {
                $this->auditAcceptFailure('email_mismatch', (int) $invitation['id']);

                throw new GovernanceException('user_exists');
            }

            $passwordHash = (new PasswordHasher((string) Config::adminAuth()['pepper']))->hash($password);
        } else {
            $user = UserRepository::findById($sessionUserId);

            if ($user === null || $user['status'] !== 'active'
                || strtolower((string) $user['email']) !== strtolower($email)
            ) {
                $this->auditAcceptFailure('email_mismatch', (int) $invitation['id']);

                throw new GovernanceException('email_mismatch');
            }
        }

        $pdo = AdminDatabase::connection();
        $invitationId = (int) $invitation['id'];
        $organizationId = (int) $invitation['organization_id'];
        $roleCode = (string) $invitation['role_code'];

        try {
            $pdo->beginTransaction();

            InvitationRepository::lockForUpdate($pdo, $invitationId);
            $locked = InvitationRepository::findByTokenHash(Token::hash($token));

            if ($locked === null || $this->invitationBlockReason($locked) !== null) {
                throw new GovernanceException('invalid');
            }

            if ($newUser) {
                $userId = UserRepository::createInvited($email, $passwordHash, $fullName);
            } else {
                $userId = (int) $sessionUserId;
            }

            $membership = MembershipRepository::upsertWithin(
                $pdo,
                $userId,
                $organizationId,
                $roleCode,
                $userId
            );

            foreach (InvitationRepository::grants($invitationId) as $grant) {
                CatalogGrantRepository::setForMembership(
                    $userId,
                    $membership['id'],
                    $grant['catalog_code'],
                    $grant['operation'],
                    $grant['allowed'],
                    $userId
                );
            }

            InvitationRepository::markAccepted($invitationId, $userId);

            AuditLogger::record('invitation_accepted', [
                'actor_user_id' => $userId,
                'actor_email' => $email,
                'entity_type' => 'invitation',
                'entity_id' => (string) $invitationId,
                'after_state' => [
                    'user_id' => $userId,
                    'organization_id' => $organizationId,
                    'role_code' => $roleCode,
                ],
            ]);

            AuditLogger::record(
                $membership['action'] === 'reactivated' ? 'membership_reactivated' : 'membership_created',
                [
                    'actor_user_id' => $userId,
                    'actor_email' => $email,
                    'entity_type' => 'membership',
                    'entity_id' => (string) $membership['id'],
                    'after_state' => [
                        'user_id' => $userId,
                        'organization_id' => $organizationId,
                        'role_code' => $roleCode,
                    ],
                ]
            );

            $pdo->commit();
        } catch (PDOException | RepositoryException | GovernanceException $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }

            if ($exception instanceof GovernanceException) {
                throw $exception;
            }

            throw new RepositoryException('invitation_accept_failed');
        }

        return ['ok' => true, 'user_id' => $userId];
    }

    /** @param array<string, mixed> $input */
    public function assignMembership(int $organizationId, array $input, array $actor): int
    {
        $this->requirePermission($actor, 'admin.memberships.manage');

        $organization = OrganizationRepository::find($organizationId);

        if ($organization === null || !(bool) $organization['is_active']) {
            throw new GovernanceException('org_not_found');
        }

        $this->requireOrganizationScope($actor, $organizationId);

        $emailRaw = Validator::text($input['email'] ?? '', 254);
        $email = Validator::email($emailRaw);

        if ($emailRaw === '' || $email === '') {
            throw new GovernanceException('email');
        }

        $roleCode = Validator::text($input['role_code'] ?? '', 40);

        if (!array_key_exists($roleCode, Rbac::ROLE_PERMISSIONS)
            || !Rbac::canGrantRole($actor['permissions'], $actor['roles'], $roleCode)
        ) {
            throw new GovernanceException('role');
        }

        $user = UserRepository::findByEmail($email);

        if ($user === null) {
            throw new GovernanceException('not_found');
        }

        $userId = (int) $user['id'];
        $grants = $this->grantsFromInput($input);
        $actorId = $this->actorId($actor);
        $membership = MembershipRepository::upsert($userId, $organizationId, $roleCode, $actorId);

        foreach ($grants as $grant) {
            CatalogGrantRepository::setForMembership(
                $userId,
                $membership['id'],
                $grant['catalog_code'],
                $grant['operation'],
                $grant['allowed'],
                $actorId
            );
            AuditLogger::record('catalog_grant_created', $this->actorContext($actor) + [
                'entity_type' => 'catalog_grant',
                'entity_id' => (string) $membership['id'],
                'catalog_code' => $grant['catalog_code'],
                'after_state' => [
                    'operation' => $grant['operation'],
                    'allowed' => $grant['allowed'],
                ],
            ]);
        }

        AuditLogger::record(
            $membership['action'] === 'reactivated' ? 'membership_reactivated' : 'membership_created',
            $this->actorContext($actor) + [
                'entity_type' => 'membership',
                'entity_id' => (string) $membership['id'],
                'after_state' => [
                    'user_id' => $userId,
                    'organization_id' => $organizationId,
                    'role_code' => $roleCode,
                ],
            ]
        );

        return $membership['id'];
    }

    public function setMembershipStatus(
        int $membershipId,
        string $status,
        array $actor,
        string $reason = ''
    ): void {
        $this->requirePermission($actor, 'admin.memberships.manage');

        if (!in_array($status, ['active', 'suspended', 'revoked'], true)) {
            throw new GovernanceException('invalid');
        }

        $membership = MembershipRepository::findById($membershipId);

        if ($membership === null) {
            throw new GovernanceException('not_found');
        }

        if ($membership['organization_id'] === null) {
            if (!$this->hasGlobalScope($actor)) {
                throw new GovernanceException('permission');
            }
        } else {
            $this->requireOrganizationScope($actor, (int) $membership['organization_id']);
        }

        if ($status !== 'active' && $this->isLastSuperadmin($membership)) {
            throw new GovernanceException('last_superadmin');
        }

        $actorId = $this->actorId($actor);
        MembershipRepository::setStatus($membershipId, $status, $actorId, $reason);

        $revokedInvites = 0;

        if ($status !== 'active' && $membership['organization_id'] !== null) {
            $revokedInvites = InvitationRepository::revokePendingForEmail(
                (string) $membership['email'],
                (int) $membership['organization_id'],
                $actorId,
                'membership_' . $status
            );
        }

        $action = match ($status) {
            'active' => 'membership_reactivated',
            'suspended' => 'membership_suspended',
            'revoked' => 'membership_revoked',
        };

        AuditLogger::record($action, $this->actorContext($actor) + [
            'entity_type' => 'membership',
            'entity_id' => (string) $membershipId,
            'reason' => $reason !== '' ? mb_substr($reason, 0, 200) : null,
            'after_state' => [
                'status' => $status,
                'revoked_invitations' => $revokedInvites,
            ],
        ]);
    }

    /** @param array<string, mixed> $input */
    public function setGrant(int $membershipId, array $input, array $actor): void
    {
        $this->requirePermission($actor, 'admin.grants.manage');

        $membership = MembershipRepository::findById($membershipId);

        if ($membership === null) {
            throw new GovernanceException('not_found');
        }

        if ($membership['organization_id'] !== null) {
            $this->requireOrganizationScope($actor, (int) $membership['organization_id']);
        } elseif (!$this->hasGlobalScope($actor)) {
            throw new GovernanceException('permission');
        }

        $grants = $this->grantsFromInput($input);

        if ($grants === []) {
            throw new GovernanceException('grant_required');
        }

        $userId = (int) $membership['user_id'];
        $actorId = $this->actorId($actor);

        foreach ($grants as $grant) {
            CatalogGrantRepository::setForMembership(
                $userId,
                $membershipId,
                $grant['catalog_code'],
                $grant['operation'],
                $grant['allowed'],
                $actorId
            );

            AuditLogger::record('catalog_grant_updated', $this->actorContext($actor) + [
                'entity_type' => 'catalog_grant',
                'entity_id' => (string) $membershipId,
                'catalog_code' => $grant['catalog_code'],
                'after_state' => [
                    'operation' => $grant['operation'],
                    'allowed' => $grant['allowed'],
                ],
            ]);
        }
    }

    /** @param array<string, mixed> $actor */
    private function requirePermission(array $actor, string $permission): void
    {
        $permissions = is_array($actor['permissions'] ?? null) ? $actor['permissions'] : [];

        if (!Rbac::hasPermission($permissions, $permission)) {
            throw new GovernanceException('permission');
        }
    }

    /** @param array<string, mixed> $actor */
    private function hasGlobalScope(array $actor): bool
    {
        $roles = is_array($actor['roles'] ?? null) ? array_column($actor['roles'], 'code') : [];

        return in_array('superadmin', $roles, true)
            || in_array(Rbac::WILDCARD, $actor['permissions'] ?? [], true);
    }

    /** @param array<string, mixed> $actor */
    private function requireOrganizationScope(array $actor, int $organizationId): void
    {
        if ($this->hasGlobalScope($actor)) {
            return;
        }

        $userId = (int) ($actor['user']['id'] ?? 0);

        if ($userId === 0 || !MembershipRepository::hasActiveInOrganization($userId, $organizationId)) {
            throw new GovernanceException('permission');
        }
    }

    /** @param array<string, mixed> $membership */
    private function isLastSuperadmin(array $membership): bool
    {
        if ($membership['organization_id'] !== null || $membership['role_code'] !== 'superadmin') {
            return false;
        }

        if ($membership['status'] !== 'active') {
            return false;
        }

        return MembershipRepository::countActiveGlobalSuperadmins() <= 1;
    }

    /** @param array<string, mixed> $input */
    private function invitationTtl(array $input): int
    {
        $config = Config::adminAuth();
        $max = max(60, (int) $config['invite_max_ttl']);
        $default = max(60, (int) $config['invite_ttl']);
        $requested = $this->positiveInt($input['ttl'] ?? null) ?? $default;

        return min($max, $requested);
    }

    /** @param array<string, mixed> $input @return array<string, mixed> */
    private function organizationData(array $input): array
    {
        $code = strtolower(Validator::text($input['code'] ?? '', 40));

        if (!Rbac::isValidOrganizationCode($code)) {
            throw new GovernanceException('org_code');
        }

        $name = Validator::text($input['name'] ?? '', 180);

        if ($name === '') {
            throw new GovernanceException('org_name');
        }

        $type = Validator::choice($input['type'] ?? 'external', Rbac::ORGANIZATION_TYPES);

        if ($type === '') {
            throw new GovernanceException('org_type');
        }

        $country = strtoupper(Validator::text($input['country_code'] ?? 'AR', 2));

        if (preg_match('/^[A-Z]{2}$/', $country) !== 1) {
            throw new GovernanceException('org_country');
        }

        $contactRaw = Validator::text($input['contact_email'] ?? '', 254);
        $contact = $contactRaw === '' ? '' : Validator::email($contactRaw);

        if ($contactRaw !== '' && $contact === '') {
            throw new GovernanceException('email');
        }

        $website = Validator::text($input['website'] ?? '', 254);

        if ($website !== '' && filter_var($website, FILTER_VALIDATE_URL) === false) {
            throw new GovernanceException('invalid');
        }

        return [
            'code' => $code,
            'name' => $name,
            'legal_name' => Validator::text($input['legal_name'] ?? '', 240),
            'type' => $type,
            'country_code' => $country,
            'contact_email' => $contact,
            'website' => $website,
            'notes' => Validator::text($input['notes'] ?? '', 1000),
        ];
    }

    /**
     * Punto único de entrada de los grants: casillas del panel, texto legacy
     * (compatibilidad con formularios ya desplegados) o un grant suelto.
     *
     * @param array<string, mixed> $input
     * @return list<array{catalog_code: string, operation: string, allowed: bool}>
     */
    private function grantsFromInput(array $input): array
    {
        if (array_key_exists('grant_allow', $input) || array_key_exists('grant_deny', $input)) {
            return $this->grantsFromSelection($input);
        }

        if (array_key_exists('grants', $input)) {
            return $this->grantsFromText((string) $input['grants']);
        }

        // Compatibilidad con el formulario anterior de un solo grant.
        if (array_key_exists('catalog_code', $input)) {
            $single = Validator::text($input['catalog_code'] ?? '', 50)
                . '|' . Validator::text($input['operation'] ?? '', 40);
            $decision = (string) ($input['allowed'] ?? 'allow');

            return $this->grantsFromSelection([
                'grant_allow' => $decision === 'deny' ? [] : [$single],
                'grant_deny' => $decision === 'deny' ? [$single] : [],
            ]);
        }

        return [];
    }

    /**
     * Casillas `grant_allow[]` y `grant_deny[]`, con valor "catalogo|operacion".
     * Si una misma opción aparece en ambas, gana la denegación.
     *
     * @param array<string, mixed> $input
     * @return list<array{catalog_code: string, operation: string, allowed: bool}>
     */
    private function grantsFromSelection(array $input): array
    {
        $grants = [];
        $seen = [];

        foreach (['deny' => false, 'allow' => true] as $field => $allowed) {
            $values = $input['grant_' . $field] ?? [];

            if (!is_array($values)) {
                throw new GovernanceException('grants');
            }

            foreach ($values as $value) {
                if (!is_string($value)) {
                    throw new GovernanceException('grants');
                }

                $parts = explode('|', $value);

                if (count($parts) !== 2) {
                    throw new GovernanceException('grants');
                }

                $key = strtolower(trim($parts[0])) . '|' . strtolower(trim($parts[1]));

                if (isset($seen[$key])) {
                    continue;
                }

                $seen[$key] = true;
                $grants[] = $this->makeGrant($parts[0], $parts[1], $allowed);
            }
        }

        return $grants;
    }

    /** @return list<array{catalog_code: string, operation: string, allowed: bool}> */
    private function grantsFromText(string $text): array
    {
        $grants = [];
        $seen = [];

        foreach (preg_split('/\R/u', $text) ?: [] as $line) {
            $line = trim($line);

            if ($line === '') {
                continue;
            }

            $parts = array_map('trim', explode(':', $line));

            if (count($parts) < 2 || count($parts) > 3) {
                throw new GovernanceException('grants');
            }

            $key = strtolower($parts[0]) . '|' . strtolower($parts[1]);

            if (isset($seen[$key])) {
                continue;
            }

            $seen[$key] = true;
            $allowed = !isset($parts[2]) || strtolower($parts[2]) !== 'deny';
            $grants[] = $this->makeGrant($parts[0], $parts[1], $allowed);
        }

        return $grants;
    }

    /** @return array{catalog_code: string, operation: string, allowed: bool} */
    private function makeGrant(string $catalog, string $operation, bool $allowed): array
    {
        $catalog = strtolower(trim($catalog));
        $operation = strtolower(trim($operation));

        if ($catalog === '' || !Rbac::isValidOperation($operation)
            || !CatalogReferenceRepository::exists($catalog)
        ) {
            throw new GovernanceException('catalog');
        }

        return [
            'catalog_code' => $catalog,
            'operation' => $operation,
            'allowed' => $allowed,
        ];
    }

    /** @param array<string, mixed> $invitation */
    private function invitationBlockReason(array $invitation): ?string
    {
        if ($invitation['accepted_at'] !== null) {
            return 'accepted';
        }

        if ($invitation['revoked_at'] !== null) {
            return 'revoked';
        }

        if (!(bool) $invitation['organization_active']) {
            return 'org_not_found';
        }

        $expires = new \DateTimeImmutable((string) $invitation['expires_at']);

        if ($expires <= new \DateTimeImmutable('now', new \DateTimeZone('UTC'))) {
            return 'expired';
        }

        return null;
    }

    private function auditAcceptFailure(string $reason, ?int $invitationId = null): void
    {
        try {
            AuditLogger::record('invitation_accept_failed', [
                'entity_type' => 'invitation',
                'entity_id' => $invitationId === null ? null : (string) $invitationId,
                'reason' => $reason,
            ]);
        } catch (RepositoryException) {
            // La negación prevalece aunque la auditoría no esté disponible.
        }
    }

    private function sendInvitationMail(
        string $email,
        string $organizationName,
        string $token,
        int $invitationId,
        array $actor,
        ?string $message = null
    ): void {
        $link = Config::adminBaseUrl() . '/admin/invite?token=' . rawurlencode($token);
        $text = "Fue invitado/a a colaborar en “" . $organizationName . "” en Origen Salud.\n\n";

        if ($message !== null && $message !== '') {
            $text .= "Mensaje: " . $message . "\n\n";
        }

        $text .= 'Acepte la invitación en: ' . $link . "\n\n"
            . "El vínculo es de un solo uso. Si no esperaba este correo, ignórelo.\n";

        $mail = SmtpMailer::send($email, 'Origen Salud - invitación de colaborador', $text, nl2br(e($text), false));

        if (!$mail['ok']) {
            AuditLogger::record('invitation_mail_failed', $this->actorContext($actor) + [
                'entity_type' => 'invitation',
                'entity_id' => (string) $invitationId,
                'reason' => (string) ($mail['error'] ?? 'mail_failed'),
            ]);
        }
    }

    /** @param array<string, mixed> $actor @return array<string, mixed> */
    private function actorContext(array $actor): array
    {
        return [
            'actor_user_id' => (int) ($actor['user']['id'] ?? 0),
            'actor_email' => (string) ($actor['user']['email'] ?? ''),
        ];
    }

    /** @param array<string, mixed> $actor */
    private function actorId(array $actor): int
    {
        return (int) ($actor['user']['id'] ?? 0);
    }

    /** @param array<string, mixed> $input */
    private function flag(array $input, string $key): bool
    {
        $value = $input[$key] ?? null;

        return $value === '1' || $value === 1 || $value === true || $value === 'on';
    }

    private function positiveInt(mixed $value): ?int
    {
        if (is_int($value) && $value > 0) {
            return $value;
        }

        if (is_string($value) && ctype_digit(trim($value)) && (int) $value > 0) {
            return (int) $value;
        }

        return null;
    }

    private function nullableText(mixed $value, int $max): ?string
    {
        $text = Validator::text($value, $max);

        return $text === '' ? null : $text;
    }
}
