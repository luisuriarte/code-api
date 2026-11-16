-- =============================================================================
-- Origen Salud · PMO · Formulario Terapéutico
-- sql/04_pmo/01_formulario_terapeutico.sql
-- =============================================================================
-- Asociacion de formularios therapeuticos a las praticas medicas del PMO
-- (Res. 201/2002 + Actualizacion 1/2002) al catologo nn-pmo.
-- Idempotente: seguro reejecutarse sin duplicar registros.
-- =============================================================================

SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. Verificar que el catologo nn-pmo existe
-- =============================================================================
DO $$
BEGIN
    IF to_regclass('public.os_catalog') IS NULL THEN
        RAISE EXCEPTION 'Tabla os_catalog no existe. Ejecutar sql/01_schema/design.sql y sql/02_catalogs/origen_catalog_engine.sql primero.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM os_catalog WHERE code = 'nn-pmo') THEN
        RAISE EXCEPTION 'El catologo nn-pmo no existe en os_catalog.';
    END IF;
END$$;

-- =============================================================================
-- 2. Verificar que las practicas PMO esten importadas
-- =============================================================================
--
-- Validacion preliminar: asegurarse de que hay practicas importadas
-- antes de asociar formularios.
--

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM os_catalog_item WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')) = 0 THEN
        RAISE EXCEPTION 'No hay practicas importadas en os_catalog_item. Ejecutar sql/04_pmo/02_pmo_practicas.sql primero.';
    END IF;
END$$;

-- =============================================================================
-- 3. Insertar formularios teraputicos asociados a practicas
-- =============================================================================
--
-- Mapeo: cada pratica medica puede tener uno o mas formularios therapeuticos.
-- Dado que el modelo general os_* no tiene una tabla de formularios preexistente,
-- utilizamos la columna 'observation' de os_catalog_item_version para almacenar
-- la referencia al formato, o utilizamos una convenio de nombres.
--
-- Estructura:
--   - permanent_code: codigo de la pratica (ej: '010101')
--   - formulario: nombre del formato therapeutico
--   - indicaciones: texto complementario
--

-- Insertar formularios therapeuticos para un subconjunto representativo
-- (para importacion masiva, procesar todas las practicas del archivo fuente)
--
INSERT INTO os_catalog_item (catalog_id, permanent_code, status, observation)
SELECT
    (SELECT id FROM os_catalog WHERE code = 'nn-pmo') AS catalog_id,
    permanent_code,
    'active' AS status,
    'FORMULARIO:' || permanent_code || ':TERAPEUTICO' AS observation
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

-- =============================================================================
-- 4. Validacion del formulario asociado
-- =============================================================================
--
SELECT
    'Formularios asociados a practicas' AS descripcion,
    COUNT(*) AS total_formularios
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND observation LIKE 'FORMULARIO:%';

-- Verificar algunas asociaciones
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
-- El presente script esta disenado para ser utilizado en conjunto con:
-- - El archivo 02_pmo_practicas.sql (já ejecutado)
-- - Procesos posteriores que completen la carga de formularios
-- - O adaptar la columna 'observation' según la estructura del proyecto
--
-- Restricciones:
-- - No crear tablas paralelas de prestaciones.
-- - Utilizar exclusivamente tablas generales os_*.
-- - Comportamiento idempotente (ON CONFLICT DO NOTHING).
-- - No modificar el archivo fuente pmo_2002.sql.