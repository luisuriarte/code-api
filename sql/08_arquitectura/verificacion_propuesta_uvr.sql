-- =============================================================================
-- Verificación SOLO LECTURA: el panel responde "El servicio no está disponible"
-- al enviar una propuesta UVR (admin.errors.database).
--
-- IMPORTANTE: ejecutar contra la base que usa el PANEL, es decir el dbname de
-- PORTAL_ADMIN_DB_DSN (no necesariamente el de la API). Para saber el dbname sin
-- exponer secretos: grep PORTAL_ADMIN_DB_DSN .env | sed 's/:.*@/:***@/'
--
--   sudo -u postgres psql -d <dbname_del_panel> \
--     -v ON_ERROR_STOP=0 -f sql/08_arquitectura/verificacion_propuesta_uvr.sql
--
-- El panel se conecta como PORTAL_ADMIN_DB_USER (por defecto origen_admin), por
-- eso los permisos se consultan para ese rol. No modifica datos:
-- BEGIN READ ONLY / ROLLBACK.
-- =============================================================================

SET client_encoding = 'UTF8';
\pset pager off

BEGIN READ ONLY;

SELECT current_database() AS base_actual, current_user AS usuario_actual;

-- 1) ¿Está aplicada la migración que necesita el repositorio?
--    propose() escribe en estas tablas; si falta una o falta una columna,
--    PDO lanza una excepción y AdminForm muestra "database".
SELECT '=== 1. Objetos que escribe propose() ===' AS seccion;
SELECT
    to_regclass('public.os_governance_request') IS NOT NULL AS governance_request,
    to_regclass('os_admin.app_user') IS NOT NULL AS app_user,
    to_regclass('public.os_review_state') IS NOT NULL AS review_state,
    to_regclass('public.os_uvr_valuation') IS NOT NULL AS uvr_valuation,
    to_regclass('public.os_uvr_component') IS NOT NULL AS uvr_component,
    to_regclass('public.os_prestacion') IS NOT NULL AS prestacion,
    to_regclass('public.os_prestacion_codigo') IS NOT NULL AS prestacion_codigo,
    to_regclass('public.os_uvr_profile') IS NOT NULL AS uvr_profile,
    to_regclass('public.os_uvr_profile_component') IS NOT NULL AS uvr_profile_component,
    to_regclass('public.os_uvr_prestacion_valuation') IS NOT NULL AS prestacion_valuation,
    to_regclass('public.os_uvr_prestacion_component') IS NOT NULL AS prestacion_component,
    to_regclass('public.v_os_uvr_prestacion_public') IS NOT NULL AS vista_publica;

SELECT '=== 2. Columnas usadas por los INSERT del panel ===' AS seccion;
SELECT table_name, column_name, data_type, is_nullable
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND (
        (table_name = 'os_uvr_valuation' AND column_name IN (
            'service_item_id', 'release_id', 'version_tag', 'methodology',
            'source_reference', 'evaluated_at', 'calculated_by',
            'calculated_by_user_id', 'review_status', 'valid_from', 'valid_to',
            'approved_by_user_id', 'published_at'))
     OR (table_name = 'os_uvr_component' AND column_name IN (
            'valuation_id', 'component_type', 'value', 'calculation_note',
            'is_not_applicable', 'negative_adjustment_evidence'))
     OR (table_name = 'os_governance_request' AND column_name IN (
            'request_type', 'subject_type', 'subject_id', 'proposed_change',
            'source_reference', 'requested_by', 'requested_by_user_id',
            'review_status'))
     OR (table_name = 'os_uvr_prestacion_valuation' AND column_name IN (
            'prestacion_id', 'profile_id', 'version_tag', 'source_reference',
            'evaluated_at', 'calculated_by_user_id', 'review_status',
            'valid_from', 'valid_to'))
     OR (table_name = 'os_uvr_prestacion_component' AND column_name IN (
            'valuation_id', 'component_type', 'value', 'is_not_applicable',
            'negative_adjustment_evidence', 'calculation_note', 'source_reference'))
   )
 ORDER BY table_name, column_name;

