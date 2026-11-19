-- =============================================================================
-- FASE 5 (§16) · Gobernanza y auditoría unificadas
-- =============================================================================
-- NOTA DE NUMERACIÓN: el nombre del archivo conserva la numeración histórica
-- de la carpeta. Según §16 del documento de arquitectura esto es la FASE 5.
-- Ver la tabla de alineación en sql/08_arquitectura/README.md.
--
-- PROPUESTA PREPARADA EL 2026-11-19. NO EJECUTAR SIN APROBACIÓN Y BACKUP.
-- Autorización registrada: "Fase 5: gobernanza". Requiere la Fase 1 ejecutada
-- (os_review_state) y M1 aplicado (os_admin.app_user) para los actores reales.
--
-- ADITIVO Y TRANSACCIONAL:
--   · CREATE TABLE IF NOT EXISTS, CREATE INDEX IF NOT EXISTS,
--     CREATE OR REPLACE FUNCTION/TRIGGER y REVOKE.
--   · No elimina tablas, columnas ni datos. No contiene DDL destructivo.
--   · No crea usuarios: los actores se referencian a os_admin.app_user.
--   · No modifica importadores, API pública, catálogos publicados ni
--     Browse Codes. No siembra filas: las tablas nuevas nacen vacías.
--
-- ACTORES REALES: las cuatro tablas incorporan columnas <nombre>_user_id
-- BIGINT NULL REFERENCES os_admin.app_user(id) ON DELETE SET NULL. Los campos
-- textuales de procedencia se conservan para no romper el formato histórico.
-- El trigger de auditoría toma el actor de app.actor_id (el mismo setting que
-- usa D-31) cuando la aplicación lo proporciona; si no, queda NULL.
--
-- AUDITORÍA APPEND-ONLY: os_audit_log tendrá un trigger BEFORE UPDATE OR DELETE
-- que lanza una excepción, con el mismo patrón que os_admin.audit_log en M1.
-- Los triggers de gobernanza SÍ registran altas, cambios y bajas de solicitudes,
-- revisiones y decisiones; nunca escriben en una tabla ya cerrada.
--
-- PRIVILEGIOS: se revoca PUBLIC/origen_admin sobre las cuatro tablas nuevas
-- por el DEFAULT ACL de public. No se otorga acceso de escritura a ningún rol
-- de aplicación: conectar el panel a estas tablas requiere autorización nueva.
--
-- ROLLBACK: restaurar el dump previo (ver README). No hay DDL destructivo.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Preflight
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.os_review_state') IS NULL THEN
        RAISE EXCEPTION 'Fase 5 requiere la Fase 1 (public.os_review_state)';
    END IF;
    IF to_regclass('os_admin.app_user') IS NULL THEN
        RAISE EXCEPTION 'Fase 5 requiere M1 (os_admin.app_user) para los actores reales';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Solicitudes de gobernanza
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_governance_request (
    id BIGSERIAL PRIMARY KEY,
    request_type VARCHAR(60) NOT NULL,
    subject_type VARCHAR(60) NOT NULL,
    subject_id TEXT NOT NULL,
    proposed_change TEXT NOT NULL,
    source_reference TEXT,
    license_reference TEXT,
    requested_by TEXT,
    requested_by_user_id BIGINT REFERENCES os_admin.app_user(id) ON DELETE SET NULL,
    review_status VARCHAR(30) NOT NULL DEFAULT 'draft'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_os_governance_request_subject
        UNIQUE (request_type, subject_type, subject_id, proposed_change)
);

CREATE INDEX IF NOT EXISTS idx_os_governance_request_status
    ON os_governance_request (review_status);

