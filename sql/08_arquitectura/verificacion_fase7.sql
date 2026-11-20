-- =============================================================================
-- VERIFICACIÓN DE LA FASE 7 (§16) · módulo UVR sin valores inventados
-- =============================================================================
-- Solo lectura. BEGIN READ_ONLY / ROLLBACK: no escribe en la base.
-- Ejecutar después de sql/08_arquitectura/fase6_uvr.sql:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f sql/08_arquitectura/verificacion_fase7.sql
--
-- El nombre del archivo de migración conserva la numeración histórica; según
-- §16 esta es la Fase 7. Ver sql/08_arquitectura/README.md.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN READ ONLY;

\echo '========== 1. Cinco tablas nuevas =========='
SELECT tablename
  FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN (
       'os_uvr_eligible_catalog', 'os_uvr_valuation', 'os_uvr_component',
       'os_uvr_conversion', 'os_uvr_geo_index'
   )
 ORDER BY tablename;

\echo '========== 2. Elegibilidad: 1 fila real (dentar-pr), DENTAR-DX excluido =========='
SELECT catalog_code, source_reference, is_active
  FROM os_uvr_eligible_catalog
 ORDER BY catalog_code;

SELECT count(*) AS filas_dx
  FROM os_uvr_eligible_catalog
 WHERE catalog_code = 'dentar-dx';

\echo '========== 3. Tablas de valoración VACÍAS (0 filas cada una) =========='
SELECT 'os_uvr_valuation' AS tabla, count(*) AS filas FROM os_uvr_valuation
UNION ALL SELECT 'os_uvr_component', count(*) FROM os_uvr_component
UNION ALL SELECT 'os_uvr_conversion', count(*) FROM os_uvr_conversion
UNION ALL SELECT 'os_uvr_geo_index', count(*) FROM os_uvr_geo_index
ORDER BY tabla;

\echo '========== 4. Constraints de integridad (7) =========='
SELECT conname
  FROM pg_constraint
 WHERE conrelid IN (
     to_regclass('public.os_uvr_valuation'),
     to_regclass('public.os_uvr_component'),
     to_regclass('public.os_uvr_conversion'),
     to_regclass('public.os_uvr_geo_index')
 )
   AND conname IN (
       'uq_os_uvr_valuation', 'ck_os_uvr_valuation_validity',
       'uq_os_uvr_conversion', 'ck_os_uvr_conversion_validity',
       'uq_os_uvr_geo_index', 'ck_os_uvr_geo_index_validity',
       'os_uvr_component_valuation_id_component_type_key'
   )
 ORDER BY conname;

\echo '========== 5. FK a los tres componentes (CHECK de component_type) =========='
SELECT conname, pg_get_constraintdef(oid) AS definicion
  FROM pg_constraint
 WHERE conrelid = to_regclass('public.os_uvr_component')
   AND contype = 'c'
 ORDER BY conname;

\echo '========== 6. Trigger de elegibilidad y vista derivada =========='
SELECT t.tgname, t.tgenabled
  FROM pg_trigger t
 WHERE t.tgrelid = to_regclass('public.os_uvr_valuation')
   AND t.tgname = 'trg_os_uvr_valuation_eligible';

SELECT table_name, column_name
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'v_os_uvr_valuation_total'
   AND column_name IN (
       'work_uvr', 'practice_expense_uvr', 'professional_liability_uvr', 'total_uvr'
   )
 ORDER BY column_name;

SELECT count(*) AS total_almacenado
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'os_uvr_valuation'
   AND column_name = 'total_uvr';

\echo '========== 7. DEFAULT ACL: grantees no deseados (0 filas) =========='
SELECT table_name, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND table_name IN (
       'os_uvr_eligible_catalog', 'os_uvr_valuation', 'os_uvr_component',
       'os_uvr_conversion', 'os_uvr_geo_index'
   )
   AND grantee IN ('origen_admin', 'PUBLIC')
 ORDER BY table_name, grantee, privilege_type;

\echo '========== 8. Modelos heredados NO modificados (informativo) =========='
SELECT (SELECT count(*) FROM os_pricing_values) AS pricing_values_rvu,
       (SELECT count(*) FROM os_fee_item) AS fee_items;

\echo '========== 9. Regresión de fases cerradas =========='
SELECT (SELECT count(*) FROM os_catalog_relation) AS relaciones,
       (SELECT count(*) FROM os_catalog_language) AS idiomas_por_catalogo,
       (SELECT count(*) FROM os_governance_request) AS solicitudes_gobernanza;

ROLLBACK;
