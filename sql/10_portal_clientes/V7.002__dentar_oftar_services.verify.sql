-- Verificación SELECT-only de V7.002.
-- No modifica datos. No consulta secretos ni tokens.

BEGIN READ ONLY;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para V7.002: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

SELECT current_database() AS base, current_user AS usuario;

SELECT code, name, domain, api_route, api_method, auth_required, environment, status, verified_source
FROM os_customer.service
WHERE code IN ('api.dentar', 'api.oftar')
ORDER BY code;

SELECT count(*) AS servicios_dentar_oftar
FROM os_customer.service
WHERE code IN ('api.dentar', 'api.oftar')
  AND status = 'available'
  AND api_method = 'GET'
  AND environment = 'production'
  AND auth_required = true
  AND api_route <> ''
  AND verified_source <> '';

SELECT count(*) AS servicios_verificados
FROM os_customer.service
WHERE status = 'available'
  AND api_method = 'GET'
  AND environment = 'production'
  AND verified_source <> ''
  AND api_route <> '';

-- No se publican capacidades inexistentes.
SELECT count(*) AS capacidades_inexistentes
FROM os_customer.service
WHERE api_route ~* '(^|/)(fhir|uvr|cdt)(/|$)';

-- Ningún campo comercial duplicado en el catálogo técnico.
SELECT count(*) AS columnas_prohibidas
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name = 'service'
  AND column_name ~* '(price|amount|total|product|invoice_number|payment|email|legal_name|tax_id)';

SELECT has_table_privilege('origen_customer', 'os_customer.service', 'SELECT') AS lee_servicios,
       NOT has_table_privilege('origen_customer', 'os_customer.service', 'INSERT') AS catalogo_solo_lectura;

ROLLBACK;
