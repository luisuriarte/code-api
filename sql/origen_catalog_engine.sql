-- =============================================================================
-- Origen Salud · Origen Catalog Engine 1.0 (PostgreSQL 18 Architecture)
-- Archivo unificado de esquemas, catálogos, aranceles, mapeos y vademécum
-- =============================================================================
SET client_encoding = 'UTF8';
SET statement_timeout = 0;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================================================
-- 1. TABLAS NUCLEARES DE CATÁLOGOS (os_catalog_*)
-- =============================================================================
CREATE TABLE IF NOT EXISTS os_catalog (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    organization VARCHAR(150) NOT NULL,
    country_code VARCHAR(2) NOT NULL DEFAULT 'AR',
    domain_type VARCHAR(30) NOT NULL CHECK (domain_type IN ('dental', 'medical', 'biochemical', 'rehabilitation', 'mental_health', 'pharma', 'terminology')),
    description TEXT,
    website_url VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS os_catalog_release (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    version_tag VARCHAR(50) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    official_norm_reference TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'review', 'published', 'deprecated')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (catalog_id, version_tag)
);

CREATE TABLE IF NOT EXISTS os_catalog_category (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    parent_category_id INT REFERENCES os_catalog_category(id) ON DELETE SET NULL,
    UNIQUE (catalog_id, code)
);

CREATE TABLE IF NOT EXISTS os_catalog_item (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    permanent_code VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'retired', 'superseded')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (catalog_id, permanent_code)
);

CREATE TABLE IF NOT EXISTS os_catalog_item_version (
    id SERIAL PRIMARY KEY,
    item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    release_id INT NOT NULL REFERENCES os_catalog_release(id) ON DELETE CASCADE,
    category_id INT REFERENCES os_catalog_category(id) ON DELETE SET NULL,
    preferred_term VARCHAR(255) NOT NULL,
    definition TEXT,
    clinical_criteria TEXT,
    language_code VARCHAR(10) NOT NULL DEFAULT 'es-AR',
    UNIQUE (item_id, release_id, language_code)
);

CREATE TABLE IF NOT EXISTS os_catalog_term (
    id SERIAL PRIMARY KEY,
    item_version_id INT NOT NULL REFERENCES os_catalog_item_version(id) ON DELETE CASCADE,
    term VARCHAR(255) NOT NULL,
    term_type VARCHAR(20) NOT NULL DEFAULT 'synonym' CHECK (term_type IN ('preferred', 'synonym', 'acronym', 'search_variant')),
    language_code VARCHAR(10) NOT NULL DEFAULT 'es-AR'
);

CREATE TABLE IF NOT EXISTS os_catalog_identifier (
    id SERIAL PRIMARY KEY,
    item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    system_name VARCHAR(50) NOT NULL,
    value VARCHAR(50) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (item_id, system_name, value)
);

