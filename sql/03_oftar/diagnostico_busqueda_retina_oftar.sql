-- =============================================================================
-- SOLO LECTURA · Diagnóstico: búsqueda "retina" no devuelve catálogo Regional
-- sql/03_oftar/diagnostico_busqueda_retina_oftar.sql
-- =============================================================================
-- Ejecutar en el VPS:
--   cd /var/www/html/origen.ar/code-api
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 \
--     -f sql/03_oftar/diagnostico_busqueda_retina_oftar.sql
--
-- No modifica datos. Si preferís DBeaver, conectate a la DB `origen_codes`
-- y ejecutá cada SELECT por separado dentro de una transacción READ ONLY.
-- =============================================================================
BEGIN READ ONLY;

\echo '=== 1. Coincidencias en la vista que usa la API (/v1/search) ==='
SELECT catalogo,
       count(*) AS coincidencias
  FROM public.v_oftar_search_catalog
 WHERE termino ILIKE '%retina%'
    OR codigo ILIKE '%retina%'
    OR subtitulo ILIKE '%retina%'
 GROUP BY catalogo
 ORDER BY catalogo;

\echo '=== 2. Detalle de coincidencias (esperado: CAO 3 y Regional 13+) ==='
SELECT catalogo,
       codigo,
       left(termino, 90) AS termino,
       left(subtitulo, 60) AS subtitulo
  FROM public.v_oftar_search_catalog
 WHERE termino ILIKE '%retina%'
    OR codigo ILIKE '%retina%'
    OR subtitulo ILIKE '%retina%'
 ORDER BY catalogo, codigo;

\echo '=== 2b. Coincidencias por similitud de trigramas (lo que también suma la API) ==='
SELECT catalogo,
       count(*) AS coincidencias
  FROM public.v_oftar_search_catalog
 WHERE termino % 'retina'
 GROUP BY catalogo
 ORDER BY catalogo;

\echo '=== 3. Estado de catálogos y releases (ambos deben estar activos/publicados) ==='
SELECT c.code AS catalogo,
       c.is_active,
       c.family_code,
       c.domain_type,
       c.product_role,
       r.version_tag,
       r.status AS release_status,
       r.valid_from
  FROM public.os_catalog c
  LEFT JOIN public.os_catalog_release r ON r.catalog_id = c.id
 WHERE c.code IN ('nomenclador-oftalmologico-cao-ar',
                  'nomenclador-oftalmologico-regional-ar')
 ORDER BY c.code, r.id;

\echo '=== 4. Conteo por release/idioma/estado de revisión ==='
SELECT c.code AS catalogo,
       r.version_tag,
       iv.language_code,
       iv.review_status,
       count(*) AS versiones
  FROM public.os_catalog c
  JOIN public.os_catalog_item i ON i.catalog_id = c.id
  JOIN public.os_catalog_item_version iv ON iv.item_id = i.id
  JOIN public.os_catalog_release r ON r.id = iv.release_id
 WHERE c.code IN ('nomenclador-oftalmologico-cao-ar',
                  'nomenclador-oftalmologico-regional-ar')
 GROUP BY 1, 2, 3, 4
 ORDER BY 1, 2, 3, 4;

\echo '=== 5. Lo que ve el explorador del portal (JOIN por release publicado) ==='
SELECT c.code AS catalogo,
       count(*) AS items_visibles
  FROM public.os_catalog_item item
  JOIN public.os_catalog c ON c.id = item.catalog_id
  JOIN public.os_catalog_release rel ON rel.id = (
        SELECT r.id FROM public.os_catalog_release r
         WHERE r.catalog_id = c.id AND r.status = 'published'
         ORDER BY r.valid_from DESC, r.id DESC LIMIT 1
  )
  JOIN public.os_catalog_item_version ver ON ver.id = (
        SELECT v.id FROM public.os_catalog_item_version v
         WHERE v.item_id = item.id AND v.release_id = rel.id
         ORDER BY v.id DESC LIMIT 1
  )
 WHERE c.family_code = 'oftar'
   AND c.is_active = TRUE
   AND item.status = 'active'
   AND (ver.preferred_term ILIKE '%retina%' OR item.permanent_code ILIKE '%retina%')
 GROUP BY c.code
 ORDER BY c.code;

\echo '=== 6. Fuente literal (descartando problemas de importación) ==='
SELECT 'CAO' AS fuente, count(*) AS filas
  FROM public.os_source_oftar_cao WHERE descripcion ILIKE '%retina%'
UNION ALL
SELECT 'Regional', count(*)
  FROM public.os_source_oftar_regional WHERE descripcion ILIKE '%retina%';

ROLLBACK;
