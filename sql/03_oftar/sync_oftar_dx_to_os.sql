-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud
-- sql/03_oftar/sync_oftar_dx_to_os.sql
-- =============================================================================
--
-- QUÉ HACE
--   Proyecta los diagnósticos ya importados en OFTAR-DX al motor canónico:
--     os_catalog_item → os_catalog_item_version → os_catalog_identifier
--     → os_concept_mapping → revisiones de campo PENDIENTES.
--
--   Solo crea versión para el idioma que existe en la fuente. Los 17 códigos
--   exclusivos de ICD-10-CM 2027 quedan en `en`; H01.8 queda en `es-AR`.
--   No se inventa texto traducido.
--
--   NO aprueba contenido. Las filas de os_field_review se crean en estado
--   'unknown' para que la aprobación la haga una persona autorizada.
--   No toca UVR ni crea procedimientos.
--
--   Aditivo e idempotente: usa ON CONFLICT, sin DELETE/TRUNCATE/DROP.
-- Requiere: oftar_core.sql, oftar_external_identity.sql e importar_cie10_dx.sql.
-- PostgreSQL 18.
-- =============================================================================
BEGIN;

SET client_encoding = 'UTF8';

DO $$
BEGIN
    IF to_regclass('public.oftar_diagnosis') IS NULL
       OR to_regclass('public.os_catalog_item_version') IS NULL
       OR to_regclass('public.os_field_review') IS NULL THEN
        RAISE EXCEPTION 'Falta la estructura OFTAR u OS necesaria para sincronizar.'
            USING HINT = 'Ejecutá oftar_core.sql, oftar_external_identity.sql y el importador CIE-10.';
    END IF;
END $$;

-- =============================================================================
-- 1. RELEASE DESTINO
-- =============================================================================
CREATE TEMP TABLE _oftar_sync_release ON COMMIT DROP AS
SELECT c.id AS catalog_id, r.id AS release_id
  FROM public.os_catalog c
  JOIN public.os_catalog_release r
         ON r.catalog_id = c.id AND r.version_tag = '2026-v1'
 WHERE c.code = 'oftar-dx';

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*) INTO v_count FROM _oftar_sync_release;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Se esperaba un único release 2026-v1 para oftar-dx; hay %.', v_count;
    END IF;
END $$;

-- =============================================================================
-- 2. ÍTEMS PERMANENTES
-- =============================================================================
INSERT INTO public.os_catalog_item (catalog_id, permanent_code, status)
SELECT rel.catalog_id, d.code,
       CASE WHEN d.status = 'active' THEN 'active' ELSE 'retired' END
  FROM public.oftar_diagnosis d
  CROSS JOIN _oftar_sync_release rel
ON CONFLICT (catalog_id, permanent_code) DO UPDATE
   SET status = EXCLUDED.status;

-- =============================================================================
-- 3. TEXTO POR IDIOMA DISPONIBLE
-- =============================================================================
-- Un texto por (diagnóstico, idioma). No se rellena el idioma ausente.
CREATE TEMP TABLE _oftar_sync_text ON COMMIT DROP AS
SELECT d.id AS diagnosis_id,
       dt.language AS language_code,
       left(dt.term, 255) AS preferred_term,
       v.definition,
       dt.language AS source_language_code
  FROM public.oftar_diagnosis d
  JOIN public.oftar_diagnosis_version v
         ON v.diagnosis_id = d.id AND v.version_number = 1
  JOIN public.oftar_diagnosis_term dt
         ON dt.diagnosis_id = d.id AND dt.term_type = 'preferred'
 WHERE dt.language IN ('es-AR', 'en')
   AND NULLIF(btrim(dt.term), '') IS NOT NULL;

INSERT INTO public.os_catalog_item_version
       (item_id, release_id, category_id, preferred_term, definition,
        language_code, source_language_code, language_evidence,
        provenance, review_status, source_reference, valid_from)
SELECT i.id,
       rel.release_id,
       occ.id,
       t.preferred_term,
       t.definition,
       t.language_code,
       t.source_language_code,
       'explicit',
       'imported_cie10',
       'unknown',
       'CIE-10-ES 2026 / ICD-10-CM 2027',
       CURRENT_DATE
  FROM _oftar_sync_text t
  JOIN public.oftar_diagnosis d ON d.id = t.diagnosis_id
  CROSS JOIN _oftar_sync_release rel
  JOIN public.os_catalog_item i
         ON i.catalog_id = rel.catalog_id AND i.permanent_code = d.code
  LEFT JOIN public.os_catalog_category occ
         ON occ.catalog_id = rel.catalog_id AND occ.code = 'CAT-DX'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE
   SET category_id          = EXCLUDED.category_id,
       preferred_term       = EXCLUDED.preferred_term,
       definition           = EXCLUDED.definition,
       source_language_code = EXCLUDED.source_language_code,
       language_evidence    = EXCLUDED.language_evidence,
       provenance           = EXCLUDED.provenance,
       source_reference     = EXCLUDED.source_reference,
       valid_from           = EXCLUDED.valid_from;

