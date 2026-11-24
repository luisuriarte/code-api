-- V6.001__invoice_ninja_links.down.sql
-- Revierte la Etapa 6. SOLO entorno de prueba. NO ejecutar en producción.
--
-- Re-ejecutable: puede correrse varias veces seguidas sin fallar aunque las
-- tablas o el rol ya no existan.
--
-- NO toca ninguna tabla creada en V5.001, en especial os_customer.audit_log.
-- Debe ejecutarse ANTES del down de V5.001.

BEGIN;

DO $revoke$
DECLARE
    obj text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'origen_customer') THEN
        RETURN;
    END IF;

    IF to_regnamespace('os_customer') IS NOT NULL THEN
        FOREACH obj IN ARRAY ARRAY[
            'invoice_ninja_client_link','invoice_ninja_duplicate_review'
        ] LOOP
            IF to_regclass(format('os_customer.%I', obj)) IS NOT NULL THEN
                EXECUTE format('REVOKE ALL ON TABLE os_customer.%I FROM origen_customer', obj);
            END IF;
        END LOOP;

        FOREACH obj IN ARRAY ARRAY[
            'invoice_ninja_client_link_id_seq','invoice_ninja_duplicate_review_id_seq'
        ] LOOP
            IF to_regclass(format('os_customer.%I', obj)) IS NOT NULL THEN
                EXECUTE format('REVOKE ALL ON SEQUENCE os_customer.%I FROM origen_customer', obj);
            END IF;
        END LOOP;
    END IF;
EXCEPTION
    WHEN undefined_object THEN NULL;
END
$revoke$;

DROP TABLE IF EXISTS os_customer.invoice_ninja_duplicate_review;
DROP TABLE IF EXISTS os_customer.invoice_ninja_client_link;

COMMIT;
