-- =============================================================================
-- Origen Salud · PMO · Integración de prácticas médicas (pmo_practicas)
-- sql/04_pmo/02_pmo_practicas.sql
-- =============================================================================
-- Integración de prácticas médicas del PMO (Res. 201/2002 + Actualización 1/2002)
-- al catálogo nn-pmo usando tablas generales os_*.
-- Idempotente: seguro reejecutarse sin duplicar registros.
-- =============================================================================

SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. Verificar que el catálogo nn-pmo existe
-- =============================================================================
DO $$
BEGIN
    IF to_regclass('public.os_catalog') IS NULL THEN
        RAISE EXCEPTION 'Tabla os_catalog no existe. Ejecutá sql/01_schema/design.sql y sql/02_catalogs/origen_catalog_engine.sql primero.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM os_catalog WHERE code = 'nn-pmo') THEN
        RAISE EXCEPTION 'El catálogo nn-pmo no existe en os_catalog. Ejecutá sql/02_catalogs/origen_catalog_engine.sql para registralo.';
    END IF;
END
$$;

-- =============================================================================
-- 2. Insertar categorías (capítulos y subcapítulos) desde los datos origen
-- =============================================================================
--
-- Insertar categorías únicas (codigo + capitulo) desde el archivo pmo_2002.sql.
-- Como SQL puro no puede leer el archivo CSV directamente, insertamos ejemplos
-- representativos. Para importación masiva, usar COPY o adaptar el importador PHP.
--
INSERT INTO os_catalog_category (catalog_id, code, name, parent_category_id)
SELECT DISTINCT
    (SELECT id FROM os_catalog WHERE code = 'nn-pmo') AS catalog_id,
    codigo,
    capitulo,
    NULL::integer AS parent_category_id
FROM (VALUES
-- Datos representativos de pmo_practicas (registros 010101 a 010201)
 ('010101', '01', 'Operaciones en el sistema nervioso'),
 ('010102', '01', 'Operaciones en el sistema nervioso'),
 ('010103', '01', 'Operaciones en el sistema nervioso'),
 ('010201', '01', 'Operaciones en el sistema nervioso'),
 ('010301', '01', 'Operaciones en el sistema nervioso'),
 ('010401', '01', 'Operaciones en el sistema nervioso'),
 ('010501', '01', 'Operaciones en el sistema nervioso'),
 ('010601', '01', 'Operaciones en el sistema nervioso')
) AS tmp(codigo, capitulo, subcapitulo)
ON CONFLICT (catalog_id, code) DO NOTHING;

-- =============================================================================
-- 3. Insertar conceptos os_catalog_item y versiones
-- =============================================================================
--
-- Insertar conceptos permanentes (códigos PMO con ceros iniciales preservados)
--
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT
    (SELECT id FROM os_catalog WHERE code = 'nn-pmo') AS catalog_id,
    codigo,
    'active' AS status
FROM (VALUES
    ('010101'),
    ('010102'),
    ('010103'),
    ('010104'),
    ('010105'),
    ('010106'),
    ('010107'),
    ('010108'),
    ('010109'),
    ('010110'),
    ('010111'),
    ('010112'),
    ('010113'),
    ('010114'),
    ('010115')
) AS tmp(codigo)
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

-- =============================================================================
-- 3. Insertar versiones os_catalog_item_version
-- =============================================================================
--
INSERT INTO os_catalog_item_version (item_id, release_id, language_code, preferred_term, definition, clinical_criteria, release_tag)
SELECT
    os_catalog_item.id,
    (SELECT id FROM os_catalog_release WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo') AND status = 'published' LIMIT 1),
    'es-AR',
    practica,
    practica,                      -- definición = término preferido por defecto
    cobertura_condicionada,      -- 0 o 1 desde el archivo origen
    'PMOE-201-2002'              -- identificador histórico, NO reutilizar 2026-v1
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
ON CONFLICT (item_id, release_id, language_code) DO NOTHING;

-- =============================================================================
-- Nota final: Para importación masiva real
-- =============================================================================
--
-- El presente script está diseñado para ser ejecutado en conjunto con:
-- - El archivo de origen tools/sources/pmo/pmo_2002.sql (SIN MODIFICAR)
-- - Un proceso que lea el archivo CSV y alimente los INSERTs anteriores
-- - O adaptación del importador PHP del proyecto con parámetro --origen=pmo
--
-- Estructura de la tabla origen pmo_practicas (archivo pmo_2002.sql):
--   id SERIAL PRIMARY KEY,
--   codigo VARCHAR(10) NOT NULL UNIQUE,     -- ej: '010101' (con ceros iniciales, preservar texto)
--   cap_cod VARCHAR(10),                    -- código de capítulo
--   capitulo VARCHAR(150),                 -- nombre del capítulo
--   subcapitulo VARCHAR(150),              -- nombre del subcapítulo
--   practica TEXT NOT NULL,                -- término preferido
--   notas TEXT,                            -- información complementaria
--   cobertura_condicionada SMALLINT DEFAULT 0, -- 0 = no, 1 = sí (clinical_criteria)
--   revisar SMALLINT DEFAULT 0         -- 0 = no, 1 = sí (revisar calidad)
--
-- Mapeo a os_*:
--   codigo              → permanent_code (os_catalog_item), VARCHAR, ceros iniciales preservados
--   capitulo            → categoría en os_catalog_category (code + name)
--   practica            → preferred_term (os_catalog_item_version)
--   cobertura_condicionada → clinical_criteria (os_catalog_item_version, 0 o 1)
--   revisar             → puede guardarse en observaciones o campo de calidad
--
-- Para importación masiva recomendada:
--   1. Utilizar pg_dump/pg_restore con filtros, o
--   2. Adaptar el importador PHP del proyecto con parámetro --origen=pmo, o
--   3. Utilizar psql variables: psql -v 'codigo_list="010101,010102,..."' ... -f 02_pmo_practicas.sql
-- =============================================================================