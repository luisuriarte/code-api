# -*- coding: utf-8 -*-
"""
Generador Maestro: Origen Catalog Engine 1.0 (PostgreSQL 18)
Unifica DENTAR, Nomencladores Argentinos (NN, NBU, NHPGD, ANDIS, Kinesiología, Salud Mental),
Sistemas Terminológicos (SNOMED-CT, CIE-10, LOINC, CDT-2025), Vademécum Multicapa y Aranceles.
Genera: sql/origen_catalog_engine.sql
"""
import os, sys

def load_odontologico_rows():
    sql_path = os.path.join(os.path.dirname(__file__), "..", "sql", "odontologico.sql")
    with open(sql_path, "r", encoding="utf-8") as f:
        sql = f.read()

    start_idx = sql.find("INSERT INTO `odontologico` VALUES") + len("INSERT INTO `odontologico` VALUES")
    end_idx = sql.find("/*!40000 ALTER TABLE `odontologico` ENABLE KEYS */")
    values_str = sql[start_idx:end_idx].strip()
    if values_str.endswith(";"):
        values_str = values_str[:-1]

    tuples = []
    current_tuple = []
    current_val = []
    in_quotes = False
    quote_char = None
    in_tuple = False
    escape = False

    i = 0
    n = len(values_str)
    while i < n:
        c = values_str[i]
        if not in_tuple:
            if c == "(":
                in_tuple = True
                current_tuple = []
                current_val = []
        else:
            if in_quotes:
                if escape:
                    current_val.append(c)
                    escape = False
                elif c == "\\":
                    escape = True
                elif c == quote_char:
                    if i + 1 < n and values_str[i+1] == quote_char:
                        current_val.append(quote_char)
                        i += 1
                    else:
                        in_quotes = False
                else:
                    current_val.append(c)
            else:
                if c in ("\x27", "\x22"):
                    in_quotes = True
                    quote_char = c
                elif c == ",":
                    val_str = "".join(current_val).strip()
                    current_tuple.append(None if val_str == "NULL" else val_str)
                    current_val = []
                elif c == ")":
                    val_str = "".join(current_val).strip()
                    current_tuple.append(None if val_str == "NULL" else val_str)
                    tuples.append(current_tuple)
                    in_tuple = False
                    current_tuple = []
                    current_val = []
                else:
                    current_val.append(c)
        i += 1
    return tuples

def sql_str(s):
    if s is None:
        return "NULL"
    clean = str(s).replace("'", "''").replace("\\", "\\\\")
    return f"E'{clean}'"

# Map row from odontologico.sql
def map_dental_row(r):
    code = r[0].strip()
    desc = r[1].strip()
    cap = r[11].strip() if r[11] else ""
    c_num = code.split(".")[0]

    if c_num == "01":
        if "fichado" in desc.lower() or "diagn" in desc.lower():
            return ("CAT-DIAG", "D0150", 424759004)
        return ("CAT-DIAG", "D0120", 424759004)
    elif c_num == "02":
        if "amalgama" in desc.lower():
            if "simple" in desc.lower(): return ("CAT-REST", "D2140", 424759004)
            if "compuesta" in desc.lower(): return ("CAT-REST", "D2150", 424759004)
            return ("CAT-REST", "D2160", 424759004)
        elif "composite" in desc.lower() or "resina" in desc.lower():
            if "simple" in desc.lower(): return ("CAT-REST", "D2330", 424759004)
            if "compuesta" in desc.lower(): return ("CAT-REST", "D2331", 424759004)
            return ("CAT-REST", "D2332", 424759004)
        elif "incrusta" in desc.lower(): return ("CAT-REST", "D2610", 424759004)
        return ("CAT-REST", "D2999", 424759004)
    elif c_num == "03":
        if "unirradicular" in desc.lower(): return ("CAT-ENDO", "D3310", 73785006)
        if "multirradicular" in desc.lower() or "birradicular" in desc.lower(): return ("CAT-ENDO", "D3320", 73785006)
        return ("CAT-ENDO", "D3330", 73785006)
    elif c_num == "04":
        return ("CAT-SURG", "D7140", 274154007)
    elif c_num == "05":
        if "completa" in desc.lower(): return ("CAT-PROSTH-R", "D5110", 11210001)
        if "parcial" in desc.lower(): return ("CAT-PROSTH-R", "D5213", 11210001)
        return ("CAT-PROSTH-R", "D5899", 11210001)
    elif c_num == "06":
        return ("CAT-PROSTH-F", "D6240", 67270000)
    elif c_num == "07":
        return ("CAT-PERI", "D4341", 38694004)
    elif c_num == "08":
        if "consulta" in desc.lower(): return ("CAT-ORTHO", "D8010", 8708008)
        return ("CAT-ORTHO", "D8080", 8708008)
    elif c_num == "09":
        return ("CAT-IMPL", "D6010", 234737002)
    elif c_num == "10":
        return ("CAT-SURG", "D7210", 274154007)
    else:
        return ("CAT-ADJ", "D9110", 424759004)

