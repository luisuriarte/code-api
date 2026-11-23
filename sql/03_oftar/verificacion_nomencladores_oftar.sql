-- =============================================================================
-- SOLO LECTURA · Origen Salud · Familia OFTAR
-- sql/03_oftar/verificacion_nomencladores_oftar.sql
-- =============================================================================
--
-- EJECUCIÓN EN EL VPS (el rol `root` no existe en PostgreSQL):
--   cd /var/www/html/origen.ar/code-api
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 \
--     -f sql/03_oftar/verificacion_nomencladores_oftar.sql
--
-- Verificación posterior a:
--   1) nomencladores_oftar_mapping.sql
--   2) nomenclador_oftalmologico_cao.sql
--   3) nomenclador_oftalmologico_regional.sql
--   4) aprobar_mapeo_nomencladores_oftar.sql (opcional, tras revisión)
--
-- No modifica datos. PostgreSQL 18.
-- =============================================================================
BEGIN READ ONLY;

\echo '=== 1. Catálogos de origen registrados ==='
SELECT code, short_name, family_code, product_role, domain_type, is_active
  FROM public.os_catalog
 WHERE code IN ('nomenclador-oftalmologico-cao-ar', 'nomenclador-oftalmologico-regional-ar')
 ORDER BY code;

\echo '=== 2. Ítems por catálogo (esperado: CAO 143 / Regional 136) ==='
SELECT c.code AS catalogo, count(i.id) AS items
  FROM public.os_catalog c
  LEFT JOIN public.os_catalog_item i ON i.catalog_id = c.id
 WHERE c.code IN ('nomenclador-oftalmologico-cao-ar', 'nomenclador-oftalmologico-regional-ar')
 GROUP BY c.code ORDER BY c.code;

\echo '=== 3. Espejos sin columnas de precio (no debe devolver filas) ==='
SELECT table_name, column_name
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name IN ('os_source_oftar_cao', 'os_source_oftar_regional')
   AND column_name IN ('valor', 'honorario_medico', 'gasto', 'valor_total')
 ORDER BY table_name, column_name;

\echo '=== 4. Textos y definiciones (definition debe seguir en 0) ==='
SELECT c.code AS catalogo,
       count(*) FILTER (WHERE iv.review_status = 'approved') AS textos_aprobados,
       count(*) FILTER (WHERE iv.review_status = 'unknown') AS textos_pendientes,
       count(iv.definition) AS con_definicion
  FROM public.os_catalog c
  JOIN public.os_catalog_item i ON i.catalog_id = c.id
  JOIN public.os_catalog_item_version iv ON iv.item_id = i.id
 WHERE c.code IN ('nomenclador-oftalmologico-cao-ar', 'nomenclador-oftalmologico-regional-ar')
 GROUP BY c.code ORDER BY c.code;

\echo '=== 5. Estado del mapeo gobernado ==='
-- Antes de la revisión: 91 proposed en CAO y 0 en Regional.
SELECT source_catalog_code, review_status, count(*) AS pares
  FROM public.os_oftar_nomenclador_match
 GROUP BY 1, 2 ORDER BY 1, 2;

\echo '=== 6. Enlaces publicados solo si hay pares aprobados ==='
SELECT source_system_code, count(*) AS relaciones
  FROM public.os_catalog_relation
 WHERE source_system_code IN ('NOMENCLADOR-CAO-AR', 'NOMENCLADOR-OFTAL-REG-AR')
 GROUP BY 1 ORDER BY 1;

\echo '=== 7. Los nuevos catálogos no tienen UVR ==='
SELECT catalog_code, count(*) AS prestaciones_uvr
  FROM public.v_os_uvr_prestacion_public
 WHERE catalog_code IN ('nomenclador-oftalmologico-cao-ar', 'nomenclador-oftalmologico-regional-ar')
 GROUP BY 1;

\echo '=== 8. Los tres nomencladores conviven en la búsqueda de oftar ==='
SELECT catalogo, count(*) AS items
  FROM public.v_oftar_search_catalog
 GROUP BY catalogo ORDER BY catalogo;

ROLLBACK;
