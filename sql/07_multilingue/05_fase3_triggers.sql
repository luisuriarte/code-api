-- =============================================================================
-- FASE 3 · Triggers de consistencia, invalidación y auditoría
-- =============================================================================
-- Entorno de PRUEBAS. Aditivo: CREATE OR REPLACE FUNCTION / TRIGGER.
-- NO contiene DROP TRIGGER, DROP FUNCTION, TRUNCATE ni DELETE de datos.
-- Ejecutar DENTRO de transacción.
-- Fuentes: modelo §4.1-§4.4, §5.3-§5.5; D-06, D-10, D-14, D-21, D-31,
--          D-32, D-35, D-41; plan Fase 3.
--
-- Cobertura de auditoría al cierre de esta fase: 7 tablas
--   os_catalog_item_version, os_catalog_term, os_localized_text,
--   os_field_review, snomed_descriptions, cie10_descriptions,
--   os_concept_mapping.
-- loinc_localized_text NO se audita aquí: se incorpora en Fase 5 (D-29).
-- os_concept_mapping NO tiene columna language_code: se registra
--   'undet' en el evento (cabe en VARCHAR(10)), sin inventar un idioma.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Helper: valor actual de un campo clínico para calcular el hash individual
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_localized_field_value(
    p_table TEXT, p_id BIGINT, p_field TEXT)
RETURNS TEXT LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_sql TEXT;
    v_val TEXT;
BEGIN
    IF p_table NOT IN (
        'os_catalog_item_version', 'os_catalog_term', 'os_localized_text',
        'os_field_review', 'snomed_descriptions', 'cie10_descriptions',
        'os_concept_mapping') THEN
        RETURN NULL;
    END IF;
    BEGIN
        v_sql := format('SELECT %I::text FROM %I WHERE id = $1', p_field, p_table);
        EXECUTE v_sql INTO v_val USING p_id;
    EXCEPTION
        WHEN undefined_column OR undefined_table THEN
            RETURN NULL;
    END;
    RETURN v_val;
END $$;

-- ---------------------------------------------------------------------------
-- Hash + invalidación de aprobación (D-31, D-32, D-41)
-- TG_ARGV[0] = columnas en orden fijo, separadas por coma.
-- El centinela '' (Fase 4) solo asigna el hash real: NO invalida una aprobación
-- heredada, porque ese hash no era una evidencia de contenido.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_content_hash_and_invalidate() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_cols    TEXT[] := string_to_array(TG_ARGV[0], ',');
    v_col     TEXT;
    v_data    JSONB := to_jsonb(NEW);
    v_parts   TEXT := '';
    v_hash    TEXT;
    v_covered TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- D-41: en la fila de versión, el hash agregado excluye los campos que ya
    -- tienen revisión individual en os_field_review.
    IF TG_TABLE_NAME = 'os_catalog_item_version' THEN
        SELECT COALESCE(array_agg(field_name), ARRAY[]::TEXT[])
          INTO v_covered
          FROM os_field_review
         WHERE target_table = 'os_catalog_item_version'
           AND target_id = NEW.id;
    END IF;

    FOREACH v_col IN ARRAY v_cols LOOP
        v_col := btrim(v_col);
        IF NOT (v_col = ANY (v_covered)) THEN
            v_parts := v_parts || COALESCE(v_data->>v_col, '') || E'\x1f';
        END IF;
    END LOOP;
    v_hash := md5(v_parts);

    IF TG_OP = 'INSERT' THEN
        NEW.content_hash := v_hash;
        RETURN NEW;
    END IF;

    IF OLD.content_hash IS DISTINCT FROM v_hash THEN
        NEW.content_hash := v_hash;   -- siempre se actualiza el hash
        IF OLD.content_hash IS DISTINCT FROM '' THEN
            IF TG_TABLE_NAME = 'os_concept_mapping' THEN
                -- Su CHECK no admite 'unreviewed': se usa 'draft'.
                NEW.review_status := 'draft';
            ELSIF v_data ? 'review_status' THEN
                NEW.review_status := 'unreviewed';
            END IF;
            IF v_data ? 'reviewed_by' THEN
                NEW.reviewed_by := NULL;
                NEW.reviewed_at := NULL;
            END IF;
            IF v_data ? 'updated_at' THEN
                NEW.updated_at := now();
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END $$;

