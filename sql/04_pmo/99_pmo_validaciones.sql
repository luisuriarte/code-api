-- =============================================================================
-- Origen Salud · PMO · Validaciones de calidad
-- sql/04_pmo/99_pmo_validaciones.sql
-- =============================================================================
-- Consultas de validación para verificar la integración de pmo_practicas.
-- Ejecutar después de importar.
-- =============================================================================

SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. CANTIDAD DE REGISTROS: ORIGEN vs DESTINO
-- =============================================================================

-- Cantidad en la tabla origen (archivo pmo_2002.sql)
-- Nota: Count exacto depende de cuántos registros tenga el archivo fuente.
-- Verificar manualmente: SELECT COUNT(*) FROM pmo_practicas; (en el archivo fuente)

-- Cantidad importada a os_catalog_item (solo nn-pmo)
SELECT
    'os_catalog_item' AS tabla,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT permanent_code) AS codigos_unicos,
    COUNT(*) - COUNT(DISTINCT permanent_code) AS duplicados
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo');

-- Cantidad de versiones importadas
SELECT
    'os_catalog_item_version' AS tabla,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT item_id) AS conceptos_con_version,
    COUNT(*) FILTER (WHERE clinical_criteria IS NOT NULL) AS con_cobertura_condicionada
FROM os_catalog_item_version
WHERE item_id IN (SELECT id FROM os_catalog_item WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo'));

-- =============================================================================
-- 2. VALIDACIÓN DE CÓDIGOS
-- =============================================================================

-- Verificar códigos con ceros iniciales preservados (deben empezar con '0')
SELECT
    ' códigos con ceros iniciales' AS validacion,
    COUNT(*) AS total,
    COUNT(CASE WHEN permanent_code LIKE '0%' THEN 1 END) AS con_cero_inicial,
    COUNT(CASE WHEN permanent_code !~ '^0' THEN 1 END) AS sin_cero_inicial
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo');

-- Verificar códigos vacíos o nulos
SELECT
    ' códigos vacíos' AS validacion,
    COUNT(*) AS total_vacios
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
AND (permanent_code IS NULL OR permanent_code = '');

-- Verificar códigos duplicados (deben ser UNIQUE)
SELECT
    ' códigos duplicados' AS validacion,
    permanent_code,
    COUNT(*) AS repeticiones
FROM os_catalog_item
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
GROUP BY permanent_code
HAVING COUNT(*) > 1;

-- =============================================================================
-- 3. VALIDACIÓN DE CATEGORÍAS
-- =============================================================================

-- Verificar capítulos registrados (usando code de os_catalog_category)
SELECT
    ' capítulos registrados' AS validacion,
    code,
    name
FROM os_catalog_category
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
ORDER BY code;

-- Verificar subcapítulos (categorías con padre)
SELECT
    ' subcapítulos' AS validacion,
    c.code,
    c.name,
    p.code AS padre,
    c.name AS nombre_hijo
FROM os_catalog_category c
LEFT JOIN os_catalog_category p ON c.parent_category_id = p.id AND c.catalog_id = p.catalog_id
WHERE c.catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
ORDER BY c.code;

-- =============================================================================
-- 4. VALIDACIÓN DE VERSIONES Y CONDICIONALIDAD
-- =============================================================================

-- Versiones por concepto
SELECT
    ' versiones por concepto' AS validacion,
    i.permanent_code,
    v.preferred_term,
    v.clinical_criteria,
    v.language_code
FROM os_catalog_item i
JOIN os_catalog_item_version v ON i.id = v.item_id
WHERE i.catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
ORDER BY i.permanent_code;

-- Conceptos con cobertura condicionada (clinical_criteria no nulo y no vacío)
SELECT
    ' con cobertura condicionada' AS validacion,
    i.permanent_code,
    v.preferred_term,
    v.clinical_criteria
FROM os_catalog_item i
JOIN os_catalog_item_version v ON i.id = v.item_id
WHERE i.catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
AND v.clinical_criteria IS NOT NULL
AND v.clinical_criteria != '';

-- Conceptos pendientes de revisión (review_status = 'review')
SELECT
    ' pendientes de revisión' AS validacion,
    i.permanent_code,
    v.preferred_term,
    v.review_status
FROM os_catalog_item i
JOIN os_catalog_item_version v ON i.id = v.item_id
LEFT JOIN os_concept_mapping m ON i.id = m.item_id AND m.terminology_system_id = 1  -- SNOMED-CT
WHERE i.catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
-- Sin revisión (columna no existe en modelo actual; informativa solo)
SELECT 'sin revisión' AS validacion, i.permanent_code

-- =============================================================================
-- 5. INTEGRIDAD REFERENCIAL
-- =============================================================================

-- Verificar que todos los ítems tengan versión publicada
SELECT
    ' sin versión publicada' AS validacion,
    i.permanent_code
FROM os_catalog_item i
LEFT JOIN os_catalog_item_version v ON i.id = v.item_id
JOIN os_catalog_release r ON v.release_id = r.id
WHERE i.catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
AND (v.release_id IS NULL OR r.status != 'published');

-- Verificar que todas las categorías tengan catálogo padre (NULL está bien)
SELECT
    ' categoría sin catálogo padre (NULL está bien)' AS validacion,
    c.code
FROM os_catalog_category c
WHERE c.catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
AND c.parent_category_id IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM os_catalog_category p WHERE p.id = c.parent_category_id AND p.catalog_id = c.catalog_id);

-- =============================================================================
-- 6. RESUMEN EJECUTIVO
-- =============================================================================

SELECT
    'RESUMEN EJECUTIVO' AS tipo,
    (SELECT COUNT(*) FROM os_catalog_item WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')) AS total_registros,
    (SELECT COUNT(DISTINCT permanent_code) FROM os_catalog_item WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')) AS total_codigos_unicos,
    (SELECT COUNT(*) FROM os_catalog_item_version WHERE item_id IN (SELECT id FROM os_catalog_item WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo'))) AS total_versiones,
    (SELECT COUNT(*) FROM os_catalog_item_version WHERE clinical_criteria IS NOT NULL AND clinical_criteria != '' AND item_id IN (SELECT id FROM os_catalog_item WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo'))) AS total_con_cobertura_condicionada;

-- =============================================================================
-- Fin de validaciones
-- =============================================================================