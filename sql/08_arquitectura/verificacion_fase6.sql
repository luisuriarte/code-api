-- =============================================================================
-- VERIFICACIÓN DE LA FASE 6 (§16) · productos, presentaciones e identificadores
-- =============================================================================
-- Solo lectura. BEGIN READ_ONLY / ROLLBACK: no escribe en la base.
-- Ejecutar después de sql/08_arquitectura/fase5_productos.sql:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f sql/08_arquitectura/verificacion_fase6.sql
--
-- El nombre del archivo de migración conserva la numeración histórica; según
-- §16 esta es la Fase 6. Ver sql/08_arquitectura/README.md.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN READ ONLY;

\echo '========== 1. Nueve tablas nuevas =========='
SELECT tablename
  FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN (
       'os_manufacturer', 'os_concept', 'os_product', 'os_product_presentation',
       'os_product_identifier_type', 'os_product_identifiers',
       'os_manufacturer_role', 'os_product_manufacturer', 'os_regulatory_records'
   )
 ORDER BY tablename;

\echo '========== 2. Catálogos de tipos semilla (3 y 4) =========='
SELECT 'os_product_identifier_type' AS catalogo, count(*) AS filas
  FROM os_product_identifier_type
UNION ALL
SELECT 'os_manufacturer_role', count(*) FROM os_manufacturer_role;

SELECT code FROM os_product_identifier_type ORDER BY code;
SELECT code FROM os_manufacturer_role ORDER BY code;

\echo '========== 3. Tablas de negocio VACÍAS (0 filas cada una) =========='
SELECT 'os_manufacturer' AS tabla, count(*) AS filas FROM os_manufacturer
UNION ALL SELECT 'os_concept', count(*) FROM os_concept
UNION ALL SELECT 'os_product', count(*) FROM os_product
UNION ALL SELECT 'os_product_presentation', count(*) FROM os_product_presentation
UNION ALL SELECT 'os_product_identifiers', count(*) FROM os_product_identifiers
UNION ALL SELECT 'os_product_manufacturer', count(*) FROM os_product_manufacturer
UNION ALL SELECT 'os_regulatory_records', count(*) FROM os_regulatory_records
ORDER BY tabla;

\echo '========== 4. Constraints de integridad =========='
SELECT conname
  FROM pg_constraint
 WHERE conrelid IN (
     to_regclass('public.os_product_identifiers'),
     to_regclass('public.os_product_manufacturer'),
     to_regclass('public.os_regulatory_records')
 )
   AND conname IN (
       'uq_os_product_identifier_scoped', 'ck_os_product_identifier_validity',
       'uq_os_product_manufacturer', 'ck_os_product_manufacturer_validity',
       'uq_os_regulatory_record', 'ck_os_regulatory_record_validity'
   )
 ORDER BY conname;

\echo '========== 5. Índices nuevos =========='
SELECT indexname
  FROM pg_indexes
 WHERE schemaname = 'public'
   AND tablename IN (
       'os_product', 'os_product_presentation',
       'os_product_identifiers', 'os_regulatory_records'
   )
   AND indexname IN (
       'idx_os_product_concept', 'idx_os_presentation_product',
       'idx_os_product_identifiers_value', 'idx_os_regulatory_record_number'
   )
 ORDER BY indexname;

\echo '========== 6. DEFAULT ACL: grantees no deseados (0 filas) =========='
SELECT table_name, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND table_name IN (
       'os_manufacturer', 'os_concept', 'os_product', 'os_product_presentation',
       'os_product_identifier_type', 'os_product_identifiers',
       'os_manufacturer_role', 'os_product_manufacturer', 'os_regulatory_records'
   )
   AND grantee IN ('origen_admin', 'PUBLIC')
 ORDER BY table_name, grantee, privilege_type;

\echo '========== 7. Modelo farmacéutico heredado intacto (informativo) =========='
SELECT 'os_substance' AS tabla, count(*) AS filas FROM os_substance
UNION ALL SELECT 'os_medicinal_product', count(*) FROM os_medicinal_product
UNION ALL SELECT 'os_product_package', count(*) FROM os_product_package
UNION ALL SELECT 'os_product_identifier', count(*) FROM os_product_identifier;

\echo '========== 8. Regresión de fases cerradas =========='
SELECT (SELECT count(*) FROM os_catalog_relation) AS relaciones,
       (SELECT count(*) FROM os_catalog_language) AS idiomas_por_catalogo,
       (SELECT count(*) FROM os_governance_request) AS solicitudes_gobernanza;

ROLLBACK;
