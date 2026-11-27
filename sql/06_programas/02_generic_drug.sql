-- =============================================================================
-- 06_programas / 02_generic_drug.sql
-- Carga de fármacos genéricos SNOMED CT Argentina 2026 → tabla generic_drug
--
-- Fuentes (en VPS): tools/sources/snomed_argentina/
--   snomed_genericos_sin_pres.txt      → refset 425091 (3.641 filas)
--   snomed_genericos_con_pres.txt      → refset 425081 (9.389 filas)
--   snomed_genericos_sin_pres_com.txt  → refset 574481 (1.254 filas, comerc.)
--   snomed_genericos_con_pres_com.txt  → refset 574471 (4.593 filas, comerc.)
--
-- Tabla destino: generic_drug (creada en este script si no existe)
--   Columnas clave: snomed_concept_id, termino, tipo_generico, con_presentacion
-- =============================================================================

SET client_encoding = 'UTF8';
SET search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Verificar dependencias
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM snomed_concepts LIMIT 1) THEN
        RAISE EXCEPTION 'snomed_concepts está vacía.';
    END IF;
    RAISE NOTICE 'Dependencias OK.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Crear tabla generic_drug (si no existe)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS generic_drug (
    id                 SERIAL PRIMARY KEY,
    snomed_concept_id  BIGINT UNIQUE NOT NULL REFERENCES snomed_concepts(id) ON DELETE CASCADE,
    termino            TEXT NOT NULL,
    -- Clasificación del concepto
    tipo_generico      VARCHAR(30) NOT NULL DEFAULT 'generico'
                           CHECK (tipo_generico IN ('generico','generico_comercializado')),
    con_presentacion   BOOLEAN NOT NULL DEFAULT FALSE,
                       -- TRUE = tiene unidad de presentación definida (425081/574471)
                       -- FALSE = sin unidad de presentación (425091/574481)
    refset_id          BIGINT,
    effective_date     DATE,
    active             BOOLEAN DEFAULT TRUE,
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_gd_snomed  ON generic_drug(snomed_concept_id);
CREATE INDEX IF NOT EXISTS idx_gd_tipo    ON generic_drug(tipo_generico, con_presentacion);
CREATE INDEX IF NOT EXISTS idx_gd_termino_trgm ON generic_drug
    USING gin (f_unaccent(termino) gin_trgm_ops);

DO $$ BEGIN RAISE NOTICE 'Tabla generic_drug lista.'; END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Tablas de staging
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS _stg_gd_sp;
DROP TABLE IF EXISTS _stg_gd_cp;
DROP TABLE IF EXISTS _stg_gd_spc;
DROP TABLE IF EXISTS _stg_gd_cpc;

CREATE TEMP TABLE _stg_gd_sp (
    id_row             UUID,
    effective_time     TEXT,
    active             TEXT,
    module_id          BIGINT,
    refset_id          BIGINT,
    refset_term        TEXT,
    snomed_concept_id  BIGINT,
    termino            TEXT
);
CREATE TEMP TABLE _stg_gd_cp  (LIKE _stg_gd_sp);
CREATE TEMP TABLE _stg_gd_spc (LIKE _stg_gd_sp);
CREATE TEMP TABLE _stg_gd_cpc (LIKE _stg_gd_sp);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Cargar fuentes
-- ─────────────────────────────────────────────────────────────────────────────
\copy _stg_gd_sp  FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_genericos_sin_pres.txt'     WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');
\copy _stg_gd_cp  FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_genericos_con_pres.txt'     WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');
\copy _stg_gd_spc FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_genericos_sin_pres_com.txt' WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');
\copy _stg_gd_cpc FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_genericos_con_pres_com.txt' WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');

SELECT fuente, COUNT(*) AS filas FROM (
    SELECT '425091 sin_pres'     AS fuente FROM _stg_gd_sp
    UNION ALL SELECT '425081 con_pres'     FROM _stg_gd_cp
    UNION ALL SELECT '574481 sin_pres_com' FROM _stg_gd_spc
    UNION ALL SELECT '574471 con_pres_com' FROM _stg_gd_cpc
) t GROUP BY fuente ORDER BY fuente;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Insertar / actualizar en generic_drug
--    Prioridad: comercializado > base; con_pres > sin_pres en caso de conflicto
--    ON CONFLICT (snomed_concept_id) → actualizar si el nuevo es más reciente
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_ins_sp  INTEGER;
    v_ins_cp  INTEGER;
    v_ins_spc INTEGER;
    v_ins_cpc INTEGER;
