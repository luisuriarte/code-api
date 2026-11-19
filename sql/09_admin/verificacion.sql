-- Verificación de M1 — SOLO LECTURA.
-- Ejecutar en psql contra origen_codes: psql -d origen_codes -f verificacion.sql
-- Envuelve la sesión en READ ONLY y hace ROLLBACK: no puede escribir.

BEGIN READ ONLY;

SELECT current_database() AS base, current_user AS usuario;

-- 1. Objetos creados
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'os_admin'
ORDER BY table_name;

-- 2. Rol de aplicación (sin secretos)
SELECT rolname, rolcanlogin FROM pg_roles WHERE rolname = 'origen_admin';

-- 3. Trigger append-only de auditoría
SELECT t.tgname, t.tgenabled, c.relname AS tabla
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'os_admin' AND t.tgname = 'trg_audit_log_immutable';

-- 4. Roles y permisos base
SELECT code, is_system FROM os_admin.role ORDER BY code;
SELECT role_code, count(*) AS permisos
FROM os_admin.role_permission GROUP BY role_code ORDER BY role_code;

-- 5. Privilegios mínimos (ninguno sobre os_catalog_*)
SELECT table_schema, table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'origen_admin'
ORDER BY table_schema, table_name, privilege_type;

-- 6. Estado de usuarios (sin hashes)
SELECT id, email, status, email_verified_at IS NOT NULL AS verificado, last_login_at
FROM os_admin.app_user ORDER BY id;

-- 7. Auditoría reciente
SELECT action, count(*) AS n
FROM os_admin.audit_log GROUP BY action ORDER BY action;

ROLLBACK;
