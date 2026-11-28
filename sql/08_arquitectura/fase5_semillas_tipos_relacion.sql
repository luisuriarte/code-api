-- =============================================================================
-- NO EJECUTAR SIN RATIFICACIÓN CLÍNICA, ACTA, BACKUP Y VERIFICACIÓN READ ONLY
-- sql/08_arquitectura/fase5_semillas_tipos_relacion.sql
-- =============================================================================
-- Semilla gobernada del diccionario común de relaciones clínicas.
--
-- Qué hace:
--   1. Registra los 31 códigos REL-* canónicos como relation_kind='clinical'.
--   2. Declara la única inversa semánticamente equivalente: NARROW <-> BROAD.
--
-- Qué NO hace:
--   - No crea relaciones entre conceptos ni mapeos terminológicos.
--   - No reescribe tipos ya existentes: ON CONFLICT DO NOTHING.
--   - No modifica la única inversa si ya fue declarada.
--   - No ejecuta sentencias destructivas.
-- =============================================================================

BEGIN;

SET LOCAL client_encoding = 'UTF8';
SET LOCAL standard_conforming_strings = on;

DO $$
BEGIN
    IF to_regclass('public.os_relation_type') IS NULL THEN
        RAISE EXCEPTION 'Falta public.os_relation_type; aplique primero fase1_infraestructura.sql.';
    END IF;
    IF to_regclass('public.os_relation_kind') IS NULL THEN
        RAISE EXCEPTION 'Falta public.os_relation_kind; aplique primero fase1_infraestructura.sql.';
    END IF;
END
$$;

INSERT INTO public.os_relation_type
    (code, relation_kind, source, inverse_code, is_active)
VALUES
    ('REL-PR-REL',      'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PR-COMP',     'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PR-ALT',      'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PR-PART',     'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PR-COMB',     'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PR-REQR',     'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PR-SEQ',      'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-DX-REL',      'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-DX-ASSOC',    'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-DX-DIFF',     'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-DX-NARROW',   'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-DX-BROAD',    'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-DX-MANIF',    'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-DX-COMPL',    'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-DX-ETIOL',    'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-DX-COEX',     'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PRDX-DIAG',   'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PRDX-EVAL',   'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PRDX-TER',    'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PRDX-TRAT',   'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PRDX-FUP',    'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PRDX-CTRL',   'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PRDX-PREV',   'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PRDX-CONTRA', 'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-PRDX-NOTREC', 'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-ANAT-AFFECT', 'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-ANAT-INTERV', 'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-ANAT-EVAL',   'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-ANAT-LOC',    'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-ANAT-PART',   'clinical', 'OFTAR-v1.0', NULL, TRUE),
    ('REL-FUNC-IMPAIR', 'clinical', 'OFTAR-v1.0', NULL, TRUE)
ON CONFLICT (code) DO NOTHING;

-- Única inversa semánticamente equivalente. La actualización es condicional:
-- no reescribe una fila que ya tenga inverse_code declarado.
UPDATE public.os_relation_type AS t
   SET inverse_code = CASE t.code
                          WHEN 'REL-DX-NARROW' THEN 'REL-DX-BROAD'
                          WHEN 'REL-DX-BROAD'  THEN 'REL-DX-NARROW'
                      END
 WHERE t.code IN ('REL-DX-NARROW', 'REL-DX-BROAD')
   AND t.source = 'OFTAR-v1.0'
   AND t.inverse_code IS NULL;

COMMIT;

-- Verificación posterior obligatoria (fuera de esta transacción):
--   SELECT count(*) FROM os_relation_type WHERE source = 'OFTAR-v1.0';  -- 31
--   SELECT count(*) FROM os_relation_type WHERE source = 'OFTAR-v1.0'
--    AND inverse_code IS NOT NULL;                                      -- 2
