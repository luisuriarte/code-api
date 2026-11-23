-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud · Familia OFTAR
-- sql/03_oftar/aprobar_mapeo_nomencladores_oftar.sql
-- =============================================================================
--
-- QUÉ HACE
--   1. Aprueba SOLO `preferred_term` de los textos importados desde los dos
--      nomencladores de origen. `definition` y `external_display` siguen
--      pendientes y no se inventan.
--   2. Publica identificadores secundarios y relaciones `referencia_literal`
--      SOLAMENTE para las filas de `os_oftar_nomenclador_match` que la revisión
--      humana marcó como `approved`.
--
-- REQUISITO PREVIO
--   Haber revisado la tabla de mapeo. Las propuestas iniciales quedan en
--   `proposed`: este script no aprueba ninguna correspondencia por su cuenta.
--
-- GOBERNANZA
--   · Actor explícito en la sesión para que los triggers de auditoría registren
--     el evento append-only correspondiente.
--   · Guarda de content_hash antes de aprobar texto: si cambió desde la
--     importación, el script aborta en lugar de aprobar otro contenido.
--   · Idempotente: repetirlo no duplica identificadores ni relaciones; si una
--     fila pasa a `rejected`, una nueva ejecución retira sus enlaces.
--
-- QUÉ NO HACE
--   · No crea códigos OFT-PR, UVR, dominios ni rutas nuevas.
--   · No toca DENTAR, CIE-10 ni los 154 ítems de oftar-pr.
--   · No usa DROP ... CASCADE ni ALTER DEFAULT PRIVILEGES.
-- PostgreSQL 18.
-- =============================================================================
BEGIN;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

SET LOCAL app.actor_id = 'oftar_nomencladores_approval';
SET LOCAL app.actor_type = 'user';

DO $$
BEGIN
    IF to_regclass('public.os_oftar_nomenclador_match') IS NULL
       OR to_regclass('public.os_field_review') IS NULL
       OR to_regclass('public.os_translation_review') IS NULL
       OR to_regclass('public.os_terminology_system') IS NULL THEN
        RAISE EXCEPTION 'Falta la estructura de gobernanza o de mapeo.'
            USING HINT = 'Aplicar nomencladores_oftar_mapping.sql y los dos importadores.';
    END IF;
END $$;

-- =============================================================================
-- 1. Textos aprobables: solo preferred_term de los dos nomencladores de origen
-- =============================================================================
CREATE TEMP TABLE _oftar_nom_aprobables ON COMMIT DROP AS
SELECT f.target_id AS version_id,
       f.language_code,
       f.scope_release_id,
       f.content_hash,
       md5(
           iv.preferred_term || E'\x1f'
           || f.language_code || E'\x1f'
           || COALESCE(f.source_reference, '')
       ) AS hash_esperado
  FROM public.os_field_review f
  JOIN public.os_catalog_item_version iv ON iv.id = f.target_id
 WHERE f.target_table = 'os_catalog_item_version'
   AND f.field_name = 'preferred_term'
   AND f.provenance IN ('imported_oftar_cao', 'imported_oftar_regional')
   AND f.review_status = 'unknown'
   AND f.language_code = 'es-AR'
   AND f.scope_release_id = iv.release_id
   AND NULLIF(btrim(iv.preferred_term), '') IS NOT NULL;

DO $$
DECLARE
    v_desactualizados INT;
BEGIN
    SELECT count(*) INTO v_desactualizados
      FROM _oftar_nom_aprobables
     WHERE content_hash IS DISTINCT FROM hash_esperado;

    IF v_desactualizados > 0 THEN
        RAISE EXCEPTION
            'Hay % términos preferidos con hash desactualizado; no se aprueba nada.',
            v_desactualizados
            USING HINT = 'Revisá esas filas y vuelve a importar antes de aprobar.';
    END IF;
END $$;

UPDATE public.os_field_review f
   SET review_status = 'approved',
       reviewed_by = 'oftar_nomencladores_approval',
       reviewed_at = now(),
       updated_at = now()
  FROM _oftar_nom_aprobables a
 WHERE f.target_table = 'os_catalog_item_version'
   AND f.target_id = a.version_id
   AND f.field_name = 'preferred_term'
   AND f.language_code = a.language_code
   AND f.scope_release_id IS NOT DISTINCT FROM a.scope_release_id;

