-- =============================================================================
-- 06_programas / 01_sumar.sql
-- Carga del Programa SUMAR desde SNOMED CT Argentina 2026
--
-- Fuentes (en VPS):
--   /var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/
--     sumar_dx.txt       → refset 371191000221103 (diagnósticos)
--     sumar_proc.txt     → refset 371201000221100 (procedimientos)
--     sumar_prof.txt     → refset 371211000221102 (profesionales)
--     sumar_ambitos.txt  → refset 371221000221107 (ámbitos de atención)
--
-- Tablas destino:
--   programas_sociales        → 1 fila por programa (ya existe en schema)
--   programas_sociales_items  → nueva tabla con conceptos SNOMED por refset
-- =============================================================================

SET client_encoding = 'UTF8';
SET search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Verificar dependencias
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'programas_sociales') THEN
        RAISE EXCEPTION 'Tabla programas_sociales no existe. Ejecutar primero sql/01_schema/design.sql';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM snomed_concepts LIMIT 1) THEN
        RAISE EXCEPTION 'snomed_concepts está vacía. Ejecutar primero sql/02_snomed/*.sql';
    END IF;
    RAISE NOTICE 'Dependencias OK.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Crear tabla programas_sociales_items (si no existe)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS programas_sociales_items (
    id                 SERIAL PRIMARY KEY,
    programa_id        INTEGER NOT NULL REFERENCES programas_sociales(id) ON DELETE CASCADE,
    snomed_concept_id  BIGINT  NOT NULL REFERENCES snomed_concepts(id) ON DELETE CASCADE,
    tipo_item          VARCHAR(20) NOT NULL
                           CHECK (tipo_item IN ('diagnostico','procedimiento','profesional','ambito')),
    termino            TEXT    NOT NULL,          -- término preferido en es-AR del refset
    refset_id          BIGINT  NOT NULL,          -- ID del refset de origen (traza)
    effective_date     DATE,
    active             BOOLEAN DEFAULT TRUE,
    UNIQUE (programa_id, snomed_concept_id, tipo_item)
);

CREATE INDEX IF NOT EXISTS idx_psi_programa      ON programas_sociales_items(programa_id);
CREATE INDEX IF NOT EXISTS idx_psi_snomed        ON programas_sociales_items(snomed_concept_id);
CREATE INDEX IF NOT EXISTS idx_psi_tipo          ON programas_sociales_items(tipo_item);
CREATE INDEX IF NOT EXISTS idx_psi_termino_trgm  ON programas_sociales_items
    USING gin (f_unaccent(termino) gin_trgm_ops);

DO $$ BEGIN RAISE NOTICE 'Tabla programas_sociales_items lista.'; END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Insertar programa SUMAR en programas_sociales (upsert)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO programas_sociales (codigo, nombre_programa, descripcion, activo)
VALUES (
    'SUMAR',
    'Programa SUMAR',
    'Sistema Único de Reintegros — Programa federal de cobertura de salud para '
    'población sin obra social (niños, adolescentes, mujeres embarazadas y jóvenes). '
    'Fuente: SNOMED CT Argentina Edición 2026-08-20.',
    TRUE
)
ON CONFLICT (codigo) DO UPDATE
    SET nombre_programa = EXCLUDED.nombre_programa,
        descripcion     = EXCLUDED.descripcion,
        activo          = TRUE;

DO $$ BEGIN RAISE NOTICE 'Programa SUMAR upserted.'; END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Tablas de staging (TEMP)
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS _stg_sumar_dx;
DROP TABLE IF EXISTS _stg_sumar_proc;
DROP TABLE IF EXISTS _stg_sumar_prof;
DROP TABLE IF EXISTS _stg_sumar_amb;

CREATE TEMP TABLE _stg_sumar_dx (
    id_row              UUID,
    effective_time      TEXT,
    active              TEXT,
    module_id           BIGINT,
    refset_id           BIGINT,
    refset_term         TEXT,
    snomed_concept_id   BIGINT,
    termino             TEXT
);

CREATE TEMP TABLE _stg_sumar_proc  (LIKE _stg_sumar_dx);
CREATE TEMP TABLE _stg_sumar_prof  (LIKE _stg_sumar_dx);
CREATE TEMP TABLE _stg_sumar_amb   (LIKE _stg_sumar_dx);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Cargar archivos fuente
--    Ajustar path si es necesario; columnas: id  effectiveTime  active
--    moduleId  refsetId  refsetId_term  referencedComponentId  referencedComponentId_term
-- ─────────────────────────────────────────────────────────────────────────────
\copy _stg_sumar_dx   FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/sumar_dx.txt'   WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');
\copy _stg_sumar_proc FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/sumar_proc.txt' WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');
\copy _stg_sumar_prof FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/sumar_prof.txt' WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');
\copy _stg_sumar_amb  FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/sumar_ambitos.txt' WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');

SELECT 'Filas staging dx'    AS fuente, COUNT(*) FROM _stg_sumar_dx
UNION ALL
SELECT 'Filas staging proc'  AS fuente, COUNT(*) FROM _stg_sumar_proc
UNION ALL
SELECT 'Filas staging prof'  AS fuente, COUNT(*) FROM _stg_sumar_prof
UNION ALL
SELECT 'Filas staging amb'   AS fuente, COUNT(*) FROM _stg_sumar_amb;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Insertar items en programas_sociales_items
--    Solo filas activas (active = '1') cuyo snomed_concept_id existe en snomed_concepts
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_programa_id INTEGER;
    v_ins_dx      INTEGER;
    v_ins_proc    INTEGER;
    v_ins_prof    INTEGER;
    v_ins_amb     INTEGER;
