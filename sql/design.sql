-- Habilitar extensión para búsqueda de texto difusa / rápida en nombres comerciales y clínicos
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ==========================================
-- 1. SNOMED-CT: Conceptos (Núcleo Ontológico)
-- ==========================================
CREATE TABLE snomed_concepts (
    id BIGINT PRIMARY KEY, -- SCTID (SNOMED Concept ID)
    active BOOLEAN NOT NULL DEFAULT TRUE,
    effective_time DATE NOT NULL,
    module_id BIGINT NOT NULL,
    definition_status_id BIGINT NOT NULL
);

CREATE INDEX idx_concepts_active ON snomed_concepts(active);

-- ==========================================
-- 2. SNOMED-CT: Descripciones (Términos y Sinónimos en ES/EN)
-- ==========================================
CREATE TABLE snomed_descriptions (
    id BIGINT PRIMARY KEY,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    effective_time DATE NOT NULL,
    module_id BIGINT NOT NULL,
    concept_id BIGINT NOT NULL REFERENCES snomed_concepts(id) ON DELETE CASCADE,
    language_code VARCHAR(10) NOT NULL, -- 'es', 'en'
    type_id BIGINT NOT NULL, -- 900000000000003001 (Fully specified name), 900000000000013009 (Synonym)
    term TEXT NOT NULL,
    case_significance_id BIGINT NOT NULL
);

-- Índice GIN con Trigramas para búsquedas ultrarrápidas tipo "autocomplete" sobre los términos clínicos
CREATE INDEX idx_descriptions_term_trgm ON snomed_descriptions USING gin (term gin_trgm_ops);
CREATE INDEX idx_descriptions_concept ON snomed_descriptions(concept_id);
CREATE INDEX idx_descriptions_lang ON snomed_descriptions(language_code);

-- ==========================================
-- 3. SNOMED-CT: Relaciones (Jerarquía Is-A y Atributos)
-- ==========================================
CREATE TABLE snomed_relationships (
    id BIGINT PRIMARY KEY,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    effective_time DATE NOT NULL,
    module_id BIGINT NOT NULL,
    source_id BIGINT NOT NULL REFERENCES snomed_concepts(id) ON DELETE CASCADE,
    destination_id BIGINT NOT NULL REFERENCES snomed_concepts(id) ON DELETE CASCADE,
    relationship_group INT NOT NULL,
    type_id BIGINT NOT NULL, -- Ej: 116680003 (Is a)
    characteristic_type_id BIGINT NOT NULL,
    modifier_id BIGINT NOT NULL
);

CREATE INDEX idx_rel_source ON snomed_relationships(source_id, type_id, active);
CREATE INDEX idx_rel_destination ON snomed_relationships(destination_id, type_id, active);

-- ==========================================
-- 4. Catálogo Local: Medicamentos ANMAT (Argentina)
-- ==========================================
CREATE TABLE anmat_medicamentos (
    id SERIAL PRIMARY KEY,
    certificado_number VARCHAR(50) UNIQUE NOT NULL,
    nombre_generico VARCHAR(255) NOT NULL,
    nombre_comercial VARCHAR(255) NOT NULL,
    forma_farmaceutica VARCHAR(100),
    presentacion TEXT,
    laboratorio VARCHAR(150),
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) -- Vínculo opcional con el concepto SNOMED del principio activo
);

CREATE INDEX idx_anmat_comercial_trgm ON anmat_medicamentos USING gin (nombre_comercial gin_trgm_ops);
CREATE INDEX idx_anmat_generico_trgm ON anmat_medicamentos USING gin (nombre_generico gin_trgm_ops);

