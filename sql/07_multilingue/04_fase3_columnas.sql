-- =============================================================================
-- FASE 3 · Columnas aditivas en tablas existentes
-- =============================================================================
-- Entorno de PRUEBAS. Aditivo e idempotente: ADD COLUMN IF NOT EXISTS.
-- NO modifica columnas originales, NO borra nada. Ejecutar dentro de transacción.
-- Fuentes: modelo §4.1-§4.4; plan Fase 3; D-31, D-32, D-36, D-40.
--
-- D-36: semántica conocida -> NOT NULL con DEFAULT; sin evidencia -> NULL.
-- content_hash se agrega con centinela '' (provisional). El trigger de 05 lo
-- sustituye por el md5 real en Fase 4 (06). El centinela NO es una aprobación.
-- source_language_code NO lleva FK (puede contener tags RF2 como 'es').
-- os_concept_mapping YA TIENE review_status con CHECK propio
--   (draft|reviewed|approved|deprecated): NO se agrega de nuevo ni se modifica
--   ese CHECK. La revisión editorial por campo vive en os_field_review.
-- D-40: el source_language_code de LOINC se deriva con loinc_source_language(...)
--   en Fase 5; NO se agrega aquí columna a loinc.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- os_catalog_item_version (§4.1): seis campos clínicos + metadatos
-- ---------------------------------------------------------------------------
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS source_language_code VARCHAR(10);
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS language_evidence    VARCHAR(24) NOT NULL DEFAULT 'undetermined';
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS provenance           VARCHAR(24) NOT NULL DEFAULT 'unknown';
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS review_status        VARCHAR(20) NOT NULL DEFAULT 'unknown';
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS source_reference     TEXT;
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS reviewed_by          VARCHAR(120);
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS reviewed_at          TIMESTAMPTZ;
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS content_hash         TEXT NOT NULL DEFAULT '';
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS updated_at           TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS valid_from           DATE;
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS valid_to             DATE;
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS short_definition     VARCHAR(255);
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS lay_terms            TEXT;
ALTER TABLE os_catalog_item_version ADD COLUMN IF NOT EXISTS clinical_scope       TEXT;

-- ---------------------------------------------------------------------------
-- os_catalog_term (§4.2): sinónimos, siglas y variantes
-- ---------------------------------------------------------------------------
ALTER TABLE os_catalog_term ADD COLUMN IF NOT EXISTS source_language_code VARCHAR(10);
ALTER TABLE os_catalog_term ADD COLUMN IF NOT EXISTS language_evidence    VARCHAR(24) NOT NULL DEFAULT 'undetermined';
ALTER TABLE os_catalog_term ADD COLUMN IF NOT EXISTS provenance           VARCHAR(24) NOT NULL DEFAULT 'unknown';
ALTER TABLE os_catalog_term ADD COLUMN IF NOT EXISTS review_status        VARCHAR(20) NOT NULL DEFAULT 'unknown';
ALTER TABLE os_catalog_term ADD COLUMN IF NOT EXISTS source_reference     TEXT;
ALTER TABLE os_catalog_term ADD COLUMN IF NOT EXISTS reviewed_by          VARCHAR(120);
ALTER TABLE os_catalog_term ADD COLUMN IF NOT EXISTS reviewed_at          TIMESTAMPTZ;
ALTER TABLE os_catalog_term ADD COLUMN IF NOT EXISTS content_hash         TEXT NOT NULL DEFAULT '';
ALTER TABLE os_catalog_term ADD COLUMN IF NOT EXISTS updated_at           TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE os_catalog_term ADD COLUMN IF NOT EXISTS valid_from           DATE;
ALTER TABLE os_catalog_term ADD COLUMN IF NOT EXISTS valid_to             DATE;

-- ---------------------------------------------------------------------------
-- snomed_descriptions (§4.3): estructura nativa, NO se migra a localized_text
-- ---------------------------------------------------------------------------
ALTER TABLE snomed_descriptions ADD COLUMN IF NOT EXISTS rf2_language_tag    VARCHAR(10);
ALTER TABLE snomed_descriptions ADD COLUMN IF NOT EXISTS provenance          VARCHAR(24) NOT NULL DEFAULT 'unknown';
ALTER TABLE snomed_descriptions ADD COLUMN IF NOT EXISTS source_reference    TEXT;
ALTER TABLE snomed_descriptions ADD COLUMN IF NOT EXISTS dialect_determined  BOOLEAN;
ALTER TABLE snomed_descriptions ADD COLUMN IF NOT EXISTS language_evidence   VARCHAR(24) NOT NULL DEFAULT 'undetermined';
ALTER TABLE snomed_descriptions ADD COLUMN IF NOT EXISTS content_hash        TEXT NOT NULL DEFAULT '';

-- ---------------------------------------------------------------------------
-- cie10_descriptions (§4.3): CIE-10 no tiene effective_time; no se inventa
-- ---------------------------------------------------------------------------
ALTER TABLE cie10_descriptions ADD COLUMN IF NOT EXISTS provenance       VARCHAR(24) NOT NULL DEFAULT 'unknown';
ALTER TABLE cie10_descriptions ADD COLUMN IF NOT EXISTS source_reference TEXT;
ALTER TABLE cie10_descriptions ADD COLUMN IF NOT EXISTS content_hash     TEXT NOT NULL DEFAULT '';

-- ---------------------------------------------------------------------------
-- os_concept_mapping (§4.4 / plan Fase 3): SIN review_status nuevo
-- ---------------------------------------------------------------------------
ALTER TABLE os_concept_mapping ADD COLUMN IF NOT EXISTS source_language_code         VARCHAR(10);
ALTER TABLE os_concept_mapping ADD COLUMN IF NOT EXISTS language_evidence            VARCHAR(24) NOT NULL DEFAULT 'undetermined';
ALTER TABLE os_concept_mapping ADD COLUMN IF NOT EXISTS provenance                   VARCHAR(24) NOT NULL DEFAULT 'unknown';
ALTER TABLE os_concept_mapping ADD COLUMN IF NOT EXISTS source_reference             TEXT;
ALTER TABLE os_concept_mapping ADD COLUMN IF NOT EXISTS reviewed_by                  VARCHAR(120);
ALTER TABLE os_concept_mapping ADD COLUMN IF NOT EXISTS reviewed_at                  TIMESTAMPTZ;
ALTER TABLE os_concept_mapping ADD COLUMN IF NOT EXISTS content_hash                 TEXT NOT NULL DEFAULT '';
ALTER TABLE os_concept_mapping ADD COLUMN IF NOT EXISTS updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE os_concept_mapping ADD COLUMN IF NOT EXISTS valid_from                   DATE;
ALTER TABLE os_concept_mapping ADD COLUMN IF NOT EXISTS valid_to                     DATE;
-- external_display llega en inglés del estándar (p. ej. 'ADA CDT 2025'): se
-- informa sin alterar language_code del concepto. Si difiere por campo, prevalece
-- os_field_review; esta columna NO duplica su función.
ALTER TABLE os_concept_mapping ADD COLUMN IF NOT EXISTS source_language_code_display VARCHAR(10);

COMMENT ON COLUMN os_catalog_item_version.content_hash IS
    'md5 de los seis campos clínicos no cubiertos por os_field_review (D-41 row_shared). Centinela inicial: cadena vacía.';
COMMENT ON COLUMN os_field_review.content_hash IS
    'md5 del campo individual, su idioma y su referencia (D-41 field_individual).';

COMMIT;

-- Fin de Fase 3 · columnas.
