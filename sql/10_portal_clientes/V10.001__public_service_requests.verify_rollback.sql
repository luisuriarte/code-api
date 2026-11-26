-- Verificación SELECT-only del rollback de V10.001.
-- Confirma que solo se eliminaron las dos tablas nuevas.

BEGIN READ ONLY;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para V10.001: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

SELECT current_database() AS base, current_user AS usuario;

SELECT count(*) AS tablas_v10_restantes
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename IN ('public_service_request', 'public_service_request_item');

SELECT count(*) AS servicios_verificados
FROM os_customer.service
WHERE status = 'available'
  AND api_method = 'GET'
  AND environment = 'production'
  AND verified_source <> ''
  AND api_route <> '';

SELECT tablename
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename IN (
      'organization', 'app_user', 'membership', 'session', 'audit_log',
      'invoice_ninja_client_link', 'invoice_ninja_duplicate_review',
      'service', 'service_item', 'service_request', 'service_request_item',
      'contract', 'entitlement', 'operator',
      'api_credential'
  )
ORDER BY tablename;

SELECT count(*) AS total_tablas
FROM pg_tables
WHERE schemaname = 'os_customer';

ROLLBACK;
