-- =============================================================================
-- NO EJECUTAR SIN BACKUP Y VERIFICACIÓN READ ONLY
-- sql/08_arquitectura/relaciones_crud_auditable.sql
-- =============================================================================
-- CRUD auditable de relaciones terminológicas y clínicas desde el panel.
--
-- Qué hace:
--   1. Crea una función SECURITY DEFINER que escribe en:
--        · public.os_catalog_relation
--        · public.os_concept_mapping (+ os_mapping_metadata, si existe)
--        · public.os_oftar_nomenclador_match
--   2. Fuerza estados NO publicables en alta/edición:
--        · catalog_relation / concept_mapping -> 'draft'
--        · nomenclador_match                 -> 'proposed'
--   3. El "borrado" es lógico:
--        · catalog_relation / concept_mapping -> 'deprecated'
--        · nomenclador_match                 -> 'rejected'
--   4. Devuelve before/after para que PHP registre auditoría en la MISMA
--      transacción (fail closed).
--
-- Qué NO hace:
--   - No publica relaciones: nunca escribe review_status='approved'.
--   - No aprueba pares, no crea equivalencias clínicas y no toca la API.
--   - No elimina filas físicamente ni modifica las relaciones heredadas.
--   - No depende de columnas agregadas por fases posteriores (Fase 3/5):
--     solo escribe columnas del esquema base ya existente en producción.
--   - No cambia family_code ni crea endpoints por familia.
--
-- Requisito: origen_admin debe poder ejecutar la función; no recibe grants
-- de INSERT/UPDATE/DELETE sobre las tablas base. La función se crea como
-- postgres (owner) para que SECURITY DEFINER tenga los privilegios necesarios.
-- =============================================================================

BEGIN;

SET LOCAL client_encoding = 'UTF8';
SET LOCAL standard_conforming_strings = on;

