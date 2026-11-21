<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Admin;

use OrigenSalud\Portal\Repositories\CatalogGovernanceRepository;
use OrigenSalud\Portal\Repositories\CatalogReferenceRepository;
use OrigenSalud\Portal\Repositories\UvrRepository;

/**
 * Gestión operativa de valoración UVR.
 *
 * Reutiliza los 14 permisos existentes y la cadena de gestión pública. No
 * crea catálogos values, no carga valores y no expone rutas de API. Toda
 * aprobación pasa por Rbac::canApprove() en la capa de servicio (Acta U0).
 */
final class UvrGovernanceService
{
    /** Catálogo único del esquema U0–U6; no se usa cuando U7-B está aplicado. */
    private const LEGACY_CATALOG_CODE = 'dentar-pr';
    private const COMPONENT_TYPES = ['work', 'practice_expense', 'professional_liability'];

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function valuations(array $actor): array
    {
        $visible = $this->requireAnyCatalog($actor, 'view', 'catalog.view');
        $rows = in_array(self::LEGACY_CATALOG_CODE, $visible, true)
            ? UvrRepository::valuations()
            : [];

        foreach (UvrRepository::prestacionValuations() as $row) {
            $codes = UvrRepository::catalogCodesForPrestacionValuation(
                (int) ($row['valuation_id'] ?? 0)
            );

            if (!$this->anyVisible($codes, $visible)) {
                continue;
            }

            $rows[] = [
                'valuation_id' => (int) ($row['valuation_id'] ?? 0),
                'valuation_kind' => 'prestacion',
                'service_item_id' => (string) ($row['prestacion_code'] ?? ''),
                'prestacion_name' => (string) ($row['prestacion_name'] ?? ''),
                'profile_code' => (string) ($row['profile_code'] ?? ''),
                'scope' => (string) ($row['scope'] ?? ''),
                'jurisdiction' => (string) ($row['jurisdiction'] ?? ''),
                'methodology' => (string) ($row['methodology'] ?? ''),
                'source_reference' => (string) ($row['source_reference'] ?? ''),
                'version_tag' => (string) ($row['version_tag'] ?? ''),
                'review_status' => (string) ($row['review_status'] ?? ''),
                'published_at' => (string) ($row['published_at'] ?? ''),
                'work_uvr' => (float) ($row['work_uvr'] ?? 0),
                'practice_expense_uvr' => (float) ($row['practice_expense_uvr'] ?? 0),
                'professional_liability_uvr' => (float) ($row['professional_liability_uvr'] ?? 0),
                'total_uvr' => (float) ($row['total_uvr'] ?? 0),
            ];
        }

        foreach ($rows as $index => $row) {
            if (!isset($row['valuation_kind'])) {
                $rows[$index]['valuation_kind'] = 'legacy';
            }
        }

        return $this->withSubjectCodes($rows, 'valuation_id');
    }