UPDATE public.os_catalog_item_version iv
   SET review_status = 'approved'
  FROM _oftar_nom_aprobables a
 WHERE iv.id = a.version_id
   AND iv.review_status <> 'approved';

-- =============================================================================
-- 2. Sistemas terminológicos de los nomencladores de origen
-- =============================================================================
SELECT setval(
    pg_get_serial_sequence('os_terminology_system', 'id'),
    (SELECT COALESCE(max(id), 1) FROM os_terminology_system),
    true
);

INSERT INTO public.os_terminology_system (code, name, uri, default_version)
VALUES
    ('NOMENCLADOR-CAO-AR',
     'Nomenclador Nacional de Oftalmología (CAO, Argentina)',
     'https://www.cao.org.ar', '2026-v1'),
    ('NOMENCLADOR-OFTAL-REG-AR',
     'Nomenclador Oftalmológico de Referencia Regional (Argentina)',
     'https://www.cao.org.ar', '2026-v1')
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    uri = EXCLUDED.uri;

CREATE TEMP TABLE _oftar_source_system (
    catalog_code VARCHAR(60) NOT NULL PRIMARY KEY,
    system_code VARCHAR(30) NOT NULL,
    identifier_system VARCHAR(50) NOT NULL
) ON COMMIT DROP;

INSERT INTO _oftar_source_system (catalog_code, system_code, identifier_system) VALUES
    ('nomenclador-oftalmologico-cao-ar', 'NOMENCLADOR-CAO-AR', 'NOMENCLADOR_CAO_AR'),
    ('nomenclador-oftalmologico-regional-ar', 'NOMENCLADOR-OFTAL-REG-AR', 'NOMENCLADOR_OFTAL_REG_AR');

-- =============================================================================
-- 3. Pares publicables: SOLO los aprobados por revisión humana
-- =============================================================================
CREATE TEMP TABLE _oftar_match_todos ON COMMIT DROP AS
SELECT m.source_catalog_code,
       m.source_code,
       m.target_code,
       m.review_status,
       ss.system_code,
       ss.identifier_system,
       src.id AS source_item_id,
       tgt.id AS target_item_id,
       src.status AS source_status,
       tgt.status AS target_status
  FROM public.os_oftar_nomenclador_match m
  JOIN _oftar_source_system ss ON ss.catalog_code = m.source_catalog_code
  JOIN public.os_catalog sc ON sc.code = m.source_catalog_code
  JOIN public.os_catalog_item src
         ON src.catalog_id = sc.id AND src.permanent_code = m.source_code
  JOIN public.os_catalog tc ON tc.code = m.target_catalog_code
  JOIN public.os_catalog_item tgt
         ON tgt.catalog_id = tc.id AND tgt.permanent_code = m.target_code;

CREATE TEMP TABLE _oftar_match_publicable ON COMMIT DROP AS
SELECT * FROM _oftar_match_todos
 WHERE review_status = 'approved'
   AND source_status = 'active'
   AND target_status = 'active';

-- =============================================================================
-- 4. Identificadores secundarios en ambos sentidos (nunca principales)
-- =============================================================================
DELETE FROM public.os_catalog_identifier i
 USING _oftar_match_todos p
 WHERE (i.item_id = p.target_item_id
        AND i.system_name = p.identifier_system AND i.value = p.source_code)
    OR (i.item_id = p.source_item_id
        AND i.system_name = 'OFT-PR' AND i.value = p.target_code);

WITH nuevos AS (
    SELECT p.target_item_id AS item_id, p.identifier_system AS system_name,
           p.source_code AS value FROM _oftar_match_publicable p
    UNION ALL
    SELECT p.source_item_id, 'OFT-PR', p.target_code FROM _oftar_match_publicable p
)
INSERT INTO public.os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT item_id, system_name, value, FALSE FROM nuevos
ON CONFLICT (item_id, system_name, value) DO UPDATE SET is_primary = FALSE;

