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

    private static ?bool $transversalSchema = null;

    /**
     * Las propuestas escriben varias tablas; un fallo a mitad de camino deja
     * filas huérfanas y el reintento choca con la UNIQUE de os_uvr_valuation.
     * Estos métodos mantienen todas las escrituras en una sola transacción.
     */
    public static function beginWrite(): void
    {
        try {
            AdminDatabase::connection()->beginTransaction();
        } catch (\Throwable) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function commitWrite(): void
    {
        try {
            AdminDatabase::connection()->commit();
        } catch (\Throwable) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    public static function rollBackWrite(): void
    {
        try {
            $connection = AdminDatabase::connection();

            if ($connection->inTransaction()) {
                $connection->rollBack();
            }
        } catch (\Throwable) {
            // No enmascarar la excepción original que originó el rollback.
        }
    }

    /**
     * El panel funciona con el esquema U0–U6 hasta que el responsable aplica
     * U7-B. La detección evita consultar tablas inexistentes en producción.
     */
    public static function hasTransversalSchema(): bool
    {
        if (self::$transversalSchema !== null) {
            return self::$transversalSchema;
        }

        try {
            $statement = AdminDatabase::connection()->prepare(
                "SELECT to_regclass('public.os_prestacion') IS NOT NULL
                    AND to_regclass('public.os_uvr_profile') IS NOT NULL
                    AND to_regclass('public.os_uvr_prestacion_valuation') IS NOT NULL
                    AND to_regclass('public.v_os_uvr_prestacion_public') IS NOT NULL"
            );
            $statement->execute();
            self::$transversalSchema = (bool) $statement->fetchColumn();
        } catch (\Throwable) {
            self::$transversalSchema = false;
        }

        return self::$transversalSchema;
    }

    /** @return list<array<string, mixed>> */
    public static function prestaciones(): array
    {
        if (!self::hasTransversalSchema()) {
            return [];
        }

        return self::fetchAll(
            'SELECT id, code, display_name, prestation_type, source_reference
               FROM public.os_prestacion
              WHERE is_valuable AND status IN (\'approved\', \'published\')
              ORDER BY display_name, code'
        );
    }

    /** @return list<array<string, mixed>> */
    public static function profiles(): array
    {
        if (!self::hasTransversalSchema()) {
            return [];
        }

        return self::fetchAll(
            'SELECT id, code, name, methodology, scope, jurisdiction, version_tag, source_reference
               FROM public.os_uvr_profile
              WHERE status IN (\'approved\', \'published\')
              ORDER BY name, code'
        );
    }

    /**
     * Prestaciones con vínculo aprobado al código seleccionado. El vínculo es
     * navegación y trazabilidad: nunca copia ni deriva UVR (U7.6).
     *
     * @return list<array<string, mixed>>
     */
    public static function linkedPrestaciones(int $itemId, string $catalogCode): array
    {
        if (!self::hasTransversalSchema() || $itemId <= 0 || $catalogCode === '') {
            return [];
        }

        return self::fetchAll(
            'SELECT p.id, p.code, p.display_name, p.prestation_type,
                    pc.id AS link_id, pc.correspondence_type, pc.review_status
               FROM public.os_prestacion_codigo pc
               JOIN public.os_prestacion p ON p.id = pc.prestacion_id
              WHERE pc.catalog_code = :catalog
                AND pc.item_id = :item
                AND pc.review_status IN (\'approved\', \'deprecated\')
                AND p.is_valuable
                AND p.status IN (\'approved\', \'published\')
              ORDER BY p.display_name, p.code',
            [':catalog' => $catalogCode, ':item' => $itemId]
        );
    }

    /** @return array<int, string> */
    public static function profileComponents(int $profileId): array
    {
        if (!self::hasTransversalSchema() || $profileId <= 0) {
            return [];
        }

        $rows = self::fetchAll(
            'SELECT component_type, applicability
               FROM public.os_uvr_profile_component
              WHERE profile_id = :profile
              ORDER BY component_type',
            [':profile' => $profileId]
        );
        $components = [];

        foreach ($rows as $row) {
            $components[(string) $row['component_type']] = (string) $row['applicability'];
        }

        return $components;
    }

    /** @return list<array<string, mixed>> */
    public static function prestacionValuations(): array
    {
        if (!self::hasTransversalSchema()) {
            return [];
        }

        return self::fetchAll(
            'SELECT t.valuation_id, t.prestacion_code, t.prestacion_name,
                    t.profile_code, t.methodology, t.scope, t.jurisdiction,
                    v.source_reference, v.version_tag, v.review_status,
                    v.published_at, v.valid_from, v.valid_to, v.evaluated_at,
                    v.calculated_by_user_id, v.approved_by_user_id,
                    t.work_uvr, t.practice_expense_uvr,
                    t.professional_liability_uvr, t.total_uvr
               FROM public.v_os_uvr_prestacion_total t
               JOIN public.os_uvr_prestacion_valuation v ON v.id = t.valuation_id
              ORDER BY t.valuation_id DESC'
        );
    }

    /** @param array<string, mixed> $data */
    public static function createPrestacionValuation(array $data, int $actorId): int
    {
        self::setActor($actorId);

        return self::insertReturningId(
            'INSERT INTO public.os_uvr_prestacion_valuation (
                prestacion_id, profile_id, version_tag, source_reference,
                evaluated_at, calculated_by_user_id, review_status,
                valid_from, valid_to
             ) VALUES (
                :prestacion, :profile, :version, :source, :evaluated,
                :actor, :status, :valid_from, :valid_to
             ) RETURNING id',
            [
                ':prestacion' => (int) $data['prestacion_id'],
                ':profile' => (int) $data['profile_id'],
                ':version' => (string) $data['version_tag'],
                ':source' => (string) $data['source_reference'],
                ':evaluated' => (string) $data['evaluated_at'],
                ':actor' => $actorId,
                ':status' => 'draft',
                ':valid_from' => $data['valid_from'] !== null ? (string) $data['valid_from'] : null,
                ':valid_to' => $data['valid_to'] !== null ? (string) $data['valid_to'] : null,
            ]
        );
    }

    /** @param array<string, mixed> $data */
    public static function addPrestacionComponent(int $valuationId, array $data): void
    {
        self::execute(
            'INSERT INTO public.os_uvr_prestacion_component (
                valuation_id, component_type, value, is_not_applicable,
                negative_adjustment_evidence, calculation_note, source_reference
             ) VALUES (
                :valuation, :type, :value, :not_applicable, :evidence,
                :note, :source
             )
             ON CONFLICT (valuation_id, component_type) DO NOTHING',
            [
                ':valuation' => $valuationId,
                ':type' => (string) $data['component_type'],
                ':value' => (float) $data['value'],
                // PDO_PGSQL enlaza false como '' y PostgreSQL no lo casa a boolean.
                ':not_applicable' => $data['is_not_applicable'] ? 't' : 'f',
                ':evidence' => $data['negative_adjustment_evidence'] !== null
                    ? (string) $data['negative_adjustment_evidence']
                    : null,
                ':note' => $data['calculation_note'] !== null ? (string) $data['calculation_note'] : null,
                ':source' => (string) $data['source_reference'],
            ]
        );
    }

    public static function linkPrestacionApproval(int $valuationId, int $actorId): void
    {
        self::execute(
            'UPDATE public.os_uvr_prestacion_valuation
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

    public static function publishPrestacion(int $valuationId, int $actorId): void
    {
        self::setActor($actorId);
        self::execute(
            'UPDATE public.os_uvr_prestacion_valuation
                SET review_status = :status, published_at = CURRENT_TIMESTAMP
              WHERE id = :id AND review_status = :approved',
            [':status' => 'published', ':id' => $valuationId, ':approved' => 'approved']
        );
    }

    /** @return array<string, mixed>|null */
    public static function findPrestacionValuation(int $id): ?array
    {
        if (!self::hasTransversalSchema() || $id <= 0) {
            return null;
        }

        return self::fetchOne(
            'SELECT t.valuation_id, t.prestacion_id, t.prestacion_code, t.prestacion_name,
                    t.profile_id, t.profile_code, t.methodology, t.scope, t.jurisdiction,
                    v.version_tag, v.source_reference, v.evaluated_at, v.review_status,
                    v.published_at, v.valid_from, v.valid_to, v.calculated_by_user_id,
                    v.approved_by_user_id, t.work_uvr, t.practice_expense_uvr,
                    t.professional_liability_uvr, t.total_uvr
               FROM public.v_os_uvr_prestacion_total t
               JOIN public.os_uvr_prestacion_valuation v ON v.id = t.valuation_id
              WHERE t.valuation_id = :id LIMIT 1',
            [':id' => $id]
        );
    }

    /**
     * Catálogos con vínculo aprobado para una valoración de prestación. Da el
     * ámbito de autorización sin ampliar los grants ni crear permisos nuevos.
     *
     * @return list<string>
     */
    public static function catalogCodesForPrestacionValuation(int $valuationId): array
    {
        if (!self::hasTransversalSchema() || $valuationId <= 0) {
            return [];
        }

        $rows = self::fetchAll(
            'SELECT DISTINCT pc.catalog_code
               FROM public.os_uvr_prestacion_valuation v
               JOIN public.os_prestacion_codigo pc ON pc.prestacion_id = v.prestacion_id
              WHERE v.id = :id
                AND pc.review_status IN (\'approved\', \'deprecated\')
              ORDER BY pc.catalog_code',
            [':id' => $valuationId]
        );
        $codes = [];

        foreach ($rows as $row) {
            $code = (string) ($row['catalog_code'] ?? '');
            if ($code !== '') {
                $codes[] = $code;
            }
        }

        return $codes;
    }

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
                    r.proposed_change, r.review_status, r.requested_by, r.created_at,
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
                // PDO_PGSQL enlaza false como '' y PostgreSQL no lo casa a boolean.
                ':not_applicable' => $data['is_not_applicable'] ? 't' : 'f',
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
