-- V7.001__services_entitlements.up.sql
-- Etapa 7: servicios técnicos y habilitaciones administradas.
-- Autorizado por docs/portal-clientes/acta-autorizacion-etapa-7.md.
-- SOLO entorno de prueba/base independiente. NO ejecutar en producción.
--
-- Reglas:
--   - Invoice Ninja sigue siendo la fuente de verdad comercial.
--   - No se guardan precios, importes, facturas, pagos ni datos de contacto.
--   - La habilitación exige pago confirmado verificado por un superadministrador
--     y una decisión técnica manual posterior.
--   - Los privilegios se otorgan por objeto, no de forma predeterminada.

BEGIN;

-- ---------------------------------------------------------------------------
-- Catálogo técnico de servicios
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS os_customer.service (
    id              BIGSERIAL PRIMARY KEY,
    code            VARCHAR(64)  NOT NULL UNIQUE,
    name            VARCHAR(120) NOT NULL,
    description     TEXT         NOT NULL,
    domain          VARCHAR(64),
    api_route       VARCHAR(200) NOT NULL,
    api_method      VARCHAR(16)  NOT NULL DEFAULT 'GET'
        CHECK (api_method = 'GET'),
    auth_required   BOOLEAN      NOT NULL DEFAULT true,
    environment     VARCHAR(20)  NOT NULL DEFAULT 'production'
        CHECK (environment = 'production'),
    verified_source VARCHAR(200) NOT NULL,
    verified_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    status          VARCHAR(20)  NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'deprecated', 'retired')),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Relación opaca con un ítem comercial de Invoice Ninja. No guarda nombre ni precio.
CREATE TABLE IF NOT EXISTS os_customer.service_item (
    id                BIGSERIAL PRIMARY KEY,
    service_id        BIGINT NOT NULL
        REFERENCES os_customer.service(id) ON DELETE RESTRICT,
    external_item_ref VARCHAR(64) NOT NULL,
    status            VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (service_id, external_item_ref)
);