-- ---------------------------------------------------------------------------
-- Hash individual de os_field_review (D-31, D-41 field_individual)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_field_review_hash() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_val  TEXT;
    v_hash TEXT;
BEGIN
    v_val := fn_localized_field_value(
        NEW.target_table, NEW.target_id, NEW.field_name);
    v_hash := md5(COALESCE(v_val, '') || E'\x1f' ||
                  NEW.language_code || E'\x1f' ||
                  COALESCE(NEW.source_reference, ''));

    IF TG_OP = 'INSERT' THEN
        NEW.content_hash := v_hash;
    ELSIF OLD.content_hash IS DISTINCT FROM v_hash
          AND OLD.content_hash IS DISTINCT FROM '' THEN
        NEW.content_hash := v_hash;
        NEW.review_status := 'unreviewed';
        NEW.reviewed_by := NULL;
        NEW.reviewed_at := NULL;
    ELSE
        NEW.content_hash := v_hash;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END $$;

-- ---------------------------------------------------------------------------
-- Crear/deprecar una revisión individual recalcula el agregado de la fila
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_field_review_sync() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_table TEXT;
    v_id    BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_table := OLD.target_table;
        v_id := OLD.target_id;
    ELSE
        v_table := NEW.target_table;
        v_id := NEW.target_id;
    END IF;

    IF v_table = 'os_catalog_item_version' THEN
        -- Dispara trg_content_hash_and_invalidate: recalcula el hashes agregado
        -- sin los campos cubiertos e invalida una sola vez si cambió.
        UPDATE os_catalog_item_version SET updated_at = now() WHERE id = v_id;
    END IF;
    RETURN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Auditoría transaccional genérica (D-10, D-23, D-31, D-32)
-- TG_ARGV[0] = field_name del evento; [1] = columna de valor; [2] = ámbito D-41.
-- SESSION_USER es evidencia de respaldo; el autor se toma de app.actor_id /
-- app.importer_run_id fijados por la aplicación/importador en la transacción.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_audit_content() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_table      TEXT := TG_TABLE_NAME;
    v_field      TEXT := COALESCE(TG_ARGV[0], 'content');
    v_value_col  TEXT := COALESCE(TG_ARGV[1], 'content_hash');
    v_scope      TEXT := COALESCE(TG_ARGV[2], 'field_individual');
    v_data       JSONB;
    v_old_data   JSONB;
    v_id         BIGINT;
    v_lang       TEXT;
    v_prev       TEXT;
    v_new        TEXT;
    v_old_hash   TEXT;
    v_new_hash   TEXT;
    v_hash_chg   BOOLEAN := FALSE;
    v_old_status TEXT;
    v_new_status TEXT;
    v_status_chg BOOLEAN := FALSE;
    v_actor      VARCHAR(16);
    v_app        VARCHAR(80);
    v_imp        VARCHAR(80);
    v_identified BOOLEAN;
    v_session    VARCHAR(80) := (SESSION_USER)::VARCHAR(80);
    v_tx         BIGINT := txid_current();
    v_notes      TEXT;
