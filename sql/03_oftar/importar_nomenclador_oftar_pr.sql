-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud
-- sql/03_oftar/importar_nomenclador_oftar_pr.sql
-- =============================================================================
--
-- QUÉ HACE
--   Importa TODAS las filas de `oftar_nomenclador_source` cuya categoría literal es
--   'OFTALMOLOGIA' al catálogo `oftar-pr` (procedimientos). No toca oftar-dx.
--
--   · Un concepto editorial por código NOMENCLADOR-AR.
--   · Un mapeo NOMENCLADOR-AR por concepto (sistema con dueño oftar-pr).
--   · Proyección a os_catalog_item / os_catalog_item_version / identificador.
--   · Lateralidad OD / OI / AO / NA como ATRIBUTO del ítem, nunca como
--     categoría ni como código OFTAR nuevo. NA = no declarada en la fuente.
--   · Aprueba SOLO preferred_term, con guarda de hash, igual que en oftar-dx.
--
-- QUÉ NO HACE
--   · No carga `definition`: queda PENDIENTE para revisión humana posterior.
--     No se inventa texto clínico ni traducción.
--   · No crea OFTAR-CIR / OFTAR-IMG / OFTAR-TER / OFTAR-MED: cirugía, imágenes
--     y tratamientos son categorías internas de oftar-pr.
--   · No crea UVR. La valoración del ejemplo OCT se carga en
--     `uvr_ejemplo_oct_oftar_pr.sql`.
--   · No modifica importadores ni fuentes existentes. No crea objetos
--     persistentes nuevos (solo tablas TEMP), por lo que no hay ACL nueva.
--   · No ejecuta ALTER DEFAULT PRIVILEGES.
--
-- REQUIERE: oftar_family.sql, oftar_core.sql y
--           sql/03_oftar/fuente_nomenclador_oftar_pr.sql ya aplicada.
--           No depende de que exista `nomenclador_2025` en la base.
-- IDEMPOTENTE: una segunda ejecución no duplica conceptos, textos ni atributos.
-- =============================================================================

BEGIN;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- Identidad del importador para los triggers de auditoría editorial.
SET LOCAL app.actor_id = 'oftar_nomenclador_import';
SET LOCAL app.actor_type = 'user';

DO $$
BEGIN
    IF to_regclass('public.oftar_nomenclador_source') IS NULL THEN
        RAISE EXCEPTION 'Falta public.oftar_nomenclador_source.'
            USING HINT = 'Aplicar sql/03_oftar/fuente_nomenclador_oftar_pr.sql.';
    END IF;
    IF to_regclass('public.oftar_concept') IS NULL
       OR to_regclass('public.oftar_concept_version') IS NULL
       OR to_regclass('public.oftar_term') IS NULL
       OR to_regclass('public.oftar_concept_mapping') IS NULL
       OR to_regclass('public.os_catalog_source_attribute') IS NULL
       OR to_regclass('public.os_field_review') IS NULL
       OR to_regclass('public.os_translation_review') IS NULL THEN
        RAISE EXCEPTION 'Falta la estructura OFTAR o de gobernanza editorial.'
            USING HINT = 'Aplicar oftar_core.sql y la Fase 2/3 de i18n.';
    END IF;
END $$;

-- =============================================================================
-- 1. FUENTE Y RELEASE DESTINO
-- =============================================================================
CREATE TEMP TABLE _oftar_pr_source ON COMMIT DROP AS
SELECT DISTINCT ON (codigo)
       codigo,
       btrim(descripcion) AS descripcion
  FROM public.oftar_nomenclador_source
 WHERE categoria = 'OFTALMOLOGIA'
   AND codigo ~ '^[0-9]{6}$'
   AND NULLIF(btrim(descripcion), '') IS NOT NULL
 ORDER BY codigo, descripcion;

CREATE TEMP TABLE _oftar_pr_release ON COMMIT DROP AS
SELECT c.id AS catalog_id, r.id AS release_id, r.version_tag
  FROM public.os_catalog c
  JOIN public.os_catalog_release r
         ON r.catalog_id = c.id AND r.status = 'published'
 WHERE c.code = 'oftar-pr' AND c.is_active = TRUE;

DO $$
DECLARE
    v_filas INT;
    v_releases INT;
