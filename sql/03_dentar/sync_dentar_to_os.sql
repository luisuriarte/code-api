-- =============================================================================
-- Origen Salud · Sincronización familia DENTAR (dentar_*) -> Origen Catalog Engine (os_*)
-- =============================================================================
--
-- POR QUÉ EXISTE
--   La familia DENTAR tiene dos representaciones:
--     · dentar_*  → modelo editorial completo (versiones, términos, mapeos,
--                   diagnósticos). Es donde escribe tools/php/import_dentar_csv.php.
--     · os_*      → modelo que consume GET /v1/catalogs, /v1/mappings y
--                   /v1/pricing-units (Origen Catalog Engine).
--   Sin esta sincronización, los códigos cargados por CSV quedan visibles en
--   dentar_* pero no en la API de catálogos.
--
-- MODELO DE FAMILIA
--   'dentar'    → marca paraguas. No publica releases, ítems ni aranceles.
--   'dentar-pr' → DENTAR-PR, procedimientos (DNT-PR-NNNNNN).
--   'dentar-dx' → DENTAR-DX, diagnósticos (DNT-DX-NNNNNN).
--   Cada producto tiene su propia release, calculada a partir de su propia
--   versión editorial. No comparten numeración ni ciclo de publicación.
--
-- CUÁNDO SE EJECUTA
--   Lo ejecuta automáticamente tools/php/import_dentar_csv.php al final de la
--   misma transacción. También se puede correr a mano:
--     psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/sync_dentar_to_os.sql
--
-- QUÉ HACE
--   1. Publica una release por producto: '2026-v1' para la versión 1 y
--      'DENTAR-PR-vN' / 'DENTAR-DX-vN' para versiones editoriales posteriores.
--      Las demás releases publicadas de ese producto pasan a 'deprecated'.
--   2. Copia categorías, conceptos, versión vigente, sinónimos, identificadores
--      (NOMENCLADOR_AR en PR, CIE-10 en DX) y mapeos externos.
--   3. Marca 'retired' los ítems que ya no existen en el modelo editorial.
--   4. No toca aranceles (os_fee_item): el precio vive en el arancel, no en el
--      concepto. Se cargan aparte.
--
-- Es idempotente: se puede correr todas las veces que haga falta.
-- =============================================================================
SET client_encoding = 'UTF8';

-- Fase 11: identidad de importador para la auditoría de os_* (D-23, D-32).
-- Si el importador PHP ya fijó un run_id, se conserva; si el script se ejecuta
-- suelto, se genera uno alfanumérico sin usar SESSION_USER como actor real.
SELECT set_config(
    'app.importer_run_id',
    COALESCE(
        NULLIF(current_setting('app.importer_run_id', TRUE), ''),
        'sync_dentar_to_os:' || txid_current()::TEXT
    ),
    TRUE
);

-- -----------------------------------------------------------------------------
-- 0. Verificación de catálogos
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM os_catalog WHERE code = 'dentar-pr' AND product_role = 'catalog') THEN
        RAISE EXCEPTION
            'Falta el catálogo DENTAR-PR en os_catalog.'
            USING HINT = 'Ejecutá sql/origen_catalog_engine.sql antes de sincronizar.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM os_catalog WHERE code = 'dentar-dx' AND product_role = 'catalog') THEN
        RAISE EXCEPTION
            'Falta el catálogo DENTAR-DX en os_catalog.'
            USING HINT = 'Ejecutá sql/origen_catalog_engine.sql antes de sincronizar.';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 1. Releases publicadas por producto
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS _dentar_sync_release;
CREATE TEMP TABLE _dentar_sync_release (
    catalog_code   TEXT PRIMARY KEY,
    catalog_id     INT NOT NULL,
    version_number INT NOT NULL,
    release_tag    TEXT NOT NULL,
    valid_from     DATE NOT NULL,
    release_id     INT
);