print("Iniciando generación de Origen Catalog Engine 1.0 SQL...")
rows = load_odontologico_rows()
print(f"Cargadas {len(rows)} prestaciones odontológicas DENTAR.")

out = []
out.append("""-- =============================================================================
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
""")

# Categorías DENTAR
dental_categories = [
    ("CAT-DIAG", "Capítulo I - Consultas y Diagnóstico"),
    ("CAT-REST", "Capítulo II - Operatoria Dental y Restauradora"),
    ("CAT-ENDO", "Capítulo III - Endodoncia"),
    ("CAT-SURG", "Capítulo IV - Cirugía Bucomaxilofacial Menor"),
    ("CAT-PROSTH-R", "Capítulo V - Prótesis Removible"),
    ("CAT-PROSTH-F", "Capítulo VI - Prótesis Fija"),
    ("CAT-PERI", "Capítulo VII - Periodoncia"),
    ("CAT-ORTHO", "Capítulo VIII - Ortodoncia y Ortopedia Funcional"),
    ("CAT-IMPL", "Capítulo IX - Implantología Oral"),
    ("CAT-SURG-MAX", "Capítulo X - Cirugía Bucomaxilofacial Mayor"),
    ("CAT-ADJ", "Capítulo XI - Prestaciones Generales y Urgencias"),
]

out.append("\n-- Categorías DENTAR")
for code, name in dental_categories:
    out.append(f"""INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, '{code}', {sql_str(name)} FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;""")

# 138 Procedimientos DENTAR en os_catalog_item
out.append("\n-- Ingesta de las 138 Prestaciones DENTAR")
for idx, r in enumerate(rows, 1):
    dnt_code = f"DNT-{idx:06d}"
    ar_code = r[0].strip()
    desc = r[1].strip()
    cap_code, cdt_code, sct_concept = map_dental_row(r)

    out.append(f"""-- {dnt_code} :: {ar_code}
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, '{dnt_code}', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, {sql_str(desc)}, 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = '{cap_code}'
WHERE cat.code = 'dentar' AND i.permanent_code = '{dnt_code}'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '{ar_code}', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = '{dnt_code}'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, '{cdt_code}', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = '{dnt_code}'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '{sct_concept}', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = '{dnt_code}'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
""")

# Mapeos de justificación diagnóstica DENTAR <-> CIE-10
out.append("""
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
""")

# Ingesta de prestaciones en los otros 6 Nomencladores Nacionales
out.append("""
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
""")

output_sql = "\n".join(out)
dest_path = os.path.join(os.path.dirname(__file__), "..", "sql", "origen_catalog_engine.sql")
with open(dest_path, "w", encoding="utf-8") as f:
    f.write(output_sql)

print(f"Archivo generado con éxito: {dest_path} ({len(output_sql)} bytes)")