    /**
     * Valoraciones con importe referencial derivado.
     *
     * Se usa la conversión aprobada más reciente; si no existe, el importe es
     * null y la vista lo indica como «sin conversión aprobada».
     *
     * @param array<string, mixed> $actor @return list<array<string, mixed>>
     */
    public function valuationsWithImporte(array $actor): array
    {
        $rows = $this->valuations($actor);
        $approved = null;

        foreach (UvrRepository::conversions() as $conversion) {
            if (in_array((string) ($conversion['review_status'] ?? ''), ['approved', 'published'], true)) {
                if ($approved === null
                    || (int) ($conversion['id'] ?? 0) > (int) ($approved['id'] ?? 0)
                ) {
                    $approved = $conversion;
                }
            }
        }

        foreach ($rows as $index => $row) {
            $rows[$index]['importe'] = UvrImporteService::calcular($row, $approved);
        }

        return $rows;
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function proposals(array $actor): array
    {
        $visible = $this->requireAnyCatalog($actor, 'view', 'catalog.view');
        $proposals = [];

        foreach (UvrRepository::proposals() as $proposal) {
            if (in_array($this->proposalCatalog($proposal), $visible, true)) {
                $proposals[] = $proposal;
            }
        }

        return $this->withSubjectCodes($proposals);
    }

    /** @param array<string, mixed> $actor @return array<string, mixed> */
    public function proposalDetail(int $id, array $actor): array
    {
        $proposal = UvrRepository::findProposal($id);

        if ($proposal === null) {
            throw new UvrGovernanceException('uvr_proposal_not_found');
        }

        $proposal = $this->withSubjectCodes([$proposal])[0] ?? $proposal;

        $this->require($actor, 'catalog.view', 'view', $this->proposalCatalog($proposal));

        $reviews = UvrRepository::reviews($id);
        $decisions = [];

        foreach ($reviews as $review) {
            $decision = UvrRepository::decisionForReview((int) $review['id']);

            if ($decision !== null) {
                $decisions[(int) $review['id']] = $decision;
            }
        }

        return ['proposal' => $proposal, 'reviews' => $reviews, 'decisions' => $decisions];
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function tasks(array $actor): array
    {
        $visible = $this->requireAnyCatalog($actor, 'review', 'catalog.review');
        $tasks = [];

        foreach (UvrRepository::tasks() as $task) {
            $meta = $this->decodeMeta((string) ($task['proposed_change'] ?? ''));
            $code = (string) ($meta['catalog_code'] ?? self::LEGACY_CATALOG_CODE);

            if (in_array($code, $visible, true)) {
                $tasks[] = $task;
            }
        }

        return $this->withSubjectCodes($tasks);
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function editableCatalogs(array $actor): array
    {
        $visible = $this->requireAnyCatalog($actor, 'edit_draft', 'catalog.edit_draft');
        $catalogs = [];

        foreach (CatalogReferenceRepository::all() as $catalog) {
            if (in_array((string) ($catalog['code'] ?? ''), $visible, true)) {
                $catalogs[] = $catalog;
            }
        }

        return $catalogs;
    }

    /**
     * El modo transversal solo se activa cuando U7-B está aplicado **y** ya
     * existen prestaciones y perfiles gobernados. Mientras las tablas nuevas
     * estén vacías, el panel sigue operando con el flujo U0–U6 para no dejar
     * de proponer UVR sobre códigos ya publicados.
     */
    public function transversal(): bool
    {
        return UvrRepository::hasTransversalSchema()
            && UvrRepository::prestaciones() !== []
            && UvrRepository::profiles() !== [];
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function prestaciones(array $actor): array
    {
        $this->requirePermission($actor, 'catalog.view');

        return UvrRepository::prestaciones();
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function profiles(array $actor): array
    {
        $this->requirePermission($actor, 'catalog.view');

        return UvrRepository::profiles();
    }

    /**
     * @param array<string, mixed> $actor @return list<array<string, mixed>>
     */
    public function linkedPrestaciones(int $itemId, string $catalogCode, array $actor): array
    {
        $this->require($actor, 'catalog.view', 'view', $catalogCode);

        return UvrRepository::linkedPrestaciones($itemId, $catalogCode);
    }

    /** @param array<string, mixed> $actor @return array<int, string> */
    public function profileComponents(int $profileId, array $actor): array
    {
        $this->requirePermission($actor, 'catalog.view');

        return UvrRepository::profileComponents($profileId);
    }

    /**
     * Catálogos desde los que se puede proponer UVR. Con U7-B aplicado la
     * elegibilidad es por prestación y se respetan los grants por catálogo;
     * sin U7-B rige el catálogo único de U0–U6.
     *
     * @param array<string, mixed> $actor @return list<array<string, mixed>>
     */
    public function proposalCatalogs(array $actor): array
    {
        $this->requirePermission($actor, 'catalog.view');

        $catalogs = [];

        foreach (CatalogReferenceRepository::uvrCatalogs() as $catalog) {
            $code = (string) ($catalog['code'] ?? '');

            if ($this->canAccess($actor, $code, 'view')) {
                $catalogs[] = $catalog;
            }
        }

        // Fallback legacy: si el catálogo histórico aún existe y el actor tiene
        // acceso, se mantiene visible aunque el dato de product_role cambie.
        if ($catalogs === []
            && CatalogReferenceRepository::exists(self::LEGACY_CATALOG_CODE)
            && $this->canAccess($actor, self::LEGACY_CATALOG_CODE, 'view')
        ) {
            foreach (CatalogReferenceRepository::all() as $catalog) {
                if ($catalog['code'] === self::LEGACY_CATALOG_CODE) {
                    return [$catalog];
                }
            }
        }

        return $catalogs;
    }

    private function isUvrCatalog(string $code): bool
    {
        if ($code === self::LEGACY_CATALOG_CODE) {
            return true;
        }

        foreach (CatalogReferenceRepository::uvrCatalogs() as $catalog) {
            if ($catalog['code'] === $code) {
                return true;
            }
        }

        return false;
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function conversions(array $actor): array
    {
        $this->requirePermission($actor, 'catalog.view');

        return UvrRepository::conversions();
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function geoIndexes(array $actor): array
    {
        $this->requirePermission($actor, 'catalog.view');

        return UvrRepository::geoIndexes();
    }

    /** @param array<string, mixed> $input @param array<string, mixed> $actor */
    public function propose(array $input, array $actor): int
    {
        $catalogCode = $this->inputCatalog($input);
        $this->require($actor, 'catalog.propose', 'propose', $catalogCode);

        if ($catalogCode === '' || !CatalogReferenceRepository::exists($catalogCode)) {
            throw new UvrGovernanceException('uvr_catalog_unavailable');
        }

        $serviceItemId = $this->positiveInt($input['service_item_id'] ?? null);
        $versionTag = $this->text($input['version_tag'] ?? null, 50);
        $source = $this->text($input['source_reference'] ?? null, 2000);
        $evaluatedAt = $this->date($input['evaluated_at'] ?? null);

        if ($serviceItemId === null || $versionTag === '' || $source === '' || $evaluatedAt === '') {
            throw new UvrGovernanceException('uvr_invalid_valuation');
        }

        // El código debe pertenecer al catálogo enviado. El trigger de base
        // también lo comprueba, pero aquí el error es comprensible en el panel.
        if (CatalogGovernanceRepository::item($catalogCode, $serviceItemId) === null) {
            throw new UvrGovernanceException('catalog_item_not_found');
        }

        $transversal = $this->transversal();
        $prestacionId = $this->positiveInt($input['prestacion_id'] ?? null);
        $profileId = $this->positiveInt($input['profile_id'] ?? null);
        $methodology = $this->text($input['methodology'] ?? null, 120);
        $allowedTypes = self::COMPONENT_TYPES;
        $changeExtras = ['valuation_kind' => $transversal ? 'prestacion' : 'legacy'];

        if ($transversal) {
            $linked = [];

            foreach (UvrRepository::linkedPrestaciones($serviceItemId, $catalogCode) as $row) {
                $linked[(int) $row['id']] = $row;
            }

            if ($prestacionId === null || !isset($linked[$prestacionId])) {
                throw new UvrGovernanceException('uvr_prestacion_link_required');
            }

            $profiles = [];

            foreach (UvrRepository::profiles() as $row) {
                $profiles[(int) $row['id']] = $row;
            }

            if ($profileId === null || !isset($profiles[$profileId])) {
                throw new UvrGovernanceException('uvr_profile_not_found');
            }

            $methodology = $this->text($profiles[$profileId]['methodology'] ?? null, 120);
            $applicable = [];

            foreach (UvrRepository::profileComponents($profileId) as $type => $state) {
                if ($state === 'applicable') {
                    $applicable[] = (string) $type;
                }
            }

            if ($applicable === []) {
                throw new UvrGovernanceException('uvr_profile_components_required');
            }

            $allowedTypes = array_values(array_intersect(self::COMPONENT_TYPES, $applicable));
            $changeExtras += [
                'prestacion_id' => $prestacionId,
                'prestacion_code' => (string) ($linked[$prestacionId]['code'] ?? ''),
                'profile_id' => $profileId,
                'profile_code' => (string) ($profiles[$profileId]['code'] ?? ''),
                'methodology' => $methodology,
            ];
        } else {
            if ($methodology === '' || !$this->isUvrCatalog($catalogCode)) {
                throw new UvrGovernanceException('uvr_catalog_unavailable');
            }
        }

        $normalized = $this->normalizeComponents($input['components'] ?? null, $allowedTypes);
        $actorId = $this->actorId($actor);
        $actorEmail = $this->actorEmail($actor);
        $validFrom = $this->date($input['valid_from'] ?? null) ?: null;
        $validTo = $this->date($input['valid_to'] ?? null) ?: null;

        UvrRepository::beginWrite();

        try {
            if ($transversal) {
                $valuationId = UvrRepository::createPrestacionValuation([
                    'prestacion_id' => (int) $changeExtras['prestacion_id'],
                    'profile_id' => (int) $changeExtras['profile_id'],
                    'version_tag' => $versionTag,
                    'source_reference' => $source,
                    'evaluated_at' => $evaluatedAt,
                    'valid_from' => $validFrom,
                    'valid_to' => $validTo,
                ], $actorId);

                foreach ($normalized as $component) {
                    UvrRepository::addPrestacionComponent(
                        $valuationId,
                        $component + ['source_reference' => $source]
                    );
                }
            } else {
                $valuationId = UvrRepository::createValuation([
                    'service_item_id' => $serviceItemId,
                    'release_id' => $this->positiveInt($input['release_id'] ?? null),
                    'version_tag' => $versionTag,
                    'methodology' => $methodology,
                    'source_reference' => $source,
                    'evaluated_at' => $evaluatedAt,
                    'valid_from' => $validFrom,
                    'valid_to' => $validTo,
                ], $actorId, $actorEmail);

                foreach ($normalized as $component) {
                    UvrRepository::addComponent($valuationId, $component);
                }
            }

            $proposedChange = json_encode($changeExtras + [
                'catalog_code' => $catalogCode,
                'version_tag' => $versionTag,
                'components' => $normalized,
            ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

            $proposalId = UvrRepository::createProposal(
                is_string($proposedChange) ? $proposedChange : '{}',
                $source,
                $actorId,
                $actorEmail,
                $valuationId
            );

            $this->audit('uvr_valuation_proposed', $actor, [
                'entity_type' => 'uvr_valuation',
                'entity_id' => (string) $valuationId,
                'catalog_code' => $catalogCode,
                'after_state' => ['proposal_id' => $proposalId, 'version_tag' => $versionTag],
            ]);

            UvrRepository::commitWrite();
        } catch (\Throwable $exception) {
            UvrRepository::rollBackWrite();

            throw $exception;
        }

        return $proposalId;
    }

    /** @param array<string, mixed> $input @param array<string, mixed> $actor */
    public function recordReview(int $proposalId, array $input, array $actor): int
    {
        $proposal = UvrRepository::findProposal($proposalId);

        if ($proposal === null) {
            throw new UvrGovernanceException('uvr_proposal_not_found');
        }

        $this->require($actor, 'catalog.review', 'review', $this->proposalCatalog($proposal));
        $role = (string) ($input['review_role'] ?? '');

        if (!in_array($role, ['clinical', 'economic'], true)) {
            throw new UvrGovernanceException('uvr_invalid_review_role');
        }

        $rationale = $this->text($input['rationale'] ?? null, 2000);
        $outcome = (string) ($input['outcome'] ?? 'unreviewed');

        if (!in_array($outcome, ['unreviewed', 'reviewed', 'approved'], true) || $rationale === '') {
            throw new UvrGovernanceException('uvr_invalid_review');
        }

        $actorId = $this->actorId($actor);

        foreach (UvrRepository::reviews($proposalId) as $existing) {
            if ((int) ($existing['reviewer_user_id'] ?? 0) === $actorId) {
                throw new UvrGovernanceException('uvr_review_actor_reused');
            }

            if ((string) ($existing['reviewer_role'] ?? '') === $role) {
                throw new UvrGovernanceException('uvr_duplicate_review_role');
            }
        }

        $reviewId = UvrRepository::recordReview(
            $proposalId,
            $role,
            $outcome,
            $rationale,
            $actorId,
            $this->actorEmail($actor)
        );

        if ($outcome === 'approved' && $this->hasBothApprovedReviews($proposalId)) {
            UvrRepository::setProposalStatus($proposalId, 'reviewed');
        }

        $this->audit($role === 'clinical' ? 'uvr_review_clinical_recorded' : 'uvr_review_economic_recorded', $actor, [
            'entity_type' => 'uvr_governance_request',
            'entity_id' => (string) $proposalId,
            'catalog_code' => $this->proposalCatalog($proposal),
            'after_state' => ['review_id' => $reviewId, 'role' => $role, 'outcome' => $outcome],
        ]);

        return $reviewId;
    }

    /** @param array<string, mixed> $input @param array<string, mixed> $actor */
    public function decide(int $proposalId, array $input, array $actor): int
    {
        $proposal = UvrRepository::findProposal($proposalId);

        if ($proposal === null) {
            throw new UvrGovernanceException('uvr_proposal_not_found');
        }

        $this->require($actor, 'catalog.approve', 'approve', $this->proposalCatalog($proposal));
        $evidence = $this->text($input['evidence_reference'] ?? null, 2000);

        if ($evidence === '') {
            throw new UvrGovernanceException('uvr_evidence_required');
        }

        if (!Rbac::canApprove(
            (string) ($proposal['requested_by_user_id'] ?? ''),
            (string) $this->actorId($actor),
            $this->permissions($actor)
        )) {
            throw new UvrGovernanceException('uvr_self_approval_denied');
        }

        $reviews = UvrRepository::reviews($proposalId);

        if (!$this->hasBothApprovedReviews($proposalId)) {
            throw new UvrGovernanceException('uvr_reviews_incomplete');
        }

        $actorId = $this->actorId($actor);
        $decisionId = 0;

        foreach ($reviews as $review) {
            if ((string) ($review['outcome'] ?? '') !== 'approved') {
                continue;
            }

            $decisionId = UvrRepository::recordDecision(
                (int) $review['id'],
                $actorId,
                $this->actorEmail($actor),
                $evidence
            );
        }

        $valuationId = (int) ($proposal['subject_id'] ?? 0);

        if ($valuationId > 0) {
            if ((string) ($this->proposalMeta($proposal)['valuation_kind'] ?? '') === 'prestacion') {
                UvrRepository::linkPrestacionApproval($valuationId, $actorId);
            } else {
                UvrRepository::linkApproval($valuationId, $actorId);
            }
        }

        UvrRepository::setProposalStatus($proposalId, 'approved');

        $this->audit('uvr_decision_recorded', $actor, [
            'entity_type' => 'uvr_governance_request',
            'entity_id' => (string) $proposalId,
            'catalog_code' => $this->proposalCatalog($proposal),
            'after_state' => ['decision_id' => $decisionId, 'evidence_reference' => $evidence],
        ]);

        return $decisionId;
    }

    /** @param array<string, mixed> $actor */
    public function publish(int $valuationId, array $actor): void
    {
        $this->requirePermission($actor, 'catalog.publish');
        $prestacion = UvrRepository::findPrestacionValuation($valuationId);
        $catalogCodes = $prestacion === null
            ? [self::LEGACY_CATALOG_CODE]
            : UvrRepository::catalogCodesForPrestacionValuation($valuationId);

        if (!$this->canAccessAny($actor, $catalogCodes, 'publish')) {
            throw new UvrGovernanceException('uvr_grant_denied');
        }

        if ($prestacion === null) {
            UvrRepository::publish($valuationId, $this->actorId($actor));
        } else {
            UvrRepository::publishPrestacion($valuationId, $this->actorId($actor));
        }

        $this->audit('uvr_published', $actor, [
            'entity_type' => 'uvr_valuation',
            'entity_id' => (string) $valuationId,
            'catalog_code' => (string) ($catalogCodes[0] ?? self::LEGACY_CATALOG_CODE),
        ]);
    }

    /** @param array<string, mixed> $actor @return array<string, mixed>|null */
    public function importe(int $valuationId, ?int $conversionId, array $actor): ?array
    {
        $visible = $this->requireAnyCatalog($actor, 'view', 'catalog.view');
        $legacy = UvrRepository::findValuation($valuationId);
        $prestacion = $legacy === null
            ? UvrRepository::findPrestacionValuation($valuationId)
            : null;
        $valuation = $legacy ?? $prestacion;

        if ($valuation === null) {
            throw new UvrGovernanceException('uvr_valuation_not_found');
        }

        $codes = $prestacion === null
            ? [self::LEGACY_CATALOG_CODE]
            : UvrRepository::catalogCodesForPrestacionValuation($valuationId);

        if (!$this->anyVisible($codes, $visible)) {
            throw new UvrGovernanceException('uvr_grant_denied');
        }

        if ($conversionId === null) {
            return null;
        }

        foreach (UvrRepository::conversions() as $conversion) {
            if ((int) $conversion['id'] === $conversionId) {
                return UvrImporteService::calcular($valuation, $conversion);
            }
        }

        return null;
    }

    private function hasBothApprovedReviews(int $proposalId): bool
    {
        $roles = [];

        foreach (UvrRepository::reviews($proposalId) as $review) {
            if ((string) ($review['outcome'] ?? '') === 'approved') {
                $roles[(string) ($review['reviewer_role'] ?? '')] = true;
            }
        }

        return isset($roles['clinical'], $roles['economic']);
    }

    /** @param array<string, mixed> $actor */
    private function require(
        array $actor,
        string $permission,
        string $operation,
        ?string $catalogCode = null
    ): void {
        $this->requirePermission($actor, $permission);

        if (!$this->canAccess(
            $actor,
            $catalogCode !== null && $catalogCode !== '' ? $catalogCode : self::LEGACY_CATALOG_CODE,
            $operation
        )) {
            throw new UvrGovernanceException('uvr_grant_denied');
        }
    }

    /** @param array<string, mixed> $actor */
    private function requirePermission(array $actor, string $permission): void
    {
        if (!Rbac::hasPermission($this->permissions($actor), $permission)) {
            throw new UvrGovernanceException('uvr_permission_denied');
        }
    }

    /** @param array<string, mixed> $actor */
    private function canAccess(array $actor, string $catalogCode, string $operation): bool
    {
        $grants = is_array($actor['grants'] ?? null) ? $actor['grants'] : [];

        return Rbac::canAccessCatalog($grants, $catalogCode, $operation, $this->permissions($actor));
    }

    /**
     * @param list<string> $catalogCodes
     * @param array<string, mixed> $actor
     */
    private function canAccessAny(array $actor, array $catalogCodes, string $operation): bool
    {
        if (in_array(Rbac::WILDCARD, $this->permissions($actor), true)) {
            return true;
        }

        foreach ($catalogCodes as $catalogCode) {
            if ($this->canAccess($actor, $catalogCode, $operation)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Catálogos visibles para la operación. Sin U7-B rige solo el legado; con
     * U7-B se respetan los grants por catálogo sin crear permisos nuevos.
     *
     * @param array<string, mixed> $actor @return list<string>
     */
    private function visibleCatalogCodes(array $actor, string $operation): array
    {
        if (!UvrRepository::hasTransversalSchema()) {
            return $this->canAccess($actor, self::LEGACY_CATALOG_CODE, $operation)
                ? [self::LEGACY_CATALOG_CODE]
                : [];
        }

        $codes = [];

        foreach (CatalogReferenceRepository::all() as $catalog) {
            $code = (string) ($catalog['code'] ?? '');

            if ($code !== '' && $this->canAccess($actor, $code, $operation)) {
                $codes[] = $code;
            }
        }

        return $codes;
    }

    /**
     * @param array<string, mixed> $actor @return list<string>
     */
    private function requireAnyCatalog(array $actor, string $operation, string $permission): array
    {
        $this->requirePermission($actor, $permission);
        $codes = $this->visibleCatalogCodes($actor, $operation);

        if ($codes === []) {
            throw new UvrGovernanceException('uvr_grant_denied');
        }

        return $codes;
    }

    /**
     * @param list<string> $codes
     * @param list<string> $visible
     */
    private function anyVisible(array $codes, array $visible): bool
    {
        foreach ($codes as $code) {
            if (in_array($code, $visible, true)) {
                return true;
            }
        }

        return false;
    }

    /** @param array<string, mixed> $input */
    private function inputCatalog(array $input): string
    {
        $code = $input['catalog'] ?? '';

        return is_string($code) && preg_match('/^[a-z0-9][a-z0-9-]{1,49}$/', $code) === 1
            ? $code
            : self::LEGACY_CATALOG_CODE;
    }

    /** @return array<string, mixed> */
    private function decodeMeta(string $raw): array
    {
        $decoded = json_decode($raw, true);

        return is_array($decoded) ? $decoded : [];
    }

    /**
     * Expone el código visible del asunto (DNT-PR-000001) además del id interno.
     * Reutiliza la vista gobernada para resolver el ítem y la conexión pública
     * para leer su permanent_code: sin nuevos privilegios sobre os_catalog_*.
     *
     * @param list<array<string, mixed>> $rows
     * @return list<array<string, mixed>>
     */
    private function withSubjectCodes(array $rows, string $idField = 'subject_id'): array
    {
        $subjectIds = [];

        foreach ($rows as $row) {
            $id = (int) ($row[$idField] ?? 0);

            if ($id > 0) {
                $subjectIds[$id] = $id;
            }
        }

        if ($subjectIds === []) {
            return $rows;
        }

        $itemsByValuation = [];
        $itemIds = [];

        foreach (UvrRepository::valuations() as $valuation) {
            $id = (int) ($valuation['valuation_id'] ?? 0);

            if (!isset($subjectIds[$id])) {
                continue;
            }

            $itemId = (int) ($valuation['service_item_id'] ?? 0);
            $itemsByValuation[$id] = $itemId;

            if ($itemId > 0) {
                $itemIds[$itemId] = $itemId;
            }
        }

        $codes = CatalogGovernanceRepository::permanentCodes(array_values($itemIds));

        foreach ($rows as $index => $row) {
            $id = (int) ($row[$idField] ?? 0);
            $itemId = $itemsByValuation[$id] ?? 0;
            $code = $itemId > 0 ? (string) ($codes[$itemId] ?? '') : '';

            if ($code === '' && (string) ($row['valuation_kind'] ?? '') === 'prestacion') {
                $code = (string) ($row['service_item_id'] ?? '');
            }

            if ($code === '') {
                $meta = $this->decodeMeta((string) ($row['proposed_change'] ?? ''));
                $code = (string) ($meta['prestacion_code'] ?? '');
            }

            if ($code !== '') {
                $rows[$index]['subject_code'] = $code;
            }
        }

        return $rows;
    }

    /** @param array<string, mixed> $proposal @return array<string, mixed> */
    private function proposalMeta(array $proposal): array
    {
        return $this->decodeMeta((string) ($proposal['proposed_change'] ?? ''));
    }

    /** @param array<string, mixed> $proposal */
    private function proposalCatalog(array $proposal): string
    {
        $code = (string) ($this->proposalMeta($proposal)['catalog_code'] ?? '');

        return $code !== '' ? $code : self::LEGACY_CATALOG_CODE;
    }

    /**
     * @param mixed $raw
     * @param list<string> $allowedTypes
     *
     * @return list<array<string, mixed>>
     */
    private function normalizeComponents(mixed $raw, array $allowedTypes): array
    {
        if (!is_array($raw)) {
            throw new UvrGovernanceException('uvr_components_required');
        }

        $normalized = [];

        foreach ($raw as $component) {
            if (!is_array($component)) {
                throw new UvrGovernanceException('uvr_invalid_component');
            }

            $type = (string) ($component['component_type'] ?? '');

            if (!in_array($type, self::COMPONENT_TYPES, true) || !in_array($type, $allowedTypes, true)) {
                continue;
            }

            $notApplicable = $this->flag($component, 'is_not_applicable');
            $amount = UvrImporteService::decimal($component['value'] ?? null);

            if ($amount === null) {
                throw new UvrGovernanceException('uvr_invalid_component');
            }

            $evidence = $this->text($component['negative_adjustment_evidence'] ?? null, 2000);

            if ($notApplicable && abs($amount) > 0.00001) {
                throw new UvrGovernanceException('uvr_na_requires_zero');
            }

            if ($amount < 0 && $evidence === '') {
                throw new UvrGovernanceException('uvr_negative_requires_evidence');
            }

            if ($amount >= 0 && $evidence !== '') {
                throw new UvrGovernanceException('uvr_evidence_requires_negative');
            }

            $normalized[] = [
                'component_type' => $type,
                'value' => $amount,
                'is_not_applicable' => $notApplicable,
                'negative_adjustment_evidence' => $evidence !== '' ? $evidence : null,
                'calculation_note' => $this->text($component['calculation_note'] ?? null, 2000) ?: null,
            ];
        }

        if ($normalized === []) {
            throw new UvrGovernanceException('uvr_components_required');
        }

        return $normalized;
    }

    /** @param array<string, mixed> $actor @return list<string> */
    private function permissions(array $actor): array
    {
        $permissions = $actor['permissions'] ?? [];

        return is_array($permissions) ? array_values(array_map('strval', $permissions)) : [];
    }

    /** @param array<string, mixed> $actor */
    private function actorId(array $actor): int
    {
        return (int) ($actor['user']['id'] ?? 0);
    }

    /** @param array<string, mixed> $actor */
    private function actorEmail(array $actor): string
    {
        return (string) ($actor['user']['email'] ?? '');
    }

    /** @param array<string, mixed> $context */
    private function audit(string $action, array $actor, array $context): void
    {
        AuditLogger::record($action, $context + [
            'actor_user_id' => $this->actorId($actor),
            'actor_email' => $this->actorEmail($actor),
        ]);
    }

    private function text(mixed $value, int $max): string
    {
        if (!is_string($value)) {
            return '';
        }

        return substr(trim($value), 0, $max);
    }

    private function date(mixed $value): string
    {
        if (!is_string($value) || preg_match('/^\d{4}-\d{2}-\d{2}$/', $value) !== 1) {
            return '';
        }

        return $value;
    }

    private function positiveInt(mixed $value): ?int
    {
        if (!is_int($value) && !is_string($value)) {
            return null;
        }

        $number = (int) $value;

        return $number > 0 ? $number : null;
    }

    /** @param array<string, mixed> $input */
    private function flag(array $input, string $key): bool
    {
        $value = $input[$key] ?? null;

        return $value === true || $value === 1 || $value === '1' || $value === 'on';
    }
}
