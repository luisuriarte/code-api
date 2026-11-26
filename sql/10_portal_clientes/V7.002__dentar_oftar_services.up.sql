-- V7.002__dentar_oftar_services.up.sql
-- Adición autorizada al catálogo técnico de la Etapa 7: DENTAR y OFTAR.
-- No modifica V7.001. Solo inserta dos filas en os_customer.service.
-- Autorizado por docs/portal-clientes/acta-autorizacion-etapa-9.md (adenda).
-- SOLO entorno de prueba/base independiente. NO ejecutar en producción.
--
-- Reglas:
--   - Invoice Ninja sigue siendo la fuente de verdad comercial.
--   - No se guardan precios, importes, UVR, facturas ni pagos.
--   - Las rutas ya están documentadas y verificadas en el repositorio.

BEGIN;

-- Guarda: esta migración solo se ejecuta en la base aislada de prueba.
DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para V7.002: %', current_database()
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

INSERT INTO os_customer.service
    (code, name, description, domain, api_route, api_method, auth_required, verified_source)
VALUES
    (
        'api.dentar',
        'DENTAR',
        'Familia odontológica DENTAR-PR y DENTAR-DX. Rutas verificadas en la API; sin precios ni UVR en este catálogo.',
        'odontologia',
        '/v1/odontologia/diagnosticos',
        'GET',
        true,
        'api/index.php;docs/api/openapi-3.1.yaml;docs/dentar/README.md'
    ),
    (
        'api.oftar',
        'OFTAR',
        'Familia oftalmológica OFTAR-PR y OFTAR-DX. Consultar con catalog_code=oftar-pr u oftar-dx; sin UVR en diagnósticos.',
        'oftar',
        '/v1/catalogs/{catalog_code}/items',
        'GET',
        true,
        'api/services/TerminologySearchService.php;docs/api/openapi-3.1.yaml'
    )
ON CONFLICT (code) DO NOTHING;

COMMIT;
