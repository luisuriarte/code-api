-- =============================================================================
-- Diagnóstico de solo lectura: por qué Browse Codes no muestra UVR
-- =============================================================================
-- Ejecutar en el VPS como postgres:
--   sudo -u postgres psql -d origen_codes -f \
--     sql/08_arquitectura/diagnostico_uvr_browse.sql
--
-- NO modifica datos, NO crea ni reemplaza objetos. Todas las consultas van
-- dentro de BEGIN READ ONLY / ROLLBACK. Las vistas ausentes se informan con
-- NOTICE en lugar de abortar el script.
-- =============================================================================

BEGIN READ ONLY;

\echo '=== 1. Vistas públicas y permisos del rol del portal ==='
SELECT 'v_os_uvr_prestacion_public' AS objeto,
       to_regclass('public.v_os_uvr_prestacion_public') IS NOT NULL AS existe,
       CASE WHEN to_regclass('public.v_os_uvr_prestacion_public') IS NULL THEN NULL
            ELSE has_table_privilege('origen_med', 'public.v_os_uvr_prestacion_public', 'SELECT')
       END AS puede_leer
UNION ALL
SELECT 'v_os_uvr_valuation_public',
       to_regclass('public.v_os_uvr_valuation_public') IS NOT NULL,
       CASE WHEN to_regclass('public.v_os_uvr_valuation_public') IS NULL THEN NULL
            ELSE has_table_privilege('origen_med', 'public.v_os_uvr_valuation_public', 'SELECT')
       END;

\echo '=== 2. Valoración legacy de la propuesta 8 (o del código DNT-PR-000001) ==='
SELECT v.id,
       v.service_item_id,
       i.permanent_code,
       c.code AS catalog_code,
       c.is_active AS catalogo_activo,
       v.review_status,
       v.published_at,
       v.version_tag,
       v.source_reference
  FROM public.os_uvr_valuation v
  LEFT JOIN public.os_catalog_item i ON i.id = v.service_item_id
  LEFT JOIN public.os_catalog c ON c.id = i.catalog_id
 WHERE v.id = 8
    OR i.permanent_code = 'DNT-PR-000001'
 ORDER BY v.id;

\echo '=== 3. Componentes derivados (total_uvr se calcula, nunca se guarda) ==='
SELECT v.id AS valuation_id,
       v.review_status,
       COALESCE(cw.value, 0) AS work_uvr,
       COALESCE(cp.value, 0) AS practice_expense_uvr,
       COALESCE(cl.value, 0) AS professional_liability_uvr,
       COALESCE(cw.value, 0) + COALESCE(cp.value, 0) + COALESCE(cl.value, 0) AS total_uvr
  FROM public.os_uvr_valuation v
  LEFT JOIN public.os_uvr_component cw
    ON cw.valuation_id = v.id AND cw.component_type = 'work'
  LEFT JOIN public.os_uvr_component cp
    ON cp.valuation_id = v.id AND cp.component_type = 'practice_expense'
  LEFT JOIN public.os_uvr_component cl
    ON cl.valuation_id = v.id AND cl.component_type = 'professional_liability'
 WHERE v.id = 8
 ORDER BY v.id;

\echo '=== 4. Vista legacy pública: filas que debería ver Browse ==='
DO $$
DECLARE
    r record;
BEGIN
    IF to_regclass('public.v_os_uvr_valuation_public') IS NULL THEN
        RAISE NOTICE 'FALTA: public.v_os_uvr_valuation_public no existe en esta base.';
    ELSE
        FOR r IN
            SELECT valuation_id, catalog_code, external_code, item_id,
                   total_uvr, published_at
              FROM public.v_os_uvr_valuation_public
             WHERE external_code = 'DNT-PR-000001' OR valuation_id = 8
             ORDER BY published_at DESC NULLS LAST
        LOOP
            RAISE NOTICE 'legacy: id=% catalog=% code=% item=% total=% publicada=%',
                r.valuation_id, r.catalog_code, r.external_code,
                r.item_id, r.total_uvr, r.published_at;
        END LOOP;
    END IF;
END $$;

\echo '=== 5. Vista transversal pública: misma búsqueda por código ==='
DO $$
DECLARE
    r record;
BEGIN
    IF to_regclass('public.v_os_uvr_prestacion_public') IS NULL THEN
        RAISE NOTICE 'FALTA: public.v_os_uvr_prestacion_public no existe en esta base.';
    ELSE
        FOR r IN
            SELECT valuation_id, catalog_code, external_code, prestacion_code,
                   total_uvr, published_at
              FROM public.v_os_uvr_prestacion_public
             WHERE btrim(external_code) = 'DNT-PR-000001'
                OR btrim(prestacion_code) = 'DNT-PR-000001'
                OR valuation_id = 8
             ORDER BY published_at DESC NULLS LAST
        LOOP
            RAISE NOTICE 'transversal: id=% catalog=% code=% prestacion=% total=% publicada=%',
                r.valuation_id, r.catalog_code, r.external_code,
                r.prestacion_code, r.total_uvr, r.published_at;
        END LOOP;
    END IF;
END $$;

\echo '=== 6. Identificadores que Browse usa como códigos alternativos ==='
SELECT i.id AS item_id,
       i.permanent_code,
       c.code AS catalog_code,
       ident.system_name,
       ident.value
  FROM public.os_catalog_item i
  JOIN public.os_catalog c ON c.id = i.catalog_id
  LEFT JOIN public.os_catalog_identifier ident ON ident.item_id = i.id
 WHERE i.permanent_code = 'DNT-PR-000001'
 ORDER BY c.code, ident.system_name;

ROLLBACK;
