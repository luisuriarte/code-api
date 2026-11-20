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
    private const CATALOG_CODE = 'dentar-pr';
    private const COMPONENT_TYPES = ['work', 'practice_expense', 'professional_liability'];

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function valuations(array $actor): array
    {
        $this->require($actor, 'catalog.view', 'view');

        return UvrRepository::valuations();
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
        $this->require($actor, 'catalog.view', 'view');

        return UvrRepository::proposals();
    }

    /** @param array<string, mixed> $actor @return array<string, mixed> */
    public function proposalDetail(int $id, array $actor): array
    {
        $this->require($actor, 'catalog.view', 'view');
        $proposal = UvrRepository::findProposal($id);

        if ($proposal === null) {
            throw new UvrGovernanceException('uvr_proposal_not_found');
        }

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
        $this->require($actor, 'catalog.review', 'review');

        return UvrRepository::tasks();
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function editableCatalogs(array $actor): array
    {
        $this->require($actor, 'catalog.edit_draft', 'edit_draft');

        return CatalogReferenceRepository::all();
    }

    /**
     * Catálogos desde los que se puede proponer UVR.
     *
     * Mientras la fase U7-B no esté autorizada, la elegibilidad sigue siendo la
     * de U0–U6 (acta U7 §5): un solo catálogo, leído de la misma constante que
     * valida `propose()`. No se consulta `os_uvr_eligible_catalog` porque
     * `origen_admin` no tiene SELECT sobre esa tabla.
     *
     * @param array<string, mixed> $actor @return list<array<string, mixed>>
     */
    public function proposalCatalogs(array $actor): array
    {
        $this->require($actor, 'catalog.view', 'view');

        if (!CatalogReferenceRepository::exists(self::CATALOG_CODE)) {
            return [];
        }

        foreach (CatalogReferenceRepository::all() as $catalog) {
            if ($catalog['code'] === self::CATALOG_CODE) {
                return [$catalog];
            }
        }

        return [[
            'code' => self::CATALOG_CODE,
            'name' => self::CATALOG_CODE,
            'short_name' => '',
        ]];
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function conversions(array $actor): array
    {
        $this->require($actor, 'catalog.view', 'view');

        return UvrRepository::conversions();
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function geoIndexes(array $actor): array
    {
        $this->require($actor, 'catalog.view', 'view');

        return UvrRepository::geoIndexes();
    }

    /** @param array<string, mixed> $input @param array<string, mixed> $actor */
    public function propose(array $input, array $actor): int
    {
        $this->require($actor, 'catalog.propose', 'propose');

        if (!CatalogReferenceRepository::exists(self::CATALOG_CODE)) {
            throw new UvrGovernanceException('uvr_catalog_unavailable');
        }

        $serviceItemId = $this->positiveInt($input['service_item_id'] ?? null);
        $versionTag = $this->text($input['version_tag'] ?? null, 50);
        $methodology = $this->text($input['methodology'] ?? null, 120);
        $source = $this->text($input['source_reference'] ?? null, 2000);
        $evaluatedAt = $this->date($input['evaluated_at'] ?? null);

        if ($serviceItemId === null || $versionTag === '' || $methodology === '' || $source === '' || $evaluatedAt === '') {
            throw new UvrGovernanceException('uvr_invalid_valuation');
        }

        // El código debe pertenecer al catálogo elegible. El trigger de base
        // también lo comprueba, pero aquí el error es comprensible para quien
        // carga la propuesta desde el panel.
        if (CatalogGovernanceRepository::item(self::CATALOG_CODE, $serviceItemId) === null) {
            throw new UvrGovernanceException('catalog_item_not_found');
        }

        $components = $input['components'] ?? null;

        if (!is_array($components) || count($components) === 0) {
            throw new UvrGovernanceException('uvr_components_required');
        }

        $normalized = [];

        foreach ($components as $component) {
            if (!is_array($component)) {
                throw new UvrGovernanceException('uvr_invalid_component');
            }

            $type = (string) ($component['component_type'] ?? '');

            if (!in_array($type, self::COMPONENT_TYPES, true)) {
                throw new UvrGovernanceException('uvr_invalid_component');
            }

            $notApplicable = $this->flag($component, 'is_not_applicable');
            $rawValue = $component['value'] ?? null;

            if (!is_numeric($rawValue)) {
                throw new UvrGovernanceException('uvr_invalid_component');
            }

            $value = (float) $rawValue;
            $evidence = $this->text($component['negative_adjustment_evidence'] ?? null, 2000);

            if ($notApplicable && abs($value) > 0.00001) {
                throw new UvrGovernanceException('uvr_na_requires_zero');
            }

            if ($value < 0 && $evidence === '') {
                throw new UvrGovernanceException('uvr_negative_requires_evidence');
            }

            if ($value >= 0 && $evidence !== '') {
                throw new UvrGovernanceException('uvr_evidence_requires_negative');
            }

            $normalized[] = [
                'component_type' => $type,
                'value' => $value,
                'is_not_applicable' => $notApplicable,
                'negative_adjustment_evidence' => $evidence !== '' ? $evidence : null,
                'calculation_note' => $this->text($component['calculation_note'] ?? null, 2000) ?: null,
            ];
        }

        $actorId = $this->actorId($actor);
        $actorEmail = $this->actorEmail($actor);
        $valuationId = UvrRepository::createValuation([
            'service_item_id' => $serviceItemId,
            'release_id' => $this->positiveInt($input['release_id'] ?? null),
            'version_tag' => $versionTag,
            'methodology' => $methodology,
            'source_reference' => $source,
            'evaluated_at' => $evaluatedAt,
            'valid_from' => $this->date($input['valid_from'] ?? null) ?: null,
            'valid_to' => $this->date($input['valid_to'] ?? null) ?: null,
        ], $actorId, $actorEmail);

        foreach ($normalized as $component) {
            UvrRepository::addComponent($valuationId, $component);
        }

        $proposedChange = json_encode([
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
            'catalog_code' => self::CATALOG_CODE,
            'after_state' => ['proposal_id' => $proposalId, 'version_tag' => $versionTag],
        ]);

        return $proposalId;
    }

    /** @param array<string, mixed> $input @param array<string, mixed> $actor */
    public function recordReview(int $proposalId, array $input, array $actor): int
    {
        $this->require($actor, 'catalog.review', 'review');
        $proposal = UvrRepository::findProposal($proposalId);

        if ($proposal === null) {
            throw new UvrGovernanceException('uvr_proposal_not_found');
        }

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
            'catalog_code' => self::CATALOG_CODE,
            'after_state' => ['review_id' => $reviewId, 'role' => $role, 'outcome' => $outcome],
        ]);

        return $reviewId;
    }

    /** @param array<string, mixed> $input @param array<string, mixed> $actor */
    public function decide(int $proposalId, array $input, array $actor): int
    {
        $this->require($actor, 'catalog.approve', 'approve');
        $proposal = UvrRepository::findProposal($proposalId);

        if ($proposal === null) {
            throw new UvrGovernanceException('uvr_proposal_not_found');
        }

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
            UvrRepository::linkApproval($valuationId, $actorId);
        }

        UvrRepository::setProposalStatus($proposalId, 'approved');

        $this->audit('uvr_decision_recorded', $actor, [
            'entity_type' => 'uvr_governance_request',
            'entity_id' => (string) $proposalId,
            'catalog_code' => self::CATALOG_CODE,
            'after_state' => ['decision_id' => $decisionId, 'evidence_reference' => $evidence],
        ]);

        return $decisionId;
    }

    /** @param array<string, mixed> $actor */
    public function publish(int $valuationId, array $actor): void
    {
        $this->require($actor, 'catalog.publish', 'publish');
        UvrRepository::publish($valuationId, $this->actorId($actor));

        $this->audit('uvr_published', $actor, [
            'entity_type' => 'uvr_valuation',
            'entity_id' => (string) $valuationId,
            'catalog_code' => self::CATALOG_CODE,
        ]);
    }

    /** @param array<string, mixed> $actor @return array<string, mixed>|null */
    public function importe(int $valuationId, ?int $conversionId, array $actor): ?array
    {
        $this->require($actor, 'catalog.view', 'view');
        $valuation = UvrRepository::findValuation($valuationId);

        if ($valuation === null) {
            throw new UvrGovernanceException('uvr_valuation_not_found');
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
    private function require(array $actor, string $permission, string $operation): void
    {
        if (!Rbac::hasPermission($this->permissions($actor), $permission)) {
            throw new UvrGovernanceException('uvr_permission_denied');
        }

        $grants = is_array($actor['grants'] ?? null) ? $actor['grants'] : [];

        if (!Rbac::canAccessCatalog($grants, self::CATALOG_CODE, $operation, $this->permissions($actor))) {
            throw new UvrGovernanceException('uvr_grant_denied');
        }
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
