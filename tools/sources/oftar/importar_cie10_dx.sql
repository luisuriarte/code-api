-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud
-- tools/sources/oftar/importar_cie10_dx.sql
-- =============================================================================
--
-- QUÉ IMPORTA
--   Solo diagnósticos CIE-10-ES del capítulo H00-H59 (ojo y anexos) hacia
--   OFTAR-DX. NO importa procedimientos: ICD-10-PCS `08*` queda como mapeo
--   opcional de un OFTAR-PR ya existente, nunca como código nuevo.
--
-- DEDUPE (tres capas)
--   1. Normalización canónica del código externo (oftar_normalize_external_code).
--   2. DISTINCT ON (código normalizado, idioma destino) con precedencia de
--      fuente: es -> es-AR, en -> en; si hay dos textos, gana el de menor id.
--   3. Registro central oftar_external_identity con UNIQUE (sistema, código):
--      un código ya importado se omite en una segunda ejecución.
--
-- SALIDA
--   oftar_diagnosis, oftar_diagnosis_version, oftar_diagnosis_term y
--   oftar_diagnosis_mapping. El trigger de identidad fija el dueño oftar-dx.
--   La sincronización a os_catalog_item y la aprobación por campo se hacen
--   después, con el flujo editorial existente. No crea UVR.
--
-- REQUISITOS
--   oftar_family.sql, oftar_core.sql y oftar_external_identity.sql aplicados.
--   cie10_codes / cie10_descriptions ya cargados por el generador CIE-10.
-- PostgreSQL 18.
-- =============================================================================
BEGIN;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

DO $$
BEGIN
    IF to_regclass('public.cie10_codes') IS NULL
       OR to_regclass('public.cie10_descriptions') IS NULL THEN
        RAISE EXCEPTION 'Faltan las tablas CIE-10 canónicas.'
            USING HINT = 'Cargá primero tools/php/generar_carga_cie10_pg.php.';
    END IF;

    IF to_regclass('public.oftar_external_identity') IS NULL THEN
        RAISE EXCEPTION 'Falta el registro de identidad externa de OFTAR.'
            USING HINT = 'Ejecutá sql/03_oftar/oftar_external_identity.sql.';
    END IF;
END $$;

-- =============================================================================
-- 1. STAGING: UN TEXTO POR (CÓDIGO NORMALIZADO, IDIOMA DESTINO)
-- =============================================================================
-- El generador CIE-10 guarda language_code = 'es' | 'en'. Se mapean a los
-- idiomas canónicos del portal: es -> es-AR, en -> en. No se crea en-US.
CREATE TEMP TABLE _oftar_cie10_dx ON COMMIT DROP AS
SELECT DISTINCT ON (
           public.oftar_normalize_external_code(c.codigo),
           v.lang
       )
       public.oftar_normalize_external_code(c.codigo) AS code_normalized,
       c.codigo AS code_raw,
       v.lang AS language,
       d.descripcion AS description
  FROM public.cie10_codes c
  JOIN public.cie10_descriptions d ON d.cie10_id = c.id
  CROSS JOIN LATERAL (VALUES
      ('es', 'es-AR'),
      ('en', 'en')
  ) AS v(src_lang, lang)
 WHERE c.tipo = 'diagnostico'
   AND c.codigo ~ '^H(0[0-9]|[1-5][0-9])'
   AND d.language_code = v.src_lang
 ORDER BY public.oftar_normalize_external_code(c.codigo), v.lang, d.id;

-- =============================================================================
-- 2. UN ÍTEM POR CÓDIGO, CON SU TEXTO PREFERIDO
-- =============================================================================
CREATE TEMP TABLE _oftar_cie10_dx_item ON COMMIT DROP AS
SELECT s.code_normalized,
       min(s.code_raw) AS code_raw,
       max(s.description) FILTER (WHERE s.language = 'es-AR') AS nombre_es,
       max(s.description) FILTER (WHERE s.language = 'en') AS nombre_en
  FROM _oftar_cie10_dx s
 GROUP BY s.code_normalized;

