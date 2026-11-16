-- =============================================================================
-- Origen Salud · Sistema DENTAR (Ontología Odontológica + Diagnósticos CIE-10)
-- dentar_core_and_diagnosis.sql :: DENTAR Core + Justificación Clínica
-- =============================================================================
--
-- CONTENIDO:
--   0. Familia DENTAR: registro de catálogos (lo crea sql/dentar_family.sql).
--   1. dentar_release: Versiones y ciclo de vida de la ontología.
--   2. dentar_category / dentar_category_version: Jerarquía y capítulos por catálogo.
--   3. dentar_concept / dentar_concept_version: DENTAR-PR, identidad DNT-PR-NNNNNN.
--   4. dentar_term: Términos preferidos, sinónimos y siglas (es-AR / en).
--   5. dentar_unit / dentar_concept_unit: Unidades clínicas (pieza, cara, arcada).
--   6. dentar_attribute_definition / dentar_concept_attribute_rule: Reglas de auditoría.
--   7. dentar_terminology_system / dentar_catalog_mapping_rule: Reglas de mapeo por catálogo.
--   8. dentar_concept_mapping: Mapeos externos de DENTAR-PR (Nomenclador/AR, CDT, SNOMED).
--   9. dentar_diagnosis / dentar_diagnosis_mapping: DENTAR-DX, identidad DNT-DX-NNNNNN.
--  10. dentar_concept_diagnosis: Matriz de justificación clínica (prestación <-> diagnóstico).
--  11. Vistas de consulta clínica, familia e interoperabilidad.
--
-- REQUISITO: ejecutar antes sql/dentar_family.sql (registro dentar_catalog).
-- COMPATIBILIDAD: PostgreSQL 18
-- =============================================================================

SET client_encoding = 'UTF8';
SET statement_timeout = 0;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO $$
BEGIN
    IF to_regclass('public.dentar_catalog') IS NULL THEN
        RAISE EXCEPTION
            'Falta el registro de la familia DENTAR (tabla dentar_catalog).'
            USING HINT = 'Ejecutá primero: psql -d origen_salud -f sql/dentar_family.sql';
    END IF;
END $$;

-- =============================================================================
-- 1. DENTAR RELEASE (GOBERNANZA Y VERSIONES)
-- =============================================================================
CREATE TABLE IF NOT EXISTS dentar_release (
    id SERIAL PRIMARY KEY,
    version VARCHAR(20) NOT NULL UNIQUE,
    release_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'deprecated')),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dentar_release (version, release_date, status, description)
VALUES ('1.0.0', CURRENT_DATE, 'published', 'Primera publicación oficial del estándar DENTAR Argentina')
ON CONFLICT (version) DO UPDATE SET description = EXCLUDED.description;


-- =============================================================================
-- 2. CATEGORÍAS Y CAPÍTULOS
-- =============================================================================
CREATE TABLE IF NOT EXISTS dentar_category (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL DEFAULT dentar_catalog_id('dentar-pr') REFERENCES dentar_catalog(id),
    code VARCHAR(30) NOT NULL UNIQUE,
    parent_id INT REFERENCES dentar_category(id),
    sort_order INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive'))
);

