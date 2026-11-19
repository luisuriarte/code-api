-- =============================================================================
-- FASE 3 (§16) · CORRECTIVO de desempate del idioma default
-- =============================================================================
-- Ejecutar UNA VEZ, solo si la verificación de Fase 3 mostró catálogos con
-- default `en` y contenido empatado en `es-AR` (en la ejecución del 2026-11-19
-- ocurrió con dentar-an y dentar-cl).
--
-- Motivo: la regla original ordenaba el desempate por language_code ASC, y
-- 'en' < 'es-AR'. En catálogos con dos versiones por ítem (es-AR y en) el
-- empate hacía ganar 'en'. La regla correcta prioriza 'es-AR' por ser el locale
-- del portal y el fallback global D-27. El propio fase3_i18n.sql ya fue
-- corregido para futuras ejecuciones.
--
-- ADITIVO E IDEMPOTENTE: usa INSERT ... ON CONFLICT DO UPDATE sobre filas ya
-- existentes de os_catalog_language. No elimina tablas, columnas ni datos.
-- Los cuatro pasos van en este orden para no violar los índices únicos
-- parciales uq_ocl_default / uq_ocl_fallback durante el intercambio de flags.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN;

-- Objetivo: catálogos donde 'en' es default hoy, pero 'es-AR' tiene tantas o
-- más versiones seleccionables que 'en'. Solo se corrige si hay contenido en
-- 'en'; si no lo hay, el default es-AR ya era el correcto.
WITH contenido AS (
    SELECT i.catalog_id, v.language_code, count(*) AS filas
      FROM os_catalog_item i
      JOIN os_catalog_item_version v ON v.item_id = i.id
      JOIN os_language idi ON idi.code = v.language_code
     WHERE v.language_code IS NOT NULL
       AND idi.is_active
       AND NOT idi.is_source_only
     GROUP BY i.catalog_id, v.language_code
),
preferido AS (
    SELECT c.catalog_id,
           CASE WHEN COALESCE(es.filas, 0) >= COALESCE(en.filas, 0)
                THEN 'es-AR' ELSE 'en' END AS lang
      FROM (SELECT DISTINCT catalog_id FROM contenido) c
      LEFT JOIN contenido es ON es.catalog_id = c.catalog_id AND es.language_code = 'es-AR'
      LEFT JOIN contenido en ON en.catalog_id = c.catalog_id AND en.language_code = 'en'
     WHERE en.filas > 0
),
objetivo AS (
    SELECT p.catalog_id
      FROM preferido p
     WHERE p.lang = 'es-AR'
)
INSERT INTO os_catalog_language
       (catalog_id, language_code, is_default, is_fallback, is_bridge, coverage_status)
SELECT o.catalog_id, 'es-AR', FALSE, FALSE, FALSE, 'undetermined'
  FROM objetivo o
ON CONFLICT (catalog_id, language_code) DO UPDATE
   SET is_default  = EXCLUDED.is_default,
       is_fallback = EXCLUDED.is_fallback;

WITH contenido AS (
    SELECT i.catalog_id, v.language_code, count(*) AS filas
      FROM os_catalog_item i
      JOIN os_catalog_item_version v ON v.item_id = i.id
      JOIN os_language idi ON idi.code = v.language_code
     WHERE v.language_code IS NOT NULL
       AND idi.is_active
       AND NOT idi.is_source_only
     GROUP BY i.catalog_id, v.language_code
),
preferido AS (
    SELECT c.catalog_id,
           CASE WHEN COALESCE(es.filas, 0) >= COALESCE(en.filas, 0)
                THEN 'es-AR' ELSE 'en' END AS lang
      FROM (SELECT DISTINCT catalog_id FROM contenido) c
      LEFT JOIN contenido es ON es.catalog_id = c.catalog_id AND es.language_code = 'es-AR'
      LEFT JOIN contenido en ON en.catalog_id = c.catalog_id AND en.language_code = 'en'
     WHERE en.filas > 0
),
objetivo AS (
    SELECT p.catalog_id
      FROM preferido p
     WHERE p.lang = 'es-AR'
)
INSERT INTO os_catalog_language
       (catalog_id, language_code, is_default, is_fallback, is_bridge, coverage_status)
