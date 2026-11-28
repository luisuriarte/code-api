<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDO;
use PDOException;

/**
 * Acceso de gestión de catálogos.
 *
 * Las lecturas usan la conexión pública de solo lectura; las solicitudes,
 * revisiones, decisiones y la publicación usan la conexión administrativa.
 * La publicación invoca `os_catalog_apply_governed_change()`, que es
 * SECURITY DEFINER: origen_admin nunca recibe INSERT/UPDATE sobre os_catalog_*.
 */
final class CatalogGovernanceRepository
{
    private const SUBJECT = 'catalog_change';

    /**
     * Listado de códigos. El término visible prioriza la versión canónica es-AR:
     * AN/CL tienen también una versión 'en' posterior y un ORDER BY id DESC la
     * elegiría, mostrando el término inglés aunque el panel esté en es-AR.
     *
     * @return list<array<string, mixed>>
     */
    public static function items(string $code, string $query): array
    {
        $clinical = self::clinicalCategoryAvailable();
        $identifier = self::identifierAvailable();
        $term = self::termAvailable();
        $clinicalColumns = $clinical
            ? ' COALESCE(icc.clinical_category_code, map.clinical_category_code, def.clinical_category_code) AS clinical_category_code,'
            . ' catclin.name AS clinical_category_name,'
            : ' NULL::text AS clinical_category_code, NULL::text AS clinical_category_name,';
        $clinicalJoins = $clinical
            ? ' LEFT JOIN public.os_catalog_item_clinical_category icc ON icc.item_id = i.id'
            . ' LEFT JOIN LATERAL ('
            . '     SELECT ccm.clinical_category_code'
            . '       FROM public.os_catalog_item_version cv'
            . '       JOIN public.os_catalog_category_clinical_map ccm ON ccm.category_id = cv.category_id'
            . '      WHERE cv.item_id = i.id'
            . '      ORDER BY cv.id DESC LIMIT 1'
            . ' ) map ON TRUE'
            . ' LEFT JOIN public.os_catalog_clinical_default def ON def.catalog_code = c.code'
            . ' LEFT JOIN public.os_clinical_category catclin'
            . '   ON catclin.code = COALESCE(icc.clinical_category_code, map.clinical_category_code, def.clinical_category_code)'
            : '';
        $identifierColumns = $identifier
            ? " (SELECT string_agg(COALESCE(si.system_name, '') || ':' || si.value, ', '"
              . ' ORDER BY si.is_primary DESC, si.id)'
              . ' FROM public.os_catalog_identifier si WHERE si.item_id = i.id) AS identifiers,'
            : ' NULL::text AS identifiers,';
        $identifierWhere = $identifier
            ? ' OR EXISTS (SELECT 1 FROM public.os_catalog_identifier si'
              . ' WHERE si.item_id = i.id AND si.value ILIKE :query)'
            : '';
        $exactIdentifier = $identifier
            ? ' (EXISTS (SELECT 1 FROM public.os_catalog_identifier ei'
              . ' WHERE ei.item_id = i.id AND ei.value = :needle)) DESC,'
            : '';
        $termWhere = $term
            ? ' OR EXISTS (SELECT 1 FROM public.os_catalog_item_version sv'
              . ' JOIN public.os_catalog_term st ON st.item_version_id = sv.id'
              . ' WHERE sv.item_id = i.id AND st.term ILIKE :query)'
            : '';

        return self::publicRows(
            'SELECT i.id, i.permanent_code, i.status, v.preferred_term,'
            . $clinicalColumns . $identifierColumns . chr(10)
            . '  FROM public.os_catalog_item i'
            . '  JOIN public.os_catalog c ON c.id = i.catalog_id'
            . $clinicalJoins . chr(10)
            . '  LEFT JOIN LATERAL ('
            . '       SELECT v2.preferred_term'
            . '         FROM public.os_catalog_item_version v2'
            . '        WHERE v2.item_id = i.id'
            . '        ORDER BY (v2.language_code = \'es-AR\') DESC, v2.id DESC'
            . '        LIMIT 1'
            . '  ) v ON TRUE'
            . ' WHERE c.code = :code'
            . '   AND (i.permanent_code ILIKE :query'
            . '        OR COALESCE(v.preferred_term, \'\') ILIKE :query'
            . $identifierWhere . $termWhere . ')'
            . ' ORDER BY (lower(i.permanent_code) = lower(:needle)) DESC,'
            . $exactIdentifier . chr(10)
            . '          i.permanent_code'
            . ' LIMIT 200',
            [':code' => $code, ':query' => '%' . $query . '%', ':needle' => $query]
        );
    }

