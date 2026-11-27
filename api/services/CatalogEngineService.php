<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Services;

use OrigenSalud\Api\Http\ApiException;
use OrigenSalud\Api\Http\Request;
use PDO;

/**
 * Origen Salud - Origen Catalog Engine Service
 *
 * Motor central de interoperabilidad sanitaria para catálogos clínicos,
 * arancelarios y farmacéuticos de Argentina y Latinoamérica.
 */
final class CatalogEngineService
{
    public function __construct(private readonly PDO $db)
    {
    }

    /**
     * GET /v1/catalogs
     * Lista todos los catálogos registrados.
     */
    public function listCatalogs(): array
    {
        $startedAt = hrtime(true);
        $sql = 'SELECT c.id, c.code, c.name, c.short_name, c.family_code, c.product_role,
                       c.organization, c.country_code, c.domain_type, c.description, c.website_url,
                       (SELECT count(*) FROM os_catalog_item i WHERE i.catalog_id = c.id AND i.status = \'active\') AS active_items_count
                  FROM os_catalog c
                 WHERE c.is_active = TRUE
                 ORDER BY CASE c.product_role WHEN \'family\' THEN 0 ELSE 1 END, c.code ASC';

        $stmt = $this->db->query($sql);
        $rows = $stmt->fetchAll();

        $catalogs = array_map(static fn (array $r): array => [
            'id' => (string) $r['id'],
            'code' => (string) $r['code'],
            'name' => (string) $r['name'],
            'short_name' => $r['short_name'] !== null ? (string) $r['short_name'] : null,
            'family' => $r['family_code'] !== null ? (string) $r['family_code'] : null,
            'role' => (string) $r['product_role'],
            'organization' => (string) $r['organization'],
            'country' => (string) $r['country_code'],
            'domain_type' => (string) $r['domain_type'],
            'description' => (string) $r['description'],
            'website' => $r['website_url'] !== null ? (string) $r['website_url'] : null,
            'items_count' => (int) $r['active_items_count'],
        ], $rows);

        return [
            'data' => $catalogs,
            'meta' => [
                'total' => count($catalogs),
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * GET /v1/catalogs/{catalogCode}/releases
     */
    public function listReleases(string $catalogCode): array
    {
        $startedAt = hrtime(true);
        $sql = 'SELECT r.id, r.version_tag, r.valid_from, r.valid_to, r.official_norm_reference, r.status
                  FROM os_catalog_release r
                  JOIN os_catalog c ON c.id = r.catalog_id
                 WHERE c.code = :cat_code
                 ORDER BY r.valid_from DESC';

        $stmt = $this->db->prepare($sql);
        $stmt->execute([':cat_code' => $catalogCode]);
        $rows = $stmt->fetchAll();

        return [
            'data' => array_map(static fn (array $r): array => [
                'release_id' => (string) $r['id'],
                'version' => (string) $r['version_tag'],
                'valid_from' => (string) $r['valid_from'],
                'valid_to' => $r['valid_to'] !== null ? (string) $r['valid_to'] : null,
                'normative' => $r['official_norm_reference'] !== null ? (string) $r['official_norm_reference'] : null,
                'status' => (string) $r['status'],
            ], $rows),
            'meta' => [
                'catalog' => $catalogCode,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * GET /v1/catalogs/{catalogCode}/items
     */
    public function listItems(string $catalogCode, Request $request): array
    {
        $startedAt = hrtime(true);
        $query = trim((string) ($request->query['q'] ?? $request->query['query'] ?? ''));
        $category = trim((string) ($request->query['category'] ?? ''));
        $limit = max(1, min(100, (int) ($request->query['limit'] ?? 20)));
        $offset = max(0, (int) ($request->query['offset'] ?? 0));

        $clinicalTables = $this->clinicalTablesAvailable();
        $clinicalSelect = $clinicalTables
            ? ', COALESCE(icc.clinical_category_code, ccm.clinical_category_code, ccd.clinical_category_code) AS clinical_category_code,
                     clin.name AS clinical_category_name'
            : '';
        $clinicalJoin = $clinicalTables
            ? ' LEFT JOIN os_catalog_item_clinical_category icc ON icc.item_id = item.id'
            . ' LEFT JOIN LATERAL ('
            . '     SELECT cm.clinical_category_code'
            . '       FROM os_catalog_item_version cv'
            . '       JOIN os_catalog_category_clinical_map cm ON cm.category_id = cv.category_id'
            . '      WHERE cv.item_id = item.id'
            . '      ORDER BY cv.id DESC LIMIT 1'
            . ' ) ccm ON TRUE'
            . ' LEFT JOIN os_catalog_clinical_default ccd ON ccd.catalog_code = cat.code'
            . ' LEFT JOIN os_clinical_category clin'
            . '   ON clin.code = COALESCE(icc.clinical_category_code, ccm.clinical_category_code, ccd.clinical_category_code)'
            : '';

        $sql = 'SELECT item.permanent_code,
                       ident.value AS official_code,
                       ver.preferred_term,
                       cat.code AS catalog_code,
                       categ.name AS category_name'
            . $clinicalSelect . ',
                       p_unit.code AS pricing_unit,
                       fee.units_amount,
                       fee.fixed_price
                  FROM os_catalog_item item
                  JOIN os_catalog cat ON cat.id = item.catalog_id
                  JOIN os_catalog_release rel ON rel.catalog_id = cat.id AND rel.status = \'published\'
                  JOIN os_catalog_item_version ver ON ver.item_id = item.id AND ver.release_id = rel.id
                  LEFT JOIN os_catalog_category categ ON categ.id = ver.category_id'
            . $clinicalJoin . '
                  LEFT JOIN os_catalog_identifier ident ON ident.item_id = item.id AND ident.is_primary = TRUE
                  LEFT JOIN os_fee_schedule f_sched ON f_sched.catalog_id = cat.id AND CURRENT_DATE BETWEEN f_sched.valid_from AND coalesce(f_sched.valid_to, CURRENT_DATE)
                  LEFT JOIN os_fee_item fee ON fee.item_id = item.id AND fee.fee_schedule_id = f_sched.id
                  LEFT JOIN os_pricing_unit p_unit ON p_unit.id = fee.pricing_unit_id
                 WHERE cat.code = :catalog_code
                   AND item.status = \'active\'';

        $params = [':catalog_code' => $catalogCode];

        if ($query !== '') {
            $sql .= ' AND (ver.preferred_term ILIKE :q OR ident.value ILIKE :q OR item.permanent_code ILIKE :q)';
            $params[':q'] = '%' . str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $query) . '%';
        }

        if ($category !== '') {
            if ($clinicalTables && str_starts_with($category, 'CLIN-')) {
                $explicit = 'SELECT 1 FROM os_catalog_item_clinical_category icc'
                    . ' WHERE icc.item_id = item.id AND icc.clinical_category_code = :category';
                $mapped = 'SELECT 1 FROM os_catalog_item_version cv'
                    . ' JOIN os_catalog_category_clinical_map cm ON cm.category_id = cv.category_id'
                    . ' WHERE cv.item_id = item.id AND cm.clinical_category_code = :category';
                $default = 'SELECT 1 FROM os_catalog_clinical_default ccd'
                    . ' WHERE ccd.catalog_code = cat.code AND ccd.clinical_category_code = :category';
                $sql .= ' AND (EXISTS (' . $explicit . ') OR EXISTS (' . $mapped . ')'
                    . ' OR (NOT EXISTS (' . $explicit . ') AND NOT EXISTS (' . $mapped . ')'
                    . ' AND EXISTS (' . $default . ')))';
                $params[':category'] = $category;
            } else {
                // Contrato histórico: el filtro `category` sigue aceptando el
                // capítulo fuente. La nueva dimensión se expone como
                // `clinical_category` sin romper deep links existentes.
                $sql .= ' AND (categ.code = :category OR categ.name ILIKE :category_like)';
                $params[':category'] = $category;
                $params[':category_like'] = '%' . $category . '%';
            }
        }

        $sql .= ' ORDER BY COALESCE(ident.value, item.permanent_code) ASC LIMIT :limit OFFSET :offset';

        $stmt = $this->db->prepare($sql);
        foreach ($params as $k => $v) {
            $stmt->bindValue($k, $v);
        }
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll();

        return [
            'data' => array_map(static function (array $r) use ($clinicalTables): array {
                return [
                    'permanent_code' => (string) $r['permanent_code'],
                    'official_code' => $r['official_code'] !== null ? (string) $r['official_code'] : null,
                    'term' => (string) $r['preferred_term'],
                    'category' => $r['category_name'] !== null ? (string) $r['category_name'] : null,
                    'clinical_category' => $clinicalTables && $r['clinical_category_name'] !== null
                        ? (string) $r['clinical_category_name']
                        : null,
                    'clinical_category_code' => $clinicalTables && $r['clinical_category_code'] !== null
                        ? (string) $r['clinical_category_code']
                        : null,
                    'pricing' => $r['pricing_unit'] !== null ? [
                        'unit_type' => (string) $r['pricing_unit'],
                        'units' => $r['units_amount'] !== null ? (float) $r['units_amount'] : null,
                        'fixed_price' => $r['fixed_price'] !== null ? (float) $r['fixed_price'] : null,
                    ] : null,
                ];
            }, $rows),
            'meta' => [
                'catalog' => $catalogCode,
                'query' => $query !== '' ? $query : null,
                'limit' => $limit,
                'offset' => $offset,
                'returned' => count($rows),
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * GET /v1/catalogs/{catalogCode}/items/{code}
     *
     * Fase 9: solo se publican campos aprobados. La versión, los sinónimos y
     * el texto localizado se evalúan por campo con EditorialEvaluator; cuando
     * no hay contenido aprobado el valor es null y se informa untranslated.
     */
    public function getItem(string $catalogCode, string $code, Request $request): array
    {
        $startedAt = hrtime(true);

        $catalogStatement = $this->db->prepare(
            'SELECT id, code, name, short_name, family_code
               FROM os_catalog
              WHERE code = :catalog_code AND is_active = TRUE
              LIMIT 1'
        );
        $catalogStatement->execute([':catalog_code' => $catalogCode]);
        $catalogRow = $catalogStatement->fetch();

        if ($catalogRow === false) {
            throw ApiException::notFound("No se encontró el elemento '{$code}' en el catálogo '{$catalogCode}'.");
        }

        $catalogId = (int) $catalogRow['id'];
        $catalog = LanguageCatalog::fromPdo($this->db, $catalogId);
        $resolution = LanguageResolver::fromPdo(
            $this->db,
            $catalogId,
            (string) env('API_DEFAULT_LANG', 'es')
        )->resolve($request);
        $requestedLanguage = $resolution->requestedLanguage;

        $clinicalTables = $this->clinicalTablesAvailable();
        $clinicalSelect = $clinicalTables
            ? ', COALESCE(icc.clinical_category_code, ccm.clinical_category_code, ccd.clinical_category_code) AS clinical_category_code,
                     clin.name AS clinical_category_name'
            : '';
        $clinicalJoin = $clinicalTables
            ? ' LEFT JOIN os_catalog_item_clinical_category icc ON icc.item_id = item.id'
            . ' LEFT JOIN LATERAL ('
            . '     SELECT cm.clinical_category_code'
            . '       FROM os_catalog_item_version cv'
            . '       JOIN os_catalog_category_clinical_map cm ON cm.category_id = cv.category_id'
            . '      WHERE cv.item_id = item.id'
            . '      ORDER BY cv.id DESC LIMIT 1'
            . ' ) ccm ON TRUE'
            . ' LEFT JOIN os_catalog_clinical_default ccd ON ccd.catalog_code = cat.code'
            . ' LEFT JOIN os_clinical_category clin'
            . '   ON clin.code = COALESCE(icc.clinical_category_code, ccm.clinical_category_code, ccd.clinical_category_code)'
            : '';

        $sql = 'SELECT item.id AS item_id,
                       item.permanent_code,
                       ident.value AS official_code,
                       ver.id AS version_id,
                       ver.release_id,
                       ver.language_code AS version_language,
                       ver.review_status AS version_review_status,
                       ver.source_language_code AS version_source_language,
                       ver.provenance AS version_provenance,
                       ver.content_hash AS version_content_hash,
                       ver.language_evidence AS version_language_evidence,
                        ver.source_reference AS version_source_reference,
                       ver.preferred_term,
                       ver.definition,
                       ver.clinical_criteria,
                       ver.short_definition,
                       ver.lay_terms,
                       ver.clinical_scope,
                       cat.code AS catalog_code,
                       cat.name AS catalog_native_name,
                       cat.short_name AS catalog_native_short_name,
                       cat.family_code AS catalog_family_code,
                       categ.id AS category_id,
                       categ.name AS category_native_name'
            . $clinicalSelect . ',
                       p_unit.code AS pricing_unit,
                       p_unit.name AS pricing_unit_name,
                       fee.units_amount,
                       fee.fixed_price,
                       fee.expenses_amount
                  FROM os_catalog_item item
                  JOIN os_catalog cat ON cat.id = item.catalog_id
                  JOIN os_catalog_release rel ON rel.catalog_id = cat.id AND rel.status = \'published\'
                  JOIN os_catalog_item_version ver ON ver.item_id = item.id AND ver.release_id = rel.id
                  LEFT JOIN os_catalog_category categ ON categ.id = ver.category_id'
            . $clinicalJoin . '
                  LEFT JOIN os_catalog_identifier ident ON ident.item_id = item.id
                  LEFT JOIN os_fee_schedule f_sched ON f_sched.catalog_id = cat.id AND CURRENT_DATE BETWEEN f_sched.valid_from AND coalesce(f_sched.valid_to, CURRENT_DATE)
                  LEFT JOIN os_fee_item fee ON fee.item_id = item.id AND fee.fee_schedule_id = f_sched.id
                  LEFT JOIN os_pricing_unit p_unit ON p_unit.id = fee.pricing_unit_id
                 WHERE cat.id = :catalog_id
                   AND (ident.value = :code OR replace(ident.value, \'.\', \'\') = :code_clean OR item.permanent_code = :code)
                 ORDER BY (ver.language_code = :requested_language) DESC, ver.id DESC';

        $statement = $this->db->prepare($sql);
        $statement->execute([
            ':catalog_id' => $catalogId,
            ':code' => $code,
            ':code_clean' => str_replace(['.', ' ', '-'], '', $code),
            ':requested_language' => $requestedLanguage,
        ]);

        $versionRows = [];
        $seenVersions = [];

        foreach ($statement->fetchAll() as $row) {
            $versionId = (int) $row['version_id'];

            if (!isset($seenVersions[$versionId])) {
                $seenVersions[$versionId] = true;
                $versionRows[] = $row;
            }
        }

        if ($versionRows === []) {
            throw ApiException::notFound("No se encontró el elemento '{$code}' en el catálogo '{$catalogCode}'.");
        }

        $preferred = $versionRows[0];
        $targetId = (int) $preferred['version_id'];
        $releaseId = (int) $preferred['release_id'];
        $itemId = (int) $preferred['item_id'];
        $versionIds = array_map(static fn (array $row): int => (int) $row['version_id'], $versionRows);

        $termStatement = $this->db->prepare(
            'SELECT id, item_version_id, term, term_type, language_code, review_status,
                    source_language_code, provenance, language_evidence, content_hash,
                    source_reference
               FROM os_catalog_term
              WHERE item_version_id IN (' . implode(', ', array_fill(0, count($versionIds), '?')) . ')
              ORDER BY id'
        );
        $termStatement->execute($versionIds);
        $terms = $termStatement->fetchAll();

        $categoryIds = [];

        foreach ($versionRows as $row) {
            if ($row['category_id'] !== null) {
                $categoryIds[(int) $row['category_id']] = true;
            }
        }

        $categoryIds = array_map('intval', array_keys($categoryIds));
        $localizedSql = 'SELECT id, entity_type, entity_id, field_name, language_code, value,
                                source_language_code, language_evidence, provenance, review_status,
                                content_hash, scope_release_id, source_reference
                           FROM os_localized_text
                          WHERE (entity_type = ? AND entity_id = ?)';
        $localizedParams = ['catalog', $catalogId];

        if ($categoryIds !== []) {
            $localizedSql .= ' OR (entity_type = ? AND entity_id IN ('
                . implode(', ', array_fill(0, count($categoryIds), '?')) . '))';
            $localizedParams[] = 'catalog_category';

            foreach ($categoryIds as $categoryId) {
                $localizedParams[] = $categoryId;
            }
        }

        $localizedSql .= ' ORDER BY id';
        $localizedStatement = $this->db->prepare($localizedSql);
        $localizedStatement->execute($localizedParams);
        $localizedRows = $localizedStatement->fetchAll();

        $clinicalFields = [
            'preferred_term',
            'definition',
            'clinical_criteria',
            'short_definition',
            'lay_terms',
            'clinical_scope',
        ];

        $fields = [];

        foreach ($clinicalFields as $field) {
            $fields[$field] = [];
        }

        $fields['synonyms'] = [];
        $fields['catalog_name'] = [];
        $fields['catalog_short_name'] = [];
        $fields['catalog_description'] = [];
        $fields['category_name'] = [];

        foreach ($versionRows as $row) {
            $base = [
                'language_code' => (string) $row['version_language'],
                'review_status' => (string) $row['version_review_status'],
                'source_language_code' => $row['version_source_language'] !== null
                    ? (string) $row['version_source_language']
                    : null,
                'provenance' => (string) $row['version_provenance'],
                'language_evidence' => (string) $row['version_language_evidence'],
                'content_hash' => (string) $row['version_content_hash'],
                'source_reference' => $row['version_source_reference'] !== null
                    ? (string) $row['version_source_reference']
                    : null,
                'target_id' => (int) $row['version_id'],
            ];

            foreach ($clinicalFields as $field) {
                if ($row[$field] !== null) {
                    $fields[$field][] = array_merge($base, ['value' => (string) $row[$field]]);
                }
            }
        }

        $synonymsByLanguage = [];

        foreach ($terms as $term) {
            $language = (string) $term['language_code'];
            $synonymsByLanguage[$language][] = [
                'language_code' => $language,
                'review_status' => (string) $term['review_status'],
                'source_language_code' => $term['source_language_code'] !== null
                    ? (string) $term['source_language_code']
                    : null,
                'provenance' => (string) $term['provenance'],
                'language_evidence' => (string) $term['language_evidence'],
                'content_hash' => (string) $term['content_hash'],
                'source_reference' => $term['source_reference'] !== null
                    ? (string) $term['source_reference']
                    : null,
                'target_id' => (int) $term['id'],
                'value' => (string) $term['term'],
                'term_type' => (string) $term['term_type'],
            ];
        }

        foreach ($synonymsByLanguage as $language => $variants) {
            $first = $variants[0];
            $fields['synonyms'][] = array_merge($first, [
                'value' => array_map(static fn (array $variant): array => [
                    'term' => $variant['value'],
                    'type' => $variant['term_type'],
                ], $variants),
            ]);
        }

        $localizedFieldMap = [
            'catalog.name' => 'catalog_name',
            'catalog.short_name' => 'catalog_short_name',
            'catalog.description' => 'catalog_description',
            'catalog_category.name' => 'category_name',
        ];

        foreach ($localizedRows as $row) {
            $key = (string) $row['entity_type'] . '.' . (string) $row['field_name'];
            $field = $localizedFieldMap[$key] ?? null;

            if ($field === null) {
                continue;
            }

            $fields[$field][] = [
                'language_code' => (string) $row['language_code'],
                'review_status' => (string) $row['review_status'],
                'source_language_code' => $row['source_language_code'] !== null
                    ? (string) $row['source_language_code']
                    : null,
                'provenance' => (string) $row['provenance'],
                'language_evidence' => (string) $row['language_evidence'],
                'content_hash' => (string) $row['content_hash'],
                'source_reference' => $row['source_reference'] !== null
                    ? (string) $row['source_reference']
                    : null,
                'target_id' => (int) $row['id'],
                'value' => (string) $row['value'],
            ];
        }

        $reviews = FieldReviewRepository::fromPdoForTargets(
            $this->db,
            ['os_catalog_item_version', 'os_catalog_term', 'os_localized_text'],
            array_merge(
                $versionIds,
                array_map(static fn (array $row): int => (int) $row['id'], $terms),
                array_map(static fn (array $row): int => (int) $row['id'], $localizedRows)
            ),
            array_keys(array_filter($fields, static fn (array $variants): bool => $variants !== []))
        );

        $editorial = (new EditorialEvaluator($catalog, $reviews))->evaluate([
            'target_table' => 'os_catalog_item_version',
            'target_id' => $targetId,
            'catalog_id' => $catalogId,
            'release_id' => $releaseId,
            'requested_language' => $requestedLanguage,
            'source_language_code' => $preferred['version_source_language'],
            'fields' => $fields,
        ]);

        $values = $editorial->values();
        $fieldLanguages = $editorial->fieldLanguages();
        $meta = $editorial->meta();
        $meta['available_languages'] = $editorial->availableLanguages();
        $meta['field_languages'] = $fieldLanguages;
        $meta['dialect_determined'] = $fieldLanguages['preferred_term']['dialect_determined'] ?? false;
        $meta['version_id'] = $targetId;
        $meta['review_status'] = (string) $preferred['version_review_status'];
        $meta['source_language_code'] = $preferred['version_source_language'];
        $meta['provenance'] = (string) $preferred['version_provenance'];

        // Mappings: dual-read condicionado (Fase 11). La columna original solo
        // se publica si D-19 dejó una revisión aprobada y vigente; si no,
        // display/rationale son null con untranslated=true.
        $mapStmt = $this->db->prepare(
            'SELECT m.id, sys.code AS system_code, sys.uri AS system_uri,
                    m.external_code, m.external_display, m.mapping_type,
                    m.relationship_role, m.clinical_rationale,
                    m.review_status, m.provenance, m.source_reference,
                    m.source_language_code, m.source_language_code_display,
                    m.language_evidence
               FROM os_concept_mapping m
               JOIN os_terminology_system sys ON sys.id = m.terminology_system_id
              WHERE m.item_id = :item_id'
        );
        $mapStmt->execute([':item_id' => $itemId]);
        $mappings = $mapStmt->fetchAll();

        $mappingReader = new MappingReviewReader($this->db, $catalog);
        $mappingResolution = $mappingReader->resolve($mappings, $requestedLanguage);

        $headers = ['Vary' => 'Accept-Language'];

        if ($meta['effective_language'] !== null && $meta['effective_language'] !== '') {
            $headers['Content-Language'] = (string) $meta['effective_language'];
        }

        return [
            'data' => [
                'catalog' => [
                    'code' => (string) $preferred['catalog_code'],
                    'name' => $values['catalog_name'] ?? $catalogRow['name'],
                    'short_name' => $values['catalog_short_name'] ?? $catalogRow['short_name'],
                    'family' => $catalogRow['family_code'] !== null ? (string) $catalogRow['family_code'] : null,
                ],
                'permanent_code' => $preferred['permanent_code'],
                'official_code' => $preferred['official_code'] !== null ? (string) $preferred['official_code'] : null,
                'preferred_term' => $values['preferred_term'] ?? null,
                'definition' => $values['definition'] ?? null,
                'clinical_criteria' => $values['clinical_criteria'] ?? null,
                'short_definition' => $values['short_definition'] ?? null,
                'lay_terms' => $values['lay_terms'] ?? null,
                'clinical_scope' => $values['clinical_scope'] ?? null,
                'synonyms' => $values['synonyms'] ?? [],
                'category' => $values['category_name'] ?? $preferred['category_native_name'],
                'clinical_category' => $clinicalTables && $preferred['clinical_category_name'] !== null
                    ? (string) $preferred['clinical_category_name']
                    : null,
                'clinical_category_code' => $clinicalTables && $preferred['clinical_category_code'] !== null
                    ? (string) $preferred['clinical_category_code']
                    : null,
                'pricing' => $preferred['pricing_unit'] !== null ? [
                    'unit_type' => $preferred['pricing_unit'],
                    'unit_name' => $preferred['pricing_unit_name'],
                    'units' => $preferred['units_amount'] !== null ? (float) $preferred['units_amount'] : null,
                    'fixed_price' => $preferred['fixed_price'] !== null ? (float) $preferred['fixed_price'] : null,
                    'expenses' => $preferred['expenses_amount'] !== null ? (float) $preferred['expenses_amount'] : null,
                ] : null,
                'mappings' => array_map(
                    static function (array $m) use ($mappingResolution): array {
                        $id = (int) $m['id'];
                        $resolved = $mappingResolution[$id] ?? null;
                        $languages = $resolved['field_languages'] ?? [];

                        return [
                            'system' => $m['system_code'],
                            'uri' => $m['system_uri'],
                            'code' => $m['external_code'],
                            'display' => $resolved['external_display'] ?? null,
                            'equivalence' => $m['mapping_type'],
                            'role' => $m['relationship_role'],
                            'rationale' => $resolved['clinical_rationale'] ?? null,
                            'field_languages' => $languages,
                            'untranslated' => (bool) ($resolved['untranslated'] ?? true),
                        ];
                    },
                    $mappings
                ),
            ],
            'meta' => $meta + [
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
            'headers' => $headers,
        ];
    }

    /**
     * GET /v1/mappings
     */
    public function searchMappings(Request $request): array
    {
        $startedAt = hrtime(true);
        $system = trim((string) ($request->query['system'] ?? ''));
        $code = trim((string) ($request->query['code'] ?? ''));
        $catalog = trim((string) ($request->query['catalog'] ?? ''));

        $sql = 'SELECT m.id,
                        cat.code AS catalog_code,
                       ident.value AS official_code,
                       ver.preferred_term,
                       sys.code AS target_system,
                       sys.uri AS target_uri,
                       m.external_code,
                       m.external_display,
                       m.mapping_type,
                       m.relationship_role,
                       m.clinical_rationale,
                       m.review_status, m.provenance, m.source_reference,
                       m.source_language_code, m.source_language_code_display,
                       m.language_evidence
                  FROM os_concept_mapping m
                  JOIN os_catalog_item item ON item.id = m.item_id
                  JOIN os_catalog cat ON cat.id = item.catalog_id
                  JOIN os_catalog_release rel ON rel.catalog_id = cat.id AND rel.status = \'published\'
                  JOIN os_catalog_item_version ver ON ver.item_id = item.id AND ver.release_id = rel.id
                  JOIN os_terminology_system sys ON sys.id = m.terminology_system_id
                  LEFT JOIN os_catalog_identifier ident ON ident.item_id = item.id AND ident.is_primary = TRUE
                 WHERE 1=1';

        $params = [];
        if ($system !== '') {
            $sql .= ' AND upper(sys.code) = upper(:system)';
            $params[':system'] = $system;
        }
        if ($code !== '') {
            $sql .= ' AND (m.external_code = :code OR ident.value = :code OR replace(ident.value, \'.\', \'\') = :code_clean)';
            $params[':code'] = $code;
            $params[':code_clean'] = str_replace(['.', ' ', '-'], '', $code);
        }
        if ($catalog !== '') {
            $sql .= ' AND cat.code = :catalog';
            $params[':catalog'] = $catalog;
        }

        $sql .= ' ORDER BY cat.code ASC, ident.value ASC LIMIT 50';

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();

        $catalog = LanguageCatalog::fromPdo($this->db, null);
        $requestedLanguage = LanguageResolver::fromPdo(
            $this->db,
            null,
            (string) env('API_DEFAULT_LANG', 'es')
        )->resolve($request)->requestedLanguage;
        $mappingReader = new MappingReviewReader($this->db, $catalog);
        $mappingResolution = $mappingReader->resolve($rows, $requestedLanguage);

        return [
            'data' => array_map(
                static function (array $r) use ($mappingResolution): array {
                    $id = (int) $r['id'];
                    $resolved = $mappingResolution[$id] ?? null;

                    return [
                        'catalog' => $r['catalog_code'],
                        'catalog_code' => $r['official_code'] !== null ? (string) $r['official_code'] : null,
                        'term' => $r['preferred_term'],
                        'target_system' => $r['target_system'],
                        'target_uri' => $r['target_uri'],
                        'target_code' => $r['external_code'],
                        'target_display' => $resolved['external_display'] ?? null,
                        'equivalence' => $r['mapping_type'],
                        'role' => $r['relationship_role'],
                        'rationale' => $resolved['clinical_rationale'] ?? null,
                        'field_languages' => $resolved['field_languages'] ?? [],
                        'untranslated' => (bool) ($resolved['untranslated'] ?? true),
                    ];
                },
                $rows
            ),
            'meta' => [
                'total' => count($rows),
                'requested_language' => $requestedLanguage,
                'untranslated' => array_reduce(
                    $rows,
                    static fn (bool $carry, array $r): bool => $carry
                        || ($mappingResolution[(int) $r['id']]['untranslated'] ?? true),
                    false
                ),
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
            'headers' => ['Vary' => 'Accept-Language'],
        ];
    }

    /**
     * GET /v1/pricing-units
     */
    public function listPricingUnits(): array
    {
        $startedAt = hrtime(true);
        $stmt = $this->db->query('SELECT code, name, organization, description FROM os_pricing_unit ORDER BY id ASC');
        $rows = $stmt->fetchAll();

        return [
            'data' => $rows,
            'meta' => [
                'total' => count($rows),
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * GET /v1/medicines/identifiers/{system}/{code}
     */
    public function findMedicineByIdentifier(string $system, string $code): array
    {
        $startedAt = hrtime(true);
        $system = strtoupper(trim($system));
        $code = trim($code);

        $sql = 'SELECT p.id AS package_id,
                       p.presentation_text,
                       p.dosage_form,
                       p.sale_type,
                       prod.brand_name,
                       prod.laboratory,
                       prod.pharmacological_action,
                       sub.name AS substance_name,
                       sub.atc_code,
                       ident.system_code,
                       ident.identifier_value
                  FROM os_product_identifier ident
                  JOIN os_product_package p ON p.id = ident.package_id
                  JOIN os_medicinal_product prod ON prod.id = p.product_id
                  JOIN os_substance sub ON sub.id = prod.substance_id
                 WHERE ident.system_code = :sys AND ident.identifier_value = :code
                 LIMIT 1';

        $stmt = $this->db->prepare($sql);
        $stmt->execute([':sys' => $system, ':code' => $code]);
        $row = $stmt->fetch();

        if ($row === false) {
            throw ApiException::notFound("No se encontró ningún medicamento con identificador {$system}: {$code}.");
        }

        $packageId = (int) $row['package_id'];
        $allIdentStmt = $this->db->prepare('SELECT system_code, identifier_value FROM os_product_identifier WHERE package_id = :pkg_id');
        $allIdentStmt->execute([':pkg_id' => $packageId]);
        $allIdentifiers = $allIdentStmt->fetchAll();

        return [
            'data' => [
                'brand_name' => $row['brand_name'],
                'laboratory' => $row['laboratory'],
                'ingredient' => [
                    'name' => $row['substance_name'],
                    'atc_code' => $row['atc_code'],
                ],
                'presentation' => $row['presentation_text'],
                'dosage_form' => $row['dosage_form'],
                'sale_type' => $row['sale_type'],
                'pharmacological_action' => $row['pharmacological_action'],
                'identifiers' => array_column($allIdentifiers, 'identifier_value', 'system_code'),
            ],
            'meta' => [
                'matched_system' => $system,
                'matched_code' => $code,
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
        ];
    }

    /**
     * La taxonomía clínica es aditiva: si la migración no fue aplicada, el
     * contrato histórico sigue funcionando con `category` y sin la nueva
     * dimensión. La comprobación se hace contra el catálogo del sistema.
     */
    private function clinicalTablesAvailable(): bool
    {
        static $available = null;

        if ($available !== null) {
            return $available;
        }

        $tables = [
            'os_clinical_category',
            'os_catalog_category_clinical_map',
            'os_catalog_clinical_default',
            'os_catalog_item_clinical_category',
        ];

        $available = true;

        foreach ($tables as $table) {
            $statement = $this->db->prepare('SELECT to_regclass(:name) IS NOT NULL');
            $statement->execute([':name' => 'public.' . $table]);

            if (!(bool) $statement->fetchColumn()) {
                $available = false;
                break;
            }
        }

        return $available;
    }
}
