-- Verificación SELECT-only después de ejecutar la migración down.
-- Confirma que el rollback no borró la auditoría append-only.

BEGIN READ ONLY;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para V5.001: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

SELECT current_database() AS base, current_user AS usuario;

SELECT to_regclass('os_customer.audit_log') AS auditoria_conservada;

SELECT count(*) AS filas_auditoria
FROM os_customer.audit_log;

SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgrelid = to_regclass('os_customer.audit_log')
  AND NOT tgisinternal;

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

ROLLBACK;
