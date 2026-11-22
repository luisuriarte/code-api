-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud · Familia OFTAR
-- sql/03_oftar/oftar_core.sql
-- =============================================================================
--
-- CONTENIDO
--   1. oftar_release: versiones editoriales de la familia.
--   2. oftar_category / oftar_category_version: jerarquía interna de OFTAR-PR
--      y categoría propia de OFTAR-DX, en es-AR y en.
--   3. Registro canónico en os_catalog, os_catalog_release,
--      os_catalog_language y os_catalog_category.
--   4. Sistemas terminológicos, reglas de mapeo y atributos estructurados
--      (incluye la lateralidad OD / OI / AO / NA).
--   5. oftar_concept / oftar_diagnosis y sus versiones, términos, mapeos y
--      relaciones de justificación clínica. Sin valores UVR: la valoración
--      vive en os_uvr_* y se propone por gobernanza.
--   6. Vista de familia y privilegios explícitos.
--
-- REQUISITO: ejecutar antes `oftar_family.sql`.
-- La clasificación es orientativa: no crea códigos originales por procedimiento.
-- PostgreSQL 18.
-- =============================================================================
BEGIN;

SET client_encoding = 'UTF8';

DO $$
BEGIN
    IF to_regclass('public.oftar_catalog') IS NULL THEN
        RAISE EXCEPTION 'Falta el registro de la familia OFTAR (tabla oftar_catalog).'
            USING HINT = 'Ejecutá primero: psql -d origen_codes -f sql/03_oftar/oftar_family.sql';
    END IF;

    IF to_regclass('public.os_catalog') IS NULL THEN
        RAISE EXCEPTION 'Falta el motor de catálogos (tabla os_catalog).'
            USING HINT = 'Ejecutá primero: psql -d origen_codes -f sql/02_catalogs/origen_catalog_engine.sql';
    END IF;
END $$;

