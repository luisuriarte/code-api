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

-- 2. Índices funcionales unaccent en pmo_practicas
CREATE INDEX IF NOT EXISTS idx_pmo_practica_unaccent
    ON pmo_practicas USING gin (unaccent(practica) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_pmo_capitulo_unaccent
    ON pmo_practicas USING gin (unaccent(capitulo) gin_trgm_ops);

-- 3. Índice funcional en pmo_odontologia (si ya existe como tabla)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'pmo_odontologia'
          AND n.nspname = 'public'
          AND c.relkind = 'r'  -- solo tabla, no vista
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_pmo_odonto_unaccent
            ON pmo_odontologia USING gin (unaccent(practica) gin_trgm_ops);
    END IF;
END$$;

-- 4. Verificación
SELECT extname, extversion FROM pg_extension WHERE extname = 'unaccent';
