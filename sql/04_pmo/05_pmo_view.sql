-- =============================================================================
-- Origen Salud · PMO · Vistas de compatibilidad
-- sql/04_pmo/05_pmo_view.sql
-- =============================================================================
-- Crea las vistas pmo_practicas y pmo_odontologia sobre las tablas del catalog
-- engine (os_catalog_item, os_catalog_item_version, os_catalog_category).
-- El PHP consulta estas vistas exactamente como si fueran tablas nativas.
-- Idempotente: seguro reejecutarse.
-- =============================================================================

SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. Vista pmo_practicas
--    Mapea os_catalog_item + os_catalog_item_version para el catálogo nn-pmo.
--    Columnas esperadas por TerminologySearchService::searchPmoPracticas() y
--    findPmoPractica():
--      id, codigo, cap_cod, capitulo, subcapitulo, practica,
--      notas, cobertura_condicionada, revisar
-- =============================================================================
CREATE OR REPLACE VIEW pmo_practicas AS
SELECT
    i.id,
    i.permanent_code                                            AS codigo,
    LEFT(i.permanent_code, 2)                                   AS cap_cod,
    cat.name                                                    AS capitulo,
    NULL::text                                                  AS subcapitulo,
    CASE
        WHEN v.preferred_term IS DISTINCT FROM 'Sin descripción'
        THEN v.preferred_term
        ELSE NULL
    END                                                         AS practica,
    NULLIF(v.definition, 'Sin descripción')                     AS notas,
    CASE
        WHEN v.clinical_criteria ~ '^[0-9]+$'
        THEN v.clinical_criteria::smallint
        ELSE 0
    END                                                         AS cobertura_condicionada,
    0::smallint                                                 AS revisar
FROM os_catalog_item i
JOIN os_catalog c
    ON c.id = i.catalog_id AND c.code = 'nn-pmo'
LEFT JOIN os_catalog_item_version v
    ON v.item_id = i.id
LEFT JOIN os_catalog_category cat
    ON cat.catalog_id = i.catalog_id
   AND cat.code = i.permanent_code
WHERE i.status = 'active';

COMMENT ON VIEW pmo_practicas IS
    'Vista de compatibilidad: expone os_catalog_item/version del catálogo nn-pmo '
    'con la misma interfaz que la tabla pmo_practicas (Res. 201/2002).';

-- =============================================================================
-- 2. Vista pmo_odontologia
--    Prácticas odontológicas: ítems del catálogo nn-pmo con categoría ODON.
--    Columnas esperadas por findPmoPractica() (fallback odontológico):
--      id, codigo, practica, descripcion
-- =============================================================================
CREATE OR REPLACE VIEW pmo_odontologia AS
SELECT
    i.id,
    i.permanent_code                                            AS codigo,
    NULLIF(v.preferred_term, 'Sin descripción')                 AS practica,
    NULLIF(v.definition,     'Sin descripción')                 AS descripcion
FROM os_catalog_item i
JOIN os_catalog c
    ON c.id = i.catalog_id AND c.code = 'nn-pmo'
JOIN os_catalog_item_version v
    ON v.item_id = i.id
JOIN os_catalog_category odon
    ON odon.catalog_id = i.catalog_id AND odon.code = 'ODON'
WHERE i.status = 'active'
  AND v.category_id = odon.id;

COMMENT ON VIEW pmo_odontologia IS
    'Vista de compatibilidad: prácticas odontológicas del catálogo nn-pmo '
    '(categoría ODON, identificadas por patrón de código 13xx/14xx o término).';

-- =============================================================================
-- 3. Validación
-- =============================================================================
SELECT 'pmo_practicas'   AS vista, COUNT(*) AS total FROM pmo_practicas
UNION ALL
SELECT 'pmo_odontologia' AS vista, COUNT(*) AS total FROM pmo_odontologia;
