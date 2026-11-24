-- Verificación SELECT-only de V7.001.
-- No modifica datos. No consulta secretos ni tokens.

BEGIN READ ONLY;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para la Etapa 7: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

SELECT current_database() AS base, current_user AS usuario, version() AS version_pg;

SELECT tablename
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename IN (
      'service','service_item','service_request','service_request_item',
      'contract','entitlement','operator'
  )
ORDER BY tablename;

SELECT count(*) AS tablas_v7
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename IN (
      'service','service_item','service_request','service_request_item',
      'contract','entitlement','operator'
  );

SELECT tgname, tgrelid::regclass AS tabla
FROM pg_trigger
WHERE tgrelid::regclass::text IN (
    'os_customer.service','os_customer.service_item','os_customer.service_request',
    'os_customer.contract','os_customer.entitlement','os_customer.operator'
)
  AND NOT tgisinternal
ORDER BY tgrelid::regclass::text, tgname;

-- Ningún campo comercial duplicado. Esta consulta debe devolver 0 filas.
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name IN (
      'service','service_item','service_request','service_request_item',
      'contract','entitlement','operator'
  )
  AND column_name ~* '(price|amount|total|product|invoice_number|payment|email|legal_name|tax_id)'
ORDER BY table_name, ordinal_position;

SELECT count(*) AS columnas_prohibidas
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name IN (
      'service','service_item','service_request','service_request_item',
      'contract','entitlement','operator'
  )
  AND column_name ~* '(price|amount|total|product|invoice_number|payment|email|legal_name|tax_id)';

-- Catálogo inicial: solo servicios verificados, con fuente y ruta real.
SELECT count(*) AS servicios_verificados
FROM os_customer.service
WHERE status = 'available'
  AND api_method = 'GET'
  AND environment = 'production'
  AND verified_source <> ''
  AND api_route <> '';

SELECT code, api_method, api_route, auth_required, verified_source
FROM os_customer.service
WHERE status = 'available'
ORDER BY code;

-- No se publican capacidades inexistentes.
SELECT count(*) AS capacidades_inexistentes
FROM os_customer.service
WHERE api_route ~* '(^|/)(fhir|uvr|cdt)(/|$)';

-- La base rechaza habilitaciones activas sin pago verificado.
SELECT tgname, tgrelid::regclass AS tabla, pg_get_triggerdef(oid) AS definicion
FROM pg_trigger
WHERE tgrelid::regclass::text = 'os_customer.entitlement'
  AND tgname = 'trg_entitlement_verified_payment'
  AND NOT tgisinternal;

SELECT count(*) AS trigger_pago_verificado
FROM pg_trigger
WHERE tgrelid::regclass::text = 'os_customer.entitlement'
  AND tgname = 'trg_entitlement_verified_payment'
  AND NOT tgisinternal;

-- Una sola habilitación activa por organización y servicio.
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'os_customer'
  AND tablename = 'entitlement'
  AND indexname = 'entitlement_one_active_per_service';

-- Pago confirmado verificado es obligatorio para contratos activos.
SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE connamespace = 'os_customer'::regnamespace
  AND conname IN ('contract_requires_verification','contract_validity_order')
ORDER BY conname;

SELECT has_table_privilege('origen_customer', 'os_customer.service', 'SELECT') AS lee_servicios,
       NOT has_table_privilege('origen_customer', 'os_customer.service', 'INSERT') AS catalogo_solo_lectura,
       NOT has_table_privilege('origen_customer', 'os_customer.service_item', 'UPDATE') AS relaciones_solo_lectura,
       has_table_privilege('origen_customer', 'os_customer.service_request', 'INSERT') AS crea_solicitudes,
       has_table_privilege('origen_customer', 'os_customer.contract', 'UPDATE') AS actualiza_contratos,
       has_table_privilege('origen_customer', 'os_customer.entitlement', 'UPDATE') AS actualiza_habilitaciones,
       has_table_privilege('origen_customer', 'os_customer.operator', 'SELECT') AS lee_operadores,
       has_sequence_privilege('origen_customer', 'os_customer.entitlement_id_seq', 'USAGE') AS usa_secuencia;

SELECT count(*) AS total_tablas
FROM pg_tables
WHERE schemaname = 'os_customer';

ROLLBACK;
