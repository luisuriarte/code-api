-- V10.001__public_service_requests.up.sql
-- Etapa 10: Solicitud de Servicios pública, sin cuenta ni cuenta técnica.
-- Autorizado por docs/portal-clientes/acta-autorizacion-etapa-10.md.
-- SOLO entorno de prueba/base independiente. NO ejecutar en producción.
--
-- Reglas:
--   - Invoice Ninja sigue siendo la fuente de verdad comercial y financiera.
--   - No se guardan precios, importes, facturas ni pagos.
--   - No se crean clientes, presupuestos, habilitaciones ni credenciales.
--   - Privilegios por objeto: origen_med solo puede consultar e insertar en
--     estas dos tablas; no obtiene UPDATE, DELETE ni acceso a otras tablas.

BEGIN;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para V10.001: %', current_database()
            USING ERRCODE = '42501';
    END IF;

    IF to_regrole('origen_med') IS NULL THEN
        RAISE EXCEPTION 'Falta el rol origen_med; no se otorgan privilegios.'
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

CREATE TABLE os_customer.public_service_request (
    id                  BIGSERIAL PRIMARY KEY,
    reference           TEXT NOT NULL UNIQUE,
    locale              TEXT NOT NULL CHECK (locale IN ('es-AR', 'en', 'pt-BR')),
    organization_name   TEXT NOT NULL CHECK (char_length(organization_name) BETWEEN 1 AND 160),
    contact_name        TEXT NOT NULL CHECK (char_length(contact_name) BETWEEN 1 AND 120),
    contact_email       TEXT NOT NULL CHECK (position('@' IN contact_email) > 1),
    country             TEXT NOT NULL DEFAULT '',
    tax_id_normalized   TEXT NOT NULL DEFAULT '',
    dedupe_key          TEXT NOT NULL,
    note                TEXT NOT NULL DEFAULT '',
    terms_accepted      BOOLEAN NOT NULL DEFAULT false,
    status              TEXT NOT NULL DEFAULT 'received'
        CHECK (status IN ('received', 'needs_review', 'under_review',
                          'approved', 'rejected', 'converted')),
    ninja_client_status TEXT NOT NULL DEFAULT 'not_checked'
        CHECK (ninja_client_status IN ('not_checked', 'none', 'exact',
                                       'ambiguous', 'unavailable')),
    duplicate_of        BIGINT NULL REFERENCES os_customer.public_service_request(id)
        ON DELETE RESTRICT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX public_service_request_dedupe_idx
    ON os_customer.public_service_request (dedupe_key, created_at DESC);

CREATE TABLE os_customer.public_service_request_item (
    id          BIGSERIAL PRIMARY KEY,
    request_id  BIGINT NOT NULL REFERENCES os_customer.public_service_request(id)
        ON DELETE RESTRICT,
    product_ref TEXT NOT NULL CHECK (char_length(product_ref) BETWEEN 1 AND 64),
    quantity    INTEGER NOT NULL DEFAULT 1 CHECK (quantity BETWEEN 1 AND 20),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX public_service_request_item_request_idx
    ON os_customer.public_service_request_item (request_id);

-- USAGE de esquema es necesario para alcanzar los objetos; no da acceso a
-- ninguna otra tabla de os_customer.
GRANT USAGE ON SCHEMA os_customer TO origen_med;
GRANT SELECT, INSERT ON TABLE os_customer.public_service_request TO origen_med;
GRANT SELECT, INSERT ON TABLE os_customer.public_service_request_item TO origen_med;
GRANT USAGE ON SEQUENCE os_customer.public_service_request_id_seq TO origen_med;
GRANT USAGE ON SEQUENCE os_customer.public_service_request_item_id_seq TO origen_med;

COMMIT;
