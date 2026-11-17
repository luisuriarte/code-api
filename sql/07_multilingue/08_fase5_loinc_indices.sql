-- =============================================================================
-- FASE 5 · Índices de loinc_localized_text
-- =============================================================================
-- EJECUTAR FUERA DE TRANSACCIÓN (CREATE INDEX CONCURRENTLY).
-- DBeaver-CE: autocommit activo, sin transacción.
-- El índice único uq_llt_source se creó con la tabla en 07 (tabla vacía,
-- sin riesgo de bloqueo). Aquí se agregan los índices de consulta.
-- Aditivo e idempotente. Sin DROP INDEX (D-24/D-34).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO $$
DECLARE r record;
BEGIN
    FOR r IN
        SELECT c.relname AS nombre, i.indisvalid, i.indisready
        FROM pg_index i
        JOIN pg_class c ON c.oid = i.indexrelid
        WHERE c.relname IN ('uq_llt_source','idx_llt_identity',
                            'idx_llt_value_trgm','idx_llt_resolution')
    LOOP
        IF NOT r.indisvalid OR NOT r.indisready THEN
            RAISE EXCEPTION
                'Índice inválido preexistente: %. No se aplica D-34 sin autorización individual.', r.nombre;
        END IF;
    END LOOP;
END $$;

-- Identidad lógica y resolución por prioridad (D-33)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_llt_identity
    ON loinc_localized_text (loinc_code, language_code, field_name, source_release);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_llt_resolution
    ON loinc_localized_text
       (loinc_code, language_code, field_name, source_release,
        source_priority DESC, source_file ASC,
        version_last_changed DESC NULLS LAST);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_llt_value_trgm
    ON loinc_localized_text USING gin (value gin_trgm_ops);

SELECT c.relname AS indice, i.indisvalid, i.indisready
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
WHERE c.relname IN ('uq_llt_source','idx_llt_identity',
                    'idx_llt_value_trgm','idx_llt_resolution')
ORDER BY c.relname;

-- Fin de Fase 5 · índices.
