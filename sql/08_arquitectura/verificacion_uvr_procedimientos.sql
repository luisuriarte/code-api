-- =============================================================================
-- Verificación SOLO LECTURA: ¿por qué no aparece UVR en procedimientos?
-- Ejecutar como sudo -u postgres psql -d origen_codes -f <este archivo>
-- No modifica datos: BEGIN READ ONLY + ROLLBACK.
-- =============================================================================

BEGIN READ ONLY;

-- 1) ¿Existen entidades U7 y hay filas publicadas en la vista pública?
SELECT 'os_prestacion' AS tabla, count(*) AS filas FROM public.os_prestacion
UNION ALL SELECT 'os_prestacion_codigo', count(*) FROM public.os_prestacion_codigo
UNION ALL SELECT 'os_uvr_profile', count(*) FROM public.os_uvr_profile
UNION ALL SELECT 'os_uvr_prestacion_valuation', count(*) FROM public.os_uvr_prestacion_valuation
UNION ALL SELECT 'os_uvr_prestacion_component', count(*) FROM public.os_uvr_prestacion_component
UNION ALL SELECT 'v_os_uvr_prestacion_public', count(*) FROM public.v_os_uvr_prestacion_public
ORDER BY tabla;

-- 2) ¿Cómo están vinculados los códigos? item_id vs external_code.
SELECT count(*) AS total,
       count(*) FILTER (WHERE item_id IS NOT NULL)                             AS con_item_id,
       count(*) FILTER (WHERE item_id IS NULL AND btrim(external_code) <> '') AS solo_external_code
  FROM public.os_prestacion_codigo;

-- 3) Detalle de vínculos y publicación.
SELECT p.code AS prestacion,
       p.is_valuable,
       p.status AS prestacion_status,
       pc.catalog_code,
       pc.item_id,
       pc.external_code,
       pc.review_status AS vinculo_status,
       c.is_active AS catalogo_activo,
       v.review_status AS valuation_status,
       v.published_at,
       v.total_uvr
  FROM public.os_prestacion p
  JOIN public.os_prestacion_codigo pc ON pc.prestacion_id = p.id
  LEFT JOIN public.os_catalog c ON c.code = pc.catalog_code
  LEFT JOIN public.os_uvr_prestacion_valuation v ON v.prestacion_id = p.id
 ORDER BY pc.catalog_code, pc.item_id, p.code
 LIMIT 50;

-- 4) Resolución por item_id (caso DENTAR / os_catalog).
--    Reemplazar 'dentar-pr' y 123 por el catalog_code y source_id de la ficha.
SELECT catalog_code, item_id, external_code, prestacion_code, profile_code, total_uvr
  FROM public.v_os_uvr_prestacion_public
 WHERE catalog_code = 'dentar-pr'
   AND item_id = 123
 LIMIT 5;

-- 5) Resolución por external_code (caso procedimientos SNOMED/CIE-10/nativo).
--    Reemplazar por el código visible en la ficha.
SELECT catalog_code, item_id, external_code, prestacion_code, profile_code, total_uvr
  FROM public.v_os_uvr_prestacion_public
 WHERE btrim(external_code) IN ('DNT-PR-000001', 'D0150', '58258-5')
 LIMIT 20;

-- 6) Legacy U0-U6: por si alguien publicó solo en la tabla antigua.
SELECT 'os_uvr_valuation' AS tabla, count(*) AS filas FROM public.os_uvr_valuation
UNION ALL SELECT 'os_uvr_component', count(*) FROM public.os_uvr_component
UNION ALL SELECT 'os_uvr_eligible_catalog', count(*) FROM public.os_uvr_eligible_catalog
ORDER BY tabla;

ROLLBACK;
