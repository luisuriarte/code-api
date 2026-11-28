-- =============================================================================
-- SOLO LECTURA · Origen Salud · Familia OFTAR
-- sql/03_oftar/verificacion_visibilidad_catalogos_oftar.sql
-- =============================================================================
--
-- Diagnostica por qué no aparecen `nomenclador-oftalmologico-cao-ar` ni
-- `nomenclador-oftalmologico-regional-ar` en la API ni en Browse Codes, y por
-- qué no hay relaciones OFT-PR ↔ nomencladores.
--
-- EJECUCIÓN EN EL VPS:
--   cd /var/www/html/origen.ar/code-api
--   sudo -u postgres psql -X -v ON_ERROR_STOP=1 -P pager=off -d origen_codes \
--     -f sql/03_oftar/verificacion_visibilidad_catalogos_oftar.sql \
--     2>&1 | tee /tmp/visibilidad_catalogos_oftar.log
--
-- No modifica datos. PostgreSQL 18.
-- =============================================================================

BEGIN READ ONLY;

SET LOCAL client_encoding = 'UTF8';

\echo '=== 1. Catálogos OFTAR en os_catalog (esperado: 4 filas activas) ==='
SELECT c.code,
       c.short_name,
       c.family_code,
       c.product_role,
       c.domain_type,
       c.is_active,
       (SELECT count(*) FROM public.os_catalog_item i
         WHERE i.catalog_id = c.id AND i.status = 'active') AS items_active
  FROM public.os_catalog c
 WHERE c.code IN ('oftar-pr', 'oftar-dx',
                  'nomenclador-oftalmologico-cao-ar',
                  'nomenclador-oftalmologico-regional-ar')
 ORDER BY c.code;

\echo '=== 2. Releases (esperado: NOM-CAO-AR-v1 y NOM-OFTAL-REG-v1 published) ==='
SELECT c.code AS catalogo, r.version_tag, r.status, r.valid_from
  FROM public.os_catalog_release r
  JOIN public.os_catalog c ON c.id = r.catalog_id
 WHERE c.code IN ('nomenclador-oftalmologico-cao-ar',
                  'nomenclador-oftalmologico-regional-ar')
 ORDER BY 1, 2;

\echo '=== 3. Versiones por estado (sin aprobación no hay ítems visibles) ==='
SELECT c.code AS catalogo, v.review_status, count(*) AS versiones
  FROM public.os_catalog c
  JOIN public.os_catalog_item i ON i.catalog_id = c.id
  JOIN public.os_catalog_item_version v ON v.item_id = i.id
 WHERE c.code IN ('nomenclador-oftalmologico-cao-ar',
                  'nomenclador-oftalmologico-regional-ar')
 GROUP BY 1, 2 ORDER BY 1, 2;

\echo '=== 4. Revisión de preferred_term (requiere aprobación por campo) ==='
SELECT c.code AS catalogo, f.review_status, count(*) AS campos
  FROM public.os_field_review f
  JOIN public.os_catalog_item_version v ON v.id = f.target_id
  JOIN public.os_catalog_item i ON i.id = v.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id
 WHERE f.target_table = 'os_catalog_item_version'
   AND f.field_name = 'preferred_term'
   AND c.code IN ('nomenclador-oftalmologico-cao-ar',
                  'nomenclador-oftalmologico-regional-ar')
 GROUP BY 1, 2 ORDER BY 1, 2;

\echo '=== 5. Vista de búsqueda OFTAR (esperado: 4 catálogos con filas) ==='
SELECT catalogo, count(*) AS items
  FROM public.v_oftar_search_catalog
 GROUP BY 1 ORDER BY 1;

\echo '=== 6. Pares nomenclador → OFT-PR por estado ==='
SELECT source_catalog_code, review_status, count(*) AS pares
  FROM public.os_oftar_nomenclador_match
 GROUP BY 1, 2 ORDER BY 1, 2;

\echo '=== 7. H-02: target_code no resuelve a permanent_code de oftar-pr ==='
SELECT m.source_catalog_code,
       count(*) FILTER (WHERE i.id IS NULL) AS target_no_resuelve,
       count(*) FILTER (WHERE i.id IS NOT NULL) AS target_resuelve
  FROM public.os_oftar_nomenclador_match m
  LEFT JOIN public.os_catalog tc ON tc.code = m.target_catalog_code
  LEFT JOIN public.os_catalog_item i
         ON i.catalog_id = tc.id AND i.permanent_code = m.target_code
 GROUP BY 1 ORDER BY 1;

\echo '=== 8. Relaciones entre oftar-pr y nomencladores (ambos sentidos) ==='
SELECT sc.code AS catalogo_origen,
       tc.code AS catalogo_destino,
       r.relation_type,
       r.review_status,
       count(*) AS relaciones
  FROM public.os_catalog_relation r
  JOIN public.os_catalog_item si ON si.id = r.source_item_id
  JOIN public.os_catalog_item ti ON ti.id = r.target_item_id
  JOIN public.os_catalog sc ON sc.id = si.catalog_id
  JOIN public.os_catalog tc ON tc.id = ti.catalog_id
 WHERE sc.code LIKE 'nomenclador-oftalmologico%'
    OR tc.code LIKE 'nomenclador-oftalmologico%'
 GROUP BY 1, 2, 3, 4 ORDER BY 1, 2, 3, 4;

\echo '=== 9. Mapeos terminológicos publicados de los nomencladores ==='
SELECT s.code AS sistema, m.review_status, count(*) AS mapeos
  FROM public.os_concept_mapping m
  JOIN public.os_terminology_system s ON s.id = m.terminology_system_id
 WHERE s.code IN ('NOMENCLADOR-CAO-AR', 'NOMENCLADOR-OFTAL-REG-AR')
 GROUP BY 1, 2 ORDER BY 1, 2;

\echo '=== 10. Privilegios sobre v_oftar_search_catalog ==='
SELECT grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_name = 'v_oftar_search_catalog'
 ORDER BY 1, 2;

\echo '=== 11. Pares aprobados y resolución por identificador NOMENCLADOR-AR ==='
SELECT m.source_catalog_code,
       m.source_code,
       m.target_catalog_code,
       m.target_code,
       i.permanent_code AS permanent_resuelto,
       ident.value AS identificador_nomenclador
  FROM public.os_oftar_nomenclador_match m
  LEFT JOIN public.os_catalog tc ON tc.code = m.target_catalog_code
  LEFT JOIN public.os_catalog_item i
         ON i.catalog_id = tc.id AND i.permanent_code = m.target_code
  LEFT JOIN public.os_catalog_identifier ident
         ON ident.item_id = i.id
        AND ident.system_name = 'NOMENCLADOR-AR'
        AND ident.value = m.target_code
 WHERE m.review_status = 'approved'
 ORDER BY 1, 2;

\echo '=== 12. Destino alternativo: item de oftar-pr por identificador ==='
SELECT m.source_code,
       m.target_code,
       ident.value AS valor_identificador,
       i.permanent_code AS permanent_resuelto
  FROM public.os_oftar_nomenclador_match m
  JOIN public.os_catalog tc ON tc.code = m.target_catalog_code
  JOIN public.os_catalog_identifier ident
         ON ident.system_name = 'NOMENCLADOR-AR'
        AND ident.value = m.target_code
  JOIN public.os_catalog_item i
         ON i.id = ident.item_id AND i.catalog_id = tc.id
 WHERE m.review_status = 'approved'
 ORDER BY 1;

ROLLBACK;
