-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud
-- sql/03_oftar/grant_oftar_search_api.sql
-- =============================================================================
--
-- MOTIVO
--   /v1/domains responde 200 pero /v1/search?domains=oftar responde 500.
--   La API se conecta con `origen_api` (api/config/database.php, DB_USER) y
--   `oftar_domain_search.sql` solo concedía SELECT a origen_admin y origen_med.
--
-- QUÉ HACE
--   REVOKE por objeto + GRANT SELECT puntual a origen_api sobre la vista de
--   búsqueda OFTAR. No crea objetos nuevos, no toca tablas base, no modifica
--   datos y no ejecuta ALTER DEFAULT PRIVILEGES.
--   Idempotente: se puede ejecutar las veces que haga falta.
-- =============================================================================

BEGIN;

DO $$
BEGIN
    IF to_regclass('public.v_oftar_search_catalog') IS NULL THEN
        RAISE EXCEPTION 'Falta public.v_oftar_search_catalog: aplicar oftar_domain_search.sql.';
    END IF;
    IF to_regrole('origen_api') IS NULL THEN
        RAISE EXCEPTION 'No existe el rol origen_api.';
    END IF;
END $$;

REVOKE ALL PRIVILEGES ON TABLE public.v_oftar_search_catalog FROM PUBLIC;

DO $$
BEGIN
    EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.v_oftar_search_catalog FROM origen_api';
    EXECUTE 'GRANT SELECT ON TABLE public.v_oftar_search_catalog TO origen_api';
END $$;

SELECT has_table_privilege('origen_api', 'public.v_oftar_search_catalog', 'SELECT') AS api_puede_leer;

COMMIT;
