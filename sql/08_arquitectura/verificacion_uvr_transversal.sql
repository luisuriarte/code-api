-- =============================================================================
-- U7-B/C/D · VERIFICACIÓN READ ONLY
-- =============================================================================
-- Ejecutar por el responsable, nunca por el agente:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f sql/08_arquitectura/verificacion_uvr_transversal.sql
--
-- No escribe: BEGIN READ ONLY / ROLLBACK. Se ejecuta DESPUÉS de aplicar
-- `uvr_transversal_prestaciones.sql` con backup verificado.
-- =============================================================================

SET client_encoding = 'UTF8';
\pset pager off

BEGIN READ ONLY;

SELECT '=== 1. Objetos U7 presentes ===' AS seccion;
SELECT
    to_regclass('public.os_prestacion') IS NOT NULL AS prestacion,
    to_regclass('public.os_prestacion_codigo') IS NOT NULL AS prestacion_codigo,
    to_regclass('public.os_uvr_profile') IS NOT NULL AS perfil,
    to_regclass('public.os_uvr_profile_component') IS NOT NULL AS perfil_componente,
    to_regclass('public.os_uvr_prestacion_valuation') IS NOT NULL AS valoracion,
    to_regclass('public.os_uvr_prestacion_component') IS NOT NULL AS componente,
    to_regclass('public.v_os_uvr_prestacion_total') IS NOT NULL AS vista_total,
    to_regclass('public.v_os_uvr_prestacion_public') IS NOT NULL AS vista_publica;

SELECT '=== 2. total_uvr sigue derivado ===' AS seccion;
SELECT count(*) AS columnas_total_uvr_almacenadas
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'os_uvr_prestacion_valuation'
   AND column_name = 'total_uvr';

SELECT '=== 3. Tablas nuevas vacías (sin datos inventados) ===' AS seccion;
SELECT 'os_prestacion' AS tabla, count(*) AS filas FROM public.os_prestacion
UNION ALL SELECT 'os_prestacion_codigo', count(*) FROM public.os_prestacion_codigo
UNION ALL SELECT 'os_uvr_profile', count(*) FROM public.os_uvr_profile
UNION ALL SELECT 'os_uvr_profile_component', count(*) FROM public.os_uvr_profile_component
UNION ALL SELECT 'os_uvr_prestacion_valuation', count(*) FROM public.os_uvr_prestacion_valuation
UNION ALL SELECT 'os_uvr_prestacion_component', count(*) FROM public.os_uvr_prestacion_component
ORDER BY tabla;

SELECT '=== 4. FK a actores y a entidades U7 ===' AS seccion;
SELECT conrelid::regclass AS tabla, conname, pg_get_constraintdef(oid) AS definicion
  FROM pg_constraint
 WHERE contype = 'f'
   AND (
        confrelid = 'os_admin.app_user'::regclass
        OR confrelid IN (
            'public.os_prestacion'::regclass,
            'public.os_uvr_profile'::regclass,
            'public.os_uvr_prestacion_valuation'::regclass
        )
   )
   AND conrelid IN (
        'public.os_prestacion'::regclass,
        'public.os_prestacion_codigo'::regclass,
        'public.os_uvr_profile'::regclass,
        'public.os_uvr_profile_component'::regclass,
        'public.os_uvr_prestacion_valuation'::regclass,
        'public.os_uvr_prestacion_component'::regclass
   )
 ORDER BY conrelid::regclass::text, conname;

SELECT '=== 5. CHECK de evidencia y aplicabilidad ===' AS seccion;
SELECT conrelid::regclass AS tabla, conname, pg_get_constraintdef(oid) AS definicion
  FROM pg_constraint
 WHERE contype = 'c'
   AND conrelid IN (
        'public.os_prestacion'::regclass,
        'public.os_uvr_profile'::regclass,
        'public.os_uvr_profile_component'::regclass,
        'public.os_uvr_prestacion_component'::regclass
   )
 ORDER BY conrelid::regclass::text, conname;

SELECT '=== 6. Triggers U7 activos ===' AS seccion;
SELECT c.relname AS tabla, t.tgname
  FROM pg_trigger t
  JOIN pg_class c ON c.oid = t.tgrelid
 WHERE NOT t.tgisinternal
   AND t.tgname IN (
        'trg_os_uvr_prestacion_immutable',
        'trg_os_prestacion_audit',
        'trg_os_prestacion_codigo_audit',
        'trg_os_uvr_profile_audit',
        'trg_os_uvr_profile_component_audit',
        'trg_os_uvr_prestacion_valuation_audit',
        'trg_os_uvr_prestacion_component_audit',
        'trg_os_audit_log_immutable'
   )
 ORDER BY tabla, tgname;

SELECT '=== 7. Grants explícitos ===' AS seccion;
SELECT table_name AS objeto, grantee,
       string_agg(privilege_type, ',' ORDER BY privilege_type) AS privilegios
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND grantee IN ('origen_admin', 'origen_med')
   AND table_name IN (
        'os_prestacion', 'os_prestacion_codigo', 'os_uvr_profile',
        'os_uvr_profile_component', 'os_uvr_prestacion_valuation',
        'os_uvr_prestacion_component', 'v_os_uvr_prestacion_total',
        'v_os_uvr_prestacion_public'
   )
 GROUP BY table_name, grantee
 ORDER BY table_name, grantee;

SELECT '=== 8. Sin grantees no deseados en PUBLIC ===' AS seccion;
SELECT table_name AS objeto, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND grantee = 'PUBLIC'
   AND table_name IN (
        'os_prestacion', 'os_prestacion_codigo', 'os_uvr_profile',
        'os_uvr_profile_component', 'os_uvr_prestacion_valuation',
        'os_uvr_prestacion_component', 'v_os_uvr_prestacion_total',
        'v_os_uvr_prestacion_public'
   )
 ORDER BY table_name, privilege_type;

SELECT '=== 9. Concisión de la vista pública ===' AS seccion;
SELECT column_name
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'v_os_uvr_prestacion_public'
 ORDER BY ordinal_position;

SELECT '=== 10. Regresión U0–U6 intacta ===' AS seccion;
SELECT 'os_uvr_eligible_catalog' AS tabla, count(*) AS filas FROM public.os_uvr_eligible_catalog
UNION ALL SELECT 'os_uvr_valuation', count(*) FROM public.os_uvr_valuation
UNION ALL SELECT 'os_uvr_component', count(*) FROM public.os_uvr_component
UNION ALL SELECT 'os_uvr_conversion', count(*) FROM public.os_uvr_conversion
UNION ALL SELECT 'os_uvr_geo_index', count(*) FROM public.os_uvr_geo_index
ORDER BY tabla;

SELECT '=== 11. Regresión de catálogos intacta ===' AS seccion;
SELECT 'os_catalog' AS tabla, count(*) AS filas FROM public.os_catalog
UNION ALL SELECT 'os_catalog_item', count(*) FROM public.os_catalog_item
UNION ALL SELECT 'os_catalog_relation', count(*) FROM public.os_catalog_relation
UNION ALL SELECT 'os_language', count(*) FROM public.os_language
ORDER BY tabla;

ROLLBACK;
