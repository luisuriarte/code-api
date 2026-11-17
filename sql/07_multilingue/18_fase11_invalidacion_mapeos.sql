-- =============================================================================
-- FASE 11 · Invalidación D-31 de revisiones D-19 por cambio de contenido
-- =============================================================================
-- Entorno de PRUEBAS. Aditivo: CREATE OR REPLACE FUNCTION / TRIGGER.
-- NO contiene DROP TRIGGER, DROP FUNCTION, TRUNCATE ni DELETE de datos.
-- Ejecutar DENTRO de transacción. Válido en psql y DBeaver-CE.
--
-- El trigger existente de Fase 3 (trg_ocm_hash) ya recalcula el content_hash de
-- os_concept_mapping y marca la fila como 'draft' cuando cambia el texto. Su
-- ámbito es la fila; NO retira la revisión individual de os_field_review.
-- Este trigger complementario sí la retira, en la misma transacción, y deja el
-- evento approval_invalidated con identidad de aplicación/importador.
--
-- Solo se invalida el campo cuyo texto cambió; un cambio de source_reference
-- invalida ambos porque el hash individual lo incluye (D-31, D-41).
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION trg_ocm_invalidate_field_reviews() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_app         VARCHAR(80);
    v_imp         VARCHAR(80);
    v_actor       VARCHAR(16);
    v_identified  BOOLEAN;
BEGIN
    IF TG_OP <> 'UPDATE' THEN
        RETURN NULL;
    END IF;

    v_app := NULLIF(current_setting('app.actor_id', TRUE), '');
    v_imp := NULLIF(current_setting('app.importer_run_id', TRUE), '');
    v_actor := NULLIF(current_setting('app.actor_type', TRUE), '');

    IF v_actor IS NULL OR v_actor NOT IN ('user', 'importer', 'system', 'db_role') THEN
        v_actor := CASE WHEN v_app IS NOT NULL THEN 'user'
                        WHEN v_imp IS NOT NULL THEN 'importer'
                        ELSE 'db_role' END;
    END IF;
    v_identified := (v_app IS NOT NULL OR v_imp IS NOT NULL);

    WITH invalidadas AS (
        UPDATE os_field_review f
           SET review_status = 'unreviewed',
               reviewed_by = NULL,
               reviewed_at = NULL,
               updated_at = now()
         WHERE f.target_table = 'os_concept_mapping'
           AND f.target_id = NEW.id
           AND f.review_status IN ('approved', 'reviewed')
           AND (
                (f.field_name = 'external_display'
                 AND (OLD.external_display IS DISTINCT FROM NEW.external_display
                      OR OLD.source_reference IS DISTINCT FROM NEW.source_reference))
                OR
                (f.field_name = 'clinical_rationale'
                 AND (OLD.clinical_rationale IS DISTINCT FROM NEW.clinical_rationale
                      OR OLD.source_reference IS DISTINCT FROM NEW.source_reference))
           )
        RETURNING f.target_id, f.field_name, f.language_code
    )
    INSERT INTO os_translation_review (
        target_table, target_id, field_name, language_code, event_type, action,
        previous_value, new_value, review_status, actor_type,
        application_user_id, importer_run_id, "session_user", actor_identified,
        transaction_id, notes
    )
    SELECT 'os_field_review',
           i.target_id,
           i.field_name,
           i.language_code,
           'approval_invalidated',
           'invalidate',
           'approved',
           'unreviewed',
           'unreviewed',
           v_actor,
           v_app,
           v_imp,
           SESSION_USER::VARCHAR(80),
           v_identified,
           txid_current(),
           'D-31: cambió el texto/referencia de os_concept_mapping; se retira la aprobación D-19 de este campo.'
      FROM invalidadas i;

    RETURN NULL;
END $$;

CREATE OR REPLACE TRIGGER trg_ocm_invalidate_fr
    AFTER UPDATE OF external_display, clinical_rationale, source_reference
    ON os_concept_mapping
    FOR EACH ROW
    EXECUTE FUNCTION trg_ocm_invalidate_field_reviews();

COMMIT;

SELECT '=== Fase 11 · Trigger de invalidación instalado ===' AS seccion;
SELECT tgname, tgenabled
  FROM pg_trigger
 WHERE tgrelid = to_regclass('public.os_concept_mapping')
   AND tgname = 'trg_ocm_invalidate_fr';

-- Fin de Fase 11 · invalidación de aprobaciones D-19.