CREATE TABLE IF NOT EXISTS dentar_category_version (
    id SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES dentar_category(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    language VARCHAR(10) NOT NULL DEFAULT 'es-AR',
    name VARCHAR(150) NOT NULL,
    description TEXT,
    UNIQUE (category_id, version_number, language)
);

INSERT INTO dentar_category (code, sort_order) VALUES (E'CAT-DIAG', 10)
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Diagnóstico y Exámenes Clínicos', E'Evaluaciones orales, exámenes estomatológicos e imágenes radiográficas.' FROM dentar_category WHERE code = E'CAT-DIAG'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_category (code, sort_order) VALUES (E'CAT-PREV', 20)
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Odontología Preventiva', E'Profilaxis, aplicaciones de flúor, selladores y mantenedores de espacio.' FROM dentar_category WHERE code = E'CAT-PREV'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_category (code, sort_order) VALUES (E'CAT-REST', 30)
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Operatoria Dental y Restauradora', E'Restauraciones con amalgama, resinas fotocurables, incrustaciones y estética.' FROM dentar_category WHERE code = E'CAT-REST'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_category (code, sort_order) VALUES (E'CAT-ENDO', 40)
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Endodoncia', E'Biopulpectomías, tratamientos de conductos unirradiculares y multirradiculares.' FROM dentar_category WHERE code = E'CAT-ENDO'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_category (code, sort_order) VALUES (E'CAT-PERI', 50)
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Periodoncia', E'Tratamiento de gingivitis, raspado y alisado radicular y cirugías periodontales.' FROM dentar_category WHERE code = E'CAT-PERI'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_category (code, sort_order) VALUES (E'CAT-PROSTH-R', 60)
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Prótesis Parcial y Completa Removible', E'Prótesis completas, parciales acrílicas y de cromo-cobalto, composturas y rebasados.' FROM dentar_category WHERE code = E'CAT-PROSTH-R'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_category (code, sort_order) VALUES (E'CAT-PROSTH-F', 70)
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Prótesis Fija', E'Coronas unitarias coladas, porcelana pura o sobre metal, pernos muñón y puentes.' FROM dentar_category WHERE code = E'CAT-PROSTH-F'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_category (code, sort_order) VALUES (E'CAT-IMPL', 80)
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Implantología Odontológica', E'Colocación quirúrgica de implantes, emergentes protésicos y relleno óseo.' FROM dentar_category WHERE code = E'CAT-IMPL'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_category (code, sort_order) VALUES (E'CAT-SURG', 90)
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Cirugía Bucal y Maxilofacial', E'Extracciones simples, dientes retenidos, germectomías, apicectomías y biopsias.' FROM dentar_category WHERE code = E'CAT-SURG'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_category (code, sort_order) VALUES (E'CAT-ORTHO', 100)
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Ortodoncia y Ortopedia Funcional', E'Estudios diagnósticos, ortodoncia interceptiva y tratamientos integrales.' FROM dentar_category WHERE code = E'CAT-ORTHO'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_category (code, sort_order) VALUES (E'CAT-ADJ', 110)
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Servicios Complementarios de Odontología', E'Consultas de urgencia, visitas a domicilio, placas de relajación y ATM.' FROM dentar_category WHERE code = E'CAT-ADJ'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Categoría propia de DENTAR-DX: no comparte el árbol de capítulos de DENTAR-PR.
INSERT INTO dentar_category (code, sort_order, catalog_id) VALUES (E'CAT-DX', 200, dentar_catalog_id('dentar-dx'))
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order, catalog_id = EXCLUDED.catalog_id;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', E'Diagnósticos odontológicos (CIE-10 K00-K14)', E'Enfermedades, condiciones y alteraciones bucomaxilofaciales codificadas con DENTAR-DX.' FROM dentar_category WHERE code = E'CAT-DX'
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;


-- =============================================================================
-- 3. UNIDADES CLÍNICAS DE PRESTACIÓN
-- =============================================================================
CREATE TABLE IF NOT EXISTS dentar_unit (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

INSERT INTO dentar_unit (code, name, description) VALUES
('UNIT-TOOTH', 'Por pieza dentaria (FDI)', 'Requiere indicar número de pieza dentaria según nomenclatura FDI de 2 dígitos'),
('UNIT-SURFACE', 'Por cara dentaria', 'Requiere indicar caras involucradas (Oclusal, Mesial, Distal, Vestibular, Lingual/Palatina)'),
('UNIT-QUADRANT', 'Por cuadrante o sector', 'Requiere especificar cuadrante (1 a 4) o sector bucal (1 a 6)'),
('UNIT-ARCH', 'Por arcada / maxilar', 'Requiere especificar maxilar superior o inferior'),
('UNIT-SESSION', 'Por consulta / sesión', 'Prestación de carácter clínico global que no se acota a una pieza individual')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;


-- =============================================================================
-- 4. REGLAS Y DEFINICIÓN DE ATRIBUTOS CLÍNICOS DE AUDITORÍA
-- =============================================================================
CREATE TABLE IF NOT EXISTS dentar_attribute_definition (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    data_type VARCHAR(20) NOT NULL CHECK (data_type IN ('string','integer','decimal','boolean','date','coded')),
    description TEXT
);

INSERT INTO dentar_attribute_definition (code, name, data_type, description) VALUES
('ATTR-TOOTH', 'Especificación de Pieza Dentaria', 'coded', 'Indica si es obligatorio enviar la pieza dentaria bajo norma FDI'),
('ATTR-SURFACE', 'Especificación de Caras', 'coded', 'Indica si es obligatorio detallar las caras cavitarias tratadas'),
('ATTR-PRE-XRAY', 'Radiografía Pre-Operatoria', 'boolean', 'Exigencia de radiografía previa para auditoría médica'),
('ATTR-POST-XRAY', 'Radiografía Post-Operatoria', 'boolean', 'Exigencia de radiografía de control final'),
('ATTR-DENTAL-CHART', 'Odontograma / Fichado Inicial', 'boolean', 'Requisito de registrar estado inicial de la cavidad bucal'),
('ATTR-PERIODONTAL-CHART', 'Ficha Periodontal / Periodontograma', 'boolean', 'Requisito de registro de profundidad de sondaje de bolsas'),
('ATTR-MATERIAL', 'Material Protésico / Dental', 'string', 'Especificación del material biocompatible o metal empleado')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;


-- =============================================================================
-- 5. SISTEMAS DE TERMINOLOGÍA EXTERNA VINCULADOS
-- =============================================================================
CREATE TABLE IF NOT EXISTS dentar_terminology_system (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    uri VARCHAR(500),
    description TEXT
);

INSERT INTO dentar_terminology_system (code, name, uri, description) VALUES
('CDT-2025', 'Code on Dental Procedures and Nomenclature (ADA)', 'https://www.ada.org/cdt', 'Estándar internacional de codificación de procedimientos odontológicos de la ADA'),
('NOMENCLADOR-AR', 'Nomenclador Odontológico Único de Argentina', 'https://fopba.org.ar', 'Nomenclador nacional y de colegios odontológicos argentinos (Capítulos I a XI)'),
('SNOMED-CT', 'SNOMED Clinical Terms (Edición Argentina)', 'http://snomed.info/sct', 'Terminología clínica ontológica universal adoptada por el Ministerio de Salud'),
('CIE-10', 'Clasificación Internacional de Enfermedades 10ª Rev.', 'https://icd.who.int/browse10', 'Clasificación estadística de afecciones y diagnósticos bucomaxilofaciales (K00-K14)')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Reglas de mapeo por catálogo. No bloquean la carga: documentan qué sistemas
-- corresponden a cada producto y cuáles son obligatorios para publicar.
CREATE TABLE IF NOT EXISTS dentar_catalog_mapping_rule (
    catalog_id INT NOT NULL REFERENCES dentar_catalog(id) ON DELETE CASCADE,
    system_code VARCHAR(30) NOT NULL REFERENCES dentar_terminology_system(code) ON DELETE CASCADE,
    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    is_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (catalog_id, system_code)
);

INSERT INTO dentar_catalog_mapping_rule (catalog_id, system_code, is_required, is_allowed)
VALUES
    (dentar_catalog_id('dentar-pr'), 'NOMENCLADOR-AR', TRUE,  TRUE),
    (dentar_catalog_id('dentar-pr'), 'CDT-2025',       FALSE, TRUE),
    (dentar_catalog_id('dentar-pr'), 'SNOMED-CT',      FALSE, TRUE),
    (dentar_catalog_id('dentar-dx'), 'CIE-10',         TRUE,  TRUE),
    (dentar_catalog_id('dentar-dx'), 'SNOMED-CT',      FALSE, TRUE)
ON CONFLICT (catalog_id, system_code) DO UPDATE
   SET is_required = EXCLUDED.is_required,
       is_allowed  = EXCLUDED.is_allowed;


-- =============================================================================
-- 6. CONCEPTOS PERMANENTES DENTAR, VERSIONES, TÉRMINOS Y MAPEOS
-- =============================================================================
CREATE TABLE IF NOT EXISTS dentar_concept (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL DEFAULT dentar_catalog_id('dentar-pr') REFERENCES dentar_catalog(id),
    code VARCHAR(30) NOT NULL UNIQUE,            -- Ej: 'DNT-PR-000001'
    concept_type VARCHAR(30) NOT NULL DEFAULT 'procedure' CHECK (concept_type IN ('procedure','service','evaluation','diagnostic_service','rehabilitation')),
    lifecycle_status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (lifecycle_status IN ('draft','active','retired')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dentar_concept_version (
    id SERIAL PRIMARY KEY,
    concept_id INT NOT NULL REFERENCES dentar_concept(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    definition TEXT NOT NULL,
    clinical_scope TEXT,
    clinical_criteria TEXT,
    approval_status VARCHAR(20) NOT NULL DEFAULT 'approved' CHECK (approval_status IN ('draft','review','approved','rejected')),
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (concept_id, version_number)
);

CREATE TABLE IF NOT EXISTS dentar_term (
    id SERIAL PRIMARY KEY,
    concept_version_id INT NOT NULL REFERENCES dentar_concept_version(id) ON DELETE CASCADE,
    language VARCHAR(10) NOT NULL DEFAULT 'es-AR',
    term VARCHAR(500) NOT NULL,
    term_type VARCHAR(20) NOT NULL DEFAULT 'preferred' CHECK (term_type IN ('preferred','synonym','abbreviation')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dentar_term_trgm ON dentar_term USING gin (term gin_trgm_ops);

CREATE TABLE IF NOT EXISTS dentar_concept_category (
    concept_version_id INT NOT NULL REFERENCES dentar_concept_version(id) ON DELETE CASCADE,
    category_id INT NOT NULL REFERENCES dentar_category(id) ON DELETE CASCADE,
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (concept_version_id, category_id)
);

CREATE TABLE IF NOT EXISTS dentar_concept_attribute_rule (
    concept_version_id INT NOT NULL REFERENCES dentar_concept_version(id) ON DELETE CASCADE,
    attribute_id INT NOT NULL REFERENCES dentar_attribute_definition(id) ON DELETE CASCADE,
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (concept_version_id, attribute_id)
);

CREATE TABLE IF NOT EXISTS dentar_concept_mapping (
    id SERIAL PRIMARY KEY,
    concept_version_id INT NOT NULL REFERENCES dentar_concept_version(id) ON DELETE CASCADE,
    system_code VARCHAR(30) NOT NULL REFERENCES dentar_terminology_system(code),
    external_code VARCHAR(100) NOT NULL,
    external_display VARCHAR(500),
    relationship VARCHAR(30) NOT NULL DEFAULT 'equivalent' CHECK (relationship IN ('equivalent','broader','narrower','related','not_mappable')),
    UNIQUE (concept_version_id, system_code, external_code)
);

-- DNT-PR-000001 :: 01.01 - Examen-Diagnóstico-Fichado y plan de tratamiento
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000001', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Examen-Diagnóstico-Fichado y plan de tratamiento Normas de auditoría: Se considera primera consulta al examen, diagnóstico, el fichado y plan de tratamiento. Como consecuencia del examen, el fichado deberá reflejar el estado actual de la boca, previo al tratamiento a efectuarse. El código 01.01 podrá facturarse hasta una vez por año, salvo para menores de dieciocho años cuyo tope serán dos consultas por año, cualquiera fuese el número de veces que en dicho período el beneficiario demande servicios con el mismo prestador, no pudiendo facturarlo los especialistas que efectúen determinada práctica derivada de otro prestador y/o profesional. Sólo se reconocerá cuando no se realice la práctica indicada', E'Capítulo I - Consultas', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000001'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Examen-Diagnóstico-Fichado y plan de tratamiento', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000001'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000001' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'01.01', E'Examen-Diagnóstico-Fichado y plan de tratamiento', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000001'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0150', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000001'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '424759004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000001'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000002 :: 01.02 - Consulta nocturna-Domingo y feriado (urgencias)
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000002', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Consulta nocturna-Domingo y feriado (urgencias)', E'Capítulo I - Consultas', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000002'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Consulta nocturna-Domingo y feriado (urgencias)', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000002'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000002' AND cat.code = E'CAT-ADJ'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'01.02', E'Consulta nocturna-Domingo y feriado (urgencias)', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000002'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D9440', E'Servicios Complementarios de Odontología', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000002'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '275932009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000002'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000003 :: 01.03 - Visitas a domicilio
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000003', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Visitas a domicilio Normas de auditoría: Se considera consulta domiciliaria a la atención de pacientes impedidos de trasladarse al consultorio del prestador, fuera del radio urbano.', E'Capítulo I - Consultas', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000003'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Visitas a domicilio', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000003'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000003' AND cat.code = E'CAT-ADJ'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'01.03', E'Visitas a domicilio', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000003'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D9410', E'Servicios Complementarios de Odontología', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000003'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '308335008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000003'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000004 :: 01.04 - Consultas de urgencia, prestación que no constituya paso int
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000004', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Consultas de urgencia, prestación que no constituya paso intermedio de tratamiento. Normas de auditoría: Se considera consulta de urgencia a toda prestación que no constituye paso intermedio o final de tratamiento. Se debe establecer en todos los casos el motivo de la misma, Ej.: Pericoronaritis, estomatitis, cementado de coronas y puentes, punción y drenaje de abscesos, flemones, hemorragias y alveolitis, etc.', E'Capítulo I - Consultas', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000004'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Consultas de urgencia, prestación que no constituya paso intermedio de tratamiento.', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000004'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000004' AND cat.code = E'CAT-ADJ'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'01.04', E'Consultas de urgencia, prestación que no constituya paso intermedio de tratamiento.', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000004'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D9110', E'Servicios Complementarios de Odontología', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000004'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '275932009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000004'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000005 :: 01.05 - Consulta de estomatología (sólo para especialistas)
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000005', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Consulta de estomatología (sólo para especialistas) Normas de auditoría: Se reconoce para lesiones propias de la mucosa bucal. Se permite facturar en forma independiente del código 01.01 (Ej.: patologías: Papilomas épulis, lesiones precancerosas y cancerosas, micosis, etc.). Incluye diagnóstico e indicación de tratamiento', E'Capítulo I - Consultas', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000005'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Consulta de estomatología (sólo para especialistas)', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000005'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000005' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'01.05', E'Consulta de estomatología (sólo para especialistas)', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000005'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0160', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000005'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '386053000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000005'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000006 :: 01.06 - Consulta preventiva periódica
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000006', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Consulta preventiva periódica', E'Capítulo I - Consultas', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000006'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Consulta preventiva periódica', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000006'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000006' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'01.06', E'Consulta preventiva periódica', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000006'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0120', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000006'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '424759004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000006'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000007 :: 01.07 - Bonos otras Obras Sociales
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000007', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Bonos otras Obras Sociales', E'Capítulo I - Consultas', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000007'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Bonos otras Obras Sociales', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000007'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000007' AND cat.code = E'CAT-ADJ'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'01.07', E'Bonos otras Obras Sociales', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000007'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D9999', E'Servicios Complementarios de Odontología', E'related'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000007'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '275932009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000007'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000008 :: 02.01 - Obturación con amalgama: cavidad simple
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000008', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Obturación con amalgama: cavidad simple Normas de auditoría: Se reconocerá para cavidad simple habiéndose practicado correcto diagnóstico y adecuado tallado de la cavidad.', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000008'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Obturación con amalgama: cavidad simple', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000008'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000008' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.01', E'Obturación con amalgama: cavidad simple', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000008'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2140', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000008'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '80891009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000008'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000008' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000008' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
-- DNT-PR-000009 :: 02.02 - Obturación con amalgama: cavidad compuesta
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000009', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Obturación con amalgama: cavidad compuesta Normas de auditoría: Se reconocerá para cavidad compuesta o compleja previo diagnóstico pulpar y adecuado tallado de la cavidad.', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000009'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Obturación con amalgama: cavidad compuesta', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000009'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000009' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.02', E'Obturación con amalgama: cavidad compuesta', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000009'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2150', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000009'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '80891009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000009'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000009' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000009' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
-- DNT-PR-000010 :: 02.03 - Obturación con amalgama: cavidad compleja
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000010', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Obturación con amalgama: cavidad compleja Normas de auditoría: Se reconocerá para cavidad compuesta o compleja previo diagnóstico pulpar y adecuado tallado de la cavidad.', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000010'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Obturación con amalgama: cavidad compleja', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000010'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000010' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.03', E'Obturación con amalgama: cavidad compleja', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000010'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2160', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000010'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '80891009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000010'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000010' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000010' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
-- DNT-PR-000011 :: 02.04 - Obturación con amalgama: reconstrucción con tornillo en cond
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000011', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Obturación con amalgama: reconstrucción con tornillo en conducto Normas de auditoría: Se reconocerá en piezas posteriores y con Rx post-operatoria que se incluye.', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000011'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Obturación con amalgama: reconstrucción con tornillo en conducto', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000011'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000011' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.04', E'Obturación con amalgama: reconstrucción con tornillo en conducto', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000011'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2161', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000011'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '80891009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000011'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000011' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000011' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000011' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000012 :: 02.05 - Obturación Estética - Cavidad simple
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000012', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Obturación Estética - Cavidad simple Normas de auditoría: Se reconocerá para cavidad simple y previo diagnóstico pulpar, y se aplica a piezas TEMPORARIAS.', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000012'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Obturación Estética - Cavidad simple', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000012'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000012' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.05', E'Obturación Estética - Cavidad simple', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000012'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2330', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000012'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '111164008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000012'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000012' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000012' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000012' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000013 :: 02.06 - Obturación Estética- Cavidad compuesta o Compuesta
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000013', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Obturación Estética- Cavidad compuesta o Compuesta Normas de auditoría: Se reconocerá para cavidades compuestas o complejas previo diagnóstico pulpar. y se aplica a piezas TEMPORARIAS.', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000013'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Obturación Estética- Cavidad compuesta o Compuesta', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000013'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000013' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.06', E'Obturación Estética- Cavidad compuesta o Compuesta', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000013'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2331', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000013'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '111164008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000013'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000013' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000013' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000013' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000014 :: 02.08 - Obturación resina fotocurado sector Anterior y Posterior
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000014', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Obturación resina fotocurado sector Anterior y Posterior Normas de auditoría: Se reconocerá en piezas permanentes anteriores y posteriores previo diagnóstico pulpar', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000014'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Obturación resina fotocurado sector Anterior y Posterior', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000014'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000014' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.08', E'Obturación resina fotocurado sector Anterior y Posterior', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000014'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2391', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000014'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '111164008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000014'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000014' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000014' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000014' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000015 :: 02.09 - Reconstrucción de ángulo en dientes anteriores
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000015', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Reconstrucción de ángulo en dientes anteriores Normas de auditoría: Se reconocerá en piezas anteriores, previo diagnóstico pulpar e incluye técnicas de grabado ácido.', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000015'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Reconstrucción de ángulo en dientes anteriores', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000015'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000015' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.09', E'Reconstrucción de ángulo en dientes anteriores', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000015'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2335', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000015'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '111164008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000015'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000015' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000015' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
-- DNT-PR-000016 :: 02.10 - Obturación resina fotocurado sector Posterior
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000016', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Obturación resina fotocurado sector Posterior Normas de auditoría: Se reconocerá en piezas permanentes posteriores previo diagnóstico pulpar.', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000016'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Obturación resina fotocurado sector Posterior', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000016'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000016' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.10', E'Obturación resina fotocurado sector Posterior', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000016'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2391', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000016'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '111164008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000016'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000016' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000016' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
-- DNT-PR-000017 :: 02.15 - Composite simple ( incluye fotocurado )
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000017', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Composite simple ( incluye fotocurado )', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000017'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Composite simple ( incluye fotocurado )', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000017'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000017' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.15', E'Composite simple ( incluye fotocurado )', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000017'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2391', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000017'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '111164008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000017'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000017' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000017' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
-- DNT-PR-000018 :: 02.16 - Composite compuesto ( incluye fotocurado )
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000018', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Composite compuesto ( incluye fotocurado )', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000018'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Composite compuesto ( incluye fotocurado )', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000018'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000018' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.16', E'Composite compuesto ( incluye fotocurado )', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000018'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2391', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000018'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '111164008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000018'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000018' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000018' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
-- DNT-PR-000019 :: 02.17 - Composite compuesto con tornillo en conducto
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000019', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Composite compuesto con tornillo en conducto', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000019'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Composite compuesto con tornillo en conducto', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000019'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000019' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.17', E'Composite compuesto con tornillo en conducto', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000019'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2951', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000019'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '111164008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000019'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000019' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000019' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000019' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000020 :: 02.15 F - Ferulización por causas periodontales
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000020', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Ferulización por causas periodontales Normas de auditoría: Se reconocerá con autorización previa, análisis de los factores traumatizantes, remitiéndose los elementos de juicio necesarios para su evaluación. Periodo de cobertura mínima de tres (3) años.', E'Cápitulo II - Operatoria Dental', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000020'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Ferulización por causas periodontales', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000020'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000020' AND cat.code = E'CAT-PERI'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'02.15 F', E'Ferulización por causas periodontales', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000020'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D4322', E'Periodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000020'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274438002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000020'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000020' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000020' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
-- DNT-PR-000021 :: 03.01 - Tratamiento de un conducto
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000021', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tratamiento de un conducto', E'Capítulo III - Endodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000021'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tratamiento de un conducto', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000021'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000021' AND cat.code = E'CAT-ENDO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'03.01', E'Tratamiento de un conducto', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000021'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D3310', E'Endodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000021'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '68673005', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000021'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000021' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000021' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000021' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000022 :: 03.02 - Tratamiento de dos conductos
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000022', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tratamiento de dos conductos', E'Capítulo III - Endodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000022'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tratamiento de dos conductos', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000022'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000022' AND cat.code = E'CAT-ENDO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'03.02', E'Tratamiento de dos conductos', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000022'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D3320', E'Endodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000022'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '68673005', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000022'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000022' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000022' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000022' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000023 :: 03.03 - Tratamiento de tres conductos
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000023', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tratamiento de tres conductos', E'Capítulo III - Endodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000023'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tratamiento de tres conductos', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000023'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000023' AND cat.code = E'CAT-ENDO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'03.03', E'Tratamiento de tres conductos', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000023'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D3330', E'Endodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000023'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '68673005', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000023'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000023' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000023' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000023' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000024 :: 03.04 - Tratamiento de cuatro conductos
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000024', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tratamiento de cuatro conductos', E'Capítulo III - Endodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000024'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tratamiento de cuatro conductos', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000024'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000024' AND cat.code = E'CAT-ENDO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'03.04', E'Tratamiento de cuatro conductos', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000024'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D3330', E'Endodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000024'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '68673005', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000024'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000024' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000024' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000024' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000025 :: 03.05 - Biopulpectomía parcial
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000025', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Biopulpectomía parcial Normas de auditoría: Cuando se realice esta práctica no se reconocerá otro tratamiento de endodoncia y su  correspondiente restauración coronaria hasta un año después de efectuada la misma, si  es realizado por el mismo profesional. Solamente para piezas con foramen apical abierto o en formación.', E'Capítulo III - Endodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000025'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Biopulpectomía parcial', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000025'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000025' AND cat.code = E'CAT-ENDO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'03.05', E'Biopulpectomía parcial', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000025'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D3220', E'Endodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000025'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234737002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000025'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000025' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000025' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000025' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000026 :: 03.06 - Necropulpectomía parcial ( momificación )
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000026', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Necropulpectomía parcial ( momificación ) Normas de auditoría: Se reconocerá solamente en dientes posteriores.', E'Capítulo III - Endodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000026'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Necropulpectomía parcial ( momificación )', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000026'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000026' AND cat.code = E'CAT-ENDO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'03.06', E'Necropulpectomía parcial ( momificación )', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000026'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D3221', E'Endodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000026'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234737002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000026'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000026' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000026' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000026' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000027 :: 04.01.01 - Incrustaciones:  cavidad simple
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000027', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Incrustaciones:  cavidad simple', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000027'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Incrustaciones:  cavidad simple', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000027'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000027' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.01', E'Incrustaciones:  cavidad simple', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000027'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2610', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000027'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '111163002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000027'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000027' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000027' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000027' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000027' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000028 :: 04.01.02 - Incrustaciones: cavidad compuesta o compleja
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000028', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Incrustaciones: cavidad compuesta o compleja', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000028'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Incrustaciones: cavidad compuesta o compleja', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000028'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000028' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.02', E'Incrustaciones: cavidad compuesta o compleja', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000028'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2620', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000028'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '111163002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000028'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000028' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000028' AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000028' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000028' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000029 :: 04.01.03 - Corona forjada
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000029', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corona forjada Normas de auditoría: No incluye corona provisoria. Para su reconocimiento deberá fundamentarse el motivo de su confección.', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000029'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corona forjada', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000029'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000029' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.03', E'Corona forjada', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000029'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2790', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000029'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '36830009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000029'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000029' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000029' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000029' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000030 :: 04.01.04 - Corona colada
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000030', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corona colada Normas de auditoría: No incluye corona provisoria.', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000030'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corona colada', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000030'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000030' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.04', E'Corona colada', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000030'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2790', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000030'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '36830009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000030'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000030' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000030' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000030' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000031 :: 04.01.05 - Corona colada con frente estético
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000031', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corona colada con frente estético Normas de auditoría: No incluye corona provisoria. Incluye la carilla de acrílico.', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000031'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corona colada con frente estético', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000031'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000031' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.05', E'Corona colada con frente estético', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000031'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2751', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000031'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '36830009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000031'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000031' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000031' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000031' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000032 :: 04.01.06 - Corona espiga
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000032', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corona espiga Normas de auditoría: Incluye pieza metálica y acrílico.', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000032'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corona espiga', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000032'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000032' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.06', E'Corona espiga', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000032'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2790', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000032'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '36830009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000032'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000032' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000032' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000032' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000033 :: 04.01.07 - Corona colada revestida en acrílico
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000033', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corona colada revestida en acrílico Normas de auditoría: No incluye corona provisoria. Incluye pieza metálica y acrílica y metálica.', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000033'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corona colada revestida en acrílico', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000033'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000033' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.07', E'Corona colada revestida en acrílico', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000033'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2751', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000033'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '36830009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000033'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000033' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000033' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000033' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000034 :: 04.01.07 bis - Corona colada revestida en porcelana
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000034', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corona colada revestida en porcelana', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000034'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corona colada revestida en porcelana', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000034'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000034' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.07 bis', E'Corona colada revestida en porcelana', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000034'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2740', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000034'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '36830009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000034'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000034' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000034' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000034' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000035 :: 04.01.07 bis i - Corona colada revestida en porcelana sobre implante
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000035', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corona colada revestida en porcelana sobre implante', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000035'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corona colada revestida en porcelana sobre implante', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000035'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000035' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.07 bis i', E'Corona colada revestida en porcelana sobre implante', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000035'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D6058', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000035'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '36830009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000035'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000035' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000035' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000035' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000036 :: 04.01.08 - Perno muñón simple
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000036', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Perno muñón simple Normas de auditoría: Para su reconocimiento podrá requerirse las radiografías pre y post-operatorias.', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000036'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Perno muñón simple', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000036'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000036' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.08', E'Perno muñón simple', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000036'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2952', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000036'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234736006', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000036'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000036' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000036' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000036' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000037 :: 04.01.08 i - Emergente o intermediario sobre implantes
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000037', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Emergente o intermediario sobre implantes', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000037'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Emergente o intermediario sobre implantes', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000037'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000037' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.08 i', E'Emergente o intermediario sobre implantes', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000037'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D6056', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000037'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234736006', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000037'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000037' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000037' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000037' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000038 :: 04.01.09 - Perno muñon seccionado
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000038', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Perno muñon seccionado Normas de auditoría: Para su reconocimiento podrá requerirse las radiografías pre y post-operatorias.', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000038'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Perno muñon seccionado', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000038'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000038' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.09', E'Perno muñon seccionado', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000038'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2952', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000038'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234736006', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000038'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000038' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000038' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000038' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000039 :: 04.01.10 - Tramo de puente colado
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000039', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tramo de puente colado Normas de auditoría: Incluye pieza metálica y acrílico.', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000039'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tramo de puente colado', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000039'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000039' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.10', E'Tramo de puente colado', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000039'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D6241', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000039'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274439005', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000039'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000039' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000039' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000039' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000040 :: 04.01.10 bis - Tramo puente colado ( porcelana )
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000040', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tramo puente colado ( porcelana )', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000040'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tramo puente colado ( porcelana )', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000040'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000040' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.10 bis', E'Tramo puente colado ( porcelana )', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000040'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D6240', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000040'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274439005', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000040'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000040' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000040' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000040' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000041 :: 04.01.11 - Corona de acrílico
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000041', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corona de acrílico Normas de auditoría: No incluye corona provisoria.', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000041'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corona de acrílico', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000041'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000041' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.11', E'Corona de acrílico', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000041'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2751', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000041'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '36830009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000041'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000041' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000041' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000041' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000042 :: 04.01.12 - Corona provisoria
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000042', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corona provisoria Normas de auditoría: Para su reconocimiento podrá requerirse su presentación.', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000042'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corona provisoria', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000042'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000042' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.12', E'Corona provisoria', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000042'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2799', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000042'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '36830009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000042'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000042' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000043 :: 04.01.12 i - Corona provisoria sobre implantes
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000043', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corona provisoria sobre implantes', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000043'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corona provisoria sobre implantes', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000043'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000043' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.12 i', E'Corona provisoria sobre implantes', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000043'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D6085', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000043'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '36830009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000043'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000043' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000044 :: 04.01.15 - Ataches
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000044', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Ataches', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000044'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Ataches', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000044'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000044' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.15', E'Ataches', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000044'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5862', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000044'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274439005', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000044'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000044' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000044' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000044' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000045 :: 04.01.16 - Poste bola
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000045', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Poste bola', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000045'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Poste bola', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000045'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000045' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.16', E'Poste bola', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000045'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5862', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000045'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274439005', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000045'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000045' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000045' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000045' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000046 :: 04.01.17 - Barra tangencial tipo Dolder
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000046', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Barra tangencial tipo Dolder', E'Capítulo IV – Prótesis Fija', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000046'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Barra tangencial tipo Dolder', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000046'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000046' AND cat.code = E'CAT-PROSTH-F'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.01.17', E'Barra tangencial tipo Dolder', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000046'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5862', E'Prótesis Fija', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000046'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274439005', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000046'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000046' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000046' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000046' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000047 :: 04.02.01 - De acrílico: hasta cuatro dientes
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000047', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'De acrílico: hasta cuatro dientes Normas de auditoría: Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.', E'Prótesis parcial removible', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000047'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'De acrílico: hasta cuatro dientes', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000047'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000047' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.02.01', E'De acrílico: hasta cuatro dientes', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000047'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5211', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000047'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000047'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000047' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000048 :: 04.02.02 - De acrílico: de cinco o más dientes
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000048', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'De acrílico: de cinco o más dientes Normas de auditoría: Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.', E'Prótesis parcial removible', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000048'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'De acrílico: de cinco o más dientes', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000048'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000048' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.02.02', E'De acrílico: de cinco o más dientes', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000048'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5211', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000048'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000048'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000048' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000049 :: 04.02.03 - Cromo cobalto: hasta cuatro dientes
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000049', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Cromo cobalto: hasta cuatro dientes Normas de auditoría: Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.', E'Prótesis parcial removible', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000049'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Cromo cobalto: hasta cuatro dientes', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000049'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000049' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.02.03', E'Cromo cobalto: hasta cuatro dientes', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000049'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5213', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000049'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000049'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000049' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000050 :: 04.02.04 - Cromo cobalto: de cinco o más dientes
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000050', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Cromo cobalto: de cinco o más dientes Normas de auditoría: Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.', E'Prótesis parcial removible', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000050'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Cromo cobalto: de cinco o más dientes', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000050'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000050' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.02.04', E'Cromo cobalto: de cinco o más dientes', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000050'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5213', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000050'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000050'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000050' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000051 :: 04.02.04 i - Cromo cobalto sobre implantes
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000051', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Cromo cobalto sobre implantes', E'Prótesis parcial removible', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000051'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Cromo cobalto sobre implantes', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000051'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000051' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.02.04 i', E'Cromo cobalto sobre implantes', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000051'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5213', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000051'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000051'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000051' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000052 :: 04.02.05 - Prótesis parcial inmediata ( temporaria )
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000052', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Prótesis parcial inmediata ( temporaria ) Normas de auditoría: Incluye cubeta individual, retenedores, cualquier número dientes, eventual rebasado y controles posteriores. No podrá reconocerse la facturación de la prótesis definitiva, hasta transcurridos seis meses de su instalación; con autorización previa de la Obra Social.', E'Prótesis parcial removible', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000052'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Prótesis parcial inmediata ( temporaria )', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000052'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000052' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.02.05', E'Prótesis parcial inmediata ( temporaria )', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000052'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5221', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000052'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000052'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000052' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000053 :: 04.02.05 i - Prótesis parcial inmediata ( temporaria ) sobre implantes
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000053', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Prótesis parcial inmediata ( temporaria ) sobre implantes', E'Prótesis parcial removible', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000053'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Prótesis parcial inmediata ( temporaria ) sobre implantes', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000053'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000053' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.02.05 i', E'Prótesis parcial inmediata ( temporaria ) sobre implantes', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000053'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5221', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000053'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000053'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000053' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000054 :: 04.03.01 - Superior
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000054', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Superior Normas de auditoría: Incluye las consultas posteriores a su instalación para los retoques necesarios.', E'Prótesis completa - 04.03', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000054'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Superior', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000054'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000054' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.03.01', E'Superior', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000054'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5110', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000054'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000054'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000054' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000055 :: 04.03.01 i - Superior sobre implantes
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000055', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Superior sobre implantes', E'Prótesis completa - 04.04', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000055'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Superior sobre implantes', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000055'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000055' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.03.01 i', E'Superior sobre implantes', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000055'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5110', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000055'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000055'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000055' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000056 :: 04.03.02 - Inferior
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000056', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Inferior Normas de auditoría: Incluye las consultas posteriores a su instalación para los retoques necesarios.', E'Prótesis completa - 04.05', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000056'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Inferior', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000056'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000056' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.03.02', E'Inferior', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000056'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5120', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000056'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000056'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000056' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000057 :: 04.03.02 i - Inferior sobre implantes
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000057', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Inferior sobre implantes', E'Prótesis completa - 04.06', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000057'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Inferior sobre implantes', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000057'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000057' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.03.02 i', E'Inferior sobre implantes', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000057'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5120', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000057'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000057'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000057' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000058 :: 04.03.03 - Prótesis completa inmediata ( temporaria )
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000058', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Prótesis completa inmediata ( temporaria ) Normas de auditoría: Incluye cubeta individual, eventual rebasado y controles posteriores a su instalación. No podrá reconocerse la facturación de la prótesis definitiva hasta transcurridos seis meses de su instalación; con autorización previa de la Obra Social.', E'Prótesis completa - 04.07', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000058'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Prótesis completa inmediata ( temporaria )', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000058'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000058' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.03.03', E'Prótesis completa inmediata ( temporaria )', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000058'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5130', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000058'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000058'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000058' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000059 :: 04.03.03 i - Prótesis completa inmediata sobre implantes ( temporaria )
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000059', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Prótesis completa inmediata sobre implantes ( temporaria )', E'Prótesis completa - 04.08', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000059'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Prótesis completa inmediata sobre implantes ( temporaria )', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000059'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000059' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.03.03 i', E'Prótesis completa inmediata sobre implantes ( temporaria )', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000059'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5130', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000059'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000059'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000059' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000060 :: 04.04.01 - Compostura simple
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000060', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Compostura simple', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000060'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Compostura simple', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000060'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000060' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.01', E'Compostura simple', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000060'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5611', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000060'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000060'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000061 :: 04.04.02 - Compostura con agregado de un diente
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000061', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Compostura con agregado de un diente', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000061'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Compostura con agregado de un diente', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000061'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000061' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.02', E'Compostura con agregado de un diente', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000061'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5640', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000061'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000061'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000061' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000062 :: 04.04.03 - Compostura con agregado de un retenedor
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000062', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Compostura con agregado de un retenedor', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000062'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Compostura con agregado de un retenedor', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000062'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000062' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.03', E'Compostura con agregado de un retenedor', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000062'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5630', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000062'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000062'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000062' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000063 :: 04.04.04 - Compostura simple con agregado de un diente y un retenedor
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000063', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Compostura simple con agregado de un diente y un retenedor', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000063'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Compostura simple con agregado de un diente y un retenedor', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000063'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000063' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.04', E'Compostura simple con agregado de un diente y un retenedor', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000063'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5640', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000063'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000063'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000063' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000064 :: 04.04.05 - Diente subsiguiente, c/u
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000064', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Diente subsiguiente, c/u', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000064'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Diente subsiguiente, c/u', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000064'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000064' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.05', E'Diente subsiguiente, c/u', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000064'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5211', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000064'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000064'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000064' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000065 :: 04.04.06 - Retenedor subsiguiente, c/u
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000065', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Retenedor subsiguiente, c/u', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000065'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Retenedor subsiguiente, c/u', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000065'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000065' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.06', E'Retenedor subsiguiente, c/u', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000065'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5211', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000065'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000065'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000065' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000066 :: 04.04.07 - Soldado de retención en aparatos de cromo
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000066', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Soldado de retención en aparatos de cromo Normas de auditoría: Incluye el montaje del diente artificial.', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000066'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Soldado de retención en aparatos de cromo', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000066'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000066' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.07', E'Soldado de retención en aparatos de cromo', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000066'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5621', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000066'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000066'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000066' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000067 :: 04.04.08 - Retención subsiguiente
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000067', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Retención subsiguiente', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000067'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Retención subsiguiente', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000067'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000067' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.08', E'Retención subsiguiente', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000067'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5211', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000067'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000067'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000067' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000068 :: 04.04.09 - Carilla de acrílico
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000068', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Carilla de acrílico', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000068'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Carilla de acrílico', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000068'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000068' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.09', E'Carilla de acrílico', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000068'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5611', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000068'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000068'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000068' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000069 :: 04.04.10 - Rebasado de prótesis, c/u
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000069', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Rebasado de prótesis, c/u', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000069'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Rebasado de prótesis, c/u', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000069'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000069' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.10', E'Rebasado de prótesis, c/u', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000069'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5750', E'Prótesis Parcial y Completa Removible', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000069'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274440007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000069'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000070 :: 04.04.11 - Cubeta individual
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000070', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Cubeta individual Normas de auditoría: Se reconocerá cuando se efectúe con acrílico termocurable, pudiendo requerirse su presentación para su reconocimiento.', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000070'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Cubeta individual', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000070'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000070' AND cat.code = E'CAT-PROSTH-R'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.11', E'Cubeta individual', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000070'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D5899', E'Prótesis Parcial y Completa Removible', E'related'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000070'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000071 :: 04.04.12 - Levante de articulación, en acrílico traslucido y retenedore
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000071', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Levante de articulación, en acrílico traslucido y retenedores forjados en acero. Normas de auditoría: Incluye cubeta individual y controles posteriores. Gramos estimados de los metales utilizados en las siguientes prácticas según código', E'Varios', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000071'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Levante de articulación, en acrílico traslucido y retenedores forjados en acero.', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000071'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000071' AND cat.code = E'CAT-ADJ'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'04.04.12', E'Levante de articulación, en acrílico traslucido y retenedores forjados en acero.', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000071'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D9944', E'Servicios Complementarios de Odontología', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000071'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274441006', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000071'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000072 :: 05.00 - Ficha de prevención.
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000072', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Ficha de prevención.', E'Capítulo V - Odontología Preventiva', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000072'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Ficha de prevención.', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000072'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000072' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'05.00', E'Ficha de prevención.', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000072'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0150', E'Diagnóstico y Exámenes Clínicos', E'related'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000072'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000073 :: 05.01 - Tartrectomía y cepillado mecánico
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000073', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tartrectomía y cepillado mecánico Normas de auditoría: No incluye blanqueamiento de piezas dentarias.  Se cubre una vez por año a pacientes mayores de 18 años.', E'Capítulo V - Odontología Preventiva', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000073'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tartrectomía y cepillado mecánico', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000073'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000073' AND cat.code = E'CAT-PREV'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'05.01', E'Tartrectomía y cepillado mecánico', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000073'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D1110', E'Odontología Preventiva', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000073'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '22769002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000073'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000074 :: 05.02 - Aplicación de fluor, incluye cepillado previo y tartrectomía
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000074', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Aplicación de fluor, incluye cepillado previo y tartrectomía Normas de auditoría: Incluye Tartrectomía y cepillado mecánico, detección y control de placa bacteriana,  enseñanza de técnicas de higiene. Comprende aplicación de flúor tópico, barniz y  colutorios. O sea, incluye código 05.04.  Se cubrirá hasta los 18 años y semestralmente.', E'Capítulo V - Odontología Preventiva', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000074'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Aplicación de fluor, incluye cepillado previo y tartrectomía', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000074'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000074' AND cat.code = E'CAT-PREV'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'05.02', E'Aplicación de fluor, incluye cepillado previo y tartrectomía', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000074'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D1206', E'Odontología Preventiva', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000074'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '110462007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000074'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000075 :: 05.03 - Detección de placa bacteriana y test de susceptibilidad de c
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000075', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Detección de placa bacteriana y test de susceptibilidad de caries', E'Capítulo V - Odontología Preventiva', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000075'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Detección de placa bacteriana y test de susceptibilidad de caries', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000075'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000075' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'05.03', E'Detección de placa bacteriana y test de susceptibilidad de caries', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000075'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0425', E'Diagnóstico y Exámenes Clínicos', E'related'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000075'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000076 :: 05.04 - Enseñanzas de técnicas de higiene bucal.Incluye control de p
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000076', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Enseñanzas de técnicas de higiene bucal.Incluye control de placa y test de suscep. Normas de auditoría: Incluye detección de placa bacteriana y enseñanza de técnica de higiene bucal.  Comprende uso de elementos como interdentarios, asesoramiento dietético y revelado  de placa, se aplica en mayores de 18 años.', E'Capítulo V - Odontología Preventiva', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000076'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Enseñanzas de técnicas de higiene bucal.Incluye control de placa y test de suscep.', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000076'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000076' AND cat.code = E'CAT-PREV'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'05.04', E'Enseñanzas de técnicas de higiene bucal.Incluye control de placa y test de suscep.', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000076'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D1330', E'Odontología Preventiva', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000076'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399047006', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000076'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000077 :: 05.05 - Sellantes de puntos y fisuras
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000077', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Sellantes de puntos y fisuras Normas de auditoría: Se reconoce hasta los 15 años en premolares y molares permanentes enteros con un  período de responsabilidad de dos años, no pudiendo facturar el mismo profesional prestador obturaciones ni extracciones de las piezas tratadas en dicho período de  tiempo. No se acepta en caras libres.', E'Capítulo V - Odontología Preventiva', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000077'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Sellantes de puntos y fisuras', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000077'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000077' AND cat.code = E'CAT-PREV'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'05.05', E'Sellantes de puntos y fisuras', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000077'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D1351', E'Odontología Preventiva', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000077'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234735005', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000077'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000077' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000078 :: 05.06 - Aplicación de cariostáticos en piezas dentarias permanentes
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000078', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Aplicación de cariostáticos en piezas dentarias permanentes Normas de auditoría: Se cubrirá para aquellos casos que sea necesario curar infección de ulceras,  estabilización de procesos de destrucción, mineralización, etc. Se contempla en piezas  permanentes, hasta una vez por año por pieza (incluye las aplicaciones necesarias),  aclarando diagnóstico.', E'Capítulo V - Odontología Preventiva', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000078'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Aplicación de cariostáticos en piezas dentarias permanentes', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000078'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000078' AND cat.code = E'CAT-PREV'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'05.06', E'Aplicación de cariostáticos en piezas dentarias permanentes', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000078'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D1354', E'Odontología Preventiva', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000078'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '713601007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000078'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000078' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000079 :: 06.01 - Consulta de estudio
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000079', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Consulta de estudio', E'Capítulo VI - Ortodoncia y ortopedia funcional', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000079'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Consulta de estudio', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000079'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000079' AND cat.code = E'CAT-ORTHO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'06.01', E'Consulta de estudio', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000079'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D8660', E'Ortodoncia y Ortopedia Funcional', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000079'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '401267008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000079'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000080 :: 06.02 - Tratamiento de la dentición primaria o mixta *
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000080', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tratamiento de la dentición primaria o mixta *', E'Capítulo VI - Ortodoncia y ortopedia funcional', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000080'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tratamiento de la dentición primaria o mixta *', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000080'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000080' AND cat.code = E'CAT-ORTHO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'06.02', E'Tratamiento de la dentición primaria o mixta *', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000080'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D8020', E'Ortodoncia y Ortopedia Funcional', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000080'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '401267008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000080'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000081 :: 06.03 - Tratamiento de la dentición permanente *
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000081', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tratamiento de la dentición permanente *', E'Capítulo VI - Ortodoncia y ortopedia funcional', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000081'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tratamiento de la dentición permanente *', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000081'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000081' AND cat.code = E'CAT-ORTHO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'06.03', E'Tratamiento de la dentición permanente *', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000081'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D8080', E'Ortodoncia y Ortopedia Funcional', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000081'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '401267008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000081'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000082 :: 06.04 - Corrección de malposiciones simples con espacio
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000082', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corrección de malposiciones simples con espacio', E'Capítulo VI - Ortodoncia y ortopedia funcional', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000082'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corrección de malposiciones simples con espacio', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000082'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000082' AND cat.code = E'CAT-ORTHO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'06.04', E'Corrección de malposiciones simples con espacio', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000082'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D8050', E'Ortodoncia y Ortopedia Funcional', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000082'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '401267008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000082'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000083 :: 06.05 - Tratamiento de la dentición permanente: hemi - arcada.
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000083', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tratamiento de la dentición permanente: hemi - arcada.', E'Capítulo VI - Ortodoncia y ortopedia funcional', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000083'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tratamiento de la dentición permanente: hemi - arcada.', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000083'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000083' AND cat.code = E'CAT-ORTHO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'06.05', E'Tratamiento de la dentición permanente: hemi - arcada.', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000083'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D8080', E'Ortodoncia y Ortopedia Funcional', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000083'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '401267008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000083'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000084 :: 07.01 - Motivación ( hasta 3 consultas ) Incluye 1ra y ficha hasta 1
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000084', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Motivación ( hasta 3 consultas ) Incluye 1ra y ficha hasta 13 años Normas de auditoría: Se reconocerán hasta los 13 años de edad. Incluye 01.01 y comprende hasta tres visitas  al consultorio', E'Capítulo VII - Odontopediatría', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000084'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Motivación ( hasta 3 consultas ) Incluye 1ra y ficha hasta 13 años', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000084'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000084' AND cat.code = E'CAT-PREV'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'07.01', E'Motivación ( hasta 3 consultas ) Incluye 1ra y ficha hasta 13 años', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000084'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0145', E'Odontología Preventiva', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000084'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399120002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000084'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000085 :: 07.02 - Mantenedor de espacio fijo
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000085', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Mantenedor de espacio fijo Normas de auditoría: Incluye corona en pieza dentaria y ansa de alambre de apoyo. Deberá acompañar  radiografía post-operatoria. Se cubre por única vez y en pacientes hasta 8 años de  edad. Requiere autorización previa.', E'Capítulo VII - Odontopediatría', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000085'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Mantenedor de espacio fijo', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000085'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000085' AND cat.code = E'CAT-PREV'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'07.02', E'Mantenedor de espacio fijo', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000085'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D1510', E'Odontología Preventiva', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000085'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274437007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000085'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000085' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000085' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000086 :: 07.03 - Mantenedor de espacio removible
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000086', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Mantenedor de espacio removible Normas de auditoría: Se reconocerá cuando falten dos o más dientes primarios contiguos o más de dos  dientes alternados en la misma arcada dental. Se cubre por única vez y en pacientes  hasta 8 años de edad. Requiere autorización previa.', E'Capítulo VII - Odontopediatría', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000086'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Mantenedor de espacio removible', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000086'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000086' AND cat.code = E'CAT-PREV'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'07.03', E'Mantenedor de espacio removible', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000086'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D1520', E'Odontología Preventiva', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000086'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274437007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000086'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000086' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000087 :: 07.04 - Tratamiento de dientes primarios con formocresol
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000087', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tratamiento de dientes primarios con formocresol Normas de auditoría: Se reconoce con radiografía post-operatoria, y cuando el diente tratado no se encuentre  en período de exfoliación normal.', E'Capítulo VII - Odontopediatría', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000087'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tratamiento de dientes primarios con formocresol', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000087'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000087' AND cat.code = E'CAT-ENDO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'07.04', E'Tratamiento de dientes primarios con formocresol', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000087'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D3220', E'Endodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000087'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234737002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000087'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000087' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000087' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000088 :: 07.05 - Corona de acero y similares
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000088', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Corona de acero y similares Normas de auditoría: Se reconocerá en dientes primarios con gran destrucción coronaria y que no se  encuentre en período de exfoliación normal. Incluye toda obturación realizada por el  mismo profesional y deberá acompañar radiografía post-operatoria. En primeros  molares permanentes hasta los 15 años de edad. Requiere autorización previa.', E'Capítulo VII - Odontopediatría', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000088'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Corona de acero y similares', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000088'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000088' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'07.05', E'Corona de acero y similares', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000088'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2930', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000088'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '36830009', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000088'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000088' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000088' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000089 :: 07.06.01 - Reducción de luxación con inmovilización dentaria
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000089', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Reducción de luxación con inmovilización dentaria', E'Odontopediatría (Traumatismos dentarios)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000089'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Reducción de luxación con inmovilización dentaria', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000089'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000089' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'07.06.01', E'Reducción de luxación con inmovilización dentaria', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000089'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7270', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000089'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000089'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000089' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000089' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000090 :: 07.06.02 - Luxación total ( reimplante ) o inmovilización dentaria
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000090', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Luxación total ( reimplante ) o inmovilización dentaria Normas de auditoría: No incluye el tratamiento endodónticos.', E'Odontopediatría (Traumatismos dentarios)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000090'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Luxación total ( reimplante ) o inmovilización dentaria', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000090'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000090' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'07.06.02', E'Luxación total ( reimplante ) o inmovilización dentaria', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000090'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7270', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000090'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000090'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000090' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000090' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000091 :: 07.06.04 - Fractura amelodentinaria, protección pulpar con coronas prov
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000091', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Fractura amelodentinaria, protección pulpar con coronas provisorias Normas de auditoría: Incluye corona provisoria y se reconocerá con Rx pre y post operatoria.', E'Odontopediatría (Traumatismos dentarios)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000091'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Fractura amelodentinaria, protección pulpar con coronas provisorias', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000091'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000091' AND cat.code = E'CAT-REST'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'07.06.04', E'Fractura amelodentinaria, protección pulpar con coronas provisorias', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000091'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D2970', E'Operatoria Dental y Restauradora', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000091'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '111164008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000091'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000091' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000091' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000091' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000092 :: 07.07 - Protección pulpar directa
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000092', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Protección pulpar directa Normas de auditoría: Se reconoce en piezas molares permanentes con Rx post-operatoria incluida en valor de  la prestación. Por el término de seis (6) meses no se reconocerá otro tratamiento pulpar.  Se aplica hasta los 18 años.', E'Odontopediatría (Traumatismos dentarios)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000092'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Protección pulpar directa', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000092'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000092' AND cat.code = E'CAT-ENDO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'07.07', E'Protección pulpar directa', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000092'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D3110', E'Endodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000092'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234737002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000092'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000092' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000092' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000093 :: 07.08 - Aplicación de cariostáticos
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000093', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Aplicación de cariostáticos Normas de auditoría: Se aplicará ante la presencia de caries rampantes en dientes temporarios, por única  vez y hasta los seis (6) años.', E'Odontopediatría (Traumatismos dentarios)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000093'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Aplicación de cariostáticos', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000093'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000093' AND cat.code = E'CAT-PREV'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'07.08', E'Aplicación de cariostáticos', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000093'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D1354', E'Odontología Preventiva', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000093'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '713601007', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000093'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000093' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000093' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000094 :: 08.01 - Consulta de estudio-Diagnóstico-Pronóstico
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000094', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Consulta de estudio-Diagnóstico-Pronóstico Normas de auditoría: Incluye la confección de la ficha periodontal respectiva (de acuerdo al modelo que se  adopte), la cual deberá acompañar a los códigos 08.03. y 08.04. Se reconocerá una vez  cada dos años e incluye código 0101.', E'Capítulo VIII - Periodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000094'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Consulta de estudio-Diagnóstico-Pronóstico', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000094'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000094' AND cat.code = E'CAT-PERI'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'08.01', E'Consulta de estudio-Diagnóstico-Pronóstico', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000094'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0180', E'Periodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000094'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '424759004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000094'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000095 :: 08.02 - Tratamiento de gingivitis, marginal crónica
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000095', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tratamiento de gingivitis, marginal crónica Normas de auditoría: Comprende todos los cuadros gingivales cualquiera fuese su etiología. Incluye Tartrectomía, raspado, control de placas, enseñanza de cepillado y FLUOR ambas  arcadas. Como única patología se reconocerá una vez por año. Cuando en la ficha  periodontal correspondiente a los códigos 08.03. y 08.04.; se señale esta patología en  otros sectores de la boca, se podrá sumar este código para el resto de las piezas.', E'Capítulo VIII - Periodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000095'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tratamiento de gingivitis, marginal crónica', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000095'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000095' AND cat.code = E'CAT-PERI'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'08.02', E'Tratamiento de gingivitis, marginal crónica', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000095'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D4346', E'Periodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000095'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '110463002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000095'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000096 :: 08.03 - Trat. periodontitis destructiva leve o mod. Bolsas hasta  5m
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000096', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Trat. periodontitis destructiva leve o mod. Bolsas hasta  5mm por sector (6 sec) Normas de auditoría: En bolsas de hasta 5 mm., pérdida ósea alveolar de hasta 2/3 de la raíz, por sector.  Incluye 05.01; 05.04; 08.02 y 08.05 alisado radicular eventual gingivectomía o colgajo.  Periodo de cobertura: 2 años, excepto casos especiales a considerar por auditoria.  Mínimo de cuatro (4) piezas por sector. Se reconocerá con Radiografías preoperatorias y ficha periodontal debidamente  confeccionada', E'Capítulo VIII - Periodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000096'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Trat. periodontitis destructiva leve o mod. Bolsas hasta  5mm por sector (6 sec)', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000096'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000096' AND cat.code = E'CAT-PERI'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'08.03', E'Trat. periodontitis destructiva leve o mod. Bolsas hasta  5mm por sector (6 sec)', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000096'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D4341', E'Periodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000096'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '110463002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000096'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000096' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000097 :: 08.04 - Trat. periodontitis destructiva severa. Bolsas de 6mm o más.
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000097', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Trat. periodontitis destructiva severa. Bolsas de 6mm o más. Por sector (6 sec) Normas de auditoría: En bolsas de 6 mm. o más, pérdida ósea alveolar de más de 2/3 y/o lesión de  furcación en grados 3 y 4 , por sector. Incluye 05.01; 05.04 ; 08.02, 08.03 y 08.05 más eventual cirugía mucogingival e  injerto.  Periodo de cobertura: 2 años., excepto casos especiales a considerar por auditoria.  Mínimo cuatro (4) piezas por sector. Se reconocerá con Radiografías preoperatorias y ficha periodontal debidamente  confeccionada', E'Capítulo VIII - Periodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000097'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Trat. periodontitis destructiva severa. Bolsas de 6mm o más. Por sector (6 sec)', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000097'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000097' AND cat.code = E'CAT-PERI'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'08.04', E'Trat. periodontitis destructiva severa. Bolsas de 6mm o más. Por sector (6 sec)', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000097'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D4260', E'Periodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000097'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234740008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000097'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000097' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000098 :: 08.04 C - Cirugía Periodontal
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000098', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Cirugía Periodontal', E'Capítulo VIII - Periodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000098'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Cirugía Periodontal', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000098'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000098' AND cat.code = E'CAT-PERI'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'08.04 C', E'Cirugía Periodontal', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000098'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D4210', E'Periodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000098'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234740008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000098'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000098' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000098' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000099 :: 08.05 - Desgaste selectivo o armonización oclusal
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000099', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Desgaste selectivo o armonización oclusal Normas de auditoría: Se reconocerá cuando se detalle el estudio de la oclusión y el análisis de los factores  traumatizantes, remitiendo los elementos de juicio necesarios para su evaluación.', E'Capítulo VIII - Periodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000099'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Desgaste selectivo o armonización oclusal', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000099'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000099' AND cat.code = E'CAT-PERI'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'08.05', E'Desgaste selectivo o armonización oclusal', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000099'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D9951', E'Periodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000099'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274441006', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000099'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000100 :: 08.05.01 - ATM. y bruxismo, terapia farmacológica y fisioterapia.
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000100', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'ATM. y bruxismo, terapia farmacológica y fisioterapia.', E'Capítulo VIII - Periodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000100'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'ATM. y bruxismo, terapia farmacológica y fisioterapia.', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000100'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000100' AND cat.code = E'CAT-ADJ'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'08.05.01', E'ATM. y bruxismo, terapia farmacológica y fisioterapia.', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000100'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7880', E'Servicios Complementarios de Odontología', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000100'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274441006', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000100'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000101 :: 08.05.02 - Aparato de estabilización oclusal y en relación céntrica.
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000101', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Aparato de estabilización oclusal y en relación céntrica.', E'Capítulo VIII - Periodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000101'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Aparato de estabilización oclusal y en relación céntrica.', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000101'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000101' AND cat.code = E'CAT-ADJ'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'08.05.02', E'Aparato de estabilización oclusal y en relación céntrica.', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000101'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7880', E'Servicios Complementarios de Odontología', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000101'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274441006', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000101'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000102 :: 08.05.03 - Aparato oclusal pivotante.
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000102', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Aparato oclusal pivotante.', E'Capítulo VIII - Periodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000102'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Aparato oclusal pivotante.', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000102'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000102' AND cat.code = E'CAT-ADJ'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'08.05.03', E'Aparato oclusal pivotante.', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000102'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7880', E'Servicios Complementarios de Odontología', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000102'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274441006', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000102'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000103 :: 08.06 - Placas oclusales ( temporarias ) removibles de acrílico, cua
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000103', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Placas oclusales ( temporarias ) removibles de acrílico, cualquier tipo', E'Capítulo VIII - Periodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000103'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Placas oclusales ( temporarias ) removibles de acrílico, cualquier tipo', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000103'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000103' AND cat.code = E'CAT-ADJ'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'08.06', E'Placas oclusales ( temporarias ) removibles de acrílico, cualquier tipo', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000103'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D9944', E'Servicios Complementarios de Odontología', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000103'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '274441006', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000103'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000104 :: 08.07 - Mantenimiento de tratamiento periodontal
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000104', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Mantenimiento de tratamiento periodontal Normas de auditoría: Se reconocerá cada seis (6) meses siempre que exista tratamiento previo de 08.03 u  08.04, y con el mismo profesional. Incluye 05.01; 05.04 y 08.02', E'Capítulo VIII - Periodoncia', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000104'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Mantenimiento de tratamiento periodontal', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000104'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000104' AND cat.code = E'CAT-PERI'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'08.07', E'Mantenimiento de tratamiento periodontal', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000104'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D4910', E'Periodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000104'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '110463002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000104'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000105 :: 09.01.01 - Periapical, técnicas de cono corto o cono largo
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000105', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Periapical, técnicas de cono corto o cono largo Normas de auditoría: Se admite como máximo cuatro veces la suma. De cinco a siete películas se facturará como  código 09.01.04., de ocho a nueve películas se facturará como código 09.01.04., más una o dos  veces el código 09.01.01. según corresponda. De diez a catorce películas se facturará como código 09.01. 05.', E'Capítulo IX – Radiología (Intraorales – 09.01)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000105'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Periapical, técnicas de cono corto o cono largo', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000105'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000105' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.01.01', E'Periapical, técnicas de cono corto o cono largo', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000105'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0220', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000105'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000105'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000106 :: 09.01.02 - Bite-Wing
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000106', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Bite-Wing', E'Capítulo IX – Radiología (Intraorales – 09.01)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000106'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Bite-Wing', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000106'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000106' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.01.02', E'Bite-Wing', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000106'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0272', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000106'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000106'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000107 :: 09.01.03 - Oclusal de 6 x 8 cm.
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000107', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Oclusal de 6 x 8 cm.', E'Capítulo IX – Radiología (Intraorales – 09.01)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000107'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Oclusal de 6 x 8 cm.', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000107'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000107' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.01.03', E'Oclusal de 6 x 8 cm.', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000107'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0240', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000107'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000107'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000108 :: 09.01.04 - Media seriada: 7 películas- Técnicas de cono corto o largo
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000108', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Media seriada: 7 películas- Técnicas de cono corto o largo Normas de auditoría: Se reconocerá cuando la integren siete películas.', E'Capítulo IX – Radiología (Intraorales – 09.01)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000108'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Media seriada: 7 películas- Técnicas de cono corto o largo', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000108'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000108' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.01.04', E'Media seriada: 7 películas- Técnicas de cono corto o largo', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000108'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0210', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000108'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000108'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000109 :: 09.01.05 - Seriada de 14 péliculas- técnicas de cono corto o largo
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000109', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Seriada de 14 péliculas- técnicas de cono corto o largo Normas de auditoría: Se reconocerá cuando la integren 14 películas.', E'Capítulo IX – Radiología (Intraorales – 09.01)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000109'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Seriada de 14 péliculas- técnicas de cono corto o largo', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000109'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000109' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.01.05', E'Seriada de 14 péliculas- técnicas de cono corto o largo', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000109'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0210', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000109'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000109'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000110 :: 09.02.01 - Extraorales: primera exposición
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000110', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Extraorales: primera exposición Normas de auditoría: Comprende todas las radiografías extraorales de la especialidad, exceptuadas las  señaladas con los códigos 09.02.03., 09.02.04., 09.02.05 y 09.02.06.', E'Capítulo IX – Radiología (Extraorales – 09.02)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000110'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Extraorales: primera exposición', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000110'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000110' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.02.01', E'Extraorales: primera exposición', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000110'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0250', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000110'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000110'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000111 :: 09.02.02 - Extraorales: por exposición subsiguiente
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000111', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Extraorales: por exposición subsiguiente Normas de auditoría: Comprende todas las radiografías extraorales de la especialidad, 09.02.05 y 09.02.06.', E'Capítulo IX – Radiología (Extraorales – 09.02)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000111'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Extraorales: por exposición subsiguiente', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000111'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000111' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.02.02', E'Extraorales: por exposición subsiguiente', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000111'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0250', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000111'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000111'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000112 :: 09.02.03 - Articulación Temporo-maxilar ( 6 tomas )
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000112', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Articulación Temporo-maxilar ( 6 tomas ) Normas de auditoría: Técnica de Schuller Modificada. Incluye seis tomas comparativas, tres por lado.', E'Capítulo IX – Radiología (Extraorales – 09.02)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000112'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Articulación Temporo-maxilar ( 6 tomas )', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000112'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000112' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.02.03', E'Articulación Temporo-maxilar ( 6 tomas )', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000112'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0320', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000112'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000112'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000113 :: 09.02.04 - Pantomografía ( radiografícas panorámicas )
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000113', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Pantomografía ( radiografícas panorámicas ) Normas de auditoría: Radiografía panorámica. Es el estudio panorámico de la cavidad bucal y zonas vecinas.', E'Capítulo IX – Radiología (Extraorales – 09.02)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000113'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Pantomografía ( radiografícas panorámicas )', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000113'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000113' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.02.04', E'Pantomografía ( radiografícas panorámicas )', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000113'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0330', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000113'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000113'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000114 :: 09.02.05 - Telerradiografía cefalométrica
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000114', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Telerradiografía cefalométrica', E'Capítulo IX – Radiología (Extraorales – 09.02)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000114'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Telerradiografía cefalométrica', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000114'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000114' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.02.05', E'Telerradiografía cefalométrica', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000114'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0340', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000114'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000114'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000115 :: 09.02.05 bis - Estudio o trazado cefalométrico
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000115', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Estudio o trazado cefalométrico', E'Capítulo IX – Radiología (Extraorales – 09.02)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000115'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Estudio o trazado cefalométrico', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000115'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000115' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.02.05 bis', E'Estudio o trazado cefalométrico', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000115'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0340', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000115'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000115'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000116 :: 09.02.06 - Sialografía
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000116', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Sialografía Normas de auditoría: No incluye la sustancia de contraste. Comprende el estudio con un mínimo de tres placas,  por glándula y por lado.', E'Capítulo IX – Radiología (Extraorales – 09.02)', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000116'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Sialografía', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000116'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000116' AND cat.code = E'CAT-DIAG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'09.02.06', E'Sialografía', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000116'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D0310', E'Diagnóstico y Exámenes Clínicos', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000116'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '399195000', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000116'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000117 :: 10.01 - Extracción dentaria
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000117', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Extracción dentaria Normas de auditoría: No se contempla su cobertura en piezas temporarias en su periodo de exfoliación.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000117'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Extracción dentaria', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000117'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000117' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.01', E'Extracción dentaria', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000117'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7140', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000117'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000117'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000117' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000118 :: 10.02 - Plástica de comunicación buco-sinusal como riesgo previsto s
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000118', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Plástica de comunicación buco-sinusal como riesgo previsto simultáneo a la extracción Normas de auditoría: Para su reconocimiento deberá acompañarse la radiografía preoperatoria que justifique  la realización de la práctica.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000118'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Plástica de comunicación buco-sinusal como riesgo previsto simultáneo a la extracción', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000118'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000118' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.02', E'Plástica de comunicación buco-sinusal como riesgo previsto simultáneo a la extracción', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000118'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7260', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000118'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000118'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000118' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000119 :: 10.03 - Biopsia por punción o aspiración
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000119', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Biopsia por punción o aspiración Normas de auditoría: No incluye el estudio Anatomopatológico.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000119'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Biopsia por punción o aspiración', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000119'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000119' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.03', E'Biopsia por punción o aspiración', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000119'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7285', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000119'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000119'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000120 :: 10.04 - Alveolectomia estabilizadora ( 6 zonas ): por zona
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000120', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Alveolectomia estabilizadora ( 6 zonas ): por zona Normas de auditoría: Podrá requerir autorización previa.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000120'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Alveolectomia estabilizadora ( 6 zonas ): por zona', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000120'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000120' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.04', E'Alveolectomia estabilizadora ( 6 zonas ): por zona', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000120'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7310', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000120'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000120'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000121 :: 10.05 - Reimplante dentario inmediato al traumatismo
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000121', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Reimplante dentario inmediato al traumatismo Normas de auditoría: Se reconoce con radiografía post-operatoria.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000121'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Reimplante dentario inmediato al traumatismo', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000121'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000121' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.05', E'Reimplante dentario inmediato al traumatismo', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000121'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7270', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000121'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000121'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000121' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000121' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000122 :: 10.06 - Incisión y drenaje de abscesos por via intrabucal
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000122', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Incisión y drenaje de abscesos por via intrabucal', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000122'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Incisión y drenaje de abscesos por via intrabucal', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000122'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000122' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.06', E'Incisión y drenaje de abscesos por via intrabucal', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000122'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7510', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000122'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000122'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000123 :: 10.07 - Biopsia por escisión
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000123', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Biopsia por escisión Normas de auditoría: No incluye el estudio Anatomopatológico.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000123'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Biopsia por escisión', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000123'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000123' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.07', E'Biopsia por escisión', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000123'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7286', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000123'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000123'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000124 :: 10.08 - Alargamiento quirúrgico de la corona clínica
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000124', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Alargamiento quirúrgico de la corona clínica Normas de auditoría: Se reconoce solo asociado a práctica de la misma facturación.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000124'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Alargamiento quirúrgico de la corona clínica', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000124'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000124' AND cat.code = E'CAT-PERI'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.08', E'Alargamiento quirúrgico de la corona clínica', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000124'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D4249', E'Periodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000124'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234740008', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000124'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000124' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
-- DNT-PR-000125 :: 10.09 - Extracción de dientes retenidos o restos radiculares retenid
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000125', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Extracción de dientes retenidos o restos radiculares retenidos Normas de auditoría: Se reconocerá con radiografía pre y post-operatoria.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000125'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Extracción de dientes retenidos o restos radiculares retenidos', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000125'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000125' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.09', E'Extracción de dientes retenidos o restos radiculares retenidos', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000125'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7210', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000125'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000125'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000125' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000125' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000125' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000126 :: 10.10 - Germectomía
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000126', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Germectomía Normas de auditoría: Se reconocerá con radiografía pre y post-operatoria. Podrá requerirse autorización previa.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000126'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Germectomía', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000126'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000126' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.10', E'Germectomía', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000126'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7251', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000126'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000126'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000126' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000126' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000127 :: 10.11 - Libreración de dientes retenidos
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000127', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Libreración de dientes retenidos Normas de auditoría: Se reconocerá con radiografía pre-operatoria y post-operatoria.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000127'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Libreración de dientes retenidos', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000127'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000127' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.11', E'Libreración de dientes retenidos', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000127'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7280', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000127'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000127'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000127' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000127' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000127' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000128 :: 10.12 - Apicectomía
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000128', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Apicectomía Normas de auditoría: Se reconocerá con radiografía pre y post-operatoria.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000128'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Apicectomía', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000128'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000128' AND cat.code = E'CAT-ENDO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.12', E'Apicectomía', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000128'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D3410', E'Endodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000128'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234737002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000128'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000128' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000128' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000129 :: 10.13 - Tratamiento de osteomielitis
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000129', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Tratamiento de osteomielitis', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000129'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Tratamiento de osteomielitis', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000129'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000129' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.13', E'Tratamiento de osteomielitis', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000129'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7440', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000129'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000129'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000129' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000129' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000130 :: 10.14 - Extracción de cuerpo extraño
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000130', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Extracción de cuerpo extraño Normas de auditoría: Se reconocerá con radiografía pre y post-operatoria.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000130'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Extracción de cuerpo extraño', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000130'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000130' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.14', E'Extracción de cuerpo extraño', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000130'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7530', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000130'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000130'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000130' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000130' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000131 :: 10.15 - Alveolectomía correctiva( 6 zonas ): por zona
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000131', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Alveolectomía correctiva( 6 zonas ): por zona Normas de auditoría: Se reconocerá con radiografía pre y post-operatoria.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000131'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Alveolectomía correctiva( 6 zonas ): por zona', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000131'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000131' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.15', E'Alveolectomía correctiva( 6 zonas ): por zona', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000131'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7310', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000131'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000131'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000131' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000131' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000132 :: 10.16 - Frenectomía
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000132', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Frenectomía', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000132'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Frenectomía', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000132'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000132' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.16', E'Frenectomía', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000132'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7961', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000132'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000132'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000133 :: 10.17 - Radectomía
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000133', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Radectomía', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000133'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Radectomía', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000133'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000133' AND cat.code = E'CAT-ENDO'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.17', E'Radectomía', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000133'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D3920', E'Endodoncia', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000133'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234737002', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000133'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000133' AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000133' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000133' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000134 :: 10.18 - Extracción por alveolectomía externa (complicación de extrac
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000134', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Extracción por alveolectomía externa (complicación de extracción).', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000134'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Extracción por alveolectomía externa (complicación de extracción).', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000134'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000134' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.18', E'Extracción por alveolectomía externa (complicación de extracción).', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000134'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7210', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000134'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000134'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000135 :: 10.19 - Extracción de dientes en retención ósea.
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000135', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Extracción de dientes en retención ósea.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000135'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Extracción de dientes en retención ósea.', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000135'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000135' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.19', E'Extracción de dientes en retención ósea.', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000135'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7240', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000135'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000135'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000136 :: 10.20 - Sutura de encías como tratamiento de lesión traumática.
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000136', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Sutura de encías como tratamiento de lesión traumática.', E'Capítulo X - Cirugía Bucal', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000136'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Sutura de encías como tratamiento de lesión traumática.', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000136'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000136' AND cat.code = E'CAT-SURG'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'10.20', E'Sutura de encías como tratamiento de lesión traumática.', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000136'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D7910', E'Cirugía Bucal y Maxilofacial', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000136'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234744004', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000136'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- DNT-PR-000137 :: 11.01.01 - Implante dentario
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000137', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Implante dentario', E'Capítulo XI – Implantes', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000137'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Implante dentario', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000137'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000137' AND cat.code = E'CAT-IMPL'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'11.01.01', E'Implante dentario', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000137'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D6010', E'Implantología Odontológica', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000137'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234745003', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000137'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000137' AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;
INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000137' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;
-- DNT-PR-000138 :: 11.02 - Relleno óseo
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES (E'DNT-PR-000138', 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, E'Relleno óseo', E'Capítulo XI – Implantes', 'approved'
FROM dentar_concept WHERE code = E'DNT-PR-000138'
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', E'Relleno óseo', 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000138'
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = E'DNT-PR-000138' AND cat.code = E'CAT-IMPL'
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', E'11.02', E'Relleno óseo', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000138'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', E'D6104', E'Implantología Odontológica', E'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000138'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '234745003', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = E'DNT-PR-000138'
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = E'DNT-PR-000138' AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;

-- =============================================================================
-- 7. MÓDULO DE DIAGNÓSTICOS ODONTOLÓGICOS (CIE-10 BLOQUE K00–K14)
-- =============================================================================
CREATE TABLE IF NOT EXISTS dentar_diagnosis (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL DEFAULT dentar_catalog_id('dentar-dx') REFERENCES dentar_catalog(id),
    code VARCHAR(30) NOT NULL UNIQUE,              -- Ej: 'DNT-DX-0000001'
    clinical_name VARCHAR(500) NOT NULL,
    category_id INT REFERENCES dentar_category(id),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'retired')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dentar_diagnosis_version (
    id SERIAL PRIMARY KEY,
    diagnosis_id INT NOT NULL REFERENCES dentar_diagnosis(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    definition TEXT,
    clinical_criteria TEXT,
    approval_status VARCHAR(20) NOT NULL DEFAULT 'approved' CHECK (approval_status IN ('draft','review','approved','rejected')),
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (diagnosis_id, version_number)
);

CREATE TABLE IF NOT EXISTS dentar_diagnosis_term (
    id SERIAL PRIMARY KEY,
    diagnosis_id INT NOT NULL REFERENCES dentar_diagnosis(id) ON DELETE CASCADE,
    language VARCHAR(10) NOT NULL DEFAULT 'es-AR',
    term VARCHAR(500) NOT NULL,
    term_type VARCHAR(20) NOT NULL DEFAULT 'preferred' CHECK (term_type IN ('preferred','synonym','abbreviation')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (diagnosis_id, language, term_type, term)
);

CREATE INDEX IF NOT EXISTS idx_dentar_diag_term_trgm ON dentar_diagnosis_term USING gin (term gin_trgm_ops);

CREATE TABLE IF NOT EXISTS dentar_diagnosis_mapping (
    id SERIAL PRIMARY KEY,
    diagnosis_id INT NOT NULL REFERENCES dentar_diagnosis(id) ON DELETE CASCADE,
    system_code VARCHAR(30) NOT NULL REFERENCES dentar_terminology_system(code),
    external_code VARCHAR(50) NOT NULL,            -- Ej: 'K02.1' o un SCTID
    external_display VARCHAR(500) NOT NULL,
    mapping_type VARCHAR(30) NOT NULL DEFAULT 'equivalent' CHECK (mapping_type IN ('equivalent','narrower','broader','related')),
    UNIQUE (diagnosis_id, system_code, external_code)
);

-- Actualización de esquemas creados por versiones anteriores (idempotente).
ALTER TABLE dentar_concept_version ADD COLUMN IF NOT EXISTS clinical_criteria TEXT;
ALTER TABLE dentar_diagnosis ADD COLUMN IF NOT EXISTS category_id INT REFERENCES dentar_category(id);
ALTER TABLE dentar_diagnosis ALTER COLUMN clinical_name TYPE VARCHAR(500);
ALTER TABLE dentar_diagnosis_version ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) NOT NULL DEFAULT 'approved';
ALTER TABLE dentar_diagnosis_version ADD COLUMN IF NOT EXISTS effective_from DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE dentar_diagnosis_mapping ALTER COLUMN external_code TYPE VARCHAR(50);
ALTER TABLE dentar_diagnosis_mapping ALTER COLUMN external_display TYPE VARCHAR(500);

CREATE TABLE IF NOT EXISTS dentar_concept_diagnosis (
    id SERIAL PRIMARY KEY,
    concept_id INT NOT NULL REFERENCES dentar_concept(id) ON DELETE CASCADE,
    diagnosis_id INT NOT NULL REFERENCES dentar_diagnosis(id) ON DELETE CASCADE,
    relationship_type VARCHAR(30) NOT NULL DEFAULT 'indicacion_habitual'
        CHECK (relationship_type IN ('indicacion_habitual', 'indicacion_posible', 'contraindicacion', 'contextual')),
    clinical_rationale TEXT,
    UNIQUE (concept_id, diagnosis_id, relationship_type)
);

CREATE INDEX IF NOT EXISTS idx_dentar_diag_concept ON dentar_concept_diagnosis(concept_id);
CREATE INDEX IF NOT EXISTS idx_dentar_diag_diagnosis ON dentar_concept_diagnosis(diagnosis_id);
CREATE INDEX IF NOT EXISTS idx_dentar_diag_rel ON dentar_concept_diagnosis(relationship_type);

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000001', E'Dientes supernumerarios', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Dientes supernumerarios', E'Presencia de piezas dentarias que exceden el número habitual de la serie dentaria.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000001'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K00.1', E'Dientes supernumerarios', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000001'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '205600004', E'Dientes supernumerarios', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000001'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000002', E'Alteraciones en la erupción dentaria (dentición retenida o retrasada)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Alteraciones en la erupción dentaria (dentición retenida o retrasada)', E'Retraso patológico en la emergencia de piezas temporarias o permanentes.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000002'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K00.6', E'Alteraciones en la erupción dentaria', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000002'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '278667004', E'Alteraciones en la erupción dentaria (dentición retenida o retrasada)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000002'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000003', E'Dientes incluidos (retención ósea o mucosa)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Dientes incluidos (retención ósea o mucosa)', E'Pieza dentaria que permanece completamente rodeada de hueso o mucosa tras su tiempo de erupción.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000003'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K01.0', E'Dientes incluidos', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000003'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '371077008', E'Dientes incluidos (retención ósea o mucosa)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000003'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000004', E'Dientes impactados (terceros molares, caninos)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Dientes impactados (terceros molares, caninos)', E'Pieza dentaria cuya trayectoria eruptiva está bloqueada por otra pieza, hueso o tejido blando.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000004'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K01.1', E'Dientes impactados', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000004'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '371077008', E'Dientes impactados (terceros molares, caninos)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000004'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000005', E'Caries limitada al esmalte (manchas blancas / cavitación incipiente)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Caries limitada al esmalte (manchas blancas / cavitación incipiente)', E'Lesión de desmineralización activa localizada en la superficie adamantina.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000005'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K02.0', E'Caries limitada al esmalte', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000005'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '80967001', E'Caries limitada al esmalte (manchas blancas / cavitación incipiente)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000005'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000006', E'Caries de la dentina (cavitación simple, compuesta o compleja)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Caries de la dentina (cavitación simple, compuesta o compleja)', E'Destrucción bacteriana activa con pérdida de estructura dentinaria.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000006'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K02.1', E'Caries de la dentina', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000006'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '80967001', E'Caries de la dentina (cavitación simple, compuesta o compleja)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000006'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000007', E'Caries del cemento / radicular', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Caries del cemento / radicular', E'Caries que se desarrolla en superficies radiculares expuestas a la cavidad bucal.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000007'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K02.2', E'Caries del cemento', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000007'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '80967001', E'Caries del cemento / radicular', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000007'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000008', E'Caries dental no especificada / destrucción coronaria severa', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Caries dental no especificada / destrucción coronaria severa', E'Pérdida estructural severa por caries que compromete la viabilidad coronaria.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000008'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K02.9', E'Caries dental, no especificada', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000008'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '80967001', E'Caries dental no especificada / destrucción coronaria severa', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000008'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000009', E'Abrasión y atrición dentaria patológica', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Abrasión y atrición dentaria patológica', E'Pérdida de sustancia dental por factores mecánicos o desgaste oclusal.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000009'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K03.1', E'Abrasión de los dientes', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000009'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '47444005', E'Abrasión y atrición dentaria patológica', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000009'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000010', E'Erosión dental ácida', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Erosión dental ácida', E'Disolución química del esmalte por exposición a ácidos intrínsecos o extrínsecos.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000010'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K03.2', E'Erosión de los dientes', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000010'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '73678001', E'Erosión dental ácida', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000010'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000011', E'Depósitos y cálculo [sarro] en los dientes', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Depósitos y cálculo [sarro] en los dientes', E'Acumulación de placa bacteriana calcificada supra y subgingival.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000011'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K03.6', E'Depósitos [adherencias] en los dientes', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000011'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '22769002', E'Depósitos y cálculo [sarro] en los dientes', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000011'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000012', E'Hipersensibilidad dentinaria / hiperestesia', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Hipersensibilidad dentinaria / hiperestesia', E'Respuesta dolorosa breve y aguda de la dentina expuesta a estímulos térmicos o táctiles.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000012'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K03.8', E'Otras enfermedades especificadas de los tejidos duros de los dientes', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000012'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '88874008', E'Hipersensibilidad dentinaria / hiperestesia', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000012'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000013', E'Pulpitis reversible', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Pulpitis reversible', E'Inflamación pulpar con capacidad biológica de recuperación tras eliminar el irritante.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000013'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K04.0', E'Pulpitis reversible', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000013'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '71738007', E'Pulpitis reversible', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000013'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000014', E'Pulpitis irreversible (aguda / purulenta / crónica)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Pulpitis irreversible (aguda / purulenta / crónica)', E'Inflamación pulpar severa que progresa hacia la necrosis y requiere endodoncia.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000014'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K04.0', E'Pulpitis irreversible', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000014'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '71738007', E'Pulpitis irreversible (aguda / purulenta / crónica)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000014'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000015', E'Necrosis pulpar', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Necrosis pulpar', E'Muerte del tejido pulpar con cese de vascularización e inervación.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000015'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K04.1', E'Necrosis de la pulpa', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000015'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '34509003', E'Necrosis pulpar', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000015'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000016', E'Periodontitis apical aguda de origen pulpar', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Periodontitis apical aguda de origen pulpar', E'Inflamación dolorosa del ligamento periodontal apical secundaria a patología endodóntica.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000016'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K04.4', E'Periodontitis apical aguda originada en la pulpa', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000016'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '44960002', E'Periodontitis apical aguda de origen pulpar', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000016'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000017', E'Periodontitis apical crónica (granuloma apical)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Periodontitis apical crónica (granuloma apical)', E'Respuesta inflamatoria periapical prolongada con reabsorción ósea asintomática.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000017'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K04.5', E'Periodontitis apical crónica', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000017'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '44960002', E'Periodontitis apical crónica (granuloma apical)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000017'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000018', E'Absceso periapical con fístula', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Absceso periapical con fístula', E'Colección purulenta periapical con drenaje espontáneo a mucosa o piel.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000018'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K04.6', E'Absceso periapical con fístula', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000018'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '44960002', E'Absceso periapical con fístula', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000018'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000019', E'Absceso periapical sin fístula (flemón odontógeno agudo)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Absceso periapical sin fístula (flemón odontógeno agudo)', E'Colección purulenta aguda con tumefacción facial, dolor severo y riesgo de celulitis.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000019'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K04.7', E'Absceso periapical sin fístula', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000019'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '44960002', E'Absceso periapical sin fístula (flemón odontógeno agudo)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000019'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000020', E'Quiste radicular / periapical', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Quiste radicular / periapical', E'Lesión quística epitelizada desarrollada a partir de restos de Malassez por estímulo pulpar.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000020'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K04.8', E'Quiste radicular', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000020'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '61159002', E'Quiste radicular / periapical', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000020'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000021', E'Gingivitis aguda / papilar / pericoronaritis aguda', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Gingivitis aguda / papilar / pericoronaritis aguda', E'Inflamación gingival de inicio rápido con eritema, edema y hemorragia activa.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000021'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K05.0', E'Gingivitis aguda', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000021'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '66383009', E'Gingivitis aguda / papilar / pericoronaritis aguda', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000021'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000022', E'Gingivitis marginal crónica inducida por placa', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Gingivitis marginal crónica inducida por placa', E'Afección gingival crónica reversible sin pérdida de inserción periodontal clínica.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000022'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K05.1', E'Gingivitis crónica', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000022'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '66383009', E'Gingivitis marginal crónica inducida por placa', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000022'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000023', E'Periodontitis crónica leve a moderada (bolsas hasta 5 mm)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Periodontitis crónica leve a moderada (bolsas hasta 5 mm)', E'Destrucción periodontal inflamatoria con pérdida ósea alveolar de hasta 2/3 radicular.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000023'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K05.3', E'Periodontitis crónica', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000023'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '110463002', E'Periodontitis crónica leve a moderada (bolsas hasta 5 mm)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000023'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000024', E'Periodontitis crónica severa destructiva (bolsas 6 mm o más)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Periodontitis crónica severa destructiva (bolsas 6 mm o más)', E'Pérdida ósea alveolar severa (> 2/3), compromiso de furcaciones y movilidad dentaria.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000024'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K05.3', E'Periodontitis crónica severa', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000024'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '110463002', E'Periodontitis crónica severa destructiva (bolsas 6 mm o más)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000024'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000025', E'Retracción gingival localizada o generalizada', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Retracción gingival localizada o generalizada', E'Migración apical del margen gingival con exposición radicular y pérdida estética/funcional.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000025'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K06.0', E'Retracción gingival', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000025'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '110463002', E'Retracción gingival localizada o generalizada', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000025'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000026', E'Hiperplasia gingival inflamatoria o medicamentosa', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Hiperplasia gingival inflamatoria o medicamentosa', E'Aumento de volumen tisular de la encía que cubre coronas clínicas o dificulta la higiene.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000026'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K06.1', E'Hiperplasia gingival', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000026'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '66383009', E'Hiperplasia gingival inflamatoria o medicamentosa', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000026'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000027', E'Anomalías en la posición dentaria (apiñamiento, rotación, diastemas)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Anomalías en la posición dentaria (apiñamiento, rotación, diastemas)', E'Discrepancia dentomaxilar con malposición funcional o estética.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000027'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K07.3', E'Anomalías de la posición del diente', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000027'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '401267008', E'Anomalías en la posición dentaria (apiñamiento, rotación, diastemas)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000027'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000028', E'Maloclusión funcional (Clase II, Clase III, mordida abierta / cruzada)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Maloclusión funcional (Clase II, Clase III, mordida abierta / cruzada)', E'Relación desarmónica entre los arcos dentarios con interferencia masticatoria.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000028'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K07.4', E'Maloclusión, tipo no especificado', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000028'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '401267008', E'Maloclusión funcional (Clase II, Clase III, mordida abierta / cruzada)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000028'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000029', E'Trastornos de la articulación temporomandibular (disfunción ATM / dolor miofascial)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Trastornos de la articulación temporomandibular (disfunción ATM / dolor miofascial)', E'Disfunción articular con ruidos, chasquidos, limitación de apertura o dolor masticatorio.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000029'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K07.6', E'Trastornos de la articulación temporomandibular', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000029'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '274441006', E'Trastornos de la articulación temporomandibular (disfunción ATM / dolor miofascial)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000029'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000030', E'Pérdida de dientes / desdentamiento parcial o total', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Pérdida de dientes / desdentamiento parcial o total', E'Ausencia de unidades dentarias con reducción de la eficacia masticatoria y soporte oclusal.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000030'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K08.1', E'Pérdida de dientes debida a accidente, extracción o afección periodontal', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000030'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '274440007', E'Pérdida de dientes / desdentamiento parcial o total', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000030'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000031', E'Atrofia severa del reborde alveolar desdentado', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Atrofia severa del reborde alveolar desdentado', E'Reabsorción ósea de los maxilares que dificulta la retención de prótesis convencionales.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000031'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K08.2', E'Atrofia del reborde alveolar desdentado', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000031'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '274440007', E'Atrofia severa del reborde alveolar desdentado', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000031'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000032', E'Resto radicular retenido', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Resto radicular retenido', E'Persistencia de raíz dentaria intraósea con o sin infección activa asociada.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000032'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K08.3', E'Raíz dental retenida', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000032'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '371077008', E'Resto radicular retenido', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000032'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000033', E'Osteomielitis maxilar / alveolitis seca o supurada', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Osteomielitis maxilar / alveolitis seca o supurada', E'Infección bacteriana ósea de los maxilares tras extracción o trauma.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000033'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K10.2', E'Afecciones inflamatorias de los maxilares', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000033'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '234744004', E'Osteomielitis maxilar / alveolitis seca o supurada', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000033'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000034', E'Estomatitis aftosa recurrente y lesiones de mucosa oral', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Estomatitis aftosa recurrente y lesiones de mucosa oral', E'Ulceraciones de la mucosa bucal que requieren diagnóstico diferencial e interconsulta.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000034'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'K12.0', E'Estomatitis aftosa recurrente', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000034'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '386053000', E'Estomatitis aftosa recurrente y lesiones de mucosa oral', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000034'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000035', E'Fractura de corona o raíz dental (traumatismo dentario)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Fractura de corona o raíz dental (traumatismo dentario)', E'Solución de continuidad del esmalte, dentina o raíz por impacto traumático.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000035'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'S02.5', E'Fractura de los dientes', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000035'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '111164008', E'Fractura de corona o raíz dental (traumatismo dentario)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000035'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000036', E'Luxación o avulsión total de diente por traumatismo', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Luxación o avulsión total de diente por traumatismo', E'Desplazamiento o expulsión completa de la pieza dentaria fuera de su alvéolo.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000036'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'S03.2', E'Luxación de diente', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000036'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '234744004', E'Luxación o avulsión total de diente por traumatismo', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000036'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000037', E'Bruxismo (rechinar / apretamiento diurno o nocturno)', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Bruxismo (rechinar / apretamiento diurno o nocturno)', E'Actividad parafuncional masticatoria que genera desgaste dentario, cefaleas o dolor de ATM.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000037'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'F45.8', E'Bruxismo', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000037'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '274441006', E'Bruxismo (rechinar / apretamiento diurno o nocturno)', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000037'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES (E'DNT-DX-000038', E'Examen odontológico general de rutina / control preventivo', 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, E'Examen odontológico general de rutina / control preventivo', E'Evaluación odontológica periódica programada en paciente asintomático.'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000038'
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', E'Z01.2', E'Examen odontológico', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000038'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '424759004', E'Examen odontológico general de rutina / control preventivo', 'equivalent'
FROM dentar_diagnosis WHERE code = E'DNT-DX-000038'
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;


-- =============================================================================
-- 8. MATRIZ DE JUSTIFICACIÓN CLÍNICA DENTAR <-> DIAGNÓSTICOS CIE-10
-- =============================================================================
INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Examen estomatológico inicial y control periódico'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000001' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Urgencia por dolor pulpar agudo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000002' AND d.code = E'DNT-DX-000014'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Urgencia por flemón / absceso periapical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000002' AND d.code = E'DNT-DX-000019'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Urgencia por pericoronaritis aguda'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000002' AND d.code = E'DNT-DX-000021'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Urgencia por dolor pulpar agudo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000004' AND d.code = E'DNT-DX-000014'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Urgencia por flemón / absceso periapical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000004' AND d.code = E'DNT-DX-000019'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Urgencia por pericoronaritis aguda'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000004' AND d.code = E'DNT-DX-000021'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Interconsulta por lesiones mucosas o estomatitis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000005' AND d.code = E'DNT-DX-000034'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Examen estomatológico inicial y control periódico'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000006' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000008' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000008' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000008' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000009' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000009' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000009' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000010' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000010' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000010' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000011' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000011' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000011' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000012' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000012' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000012' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000013' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000013' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000013' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000014' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000014' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000014' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000015' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000015' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000015' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Fractura coronaria de ángulo por traumatismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000015' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000016' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000016' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000016' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000017' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000017' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000017' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000018' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000018' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000018' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries dentinaria con cavitación activa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000019' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Caries incipiente cavitada'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000019' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Atrición o abrasión cervical severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000019' AND d.code = E'DNT-DX-000009'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Movilidad dentaria por periodontitis severa'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000020' AND d.code = E'DNT-DX-000024'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Inmovilización post-traumatismo dental'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000020' AND d.code = E'DNT-DX-000036'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pulpitis irreversible sintomática o asintomática'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000021' AND d.code = E'DNT-DX-000014'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Necrosis pulpar con o sin lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000021' AND d.code = E'DNT-DX-000015'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Periodontitis apical aguda de origen pulpar'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000021' AND d.code = E'DNT-DX-000016'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Periodontitis apical crónica / granuloma'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000021' AND d.code = E'DNT-DX-000017'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pulpitis irreversible sintomática o asintomática'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000022' AND d.code = E'DNT-DX-000014'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Necrosis pulpar con o sin lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000022' AND d.code = E'DNT-DX-000015'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Periodontitis apical aguda de origen pulpar'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000022' AND d.code = E'DNT-DX-000016'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Periodontitis apical crónica / granuloma'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000022' AND d.code = E'DNT-DX-000017'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pulpitis irreversible sintomática o asintomática'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000023' AND d.code = E'DNT-DX-000014'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Necrosis pulpar con o sin lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000023' AND d.code = E'DNT-DX-000015'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Periodontitis apical aguda de origen pulpar'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000023' AND d.code = E'DNT-DX-000016'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Periodontitis apical crónica / granuloma'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000023' AND d.code = E'DNT-DX-000017'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pulpitis irreversible sintomática o asintomática'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000024' AND d.code = E'DNT-DX-000014'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Necrosis pulpar con o sin lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000024' AND d.code = E'DNT-DX-000015'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Periodontitis apical aguda de origen pulpar'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000024' AND d.code = E'DNT-DX-000016'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Periodontitis apical crónica / granuloma'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000024' AND d.code = E'DNT-DX-000017'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Exposición pulpar en pieza temporaria o foramen abierto'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000025' AND d.code = E'DNT-DX-000013'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Necrosis parcial en diente posterior temporario'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000026' AND d.code = E'DNT-DX-000015'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000027' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000027' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000028' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000028' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000029' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000029' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000030' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000030' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000031' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000031' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000032' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000032' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000033' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000033' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000034' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000034' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000035' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000035' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000036' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000036' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000037' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000037' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000038' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000038' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000039' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000039' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Desdentamiento parcial / brecha edéntula'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000039' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000040' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000040' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Desdentamiento parcial / brecha edéntula'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000040' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000041' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000041' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000042' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000042' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000043' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000043' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000044' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000044' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000045' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000045' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria severa que no admite obturación simple'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000046' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Fractura dental con compromiso de cúspides'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000046' AND d.code = E'DNT-DX-000035'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000047' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000047' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000048' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000048' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000049' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000049' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000050' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000050' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000051' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000051' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000052' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000052' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000053' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000053' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000054' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000054' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000055' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000055' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000056' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000056' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000057' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000057' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000058' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000058' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000059' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000059' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000060' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000060' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000061' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000061' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000062' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000062' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000063' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000063' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000064' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000064' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000065' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000065' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000066' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000066' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000067' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000067' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000068' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000068' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000069' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000069' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida de piezas dentarias / edentulismo'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000070' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar atrófico que requiere prótesis'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000070' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Bruxismo severo con colapso de dimensión vertical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000071' AND d.code = E'DNT-DX-000037'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Disfunción de articulación temporomandibular'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000071' AND d.code = E'DNT-DX-000029'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Presencia de sarro / cálculo dental y manchas extrínsecas'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000073' AND d.code = E'DNT-DX-000011'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Gingivitis marginal por placa bacteriana'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000073' AND d.code = E'DNT-DX-000022'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Prevención y control en pacientes con riesgo cariogénico'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000074' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Manchas blancas / caries incipiente'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000074' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Prevención y control en pacientes con riesgo cariogénico'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000076' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Manchas blancas / caries incipiente'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000076' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Prevención y control en pacientes con riesgo cariogénico'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000077' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Manchas blancas / caries incipiente'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000077' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Prevención y control en pacientes con riesgo cariogénico'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000078' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Manchas blancas / caries incipiente'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000078' AND d.code = E'DNT-DX-000005'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Apiñamiento dentario o alteraciones de posición'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000079' AND d.code = E'DNT-DX-000027'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Maloclusión Clase I/II/III o mordida abierta'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000079' AND d.code = E'DNT-DX-000028'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Apiñamiento dentario o alteraciones de posición'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000080' AND d.code = E'DNT-DX-000027'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Maloclusión Clase I/II/III o mordida abierta'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000080' AND d.code = E'DNT-DX-000028'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Apiñamiento dentario o alteraciones de posición'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000081' AND d.code = E'DNT-DX-000027'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Maloclusión Clase I/II/III o mordida abierta'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000081' AND d.code = E'DNT-DX-000028'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Apiñamiento dentario o alteraciones de posición'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000082' AND d.code = E'DNT-DX-000027'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Maloclusión Clase I/II/III o mordida abierta'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000082' AND d.code = E'DNT-DX-000028'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Apiñamiento dentario o alteraciones de posición'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000083' AND d.code = E'DNT-DX-000027'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Maloclusión Clase I/II/III o mordida abierta'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000083' AND d.code = E'DNT-DX-000028'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries rampante o temprana de la infancia'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000084' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida prematura de diente temporario'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000085' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pérdida prematura de diente temporario'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000086' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Pulpitis en diente primario'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000087' AND d.code = E'DNT-DX-000013'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries rampante o temprana de la infancia'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000088' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Avulsión o luxación traumática en niño'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000089' AND d.code = E'DNT-DX-000036'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Avulsión o luxación traumática en niño'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000090' AND d.code = E'DNT-DX-000036'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries rampante o temprana de la infancia'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000091' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries rampante o temprana de la infancia'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000092' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Caries rampante o temprana de la infancia'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000093' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Gingivitis marginal crónica'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000095' AND d.code = E'DNT-DX-000022'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Periodontitis destructiva leve/moderada (bolsas <= 5mm)'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000096' AND d.code = E'DNT-DX-000023'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Periodontitis destructiva severa (bolsas >= 6mm)'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000097' AND d.code = E'DNT-DX-000024'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Periodontitis destructiva severa (bolsas >= 6mm)'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000098' AND d.code = E'DNT-DX-000024'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Desarmonía oclusal y disfunción temporomandibular'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000099' AND d.code = E'DNT-DX-000029'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Desarmonía oclusal y disfunción temporomandibular'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000100' AND d.code = E'DNT-DX-000029'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Desarmonía oclusal y disfunción temporomandibular'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000101' AND d.code = E'DNT-DX-000029'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Desarmonía oclusal y disfunción temporomandibular'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000102' AND d.code = E'DNT-DX-000029'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Bruxismo primario o secundario'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000103' AND d.code = E'DNT-DX-000037'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Trastornos de la ATM'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000103' AND d.code = E'DNT-DX-000029'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Examen radiográfico para diagnóstico y plan de tratamiento'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000105' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Detección de caries interproximal o lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000105' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Examen radiográfico para diagnóstico y plan de tratamiento'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000106' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Detección de caries interproximal o lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000106' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Examen radiográfico para diagnóstico y plan de tratamiento'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000107' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Detección de caries interproximal o lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000107' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Examen radiográfico para diagnóstico y plan de tratamiento'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000108' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Detección de caries interproximal o lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000108' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Examen radiográfico para diagnóstico y plan de tratamiento'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000109' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Detección de caries interproximal o lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000109' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Examen radiográfico para diagnóstico y plan de tratamiento'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000110' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Detección de caries interproximal o lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000110' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Examen radiográfico para diagnóstico y plan de tratamiento'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000111' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Detección de caries interproximal o lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000111' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Examen radiográfico para diagnóstico y plan de tratamiento'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000112' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Detección de caries interproximal o lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000112' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Examen radiográfico para diagnóstico y plan de tratamiento'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000113' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Detección de caries interproximal o lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000113' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Estudio cefalométrico para ortodoncia'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000114' AND d.code = E'DNT-DX-000028'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Estudio cefalométrico para ortodoncia'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000115' AND d.code = E'DNT-DX-000028'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'contextual', E'Examen radiográfico para diagnóstico y plan de tratamiento'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000116' AND d.code = E'DNT-DX-000038'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Detección de caries interproximal o lesión apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000116' AND d.code = E'DNT-DX-000006'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria no restaurable'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000117' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Resto radicular retenido sintomático'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000117' AND d.code = E'DNT-DX-000032'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria no restaurable'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000118' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Resto radicular retenido sintomático'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000118' AND d.code = E'DNT-DX-000032'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Lesión de mucosa bucal que requiere confirmación histopatológica'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000119' AND d.code = E'DNT-DX-000034'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria no restaurable'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000120' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Resto radicular retenido sintomático'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000120' AND d.code = E'DNT-DX-000032'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Avulsión traumática de diente'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000121' AND d.code = E'DNT-DX-000036'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Absceso odontógeno agudo intraoral'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000122' AND d.code = E'DNT-DX-000019'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Lesión de mucosa bucal que requiere confirmación histopatológica'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000123' AND d.code = E'DNT-DX-000034'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria no restaurable'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000124' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Resto radicular retenido sintomático'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000124' AND d.code = E'DNT-DX-000032'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Diente incluido con retención ósea'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000125' AND d.code = E'DNT-DX-000003'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Diente impactado (terceros molares / caninos)'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000125' AND d.code = E'DNT-DX-000004'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Pericoronaritis recurrente en molar impactado'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000125' AND d.code = E'DNT-DX-000021'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Diente incluido con retención ósea'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000126' AND d.code = E'DNT-DX-000003'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Diente impactado (terceros molares / caninos)'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000126' AND d.code = E'DNT-DX-000004'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Pericoronaritis recurrente en molar impactado'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000126' AND d.code = E'DNT-DX-000021'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Diente incluido con retención ósea'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000127' AND d.code = E'DNT-DX-000003'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Diente impactado (terceros molares / caninos)'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000127' AND d.code = E'DNT-DX-000004'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Pericoronaritis recurrente en molar impactado'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000127' AND d.code = E'DNT-DX-000021'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Fracaso endodóntico / granuloma o quiste apical'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000128' AND d.code = E'DNT-DX-000017'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Osteomielitis maxilar'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000129' AND d.code = E'DNT-DX-000033'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria no restaurable'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000130' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Resto radicular retenido sintomático'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000130' AND d.code = E'DNT-DX-000032'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria no restaurable'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000131' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Resto radicular retenido sintomático'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000131' AND d.code = E'DNT-DX-000032'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria no restaurable'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000132' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Resto radicular retenido sintomático'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000132' AND d.code = E'DNT-DX-000032'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria no restaurable'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000133' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Resto radicular retenido sintomático'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000133' AND d.code = E'DNT-DX-000032'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Diente incluido con retención ósea'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000134' AND d.code = E'DNT-DX-000003'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Diente impactado (terceros molares / caninos)'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000134' AND d.code = E'DNT-DX-000004'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Pericoronaritis recurrente en molar impactado'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000134' AND d.code = E'DNT-DX-000021'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Diente incluido con retención ósea'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000135' AND d.code = E'DNT-DX-000003'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Diente impactado (terceros molares / caninos)'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000135' AND d.code = E'DNT-DX-000004'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Pericoronaritis recurrente en molar impactado'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000135' AND d.code = E'DNT-DX-000021'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Destrucción coronaria no restaurable'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000136' AND d.code = E'DNT-DX-000008'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Resto radicular retenido sintomático'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000136' AND d.code = E'DNT-DX-000032'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Edentulismo parcial o total que requiere rehabilitación fija'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000137' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar con defecto que requiere regeneración ósea'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000137' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_habitual', E'Edentulismo parcial o total que requiere rehabilitación fija'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000138' AND d.code = E'DNT-DX-000030'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, E'indicacion_posible', E'Reborde alveolar con defecto que requiere regeneración ósea'
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = E'DNT-PR-000138' AND d.code = E'DNT-DX-000031'
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;

-- Término preferido de cada diagnóstico en la tabla de términos. El nombre
-- clínico sigue existiendo para compatibilidad, pero la API y la sincronización
-- leen los términos desde acá para poder agregar sinónimos sin tocar el código.
INSERT INTO dentar_diagnosis_term (diagnosis_id, language, term, term_type)
SELECT d.id, 'es-AR', d.clinical_name, 'preferred'
  FROM dentar_diagnosis d
ON CONFLICT (diagnosis_id, language, term_type, term) DO NOTHING;

-- Todos los diagnósticos del seed pertenecen a la categoría CAT-DX.
UPDATE dentar_diagnosis d
   SET category_id = cat.id
  FROM dentar_category cat
 WHERE d.category_id IS NULL
   AND cat.code = 'CAT-DX';


-- =============================================================================
-- 9. VISTA DE CONSULTA E INTEROPERABILIDAD CLÍNICA
-- =============================================================================
CREATE OR REPLACE VIEW v_dentar_procedimiento_diagnostico AS
SELECT
    'DENTAR-PR'                  AS catalogo_prestacion,
    c.code                       AS dentar_code,
    tp.term                      AS prestacion_nombre,
    m_ar.external_code           AS codigo_nomenclador_ar,
    m_cdt.external_code          AS codigo_cdt,
    m_sct_proc.external_code     AS snomed_ct_practica,
    dcat.name                    AS categoria,
    'DENTAR-DX'                  AS catalogo_diagnostico,
    d.code                       AS codigo_diagnostico_dentar,
    COALESCE(dtp.term, d.clinical_name) AS diagnostico_nombre,
    m_cie.external_code          AS cie10_codigo,
    m_cie.external_display       AS cie10_descripcion,
    m_sct.external_code          AS snomed_ct_codigo,
    cd.relationship_type         AS tipo_relacion,
    cd.clinical_rationale        AS justificacion_clinica
FROM dentar_concept c
JOIN dentar_concept_version cv
  ON cv.concept_id = c.id
 AND cv.version_number = (
        SELECT max(v2.version_number)
          FROM dentar_concept_version v2
         WHERE v2.concept_id = c.id
           AND v2.approval_status = 'approved'
     )
JOIN LATERAL (
    SELECT t.term
      FROM dentar_term t
     WHERE t.concept_version_id = cv.id
       AND t.term_type = 'preferred'
       AND t.language = 'es-AR'
     ORDER BY t.id DESC
     LIMIT 1
) tp ON TRUE
LEFT JOIN dentar_concept_category cc ON cc.concept_version_id = cv.id AND cc.is_primary = TRUE
LEFT JOIN dentar_category_version dcat
  ON dcat.category_id = cc.category_id
 AND dcat.language = 'es-AR'
 AND dcat.version_number = (
        SELECT max(v2.version_number)
          FROM dentar_category_version v2
         WHERE v2.category_id = cc.category_id
           AND v2.language = 'es-AR'
     )
LEFT JOIN dentar_concept_mapping m_ar ON m_ar.concept_version_id = cv.id AND m_ar.system_code = 'NOMENCLADOR-AR'
LEFT JOIN dentar_concept_mapping m_cdt ON m_cdt.concept_version_id = cv.id AND m_cdt.system_code = 'CDT-2025'
LEFT JOIN dentar_concept_mapping m_sct_proc ON m_sct_proc.concept_version_id = cv.id AND m_sct_proc.system_code = 'SNOMED-CT'
LEFT JOIN dentar_concept_diagnosis cd ON cd.concept_id = c.id
LEFT JOIN dentar_diagnosis d ON d.id = cd.diagnosis_id
LEFT JOIN LATERAL (
    SELECT dt.term
      FROM dentar_diagnosis_term dt
     WHERE dt.diagnosis_id = d.id
       AND dt.term_type = 'preferred'
       AND dt.language = 'es-AR'
     ORDER BY dt.id DESC
     LIMIT 1
) dtp ON TRUE
LEFT JOIN dentar_diagnosis_mapping m_cie ON m_cie.diagnosis_id = d.id AND m_cie.system_code = 'CIE-10'
LEFT JOIN dentar_diagnosis_mapping m_sct ON m_sct.diagnosis_id = d.id AND m_sct.system_code = 'SNOMED-CT'
ORDER BY c.code, cd.relationship_type;

COMMENT ON VIEW v_dentar_procedimiento_diagnostico IS
'Matriz clínica completa de interoperabilidad: DENTAR + Nomenclador Argentino + ADA CDT 2025 + CIE-10 + SNOMED CT.';


-- =============================================================================
-- 10. VISTAS DE FAMILIA
-- =============================================================================
-- DENTAR es la marca paraguas. Cada producto conserva su identidad, su prefijo,
-- sus reglas de mapeo y su release; estas vistas permiten consultarlos juntos.
CREATE OR REPLACE VIEW v_dentar_catalogo_familia AS
SELECT cat.code           AS catalog_code,
       cat.short_name     AS catalog,
       cat.family_code    AS family,
       cat.name           AS name,
       cat.code_prefix    AS code_prefix,
       cat.concept_kind   AS concept_kind,
       cat.status         AS status,
       CASE cat.code
            WHEN 'dentar-pr' THEN (SELECT count(*) FROM dentar_concept c WHERE c.catalog_id = cat.id)
            WHEN 'dentar-dx' THEN (SELECT count(*) FROM dentar_diagnosis d WHERE d.catalog_id = cat.id)
            ELSE 0
       END                AS concepts_count
  FROM dentar_catalog cat;

COMMENT ON VIEW v_dentar_catalogo_familia IS
'Productos de la familia DENTAR con su prefijo, tipo de concepto y cantidad de códigos cargados.';

CREATE OR REPLACE VIEW v_dentar_family_concept AS
-- DENTAR-PR: procedimientos
SELECT cat.code                     AS catalog_code,
       cat.short_name               AS catalog,
       cat.family_code              AS family,
       'procedure'::varchar(30)     AS concept_kind,
       c.code                       AS code,
       tp.term                      AS preferred_term,
       cv.definition                AS definition,
       cv.clinical_criteria         AS clinical_criteria,
       c.lifecycle_status           AS status,
       dcat.code                    AS category_code,
       dcatv.name                   AS category_name,
       m_sct.external_code::varchar(100) AS snomed_code,
       NULL::varchar(100)           AS cie10_code,
       m_ar.external_code::varchar(100)  AS nomenclador_code,
       m_cdt.external_code::varchar(100) AS cdt_code
  FROM dentar_concept c
  JOIN dentar_catalog cat ON cat.id = c.catalog_id AND cat.code = 'dentar-pr'
  JOIN dentar_concept_version cv
    ON cv.concept_id = c.id
   AND cv.version_number = (
        SELECT max(v2.version_number)
          FROM dentar_concept_version v2
         WHERE v2.concept_id = c.id
           AND v2.approval_status = 'approved'
     )
  JOIN LATERAL (
      SELECT t.term
        FROM dentar_term t
       WHERE t.concept_version_id = cv.id
         AND t.term_type = 'preferred'
         AND t.language = 'es-AR'
       ORDER BY t.id DESC
       LIMIT 1
  ) tp ON TRUE
  LEFT JOIN dentar_concept_category cc ON cc.concept_version_id = cv.id AND cc.is_primary = TRUE
  LEFT JOIN dentar_category dcat ON dcat.id = cc.category_id
  LEFT JOIN dentar_category_version dcatv
    ON dcatv.category_id = dcat.id
   AND dcatv.language = 'es-AR'
   AND dcatv.version_number = (
        SELECT max(v2.version_number)
          FROM dentar_category_version v2
         WHERE v2.category_id = dcat.id
           AND v2.language = 'es-AR'
     )
  LEFT JOIN dentar_concept_mapping m_sct ON m_sct.concept_version_id = cv.id AND m_sct.system_code = 'SNOMED-CT'
  LEFT JOIN dentar_concept_mapping m_ar  ON m_ar.concept_version_id = cv.id AND m_ar.system_code = 'NOMENCLADOR-AR'
  LEFT JOIN dentar_concept_mapping m_cdt ON m_cdt.concept_version_id = cv.id AND m_cdt.system_code = 'CDT-2025'

UNION ALL

-- DENTAR-DX: diagnósticos
SELECT cat.code                     AS catalog_code,
       cat.short_name               AS catalog,
       cat.family_code              AS family,
       'diagnosis'::varchar(30)     AS concept_kind,
       d.code                       AS code,
       COALESCE(dtp.term, d.clinical_name) AS preferred_term,
       dv.definition                AS definition,
       dv.clinical_criteria         AS clinical_criteria,
       d.status                     AS status,
       dcat.code                    AS category_code,
       dcatv.name                   AS category_name,
       m_sct.external_code::varchar(100) AS snomed_code,
       m_cie.external_code::varchar(100) AS cie10_code,
       NULL::varchar(100)           AS nomenclador_code,
       NULL::varchar(100)           AS cdt_code
  FROM dentar_diagnosis d
  JOIN dentar_catalog cat ON cat.id = d.catalog_id AND cat.code = 'dentar-dx'
  JOIN dentar_diagnosis_version dv
    ON dv.diagnosis_id = d.id
   AND dv.version_number = (
        SELECT max(v2.version_number)
          FROM dentar_diagnosis_version v2
         WHERE v2.diagnosis_id = d.id
           AND v2.approval_status = 'approved'
     )
  LEFT JOIN LATERAL (
      SELECT dt.term
        FROM dentar_diagnosis_term dt
       WHERE dt.diagnosis_id = d.id
         AND dt.term_type = 'preferred'
         AND dt.language = 'es-AR'
       ORDER BY dt.id DESC
       LIMIT 1
  ) dtp ON TRUE
  LEFT JOIN dentar_category dcat ON dcat.id = d.category_id
  LEFT JOIN dentar_category_version dcatv
    ON dcatv.category_id = dcat.id
   AND dcatv.language = 'es-AR'
   AND dcatv.version_number = (
        SELECT max(v2.version_number)
          FROM dentar_category_version v2
         WHERE v2.category_id = dcat.id
           AND v2.language = 'es-AR'
     )
  LEFT JOIN dentar_diagnosis_mapping m_sct ON m_sct.diagnosis_id = d.id AND m_sct.system_code = 'SNOMED-CT'
  LEFT JOIN dentar_diagnosis_mapping m_cie ON m_cie.diagnosis_id = d.id AND m_cie.system_code = 'CIE-10';

COMMENT ON VIEW v_dentar_family_concept IS
'Vista de lectura unificada de la familia DENTAR: procedimientos (DENTAR-PR) y diagnósticos (DENTAR-DX) con sus mapeos.';


-- =============================================================================
-- 17. IDEMPOTENCIA DE TÉRMINOS
-- =============================================================================
-- El seed usa `ON CONFLICT DO NOTHING` sin destino, pero `dentar_term` no tenía
-- restricción única: al volver a ejecutar este archivo se duplicaban los
-- términos de cada concepto. Se deduplica y se crea la restricción que faltaba,
-- para que el seed sea realmente idempotente y el importador CSV actualice una
-- sola fila por término.
DELETE FROM dentar_term a
 USING dentar_term b
 WHERE a.id > b.id
   AND a.concept_version_id = b.concept_version_id
   AND a.language = b.language
   AND a.term_type = b.term_type
   AND a.term = b.term;

CREATE UNIQUE INDEX IF NOT EXISTS ux_dentar_term
    ON dentar_term (concept_version_id, language, term_type, term);

-- Control de prefijo por catálogo (la función la define sql/dentar_family.sql).
CREATE OR REPLACE TRIGGER trg_dentar_concept_code
    BEFORE INSERT OR UPDATE OF code, catalog_id ON dentar_concept
    FOR EACH ROW EXECUTE FUNCTION dentar_assert_catalog_code();

CREATE OR REPLACE TRIGGER trg_dentar_diagnosis_code
    BEFORE INSERT OR UPDATE OF code, catalog_id ON dentar_diagnosis
    FOR EACH ROW EXECUTE FUNCTION dentar_assert_catalog_code();

ANALYZE dentar_release;
ANALYZE dentar_catalog;
ANALYZE dentar_category;
ANALYZE dentar_category_version;
ANALYZE dentar_concept;
ANALYZE dentar_concept_version;
ANALYZE dentar_term;
ANALYZE dentar_concept_category;
ANALYZE dentar_unit;
ANALYZE dentar_attribute_definition;
ANALYZE dentar_concept_attribute_rule;
ANALYZE dentar_terminology_system;
ANALYZE dentar_catalog_mapping_rule;
ANALYZE dentar_concept_mapping;
ANALYZE dentar_diagnosis;
ANALYZE dentar_diagnosis_version;
ANALYZE dentar_diagnosis_term;
ANALYZE dentar_diagnosis_mapping;
ANALYZE dentar_concept_diagnosis;

SELECT 'dentar_catalog' AS tabla, count(*) AS filas FROM dentar_catalog
UNION ALL SELECT 'dentar_release', count(*) FROM dentar_release
UNION ALL SELECT 'dentar_category', count(*) FROM dentar_category
UNION ALL SELECT 'dentar_concept', count(*) FROM dentar_concept
UNION ALL SELECT 'dentar_term', count(*) FROM dentar_term
UNION ALL SELECT 'dentar_concept_mapping', count(*) FROM dentar_concept_mapping
UNION ALL SELECT 'dentar_concept_attribute_rule', count(*) FROM dentar_concept_attribute_rule
UNION ALL SELECT 'dentar_diagnosis', count(*) FROM dentar_diagnosis
UNION ALL SELECT 'dentar_diagnosis_term', count(*) FROM dentar_diagnosis_term
UNION ALL SELECT 'dentar_diagnosis_mapping', count(*) FROM dentar_diagnosis_mapping
UNION ALL SELECT 'dentar_concept_diagnosis', count(*) FROM dentar_concept_diagnosis;
