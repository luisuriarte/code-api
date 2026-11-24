-- Verificación SELECT-only del rollback de V7.001.
-- No modifica datos. Confirma que V5 y V6 permanecen intactos.

BEGIN READ ONLY;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para la Etapa 7: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

SELECT current_database() AS base, current_user AS usuario;

SELECT count(*) AS tablas_v7_restantes
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename IN (
      'service','service_item','service_request','service_request_item',
      'contract','entitlement','operator'
  );

SELECT tablename
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename IN (
      'organization','app_user','membership','session','audit_log',
      'invoice_ninja_client_link','invoice_ninja_duplicate_review'
  )
ORDER BY tablename;

SELECT count(*) AS total_tablas
FROM pg_tables
WHERE schemaname = 'os_customer';

SELECT tgname
FROM pg_trigger
WHERE tgrelid::regclass::text = 'os_customer.audit_log'
  AND NOT tgisinternal;

SELECT count(*) AS funcion_pago_v7_restante
FROM pg_proc
WHERE pronamespace = 'os_customer'::regnamespace
  AND proname = 'require_verified_payment_for_active_entitlement';

SELECT count(*) AS permisos_v7_restantes
FROM os_customer.permission
WHERE code IN ('service.request','service.activate','service.suspend','service.revoke');

SELECT count(*) AS rol_v7_restante
FROM os_customer.role
WHERE code = 'origen_superadmin';

ROLLBACK;