BEGIN
    SELECT count(*) INTO v_filas FROM _oftar_pr_source;
    SELECT count(*) INTO v_releases FROM _oftar_pr_release;
    IF v_filas = 0 THEN
        RAISE EXCEPTION 'No hay filas de OFTALMOLOGIA para importar.';
    END IF;
    IF v_releases <> 1 THEN
        RAISE EXCEPTION 'Se esperaba un único release publicado para oftar-pr; hay %.', v_releases;
    END IF;
END $$;

-- Código permanente estable: el orden por código de fuente no cambia entre
-- ejecuciones. Categoría interna por palabras literales de la descripción;
-- nunca se declara una equivalencia clínica inferida.
CREATE TEMP TABLE _oftar_pr_items ON COMMIT DROP AS
SELECT s.codigo,
       s.descripcion,
       'OFTAR-PR-' || lpad(row_number() OVER (ORDER BY s.codigo)::text, 6, '0') AS permanent_code,
       CASE
           WHEN s.descripcion ~* '(oct|tomograf[ií]a|ecograf|retinograf|videonistagmograf|fotograf)' THEN 'IMG'
           WHEN s.descripcion ~* '(cirug|operac|implante|extracc|vitrectom|queratoplast|trasplante|enucleac)' THEN 'CIR'
           WHEN s.descripcion ~* '(l[aá]ser|inyecc|radioterap|crioterap|tratamiento|terapia)' THEN 'TER'
           WHEN s.descripcion ~* '(diagn[oó]stico|estudio|test|prueba)' THEN 'DIAG'
           ELSE 'EXAM'
       END AS category_code,
       CASE
           -- "uni o bilateral" no declara lado: no se infiere AO.
           WHEN s.descripcion ~* '(uni o bilateral|uni/bilateral|uno o ambos)' THEN 'NA'
           WHEN s.descripcion ~* '(^|[^a-z])(ao|ambos ojos|bilateral)([^a-z]|$)' THEN 'AO'
           WHEN s.descripcion ~* '(^|[^a-z])(od|ojo derecho|derech[oa])([^a-z]|$)' THEN 'OD'
           WHEN s.descripcion ~* '(^|[^a-z])(oi|ojo izquierdo|izquierd[oa])([^a-z]|$)' THEN 'OI'
           ELSE 'NA'
       END AS laterality
  FROM _oftar_pr_source s;

-- =============================================================================
-- 2. CONCEPTO EDITORIAL OFTAR-PR
-- =============================================================================
INSERT INTO public.oftar_concept (code, concept_type, lifecycle_status)
SELECT i.permanent_code, 'procedure', 'active'
  FROM _oftar_pr_items i
ON CONFLICT (code) DO UPDATE
   SET lifecycle_status = EXCLUDED.lifecycle_status;

INSERT INTO public.oftar_concept_version
       (concept_id, version_number, definition, approval_status,
        effective_from, year_effective)
SELECT c.id, 1, 'SIN DEFINICIÓN EDITORIAL APROBADA · PENDIENTE', 'draft',
       DATE '2026-01-01', 2026
  FROM _oftar_pr_items i
  JOIN public.oftar_concept c ON c.code = i.permanent_code
ON CONFLICT (concept_id, version_number) DO NOTHING;

INSERT INTO public.oftar_term (concept_version_id, language, term, term_type)
SELECT v.id, 'es-AR', i.descripcion, 'preferred'
  FROM _oftar_pr_items i
  JOIN public.oftar_concept c ON c.code = i.permanent_code
  JOIN public.oftar_concept_version v
         ON v.concept_id = c.id AND v.version_number = 1
 WHERE NOT EXISTS (
       SELECT 1 FROM public.oftar_term t
        WHERE t.concept_version_id = v.id
          AND t.language = 'es-AR' AND t.term_type = 'preferred'
   );

INSERT INTO public.oftar_concept_mapping
       (concept_version_id, system_code, external_code, external_display, relationship)
SELECT v.id, 'NOMENCLADOR-AR', i.codigo, i.descripcion, 'equivalent'
  FROM _oftar_pr_items i
  JOIN public.oftar_concept c ON c.code = i.permanent_code
  JOIN public.oftar_concept_version v
         ON v.concept_id = c.id AND v.version_number = 1
ON CONFLICT (concept_version_id, system_code, external_code) DO UPDATE
   SET external_display = EXCLUDED.external_display;

-- La lateralidad es un atributo declarado de la versión, con valor obligatorio
-- (NA cuando la fuente no declara lado). No genera categorías ni códigos.
INSERT INTO public.oftar_concept_attribute_rule
       (concept_version_id, attribute_id, is_required)
