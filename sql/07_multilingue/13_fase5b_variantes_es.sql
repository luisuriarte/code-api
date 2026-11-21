-- =============================================================================
-- FASE 5b · Recuperar capas LOINC es-MX y es-AR desde los CSV (SQL puro)
-- =============================================================================
-- Entorno de PRUEBAS. Aditivo e idempotente: INSERT ... ON CONFLICT DO NOTHING.
-- NO modifica sql/05_loinc.sql/importar_loinc.sql, NO toca la tabla loinc,
-- NO contiene DROP/TRUNCATE/DELETE de datos, NO contiene meta-comandos.
-- Válido en psql y en DBeaver-CE.
-- Fuentes: modelo §4.4; plan Fase 5; D-08, D-19, D-29, D-33, D-39, D-40.
--
-- Por qué existe: el importador sobrescribió 12 campos con esMX28LinguisticVariant.csv
-- y después con esAR7LinguisticVariant.csv (importar_loinc.sql:162-230). Esas
-- capas se recuperan aquí como filas separadas en loinc_localized_text, sin
-- tocar loinc ni el importador.
--
-- CAMBIO RESPECTO A LA VERSIÓN ANTERIOR: el INSERT único de ~400.000 filas era
-- demasiado largo y no mostraba progreso (el trigger de auditoría escribe una
-- fila por registro). Ahora se inserta CAMPO POR CAMPO dentro de UNA SOLA
-- transacción: psql imprime "INSERT 0 N" después de cada campo. Un reintento
-- no duplica nada porque el staging es temporal y todos los INSERT usan
-- ON CONFLICT DO NOTHING. Si falla, ROLLBACK completo.
--
-- El trigger trg_llt_load calcula prioridad, evidencia, versión normalizada
-- ('(sin_version)': estos CSV no traen VersionLastChanged) y content_hash.
-- Nada se marca approved: provenance='unknown', review_status='unknown'.
-- source_release='2.83' se toma de importar_loinc.sql:2-5 (los CSV de
-- variantes no tienen columna de versión; se documenta, no se inventa).
--
-- Requisito: el usuario postgres del servidor debe poder LEER:
--   /var/www/html/origen.ar/code-api/tools/sources/loinc/esMX28LinguisticVariant.csv
--   /var/www/html/origen.ar/code-api/tools/sources/loinc/esAR7LinguisticVariant.csv
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Etapa 1 · staged de los CSV (rápido; ya verificado en ejecuciones previas)
-- ---------------------------------------------------------------------------
BEGIN;

CREATE TEMP TABLE IF NOT EXISTS _loinc_mx_variant (
    loinc_num VARCHAR(20), component TEXT, property VARCHAR(255),
    time_aspct VARCHAR(255), system VARCHAR(255), scale_typ VARCHAR(255),
    method_typ VARCHAR(255), class VARCHAR(255), shortname TEXT,
    long_common_name TEXT, relatednames2 TEXT,
    linguistic_variant_display_name TEXT, consumer_name TEXT);

CREATE TEMP TABLE IF NOT EXISTS _loinc_ar_variant (
    loinc_num VARCHAR(20), component TEXT, property VARCHAR(255),
    time_aspct VARCHAR(255), system VARCHAR(255), scale_typ VARCHAR(255),
    method_typ VARCHAR(255), class VARCHAR(255), shortname TEXT,
    long_common_name TEXT, relatednames2 TEXT,
    linguistic_variant_display_name TEXT, consumer_name TEXT);

COPY _loinc_mx_variant (
    loinc_num, component, property, time_aspct, system, scale_typ, method_typ,
    class, shortname, long_common_name, relatednames2,
    linguistic_variant_display_name, consumer_name)
FROM '/var/www/html/origen.ar/code-api/tools/sources/loinc/esMX28LinguisticVariant.csv'
WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"', ENCODING 'UTF8', NULL '');

COPY _loinc_ar_variant (
    loinc_num, component, property, time_aspct, system, scale_typ, method_typ,
    class, shortname, long_common_name, relatednames2,
    linguistic_variant_display_name, consumer_name)
FROM '/var/www/html/origen.ar/code-api/tools/sources/loinc/esAR7LinguisticVariant.csv'
WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"', ENCODING 'UTF8', NULL '');

