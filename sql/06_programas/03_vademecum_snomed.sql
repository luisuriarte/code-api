-- =============================================================================
-- 06_programas / 03_vademecum_snomed.sql
-- Carga de presentaciones farmacéuticas comerciales SNOMED CT Argentina 2026
-- → tabla vademecum_comercial (columna snomed_concept_id)
-- → programa Remediar → programas_sociales_items
--
-- Fuentes (en VPS): tools/sources/snomed_argentina/
--   snomed_comerciales_pres.txt     → refset 574451 (21.925 filas, pres. farmac. comerc.)
--   snomed_comerciales_en_com.txt   → refset 574461 (12.313 filas, fármacos en comerc.)
--   snomed_comerciales_clinicos.txt → refset 425071 (15.155 filas, fármacos clínicos)
--   snomed_remediar.txt             → refset 349091 (429 filas, Programa Remediar)
--
-- Nota: vademecum_comercial ya existe. Este script usa UPSERT por snomed_concept_id.
--   Los campos troquel/alfabeta/kairos se cargan con NULL (vienen de otra fuente: ANMAT).
--   El campo monodroga y presentacion se derivan del termino SNOMED.
-- =============================================================================

SET client_encoding = 'UTF8';
SET search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Verificar dependencias
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vademecum_comercial') THEN
        RAISE EXCEPTION 'Tabla vademecum_comercial no existe.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'programas_sociales') THEN
        RAISE EXCEPTION 'Tabla programas_sociales no existe.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM snomed_concepts LIMIT 1) THEN
        RAISE EXCEPTION 'snomed_concepts está vacía.';
    END IF;
    RAISE NOTICE 'Dependencias OK.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Agregar columna snomed_concept_id a vademecum_comercial (si no existe)
--    y columna fuente_snomed para saber qué filas vienen de este script
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'vademecum_comercial' AND column_name = 'snomed_concept_id'
    ) THEN
        ALTER TABLE vademecum_comercial ADD COLUMN snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL;
        RAISE NOTICE 'Columna snomed_concept_id agregada a vademecum_comercial.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'vademecum_comercial' AND column_name = 'refset_id'
    ) THEN
        ALTER TABLE vademecum_comercial ADD COLUMN refset_id BIGINT;
        RAISE NOTICE 'Columna refset_id agregada a vademecum_comercial.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'vademecum_comercial' AND column_name = 'effective_date'
    ) THEN
        ALTER TABLE vademecum_comercial ADD COLUMN effective_date DATE;
        RAISE NOTICE 'Columna effective_date agregada a vademecum_comercial.';
    END IF;
END $$;

-- Índice único por snomed_concept_id para los registros que vienen de SNOMED
CREATE UNIQUE INDEX IF NOT EXISTS idx_vad_snomed_concept
    ON vademecum_comercial(snomed_concept_id)
    WHERE snomed_concept_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vad_snomed ON vademecum_comercial(snomed_concept_id);

DO $$ BEGIN RAISE NOTICE 'Schema vademecum_comercial actualizado.'; END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Tablas de staging
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS _stg_vc_pres;
DROP TABLE IF EXISTS _stg_vc_encom;
DROP TABLE IF EXISTS _stg_vc_clin;
DROP TABLE IF EXISTS _stg_remediar;

CREATE TEMP TABLE _stg_vc_pres (
    id_row             UUID,
    effective_time     TEXT,
    active             TEXT,
    module_id          BIGINT,
    refset_id          BIGINT,
    refset_term        TEXT,
    snomed_concept_id  BIGINT,
    termino            TEXT
);
CREATE TEMP TABLE _stg_vc_encom  (LIKE _stg_vc_pres);
CREATE TEMP TABLE _stg_vc_clin   (LIKE _stg_vc_pres);
CREATE TEMP TABLE _stg_remediar  (LIKE _stg_vc_pres);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Cargar fuentes
-- ─────────────────────────────────────────────────────────────────────────────
\copy _stg_vc_pres  FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_comerciales_pres.txt'     WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');
\copy _stg_vc_encom FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_comerciales_en_com.txt'   WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');
\copy _stg_vc_clin  FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_comerciales_clinicos.txt' WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');
\copy _stg_remediar FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_remediar.txt'             WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');

