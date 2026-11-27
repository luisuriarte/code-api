-- =============================================================================
-- Origen Salud · PMO · Documentación Normativa
-- sql/04_pmo/04_normativa.sql
-- =============================================================================
-- Registro de referencias normativas del Programa Médico Obligatorio
-- (Res. 201/2002 + Actualización 1/2002) en la tabla os_catalog_release,
-- asociando la fuente normativa al release publicado de nn-pmo.
-- Idempotente: seguro reejecutarse sin duplicar registros.
-- =============================================================================

SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. Verificar que el catálogo nn-pmo existe
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM os_catalog WHERE code = 'nn-pmo') THEN
        RAISE EXCEPTION 'El catálogo nn-pmo no existe. Ejecutar 02_pmo_practicas.sql primero.';
    END IF;
END$$;

-- =============================================================================
-- 2. Actualizar la referencia normativa en os_catalog_release
-- =============================================================================
-- Forzar actualización de la referencia normativa histórica real
UPDATE os_catalog_release
SET official_norm_reference = 'Res. 201/2002 + Actualización Normativa 1/2002 (MSAS Argentina)'
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo');

-- =============================================================================
-- 3. Registrar descripción normativa en os_catalog (website_url como referencia)
-- =============================================================================
UPDATE os_catalog
SET description = CASE
    WHEN description IS NULL OR description = ''
    THEN 'Programa Médico Obligatorio – Resolución 201/2002 y Actualización Normativa 1/2002. Ministerio de Salud y Acción Social de la Argentina.'
    ELSE description
    END
WHERE code = 'nn-pmo';

-- =============================================================================
-- 4. Validación
-- =============================================================================
SELECT
    'Release normativo registrado' AS descripcion,
    r.version_tag,
    r.valid_from,
    r.official_norm_reference,
    r.status
FROM os_catalog_release r
JOIN os_catalog c ON c.id = r.catalog_id
WHERE c.code = 'nn-pmo';

SELECT
    'Prácticas con referencia normativa' AS descripcion,
    COUNT(*) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo');

SELECT
    'Prácticas - Resolución 201/2002' AS descripcion,
    COUNT(*) AS total
FROM os_catalog_item i
JOIN os_catalog_release r ON r.catalog_id = i.catalog_id
WHERE i.catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND r.official_norm_reference LIKE '%201/2002%';

-- =============================================================================
-- Nota final
-- =============================================================================
-- Referencias documentadas:
--   - Resolución 201/2002: Creación del Programa Médico Obligatorio
--   - Actualización Normativa 1/2002: Modificaciones y actualizaciones
--   - Identificador de versión: PMOE-201-2002
--   - Fuente original: tools/sources/pmo/pmo_2002.sql (SIN MODIFICAR)
--
-- La referencia normativa vive en os_catalog_release.official_norm_reference,
-- que es el campo canónico del motor de catálogos para ese propósito.
