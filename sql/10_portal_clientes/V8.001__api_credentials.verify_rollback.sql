-- Verificación SELECT-only tras el down de V8.001.
-- No modifica datos. No consulta claves API ni secretos.

BEGIN READ ONLY;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para la Etapa 8: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

SELECT current_database() AS base, current_user AS usuario;

SELECT tablename
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename = 'api_credential';

SELECT count(*) AS tablas_v8_restantes
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename = 'api_credential';

SELECT proname
FROM pg_proc
WHERE pronamespace = 'os_customer'::regnamespace
  AND proname = 'api_credential_immutable_revocation';

SELECT count(*) AS funcion_revocacion_v8_restante
FROM pg_proc
WHERE pronamespace = 'os_customer'::regnamespace
  AND proname = 'api_credential_immutable_revocation';

SELECT count(*) AS audit_log
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename = 'audit_log';

SELECT count(*) AS tablas_v5_v6_v7
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename IN (
      'organization','app_user','membership','audit_log',
      'service','service_item','service_request','contract','entitlement','operator'
  );

SELECT count(*) AS columnas_api_clients
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'api_clients';
