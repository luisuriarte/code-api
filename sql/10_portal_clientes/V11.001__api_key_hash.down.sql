-- V11.001__api_key_hash.down.sql
-- Reversión preparada de V11.001. NO EJECUTADA EN LA AUDITORÍA.
-- Solo se considera con acta de despliegue/rollback autorizada y revisión
-- humana previa: si hay claves nuevas (api_key IS NULL), no se revierte nada.
--
-- Regla: SET NOT NULL solo cuando no queden filas con api_key IS NULL.
-- La guarda omite la reversión con NOTICE en vez de fallar, para no perder
-- credenciales nuevas ni dejar la tabla a medias. No hay backfill: las filas
-- legacy no se reescriben.

BEGIN;

DO $guard$
BEGIN
    IF current_database() <> 'origen_codes' THEN
        RAISE EXCEPTION 'V11.001 down requiere la base exacta origen_codes, no %', current_database()
            USING ERRCODE = '42501';
    END IF;

    IF to_regclass('public.api_clients') IS NULL THEN
        RAISE EXCEPTION 'No existe public.api_clients en %', current_database()
            USING ERRCODE = '42P01';
    END IF;
END
$guard$;

DO $rollback$
DECLARE
    filas_clave_nueva bigint;
BEGIN
    SELECT count(*) INTO filas_clave_nueva
    FROM public.api_clients
    WHERE api_key IS NULL;

    IF filas_clave_nueva > 0 THEN
        RAISE NOTICE 'V11.001 down omitido: % filas tienen api_key IS NULL (claves nuevas). Revisión humana requerida; no se quitan columnas ni se restaura NOT NULL.', filas_clave_nueva;
        RETURN;
    END IF;

    COMMENT ON COLUMN public.api_clients.api_key IS NULL;

    ALTER TABLE public.api_clients
        DROP COLUMN IF EXISTS key_hash,
        DROP COLUMN IF EXISTS key_prefix;

    ALTER TABLE public.api_clients
        ALTER COLUMN api_key SET NOT NULL;
END
$rollback$;

COMMIT;
