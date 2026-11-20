<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Admin;

use OrigenSalud\Portal\Repositories\CatalogGovernanceRepository;
use OrigenSalud\Portal\Repositories\CatalogReferenceRepository;
use OrigenSalud\Portal\Repositories\RepositoryException;

/**
 * Gestión de catálogos: propuesta, revisión, decisión y publicación.
 *
 * No escribe directamente en os_catalog_*. La publicación se delega a una
 * función de base que valida el estado, las dos revisiones y la evidencia
 * antes de aplicar el cambio y auditarlo.
 */
final class CatalogGovernanceService
{
    private const STATUSES = ['active', 'retired', 'superseded'];
    private const RELEASE_STATUSES = ['draft', 'review', 'published', 'deprecated'];
    private const RELATION_TYPES = [
        'alternate_benefit', 'billed_in_conjunction_with', 'concurrent_to',
        'denied_as_integral', 'frequency_limitations', 'integral_to',
        'interchangeable_with', 'not_paid_separately', 'not_to_be_used_with',
        'paid_as_code', 'procedure_code_not_used_for', 'refer_to_details',
        'referencia_literal', 'shares_frequency_limitation_with',
        'used_in_combination_with',
    ];
    private const SOURCE_FIELDS = ['description', 'procedure', 'notes', 'req'];
    private const COVERAGE = ['original', 'complete', 'partial', 'planned', 'undetermined'];

