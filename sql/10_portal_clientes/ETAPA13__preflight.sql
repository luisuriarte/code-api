-- ETAPA13__preflight.sql
-- Comprobación SELECT-only previa a crear el esquema del portal en producción.
-- Solo se ejecuta en la base operativa origen_codes_portal_clientes.
-- No modifica datos ni muestra secretos.

BEGIN READ ONLY;

DO $guard$
BEGIN
    IF current_database() <> 'origen_codes_portal_clientes' THEN
        RAISE EXCEPTION 'Etapa 13 requiere la base origen_codes_portal_clientes, no %', current_database()
            USING ERRCODE = '42501';
    END IF;

    IF to_regnamespace('os_customer') IS NOT NULL THEN
        RAISE EXCEPTION 'La base ya tiene os_customer; no ejecutar migraciones de nuevo.'
            USING ERRCODE = '42710';
    END IF;
END
$guard$;

SELECT current_database() AS base, current_user AS usuario, version() AS version;

SELECT rolname, rolcanlogin, rolsuper
FROM pg_roles
WHERE rolname IN ('origen_customer', 'origen_med', 'origen_admin')
ORDER BY rolname;

SELECT datname,
       has_database_privilege('origen_customer', datname, 'CONNECT') AS conecta_customer,
       has_database_privilege('origen_med', datname, 'CONNECT') AS conecta_med
FROM pg_database
WHERE datname IN ('origen_codes', 'origen_codes_portal_clientes',
                  'origen_codes_portal_clientes_test')
ORDER BY datname;

ROLLBACK;
