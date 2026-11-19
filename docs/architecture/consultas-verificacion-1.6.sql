-- =============================================================================
-- Verificación SELECT-only de las contradicciones §1.6
-- docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md
-- =============================================================================
-- NO contiene DDL, DML, DROP, TRUNCATE ni DELETE. Solo SELECT y meta-comandos
-- de psql. Ejecutar contra la base que se quiera verificar (por ejemplo
-- origen_codes) con:
--
--   psql -d origen_codes -v ON_ERROR_STOP=1 -P pager=off \
--     -f docs/architecture/consultas-verificacion-1.6.sql
--
-- Desde el VPS, si aplica peer auth:
--
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -P pager=off \
--     -f /var/www/html/origen.ar/code-api/docs/architecture/consultas-verificacion-1.6.sql
--
-- Las contradicciones 4, 5 y 6 NO requieren base de datos; ver el final.
--
-- RESULTADO REGISTRADO: ejecutado el 2026-11-19 en origen_codes (PostgreSQL
-- 18.6). Las contradicciones 1, 2 y 3 quedaron resueltas; evidencia y hallazgos
-- nuevos en docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md §1.6.
-- =============================================================================

\pset pager off
\set ON_ERROR_STOP on

\echo ''
\echo '========== 0. CONTEXTO =========='
SELECT current_database() AS base,
       current_user        AS usuario,
       current_setting('server_version') AS pg_version,
       now()               AS consultado_el;


-- =============================================================================
-- CONTRADICCIÓN 1
-- [DOC] 844 / 223 / 624 / 218 ítems y 333 relaciones CDT
-- [REPO] 138 PR / 38 DX en SQL versionado; relaciones no ejecutadas
-- =============================================================================

\echo ''
\echo '========== 1A. ÍTEMS POR CATÁLOGO EN os_catalog =========='
SELECT c.code,
       c.name,
       c.family_code,
       c.product_role,
       c.is_active,
       count(i.id)                                        AS items_totales,
       count(*) FILTER (WHERE i.status = 'active')        AS activos,
       count(*) FILTER (WHERE i.status <> 'active')       AS no_activos
FROM os_catalog c
LEFT JOIN os_catalog_item i ON i.catalog_id = c.id
WHERE c.code IN ('dentar-pr', 'dentar-dx', 'dentar-an', 'dentar-cl',
                 'nomenclador-odontologico-ar')
GROUP BY c.code, c.name, c.family_code, c.product_role, c.is_active
ORDER BY c.code;

\echo ''
\echo '========== 1B. EDITORIAL DENTAR (tablas nativas) =========='
SELECT 'dentar_catalog'                  AS tabla, count(*) AS filas FROM dentar_catalog
UNION ALL SELECT 'dentar_concept',        count(*) FROM dentar_concept
UNION ALL SELECT 'dentar_concept_version',count(*) FROM dentar_concept_version
UNION ALL SELECT 'dentar_term',           count(*) FROM dentar_term
UNION ALL SELECT 'dentar_diagnosis',      count(*) FROM dentar_diagnosis
UNION ALL SELECT 'dentar_diagnosis_version', count(*) FROM dentar_diagnosis_version
UNION ALL SELECT 'dentar_diagnosis_term', count(*) FROM dentar_diagnosis_term
UNION ALL SELECT 'dentar_concept_mapping',count(*) FROM dentar_concept_mapping
UNION ALL SELECT 'dentar_diagnosis_mapping', count(*) FROM dentar_diagnosis_mapping
ORDER BY tabla;

\echo ''
\echo '========== 1C. DESGLOSE POR PREFIJO DE CÓDIGO =========='
SELECT substring(code FROM 1 FOR 8) AS prefijo,
       count(*)                     AS total,
       count(*) FILTER (WHERE lifecycle_status = 'active') AS activos
FROM dentar_concept
GROUP BY 1
ORDER BY 1;

\echo ''
\echo '========== 1D. IDENTIFICADORES (CDT-2025 / ANMAT / etc.) =========='
SELECT system_name,
       count(*)            AS identificadores,
       count(DISTINCT item_id) AS items_distintos,
       count(*) FILTER (WHERE is_primary) AS primarios
FROM os_catalog_identifier
GROUP BY system_name
ORDER BY identificadores DESC;

