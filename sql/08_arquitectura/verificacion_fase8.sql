-- =============================================================================
-- VERIFICACIÓN DE LA FASE 8 (§16) · catálogos DENTAR reservados IN/PD/EQ
-- =============================================================================
-- Solo lectura. BEGIN READ_ONLY / ROLLBACK: no escribe en la base.
-- Ejecutar después de sql/08_arquitectura/fase7_catalogos_reservados.sql:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f sql/08_arquitectura/verificacion_fase8.sql
--
-- El nombre del archivo de migración conserva la numeración histórica; según
-- §16 esta es la Fase 8. Ver sql/08_arquitectura/README.md.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN READ ONLY;

\echo '========== 1. Tabla de reserva =========='
SELECT tablename
  FROM pg_tables
 WHERE schemaname = 'public' AND tablename = 'os_catalog_reservation';

\echo '========== 2. Tres reservas, sin publicación (0 filas con catálogo) =========='
SELECT code, label_es, family_code, domain_code, review_status, catalog_id
  FROM os_catalog_reservation
 ORDER BY code;

SELECT count(*) AS filas FROM os_catalog_reservation;
SELECT count(*) AS con_catalog_id FROM os_catalog_reservation WHERE catalog_id IS NOT NULL;
SELECT count(*) AS sin_fuente FROM os_catalog_reservation WHERE source_reference IS NULL OR source_reference = '';

\echo '========== 3. No se crearon catálogos reales ni contenido =========='
SELECT count(*) AS catalogos_reales
  FROM os_catalog WHERE code IN ('dentar-in', 'dentar-pd', 'dentar-eq');

SELECT count(*) AS items_reservados
  FROM os_catalog_item i
  JOIN os_catalog c ON c.id = i.catalog_id
 WHERE c.code IN ('dentar-in', 'dentar-pd', 'dentar-eq');

SELECT count(*) AS releases_reservadas
  FROM os_catalog_release r
  JOIN os_catalog c ON c.id = r.catalog_id
 WHERE c.code IN ('dentar-in', 'dentar-pd', 'dentar-eq');

\echo '========== 4. Constraint de alcance y guardián de publicación =========='
SELECT conname
  FROM pg_constraint
 WHERE conrelid = to_regclass('public.os_catalog_reservation')
   AND conname IN ('ck_os_catalog_reservation_scope', 'uq_os_catalog_reservation_catalog')
 ORDER BY conname;

SELECT t.tgname, t.tgenabled
  FROM pg_trigger t
 WHERE t.tgrelid = to_regclass('public.os_catalog_reservation')
   AND t.tgname = 'trg_os_catalog_reservation_publication';

\echo '========== 5. DEFAULT ACL: grantees no deseados (0 filas) =========='
SELECT table_name, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND table_name = 'os_catalog_reservation'
   AND grantee IN ('origen_admin', 'PUBLIC');

\echo '========== 6. Regresión de fases cerradas =========='
SELECT (SELECT count(*) FROM os_catalog_relation) AS relaciones,
       (SELECT count(*) FROM os_catalog_language) AS idiomas_por_catalogo,
       (SELECT count(*) FROM os_governance_request) AS solicitudes_gobernanza,
       (SELECT count(*) FROM os_uvr_valuation) AS valoraciones_uvr;

\echo '========== 7. Catálogos publicados intactos (informativo) =========='
SELECT code, is_active
  FROM os_catalog
 WHERE code IN ('dentar-pr', 'dentar-dx', 'nomenclador-odontologico-ar')
 ORDER BY code;

ROLLBACK;