-- ---------------------------------------------------------------------------
-- 2. Revisiones
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_governance_review (
    id BIGSERIAL PRIMARY KEY,
    request_id BIGINT NOT NULL REFERENCES os_governance_request(id) ON DELETE CASCADE,
    reviewer_actor TEXT,
    reviewer_user_id BIGINT REFERENCES os_admin.app_user(id) ON DELETE SET NULL,
    reviewer_role TEXT,
    outcome VARCHAR(30) NOT NULL DEFAULT 'unreviewed'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    rationale TEXT,
    reviewed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------------
-- 3. Decisiones
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_governance_decision (
    id BIGSERIAL PRIMARY KEY,
    review_id BIGINT NOT NULL REFERENCES os_governance_review(id) ON DELETE CASCADE,
    decision_code VARCHAR(60) NOT NULL,
    approved_by TEXT,
    approved_by_user_id BIGINT REFERENCES os_admin.app_user(id) ON DELETE SET NULL,
    approved_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    effective_from DATE,
    evidence_reference TEXT NOT NULL,
    CONSTRAINT uq_os_governance_decision UNIQUE (review_id, decision_code)
);

COMMENT ON COLUMN os_governance_decision.evidence_reference IS
    'Referencia obligatoria al acta o evidencia de aprobación; no se acepta aprobación implícita.';
COMMENT ON COLUMN os_governance_request.requested_by_user_id IS
    'Actor real de os_admin.app_user. El campo requested_by conserva la procedencia textual histórica.';
COMMENT ON COLUMN os_governance_review.reviewer_user_id IS
    'Revisor real de os_admin.app_user. Rbac::canApprove() impide aprobar la propia propuesta.';
COMMENT ON COLUMN os_governance_decision.approved_by_user_id IS
    'Aprobador real de os_admin.app_user; la evidencia escrita es obligatoria.';

-- ---------------------------------------------------------------------------
-- 4. Registro de auditoría append-only
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_audit_log (
    id BIGSERIAL PRIMARY KEY,
    entity_type VARCHAR(80) NOT NULL,
    entity_id TEXT NOT NULL,
    action VARCHAR(40) NOT NULL,
    actor TEXT,
    actor_user_id BIGINT REFERENCES os_admin.app_user(id) ON DELETE SET NULL,
    request_id BIGINT REFERENCES os_governance_request(id) ON DELETE SET NULL,
    before_state JSONB,
    after_state JSONB,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_os_audit_log_entity
    ON os_audit_log (entity_type, entity_id, occurred_at DESC);

CREATE OR REPLACE FUNCTION os_governance_audit_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'public.os_audit_log es append-only';
END;
$$;

CREATE OR REPLACE TRIGGER trg_os_audit_log_immutable
    BEFORE UPDATE OR DELETE ON os_audit_log
    FOR EACH ROW EXECUTE FUNCTION os_governance_audit_immutable();

-- ---------------------------------------------------------------------------
-- 5. Trigger de auditoría de gobernanza
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION os_governance_audit_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_entity     TEXT := TG_TABLE_NAME;
    v_id         TEXT;
    v_action     TEXT;
    v_before     JSONB;
    v_after      JSONB;
    v_request    BIGINT;
    v_actor      TEXT;
    v_actor_id   BIGINT;
    v_raw_actor  TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id := OLD.id::text;
        v_action := 'delete';
        v_before := to_jsonb(OLD);
        v_after := NULL;
    ELSIF TG_OP = 'UPDATE' THEN
        v_id := NEW.id::text;
        v_action := 'update';
        v_before := to_jsonb(OLD);
        v_after := to_jsonb(NEW);
    ELSE
        v_id := NEW.id::text;
        v_action := 'insert';
        v_before := NULL;
        v_after := to_jsonb(NEW);
    END IF;

    IF v_entity = 'os_governance_review' THEN
        v_request := COALESCE(NEW.request_id, OLD.request_id);
    ELSIF v_entity = 'os_governance_decision' THEN
        SELECT r.request_id INTO v_request
          FROM os_governance_review r
         WHERE r.id = COALESCE(NEW.review_id, OLD.review_id);
    END IF;

    v_raw_actor := NULLIF(current_setting('app.actor_id', TRUE), '');
    IF v_raw_actor IS NOT NULL AND v_raw_actor ~ '^\d+$' THEN
        v_actor_id := v_raw_actor::BIGINT;
    END IF;

    v_actor := COALESCE(
        v_after->>'approved_by',
        v_after->>'reviewer_actor',
        v_after->>'requested_by',
        v_actor_id::text,
        current_user::text
    );

    INSERT INTO os_audit_log
        (entity_type, entity_id, action, actor, actor_user_id, request_id, before_state, after_state)
    VALUES
        (v_entity, v_id, v_action, v_actor, v_actor_id, v_request, v_before, v_after);

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_os_governance_request_audit
    AFTER INSERT OR UPDATE OR DELETE ON os_governance_request
    FOR EACH ROW EXECUTE FUNCTION os_governance_audit_trigger();

CREATE OR REPLACE TRIGGER trg_os_governance_review_audit
    AFTER INSERT OR UPDATE OR DELETE ON os_governance_review
    FOR EACH ROW EXECUTE FUNCTION os_governance_audit_trigger();

CREATE OR REPLACE TRIGGER trg_os_governance_decision_audit
    AFTER INSERT OR UPDATE OR DELETE ON os_governance_decision
    FOR EACH ROW EXECUTE FUNCTION os_governance_audit_trigger();

-- ---------------------------------------------------------------------------
-- 6. DEFAULT ACL: retirar privilegios automáticos sobre las tablas nuevas
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON TABLE
    public.os_governance_request,
    public.os_governance_review,
    public.os_governance_decision,
    public.os_audit_log
FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE
            public.os_governance_request,
            public.os_governance_review,
            public.os_governance_decision,
            public.os_audit_log
            FROM origen_admin';
    END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- Comprobaciones posteriores (solo lectura)
-- ---------------------------------------------------------------------------
SELECT '=== Fase 5 · tablas de gobernanza ===' AS seccion;
SELECT tablename
  FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN (
       'os_governance_request', 'os_governance_review',
       'os_governance_decision', 'os_audit_log'
   )
 ORDER BY tablename;

SELECT '=== Fase 5 · triggers activos ===' AS seccion;
SELECT tgname, tgenabled
  FROM pg_trigger
 WHERE tgrelid IN (
     to_regclass('public.os_governance_request'),
     to_regclass('public.os_governance_review'),
     to_regclass('public.os_governance_decision'),
     to_regclass('public.os_audit_log')
 )
   AND NOT tgisinternal
 ORDER BY tgname;

SELECT '=== Fase 5 · filas nuevas (debe ser 0 en las cuatro) ===' AS seccion;
SELECT 'request' AS tabla, count(*) AS filas FROM os_governance_request
UNION ALL SELECT 'review', count(*) FROM os_governance_review
UNION ALL SELECT 'decision', count(*) FROM os_governance_decision
UNION ALL SELECT 'audit', count(*) FROM os_audit_log;

-- Fin de Fase 5 (§16) · gobernanza y auditoría unificadas.
