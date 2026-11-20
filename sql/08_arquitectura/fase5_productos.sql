-- =============================================================================
-- FASE 6 (§16) · Modelo de productos, presentaciones e identificadores
-- =============================================================================
-- NOTA DE NUMERACIÓN: el nombre del archivo conserva la numeración histórica
-- de la carpeta. Según §16 del documento de arquitectura esto es la FASE 6.
-- Ver la tabla de alineación en sql/08_arquitectura/README.md.
--
-- PROPUESTA PREPARADA EL 2026-11-20. NO EJECUTAR SIN APROBACIÓN Y BACKUP.
-- Autorización registrada: "Fase 6: productos". Requiere la Fase 1 ejecutada
-- (os_domain_registry, os_review_state) y backup verificado.
--
-- ESTRUCTURA VACÍA: no carga productos, marcas, fabricantes, registros
-- sanitarios ni identificadores sin fuente verificable. Los únicos INSERT son
-- los tipos de identificador y los roles de fabricante documentados en §8.3.
-- Las tablas farmacéuticas heredadas (os_substance, os_medicinal_product,
-- os_product_package, os_product_identifier) NO se modifican.
--
-- ADITIVO Y TRANSACCIONAL:
--   · CREATE TABLE IF NOT EXISTS, CREATE INDEX IF NOT EXISTS,
--     INSERT ... ON CONFLICT DO NOTHING y REVOKE.
--   · No elimina tablas, columnas ni datos. No contiene DDL destructivo.
--   · No modifica importadores, API pública, catálogos publicados ni
--     Browse Codes.
--
-- PRIVILEGIOS: se revoca PUBLIC/origen_admin sobre las nueve tablas nuevas
-- por el DEFAULT ACL de public, en la misma transacción.
--
-- ROLLBACK: restaurar el dump previo (ver README). No hay DDL destructivo.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Preflight
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.os_domain_registry') IS NULL
       OR to_regclass('public.os_review_state') IS NULL THEN
        RAISE EXCEPTION 'Fase 6 requiere la Fase 1 (os_domain_registry y os_review_state)';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Fabricantes y conceptos generales
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 2. Producto comercial y presentación
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 3. Identificadores por presentación
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 4. Roles de fabricante y registro sanitario
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 5. DEFAULT ACL: retirar privilegios automáticos sobre las tablas nuevas
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON TABLE
    public.os_manufacturer,
    public.os_concept,
    public.os_product,
    public.os_product_presentation,
    public.os_product_identifier_type,
    public.os_product_identifiers,
    public.os_manufacturer_role,
    public.os_product_manufacturer,
    public.os_regulatory_records
FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE
            public.os_manufacturer,
            public.os_concept,
            public.os_product,
            public.os_product_presentation,
            public.os_product_identifier_type,
            public.os_product_identifiers,
            public.os_manufacturer_role,
            public.os_product_manufacturer,
            public.os_regulatory_records
            FROM origen_admin';
    END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- Comprobaciones posteriores (solo lectura)
-- ---------------------------------------------------------------------------
SELECT '=== Fase 6 · tablas nuevas vacías ===' AS seccion;
SELECT 'os_concept' AS tabla, count(*) AS filas FROM os_concept
UNION ALL SELECT 'os_product', count(*) FROM os_product
UNION ALL SELECT 'os_product_presentation', count(*) FROM os_product_presentation
UNION ALL SELECT 'os_product_identifiers', count(*) FROM os_product_identifiers
UNION ALL SELECT 'os_regulatory_records', count(*) FROM os_regulatory_records;

SELECT '=== Fase 6 · catálogos de tipos semilla ===' AS seccion;
SELECT code FROM os_product_identifier_type ORDER BY code;
SELECT code FROM os_manufacturer_role ORDER BY code;

-- Fin de Fase 6 (§16) · productos, presentaciones e identificadores.