-- 2) Permisos. Si falta INSERT o USAGE de secuencia, el INSERT falla aunque
--    el esquema esté completo.
SELECT '=== 3. Permisos de origen_admin (INSERT/SELECT/USAGE) ===' AS seccion;
WITH objetos(tabla) AS (
    VALUES
        ('public.os_uvr_valuation'),
        ('public.os_uvr_component'),
        ('public.os_governance_request'),
        ('public.os_governance_review'),
        ('public.os_governance_decision'),
        ('public.os_prestacion'),
        ('public.os_prestacion_codigo'),
        ('public.os_uvr_profile'),
        ('public.os_uvr_profile_component'),
        ('public.os_uvr_prestacion_valuation'),
        ('public.os_uvr_prestacion_component'),
        ('public.os_audit_log'),
        ('os_admin.audit_log')
)
SELECT o.tabla,
       CASE WHEN to_regclass(o.tabla) IS NULL THEN NULL
            ELSE has_table_privilege('origen_admin', o.tabla, 'SELECT') END AS select_ok,
       CASE WHEN to_regclass(o.tabla) IS NULL THEN NULL
            ELSE has_table_privilege('origen_admin', o.tabla, 'INSERT') END AS insert_ok,
       CASE WHEN to_regclass(o.tabla) IS NULL THEN NULL
            ELSE has_table_privilege('origen_admin', o.tabla, 'UPDATE') END AS update_ok,
       pg_get_serial_sequence(o.tabla, 'id') AS secuencia
  FROM objetos o
 ORDER BY o.tabla;

SELECT '=== 4. USAGE/SELECT de secuencias ===' AS seccion;
SELECT s.sequence_schema || '.' || s.sequence_name AS secuencia,
       has_sequence_privilege('origen_admin', s.sequence_schema || '.' || s.sequence_name, 'USAGE') AS usage_ok,
       has_sequence_privilege('origen_admin', s.sequence_schema || '.' || s.sequence_name, 'SELECT') AS select_ok
  FROM information_schema.sequences s
 WHERE (s.sequence_schema, s.sequence_name) IN (
       ('public', 'os_uvr_valuation_id_seq'),
       ('public', 'os_uvr_component_id_seq'),
       ('public', 'os_governance_request_id_seq'),
       ('public', 'os_uvr_prestacion_valuation_id_seq'),
       ('public', 'os_uvr_prestacion_component_id_seq'),
       ('public', 'os_audit_log_id_seq'),
       ('os_admin', 'audit_log_id_seq'))
 ORDER BY 1;

-- 3) Los INSERT usan review_status = 'draft' y FKs a os_admin.app_user.
SELECT '=== 5. Estados de revisión y actores ===' AS seccion;
SELECT code FROM public.os_review_state ORDER BY code;
SELECT count(*) AS actores_app_user FROM os_admin.app_user;
SELECT id, email, status FROM os_admin.app_user ORDER BY id DESC LIMIT 5;

-- 4) Triggers y CHECK: una violación se traduce como "database".
SELECT '=== 6. Triggers en tablas UVR ===' AS seccion;
SELECT c.relname AS tabla, t.tgname AS trigger, p.proname AS funcion
  FROM pg_trigger t
  JOIN pg_class c ON c.oid = t.tgrelid
  JOIN pg_proc p ON p.oid = t.tgfoid
 WHERE NOT t.tgisinternal
   AND c.relname IN (
       'os_uvr_valuation', 'os_uvr_component', 'os_governance_request',
       'os_uvr_prestacion_valuation', 'os_uvr_prestacion_component')
 ORDER BY c.relname, t.tgname;

SELECT '=== 7. CHECK de componentes ===' AS seccion;
SELECT conrelid::regclass::text AS tabla, conname, pg_get_constraintdef(oid) AS definicion
  FROM pg_constraint
 WHERE contype = 'c'
   AND conrelid IN (
       'public.os_uvr_component'::regclass,
       'public.os_uvr_prestacion_component'::regclass)
 ORDER BY 1, 2;

