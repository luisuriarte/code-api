-- Verificación SELECT-only de V5.001.
-- No modifica datos. No consulta secretos.

BEGIN READ ONLY;

SELECT current_database() AS base, current_user AS usuario, version() AS version_pg;

SELECT nspname
FROM pg_namespace
WHERE nspname = 'os_customer';

SELECT rolname
FROM pg_roles
WHERE rolname = 'origen_customer';

SELECT tablename
FROM pg_tables
WHERE schemaname = 'os_customer'
ORDER BY tablename;

SELECT tgname, tgrelid::regclass AS tabla
FROM pg_trigger
WHERE tgrelid::regclass::text LIKE 'os_customer.%'
  AND NOT tgisinternal
ORDER BY tgrelid::regclass::text, tgname;

SELECT code
FROM os_customer.role
ORDER BY code;

SELECT code
FROM os_customer.permission
ORDER BY code;

SELECT r.code AS rol, count(p.id) AS permisos
FROM os_customer.role r
LEFT JOIN os_customer.role_permission rp ON rp.role_id = r.id
LEFT JOIN os_customer.permission p ON p.id = rp.permission_id
GROUP BY r.code
ORDER BY r.code;

SELECT has_schema_privilege('origen_customer', 'os_customer', 'USAGE') AS usa_esquema,
       has_table_privilege('origen_customer', 'os_customer.audit_log', 'INSERT') AS inserta_auditoria,
       has_table_privilege('origen_customer', 'os_customer.audit_log', 'UPDATE') AS actualiza_auditoria,
       has_table_privilege('origen_customer', 'os_customer.app_user', 'SELECT') AS lee_usuarios;

SELECT count(*) AS total_tablas
FROM pg_tables
WHERE schemaname = 'os_customer';

ROLLBACK;