SELECT o.catalog_id, 'en', FALSE, FALSE, FALSE, 'undetermined'
  FROM objetivo o
ON CONFLICT (catalog_id, language_code) DO UPDATE
   SET is_default  = EXCLUDED.is_default,
       is_fallback = EXCLUDED.is_fallback;

WITH contenido AS (
    SELECT i.catalog_id, v.language_code, count(*) AS filas
      FROM os_catalog_item i
      JOIN os_catalog_item_version v ON v.item_id = i.id
      JOIN os_language idi ON idi.code = v.language_code
     WHERE v.language_code IS NOT NULL
       AND idi.is_active
       AND NOT idi.is_source_only
     GROUP BY i.catalog_id, v.language_code
),
preferido AS (
    SELECT c.catalog_id,
           CASE WHEN COALESCE(es.filas, 0) >= COALESCE(en.filas, 0)
                THEN 'es-AR' ELSE 'en' END AS lang
      FROM (SELECT DISTINCT catalog_id FROM contenido) c
      LEFT JOIN contenido es ON es.catalog_id = c.catalog_id AND es.language_code = 'es-AR'
      LEFT JOIN contenido en ON en.catalog_id = c.catalog_id AND en.language_code = 'en'
     WHERE en.filas > 0
),
objetivo AS (
    SELECT p.catalog_id
      FROM preferido p
     WHERE p.lang = 'es-AR'
)
INSERT INTO os_catalog_language
       (catalog_id, language_code, is_default, is_fallback, is_bridge, coverage_status)
SELECT o.catalog_id, 'es-AR', TRUE, FALSE, FALSE, 'undetermined'
  FROM objetivo o
ON CONFLICT (catalog_id, language_code) DO UPDATE
   SET is_default  = EXCLUDED.is_default,
       is_fallback = EXCLUDED.is_fallback;

WITH contenido AS (
    SELECT i.catalog_id, v.language_code, count(*) AS filas
      FROM os_catalog_item i
      JOIN os_catalog_item_version v ON v.item_id = i.id
      JOIN os_language idi ON idi.code = v.language_code
     WHERE v.language_code IS NOT NULL
       AND idi.is_active
       AND NOT idi.is_source_only
     GROUP BY i.catalog_id, v.language_code
),
preferido AS (
    SELECT c.catalog_id,
           CASE WHEN COALESCE(es.filas, 0) >= COALESCE(en.filas, 0)
                THEN 'es-AR' ELSE 'en' END AS lang
      FROM (SELECT DISTINCT catalog_id FROM contenido) c
      LEFT JOIN contenido es ON es.catalog_id = c.catalog_id AND es.language_code = 'es-AR'
      LEFT JOIN contenido en ON en.catalog_id = c.catalog_id AND en.language_code = 'en'
     WHERE en.filas > 0
),
objetivo AS (
    SELECT p.catalog_id
      FROM preferido p
     WHERE p.lang = 'es-AR'
)
INSERT INTO os_catalog_language
       (catalog_id, language_code, is_default, is_fallback, is_bridge, coverage_status)
SELECT o.catalog_id, 'en', FALSE, TRUE, FALSE, 'undetermined'
  FROM objetivo o
ON CONFLICT (catalog_id, language_code) DO UPDATE
   SET is_default  = EXCLUDED.is_default,
       is_fallback = EXCLUDED.is_fallback;

COMMIT;

SELECT '=== Fase 3 · default/fallback tras la corrección ===' AS seccion;
SELECT c.code, l.language_code, l.is_default, l.is_fallback
  FROM os_catalog c
  JOIN os_catalog_language l ON l.catalog_id = c.id
 WHERE c.code IN ('dentar-an', 'dentar-cl', 'dentar-pr', 'dentar-dx')
 ORDER BY c.code, l.is_default DESC, l.is_fallback DESC;

-- Fin del correctivo de Fase 3.
