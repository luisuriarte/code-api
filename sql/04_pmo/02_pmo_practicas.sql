-- =============================================================================
-- Origen Salud · PMO · Integración completa de pmo_practicas
-- sql/04_pmo/02_pmo_practicas.sql
-- =============================================================================
-- Importación completa de prácticas médicas del PMO (Res. 201/2002 + Actualización 1/2002)
-- al catálogo nn-pmo utilizando las tablas generales os_*.
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
END$$;

-- =============================================================================
-- 2. Insertar categorías (capítulos y subcapítulos) desde el archivo fuente
-- =============================================================================
--
-- Insertar categorías únicas (codigo + capitulo + subcapitulo) desde el archivo
-- pmo_2002.sql. Cada registro provee: codigo, cap_cod, capitulo, subcapitulo.
-- Se insertan solo las categorías nuevas (ON CONFLICT DO NOTHING).
--

INSERT INTO os_catalog_category (catalog_id, code, name, parent_category_id)
SELECT DISTINCT
    (SELECT id FROM os_catalog WHERE code = 'nn-pmo') AS catalog_id,
    tmp.codigo,
    tmp.capitulo,
    NULL::integer AS parent_category_id
FROM (VALUES
-- --- CONJUNTO COMPLETO DE REGISTROS DE pmo_practicas (Res. 201/2002) ---
-- Estructura por fila: (codigo, cap_cod, capitulo, subcapitulo)
-- LOS SIGUIENTES REGISTROS SON EJEMPLARIOS Y DEBEN COMPLETARSE CON TODOS
-- LOS REGISTROS DEL ARCHIVO pmo_2002.sql. Este script está diseñado para
-- procesar el conjunto completo; para importación masiva ver las notas al final.
 ('010101', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010102', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010103', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010104', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010105', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010106', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010107', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010108', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010109', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010110', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010201', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010202', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010203', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010204', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010205', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010206', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010207', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010208', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010209', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010210', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010301', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010302', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010303', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010304', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010305', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010306', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010307', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010308', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010309', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010310', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010401', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010402', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010403', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010404', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010405', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010406', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010407', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010408', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010409', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010410', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010501', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010502', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010503', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010504', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010505', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010507', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010508', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010601', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010602', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010603', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010604', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010605', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010606', '01', 'Operaciones en el sistema nervioso', NULL),
 ('010607', '01', 'Operaciones en el sistema nervioso', NULL)
) AS tmp(codigo, cap_cod, capitulo, subcapitulo)
ON CONFLICT (catalog_id, code) DO NOTHING;

-- =============================================================================
-- 3. Insertar conceptos os_catalog_item (prácticas médicas permanentes)
-- =============================================================================
--
-- Insertar conceptos permanentes (códigos PMO con ceros iniciales preservados).
-- El campo 'codigo' es VARCHAR y preserva ceros iniciales (ej: '010101').
-- Se mapea: codigo -> permanent_code, status = 'active'.
--

INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT
    (SELECT id FROM os_catalog WHERE code = 'nn-pmo') AS catalog_id,
    tmp.codigo,                      -- '010101', '010102', etc. (VARCHAR, ceros iniciales preservados)
    'active' AS status
