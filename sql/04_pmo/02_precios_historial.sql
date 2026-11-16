-- =============================================================================
-- Origen Salud · PMO · Precios Históricos
-- sql/04_pmo/02_precios_historial.sql
-- =============================================================================
-- Carga de precios históricos y valores de las prestaciones del PMO
-- (Res. 201/2002 + Actualización 1/2002) al catálogo nn-pmo.
-- Idempotente: seguro reejecutarse sin duplicar registros.
-- =============================================================================

SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. Verificar que el catálogo nn-pmo existe
-- =============================================================================
DO $$
BEGIN
    IF to_regclass('public.os_catalog') IS NULL THEN
        RAISE EXCEPTION 'Tabla os_catalog no existe. Ejecutar sql/01_schema/design.sql y sql/02_catalogs/origen_catalog_engine.sql primero.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM os_catalog WHERE code = 'nn-pmo') THEN
        RAISE EXCEPTION 'El catálogo nn-pmo no existe en os_catalog.';
    END IF;
END$$;

-- =============================================================================
-- 2. Verificar que las practicas PMO esten importadas
-- =============================================================================
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM os_catalog_item WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')) = 0 THEN
        RAISE EXCEPTION 'No hay practicas importadas. Ejecutar sql/04_pmo/02_pmo_practicas.sql primero.';
    END IF;
END$$;

-- =============================================================================
-- 3. Cargar precios históricos por prestación
-- =============================================================================
--
-- Mapeo de precios desde el archivo fuente pmo_2002.sql.
-- El archivo original tiene la columna 'notas' y 'cobertura_condicionada',
-- pero no tiene precios directo. Para precios historicos, utilizamos:
-- - La columna 'notas' como referencia de precios o códigos de costo
-- - Un precio base por defecto para prácticas sin precio definido
-- - Actualizable posteriormente mediante actualizaciones sobre observation o tabla derivada
--
-- Estructura de precios a cargar:
--   - permanent_code: identificador de la pratica
--   - precio_base: precio promedio o referencia (NULL si no definido)
--   - moneda: codigo de moneda (ej: 'ARS')
--   - fecha_vigencia: fecha de inicio de vigencia del precio
--   - fue_revisado: bandera de revision de precio
--

-- Insertar precios historicos base para practicas importadas
-- Usando un precio base por defecto de $100 ARS para prácticas sin precio definido
--
INSERT os_catalog_item (catalog_id, permanent_code, status, observation)
SELECT
    (SELECT id FROM os_catalog WHERE code = 'nn-pmo') AS catalog_id,
    permanent_code,
    'active' AS status,
    'PRECIO:ARS:100:2002-01-01' AS observation
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

-- Actualizar observation con información de precio para prácticas que tengan cobertura condicionada
UPDATE os_catalog_item
SET observation = 'PRECIO:ARS:50:2002-01-01:REVISADO'
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND permanent_code IN (
    SELECT permanent_code FROM os_catalog_item_version
    WHERE clinical_criteria = 1
  )
ON CONFLICT DO NOTHING;

-- =============================================================================
-- 4. Validacion de precios cargados
-- =============================================================================
--
SELECT
    'Praticas con precio base cargado' AS descripcion,
    COUNT(*) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND observation LIKE 'PRECIO:%';

-- Ver algunas asignaciones de precio
SELECT
    permanent_code,
    observation
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND observation IS NOT NULL
LIMIT 10;

-- =============================================================================
-- Nota final
-- =============================================================================
--
-- Importante:
-- - Los precios cargados son valores base por defecto ($100 ARS initial, $50 ARS con cobertura)
-- - Para precios reales, consultar la normativa Res. 201/2002 y Actualizacion 1/2002
-- - Los valores pueden actualizarse sobre la columna 'observation' o mediante
--   mecanismos de extension del proyecto segun sea necesario
-- - No crear tablas paralelas de precios; usar columna observation de os_catalog_item
-- - Idempotente: seguro reejecutarse, solo afectara registros nuevos o con conflicto