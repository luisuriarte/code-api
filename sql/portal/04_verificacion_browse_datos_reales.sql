-- =============================================================================
-- PORTAL med.origen.ar · verificación read-only de Browse Codes con datos reales
-- =============================================================================
-- Ejecutar en el VPS como postgres:
--   sudo -u postgres psql -d origen_codes -f sql/portal/04_verificacion_browse_datos_reales.sql
--
-- Solo SELECT. No modifica esquema ni datos. Sirve para comprobar que el
-- explorador tiene fuentes reales detrás de facetas, relaciones, result_key
-- y valores arancelarios. Si una tabla no existe, esa consulta dará error:
-- significa que no se aplicó el SQL de origen correspondiente.
-- =============================================================================

\echo '== 1. Permisos del rol origen_med =='
SELECT tablename,
       to_regclass('public.' || tablename) IS NOT NULL AS existe,
       CASE WHEN to_regclass('public.' || tablename) IS NULL THEN NULL
            ELSE has_table_privilege('origen_med', 'public.' || tablename, 'SELECT')
       END AS puede_leer
  FROM (VALUES
      ('os_catalog'), ('os_catalog_release'), ('os_catalog_category'),
      ('os_catalog_item'), ('os_catalog_item_version'), ('os_catalog_term'),
      ('os_catalog_identifier'), ('os_language'), ('os_catalog_language'),
      ('os_field_review'), ('os_concept_mapping'), ('os_terminology_system'),
      ('os_fee_item'), ('os_fee_schedule'), ('os_pricing_unit')
  ) AS v(tablename)
 ORDER BY tablename;

\echo '== 2. Extensión pg_trgm (necesaria para búsqueda parcial) =='
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_trgm';

\echo '== 3. Facetas reales que debe mostrar el formulario =='
SELECT 'families' AS facet, count(DISTINCT family_code) AS opciones
  FROM public.os_catalog
 WHERE is_active = TRUE AND family_code IS NOT NULL
UNION ALL
SELECT 'types', count(DISTINCT domain_type)
  FROM public.os_catalog
 WHERE is_active = TRUE AND domain_type IS NOT NULL
UNION ALL
SELECT 'categories', count(DISTINCT c.code)
  FROM public.os_catalog_category c
  JOIN public.os_catalog cat ON cat.id = c.catalog_id
 WHERE cat.is_active = TRUE
UNION ALL
SELECT 'versions', count(DISTINCT r.version_tag)
  FROM public.os_catalog_release r
  JOIN public.os_catalog cat ON cat.id = r.catalog_id
 WHERE cat.is_active = TRUE AND r.status = 'published'
UNION ALL
SELECT 'statuses', count(DISTINCT i.status)
  FROM public.os_catalog_item i
 WHERE i.status IS NOT NULL
 ORDER BY facet;

\echo '== 4. Detalle de facetas =='
SELECT coalesce(family_code, '(sin family)') AS family_code,
       domain_type, count(*) AS catalogos
  FROM public.os_catalog
 WHERE is_active = TRUE
 GROUP BY family_code, domain_type
 ORDER BY family_code, domain_type;

SELECT status, count(*) AS items
  FROM public.os_catalog_item
 WHERE status IS NOT NULL
 GROUP BY status
 ORDER BY status;

SELECT r.version_tag, count(*) AS releases
  FROM public.os_catalog_release r
  JOIN public.os_catalog cat ON cat.id = r.catalog_id
 WHERE cat.is_active = TRUE AND r.status = 'published'
 GROUP BY r.version_tag
 ORDER BY r.version_tag DESC;

\echo '== 5. Conteo de relaciones por ítem (debe coincidir con el badge) =='
SELECT m.item_id, count(*) AS relaciones
  FROM public.os_concept_mapping m
 GROUP BY m.item_id
HAVING count(*) > 0
 ORDER BY relaciones DESC, m.item_id
 LIMIT 20;

\echo '== 6. Candidatos a result_key (solo coincidencia única y mismo sistema) =='
SELECT m.item_id,
       sys.code AS system_code,
       m.external_code,
       linked.matches AS linked_matches,
       linked.item_id AS linked_item,
       linked.catalog_code,
       linked.domain_type,
       CASE
           WHEN linked.matches = 1
                AND linked.catalog_code IS NOT NULL
                AND linked.item_id IS NOT NULL
                AND linked.domain_type IN (
                    'dental', 'biochemical', 'medical',
                    'mental_health', 'rehabilitation', 'pharma'
                )
           THEN (CASE linked.domain_type
                    WHEN 'dental' THEN 'odontologia'
                    WHEN 'biochemical' THEN 'laboratorio'
                    WHEN 'medical' THEN 'prestaciones'
                    WHEN 'mental_health' THEN 'prestaciones'
                    WHEN 'rehabilitation' THEN 'programas'
                    WHEN 'pharma' THEN 'vademecum'
                 END) || ':os_catalog:' || linked.catalog_code || ':' || linked.item_id
           ELSE ''
       END AS result_key_app
  FROM public.os_concept_mapping m
  JOIN public.os_terminology_system sys ON sys.id = m.terminology_system_id
  LEFT JOIN LATERAL (
      SELECT count(*) AS matches,
             min(li.item_id) AS item_id,
             min(lcat.code) AS catalog_code,
             min(lcat.domain_type) AS domain_type
        FROM public.os_catalog_identifier li
        JOIN public.os_catalog_item litem ON litem.id = li.item_id
        JOIN public.os_catalog lcat ON lcat.id = litem.catalog_id
       WHERE li.value = m.external_code
         AND li.system_name = sys.code
         AND lcat.is_active = TRUE
  ) linked ON TRUE
 ORDER BY linked.matches DESC, m.item_id
 LIMIT 20;

\echo '== 7. Valores arancelarios (pestaña Valores) =='
SELECT fi.item_id,
       f.name AS schedule,
       f.currency,
       f.valid_from,
       f.valid_to,
       p.code AS unit_code,
       fi.units_amount,
       fi.fixed_price,
       fi.expenses_amount,
       f.unit_monetary_value
  FROM public.os_fee_item fi
  JOIN public.os_fee_schedule f ON f.id = fi.fee_schedule_id
  LEFT JOIN public.os_pricing_unit p ON p.id = fi.pricing_unit_id
 ORDER BY f.valid_from DESC NULLS LAST, f.id DESC
 LIMIT 20;

\echo '== 8. Catálogos DENTAR presentes =='
SELECT code, name, short_name, domain_type, family_code, is_active
  FROM public.os_catalog
 WHERE code IN ('dentar-pr', 'dentar-dx')
 ORDER BY code;
