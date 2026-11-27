-- =============================================================================
-- Origen Salud · Mapeo SNOMED CT → CIE-10
-- sql/05_maps/01_map_snomed_cie10.sql
-- =============================================================================
-- Carga el ExtendedMap de la Edición Argentina SNOMED CT 2026 (agosto)
-- en la tabla map_snomed_cie10.
--
-- ANTES DE EJECUTAR:
--   1. Colocar el archivo RF2 en el proyecto:
--      LOCAL:  SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z/
--              Snapshot/Refset/Map/
--              der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt
--      DESTINO LOCAL:  tools/sources/snomed_argentina/
--                      der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt
--      VPS:    /var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/
--              der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt
--
--   2. Ejecutar:
--      sudo -u postgres psql -d origen_codes -f sql/05_maps/01_map_snomed_cie10.sql
--
-- Idempotente: seguro reejecutarse (ON CONFLICT DO UPDATE).
-- =============================================================================

SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. Verificar dependencias
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM snomed_concepts LIMIT 1) THEN
        RAISE EXCEPTION 'snomed_concepts está vacía. Cargar SNOMED CT primero.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM cie10_codes LIMIT 1) THEN
        RAISE EXCEPTION 'cie10_codes está vacía. Cargar CIE-10 primero.';
    END IF;
    RAISE NOTICE 'Dependencias OK: snomed_concepts y cie10_codes tienen datos.';
END$$;

-- =============================================================================
-- 2. Tabla de staging temporal (RF2 ExtendedMap — columnas estándar)
-- =============================================================================
DROP TABLE IF EXISTS _staging_ext_map;
CREATE TEMP TABLE _staging_ext_map (
    id                  TEXT,
    effective_time      TEXT,       -- YYYYMMDD
    active              SMALLINT,
    module_id           BIGINT,
    refset_id           BIGINT,
    referenced_id       BIGINT,     -- SCTID del concepto SNOMED
    map_group           SMALLINT,
    map_priority        SMALLINT,
    map_rule            TEXT,
    map_advice          TEXT,
    map_target          TEXT,       -- Código CIE-10 (ej: 'J18.9')
    correlation_id      BIGINT,
    map_category_id     BIGINT
);

-- =============================================================================
-- 3. Cargar el archivo RF2 (psql \copy usa el sistema de archivos del cliente)
-- =============================================================================
\copy _staging_ext_map FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt' WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, NULL '')

SELECT 'Filas cargadas en staging' AS descripcion, COUNT(*) AS total FROM _staging_ext_map;
SELECT 'Filas activas con mapTarget' AS descripcion, COUNT(*) AS total
FROM _staging_ext_map WHERE active = 1 AND map_target <> '';

-- =============================================================================
-- 4. Extender el schema de map_snomed_cie10
--    (tabla está vacía → seguro alterar el PK)
-- =============================================================================
ALTER TABLE map_snomed_cie10
    ADD COLUMN IF NOT EXISTS map_group      SMALLINT  NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS map_priority   SMALLINT  NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS map_rule       TEXT,
    ADD COLUMN IF NOT EXISTS map_advice     TEXT,
    ADD COLUMN IF NOT EXISTS map_category_id BIGINT,
    ADD COLUMN IF NOT EXISTS effective_date  DATE;

-- Reemplazar PK para incluir map_group (soporta mapeos complejos multi-grupo)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'map_snomed_cie10' AND column_name = 'map_group'
          AND column_default IS NOT NULL
    ) THEN
        -- Solo recrea el PK si aún no incluye map_group
        ALTER TABLE map_snomed_cie10 DROP CONSTRAINT IF EXISTS map_snomed_cie10_pkey;
        ALTER TABLE map_snomed_cie10
            ADD CONSTRAINT map_snomed_cie10_pkey
            PRIMARY KEY (snomed_concept_id, cie10_id, map_group);
    END IF;
END$$;

-- =============================================================================
-- 5. Insertar desde staging con JOIN a las tablas maestras
--    Solo:
--    - active = 1 (mapeos vigentes)
--    - map_target <> '' (tiene código CIE-10 destino)
--    - snomed_concept_id existe en snomed_concepts
--    - cie10 codigo existe en cie10_codes
-- =============================================================================
INSERT INTO map_snomed_cie10
    (snomed_concept_id, cie10_id, map_group, map_priority,
     map_rule, map_advice, map_category_id, effective_date)
SELECT
    em.referenced_id                            AS snomed_concept_id,
    c.id                                        AS cie10_id,
    em.map_group,
    em.map_priority,
    NULLIF(em.map_rule, '')                     AS map_rule,
    NULLIF(em.map_advice, '')                   AS map_advice,
    em.map_category_id,
    to_date(em.effective_time, 'YYYYMMDD')      AS effective_date
FROM _staging_ext_map em
JOIN snomed_concepts sc ON sc.id = em.referenced_id
JOIN cie10_codes c      ON c.codigo = em.map_target
WHERE em.active = 1
  AND em.map_target <> ''
ON CONFLICT (snomed_concept_id, cie10_id, map_group) DO UPDATE SET
    map_priority    = EXCLUDED.map_priority,
    map_rule        = EXCLUDED.map_rule,
    map_advice      = EXCLUDED.map_advice,
    map_category_id = EXCLUDED.map_category_id,
    effective_date  = EXCLUDED.effective_date;

-- =============================================================================
-- 6. Índice adicional para búsqueda por código CIE-10
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_map_cie10_code
    ON map_snomed_cie10 (cie10_id, map_group, map_priority);

-- =============================================================================
-- 7. Validaciones finales
-- =============================================================================
SELECT 'Mapeos SNOMED→CIE-10 insertados' AS descripcion,
       COUNT(*) AS total
FROM map_snomed_cie10;

SELECT 'Conceptos SNOMED únicos mapeados' AS descripcion,
       COUNT(DISTINCT snomed_concept_id) AS total
FROM map_snomed_cie10;

SELECT 'Códigos CIE-10 únicos en el mapa' AS descripcion,
       COUNT(DISTINCT cie10_id) AS total
FROM map_snomed_cie10;

SELECT 'Mapeos sin CIE-10 en nuestra BD (descartados)' AS descripcion,
       COUNT(*) AS total
FROM _staging_ext_map em
WHERE em.active = 1
  AND em.map_target <> ''
  AND NOT EXISTS (SELECT 1 FROM cie10_codes c WHERE c.codigo = em.map_target);

-- Top 5 capítulos CIE-10 más mapeados
SELECT LEFT(c.codigo, 1) AS capitulo_cie10,
       COUNT(*) AS mapeos
FROM map_snomed_cie10 m
JOIN cie10_codes c ON c.id = m.cie10_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;

DROP TABLE IF EXISTS _staging_ext_map;

ANALYZE map_snomed_cie10;
RAISE NOTICE 'Carga map_snomed_cie10 finalizada.';