    /** @param array<string, mixed> $actor */
    public function catalogs(string $query, array $actor): array
    {
        $this->require($actor, 'catalog.view', 'view');
        $query = mb_strtolower(trim($query));

        return array_values(array_filter(
            CatalogReferenceRepository::all(),
            static fn (array $catalog): bool => $query === ''
                || str_contains(mb_strtolower($catalog['code'] . ' ' . $catalog['name']), $query)
        ));
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function items(string $code, string $query, array $actor): array
    {
        $this->requireForCatalog($actor, $code, 'catalog.view', 'view');

        return CatalogGovernanceRepository::items($code, trim($query));
    }

    /**
     * @param array<string, mixed> $actor
     * @return array<string, mixed>
     */
    public function item(string $code, int $itemId, array $actor): array
    {
        $this->requireForCatalog($actor, $code, 'catalog.view', 'view');
        $item = CatalogGovernanceRepository::item($code, $itemId);

        if ($item === null) {
            throw new UvrGovernanceException('catalog_item_not_found');
        }

        return [
            'item' => $item,
            'versions' => CatalogGovernanceRepository::versions($itemId),
            'relations' => CatalogGovernanceRepository::relations($itemId),
            'releases' => CatalogGovernanceRepository::releases($code),
            'languages' => CatalogGovernanceRepository::languages($code),
        ];
    }

    /** @param array<string, mixed> $actor @return list<array<string, mixed>> */
    public function proposals(array $actor): array
    {
        $this->require($actor, 'catalog.view', 'view');

        return CatalogGovernanceRepository::proposals();
    }

    /** @param array<string, mixed> $actor @return array<string, mixed> */
    public function proposal(int $id, array $actor): array
    {
        $this->require($actor, 'catalog.view', 'view');
        $proposal = CatalogGovernanceRepository::findProposal($id);

        if ($proposal === null) {
            throw new UvrGovernanceException('catalog_proposal_not_found');
        }

        return [
            'proposal' => $proposal,
            'reviews' => CatalogGovernanceRepository::reviews($id),
            'decisions' => CatalogGovernanceRepository::decisions($id),
        ];
    }

    /** @param array<string, mixed> $input @param array<string, mixed> $actor */
    public function propose(array $input, array $actor): int
    {
        $code = $this->code($input['code'] ?? null);
        $this->requireForCatalog($actor, $code, 'catalog.propose', 'propose');

        if (!CatalogReferenceRepository::exists($code)) {
            throw new UvrGovernanceException('catalog_unavailable');
        }

        $source = $this->text($input['source_reference'] ?? null, 2000);

        if ($source === '') {
            throw new UvrGovernanceException('catalog_source_required');
        }

        $operation = (string) ($input['operation'] ?? 'update');
        $itemId = $this->positiveInt($input['item_id'] ?? null);

        if (!in_array($operation, ['create', 'update'], true)) {
            throw new UvrGovernanceException('catalog_invalid_change');
        }

        if ($operation === 'update' && ($itemId === null || CatalogGovernanceRepository::item($code, $itemId) === null)) {
            throw new UvrGovernanceException('catalog_item_not_found');
        }

        $change = [
            'catalog_code' => $code,
            'operation' => $operation,
        ];

        if ($itemId !== null) {
            $change['item_id'] = $itemId;
        }

        $permanentCode = $this->text($input['permanent_code'] ?? null, 50);
        $status = (string) ($input['status'] ?? '');

        if ($permanentCode !== '' && preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]{0,49}$/', $permanentCode) !== 1) {
            throw new UvrGovernanceException('catalog_invalid_change');
        }

        if ($operation === 'create' && ($permanentCode === '' || !in_array($status, self::STATUSES, true))) {
            throw new UvrGovernanceException('catalog_invalid_change');
        }

        if ($permanentCode !== '' || in_array($status, self::STATUSES, true)) {
            $change['item'] = [
                'permanent_code' => $permanentCode,
                'status' => in_array($status, self::STATUSES, true) ? $status : null,
            ];
        }

        $releaseId = $this->positiveInt($input['release_id'] ?? null);
        $release = $this->validRelease($code, $releaseId, $input);

        if ($release !== null) {
            $change['release'] = $release;
        }

        $preferredTerm = $this->text($input['preferred_term'] ?? null, 255);

        if ($preferredTerm !== '') {
            if ($releaseId === null) {
                throw new UvrGovernanceException('catalog_release_required');
            }

            $change['version'] = [
                'release_id' => $releaseId,
                'preferred_term' => $preferredTerm,
                'definition' => $this->text($input['definition'] ?? null, 4000),
                'clinical_criteria' => $this->text($input['clinical_criteria'] ?? null, 4000),
                'language_code' => $this->language($input['language_code'] ?? 'es-AR'),
            ];
        }

        $relations = $this->relations($input['relations'] ?? []);

        if ($relations !== []) {
            $change['relations'] = $relations;
        }

        $languages = $this->languages($input['languages'] ?? []);

        if ($languages !== []) {
            $change['languages'] = $languages;
        }

        $hasChange = isset($change['item'])
            || isset($change['release'])
            || isset($change['version'])
            || isset($change['relations'])
            || isset($change['languages']);

        if (!$hasChange) {
            throw new UvrGovernanceException('catalog_invalid_change');
        }

        $json = json_encode($change, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $json = is_string($json) ? $json : '{}';
        $actorId = $this->actorId($actor);
        $actorEmail = $this->actorEmail($actor);
        $subjectId = $operation === 'create' ? 'new:' . $code : (string) $itemId;

        $proposalId = CatalogGovernanceRepository::createProposal(
            $subjectId,
            $json,
            $source,
            $actorId,
            $actorEmail
        );

        $this->audit('catalog_change_proposed', $actor, [
            'entity_type' => 'catalog_change',
            'entity_id' => $subjectId,
            'catalog_code' => $code,
            'request_id' => (string) $proposalId,
            'after_state' => ['operation' => $operation],
        ]);

        return $proposalId;
    }

    /** @param array<string, mixed> $input @param array<string, mixed> $actor */
    public function recordReview(int $proposalId, array $input, array $actor): int
    {
        $proposal = CatalogGovernanceRepository::findProposal($proposalId);

        if ($proposal === null) {
            throw new UvrGovernanceException('catalog_proposal_not_found');
        }

        $this->requireForCatalog($actor, $this->proposalCatalog($proposal), 'catalog.review', 'review');

        $role = (string) ($input['review_role'] ?? '');

        if (!in_array($role, ['clinical', 'technical'], true)) {
            throw new UvrGovernanceException('catalog_invalid_review_role');
        }

        $rationale = $this->text($input['rationale'] ?? null, 2000);
        $outcome = (string) ($input['outcome'] ?? 'unreviewed');

        if (!in_array($outcome, ['unreviewed', 'reviewed', 'approved'], true) || $rationale === '') {
            throw new UvrGovernanceException('catalog_invalid_review');
        }

        $actorId = $this->actorId($actor);

        foreach (CatalogGovernanceRepository::reviews($proposalId) as $existing) {
            if ((int) ($existing['reviewer_user_id'] ?? 0) === $actorId) {
                throw new UvrGovernanceException('catalog_review_actor_reused');
            }

            if ((string) ($existing['reviewer_role'] ?? '') === $role) {
                throw new UvrGovernanceException('catalog_duplicate_review_role');
            }
        }

        $reviewId = CatalogGovernanceRepository::recordReview(
            $proposalId,
            $role,
            $outcome,
            $rationale,
            $actorId,
            $this->actorEmail($actor)
        );

        if ($outcome === 'approved' && $this->hasBothApprovedReviews($proposalId)) {
            CatalogGovernanceRepository::setStatus($proposalId, 'reviewed');
        }

        $this->audit('catalog_review_recorded', $actor, [
            'entity_type' => 'catalog_change',
            'entity_id' => (string) $proposalId,
            'request_id' => (string) $proposalId,
            'after_state' => ['review_id' => $reviewId, 'role' => $role, 'outcome' => $outcome],
        ]);

        return $reviewId;
    }

    /** @param array<string, mixed> $input @param array<string, mixed> $actor */
    public function decide(int $proposalId, array $input, array $actor): int
    {
        $proposal = CatalogGovernanceRepository::findProposal($proposalId);

        if ($proposal === null) {
            throw new UvrGovernanceException('catalog_proposal_not_found');
        }

        $this->requireForCatalog($actor, $this->proposalCatalog($proposal), 'catalog.approve', 'approve');

        $evidence = $this->text($input['evidence_reference'] ?? null, 2000);

        if ($evidence === '') {
            throw new UvrGovernanceException('catalog_evidence_required');
        }

        $actorId = $this->actorId($actor);

        if (!Rbac::canApprove(
            (string) ($proposal['requested_by_user_id'] ?? ''),
            (string) $actorId,
            $this->permissions($actor)
        )) {
            throw new UvrGovernanceException('catalog_self_approval_denied');
        }

        if (!$this->hasBothApprovedReviews($proposalId)) {
            throw new UvrGovernanceException('catalog_reviews_incomplete');
        }

        $decisionId = 0;

        foreach (CatalogGovernanceRepository::reviews($proposalId) as $review) {
            if ((string) ($review['outcome'] ?? '') !== 'approved') {
                continue;
            }

            $decisionId = CatalogGovernanceRepository::recordDecision(
                (int) $review['id'],
                $actorId,
                $this->actorEmail($actor),
                $evidence
            );
        }

        CatalogGovernanceRepository::setStatus($proposalId, 'approved');
        $this->audit('catalog_decision_recorded', $actor, [
            'entity_type' => 'catalog_change',
            'entity_id' => (string) $proposalId,
            'request_id' => (string) $proposalId,
            'after_state' => ['decision_id' => $decisionId],
        ]);

        return $decisionId;
    }

    /** @param array<string, mixed> $actor */
    public function publish(int $proposalId, array $actor): string
    {
        $proposal = CatalogGovernanceRepository::findProposal($proposalId);

        if ($proposal === null) {
            throw new UvrGovernanceException('catalog_proposal_not_found');
        }

        $this->requireForCatalog($actor, $this->proposalCatalog($proposal), 'catalog.publish', 'publish');

        $actorId = $this->actorId($actor);

        try {
            return CatalogGovernanceRepository::publish($proposalId, $actorId, $this->actorEmail($actor));
        } catch (RepositoryException) {
            throw new UvrGovernanceException('catalog_publish_failed');
        }
    }

    /** @param array<string, mixed> $actor @param array<string, mixed> $context */
    private function audit(string $action, array $actor, array $context): void
    {
        AuditLogger::record($action, $context + [
            'actor_user_id' => $this->actorId($actor),
            'actor_email' => $this->actorEmail($actor),
        ]);
    }

    private function hasBothApprovedReviews(int $proposalId): bool
    {
        $roles = [];

        foreach (CatalogGovernanceRepository::reviews($proposalId) as $review) {
            if ((string) ($review['outcome'] ?? '') === 'approved') {
                $roles[(string) ($review['reviewer_role'] ?? '')] = true;
            }
        }

        return isset($roles['clinical'], $roles['technical']);
    }

    /** @param array<string, mixed> $input @return array<string, mixed>|null */
    private function validRelease(string $code, ?int $releaseId, array $input): ?array
    {
        if ($releaseId === null) {
            return null;
        }

        $releases = CatalogGovernanceRepository::releases($code);
        $found = null;

        foreach ($releases as $release) {
            if ((int) $release['id'] === $releaseId) {
                $found = $release;
                break;
            }
        }

        if ($found === null) {
            throw new UvrGovernanceException('catalog_release_required');
        }

        $status = (string) ($input['release_status'] ?? '');
        $versionTag = $this->text($input['version_tag'] ?? null, 50) ?: (string) $found['version_tag'];
        $validFrom = $this->date($input['valid_from'] ?? null) ?: (string) ($found['valid_from'] ?? '');
        $validTo = $this->date($input['valid_to'] ?? null) ?: (string) ($found['valid_to'] ?? '');

        if ($status !== '' && !in_array($status, self::RELEASE_STATUSES, true)) {
            throw new UvrGovernanceException('catalog_invalid_change');
        }

        return [
            'release_id' => $releaseId,
            'version_tag' => $versionTag,
            'valid_from' => $validFrom,
            'valid_to' => $validTo,
            'status' => $status !== '' ? $status : null,
        ];
    }

    /** @param mixed $rows @return list<array<string, mixed>> */
    private function relations(mixed $rows): array
    {
        if (!is_array($rows)) {
            return [];
        }

        $normalized = [];

        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }

            $target = $this->positiveInt($row['target_item_id'] ?? null);
            $type = (string) ($row['relation_type'] ?? '');
            $field = (string) ($row['source_field'] ?? '');
            $value = $this->text($row['source_value'] ?? null, 20);
            $provenance = $this->text($row['provenance'] ?? null, 2000);

            if ($target === null && $type === '' && $value === '' && $provenance === '') {
                continue;
            }

            if ($target === null || $type === '' || $value === '' || $provenance === '') {
                throw new UvrGovernanceException('catalog_invalid_change');
            }

            if (!in_array($type, self::RELATION_TYPES, true) || !in_array($field, self::SOURCE_FIELDS, true)) {
                throw new UvrGovernanceException('catalog_invalid_change');
            }

            $normalized[] = [
                'target_item_id' => $target,
                'relation_type' => $type,
                'source_field' => $field,
                'source_value' => $value,
                'context_text' => $this->text($row['context_text'] ?? null, 2000),
                'provenance' => $provenance,
                'review_status' => 'approved',
            ];
        }

