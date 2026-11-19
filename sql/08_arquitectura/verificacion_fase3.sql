-- =============================================================================
-- VERIFICACIÓN DE LA FASE 3 (§16) · i18n
-- =============================================================================
-- Solo lectura. BEGIN READ_ONLY / ROLLBACK: no escribe en la base.
-- Ejecutar después de sql/08_arquitectura/fase3_i18n.sql:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f sql/08_arquitectura/verificacion_fase3.sql
--
-- OS_IMPORT_MODE no es dato de base. Comprobarlo por separado en el VPS:
--   sudo -u www-data printenv OS_IMPORT_MODE
-- Vacío => modo efectivo `dual` (ImporterIdentity::MODE_DUAL). No activar Fase 13.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN READ ONLY;

\echo '========== 1. D-31: trigger de invalidación =========='
SELECT tgname,
       tgenabled,
       CASE WHEN tgname = 'trg_ocm_invalidate_fr' AND tgenabled = 'O'
            THEN 'OK' ELSE 'FALLO' END AS resultado
  FROM pg_trigger
 WHERE tgrelid = to_regclass('public.os_concept_mapping')
   AND tgname = 'trg_ocm_invalidate_fr';

\echo '========== 2. D-13: exactamente 1 default y 1 fallback por catálogo =========='
-- Debe devolver 0 filas. Se excluye la familia 'dentar', que no publica releases.
SELECT c.code,
       count(l.language_code) FILTER (WHERE l.is_default)  AS defaults,
       count(l.language_code) FILTER (WHERE l.is_fallback) AS fallbacks,
       count(l.language_code) FILTER (WHERE l.is_bridge)   AS bridges
  FROM os_catalog c
  LEFT JOIN os_catalog_language l ON l.catalog_id = c.id
 WHERE c.product_role IS DISTINCT FROM 'family'
 GROUP BY c.code
HAVING count(l.language_code) FILTER (WHERE l.is_default)  <> 1
    OR count(l.language_code) FILTER (WHERE l.is_fallback) <> 1
    OR count(l.language_code) FILTER (WHERE l.is_bridge)   > 1;

\echo '========== 3. Códigos de idioma válidos y activos =========='
-- Debe devolver 0 filas. 'es' y 'es-MX' son source-only y no deben aparecer.
SELECT c.code, l.language_code, idi.is_active, idi.is_source_only
  FROM os_catalog_language l
  JOIN os_catalog c ON c.id = l.catalog_id
  JOIN os_language idi ON idi.code = l.language_code
 WHERE idi.is_active IS DISTINCT FROM TRUE
    OR idi.is_source_only IS DISTINCT FROM FALSE;

\echo '========== 4. Catálogos publicados sin configuración =========='
-- Informativo: la familia 'dentar' queda fuera por diseño.
SELECT c.code, c.product_role
  FROM os_catalog c
  LEFT JOIN os_catalog_language l ON l.catalog_id = c.id
 WHERE c.product_role IS DISTINCT FROM 'family'
   AND l.catalog_id IS NULL
 ORDER BY c.code;

\echo '========== 5. Contenido sembrado =========='
SELECT count(*) AS filas_totales,
       count(*) FILTER (WHERE is_default)  AS defaults,
       count(*) FILTER (WHERE is_fallback) AS fallbacks,
       count(*) FILTER (WHERE is_bridge)   AS bridges
  FROM os_catalog_language;

\echo '========== 6. Grantees sobre os_catalog_language (informativo) =========='
-- origen_med debe conservar SELECT. Si apareciera origen_admin, aplicar el
-- mismo patrón de REVOKE de fase1_correcion_privilegios.sql antes de cerrar.
SELECT grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND table_name = 'os_catalog_language'
 ORDER BY grantee, privilege_type;

\echo '========== 7. Huella multilingüe previa NO reejecutada =========='
SELECT 'os_language' AS objeto, count(*) AS filas FROM os_language
UNION ALL SELECT 'os_language_alias', count(*) FROM os_language_alias
UNION ALL SELECT 'os_catalog_language', count(*) FROM os_catalog_language;

\echo '========== 8. Preferencia es-AR en empates (debe ser 0 filas) =========='
-- Si hay filas, ejecutar fase3_correcion_idioma_default.sql.
WITH contenido AS (
    SELECT i.catalog_id, v.language_code, count(*) AS filas
      FROM os_catalog_item i
      JOIN os_catalog_item_version v ON v.item_id = i.id
      JOIN os_language idi ON idi.code = v.language_code
     WHERE v.language_code IS NOT NULL
       AND idi.is_active
       AND NOT idi.is_source_only
     GROUP BY i.catalog_id, v.language_code
),
preferido AS (
    SELECT c.catalog_id,
           CASE WHEN COALESCE(es.filas, 0) >= COALESCE(en.filas, 0)
                THEN 'es-AR' ELSE 'en' END AS lang
      FROM (SELECT DISTINCT catalog_id FROM contenido) c
      LEFT JOIN contenido es ON es.catalog_id = c.catalog_id AND es.language_code = 'es-AR'
      LEFT JOIN contenido en ON en.catalog_id = c.catalog_id AND en.language_code = 'en'
     WHERE en.filas > 0
)
SELECT c.code, l.language_code AS default_actual, p.lang AS default_esperado
  FROM preferido p
  JOIN os_catalog c ON c.id = p.catalog_id
  JOIN os_catalog_language l ON l.catalog_id = p.catalog_id AND l.is_default
 WHERE l.language_code <> p.lang;

ROLLBACK;
