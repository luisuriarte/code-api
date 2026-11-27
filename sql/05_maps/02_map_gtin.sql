-- =============================================================================
-- 05_maps / 02_map_gtin.sql
-- Carga del mapa GTIN → RPCD (Referencia de Producto Comercial Definido) SNOMED
--
-- Fuente (en VPS):
--   tools/sources/snomed_argentina/map_gtin_rpcd.tsv
--   Columnas: gtin | condicion | rpcd_id | rpcd_fsn
--   15.500 filas — EAN-13/GTIN → concepto SNOMED de presentación comercial
--
-- Tabla destino: map_gtin (creada en este script si no existe)
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
-- 1. Crear tabla map_gtin (si no existe)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS map_gtin (
    id                 SERIAL PRIMARY KEY,
    gtin               VARCHAR(20) UNIQUE NOT NULL,  -- EAN-13 / GTIN-14
    condicion          VARCHAR(30),                   -- 'COMERCIALIZADO', 'BAJA', etc.
    snomed_concept_id  BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    rpcd_fsn           TEXT,                          -- Fully Specified Name del RPCD
    -- Vínculo opcional con vademecum_comercial
    vademecum_id       INTEGER REFERENCES vademecum_comercial(id) ON DELETE SET NULL,
    activo             BOOLEAN DEFAULT TRUE,
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_gtin_snomed    ON map_gtin(snomed_concept_id);
CREATE INDEX IF NOT EXISTS idx_gtin_condicion ON map_gtin(condicion);
CREATE INDEX IF NOT EXISTS idx_gtin_vad       ON map_gtin(vademecum_id);

DO $$ BEGIN RAISE NOTICE 'Tabla map_gtin lista.'; END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Tabla de staging
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS _stg_gtin;

CREATE TEMP TABLE _stg_gtin (
    gtin       TEXT,
    condicion  TEXT,
    rpcd_id    BIGINT,
    rpcd_fsn   TEXT
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Cargar fuente TSV
-- ─────────────────────────────────────────────────────────────────────────────
\copy _stg_gtin FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/map_gtin_rpcd.tsv' WITH (FORMAT CSV, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8', QUOTE '"');

SELECT 'Filas staging GTIN' AS descripcion, COUNT(*) AS total FROM _stg_gtin;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Insertar en map_gtin
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_ins     INTEGER;
    v_nomatch INTEGER;
BEGIN
    WITH ins AS (
        INSERT INTO map_gtin (gtin, condicion, snomed_concept_id, rpcd_fsn, activo)
        SELECT
            g.gtin,
            g.condicion,
            sc.id,   -- NULL si rpcd_id no existe en snomed_concepts (evita error FK)
            g.rpcd_fsn,
            (g.condicion = 'COMERCIALIZADO')
        FROM _stg_gtin g
        LEFT JOIN snomed_concepts sc ON sc.id = g.rpcd_id
        WHERE g.gtin IS NOT NULL AND g.gtin <> ''
        ON CONFLICT (gtin) DO UPDATE
            SET condicion         = EXCLUDED.condicion,
                snomed_concept_id = EXCLUDED.snomed_concept_id,
                rpcd_fsn          = EXCLUDED.rpcd_fsn,
                activo            = EXCLUDED.activo
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins FROM ins;

    -- GTINs cuyo rpcd_id no está en snomed_concepts
    SELECT COUNT(*) INTO v_nomatch
    FROM _stg_gtin g
    WHERE NOT EXISTS (SELECT 1 FROM snomed_concepts sc WHERE sc.id = g.rpcd_id);

    RAISE NOTICE 'map_gtin insertados/actualizados: %', v_ins;
    RAISE NOTICE 'GTINs sin match en snomed_concepts: %', v_nomatch;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Vincular map_gtin con vademecum_comercial (si ya fue cargado)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE v_vinculados INTEGER;
BEGIN
    UPDATE map_gtin mg
    SET vademecum_id = vc.id
    FROM vademecum_comercial vc
    WHERE vc.snomed_concept_id = mg.snomed_concept_id
      AND mg.vademecum_id IS NULL;

    GET DIAGNOSTICS v_vinculados = ROW_COUNT;
    RAISE NOTICE 'GTINs vinculados a vademecum_comercial: %', v_vinculados;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Verificación
-- ─────────────────────────────────────────────────────────────────────────────
SELECT condicion, COUNT(*) AS total
FROM map_gtin
GROUP BY condicion
ORDER BY total DESC;

SELECT
    COUNT(*)                                              AS total_gtin,
    COUNT(*) FILTER (WHERE snomed_concept_id IS NOT NULL) AS con_snomed,
    COUNT(*) FILTER (WHERE vademecum_id IS NOT NULL)      AS con_vademecum,
    COUNT(*) FILTER (WHERE activo = TRUE)                 AS comercializados
FROM map_gtin;

ANALYZE map_gtin;
DO $$ BEGIN RAISE NOTICE 'Carga map_gtin finalizada.'; END $$;
