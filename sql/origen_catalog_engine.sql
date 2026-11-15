-- =============================================================================
-- Origen Salud · Origen Catalog Engine 1.0
-- origen_catalog_engine.sql
-- =============================================================================
-- Arquitectura de interoperabilidad clínica, arancelaria y farmacéutica
--   1. os_catalog, release, category, item, version, term, identifier
--   2. os_terminology_system, os_concept_mapping (SNOMED CT, CIE-10, LOINC, CDT)
--   3. os_pricing_unit, os_fee_schedule, os_fee_item
--   4. os_substance, os_medicinal_product, os_product_package, os_product_identifier
--   5. Ingesta completa de DENTAR (138 procedimientos) + 6 Nomencladores Nacionales
-- =============================================================================

SET client_encoding = 'UTF8';
SET statement_timeout = 0;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================================================
-- 1. TABLAS DEL MOTOR DE CATÁLOGOS (os_catalog_*)
-- =============================================================================
CREATE TABLE IF NOT EXISTS os_catalog (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    organization VARCHAR(150) NOT NULL,
    country_code VARCHAR(5) NOT NULL DEFAULT 'AR',
    domain_type VARCHAR(30) NOT NULL,
    description TEXT,
    website_url VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS os_catalog_release (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    version_tag VARCHAR(30) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    official_norm_reference VARCHAR(255),
    status VARCHAR(20) NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'deprecated')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (catalog_id, version_tag)
);

CREATE TABLE IF NOT EXISTS os_catalog_category (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    parent_id INT REFERENCES os_catalog_category(id),
    sort_order INT NOT NULL DEFAULT 0,
    UNIQUE (catalog_id, code)
);

CREATE TABLE IF NOT EXISTS os_catalog_item (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    permanent_code VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'retired')),
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
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
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
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS os_product_package (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES os_medicinal_product(id) ON DELETE CASCADE,
    presentation_text VARCHAR(255) NOT NULL,
    dosage_form VARCHAR(100),
    sale_type VARCHAR(50) NOT NULL DEFAULT 'Venta Bajo Receta'
        CHECK (sale_type IN ('Venta Libre', 'Venta Bajo Receta', 'Archivada', 'Decreto')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
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

-- Releases 2026 oficiales
INSERT INTO os_catalog_release (catalog_id, version_tag, valid_from, official_norm_reference)
SELECT id, '2026-v1', '2026-01-01', 'Vigencia oficial 2026' FROM os_catalog
ON CONFLICT (catalog_id, version_tag) DO NOTHING;


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
SELECT i.id, 4, 'D3330', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000021'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '73785006', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D3330', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000022'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '73785006', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D3330', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000023'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '73785006', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D3330', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000024'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '73785006', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D3330', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000025'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '73785006', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D3330', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000026'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '73785006', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D5899', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000072'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '11210001', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D5899', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000073'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '11210001', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D5899', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000074'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '11210001', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D5899', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000075'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '11210001', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D5899', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000076'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '11210001', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D5899', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000077'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '11210001', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D5899', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000078'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '11210001', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '67270000', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '67270000', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '67270000', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '67270000', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '67270000', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '38694004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '38694004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '38694004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '38694004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '38694004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '38694004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '38694004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '38694004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '38694004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '38694004', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 4, 'D8010', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = 'DNT-000094'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '8708008', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '8708008', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '8708008', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '8708008', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '8708008', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '8708008', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '8708008', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '8708008', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '8708008', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '8708008', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '8708008', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
SELECT i.id, 1, '234737002', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = 'CAT-SURG'
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
SELECT i.id, 1, '274154007', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
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
-- 7. INGESTA: NOMENCLADOR NACIONAL MÉDICO / PMO (nn-pmo)
-- =============================================================================
INSERT INTO os_catalog_item (catalog_id, permanent_code)
SELECT id, 'NN-420101' FROM os_catalog WHERE code = 'nn-pmo' ON CONFLICT DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term)
SELECT i.id, r.id, 'Consulta médica general o especializada en consultorio'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420101'
ON CONFLICT DO NOTHING;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '42.01.01', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420101'
ON CONFLICT DO NOTHING;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '420101', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420101'
ON CONFLICT DO NOTHING;

INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '185349003', 'Consulta médica ambulatoria (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nn-pmo' AND i.permanent_code = 'NN-420101'
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. INGESTA: NOMENCLADOR BIOQUÍMICO ÚNICO (nbu)
-- =============================================================================
INSERT INTO os_catalog_item (catalog_id, permanent_code)
SELECT id, 'NBU-660475' FROM os_catalog WHERE code = 'nbu' ON CONFLICT DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term)
SELECT i.id, r.id, 'Hemograma completo (recuento globular, fórmula leucocitaria, Hb y Hto)'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660475'
ON CONFLICT DO NOTHING;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_CUBRA', '660475', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660475'
ON CONFLICT DO NOTHING;

