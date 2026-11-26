-- V10.001__public_service_requests.down.sql
-- Revierte solo las dos tablas de la Solicitud de Servicios.
-- No toca V5, V6, V7, V7.002, V8, la auditoría ni las habilitaciones.
-- SOLO entorno de prueba/base independiente. NO ejecutar en producción.

BEGIN;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para V10.001: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

DROP TABLE IF EXISTS os_customer.public_service_request_item;
DROP TABLE IF EXISTS os_customer.public_service_request;

-- V10.001 fue el único otorgante de USAGE en este esquema a origen_med.
REVOKE USAGE ON SCHEMA os_customer FROM origen_med;

COMMIT;
