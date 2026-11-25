-- Verificación SELECT-only de V8.001.
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

SELECT current_database() AS base, current_user AS usuario, version() AS version_pg;

SELECT tablename
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename = 'api_credential';

SELECT count(*) AS tablas_v8
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename = 'api_credential';

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name = 'api_credential'
ORDER BY ordinal_position;

-- El portal no guarda secretos ni capacidades inexistentes. Debe devolver 0.
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name = 'api_credential'
  AND column_name ~* '(api_key|token|secret|password|scope|expire|expiry|last_used|consum|quota|price|amount|invoice)'
ORDER BY column_name;

SELECT count(*) AS columnas_prohibidas
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name = 'api_credential'
  AND column_name ~* '(api_key|token|secret|password|scope|expire|expiry|last_used|consum|quota|price|amount|invoice)';

SELECT count(*) AS capacidades_inexistentes
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name = 'api_credential'
  AND column_name ~* '(scope|expire|expiry|last_used|consum|quota)';

SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE connamespace = 'os_customer'::regnamespace
  AND conrelid = 'os_customer.api_credential'::regclass
ORDER BY conname;

SELECT tgname, pg_get_triggerdef(oid) AS definicion
FROM pg_trigger
WHERE tgrelid = 'os_customer.api_credential'::regclass
  AND tgname = 'trg_api_credential_immutable_revocation'
  AND NOT tgisinternal;

SELECT count(*) AS trigger_revocacion
FROM pg_trigger
WHERE tgrelid = 'os_customer.api_credential'::regclass
  AND tgname = 'trg_api_credential_immutable_revocation'
  AND NOT tgisinternal;

SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'os_customer'
  AND tablename = 'api_credential'
ORDER BY indexname;

SELECT has_table_privilege('origen_customer', 'os_customer.api_credential', 'SELECT') AS lee_metadatos,
       has_table_privilege('origen_customer', 'os_customer.api_credential', 'INSERT') AS crea_metadatos,
       has_table_privilege('origen_customer', 'os_customer.api_credential', 'UPDATE') AS actualiza_metadatos,
       NOT has_table_privilege('origen_customer', 'os_customer.api_credential', 'DELETE') AS sin_borrado,
       has_sequence_privilege('origen_customer', 'os_customer.api_credential_id_seq', 'USAGE') AS usa_secuencia;

-- public.api_clients permanece con su esquema original: seis columnas.
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'api_clients'
ORDER BY ordinal_position;

SELECT count(*) AS columnas_api_clients
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'api_clients';

SELECT count(*) AS columnas_api_clients_prohibidas
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'api_clients'
  AND column_name ~* '(scope|expire|expiry|last_used|organization_id|revoked_at)';

SELECT count(*) AS total_tablas
FROM pg_tables
WHERE schemaname = 'os_customer';

ROLLBACK;
