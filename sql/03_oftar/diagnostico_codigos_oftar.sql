-- =============================================================================
-- Diagnóstico de solo lectura: formato real de los códigos OFTAR
-- sql/03_oftar/diagnostico_codigos_oftar.sql
-- =============================================================================

BEGIN READ ONLY;

SET client_encoding = 'UTF8';

\echo '=== 1. os_catalog_item: prefijos y longitudes ==='
SELECT c.code AS catalogo,
       split_part(i.permanent_code, '-', 1) AS prefijo,
       length(i.permanent_code) AS largo,
       count(*) AS filas,
       min(i.permanent_code) AS ejemplo_min,
       max(i.permanent_code) AS ejemplo_max
  FROM public.os_catalog_item i
  JOIN public.os_catalog c ON c.id = i.catalog_id
 WHERE c.family_code = 'oftar'
    OR i.permanent_code LIKE 'OFTAR%'
 GROUP BY c.code, split_part(i.permanent_code, '-', 1), length(i.permanent_code)
 ORDER BY c.code, largo, prefijo;

\echo '=== 2. Ejemplos con bytes (para detectar guiones invisibles) ==='
SELECT i.id, c.code AS catalogo, i.permanent_code,
       length(i.permanent_code) AS largo,
       encode(convert_to(i.permanent_code, 'UTF8'), 'hex') AS hex
  FROM public.os_catalog_item i
  JOIN public.os_catalog c ON c.id = i.catalog_id
 WHERE i.permanent_code LIKE 'OFTAR%'
 ORDER BY i.id
 LIMIT 8;

\echo '=== 3. oftar_concept / oftar_diagnosis ==='
SELECT 'oftar_concept' AS tabla, code, length(code) AS largo,
       encode(convert_to(code, 'UTF8'), 'hex') AS hex
  FROM (SELECT code FROM public.oftar_concept ORDER BY code LIMIT 5) c
UNION ALL
SELECT 'oftar_diagnosis', code, length(code),
       encode(convert_to(code, 'UTF8'), 'hex')
  FROM (SELECT code FROM public.oftar_diagnosis ORDER BY code LIMIT 5) d
 ORDER BY 1, 2;

\echo '=== 4. Prefijos declarados ==='
SELECT code, code_prefix, short_name FROM public.oftar_catalog ORDER BY code;

\echo '=== 5. Vista y registro de dominio ==='
SELECT to_regclass('public.v_oftar_search_catalog') AS vista,
       (SELECT count(*) FROM public.os_domain_registry WHERE code = 'oftar') AS registro_oftar;

\echo '=== 6. Coincidencia de los patrones usados por el renombrado ==='
SELECT count(*) FILTER (WHERE permanent_code ~ '^OFTAR-PR-[0-9]{6}$') AS pr_6digitos,
       count(*) FILTER (WHERE permanent_code LIKE 'OFTAR-PR-%') AS pr_cualquiera,
       count(*) FILTER (WHERE permanent_code ~ '^OFTAR-DX-[0-9]{6}$') AS dx_6digitos,
       count(*) FILTER (WHERE permanent_code LIKE 'OFTAR-DX-%') AS dx_cualquiera
  FROM public.os_catalog_item;

ROLLBACK;
