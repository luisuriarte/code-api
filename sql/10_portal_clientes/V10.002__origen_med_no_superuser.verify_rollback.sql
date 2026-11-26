-- Verificación SELECT-only del rollback de V10.002.
-- Confirma que SUPERUSER fue restaurado; solo para deshacer la corrección.

BEGIN READ ONLY;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para V10.002: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

SELECT current_database() AS base, current_user AS usuario;

SELECT rolname,
       rolsuper,
       rolsuper AS superuser_restorado
FROM pg_roles
WHERE rolname = 'origen_med';

ROLLBACK;
