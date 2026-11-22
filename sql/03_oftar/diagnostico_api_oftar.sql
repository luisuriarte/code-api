-- =============================================================================
-- Diagnóstico de solo lectura del error 500 de /v1/search?domains=oftar
-- sql/03_oftar/diagnostico_api_oftar.sql
-- =============================================================================

BEGIN READ ONLY;

SET client_encoding = 'UTF8';

\echo '=== 1. Rol de la conexión actual ==='
SELECT current_user, session_user, current_database();

\echo '=== 2. Roles y pertenencia ==='
SELECT r.rolname,
       r.rolsuper,
       r.rolinherit,
       (SELECT string_agg(g.rolname, ', ' ORDER BY g.rolname)
          FROM pg_auth_members m
          JOIN pg_roles g ON g.oid = m.roleid
         WHERE m.member = r.oid) AS member_of
  FROM pg_roles r
 WHERE r.rolname IN ('origen_api', 'origen_admin', 'origen_med', 'postgres')
 ORDER BY r.rolname;

\echo '=== 3. Existencia y privilegios de la vista OFTAR ==='
SELECT to_regclass('public.v_oftar_search_catalog') AS vista,
       has_table_privilege('origen_api', 'public.v_oftar_search_catalog', 'SELECT') AS api_select,
       has_table_privilege('origen_admin', 'public.v_oftar_search_catalog', 'SELECT') AS admin_select,
       has_table_privilege('origen_med', 'public.v_oftar_search_catalog', 'SELECT') AS med_select;

\echo '=== 4. La vista devuelve filas (ejecutado como postgres) ==='
SELECT catalogo, count(*) AS filas
  FROM public.v_oftar_search_catalog
 GROUP BY catalogo
 ORDER BY catalogo;

\echo '=== 5. Como origen_api (si el rol existe) ==='
DO $$
DECLARE
    v_num BIGINT;
BEGIN
    IF to_regrole('origen_api') IS NOT NULL THEN
        EXECUTE 'SELECT count(*) FROM public.v_oftar_search_catalog' INTO v_num;
        RAISE NOTICE 'origen_api puede ejecutar el SELECT sobre la vista: % filas.', v_num;
    END IF;
END $$;

\echo '=== 6. Columnas de la vista ==='
SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'v_oftar_search_catalog'
 ORDER BY ordinal_position;

ROLLBACK;