BEGIN
    v_notes := 'ambito=' || v_scope || ';campos=' || v_field;

    IF TG_OP = 'DELETE' THEN
        v_old_data := to_jsonb(OLD);
        v_data := v_old_data;
        v_id := CASE WHEN v_table = 'os_field_review'
                     THEN (v_old_data->>'target_id')::BIGINT
                     ELSE (v_old_data->>'id')::BIGINT END;
        v_lang := COALESCE(v_old_data->>'language_code', 'undet');
        v_prev := v_old_data->>v_value_col;
        v_old_status := v_old_data->>'review_status';
    ELSE
        v_data := to_jsonb(NEW);
        v_id := CASE WHEN v_table = 'os_field_review'
                     THEN (v_data->>'target_id')::BIGINT
                     ELSE (v_data->>'id')::BIGINT END;
        v_lang := COALESCE(v_data->>'language_code', 'undet');
        v_new := v_data->>v_value_col;
        v_new_status := v_data->>'review_status';
        IF TG_OP = 'UPDATE' THEN
            v_old_data := to_jsonb(OLD);
            v_prev := v_old_data->>v_value_col;
            v_old_hash := v_old_data->>'content_hash';
            v_new_hash := v_data->>'content_hash';
            v_hash_chg := (v_old_hash IS DISTINCT FROM v_new_hash)
                          AND (v_old_hash IS DISTINCT FROM '');
            v_old_status := v_old_data->>'review_status';
            v_status_chg := (v_old_status IS DISTINCT FROM v_new_status);
        END IF;
    END IF;

    v_app := NULLIF(current_setting('app.actor_id', TRUE), '');
    v_imp := NULLIF(current_setting('app.importer_run_id', TRUE), '');
    v_actor := NULLIF(current_setting('app.actor_type', TRUE), '');
    IF v_actor IS NULL OR v_actor NOT IN ('user','importer','system','db_role') THEN
        v_actor := CASE WHEN v_app IS NOT NULL THEN 'user'
                        WHEN v_imp IS NOT NULL THEN 'importer'
                        ELSE 'db_role' END;
    END IF;
    v_identified := (v_app IS NOT NULL OR v_imp IS NOT NULL);

    IF TG_OP = 'INSERT' THEN
        INSERT INTO os_translation_review (
            target_table, target_id, field_name, language_code, event_type,
            action, previous_value, new_value, review_status, actor_type,
            application_user_id, importer_run_id, "session_user",
            actor_identified, transaction_id, notes)
        VALUES (
            v_table, v_id, v_field, v_lang, 'content_changed', 'create',
            NULL, v_new, v_new_status, v_actor, v_app, v_imp, v_session,
            v_identified, v_tx, v_notes);

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO os_translation_review (
            target_table, target_id, field_name, language_code, event_type,
            action, previous_value, new_value, review_status, actor_type,
            application_user_id, importer_run_id, "session_user",
            actor_identified, transaction_id, notes)
        VALUES (
            v_table, v_id, v_field, v_lang, 'deprecate', 'deprecate',
            v_prev, NULL, v_old_status, v_actor, v_app, v_imp, v_session,
            v_identified, v_tx, v_notes);

    ELSIF v_hash_chg THEN
        INSERT INTO os_translation_review (
            target_table, target_id, field_name, language_code, event_type,
            action, previous_value, new_value, review_status, actor_type,
            application_user_id, importer_run_id, "session_user",
            actor_identified, transaction_id, notes)
        VALUES (
            v_table, v_id, v_field, v_lang, 'content_changed', 'update',
            v_prev, v_new, v_new_status, v_actor, v_app, v_imp, v_session,
            v_identified, v_tx, v_notes);

        INSERT INTO os_translation_review (
            target_table, target_id, field_name, language_code, event_type,
            action, previous_value, new_value, review_status, actor_type,
            application_user_id, importer_run_id, "session_user",
            actor_identified, transaction_id, notes)
        VALUES (
            v_table, v_id, v_field, v_lang, 'approval_invalidated', 'invalidate',
            v_old_hash, v_new_hash, v_new_status, v_actor, v_app, v_imp,
            v_session, v_identified, v_tx, v_notes);

    ELSIF v_status_chg THEN
        INSERT INTO os_translation_review (
            target_table, target_id, field_name, language_code, event_type,
            action, previous_value, new_value, review_status, actor_type,
            application_user_id, importer_run_id, "session_user",
            actor_identified, transaction_id, notes)
        VALUES (
            v_table, v_id, v_field, v_lang, 'review_state_changed',
            CASE WHEN v_new_status IN ('approved','reviewed') THEN 'approve'
                 ELSE 'update' END,
            v_old_status, v_new_status, v_new_status, v_actor, v_app, v_imp,
            v_session, v_identified, v_tx, v_notes);

        IF v_new_status = 'approved' THEN
            INSERT INTO os_translation_review (
                target_table, target_id, field_name, language_code, event_type,
                action, previous_value, new_value, review_status, actor_type,
                application_user_id, importer_run_id, "session_user",
                actor_identified, transaction_id, notes)
            VALUES (
                v_table, v_id, v_field, v_lang, 'approval_granted', 'approve',
                v_old_status, v_new_status, v_new_status, v_actor, v_app, v_imp,
                v_session, v_identified, v_tx, v_notes);
        END IF;
    ELSE
        INSERT INTO os_translation_review (
            target_table, target_id, field_name, language_code, event_type,
            action, previous_value, new_value, review_status, actor_type,
            application_user_id, importer_run_id, "session_user",
            actor_identified, transaction_id, notes)
        VALUES (
            v_table, v_id, v_field, v_lang, 'content_changed', 'update',
            v_prev, v_new, v_new_status, v_actor, v_app, v_imp, v_session,
            v_identified, v_tx, v_notes);
    END IF;
    RETURN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Validación polimórfica de os_localized_text (D-06, D-14, D-35)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_localized_text_validate() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_existe   BOOLEAN;
    v_campo_ok BOOLEAN;
    v_catalog  INT;