SELECT v.id, a.id, TRUE
  FROM _oftar_pr_items i
  JOIN public.oftar_concept c ON c.code = i.permanent_code
  JOIN public.oftar_concept_version v
         ON v.concept_id = c.id AND v.version_number = 1
  JOIN public.oftar_attribute_definition a ON a.code = 'ATTR-LATERALITY'
ON CONFLICT (concept_version_id, attribute_id) DO NOTHING;

-- =============================================================================
-- 3. PROYECCIÓN AL MOTOR os_catalog
-- =============================================================================
INSERT INTO public.os_catalog_item (catalog_id, permanent_code, status)
SELECT r.catalog_id, i.permanent_code, 'active'
  FROM _oftar_pr_items i
  CROSS JOIN _oftar_pr_release r
ON CONFLICT (catalog_id, permanent_code) DO UPDATE
   SET status = EXCLUDED.status;

CREATE TEMP TABLE _oftar_pr_versions ON COMMIT DROP AS
SELECT i.codigo,
       i.permanent_code,
       i.category_code,
       i.laterality,
       item.id AS item_id,
       rel.release_id
  FROM _oftar_pr_items i
  CROSS JOIN _oftar_pr_release rel
  JOIN public.os_catalog_item item
         ON item.catalog_id = rel.catalog_id
        AND item.permanent_code = i.permanent_code;

INSERT INTO public.os_catalog_item_version
       (item_id, release_id, category_id, preferred_term, definition,
        language_code, source_language_code, language_evidence, provenance,
        review_status, source_reference, valid_from)
SELECT v.item_id,
       v.release_id,
       occ.id,
       left(i.descripcion, 255),
       NULL,
       'es-AR',
       'es-AR',
       'explicit',
       'imported_nomenclador',
       'unknown',
       'Nomenclador Nacional 2025 · OFTALMOLOGIA',
       DATE '2026-01-01'
  FROM _oftar_pr_items i
  JOIN _oftar_pr_versions v ON v.codigo = i.codigo
  LEFT JOIN public.os_catalog_category occ
         ON occ.catalog_id = (SELECT catalog_id FROM _oftar_pr_release)
        AND occ.code = v.category_code
ON CONFLICT (item_id, release_id, language_code) DO UPDATE
   SET category_id          = EXCLUDED.category_id,
       preferred_term       = EXCLUDED.preferred_term,
       definition           = NULL,
       source_language_code = EXCLUDED.source_language_code,
       language_evidence    = EXCLUDED.language_evidence,
       provenance           = EXCLUDED.provenance,
       source_reference     = EXCLUDED.source_reference,
       valid_from           = EXCLUDED.valid_from;

INSERT INTO public.os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT v.item_id, 'NOMENCLADOR-AR', i.codigo, TRUE
  FROM _oftar_pr_items i
  JOIN _oftar_pr_versions v ON v.codigo = i.codigo
ON CONFLICT (item_id, system_name, value) DO UPDATE
   SET is_primary = TRUE;

DO $$
DECLARE
    v_sin_categoria INT;
    v_sin_termino INT;
BEGIN
    SELECT count(*) INTO v_sin_categoria
      FROM public.os_catalog_item_version iv
      JOIN public.os_catalog_item i ON i.id = iv.item_id
      JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-pr'
     WHERE iv.provenance = 'imported_nomenclador'
       AND iv.category_id IS NULL;
    SELECT count(*) INTO v_sin_termino
      FROM public.os_catalog_item_version iv
      JOIN public.os_catalog_item i ON i.id = iv.item_id
      JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-pr'
     WHERE iv.provenance = 'imported_nomenclador'
       AND NULLIF(btrim(iv.preferred_term), '') IS NULL;
    IF v_sin_categoria > 0 OR v_sin_termino > 0 THEN
        RAISE EXCEPTION
            'Importación incompleta: % versiones sin categoría y % sin término.',
            v_sin_categoria, v_sin_termino;
    END IF;
END $$;

-- Atributo visible en la ficha del Browser. `NA` significa "sin lateralidad
-- declarada por la fuente", no una inferencia clínica.
INSERT INTO public.os_catalog_source_attribute
       (item_id, source_catalog_code, attribute_code, attribute_label,
        attribute_value, is_boolean, display_order)
SELECT v.item_id, 'oftar', 'ATTR-LATERALITY', 'Lateralidad',
       v.laterality, FALSE, 1
  FROM _oftar_pr_versions v
