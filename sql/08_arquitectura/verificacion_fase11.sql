-- =============================================================================
-- VERIFICACIÓN DE LA FASE 11 (§16) · integración ANMAT/UDI/GTIN sin datos
-- =============================================================================
-- Solo lectura. BEGIN READ_ONLY / ROLLBACK: no escribe en la base.
-- Ejecutar después de sql/08_arquitectura/fase11_integracion_farmacia.sql:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f sql/08_arquitectura/verificacion_fase11.sql
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN READ ONLY;

\echo '========== 1. Tres tablas nuevas =========='
SELECT tablename
  FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN ('os_pharma_source', 'os_pharma_import_batch', 'os_pharma_import_row')
 ORDER BY tablename;

\echo '========== 2. Staging VACÍO (0 filas) =========='
SELECT 'os_pharma_source' AS tabla, count(*) AS filas FROM os_pharma_source
UNION ALL SELECT 'os_pharma_import_batch', count(*) FROM os_pharma_import_batch
UNION ALL SELECT 'os_pharma_import_row', count(*) FROM os_pharma_import_row
ORDER BY tabla;

\echo '========== 3. Modelo de la Fase 6 sigue vacío =========='
SELECT 'os_concept' AS tabla, count(*) AS filas FROM os_concept
UNION ALL SELECT 'os_product', count(*) FROM os_product
UNION ALL SELECT 'os_product_presentation', count(*) FROM os_product_presentation
UNION ALL SELECT 'os_product_identifiers', count(*) FROM os_product_identifiers
UNION ALL SELECT 'os_regulatory_records', count(*) FROM os_regulatory_records
ORDER BY tabla;

\echo '========== 4. Legado farmacéutico intacto =========='
SELECT 'os_substance' AS tabla, count(*) AS filas FROM os_substance
UNION ALL SELECT 'os_medicinal_product', count(*) FROM os_medicinal_product
UNION ALL SELECT 'os_product_package', count(*) FROM os_product_package
UNION ALL SELECT 'os_product_identifier', count(*) FROM os_product_identifier
ORDER BY tabla;

\echo '========== 5. Vista de conciliación (legado vs modelo) =========='
SELECT * FROM v_os_pharma_reconciliation ORDER BY mapping;

\echo '========== 6. FK a fuentes, actores y estados de revisión =========='
SELECT conname, conrelid::regclass AS tabla
  FROM pg_constraint
 WHERE confrelid IN (
     to_regclass('public.os_pharma_source'),
     to_regclass('public.os_pharma_import_batch'),
     to_regclass('os_admin.app_user'),
     to_regclass('public.os_review_state')
 )
   AND conrelid IN (
     to_regclass('public.os_pharma_import_batch'),
     to_regclass('public.os_pharma_import_row'),
     to_regclass('public.os_pharma_source')
 )
 ORDER BY conrelid::regclass::text, conname;

\echo '========== 7. Guardián de aprobación y CHECK de destino =========='
SELECT t.tgname, t.tgenabled
  FROM pg_trigger t
 WHERE t.tgrelid = to_regclass('public.os_pharma_import_row')
   AND t.tgname = 'trg_os_pharma_import_row_review';

SELECT conname
  FROM pg_constraint
 WHERE conrelid = to_regclass('public.os_pharma_import_row')
   AND conname IN ('uq_os_pharma_import_row', 'os_pharma_import_row_target_entity_check')
 ORDER BY conname;

\echo '========== 8. DEFAULT ACL: grantees no deseados (0 filas) =========='
SELECT table_name, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND table_name IN ('os_pharma_source', 'os_pharma_import_batch', 'os_pharma_import_row')
   AND grantee IN ('origen_admin', 'PUBLIC');

\echo '========== 9. Regresión de fases cerradas =========='
SELECT (SELECT count(*) FROM os_catalog_relation) AS relaciones,
       (SELECT count(*) FROM os_catalog_language) AS idiomas_por_catalogo,
       (SELECT count(*) FROM os_governance_request) AS solicitudes_gobernanza,
       (SELECT count(*) FROM os_uvr_valuation) AS valoraciones_uvr,
       (SELECT count(*) FROM os_catalog_reservation) AS reservas_dentar,
       (SELECT count(*) FROM os_product_family_reservation) AS reservas_os;

ROLLBACK;