BEGIN
    IF TG_OP = 'UPDATE'
       AND (NEW.entity_type IS DISTINCT FROM OLD.entity_type
            OR NEW.entity_id IS DISTINCT FROM OLD.entity_id) THEN
        RAISE EXCEPTION
            'entity_type/entity_id son inmutables (D-14). Para mover: baja + alta auditada.';
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtext(NEW.entity_type || ':' || NEW.entity_id::TEXT));
    IF NEW.scope_release_id IS NOT NULL THEN
        PERFORM pg_advisory_xact_lock(
            hashtext('release:' || NEW.scope_release_id::TEXT));
    END IF;

    v_existe := CASE NEW.entity_type
        WHEN 'catalog'            THEN EXISTS (SELECT 1 FROM os_catalog WHERE id = NEW.entity_id)
        WHEN 'catalog_category'   THEN EXISTS (SELECT 1 FROM os_catalog_category WHERE id = NEW.entity_id)
        WHEN 'catalog_release'    THEN EXISTS (SELECT 1 FROM os_catalog_release WHERE id = NEW.entity_id)
        WHEN 'fee_schedule'       THEN EXISTS (SELECT 1 FROM os_fee_schedule WHERE id = NEW.entity_id)
        WHEN 'pricing_unit'       THEN EXISTS (SELECT 1 FROM os_pricing_unit WHERE id = NEW.entity_id)
        WHEN 'terminology_system' THEN EXISTS (SELECT 1 FROM os_terminology_system WHERE id = NEW.entity_id)
        WHEN 'concept_mapping'    THEN EXISTS (SELECT 1 FROM os_concept_mapping WHERE id = NEW.entity_id)
        WHEN 'nomenclador'        THEN EXISTS (SELECT 1 FROM nomencladores_argentina WHERE id = NEW.entity_id)
        WHEN 'vademecum'          THEN EXISTS (SELECT 1 FROM vademecum_comercial WHERE id = NEW.entity_id)
        WHEN 'substance'          THEN EXISTS (SELECT 1 FROM os_substance WHERE id = NEW.entity_id)
        WHEN 'medicinal_product'  THEN EXISTS (SELECT 1 FROM os_medicinal_product WHERE id = NEW.entity_id)
        WHEN 'product_package'    THEN EXISTS (SELECT 1 FROM os_product_package WHERE id = NEW.entity_id)
        ELSE FALSE END;

    IF NOT v_existe THEN
        RAISE EXCEPTION
            'Entidad inexistente: % id=% (os_localized_text no es FK nativa, D-14).',
            NEW.entity_type, NEW.entity_id;
    END IF;

    v_campo_ok := CASE NEW.entity_type
        WHEN 'catalog'            THEN NEW.field_name IN ('name','short_name','description')
        WHEN 'catalog_category'   THEN NEW.field_name IN ('name')
        WHEN 'catalog_release'    THEN NEW.field_name IN ('official_norm_reference')
        WHEN 'fee_schedule'       THEN NEW.field_name IN ('name')
        WHEN 'pricing_unit'       THEN NEW.field_name IN ('name','description','organization')
        WHEN 'terminology_system' THEN NEW.field_name IN ('name')
        WHEN 'concept_mapping'    THEN NEW.field_name IN ('external_display','clinical_rationale')
        WHEN 'nomenclador'        THEN NEW.field_name IN ('capitulo','descripcion')
        WHEN 'vademecum'          THEN NEW.field_name IN ('monodroga','nombre_comercial','presentacion')
        WHEN 'substance'          THEN NEW.field_name IN ('name')
        WHEN 'medicinal_product'  THEN NEW.field_name IN ('brand_name','pharmacological_action')
        WHEN 'product_package'    THEN NEW.field_name IN ('presentation_text','dosage_form')
        ELSE FALSE END;

    IF NOT v_campo_ok THEN
        RAISE EXCEPTION
            'field_name=% no permitido para entity_type=% (modelo §5.3).',
            NEW.field_name, NEW.entity_type;
    END IF;

    IF NEW.scope_release_id IS NOT NULL THEN
        IF NEW.entity_type IN (
            'substance','medicinal_product','product_package',
            'nomenclador','vademecum','pricing_unit','terminology_system') THEN
            RAISE EXCEPTION
                'scope_release_id debe ser NULL para % (sin ámbito de catálogo, D-06).',
                NEW.entity_type;
        END IF;

        v_catalog := CASE NEW.entity_type
            WHEN 'catalog'          THEN NEW.entity_id::INT
            WHEN 'catalog_category' THEN (SELECT catalog_id FROM os_catalog_category WHERE id = NEW.entity_id)
            WHEN 'catalog_release'  THEN (SELECT catalog_id FROM os_catalog_release WHERE id = NEW.entity_id)
            WHEN 'fee_schedule'     THEN (SELECT catalog_id FROM os_fee_schedule WHERE id = NEW.entity_id)
            WHEN 'concept_mapping'  THEN (SELECT i.catalog_id
                                            FROM os_concept_mapping m
                                            JOIN os_catalog_item i ON i.id = m.item_id
                                           WHERE m.id = NEW.entity_id)
        END;

        IF v_catalog IS NULL OR NOT EXISTS (
            SELECT 1 FROM os_catalog_release
             WHERE id = NEW.scope_release_id AND catalog_id = v_catalog) THEN
            RAISE EXCEPTION
                'El release % no pertenece al catálogo de % id=% (D-06).',
                NEW.scope_release_id, NEW.entity_type, NEW.entity_id;
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        NEW.updated_at := now();
    END IF;
    RETURN NEW;