INSERT INTO _dentar_sync_release (catalog_code, catalog_id, version_number, release_tag, valid_from)
SELECT 'dentar-pr',
       c.id,
       v.max_version,
       CASE WHEN v.max_version <= 1 THEN '2026-v1'
            ELSE 'DENTAR-PR-v' || v.max_version::text END,
       v.valid_from
  FROM os_catalog c
  CROSS JOIN LATERAL (
      SELECT COALESCE(max(cv.version_number), 1) AS max_version,
             COALESCE(min(cv.effective_from), CURRENT_DATE) AS valid_from
        FROM dentar_concept dc
        JOIN dentar_concept_version cv ON cv.concept_id = dc.id
       WHERE dc.catalog_id = dentar_catalog_id('dentar-pr')
  ) v
 WHERE c.code = 'dentar-pr';

INSERT INTO _dentar_sync_release (catalog_code, catalog_id, version_number, release_tag, valid_from)
SELECT 'dentar-dx',
       c.id,
       v.max_version,
       CASE WHEN v.max_version <= 1 THEN '2026-v1'
            ELSE 'DENTAR-DX-v' || v.max_version::text END,
       v.valid_from
  FROM os_catalog c
  CROSS JOIN LATERAL (
      SELECT COALESCE(max(dv.version_number), 1) AS max_version,
             COALESCE(min(dv.effective_from), CURRENT_DATE) AS valid_from
        FROM dentar_diagnosis d
        JOIN dentar_diagnosis_version dv ON dv.diagnosis_id = d.id
       WHERE d.catalog_id = dentar_catalog_id('dentar-dx')
  ) v
 WHERE c.code = 'dentar-dx';

INSERT INTO os_catalog_release (catalog_id, version_tag, valid_from, official_norm_reference, status)
SELECT rel.catalog_id,
       rel.release_tag,
       rel.valid_from,
       CASE rel.catalog_code
            WHEN 'dentar-pr' THEN 'Catálogo DENTAR-PR (importación CSV)'
            ELSE 'Catálogo DENTAR-DX (importación CSV)'
       END,
       'published'
  FROM _dentar_sync_release rel
ON CONFLICT (catalog_id, version_tag)
DO UPDATE SET status = 'published',
              official_norm_reference = EXCLUDED.official_norm_reference;

UPDATE _dentar_sync_release rel
   SET release_id = r.id
  FROM os_catalog_release r
 WHERE r.catalog_id = rel.catalog_id
   AND r.version_tag = rel.release_tag;

DO $$
DECLARE
    v_faltantes INT;
BEGIN
    SELECT count(*) INTO v_faltantes
      FROM _dentar_sync_release
     WHERE release_id IS NULL;

    IF v_faltantes > 0 THEN
        RAISE EXCEPTION 'No se pudieron resolver % releases DENTAR para sincronizar.', v_faltantes;
    END IF;
END $$;

UPDATE os_catalog_release r
   SET status = 'deprecated'
  FROM _dentar_sync_release rel
 WHERE r.catalog_id = rel.catalog_id
   AND r.id <> rel.release_id
   AND r.status = 'published';

-- -----------------------------------------------------------------------------
-- 2. Versiones vigentes (aprobadas y de número más alto)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS _dentar_sync_latest;
CREATE TEMP TABLE _dentar_sync_latest AS
SELECT cv.id AS version_id,
       cv.concept_id,
       cv.version_number,
       cv.definition,
       cv.clinical_criteria
  FROM dentar_concept_version cv
  JOIN dentar_concept dc ON dc.id = cv.concept_id
 WHERE dc.catalog_id = dentar_catalog_id('dentar-pr')
   AND cv.approval_status = 'approved'
   AND cv.version_number = (
       SELECT max(v2.version_number)
         FROM dentar_concept_version v2
        WHERE v2.concept_id = cv.concept_id
          AND v2.approval_status = 'approved'
   );

DROP TABLE IF EXISTS _dentar_sync_latest_dx;
CREATE TEMP TABLE _dentar_sync_latest_dx AS
SELECT dv.id AS version_id,
       dv.diagnosis_id,
       dv.version_number,
       dv.definition,
       dv.clinical_criteria
  FROM dentar_diagnosis_version dv
  JOIN dentar_diagnosis d ON d.id = dv.diagnosis_id
 WHERE d.catalog_id = dentar_catalog_id('dentar-dx')
   AND dv.approval_status = 'approved'
   AND dv.version_number = (
       SELECT max(v2.version_number)
         FROM dentar_diagnosis_version v2
        WHERE v2.diagnosis_id = dv.diagnosis_id
          AND v2.approval_status = 'approved'
   );

