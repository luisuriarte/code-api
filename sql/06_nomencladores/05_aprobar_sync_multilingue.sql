-- =============================================================================
-- 06_nomencladores / 05_aprobar_sync_multilingue.sql
-- Marca como aprobadas y publicables las versiones y mapeos sincronizados
-- desde fuentes oficiales (NN_PMO, NBU, Imágenes, PMO) en el paso 04.
-- =============================================================================

SET client_encoding = 'UTF8';
SET search_path = public;

BEGIN;

SELECT set_config('app.actor_type', 'user', true);
SELECT set_config('app.actor_id', 'sync_oficial_2026', true);
SELECT set_config('app.importer_run_id', '', true);

-- 1. Aprobar versiones oficiales en os_catalog_item_version para los 4 catálogos
UPDATE os_catalog_item_version v
SET
    review_status     = 'approved',
    provenance        = 'official_source',
    language_evidence = 'official_source',
    reviewed_by       = 'sync_oficial_2026',
    reviewed_at       = now()
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id
WHERE v.item_id = i.id
  AND c.code IN ('nn-pmo', 'nbu', 'imagenes-ar', 'pmo-ar')
  AND v.review_status = 'unknown';

-- 2. Registrar os_field_review para los os_concept_mapping aprobados que faltan
WITH candidatas AS (
    SELECT m.id AS target_id,
           v.field_name,
           v.valor,
           COALESCE(NULLIF(m.provenance, 'unknown'), 'official_source') AS provenance,
           COALESCE(m.source_reference, 'sync_oficial_2026') AS source_reference
      FROM os_concept_mapping m
      JOIN os_catalog_item i ON i.id = m.item_id
      JOIN os_catalog c ON c.id = i.catalog_id
      CROSS JOIN LATERAL (
          VALUES ('external_display', m.external_display),
                 ('clinical_rationale', m.clinical_rationale)
      ) AS v(field_name, valor)
     WHERE c.code IN ('nn-pmo', 'nbu', 'imagenes-ar', 'pmo-ar')
       AND m.review_status = 'approved'
       AND NULLIF(btrim(COALESCE(v.valor, '')), '') IS NOT NULL
       AND NOT EXISTS (
             SELECT 1
               FROM os_field_review f
              WHERE f.target_table = 'os_concept_mapping'
                AND f.target_id = m.id
                AND f.field_name = v.field_name
                AND f.language_code = 'undet'
                AND f.scope_release_id IS NULL
           )
)
INSERT INTO os_field_review (
    target_table, target_id, field_name, language_code, scope_release_id,
    source_language_code, language_evidence, provenance, review_status,
    source_reference, reviewed_by, reviewed_at
)
SELECT 'os_concept_mapping',
       c.target_id,
       c.field_name,
       'undet',
       NULL,
       NULL,
       'undetermined',
       c.provenance,
       'approved',
       c.source_reference,
       'sync_oficial_2026',
       now()
  FROM candidatas c
 ON CONFLICT DO NOTHING;

COMMIT;

SELECT c.code AS catalog_code, v.review_status, COUNT(*) AS versiones
FROM os_catalog_item_version v
JOIN os_catalog_item i ON i.id = v.item_id
JOIN os_catalog c ON c.id = i.catalog_id
WHERE c.code IN ('nn-pmo', 'nbu', 'imagenes-ar', 'pmo-ar')
GROUP BY c.code, v.review_status
ORDER BY c.code, v.review_status;