BEGIN
    -- 4a. 425091 — genéricos sin presentación (base)
    WITH ins AS (
        INSERT INTO generic_drug (snomed_concept_id, termino, tipo_generico, con_presentacion, refset_id, effective_date)
        SELECT s.snomed_concept_id, s.termino, 'generico', FALSE,
               s.refset_id, TO_DATE(s.effective_time, 'YYYYMMDD')
        FROM _stg_gd_sp s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (snomed_concept_id) DO UPDATE
            SET termino        = EXCLUDED.termino,
                tipo_generico  = EXCLUDED.tipo_generico,
                con_presentacion = EXCLUDED.con_presentacion,
                effective_date = EXCLUDED.effective_date,
                active         = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_sp FROM ins;

    -- 4b. 425081 — genéricos con presentación (base)
    WITH ins AS (
        INSERT INTO generic_drug (snomed_concept_id, termino, tipo_generico, con_presentacion, refset_id, effective_date)
        SELECT s.snomed_concept_id, s.termino, 'generico', TRUE,
               s.refset_id, TO_DATE(s.effective_time, 'YYYYMMDD')
        FROM _stg_gd_cp s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (snomed_concept_id) DO UPDATE
            SET termino        = EXCLUDED.termino,
                tipo_generico  = EXCLUDED.tipo_generico,
                con_presentacion = EXCLUDED.con_presentacion,
                effective_date = EXCLUDED.effective_date,
                active         = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_cp FROM ins;

    -- 4c. 574481 — genéricos sin presentación, en comercialización (sobreescribe)
    WITH ins AS (
        INSERT INTO generic_drug (snomed_concept_id, termino, tipo_generico, con_presentacion, refset_id, effective_date)
        SELECT s.snomed_concept_id, s.termino, 'generico_comercializado', FALSE,
               s.refset_id, TO_DATE(s.effective_time, 'YYYYMMDD')
        FROM _stg_gd_spc s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (snomed_concept_id) DO UPDATE
            SET termino        = EXCLUDED.termino,
                tipo_generico  = 'generico_comercializado',
                con_presentacion = EXCLUDED.con_presentacion,
                effective_date = EXCLUDED.effective_date,
                active         = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_spc FROM ins;

    -- 4d. 574471 — genéricos con presentación, en comercialización (sobreescribe)
    WITH ins AS (
        INSERT INTO generic_drug (snomed_concept_id, termino, tipo_generico, con_presentacion, refset_id, effective_date)
        SELECT s.snomed_concept_id, s.termino, 'generico_comercializado', TRUE,
               s.refset_id, TO_DATE(s.effective_time, 'YYYYMMDD')
        FROM _stg_gd_cpc s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (snomed_concept_id) DO UPDATE
            SET termino        = EXCLUDED.termino,
                tipo_generico  = 'generico_comercializado',
                con_presentacion = EXCLUDED.con_presentacion,
                effective_date = EXCLUDED.effective_date,
                active         = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_cpc FROM ins;

    RAISE NOTICE 'Genéricos insertados/actualizados:';
    RAISE NOTICE '  425091 sin_pres (generico)              : %', v_ins_sp;
    RAISE NOTICE '  425081 con_pres (generico)              : %', v_ins_cp;
    RAISE NOTICE '  574481 sin_pres_com (comercializado)    : %', v_ins_spc;
    RAISE NOTICE '  574471 con_pres_com (comercializado)    : %', v_ins_cpc;
    RAISE NOTICE '  TOTAL                                   : %', v_ins_sp + v_ins_cp + v_ins_spc + v_ins_cpc;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Verificación
-- ─────────────────────────────────────────────────────────────────────────────
SELECT tipo_generico, con_presentacion, COUNT(*) AS total
FROM generic_drug
WHERE active = TRUE
GROUP BY tipo_generico, con_presentacion
ORDER BY tipo_generico, con_presentacion;

SELECT COUNT(*) AS total_generic_drug FROM generic_drug WHERE active = TRUE;

-- Sin match en snomed_concepts
SELECT '425091 sin match' AS fuente, COUNT(*) AS sin_match
FROM _stg_gd_sp WHERE active = '1'
  AND NOT EXISTS (SELECT 1 FROM snomed_concepts sc WHERE sc.id = snomed_concept_id)
UNION ALL
SELECT '425081 sin match', COUNT(*) FROM _stg_gd_cp WHERE active = '1'
  AND NOT EXISTS (SELECT 1 FROM snomed_concepts sc WHERE sc.id = snomed_concept_id)
UNION ALL
SELECT '574481 sin match', COUNT(*) FROM _stg_gd_spc WHERE active = '1'
  AND NOT EXISTS (SELECT 1 FROM snomed_concepts sc WHERE sc.id = snomed_concept_id)
UNION ALL
SELECT '574471 sin match', COUNT(*) FROM _stg_gd_cpc WHERE active = '1'
  AND NOT EXISTS (SELECT 1 FROM snomed_concepts sc WHERE sc.id = snomed_concept_id);

ANALYZE generic_drug;
DO $$ BEGIN RAISE NOTICE 'Carga generic_drug finalizada.'; END $$;