-- -----------------------------------------------------------------------------
-- 3. Categorías
-- -----------------------------------------------------------------------------
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT rel.catalog_id,
       dc.code,
       COALESCE(dcv.name, dc.code)
  FROM dentar_category dc
  JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-pr'
  LEFT JOIN LATERAL (
       SELECT v.name
         FROM dentar_category_version v
        WHERE v.category_id = dc.id
          AND v.language = 'es-AR'
        ORDER BY v.version_number DESC
        LIMIT 1
  ) dcv ON TRUE
 WHERE dc.catalog_id = dentar_catalog_id('dentar-pr')
   AND dc.status = 'active'
ON CONFLICT (catalog_id, code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT rel.catalog_id,
       dc.code,
       COALESCE(dcv.name, dc.code)
  FROM dentar_category dc
  JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-dx'
  LEFT JOIN LATERAL (
       SELECT v.name
         FROM dentar_category_version v
        WHERE v.category_id = dc.id
          AND v.language = 'es-AR'
        ORDER BY v.version_number DESC
        LIMIT 1
  ) dcv ON TRUE
 WHERE dc.catalog_id = dentar_catalog_id('dentar-dx')
   AND dc.status = 'active'
ON CONFLICT (catalog_id, code) DO UPDATE SET name = EXCLUDED.name;

-- -----------------------------------------------------------------------------
-- 4.1 DENTAR-PR · conceptos permanentes (os_catalog_item)
-- -----------------------------------------------------------------------------
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT rel.catalog_id,
       dc.code,
       CASE dc.lifecycle_status
            WHEN 'retired' THEN 'retired'
            ELSE 'active'
       END
  FROM dentar_concept dc
  JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-pr'
 WHERE dc.catalog_id = dentar_catalog_id('dentar-pr')
ON CONFLICT (catalog_id, permanent_code) DO UPDATE SET status = EXCLUDED.status;

UPDATE os_catalog_item i
   SET status = 'retired'
  FROM _dentar_sync_release rel
 WHERE i.catalog_id = rel.catalog_id
   AND rel.catalog_code = 'dentar-pr'
   AND i.status = 'active'
   AND NOT EXISTS (
       SELECT 1
         FROM dentar_concept dc
        WHERE dc.code = i.permanent_code
          AND dc.catalog_id = dentar_catalog_id('dentar-pr')
   );

-- -----------------------------------------------------------------------------
-- 4.2 DENTAR-PR · versión vigente (os_catalog_item_version)
-- -----------------------------------------------------------------------------
INSERT INTO os_catalog_item_version
    (item_id, release_id, category_id, preferred_term, definition, clinical_criteria, language_code)
SELECT i.id,
       rel.release_id,
       cat.category_id,
       COALESCE(pref.term, left(l.definition, 255)),
       l.definition,
       l.clinical_criteria,
       'es-AR'
  FROM _dentar_sync_latest l
  JOIN dentar_concept dc ON dc.id = l.concept_id
  JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-pr'
  JOIN os_catalog_item i
    ON i.catalog_id = rel.catalog_id
   AND i.permanent_code = dc.code
  LEFT JOIN LATERAL (
       SELECT t.term
         FROM dentar_term t
        WHERE t.concept_version_id = l.version_id
          AND t.term_type = 'preferred'
          AND t.language = 'es-AR'
        ORDER BY t.id DESC
        LIMIT 1
  ) pref ON TRUE
  LEFT JOIN LATERAL (
       SELECT occ.id AS category_id
         FROM dentar_concept_category cc
         JOIN dentar_category dcat ON dcat.id = cc.category_id
         JOIN os_catalog_category occ
           ON occ.catalog_id = rel.catalog_id
          AND occ.code = dcat.code
        WHERE cc.concept_version_id = l.version_id
        ORDER BY cc.is_primary DESC, occ.code
        LIMIT 1
  ) cat ON TRUE
ON CONFLICT (item_id, release_id, language_code) DO UPDATE
   SET category_id       = EXCLUDED.category_id,
       preferred_term    = EXCLUDED.preferred_term,
       definition        = EXCLUDED.definition,
       clinical_criteria = EXCLUDED.clinical_criteria;

-- -----------------------------------------------------------------------------
-- 4.3 DENTAR-PR · términos alternativos (os_catalog_term)
-- -----------------------------------------------------------------------------
DELETE FROM os_catalog_term t
 USING os_catalog_item_version iv, os_catalog_item i, _dentar_sync_release rel
 WHERE t.item_version_id = iv.id
   AND iv.item_id = i.id
   AND i.catalog_id = rel.catalog_id
   AND iv.release_id = rel.release_id;

INSERT INTO os_catalog_term (item_version_id, term, term_type, language_code)
SELECT iv.id,
       left(t.term, 255),
       CASE t.term_type
            WHEN 'abbreviation' THEN 'acronym'
            ELSE 'synonym'
       END,
       'es-AR'
  FROM dentar_term t
  JOIN _dentar_sync_latest l ON l.version_id = t.concept_version_id
  JOIN dentar_concept dc ON dc.id = l.concept_id
  JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-pr'
  JOIN os_catalog_item i
    ON i.catalog_id = rel.catalog_id
   AND i.permanent_code = dc.code
  JOIN os_catalog_item_version iv
    ON iv.item_id = i.id
   AND iv.release_id = rel.release_id
 WHERE t.language = 'es-AR'
   AND t.term_type <> 'preferred';

-- -----------------------------------------------------------------------------
-- 4.4 DENTAR-PR · identificador del Nomenclador Argentino
-- El código nacional se conserva como identificador secundario y buscable.
-- DENTAR-PR sigue siendo el código permanente principal de la ficha.
-- -----------------------------------------------------------------------------
DELETE FROM os_catalog_identifier ident
 USING os_catalog_item i, _dentar_sync_release rel
 WHERE ident.item_id = i.id
   AND i.catalog_id = rel.catalog_id
   AND rel.catalog_code = 'dentar-pr'
   AND ident.system_name = 'NOMENCLADOR_AR';

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT x.item_id, 'NOMENCLADOR_AR', x.external_code, FALSE
  FROM (
      SELECT i.id AS item_id,
             m.external_code,
             row_number() OVER (PARTITION BY i.id ORDER BY m.external_code) AS rn
        FROM dentar_concept_mapping m
        JOIN _dentar_sync_latest l ON l.version_id = m.concept_version_id
        JOIN dentar_concept dc ON dc.id = l.concept_id
        JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-pr'
        JOIN os_catalog_item i
          ON i.catalog_id = rel.catalog_id
         AND i.permanent_code = dc.code
       WHERE m.system_code = 'NOMENCLADOR-AR'
  ) x
ON CONFLICT (item_id, system_name, value) DO UPDATE SET is_primary = EXCLUDED.is_primary;

-- -----------------------------------------------------------------------------
-- 5.1 DENTAR-DX · diagnósticos permanentes (os_catalog_item)
-- -----------------------------------------------------------------------------
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT rel.catalog_id,
       d.code,
       CASE d.status
            WHEN 'retired' THEN 'retired'
            WHEN 'inactive' THEN 'retired'
            ELSE 'active'
       END
  FROM dentar_diagnosis d
  JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-dx'
 WHERE d.catalog_id = dentar_catalog_id('dentar-dx')
ON CONFLICT (catalog_id, permanent_code) DO UPDATE SET status = EXCLUDED.status;

UPDATE os_catalog_item i
   SET status = 'retired'
  FROM _dentar_sync_release rel
 WHERE i.catalog_id = rel.catalog_id
   AND rel.catalog_code = 'dentar-dx'
   AND i.status = 'active'
   AND NOT EXISTS (
       SELECT 1
         FROM dentar_diagnosis d
        WHERE d.code = i.permanent_code
          AND d.catalog_id = dentar_catalog_id('dentar-dx')
   );

-- -----------------------------------------------------------------------------
-- 5.2 DENTAR-DX · versión vigente (os_catalog_item_version)
-- -----------------------------------------------------------------------------
INSERT INTO os_catalog_item_version
    (item_id, release_id, category_id, preferred_term, definition, clinical_criteria, language_code)
SELECT i.id,
       rel.release_id,
       cat.category_id,
       COALESCE(pref.term, d.clinical_name),
       l.definition,
       l.clinical_criteria,
       'es-AR'
  FROM _dentar_sync_latest_dx l
  JOIN dentar_diagnosis d ON d.id = l.diagnosis_id
  JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-dx'
  JOIN os_catalog_item i
    ON i.catalog_id = rel.catalog_id
   AND i.permanent_code = d.code
  LEFT JOIN LATERAL (
       SELECT dt.term
         FROM dentar_diagnosis_term dt
        WHERE dt.diagnosis_id = d.id
          AND dt.term_type = 'preferred'
          AND dt.language = 'es-AR'
        ORDER BY dt.id DESC
        LIMIT 1
  ) pref ON TRUE
  LEFT JOIN LATERAL (
       SELECT occ.id AS category_id
         FROM dentar_category dcat
         JOIN os_catalog_category occ
           ON occ.catalog_id = rel.catalog_id
          AND occ.code = dcat.code
        WHERE dcat.id = d.category_id
        LIMIT 1
  ) cat ON TRUE
ON CONFLICT (item_id, release_id, language_code) DO UPDATE
   SET category_id       = EXCLUDED.category_id,
       preferred_term    = EXCLUDED.preferred_term,
       definition        = EXCLUDED.definition,
       clinical_criteria = EXCLUDED.clinical_criteria;

-- -----------------------------------------------------------------------------
-- 5.3 DENTAR-DX · términos alternativos (os_catalog_term)
-- -----------------------------------------------------------------------------
INSERT INTO os_catalog_term (item_version_id, term, term_type, language_code)
SELECT iv.id,
       left(dt.term, 255),
       CASE dt.term_type
            WHEN 'abbreviation' THEN 'acronym'
            ELSE 'synonym'
       END,
       'es-AR'
  FROM dentar_diagnosis_term dt
  JOIN dentar_diagnosis d ON d.id = dt.diagnosis_id
  JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-dx'
  JOIN os_catalog_item i
    ON i.catalog_id = rel.catalog_id
   AND i.permanent_code = d.code
  JOIN os_catalog_item_version iv
    ON iv.item_id = i.id
   AND iv.release_id = rel.release_id
 WHERE dt.language = 'es-AR'
   AND dt.term_type <> 'preferred';

-- -----------------------------------------------------------------------------
-- 5.4 DENTAR-DX · identificador CIE-10
-- -----------------------------------------------------------------------------
DELETE FROM os_catalog_identifier ident
 USING os_catalog_item i, _dentar_sync_release rel
 WHERE ident.item_id = i.id
   AND i.catalog_id = rel.catalog_id
   AND rel.catalog_code = 'dentar-dx'
   AND ident.system_name = 'CIE-10';

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT x.item_id, 'CIE-10', x.external_code, x.rn = 1
  FROM (
      SELECT i.id AS item_id,
             m.external_code,
             row_number() OVER (PARTITION BY i.id ORDER BY m.external_code) AS rn
        FROM dentar_diagnosis_mapping m
        JOIN dentar_diagnosis d ON d.id = m.diagnosis_id
        JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-dx'
        JOIN os_catalog_item i
          ON i.catalog_id = rel.catalog_id
         AND i.permanent_code = d.code
       WHERE m.system_code = 'CIE-10'
  ) x
ON CONFLICT (item_id, system_name, value) DO UPDATE SET is_primary = EXCLUDED.is_primary;

-- -----------------------------------------------------------------------------
-- 6. Mapeos a sistemas terminológicos (os_concept_mapping)
-- -----------------------------------------------------------------------------
DELETE FROM os_concept_mapping m
 USING os_catalog_item i, _dentar_sync_release rel
 WHERE m.item_id = i.id
   AND i.catalog_id = rel.catalog_id;

-- 6.1 DENTAR-PR: Nomenclador/AR queda como identificador; CDT y SNOMED como mapeos.
INSERT INTO os_concept_mapping
    (item_id, terminology_system_id, external_code, external_display,
     mapping_type, relationship_role)
SELECT i.id,
       ts.id,
       m.external_code,
       COALESCE(NULLIF(btrim(m.external_display), ''), m.external_code),
       CASE m.relationship
            WHEN 'equivalent'   THEN 'equivalent'
            WHEN 'broader'      THEN 'broader'
            WHEN 'narrower'     THEN 'narrower'
            WHEN 'not_mappable' THEN 'unmatched'
            ELSE 'related'
       END,
       'procedure_concept'
  FROM dentar_concept_mapping m
  JOIN _dentar_sync_latest l ON l.version_id = m.concept_version_id
  JOIN dentar_concept dc ON dc.id = l.concept_id
  JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-pr'
  JOIN os_catalog_item i
    ON i.catalog_id = rel.catalog_id
   AND i.permanent_code = dc.code
  JOIN os_terminology_system ts ON ts.code = m.system_code
 WHERE m.system_code <> 'NOMENCLADOR-AR'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role)
