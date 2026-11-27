-- =============================================================================
-- 06_programas / 04_vacunas_eno_dispositivos.sql
-- Carga desde SNOMED CT Argentina 2026:
--   1. Vacunas / Inmunizaciones notificables (2281000221106) -> vacunas_catalogo
--   2. Enfermedades de Notificación Obligatoria (651000221107) -> programas_sociales_items ('ENO')
--   3. Dispositivos médicos prescribibles (869651000221108) -> dispositivos_medicos
-- =============================================================================

SET client_encoding = 'UTF8';
SET search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Verificar dependencias
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vacunas_catalogo') THEN
        RAISE EXCEPTION 'Tabla vacunas_catalogo no existe.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'programas_sociales_items') THEN
        RAISE EXCEPTION 'Tabla programas_sociales_items no existe.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM snomed_concepts LIMIT 1) THEN
        RAISE EXCEPTION 'snomed_concepts está vacía.';
    END IF;
    RAISE NOTICE 'Dependencias OK.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Crear tabla dispositivos_medicos (si no existe)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dispositivos_medicos (
    id                 SERIAL PRIMARY KEY,
    snomed_concept_id  BIGINT UNIQUE NOT NULL REFERENCES snomed_concepts(id) ON DELETE CASCADE,
    termino            TEXT NOT NULL,
    refset_id          BIGINT NOT NULL,
    effective_date     DATE,
    activo             BOOLEAN DEFAULT TRUE,
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_disp_snomed ON dispositivos_medicos(snomed_concept_id);
CREATE INDEX IF NOT EXISTS idx_disp_termino_trgm ON dispositivos_medicos
    USING gin (f_unaccent(termino) gin_trgm_ops);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Staging
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS _stg_vac;
DROP TABLE IF EXISTS _stg_eno;
DROP TABLE IF EXISTS _stg_disp;

CREATE TEMP TABLE _stg_vac (
    id_row             UUID,
    effective_time     TEXT,
    active             TEXT,
    module_id          BIGINT,
    refset_id          BIGINT,
    refset_term        TEXT,
    snomed_concept_id  BIGINT,
    termino            TEXT
);
CREATE TEMP TABLE _stg_eno  (LIKE _stg_vac);
CREATE TEMP TABLE _stg_disp (LIKE _stg_vac);

\copy _stg_vac  FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_vacunas_228.txt'      WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');
\copy _stg_eno  FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_eno_651.txt'          WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');
\copy _stg_disp FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_dispositivos_869.txt' WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');

SELECT 'Vacunas staging'      AS fuente, COUNT(*) AS filas FROM _stg_vac
UNION ALL SELECT 'ENO staging',          COUNT(*) FROM _stg_eno
UNION ALL SELECT 'Dispositivos staging', COUNT(*) FROM _stg_disp;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Cargar Vacunas -> vacunas_catalogo
-- ─────────────────────────────────────────────────────────────────────────────
WITH ins AS (
    INSERT INTO vacunas_catalogo (
        codigo_vacuna_msal, nombre_comercial, principio_activo,
        snomed_concept_id, activo
    )
    SELECT DISTINCT ON (s.snomed_concept_id)
        'SCT-' || s.snomed_concept_id::TEXT,
        LEFT(TRIM(s.termino), 150),
        LEFT(TRIM(s.termino), 150),
        sc.id,
        TRUE
    FROM _stg_vac s
    JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
    WHERE s.active = '1'
      AND TRIM(COALESCE(s.termino, '')) <> ''
    ORDER BY s.snomed_concept_id
    ON CONFLICT (codigo_vacuna_msal) DO UPDATE
        SET nombre_comercial  = EXCLUDED.nombre_comercial,
            principio_activo  = EXCLUDED.principio_activo,
            snomed_concept_id = EXCLUDED.snomed_concept_id,
            activo            = TRUE
    RETURNING 1
)
SELECT COUNT(*) AS vacunas_upserted FROM ins;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Cargar ENO -> programas_sociales + programas_sociales_items
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO programas_sociales (codigo, nombre_programa, descripcion, activo)
VALUES (
    'ENO',
    'Enfermedades de Notificación Obligatoria (ENO)',
    'Eventos y enfermedades de notificación obligatoria para vigilancia epidemiológica (SISA / MSAL Argentina). Fuente: SNOMED CT Argentina 2026-08-20.',
    TRUE
)
ON CONFLICT (codigo) DO UPDATE
    SET nombre_programa = EXCLUDED.nombre_programa,
        descripcion     = EXCLUDED.descripcion,
        activo          = TRUE;

DO $$
DECLARE
    v_prog_id INTEGER;
    v_ins_eno INTEGER;
BEGIN
    SELECT id INTO v_prog_id FROM programas_sociales WHERE codigo = 'ENO';

    WITH ins AS (
        INSERT INTO programas_sociales_items (
            programa_id, snomed_concept_id, tipo_item, termino, refset_id, effective_date, active
        )
        SELECT DISTINCT ON (s.snomed_concept_id)
            v_prog_id,
            sc.id,
            'diagnostico',
            TRIM(s.termino),
            s.refset_id,
            TO_DATE(s.effective_time, 'YYYYMMDD'),
            TRUE
        FROM _stg_eno s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ORDER BY s.snomed_concept_id
        ON CONFLICT (programa_id, snomed_concept_id, tipo_item) DO UPDATE
            SET termino        = EXCLUDED.termino,
                effective_date = EXCLUDED.effective_date,
                active         = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_eno FROM ins;

    RAISE NOTICE 'ENO items insertados/actualizados: %', v_ins_eno;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Cargar Dispositivos Médicos -> dispositivos_medicos
-- ─────────────────────────────────────────────────────────────────────────────
WITH ins AS (
    INSERT INTO dispositivos_medicos (
        snomed_concept_id, termino, refset_id, effective_date, activo
    )
    SELECT DISTINCT ON (s.snomed_concept_id)
        sc.id,
        TRIM(s.termino),
        s.refset_id,
        TO_DATE(s.effective_time, 'YYYYMMDD'),
        TRUE
    FROM _stg_disp s
    JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
    WHERE s.active = '1'
      AND TRIM(COALESCE(s.termino, '')) <> ''
    ORDER BY s.snomed_concept_id
    ON CONFLICT (snomed_concept_id) DO UPDATE
        SET termino        = EXCLUDED.termino,
            refset_id      = EXCLUDED.refset_id,
            effective_date = EXCLUDED.effective_date,
            activo         = TRUE
    RETURNING 1
)
SELECT COUNT(*) AS dispositivos_upserted FROM ins;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Verificación final
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'vacunas_catalogo' AS tabla, COUNT(*) AS activos FROM vacunas_catalogo WHERE activo = TRUE
UNION ALL
SELECT 'ENO (programas_sociales_items)', COUNT(*) FROM programas_sociales_items
    WHERE programa_id = (SELECT id FROM programas_sociales WHERE codigo = 'ENO') AND active = TRUE
UNION ALL
SELECT 'dispositivos_medicos', COUNT(*) FROM dispositivos_medicos WHERE activo = TRUE;

ANALYZE vacunas_catalogo;
ANALYZE programas_sociales_items;
ANALYZE dispositivos_medicos;

DO $$ BEGIN RAISE NOTICE 'Carga Vacunas, ENO y Dispositivos finalizada.'; END $$;
