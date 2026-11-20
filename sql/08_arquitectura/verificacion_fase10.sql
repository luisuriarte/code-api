-- =============================================================================
-- VERIFICACIÓN DE LA FASE 10 (§16) · catálogos generales OS-* / OS-PRODUCTS
-- =============================================================================
-- Solo lectura. BEGIN READ_ONLY / ROLLBACK: no escribe en la base.
-- Ejecutar después de sql/08_arquitectura/fase10_catalogos_os.sql:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f sql/08_arquitectura/verificacion_fase10.sql
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN READ ONLY;

\echo '========== 1. Dos tablas nuevas =========='
SELECT tablename
  FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN ('os_product_class', 'os_product_family_reservation')
 ORDER BY tablename;

\echo '========== 2. Cinco clases documentadas =========='
SELECT code FROM os_product_class ORDER BY code;
SELECT count(*) AS clases FROM os_product_class;

\echo '========== 3. Familia + seis etiquetas, sin catálogo vinculado =========='
SELECT code, kind, label_es, class_code, review_status, catalog_id
  FROM os_product_family_reservation
 ORDER BY code;

SELECT count(*) AS filas FROM os_product_family_reservation;
SELECT count(*) AS con_catalog_id FROM os_product_family_reservation WHERE catalog_id IS NOT NULL;
SELECT count(*) AS sin_fuente
  FROM os_product_family_reservation
 WHERE source_reference IS NULL OR source_reference = '';
SELECT count(*) AS familias FROM os_product_family_reservation WHERE kind = 'family';
SELECT count(*) AS etiquetas FROM os_product_family_reservation WHERE kind = 'label';

\echo '========== 4. No se crearon catálogos reales ni contenido =========='
SELECT count(*) AS catalogos_reales
  FROM os_catalog
 WHERE code IN (
     'OS-PRODUCTS', 'OS-INS', 'OS-PROD', 'OS-MED', 'OS-DIS', 'OS-EQP', 'OS-IMPL'
 );

SELECT count(*) AS items_os
  FROM os_catalog_item i
  JOIN os_catalog c ON c.id = i.catalog_id
 WHERE c.code LIKE 'OS-%';

\echo '========== 5. Constraint de alcance y guardián de publicación =========='
SELECT conname
  FROM pg_constraint
 WHERE conrelid = to_regclass('public.os_product_family_reservation')
   AND conname = 'ck_os_product_family_reservation_scope';

SELECT t.tgname, t.tgenabled
  FROM pg_trigger t
 WHERE t.tgrelid = to_regclass('public.os_product_family_reservation')
   AND t.tgname = 'trg_os_product_family_reservation_publication';

\echo '========== 6. DEFAULT ACL: grantees no deseados (0 filas) =========='
SELECT table_name, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND table_name IN ('os_product_class', 'os_product_family_reservation')
   AND grantee IN ('origen_admin', 'PUBLIC');

\echo '========== 7. Sin solapamiento con DENTAR-IN/PD/EQ (0 catálogos reales) =========='
SELECT (SELECT count(*) FROM os_catalog_reservation WHERE catalog_id IS NOT NULL) AS dentar_vinculadas,
       (SELECT count(*) FROM os_product_family_reservation WHERE catalog_id IS NOT NULL) AS os_vinculadas,
       (SELECT count(*) FROM os_catalog WHERE code IN ('dentar-in','dentar-pd','dentar-eq')) AS dentar_reales,
       (SELECT count(*) FROM os_catalog WHERE code LIKE 'OS-%') AS os_reales;

\echo '========== 8. Regresión de fases cerradas =========='
SELECT (SELECT count(*) FROM os_catalog_relation) AS relaciones,
       (SELECT count(*) FROM os_catalog_language) AS idiomas_por_catalogo,
       (SELECT count(*) FROM os_governance_request) AS solicitudes_gobernanza,
       (SELECT count(*) FROM os_uvr_valuation) AS valoraciones_uvr;

ROLLBACK;
