-- V7.002__dentar_oftar_services.down.sql
-- Revierte solo las dos filas agregadas por V7.002. No toca V7.001, V5, V6,
-- la auditoría ni ninguna habilitación ajena a estas dos servicios.
-- SOLO entorno de prueba/base independiente. NO ejecutar en producción.

BEGIN;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para V7.002: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

DELETE FROM os_customer.service
WHERE code IN ('api.dentar', 'api.oftar');

COMMIT;
