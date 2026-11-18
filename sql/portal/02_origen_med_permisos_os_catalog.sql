-- =============================================================================
-- PORTAL med.origen.ar · permisos incrementales para la rama os_catalog
-- =============================================================================
-- Ejecutar en el VPS con:
--   sudo -u postgres psql -d origen_codes -f /var/www/html/origen.ar/code-api/sql/portal/02_origen_med_permisos_os_catalog.sql
-- o desde DBEaver-CE con usuario postgres.
-- Aditivo e idempotente: no modifica datos, no borra objetos y no crea backups.
-- =============================================================================

BEGIN;

GRANT SELECT ON TABLE
    public.os_catalog,
    public.os_catalog_release,
    public.os_catalog_category,
    public.os_catalog_item,
    public.os_catalog_item_version,
    public.os_catalog_term,
    public.os_catalog_identifier
TO origen_med;

COMMIT;

-- Verificación: las 7 tablas deben devolver 't'.
SELECT tablename,
       has_table_privilege('origen_med', 'public.' || tablename, 'SELECT') AS puede_leer
  FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN (
       'os_catalog', 'os_catalog_release', 'os_catalog_category',
       'os_catalog_item', 'os_catalog_item_version', 'os_catalog_term',
       'os_catalog_identifier'
   )
 ORDER BY tablename;