-- 5) En modo transversal, propose() exige vínculo aprobado y perfil con
--    componentes aplicables. Si no hay filas, el panel da otro mensaje; se
--    muestra igual para descartar confusión entre causas.
SELECT '=== 8. Datos mínimos para la ruta transversal ===' AS seccion;
SELECT
    (SELECT count(*) FROM public.os_uvr_profile
      WHERE status IN ('approved', 'published')) AS perfiles_aprobados,
    (SELECT count(*) FROM public.os_prestacion_codigo
      WHERE review_status IN ('approved', 'deprecated')
        AND item_id IS NOT NULL) AS vinculos_con_item_id,
    (SELECT count(*) FROM public.os_prestacion_codigo
      WHERE review_status IN ('approved', 'deprecated')
        AND item_id IS NULL
        AND btrim(coalesce(external_code, '')) <> '') AS vinculos_solo_external_code,
    (SELECT count(*) FROM public.os_prestacion
      WHERE is_valuable AND status IN ('approved', 'published')) AS prestaciones_valorables;

SELECT '=== 9. Campo source_reference vacío en tablas UVR (puede violar NOT NULL) ===' AS seccion;
SELECT 'os_uvr_valuation' AS tabla, count(*) AS nulas
  FROM public.os_uvr_valuation WHERE btrim(coalesce(source_reference, '')) = ''
UNION ALL
SELECT 'os_uvr_prestacion_valuation', count(*)
  FROM public.os_uvr_prestacion_valuation WHERE btrim(coalesce(source_reference, '')) = ''
UNION ALL
SELECT 'os_governance_request', count(*)
  FROM public.os_governance_request WHERE btrim(coalesce(source_reference, '')) = '';

-- 6) Los triggers UVR insertan en public.os_audit_log con los privilegios del
--    usuario que ejecuta el INSERT (no son SECURITY DEFINER). Sin INSERT o sin
--    USAGE de su secuencia, la propuesta falla ya con el esquema correcto.
SELECT '=== 10. Auditoría de los triggers UVR ===' AS seccion;
SELECT p.proname,
       p.prosecdef AS security_definer,
       has_table_privilege('origen_admin', 'public.os_audit_log', 'INSERT') AS audit_insert_ok,
       has_sequence_privilege('origen_admin', 'public.os_audit_log_id_seq', 'USAGE') AS audit_seq_usage_ok
  FROM pg_proc p
 WHERE p.proname IN ('os_uvr_audit_trigger', 'os_governance_audit_trigger')
 ORDER BY p.proname;

-- 7) Intentos parciales: si el INSERT principal entró pero falló la auditoría,
--    un reintento con los mismos datos choca con la UNIQUE de governance_request.
SELECT '=== 11. Escrituras recientes (intentos parciales) ===' AS seccion;
SELECT 'os_uvr_valuation' AS tabla, id, created_at, review_status, source_reference
  FROM public.os_uvr_valuation ORDER BY id DESC LIMIT 5;
SELECT 'os_governance_request' AS tabla, id, created_at, review_status, subject_id
  FROM public.os_governance_request ORDER BY id DESC LIMIT 5;
SELECT 'public.os_audit_log' AS tabla, id, occurred_at, entity_type, action, actor
  FROM public.os_audit_log ORDER BY id DESC LIMIT 8;

-- 8) Los triggers que leen catálogos deben ser SECURITY DEFINER: origen_admin
--    no tiene SELECT sobre os_catalog_* (y eso es intencional).
SELECT '=== 12. Triggers que leen catálogos ===' AS seccion;
SELECT p.proname,
       p.prosecdef AS security_definer,
       has_table_privilege('origen_admin', 'public.os_catalog_item', 'SELECT') AS admin_catalog_select
  FROM pg_proc p
 WHERE p.proname IN ('os_uvr_assert_eligible_service', 'os_uvr_assert_publication_ready')
 ORDER BY p.proname;

SELECT '=== 13. Catálogos elegibles para UVR ===' AS seccion;
SELECT catalog_code, is_active, source_reference
  FROM public.os_uvr_eligible_catalog
 ORDER BY catalog_code;

ROLLBACK;
