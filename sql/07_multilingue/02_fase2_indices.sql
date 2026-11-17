-- =============================================================================
-- FASE 2 · Índices de las tablas lingüísticas
-- =============================================================================
-- EJECUTAR FUERA DE TRANSACCIÓN.
--   psql:    no hace falta BEGIN; el archivo no lo contiene.
--   DBeaver: desactivar "ejecutar en transacción" / dejar autocommit ACTIVO.
-- PostgreSQL no permite CREATE INDEX CONCURRENTLY dentro de BEGIN/COMMIT.
-- Aditivo e idempotente. Sin DROP INDEX: si existe un índice inválido con
-- alguno de estos nombres, el bloque de verificación detiene el script (D-24,
-- D-34) en vez de borrarlo.
-- Requiere la extensión pg_trgm (ya creada en 01_schema/design.sql).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ---------------------------------------------------------------------------
-- Verificación previa (D-24 / D-34): ningún índice propio puede estar inválido
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT c.relname AS nombre, i.indisvalid, i.indisready
        FROM pg_index i
        JOIN pg_class c ON c.oid = i.indexrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname IN (
            'uq_ocl_default', 'uq_ocl_fallback', 'uq_ocl_bridge',
            'uq_olt_global', 'uq_olt_scoped', 'idx_olt_identity',
            'idx_olt_value_trgm', 'uq_fr_global', 'uq_fr_scoped')
    LOOP
        IF NOT r.indisvalid OR NOT r.indisready THEN
            RAISE EXCEPTION
                'Índice inválido preexistente: %. No se aplica D-34 sin autorización individual; detener y revisar.',
                r.nombre;
        END IF;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- os_catalog_language: exactamente 1 default y 1 fallback; bridge opcional
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_ocl_default
    ON os_catalog_language (catalog_id) WHERE is_default;

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_ocl_fallback
    ON os_catalog_language (catalog_id) WHERE is_fallback;

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_ocl_bridge
    ON os_catalog_language (catalog_id) WHERE is_bridge;

-- ---------------------------------------------------------------------------
-- os_localized_text: unicidad por dominio de nulidad de scope_release_id
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_olt_global
    ON os_localized_text (entity_type, entity_id, field_name, language_code)
    WHERE scope_release_id IS NULL;

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_olt_scoped
    ON os_localized_text (entity_type, entity_id, field_name, language_code, scope_release_id)
    WHERE scope_release_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_olt_identity
    ON os_localized_text (entity_type, entity_id, field_name, language_code);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_olt_value_trgm
    ON os_localized_text USING gin (value gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- os_field_review: dos índices únicos parciales (D-21, D-28)
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_fr_global
    ON os_field_review (target_table, target_id, field_name, language_code)
    WHERE scope_release_id IS NULL;

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_fr_scoped
    ON os_field_review (target_table, target_id, field_name, language_code, scope_release_id)
    WHERE scope_release_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Comprobación de cierre: todos válidos (leer el resultado)
-- ---------------------------------------------------------------------------
SELECT c.relname AS indice, i.indisvalid, i.indisready
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
WHERE c.relname IN (
    'uq_ocl_default', 'uq_ocl_fallback', 'uq_ocl_bridge',
    'uq_olt_global', 'uq_olt_scoped', 'idx_olt_identity',
    'idx_olt_value_trgm', 'uq_fr_global', 'uq_fr_scoped')
ORDER BY c.relname;

-- Fin de Fase 2 · índices.