-- Solo códigos todavía no registrados. Esto hace reejecutable el importador:
-- la segunda pasada no desplaza la numeración ni crea diagnósticos nuevos.
CREATE TEMP TABLE _oftar_cie10_dx_nuevo ON COMMIT DROP AS
SELECT i.*
  FROM _oftar_cie10_dx_item i
 WHERE NOT EXISTS (
       SELECT 1
         FROM public.oftar_external_identity e
        WHERE e.system_code = 'CIE-10'
          AND e.code_normalized = i.code_normalized
   )
   AND NOT EXISTS (
       SELECT 1
         FROM public.oftar_diagnosis_mapping m
        WHERE m.system_code = 'CIE-10'
          AND public.oftar_normalize_external_code(m.external_code) = i.code_normalized
   );

-- =============================================================================
-- 3. ASIGNACIÓN DE CÓDIGOS PERMANENTES OFTAR-DX-NNNNNN
-- =============================================================================
CREATE TEMP TABLE _oftar_cie10_offset ON COMMIT DROP AS
SELECT coalesce(max(regexp_replace(code, '^OFTAR-DX-', '')::int), 0) AS next_value
  FROM public.oftar_diagnosis
 WHERE code ~ '^OFTAR-DX-[0-9]{6}$';

CREATE TEMP TABLE _oftar_cie10_dx_asignado ON COMMIT DROP AS
SELECT n.*,
       'OFTAR-DX-' || lpad(
           (o.next_value + row_number() OVER (ORDER BY n.code_normalized))::text,
           6, '0'
       ) AS new_code
  FROM _oftar_cie10_dx_nuevo n
  CROSS JOIN _oftar_cie10_offset o;

-- =============================================================================
-- 4. CARGA EN EL MODELO EDITORIAL OFTAR-DX
-- =============================================================================
INSERT INTO public.oftar_diagnosis (code, clinical_name, category_id, status)
SELECT a.new_code,
       coalesce(a.nombre_es, a.nombre_en, a.code_raw),
       cat.id,
       'active'
  FROM _oftar_cie10_dx_asignado a
  JOIN public.oftar_catalog oc ON oc.code = 'oftar-dx'
  JOIN public.oftar_category cat
         ON cat.catalog_id = oc.id AND cat.code = 'CAT-DX'
ON CONFLICT (code) DO NOTHING;

-- approval_status = draft: requiere revisión/aprobación antes de publicar.
INSERT INTO public.oftar_diagnosis_version
       (diagnosis_id, version_number, definition, approval_status, effective_from)
SELECT d.id,
       1,
       coalesce(a.nombre_es, a.nombre_en, a.code_raw),
       'draft',
       CURRENT_DATE
  FROM _oftar_cie10_dx_asignado a
  JOIN public.oftar_diagnosis d ON d.code = a.new_code
ON CONFLICT (diagnosis_id, version_number) DO NOTHING;

INSERT INTO public.oftar_diagnosis_term
       (diagnosis_id, language, term, term_type)
SELECT d.id, s.language, s.description, 'preferred'
  FROM _oftar_cie10_dx s
  JOIN _oftar_cie10_dx_asignado a ON a.code_normalized = s.code_normalized
  JOIN public.oftar_diagnosis d ON d.code = a.new_code
ON CONFLICT DO NOTHING;

-- El trigger trg_oftar_diagnosis_mapping_identity registra el dueño oftar-dx
-- y completa identity_id. Un código repetido con otro dueño falla acá.
INSERT INTO public.oftar_diagnosis_mapping
       (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT d.id,
       'CIE-10',
       a.code_raw,
       coalesce(a.nombre_es, a.nombre_en, a.code_raw),
       'equivalent'
  FROM _oftar_cie10_dx_asignado a
  JOIN public.oftar_diagnosis d ON d.code = a.new_code
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

-- =============================================================================
-- 5. RESULTADO
-- =============================================================================
DO $$
DECLARE
    v_nuevos INT;
    v_totales INT;
BEGIN
    SELECT count(*) INTO v_nuevos FROM _oftar_cie10_dx_asignado;
    SELECT count(*) INTO v_totales FROM public.oftar_diagnosis;

    RAISE NOTICE 'CIE-10 -> OFTAR-DX: % diagnósticos nuevos; % en total.',
        v_nuevos, v_totales;
END $$;

SELECT system_code, owner_catalog, entity_kind, count(*) AS codigos
  FROM public.oftar_external_identity
 GROUP BY system_code, owner_catalog, entity_kind
 ORDER BY system_code, owner_catalog;

SELECT count(*) AS mapeos_sin_identidad
  FROM public.oftar_diagnosis_mapping
 WHERE identity_id IS NULL;

COMMIT;

-- Fin de importar_cie10_dx.sql
