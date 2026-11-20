<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDOException;

/**
 * Acceso de gestión a las tablas UVR y a la cadena de gestión pública.
 *
 * Usa la conexión administrativa: los privilegios sobre `public.os_uvr_*` y
 * `public.os_governance_*` se conceden de forma explícita en
 * `sql/08_arquitectura/uvr_gobernanza_datos.sql`. No escribe en os_catalog_*,
 * no carga valores y no expone datos a la API pública.
 */
final class UvrRepository
{
    private const SUBJECT_TYPE = 'uvr_valuation';

    /** @return list<array<string, mixed>> */
    public static function valuations(): array
    {
        return self::fetchAll(
            'SELECT valuation_id, service_item_id, release_id, version_tag, methodology,
                    source_reference, review_status, calculated_by_user_id,
                    approved_by_user_id, published_at, work_uvr,
                    practice_expense_uvr, professional_liability_uvr,
                    work_is_not_applicable, practice_expense_is_not_applicable,
                    professional_liability_is_not_applicable, total_uvr
               FROM public.v_os_uvr_valuation_governed
              ORDER BY valuation_id DESC'
        );
    }

    /** @return array<string, mixed>|null */
    public static function findValuation(int $id): ?array
    {
        return self::fetchOne(
            'SELECT * FROM public.v_os_uvr_valuation_governed WHERE valuation_id = :id LIMIT 1',
            [':id' => $id]
        );
    }

    /** @return list<array<string, mixed>> */
    public static function proposals(): array
    {
        return self::fetchAll(
            'SELECT id, request_type, subject_type, subject_id, proposed_change,
                    source_reference, requested_by, requested_by_user_id,
                    review_status, created_at
               FROM public.os_governance_request
              WHERE subject_type = :subject
              ORDER BY id DESC',
            [':subject' => self::SUBJECT_TYPE]
        );
    }

    /** @return array<string, mixed>|null */
    public static function findProposal(int $id): ?array
    {
        return self::fetchOne(
            'SELECT * FROM public.os_governance_request
              WHERE id = :id AND subject_type = :subject LIMIT 1',
            [':id' => $id, ':subject' => self::SUBJECT_TYPE]
        );
    }

    /** @return list<array<string, mixed>> */
    public static function reviews(int $requestId): array
    {
        return self::fetchAll(
            'SELECT id, request_id, reviewer_actor, reviewer_user_id,
                    reviewer_role, outcome, rationale, reviewed_at
               FROM public.os_governance_review
              WHERE request_id = :request
              ORDER BY id',
            [':request' => $requestId]
        );
    }

    /** @return array<string, mixed>|null */
    public static function decisionForReview(int $reviewId): ?array
    {
        return self::fetchOne(
            'SELECT * FROM public.os_governance_decision WHERE review_id = :review LIMIT 1',
            [':review' => $reviewId]
        );
    }

    /** @return list<array<string, mixed>> */
    public static function tasks(): array
    {
        return self::fetchAll(
            'SELECT r.id AS request_id, r.subject_id, r.request_type,
                    r.review_status, r.requested_by, r.created_at,
                    (SELECT count(*) FROM public.os_governance_review rv
                      WHERE rv.request_id = r.id AND rv.outcome = :outcome) AS pending_reviews
               FROM public.os_governance_request r
              WHERE r.subject_type = :subject
                AND r.review_status NOT IN (:approved, :published)
              ORDER BY r.id DESC',
            [
                ':subject' => self::SUBJECT_TYPE,
                ':outcome' => 'unreviewed',
                ':approved' => 'approved',
                ':published' => 'published',
            ]
        );
    }

    /** @return list<array<string, mixed>> */
    public static function conversions(): array
    {
        return self::fetchAll(
            'SELECT id, uvr_value, currency, country_code, jurisdiction, payer,
                    contract, period_start, period_end, source_reference, review_status
               FROM public.os_uvr_conversion
              ORDER BY id DESC'
        );
    }

    /** @return list<array<string, mixed>> */
    public static function geoIndexes(): array
    {
        return self::fetchAll(
            'SELECT id, component_type, jurisdiction, index_value, methodology,
                    source_reference, period_start, period_end, review_status
               FROM public.os_uvr_geo_index
              ORDER BY id DESC'
        );
    }