-- =============================================================================
-- 1. RELEASES EDITORIALES
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.oftar_release (
    id SERIAL PRIMARY KEY,
    version VARCHAR(20) NOT NULL UNIQUE,
    release_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'published'
        CHECK (status IN ('draft', 'published', 'deprecated')),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO public.oftar_release (version, release_date, status, description)
VALUES ('1.0.0', CURRENT_DATE, 'published',
        'Primera publicación de la estructura OFTAR: dos catálogos y clasificación interna orientativa de OFTAR-PR.')
ON CONFLICT (version) DO UPDATE SET description = EXCLUDED.description;

-- =============================================================================
-- 2. CATEGORÍAS
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.oftar_category (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL DEFAULT public.oftar_catalog_id('oftar-pr')
        REFERENCES public.oftar_catalog(id),
    code VARCHAR(30) NOT NULL,
    parent_id INT REFERENCES public.oftar_category(id) ON DELETE SET NULL,
    sort_order INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive')),
    UNIQUE (catalog_id, code)
);

CREATE TABLE IF NOT EXISTS public.oftar_category_version (
    id SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES public.oftar_category(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    language VARCHAR(10) NOT NULL DEFAULT 'es-AR',
    name VARCHAR(150) NOT NULL,
    description TEXT,
    UNIQUE (category_id, version_number, language)
);

-- Fuente única de la clasificación. El mismo contenido se usa para sembrar
-- oftar_category_version y os_catalog_category. tools/sources/oftar/
-- oftar_categorias.csv conserva estas filas para el futuro importador.
CREATE TEMP TABLE _oftar_categoria ON COMMIT DROP AS
SELECT * FROM (VALUES
    ('oftar-pr', 'GRP-EVAL', NULL,      10, 'Evaluación y consulta',         'Evaluation and consultation',      'Agrupa consultas y exámenes clínicos iniciales.',                         'Groups consultations and initial clinical examinations.'),
    ('oftar-pr', 'GRP-DIAG', NULL,      20, 'Diagnóstico y estudios',        'Diagnosis and studies',            'Agrupa estudios funcionales y diagnóstico por imágenes.',                  'Groups functional studies and diagnostic imaging.'),
    ('oftar-pr', 'GRP-TER',  NULL,      30, 'Tratamiento y cirugía',         'Treatment and surgery',            'Agrupa procedimientos terapéuticos, láser, inyecciones y cirugía.',        'Groups therapeutic procedures, laser, injections and surgery.'),
    ('oftar-pr', 'GRP-OCUL', NULL,      40, 'Oculoplastia y aparato lagrimal','Oculoplasty and lacrimal system', 'Agrupa párpados, órbita y vías lagrimales.',                               'Groups eyelids, orbit and lacrimal system.'),
    ('oftar-pr', 'CONSULT',  'GRP-EVAL', 11, 'Consultas y evaluaciones',     'Consultations and evaluations',    'Consulta oftalmológica general, especializada y controles.',               'General and specialized ophthalmic consultations and follow-up visits.'),
    ('oftar-pr', 'EXAM',     'GRP-EVAL', 12, 'Exámenes oftalmológicos',      'Ophthalmic examinations',          'Biomicroscopía con lámpara de hendidura, tonometría y gonioscopía.',       'Slit-lamp biomicroscopy, tonometry and gonioscopy.'),
    ('oftar-pr', 'DIAG',     'GRP-DIAG', 21, 'Estudios diagnósticos',        'Diagnostic studies',               'Campimetría y pruebas funcionales visuales.',                              'Perimetry and visual function tests.'),
    ('oftar-pr', 'IMG',      'GRP-DIAG', 22, 'Diagnóstico por imágenes',      'Diagnostic imaging',               'Tomografía de coherencia óptica (OCT), retinografía y paquimetría.',        'Optical coherence tomography (OCT), fundus photography and pachymetry.'),
    ('oftar-pr', 'TER',      'GRP-TER',  31, 'Procedimientos terapéuticos',  'Therapeutic procedures',           'Fotocoagulación láser e inyecciones intravítreas.',                         'Laser photocoagulation and intravitreal injections.'),
    ('oftar-pr', 'CIR',      'GRP-TER',  32, 'Cirugía oftalmológica',        'Ophthalmic surgery',               'Catarata, retina, glaucoma, córnea y cirugía refractiva.',                  'Cataract, retina, glaucoma, cornea and refractive surgery.'),
    ('oftar-pr', 'OCUL',     'GRP-OCUL', 41, 'Oculoplastia',                 'Oculoplasty',                      'Procedimientos de párpados y órbita.',                                     'Eyelid and orbital procedures.'),
    ('oftar-pr', 'LAGR',     'GRP-OCUL', 42, 'Vías lagrimales',              'Lacrimal system',                  'Sondaje lagrimal y procedimientos del aparato lagrimal.',                   'Lacrimal probing and lacrimal system procedures.'),
    ('oftar-dx', 'CAT-DX',   NULL,      90, 'Diagnósticos oftalmológicos (CIE-10 H00-H59)', 'Ophthalmic diagnoses (ICD-10 H00-H59)', 'Enfermedades y condiciones del ojo y sus anexos. Sin UVR propia.', 'Diseases and conditions of the eye and adnexa. No UVR of their own.')
) AS v(catalogo, codigo, padre, orden, nombre_es, nombre_en, descripcion_es, descripcion_en);

INSERT INTO public.oftar_category (catalog_id, code, parent_id, sort_order)
SELECT oc.id, v.codigo, NULL, v.orden
  FROM _oftar_categoria v
  JOIN public.oftar_catalog oc ON oc.code = v.catalogo
 WHERE v.padre IS NULL
ON CONFLICT (catalog_id, code) DO UPDATE
   SET sort_order = EXCLUDED.sort_order,
       status = 'active';

INSERT INTO public.oftar_category (catalog_id, code, parent_id, sort_order)
SELECT oc.id, v.codigo, p.id, v.orden
  FROM _oftar_categoria v
  JOIN public.oftar_catalog oc ON oc.code = v.catalogo
  JOIN public.oftar_category p ON p.catalog_id = oc.id AND p.code = v.padre
 WHERE v.padre IS NOT NULL
ON CONFLICT (catalog_id, code) DO UPDATE
   SET parent_id = EXCLUDED.parent_id,
       sort_order = EXCLUDED.sort_order,
       status = 'active';

INSERT INTO public.oftar_category_version
       (category_id, version_number, language, name, description)
SELECT c.id, 1, lang.code,
       CASE WHEN lang.code = 'es-AR' THEN v.nombre_es ELSE v.nombre_en END,
       CASE WHEN lang.code = 'es-AR' THEN v.descripcion_es ELSE v.descripcion_en END
  FROM _oftar_categoria v
  JOIN public.oftar_catalog oc ON oc.code = v.catalogo
  JOIN public.oftar_category c ON c.catalog_id = oc.id AND c.code = v.codigo
  CROSS JOIN (VALUES ('es-AR'), ('en')) AS lang(code)
ON CONFLICT (category_id, version_number, language) DO UPDATE
   SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- 3. REGISTRO CANÓNICO EN EL MOTOR DE CATÁLOGOS
-- =============================================================================
INSERT INTO public.os_catalog
    (code, name, organization, country_code, domain_type, family_code,
     product_role, short_name, description)
VALUES
    ('oftar', 'OFTAR · Familia de catálogos oftalmológicos',
     'Origen Salud / Comité de Oftalmología', 'AR', 'medical', NULL, 'family',
     'OFTAR', 'Marca paraguas de la familia OFTAR. Los únicos productos son OFTAR-PR (procedimientos) y OFTAR-DX (diagnósticos). Las imágenes, cirugías y tratamientos son categorías de OFTAR-PR.'),
    ('oftar-pr', 'OFTAR-PR · Catálogo de Procedimientos Oftalmológicos',
     'Origen Salud / Comité de Oftalmología', 'AR', 'medical', 'oftar', 'catalog',
     'OFTAR-PR', 'Prestaciones oftalmológicas con códigos permanentes OFTAR-PR-NNNNNN. Clasificación interna por CONSULT, EXAM, DIAG, IMG, TER, CIR, OCUL y LAGR. Único catálogo OFTAR con UVR.'),
    ('oftar-dx', 'OFTAR-DX · Catálogo de Diagnósticos Oftalmológicos',
     'Origen Salud / Comité de Oftalmología', 'AR', 'medical', 'oftar', 'catalog',
     'OFTAR-DX', 'Diagnósticos oftalmológicos con códigos permanentes OFTAR-DX-NNNNNN, armonizados con CIE-10 H00-H59. No reciben UVR: evita duplicar la valoración de las prestaciones.')
ON CONFLICT (code) DO UPDATE
   SET name         = EXCLUDED.name,
       family_code  = EXCLUDED.family_code,
       product_role = EXCLUDED.product_role,
       short_name   = EXCLUDED.short_name,
       description  = EXCLUDED.description;

INSERT INTO public.os_catalog_release
       (catalog_id, version_tag, valid_from, official_norm_reference)
SELECT id, '2026-v1', DATE '2026-01-01', 'Clasificación interna OFTAR v1 (orientativa)'
  FROM public.os_catalog
 WHERE code IN ('oftar-pr', 'oftar-dx')
ON CONFLICT (catalog_id, version_tag) DO NOTHING;

-- La familia no tiene idiomas propios: solo los productos. es-AR es default y
-- fallback; en está cargado; pt-BR queda planning hasta la segunda etapa.
DO $$
BEGIN
    IF to_regclass('public.os_catalog_language') IS NOT NULL THEN
        EXECUTE '
            INSERT INTO public.os_catalog_language
                   (catalog_id, language_code, is_default, is_fallback, is_bridge, coverage_status)
            SELECT c.id, l.code, l.es_default, l.es_fallback, FALSE, l.coverage
              FROM public.os_catalog c
              CROSS JOIN (VALUES
                  (''es-AR'', TRUE,  TRUE,  ''partial''),
                  (''en'',    FALSE, FALSE, ''partial''),
                  (''pt-BR'', FALSE, FALSE, ''planned'')
              ) AS l(code, es_default, es_fallback, coverage)
              JOIN public.os_language idiom ON idiom.code = l.code
             WHERE c.code IN (''oftar-pr'', ''oftar-dx'')
            ON CONFLICT (catalog_id, language_code) DO NOTHING
        ';
    END IF;
END $$;

-- En dos pasos: un INSERT único no ve las raíces que él mismo acaba de crear,
-- por eso las subcategorías se insertan después de las raíces.
INSERT INTO public.os_catalog_category (catalog_id, code, name, parent_category_id)
SELECT oc.id, v.codigo, v.nombre_es, NULL
  FROM _oftar_categoria v
  JOIN public.os_catalog oc ON oc.code = v.catalogo
 WHERE v.padre IS NULL
ON CONFLICT (catalog_id, code) DO UPDATE
   SET name = EXCLUDED.name,
       parent_category_id = NULL;

INSERT INTO public.os_catalog_category (catalog_id, code, name, parent_category_id)
SELECT oc.id, v.codigo, v.nombre_es, p.id
  FROM _oftar_categoria v
  JOIN public.os_catalog oc ON oc.code = v.catalogo
  JOIN public.os_catalog_category p
         ON p.catalog_id = oc.id AND p.code = v.padre
 WHERE v.padre IS NOT NULL
ON CONFLICT (catalog_id, code) DO UPDATE
   SET name = EXCLUDED.name,
       parent_category_id = EXCLUDED.parent_category_id;

-- =============================================================================
-- 4. TERMINOLOGÍA, MAPEOS Y ATRIBUTOS ESTRUCTURADOS
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.oftar_terminology_system (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    uri VARCHAR(500),
    description TEXT
);

INSERT INTO public.oftar_terminology_system (code, name, uri, description) VALUES
    ('NOMENCLADOR-AR', 'Nomenclador Nacional de Prestaciones Médicas 2025', NULL,
     'Anexo I, sección Operaciones en el Aparato de la Visión. Mapeo obligatorio de OFTAR-PR.'),
    ('CIE-10', 'Clasificación Internacional de Enfermedades, 10ª revisión', 'https://icd.who.int/browse10',
     'Rango H00-H59 para OFTAR-DX. Mapeo obligatorio.'),
    ('SNOMED-CT', 'SNOMED Clinical Terms', 'http://snomed.info/sct',
     'Conceptos clínicos y procedimientos. Edición Argentina disponible en es y en.'),
    ('CPT', 'Current Procedural Terminology', NULL,
     'Servicios y procedimientos. Fuente cruda no integrada todavía; requiere revisión de licencia. No copiar descripciones.'),
    ('ICD-10-PCS', 'ICD-10 Procedure Coding System', NULL,
     'Procedimientos hospitalarios, especialmente quirúrgicos. Fuente cruda no integrada todavía.'),
    ('LOINC', 'Logical Observation Identifiers Names and Codes', 'http://loinc.org',
     'Observaciones e informes de OCT, campimetría y retinografía; no identifica el procedimiento.')
ON CONFLICT (code) DO UPDATE
   SET name = EXCLUDED.name, uri = EXCLUDED.uri, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS public.oftar_catalog_mapping_rule (
    catalog_id INT NOT NULL REFERENCES public.oftar_catalog(id) ON DELETE CASCADE,
    system_code VARCHAR(30) NOT NULL REFERENCES public.oftar_terminology_system(code) ON DELETE CASCADE,
    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    is_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (catalog_id, system_code)
);

INSERT INTO public.oftar_catalog_mapping_rule (catalog_id, system_code, is_required, is_allowed)
VALUES
    (public.oftar_catalog_id('oftar-pr'), 'NOMENCLADOR-AR', TRUE,  TRUE),
    (public.oftar_catalog_id('oftar-pr'), 'SNOMED-CT',      FALSE, TRUE),
    (public.oftar_catalog_id('oftar-pr'), 'CPT',            FALSE, TRUE),
    (public.oftar_catalog_id('oftar-pr'), 'ICD-10-PCS',     FALSE, TRUE),
    (public.oftar_catalog_id('oftar-pr'), 'LOINC',          FALSE, TRUE),
    (public.oftar_catalog_id('oftar-dx'), 'CIE-10',         TRUE,  TRUE),
    (public.oftar_catalog_id('oftar-dx'), 'SNOMED-CT',      FALSE, TRUE)
ON CONFLICT (catalog_id, system_code) DO UPDATE
   SET is_required = EXCLUDED.is_required,
       is_allowed  = EXCLUDED.is_allowed;

CREATE TABLE IF NOT EXISTS public.oftar_attribute_definition (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    data_type VARCHAR(20) NOT NULL
        CHECK (data_type IN ('string','integer','decimal','boolean','date','coded')),
    description TEXT
);

INSERT INTO public.oftar_attribute_definition (code, name, data_type, description) VALUES
    ('ATTR-LATERALITY',    'Lateralidad', 'coded',
     'OD, OI, AO o sin lateralidad. Se guarda como atributo/modificador; no genera códigos OFTAR independientes.'),
    ('ATTR-STRUCTURE',     'Ojo o estructura', 'coded',
     'Globo ocular, retina, córnea, cristalino u otra estructura anatómica.'),
    ('ATTR-TECHNIQUE',     'Técnica', 'coded',
     'Convencional, láser o microcirugía.'),
    ('ATTR-MODALITY',      'Modalidad', 'coded',
     'Diagnóstico, tratamiento o cirugía.'),
    ('ATTR-COMPLEXITY',    'Complejidad', 'coded',
     'Básica, intermedia o avanzada.'),
    ('ATTR-ANESTHESIA',    'Anestesia', 'coded',
     'Tópica, local, regional o general.'),
    ('ATTR-SETTING',       'Ámbito', 'coded',
     'Consultorio, quirófano o centro especializado.'),
    ('ATTR-EXECUTION-ROLE','Rol de ejecución', 'coded',
     'Técnico, profesional o integral. Permite distinguir realización e interpretación sin cuarto componente UVR.'),
    ('ATTR-REQUIRES-REPORT','Requiere informe', 'boolean',
     'Indica si la prestación genera informe profesional separado de la realización.')
ON CONFLICT (code) DO UPDATE
   SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS public.oftar_attribute_value (
    attribute_code VARCHAR(50) NOT NULL
        REFERENCES public.oftar_attribute_definition(code) ON UPDATE CASCADE,
    value_code VARCHAR(30) NOT NULL,
    label_es VARCHAR(150) NOT NULL,
    label_en VARCHAR(150) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    PRIMARY KEY (attribute_code, value_code)
);

INSERT INTO public.oftar_attribute_value
       (attribute_code, value_code, label_es, label_en, sort_order) VALUES
    ('ATTR-LATERALITY',     'OD',        'Ojo derecho',       'Right eye',        10),
    ('ATTR-LATERALITY',     'OI',        'Ojo izquierdo',     'Left eye',         20),
    ('ATTR-LATERALITY',     'AO',        'Ambos ojos',        'Both eyes',        30),
    ('ATTR-LATERALITY',     'NA',        'Sin lateralidad',   'Not applicable',   40),
    ('ATTR-EXECUTION-ROLE', 'TECHNICAL', 'Realización técnica', 'Technical performance', 10),
    ('ATTR-EXECUTION-ROLE', 'PROFESSIONAL','Interpretación e informe', 'Interpretation and report', 20),
    ('ATTR-EXECUTION-ROLE', 'INTEGRAL',  'Integral',          'Integral',         30)
ON CONFLICT (attribute_code, value_code) DO UPDATE
   SET label_es = EXCLUDED.label_es,
       label_en = EXCLUDED.label_en,
       sort_order = EXCLUDED.sort_order;

-- Tabla canónica ya usada por el panel y Browse. CREATE IF NOT EXISTS la hace
-- idempotente cuando el Nomenclador Odontológico ya la creó.
CREATE TABLE IF NOT EXISTS public.os_catalog_source_attribute (
    item_id INT NOT NULL REFERENCES public.os_catalog_item(id) ON DELETE CASCADE,
    source_catalog_code VARCHAR(50) NOT NULL,
    attribute_code VARCHAR(50) NOT NULL,
    attribute_label VARCHAR(150) NOT NULL,
    attribute_value TEXT NOT NULL,
    is_boolean BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INT NOT NULL DEFAULT 0,
    PRIMARY KEY (item_id, source_catalog_code, attribute_code)
);

COMMENT ON TABLE public.os_catalog_source_attribute IS
    'Atributos literales de la fuente. Para OFTAR usar source_catalog_code = oftar y attribute_code de oftar_attribute_definition, con valores de oftar_attribute_value.';

-- =============================================================================
-- 5. CONCEPTOS Y DIAGNÓSTICOS EDITORIALES
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.oftar_concept (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL DEFAULT public.oftar_catalog_id('oftar-pr')
        REFERENCES public.oftar_catalog(id),
    code VARCHAR(30) NOT NULL UNIQUE,
    concept_type VARCHAR(30) NOT NULL DEFAULT 'procedure'
        CHECK (concept_type IN ('procedure','service','evaluation',
                                'diagnostic_service','imaging','surgery','rehabilitation')),
    lifecycle_status VARCHAR(20) NOT NULL DEFAULT 'draft'
        CHECK (lifecycle_status IN ('draft','active','retired')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Sin columnas UVR: el total se deriva en os_uvr_* y nunca se guarda aquí.
CREATE TABLE IF NOT EXISTS public.oftar_concept_version (
    id SERIAL PRIMARY KEY,
    concept_id INT NOT NULL REFERENCES public.oftar_concept(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    definition TEXT NOT NULL,
    short_definition VARCHAR(255),
    global_period_days INT,
    lay_terms TEXT,
    clinical_scope TEXT,
    clinical_criteria TEXT,
    approval_status VARCHAR(20) NOT NULL DEFAULT 'draft'
        CHECK (approval_status IN ('draft','review','approved','rejected')),
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    year_effective INT,
    UNIQUE (concept_id, version_number)
);

CREATE TABLE IF NOT EXISTS public.oftar_term (
    id SERIAL PRIMARY KEY,
    concept_version_id INT NOT NULL REFERENCES public.oftar_concept_version(id) ON DELETE CASCADE,
    language VARCHAR(10) NOT NULL DEFAULT 'es-AR',
    term VARCHAR(500) NOT NULL,
    term_type VARCHAR(20) NOT NULL DEFAULT 'preferred'
        CHECK (term_type IN ('preferred','synonym','abbreviation')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.oftar_concept_category (
    concept_version_id INT NOT NULL REFERENCES public.oftar_concept_version(id) ON DELETE CASCADE,
    category_id INT NOT NULL REFERENCES public.oftar_category(id) ON DELETE CASCADE,
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (concept_version_id, category_id)
);

CREATE TABLE IF NOT EXISTS public.oftar_concept_attribute_rule (
    concept_version_id INT NOT NULL REFERENCES public.oftar_concept_version(id) ON DELETE CASCADE,
    attribute_id INT NOT NULL REFERENCES public.oftar_attribute_definition(id) ON DELETE CASCADE,
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (concept_version_id, attribute_id)
);

CREATE TABLE IF NOT EXISTS public.oftar_concept_mapping (
    id SERIAL PRIMARY KEY,
    concept_version_id INT NOT NULL REFERENCES public.oftar_concept_version(id) ON DELETE CASCADE,
    system_code VARCHAR(30) NOT NULL REFERENCES public.oftar_terminology_system(code),
    external_code VARCHAR(100) NOT NULL,
    external_display VARCHAR(500),
    relationship VARCHAR(30) NOT NULL DEFAULT 'equivalent'
        CHECK (relationship IN ('equivalent','broader','narrower','related','not_mappable')),
    UNIQUE (concept_version_id, system_code, external_code)
);

CREATE TABLE IF NOT EXISTS public.oftar_diagnosis (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL DEFAULT public.oftar_catalog_id('oftar-dx')
        REFERENCES public.oftar_catalog(id),
    code VARCHAR(30) NOT NULL UNIQUE,
    clinical_name TEXT NOT NULL,
    category_id INT REFERENCES public.oftar_category(id),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','inactive','retired')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.oftar_diagnosis_version (
    id SERIAL PRIMARY KEY,
    diagnosis_id INT NOT NULL REFERENCES public.oftar_diagnosis(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    definition TEXT,
    clinical_criteria TEXT,
    approval_status VARCHAR(20) NOT NULL DEFAULT 'draft'
        CHECK (approval_status IN ('draft','review','approved','rejected')),
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    UNIQUE (diagnosis_id, version_number)
);

CREATE TABLE IF NOT EXISTS public.oftar_diagnosis_term (
    id SERIAL PRIMARY KEY,
    diagnosis_id INT NOT NULL REFERENCES public.oftar_diagnosis(id) ON DELETE CASCADE,
    language VARCHAR(10) NOT NULL DEFAULT 'es-AR',
    term VARCHAR(500) NOT NULL,
    term_type VARCHAR(20) NOT NULL DEFAULT 'preferred'
        CHECK (term_type IN ('preferred','synonym','abbreviation'))
);

CREATE TABLE IF NOT EXISTS public.oftar_diagnosis_mapping (
    id SERIAL PRIMARY KEY,
    diagnosis_id INT NOT NULL REFERENCES public.oftar_diagnosis(id) ON DELETE CASCADE,
    system_code VARCHAR(30) NOT NULL REFERENCES public.oftar_terminology_system(code),
    external_code VARCHAR(100) NOT NULL,
    external_display VARCHAR(500),
    mapping_type VARCHAR(30) NOT NULL DEFAULT 'equivalent'
        CHECK (mapping_type IN ('equivalent','broader','narrower','related')),
    UNIQUE (diagnosis_id, system_code, external_code)
);

CREATE TABLE IF NOT EXISTS public.oftar_concept_diagnosis (
    concept_version_id INT NOT NULL REFERENCES public.oftar_concept_version(id) ON DELETE CASCADE,
    diagnosis_id INT NOT NULL REFERENCES public.oftar_diagnosis(id) ON DELETE CASCADE,
    relationship_type VARCHAR(30) NOT NULL DEFAULT 'contextual'
        CHECK (relationship_type IN ('indicacion_habitual','indicacion_posible',
                                     'contraindicacion','contextual')),
    PRIMARY KEY (concept_version_id, diagnosis_id, relationship_type)
);

CREATE OR REPLACE FUNCTION public.oftar_assert_catalog_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_prefix TEXT;
BEGIN
    SELECT upper(code_prefix) INTO v_prefix
      FROM public.oftar_catalog
     WHERE id = NEW.catalog_id;

    IF v_prefix IS NULL THEN
        RAISE EXCEPTION 'catalog_id % no existe en oftar_catalog', NEW.catalog_id;
    END IF;

    IF NEW.code !~ ('^' || v_prefix || '-[0-9]{6}$') THEN
        RAISE EXCEPTION
            'El código % no corresponde al catálogo seleccionado (prefijo esperado: %-NNNNNN).',
            NEW.code, v_prefix
            USING HINT = 'OFTAR-PR usa OFTAR-PR-NNNNNN; OFTAR-DX usa OFTAR-DX-NNNNNN.';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_oftar_concept_code
    BEFORE INSERT OR UPDATE OF code, catalog_id ON public.oftar_concept
    FOR EACH ROW EXECUTE FUNCTION public.oftar_assert_catalog_code();

CREATE OR REPLACE TRIGGER trg_oftar_diagnosis_code
    BEFORE INSERT OR UPDATE OF code, catalog_id ON public.oftar_diagnosis
    FOR EACH ROW EXECUTE FUNCTION public.oftar_assert_catalog_code();

-- =============================================================================
-- 6. VISTA DE FAMILIA
-- =============================================================================
CREATE OR REPLACE VIEW public.v_oftar_family_concept AS
SELECT c.code,
       'oftar-pr'::text AS catalogo,
       c.concept_type::text AS tipo_concepto,
       cv.version_number,
       t.term AS preferred_term_es,
       c.lifecycle_status AS estado
  FROM public.oftar_concept c
  JOIN public.oftar_concept_version cv
    ON cv.id = (
        SELECT max(x.id) FROM public.oftar_concept_version x
         WHERE x.concept_id = c.id AND x.approval_status = 'approved'
    )
  LEFT JOIN public.oftar_term t
    ON t.concept_version_id = cv.id AND t.term_type = 'preferred' AND t.language = 'es-AR'
UNION ALL
SELECT d.code,
       'oftar-dx'::text,
       'diagnosis'::text,
       dv.version_number,
       dt.term,
       d.status
  FROM public.oftar_diagnosis d
  JOIN public.oftar_diagnosis_version dv
    ON dv.id = (
        SELECT max(x.id) FROM public.oftar_diagnosis_version x
         WHERE x.diagnosis_id = d.id AND x.approval_status = 'approved'
    )
  LEFT JOIN public.oftar_diagnosis_term dt
    ON dt.diagnosis_id = d.id AND dt.term_type = 'preferred' AND dt.language = 'es-AR';

COMMENT ON VIEW public.v_oftar_family_concept IS
    'Unión de la versión aprobada más reciente de OFTAR-PR y OFTAR-DX. No expone UVR.';

-- =============================================================================
-- 7. PRIVILEGIOS EXPLÍCITOS
-- =============================================================================
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'oftar_release', 'oftar_category', 'oftar_category_version',
        'oftar_terminology_system', 'oftar_catalog_mapping_rule',
        'oftar_attribute_definition', 'oftar_attribute_value',
        'os_catalog_source_attribute', 'oftar_concept', 'oftar_concept_version',
        'oftar_term', 'oftar_concept_category', 'oftar_concept_attribute_rule',
        'oftar_concept_mapping', 'oftar_diagnosis', 'oftar_diagnosis_version',
        'oftar_diagnosis_term', 'oftar_diagnosis_mapping',
        'oftar_concept_diagnosis', 'v_oftar_family_concept'
    ]
    LOOP
        EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM PUBLIC', t);

        IF to_regrole('origen_admin') IS NOT NULL THEN
            EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM origen_admin', t);
        END IF;

        IF to_regrole('origen_med') IS NOT NULL THEN
            EXECUTE format('GRANT SELECT ON TABLE public.%I TO origen_med', t);
        END IF;
    END LOOP;

    REVOKE ALL PRIVILEGES ON FUNCTION public.oftar_assert_catalog_code() FROM PUBLIC;

    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION public.oftar_assert_catalog_code() FROM origen_admin';
    END IF;

    IF to_regrole('origen_med') IS NOT NULL THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.oftar_assert_catalog_code() TO origen_med';
    END IF;
END $$;

-- =============================================================================
-- 8. VERIFICACIÓN (solo lectura)
-- =============================================================================
SELECT c.code AS catalogo, count(*) AS categorias
  FROM public.oftar_catalog c
  JOIN public.oftar_category cat ON cat.catalog_id = c.id
 GROUP BY c.code
 ORDER BY c.code;

SELECT cat.codigo, pad.code AS padre, cat.orden, cv.language, cv.name
  FROM _oftar_categoria cat
  JOIN public.oftar_catalog oc ON oc.code = cat.catalogo
  JOIN public.oftar_category c ON c.catalog_id = oc.id AND c.code = cat.codigo
  LEFT JOIN public.oftar_category pad ON pad.id = c.parent_id
  JOIN public.oftar_category_version cv
    ON cv.category_id = c.id AND cv.version_number = 1
 ORDER BY cat.catalogo, cat.orden, cv.language, cat.codigo;

SELECT catalogo, count(*) AS idiomas
  FROM (
      SELECT c.code AS catalogo
        FROM public.os_catalog c
        JOIN public.os_catalog_language l ON l.catalog_id = c.id
       WHERE c.code IN ('oftar-pr', 'oftar-dx')
  ) AS s
 GROUP BY catalogo;

COMMIT;

-- Fin de oftar_core.sql