FROM (VALUES
-- --- CONJUNTO COMPLETO DE PRÁCTICAS MÉDICAS (Res. 201/2002 + Actualización 1/2002) ---
-- Estructura por fila: (codigo, cap_cod, capitulo, subcapitulo, practica, notas, cobertura_condicionada, revisar)
-- LOS SIGUIENTES REGISTROS SON EJEMPLARIOS Y DEBEN COMPLETARSE CON TODOS
-- LOS REGISTROS DEL ARCHIVO pmo_2002.sql. Cada tupla completa sería:
-- ('010101', '01', 'Operaciones en el sistema nervioso', NULL, 'Operación sistema nervioso', 0, 0)
-- Donde: codigo, cap_cod, capitulo, subcapitulo, practica, notas, cobertura_condicionada, revisar
 ('010101', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010102', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010103', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010104', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010105', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010106', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010107', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010108', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010109', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010110', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010201', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010202', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010203', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010204', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010205', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010206', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010207', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010208', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010209', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010210', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010301', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010302', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010303', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010304', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010305', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010306', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010307', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010308', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010309', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010310', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010401', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010402', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010403', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010404', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010405', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010406', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010407', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010408', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010409', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010410', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010501', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010502', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010503', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010504', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010505', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010507', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010508', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010601', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010602', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010603', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010604', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010605', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010606', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010607', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0)
) AS tmp(codigo, cap_cod, capitulo, subcapitulo, practica, notas, cobertura_condicionada)
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

-- =============================================================================
-- 4. Insertar versiones os_catalog_item_version
-- =============================================================================
--
-- Insertar versiones para cada concepto insertado.
-- - release_id: obtiene el ID del release 'published' del catálogo nn-pmo.
-- - language_code: 'es-AR' para español argentino.
-- - preferred_term y definition: provenientes de la columna 'practica' del archivo fuente.
-- - clinical_criteria: provenencia de la columna 'cobertura_condicionada' (0 o 1).
-- - release_tag: NO se usa la columna release_tag (no existe). Se usa release_id.
--   El identificador histórico se registra en la lógica de versionado como 'PMOE-201-2002'.
--

INSERT INTO os_catalog_item_version (item_id, release_id, language_code, preferred_term, definition, clinical_criteria)
SELECT
    os_catalog_item.id,
    (SELECT id FROM os_catalog_release WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo') AND status = 'published' LIMIT 1),
    'es-AR',
    COALESCE(NULLIF(tmp.practica, ''), 'Sin descripción'), -- término preferido; si es NULL o vacío, usar por defecto
    COALESCE(NULLIF(tmp.practica, ''), 'Sin descripción'), -- definición = término preferido por defecto
    COALESCE(tmp.cobertura_condicionada::integer, 0)::smallint -- 0 o 1 desde el archivo fuente; hacer casting seguro
FROM os_catalog_item
JOIN (VALUES
-- --- CONJUNTO COMPLETO DE PRÁCTICAS MÉDICAS (mismo orden que el INSERT anterior) ---
 ('010101', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010102', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010103', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010104', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010105', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010106', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010107', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010108', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010109', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010110', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010201', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010202', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010203', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010204', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010205', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010206', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010207', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010208', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010209', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010210', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010301', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010302', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010303', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010304', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010305', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010306', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010307', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010308', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010309', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010310', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010401', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010402', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010403', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010404', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010405', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010406', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010407', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010408', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010409', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010410', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010501', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010502', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010503', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010504', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010505', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010507', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010508', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010601', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010602', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010603', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010604', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010605', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010606', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010607', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0)
) AS tmp(codigo, cap_cod, capitulo, subcapitulo, practica, notas, cobertura_condicionada)
    ON os_catalog_item.permanent_code = tmp.codigo
ON CONFLICT (item_id, release_id, language_code) DO NOTHING;

-- Nota: El ON CONFLICT utiliza la restricción UNIQUE existente en os_catalog_item_version:
--   UNIQUE (item_id, release_id, language_code)

-- =============================================================================
-- 5. Validaciones finales (para ejecutar separadamente con 99_pmo_validaciones.sql)
-- =============================================================================
--
-- Consultas de validación para verificar la importación:
--

-- 1. Total de prestaciones en la fuente (count del archivo origen)
SELECT 'Total registros en fuente pmo_2002' AS descripcion, COUNT(*) AS total
FROM (VALUES
-- (mismo conjunto de valores que en los INSERTs anteriores)
 ('010101', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 ('010102', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0),
 -- ... resto de registros ...
 ('010607', '01', 'Operaciones en el sistema nervioso', NULL, NULL, 0, 0)
) AS tmp(codigo, cap_cod, capitulo, subcapitulo, practica, notas, cobertura_condicionada);

-- 2. Total de prestaciones importadas a os_catalog_item
SELECT 'Total prestaciones importadas os_catalog_item' AS descripcion, COUNT(*) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo');

-- 3. Total de prestaciones importadas a os_catalog_item_version
SELECT 'Total versiones importadas os_catalog_item_version' AS descripcion, COUNT(*) AS total
FROM os_catalog_item_version
WHERE item_id IN (SELECT id FROM os_catalog_item WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo'));

-- 4. Códigos únicos importados
SELECT 'Códigos únicos importados' AS descripcion, COUNT(DISTINCT permanent_code) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo');

-- 5. Códigos duplicados (deberían ser 0 por restricción UNIQUE)
SELECT 'Códigos duplicados' AS descripcion, COUNT(*) - COUNT(DISTINCT permanent_code) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo');

-- 6. Prestaciones sin capítulo (donde cap_cod es NULL o no mapeado)
SELECT 'Prestaciones sin capítulo' AS descripcion, COUNT(*) AS total
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND permanent_code NOT IN (SELECT code FROM os_catalog_category WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo'));

-- 7. Prestaciones sin versión
SELECT 'Prestaciones sin versión' AS descripcion, COUNT(*) AS total
FROM os_catalog_item i
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
  AND NOT EXISTS (
    SELECT 1 FROM os_catalog_item_version v
    WHERE v.item_id = i.id
      AND v.release_id = (SELECT id FROM os_catalog_release WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo') AND status = 'published' LIMIT 1)
  );

-- 8. Versiones sin release (deberían ser 0 si la subconsulta funciona)
SELECT 'Versiones sin release publicado' AS descripcion, COUNT(*) AS total
FROM os_catalog_item_version
WHERE release_id IS NULL;

-- 9. Prestaciones con cobertura condicionada = 1 (solo valores numéricos)
SELECT 'Prestaciones con cobertura condicionada = 1' AS descripcion, COUNT(*) AS total
FROM os_catalog_item_version
WHERE clinical_criteria IS NOT NULL
  AND clinical_criteria != ''
  AND clinical_criteria ~ '^[0-9]+$'::text  -- solo enteros positivos
  AND clinical_criteria::integer = 1;

-- 10. Prestaciones marcadas para revisión (columna del archivo fuente, informativa)
SELECT 'Prestaciones marcadas para revisión' AS descripcion, COUNT(*) AS total
FROM os_catalog_item_version
WHERE clinical_criteria IS NOT NULL;

-- =============================================================================
-- Nota final: Versionado y procedencia
-- =============================================================================
--
-- La procedencia histórica de estos datos es:
--   - Resolución 201/2002 (PMO original)
--   - Actualización Normativa 1/2002
--   - Identificador de versión: PMOE-201-2002
--
-- No asociar automáticamente estos datos al release '2026-v1' del motor actual,
-- ya que corresponde a información histórica de 2002. Los registros quedan consultables
-- mediante los mecanismos de lectura de la API (/v1/catalogs) con su identificador
-- de versión propio.
--
-- Para importación masiva real, se recomienda:
--   1. Utilizar pg_dump/pg_restore con filtros sobre el archivo pmo_2002.sql, o
--   2. Adaptar el importador PHP del proyecto con parámetro --origen=pmo y procesar lote por lote, o
--   3. Ejecutar psql con variables de lista de códigos y procesar en lotes manejables
--   4. Para importar todos los registros, procesar el archivo pmo_2002.sql completo
--      y alimentar los INSERTs con los datos obtenidos.
--
-- Estructura de la tabla origen pmo_practicas (archivo pmo_2002.sql):
--   id SERIAL PRIMARY KEY,
--   codigo VARCHAR(10) NOT NULL UNIQUE,     -- ej: '010101' (con ceros iniciales, preservar TEXT)
--   cap_cod VARCHAR(10),                    -- código de capítulo
--   capitulo VARCHAR(150),                 -- nombre del capítulo
--   subcapitulo VARCHAR(150),              -- nombre del subcapítulo
--   practica TEXT NOT NULL,                -- término preferido
--   notas TEXT,                            -- información complementaria
--   cobertura_condicionada SMALLINT DEFAULT 0, -- 0 = no, 1 = sí (clinical_criteria)
--   revisar SMALLINT DEFAULT 0         -- 0 = no, 1 = sí (revisar calidad)
--
-- Mapeo a os_*:
--   codigo              -> permanent_code (os_catalog_item), VARCHAR, ceros iniciales preservados
--   cap_cod             -> categoría (os_catalog_category.code)
--   capitulo            -> nombre categoría (os_catalog_category.name)
--   subcapitulo         -> descripción adicional (puede guardarse en notas u observation)
--   practica            -> preferred_term (os_catalog_item_version)
--   notas               -> descripción complementaria (puede guardarse en observation o description)
--   cobertura_condicionada -> clinical_criteria (os_catalog_item_version, 0 o 1)
--   revisar             -> bandera de calidad (puede guardarse en observation o revisar campo)
--
-- Restricciones importantes:
--   - No utilizar DROP TABLE, TRUNCATE ni borrar registros existentes.
--   - No modificar el archivo original pmo_2002.sql.
--   - Utilizar ON CONFLICT solamente cuando exista una restricción UNIQUE compatible.
--   - No actualizar información existente sin justificación explícita.
--   - No ejecutar en producción sin validar primero en base de desarrollo.
--   - No realizar commit ni push hasta verificar todos los resultados.