    public static function createProposal(
        string $proposedChange,
        string $sourceReference,
        int $actorId,
        string $actorEmail,
        ?int $subjectId = null
    ): int {
        self::setActor($actorId);

        return self::insertReturningId(
            'INSERT INTO public.os_governance_request (
                request_type, subject_type, subject_id, proposed_change,
                source_reference, requested_by, requested_by_user_id, review_status
             ) VALUES (
                :request_type, :subject_type, :subject_id, :proposed_change,
                :source_reference, :requested_by, :requested_by_user_id, :status
             ) RETURNING id',
            [
                ':request_type' => 'uvr_valuation_change',
                ':subject_type' => self::SUBJECT_TYPE,
                ':subject_id' => $subjectId === null ? 'pending' : (string) $subjectId,
                ':proposed_change' => $proposedChange,
                ':source_reference' => $sourceReference,
                ':requested_by' => $actorEmail,
                ':requested_by_user_id' => $actorId,
                ':status' => 'draft',
            ]
        );
    }

    /** @param array<string, mixed> $data */
    public static function createValuation(array $data, int $actorId, string $actorEmail): int
    {
        self::setActor($actorId);

        return self::insertReturningId(
            'INSERT INTO public.os_uvr_valuation (
                service_item_id, release_id, version_tag, methodology,
                source_reference, evaluated_at, calculated_by, calculated_by_user_id,
                review_status, valid_from, valid_to
             ) VALUES (
                :service_item_id, :release_id, :version_tag, :methodology,
                :source_reference, :evaluated_at, :calculated_by, :calculated_by_user_id,
                :status, :valid_from, :valid_to
             ) RETURNING id',
            [
                ':service_item_id' => (int) $data['service_item_id'],
                ':release_id' => $data['release_id'] !== null ? (int) $data['release_id'] : null,
                ':version_tag' => (string) $data['version_tag'],
                ':methodology' => (string) $data['methodology'],
                ':source_reference' => (string) $data['source_reference'],
                ':evaluated_at' => (string) $data['evaluated_at'],
                ':calculated_by' => $actorEmail,
                ':calculated_by_user_id' => $actorId,
                ':status' => 'draft',
                ':valid_from' => $data['valid_from'] !== null ? (string) $data['valid_from'] : null,
                ':valid_to' => $data['valid_to'] !== null ? (string) $data['valid_to'] : null,
            ]
        );
    }

    /** @param array<string, mixed> $data */
    public static function addComponent(int $valuationId, array $data): void
    {
        self::execute(
            'INSERT INTO public.os_uvr_component (
                valuation_id, component_type, value, calculation_note,
                is_not_applicable, negative_adjustment_evidence
             ) VALUES (
                :valuation_id, :component_type, :value, :calculation_note,
                :not_applicable, :evidence
             )
             ON CONFLICT (valuation_id, component_type) DO NOTHING',
            [
                ':valuation_id' => $valuationId,
                ':component_type' => (string) $data['component_type'],
                ':value' => (float) $data['value'],
                ':calculation_note' => $data['calculation_note'] !== null ? (string) $data['calculation_note'] : null,
                ':not_applicable' => (bool) $data['is_not_applicable'],
                ':evidence' => $data['negative_adjustment_evidence'] !== null
                    ? (string) $data['negative_adjustment_evidence']
                    : null,
            ]
        );
    }

    public static function recordReview(
        int $requestId,
        string $role,
        string $outcome,
        string $rationale,
        int $actorId,
        string $actorEmail
    ): int {
        self::setActor($actorId);

        return self::insertReturningId(
            'INSERT INTO public.os_governance_review (
                request_id, reviewer_actor, reviewer_user_id, reviewer_role,
                outcome, rationale, reviewed_at
             ) VALUES (
                :request, :actor, :actor_id, :role, :outcome, :rationale, CURRENT_TIMESTAMP
             ) RETURNING id',
            [
                ':request' => $requestId,
                ':actor' => $actorEmail,
                ':actor_id' => $actorId,
                ':role' => $role,
                ':outcome' => $outcome,
                ':rationale' => $rationale,
            ]
        );
    }

    public static function recordDecision(
        int $reviewId,
        int $actorId,
        string $actorEmail,
        string $evidenceReference
    ): int {
        self::setActor($actorId);

        return self::insertReturningId(
            'INSERT INTO public.os_governance_decision (
                review_id, decision_code, approved_by, approved_by_user_id,
                approved_at, effective_from, evidence_reference
             ) VALUES (
                :review, :code, :actor, :actor_id, CURRENT_TIMESTAMP, CURRENT_DATE, :evidence
             ) RETURNING id',
            [
                ':review' => $reviewId,
                ':code' => 'uvr_approved',
                ':actor' => $actorEmail,
                ':actor_id' => $actorId,
                ':evidence' => $evidenceReference,
            ]
        );
    }

    public static function setProposalStatus(int $requestId, string $status): void
    {
        self::execute(
            'UPDATE public.os_governance_request SET review_status = :status WHERE id = :id',
            [':status' => $status, ':id' => $requestId]
        );
    }

    public static function linkApproval(int $valuationId, int $actorId): void
    {
        self::execute(
            'UPDATE public.os_uvr_valuation
                SET approved_by_user_id = :actor, review_status = :status
              WHERE id = :id AND review_status NOT IN (:approved, :published)',
            [
                ':actor' => $actorId,
                ':status' => 'approved',
                ':id' => $valuationId,
                ':approved' => 'approved',
                ':published' => 'published',
            ]
        );
    }

    public static function publish(int $valuationId, int $actorId): void
    {
        self::setActor($actorId);
        self::execute(
            'UPDATE public.os_uvr_valuation
                SET review_status = :status, published_at = CURRENT_TIMESTAMP
              WHERE id = :id AND review_status = :approved',
            [':status' => 'published', ':id' => $valuationId, ':approved' => 'approved']
        );
    }

    /** @return list<array<string, mixed>> */
    private static function fetchAll(string $sql, array $params = []): array
    {
        try {
            $statement = AdminDatabase::connection()->prepare($sql);
            $statement->execute($params);

            return $statement->fetchAll();
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** @return array<string, mixed>|null */
    private static function fetchOne(string $sql, array $params = []): ?array
    {
        try {
            $statement = AdminDatabase::connection()->prepare($sql);
            $statement->execute($params);
            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** @param array<string, mixed> $params */
    private static function insertReturningId(string $sql, array $params): int
    {
        try {
            $statement = AdminDatabase::connection()->prepare($sql);
            $statement->execute($params);

            return (int) $statement->fetchColumn();
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    /** @param array<string, mixed> $params */
    private static function execute(string $sql, array $params): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare($sql);
            $statement->execute($params);
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    private static function setActor(int $actorId): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                "SELECT set_config('app.actor_id', :actor, false)"
            );
            $statement->execute([':actor' => (string) $actorId]);
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }
}
