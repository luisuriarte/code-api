-- V6.001__invoice_ninja_links.up.sql
-- Etapa 6: vinculación y revisión de clientes de Invoice Ninja.
-- Autorizado por docs/portal-clientes/acta-autorizacion-etapa-6.md.
-- SOLO entorno de prueba/base independiente. NO ejecutar en producción.
--
-- Guarda únicamente identificadores y metadatos técnicos. No guarda precios,
-- productos, presupuestos, facturas, pagos, razones sociales ni correos.

BEGIN;

-- ---------------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS os_customer.invoice_ninja_client_link (
    id                       BIGSERIAL PRIMARY KEY,
    organization_id          BIGINT NOT NULL UNIQUE
        REFERENCES os_customer.organization(id) ON DELETE RESTRICT,
    invoice_ninja_client_id  VARCHAR(64) NOT NULL,
    status                   VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'needs_review', 'inactive')),
    matched_by               VARCHAR(32) NOT NULL
        CHECK (matched_by IN ('existing_link', 'tax_id', 'legal_name', 'contact', 'manual')),
    match_confidence         VARCHAR(16) NOT NULL DEFAULT 'exact'
        CHECK (match_confidence IN ('exact', 'probable', 'manual')),
    created_by               BIGINT REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    reviewed_by              BIGINT REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    reviewed_at              TIMESTAMPTZ,
    notes                    TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_customer.invoice_ninja_duplicate_review (
    id                    BIGSERIAL PRIMARY KEY,
    organization_id       BIGINT NOT NULL
        REFERENCES os_customer.organization(id) ON DELETE RESTRICT,
    candidate_client_id   VARCHAR(64),
    candidate_contact_id  VARCHAR(64),
    match_reason          VARCHAR(32) NOT NULL
        CHECK (match_reason IN ('existing_link', 'tax_id', 'legal_name', 'contact_email', 'manual')),
    status                VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected', 'discarded')),
    requested_by          BIGINT REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    reviewed_by           BIGINT REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    reviewed_at           TIMESTAMPTZ,
    resolution_note       TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS invoice_ninja_link_status_idx
    ON os_customer.invoice_ninja_client_link (status, invoice_ninja_client_id);
CREATE INDEX IF NOT EXISTS invoice_ninja_review_org_idx
    ON os_customer.invoice_ninja_duplicate_review (organization_id, status);

-- ---------------------------------------------------------------------------
-- Triggers de updated_at (reutilizan la función creada en V5.001)
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_invoice_ninja_link_touch
    ON os_customer.invoice_ninja_client_link;
CREATE TRIGGER trg_invoice_ninja_link_touch
    BEFORE UPDATE ON os_customer.invoice_ninja_client_link
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

DROP TRIGGER IF EXISTS trg_invoice_ninja_review_touch
    ON os_customer.invoice_ninja_duplicate_review;
CREATE TRIGGER trg_invoice_ninja_review_touch
    BEFORE UPDATE ON os_customer.invoice_ninja_duplicate_review
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Privilegios: objeto por objeto. Sin ALTER DEFAULT PRIVILEGES.
-- ---------------------------------------------------------------------------

DO $priv$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'invoice_ninja_client_link','invoice_ninja_duplicate_review'
    ] LOOP
        EXECUTE format('REVOKE ALL ON TABLE os_customer.%I FROM PUBLIC', t);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE os_customer.%I TO origen_customer', t);
    END LOOP;

    FOREACH t IN ARRAY ARRAY[
        'invoice_ninja_client_link_id_seq','invoice_ninja_duplicate_review_id_seq'
    ] LOOP
        EXECUTE format('REVOKE ALL ON SEQUENCE os_customer.%I FROM PUBLIC', t);
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE os_customer.%I TO origen_customer', t);
    END LOOP;
END
$priv$;

COMMIT;
