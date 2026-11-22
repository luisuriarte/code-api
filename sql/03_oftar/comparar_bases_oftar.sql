-- =============================================================================
-- Comparación de solo lectura entre origen_salud y origen_codes
-- sql/03_oftar/comparar_bases_oftar.sql
-- =============================================================================
-- Ejecutar en AMBAS bases y comparar la salida:
--   sudo -u postgres psql -d origen_salud  -f sql/03_oftar/comparar_bases_oftar.sql
--   sudo -u postgres psql -d origen_codes  -f sql/03_oftar/comparar_bases_oftar.sql
-- =============================================================================
BEGIN READ ONLY;

SET client_encoding = 'UTF8';

\echo '=== Conteos por tabla (SIN_TABLA = no existe en esta base) ==='
DO $$
DECLARE
    v_tabla TEXT;
    v_filas BIGINT;
BEGIN
    FOREACH v_tabla IN ARRAY ARRAY[
        'api_clients',
        'os_catalog',
        'os_catalog_item',
        'os_catalog_item_version',
        'os_field_review',
        'os_concept_mapping',
        'snomed_concepts',
        'snomed_descriptions',
        'cie10_codes',
        'cie10_descriptions',
        'oftar_diagnosis'
    ]
    LOOP
        IF to_regclass('public.' || v_tabla) IS NULL THEN
            RAISE NOTICE '% | SIN_TABLA', rpad(v_tabla, 26);
        ELSE
            EXECUTE format('SELECT count(*) FROM public.%I', v_tabla) INTO v_filas;
            RAISE NOTICE '% | %', rpad(v_tabla, 26), v_filas;
        END IF;
    END LOOP;
END $$;

\echo '=== Catálogos presentes ==='
SELECT code, name, is_active
  FROM public.os_catalog
 ORDER BY code;

\echo '=== Clientes API activos (sin mostrar claves) ==='
SELECT id, institution_name, is_active, length(api_key) AS longitud_clave
  FROM public.api_clients
 ORDER BY id;

ROLLBACK;
