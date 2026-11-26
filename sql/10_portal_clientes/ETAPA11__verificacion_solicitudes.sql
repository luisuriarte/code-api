-- ETAPA11__verificacion_solicitudes.sql
-- Verificación SELECT-only de las solicitudes de prueba de la Etapa 11.
-- No modifica datos. No muestra correos, identificadores fiscales, importes
-- ni secretos: solo agregados y estados.
-- Solo base aislada de prueba.

BEGIN READ ONLY;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para la verificación Etapa 11: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

SELECT current_database() AS base, current_user AS usuario;

SELECT count(*) AS solicitudes,
       count(*) FILTER (WHERE duplicate_of IS NOT NULL) AS marcadas_duplicadas,
       count(*) FILTER (WHERE status = 'needs_review') AS para_revision
FROM os_customer.public_service_request;

SELECT status, count(*) AS cantidad
FROM os_customer.public_service_request
GROUP BY status
ORDER BY status;

SELECT ninja_client_status, count(*) AS cantidad
FROM os_customer.public_service_request
GROUP BY ninja_client_status
ORDER BY ninja_client_status;

SELECT count(*) AS items,
       count(DISTINCT request_id) AS solicitudes_con_items
FROM os_customer.public_service_request_item;

SELECT count(*) AS solicitudes_sin_items
FROM os_customer.public_service_request r
WHERE NOT EXISTS (
    SELECT 1
    FROM os_customer.public_service_request_item i
    WHERE i.request_id = r.id
);

SELECT count(*) AS columnas_prohibidas
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name IN ('public_service_request', 'public_service_request_item')
  AND column_name ~* '(price|amount|total|invoice_number|payment|currency|product_name)';

ROLLBACK;
