-- =============================================================================
-- FASE 2 · Siembra base de idiomas y alias
-- =============================================================================
-- Entorno de PRUEBAS. Aditivo e idempotente: ON CONFLICT DO NOTHING.
-- No modifica ni borra filas existentes. Ejecutar DENTRO de transacción.
-- Fuentes: modelo §5.1; D-15, D-27, D-39.
--
-- Tres clases (D-39):
--   is_active=true,  is_source_only=false -> seleccionables: es-AR, en, pt-BR
--   is_active=false, is_source_only=true  -> etiquetas de origen: es, es-MX
-- Ningún código tiene ambas banderas a la vez (CHECK en 01).
-- NO se crea el alias es-MX -> es-AR: es-MX conserva su etiqueta real.
-- La procedencia (LOINC, SNOMED, CDT) NO se escribe en os_language (D-39).
-- =============================================================================

BEGIN;

INSERT INTO os_language (code, display_name, primary_tag, is_active, is_source_only)
VALUES
    ('es-AR', 'Español (Argentina)', 'es', TRUE,  FALSE),
    ('en',    'English',             'en', TRUE,  FALSE),
    ('pt-BR', 'Português (Brasil)',  'pt', TRUE,  FALSE),
    ('es',    'Español (origen)',    'es', FALSE, TRUE),
    ('es-MX', 'Español (México)',    'es', FALSE, TRUE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO os_language_alias (alias, language_code)
VALUES
    ('es', 'es-AR'),   -- Accept-Language: es -> es-AR
    ('pt', 'pt-BR')    -- Accept-Language: pt -> pt-BR
ON CONFLICT (alias) DO NOTHING;

COMMIT;

-- Comprobación de cierre (leer el resultado): 3 activos, 2 source-only.
SELECT code, display_name, primary_tag, is_active, is_source_only
FROM os_language
ORDER BY code;

SELECT alias, language_code FROM os_language_alias ORDER BY alias;

-- Fin de Fase 2 · datos base.
