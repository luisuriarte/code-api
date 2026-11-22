-- =============================================================================
-- Verificación de solo lectura de la carga OFTAR-PR y del ejemplo OCT
-- sql/03_oftar/verificacion_oftar_pr_carga.sql
-- =============================================================================
-- Ejecutar después de:
--   importar_nomenclador_oftar_pr.sql
--   uvr_ejemplo_oct_oftar_pr_u7b.sql  (o su variante legacy)
-- No modifica datos. Todo lo que informa debe interpretarse antes de ROLLBACK.
-- =============================================================================

BEGIN READ ONLY;

SET client_encoding = 'UTF8';

\echo '=== 1. Cobertura de oftar-pr ==='
SELECT count(*) AS items_oftar_pr,
       count(*) FILTER (WHERE iv.review_status = 'approved') AS textos_aprobados,
       count(*) FILTER (WHERE iv.definition IS NOT NULL) AS textos_con_definicion,
       count(*) FILTER (WHERE ident.value IS NOT NULL) AS con_codigo_nomenclador
  FROM public.os_catalog_item i
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-pr'
  LEFT JOIN public.os_catalog_item_version iv
         ON iv.item_id = i.id AND iv.language_code = 'es-AR'
  LEFT JOIN public.os_catalog_identifier ident
         ON ident.item_id = i.id AND ident.system_name = 'NOMENCLADOR-AR';

\echo '=== 2. Lateralidad como atributo ==='
SELECT sa.attribute_value, count(*) AS items
  FROM public.os_catalog_source_attribute sa
  JOIN public.os_catalog_item i ON i.id = sa.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-pr'
 WHERE sa.source_catalog_code = 'oftar'
   AND sa.attribute_code = 'ATTR-LATERALITY'
 GROUP BY sa.attribute_value
 ORDER BY sa.attribute_value;

\echo '=== 3. Categorías internas usadas ==='
SELECT occ.code AS categoria, count(*) AS items
  FROM public.os_catalog_item_version iv
  JOIN public.os_catalog_item i ON i.id = iv.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-pr'
  JOIN public.os_catalog_category occ ON occ.id = iv.category_id
 GROUP BY occ.code
 ORDER BY occ.code;

\echo '=== 4. Ejemplo OCT 305111 = 33,00 UVR (modelo U7-B) ==='
SELECT catalog_code, prestacion_code, external_code,
       work_uvr, practice_expense_uvr, professional_liability_uvr,
       total_uvr, currency, importe_referencial
  FROM public.v_os_uvr_prestacion_public
 WHERE prestacion_code = 'OCT-305111';

\echo '=== 5. oftar-dx NO debe figurar en valoraciones UVR ==='
SELECT 'v_os_uvr_prestacion_public' AS vista, count(*) AS filas_oftar_dx
  FROM public.v_os_uvr_prestacion_public WHERE catalog_code = 'oftar-dx'
UNION ALL
SELECT 'v_os_uvr_valuation_public', count(*)
  FROM public.v_os_uvr_valuation_public v
  JOIN public.os_catalog_item i ON i.id = v.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id
 WHERE c.code = 'oftar-dx';

\echo '=== 6. Sin categorías OFTAR prohibidas ==='
SELECT code
  FROM public.os_catalog
 WHERE code IN ('OFTAR-CIR', 'OFTAR-IMG', 'OFTAR-TER', 'OFTAR-MED')
 ORDER BY code;

ROLLBACK;
