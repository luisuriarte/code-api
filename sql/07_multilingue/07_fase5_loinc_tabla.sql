-- =============================================================================
-- FASE 5 · LOINC: tabla especializada y regla central de prioridad
-- =============================================================================
-- Entorno de PRUEBAS. Aditivo e idempotente. Ejecutar DENTRO de transacción.
-- NO modifica el importador sql/05_loinc.sql/importar_loinc.sql.
-- NO contiene DROP, TRUNCATE ni DELETE.
-- Fuentes: modelo §4.4; plan Fase 5; D-08, D-29, D-33, D-39, D-40.
--
-- source_release = '2.83' CONFIRMADO: tools/sources/loinc/Loinc.csv contiene
--   VersionLastChanged="2.83" y la cabecera de importar_loinc.sql (líneas 2-5)
--   declara "LOINC 2.83". No es un valor supuesto.
-- NO se almacena source_language_code (D-40): se deriva con
--   loinc_source_language(language_code, source_file).
-- es-AR sigue activo y seleccionable en os_language (D-39).
-- Las capas es-MX/es-AR originales NO se recuperan de la BD: fueron
--   sobrescritas por el importador; requieren reimportar los CSV.
-- =============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS loinc_localized_text (
    id                              BIGSERIAL PRIMARY KEY,
    loinc_code                      VARCHAR(20) NOT NULL REFERENCES loinc(loinc) ON DELETE CASCADE,
    language_code                   VARCHAR(10) NOT NULL,
    field_name                      VARCHAR(40) NOT NULL,
    value                           TEXT NOT NULL,
    source_file                     VARCHAR(80) NOT NULL,
    source_release                  VARCHAR(20) NOT NULL,
    version_last_changed            VARCHAR(50),
    version_last_changed_normalizada VARCHAR(50) NOT NULL,
    source_priority                 INT NOT NULL,
    language_evidence               VARCHAR(24) NOT NULL DEFAULT 'undetermined',
    provenance                      VARCHAR(24) NOT NULL DEFAULT 'unknown',
    review_status                   VARCHAR(20) NOT NULL DEFAULT 'unknown',
    source_reference                TEXT,
    content_hash                    TEXT NOT NULL,
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_llt_source UNIQUE (
        loinc_code, language_code, field_name, source_file, source_release,
        version_last_changed_normalizada)
);

COMMENT ON TABLE loinc_localized_text IS
    'Capas LOINC por (código, idioma, campo, archivo, release, versión). Ninguna variante sobrescribe a otra (D-08/D-33).';
COMMENT ON COLUMN loinc_localized_text.source_priority IS
    'Calculado SOLO por loinc_source_priority(); materializado, nunca repartido entre importadores.';
COMMENT ON COLUMN loinc_localized_text.version_last_changed_normalizada IS
    'Normalización documentada: recorte de espacios y NULL/cadena vacía -> (sin_version).';

-- ---------------------------------------------------------------------------
-- Regla central de normalización de versión (D-08)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION loinc_version_normalizada(p_version VARCHAR(50))
RETURNS VARCHAR(50) LANGUAGE sql IMMUTABLE AS $$
    SELECT COALESCE(NULLIF(btrim(p_version), ''), '(sin_version)')::VARCHAR(50);
$$;

-- ---------------------------------------------------------------------------
-- Prioridad determinista por idioma / archivo / campo (D-33)
--   0 = combinación no acreditada: la fila no es publicable.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION loinc_source_priority(
    p_language VARCHAR(10), p_source_file VARCHAR(80), p_field_name VARCHAR(40))
RETURNS INT LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN p_language = 'en'    AND p_source_file = 'Loinc.csv'
            THEN 10
        WHEN p_language = 'en'    AND p_source_file = 'ConsumerName.csv'
             AND p_field_name = 'consumer_name'
            THEN 20
        WHEN p_language = 'es-MX' AND p_source_file = 'esMX28LinguisticVariant.csv'
            THEN 10
        WHEN p_language = 'es-AR' AND p_source_file = 'esAR7LinguisticVariant.csv'
            THEN 10
        ELSE 0
    END;
$$;

-- ---------------------------------------------------------------------------
-- Idioma de origen derivado, NO almacenado (D-40)
-- Devuelve NULL si el archivo no acredita el idioma declarado: la fila no se publica.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION loinc_source_language(
    p_language VARCHAR(10), p_source_file VARCHAR(80))
RETURNS VARCHAR(10) LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN p_language = 'en'    AND p_source_file IN ('Loinc.csv','ConsumerName.csv')
            THEN 'en'::VARCHAR(10)
        WHEN p_language = 'es-MX' AND p_source_file = 'esMX28LinguisticVariant.csv'
            THEN 'es-MX'::VARCHAR(10)
        WHEN p_language = 'es-AR' AND p_source_file = 'esAR7LinguisticVariant.csv'
            THEN 'es-AR'::VARCHAR(10)
        ELSE NULL
    END;
$$;

-- ---------------------------------------------------------------------------
-- Trigger de carga: normaliza, calcula prioridad, evidencia y hash (D-31/D-33/D-40)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_loinc_load() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.version_last_changed_normalizada :=
        loinc_version_normalizada(NEW.version_last_changed);
    NEW.source_priority :=
        loinc_source_priority(NEW.language_code, NEW.source_file, NEW.field_name);
    NEW.language_evidence := CASE
        WHEN loinc_source_language(NEW.language_code, NEW.source_file) IS NULL
            THEN 'undetermined'
        ELSE 'declared_by_source'
    END;
    NEW.content_hash := md5(
        COALESCE(NEW.value, '') || E'\x1f' || NEW.language_code || E'\x1f' ||
        NEW.field_name || E'\x1f' || NEW.source_file || E'\x1f' ||
        NEW.source_release || E'\x1f' || NEW.version_last_changed_normalizada);
    IF TG_OP = 'UPDATE' THEN
        NEW.updated_at := now();
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_llt_load
    BEFORE INSERT OR UPDATE ON loinc_localized_text
    FOR EACH ROW EXECUTE FUNCTION trg_loinc_load();

-- Auditoría: matricial D-29 pasa de 7 a 8 tablas.
CREATE OR REPLACE TRIGGER trg_llt_audit
    AFTER INSERT OR UPDATE OR DELETE ON loinc_localized_text
    FOR EACH ROW EXECUTE FUNCTION trg_audit_content('field_name','value','field_individual');

COMMIT;

-- Fin de Fase 5 · tabla y reglas.