DO NOTHING;

-- 6.2 DENTAR-DX: SNOMED CT y CIE-10 como mapeos del concepto diagnóstico.
INSERT INTO os_concept_mapping
    (item_id, terminology_system_id, external_code, external_display,
     mapping_type, relationship_role)
SELECT i.id,
       ts.id,
       m.external_code,
       COALESCE(NULLIF(btrim(m.external_display), ''), m.external_code),
       CASE m.mapping_type
            WHEN 'equivalent' THEN 'equivalent'
            WHEN 'broader'    THEN 'broader'
            WHEN 'narrower'   THEN 'narrower'
            ELSE 'related'
       END,
       'observation_concept'
  FROM dentar_diagnosis_mapping m
  JOIN dentar_diagnosis d ON d.id = m.diagnosis_id
  JOIN _dentar_sync_release rel ON rel.catalog_code = 'dentar-dx'
  JOIN os_catalog_item i
    ON i.catalog_id = rel.catalog_id
   AND i.permanent_code = d.code
  JOIN os_terminology_system ts ON ts.code = m.system_code
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role)
DO NOTHING;

-- -----------------------------------------------------------------------------
-- 7. Resumen
-- -----------------------------------------------------------------------------
SELECT 'os_catalog_item · DENTAR-PR' AS control, count(*)::text AS valor
  FROM os_catalog_item i
  JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'dentar-pr'
