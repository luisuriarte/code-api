-- V10.002__origen_med_no_superuser.down.sql
-- Revierte la corrección: devuelve SUPERUSER a origen_med.
--
-- ATENCIÓN: ALTER ROLE es CLUSTER-WIDE: afecta también a origen_codes aunque
-- se ejecute con -d sobre la base de prueba. Este down solo se ejecuta en la
-- base de prueba exacta `origen_codes_portal_clientes_test` y solo si se
-- deshace expresamente la corrección autorizada. No forma parte del flujo
-- normal de rollback de la Etapa 10. Restaurar SUPERUSER en producción exige
-- acta nueva y procedimiento manual auditado.

BEGIN;

DO $guard$
BEGIN
    -- Guarda anterior (obsoleta): current_database() NOT LIKE 'origen_codes_portal_clientes%'
    -- permitía la base productiva; se reemplaza por la base de prueba exacta.
    IF current_database() <> 'origen_codes_portal_clientes_test' THEN
        RAISE EXCEPTION 'Base no permitida para V10.002: %', current_database()
            USING ERRCODE = '42501';
    END IF;

    IF to_regrole('origen_med') IS NULL THEN
        RAISE EXCEPTION 'Falta el rol origen_med; no se modifica ningún rol.'
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

ALTER ROLE origen_med SUPERUSER;

COMMIT;
