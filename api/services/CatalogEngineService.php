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
        $sql = 'SELECT c.id, c.code, c.name, c.organization, c.country_code, c.domain_type, c.description, c.website_url,
                       (SELECT count(*) FROM os_catalog_item i WHERE i.catalog_id = c.id AND i.status = \'active\') AS active_items_count
                  FROM os_catalog c
                 WHERE c.is_active = TRUE
                 ORDER BY c.id ASC';

        $stmt = $this->db->query($sql);
        $rows = $stmt->fetchAll();

        $catalogs = array_map(static fn (array $r): array => [
            'id' => (string) $r['id'],
            'code' => (string) $r['code'],
            'name' => (string) $r['name'],
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

        $sql = 'SELECT item.permanent_code,
                       ident.value AS official_code,
                       ver.preferred_term,
                       cat.code AS catalog_code,
                       categ.name AS category_name,
                       p_unit.code AS pricing_unit,
                       fee.units_amount,
                       fee.fixed_price
                  FROM os_catalog_item item
                  JOIN os_catalog cat ON cat.id = item.catalog_id
                  JOIN os_catalog_release rel ON rel.catalog_id = cat.id AND rel.status = \'published\'
                  JOIN os_catalog_item_version ver ON ver.item_id = item.id AND ver.release_id = rel.id
                  LEFT JOIN os_catalog_category categ ON categ.id = ver.category_id
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
            $sql .= ' AND (categ.code = :category OR categ.name ILIKE :category_like)';
            $params[':category'] = $category;
            $params[':category_like'] = '%' . $category . '%';
        }

        $sql .= ' ORDER BY ident.value ASC LIMIT :limit OFFSET :offset';

        $stmt = $this->db->prepare($sql);
        foreach ($params as $k => $v) {
            $stmt->bindValue($k, $v);
        }
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll();

        return [
            'data' => array_map(static fn (array $r): array => [
                'permanent_code' => (string) $r['permanent_code'],
                'official_code' => (string) $r['official_code'],
                'term' => (string) $r['preferred_term'],
                'category' => $r['category_name'] !== null ? (string) $r['category_name'] : null,
                'pricing' => $r['pricing_unit'] !== null ? [
                    'unit_type' => (string) $r['pricing_unit'],
                    'units' => $r['units_amount'] !== null ? (float) $r['units_amount'] : null,
                    'fixed_price' => $r['fixed_price'] !== null ? (float) $r['fixed_price'] : null,
                ] : null,
            ], $rows),
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
     */
    public function getItem(string $catalogCode, string $code): array
    {
        $startedAt = hrtime(true);
        $sql = 'SELECT item.id AS item_id,
                       item.permanent_code,
                       ident.value AS official_code,
                       ver.preferred_term,
                       ver.definition,
                       ver.clinical_criteria,
                       cat.code AS catalog_code,
                       cat.name AS catalog_name,
                       categ.name AS category_name,
                       p_unit.code AS pricing_unit,
                       p_unit.name AS pricing_unit_name,
                       fee.units_amount,
                       fee.fixed_price,
                       fee.expenses_amount
                  FROM os_catalog_item item
                  JOIN os_catalog cat ON cat.id = item.catalog_id
                  JOIN os_catalog_release rel ON rel.catalog_id = cat.id AND rel.status = \'published\'
                  JOIN os_catalog_item_version ver ON ver.item_id = item.id AND ver.release_id = rel.id
                  LEFT JOIN os_catalog_category categ ON categ.id = ver.category_id
                  LEFT JOIN os_catalog_identifier ident ON ident.item_id = item.id
                  LEFT JOIN os_fee_schedule f_sched ON f_sched.catalog_id = cat.id AND CURRENT_DATE BETWEEN f_sched.valid_from AND coalesce(f_sched.valid_to, CURRENT_DATE)
                  LEFT JOIN os_fee_item fee ON fee.item_id = item.id AND fee.fee_schedule_id = f_sched.id
                  LEFT JOIN os_pricing_unit p_unit ON p_unit.id = fee.pricing_unit_id
                 WHERE cat.code = :catalog_code
                   AND (ident.value = :code OR replace(ident.value, \'.\', \'\') = :code_clean OR item.permanent_code = :code)
                 LIMIT 1';

        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            ':catalog_code' => $catalogCode,
            ':code' => $code,
            ':code_clean' => str_replace(['.', ' ', '-'], '', $code),
        ]);
        $row = $stmt->fetch();

        if ($row === false) {
            throw ApiException::notFound("No se encontró el elemento '{$code}' en el catálogo '{$catalogCode}'.");
        }

        $itemId = (int) $row['item_id'];

        // Mappings
        $mapStmt = $this->db->prepare(
            'SELECT sys.code AS system_code, sys.uri AS system_uri, m.external_code, m.external_display, m.mapping_type, m.relationship_role, m.clinical_rationale
               FROM os_concept_mapping m
               JOIN os_terminology_system sys ON sys.id = m.terminology_system_id
              WHERE m.item_id = :item_id'
        );
        $mapStmt->execute([':item_id' => $itemId]);
        $mappings = $mapStmt->fetchAll();

        return [
            'data' => [
                'catalog' => [
                    'code' => $row['catalog_code'],
                    'name' => $row['catalog_name'],
                ],
                'permanent_code' => $row['permanent_code'],
                'official_code' => $row['official_code'],
                'preferred_term' => $row['preferred_term'],
                'definition' => $row['definition'],
                'category' => $row['category_name'],
                'pricing' => $row['pricing_unit'] !== null ? [
                    'unit_type' => $row['pricing_unit'],
                    'unit_name' => $row['pricing_unit_name'],
                    'units' => $row['units_amount'] !== null ? (float) $row['units_amount'] : null,
                    'fixed_price' => $row['fixed_price'] !== null ? (float) $row['fixed_price'] : null,
                    'expenses' => $row['expenses_amount'] !== null ? (float) $row['expenses_amount'] : null,
                ] : null,
                'mappings' => array_map(static fn (array $m): array => [
                    'system' => $m['system_code'],
                    'uri' => $m['system_uri'],
                    'code' => $m['external_code'],
                    'display' => $m['external_display'],
                    'equivalence' => $m['mapping_type'],
                    'role' => $m['relationship_role'],
                    'rationale' => $m['clinical_rationale'],
                ], $mappings),
            ],
            'meta' => [
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
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

        $sql = 'SELECT cat.code AS catalog_code,
                       ident.value AS official_code,
                       ver.preferred_term,
                       sys.code AS target_system,
                       sys.uri AS target_uri,
                       m.external_code,
                       m.external_display,
                       m.mapping_type,
                       m.relationship_role,
                       m.clinical_rationale
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

        return [
            'data' => array_map(static fn (array $r): array => [
                'catalog' => $r['catalog_code'],
                'catalog_code' => $r['official_code'],
                'term' => $r['preferred_term'],
                'target_system' => $r['target_system'],
                'target_uri' => $r['target_uri'],
                'target_code' => $r['external_code'],
                'target_display' => $r['external_display'],
                'equivalence' => $r['mapping_type'],
                'role' => $r['relationship_role'],
                'rationale' => $r['clinical_rationale'],
            ], $rows),
            'meta' => [
                'total' => count($rows),
                'took_ms' => round((hrtime(true) - $startedAt) / 1_000_000, 2),
            ],
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
}