\echo ''
\echo '========== 1E. RELACIONES CDT =========='
SELECT to_regclass('public.os_catalog_relation') IS NOT NULL AS tabla_relation_existe \gset
\if :tabla_relation_existe
  SELECT count(*)                          AS relaciones,
         count(DISTINCT source_item_id)    AS items_origen,
         count(DISTINCT target_item_id)    AS items_destino,
         count(DISTINCT (source_item_id, target_item_id)) AS pares_unicos,
         count(DISTINCT relation_type)     AS tipos_distintos
  FROM os_catalog_relation;

  SELECT relation_type, count(*) AS filas
  FROM os_catalog_relation
  GROUP BY relation_type
  ORDER BY filas DESC, relation_type;
\else
  \echo '>>> os_catalog_relation NO EXISTE en esta base (afirma [REPO]).'
\endif


-- =============================================================================
-- CONTRADICCIÓN 2
-- [DOC/a] decisiones-arquitectura-multilingue.md: "cero ejecución"
-- [DOC/b] sql/07_multilingue/README.md: scripts 01-14 ejecutados, D-19 aprobada
-- No hay tabla de migraciones: se detecta la HUella de cada script.
-- =============================================================================

\echo ''
\echo '========== 2A. HUELLA DE LOS SCRIPTS 01..18 =========='
WITH esperados(objeto, tipo, script) AS (
    VALUES
      ('os_language',                 'tabla',   '01'),
      ('os_language_alias',           'tabla',   '01'),
      ('os_catalog_language',         'tabla',   '01'),
      ('os_localized_text',           'tabla',   '01'),
      ('os_translation_review',       'tabla',   '01'),
      ('os_field_review',             'tabla',   '01'),
      ('os_catalog_item_version.review_status', 'columna', '04'),
      ('os_catalog_item_version.content_hash',  'columna', '04'),
      ('os_catalog_term.review_status',          'columna', '04'),
      ('snomed_descriptions.rf2_language_tag',   'columna', '04'),
      ('os_concept_mapping.review_status',       'columna', '04'),
      ('trg_civ_hash',                'trigger', '05'),
      ('trg_civ_audit',               'trigger', '05'),
      ('trg_olt_audit',               'trigger', '05'),
      ('trg_fr_audit',                'trigger', '05'),
      ('trg_ocm_hash',                'trigger', '05'),
      ('loinc_localized_text',        'tabla',   '07'),
      ('trg_llt_load',                'trigger', '07'),
      ('v_loinc_resolved',            'vista',   '09'),
      ('trg_ocm_invalidate_fr',       'trigger', '18')
)
SELECT e.script,
       e.tipo,
       e.objeto,
       CASE
         WHEN e.tipo IN ('tabla','vista')
           THEN to_regclass('public.' || e.objeto) IS NOT NULL
         WHEN e.tipo = 'columna'
           THEN EXISTS (
             SELECT 1 FROM information_schema.columns c
             WHERE c.table_schema = 'public'
               AND c.table_name = split_part(e.objeto, '.', 1)
               AND c.column_name = split_part(e.objeto, '.', 2))
         WHEN e.tipo = 'trigger'
           THEN EXISTS (
             SELECT 1 FROM pg_trigger t
             WHERE t.tgname = e.objeto AND NOT t.tgisinternal)
         ELSE NULL
       END AS presente
FROM esperados e
ORDER BY e.script, e.tipo, e.objeto;

\echo ''
\echo '========== 2B. SIEMBRA DE IDIOMAS (script 03) =========='
SELECT to_regclass('public.os_language') IS NOT NULL AS tabla_os_language \gset
\if :tabla_os_language
  SELECT code, display_name, primary_tag, is_active, is_source_only
  FROM os_language
  ORDER BY code;

  \echo '--- alias de idioma ---'
  SELECT alias, language_code FROM os_language_alias ORDER BY alias;

  \echo '--- idiomas por catálogo ---'
  SELECT c.code AS catalogo, cl.language_code, cl.is_default,
         cl.is_fallback, cl.is_bridge, cl.coverage_status
  FROM os_catalog_language cl
  JOIN os_catalog c ON c.id = cl.catalog_id
  ORDER BY c.code, cl.language_code;
\else
  \echo '>>> os_language NO EXISTE: capa 01/03 no ejecutada.'
\endif

\echo ''
\echo '========== 2C. APROBACIÓN D-19 (script 15) =========='
SELECT to_regclass('public.os_field_review') IS NOT NULL AS tabla_field_review \gset
\if :tabla_field_review
  SELECT count(*) AS campos_aprobados_d19,
         min(reviewed_at) AS primera_aprobacion,
         max(reviewed_at) AS ultima_aprobacion
  FROM os_field_review
  WHERE reviewed_by = 'd19_editorial_approval';
