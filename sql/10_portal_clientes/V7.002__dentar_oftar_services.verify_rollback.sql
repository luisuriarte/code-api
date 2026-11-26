-- Verificación SELECT-only del rollback de V7.002.
-- Confirma que solo se eliminaron las dos filas nuevas.

BEGIN READ ONLY;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para V7.002: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

SELECT current_database() AS base, current_user AS usuario;

SELECT count(*) AS servicios_dentar_oftar_restantes
FROM os_customer.service
WHERE code IN ('api.dentar', 'api.oftar');

SELECT count(*) AS servicios_verificados
FROM os_customer.service
WHERE status = 'available'
  AND api_method = 'GET'
  AND environment = 'production'
  AND verified_source <> ''
  AND api_route <> '';

SELECT code, api_route
FROM os_customer.service
WHERE code IN ('api.health', 'api.search', 'api.catalogs', 'api.snomed', 'api.cie10',
               'api.loinc', 'api.anmat', 'api.nomenclador', 'api.pmo', 'api.vademecum',
               'docs.public', 'browse.codes')
ORDER BY code;

SELECT count(*) AS total_tablas
FROM pg_tables
WHERE schemaname = 'os_customer';

ROLLBACK;