ON CONFLICT (item_id, source_catalog_code, attribute_code) DO UPDATE
   SET attribute_value = EXCLUDED.attribute_value,
       attribute_label = EXCLUDED.attribute_label,
       display_order   = EXCLUDED.display_order;

-- =============================================================================
-- 4. REVISIÓN DE CAMPO: SOLO preferred_term
-- =============================================================================
INSERT INTO public.os_field_review
       (target_table, target_id, field_name, language_code, scope_release_id,
        source_language_code, language_evidence, provenance, review_status,
        source_reference, reviewed_by, reviewed_at)
SELECT 'os_catalog_item_version',
       iv.id,
       'preferred_term',
       iv.language_code,
       iv.release_id,
       iv.source_language_code,
       iv.language_evidence,
       iv.provenance,
       'unknown',
       iv.source_reference,
       NULL,
       NULL
  FROM public.os_catalog_item_version iv
  JOIN public.os_catalog_item i ON i.id = iv.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-pr'
 WHERE iv.provenance = 'imported_nomenclador'
   AND NULLIF(btrim(iv.preferred_term), '') IS NOT NULL
ON CONFLICT DO NOTHING;

-- =============================================================================
-- 5. APROBACIÓN GOBERNADA DE preferred_term
-- =============================================================================
CREATE TEMP TABLE _oftar_pr_aprobables ON COMMIT DROP AS
SELECT f.target_id AS version_id,
       f.language_code,
       f.scope_release_id,
       f.content_hash,
       md5(iv.preferred_term || E'\x1f'
           || f.language_code || E'\x1f'
           || COALESCE(f.source_reference, '')) AS hash_esperado
  FROM public.os_field_review f
  JOIN public.os_catalog_item_version iv ON iv.id = f.target_id
  JOIN public.os_catalog_item i ON i.id = iv.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-pr'
 WHERE f.target_table = 'os_catalog_item_version'
   AND f.field_name = 'preferred_term'
   AND f.provenance = 'imported_nomenclador'
   AND f.review_status = 'unknown'
   AND f.scope_release_id = iv.release_id
   AND NULLIF(btrim(iv.preferred_term), '') IS NOT NULL;

DO $$
DECLARE
    v_desactualizados INT;
BEGIN
    SELECT count(*) INTO v_desactualizados
      FROM _oftar_pr_aprobables
     WHERE content_hash IS DISTINCT FROM hash_esperado;
    IF v_desactualizados > 0 THEN
        RAISE EXCEPTION
            'Hay % preferred_term de oftar-pr con hash desactualizado; no se aprueba nada.',
            v_desactualizados;
    END IF;
END $$;

UPDATE public.os_field_review f
   SET review_status = 'approved',
       reviewed_by = 'oftar_nomenclador_import',
       reviewed_at = now(),
       updated_at = now()
  FROM _oftar_pr_aprobables a
 WHERE f.target_table = 'os_catalog_item_version'
   AND f.target_id = a.version_id
   AND f.field_name = 'preferred_term'
   AND f.language_code = a.language_code
   AND f.scope_release_id IS NOT DISTINCT FROM a.scope_release_id;

UPDATE public.os_catalog_item_version iv
   SET review_status = 'approved'
  FROM _oftar_pr_aprobables a
 WHERE iv.id = a.version_id
   AND iv.review_status <> 'approved';

-- =============================================================================
-- 6. RESULTADO
-- =============================================================================
SELECT count(*) AS conceptos_importados FROM public.oftar_concept
 WHERE code LIKE 'OFTAR-PR-%';

SELECT count(*) AS terms_aprobados
  FROM public.os_field_review f
  JOIN public.os_catalog_item_version iv ON iv.id = f.target_id
  JOIN public.os_catalog_item i ON i.id = iv.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id
 WHERE c.code = 'oftar-pr'
   AND f.target_table = 'os_catalog_item_version'
   AND f.field_name = 'preferred_term'
   AND f.review_status = 'approved';

SELECT attribute_value, count(*) AS items
  FROM public.os_catalog_source_attribute sa
  JOIN public.os_catalog_item i ON i.id = sa.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id
 WHERE c.code = 'oftar-pr'
   AND sa.source_catalog_code = 'oftar'
   AND sa.attribute_code = 'ATTR-LATERALITY'
 GROUP BY attribute_value
 ORDER BY attribute_value;

COMMIT;
