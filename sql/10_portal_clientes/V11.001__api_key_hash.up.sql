-- V11.001__api_key_hash.up.sql
-- Evolución M6 de credenciales de la API propia: columnas para hash con pepper.
-- PREPARADA PARA DESPLIEGUE, NO EJECUTADA EN LA AUDITORÍA.
-- Requiere acta de despliegue y rotación autorizada antes de cualquier ejecución.
--
-- Base objetivo: origen_codes. Es la única base que contiene public.api_clients.
-- Excepción autorizada en el acta de la Etapa 8: esta tabla se escribe desde la
-- conexión operativa del portal de clientes, aunque el esquema no pertenezca a
-- os_customer. Ninguna migración V5.001..V10.001 se ejecuta aquí.
--
-- Reglas:
--   - Sin backfill: las claves legacy siguen en api_key y se leerán por
--     compatibilidad. Este artefacto solo agrega columnas vacías.
--   - api_key pasa a nullable para que las claves nuevas se guarden solo como
--     hash (api_key = NULL). No borra ni reescribe filas existentes.
--   - Las claves nuevas usan key_prefix/key_hash con
--     SHA-256(clave + NUL + pepper).
--   - El pepper se lee de API_KEY_PEPPER; nunca se versiona su valor real.
--   - Privilegios por objeto; no se usa ALTER DEFAULT PRIVILEGES.

BEGIN;

DO $guard$
BEGIN
    IF current_database() <> 'origen_codes' THEN
        RAISE EXCEPTION 'V11.001 requiere la base exacta origen_codes, no %', current_database()
            USING ERRCODE = '42501';
    END IF;

    IF to_regclass('public.api_clients') IS NULL THEN
        RAISE EXCEPTION 'No existe public.api_clients en %', current_database()
            USING ERRCODE = '42P01';
    END IF;
END
$guard$;

ALTER TABLE public.api_clients
    ALTER COLUMN api_key DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS key_prefix VARCHAR(12),
    ADD COLUMN IF NOT EXISTS key_hash VARCHAR(64);

COMMENT ON COLUMN public.api_clients.api_key IS
    'Reservado a claves legacy en texto plano; nullable. Las claves nuevas se guardan solo en key_prefix/key_hash con SHA-256(clave + NUL + pepper) y dejan api_key en NULL.';
COMMENT ON COLUMN public.api_clients.key_prefix IS
    'Prefijo legible de la clave nueva (hasta 12 caracteres). No es el secreto.';
COMMENT ON COLUMN public.api_clients.key_hash IS
    'SHA-256(clave + NUL + API_KEY_PEPPER) de las credenciales nuevas. Nunca contiene la clave en claro.';

-- Privilegios explícitos sobre los objetos ya existentes. No hay cambios de
-- privilegios predeterminados ni roles nuevos.
DO $priv$
BEGIN
    REVOKE ALL ON TABLE public.api_clients FROM PUBLIC;
    GRANT SELECT, INSERT, UPDATE ON TABLE public.api_clients TO origen_admin;
    GRANT USAGE ON SEQUENCE public.api_clients_id_seq TO origen_admin;
END
$priv$;

COMMIT;
