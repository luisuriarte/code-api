-- =============================================================================
-- GOBERNANZA UVR · VERIFICACIÓN READ ONLY (U1/U4/U5)
-- =============================================================================
-- Ejecutar por el responsable, nunca por el agente:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f sql/08_arquitectura/verificacion_uvr_gobernanza.sql
--
-- No escribe: BEGIN READ_ONLY / ROLLBACK. Si alguna comprobación falla, no
-- ejecutar la migración y revisar el acta U0.
-- =============================================================================

SET client_encoding = 'UTF8';
\pset pager off

BEGIN READ ONLY;

SELECT '=== 1. Modelo UVR y gobernanza presentes ===' AS seccion;
SELECT
    to_regclass('public.os_review_state') IS NOT NULL AS review_state,
    to_regclass('os_admin.app_user') IS NOT NULL AS app_user,
    to_regclass('public.os_governance_request') IS NOT NULL AS governance_request,
    to_regclass('public.os_governance_review') IS NOT NULL AS governance_review,
    to_regclass('public.os_governance_decision') IS NOT NULL AS governance_decision,
    to_regclass('public.os_audit_log') IS NOT NULL AS audit_log,
    to_regclass('public.os_uvr_eligible_catalog') IS NOT NULL AS uvr_eligible,
    to_regclass('public.os_uvr_valuation') IS NOT NULL AS uvr_valuation,
    to_regclass('public.os_uvr_component') IS NOT NULL AS uvr_component,
    to_regclass('public.os_uvr_conversion') IS NOT NULL AS uvr_conversion,
    to_regclass('public.os_uvr_geo_index') IS NOT NULL AS uvr_geo_index,
    to_regclass('public.v_os_uvr_valuation_governed') IS NOT NULL AS uvr_governed_view;

SELECT '=== 2. Columnas gobernadas ===' AS seccion;
SELECT table_name, column_name, data_type, is_nullable
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name IN ('os_uvr_valuation', 'os_uvr_component')
   AND column_name IN (
       'calculated_by_user_id', 'approved_by_user_id', 'published_at',
       'is_not_applicable', 'negative_adjustment_evidence'
   )
 ORDER BY table_name, column_name;

SELECT '=== 3. total_uvr NO almacenado ===' AS seccion;
SELECT count(*) AS columnas_total_uvr_en_valuation
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'os_uvr_valuation'
   AND column_name = 'total_uvr';

SELECT '=== 4. FK de actores a os_admin.app_user ===' AS seccion;
SELECT conrelid::regclass AS tabla, conname, pg_get_constraintdef(oid) AS definicion
  FROM pg_constraint
 WHERE contype = 'f'
   AND confrelid = 'os_admin.app_user'::regclass
   AND conrelid IN (
       'public.os_uvr_valuation'::regclass,
       'public.os_governance_request'::regclass,
       'public.os_governance_review'::regclass,
       'public.os_governance_decision'::regclass,
       'public.os_audit_log'::regclass
   )
 ORDER BY conrelid::regclass::text, conname;

SELECT '=== 5. CHECK gobernado de componentes ===' AS seccion;
SELECT conname, pg_get_constraintdef(oid) AS definicion
  FROM pg_constraint
 WHERE conrelid = 'public.os_uvr_component'::regclass
   AND contype = 'c'
 ORDER BY conname;

SELECT '=== 6. Triggers UVR activos ===' AS seccion;
SELECT c.relname AS tabla, t.tgname
  FROM pg_trigger t
  JOIN pg_class c ON c.oid = t.tgrelid
 WHERE NOT t.tgisinternal
   AND t.tgname IN (
       'trg_os_uvr_valuation_eligible',
       'trg_os_uvr_valuation_immutable',
       'trg_os_uvr_publication_ready',
       'trg_os_uvr_valuation_audit',
       'trg_os_uvr_component_audit',
       'trg_os_uvr_conversion_audit',
       'trg_os_uvr_geo_index_audit',
       'trg_os_audit_log_immutable'
   )
 ORDER BY tabla, tgname;

SELECT '=== 7. Grants explícitos del panel ===' AS seccion;
SELECT table_name AS objeto, grantee, string_agg(privilege_type, ',' ORDER BY privilege_type) AS privilegios
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND grantee = 'origen_admin'
   AND table_name IN (
       'os_uvr_valuation', 'os_uvr_component', 'os_uvr_conversion',
       'os_uvr_geo_index', 'v_os_uvr_valuation_total',
       'v_os_uvr_valuation_governed', 'os_governance_request',
       'os_governance_review', 'os_governance_decision', 'os_audit_log'
   )
 GROUP BY table_name, grantee
 ORDER BY table_name;

SELECT '=== 8. Sin grantees no deseados en PUBLIC ===' AS seccion;
SELECT table_name AS objeto, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND grantee = 'PUBLIC'
   AND table_name IN (
       'os_uvr_valuation', 'os_uvr_component', 'os_uvr_conversion',
       'os_uvr_geo_index', 'v_os_uvr_valuation_governed',
       'os_governance_request', 'os_governance_review',
       'os_governance_decision', 'os_audit_log'
   )
 ORDER BY table_name, privilege_type;

SELECT '=== 9. Datos UVR siguen vacíos y regresión estable ===' AS seccion;
SELECT 'os_uvr_eligible_catalog' AS tabla, count(*) AS filas FROM public.os_uvr_eligible_catalog
UNION ALL SELECT 'os_uvr_valuation', count(*) FROM public.os_uvr_valuation
UNION ALL SELECT 'os_uvr_component', count(*) FROM public.os_uvr_component
UNION ALL SELECT 'os_uvr_conversion', count(*) FROM public.os_uvr_conversion
UNION ALL SELECT 'os_uvr_geo_index', count(*) FROM public.os_uvr_geo_index
UNION ALL SELECT 'os_governance_request', count(*) FROM public.os_governance_request
UNION ALL SELECT 'os_governance_review', count(*) FROM public.os_governance_review
UNION ALL SELECT 'os_governance_decision', count(*) FROM public.os_governance_decision
ORDER BY tabla;

SELECT '=== 10. Regresión y legado ===' AS seccion;
SELECT
    (SELECT count(*) FROM public.os_catalog_relation) AS relaciones,
    (SELECT count(*) FROM public.os_catalog_language) AS idiomas,
    (SELECT count(*) FROM public.os_catalog_reservation WHERE catalog_id IS NOT NULL) AS reservas_vinculadas,
    (SELECT count(*) FROM public.os_uvr_valuation) AS valoraciones_uvr,
    (SELECT count(*) FROM public.os_substance) AS sustancias,
    (SELECT count(*) FROM public.os_medicinal_product) AS productos,
    (SELECT count(*) FROM public.os_product_package) AS presentaciones,
    (SELECT count(*) FROM public.os_product_identifier) AS identificadores;

ROLLBACK;
