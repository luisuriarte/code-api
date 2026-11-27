-- =============================================================================
-- 06_nomencladores / 02_nbu_snomed.sql
-- Carga del Nomenclador Bioquímico Único (NBU) y su mapeo oficial a SNOMED CT
--
-- Fuente (en VPS):
--   tools/sources/snomed_argentina/mapeo_nbu_sct.tsv
--   Columnas: sctid | codigo_nbu | determinacion
--
-- Destinos:
--   1. nomencladores_argentina (tipo_nomenclador = 'NBU') — códigos únicos
--   2. map_snomed_nbu — relación N:M completa sctid <-> codigo_nbu
--   3. laboratorio_practicas — agrega/actualiza codigo_nbu donde matchea SNOMED
-- =============================================================================

SET client_encoding = 'UTF8';
SET search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Verificar dependencias
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'nomencladores_argentina') THEN
        RAISE EXCEPTION 'Tabla nomencladores_argentina no existe.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM snomed_concepts LIMIT 1) THEN
        RAISE EXCEPTION 'snomed_concepts está vacía.';
    END IF;
    RAISE NOTICE 'Dependencias OK.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Tabla map_snomed_nbu (N:M completa entre SNOMED y código NBU)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS map_snomed_nbu (
    snomed_concept_id BIGINT NOT NULL REFERENCES snomed_concepts(id) ON DELETE CASCADE,
    codigo_nbu        VARCHAR(30) NOT NULL,
    determinacion     TEXT NOT NULL,
    activo            BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (snomed_concept_id, codigo_nbu)
);

CREATE INDEX IF NOT EXISTS idx_map_nbu_codigo ON map_snomed_nbu(codigo_nbu);

-- Columna opcional codigo_nbu en laboratorio_practicas para cruce directo
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'laboratorio_practicas')
       AND NOT EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_name = 'laboratorio_practicas' AND column_name = 'codigo_nbu'
       ) THEN
        ALTER TABLE laboratorio_practicas ADD COLUMN codigo_nbu VARCHAR(30);
        CREATE INDEX IF NOT EXISTS idx_lab_nbu ON laboratorio_practicas(codigo_nbu);
        RAISE NOTICE 'Columna codigo_nbu agregada a laboratorio_practicas.';
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Staging
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS _stg_nbu;
CREATE TEMP TABLE _stg_nbu (
    sctid         BIGINT,
    codigo_nbu    TEXT,
    determinacion TEXT
);

\copy _stg_nbu FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/mapeo_nbu_sct.tsv' WITH (FORMAT CSV, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8', QUOTE '"');

SELECT 'Filas staging NBU' AS descripcion, COUNT(*) AS total FROM _stg_nbu;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Cargar map_snomed_nbu (relación completa N:M)
-- ─────────────────────────────────────────────────────────────────────────────
WITH ins AS (
    INSERT INTO map_snomed_nbu (snomed_concept_id, codigo_nbu, determinacion, activo)
    SELECT DISTINCT ON (s.sctid, TRIM(s.codigo_nbu))
        sc.id,
        TRIM(s.codigo_nbu),
        TRIM(s.determinacion),
        TRUE
    FROM _stg_nbu s
    JOIN snomed_concepts sc ON sc.id = s.sctid
    WHERE TRIM(s.codigo_nbu) <> ''
    ORDER BY s.sctid, TRIM(s.codigo_nbu)
    ON CONFLICT (snomed_concept_id, codigo_nbu) DO UPDATE
        SET determinacion = EXCLUDED.determinacion,
            activo        = TRUE
    RETURNING 1
)
SELECT COUNT(*) AS map_snomed_nbu_upserted FROM ins;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Cargar nomencladores_argentina (tipo_nomenclador = 'NBU', 1 fila por codigo)
-- ─────────────────────────────────────────────────────────────────────────────
WITH dedup AS (
    SELECT DISTINCT ON (TRIM(s.codigo_nbu))
        TRIM(s.codigo_nbu)    AS codigo,
        TRIM(s.determinacion) AS descripcion,
        sc.id                 AS snomed_concept_id
    FROM _stg_nbu s
    LEFT JOIN snomed_concepts sc ON sc.id = s.sctid
    WHERE TRIM(s.codigo_nbu) <> ''
    ORDER BY TRIM(s.codigo_nbu), (sc.id IS NULL), s.sctid
),
ins AS (
    INSERT INTO nomencladores_argentina (
        tipo_nomenclador, codigo, capitulo, descripcion,
        snomed_concept_id, vigencia_desde, activo
    )
    SELECT
        'NBU',
        d.codigo,
        'Nomenclador Bioquímico Único',
        d.descripcion,
        d.snomed_concept_id,
        '2026-08-20',
        TRUE
    FROM dedup d
    ON CONFLICT (tipo_nomenclador, codigo) DO UPDATE
        SET descripcion       = EXCLUDED.descripcion,
            capitulo          = COALESCE(nomencladores_argentina.capitulo, EXCLUDED.capitulo),
            snomed_concept_id = COALESCE(EXCLUDED.snomed_concept_id, nomencladores_argentina.snomed_concept_id),
            vigencia_desde    = EXCLUDED.vigencia_desde,
            activo            = TRUE
    RETURNING 1
)
SELECT COUNT(*) AS nbu_nomencladores_upserted FROM ins;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Vincular laboratorio_practicas con codigo_nbu vía snomed_concept_id
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE v_upd INTEGER := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'laboratorio_practicas') THEN
        UPDATE laboratorio_practicas lp
        SET codigo_nbu = m.codigo_nbu
        FROM (
            SELECT DISTINCT ON (snomed_concept_id) snomed_concept_id, codigo_nbu
            FROM map_snomed_nbu
            WHERE activo = TRUE
            ORDER BY snomed_concept_id, codigo_nbu
        ) m
        WHERE lp.snomed_concept_id = m.snomed_concept_id
          AND (lp.codigo_nbu IS NULL OR lp.codigo_nbu = '');

        GET DIAGNOSTICS v_upd = ROW_COUNT;
        RAISE NOTICE 'laboratorio_practicas actualizadas con codigo_nbu: %', v_upd;
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Verificación
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'nomencladores_argentina (NBU)' AS tabla, COUNT(*) AS total
FROM nomencladores_argentina WHERE tipo_nomenclador = 'NBU' AND activo = TRUE
UNION ALL
SELECT 'map_snomed_nbu', COUNT(*) FROM map_snomed_nbu WHERE activo = TRUE
UNION ALL
SELECT 'laboratorio_practicas con NBU', COUNT(*) FROM laboratorio_practicas WHERE codigo_nbu IS NOT NULL;

ANALYZE nomencladores_argentina;
ANALYZE map_snomed_nbu;
DO $$ BEGIN RAISE NOTICE 'Carga NBU finalizada.'; END $$;