UNION ALL
SELECT 'os_catalog_item · DENTAR-DX', count(*)::text
  FROM os_catalog_item i
  JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'dentar-dx'
UNION ALL
SELECT 'os_catalog_item_version', count(*)::text
  FROM os_catalog_item_version iv
  JOIN _dentar_sync_release rel ON rel.release_id = iv.release_id
UNION ALL
SELECT 'os_catalog_term', count(*)::text
  FROM os_catalog_term t
  JOIN os_catalog_item_version iv ON iv.id = t.item_version_id
  JOIN _dentar_sync_release rel ON rel.release_id = iv.release_id
UNION ALL
SELECT 'os_catalog_identifier · NOMENCLADOR_AR', count(*)::text
  FROM os_catalog_identifier ident
  JOIN os_catalog_item i ON i.id = ident.item_id
  JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'dentar-pr'
 WHERE ident.system_name = 'NOMENCLADOR_AR'
UNION ALL
SELECT 'os_catalog_identifier · CIE-10', count(*)::text
  FROM os_catalog_identifier ident
  JOIN os_catalog_item i ON i.id = ident.item_id
  JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'dentar-dx'
 WHERE ident.system_name = 'CIE-10'
UNION ALL
SELECT 'os_concept_mapping', count(*)::text
  FROM os_concept_mapping m
  JOIN os_catalog_item i ON i.id = m.item_id
  JOIN _dentar_sync_release rel ON rel.catalog_id = i.catalog_id;
