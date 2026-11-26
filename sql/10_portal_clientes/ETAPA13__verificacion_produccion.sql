-- ETAPA13__verificacion_produccion.sql
-- Verificación SELECT-only de la base operativa del portal de clientes.
-- No modifica datos, no muestra correos, fiscales, importes ni secretos.
-- Solo se ejecuta en origen_codes_portal_clientes.

BEGIN READ ONLY;

DO $guard$
BEGIN
    IF current_database() <> 'origen_codes_portal_clientes' THEN
        RAISE EXCEPTION 'Verificación Etapa 13 requiere origen_codes_portal_clientes, no %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

SELECT current_database() AS base, current_user AS usuario;

SELECT to_regclass('os_customer.organization') IS NOT NULL AS organizaciones,
       to_regclass('os_customer.app_user') IS NOT NULL AS usuarios,
       to_regclass('os_customer.service') IS NOT NULL AS servicios,
       to_regclass('os_customer.entitlement') IS NOT NULL AS habilitaciones,
       to_regclass('os_customer.audit_log') IS NOT NULL AS auditoria,
       to_regclass('os_customer.api_credential') IS NOT NULL AS credenciales,
       to_regclass('os_customer.public_service_request') IS NOT NULL AS solicitudes,
       to_regclass('os_customer.public_service_request_item') IS NOT NULL AS items;

SELECT count(*) AS servicios_verificados
FROM os_customer.service
WHERE status = 'available'
  AND api_method = 'GET'
  AND environment = 'production'
  AND verified_source <> ''
  AND api_route <> '';

SELECT count(*) AS servicios_dentar_oftar
FROM os_customer.service
WHERE code IN ('api.dentar', 'api.oftar')
  AND status = 'available'
  AND api_method = 'GET'
  AND environment = 'production'
  AND auth_required = true;

SELECT count(*) AS capacidades_inexistentes
FROM os_customer.service
WHERE api_route ~* '(^|/)(fhir|uvr|cdt)(/|$)';

SELECT count(*) AS columnas_prohibidas
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name = 'service'
  AND column_name ~* '(price|amount|total|product|invoice_number|payment|email|legal_name|tax_id)';

SELECT count(*) AS solicitudes_iniciales
FROM os_customer.public_service_request;

SELECT has_database_privilege('origen_customer', current_database(), 'CONNECT') AS conecta_customer,
       has_database_privilege('origen_med', current_database(), 'CONNECT') AS conecta_med;

SELECT has_schema_privilege('origen_customer', 'os_customer', 'USAGE') AS usa_esquema_customer,
       has_table_privilege('origen_customer', 'os_customer.service', 'SELECT') AS lee_servicios,
       NOT has_table_privilege('origen_customer', 'os_customer.service', 'INSERT') AS catalogo_solo_lectura;

SELECT has_table_privilege('origen_med', 'os_customer.public_service_request', 'SELECT')
       AND has_table_privilege('origen_med', 'os_customer.public_service_request', 'INSERT')
       AND NOT has_table_privilege('origen_med', 'os_customer.public_service_request', 'UPDATE')
       AND NOT has_table_privilege('origen_med', 'os_customer.public_service_request', 'DELETE') AS permisos_solicitud_ok,
       has_table_privilege('origen_med', 'os_customer.public_service_request_item', 'SELECT')
       AND has_table_privilege('origen_med', 'os_customer.public_service_request_item', 'INSERT')
       AND NOT has_table_privilege('origen_med', 'os_customer.public_service_request_item', 'UPDATE')
       AND NOT has_table_privilege('origen_med', 'os_customer.public_service_request_item', 'DELETE') AS permisos_items_ok;

ROLLBACK;
