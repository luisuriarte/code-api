-- =============================================================================
-- Comparación de solo lectura de esquemas de administración
-- sql/03_oftar/comparar_bases_admin.sql
-- =============================================================================
-- Ejecutar en AMBAS bases y comparar la salida:
--   sudo -u postgres psql -d origen_salud -f sql/03_oftar/comparar_bases_admin.sql
--   sudo -u postgres psql -d origen_codes -f sql/03_oftar/comparar_bases_admin.sql
-- =============================================================================
BEGIN READ ONLY;

SET client_encoding = 'UTF8';

\echo '=== os_admin: conteos ==='
DO $$
DECLARE
    v_reg RECORD;
    v_filas BIGINT;
BEGIN
    FOR v_reg IN
        SELECT schemaname, tablename
          FROM pg_tables
         WHERE schemaname = 'os_admin'
         ORDER BY tablename
    LOOP
        EXECUTE format('SELECT count(*) FROM %I.%I', v_reg.schemaname, v_reg.tablename)
           INTO v_filas;
        RAISE NOTICE '% | %', rpad(v_reg.tablename, 26), v_filas;
    END LOOP;

    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'os_admin') THEN
        RAISE NOTICE 'os_admin | SIN_ESQUEMA';
    END IF;
END $$;

\echo '=== public: tablas relevantes para el portal ==='
DO $$
DECLARE
    v_tabla TEXT;
    v_filas BIGINT;
BEGIN
    FOREACH v_tabla IN ARRAY ARRAY[
        'os_catalog_release',
        'os_catalog_language',
        'os_catalog_category',
        'os_catalog_identifier',
        'os_catalog_item_version',
        'os_localized_text',
        'os_fee_schedule',
        'os_fee_item',
        'os_pricing_unit',
        'os_release_audit',
        'os_translation_review',
        'api_clients'
    ]
    LOOP
        IF to_regclass('public.' || v_tabla) IS NULL THEN
            RAISE NOTICE '% | SIN_TABLA', rpad(v_tabla, 28);
        ELSE
            EXECUTE format('SELECT count(*) FROM public.%I', v_tabla) INTO v_filas;
            RAISE NOTICE '% | %', rpad(v_tabla, 28), v_filas;
        END IF;
    END LOOP;
END $$;

ROLLBACK;
