-- =============================================================================
-- Origen Salud · Verificación de solo lectura de la estructura OFTAR
-- sql/03_oftar/verificacion_oftar.sql
-- =============================================================================
-- No modifica datos. Ejecutar después de oftar_family.sql y oftar_core.sql:
--   sudo -u postgres psql -d origen_codes -f sql/03_oftar/verificacion_oftar.sql
-- =============================================================================
BEGIN READ ONLY;

SET client_encoding = 'UTF8';

\echo '=== 1. Catálogos de la familia OFTAR y prefijos ==='
SELECT code AS catalogo,
       short_name,
       code_prefix AS prefijo,
       concept_kind AS tipo_concepto,
       status,
       code_prefix = CASE code
           WHEN 'oftar-pr' THEN 'OFTAR-PR'
           WHEN 'oftar-dx' THEN 'OFTAR-DX'
       END AS prefijo_correcto
  FROM public.oftar_catalog
 ORDER BY sort_order, code;

\echo '=== 2. Categorías por catálogo ==='
SELECT c.code AS catalogo,
       count(cat.id) AS categorias,
       count(cat.id) FILTER (WHERE cat.parent_id IS NULL) AS raices,
       count(cat.id) FILTER (WHERE cat.parent_id IS NOT NULL) AS subcategorias
  FROM public.oftar_catalog c
  LEFT JOIN public.oftar_category cat ON cat.catalog_id = c.id
 GROUP BY c.code
 ORDER BY c.code;

\echo '=== 3. Jerarquía interna esperada de OFTAR-PR ==='
SELECT cat.code,
       parent.code AS padre,
       cat.sort_order AS orden,
       max(cv.name) FILTER (WHERE cv.language = 'es-AR') AS nombre_es,
       max(cv.name) FILTER (WHERE cv.language = 'en') AS nombre_en
  FROM public.oftar_category cat
  JOIN public.oftar_catalog oc ON oc.id = cat.catalog_id AND oc.code = 'oftar-pr'
  LEFT JOIN public.oftar_category parent ON parent.id = cat.parent_id
  LEFT JOIN public.oftar_category_version cv
         ON cv.category_id = cat.id AND cv.version_number = 1
 GROUP BY cat.code, parent.code, cat.sort_order
 ORDER BY cat.sort_order, cat.code;

\echo '=== 4. Códigos internos requeridos en OFTAR-PR ==='
SELECT v.codigo,
       oc.id IS NOT NULL AND cat.id IS NOT NULL AS presente,
       cat.parent_id IS NOT NULL AS tiene_padre
  FROM (VALUES
      ('GRP-EVAL'), ('GRP-DIAG'), ('GRP-TER'), ('GRP-OCUL'),
      ('CONSULT'), ('EXAM'), ('DIAG'), ('IMG'),
      ('TER'), ('CIR'), ('OCUL'), ('LAGR')
  ) AS v(codigo)
  LEFT JOIN public.oftar_catalog oc ON oc.code = 'oftar-pr'
  LEFT JOIN public.oftar_category cat
         ON cat.catalog_id = oc.id AND cat.code = v.codigo
 ORDER BY v.codigo;

\echo '=== 5. Categoría propia de OFTAR-DX ==='
SELECT oc.code AS catalogo, cat.code, cv.language, cv.name
  FROM public.oftar_category cat
  JOIN public.oftar_catalog oc ON oc.id = cat.catalog_id AND oc.code = 'oftar-dx'
  JOIN public.oftar_category_version cv ON cv.category_id = cat.id
 ORDER BY cv.language;

\echo '=== 6. Registro canónico y cobertura de idiomas ==='
SELECT c.code AS catalogo,
       c.product_role,
       c.domain_type,
       c.family_code,
       c.is_active,
       string_agg(l.language_code, ', ' ORDER BY l.language_code) AS idiomas,
       count(*) FILTER (WHERE l.is_default) AS defaults,
       count(*) FILTER (WHERE l.is_fallback) AS fallbacks
  FROM public.os_catalog c
  LEFT JOIN public.os_catalog_language l ON l.catalog_id = c.id
 WHERE c.code IN ('oftar', 'oftar-pr', 'oftar-dx')
 GROUP BY c.code, c.product_role, c.domain_type, c.family_code, c.is_active
 ORDER BY c.code;