CREATE INDEX IF NOT EXISTS idx_os_catalog_code ON os_catalog(code);
CREATE INDEX IF NOT EXISTS idx_os_item_perm ON os_catalog_item(catalog_id, permanent_code);
CREATE INDEX IF NOT EXISTS idx_os_item_ver_trgm ON os_catalog_item_version USING gin (preferred_term gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_os_term_trgm ON os_catalog_term USING gin (term gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_os_identifier_val ON os_catalog_identifier(value);


-- =============================================================================
-- 2. TABLAS DE INTEROPERABILIDAD Y MAPEOS (os_terminology_*, os_mapping_*)
-- =============================================================================
CREATE TABLE IF NOT EXISTS os_terminology_system (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    uri VARCHAR(255) NOT NULL,
    default_version VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS os_concept_mapping (
    id SERIAL PRIMARY KEY,
    item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    terminology_system_id INT NOT NULL REFERENCES os_terminology_system(id) ON DELETE CASCADE,
    external_code VARCHAR(50) NOT NULL,
    external_display VARCHAR(255) NOT NULL,
    mapping_type VARCHAR(30) NOT NULL DEFAULT 'equivalent'
        CHECK (mapping_type IN ('equivalent', 'narrower', 'broader', 'related', 'unmatched')),
    relationship_role VARCHAR(30) NOT NULL DEFAULT 'procedure_concept'
        CHECK (relationship_role IN ('procedure_concept', 'justifying_diagnosis', 'observation_concept', 'substance_concept')),
    clinical_rationale TEXT,
    review_status VARCHAR(20) NOT NULL DEFAULT 'approved' CHECK (review_status IN ('draft', 'reviewed', 'approved', 'deprecated')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (item_id, terminology_system_id, external_code, relationship_role)
);

CREATE INDEX IF NOT EXISTS idx_os_mapping_ext ON os_concept_mapping(external_code);
CREATE INDEX IF NOT EXISTS idx_os_mapping_item ON os_concept_mapping(item_id, relationship_role);


-- =============================================================================
-- 3. TABLAS DE ARANCELES Y VALORIZACIÓN (os_pricing_*, os_fee_*)
-- =============================================================================
CREATE TABLE IF NOT EXISTS os_pricing_unit (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    organization VARCHAR(100),
    description TEXT
);

CREATE TABLE IF NOT EXISTS os_fee_schedule (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    currency VARCHAR(5) NOT NULL DEFAULT 'ARS',
    unit_monetary_value NUMERIC(12, 4),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (catalog_id, name)
);

CREATE TABLE IF NOT EXISTS os_fee_item (
    id SERIAL PRIMARY KEY,
    fee_schedule_id INT NOT NULL REFERENCES os_fee_schedule(id) ON DELETE CASCADE,
    item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    pricing_unit_id INT NOT NULL REFERENCES os_pricing_unit(id),
    units_amount NUMERIC(12, 4) NOT NULL DEFAULT 1.0,
    fixed_price NUMERIC(12, 4),
    expenses_amount NUMERIC(12, 4) DEFAULT 0.0,
    UNIQUE (fee_schedule_id, item_id)
);


-- =============================================================================
-- 4. TABLAS DE FARMACIA Y VADEMÉCUM (os_pharma_*)
-- =============================================================================
CREATE TABLE IF NOT EXISTS os_substance (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    atc_code VARCHAR(10),
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS os_medicinal_product (
    id SERIAL PRIMARY KEY,
    substance_id INT NOT NULL REFERENCES os_substance(id) ON DELETE CASCADE,
    brand_name VARCHAR(255) NOT NULL,
    laboratory VARCHAR(150) NOT NULL,
    pharmacological_action VARCHAR(200),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (brand_name, laboratory)
);

CREATE TABLE IF NOT EXISTS os_product_package (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES os_medicinal_product(id) ON DELETE CASCADE,
    presentation_text VARCHAR(255) NOT NULL,
    dosage_form VARCHAR(100),
    sale_type VARCHAR(50) NOT NULL DEFAULT 'Venta Bajo Receta'
        CHECK (sale_type IN ('Venta Libre', 'Venta Bajo Receta', 'Archivada', 'Decreto')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (product_id, presentation_text)
);

CREATE TABLE IF NOT EXISTS os_product_identifier (
    id SERIAL PRIMARY KEY,
    package_id INT NOT NULL REFERENCES os_product_package(id) ON DELETE CASCADE,
    system_code VARCHAR(30) NOT NULL,
    identifier_value VARCHAR(50) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (system_code, identifier_value)
);

CREATE INDEX IF NOT EXISTS idx_os_substance_trgm ON os_substance USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_os_product_brand ON os_medicinal_product USING gin (brand_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_os_prod_ident ON os_product_identifier(system_code, identifier_value);


-- =============================================================================
-- 5. POBLADO: SISTEMAS TERMINOLÓGICOS Y UNIDADES
-- =============================================================================
INSERT INTO os_terminology_system (id, code, name, uri) VALUES
(1, 'SNOMED-CT', 'SNOMED Clinical Terms (Edición Argentina)', 'http://snomed.info/sct'),
(2, 'CIE-10', 'Clasificación Internacional de Enfermedades 10ª Rev.', 'http://hl7.org/fhir/sid/icd-10'),
(3, 'LOINC', 'Logical Observation Identifiers Names and Codes', 'http://loinc.org'),
(4, 'CDT-2025', 'Code on Dental Procedures and Nomenclature 2025', 'http://www.ada.org/cdt')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, uri = EXCLUDED.uri;

INSERT INTO os_pricing_unit (code, name, organization, description) VALUES
('UB', 'Unidad Bioquímica', 'CUBRA', 'Unidad de valorización arancelaria de análisis clínicos'),
('GALENO', 'Galeno Médico / Quirúrgico', 'MSAL', 'Unidad arancelaria histórica del Nomenclador Nacional'),
('MODULO', 'Módulo Prestacional', 'MSAL / ANDIS', 'Paquete cerrado de cobertura integral'),
('SESION', 'Sesión Terapéutica', 'Colegios Profesionales', 'Arancel por sesión de kinesiología o psicología'),
('PESOS', 'Pesos Argentinos', 'MSAL / NHPGD', 'Arancel fijado directamente en moneda de curso legal'),
('KM', 'Kilómetro Recorrido', 'ANDIS', 'Valor por kilómetro de transporte especial')
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 6. POBLADO: REGISTRO DE LOS 7 CATÁLOGOS CENTRALES
-- =============================================================================
INSERT INTO os_catalog (code, name, organization, country_code, domain_type, description) VALUES
('dentar', 'Sistema DENTAR - Ontología Odontológica Argentina y Latinoamericana', 'Origen Salud / Comité Odontológico', 'AR', 'dental', 'Catálogo odontológico central armonizado con ADA CDT 2025, Nomenclador Argentino y CIE-10.'),
('nn-pmo', 'Nomenclador Nacional de Prestaciones Médicas y Sanatoriales', 'Ministerio de Salud de la Nación', 'AR', 'medical', 'Estándar histórico para consultas médicas, cirugías, internaciones y base del PMO.'),
('nbu', 'Nomenclador Bioquímico Único', 'Confederación Unificada Bioquímica de la República Argentina (CUBRA)', 'AR', 'biochemical', 'Catálogo nacional de análisis clínicos con cálculo de Unidades Bioquímicas (UB).'),
('nhpgd', 'Nomenclador de Hospitales Públicos de Gestión Descentralizada', 'Ministerio de Salud de la Nación', 'AR', 'medical', 'Nomenclador para recupero de costos hospitalarios a obras sociales y prepagas.'),
('andis', 'Nomenclador de Prestaciones Básicas para Personas con Discapacidad', 'Agencia Nacional de Discapacidad', 'AR', 'rehabilitation', 'Aranceles regulados para rehabilitación, centros de día, transporte y apoyo escolar.'),
('kinesiologia', 'Nomenclador de Kinesiología y Fisiatría', 'Colegios y Asociaciones de Kinesiólogos', 'AR', 'rehabilitation', 'Codificación arancelaria para fisioterapia, kinesiología motriz y respiratoria.'),
('salud-mental', 'Nomenclador de Psicología y Salud Mental', 'Colegios de Psicólogos y Asociaciones de Psiquiatría', 'AR', 'mental_health', 'Prestaciones de psicoterapia individual, familiar, evaluaciones y peritajes.')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Releases 2026 oficiales para todos los catálogos
INSERT INTO os_catalog_release (catalog_id, version_tag, valid_from, official_norm_reference)
SELECT id, '2026-v1', '2026-01-01', 'Vigencia oficial 2026' FROM os_catalog
ON CONFLICT (catalog_id, version_tag) DO NOTHING;

-- Cuadros Arancelarios 2026 para todos los catálogos
INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Arancel Ético DENTAR 2026', '2026-01-01', 'ARS', 1.0 FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Nomenclador Nacional Base 2026', '2026-01-01', 'ARS', 12000.0 FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Arancel CUBRA NBU 2026', '2026-01-01', 'ARS', 3500.0 FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Arancel NHPGD Resolución MSAL 2026', '2026-01-01', 'ARS', 1.0 FROM os_catalog WHERE code = 'nhpgd'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Nomenclador Arancelario ANDIS 2026', '2026-01-01', 'ARS', 1.0 FROM os_catalog WHERE code = 'andis'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Arancel Colegiado Kinesiología 2026', '2026-01-01', 'ARS', 1.0 FROM os_catalog WHERE code = 'kinesiologia'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Arancel Referencial Psicología 2026', '2026-01-01', 'ARS', 1.0 FROM os_catalog WHERE code = 'salud-mental'
ON CONFLICT (catalog_id, name) DO NOTHING;


-- Categorías DENTAR
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, 'CAT-DIAG', E'Capítulo I - Consultas y Diagnóstico' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, 'CAT-REST', E'Capítulo II - Operatoria Dental y Restauradora' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, 'CAT-ENDO', E'Capítulo III - Endodoncia' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, 'CAT-SURG', E'Capítulo IV - Cirugía Bucomaxilofacial Menor' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, 'CAT-PROSTH-R', E'Capítulo V - Prótesis Removible' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, 'CAT-PROSTH-F', E'Capítulo VI - Prótesis Fija' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, 'CAT-PERI', E'Capítulo VII - Periodoncia' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, 'CAT-ORTHO', E'Capítulo VIII - Ortodoncia y Ortopedia Funcional' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, 'CAT-IMPL', E'Capítulo IX - Implantología Oral' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, 'CAT-SURG-MAX', E'Capítulo X - Cirugía Bucomaxilofacial Mayor' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, 'CAT-ADJ', E'Capítulo XI - Prestaciones Generales y Urgencias' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;

-- Ingesta de las 138 Prestaciones DENTAR
-- DNT-000001 :: 01.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000001', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Examen-Diagnóstico-Fichado y plan de tratamiento', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-DIAG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000001'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000001'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D0150', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000001'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000001'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000002 :: 01.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000002', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Consulta nocturna-Domingo y feriado (urgencias)', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-DIAG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000002'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '01.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000002'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D0120', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000002'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000002'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000003 :: 01.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000003', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Visitas a domicilio', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-DIAG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000003'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '01.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000003'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D0120', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000003'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000003'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000004 :: 01.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000004', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Consultas de urgencia, prestación que no constituya paso intermedio de tratamiento.', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-DIAG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000004'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '01.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000004'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D0120', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000004'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000004'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000005 :: 01.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000005', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Consulta de estomatología (sólo para especialistas)', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-DIAG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000005'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '01.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000005'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D0120', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000005'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000005'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000006 :: 01.06
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000006', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Consulta preventiva periódica', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-DIAG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000006'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '01.06', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000006'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D0120', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000006'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000006'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000007 :: 01.07
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000007', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Bonos otras Obras Sociales', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-DIAG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000007'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '01.07', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000007'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D0120', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000007'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000007'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000008 :: 02.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000008', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Obturación con amalgama: cavidad simple', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000008'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000008'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000008'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000008'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000009 :: 02.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000009', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Obturación con amalgama: cavidad compuesta', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000009'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000009'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2150', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000009'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000009'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000010 :: 02.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000010', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Obturación con amalgama: cavidad compleja', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000010'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000010'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2160', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000010'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000010'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000011 :: 02.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000011', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Obturación con amalgama: reconstrucción con tornillo en conducto', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000011'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000011'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2160', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000011'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000011'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000012 :: 02.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000012', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Obturación Estética - Cavidad simple', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000012'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000012'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2999', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000012'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000012'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000013 :: 02.06
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000013', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Obturación Estética- Cavidad compuesta o Compuesta', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000013'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.06', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000013'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2999', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000013'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000013'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000014 :: 02.08
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000014', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Obturación resina fotocurado sector Anterior y Posterior', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000014'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.08', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000014'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2332', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000014'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000014'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000015 :: 02.09
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000015', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Reconstrucción de ángulo en dientes anteriores', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000015'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.09', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000015'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2999', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000015'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000015'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000016 :: 02.10
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000016', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Obturación resina fotocurado sector Posterior', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000016'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.10', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000016'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2332', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000016'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000016'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000017 :: 02.15
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000017', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Composite simple ( incluye fotocurado )', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000017'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.15', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000017'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2330', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000017'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000017'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000018 :: 02.16
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000018', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Composite compuesto ( incluye fotocurado )', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000018'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.16', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000018'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2332', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000018'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000018'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000019 :: 02.17
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000019', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Composite compuesto con tornillo en conducto', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000019'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.17', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000019'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2332', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000019'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000019'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000020 :: 02.15 F
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000020', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Ferulización por causas periodontales', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-REST'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000020'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '02.15 F', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000020'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D2999', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000020'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000020'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000021 :: 03.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000021', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tratamiento de un conducto', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ENDO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000021'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '03.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000021'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D3999', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000021'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000021'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000022 :: 03.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000022', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tratamiento de dos conductos', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ENDO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000022'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '03.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000022'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D3999', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000022'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000022'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000023 :: 03.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000023', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tratamiento de tres conductos', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ENDO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000023'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '03.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000023'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D3999', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000023'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000023'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000024 :: 03.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000024', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tratamiento de cuatro conductos', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ENDO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000024'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '03.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000024'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D3999', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000024'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000024'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000025 :: 03.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000025', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Biopulpectomía parcial', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ENDO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000025'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '03.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000025'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D3999', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000025'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000025'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000026 :: 03.06
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000026', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Necropulpectomía parcial ( momificación )', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ENDO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000026'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '03.06', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000026'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D3999', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000026'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000026'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000027 :: 04.01.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000027', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Incrustaciones:  cavidad simple', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000027'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000027'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000027'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000027'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000028 :: 04.01.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000028', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Incrustaciones: cavidad compuesta o compleja', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000028'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000028'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000028'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000028'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000029 :: 04.01.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000029', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corona forjada', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000029'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000029'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000029'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000029'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000030 :: 04.01.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000030', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corona colada', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000030'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000030'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000030'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000030'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000031 :: 04.01.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000031', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corona colada con frente estético', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000031'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000031'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000031'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000031'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000032 :: 04.01.06
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000032', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corona espiga', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000032'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.06', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000032'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000032'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000032'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000033 :: 04.01.07
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000033', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corona colada revestida en acrílico', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000033'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.07', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000033'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000033'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000033'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000034 :: 04.01.07 bis
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000034', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corona colada revestida en porcelana', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000034'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.07 bis', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000034'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000034'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000034'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000035 :: 04.01.07 bis i
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000035', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corona colada revestida en porcelana sobre implante', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000035'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.07 bis i', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000035'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000035'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000035'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000036 :: 04.01.08
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000036', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Perno muñón simple', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000036'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.08', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000036'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000036'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000036'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000037 :: 04.01.08 i
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000037', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Emergente o intermediario sobre implantes', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000037'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.08 i', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000037'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000037'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000037'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000038 :: 04.01.09
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000038', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Perno muñon seccionado', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000038'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.09', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000038'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000038'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000038'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000039 :: 04.01.10
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000039', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tramo de puente colado', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000039'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.10', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000039'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000039'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000039'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000040 :: 04.01.10 bis
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000040', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tramo puente colado ( porcelana )', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000040'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.10 bis', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000040'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000040'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000040'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000041 :: 04.01.11
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000041', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corona de acrílico', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000041'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.11', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000041'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000041'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000041'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000042 :: 04.01.12
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000042', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corona provisoria', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000042'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.12', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000042'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000042'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000042'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000043 :: 04.01.12 i
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000043', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corona provisoria sobre implantes', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000043'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.12 i', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000043'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000043'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000043'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000044 :: 04.01.15
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000044', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Ataches', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000044'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.15', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000044'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000044'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000044'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000045 :: 04.01.16
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000045', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Poste bola', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000045'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.16', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000045'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000045'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000045'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000046 :: 04.01.17
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000046', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Barra tangencial tipo Dolder', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000046'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.01.17', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000046'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000046'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000046'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000047 :: 04.02.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000047', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'De acrílico: hasta cuatro dientes', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000047'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.02.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000047'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000047'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000047'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000048 :: 04.02.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000048', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'De acrílico: de cinco o más dientes', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000048'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.02.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000048'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000048'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000048'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000049 :: 04.02.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000049', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Cromo cobalto: hasta cuatro dientes', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000049'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.02.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000049'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000049'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000049'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000050 :: 04.02.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000050', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Cromo cobalto: de cinco o más dientes', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000050'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.02.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000050'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000050'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000050'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000051 :: 04.02.04 i
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000051', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Cromo cobalto sobre implantes', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000051'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.02.04 i', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000051'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000051'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000051'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000052 :: 04.02.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000052', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Prótesis parcial inmediata ( temporaria )', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000052'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.02.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000052'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000052'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000052'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000053 :: 04.02.05 i
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000053', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Prótesis parcial inmediata ( temporaria ) sobre implantes', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000053'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.02.05 i', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000053'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000053'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000053'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000054 :: 04.03.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000054', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Superior', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000054'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.03.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000054'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000054'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000054'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000055 :: 04.03.01 i
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000055', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Superior sobre implantes', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000055'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.03.01 i', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000055'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000055'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000055'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000056 :: 04.03.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000056', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Inferior', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000056'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.03.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000056'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000056'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000056'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000057 :: 04.03.02 i
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000057', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Inferior sobre implantes', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000057'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.03.02 i', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000057'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000057'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000057'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000058 :: 04.03.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000058', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Prótesis completa inmediata ( temporaria )', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000058'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.03.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000058'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000058'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000058'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000059 :: 04.03.03 i
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000059', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Prótesis completa inmediata sobre implantes ( temporaria )', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000059'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.03.03 i', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000059'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000059'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000059'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000060 :: 04.04.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000060', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Compostura simple', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000060'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000060'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000060'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000060'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000061 :: 04.04.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000061', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Compostura con agregado de un diente', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000061'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000061'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000061'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000061'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000062 :: 04.04.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000062', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Compostura con agregado de un retenedor', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000062'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000062'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000062'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000062'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000063 :: 04.04.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000063', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Compostura simple con agregado de un diente y un retenedor', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000063'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000063'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000063'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000063'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000064 :: 04.04.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000064', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Diente subsiguiente, c/u', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000064'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000064'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000064'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000064'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000065 :: 04.04.06
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000065', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Retenedor subsiguiente, c/u', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000065'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.06', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000065'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000065'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000065'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000066 :: 04.04.07
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000066', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Soldado de retención en aparatos de cromo', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000066'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.07', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000066'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000066'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000066'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000067 :: 04.04.08
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000067', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Retención subsiguiente', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000067'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.08', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000067'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000067'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000067'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000068 :: 04.04.09
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000068', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Carilla de acrílico', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000068'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.09', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000068'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000068'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000068'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000069 :: 04.04.10
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000069', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Rebasado de prótesis, c/u', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000069'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.10', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000069'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000069'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000069'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000070 :: 04.04.11
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000070', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Cubeta individual', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000070'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.11', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000070'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000070'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000070'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000071 :: 04.04.12
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000071', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Levante de articulación, en acrílico traslucido y retenedores forjados en acero.', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000071'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '04.04.12', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000071'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7140', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000071'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000071'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000072 :: 05.00
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000072', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Ficha de prevención.', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-R'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000072'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '05.00', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000072'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D5110', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000072'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000072'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000073 :: 05.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000073', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tartrectomía y cepillado mecánico', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-R'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000073'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '05.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000073'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D5110', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000073'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000073'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000074 :: 05.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000074', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Aplicación de fluor, incluye cepillado previo y tartrectomía', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-R'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000074'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '05.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000074'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D5110', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000074'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000074'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000075 :: 05.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000075', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Detección de placa bacteriana y test de susceptibilidad de caries', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-R'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000075'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '05.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000075'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D5110', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000075'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000075'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000076 :: 05.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000076', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Enseñanzas de técnicas de higiene bucal.Incluye control de placa y test de suscep.', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-R'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000076'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '05.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000076'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D5110', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000076'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000076'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000077 :: 05.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000077', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Sellantes de puntos y fisuras', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-R'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000077'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '05.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000077'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D5110', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000077'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000077'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000078 :: 05.06
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000078', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Aplicación de cariostáticos en piezas dentarias permanentes', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-R'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000078'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '05.06', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000078'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D5110', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000078'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000078'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000079 :: 06.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000079', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Consulta de estudio', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-F'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000079'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '06.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000079'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6240', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000079'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000079'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000080 :: 06.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000080', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tratamiento de la dentición primaria o mixta *', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-F'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000080'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '06.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000080'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6240', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000080'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000080'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000081 :: 06.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000081', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tratamiento de la dentición permanente *', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-F'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000081'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '06.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000081'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6240', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000081'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000081'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000082 :: 06.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000082', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corrección de malposiciones simples con espacio', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-F'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000082'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '06.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000082'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6240', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000082'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000082'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000083 :: 06.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000083', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tratamiento de la dentición permanente: hemi - arcada.', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PROSTH-F'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000083'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '06.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000083'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6240', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000083'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000083'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000084 :: 07.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000084', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Motivación ( hasta 3 consultas ) Incluye 1ra y ficha hasta 13 años', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PERI'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000084'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '07.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000084'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D4341', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000084'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000084'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000085 :: 07.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000085', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Mantenedor de espacio fijo', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PERI'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000085'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '07.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000085'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D4341', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000085'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000085'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000086 :: 07.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000086', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Mantenedor de espacio removible', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PERI'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000086'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '07.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000086'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D4341', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000086'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000086'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000087 :: 07.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000087', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tratamiento de dientes primarios con formocresol', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PERI'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000087'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '07.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000087'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D4341', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000087'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000087'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000088 :: 07.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000088', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Corona de acero y similares', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PERI'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000088'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '07.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000088'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D4341', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000088'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000088'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000089 :: 07.06.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000089', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Reducción de luxación con inmovilización dentaria', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PERI'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000089'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '07.06.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000089'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D4341', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000089'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000089'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000090 :: 07.06.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000090', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Luxación total ( reimplante ) o inmovilización dentaria', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PERI'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000090'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '07.06.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000090'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D4341', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000090'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000090'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000091 :: 07.06.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000091', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Fractura amelodentinaria, protección pulpar con coronas provisorias', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PERI'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000091'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '07.06.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000091'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D4341', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000091'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000091'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000092 :: 07.07
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000092', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Protección pulpar directa', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PERI'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000092'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '07.07', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000092'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D4341', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000092'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000092'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000093 :: 07.08
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000093', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Aplicación de cariostáticos', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-PERI'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000093'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '07.08', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000093'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D4341', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000093'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000093'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000094 :: 08.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000094', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Consulta de estudio-Diagnóstico-Pronóstico', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ORTHO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000094'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '08.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000094'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D8080', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000094'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000094'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000095 :: 08.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000095', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tratamiento de gingivitis, marginal crónica', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ORTHO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000095'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '08.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000095'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D8080', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000095'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000095'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000096 :: 08.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000096', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Trat. periodontitis destructiva leve o mod. Bolsas hasta  5mm por sector (6 sec)', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ORTHO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000096'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '08.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000096'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D8080', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000096'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000096'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000097 :: 08.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000097', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Trat. periodontitis destructiva severa. Bolsas de 6mm o más. Por sector (6 sec)', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ORTHO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000097'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '08.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000097'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D8080', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000097'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000097'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000098 :: 08.04 C
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000098', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Cirugía Periodontal', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ORTHO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000098'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '08.04 C', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000098'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D8080', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000098'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000098'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000099 :: 08.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000099', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Desgaste selectivo o armonización oclusal', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ORTHO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000099'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '08.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000099'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D8080', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000099'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000099'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000100 :: 08.05.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000100', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'ATM. y bruxismo, terapia farmacológica y fisioterapia.', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ORTHO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000100'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '08.05.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000100'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D8080', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000100'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000100'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000101 :: 08.05.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000101', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Aparato de estabilización oclusal y en relación céntrica.', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ORTHO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '08.05.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D8080', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000102 :: 08.05.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000102', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Aparato oclusal pivotante.', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ORTHO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000102'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '08.05.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D8080', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000102'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000102'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000103 :: 08.06
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000103', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Placas oclusales ( temporarias ) removibles de acrílico, cualquier tipo', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ORTHO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000103'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '08.06', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000103'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D8080', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000103'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000103'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000104 :: 08.07
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000104', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Mantenimiento de tratamiento periodontal', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ORTHO'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000104'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '08.07', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000104'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D8080', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000104'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000104'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000105 :: 09.01.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000105', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Periapical, técnicas de cono corto o cono largo', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000105'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000105'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000105'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000105'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000106 :: 09.01.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000106', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Bite-Wing', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000106'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.01.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000106'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000106'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000106'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000107 :: 09.01.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000107', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Oclusal de 6 x 8 cm.', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000107'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.01.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000107'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000107'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000107'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000108 :: 09.01.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000108', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Media seriada: 7 películas- Técnicas de cono corto o largo', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000108'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.01.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000108'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000108'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000108'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000109 :: 09.01.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000109', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Seriada de 14 péliculas- técnicas de cono corto o largo', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000109'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.01.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000109'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000109'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000109'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000110 :: 09.02.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000110', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Extraorales: primera exposición', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000110'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.02.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000110'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000110'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000110'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000111 :: 09.02.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000111', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Extraorales: por exposición subsiguiente', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000111'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.02.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000111'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000111'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000111'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000112 :: 09.02.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000112', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Articulación Temporo-maxilar ( 6 tomas )', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000112'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.02.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000112'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000112'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000112'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000113 :: 09.02.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000113', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Pantomografía ( radiografícas panorámicas )', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000113'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.02.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000113'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000113'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000113'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000114 :: 09.02.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000114', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Telerradiografía cefalométrica', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000114'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.02.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000114'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000114'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000114'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000115 :: 09.02.05 bis
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000115', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Estudio o trazado cefalométrico', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000115'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.02.05 bis', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000115'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000115'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000115'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000116 :: 09.02.06
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000116', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Sialografía', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-IMPL'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000116'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '09.02.06', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000116'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D6010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000116'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000116'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000117 :: 10.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000117', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Extracción dentaria', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000117'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000117'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000117'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000117'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000118 :: 10.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000118', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Plástica de comunicación buco-sinusal como riesgo previsto simultáneo a la extracción', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000118'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000118'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000118'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000118'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000119 :: 10.03
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000119', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Biopsia por punción o aspiración', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000119'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000119'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000119'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000119'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000120 :: 10.04
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000120', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Alveolectomia estabilizadora ( 6 zonas ): por zona', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000120'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000120'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000120'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000120'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000121 :: 10.05
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000121', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Reimplante dentario inmediato al traumatismo', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000121'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000121'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000121'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000121'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000122 :: 10.06
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000122', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Incisión y drenaje de abscesos por via intrabucal', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000122'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.06', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000122'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000122'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000122'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000123 :: 10.07
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000123', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Biopsia por escisión', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000123'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.07', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000123'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000123'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000123'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000124 :: 10.08
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000124', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Alargamiento quirúrgico de la corona clínica', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000124'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.08', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000124'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000124'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000124'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000125 :: 10.09
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000125', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Extracción de dientes retenidos o restos radiculares retenidos', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000125'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.09', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000125'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000125'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000125'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000126 :: 10.10
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000126', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Germectomía', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000126'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.10', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000126'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000126'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000126'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000127 :: 10.11
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000127', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Libreración de dientes retenidos', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000127'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.11', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000127'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000127'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000127'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000128 :: 10.12
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000128', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Apicectomía', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000128'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.12', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000128'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000128'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000128'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000129 :: 10.13
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000129', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Tratamiento de osteomielitis', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000129'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.13', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000129'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000129'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000129'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000130 :: 10.14
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000130', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Extracción de cuerpo extraño', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000130'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.14', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000130'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000130'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000130'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000131 :: 10.15
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000131', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Alveolectomía correctiva( 6 zonas ): por zona', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000131'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.15', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000131'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000131'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000131'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000132 :: 10.16
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000132', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Frenectomía', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000132'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.16', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000132'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000132'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000132'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000133 :: 10.17
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000133', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Radectomía', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000133'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.17', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000133'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000133'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000133'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000134 :: 10.18
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000134', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Extracción por alveolectomía externa (complicación de extracción).', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000134'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.18', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000134'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000134'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000134'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000135 :: 10.19
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000135', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Extracción de dientes en retención ósea.', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000135'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.19', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000135'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000135'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000135'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000136 :: 10.20
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000136', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Sutura de encías como tratamiento de lesión traumática.', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG-MAX'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000136'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '10.20', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000136'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D7210', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000136'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000136'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000137 :: 11.01.01
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000137', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Implante dentario', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ADJ'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000137'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '11.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000137'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D9110', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000137'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000137'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- DNT-000138 :: 11.02
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'DNT-000138', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, E'Relleno óseo', 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-ADJ'
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000138'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '11.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000138'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, 'D9110', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000138'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000138'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;


-- Justificaciones Diagnósticas CIE-10 para Operatoria DENTAR
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role, clinical_rationale)
SELECT i.id, 2, 'K02.1', 'Caries de la dentina', 'equivalent', 'justifying_diagnosis', 'Caries activa con cavitación dentinaria que justifica restauración'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code IN ('DNT-000007', 'DNT-000008', 'DNT-000009', 'DNT-000010', 'DNT-000011', 'DNT-000012')
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Justificaciones Diagnósticas CIE-10 para Endodoncia DENTAR
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role, clinical_rationale)
SELECT i.id, 2, 'K04.0', 'Pulpitis irreversible', 'equivalent', 'justifying_diagnosis', 'Inflamación pulpar irreversible que requiere tratamiento endodóntico'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code IN ('DNT-000017', 'DNT-000018', 'DNT-000019', 'DNT-000020')
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Justificaciones Diagnósticas CIE-10 para Periodoncia DENTAR
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role, clinical_rationale)
SELECT i.id, 2, 'K05.3', 'Periodontitis crónica', 'equivalent', 'justifying_diagnosis', 'Pérdida ósea y bolsas periodontales que requieren raspado y alisado radicular'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code IN ('DNT-000049', 'DNT-000050', 'DNT-000051')
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- =============================================================================
-- 7. INGESTA: NOMENCLADOR NACIONAL MÉDICO / PMO (nn-pmo) (11 ITEMS)
-- =============================================================================

-- Item NN-420101 (42.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NN-420101', 'active' FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Consulta médica general o especializada en consultorio', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '42.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '420101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '185349003', E'Consulta médica ambulatoria (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420101' AND f.name = 'Nomenclador Nacional Base 2026' AND u.code = 'GALENO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NN-420102 (42.01.02)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NN-420102', 'active' FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Consulta médica general o especializada en domicilio', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420102'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '42.01.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '420102', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '308439007', E'Visita médica a domicilio (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420102'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.5000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420102' AND f.name = 'Nomenclador Nacional Base 2026' AND u.code = 'GALENO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NN-430101 (43.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NN-430101', 'active' FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Consulta de guardia / urgencia médica', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-430101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '43.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-430101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '430101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-430101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '50849002', E'Atención de urgencia médica (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-430101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.2000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-430101' AND f.name = 'Nomenclador Nacional Base 2026' AND u.code = 'GALENO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NN-340101 (34.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NN-340101', 'active' FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Electrocardiograma de rutina (ECG) de 12 derivaciones con informe', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '34.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '340101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '268400002', E'Electrocardiograma de 12 derivaciones', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '11524-6', E'EKG study', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, NULL, 0.5000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340101' AND f.name = 'Nomenclador Nacional Base 2026' AND u.code = 'GALENO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NN-340105 (34.01.05)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NN-340105', 'active' FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Ergometría computarizada de 12 derivaciones / prueba de esfuerzo', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340105'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '34.01.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340105'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '340105', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340105'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '44734002', E'Prueba de esfuerzo cardiovascular', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340105'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '73788-2', E'Cardiac stress test', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340105'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 3.5000, NULL, 2.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-340105' AND f.name = 'Nomenclador Nacional Base 2026' AND u.code = 'GALENO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NN-170101 (17.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NN-170101', 'active' FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Apendicectomía por laparotomía o laparoscópica', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-170101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '17.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-170101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '170101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-170101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '80146002', E'Apendicectomía (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-170101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 18.0000, NULL, 12.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-170101' AND f.name = 'Nomenclador Nacional Base 2026' AND u.code = 'GALENO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NN-170112 (17.01.12)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NN-170112', 'active' FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Colecistectomía laparoscópica con colangiografía intraoperatoria', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-170112'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '17.01.12', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-170112'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '170112', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-170112'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '45595009', E'Colecistectomía laparoscópica (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-170112'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 24.0000, NULL, 16.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-170112' AND f.name = 'Nomenclador Nacional Base 2026' AND u.code = 'GALENO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NN-180101 (18.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NN-180101', 'active' FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Atención del parto vaginal en quirófano o sala de partos institucional', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-180101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '18.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-180101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '180101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-180101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '236973005', E'Parto vaginal normal (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-180101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 20.0000, NULL, 10.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-180101' AND f.name = 'Nomenclador Nacional Base 2026' AND u.code = 'GALENO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NN-180102 (18.01.02)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NN-180102', 'active' FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Operación cesárea con o sin histerectomía', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-180102'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '18.01.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-180102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '180102', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-180102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '11466000', E'Operación cesárea (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-180102'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 22.0000, NULL, 14.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-180102' AND f.name = 'Nomenclador Nacional Base 2026' AND u.code = 'GALENO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NN-400101 (40.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NN-400101', 'active' FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Día clínico de internación en sala general con atención de enfermería', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-400101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '40.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-400101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '400101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-400101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '32485007', E'Internación hospitalaria (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-400101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, NULL, 5.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-400101' AND f.name = 'Nomenclador Nacional Base 2026' AND u.code = 'MODULO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NN-400103 (40.01.03)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NN-400103', 'active' FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Día de internación en Unidad de Terapia Intensiva (UTI) polivalente', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-400103'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '40.01.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-400103'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '400103', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-400103'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '305351004', E'Cuidados intensivos en UTI (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-400103'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, NULL, 18.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-400103' AND f.name = 'Nomenclador Nacional Base 2026' AND u.code = 'MODULO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- =============================================================================
-- 8. INGESTA: NOMENCLADOR BIOQUÍMICO ÚNICO (nbu) (14 ITEMS)
-- =============================================================================

-- Item NBU-660475 (660475)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660475', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Hemograma completo (recuento de hematíes, leucocitos, fórmula leucocitaria, Hb y Hto)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660475'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660475', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660475'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '43789009', E'Recuento sanguíneo completo (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660475'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '58410-2', E'CBC panel - Blood by Automated count', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660475'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 3.8000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660475' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660370 (660370)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660370', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Glucemia en ayunas (determinación enzimática)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660370'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660370', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660370'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '67079006', E'Medición de glucosa en suero (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660370'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '1558-6', E'Fasting glucose [Mass/volume] in Serum or Plasma', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660370'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.8000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660370' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660855 (660855)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660855', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Uremia / urea en sangre por método cinético', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660855'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660855', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660855'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '26881000', E'Medición de urea en suero (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660855'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '3094-0', E'Urea nitrogen [Mass/volume] in Serum or Plasma', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660855'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.8000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660855' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660230 (660230)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660230', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Creatinina en sangre (índice de filtrado glomerular)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660230'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660230', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660230'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '27171005', E'Medición de creatinina en suero (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660230'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '2160-0', E'Creatinine [Mass/volume] in Serum or Plasma', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660230'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 2.0000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660230' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660180 (660180)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660180', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Colesterol total sérico enzimático', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660180'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660180', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660180'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '271062006', E'Medición de colesterol sérico total (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660180'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '2093-3', E'Cholesterol [Mass/volume] in Serum or Plasma', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660180'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 2.0000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660180' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660181 (660181)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660181', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Colesterol HDL (alta densidad)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660181'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660181', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660181'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '28036006', E'Medición de colesterol HDL (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660181'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '2085-9', E'Cholesterol in HDL [Mass/volume] in Serum or Plasma', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660181'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 2.5000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660181' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660182 (660182)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660182', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Colesterol LDL calculado o dosado', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660182'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660182', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660182'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '39689006', E'Medición de colesterol LDL (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660182'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '13457-7', E'Cholesterol in LDL [Mass/volume] in Serum or Plasma', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660182'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 2.5000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660182' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660810 (660810)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660810', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Triglicéridos séricos', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660810'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660810', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660810'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '14740000', E'Medición de triglicéridos séricos (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660810'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '2571-8', E'Triglyceride [Mass/volume] in Serum or Plasma', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660810'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 2.2000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660810' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660490 (660490)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660490', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Hepatograma completo (GOT, GPT, FAL, Bilirrubina total y fraccionada)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660490'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660490', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660490'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '24325000', E'Perfil hepático (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660490'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '24325-3', E'Hepatic function panel - Serum or Plasma', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660490'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 5.5000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660490' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660600 (660600)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660600', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Orina completa (examen físico, químico y sedimento urinario microscópico)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660600'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660600', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660600'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '27171005', E'Análisis de orina rutinario (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660600'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '24356-8', E'Urinalysis complete panel - Urine', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660600'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 2.2000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660600' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660835 (660835)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660835', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'TSH (Tirotrofina sérica por quimioluminiscencia ultrasensible)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660835'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660835', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660835'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '67174007', E'Medición de tirotropina sérica (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660835'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '3016-3', E'Thyrotropin [Units/volume] in Serum or Plasma', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660835'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 6.0000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660835' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660825 (660825)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660825', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'T4 libre (Tiroxina libre sérica)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660825'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660825', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660825'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '69566008', E'Medición de tiroxina libre (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660825'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '3024-7', E'Thyroxine (T4) free [Mass/volume] in Serum or Plasma', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660825'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 6.0000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660825' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660485 (660485)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660485', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Hemoglobina glicosilada (HbA1c por HPLC)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660485'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660485', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660485'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '43396009', E'Medición de hemoglobina A1c (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660485'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '4548-4', E'Hemoglobin A1c/Hemoglobin.total in Blood', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660485'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 5.0000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660485' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NBU-660500 (660500)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NBU-660500', 'active' FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Serología para VIH 1/2 (Anticuerpos + Antígeno p24 de 4ta generación)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660500'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '660500', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660500'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '104344004', E'Prueba de detección serológica de VIH (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660500'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '56888-1', E'HIV 1 and 2 tests - Serum or Plasma', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660500'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 7.5000, NULL, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660500' AND f.name = 'Arancel CUBRA NBU 2026' AND u.code = 'UB'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- =============================================================================
-- 9. INGESTA: HOSPITALES PÚBLICOS DE GESTIÓN DESCENTRALIZADA (nhpgd) (8 ITEMS)
-- =============================================================================

-- Item NHPGD-010101 (01.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NHPGD-010101', 'active' FROM os_catalog WHERE code = 'nhpgd'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Consulta médica ambulatoria en hospital público (primer nivel / guardia)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-010101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '01.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-010101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '010101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-010101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '185349003', E'Consulta médica ambulatoria (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-010101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 6500.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-010101' AND f.name = 'Arancel NHPGD Resolución MSAL 2026' AND u.code = 'PESOS'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NHPGD-010102 (01.01.02)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NHPGD-010102', 'active' FROM os_catalog WHERE code = 'nhpgd'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Consulta médica de especialidad / interconsulta hospitalaria', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-010102'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '01.01.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-010102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '010102', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-010102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '185349003', E'Consulta médica ambulatoria (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-010102'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 8200.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-010102' AND f.name = 'Arancel NHPGD Resolución MSAL 2026' AND u.code = 'PESOS'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NHPGD-020101 (02.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NHPGD-020101', 'active' FROM os_catalog WHERE code = 'nhpgd'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Consulta odontológica y atención de urgencia odontológica hospitalaria', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-020101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '02.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-020101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '020101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-020101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '424759004', E'Consulta odontológica (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-020101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 7800.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-020101' AND f.name = 'Arancel NHPGD Resolución MSAL 2026' AND u.code = 'PESOS'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NHPGD-030101 (03.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NHPGD-030101', 'active' FROM os_catalog WHERE code = 'nhpgd'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Día cama en sala de cuidados generales / internación clínica hospitalaria', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-030101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '03.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-030101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '030101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-030101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '32485007', E'Internación hospitalaria (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-030101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 38000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-030101' AND f.name = 'Arancel NHPGD Resolución MSAL 2026' AND u.code = 'PESOS'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NHPGD-030102 (03.01.02)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NHPGD-030102', 'active' FROM os_catalog WHERE code = 'nhpgd'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Día cama en Unidad de Cuidados Intensivos Pediátricos o Adultos (UTI)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-030102'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '03.01.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-030102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '030102', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-030102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '305351004', E'Cuidados intensivos en UTI (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-030102'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 125000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-030102' AND f.name = 'Arancel NHPGD Resolución MSAL 2026' AND u.code = 'PESOS'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NHPGD-040101 (04.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NHPGD-040101', 'active' FROM os_catalog WHERE code = 'nhpgd'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Atención integral del parto eutócico institucional y puerperio', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-040101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '04.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-040101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '040101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-040101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '236973005', E'Parto vaginal normal (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-040101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 145000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-040101' AND f.name = 'Arancel NHPGD Resolución MSAL 2026' AND u.code = 'PESOS'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NHPGD-040102 (04.01.02)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NHPGD-040102', 'active' FROM os_catalog WHERE code = 'nhpgd'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Operación cesárea programada o de urgencia y cuidados neonatales iniciales', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-040102'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '04.01.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-040102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '040102', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-040102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '11466000', E'Operación cesárea (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-040102'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 195000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-040102' AND f.name = 'Arancel NHPGD Resolución MSAL 2026' AND u.code = 'PESOS'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item NHPGD-050101 (05.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'NHPGD-050101', 'active' FROM os_catalog WHERE code = 'nhpgd'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Intervención quirúrgica en quirófano ambulatorio con anestesia local/regional', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-050101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '05.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-050101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '050101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-050101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '387713003', E'Procedimiento quirúrgico (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-050101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 62000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nhpgd' AND i.permanent_code = 'NHPGD-050101' AND f.name = 'Arancel NHPGD Resolución MSAL 2026' AND u.code = 'PESOS'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- =============================================================================
-- 10. INGESTA: PRESTACIONES PARA PERSONAS CON DISCAPACIDAD (andis) (9 ITEMS)
-- =============================================================================

-- Item ANDIS-250101 (250101)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'ANDIS-250101', 'active' FROM os_catalog WHERE code = 'andis'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Módulo de rehabilitación ambulatoria integral (kinesiología, terapia ocupacional, fonoaudiología)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '250101', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '386053000', E'Rehabilitación ambulatoria integral (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 85000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250101' AND f.name = 'Nomenclador Arancelario ANDIS 2026' AND u.code = 'MODULO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item ANDIS-250102 (250102)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'ANDIS-250102', 'active' FROM os_catalog WHERE code = 'andis'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Sesión individual de estimulación fonoaudiológica y rehabilitación de deglución/lenguaje', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250102'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '250102', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '284478002', E'Terapia del habla y del lenguaje (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250102'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 9200.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250102' AND f.name = 'Nomenclador Arancelario ANDIS 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item ANDIS-250103 (250103)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'ANDIS-250103', 'active' FROM os_catalog WHERE code = 'andis'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Sesión individual de psicopedagogía y apoyo escolar especializado', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250103'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '250103', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250103'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '76168009', E'Terapia psicopedagógica (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250103'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 9200.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250103' AND f.name = 'Nomenclador Arancelario ANDIS 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item ANDIS-250104 (250104)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'ANDIS-250104', 'active' FROM os_catalog WHERE code = 'andis'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Sesión de terapia ocupacional para desarrollo de autonomía y vida diaria', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250104'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '250104', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250104'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '385805005', E'Terapia ocupacional (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250104'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 9200.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250104' AND f.name = 'Nomenclador Arancelario ANDIS 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item ANDIS-250201 (250201)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'ANDIS-250201', 'active' FROM os_catalog WHERE code = 'andis'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Centro de Día - Jornada Simple (con alimentación y talleres adaptados)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250201'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '250201', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250201'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '310168007', E'Servicio de centro de día (régimen)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250201'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 210000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250201' AND f.name = 'Nomenclador Arancelario ANDIS 2026' AND u.code = 'MODULO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item ANDIS-250202 (250202)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'ANDIS-250202', 'active' FROM os_catalog WHERE code = 'andis'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Centro de Día - Jornada Doble (completa con talleres y actividades terapéuticas)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250202'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '250202', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250202'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '310168007', E'Servicio de centro de día (régimen)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250202'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 345000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250202' AND f.name = 'Nomenclador Arancelario ANDIS 2026' AND u.code = 'MODULO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item ANDIS-250301 (250301)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'ANDIS-250301', 'active' FROM os_catalog WHERE code = 'andis'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Módulo CET - Jornada Doble con abordaje multidisciplinario pedagógico y clínico', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250301'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '250301', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250301'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '386053000', E'Centro educativo terapéutico (régimen)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250301'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 380000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250301' AND f.name = 'Nomenclador Arancelario ANDIS 2026' AND u.code = 'MODULO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item ANDIS-250401 (250401)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'ANDIS-250401', 'active' FROM os_catalog WHERE code = 'andis'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Transporte especial para personas con discapacidad (arancel por kilómetro recorrido)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250401'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '250401', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250401'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '413294000', E'Transporte especial de paciente (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250401'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 520.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250401' AND f.name = 'Nomenclador Arancelario ANDIS 2026' AND u.code = 'KM'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item ANDIS-250501 (250501)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'ANDIS-250501', 'active' FROM os_catalog WHERE code = 'andis'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Acompañante de apoyo a la inclusión escolar (maestra/o de apoyo a la inclusión)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250501'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '250501', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250501'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '76168009', E'Apoyo a la inclusión educativa (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250501'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 190000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250501' AND f.name = 'Nomenclador Arancelario ANDIS 2026' AND u.code = 'MODULO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- =============================================================================
-- 11. INGESTA: KINESIOLOGÍA Y FISIATRÍA (kinesiologia) (6 ITEMS)
-- =============================================================================

-- Item KIN-250101 (25.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'KIN-250101', 'active' FROM os_catalog WHERE code = 'kinesiologia'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Sesión de fisioterapia y kinesiología motriz en consultorio (ejercicios, movilización)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '25.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '250101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '91251008', E'Terapia física (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 8500.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250101' AND f.name = 'Arancel Colegiado Kinesiología 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item KIN-250102 (25.01.02)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'KIN-250102', 'active' FROM os_catalog WHERE code = 'kinesiologia'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Sesión de fisioterapia y kinesiología motriz en domicilio del paciente', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250102'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '25.01.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '250102', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '91251008', E'Terapia física domiciliaria (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250102'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 12500.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250102' AND f.name = 'Arancel Colegiado Kinesiología 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item KIN-250103 (25.01.03)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'KIN-250103', 'active' FROM os_catalog WHERE code = 'kinesiologia'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Sesión de kinesiología respiratoria (drenaje postural, aspiración, ejercicios ventilatorios)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250103'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '25.01.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250103'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '250103', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250103'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '304526009', E'Terapia respiratoria (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250103'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 9500.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250103' AND f.name = 'Arancel Colegiado Kinesiología 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item KIN-250104 (25.01.04)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'KIN-250104', 'active' FROM os_catalog WHERE code = 'kinesiologia'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Aplicación de aparatología fisioterapéutica (magnetoterapia, ultrasonido, electroestimulación TENS)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250104'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '25.01.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250104'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '250104', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250104'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '91251008', E'Fisioterapia instrumental (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250104'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 6800.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250104' AND f.name = 'Arancel Colegiado Kinesiología 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item KIN-250105 (25.01.05)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'KIN-250105', 'active' FROM os_catalog WHERE code = 'kinesiologia'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Rehabilitación neuromuscular compleja (Bobath, Kabat, reeducación de la marcha)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250105'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '25.01.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250105'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '250105', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250105'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '91251008', E'Rehabilitación neuromuscular (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250105'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 14000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250105' AND f.name = 'Arancel Colegiado Kinesiología 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item KIN-250106 (25.01.06)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'KIN-250106', 'active' FROM os_catalog WHERE code = 'kinesiologia'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Drenaje linfático manual por miembro afectado (postquirúrgico / oncológico)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250106'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '25.01.06', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250106'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '250106', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250106'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '229562008', E'Drenaje linfático manual (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250106'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 11000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'kinesiologia' AND i.permanent_code = 'KIN-250106' AND f.name = 'Arancel Colegiado Kinesiología 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- =============================================================================
-- 12. INGESTA: PSICOLOGÍA Y SALUD MENTAL (salud-mental) (6 ITEMS)
-- =============================================================================

-- Item SM-330101 (33.01.01)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'SM-330101', 'active' FROM os_catalog WHERE code = 'salud-mental'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Sesión individual de psicoterapia en consultorio o teleconsulta (45-50 min)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330101'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '33.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '330101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330101'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '84114007', E'Psicoterapia individual (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330101'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 11500.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330101' AND f.name = 'Arancel Referencial Psicología 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item SM-330102 (33.01.02)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'SM-330102', 'active' FROM os_catalog WHERE code = 'salud-mental'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Sesión de psicoterapia de pareja o grupo familiar', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330102'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '33.01.02', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '330102', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330102'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '108313002', E'Psicoterapia familiar (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330102'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 16000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330102' AND f.name = 'Arancel Referencial Psicología 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item SM-330103 (33.01.03)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'SM-330103', 'active' FROM os_catalog WHERE code = 'salud-mental'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Sesión de psicoterapia grupal (hasta 8 pacientes)', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330103'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '33.01.03', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330103'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '330103', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330103'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '39716008', E'Psicoterapia de grupo (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330103'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 6500.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330103' AND f.name = 'Arancel Referencial Psicología 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item SM-330104 (33.01.04)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'SM-330104', 'active' FROM os_catalog WHERE code = 'salud-mental'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Evaluación psicodiagnóstica completa con batería de tests y emisión de informe pericial', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330104'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '33.01.04', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330104'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '330104', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330104'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '85247002', E'Evaluación psicodiagnóstica (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330104'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 52000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330104' AND f.name = 'Arancel Referencial Psicología 2026' AND u.code = 'MODULO'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item SM-330105 (33.01.05)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'SM-330105', 'active' FROM os_catalog WHERE code = 'salud-mental'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Consulta psiquiátrica clínica, evaluación psicofarmacológica y ajuste de dosis', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330105'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '33.01.05', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330105'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '330105', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330105'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '185349003', E'Consulta psiquiátrica (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330105'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 14500.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330105' AND f.name = 'Arancel Referencial Psicología 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- Item SM-330106 (33.01.06)
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, 'SM-330106', 'active' FROM os_catalog WHERE code = 'salud-mental'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, E'Interconsulta institucional psicológica / psiquiátrica en sala de internación sanatorial', 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330106'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '33.01.06', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330106'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '330106', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330106'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '185349003', E'Interconsulta psiquiátrica hospitalaria (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330106'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, 1.0000, 13000.0000, 0.0000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'salud-mental' AND i.permanent_code = 'SM-330106' AND f.name = 'Arancel Referencial Psicología 2026' AND u.code = 'SESION'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;

-- =============================================================================
-- 13. INGESTA: DOMINIO FARMACÉUTICO MULTICAPA (10 MEDICAMENTOS)
-- =============================================================================

-- Fármaco: AMOXIDAL 500 (Amoxicilina)
INSERT INTO os_substance (name, atc_code) VALUES (E'Amoxicilina', E'J01CA04')
ON CONFLICT (name) DO NOTHING;

INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, E'AMOXIDAL 500', E'Roemmers', E'Antibiótico betalactámico bactericida' FROM os_substance WHERE name = E'Amoxicilina'
ON CONFLICT (brand_name, laboratory) DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, E'Envase con 16 comprimidos recubiertos', E'Comprimidos recubiertos', E'Venta Bajo Receta'
FROM os_medicinal_product WHERE brand_name = E'AMOXIDAL 500' AND laboratory = E'Roemmers'
ON CONFLICT (product_id, presentation_text) DO NOTHING;

-- Identificadores Comerciales (Troquel, AlfaBeta, Kairos, GTIN)
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '458921', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'AMOXIDAL 500' AND p.presentation_text = E'Envase con 16 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '12045', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'AMOXIDAL 500' AND p.presentation_text = E'Envase con 16 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '30491', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'AMOXIDAL 500' AND p.presentation_text = E'Envase con 16 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '7791234567890', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'AMOXIDAL 500' AND p.presentation_text = E'Envase con 16 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

-- Fármaco: AMOXIDAL DUO (Amoxicilina + Ácido Clavulánico)
INSERT INTO os_substance (name, atc_code) VALUES (E'Amoxicilina + Ácido Clavulánico', E'J01CR02')
ON CONFLICT (name) DO NOTHING;

INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, E'AMOXIDAL DUO', E'Roemmers', E'Antibiótico bactericida de amplio espectro' FROM os_substance WHERE name = E'Amoxicilina + Ácido Clavulánico'
ON CONFLICT (brand_name, laboratory) DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, E'Envase con 14 comprimidos recubiertos', E'Comprimidos recubiertos', E'Venta Bajo Receta'
FROM os_medicinal_product WHERE brand_name = E'AMOXIDAL DUO' AND laboratory = E'Roemmers'
ON CONFLICT (product_id, presentation_text) DO NOTHING;

-- Identificadores Comerciales (Troquel, AlfaBeta, Kairos, GTIN)
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '458930', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'AMOXIDAL DUO' AND p.presentation_text = E'Envase con 14 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '12046', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'AMOXIDAL DUO' AND p.presentation_text = E'Envase con 14 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '30492', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'AMOXIDAL DUO' AND p.presentation_text = E'Envase con 14 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '7791234567891', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'AMOXIDAL DUO' AND p.presentation_text = E'Envase con 14 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

-- Fármaco: ACTRON 600 (Ibuprofeno)
INSERT INTO os_substance (name, atc_code) VALUES (E'Ibuprofeno', E'M01AE01')
ON CONFLICT (name) DO NOTHING;

INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, E'ACTRON 600', E'Bayer', E'Analgésico, antiinflamatorio y antipirético no esteroide (AINE)' FROM os_substance WHERE name = E'Ibuprofeno'
ON CONFLICT (brand_name, laboratory) DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, E'Envase con 20 cápsulas blandas de rápida acción', E'Cápsulas blandas', E'Venta Bajo Receta'
FROM os_medicinal_product WHERE brand_name = E'ACTRON 600' AND laboratory = E'Bayer'
ON CONFLICT (product_id, presentation_text) DO NOTHING;

-- Identificadores Comerciales (Troquel, AlfaBeta, Kairos, GTIN)
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '324510', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'ACTRON 600' AND p.presentation_text = E'Envase con 20 cápsulas blandas de rápida acción'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '11024', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'ACTRON 600' AND p.presentation_text = E'Envase con 20 cápsulas blandas de rápida acción'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '21904', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'ACTRON 600' AND p.presentation_text = E'Envase con 20 cápsulas blandas de rápida acción'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '7798765432101', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'ACTRON 600' AND p.presentation_text = E'Envase con 20 cápsulas blandas de rápida acción'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

-- Fármaco: IBUPIRAC 400 (Ibuprofeno)
INSERT INTO os_substance (name, atc_code) VALUES (E'Ibuprofeno', E'M01AE01')
ON CONFLICT (name) DO NOTHING;

INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, E'IBUPIRAC 400', E'Pfizer', E'Analgésico y antiinflamatorio no esteroide (AINE)' FROM os_substance WHERE name = E'Ibuprofeno'
ON CONFLICT (brand_name, laboratory) DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, E'Envase con 20 comprimidos', E'Comprimidos', E'Venta Libre'
FROM os_medicinal_product WHERE brand_name = E'IBUPIRAC 400' AND laboratory = E'Pfizer'
ON CONFLICT (product_id, presentation_text) DO NOTHING;

-- Identificadores Comerciales (Troquel, AlfaBeta, Kairos, GTIN)
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '324515', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'IBUPIRAC 400' AND p.presentation_text = E'Envase con 20 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '11025', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'IBUPIRAC 400' AND p.presentation_text = E'Envase con 20 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '21905', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'IBUPIRAC 400' AND p.presentation_text = E'Envase con 20 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '7798765432102', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'IBUPIRAC 400' AND p.presentation_text = E'Envase con 20 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

-- Fármaco: TERMOLGIN 1000 (Paracetamol)
INSERT INTO os_substance (name, atc_code) VALUES (E'Paracetamol', E'N02BE01')
ON CONFLICT (name) DO NOTHING;

INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, E'TERMOLGIN 1000', E'Montpellier', E'Analgésico y antipirético de acción central' FROM os_substance WHERE name = E'Paracetamol'
ON CONFLICT (brand_name, laboratory) DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, E'Envase con 20 comprimidos', E'Comprimidos', E'Venta Libre'
FROM os_medicinal_product WHERE brand_name = E'TERMOLGIN 1000' AND laboratory = E'Montpellier'
ON CONFLICT (product_id, presentation_text) DO NOTHING;

-- Identificadores Comerciales (Troquel, AlfaBeta, Kairos, GTIN)
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '512390', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'TERMOLGIN 1000' AND p.presentation_text = E'Envase con 20 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '14589', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'TERMOLGIN 1000' AND p.presentation_text = E'Envase con 20 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '33412', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'TERMOLGIN 1000' AND p.presentation_text = E'Envase con 20 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '7795432109876', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'TERMOLGIN 1000' AND p.presentation_text = E'Envase con 20 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

-- Fármaco: LOTRIAL 50 (Losartán Potásico)
INSERT INTO os_substance (name, atc_code) VALUES (E'Losartán Potásico', E'C09CA01')
ON CONFLICT (name) DO NOTHING;

INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, E'LOTRIAL 50', E'Roemmers', E'Antihipertensivo antagonista receptor AT1 de angiotensina II' FROM os_substance WHERE name = E'Losartán Potásico'
ON CONFLICT (brand_name, laboratory) DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, E'Envase con 30 comprimidos recubiertos', E'Comprimidos recubiertos', E'Venta Bajo Receta'
FROM os_medicinal_product WHERE brand_name = E'LOTRIAL 50' AND laboratory = E'Roemmers'
ON CONFLICT (product_id, presentation_text) DO NOTHING;

-- Identificadores Comerciales (Troquel, AlfaBeta, Kairos, GTIN)
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '298412', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'LOTRIAL 50' AND p.presentation_text = E'Envase con 30 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '10340', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'LOTRIAL 50' AND p.presentation_text = E'Envase con 30 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '20115', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'LOTRIAL 50' AND p.presentation_text = E'Envase con 30 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '7796543210987', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'LOTRIAL 50' AND p.presentation_text = E'Envase con 30 comprimidos recubiertos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

-- Fármaco: GLUCOPHAGE 850 (Metformina Clorhidrato)
INSERT INTO os_substance (name, atc_code) VALUES (E'Metformina Clorhidrato', E'A10BA02')
ON CONFLICT (name) DO NOTHING;

INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, E'GLUCOPHAGE 850', E'Merck', E'Hipoglucemiante oral biguanida' FROM os_substance WHERE name = E'Metformina Clorhidrato'
ON CONFLICT (brand_name, laboratory) DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, E'Envase con 60 comprimidos', E'Comprimidos', E'Venta Bajo Receta'
FROM os_medicinal_product WHERE brand_name = E'GLUCOPHAGE 850' AND laboratory = E'Merck'
ON CONFLICT (product_id, presentation_text) DO NOTHING;

-- Identificadores Comerciales (Troquel, AlfaBeta, Kairos, GTIN)
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '489012', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'GLUCOPHAGE 850' AND p.presentation_text = E'Envase con 60 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '13401', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'GLUCOPHAGE 850' AND p.presentation_text = E'Envase con 60 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '31502', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'GLUCOPHAGE 850' AND p.presentation_text = E'Envase con 60 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '7797654321098', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'GLUCOPHAGE 850' AND p.presentation_text = E'Envase con 60 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

-- Fármaco: GASTROMAX 20 (Omeprazol)
INSERT INTO os_substance (name, atc_code) VALUES (E'Omeprazol', E'A02BC01')
ON CONFLICT (name) DO NOTHING;

INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, E'GASTROMAX 20', E'Baliarda', E'Antiulceroso inhibidor de la bomba de protones (IBP)' FROM os_substance WHERE name = E'Omeprazol'
ON CONFLICT (brand_name, laboratory) DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, E'Envase con 28 cápsulas gastrorresistentes', E'Cápsulas', E'Venta Bajo Receta'
FROM os_medicinal_product WHERE brand_name = E'GASTROMAX 20' AND laboratory = E'Baliarda'
ON CONFLICT (product_id, presentation_text) DO NOTHING;

-- Identificadores Comerciales (Troquel, AlfaBeta, Kairos, GTIN)
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '550123', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'GASTROMAX 20' AND p.presentation_text = E'Envase con 28 cápsulas gastrorresistentes'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '16021', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'GASTROMAX 20' AND p.presentation_text = E'Envase con 28 cápsulas gastrorresistentes'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '38104', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'GASTROMAX 20' AND p.presentation_text = E'Envase con 28 cápsulas gastrorresistentes'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '7798901234567', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'GASTROMAX 20' AND p.presentation_text = E'Envase con 28 cápsulas gastrorresistentes'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

-- Fármaco: RIVOTRIL 0.5 (Clonazepam)
INSERT INTO os_substance (name, atc_code) VALUES (E'Clonazepam', E'N03AE01')
ON CONFLICT (name) DO NOTHING;

INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, E'RIVOTRIL 0.5', E'Roche', E'Ansiolítico y anticonvulsivo benzodiazepínico' FROM os_substance WHERE name = E'Clonazepam'
ON CONFLICT (brand_name, laboratory) DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, E'Envase con 30 comprimidos ranurados', E'Comprimidos', E'Archivada'
FROM os_medicinal_product WHERE brand_name = E'RIVOTRIL 0.5' AND laboratory = E'Roche'
ON CONFLICT (product_id, presentation_text) DO NOTHING;

-- Identificadores Comerciales (Troquel, AlfaBeta, Kairos, GTIN)
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '589124', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'RIVOTRIL 0.5' AND p.presentation_text = E'Envase con 30 comprimidos ranurados'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '17452', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'RIVOTRIL 0.5' AND p.presentation_text = E'Envase con 30 comprimidos ranurados'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '40192', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'RIVOTRIL 0.5' AND p.presentation_text = E'Envase con 30 comprimidos ranurados'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '7799012345678', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'RIVOTRIL 0.5' AND p.presentation_text = E'Envase con 30 comprimidos ranurados'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

-- Fármaco: T4 MONTPELLIER 100 (Levotiroxina Sódica)
INSERT INTO os_substance (name, atc_code) VALUES (E'Levotiroxina Sódica', E'H03AA01')
ON CONFLICT (name) DO NOTHING;

INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, E'T4 MONTPELLIER 100', E'Montpellier', E'Hormonoterapia tiroidea de reemplazo' FROM os_substance WHERE name = E'Levotiroxina Sódica'
ON CONFLICT (brand_name, laboratory) DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, E'Envase con 50 comprimidos', E'Comprimidos', E'Venta Bajo Receta'
FROM os_medicinal_product WHERE brand_name = E'T4 MONTPELLIER 100' AND laboratory = E'Montpellier'
ON CONFLICT (product_id, presentation_text) DO NOTHING;

-- Identificadores Comerciales (Troquel, AlfaBeta, Kairos, GTIN)
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '601245', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'T4 MONTPELLIER 100' AND p.presentation_text = E'Envase con 50 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '18204', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'T4 MONTPELLIER 100' AND p.presentation_text = E'Envase con 50 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '42015', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'T4 MONTPELLIER 100' AND p.presentation_text = E'Envase con 50 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '7790123456789', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = E'T4 MONTPELLIER 100' AND p.presentation_text = E'Envase con 50 comprimidos'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

-- =============================================================================
-- 14. TABLAS PLANAS AUXILIARES Y ANALYZE
-- =============================================================================
CREATE TABLE IF NOT EXISTS nomencladores_argentina (
    id SERIAL PRIMARY KEY,
    tipo_nomenclador VARCHAR(30) NOT NULL,
    codigo VARCHAR(30) NOT NULL,
    capitulo VARCHAR(100),
    descripcion TEXT NOT NULL,
    unidad_tipo VARCHAR(30),
    unidad_valor NUMERIC(12, 4),
    gastos_valor NUMERIC(12, 4),
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    codigo_loinc VARCHAR(20),
    vigencia_desde DATE,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (tipo_nomenclador, codigo)
);

CREATE INDEX IF NOT EXISTS idx_nom_arg_trgm ON nomencladores_argentina USING gin (descripcion gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_nom_arg_tipo_codigo ON nomencladores_argentina(tipo_nomenclador, codigo);

CREATE TABLE IF NOT EXISTS vademecum_comercial (
    id SERIAL PRIMARY KEY,
    numero_troquel VARCHAR(20) UNIQUE,
    codigo_alfabeta VARCHAR(20),
    codigo_kairos VARCHAR(20),
    codigo_barras_gtin VARCHAR(20),
    monodroga VARCHAR(255) NOT NULL,
    nombre_comercial VARCHAR(255) NOT NULL,
    presentacion VARCHAR(255) NOT NULL,
    laboratorio VARCHAR(150),
    accion_farmacologica VARCHAR(150),
    tipo_venta VARCHAR(50),
    anmat_certificado VARCHAR(50),
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    activo BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_vad_troquel ON vademecum_comercial(numero_troquel);
CREATE INDEX IF NOT EXISTS idx_vad_alfabeta ON vademecum_comercial(codigo_alfabeta);
CREATE INDEX IF NOT EXISTS idx_vad_kairos ON vademecum_comercial(codigo_kairos);
CREATE INDEX IF NOT EXISTS idx_vad_comercial_trgm ON vademecum_comercial USING gin (nombre_comercial gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_vad_monodroga_trgm ON vademecum_comercial USING gin (monodroga gin_trgm_ops);

-- Sincronización a tablas planas
INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor, gastos_valor)
SELECT 'NN_PMO', ident.value, ver.preferred_term, u.code, f.units_amount, f.expenses_amount
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'nn-pmo'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor)
SELECT 'NBU', ident.value, ver.preferred_term, u.code, f.units_amount
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'nbu'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor)
SELECT 'NHPGD', ident.value, ver.preferred_term, u.code, f.fixed_price
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'nhpgd'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor)
SELECT 'ANDIS', ident.value, ver.preferred_term, u.code, f.fixed_price
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'andis'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor)
SELECT 'KINESIOLOGIA', ident.value, ver.preferred_term, u.code, f.fixed_price
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'kinesiologia'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor)
SELECT 'SALUD_MENTAL', ident.value, ver.preferred_term, u.code, f.fixed_price
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'salud-mental'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

-- ANALYZE FINAL
ANALYZE os_catalog;
ANALYZE os_catalog_release;
ANALYZE os_catalog_category;
ANALYZE os_catalog_item;
ANALYZE os_catalog_item_version;
ANALYZE os_catalog_identifier;
ANALYZE os_terminology_system;
ANALYZE os_concept_mapping;
ANALYZE os_pricing_unit;
ANALYZE os_fee_schedule;
ANALYZE os_fee_item;
ANALYZE os_substance;
ANALYZE os_medicinal_product;
ANALYZE os_product_package;
ANALYZE os_product_identifier;
ANALYZE nomencladores_argentina;
ANALYZE vademecum_comercial;

-- Resumen de Catálogos
SELECT cat.code AS catalogo, count(i.id) AS total_items
  FROM os_catalog cat
  LEFT JOIN os_catalog_item i ON i.catalog_id = cat.id
 GROUP BY cat.code
 ORDER BY total_items DESC;
