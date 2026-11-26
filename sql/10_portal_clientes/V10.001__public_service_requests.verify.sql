-- Verificación SELECT-only de V10.001.
-- No modifica datos. No consulta secretos ni tokens.

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

SELECT tablename
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename IN ('public_service_request', 'public_service_request_item')
ORDER BY tablename;

SELECT count(*) AS tablas_v10
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename IN ('public_service_request', 'public_service_request_item');

-- Ninguna columna comercial duplicada: los importes viven en Invoice Ninja.
SELECT count(*) AS columnas_prohibidas
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name IN ('public_service_request', 'public_service_request_item')
  AND column_name ~* '(price|amount|total|invoice_number|payment|currency|product_name)';

SELECT count(*) AS servicios_verificados
FROM os_customer.service
WHERE status = 'available'
  AND api_method = 'GET'
  AND environment = 'production'
  AND verified_source <> ''
  AND api_route <> '';

SELECT count(*) AS capacidades_inexistentes
FROM os_customer.service
WHERE api_route ~* '(^|/)(fhir|uvr|cdt)(/|$)';

-- Privilegios mínimos y por objeto.
SELECT has_schema_privilege('origen_med', 'os_customer', 'USAGE') AS usa_esquema,
       has_table_privilege('origen_med', 'os_customer.public_service_request', 'SELECT') AS lee_solicitudes,
       has_table_privilege('origen_med', 'os_customer.public_service_request', 'INSERT') AS escribe_solicitudes,
       NOT has_table_privilege('origen_med', 'os_customer.public_service_request', 'UPDATE') AS sin_update,
       NOT has_table_privilege('origen_med', 'os_customer.public_service_request', 'DELETE') AS sin_delete,
       has_table_privilege('origen_med', 'os_customer.public_service_request_item', 'SELECT') AS lee_items,
       has_table_privilege('origen_med', 'os_customer.public_service_request_item', 'INSERT') AS escribe_items;

SELECT has_sequence_privilege('origen_med', 'os_customer.public_service_request_id_seq', 'USAGE') AS secuencia_solicitudes,
       has_sequence_privilege('origen_med', 'os_customer.public_service_request_item_id_seq', 'USAGE') AS secuencia_items;

SELECT NOT has_table_privilege('origen_med', 'os_customer.service', 'INSERT') AS sin_insert_en_servicios,
       NOT has_table_privilege('origen_med', 'os_customer.entitlement', 'INSERT') AS sin_insert_en_habilitaciones;

SELECT count(*) AS total_tablas
FROM pg_tables
WHERE schemaname = 'os_customer';

ROLLBACK;