        return $normalized;
    }

    /** @param mixed $rows @return list<array<string, mixed>> */
    private function languages(mixed $rows): array
    {
        if (!is_array($rows)) {
            return [];
        }

        $normalized = [];

        foreach ($rows as $row) {
            if (!is_array($row) || empty($row['enabled'])) {
                continue;
            }

            $language = $this->language($row['language_code'] ?? null);
            $coverage = (string) ($row['coverage_status'] ?? 'partial');

            if (!in_array($coverage, self::COVERAGE, true)) {
                throw new UvrGovernanceException('catalog_invalid_change');
            }

            $normalized[] = [
                'language_code' => $language,
                'is_default' => isset($row['is_default']),
                'is_fallback' => isset($row['is_fallback']),
                'is_bridge' => isset($row['is_bridge']),
                'coverage_status' => $coverage,
            ];
        }

        return $normalized;
    }

    private function language(mixed $value): string
    {
        $language = $this->text($value, 10);

        if (preg_match('/^[a-z]{2}(-[A-Za-z]{2})?$/', $language) !== 1) {
            throw new UvrGovernanceException('catalog_invalid_change');
        }

        return $language;
    }

    private function code(mixed $value): string
    {
        $code = $this->text($value, 50);

        if (preg_match('/^[a-z0-9][a-z0-9-]{1,49}$/', $code) !== 1) {
            throw new UvrGovernanceException('catalog_invalid_change');
        }

        return $code;
    }

    /** @param array<string, mixed> $actor */
    private function requireForCatalog(array $actor, string $code, string $permission, string $operation): void
    {
        $this->require($actor, $permission, $operation);

        $grants = is_array($actor['grants'] ?? null) ? $actor['grants'] : [];

        if (!Rbac::canAccessCatalog($grants, $code, $operation, $this->permissions($actor))) {
            throw new UvrGovernanceException('catalog_grant_denied');
        }
    }

    /** @param array<string, mixed> $actor */
    private function require(array $actor, string $permission, string $operation): void
    {
        if (!Rbac::hasPermission($this->permissions($actor), $permission)) {
            throw new UvrGovernanceException('catalog_permission_denied');
        }
    }

    /** @param array<string, mixed> $proposal */
    private function proposalCatalog(array $proposal): string
    {
        $decoded = json_decode((string) ($proposal['proposed_change'] ?? ''), true);
        $code = is_array($decoded) ? (string) ($decoded['catalog_code'] ?? '') : '';

        return preg_match('/^[a-z0-9][a-z0-9-]{1,49}$/', $code) === 1 ? $code : '';
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
        return (int) ($actor['id'] ?? 0);
    }

    /** @param array<string, mixed> $actor */
    private function actorEmail(array $actor): string
    {
        return (string) ($actor['email'] ?? '');
    }

    private function text(mixed $value, int $max): string
    {
        return trim(mb_substr((string) ($value ?? ''), 0, $max));
    }

    private function positiveInt(mixed $value): ?int
    {
        if (is_int($value) && $value > 0) {
            return $value;
        }

        if (is_string($value) && ctype_digit($value) && (int) $value > 0) {
            return (int) $value;
        }

        return null;
    }

    private function date(mixed $value): string
    {
        $text = $this->text($value, 10);

        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $text) !== 1) {
            return '';
        }

        return $text;
    }
}