CREATE OR REPLACE FUNCTION public.os_relation_admin_write(
    p_entity TEXT,
    p_action TEXT,
    p_id BIGINT,
    p_payload JSONB,
    p_reason TEXT,
    p_actor_id BIGINT,
    p_actor_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_before    JSONB := NULL;
    v_after     JSONB := NULL;
    v_entity_id TEXT := '';
    v_catalog   TEXT := NULL;
    v_reason    TEXT := NULLIF(btrim(COALESCE(p_reason, '')), '');
BEGIN
    IF COALESCE(p_entity, '') NOT IN (
        'catalog_relation', 'concept_mapping', 'nomenclador_match'
    ) THEN
        RAISE EXCEPTION 'RELATION_ENTITY_INVALID: %', COALESCE(p_entity, 'null');
    END IF;

    IF COALESCE(p_action, '') NOT IN ('create', 'update', 'delete') THEN
        RAISE EXCEPTION 'RELATION_ACTION_INVALID: %', COALESCE(p_action, 'null');
    END IF;

    IF v_reason IS NULL OR char_length(v_reason) < 4 THEN
        RAISE EXCEPTION 'RELATION_REASON_REQUIRED';
    END IF;

    IF NULLIF(btrim(COALESCE(p_actor_email, '')), '') IS NULL THEN
        RAISE EXCEPTION 'RELATION_ACTOR_REQUIRED';
    END IF;

    IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN
        RAISE EXCEPTION 'RELATION_PAYLOAD_INVALID';
    END IF;

    -- -------------------------------------------------------------------------
    -- 1. Relaciones internas (os_catalog_relation)
    -- -------------------------------------------------------------------------
    IF p_entity = 'catalog_relation' THEN
        DECLARE
            v_rel       public.os_catalog_relation%ROWTYPE;
            v_source    INT;
            v_target    INT;
            v_type      TEXT;
            v_src       TEXT;
            v_val       TEXT;
            v_ctx       TEXT;
            v_system    TEXT := COALESCE(NULLIF(p_payload ->> 'source_system_code', ''), 'CDT-2025');
        BEGIN
            IF p_action = 'create' THEN
                v_source := NULLIF(p_payload ->> 'source_item_id', '')::INT;
                v_target := NULLIF(p_payload ->> 'target_item_id', '')::INT;
                v_type   := NULLIF(p_payload ->> 'relation_type', '');
                v_src    := NULLIF(p_payload ->> 'source_field', '');
                v_val    := NULLIF(btrim(COALESCE(p_payload ->> 'source_value', '')), '');
                v_ctx    := NULLIF(p_payload ->> 'context_text', '');

                IF v_source IS NULL OR v_target IS NULL OR v_source = v_target THEN
                    RAISE EXCEPTION 'RELATION_ITEMS_INVALID';
                END IF;

                IF NOT EXISTS (SELECT 1 FROM public.os_catalog_item WHERE id = v_source)
                   OR NOT EXISTS (SELECT 1 FROM public.os_catalog_item WHERE id = v_target) THEN
                    RAISE EXCEPTION 'RELATION_ITEMS_INVALID';
                END IF;

                IF v_type IS NULL OR v_type NOT IN (
                    'alternate_benefit', 'billed_in_conjunction_with', 'concurrent_to',
                    'denied_as_integral', 'frequency_limitations', 'integral_to',
                    'interchangeable_with', 'not_paid_separately', 'not_to_be_used_with',
                    'paid_as_code', 'procedure_code_not_used_for', 'refer_to_details',
                    'referencia_literal', 'shares_frequency_limitation_with',
                    'used_in_combination_with'
                ) THEN
                    RAISE EXCEPTION 'RELATION_TYPE_INVALID: %', COALESCE(v_type, 'null');
                END IF;

                IF v_src IS NULL OR v_src NOT IN ('description', 'procedure', 'notes', 'req') THEN
                    RAISE EXCEPTION 'RELATION_FIELD_INVALID';
                END IF;

                IF v_val IS NULL OR char_length(v_val) > 20 THEN
                    RAISE EXCEPTION 'RELATION_VALUE_INVALID';
                END IF;

                IF NULLIF(btrim(COALESCE(p_payload ->> 'provenance', '')), '') IS NULL THEN
                    RAISE EXCEPTION 'RELATION_PROVENANCE_REQUIRED';
                END IF;

                IF char_length(v_system) > 30 THEN
                    RAISE EXCEPTION 'RELATION_SYSTEM_INVALID';
                END IF;

                IF EXISTS (
                    SELECT 1 FROM public.os_catalog_relation r
                     WHERE r.source_item_id = v_source
                       AND r.target_item_id = v_target
                       AND r.relation_type = v_type
                       AND r.source_system_code = v_system
                       AND r.source_field = v_src
                       AND r.source_value = v_val
                       AND r.context_text IS NOT DISTINCT FROM v_ctx
                ) THEN
                    RAISE EXCEPTION 'RELATION_DUPLICATE';
                END IF;

                INSERT INTO public.os_catalog_relation (
                    source_item_id, target_item_id, relation_type, source_system_code,
                    source_field, source_value, context_text, review_status, provenance
                ) VALUES (
                    v_source, v_target, v_type, v_system, v_src, v_val, v_ctx,
                    'draft', btrim(p_payload ->> 'provenance')
                )
                RETURNING * INTO v_rel;

            ELSIF p_action = 'update' THEN
                SELECT * INTO v_rel
                  FROM public.os_catalog_relation
                 WHERE id = p_id
                 FOR UPDATE;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'RELATION_NOT_FOUND';
                END IF;

                v_before := to_jsonb(v_rel);

                v_type := COALESCE(NULLIF(p_payload ->> 'relation_type', ''), v_rel.relation_type);
                v_src  := COALESCE(NULLIF(p_payload ->> 'source_field', ''), v_rel.source_field);
                v_val  := COALESCE(NULLIF(btrim(COALESCE(p_payload ->> 'source_value', '')), ''), v_rel.source_value);
                v_ctx  := COALESCE(NULLIF(p_payload ->> 'context_text', ''), v_rel.context_text);
                v_system := COALESCE(NULLIF(p_payload ->> 'source_system_code', ''), v_rel.source_system_code);

                IF v_type NOT IN (
                    'alternate_benefit', 'billed_in_conjunction_with', 'concurrent_to',
                    'denied_as_integral', 'frequency_limitations', 'integral_to',
                    'interchangeable_with', 'not_paid_separately', 'not_to_be_used_with',
                    'paid_as_code', 'procedure_code_not_used_for', 'refer_to_details',
                    'referencia_literal', 'shares_frequency_limitation_with',
                    'used_in_combination_with'
                ) THEN
                    RAISE EXCEPTION 'RELATION_TYPE_INVALID: %', v_type;
                END IF;

                IF v_src NOT IN ('description', 'procedure', 'notes', 'req') THEN
                    RAISE EXCEPTION 'RELATION_FIELD_INVALID';
                END IF;

                IF v_val IS NULL OR char_length(v_val) > 20 THEN
                    RAISE EXCEPTION 'RELATION_VALUE_INVALID';
                END IF;

                v_source := COALESCE(NULLIF(p_payload ->> 'source_item_id', '')::INT, v_rel.source_item_id);
                v_target := COALESCE(NULLIF(p_payload ->> 'target_item_id', '')::INT, v_rel.target_item_id);

                IF v_source IS NULL OR v_target IS NULL OR v_source = v_target THEN
                    RAISE EXCEPTION 'RELATION_ITEMS_INVALID';
                END IF;

                IF EXISTS (
                    SELECT 1 FROM public.os_catalog_relation r
                     WHERE r.id <> p_id
                       AND r.source_item_id = v_source
                       AND r.target_item_id = v_target
                       AND r.relation_type = v_type
                       AND r.source_system_code = v_system
                       AND r.source_field = v_src
                       AND r.source_value = v_val
                       AND r.context_text IS NOT DISTINCT FROM v_ctx
                ) THEN
                    RAISE EXCEPTION 'RELATION_DUPLICATE';
                END IF;

                UPDATE public.os_catalog_relation r
                   SET source_item_id     = v_source,
                       target_item_id     = v_target,
                       relation_type      = v_type,
                       source_system_code = v_system,
                       source_field       = v_src,
                       source_value       = v_val,
                       context_text       = v_ctx,
                       provenance         = COALESCE(
                           NULLIF(btrim(COALESCE(p_payload ->> 'provenance', '')), ''),
                           r.provenance),
                       review_status      = 'draft'
                 WHERE r.id = p_id
                RETURNING * INTO v_rel;

            ELSE
                SELECT * INTO v_rel
                  FROM public.os_catalog_relation
                 WHERE id = p_id
                 FOR UPDATE;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'RELATION_NOT_FOUND';
                END IF;

                v_before := to_jsonb(v_rel);

                UPDATE public.os_catalog_relation
                   SET review_status = 'deprecated'
                 WHERE id = p_id
                RETURNING * INTO v_rel;
            END IF;

            v_after := to_jsonb(v_rel);
            v_entity_id := v_rel.id::TEXT;
            v_catalog := (
                SELECT c.code FROM public.os_catalog_item i
                  JOIN public.os_catalog c ON c.id = i.catalog_id
                 WHERE i.id = v_rel.source_item_id
            );
        END;

    -- -------------------------------------------------------------------------
    -- 2. Mapeos terminológicos (os_concept_mapping)
    -- -------------------------------------------------------------------------
    ELSIF p_entity = 'concept_mapping' THEN
        DECLARE
            v_map        public.os_concept_mapping%ROWTYPE;
            v_item       INT;
            v_system     INT;
            v_ext        TEXT;
            v_display    TEXT;
            v_type       TEXT;
            v_role       TEXT;
            v_has_meta   BOOLEAN := to_regclass('public.os_mapping_metadata') IS NOT NULL;
        BEGIN
            IF p_action = 'create' THEN
                v_item    := NULLIF(p_payload ->> 'item_id', '')::INT;
                v_system  := NULLIF(p_payload ->> 'terminology_system_id', '')::INT;
                v_ext     := NULLIF(btrim(COALESCE(p_payload ->> 'external_code', '')), '');
                v_display := NULLIF(btrim(COALESCE(p_payload ->> 'external_display', '')), '');
                v_type    := COALESCE(NULLIF(p_payload ->> 'mapping_type', ''), 'equivalent');
                v_role    := COALESCE(NULLIF(p_payload ->> 'relationship_role', ''), 'procedure_concept');

                IF v_item IS NULL OR v_system IS NULL
                   OR NOT EXISTS (SELECT 1 FROM public.os_catalog_item WHERE id = v_item)
                   OR NOT EXISTS (SELECT 1 FROM public.os_terminology_system WHERE id = v_system) THEN
                    RAISE EXCEPTION 'MAPPING_ITEMS_INVALID';
                END IF;

                IF v_ext IS NULL OR v_display IS NULL THEN
                    RAISE EXCEPTION 'MAPPING_EXTERNAL_REQUIRED';
                END IF;

                IF v_type NOT IN ('equivalent', 'narrower', 'broader', 'related', 'unmatched') THEN
                    RAISE EXCEPTION 'MAPPING_TYPE_INVALID';
                END IF;

                IF v_role NOT IN (
                    'procedure_concept', 'justifying_diagnosis',
                    'observation_concept', 'substance_concept'
                ) THEN
                    RAISE EXCEPTION 'MAPPING_ROLE_INVALID';
                END IF;

                IF EXISTS (
                    SELECT 1 FROM public.os_concept_mapping m
                     WHERE m.item_id = v_item
                       AND m.terminology_system_id = v_system
                       AND m.external_code = v_ext
                       AND m.relationship_role = v_role
                ) THEN
                    RAISE EXCEPTION 'MAPPING_DUPLICATE';
                END IF;

                INSERT INTO public.os_concept_mapping (
                    item_id, terminology_system_id, external_code, external_display,
                    mapping_type, relationship_role, clinical_rationale, review_status
                ) VALUES (
                    v_item, v_system, v_ext, v_display, v_type, v_role,
                    NULLIF(p_payload ->> 'clinical_rationale', ''), 'draft'
                )
                RETURNING * INTO v_map;

            ELSIF p_action = 'update' THEN
                SELECT * INTO v_map
                  FROM public.os_concept_mapping
                 WHERE id = p_id
                 FOR UPDATE;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'MAPPING_NOT_FOUND';
                END IF;

                v_before := to_jsonb(v_map);

                v_type := COALESCE(NULLIF(p_payload ->> 'mapping_type', ''), v_map.mapping_type);
                v_role := COALESCE(NULLIF(p_payload ->> 'relationship_role', ''), v_map.relationship_role);

                IF v_type NOT IN ('equivalent', 'narrower', 'broader', 'related', 'unmatched') THEN
                    RAISE EXCEPTION 'MAPPING_TYPE_INVALID';
                END IF;

                IF v_role NOT IN (
                    'procedure_concept', 'justifying_diagnosis',
                    'observation_concept', 'substance_concept'
                ) THEN
                    RAISE EXCEPTION 'MAPPING_ROLE_INVALID';
                END IF;

                v_item := COALESCE(NULLIF(p_payload ->> 'item_id', '')::INT, v_map.item_id);
                v_system := COALESCE(NULLIF(p_payload ->> 'terminology_system_id', '')::INT, v_map.terminology_system_id);
                v_ext := COALESCE(NULLIF(btrim(COALESCE(p_payload ->> 'external_code', '')), ''), v_map.external_code);

                IF NOT EXISTS (SELECT 1 FROM public.os_catalog_item WHERE id = v_item)
                   OR NOT EXISTS (SELECT 1 FROM public.os_terminology_system WHERE id = v_system) THEN
                    RAISE EXCEPTION 'MAPPING_ITEMS_INVALID';
                END IF;

                IF EXISTS (
                    SELECT 1 FROM public.os_concept_mapping m
                     WHERE m.id <> p_id
                       AND m.item_id = v_item
                       AND m.terminology_system_id = v_system
                       AND m.external_code = v_ext
                       AND m.relationship_role = v_role
                ) THEN
                    RAISE EXCEPTION 'MAPPING_DUPLICATE';
                END IF;

                UPDATE public.os_concept_mapping m
                   SET item_id               = v_item,
                       terminology_system_id = v_system,
                       external_code         = v_ext,
                       external_display      = COALESCE(
                           NULLIF(btrim(COALESCE(p_payload ->> 'external_display', '')), ''),
                           m.external_display),
                       mapping_type          = v_type,
                       relationship_role     = v_role,
                       clinical_rationale    = NULLIF(p_payload ->> 'clinical_rationale', ''),
                       review_status         = 'draft'
                 WHERE m.id = p_id
                RETURNING * INTO v_map;

            ELSE
                SELECT * INTO v_map
                  FROM public.os_concept_mapping
                 WHERE id = p_id
                 FOR UPDATE;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'MAPPING_NOT_FOUND';
                END IF;

                v_before := to_jsonb(v_map);

                UPDATE public.os_concept_mapping
                   SET review_status = 'deprecated'
                 WHERE id = p_id
                RETURNING * INTO v_map;
            END IF;

            v_after := to_jsonb(v_map);
            v_entity_id := v_map.id::TEXT;
            v_catalog := (
                SELECT c.code FROM public.os_catalog_item i
                  JOIN public.os_catalog c ON c.id = i.catalog_id
                 WHERE i.id = v_map.item_id
            );

            -- Metadatos: solo si la tabla existe y la operación no es baja.
            IF v_has_meta AND p_action = 'delete' THEN
                UPDATE public.os_mapping_metadata
                   SET review_status = 'deprecated', reviewed_by = NULL, reviewed_at = NULL
                 WHERE mapping_id = v_map.id;
            ELSIF v_has_meta AND p_action <> 'delete'
                  AND jsonb_typeof(p_payload -> 'metadata') = 'object' THEN
                IF COALESCE(p_payload #>> '{metadata,mapping_nature}', '') <> ''
                   AND (p_payload #>> '{metadata,mapping_nature}') NOT IN (
                       'univocal', 'multiple', 'partial', 'approximate', 'not_mappable'
                   ) THEN
                    RAISE EXCEPTION 'MAPPING_NATURE_INVALID';
                END IF;

                INSERT INTO public.os_mapping_metadata (
                    mapping_id, source_system_id, target_system_id, source_version,
                    target_version, mapping_type_ext, mapping_nature, method,
                    confidence_level, source_reference, license_reference,
                    review_status, reviewed_by, reviewed_at
                ) VALUES (
                    v_map.id,
                    NULLIF(p_payload #>> '{metadata,source_system_id}', '')::INT,
                    NULLIF(p_payload #>> '{metadata,target_system_id}', '')::INT,
                    NULLIF(p_payload #>> '{metadata,source_version}', ''),
                    NULLIF(p_payload #>> '{metadata,target_version}', ''),
                    NULLIF(p_payload #>> '{metadata,mapping_type_ext}', ''),
                    NULLIF(p_payload #>> '{metadata,mapping_nature}', ''),
                    NULLIF(p_payload #>> '{metadata,method}', ''),
                    NULLIF(p_payload #>> '{metadata,confidence_level}', ''),
                    NULLIF(p_payload #>> '{metadata,source_reference}', ''),
                    NULLIF(p_payload #>> '{metadata,license_reference}', ''),
                    'draft', NULL, NULL
                )
                ON CONFLICT (mapping_id) DO UPDATE SET
                    source_system_id  = EXCLUDED.source_system_id,
                    target_system_id  = EXCLUDED.target_system_id,
                    source_version    = EXCLUDED.source_version,
                    target_version    = EXCLUDED.target_version,
                    mapping_type_ext  = EXCLUDED.mapping_type_ext,
                    mapping_nature    = EXCLUDED.mapping_nature,
                    method            = EXCLUDED.method,
                    confidence_level  = EXCLUDED.confidence_level,
                    source_reference  = EXCLUDED.source_reference,
                    license_reference = EXCLUDED.license_reference,
                    review_status     = 'draft',
                    reviewed_by       = NULL,
                    reviewed_at       = NULL;
            END IF;
        END;

    -- -------------------------------------------------------------------------
    -- 3. Pares nomenclador ↔ OFT-PR (os_oftar_nomenclador_match)
    -- -------------------------------------------------------------------------
    ELSE
        DECLARE
            v_match public.os_oftar_nomenclador_match%ROWTYPE;
            v_src_code TEXT := NULLIF(btrim(COALESCE(p_payload ->> 'source_catalog_code', '')), '');
            v_code     TEXT := NULLIF(btrim(COALESCE(p_payload ->> 'source_code', '')), '');
            v_target   TEXT := NULLIF(btrim(COALESCE(p_payload ->> 'target_code', '')), '');
            v_basis    TEXT := NULLIF(p_payload ->> 'match_basis', '');
        BEGIN
            IF v_src_code IS NULL OR v_code IS NULL THEN
                RAISE EXCEPTION 'MATCH_KEY_REQUIRED';
            END IF;

            IF p_action = 'create' THEN
                IF v_target IS NULL OR char_length(v_target) > 30 THEN
                    RAISE EXCEPTION 'MATCH_TARGET_REQUIRED';
                END IF;

                IF v_basis IS NULL OR v_basis NOT IN (
                    'texto_identico_normalizado', 'revision_manual'
                ) THEN
                    RAISE EXCEPTION 'MATCH_BASIS_INVALID';
                END IF;

                IF NULLIF(btrim(COALESCE(p_payload ->> 'provenance', '')), '') IS NULL THEN
                    RAISE EXCEPTION 'MATCH_PROVENANCE_REQUIRED';
                END IF;

                IF EXISTS (
                    SELECT 1 FROM public.os_oftar_nomenclador_match
                     WHERE source_catalog_code = v_src_code AND source_code = v_code
                ) THEN
                    RAISE EXCEPTION 'MATCH_DUPLICATE';
                END IF;

                INSERT INTO public.os_oftar_nomenclador_match (
                    source_catalog_code, source_code, target_catalog_code, target_code,
                    match_basis, review_status, source_term, target_term, provenance, notes,
                    reviewed_at, reviewed_by
                ) VALUES (
                    v_src_code, v_code,
                    COALESCE(NULLIF(p_payload ->> 'target_catalog_code', ''), 'oftar-pr'),
                    v_target, v_basis, 'proposed',
                    NULLIF(p_payload ->> 'source_term', ''),
                    NULLIF(p_payload ->> 'target_term', ''),
                    btrim(p_payload ->> 'provenance'),
                    NULLIF(p_payload ->> 'notes', ''), NULL, NULL
                )
                RETURNING * INTO v_match;

            ELSIF p_action = 'update' THEN
                SELECT * INTO v_match
                  FROM public.os_oftar_nomenclador_match
                 WHERE source_catalog_code = v_src_code AND source_code = v_code
                 FOR UPDATE;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'MATCH_NOT_FOUND';
                END IF;

                v_before := to_jsonb(v_match);

                IF v_basis IS NOT NULL AND v_basis NOT IN (
                    'texto_identico_normalizado', 'revision_manual'
                ) THEN
                    RAISE EXCEPTION 'MATCH_BASIS_INVALID';
                END IF;

                UPDATE public.os_oftar_nomenclador_match m
                   SET target_catalog_code = COALESCE(NULLIF(p_payload ->> 'target_catalog_code', ''), m.target_catalog_code),
                       target_code         = COALESCE(v_target, m.target_code),
                       match_basis         = COALESCE(v_basis, m.match_basis),
                       source_term         = COALESCE(NULLIF(p_payload ->> 'source_term', ''), m.source_term),
                       target_term         = COALESCE(NULLIF(p_payload ->> 'target_term', ''), m.target_term),
                       provenance          = COALESCE(
                           NULLIF(btrim(COALESCE(p_payload ->> 'provenance', '')), ''), m.provenance),
                       notes               = COALESCE(NULLIF(p_payload ->> 'notes', ''), m.notes),
                       review_status       = 'proposed',
                       reviewed_at         = NULL,
                       reviewed_by         = NULL
                 WHERE m.source_catalog_code = v_src_code AND m.source_code = v_code
                RETURNING * INTO v_match;

            ELSE
                SELECT * INTO v_match
                  FROM public.os_oftar_nomenclador_match
                 WHERE source_catalog_code = v_src_code AND source_code = v_code
                 FOR UPDATE;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'MATCH_NOT_FOUND';
                END IF;

                v_before := to_jsonb(v_match);

                UPDATE public.os_oftar_nomenclador_match m
                   SET review_status = 'rejected',
                       reviewed_at = now(),
                       reviewed_by = left(btrim(p_actor_email), 120)
                 WHERE m.source_catalog_code = v_src_code AND m.source_code = v_code
                RETURNING * INTO v_match;
            END IF;

            v_after := to_jsonb(v_match);
            v_entity_id := v_match.source_catalog_code || ':' || v_match.source_code;
            v_catalog := v_match.source_catalog_code;
        END;
    END IF;

    RETURN jsonb_build_object(
        'entity', p_entity,
        'action', p_action,
        'id', v_entity_id,
        'catalog_code', v_catalog,
        'before', v_before,
        'after', v_after
    );
END
$$;

REVOKE ALL PRIVILEGES ON FUNCTION public.os_relation_admin_write(
    TEXT, TEXT, BIGINT, JSONB, TEXT, BIGINT, TEXT
) FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.os_relation_admin_write('
             || 'TEXT, TEXT, BIGINT, JSONB, TEXT, BIGINT, TEXT'
             || ') TO origen_admin';
    END IF;
END
$$;

COMMIT;

-- Verificación posterior (READ ONLY):
-- SELECT has_function_privilege('origen_admin',
--   'public.os_relation_admin_write(text,text,bigint,jsonb,text,bigint,text)', 'EXECUTE');
-- SELECT review_status, count(*) FROM public.os_catalog_relation GROUP BY 1 ORDER BY 1;
-- SELECT review_status, count(*) FROM public.os_concept_mapping GROUP BY 1 ORDER BY 1;
-- SELECT review_status, count(*) FROM public.os_oftar_nomenclador_match GROUP BY 1 ORDER BY 1;
