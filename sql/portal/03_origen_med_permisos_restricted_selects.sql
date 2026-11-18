-- =============================================================================
-- PORTAL med.origen.ar · permisos SELECT que faltan para Browse Codes
-- =============================================================================
-- Ejecutar en el VPS como postgres:
--   sudo -u postgres psql -d origen_codes -f sql/portal/03_origen_med_permisos_restricted_selects.sql
--
-- Aditivo e idempotente. NO modifica esquema, NO altera datos, NO crea backups.
-- Solo concede SELECT sobre tablas ya existentes. Requiere el rol origen_med
-- creado por 01_origen_med_permisos.sql. Si tu DSN usa otra base, cambiá
-- `-d origen_codes` por el dbname real de PORTAL_DB_DSN.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'origen_med') THEN
        RAISE EXCEPTION 'Falta el rol origen_med: ejecute primero sql/portal/01_origen_med_permisos.sql';
    END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO origen_med;

DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'os_concept_mapping',
        'os_terminology_system',
        'os_fee_item',
        'os_fee_schedule',
        'os_pricing_unit'
    ]
    LOOP
        IF to_regclass('public.' || t) IS NOT NULL THEN
            EXECUTE format('GRANT SELECT ON TABLE public.%I TO origen_med', t);
            RAISE NOTICE 'GRANT SELECT verificado en public.%', t;
        ELSE
            RAISE NOTICE 'OMITIDA public.% (no existe en esta base)', t;
        END IF;
    END LOOP;
END
$$;

COMMIT;

-- Verificación: toda tabla existente debe devolver puede_leer = t.
SELECT tablename,
       to_regclass('public.' || tablename) IS NOT NULL AS existe,
       CASE WHEN to_regclass('public.' || tablename) IS NULL THEN NULL
            ELSE has_table_privilege('origen_med', 'public.' || tablename, 'SELECT')
       END AS puede_leer
  FROM (VALUES
      ('os_concept_mapping'), ('os_terminology_system'),
      ('os_fee_item'), ('os_fee_schedule'), ('os_pricing_unit')
  ) AS v(tablename)
 ORDER BY tablename;
