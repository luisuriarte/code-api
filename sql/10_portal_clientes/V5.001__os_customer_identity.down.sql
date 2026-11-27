-- V5.001__os_customer_identity.down.sql
-- Revierte la Etapa 5. SOLO entorno de prueba. NO ejecutar en producción.
--
-- Re-ejecutable: puede correrse varias veces seguidas sin fallar aunque el rol
-- o las tablas ya no existan.
--
-- La auditoría append-only NO se elimina: os_customer.audit_log y su trigger
-- permanecen intactos. Se revocan los privilegios de la aplicación sobre ella
-- antes de quitar el rol.

BEGIN;

DO $guard$
BEGIN
    IF current_database() <> 'origen_codes_portal_clientes_test' THEN
        RAISE EXCEPTION 'Base no permitida para V5.001: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

DO $revoke$
DECLARE
    obj text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'origen_customer') THEN
        RETURN;
    END IF;

    IF to_regnamespace('os_customer') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON SCHEMA os_customer FROM origen_customer';

        FOREACH obj IN ARRAY ARRAY[
            'audit_log','organization','app_user','membership','invitation',
            'session','password_reset','auth_throttle','role','permission','role_permission'
        ] LOOP
            IF to_regclass(format('os_customer.%I', obj)) IS NOT NULL THEN
                EXECUTE format('REVOKE ALL ON TABLE os_customer.%I FROM origen_customer', obj);
            END IF;
        END LOOP;

        FOREACH obj IN ARRAY ARRAY[
            'organization_id_seq','app_user_id_seq','role_id_seq','permission_id_seq',
            'membership_id_seq','invitation_id_seq','session_id_seq',
            'password_reset_id_seq','auth_throttle_id_seq','audit_log_id_seq'
        ] LOOP
            IF to_regclass(format('os_customer.%I', obj)) IS NOT NULL THEN
                EXECUTE format('REVOKE ALL ON SEQUENCE os_customer.%I FROM origen_customer', obj);
            END IF;
        END LOOP;
    END IF;

    EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM origen_customer', current_database());
EXCEPTION
    WHEN undefined_object THEN NULL;
END
$revoke$;

-- El orden respeta las claves foráneas. audit_log queda fuera de la lista.
DROP TABLE IF EXISTS os_customer.invitation;
DROP TABLE IF EXISTS os_customer.session;
DROP TABLE IF EXISTS os_customer.password_reset;
DROP TABLE IF EXISTS os_customer.auth_throttle;
DROP TABLE IF EXISTS os_customer.membership;
DROP TABLE IF EXISTS os_customer.role_permission;
DROP TABLE IF EXISTS os_customer.permission;
DROP TABLE IF EXISTS os_customer.role;
DROP TABLE IF EXISTS os_customer.app_user;
DROP TABLE IF EXISTS os_customer.organization;

-- La función de touch ya no tiene tablas que la usen. La de auditoría se
-- conserva porque sigue protegiendo audit_log.
DROP FUNCTION IF EXISTS os_customer.touch_updated_at();

-- El esquema y audit_log permanecen; solo se quita el rol de aplicación.
-- ATENCIÓN: DROP ROLE es CLUSTER-WIDE y afecta también a las demás bases.
-- Este `down` solo se ejecuta en la base de prueba exacta
-- `origen_codes_portal_clientes_test`. Revertir el rol en producción es un
-- procedimiento manual auditado, con acta nueva: NO se hace con este down.
DROP ROLE IF EXISTS origen_customer;

COMMIT;
