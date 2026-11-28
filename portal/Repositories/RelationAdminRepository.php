<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use OrigenSalud\Portal\Admin\AuditLogger;
use OrigenSalud\Portal\Admin\UvrGovernanceException;
use PDO;
use PDOException;
use Throwable;

/**
 * Acceso administrativo a relaciones, mapeos y pares nomenclador ↔ OFT-PR.
 *
 * Las lecturas usan la conexión pública de solo lectura. Las escrituras pasan
 * por public.os_relation_admin_write(), SECURITY DEFINER, y la auditoría se
 * escribe en la misma transacción: si falla la auditoría, se revierte el cambio.
 * Ninguna ruta fija review_status='approved'.
 */
final class RelationAdminRepository
{
    private const LIMIT = 100;

    public const ENTITIES = [
        'catalog_relation' => 'relaciones de catálogo',
        'concept_mapping' => 'mapeos terminológicos',
        'nomenclador_match' => 'pares nomenclador ↔ OFT-PR',
    ];

    /** @return array<string, list<array<string, mixed>>> */
    public function options(): array
    {
        return [
            'relation_types' => [
                'alternate_benefit', 'billed_in_conjunction_with', 'concurrent_to',
                'denied_as_integral', 'frequency_limitations', 'integral_to',
                'interchangeable_with', 'not_paid_separately', 'not_to_be_used_with',
                'paid_as_code', 'procedure_code_not_used_for', 'refer_to_details',
                'referencia_literal', 'shares_frequency_limitation_with',
                'used_in_combination_with',
            ],
            'source_fields' => ['description', 'procedure', 'notes', 'req'],
            'mapping_types' => ['equivalent', 'narrower', 'broader', 'related', 'unmatched'],
            'relationship_roles' => [
                'procedure_concept', 'justifying_diagnosis',
                'observation_concept', 'substance_concept',
            ],
            'match_basis' => ['texto_identico_normalizado', 'revision_manual'],
            'relation_kinds' => self::readRows(
                'SELECT code, description FROM public.os_relation_kind ORDER BY code'
            ),
            'relation_type_codes' => self::readRows(
                'SELECT code, source FROM public.os_relation_type ORDER BY code'
            ),
            'systems' => self::readRows(
                'SELECT id, code, name FROM public.os_terminology_system ORDER BY code'
            ),
            'catalogs' => self::readRows(
                'SELECT code, short_name FROM public.os_catalog WHERE is_active = TRUE ORDER BY code'
            ),
            'match_targets' => self::readRows(
                'SELECT ident.value AS value, item.permanent_code AS permanent_code,
                        COALESCE(latest.preferred_term, item.permanent_code) AS display
                   FROM public.os_catalog_identifier ident
                   JOIN public.os_catalog_item item ON item.id = ident.item_id
                   JOIN public.os_catalog cat ON cat.id = item.catalog_id
                   LEFT JOIN LATERAL (
                       SELECT ver.preferred_term
                         FROM public.os_catalog_item_version ver
                        WHERE ver.item_id = item.id
                        ORDER BY ver.id DESC
                        LIMIT 1
                   ) latest ON TRUE
                  WHERE ident.system_name = \'NOMENCLADOR-AR\'
                    AND cat.code = \'oftar-pr\'
                  ORDER BY ident.value
                  LIMIT 500'
            ),
        ];
    }