END $$;

-- ---------------------------------------------------------------------------
-- RESTRICT de borrado de entidades con traducciones (D-14, D-35)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_entity_localized_restrict() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_tipo TEXT := TG_ARGV[0];
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(v_tipo || ':' || OLD.id::TEXT));
    IF EXISTS (SELECT 1 FROM os_localized_text
                WHERE entity_type = v_tipo AND entity_id = OLD.id::BIGINT) THEN
        RAISE EXCEPTION
            'No se puede eliminar % id=%: existen traducciones (RESTRICT, D-14).',
            v_tipo, OLD.id;
    END IF;
    RETURN OLD;
END $$;

-- ---------------------------------------------------------------------------
-- Instalación de triggers
-- ---------------------------------------------------------------------------

-- os_catalog_item_version: hash row_shared de los seis campos (D-41)
CREATE OR REPLACE TRIGGER trg_civ_hash
    BEFORE INSERT OR UPDATE ON os_catalog_item_version
    FOR EACH ROW EXECUTE FUNCTION trg_content_hash_and_invalidate(
        'preferred_term,definition,clinical_criteria,short_definition,lay_terms,clinical_scope,language_code,source_reference');
CREATE OR REPLACE TRIGGER trg_civ_audit
    AFTER INSERT OR UPDATE OR DELETE ON os_catalog_item_version
    FOR EACH ROW EXECUTE FUNCTION trg_audit_content('row_shared','content_hash','row_shared');