\echo '=== 7. Categorías proyectadas al motor canónico ==='
SELECT c.code AS catalogo,
       count(cc.id) AS categorias,
       count(cc.id) FILTER (WHERE cc.parent_category_id IS NOT NULL) AS con_padre
  FROM public.os_catalog c
  LEFT JOIN public.os_catalog_category cc ON cc.catalog_id = c.id
 WHERE c.code IN ('oftar-pr', 'oftar-dx')
 GROUP BY c.code
 ORDER BY c.code;

\echo '=== 8. Atributos estructurados y lateralidad ==='
SELECT a.code, a.data_type, a.name
  FROM public.oftar_attribute_definition a
 ORDER BY a.id;

SELECT v.value_code, v.label_es, v.label_en
  FROM public.oftar_attribute_value v
 WHERE v.attribute_code = 'ATTR-LATERALITY'
 ORDER BY v.sort_order;

\echo '=== 9. Reglas de mapeo por catálogo ==='
SELECT oc.code AS catalogo, r.system_code, r.is_required, r.is_allowed
  FROM public.oftar_catalog_mapping_rule r
  JOIN public.oftar_catalog oc ON oc.id = r.catalog_id
 ORDER BY oc.code, r.is_required DESC, r.system_code;

\echo '=== 10. El modelo editorial OFTAR no guarda UVR ==='
SELECT count(*) AS columnas_uvr_en_staging
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name IN ('oftar_concept_version', 'oftar_diagnosis_version')
   AND (column_name LIKE '%uvr%' OR column_name LIKE '%payment%');

\echo '=== 11. Validadores de prefijo ==='
SELECT tgname AS trigger_name, relname AS tabla
  FROM pg_trigger t
  JOIN pg_class c ON c.oid = t.tgrelid
 WHERE t.tgname IN ('trg_oftar_concept_code', 'trg_oftar_diagnosis_code')
   AND NOT t.tgisinternal
 ORDER BY tgname;

\echo '=== 12. Permisos del rol del portal ==='
SELECT table_name,
       has_table_privilege('origen_med', 'public.' || table_name, 'SELECT') AS puede_leer
  FROM information_schema.tables
 WHERE table_schema = 'public'
   AND table_name IN ('oftar_catalog', 'oftar_category', 'oftar_category_version',
                      'oftar_concept', 'oftar_concept_version',
                      'oftar_diagnosis', 'oftar_diagnosis_version',
                      'os_catalog_source_attribute', 'v_oftar_family_concept')
 ORDER BY table_name;

\echo '=== 13. Conteo final ==='
DO $$
DECLARE
    v_catalogos INT;
    v_categorias_pr INT;
    v_categorias_dx INT;
    v_idiomas INT;
    v_con_padre INT;
BEGIN
    SELECT count(*) INTO v_catalogos FROM public.oftar_catalog WHERE status = 'active';
    SELECT count(*) INTO v_categorias_pr
      FROM public.oftar_category cat
      JOIN public.oftar_catalog oc ON oc.id = cat.catalog_id AND oc.code = 'oftar-pr';
    SELECT count(*) INTO v_categorias_dx
      FROM public.oftar_category cat
      JOIN public.oftar_catalog oc ON oc.id = cat.catalog_id AND oc.code = 'oftar-dx';
    SELECT count(*) INTO v_idiomas
      FROM public.os_catalog_language l
      JOIN public.os_catalog c ON c.id = l.catalog_id AND c.code = 'oftar-pr';
    SELECT count(*) INTO v_con_padre
      FROM public.os_catalog_category cc
      JOIN public.os_catalog c ON c.id = cc.catalog_id AND c.code = 'oftar-pr'
     WHERE cc.parent_category_id IS NOT NULL;

    RAISE NOTICE 'oftar: catálogos=%; categorías PR=%; categorías DX=%; idiomas PR=%; jerarquía canónica=%',
        v_catalogos, v_categorias_pr, v_categorias_dx, v_idiomas, v_con_padre;

    IF v_catalogos <> 2 OR v_categorias_pr <> 12 OR v_categorias_dx <> 1
       OR v_idiomas <> 3 OR v_con_padre <> 8 THEN
        RAISE EXCEPTION 'La estructura OFTAR no coincide con lo esperado (2/12/1/3/8).';
    END IF;
END $$;

ROLLBACK;

-- Fin de verificacion_oftar.sql