\else
  \echo '>>> os_field_review NO EXISTE: no puede existir aprobación D-19 registrada.'
\endif

SELECT to_regclass('public.os_translation_review') IS NOT NULL AS tabla_translation_review \gset
\if :tabla_translation_review
  SELECT event_type, action, count(*) AS eventos
  FROM os_translation_review
  WHERE application_user_id = 'd19_editorial_approval'
     OR notes LIKE 'D-19%'
  GROUP BY event_type, action
  ORDER BY eventos DESC;
\else
  \echo '>>> os_translation_review NO EXISTE.'
\endif

\echo ''
\echo '========== 2D. CAPAS LOINC RECUPERADAS (scripts 07/09/13) =========='
SELECT to_regclass('public.loinc_localized_text') IS NOT NULL AS tabla_loinc_localized \gset
\if :tabla_loinc_localized
  SELECT language_code, source_file, source_release,
         count(*) AS filas,
         count(*) FILTER (WHERE review_status = 'approved') AS aprobadas
  FROM loinc_localized_text
  GROUP BY language_code, source_file, source_release
  ORDER BY language_code, source_file;
\else
  \echo '>>> loinc_localized_text NO EXISTE: capa Fase 5 no ejecutada.'
\endif

\echo ''
\echo '========== 2E. CORTE FASE 13 (no es dato de BD) =========='
\echo '>>> OS_IMPORT_MODE es variable de entorno: verificar en el servidor con:'
\echo '>>>   sudo -u www-data printenv OS_IMPORT_MODE'
\echo '>>>   grep -R "OS_IMPORT_MODE" /etc/php /etc/supervisor /etc/environment 2>/dev/null'


-- =============================================================================
-- CONTRADICCIÓN 3
-- [DOC/a] docs/dentar/README.md: "carga real ya verificada de AN/CL y CDT"
-- [REPO]  artefactos generados marcados "NO EJECUTADO"
-- =============================================================================

\echo ''
\echo '========== 3A. AN/CL: CATÁLOGO, ÍTEMS Y TÉRMINOS =========='
SELECT c.code,
       count(DISTINCT i.id)   AS items,
       count(DISTINCT v.id)   AS versiones,
       count(DISTINCT t.id)   AS terminos,
       count(DISTINCT idn.id) AS identificadores,
       count(DISTINCT m.id)   AS mapeos
FROM os_catalog c
LEFT JOIN os_catalog_item i          ON i.catalog_id = c.id
LEFT JOIN os_catalog_item_version v  ON v.item_id = i.id
LEFT JOIN os_catalog_term t          ON t.item_version_id = v.id
LEFT JOIN os_catalog_identifier idn  ON idn.item_id = i.id
LEFT JOIN os_concept_mapping m       ON m.item_id = i.id
WHERE c.code IN ('dentar-an', 'dentar-cl')
GROUP BY c.code
ORDER BY c.code;

\echo ''
\echo '========== 3B. TÉRMINOS AN/CL POR IDIOMA =========='
SELECT c.code AS catalogo, v.language_code, count(*) AS versiones
FROM os_catalog c
JOIN os_catalog_item i         ON i.catalog_id = c.id
JOIN os_catalog_item_version v ON v.item_id = i.id
WHERE c.code IN ('dentar-an', 'dentar-cl')
GROUP BY c.code, v.language_code
ORDER BY c.code, v.language_code;

\echo ''
\echo '========== 3C. MUESTRA DE CÓDIGOS AN/CL (si existen) =========='
SELECT c.code AS catalogo, i.permanent_code, v.preferred_term, v.language_code
FROM os_catalog c
JOIN os_catalog_item i         ON i.catalog_id = c.id
JOIN os_catalog_item_version v ON v.item_id = i.id
WHERE c.code IN ('dentar-an', 'dentar-cl')
ORDER BY c.code, i.permanent_code
LIMIT 10;

\echo ''
\echo '========== 4. INVENTARIO COMPLETO DE CATÁLOGOS =========='
\echo '>>> Para confirmar si nomenclador-odontologico-ar está dado de alta.'
SELECT c.code, c.name, c.family_code, c.product_role, c.is_active,
       count(i.id) AS items
FROM os_catalog c
LEFT JOIN os_catalog_item i ON i.catalog_id = c.id
GROUP BY c.code, c.name, c.family_code, c.product_role, c.is_active
ORDER BY c.code;

\echo ''
\echo '========== FIN DE LA VERIFICACIÓN CON BASE DE DATOS =========='
\echo '>>> Las contradicciones 4, 5 y 6 se verifican solo en el repositorio.'