SELECT 'control de códigos (ausentes DEBE SER 0)' AS progreso;
SELECT 'es-MX' AS capa, count(*) AS filas_csv,
       count(l.loinc) AS codigos_validos,
       count(*) - count(l.loinc) AS codigos_ausentes_en_loinc
FROM _loinc_mx_variant s LEFT JOIN loinc l ON l.loinc = s.loinc_num
UNION ALL
SELECT 'es-AR', count(*), count(l.loinc), count(*) - count(l.loinc)
FROM _loinc_ar_variant s LEFT JOIN loinc l ON l.loinc = s.loinc_num;


-- ---------------------------------------------------------------------------
-- Etapa 2 · es-MX: un campo por transacción (12 bloques)
-- ---------------------------------------------------------------------------
SELECT 'es-MX · component' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'component', s.component,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.component, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-MX · property' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'property', s.property,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.property, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-MX · time_aspct' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'time_aspct', s.time_aspct,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.time_aspct, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-MX · system_type' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'system_type', s.system,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.system, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-MX · scale_type' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'scale_type', s.scale_typ,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.scale_typ, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-MX · method_type' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'method_type', s.method_typ,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.method_typ, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-MX · class_type' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'class_type', s.class,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.class, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-MX · shortname' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'shortname', s.shortname,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.shortname, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-MX · long_common_name' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'long_common_name', s.long_common_name,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.long_common_name, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-MX · relatednames2' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'relatednames2', s.relatednames2,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.relatednames2, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-MX · display_name' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'display_name', s.linguistic_variant_display_name,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.linguistic_variant_display_name, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-MX · consumer_name' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-MX', 'consumer_name', s.consumer_name,
       'esMX28LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_mx_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.consumer_name, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Etapa 3 · es-AR: un campo por transacción (12 bloques)
-- ---------------------------------------------------------------------------
SELECT 'es-AR · component' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'component', s.component,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.component, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-AR · property' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'property', s.property,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.property, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-AR · time_aspct' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'time_aspct', s.time_aspct,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.time_aspct, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-AR · system_type' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'system_type', s.system,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.system, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-AR · scale_type' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'scale_type', s.scale_typ,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.scale_typ, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-AR · method_type' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'method_type', s.method_typ,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.method_typ, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-AR · class_type' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'class_type', s.class,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.class, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-AR · shortname' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'shortname', s.shortname,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.shortname, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-AR · long_common_name' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'long_common_name', s.long_common_name,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.long_common_name, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-AR · relatednames2' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'relatednames2', s.relatednames2,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.relatednames2, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-AR · display_name' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'display_name', s.linguistic_variant_display_name,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.linguistic_variant_display_name, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

SELECT 'es-AR · consumer_name' AS progreso;
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value, source_file, source_release,
     version_last_changed, provenance, review_status, source_reference)
SELECT s.loinc_num, 'es-AR', 'consumer_name', s.consumer_name,
       'esAR7LinguisticVariant.csv', '2.83', NULL, 'unknown', 'unknown', NULL
FROM _loinc_ar_variant s JOIN loinc l ON l.loinc = s.loinc_num
WHERE NULLIF(btrim(COALESCE(s.consumer_name, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

COMMIT;

-- ---------------------------------------------------------------------------
-- Etapa 4 · verificación de cierre (solo lectura)
-- ---------------------------------------------------------------------------
SELECT language_code, source_file, count(*) AS filas,
       min(source_priority) AS prioridad,
       count(*) FILTER (WHERE language_evidence = 'undetermined') AS sin_evidencia
FROM loinc_localized_text
GROUP BY language_code, source_file ORDER BY language_code, source_file;

SELECT count(*) AS sin_evidencia_acreditada
FROM loinc_localized_text
WHERE language_evidence = 'undetermined' OR source_priority = 0;

SELECT count(*) AS prioridades_divergentes
FROM loinc_localized_text
WHERE source_priority IS DISTINCT FROM
      loinc_source_priority(language_code, source_file, field_name);

SELECT count(*) AS conflictos FROM v_loinc_resolved WHERE es_conflicto;
SELECT count(*) AS aprobados_sin_evidencia
FROM loinc_localized_text WHERE review_status = 'approved';
SELECT count(*) AS versiones_sin_version
FROM loinc_localized_text
WHERE version_last_changed_normalizada = '(sin_version)';

-- Fin de Fase 5b · capas es-MX/es-AR recuperadas de los CSV.