    /** @return list<array<string, mixed>> */
    public function relations(string $query): array
    {
        return self::readRows(
            'SELECT r.id, r.source_item_id, src.permanent_code AS source_code,
                    sc.code AS source_catalog, r.target_item_id,
                    tgt.permanent_code AS target_code, tc.code AS target_catalog,
                    r.relation_type, r.source_system_code, r.source_field,
                    r.source_value, r.context_text, r.review_status, r.provenance
               FROM public.os_catalog_relation r
               JOIN public.os_catalog_item src ON src.id = r.source_item_id
               JOIN public.os_catalog sc ON sc.id = src.catalog_id
               JOIN public.os_catalog_item tgt ON tgt.id = r.target_item_id
               JOIN public.os_catalog tc ON tc.id = tgt.catalog_id
              WHERE src.permanent_code ILIKE :q
                 OR tgt.permanent_code ILIKE :q
                 OR r.relation_type ILIKE :q
                 OR COALESCE(r.source_system_code, \'\') ILIKE :q
                 OR COALESCE(r.provenance, \'\') ILIKE :q
              ORDER BY r.id DESC
              LIMIT ' . self::LIMIT,
            [':q' => '%' . $query . '%']
        );
    }

    /** @return list<array<string, mixed>> */
    public function mappings(string $query): array
    {
        return self::readRows(
            'SELECT m.id, i.permanent_code AS item_code, c.code AS catalog_code,
                    sys.id AS system_id, sys.code AS system_code, m.external_code,
                    m.external_display, m.mapping_type, m.relationship_role,
                    m.clinical_rationale, m.review_status
               FROM public.os_concept_mapping m
               JOIN public.os_catalog_item i ON i.id = m.item_id
               JOIN public.os_catalog c ON c.id = i.catalog_id
               JOIN public.os_terminology_system sys ON sys.id = m.terminology_system_id
              WHERE i.permanent_code ILIKE :q
                 OR sys.code ILIKE :q
                 OR m.external_code ILIKE :q
                 OR m.external_display ILIKE :q
              ORDER BY m.id DESC
              LIMIT ' . self::LIMIT,
            [':q' => '%' . $query . '%']
        );
    }

    /** @return list<array<string, mixed>> */
    public function matches(string $query): array
    {
        return self::matchRows(
            'm.source_catalog_code ILIKE :q'
            . ' OR m.source_code ILIKE :q'
            . ' OR m.target_code ILIKE :q'
            . ' OR COALESCE(m.source_term, \'\') ILIKE :q'
            . ' OR COALESCE(m.target_term, \'\') ILIKE :q',
            [':q' => '%' . $query . '%']
        );
    }

    /**
     * Pares CAO/Regional ↔ OFT-PR que mencionan al ítem por identificador.
     * El destino se resuelve por sistema + valor, nunca por permanent_code.
     *
     * @return list<array<string, mixed>>
     */
    public function itemMatches(int $itemId): array
    {
        return self::matchRows(
            'EXISTS (SELECT 1 FROM public.os_catalog_identifier si'
            . ' WHERE si.item_id = :id AND si.value = m.source_code)'
            . ' OR EXISTS (SELECT 1 FROM public.os_catalog_identifier ti'
            . ' WHERE ti.item_id = :id AND ti.value = m.target_code'
            . ' AND ti.system_name = \'NOMENCLADOR-AR\')',
            [':id' => $itemId]
        );
    }

    /**
     * @return list<array<string, mixed>>
     */
    private static function matchRows(string $where, array $params): array
    {
        return self::readRows(
            'SELECT m.source_catalog_code, m.source_code, m.target_catalog_code,
                    m.target_code, m.match_basis, m.review_status,
                    m.source_term, m.target_term, m.provenance, m.notes,
                    m.reviewed_at, m.reviewed_by,
                    resolved.permanent_code AS target_permanent_code,
                    resolved.display AS target_display
               FROM public.os_oftar_nomenclador_match m
               LEFT JOIN LATERAL (
                   SELECT item.permanent_code,
                          COALESCE(latest.preferred_term, item.permanent_code) AS display
                     FROM public.os_catalog_identifier ident
                     JOIN public.os_catalog_item item ON item.id = ident.item_id
                     JOIN public.os_catalog cat ON cat.id = item.catalog_id
                     LEFT JOIN LATERAL (
                         SELECT ver.preferred_term
                           FROM public.os_catalog_item_version ver
                          WHERE ver.item_id = item.id
                          ORDER BY ver.id DESC
                          LIMIT 1
                     ) latest ON TRUE
                    WHERE ident.system_name = \'NOMENCLADOR-AR\'
                      AND ident.value = m.target_code
                      AND cat.code = \'oftar-pr\'
                    LIMIT 1
               ) resolved ON TRUE
              WHERE ' . $where . '
              ORDER BY m.source_catalog_code, m.source_code
              LIMIT ' . self::LIMIT,
            $params
        );
    }

    /** @return array<string, mixed>|null */
    public function itemByCode(string $code): ?array
    {
        $code = trim($code);

        if ($code === '') {
            return null;
        }

        return self::readRow(
            'SELECT i.id, i.permanent_code, c.code AS catalog_code,
                    COALESCE(latest.preferred_term, i.permanent_code) AS display
               FROM public.os_catalog_item i
               JOIN public.os_catalog c ON c.id = i.catalog_id
               LEFT JOIN LATERAL (
                   SELECT ver.preferred_term
                     FROM public.os_catalog_item_version ver
                    WHERE ver.item_id = i.id
                    ORDER BY ver.id DESC
                    LIMIT 1
               ) latest ON TRUE
              WHERE i.permanent_code = :code
                  OR EXISTS (SELECT 1 FROM public.os_catalog_identifier si
                              WHERE si.item_id = i.id AND si.value = :code)
              ORDER BY (i.permanent_code = :code) DESC, i.id
              LIMIT 1',
            [':code' => $code]
        );
    }

    /**
     * Resuelve el destino de un par por identificador NOMENCLADOR-AR,
     * nunca por permanent_code (H-02).
     *
     * @return array<string, mixed>|null
     */
    public function matchTarget(string $value): ?array
    {
        $value = trim($value);

        if ($value === '') {
            return null;
        }

        return self::readRow(
            'SELECT ident.value, i.permanent_code, c.code AS catalog_code,
                    COALESCE(latest.preferred_term, i.permanent_code) AS display
               FROM public.os_catalog_identifier ident
               JOIN public.os_catalog_item i ON i.id = ident.item_id
               JOIN public.os_catalog c ON c.id = i.catalog_id
               LEFT JOIN LATERAL (
                   SELECT ver.preferred_term
                     FROM public.os_catalog_item_version ver
                    WHERE ver.item_id = i.id
                    ORDER BY ver.id DESC
                    LIMIT 1
               ) latest ON TRUE
              WHERE ident.system_name = \'NOMENCLADOR-AR\'
                AND ident.value = :value
                AND c.code = \'oftar-pr\'
              ORDER BY i.id
              LIMIT 1',
            [':value' => $value]
        );
    }

    /**
     * Ítems buscables por código permanente, identificador o término.
     *
     * @return list<array<string, mixed>>
     */
    public function items(string $catalog, string $query): array
    {
        $params = [':q' => '%' . $query . '%', ':needle' => $query];
        $catalogWhere = '';

        if ($catalog !== '') {
            $catalogWhere .= ' AND c.code = :catalog';
            $params[':catalog'] = $catalog;
        }

        return self::readRows(
            'SELECT i.id, i.permanent_code, c.code AS catalog_code,'
            . ' COALESCE(latest.preferred_term, i.permanent_code) AS display,'
            . " (SELECT string_agg(COALESCE(si.system_name, '') || ':' || si.value, ', '"
            . ' ORDER BY si.is_primary DESC, si.id)'
            . ' FROM public.os_catalog_identifier si WHERE si.item_id = i.id) AS identifiers'
            . ' FROM public.os_catalog_item i'
            . ' JOIN public.os_catalog c ON c.id = i.catalog_id'
            . ' LEFT JOIN LATERAL ('
            . ' SELECT ver.preferred_term FROM public.os_catalog_item_version ver'
            . ' WHERE ver.item_id = i.id'
            . " ORDER BY (ver.language_code = 'es-AR') DESC, ver.id DESC"
            . ' LIMIT 1'
            . ' ) latest ON TRUE'
            . ' WHERE TRUE' . $catalogWhere
            . ' AND (i.permanent_code ILIKE :q'
            . " OR COALESCE(latest.preferred_term, '') ILIKE :q"
            . ' OR EXISTS (SELECT 1 FROM public.os_catalog_identifier si'
            . ' WHERE si.item_id = i.id AND si.value ILIKE :q)'
            . ' OR EXISTS (SELECT 1 FROM public.os_catalog_item_version sv'
            . ' JOIN public.os_catalog_term st ON st.item_version_id = sv.id'
            . ' WHERE sv.item_id = i.id AND st.term ILIKE :q))'
            . ' ORDER BY (lower(i.permanent_code) = lower(:needle)) DESC, i.permanent_code'
            . ' LIMIT 50',
            $params
        );
    }

    /** @return array<string, mixed>|null */
    public function item(int $id): ?array
    {
        if ($id <= 0) {
            return null;
        }

        return self::readRow(
            'SELECT i.id, i.permanent_code, c.code AS catalog_code, c.name AS catalog_name,'
            . ' COALESCE(latest.preferred_term, i.permanent_code) AS display,'
            . " (SELECT string_agg(COALESCE(si.system_name, '') || ':' || si.value, ', '"
            . ' ORDER BY si.is_primary DESC, si.id)'
            . ' FROM public.os_catalog_identifier si WHERE si.item_id = i.id) AS identifiers'
            . ' FROM public.os_catalog_item i'
            . ' JOIN public.os_catalog c ON c.id = i.catalog_id'
            . ' LEFT JOIN LATERAL ('
            . ' SELECT ver.preferred_term FROM public.os_catalog_item_version ver'
            . ' WHERE ver.item_id = i.id'
            . " ORDER BY (ver.language_code = 'es-AR') DESC, ver.id DESC"
            . ' LIMIT 1'
            . ' ) latest ON TRUE'
            . ' WHERE i.id = :id'
            . ' LIMIT 1',
            [':id' => $id]
        );
    }

    /** @return list<array<string, mixed>> */
    public function itemRelations(int $itemId): array
    {
        return self::readRows(
            'SELECT r.id,'
            . " CASE WHEN r.source_item_id = :id THEN 'out' ELSE 'in' END AS direction,"
            . ' src.permanent_code AS source_code, sc.code AS source_catalog,'
            . ' tgt.permanent_code AS target_code, tc.code AS target_catalog,'
            . ' r.relation_type, r.source_system_code, r.source_field, r.source_value,'
            . ' r.context_text, r.review_status, r.provenance'
            . ' FROM public.os_catalog_relation r'
            . ' JOIN public.os_catalog_item src ON src.id = r.source_item_id'
            . ' JOIN public.os_catalog sc ON sc.id = src.catalog_id'
            . ' JOIN public.os_catalog_item tgt ON tgt.id = r.target_item_id'
            . ' JOIN public.os_catalog tc ON tc.id = tgt.catalog_id'
            . ' WHERE r.source_item_id = :id OR r.target_item_id = :id2'
            . ' ORDER BY r.id DESC'
            . ' LIMIT ' . self::LIMIT,
            [':id' => $itemId, ':id2' => $itemId]
        );
    }

    /** @return list<array<string, mixed>> */
    public function itemMappings(int $itemId): array
    {
        return self::readRows(
            'SELECT m.id, i.permanent_code AS item_code, c.code AS catalog_code,'
            . ' sys.id AS system_id, sys.code AS system_code, m.external_code,'
            . ' m.external_display, m.mapping_type, m.relationship_role,'
            . ' m.clinical_rationale, m.review_status'
            . ' FROM public.os_concept_mapping m'
            . ' JOIN public.os_catalog_item i ON i.id = m.item_id'
            . ' JOIN public.os_catalog c ON c.id = i.catalog_id'
            . ' JOIN public.os_terminology_system sys ON sys.id = m.terminology_system_id'
            . ' WHERE m.item_id = :id'
            . ' ORDER BY m.id DESC'
            . ' LIMIT ' . self::LIMIT,
            [':id' => $itemId]
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, mixed> $actor
     */
    public function write(
        string $entity,
        string $action,
        int $id,
        array $payload,
        string $reason,
        array $actor
    ): void {
        $actorId = (int) ($actor['id'] ?? 0);
        $actorEmail = (string) ($actor['email'] ?? '');
        $encoded = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        if ($encoded === false) {
            throw new UvrGovernanceException('relation_invalid');
        }

        $pdo = AdminDatabase::connection();
        $pdo->beginTransaction();

        try {
            $statement = $pdo->prepare(
                'SELECT public.os_relation_admin_write('
                . ':entity, :action, :id, CAST(:payload AS jsonb), '
                . ':reason, :actor, :email)'
            );
            $statement->execute([
                ':entity' => $entity,
                ':action' => $action,
                ':id' => $id,
                ':payload' => $encoded,
                ':reason' => $reason,
                ':actor' => $actorId,
                ':email' => $actorEmail,
            ]);

            $raw = (string) $statement->fetchColumn();
            $result = json_decode($raw, true);

            if (!is_array($result)) {
                throw new UvrGovernanceException('relation_invalid');
            }

            AuditLogger::record('relation_' . $entity . '_' . $action, [
                'actor_user_id' => $actorId,
                'actor_email' => $actorEmail,
                'entity_type' => $entity,
                'entity_id' => (string) ($result['id'] ?? ''),
                'catalog_code' => $result['catalog_code'] ?? null,
                'before_state' => $result['before'] ?? null,
                'after_state' => $result['after'] ?? null,
                'reason' => $reason,
            ]);

            $pdo->commit();
        } catch (Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }

            if ($exception instanceof UvrGovernanceException
                || $exception instanceof RepositoryException
            ) {
                throw $exception;
            }

            throw new RepositoryException('relation_write_failed');
        }
    }

    /** @return list<array<string, mixed>> */
    private static function readRows(string $sql, array $params = []): array
    {
        try {
            $statement = PortalDatabase::connection()->prepare($sql);
            $statement->execute($params);

            return $statement->fetchAll();
        } catch (PDOException) {
            throw new RepositoryException('relation_read_unavailable');
        }
    }

    /** @return array<string, mixed>|null */
    private static function readRow(string $sql, array $params = []): ?array
    {
        try {
            $statement = PortalDatabase::connection()->prepare($sql);
            $statement->execute($params);
            $row = $statement->fetch();

            return $row === false ? null : $row;
        } catch (PDOException) {
            throw new RepositoryException('relation_read_unavailable');
        }
    }
}