    /** @return list<array<string, mixed>> */
    public static function clinicalCategories(): array
    {
        if (!self::clinicalCategoryAvailable()) {
            return [];
        }

        return self::publicRows(
            'SELECT code, name, definition, examples
               FROM public.os_clinical_category
              WHERE status = \'active\'
              ORDER BY sort_order ASC, code ASC',
            []
        );
    }

    /** @return array<string, mixed>|null */
    public static function item(string $code, int $itemId): ?array
    {
        $clinical = self::clinicalCategoryAvailable();
        $identifier = self::identifierAvailable();
        $clinicalColumns = $clinical
            ? ' COALESCE(icc.clinical_category_code, map.clinical_category_code, def.clinical_category_code) AS clinical_category_code,'
            . ' catclin.name AS clinical_category_name,'
            : ' NULL::text AS clinical_category_code, NULL::text AS clinical_category_name,';
        $identifierColumns = $identifier
            ? " (SELECT string_agg(COALESCE(si.system_name, '') || ':' || si.value, ', '"
              . ' ORDER BY si.is_primary DESC, si.id)'
              . ' FROM public.os_catalog_identifier si WHERE si.item_id = i.id) AS identifiers,'
            : ' NULL::text AS identifiers,';
        $clinicalJoins = $clinical
            ? ' LEFT JOIN public.os_catalog_item_clinical_category icc ON icc.item_id = i.id'
            . ' LEFT JOIN LATERAL ('
            . '     SELECT ccm.clinical_category_code'
            . '       FROM public.os_catalog_item_version cv'
            . '       JOIN public.os_catalog_category_clinical_map ccm ON ccm.category_id = cv.category_id'
            . '      WHERE cv.item_id = i.id'
            . '      ORDER BY cv.id DESC LIMIT 1'
            . ' ) map ON TRUE'
            . ' LEFT JOIN public.os_catalog_clinical_default def ON def.catalog_code = c.code'
            . ' LEFT JOIN public.os_clinical_category catclin'
            . '   ON catclin.code = COALESCE(icc.clinical_category_code, map.clinical_category_code, def.clinical_category_code)'
            : '';

        return self::publicRow(
            'SELECT i.id, i.catalog_id, i.permanent_code, i.status,'
            . ' c.code AS catalog_code, c.name AS catalog_name,' . $clinicalColumns
            . $identifierColumns . chr(10)
            . '  FROM public.os_catalog_item i'
            . '  JOIN public.os_catalog c ON c.id = i.catalog_id'
            . $clinicalJoins . chr(10)
            . ' WHERE c.code = :code AND i.id = :id'
            . ' LIMIT 1',
            [':code' => $code, ':id' => $itemId]
        );
    }

