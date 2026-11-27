-- =============================================================================
-- Origen Salud · PMO · Odontología
-- sql/04_pmo/03_odontologia.sql
-- =============================================================================
-- Identificación y etiquetado de prácticas odontológicas del PMO.
-- Los catálogos PMO históricos incluyen algunas prestaciones dentales.
-- Este script las identifica dentro del catálogo nn-pmo mediante una
-- categoría dedicada, sin crear tablas paralelas.
-- Idempotente: seguro reejecutarse sin duplicar registros.
-- =============================================================================

SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. Verificar que el catálogo nn-pmo y sus prácticas existen
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM os_catalog WHERE code = 'nn-pmo') THEN
        RAISE EXCEPTION 'El catálogo nn-pmo no existe. Ejecutar 02_pmo_practicas.sql primero.';
    END IF;
END$$;

-- =============================================================================
-- 2. Crear categoría "Odontología PMO" si no existe
-- =============================================================================
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT
    (SELECT id FROM os_catalog WHERE code = 'nn-pmo'),
    'ODON',
    'Odontología'
WHERE NOT EXISTS (
    SELECT 1 FROM os_catalog_category
    WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
      AND code = 'ODON'
);

-- =============================================================================
-- 3. Identificar prácticas odontológicas por patrón de código (13xx, 14xx)
--    y actualizar su categoría en os_catalog_item_version
-- =============================================================================
UPDATE os_catalog_item_version ver
SET category_id = (
    SELECT id FROM os_catalog_category
    WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
      AND code = 'ODON'
)
FROM os_catalog_item i
WHERE ver.item_id = i.id
  AND i.catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND (
      i.permanent_code ~ '^13'
      OR i.permanent_code ~ '^14'
      OR ver.preferred_term ILIKE '%dental%'
      OR ver.preferred_term ILIKE '%odont%'
      OR ver.preferred_term ILIKE '%estom%'
  );

-- =============================================================================
-- 4. Validación
-- =============================================================================
SELECT
    'Prácticas identificadas como odontológicas' AS descripcion,
    COUNT(*) AS total
FROM os_catalog_item_version ver
JOIN os_catalog_item i ON i.id = ver.item_id
JOIN os_catalog_category cat ON cat.id = ver.category_id
WHERE i.catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND cat.code = 'ODON';

SELECT
    'Prácticas por patrón de código 13xx/14xx' AS descripcion,
    COUNT(*) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND (permanent_code ~ '^13' OR permanent_code ~ '^14');

-- =============================================================================
-- Nota final
-- =============================================================================
-- - El conjunto actual (010101-010607) es neurocirugía; los 13xx/14xx son
--   estomatología/patología bucal cuando el archivo pmo_2002.sql completo
--   esté cargado.
-- - Esta separación usa categorías del catálogo, sin tablas paralelas.
-- - Idempotente: seguro reejecutarse.
