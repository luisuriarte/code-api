-- =============================================================================
-- VERIFICACIÓN DE LECTURA · GESTIÓN DE CATÁLOGOS
-- =============================================================================
-- Ejecutar después de `catalogos_gestion_gobernada.sql`. No escribe.
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f /var/www/html/origen.ar/code-api/sql/08_arquitectura/verificacion_catalogos_gestion.sql
-- =============================================================================

\pset pager off

BEGIN READ ONLY;

SELECT '=== Gestión de catálogos · aplicador controlado ===' AS seccion;

SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS argumentos,
       p.prosecdef AS security_definer,
       pg_get_function_result(p.oid) AS retorno
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname = 'os_catalog_apply_governed_change';

SELECT grantee, string_agg(privilege_type, ',' ORDER BY privilege_type) AS privilegios
  FROM information_schema.routine_privileges
 WHERE routine_schema = 'public'
   AND routine_name = 'os_catalog_apply_governed_change'
 GROUP BY grantee
 ORDER BY grantee;

SELECT CASE
           WHEN EXISTS (
               SELECT 1
                 FROM information_schema.routine_privileges
                WHERE routine_schema = 'public'
                  AND routine_name = 'os_catalog_apply_governed_change'
                  AND grantee = 'PUBLIC'
           ) THEN 'FAIL: PUBLIC tiene privilegios sobre el aplicador'
           ELSE 'OK: sin privilegios PUBLIC sobre el aplicador'
       END AS privilegio_publico;

SELECT CASE
           WHEN EXISTS (
               SELECT 1
                 FROM information_schema.role_table_grants
                WHERE grantee = 'origen_admin'
                  AND table_schema = 'public'
                  AND table_name IN (
                      'os_catalog', 'os_catalog_item', 'os_catalog_item_version',
                      'os_catalog_release', 'os_catalog_relation',
                      'os_catalog_language', 'os_catalog_term'
                  )
                  AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
           ) THEN 'FAIL: origen_admin tiene escritura directa en catálogos'
           ELSE 'OK: origen_admin no escribe catálogos directamente'
       END AS escritura_directa;

SELECT '=== Gestión de catálogos · gestión y auditoría ===' AS seccion;

SELECT code, description, is_publication_allowed
  FROM public.os_review_state
 ORDER BY code;

SELECT count(*) AS solicitudes_catalogo
  FROM public.os_governance_request
 WHERE subject_type = 'catalog_change';

SELECT count(*) AS publicaciones_catalogo
  FROM public.os_audit_log
 WHERE action = 'catalog_change_published';

SELECT tgname, tgenabled
  FROM pg_trigger
 WHERE tgrelid = 'public.os_audit_log'::regclass
   AND NOT tgisinternal
 ORDER BY tgname;

SELECT '=== Gestión de catálogos · fin de verificación (sin cambios) ===' AS seccion;

ROLLBACK;