-- =============================================================================
-- 4. IDENTIFICADOR Y MAPEO CIE-10
-- =============================================================================
INSERT INTO public.os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT DISTINCT
       i.id, 'CIE-10', m.external_code, TRUE
  FROM public.oftar_diagnosis_mapping m
  JOIN public.oftar_diagnosis d ON d.id = m.diagnosis_id
  CROSS JOIN _oftar_sync_release rel
  JOIN public.os_catalog_item i
         ON i.catalog_id = rel.catalog_id AND i.permanent_code = d.code
 WHERE m.system_code = 'CIE-10'
ON CONFLICT (item_id, system_name, value) DO UPDATE
   SET is_primary = EXCLUDED.is_primary;

INSERT INTO public.os_concept_mapping
       (item_id, terminology_system_id, external_code, external_display,
        mapping_type, relationship_role, review_status, language_evidence,
        provenance, source_reference)
SELECT i.id,
       ts.id,
       m.external_code,
       COALESCE(NULLIF(btrim(COALESCE(m.external_display, '')), ''), m.external_code),
       CASE m.mapping_type
            WHEN 'equivalent' THEN 'equivalent'
            WHEN 'broader'    THEN 'broader'
            WHEN 'narrower'   THEN 'narrower'
            ELSE 'related'
       END,
       'observation_concept',
       'draft',
       'explicit',
       'imported_cie10',
       'CIE-10-ES 2026 / ICD-10-CM 2027'
  FROM public.oftar_diagnosis_mapping m
  JOIN public.oftar_diagnosis d ON d.id = m.diagnosis_id
  CROSS JOIN _oftar_sync_release rel
  JOIN public.os_catalog_item i
         ON i.catalog_id = rel.catalog_id AND i.permanent_code = d.code
  JOIN public.os_terminology_system ts ON ts.code = m.system_code
 WHERE m.system_code = 'CIE-10'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role)
DO NOTHING;

-- =============================================================================
-- 5. REVISIONES DE CAMPO PENDIENTES (NO APROBADAS)
-- =============================================================================
-- preferred_term y definition por versión/idioma.
INSERT INTO public.os_field_review
       (target_table, target_id, field_name, language_code, scope_release_id,
        source_language_code, language_evidence, provenance, review_status,
        source_reference, reviewed_by, reviewed_at)
SELECT 'os_catalog_item_version',
       iv.id,
       campo.field_name,
       iv.language_code,
       rel.release_id,
       iv.source_language_code,
       iv.language_evidence,
       iv.provenance,
       'unknown',
       iv.source_reference,
       NULL,
       NULL
  FROM public.os_catalog_item_version iv
  CROSS JOIN _oftar_sync_release rel
  JOIN public.os_catalog_item i
         ON i.id = iv.item_id AND i.catalog_id = rel.catalog_id
  JOIN public.oftar_diagnosis d
         ON d.code = i.permanent_code
  CROSS JOIN LATERAL (
      SELECT 'preferred_term'::text AS field_name, iv.preferred_term AS field_value
      UNION ALL SELECT 'definition'::text, iv.definition
  ) AS campo
 WHERE NULLIF(btrim(COALESCE(campo.field_value, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

-- external_display del mapeo, sin idioma inferido (criterio D-19).
INSERT INTO public.os_field_review
       (target_table, target_id, field_name, language_code, scope_release_id,
        source_language_code, language_evidence, provenance, review_status,
        source_reference, reviewed_by, reviewed_at)
SELECT 'os_concept_mapping',
       m.id,
       'external_display',
       'undet',
       NULL,
       NULL,
       'undetermined',
       'imported_cie10',
       'unknown',
       'CIE-10-ES 2026 / ICD-10-CM 2027',
       NULL,
       NULL
  FROM public.os_concept_mapping m
  JOIN public.os_catalog_item i ON i.id = m.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
  JOIN public.os_terminology_system ts ON ts.id = m.terminology_system_id
 WHERE ts.code = 'CIE-10'
   AND NULLIF(btrim(COALESCE(m.external_display, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

-- =============================================================================
-- 6. RESULTADO
-- =============================================================================
DO $$
DECLARE
    v_items INT;
    v_versiones INT;
    v_revisiones INT;
BEGIN
    SELECT count(*) INTO v_items
      FROM public.os_catalog_item i
      JOIN _oftar_sync_release rel ON rel.catalog_id = i.catalog_id;

    SELECT count(*) INTO v_versiones
      FROM public.os_catalog_item_version iv
      JOIN public.os_catalog_item i ON i.id = iv.item_id
      JOIN _oftar_sync_release rel ON rel.catalog_id = i.catalog_id;

    SELECT count(*) INTO v_revisiones
      FROM public.os_field_review f
     WHERE f.provenance = 'imported_cie10' AND f.review_status = 'unknown';

    RAISE NOTICE 'sync oftar-dx -> os_*: ítems=%; versiones=%; revisiones pendientes=%',
        v_items, v_versiones, v_revisiones;
END $$;

SELECT language_code, count(*) AS versiones
  FROM public.os_catalog_item_version iv
  JOIN public.os_catalog_item i ON i.id = iv.item_id
  JOIN _oftar_sync_release rel ON rel.catalog_id = i.catalog_id
 GROUP BY language_code
 ORDER BY language_code;

COMMIT;

-- Fin de sync_oftar_dx_to_os.sql