-- ==========================================
-- 5. Control de Clientes API (B2B SaaS Security)
-- ==========================================
CREATE TABLE api_clients (
    id SERIAL PRIMARY KEY,
    institution_name VARCHAR(150) NOT NULL,
    api_key VARCHAR(64) UNIQUE NOT NULL,
    rate_limit_per_second INT DEFAULT 20,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 6. Catálogo Base CIE-10 (Códigos Universales)
-- ==========================================
CREATE TABLE cie10_codes (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(10) UNIQUE NOT NULL, -- Ej: J18.9, E11.9
    tipo VARCHAR(20) NOT NULL -- 'diagnostico' o 'procedimiento'
);

CREATE INDEX idx_cie10_codigo ON cie10_codes(codigo);

-- ==========================================
-- 7. Descripciones Bilingües de CIE-10
-- ==========================================
CREATE TABLE cie10_descriptions (
    id SERIAL PRIMARY KEY,
    cie10_id INT NOT NULL REFERENCES cie10_codes(id) ON DELETE CASCADE,
    language_code VARCHAR(10) NOT NULL, -- 'es', 'en'
    descripcion TEXT NOT NULL
);

-- Índice GIN con Trigramas para búsquedas ultrarrápidas de texto en ambos idiomas
CREATE INDEX idx_cie10_desc_trgm ON cie10_descriptions USING gin (descripcion gin_trgm_ops);
CREATE INDEX idx_cie10_desc_lang ON cie10_descriptions(language_code);

-- ==========================================
-- 8. Tabla de Mapeo: SNOMED <-> CIE-10
-- ==========================================
CREATE TABLE map_snomed_cie10 (
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE CASCADE,
    cie10_id INT REFERENCES cie10_codes(id) ON DELETE CASCADE,
    PRIMARY KEY (snomed_concept_id, cie10_id)
);

CREATE INDEX idx_map_snomed ON map_snomed_cie10(snomed_concept_id);
CREATE INDEX idx_map_cie10 ON map_snomed_cie10(cie10_id);

-- ==========================================
-- 8.b RefSets SNOMED publicados para filtrado
-- ==========================================
-- Catálogo estable de refsets. Lo mantiene 03_postcarga.sql y sobrevive a las
-- recargas del esquema de staging sct2. `filter_code` es el nombre corto que
-- usa 04_codigos_opcional.sql; NULL = no se publica para filtrado.
CREATE TABLE sct2_refset_catalog (
    refset_id   BIGINT       PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    category    VARCHAR(32)  NOT NULL DEFAULT 'otros',
    description VARCHAR(512) NOT NULL DEFAULT '',
    filter_code VARCHAR(24)
);

CREATE UNIQUE INDEX sct2_refset_catalog_filter_code_uq
    ON sct2_refset_catalog (filter_code)
    WHERE filter_code IS NOT NULL;

-- Miembros de los refsets filtrables. Se reconstruye completa en cada carga
-- de 04_codigos_opcional.sql.
CREATE TABLE snomed_refset_member (
    refset_id   BIGINT       NOT NULL REFERENCES sct2_refset_catalog(refset_id) ON DELETE CASCADE,
    filter_code VARCHAR(24)  NOT NULL,
    concept_id  BIGINT       NOT NULL REFERENCES snomed_concepts(id) ON DELETE CASCADE,
    term        TEXT         NOT NULL,
    map_target  VARCHAR(64),
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (refset_id, concept_id)
);

CREATE INDEX snomed_refset_member_filter_idx
    ON snomed_refset_member (filter_code) WHERE active;
CREATE INDEX snomed_refset_member_concept_idx
    ON snomed_refset_member (concept_id);
CREATE INDEX snomed_refset_member_target_idx
    ON snomed_refset_member (map_target) WHERE map_target IS NOT NULL;
CREATE INDEX snomed_refset_member_term_trgm
    ON snomed_refset_member USING gin (term gin_trgm_ops);

CREATE VIEW v_snomed_refset AS
SELECT m.filter_code,
       c.name AS refset_name,
       c.category,
       m.refset_id,
       m.concept_id,
       m.term,
       m.map_target,
       m.active
  FROM snomed_refset_member m
  JOIN sct2_refset_catalog c ON c.refset_id = m.refset_id;

-- ==========================================
-- 9. Catálogo de Prácticas de Laboratorio y Pruebas Diagnósticas
-- ==========================================
CREATE TABLE laboratorio_practicas (
    id SERIAL PRIMARY KEY,
    codigo_loinc VARCHAR(20), -- Estándar internacional para observaciones de laboratorio (LOINC)
    nombre_prueba TEXT NOT NULL,
    unidad_medida VARCHAR(50), -- Ej: mg/dL, UI/L, mm3
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    activo BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_lab_trgm ON laboratorio_practicas USING gin (nombre_prueba gin_trgm_ops);
CREATE INDEX idx_lab_loinc ON laboratorio_practicas(codigo_loinc);
CREATE INDEX idx_lab_snomed ON laboratorio_practicas(snomed_concept_id);


-- ==========================================
-- 10. Catálogo de Vacunas / Inmunizaciones (Calendario Nacional / NOMIVAC)
-- ==========================================
CREATE TABLE vacunas_catalogo (
    id SERIAL PRIMARY KEY,
    codigo_vacuna_msal VARCHAR(30) UNIQUE NOT NULL, -- Código oficial del Ministerio de Salud / NOMIVAC
    nombre_comercial VARCHAR(150) NOT NULL,
    principio_activo VARCHAR(150) NOT NULL,
    dosis_esquema VARCHAR(100), -- Ej: 1era dosis, Refuerzo, 2da dosis
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL, -- Vínculo al concepto SNOMED
    activo BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_vacunas_trgm ON vacunas_catalogo USING gin (nombre_comercial gin_trgm_ops);
CREATE INDEX idx_vacunas_msal ON vacunas_catalogo(codigo_vacuna_msal);


-- ==========================================
-- 11. Nomenclador Odontológico (FDI / Anatómico / CDT / SNOMED)
-- ==========================================
CREATE TABLE odontologia_prestaciones (
    id SERIAL PRIMARY KEY,
    codigo_nomenclador VARCHAR(30) UNIQUE NOT NULL, -- Código local o de obra social
    descripcion TEXT NOT NULL,
    capitulo VARCHAR(150),
    cdt_code VARCHAR(20),
    cdt_categoria VARCHAR(50),
    cdt_categoria_es VARCHAR(150),
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    requiere_pieza BOOLEAN DEFAULT FALSE,
    face_specification BOOLEAN DEFAULT FALSE, -- Requiere especificación de cara dentaria (vestibular, mesial, etc.)
    requiere_rx_pre BOOLEAN DEFAULT FALSE,
    requiere_rx_post BOOLEAN DEFAULT FALSE,
    ficha_odontologica BOOLEAN DEFAULT FALSE,
    ficha_periodontal BOOLEAN DEFAULT FALSE,
    material VARCHAR(100),
    maxilar VARCHAR(50),
    norma_particular TEXT,
    activo BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_odontologia_trgm ON odontologia_prestaciones USING gin (descripcion gin_trgm_ops);
CREATE INDEX idx_odontologia_codigo ON odontologia_prestaciones(codigo_nomenclador);
CREATE INDEX idx_odontologia_cdt ON odontologia_prestaciones(cdt_code);


-- ==========================================
-- 12. Catálogo de Prestaciones Médicas (Nomenclador Nacional / PMO)
-- ==========================================
CREATE TABLE prestaciones_medicas (
    id SERIAL PRIMARY KEY,
    codigo_prestacion VARCHAR(30) UNIQUE NOT NULL, -- Código del Programa Médico Obligatorio / Nomenclador
    nombre TEXT NOT NULL,
    categoria VARCHAR(100), -- Laboratorio, Diagnóstico por Imágenes, Prácticas Quirúrgicas, etc.
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    activo BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_prestaciones_trgm ON prestaciones_medicas USING gin (nombre gin_trgm_ops);


-- ==========================================
-- 13. Programas Sociales / Coberturas / Atributos Poblacionales
-- ==========================================
CREATE TABLE programas_sociales (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(30) UNIQUE NOT NULL, -- Ej: SUMAR, Remediar, Plan Materno Infantil
    nombre_programa VARCHAR(150) NOT NULL,
    descripcion TEXT,
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    activo BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_programas_trgm ON programas_sociales USING gin (nombre_programa gin_trgm_ops);

-- ==========================================
-- 14. Catálogo: Prácticas de Diagnóstico por Imágenes & Integración PACS/DICOM
-- ==========================================
CREATE TABLE imagenes_practicas (
    id SERIAL PRIMARY KEY,
    codigo_estudio VARCHAR(50) UNIQUE NOT NULL, -- Código local, nomenclador o de la institución
    nombre_estudio TEXT NOT NULL,                -- Descripción clínica de la práctica
    modalidad_dicom VARCHAR(10) NOT NULL,        -- Modalidad DICOM estándar: CT, MR, XR, US, MG, NM, PT, DX
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL, -- Vínculo ontológico a SNOMED
    codigo_loinc VARCHAR(20),                    -- Opcional: Código LOINC para la observación de imagen
    requiere_contraste BOOLEAN DEFAULT FALSE,    -- Indicador clínico relevante
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices GIN con Trigramas para autocompletado y búsqueda rápida por texto en el portal o EMR
CREATE INDEX idx_imagenes_nombre_trgm ON imagenes_practicas USING gin (nombre_estudio gin_trgm_ops);
CREATE INDEX idx_imagenes_modalidad ON imagenes_practicas(modalidad_dicom);
CREATE INDEX idx_imagenes_snomed ON imagenes_practicas(snomed_concept_id);


-- ==========================================
-- 15. Tabla de Registro / Historial de Estudios (Opcional para TaaS / PACS Link)
-- ==========================================
CREATE TABLE imagenes_estudios_pacs (
    id SERIAL PRIMARY KEY,
    patient_id VARCHAR(100) NOT NULL,            -- Identificador del paciente en el EMR
    accession_number VARCHAR(100) UNIQUE NOT NULL, -- Número de orden / acceso único del estudio
    study_instance_uid VARCHAR(128) UNIQUE NOT NULL, -- UID universal DICOM del estudio en el PACS (Orthanc)
    imagenes_practica_id INT REFERENCES imagenes_practicas(id),
    modalidad VARCHAR(10) NOT NULL,
    fecha_estudio TIMESTAMP NOT NULL,
    pacs_server_url VARCHAR(255),                -- Enlace directo al visor (ej. OHIF Viewer URL)
    metadata_json JSONB                          -- Metadatos adicionales flexibles (Series, cantidad de imágenes, etc.)
);

CREATE INDEX idx_pacs_study_uid ON imagenes_estudios_pacs(study_instance_uid);
CREATE INDEX idx_pacs_accession ON imagenes_estudios_pacs(accession_number);

