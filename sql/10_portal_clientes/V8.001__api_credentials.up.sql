-- V8.001__api_credentials.up.sql
-- Etapa 8: metadatos de credenciales de la API propia de code-api.
-- Autorizado por docs/portal-clientes/acta-autorizacion-etapa-8.md.
-- SOLO entorno de prueba/base independiente. NO ejecutar en producción.
--
-- Reglas:
--   - No se modifica public.api_clients: sin columnas nuevas, hash, scopes,
--     expiración ni organization_id.
--   - El secreto nunca se guarda aquí; solo el id del cliente API asociado.
--   - La escritura en public.api_clients la hace un servicio de servidor con
--     una conexión operativa configurada solo en el VPS (Opción A).
--   - Los privilegios se otorgan por objeto, sin ALTER DEFAULT PRIVILEGES.

BEGIN;

-- Guarda: esta migración solo se ejecuta en la base aislada de prueba.
DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para la Etapa 8: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

-- ---------------------------------------------------------------------------
-- Metadatos del portal. No contienen api_key, token, secreto ni dato comercial.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS os_customer.api_credential (
    id                 BIGSERIAL PRIMARY KEY,
    organization_id    BIGINT NOT NULL
        REFERENCES os_customer.organization(id) ON DELETE RESTRICT,
    -- Identificador opaco del registro en public.api_clients. Sin FK propósito:
    -- esta migración no modifica ni depende físicamente del esquema público.
    api_client_id      INTEGER NOT NULL CHECK (api_client_id > 0),
    institution_name   VARCHAR(150) NOT NULL,
    environment        VARCHAR(20) NOT NULL DEFAULT 'production'
        CHECK (environment = 'production'),
    status             VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'revoked')),
    created_by_user_id BIGINT NOT NULL
        REFERENCES os_customer.app_user(id) ON DELETE RESTRICT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    rotated_by_user_id BIGINT
        REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    rotated_at         TIMESTAMPTZ,
    revoked_by_user_id BIGINT
        REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    revoked_at         TIMESTAMPTZ,
    UNIQUE (api_client_id),
    CHECK (
        (status = 'active' AND revoked_at IS NULL)
        OR (status = 'revoked' AND revoked_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS api_credential_org_id
    ON os_customer.api_credential (organization_id, id);

COMMENT ON TABLE os_customer.api_credential IS
    'Metadatos del portal sobre credenciales de /v1. Nunca contiene la clave API.';

-- Una revocación no se deshace: el estado solo puede pasar a revoked.
CREATE OR REPLACE FUNCTION os_customer.api_credential_immutable_revocation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = 'revoked' AND NEW.status IS DISTINCT FROM 'revoked' THEN
        RAISE EXCEPTION 'Una credencial revocada no puede reactivarse.'
            USING ERRCODE = '23514';
    END IF;

    IF NEW.status = 'revoked' AND NEW.revoked_at IS NULL THEN
        RAISE EXCEPTION 'La revocación exige revoked_at.'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS trg_api_credential_immutable_revocation ON os_customer.api_credential;
CREATE TRIGGER trg_api_credential_immutable_revocation
    BEFORE UPDATE OF status, revoked_at ON os_customer.api_credential
    FOR EACH ROW EXECUTE FUNCTION os_customer.api_credential_immutable_revocation();

-- ---------------------------------------------------------------------------
-- Privilegios: objeto por objeto, sin privilegios predeterminados.
-- ---------------------------------------------------------------------------

DO $priv$
BEGIN
    REVOKE ALL ON TABLE os_customer.api_credential FROM PUBLIC;
    GRANT SELECT, INSERT, UPDATE ON TABLE os_customer.api_credential TO origen_customer;

    REVOKE ALL ON SEQUENCE os_customer.api_credential_id_seq FROM PUBLIC;
    GRANT USAGE, SELECT ON SEQUENCE os_customer.api_credential_id_seq TO origen_customer;
END
$priv$;

COMMIT;
