-- =============================================================================
-- Verificación SOLO LECTURA de la rama pública LOINC (CatalogRepository).
-- SQL generado por loincBranch() para:
--   en / infarction, es-AR / infarto y ficha 58258-5.
-- Ejecutar: psql -d origen_codes -f 99_verificacion_rama_publica.sql
-- Si sigue siendo lento, repetir la primera consulta con:
--   EXPLAIN (ANALYZE, BUFFERS) <consulta>;
-- =============================================================================
\timing on
SET statement_timeout = '15s';

-- en / infarction
SELECT 'loinc' AS domain, 'loinc' AS source,
 'loinc:' || t.loinc AS result_key,
 t.loinc AS source_id, t.loinc AS code,
 coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component) AS term, coalesce(nullif(l.loc_component, ''), nullif(t.component, ''), nullif(l.loc_shortname, ''), nullif(t.shortname, '')) AS subtitle,
 coalesce(l.loc_lang_long, l.loc_lang_display, l.loc_lang_short, l.loc_lang_component, 'es-AR') AS language, 'loinc_observation' AS kind,
 CAST(GREATEST(CASE WHEN lower(t.loinc) = lower('infarction') THEN CAST(1.0 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN t.loinc ILIKE 'infarction%' THEN CAST(0.96 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN lower(coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component)) = lower('infarction') THEN CAST(0.94 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component) ILIKE 'infarction%' THEN CAST(0.90 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN coalesce(nullif(l.loc_display_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, '')) ILIKE 'infarction%' THEN CAST(0.88 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN l.loc_component ILIKE 'infarction%' THEN CAST(0.86 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN l.loc_consumer_name ILIKE 'infarction%' THEN CAST(0.84 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component) ILIKE '%infarction%' THEN CAST(0.78 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN coalesce(nullif(l.loc_display_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, '')) ILIKE '%infarction%' THEN CAST(0.76 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN coalesce(nullif(l.loc_consumer_name, ''), nullif(l.loc_relatednames2, '')) ILIKE '%infarction%' THEN CAST(0.75 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN l.loc_component ILIKE '%infarction%' THEN CAST(0.74 AS float8) ELSE CAST(0.0 AS float8) END, CAST(similarity(coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component), 'infarction') AS float8)) AS float8) AS score, CAST(json_build_object('loinc_code', t.loinc, 'class_type', coalesce(nullif(l.loc_class_type, ''), t.class_type), 'system_type', coalesce(nullif(l.loc_system_type, ''), t.system_type), 'scale_type', coalesce(nullif(l.loc_scale_type, ''), t.scale_type), 'method_type', coalesce(nullif(l.loc_method_type, ''), t.method_type), 'status', t.status, 'consumer_name', coalesce(nullif(l.loc_consumer_name, ''), t.consumer_name), 'example_ucum_units', t.example_ucum_units) AS text) AS metadata
 FROM (SELECT DISTINCT l.loinc_code
 FROM loinc_localized_text l
 WHERE l.language_code IN ('en', 'es-AR', 'es-MX')
   AND l.source_release = '2.83'
   AND l.field_name IN ('long_common_name','display_name','shortname','component','consumer_name','relatednames2')
   AND l.value ILIKE '%infarction%') m
 JOIN loinc t ON t.loinc = m.loinc_code
 CROSS JOIN LATERAL (SELECT
 max(x.value) FILTER (WHERE x.field_name = 'long_common_name') AS loc_long_common_name,
 max(x.value) FILTER (WHERE x.field_name = 'display_name') AS loc_display_name,
 max(x.value) FILTER (WHERE x.field_name = 'shortname') AS loc_shortname,
 max(x.value) FILTER (WHERE x.field_name = 'component') AS loc_component,
 max(x.value) FILTER (WHERE x.field_name = 'consumer_name') AS loc_consumer_name,
 max(x.value) FILTER (WHERE x.field_name = 'relatednames2') AS loc_relatednames2,
 max(x.value) FILTER (WHERE x.field_name = 'class_type') AS loc_class_type,
 max(x.value) FILTER (WHERE x.field_name = 'system_type') AS loc_system_type,
 max(x.value) FILTER (WHERE x.field_name = 'scale_type') AS loc_scale_type,
 max(x.value) FILTER (WHERE x.field_name = 'method_type') AS loc_method_type,
 max(x.language_code) FILTER (WHERE x.field_name = 'long_common_name') AS loc_lang_long,
 max(x.language_code) FILTER (WHERE x.field_name = 'display_name') AS loc_lang_display,
 max(x.language_code) FILTER (WHERE x.field_name = 'shortname') AS loc_lang_short,
 max(x.language_code) FILTER (WHERE x.field_name = 'component') AS loc_lang_component
 FROM (
  SELECT DISTINCT ON (field_name) field_name, value, language_code
  FROM loinc_localized_text
  WHERE loinc_code = t.loinc
    AND language_code IN ('en', 'es-AR', 'es-MX')
    AND field_name IN ('long_common_name','display_name','shortname','component','consumer_name','relatednames2','class_type','system_type','scale_type','method_type')
    AND source_release = '2.83'
    AND NULLIF(btrim(value), '') IS NOT NULL
  ORDER BY field_name,
    CASE language_code WHEN 'en' THEN 1 WHEN 'es-AR' THEN 2 ELSE 3 END,
    source_priority DESC, source_file ASC,
    version_last_changed DESC NULLS LAST
 ) x) l
 WHERE (coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component) ILIKE '%infarction%' OR coalesce(nullif(l.loc_display_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, '')) ILIKE '%infarction%' OR coalesce(nullif(l.loc_consumer_name, ''), nullif(l.loc_relatednames2, '')) ILIKE '%infarction%');

-- es-AR / infarto
SELECT 'loinc' AS domain, 'loinc' AS source,
 'loinc:' || t.loinc AS result_key,
 t.loinc AS source_id, t.loinc AS code,
 coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component) AS term, coalesce(nullif(l.loc_component, ''), nullif(t.component, ''), nullif(l.loc_shortname, ''), nullif(t.shortname, '')) AS subtitle,
 coalesce(l.loc_lang_long, l.loc_lang_display, l.loc_lang_short, l.loc_lang_component, 'es-AR') AS language, 'loinc_observation' AS kind,
 CAST(GREATEST(CASE WHEN lower(t.loinc) = lower('infarto') THEN CAST(1.0 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN t.loinc ILIKE 'infarto%' THEN CAST(0.96 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN lower(coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component)) = lower('infarto') THEN CAST(0.94 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component) ILIKE 'infarto%' THEN CAST(0.90 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN coalesce(nullif(l.loc_display_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, '')) ILIKE 'infarto%' THEN CAST(0.88 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN l.loc_component ILIKE 'infarto%' THEN CAST(0.86 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN l.loc_consumer_name ILIKE 'infarto%' THEN CAST(0.84 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component) ILIKE '%infarto%' THEN CAST(0.78 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN coalesce(nullif(l.loc_display_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, '')) ILIKE '%infarto%' THEN CAST(0.76 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN coalesce(nullif(l.loc_consumer_name, ''), nullif(l.loc_relatednames2, '')) ILIKE '%infarto%' THEN CAST(0.75 AS float8) ELSE CAST(0.0 AS float8) END, CASE WHEN l.loc_component ILIKE '%infarto%' THEN CAST(0.74 AS float8) ELSE CAST(0.0 AS float8) END, CAST(similarity(coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component), 'infarto') AS float8)) AS float8) AS score, CAST(json_build_object('loinc_code', t.loinc, 'class_type', coalesce(nullif(l.loc_class_type, ''), t.class_type), 'system_type', coalesce(nullif(l.loc_system_type, ''), t.system_type), 'scale_type', coalesce(nullif(l.loc_scale_type, ''), t.scale_type), 'method_type', coalesce(nullif(l.loc_method_type, ''), t.method_type), 'status', t.status, 'consumer_name', coalesce(nullif(l.loc_consumer_name, ''), t.consumer_name), 'example_ucum_units', t.example_ucum_units) AS text) AS metadata
 FROM (SELECT DISTINCT l.loinc_code
 FROM loinc_localized_text l
 WHERE l.language_code IN ('es-AR', 'es-MX', 'en')
   AND l.source_release = '2.83'
   AND l.field_name IN ('long_common_name','display_name','shortname','component','consumer_name','relatednames2')
   AND l.value ILIKE '%infarto%') m
 JOIN loinc t ON t.loinc = m.loinc_code
 CROSS JOIN LATERAL (SELECT
 max(x.value) FILTER (WHERE x.field_name = 'long_common_name') AS loc_long_common_name,
 max(x.value) FILTER (WHERE x.field_name = 'display_name') AS loc_display_name,
 max(x.value) FILTER (WHERE x.field_name = 'shortname') AS loc_shortname,
 max(x.value) FILTER (WHERE x.field_name = 'component') AS loc_component,
 max(x.value) FILTER (WHERE x.field_name = 'consumer_name') AS loc_consumer_name,
 max(x.value) FILTER (WHERE x.field_name = 'relatednames2') AS loc_relatednames2,
 max(x.value) FILTER (WHERE x.field_name = 'class_type') AS loc_class_type,
 max(x.value) FILTER (WHERE x.field_name = 'system_type') AS loc_system_type,
 max(x.value) FILTER (WHERE x.field_name = 'scale_type') AS loc_scale_type,
 max(x.value) FILTER (WHERE x.field_name = 'method_type') AS loc_method_type,
 max(x.language_code) FILTER (WHERE x.field_name = 'long_common_name') AS loc_lang_long,
 max(x.language_code) FILTER (WHERE x.field_name = 'display_name') AS loc_lang_display,
 max(x.language_code) FILTER (WHERE x.field_name = 'shortname') AS loc_lang_short,
 max(x.language_code) FILTER (WHERE x.field_name = 'component') AS loc_lang_component
 FROM (
  SELECT DISTINCT ON (field_name) field_name, value, language_code
  FROM loinc_localized_text
  WHERE loinc_code = t.loinc
    AND language_code IN ('es-AR', 'es-MX', 'en')
    AND field_name IN ('long_common_name','display_name','shortname','component','consumer_name','relatednames2','class_type','system_type','scale_type','method_type')
    AND source_release = '2.83'
    AND NULLIF(btrim(value), '') IS NOT NULL
  ORDER BY field_name,
    CASE language_code WHEN 'es-AR' THEN 1 WHEN 'es-MX' THEN 2 ELSE 3 END,
    source_priority DESC, source_file ASC,
    version_last_changed DESC NULLS LAST
 ) x) l
 WHERE (coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component) ILIKE '%infarto%' OR coalesce(nullif(l.loc_display_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, '')) ILIKE '%infarto%' OR coalesce(nullif(l.loc_consumer_name, ''), nullif(l.loc_relatednames2, '')) ILIKE '%infarto%');

-- es-AR / 58258-5
SELECT 'loinc' AS domain, 'loinc' AS source,
 'loinc:' || t.loinc AS result_key,
 t.loinc AS source_id, t.loinc AS code,
 coalesce(nullif(l.loc_long_common_name, ''), nullif(l.loc_display_name, ''), nullif(l.loc_consumer_name, ''), nullif(l.loc_shortname, ''), nullif(l.loc_component, ''), nullif(t.long_common_name, ''), t.component) AS term, coalesce(nullif(l.loc_component, ''), nullif(t.component, ''), nullif(l.loc_shortname, ''), nullif(t.shortname, '')) AS subtitle,
 coalesce(l.loc_lang_long, l.loc_lang_display, l.loc_lang_short, l.loc_lang_component, 'es-AR') AS language, 'loinc_observation' AS kind,
 CAST(1.0 AS float8) AS score, CAST(json_build_object('loinc_code', t.loinc, 'class_type', coalesce(nullif(l.loc_class_type, ''), t.class_type), 'system_type', coalesce(nullif(l.loc_system_type, ''), t.system_type), 'scale_type', coalesce(nullif(l.loc_scale_type, ''), t.scale_type), 'method_type', coalesce(nullif(l.loc_method_type, ''), t.method_type), 'status', t.status, 'consumer_name', coalesce(nullif(l.loc_consumer_name, ''), t.consumer_name), 'example_ucum_units', t.example_ucum_units) AS text) AS metadata
 FROM (SELECT CAST('58258-5' AS VARCHAR(20)) AS loinc_code) m
 JOIN loinc t ON t.loinc = m.loinc_code
 CROSS JOIN LATERAL (SELECT
 max(x.value) FILTER (WHERE x.field_name = 'long_common_name') AS loc_long_common_name,
 max(x.value) FILTER (WHERE x.field_name = 'display_name') AS loc_display_name,
 max(x.value) FILTER (WHERE x.field_name = 'shortname') AS loc_shortname,
 max(x.value) FILTER (WHERE x.field_name = 'component') AS loc_component,
 max(x.value) FILTER (WHERE x.field_name = 'consumer_name') AS loc_consumer_name,
 max(x.value) FILTER (WHERE x.field_name = 'relatednames2') AS loc_relatednames2,
 max(x.value) FILTER (WHERE x.field_name = 'class_type') AS loc_class_type,
 max(x.value) FILTER (WHERE x.field_name = 'system_type') AS loc_system_type,
 max(x.value) FILTER (WHERE x.field_name = 'scale_type') AS loc_scale_type,
 max(x.value) FILTER (WHERE x.field_name = 'method_type') AS loc_method_type,
 max(x.language_code) FILTER (WHERE x.field_name = 'long_common_name') AS loc_lang_long,
 max(x.language_code) FILTER (WHERE x.field_name = 'display_name') AS loc_lang_display,
 max(x.language_code) FILTER (WHERE x.field_name = 'shortname') AS loc_lang_short,
 max(x.language_code) FILTER (WHERE x.field_name = 'component') AS loc_lang_component
 FROM (
  SELECT DISTINCT ON (field_name) field_name, value, language_code
  FROM loinc_localized_text
  WHERE loinc_code = t.loinc
    AND language_code IN ('es-AR', 'es-MX', 'en')
    AND field_name IN ('long_common_name','display_name','shortname','component','consumer_name','relatednames2','class_type','system_type','scale_type','method_type')
    AND source_release = '2.83'
    AND NULLIF(btrim(value), '') IS NOT NULL
  ORDER BY field_name,
    CASE language_code WHEN 'es-AR' THEN 1 WHEN 'es-MX' THEN 2 ELSE 3 END,
    source_priority DESC, source_file ASC,
    version_last_changed DESC NULLS LAST
 ) x) l
 WHERE true;