SELECT fuente, COUNT(*) FROM (
    SELECT '574451 pres_comerc'    AS fuente FROM _stg_vc_pres
    UNION ALL SELECT '574461 en_comerc'      FROM _stg_vc_encom
    UNION ALL SELECT '425071 clin_comerc'    FROM _stg_vc_clin
    UNION ALL SELECT '349091 remediar'       FROM _stg_remediar
) t GROUP BY fuente ORDER BY fuente;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Insertar en vademecum_comercial desde SNOMED
--    Los campos monodroga y nombre_comercial se extraen del termino SNOMED:
--      nombre_comercial = parte antes del primer '[' (si existe), o el termino completo
--      monodroga        = parte entre '[' y ']' (si existe), o el termino
--      presentacion     = parte después del ']' (si existe)
--    Prioridad: 574461 (en comercialización) > 574451 (pres.) > 425071 (clínico)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_ins_pres  INTEGER;
    v_ins_encom INTEGER;
    v_ins_clin  INTEGER;
BEGIN
    -- 4a. 425071 — fármacos clínicos comerciales (base, menor prioridad)
    WITH ins AS (
        INSERT INTO vademecum_comercial (
            snomed_concept_id, refset_id, effective_date, activo,
            nombre_comercial, monodroga, presentacion
        )
        SELECT
            s.snomed_concept_id,
            s.refset_id,
            TO_DATE(s.effective_time, 'YYYYMMDD'),
            TRUE,
            -- nombre_comercial: antes del '['
            LEFT(TRIM(CASE WHEN s.termino LIKE '%[%'
                 THEN LEFT(s.termino, POSITION('[' IN s.termino) - 1)
                 ELSE s.termino END), 255),
            -- monodroga: entre '[' y ']'
            LEFT(TRIM(CASE WHEN s.termino LIKE '%[%]%'
                 THEN SUBSTRING(s.termino FROM POSITION('[' IN s.termino) + 1
                                FOR POSITION(']' IN s.termino) - POSITION('[' IN s.termino) - 1)
                 ELSE s.termino END), 255),
            -- presentacion: después del ']'
            LEFT(TRIM(CASE WHEN s.termino LIKE '%]%'
                 THEN SUBSTRING(s.termino FROM POSITION(']' IN s.termino) + 1)
                 ELSE '' END), 255)
        FROM _stg_vc_clin s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (snomed_concept_id) WHERE snomed_concept_id IS NOT NULL DO UPDATE
            SET nombre_comercial = EXCLUDED.nombre_comercial,
                monodroga        = EXCLUDED.monodroga,
                presentacion     = EXCLUDED.presentacion,
                refset_id        = EXCLUDED.refset_id,
                effective_date   = EXCLUDED.effective_date,
                activo           = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_clin FROM ins;

    -- 4b. 574451 — presentaciones farmacéuticas comerciales (media prioridad)
    WITH ins AS (
        INSERT INTO vademecum_comercial (
            snomed_concept_id, refset_id, effective_date, activo,
            nombre_comercial, monodroga, presentacion
        )
        SELECT
            s.snomed_concept_id,
            s.refset_id,
            TO_DATE(s.effective_time, 'YYYYMMDD'),
            TRUE,
            LEFT(TRIM(CASE WHEN s.termino LIKE '%[%'
                 THEN LEFT(s.termino, POSITION('[' IN s.termino) - 1)
                 ELSE s.termino END), 255),
            LEFT(TRIM(CASE WHEN s.termino LIKE '%[%]%'
                 THEN SUBSTRING(s.termino FROM POSITION('[' IN s.termino) + 1
                                FOR POSITION(']' IN s.termino) - POSITION('[' IN s.termino) - 1)
                 ELSE s.termino END), 255),
            LEFT(TRIM(CASE WHEN s.termino LIKE '%]%'
                 THEN SUBSTRING(s.termino FROM POSITION(']' IN s.termino) + 1)
                 ELSE '' END), 255)
        FROM _stg_vc_pres s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (snomed_concept_id) WHERE snomed_concept_id IS NOT NULL DO UPDATE
            SET nombre_comercial = EXCLUDED.nombre_comercial,
                monodroga        = EXCLUDED.monodroga,
                presentacion     = EXCLUDED.presentacion,
                refset_id        = EXCLUDED.refset_id,
                effective_date   = EXCLUDED.effective_date,
                activo           = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_pres FROM ins;

    -- 4c. 574461 — en estado comercializado (mayor prioridad, sobreescribe)
    WITH ins AS (
        INSERT INTO vademecum_comercial (
            snomed_concept_id, refset_id, effective_date, activo,
            nombre_comercial, monodroga, presentacion
        )
        SELECT
            s.snomed_concept_id,
            s.refset_id,
            TO_DATE(s.effective_time, 'YYYYMMDD'),
            TRUE,
            LEFT(TRIM(CASE WHEN s.termino LIKE '%[%'
                 THEN LEFT(s.termino, POSITION('[' IN s.termino) - 1)
                 ELSE s.termino END), 255),
            LEFT(TRIM(CASE WHEN s.termino LIKE '%[%]%'
                 THEN SUBSTRING(s.termino FROM POSITION('[' IN s.termino) + 1
                                FOR POSITION(']' IN s.termino) - POSITION('[' IN s.termino) - 1)
                 ELSE s.termino END), 255),
            LEFT(TRIM(CASE WHEN s.termino LIKE '%]%'
                 THEN SUBSTRING(s.termino FROM POSITION(']' IN s.termino) + 1)
                 ELSE '' END), 255)
        FROM _stg_vc_encom s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (snomed_concept_id) WHERE snomed_concept_id IS NOT NULL DO UPDATE
            SET nombre_comercial = EXCLUDED.nombre_comercial,
                monodroga        = EXCLUDED.monodroga,
                presentacion     = EXCLUDED.presentacion,
                refset_id        = EXCLUDED.refset_id,
                effective_date   = EXCLUDED.effective_date,
                activo           = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_encom FROM ins;

    RAISE NOTICE 'Vademecum insertados/actualizados:';
    RAISE NOTICE '  425071 clin_comerc : %', v_ins_clin;
    RAISE NOTICE '  574451 pres_comerc : %', v_ins_pres;
    RAISE NOTICE '  574461 en_comerc   : %', v_ins_encom;
    RAISE NOTICE '  TOTAL              : %', v_ins_clin + v_ins_pres + v_ins_encom;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Programa Remediar → programas_sociales_items
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO programas_sociales (codigo, nombre_programa, descripcion, activo)
VALUES (
    'REMEDIAR',
    'Programa Remediar',
    'Programa federal de medicamentos esenciales gratuitos en CAPS. '
    'Ministerio de Salud de la Nación Argentina. '
    'Fuente: SNOMED CT Argentina Edición 2026-08-20.',
    TRUE
)
ON CONFLICT (codigo) DO UPDATE
    SET nombre_programa = EXCLUDED.nombre_programa,
        descripcion     = EXCLUDED.descripcion,
        activo          = TRUE;

DO $$
DECLARE
    v_programa_id INTEGER;
    v_ins_rem     INTEGER;
BEGIN
    SELECT id INTO v_programa_id FROM programas_sociales WHERE codigo = 'REMEDIAR';

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
        FROM _stg_remediar s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
        ON CONFLICT (programa_id, snomed_concept_id, tipo_item) DO UPDATE
            SET termino        = EXCLUDED.termino,
                effective_date = EXCLUDED.effective_date,
                active         = TRUE
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_rem FROM ins;

    RAISE NOTICE 'Remediar items insertados: %', v_ins_rem;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Verificación final
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'vademecum_comercial total'   AS descripcion, COUNT(*) AS total FROM vademecum_comercial WHERE activo = TRUE
UNION ALL
SELECT 'vademecum con snomed_id',    COUNT(*) FROM vademecum_comercial WHERE snomed_concept_id IS NOT NULL AND activo = TRUE
UNION ALL
SELECT 'Remediar items',             COUNT(*) FROM programas_sociales_items
    WHERE programa_id = (SELECT id FROM programas_sociales WHERE codigo = 'REMEDIAR');

ANALYZE vademecum_comercial;
ANALYZE programas_sociales_items;
DO $$ BEGIN RAISE NOTICE 'Carga vademecum y Remediar finalizada.'; END $$;