    /**
     * Versiones del ítem. La canónica es-AR va primero para que el editor
     * precargue el término en español de AN/CL antes que la versión 'en'.
     *
     * @return list<array<string, mixed>>
     */
    public static function versions(int $itemId): array
    {
        return self::publicRows(
            'SELECT v.id, v.release_id, r.version_tag, v.preferred_term, v.definition,
                    v.clinical_criteria, v.language_code
               FROM public.os_catalog_item_version v
               JOIN public.os_catalog_release r ON r.id = v.release_id
              WHERE v.item_id = :id
              ORDER BY (v.language_code = \'es-AR\') DESC,
                       r.valid_from DESC NULLS LAST, v.id DESC
              LIMIT 50',
            [':id' => $itemId]
        );
    }

    /** @return list<array<string, mixed>> */
    public static function releases(string $code): array
    {
        return self::publicRows(
            'SELECT r.id, r.version_tag, r.valid_from, r.valid_to, r.status
               FROM public.os_catalog_release r
               JOIN public.os_catalog c ON c.id = r.catalog_id
              WHERE c.code = :code
              ORDER BY r.valid_from DESC NULLS LAST, r.id DESC
              LIMIT 50',
            [':code' => $code]
        );
    }

    /** @return list<array<string, mixed>> */
    public static function relations(int $itemId): array
    {
        return self::publicRows(
            'SELECT r.id, r.target_item_id, t.permanent_code AS target_code,
                    r.relation_type, r.source_system_code, r.source_field,
                    r.source_value, r.context_text, r.review_status, r.provenance
               FROM public.os_catalog_relation r
               LEFT JOIN public.os_catalog_item t ON t.id = r.target_item_id
              WHERE r.source_item_id = :id
              ORDER BY r.id DESC
              LIMIT 50',
            [':id' => $itemId]
        );
    }

    /** @return list<array<string, mixed>> */
    public static function languages(string $code): array
    {
        try {
            return self::publicRows(
                'SELECT l.language_code, l.is_default, l.is_fallback, l.is_bridge, l.coverage_status
                   FROM public.os_catalog_language l
                   JOIN public.os_catalog c ON c.id = l.catalog_id
                  WHERE c.code = :code
                  ORDER BY l.language_code',
                [':code' => $code]
            );
        } catch (RepositoryException) {
            return [];
        }
    }

    /** @return list<array<string, mixed>> */
    public static function proposals(): array
    {
        return self::adminRows(
            'SELECT id, request_type, subject_type, subject_id, proposed_change,
                    source_reference, requested_by, requested_by_user_id,
                    review_status, created_at
               FROM public.os_governance_request
              WHERE subject_type = :subject
              ORDER BY id DESC',
            [':subject' => self::SUBJECT]
        );
    }

    /** @return array<string, mixed>|null */
    public static function findProposal(int $id): ?array
    {
        return self::adminRow(
            'SELECT * FROM public.os_governance_request
              WHERE id = :id AND subject_type = :subject LIMIT 1',
            [':id' => $id, ':subject' => self::SUBJECT]
        );
    }

    /** @return list<array<string, mixed>> */
    public static function reviews(int $requestId): array
    {
        return self::adminRows(
            'SELECT id, request_id, reviewer_actor, reviewer_user_id, reviewer_role,
                    outcome, rationale, reviewed_at
               FROM public.os_governance_review
              WHERE request_id = :request
              ORDER BY id',
            [':request' => $requestId]
        );
    }

    /** @return list<array<string, mixed>> */
    public static function decisions(int $requestId): array
    {
        return self::adminRows(
            'SELECT d.id, d.decision_code, d.approved_by, d.approved_by_user_id,
                    d.approved_at, d.evidence_reference
               FROM public.os_governance_decision d
               JOIN public.os_governance_review r ON r.id = d.review_id
              WHERE r.request_id = :request
              ORDER BY d.id',
            [':request' => $requestId]
        );
    }

    public static function createProposal(
        string $subjectId,
        string $change,
        string $source,
        int $actorId,
        string $actorEmail
    ): int {
        return self::adminInsert(
            'INSERT INTO public.os_governance_request
                (request_type, subject_type, subject_id, proposed_change,
                 source_reference, requested_by, requested_by_user_id, review_status)
             VALUES (:type, :subject, :subject_id, :change, :source, :actor, :actor_id, :status)
             RETURNING id',
            [
                ':type' => 'catalog_change',
                ':subject' => self::SUBJECT,
                ':subject_id' => $subjectId,
                ':change' => $change,
                ':source' => $source,
                ':actor' => $actorEmail,
                ':actor_id' => $actorId,
                ':status' => 'draft',
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
        return self::adminInsert(
            'INSERT INTO public.os_governance_review
                (request_id, reviewer_actor, reviewer_user_id, reviewer_role, outcome, rationale)
             VALUES (:request, :actor, :actor_id, :role, :outcome, :rationale)
             RETURNING id',
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
        string $evidence
    ): int {
        return self::adminInsert(
            'INSERT INTO public.os_governance_decision
                (review_id, decision_code, approved_by, approved_by_user_id, evidence_reference)
             VALUES (:review, :code, :actor, :actor_id, :evidence)
             RETURNING id',
            [
                ':review' => $reviewId,
                ':code' => 'approved',
                ':actor' => $actorEmail,
                ':actor_id' => $actorId,
                ':evidence' => $evidence,
            ]
        );
    }

    public static function setStatus(int $requestId, string $status): void
    {
        self::adminExecute(
            'UPDATE public.os_governance_request SET review_status = :status WHERE id = :id',
            [':status' => $status, ':id' => $requestId]
        );
    }

    public static function publish(int $requestId, int $actorId, string $actorEmail): string
    {
        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT public.os_catalog_apply_governed_change(:id, :actor, :email)'
            );
            $statement->execute([
                ':id' => $requestId,
                ':actor' => $actorId,
                ':email' => $actorEmail,
            ]);

            return (string) $statement->fetchColumn();
        } catch (PDOException) {
            throw new RepositoryException('catalog_publish_failed');
        }
    }

    /**
     * Catálogo al que pertenece un código. Permite conservar el deep link
     * histórico `?service_item_id=` cuando el selector ya no es único.
     */
    public static function catalogCodeForItem(int $itemId): ?string
    {
        if ($itemId <= 0) {
            return null;
        }

        $row = self::publicRow(
            'SELECT c.code
               FROM public.os_catalog_item i
               JOIN public.os_catalog c ON c.id = i.catalog_id
              WHERE i.id = :id
              LIMIT 1',
            [':id' => $itemId]
        );

        return $row === null ? null : (string) ($row['code'] ?? '');
    }

    /**
     * Códigos permanentes visibles (DNT-PR-000001, etc.) para una lista de ítems.
     *
     * @param list<int> $itemIds
     * @return array<int, string>
     */
    public static function permanentCodes(array $itemIds): array
    {
        $ids = [];

        foreach ($itemIds as $itemId) {
            $id = (int) $itemId;

            if ($id > 0) {
                $ids[$id] = $id;
            }
        }

        if ($ids === []) {
            return [];
        }

        $ids = array_values($ids);
        $placeholders = implode(',', array_fill(0, count($ids), '?'));

        try {
            $statement = PortalDatabase::connection()->prepare(
                "SELECT id, permanent_code
                   FROM public.os_catalog_item
                  WHERE id IN ({$placeholders})"
            );
            $statement->execute($ids);
            $rows = $statement->fetchAll();
        } catch (PDOException) {
            return [];
        }

        $codes = [];

        foreach (is_array($rows) ? $rows : [] as $row) {
            $codes[(int) ($row['id'] ?? 0)] = (string) ($row['permanent_code'] ?? '');
        }

        return $codes;
    }

    private static function identifierAvailable(): bool
    {
        static $available = null;

        if ($available !== null) {
            return $available;
        }

        try {
            $available = self::tableExists(PortalDatabase::connection(), 'os_catalog_identifier');
        } catch (\Throwable) {
            $available = false;
        }

        return $available;
    }

    private static function termAvailable(): bool
    {
        static $available = null;

        if ($available !== null) {
            return $available;
        }

        try {
            $available = self::tableExists(PortalDatabase::connection(), 'os_catalog_term');
        } catch (\Throwable) {
            $available = false;
        }

        return $available;
    }

    private static function clinicalCategoryAvailable(): bool
    {
        static $available = null;

        if ($available !== null) {
            return $available;
        }

        try {
            $pdo = PortalDatabase::connection();
            $available = self::tableExists($pdo, 'os_clinical_category')
                && self::tableExists($pdo, 'os_catalog_item_clinical_category')
                && self::tableExists($pdo, 'os_catalog_category_clinical_map')
                && self::tableExists($pdo, 'os_catalog_clinical_default');
        } catch (\Throwable) {
            $available = false;
        }

        return $available;
    }

    private static function tableExists(PDO $pdo, string $table): bool
    {
        if (preg_match('/^[a-z0-9_]+$/i', $table) !== 1) {
            return false;
        }

        try {
            $statement = $pdo->prepare('SELECT to_regclass(:name) IS NOT NULL');
            $statement->execute([':name' => 'public.' . $table]);

            return (bool) $statement->fetchColumn();
        } catch (PDOException) {
            return false;
        }
    }

    /** @return list<array<string, mixed>> */
    private static function publicRows(string $sql, array $params): array
    {
        try {
            $statement = PortalDatabase::connection()->prepare($sql);
            $statement->execute($params);

            return $statement->fetchAll();
        } catch (PDOException) {
            throw new RepositoryException('catalog_read_unavailable');
        }
    }

    /** @return array<string, mixed>|null */
    private static function publicRow(string $sql, array $params): ?array
    {
        try {
            $statement = PortalDatabase::connection()->prepare($sql);
            $statement->execute($params);
            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('catalog_read_unavailable');
        }
    }

    /** @return list<array<string, mixed>> */
    private static function adminRows(string $sql, array $params): array
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
    private static function adminRow(string $sql, array $params): ?array
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

    private static function adminInsert(string $sql, array $params): int
    {
        try {
            $statement = AdminDatabase::connection()->prepare($sql);
            $statement->execute($params);

            return (int) $statement->fetchColumn();
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    private static function adminExecute(string $sql, array $params): void
    {
        try {
            $statement = AdminDatabase::connection()->prepare($sql);
            $statement->execute($params);
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }
}
