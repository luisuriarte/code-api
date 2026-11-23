-- =============================================================================
-- SOLO LECTURA · Origen Salud · Familia OFTAR
-- sql/03_oftar/verificacion_post_aprobacion_nomencladores_oftar.sql
-- =============================================================================
--
-- EJECUCIÓN EN EL VPS (el rol `root` no existe en PostgreSQL):
--   cd /var/www/html/origen.ar/code-api
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 \
--     -f sql/03_oftar/verificacion_post_aprobacion_nomencladores_oftar.sql
--
-- Verificación después de aprobar_mapeo_nomencladores_oftar.sql.
-- No modifica datos. PostgreSQL 18.
-- =============================================================================
BEGIN READ ONLY;

\echo '=== 1. Estado de las versiones (esperado: 143 y 136 en approved) ==='
SELECT c.code AS catalogo,
       iv.review_status,
       count(*) AS versiones
  FROM public.os_catalog c
  JOIN public.os_catalog_item i ON i.catalog_id = c.id
  JOIN public.os_catalog_item_version iv ON iv.item_id = i.id
 WHERE c.code IN ('nomenclador-oftalmologico-cao-ar',
                  'nomenclador-oftalmologico-regional-ar')
 GROUP BY 1, 2 ORDER BY 1, 2;

\echo '=== 2. Revisiones por campo (preferred_term approved; definition pendiente) ==='
SELECT c.code AS catalogo,
       f.field_name,
       f.review_status,
       count(*) AS campos
  FROM public.os_catalog c
  JOIN public.os_catalog_item i ON i.catalog_id = c.id
  JOIN public.os_catalog_item_version iv ON iv.item_id = i.id
  JOIN public.os_field_review f
         ON f.target_table = 'os_catalog_item_version'
        AND f.target_id = iv.id
 WHERE c.code IN ('nomenclador-oftalmologico-cao-ar',
                  'nomenclador-oftalmologico-regional-ar')
 GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;

\echo '=== 3. Definiciones (debe seguir en 0) ==='
SELECT c.code AS catalogo, count(iv.definition) AS con_definicion
  FROM public.os_catalog c
  JOIN public.os_catalog_item i ON i.catalog_id = c.id
  JOIN public.os_catalog_item_version iv ON iv.item_id = i.id
 WHERE c.code IN ('nomenclador-oftalmologico-cao-ar',
                  'nomenclador-oftalmologico-regional-ar')
 GROUP BY 1 ORDER BY 1;

\echo '=== 4. Búsqueda OFTAR (esperado: 4 catálogos) ==='
SELECT catalogo, count(*) AS items
  FROM public.v_oftar_search_catalog
 GROUP BY catalogo ORDER BY catalogo;

\echo '=== 5. Enlaces publicados (0 hasta aprobar pares del mapeo) ==='
SELECT source_system_code, count(*) AS relaciones
  FROM public.os_catalog_relation
 WHERE source_system_code IN ('NOMENCLADOR-CAO-AR', 'NOMENCLADOR-OFTAL-REG-AR')
 GROUP BY 1 ORDER BY 1;

\echo '=== 6. Mapeo gobernado (91 proposed en CAO, 0 en Regional) ==='
SELECT source_catalog_code, review_status, count(*) AS pares
  FROM public.os_oftar_nomenclador_match
 GROUP BY 1, 2 ORDER BY 1, 2;

ROLLBACK;
