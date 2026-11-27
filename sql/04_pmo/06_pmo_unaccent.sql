-- =============================================================================
-- Origen Salud · PMO · Extensión unaccent para búsqueda accent-insensitive
-- sql/04_pmo/06_pmo_unaccent.sql
-- =============================================================================
-- Habilita la extensión unaccent y crea un índice funcional sobre pmo_practicas
-- para que las búsquedas sin tildes encuentren términos con tildes y viceversa.
-- Idempotente: seguro reejecutarse.
-- =============================================================================

SET client_encoding = 'UTF8';

-- 1. Extensión unaccent
CREATE EXTENSION IF NOT EXISTS unaccent;

-- 2. Función wrapper IMMUTABLE para unaccent (requerido para índices)
--    unaccent() por defecto es STABLE; esta envoltura permite usarla en expresiones de índice.
CREATE OR REPLACE FUNCTION f_unaccent(text)
    RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
AS $$ SELECT public.unaccent('public.unaccent', $1) $$;

-- 3. Índices funcionales accent-insensitive en pmo_practicas
CREATE INDEX IF NOT EXISTS idx_pmo_practica_unaccent
    ON pmo_practicas USING gin (f_unaccent(practica) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_pmo_capitulo_unaccent
    ON pmo_practicas USING gin (f_unaccent(capitulo) gin_trgm_ops);

-- 4. Índice funcional en pmo_odontologia (solo si ya es tabla, no vista)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'pmo_odontologia'
          AND n.nspname = 'public'
          AND c.relkind = 'r'
    ) THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_pmo_odonto_unaccent
                     ON pmo_odontologia USING gin (f_unaccent(practica) gin_trgm_ops)';
    END IF;
END$$;

-- 4. Verificación
SELECT extname, extversion FROM pg_extension WHERE extname = 'unaccent';
