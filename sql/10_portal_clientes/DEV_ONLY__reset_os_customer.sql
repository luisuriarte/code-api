-- ===========================================================================
-- DEV ONLY — NUNCA en producción
-- ===========================================================================
-- Reinicio completo del esquema os_customer para desarrollo.
-- A diferencia de V5.001__...down.sql, SÍ elimina os_customer.audit_log.
-- No es una migración versionada: no debe ser ejecutada por un runner.
--
-- Whitelist estricta: SOLO se permite la base de prueba exacta
-- `origen_codes_portal_clientes_test`. Cualquier otra base —incluidas
-- `origen_codes` y la productiva `origen_codes_portal_clientes`— se rechaza.
-- ===========================================================================

BEGIN;

DO $guard$
BEGIN
    IF current_database() <> 'origen_codes_portal_clientes_test' THEN
        RAISE EXCEPTION 'DEV_ONLY: solo se permite origen_codes_portal_clientes_test; base actual: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

DO $revoke$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'origen_customer') THEN
        EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM origen_customer', current_database());
    END IF;
EXCEPTION
    WHEN undefined_object THEN NULL;
END
$revoke$;

-- Borra tablas, datos, auditoría, funciones y triggers del esquema.
DROP SCHEMA IF EXISTS os_customer CASCADE;

-- El rol queda eliminado en esta base. La próxima ejecución del up lo crea.
DROP ROLE IF EXISTS origen_customer;

COMMIT;