-- ---------------------------------------------------------------------------
-- Solicitudes internas de servicios
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS os_customer.service_request (
    id            BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NOT NULL
        REFERENCES os_customer.organization(id) ON DELETE RESTRICT,
    requested_by  BIGINT NOT NULL
        REFERENCES os_customer.app_user(id) ON DELETE RESTRICT,
    status        VARCHAR(24) NOT NULL DEFAULT 'received'
        CHECK (status IN ('received','under_review','needs_info','approved','rejected','converted')),
    note          TEXT,
    reviewed_by   BIGINT REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    reviewed_at   TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_customer.service_request_item (
    request_id BIGINT NOT NULL
        REFERENCES os_customer.service_request(id) ON DELETE CASCADE,
    service_id BIGINT NOT NULL
        REFERENCES os_customer.service(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (request_id, service_id)
);

-- ---------------------------------------------------------------------------
-- Acuerdo comercial verificado. Sin importes ni datos financieros.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS os_customer.contract (
    id                     BIGSERIAL PRIMARY KEY,
    organization_id        BIGINT NOT NULL
        REFERENCES os_customer.organization(id) ON DELETE RESTRICT,
    external_client_ref    VARCHAR(64),
    external_item_ref      VARCHAR(64),
    status                 VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','active','suspended','expired','cancelled')),
    commercial_condition   VARCHAR(40) NOT NULL DEFAULT 'payment_confirmed'
        CHECK (commercial_condition = 'payment_confirmed'),
    commercial_verified_by BIGINT REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    commercial_verified_at TIMESTAMPTZ,
    valid_from             TIMESTAMPTZ,
    valid_to               TIMESTAMPTZ,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT contract_requires_verification CHECK (
        status <> 'active'
        OR (commercial_verified_by IS NOT NULL AND commercial_verified_at IS NOT NULL)
    ),
    CONSTRAINT contract_validity_order CHECK (
        valid_from IS NULL OR valid_to IS NULL OR valid_to > valid_from
    )
);

CREATE INDEX IF NOT EXISTS contract_org_status_idx
    ON os_customer.contract (organization_id, status);

-- ---------------------------------------------------------------------------
-- Habilitación técnica efectiva
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS os_customer.entitlement (
    id             BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NOT NULL
        REFERENCES os_customer.organization(id) ON DELETE RESTRICT,
    service_id     BIGINT NOT NULL
        REFERENCES os_customer.service(id) ON DELETE RESTRICT,
    contract_id    BIGINT REFERENCES os_customer.contract(id) ON DELETE RESTRICT,
    request_id     BIGINT REFERENCES os_customer.service_request(id) ON DELETE SET NULL,
    status         VARCHAR(24) NOT NULL DEFAULT 'pending_activation'
        CHECK (status IN ('pending_activation','active','suspended','expired','revoked')),
    decision_by    BIGINT REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    decision_at    TIMESTAMPTZ,
    reason         TEXT,
    expires_at     TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS entitlement_one_active_per_service
    ON os_customer.entitlement (organization_id, service_id)
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS entitlement_org_status_idx
    ON os_customer.entitlement (organization_id, status);
CREATE INDEX IF NOT EXISTS entitlement_status_idx
    ON os_customer.entitlement (status, id);

-- ---------------------------------------------------------------------------
-- Operadores de Origen Salud. Identidad propia de os_customer, sin os_admin.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS os_customer.operator (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL UNIQUE
        REFERENCES os_customer.app_user(id) ON DELETE RESTRICT,
    role_code   VARCHAR(32) NOT NULL DEFAULT 'superadmin'
        CHECK (role_code = 'superadmin'),
    status      VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','inactive')),
    created_by  BIGINT REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Triggers de updated_at (reutilizan la función creada en V5.001)
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_service_touch ON os_customer.service;
CREATE TRIGGER trg_service_touch
    BEFORE UPDATE ON os_customer.service
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

DROP TRIGGER IF EXISTS trg_service_item_touch ON os_customer.service_item;
CREATE TRIGGER trg_service_item_touch
    BEFORE UPDATE ON os_customer.service_item
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

DROP TRIGGER IF EXISTS trg_service_request_touch ON os_customer.service_request;
CREATE TRIGGER trg_service_request_touch
    BEFORE UPDATE ON os_customer.service_request
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

DROP TRIGGER IF EXISTS trg_contract_touch ON os_customer.contract;
CREATE TRIGGER trg_contract_touch
    BEFORE UPDATE ON os_customer.contract
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

DROP TRIGGER IF EXISTS trg_entitlement_touch ON os_customer.entitlement;
CREATE TRIGGER trg_entitlement_touch
    BEFORE UPDATE ON os_customer.entitlement
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

DROP TRIGGER IF EXISTS trg_operator_touch ON os_customer.operator;
CREATE TRIGGER trg_operator_touch
    BEFORE UPDATE ON os_customer.operator
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

-- ---------------------------------------------------------------------------
-- RBAC: permisos nuevos y rol de superadministrador de Origen Salud
-- ---------------------------------------------------------------------------

INSERT INTO os_customer.role (code, label, description) VALUES
    ('origen_superadmin', 'Superadministrador de Origen Salud',
     'Operador interno que verifica la condición comercial y decide habilitaciones.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO os_customer.permission (code, description) VALUES
    ('service.request', 'Solicitar servicios para la organización.'),
    ('service.activate', 'Habilitar técnicamente un servicio verificado.'),
    ('service.suspend', 'Suspender técnicamente un servicio.'),
    ('service.revoke', 'Revocar técnicamente un servicio.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO os_customer.role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM os_customer.role r
JOIN os_customer.permission p ON (
    (r.code = 'origen_superadmin' AND p.code IN (
        'service.read','service.request','service.activate','service.suspend','service.revoke'))
    OR (r.code IN ('organization_owner','organization_admin') AND p.code = 'service.request')
)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Catálogo inicial: solo endpoints verificados en el repositorio.
-- Fuentes: api/index.php, docs/api/openapi-3.1.yaml, README-API.md.
-- ---------------------------------------------------------------------------

INSERT INTO os_customer.service
    (code, name, description, domain, api_route, api_method, auth_required, verified_source)
VALUES
    ('api.health', 'Estado del servicio',
     'Verificación pública de disponibilidad del servicio y la base.',
     'infrastructure', '/health', 'GET', false,
     'api/index.php;docs/api/openapi-3.1.yaml'),
    ('api.search', 'Búsqueda unificada',
     'Búsqueda multi-dominio de terminologías clínicas.',
     'search', '/v1/search', 'GET', true,
     'api/index.php;docs/api/openapi-3.1.yaml'),
    ('api.catalogs', 'Catálogos publicados',
     'Consulta de catálogos publicados y sus versiones.',
     'catalogs', '/v1/catalogs', 'GET', true,
     'api/index.php;README-API.md'),
    ('api.mappings', 'Mapeos terminológicos',
     'Mapeos cruzados entre terminologías clínicas.',
     'mappings', '/v1/mappings', 'GET', true,
     'api/index.php;docs/api/openapi-3.1.yaml'),
    ('api.snomed', 'SNOMED CT',
     'Detalle de conceptos SNOMED CT por identificador.',
     'terminology', '/v1/snomed/{sctid}', 'GET', true,
     'api/index.php;docs/api/openapi-3.1.yaml'),
    ('api.cie10', 'CIE-10',
     'Detalle de códigos CIE-10.',
     'terminology', '/v1/cie10/{codigo}', 'GET', true,
     'api/index.php;docs/api/openapi-3.1.yaml'),
    ('api.loinc', 'LOINC',
     'Búsqueda y detalle de códigos LOINC.',
     'terminology', '/v1/loinc', 'GET', true,
     'api/index.php;docs/api/openapi-3.1.yaml'),
    ('api.anmat', 'ANMAT',
     'Detalle de registros ANMAT por identificador.',
     'terminology', '/v1/anmat/{id}', 'GET', true,
     'api/index.php;docs/api/openapi-3.1.yaml'),
    ('api.nomenclador', 'Nomencladores argentinos',
     'Consulta unificada de nomencladores argentinos.',
     'nomenclator', '/v1/nomenclador', 'GET', true,
     'api/index.php;README-API.md'),
    ('api.pmo', 'Prácticas PMO',
     'Consulta de prácticas de la nomenclatura PMO.',
     'nomenclator', '/v1/pmo/practicas', 'GET', true,
     'api/index.php;docs/api/openapi-3.1.yaml'),
    ('api.vademecum', 'Vademécum',
     'Consulta de medicamentos por troquel, código o monodroga.',
     'pharmacy', '/v1/vademecum', 'GET', true,
     'api/index.php;README-API.md'),
    ('docs.public', 'Documentación técnica',
     'Centro de documentación pública de la plataforma.',
     'documentation', '/docs', 'GET', false,
     'web/docs.php;portal/Router.php'),
    ('browse.codes', 'Explorador de códigos',
     'Búsqueda y ficha de códigos con relaciones e historial.',
     'documentation', '/{locale}/browse', 'GET', false,
     'portal/Router.php;portal/Controllers/BrowseController.php')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Privilegios: objeto por objeto, sin privilegios predeterminados.
-- ---------------------------------------------------------------------------

DO $priv$
DECLARE
    t text;
BEGIN
    -- Catálogo y operadores: solo lectura desde la aplicación.
    FOREACH t IN ARRAY ARRAY['service','service_item','operator'] LOOP
        EXECUTE format('REVOKE ALL ON TABLE os_customer.%I FROM PUBLIC', t);
        EXECUTE format('GRANT SELECT ON TABLE os_customer.%I TO origen_customer', t);
    END LOOP;

    -- Solicitudes: lectura y creación; la revisión es manual y no se implementa aquí.
    FOREACH t IN ARRAY ARRAY['service_request','service_request_item'] LOOP
        EXECUTE format('REVOKE ALL ON TABLE os_customer.%I FROM PUBLIC', t);
        EXECUTE format('GRANT SELECT, INSERT ON TABLE os_customer.%I TO origen_customer', t);
    END LOOP;

    -- Contratos e habilitaciones: lectura, creación y decisión manual.
    FOREACH t IN ARRAY ARRAY['contract','entitlement'] LOOP
        EXECUTE format('REVOKE ALL ON TABLE os_customer.%I FROM PUBLIC', t);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE ON TABLE os_customer.%I TO origen_customer', t);
    END LOOP;

    FOREACH t IN ARRAY ARRAY[
        'service_request_id_seq','contract_id_seq','entitlement_id_seq'
    ] LOOP
        EXECUTE format('REVOKE ALL ON SEQUENCE os_customer.%I FROM PUBLIC', t);
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE os_customer.%I TO origen_customer', t);
    END LOOP;
END
$priv$;

COMMIT;
