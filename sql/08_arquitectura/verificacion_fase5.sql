-- =============================================================================
-- VERIFICACIÓN DE LA FASE 5 (§16) · gobernanza y auditoría unificadas
-- =============================================================================
-- Solo lectura. BEGIN READ_ONLY / ROLLBACK: no escribe en la base.
-- Ejecutar después de sql/08_arquitectura/fase4_gobernanza.sql:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f sql/08_arquitectura/verificacion_fase5.sql
--
-- El nombre del archivo de migración conserva la numeración histórica; según
-- §16 esta es la Fase 5. Ver sql/08_arquitectura/README.md.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN READ ONLY;

\echo '========== 1. Preflight: actores y estados de revisión =========='
SELECT to_regclass('os_admin.app_user') AS app_user,
       to_regclass('public.os_review_state') AS review_state;

\echo '========== 2. Cuatro tablas de gobernanza =========='
SELECT tablename
  FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN (
       'os_governance_request', 'os_governance_review',
       'os_governance_decision', 'os_audit_log'
   )
 ORDER BY tablename;

\echo '========== 3. Columnas de actores reales (debe ser 4) =========='
SELECT table_name, column_name, data_type
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name IN (
       'os_governance_request', 'os_governance_review',
       'os_governance_decision', 'os_audit_log'
   )
   AND column_name IN (
       'requested_by_user_id', 'reviewer_user_id',
       'approved_by_user_id', 'actor_user_id'
   )
 ORDER BY table_name;

\echo '========== 4. Foreign keys hacia os_admin.app_user (debe ser 4) =========='
SELECT conrelid::regclass AS tabla, conname
  FROM pg_constraint
 WHERE confrelid = to_regclass('os_admin.app_user')
   AND connamespace = 'public'::regnamespace
   AND contype = 'f'
 ORDER BY 1, 2;

\echo '========== 5. Triggers activos (debe ser 4, todos O) =========='
SELECT tgname, tgenabled
  FROM pg_trigger
 WHERE tgrelid IN (
     to_regclass('public.os_governance_request'),
     to_regclass('public.os_governance_review'),
     to_regclass('public.os_governance_decision'),
     to_regclass('public.os_audit_log')
 )
   AND NOT tgisinternal
 ORDER BY tgname;

-- Debe devolver una fila con tgenabled = 'O': os_audit_log es append-only.
SELECT tgname, tgenabled
  FROM pg_trigger
 WHERE tgrelid = to_regclass('public.os_audit_log')
   AND tgname = 'trg_os_audit_log_immutable';

\echo '========== 6. Defaults de gobernanza =========='
SELECT table_name, column_name, column_default
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name IN ('os_governance_request', 'os_governance_review')
   AND column_name = 'review_status'
 ORDER BY table_name;

\echo '========== 7. Evidencia obligatoria en decisiones =========='
SELECT is_nullable
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'os_governance_decision'
   AND column_name = 'evidence_reference';

\echo '========== 8. DEFAULT ACL: grantees no deseados (0 filas) =========='
SELECT table_name, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND table_name IN (
       'os_governance_request', 'os_governance_review',
       'os_governance_decision', 'os_audit_log'
   )
   AND grantee IN ('origen_admin', 'PUBLIC')
 ORDER BY table_name, grantee, privilege_type;

\echo '========== 9. Tablas vacías: ningún dato inventado =========='
SELECT 'governance_request' AS tabla, count(*) AS filas FROM os_governance_request
UNION ALL SELECT 'governance_review', count(*) FROM os_governance_review
UNION ALL SELECT 'governance_decision', count(*) FROM os_governance_decision
UNION ALL SELECT 'audit_log', count(*) FROM os_audit_log;

\echo '========== 10. Regresión: catálogos intactos =========='
SELECT (SELECT count(*) FROM os_catalog_relation) AS relaciones,
       (SELECT count(*) FROM os_catalog_language) AS configuraciones_idioma,
       (SELECT count(*) FROM os_admin.app_user) AS usuarios_admin;

ROLLBACK;
