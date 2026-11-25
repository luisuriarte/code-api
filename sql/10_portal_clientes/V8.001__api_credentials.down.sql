-- V8.001__api_credentials.down.sql
-- Reversión de la Etapa 8. Conserva V5, V6, V7 y os_customer.audit_log.
-- Autorizado por docs/portal-clientes/acta-autorizacion-etapa-8.md.
-- SOLO entorno de prueba/base independiente. NO ejecutar en producción.
-- No toca public.api_clients: las credenciales ya creadas quedan como están.

BEGIN;

-- Guarda: esta reversión solo se ejecuta en la base aislada de prueba.
DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para la Etapa 8: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

DROP TRIGGER IF EXISTS trg_api_credential_immutable_revocation ON os_customer.api_credential;
DROP FUNCTION IF EXISTS os_customer.api_credential_immutable_revocation();
DROP TABLE IF EXISTS os_customer.api_credential;

COMMIT;
