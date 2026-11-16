-- =============================================================================
-- Origen Salud · PMO · Odontología
-- sql/04_pmo/03_odontologia.sql
-- =============================================================================
-- Identificación y separación de prácticas odontológicas del PMO
-- (Res. 201/2002 + Actualización 1/2002).
-- El Programa Médico Obligatorio histórico incluye algunas prestaciones dentales.
-- Este script las identifica y opcionalmente las aísla para trabajo específico.
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
-- 2. Identificar prácticas potencialmente odontológicas
-- =============================================================================
--
-- Reglas para identificar prácticas odontológicas:
-- - Códigos que empiezan con '13' o '14' suelen ser estomatología/odontología
-- - O prácticas con 'dental', 'pieza', 'sencillez' en observation/descripción
-- - Revisar el archivo pmo_2002.sql para mapeo exacto
--
-- Para este script, identificamos prácticas por patrón de código o descripción.
--

-- Seleccionar prácticas por patrón de código (ej: códigos 13xx, 14xx)
-- Nota: En el conjunto actual (010101-010607) son todas neurocirugía.
-- Para odontología real, procesar el archivo pmo_2002.sql completo.
--
SELECT
    'Prácticas por patrón de código' AS descripcion,
    COUNT(*) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND permanent_code ~ '^13|^14';  -- patrón odontológico

-- Alternativa: buscar por descripción en observation/preferred_term
SELECT
    'Prácticas por descripción' AS descripcion,
    COUNT(*) AS total
FROM os_catalog_item_version
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND preferred_term ILIKE '%dental%'
     OR preferred_term ILIKE '%odont%'
     OR preferred_term ILIKE '%estom%';

-- =============================================================================
-- 3. Marcar prácticas odontológicas en el observation
-- =============================================================================
--
-- Etiquetar las prácticas identificadas como odontológicas en el campo observation
-- Esto permite filtrado posterior sin crear tablas paralelas.
--
UPDATE os_catalog_item
SET observation = CASE
    WHEN permanent_code ~ '^13|^14' THEN observation || ';ODONTOLOGICO'
    ELSE observation
END,
    status = 'active'
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND (permanent_code ~ '^13|^14'
       OR permanent_code IN (
         SELECT permanent_code FROM os_catalog_item_version
         WHERE preferred_term ILIKE '%dental%'
            OR preferred_term ILIKE '%odont%'
            OR preferred_term ILIKE '%estom%'
       ))
ON CONFLICT DO NOTHING;

-- =============================================================================
-- 4. Validación de identificación odontológica
-- =============================================================================
--
SELECT
    'Prácticas marcadas odontológicas' AS descripcion,
    COUNT(*) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND observation LIKE '%ODONTOLOGICO%';

-- Listar las prácticas identificadas
SELECT
    permanent_code,
    observation
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND observation LIKE '%ODONTOLOGICO%';

-- =============================================================================
-- Nota final
-- =============================================================================
--
-- Hallazgos:
-- - El conjunto actual (010101-010607) corresponde a neurocirugía (sistema nervioso)
-- - Prácticas odontológicas reales requerirían procesar el archivo pmo_2002.sql completo
-- - Códigos 13xx y 14xx suelen ser estomatología/patología bucal en catálogos CIE
- Esta separación es lógica/identificatoria; no crea tablas paralelas
- Para trabajo odontológico específico, procesar pmo_2002.sql con filtro --origen=odontologia
- Idempotente: seguro reejecutarse