-- Mapeo NBU a LOINC y SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '58410-2', 'CBC panel - Blood by Automated count', 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660475'
ON CONFLICT DO NOTHING;

INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '43789009', 'Recuento sanguíneo completo (procedimiento)', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660475'
ON CONFLICT DO NOTHING;

-- Arancel NBU en UB
INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount)
SELECT f.id, i.id, u.id, 3.8000
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = 'nbu' AND i.permanent_code = 'NBU-660475' AND f.name LIKE 'Arancel CUBRA%' AND u.code = 'UB'
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. INGESTA: DISCAPACIDAD (andis)
-- =============================================================================
INSERT INTO os_catalog_item (catalog_id, permanent_code)
SELECT id, 'ANDIS-250101' FROM os_catalog WHERE code = 'andis' ON CONFLICT DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term)
SELECT i.id, r.id, 'Módulo de rehabilitación ambulatoria integral'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250101'
ON CONFLICT DO NOTHING;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_ANDIS', '250101', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'andis' AND i.permanent_code = 'ANDIS-250101'
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 10. INGESTA: DOMINIO FARMACÉUTICO MULTICAPA
-- =============================================================================
INSERT INTO os_substance (name, atc_code) VALUES
('Amoxicilina', 'J01CA04'),
('Amoxicilina + Ácido Clavulánico', 'J01CR02'),
('Ibuprofeno', 'M01AE01'),
('Paracetamol', 'N02BE01'),
('Losartán Potásico', 'C09CA01')
ON CONFLICT (name) DO NOTHING;

-- Amoxidal 500
INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, 'AMOXIDAL', 'Roemmers', 'Antibiótico betalactámico bactericida' FROM os_substance WHERE name = 'Amoxicilina'
ON CONFLICT DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, '500 mg x 16 comprimidos recubiertos', 'Comprimidos', 'Venta Bajo Receta' FROM os_medicinal_product WHERE brand_name = 'AMOXIDAL'
ON CONFLICT DO NOTHING;

-- Identificadores Troquel / AlfaBeta / Kairos / GTIN
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '458921', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id WHERE mp.brand_name = 'AMOXIDAL'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '12045', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id WHERE mp.brand_name = 'AMOXIDAL'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '30491', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id WHERE mp.brand_name = 'AMOXIDAL'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '7791234567890', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id WHERE mp.brand_name = 'AMOXIDAL'
ON CONFLICT (system_code, identifier_value) DO NOTHING;

-- Actron 600
INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, 'ACTRON 600', 'Bayer', 'Analgésico, antiinflamatorio no esteroide (AINE)' FROM os_substance WHERE name = 'Ibuprofeno'
ON CONFLICT DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, '600 mg x 20 cápsulas blandas', 'Cápsulas blandas', 'Venta Bajo Receta' FROM os_medicinal_product WHERE brand_name = 'ACTRON 600'
ON CONFLICT DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '324510', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id WHERE mp.brand_name = 'ACTRON 600'
ON CONFLICT (system_code, identifier_value) DO NOTHING;


-- =============================================================================
-- 11. ANALYZE FINAL
-- =============================================================================
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

SELECT cat.code AS catalogo, count(i.id) AS total_items
  FROM os_catalog cat
  LEFT JOIN os_catalog_item i ON i.catalog_id = cat.id
 GROUP BY cat.code
 ORDER BY total_items DESC;
