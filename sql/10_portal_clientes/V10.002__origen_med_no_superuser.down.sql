-- V10.002__origen_med_no_superuser.down.sql
-- Revierte la corrección: devuelve SUPERUSER a origen_med.
--
-- ATENCIÓN: ALTER ROLE es CLUSTER-WIDE. Este archivo solo debe ejecutarse si
-- se deshace expresamente la corrección autorizada. No forma parte del flujo
-- normal de rollback de la Etapa 10.

BEGIN;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
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
