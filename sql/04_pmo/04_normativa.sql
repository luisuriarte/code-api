-- =============================================================================
-- Origen Salud · PMO · Documentación Normativa
-- sql/04_pmo/04_normativa.sql
-- =============================================================================
-- Registro de referencias normativas y legales del Programa Médico Obligatorio
-- (Res. 201/2002 + Actualización 1/2002).
-- Documentación de la fuente original sin modificar.
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
-- 2. Cargar referencias normativas en observation
-- =============================================================================
--
-- Cargamos la referencia normativa completa en el campo observation de las
-- practicas importadas. Esto permite consulta posterior sin crear tablas paralelas.
--
UPDATE os_catalog_item
SET observation = observation || ';NORMATIVA:RES-201-2002;ACT-1-2002'
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND observation NOT LIKE '%NORMATIVA:%'
ON CONFLICT DO NOTHING;

-- =============================================================================
-- 3. Validación de referencias normativas cargadas
-- =============================================================================
--
SELECT
    'Practicas con referencia normativa' AS descripcion,
    COUNT(*) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND observation LIKE '%NORMATIVA:%';

-- Ver algunas asignaciones
SELECT
    permanent_code,
    observation
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND observation IS NOT NULL
LIMIT 5;

-- =============================================================================
-- 4. Consultas de referencia por normativa
-- =============================================================================
--
-- Consultar practicas asociadas a la resolución original
SELECT
    'Practicas - Resolución 201/2002' AS descripcion,
    COUNT(*) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND observation LIKE '%RES-201-2002%';

-- Consultar practicas asociadas a la actualización normativa
SELECT
    'Practicas - Actualización 1/2002' AS descripcion,
    COUNT(*) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND observation LIKE '%ACT-1-2002%';

-- =============================================================================
-- Nota final
-- =============================================================================
--
-- Referencias documentadas:
--   - Resolución 201/2002: Creación del Programa Médico Obligatorio
--   - Actualización Normativa 1/2002: Modificaciones y actualizaciones
--   - Identificador de versión: PMOE-201-2002
--   - Fuente original: tools/sources/pmo/pmo_2002.sql (SIN MODIFICAR)
--
-- Propiedades:
-- - No modificar el archivo fuente pmo_2002.sql
-- - Usar columna observation de os_catalog_item para metadatos
-- - Comportamiento idempotente (ON CONFLICT DO NOTHING)
-- - Consultas filtradas por tags en observation (NORMATIVA:RES-201-2002, etc.)
-- - Documentación consultable mediante API /v1/catalogs con vistas correspondientes