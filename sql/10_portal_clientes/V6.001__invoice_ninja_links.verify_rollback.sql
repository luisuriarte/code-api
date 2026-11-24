-- Verificación SELECT-only después del down de V6.001.
-- Confirma que solo se revertieron las tablas de la Etapa 6.

BEGIN READ ONLY;

SELECT current_database() AS base, current_user AS usuario;

SELECT to_regclass('os_customer.invoice_ninja_client_link') AS vinculos,
       to_regclass('os_customer.invoice_ninja_duplicate_review') AS revisiones;

SELECT tablename
FROM pg_tables
WHERE schemaname = 'os_customer'
ORDER BY tablename;

SELECT to_regclass('os_customer.audit_log') AS auditoria_conservada;

SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgrelid = to_regclass('os_customer.audit_log')
  AND NOT tgisinternal;

SELECT rolname
FROM pg_roles
WHERE rolname = 'origen_customer';

ROLLBACK;