BEGIN
    SELECT id INTO v_programa_id FROM programas_sociales WHERE codigo = 'SUMAR';

    -- 5a. Diagnósticos
    WITH ins AS (
        INSERT INTO programas_sociales_items
            (programa_id, snomed_concept_id, tipo_item, termino, refset_id, effective_date, active)
        SELECT
            v_programa_id,
            s.snomed_concept_id,
            'diagnostico',
            s.termino,
            s.refset_id,
            TO_DATE(s.effective_time, 'YYYYMMDD'),
            TRUE
        FROM _stg_sumar_dx s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (programa_id, snomed_concept_id, tipo_item) DO UPDATE
            SET termino        = EXCLUDED.termino,
                effective_date = EXCLUDED.effective_date,
                active         = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_dx FROM ins;

    -- 5b. Procedimientos
    WITH ins AS (
        INSERT INTO programas_sociales_items
            (programa_id, snomed_concept_id, tipo_item, termino, refset_id, effective_date, active)
        SELECT
            v_programa_id,
            s.snomed_concept_id,
            'procedimiento',
            s.termino,
            s.refset_id,
            TO_DATE(s.effective_time, 'YYYYMMDD'),
            TRUE
        FROM _stg_sumar_proc s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (programa_id, snomed_concept_id, tipo_item) DO UPDATE
            SET termino        = EXCLUDED.termino,
                effective_date = EXCLUDED.effective_date,
                active         = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_proc FROM ins;

    -- 5c. Profesionales
    WITH ins AS (
        INSERT INTO programas_sociales_items
            (programa_id, snomed_concept_id, tipo_item, termino, refset_id, effective_date, active)
        SELECT
            v_programa_id,
            s.snomed_concept_id,
            'profesional',
            s.termino,
            s.refset_id,
            TO_DATE(s.effective_time, 'YYYYMMDD'),
            TRUE
        FROM _stg_sumar_prof s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (programa_id, snomed_concept_id, tipo_item) DO UPDATE
            SET termino        = EXCLUDED.termino,
                effective_date = EXCLUDED.effective_date,
                active         = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_prof FROM ins;

    -- 5d. Ámbitos de atención
    WITH ins AS (
        INSERT INTO programas_sociales_items
            (programa_id, snomed_concept_id, tipo_item, termino, refset_id, effective_date, active)
        SELECT
            v_programa_id,
            s.snomed_concept_id,
            'ambito',
            s.termino,
            s.refset_id,
            TO_DATE(s.effective_time, 'YYYYMMDD'),
            TRUE
        FROM _stg_sumar_amb s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (programa_id, snomed_concept_id, tipo_item) DO UPDATE
            SET termino        = EXCLUDED.termino,
                effective_date = EXCLUDED.effective_date,
                active         = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_amb FROM ins;

    RAISE NOTICE 'Items insertados/actualizados:';
    RAISE NOTICE '  Diagnósticos  : %', v_ins_dx;
    RAISE NOTICE '  Procedimientos: %', v_ins_proc;
    RAISE NOTICE '  Profesionales : %', v_ins_prof;
    RAISE NOTICE '  Ámbitos       : %', v_ins_amb;
    RAISE NOTICE '  TOTAL         : %', v_ins_dx + v_ins_proc + v_ins_prof + v_ins_amb;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Verificación final
-- ─────────────────────────────────────────────────────────────────────────────
SELECT tipo_item, COUNT(*) AS total
FROM programas_sociales_items
WHERE programa_id = (SELECT id FROM programas_sociales WHERE codigo = 'SUMAR')
GROUP BY tipo_item
ORDER BY tipo_item;

SELECT
    (SELECT COUNT(*) FROM _stg_sumar_dx   WHERE active = '1') AS dx_fuente,
    (SELECT COUNT(*) FROM _stg_sumar_proc WHERE active = '1') AS proc_fuente,
    (SELECT COUNT(*) FROM _stg_sumar_prof WHERE active = '1') AS prof_fuente,
    (SELECT COUNT(*) FROM _stg_sumar_amb  WHERE active = '1') AS amb_fuente,
    (SELECT COUNT(*) FROM programas_sociales_items
     WHERE programa_id = (SELECT id FROM programas_sociales WHERE codigo = 'SUMAR')
       AND active = TRUE)                                      AS total_bd;

-- Conceptos SNOMED del fuente que NO están en nuestra BD
SELECT 'Dx sin match en snomed_concepts' AS descripcion,
       COUNT(*) AS sin_match
FROM _stg_sumar_dx s
WHERE s.active = '1'
  AND NOT EXISTS (SELECT 1 FROM snomed_concepts sc WHERE sc.id = s.snomed_concept_id)
UNION ALL
SELECT 'Proc sin match en snomed_concepts',
       COUNT(*)
FROM _stg_sumar_proc s
WHERE s.active = '1'
  AND NOT EXISTS (SELECT 1 FROM snomed_concepts sc WHERE sc.id = s.snomed_concept_id);

ANALYZE programas_sociales_items;

DO $$ BEGIN RAISE NOTICE 'Carga SUMAR finalizada.'; END $$;