-- =============================================================================
-- 5. Relación literal navegable en ambos sentidos
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.os_catalog_relation (
    id BIGSERIAL PRIMARY KEY,
    source_item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    target_item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    relation_type VARCHAR(60) NOT NULL CHECK (relation_type IN (
        'alternate_benefit', 'billed_in_conjunction_with', 'concurrent_to',
        'denied_as_integral', 'frequency_limitations', 'integral_to',
        'interchangeable_with', 'not_paid_separately', 'not_to_be_used_with',
        'paid_as_code', 'procedure_code_not_used_for', 'refer_to_details',
        'referencia_literal', 'shares_frequency_limitation_with',
        'used_in_combination_with'
    )),
    source_system_code VARCHAR(30) NOT NULL DEFAULT 'CDT-2025',
    source_field VARCHAR(30) NOT NULL CHECK (source_field IN ('description', 'procedure', 'notes', 'req')),
    source_value VARCHAR(20) NOT NULL,
    context_text TEXT,
    source_cdt_id INT,
    review_status VARCHAR(20) NOT NULL DEFAULT 'reviewed'
        CHECK (review_status IN ('draft', 'reviewed', 'approved', 'deprecated')),
    provenance TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_os_catalog_relation_not_self CHECK (source_item_id <> target_item_id),
    CONSTRAINT uq_os_catalog_relation UNIQUE
        (source_item_id, target_item_id, relation_type, source_system_code,
         source_field, source_value, context_text)
);

CREATE INDEX IF NOT EXISTS idx_os_catalog_relation_source
    ON public.os_catalog_relation (source_item_id);
CREATE INDEX IF NOT EXISTS idx_os_catalog_relation_target
    ON public.os_catalog_relation (target_item_id);
CREATE INDEX IF NOT EXISTS idx_os_catalog_relation_type
    ON public.os_catalog_relation (relation_type);

DELETE FROM public.os_catalog_relation r
 USING _oftar_match_todos p
 WHERE ((r.source_item_id = p.source_item_id AND r.target_item_id = p.target_item_id)
     OR (r.source_item_id = p.target_item_id AND r.target_item_id = p.source_item_id))
   AND r.relation_type = 'referencia_literal'
   AND r.source_system_code = p.system_code;

WITH nuevas AS (
    SELECT p.source_item_id AS source_item_id, p.target_item_id AS target_item_id,
           p.system_code, p.source_code AS source_value,
           'Código de origen ' || p.source_code || '; código permanente destino '
             || p.target_code || '. Referencia literal gobernada, sin juicio de equivalencia clínica.' AS context_text,
           'Mapeo gobernado: ' || p.source_catalog_code AS provenance
      FROM _oftar_match_publicable p
    UNION ALL
    SELECT p.target_item_id, p.source_item_id, p.system_code, p.target_code,
           'Código permanente OFT-PR ' || p.target_code || '; código de origen '
             || p.source_code || '. Referencia literal gobernada, sin juicio de equivalencia clínica.',
           'Mapeo gobernado: ' || p.source_catalog_code
      FROM _oftar_match_publicable p
)
INSERT INTO public.os_catalog_relation
    (source_item_id, target_item_id, relation_type, source_system_code,
     source_field, source_value, context_text, review_status, provenance)
SELECT source_item_id, target_item_id, 'referencia_literal', system_code,
       'description', source_value, context_text, 'approved', provenance
  FROM nuevas
ON CONFLICT DO NOTHING;

-- La revisión queda registrada en la propia tabla de mapeo.
UPDATE public.os_oftar_nomenclador_match m
   SET reviewed_at = COALESCE(m.reviewed_at, now()),
       reviewed_by = COALESCE(m.reviewed_by, 'oftar_nomencladores_approval')
  FROM _oftar_match_publicable p
 WHERE m.source_catalog_code = p.source_catalog_code
   AND m.source_code = p.source_code;

-- =============================================================================
-- 6. Verificación (solo lectura; ejecutar por separado)
-- =============================================================================
-- SELECT count(*) AS preferred_term_aprobados
--   FROM public.os_field_review
--  WHERE field_name = 'preferred_term'
--    AND provenance IN ('imported_oftar_cao', 'imported_oftar_regional')
--    AND review_status = 'approved';
-- SELECT source_catalog_code, review_status, count(*)
--   FROM public.os_oftar_nomenclador_match GROUP BY 1, 2 ORDER BY 1, 2;
-- SELECT source_system_code, count(*) FROM public.os_catalog_relation
--  WHERE source_system_code IN ('NOMENCLADOR-CAO-AR', 'NOMENCLADOR-OFTAL-REG-AR')
--  GROUP BY 1 ORDER BY 1;
-- SELECT catalogo, count(*) FROM public.v_oftar_search_catalog GROUP BY 1 ORDER BY 1;

COMMIT;
