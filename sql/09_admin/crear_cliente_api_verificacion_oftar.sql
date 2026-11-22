-- =============================================================================
-- Crear un cliente API para verificar OFTAR-DX por /v1
-- Idempotente: si ya existe un cliente con este institution_name, no inserta
-- nada y no modifica la clave existente.
--
-- Ejecutar en el VPS:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f sql/09_admin/crear_cliente_api_verificacion_oftar.sql
--
-- La clave se guarda SOLO en /var/lib/postgresql/.origen_api_key con permisos
-- 600 (el proceso psql corre como usuario postgres, no como root).
-- No se muestra por pantalla ni se guarda en el repositorio.
-- =============================================================================

BEGIN;

-- gen_random_bytes() está en el core desde PostgreSQL 13; el IF NOT EXISTS
-- cubre instalaciones anteriores.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

WITH generado AS (
    SELECT 'OFTAR · Verificación Browse/API'::VARCHAR(150) AS institution_name,
           encode(gen_random_bytes(32), 'hex')             AS api_key
),
ins AS (
    INSERT INTO public.api_clients (institution_name, api_key, is_active)
    SELECT g.institution_name, g.api_key, TRUE
      FROM generado g
     WHERE NOT EXISTS (
        SELECT 1
          FROM public.api_clients ac
         WHERE ac.institution_name = g.institution_name
     )
    RETURNING 1
)
SELECT CASE
           WHEN EXISTS (SELECT 1 FROM ins) THEN 'CLIENTE_CREADO'
           ELSE 'CLIENTE_YA_EXISTENTE'
       END AS resultado;

COMMIT;

-- \gset guarda la columna api_key en la variable :api_key dentro de psql.
SELECT api_key
  FROM public.api_clients
 WHERE institution_name = 'OFTAR · Verificación Browse/API'
   AND is_active = TRUE
 LIMIT 1
\gset

\o /var/lib/postgresql/.origen_api_key
\echo :api_key
\o

\! chmod 600 /var/lib/postgresql/.origen_api_key

\echo 'Clave guardada en /var/lib/postgresql/.origen_api_key (600). No se mostró en pantalla.'
