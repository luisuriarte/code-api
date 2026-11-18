-- FASE 5 — Productos, presentaciones e identificadores (propuesta, NO EJECUTAR)
-- Requiere fase1 y fase4. Crea estructura VACÍA: no carga productos, marcas,
-- registros sanitarios ni identificadores sin fuente verificable.
-- Las tablas farmacéuticas existentes (os_substance, os_medicinal_product,
-- os_product_package, os_product_identifier) se conservan como legado.

BEGIN;

CREATE TABLE IF NOT EXISTS os_manufacturer (
    id BIGSERIAL PRIMARY KEY,
    legal_name VARCHAR(255) NOT NULL,
    country_code VARCHAR(2),
    website VARCHAR(255),
    source_reference TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (legal_name, country_code)
);

CREATE TABLE IF NOT EXISTS os_concept (
    id BIGSERIAL PRIMARY KEY,
    permanent_code VARCHAR(60) NOT NULL UNIQUE,
    label VARCHAR(255) NOT NULL,
    domain_code VARCHAR(50) REFERENCES os_domain_registry(code) ON UPDATE CASCADE,
    concept_kind VARCHAR(60) NOT NULL,
    source_reference TEXT,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unknown'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON COLUMN os_concept.concept_kind IS
    'Clasificación del concepto general; los valores deben derivarse del modelo aprobado, no inventarse por similitud de nombres.';

CREATE TABLE IF NOT EXISTS os_product (
    id BIGSERIAL PRIMARY KEY,
    concept_id BIGINT NOT NULL REFERENCES os_concept(id) ON DELETE CASCADE,
    product_name VARCHAR(255) NOT NULL,
    brand VARCHAR(150),
    model VARCHAR(150),
    manufacturer_id BIGINT REFERENCES os_manufacturer(id) ON DELETE SET NULL,
    source_reference TEXT,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unknown'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (concept_id, product_name, brand, model)
);

CREATE TABLE IF NOT EXISTS os_product_presentation (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES os_product(id) ON DELETE CASCADE,
    presentation_text VARCHAR(255) NOT NULL,
    pack_size NUMERIC(12, 3),
    size_value VARCHAR(80),
    form VARCHAR(80),
    concentration VARCHAR(120),
    source_reference TEXT,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unknown'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (product_id, presentation_text)
);

CREATE TABLE IF NOT EXISTS os_product_identifier_type (
    code VARCHAR(40) PRIMARY KEY,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO os_product_identifier_type (code, description) VALUES
    ('GTIN', 'Global Trade Item Number (GS1).'),
    ('UDI',  'Unique Device Identifier.'),
    ('MANUFACTURER', 'Código del fabricante o titular.')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS os_product_identifiers (
    id BIGSERIAL PRIMARY KEY,
    presentation_id BIGINT NOT NULL REFERENCES os_product_presentation(id) ON DELETE CASCADE,
    identifier_type VARCHAR(40) NOT NULL REFERENCES os_product_identifier_type(code) ON UPDATE CASCADE,
    identifier_value VARCHAR(100) NOT NULL,
    issuing_system VARCHAR(80),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    valid_from DATE,
    valid_to DATE,
    source_reference TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_os_product_identifier_scoped
        UNIQUE (presentation_id, identifier_type, identifier_value, valid_from),
    CONSTRAINT ck_os_product_identifier_validity
        CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to > valid_from)
);

COMMENT ON TABLE os_product_identifiers IS
    'Identificadores por presentación. Corrige la UNIQUE global del modelo farmacéutico heredado: el mismo valor puede ser legítimo en más de una presentación.';

CREATE TABLE IF NOT EXISTS os_manufacturer_role (
    code VARCHAR(40) PRIMARY KEY,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO os_manufacturer_role (code, description) VALUES
    ('fabricante', 'Fabricante del producto.'),
    ('titular', 'Titular de la autorización o registro.'),
    ('importador', 'Importador.'),
    ('distribuidor', 'Distribuidor.')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS os_product_manufacturer (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES os_product(id) ON DELETE CASCADE,
    manufacturer_id BIGINT NOT NULL REFERENCES os_manufacturer(id) ON DELETE CASCADE,
    role_code VARCHAR(40) NOT NULL REFERENCES os_manufacturer_role(code) ON UPDATE CASCADE,
    valid_from DATE,
    valid_to DATE,
    source_reference TEXT,
    CONSTRAINT uq_os_product_manufacturer UNIQUE (product_id, manufacturer_id, role_code, valid_from),
    CONSTRAINT ck_os_product_manufacturer_validity
        CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to > valid_from)
);

CREATE TABLE IF NOT EXISTS os_regulatory_records (
    id BIGSERIAL PRIMARY KEY,
    presentation_id BIGINT NOT NULL REFERENCES os_product_presentation(id) ON DELETE CASCADE,
    authority VARCHAR(120) NOT NULL,
    record_number VARCHAR(100) NOT NULL,
    record_type VARCHAR(60),
    country_code VARCHAR(2),
    valid_from DATE,
    valid_to DATE,
    source_reference TEXT NOT NULL,
    license_reference TEXT,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unknown'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_os_regulatory_record UNIQUE (presentation_id, authority, record_number),
    CONSTRAINT ck_os_regulatory_record_validity
        CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to > valid_from)
);

CREATE INDEX IF NOT EXISTS idx_os_product_concept ON os_product (concept_id);
CREATE INDEX IF NOT EXISTS idx_os_presentation_product ON os_product_presentation (product_id);
CREATE INDEX IF NOT EXISTS idx_os_product_identifiers_value
    ON os_product_identifiers (identifier_type, identifier_value);
CREATE INDEX IF NOT EXISTS idx_os_regulatory_record_number
    ON os_regulatory_records (authority, record_number);

COMMIT;

-- Verificación sugerida (no ejecutar automáticamente):
-- SELECT 'os_concept' AS tabla, count(*) FROM os_concept
-- UNION ALL SELECT 'os_product', count(*) FROM os_product
-- UNION ALL SELECT 'os_product_presentation', count(*) FROM os_product_presentation
-- UNION ALL SELECT 'os_product_identifiers', count(*) FROM os_product_identifiers
-- UNION ALL SELECT 'os_regulatory_records', count(*) FROM os_regulatory_records;