-- os_catalog_term: consistencia de idioma y rechazo de 'preferred' nuevo (§4.2)
CREATE OR REPLACE FUNCTION trg_catalog_term_validate() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_lang VARCHAR(10);
BEGIN
    IF NEW.term_type = 'preferred'
       AND (TG_OP = 'INSERT' OR OLD.term_type IS DISTINCT FROM NEW.term_type) THEN
        RAISE EXCEPTION
            'term_type=preferred solo se gestiona en preferred_term de la versión (§4.2).';
    END IF;
    IF TG_OP = 'INSERT' OR OLD.language_code IS DISTINCT FROM NEW.language_code THEN
        SELECT language_code INTO v_lang
          FROM os_catalog_item_version WHERE id = NEW.item_version_id;
        IF v_lang IS NULL OR v_lang IS DISTINCT FROM NEW.language_code THEN
            RAISE EXCEPTION
                'El idioma del término (%) debe igualar el de la versión (%) (§4.2).',
                NEW.language_code, v_lang;
        END IF;
    END IF;
    IF TG_OP = 'UPDATE' THEN
        NEW.updated_at := now();
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_cterm_validate
    BEFORE INSERT OR UPDATE ON os_catalog_term
    FOR EACH ROW EXECUTE FUNCTION trg_catalog_term_validate();
CREATE OR REPLACE TRIGGER trg_cterm_hash
    BEFORE INSERT OR UPDATE ON os_catalog_term
    FOR EACH ROW EXECUTE FUNCTION trg_content_hash_and_invalidate(
        'term,language_code,source_reference');
CREATE OR REPLACE TRIGGER trg_cterm_audit
    AFTER INSERT OR UPDATE OR DELETE ON os_catalog_term
    FOR EACH ROW EXECUTE FUNCTION trg_audit_content('term','term','field_individual');

-- os_localized_text
CREATE OR REPLACE TRIGGER trg_olt_hash
    BEFORE INSERT OR UPDATE ON os_localized_text
    FOR EACH ROW EXECUTE FUNCTION trg_content_hash_and_invalidate(
        'value,language_code,source_reference');
CREATE OR REPLACE TRIGGER trg_olt_validate
    BEFORE INSERT OR UPDATE ON os_localized_text
    FOR EACH ROW EXECUTE FUNCTION trg_localized_text_validate();
CREATE OR REPLACE TRIGGER trg_olt_audit
    AFTER INSERT OR UPDATE OR DELETE ON os_localized_text
    FOR EACH ROW EXECUTE FUNCTION trg_audit_content('value','value','field_individual');

-- os_field_review
CREATE OR REPLACE TRIGGER trg_fr_hash
    BEFORE INSERT OR UPDATE ON os_field_review
    FOR EACH ROW EXECUTE FUNCTION trg_field_review_hash();
CREATE OR REPLACE TRIGGER trg_fr_audit
    AFTER INSERT OR UPDATE OR DELETE ON os_field_review
    FOR EACH ROW EXECUTE FUNCTION trg_audit_content('field_name','content_hash','field_individual');
