-- FASE 4 — Gobernanza y auditoría (propuesta, NO EJECUTAR sin aprobación)
-- Requiere fase1_infraestructura.sql y backup verificado.
-- No crea actores: la identidad de auditores sigue pendiente de decisión.

BEGIN;

CREATE TABLE IF NOT EXISTS os_governance_request (
    id BIGSERIAL PRIMARY KEY,
    request_type VARCHAR(60) NOT NULL,
    subject_type VARCHAR(60) NOT NULL,
    subject_id TEXT NOT NULL,
    proposed_change TEXT NOT NULL,
    source_reference TEXT,
    license_reference TEXT,
    requested_by TEXT,
    review_status VARCHAR(30) NOT NULL DEFAULT 'draft'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_os_governance_request_subject
        UNIQUE (request_type, subject_type, subject_id, proposed_change)
);

CREATE INDEX IF NOT EXISTS idx_os_governance_request_status
    ON os_governance_request (review_status);

CREATE TABLE IF NOT EXISTS os_governance_review (
    id BIGSERIAL PRIMARY KEY,
    request_id BIGINT NOT NULL REFERENCES os_governance_request(id) ON DELETE CASCADE,
    reviewer_actor TEXT,
    reviewer_role TEXT,
    outcome VARCHAR(30) NOT NULL DEFAULT 'unreviewed'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    rationale TEXT,
    reviewed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS os_governance_decision (
    id BIGSERIAL PRIMARY KEY,
    review_id BIGINT NOT NULL REFERENCES os_governance_review(id) ON DELETE CASCADE,
    decision_code VARCHAR(60) NOT NULL,
    approved_by TEXT,
    approved_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    effective_from DATE,
    evidence_reference TEXT NOT NULL,
    CONSTRAINT uq_os_governance_decision UNIQUE (review_id, decision_code)
);

COMMENT ON COLUMN os_governance_decision.evidence_reference IS
    'Referencia obligatoria al acta o evidencia de aprobación; no se acepta aprobación implícita.';

CREATE TABLE IF NOT EXISTS os_audit_log (
    id BIGSERIAL PRIMARY KEY,
    entity_type VARCHAR(80) NOT NULL,
    entity_id TEXT NOT NULL,
    action VARCHAR(40) NOT NULL,
    actor TEXT,
    request_id BIGINT REFERENCES os_governance_request(id) ON DELETE SET NULL,
    before_state JSONB,
    after_state JSONB,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_os_audit_log_entity
    ON os_audit_log (entity_type, entity_id, occurred_at DESC);

CREATE OR REPLACE FUNCTION os_governance_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_entity TEXT := TG_TABLE_NAME;
    v_id TEXT;
    v_action TEXT;
    v_before JSONB;
    v_after JSONB;
    v_request BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id := OLD.id::text;
        v_action := 'delete';
        v_before := to_jsonb(OLD);
        v_after := NULL;
        v_request := NULL;
    ELSIF TG_OP = 'UPDATE' THEN
        v_id := NEW.id::text;
        v_action := 'update';
        v_before := to_jsonb(OLD);
        v_after := to_jsonb(NEW);
        v_request := NULL;
    ELSE
        v_id := NEW.id::text;
        v_action := 'insert';
        v_before := NULL;
        v_after := to_jsonb(NEW);
        v_request := NULL;
    END IF;

    IF v_entity = 'os_governance_review' THEN
        v_request := COALESCE(NEW.request_id, OLD.request_id);
    ELSIF v_entity = 'os_governance_decision' THEN
        SELECT r.request_id INTO v_request
          FROM os_governance_review r
         WHERE r.id = COALESCE(NEW.review_id, OLD.review_id);
    END IF;

    INSERT INTO os_audit_log
        (entity_type, entity_id, action, actor, request_id, before_state, after_state)
    VALUES
        (v_entity, v_id, v_action,
         COALESCE(
             v_after->>'approved_by',
             v_after->>'reviewer_actor',
             v_after->>'requested_by',
             current_user::text
         ),
         v_request, v_before, v_after);

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_os_governance_request_audit ON os_governance_request;
CREATE TRIGGER trg_os_governance_request_audit
    AFTER INSERT OR UPDATE OR DELETE ON os_governance_request
    FOR EACH ROW EXECUTE FUNCTION os_governance_audit_trigger();

DROP TRIGGER IF EXISTS trg_os_governance_review_audit ON os_governance_review;
CREATE TRIGGER trg_os_governance_review_audit
    AFTER INSERT OR UPDATE OR DELETE ON os_governance_review
    FOR EACH ROW EXECUTE FUNCTION os_governance_audit_trigger();

DROP TRIGGER IF EXISTS trg_os_governance_decision_audit ON os_governance_decision;
CREATE TRIGGER trg_os_governance_decision_audit
    AFTER INSERT OR UPDATE OR DELETE ON os_governance_decision
    FOR EACH ROW EXECUTE FUNCTION os_governance_audit_trigger();

COMMIT;

-- Verificación sugerida (no ejecutar automáticamente):
-- SELECT count(*) AS requests FROM os_governance_request;
-- SELECT count(*) AS audit_events FROM os_audit_log;