CREATE OR REPLACE TRIGGER trg_fr_sync
    AFTER INSERT OR DELETE OR UPDATE OF field_name, target_id, target_table, language_code
    ON os_field_review
    FOR EACH ROW EXECUTE FUNCTION trg_field_review_sync();

-- snomed_descriptions / cie10_descriptions
CREATE OR REPLACE TRIGGER trg_snomed_hash
    BEFORE INSERT OR UPDATE ON snomed_descriptions
    FOR EACH ROW EXECUTE FUNCTION trg_content_hash_and_invalidate(
        'term,language_code,rf2_language_tag,source_reference');
CREATE OR REPLACE TRIGGER trg_snomed_audit
    AFTER INSERT OR UPDATE OR DELETE ON snomed_descriptions
    FOR EACH ROW EXECUTE FUNCTION trg_audit_content('term','term','field_individual');

CREATE OR REPLACE TRIGGER trg_cie10_hash
    BEFORE INSERT OR UPDATE ON cie10_descriptions
    FOR EACH ROW EXECUTE FUNCTION trg_content_hash_and_invalidate(
        'descripcion,language_code,source_reference');
CREATE OR REPLACE TRIGGER trg_cie10_audit
    AFTER INSERT OR UPDATE OR DELETE ON cie10_descriptions
    FOR EACH ROW EXECUTE FUNCTION trg_audit_content('descripcion','descripcion','field_individual');

-- os_concept_mapping (sin language_code: se registra 'undet', VARCHAR(10))
CREATE OR REPLACE TRIGGER trg_ocm_hash
    BEFORE INSERT OR UPDATE ON os_concept_mapping
    FOR EACH ROW EXECUTE FUNCTION trg_content_hash_and_invalidate(
        'external_display,clinical_rationale,source_reference');
CREATE OR REPLACE TRIGGER trg_ocm_audit
    AFTER INSERT OR UPDATE OR DELETE ON os_concept_mapping
    FOR EACH ROW EXECUTE FUNCTION trg_audit_content('external_display','external_display','field_individual');

-- RESTRICT en las 12 entidades del modelo §5.3
CREATE OR REPLACE TRIGGER trg_restrict_catalog
    BEFORE DELETE ON os_catalog
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('catalog');
CREATE OR REPLACE TRIGGER trg_restrict_catalog_category
    BEFORE DELETE ON os_catalog_category
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('catalog_category');
CREATE OR REPLACE TRIGGER trg_restrict_catalog_release
    BEFORE DELETE ON os_catalog_release
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('catalog_release');
CREATE OR REPLACE TRIGGER trg_restrict_fee_schedule
    BEFORE DELETE ON os_fee_schedule
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('fee_schedule');
CREATE OR REPLACE TRIGGER trg_restrict_pricing_unit
    BEFORE DELETE ON os_pricing_unit
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('pricing_unit');
CREATE OR REPLACE TRIGGER trg_restrict_terminology_system
    BEFORE DELETE ON os_terminology_system
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('terminology_system');
CREATE OR REPLACE TRIGGER trg_restrict_concept_mapping
    BEFORE DELETE ON os_concept_mapping
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('concept_mapping');
CREATE OR REPLACE TRIGGER trg_restrict_nomenclador
    BEFORE DELETE ON nomencladores_argentina
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('nomenclador');
CREATE OR REPLACE TRIGGER trg_restrict_vademecum
    BEFORE DELETE ON vademecum_comercial
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('vademecum');
CREATE OR REPLACE TRIGGER trg_restrict_substance
    BEFORE DELETE ON os_substance
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('substance');
CREATE OR REPLACE TRIGGER trg_restrict_medicinal_product
    BEFORE DELETE ON os_medicinal_product
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('medicinal_product');
CREATE OR REPLACE TRIGGER trg_restrict_product_package
    BEFORE DELETE ON os_product_package
    FOR EACH ROW EXECUTE FUNCTION trg_entity_localized_restrict('product_package');

COMMIT;

-- Fin de Fase 3 · triggers.
