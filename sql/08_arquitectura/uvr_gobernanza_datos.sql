-- =============================================================================
-- GOBERNANZA UVR · MODELO DE DATOS ADITIVO (U1/U4)
-- =============================================================================
-- PROPUESTA PREPARADA EL 2026-11-20. NO EJECUTAR SIN APROBACIÓN Y BACKUP.
-- Autorización: Acta U0 (`docs/architecture/gobernanza-uvr-acta-u0.md`) y plan
-- U0–U6 aprobado. Requiere Fase 1, Fase 5, Fase 7 y Fase 5 de gobernanza.
--
-- ALCANCE: añade actores con FK, marcador de «no aplicable», evidencia para
-- ajustes negativos, inmutabilidad de valoraciones publicadas, guardián de
-- publicación y auditoría append-only de las tablas UVR. No crea tablas nuevas,
-- no carga valores, no renombra legado y no toca la API pública.
--
-- ADITIVO: ADD COLUMN IF NOT EXISTS, CREATE OR REPLACE FUNCTION/VIEW,
-- CREATE TRIGGER IF NOT EXISTS, GRANT controlado. No hay sentencias
-- destructivas: no se eliminan tablas, columnas ni filas.
--
-- REVOKE: no hay tablas nuevas; no se modifica el DEFAULT ACL global. Los
-- privilegios de panel se conceden de forma explícita y solo a origen_admin.
--
-- ROLLBACK: restaurar el dump previo (ver README). Las verificaciones son
-- READ ONLY y terminan en ROLLBACK.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Preflight
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.os_review_state') IS NULL
       OR to_regclass('os_admin.app_user') IS NULL
       OR to_regclass('public.os_governance_request') IS NULL
       OR to_regclass('public.os_governance_review') IS NULL
       OR to_regclass('public.os_governance_decision') IS NULL
       OR to_regclass('public.os_audit_log') IS NULL
       OR to_regclass('public.os_uvr_eligible_catalog') IS NULL
       OR to_regclass('public.os_uvr_valuation') IS NULL
       OR to_regclass('public.os_uvr_component') IS NULL
       OR to_regclass('public.os_uvr_conversion') IS NULL
       OR to_regclass('public.os_uvr_geo_index') IS NULL THEN
        RAISE EXCEPTION 'Gobernanza UVR requiere Fase 1, Fase 5, gobernanza pública y Fase 7';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Actores gobernados en la valoración (decisión C4)
-- ---------------------------------------------------------------------------
ALTER TABLE public.os_uvr_valuation
    ADD COLUMN IF NOT EXISTS calculated_by_user_id BIGINT
        REFERENCES os_admin.app_user(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS approved_by_user_id BIGINT
        REFERENCES os_admin.app_user(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS published_at TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN public.os_uvr_valuation.calculated_by_user_id IS
    'Responsable del cálculo con identidad gobernada (Acta U0, C4).';
COMMENT ON COLUMN public.os_uvr_valuation.approved_by_user_id IS
    'Aprobador de la valoración con identidad gobernada (Acta U0, C4).';
COMMENT ON COLUMN public.os_uvr_valuation.published_at IS
    'Fecha de publicación controlada; solo se asigna con estado publicable.';

-- ---------------------------------------------------------------------------
-- 2. Componentes: no aplicable y evidencia de ajuste negativo (C2/C3)
-- ---------------------------------------------------------------------------
ALTER TABLE public.os_uvr_component
    ADD COLUMN IF NOT EXISTS is_not_applicable BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS negative_adjustment_evidence TEXT;

COMMENT ON COLUMN public.os_uvr_component.is_not_applicable IS
    'Marcador explícito de componente no aplicable; 0 significa medido cero (Acta U0, C3).';
COMMENT ON COLUMN public.os_uvr_component.negative_adjustment_evidence IS
    'Evidencia escrita obligatoria cuando value < 0 (Acta U0, C3).';

-- Sustituye únicamente el CHECK antiguo sobre `value`; conserva el CHECK de
-- component_type y la UNIQUE (valuation_id, component_type).
DO $$
DECLARE
    check_row record;
BEGIN
    FOR check_row IN
        SELECT conname
          FROM pg_constraint
         WHERE conrelid = 'public.os_uvr_component'::regclass
           AND contype = 'c'
           AND pg_get_constraintdef(oid) ILIKE '%value%'
    LOOP
        EXECUTE format(
            'ALTER TABLE public.os_uvr_component DROP CONSTRAINT %I',
            check_row.conname
        );
    END LOOP;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'public.os_uvr_component'::regclass
           AND conname = 'ck_os_uvr_component_governed_value'
    ) THEN
        ALTER TABLE public.os_uvr_component
            ADD CONSTRAINT ck_os_uvr_component_governed_value CHECK (
                (is_not_applicable = FALSE AND value >= 0
                 AND (negative_adjustment_evidence IS NULL
                      OR btrim(negative_adjustment_evidence) = ''))
                OR
                (is_not_applicable = FALSE AND value < 0
                 AND negative_adjustment_evidence IS NOT NULL
                 AND btrim(negative_adjustment_evidence) <> '')
                OR
                (is_not_applicable = TRUE AND value = 0
                 AND (negative_adjustment_evidence IS NULL
                      OR btrim(negative_adjustment_evidence) = ''))
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'public.os_uvr_component'::regclass
           AND conname = 'ck_os_uvr_component_na_value'
    ) THEN
        ALTER TABLE public.os_uvr_component
            ADD CONSTRAINT ck_os_uvr_component_na_value CHECK (
                is_not_applicable = FALSE OR value = 0
            );
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 3. Vista gobernada: expone marcadores sin alterar la vista pública actual
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_os_uvr_valuation_governed AS
SELECT
    v.id AS valuation_id,
    v.service_item_id,
    v.release_id,
    v.version_tag,
    v.methodology,
    v.source_reference,
    v.review_status,
    v.calculated_by_user_id,
    v.approved_by_user_id,
    v.published_at,
    COALESCE(cw.value, 0) AS work_uvr,
    COALESCE(cp.value, 0) AS practice_expense_uvr,
    COALESCE(cl.value, 0) AS professional_liability_uvr,
    COALESCE(cw.is_not_applicable, FALSE) AS work_is_not_applicable,
    COALESCE(cp.is_not_applicable, FALSE) AS practice_expense_is_not_applicable,
    COALESCE(cl.is_not_applicable, FALSE) AS professional_liability_is_not_applicable,
    COALESCE(cw.value, 0) + COALESCE(cp.value, 0) + COALESCE(cl.value, 0) AS total_uvr
FROM public.os_uvr_valuation v
LEFT JOIN public.os_uvr_component cw
       ON cw.valuation_id = v.id AND cw.component_type = 'work'
LEFT JOIN public.os_uvr_component cp
       ON cp.valuation_id = v.id AND cp.component_type = 'practice_expense'
LEFT JOIN public.os_uvr_component cl
       ON cl.valuation_id = v.id AND cl.component_type = 'professional_liability';

COMMENT ON VIEW public.v_os_uvr_valuation_governed IS
    'Vista gobernada UVR. total_uvr sigue siendo derivado; expone marcadores de no aplicable y actores (Acta U0).';

REVOKE ALL PRIVILEGES ON TABLE public.v_os_uvr_valuation_governed FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 4. Inmutabilidad de valoraciones publicadas (decisión C12)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.os_uvr_assert_valuation_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.review_status NOT IN ('approved', 'published') THEN
        RETURN NEW;
    END IF;

    -- Única transición permitida sobre una fila aprobada: publicarla sin
    -- modificar ningún dato gobernado. Cualquier otro cambio exige nueva fila.
    IF OLD.review_status = 'approved'
       AND NEW.review_status = 'published'
       AND NEW.service_item_id = OLD.service_item_id
       AND NEW.release_id IS NOT DISTINCT FROM OLD.release_id
       AND NEW.version_tag = OLD.version_tag
       AND NEW.methodology = OLD.methodology
       AND NEW.source_reference = OLD.source_reference
       AND NEW.evaluated_at = OLD.evaluated_at
       AND NEW.calculated_by IS NOT DISTINCT FROM OLD.calculated_by
       AND NEW.calculated_by_user_id IS NOT DISTINCT FROM OLD.calculated_by_user_id
       AND NEW.approved_by_user_id IS NOT DISTINCT FROM OLD.approved_by_user_id
       AND NEW.valid_from IS NOT DISTINCT FROM OLD.valid_from
       AND NEW.valid_to IS NOT DISTINCT FROM OLD.valid_to THEN
        RETURN NEW;
    END IF;

    RAISE EXCEPTION
        'UVR_PUBLISHED_IMMUTABLE: la valoración % ya fue aprobada/publicada; cree una nueva fila/versión',
        OLD.id;
END $$;

DROP TRIGGER IF EXISTS trg_os_uvr_valuation_immutable ON public.os_uvr_valuation;
CREATE TRIGGER trg_os_uvr_valuation_immutable
    BEFORE UPDATE ON public.os_uvr_valuation
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_assert_valuation_immutable();

-- ---------------------------------------------------------------------------
-- 5. Guardián de publicación (C4/C5/C8)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.os_uvr_assert_publication_ready()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_source_ok BOOLEAN;
BEGIN
    IF NEW.review_status IN ('approved', 'published') THEN
        SELECT EXISTS (
            SELECT 1
              FROM public.os_uvr_eligible_catalog e
              JOIN public.os_catalog c ON c.code = e.catalog_code
              JOIN public.os_catalog_item i ON i.catalog_id = c.id AND i.id = NEW.service_item_id
             WHERE e.is_active
        ) INTO v_source_ok;

        IF NOT v_source_ok THEN
            RAISE EXCEPTION 'UVR_NOT_ELIGIBLE: el índice % no pertenece a un catálogo UVR elegible activo', NEW.service_item_id;
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM public.os_review_state s
             WHERE s.code = NEW.review_status
               AND s.is_publication_allowed
        ) THEN
            RAISE EXCEPTION 'UVR_STATE_NOT_PUBLISHABLE: el estado % no permite publicación', NEW.review_status;
        END IF;

        IF NEW.source_reference IS NULL OR btrim(NEW.source_reference) = '' THEN
            RAISE EXCEPTION 'UVR_SOURCE_REQUIRED: no se puede aprobar sin source_reference verificable';
        END IF;

        IF NEW.approved_by_user_id IS NULL THEN
            RAISE EXCEPTION 'UVR_APPROVER_REQUIRED: no se puede aprobar sin aprobador identificado';
        END IF;

        IF NEW.review_status = 'published' THEN
            NEW.published_at = COALESCE(NEW.published_at, CURRENT_TIMESTAMP);
        END IF;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_os_uvr_publication_ready ON public.os_uvr_valuation;
CREATE TRIGGER trg_os_uvr_publication_ready
    BEFORE INSERT OR UPDATE OF review_status, service_item_id, source_reference, approved_by_user_id
    ON public.os_uvr_valuation
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_assert_publication_ready();

-- ---------------------------------------------------------------------------
-- 6. Auditoría append-only de tablas UVR (U4)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.os_uvr_audit_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_actor_text TEXT;
    v_actor_id BIGINT;
    v_raw TEXT;
BEGIN
    v_raw := current_setting('app.actor_id', TRUE);

    IF v_raw IS NOT NULL AND v_raw ~ '^[0-9]+$' THEN
        v_actor_id := v_raw::BIGINT;
        v_actor_text := v_raw;
    ELSE
        v_actor_text := COALESCE(NULLIF(v_raw, ''), current_user);
    END IF;

    INSERT INTO public.os_audit_log (
        entity_type, entity_id, action, actor, actor_user_id,
        before_state, after_state, occurred_at
    ) VALUES (
        TG_TABLE_NAME,
        CASE TG_OP
            WHEN 'DELETE' THEN (to_jsonb(OLD)->>'id')
            ELSE (to_jsonb(NEW)->>'id')
        END,
        TG_OP,
        v_actor_text,
        v_actor_id,
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
        CURRENT_TIMESTAMP
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_os_uvr_valuation_audit ON public.os_uvr_valuation;
CREATE TRIGGER trg_os_uvr_valuation_audit
    AFTER INSERT OR UPDATE OR DELETE ON public.os_uvr_valuation
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_audit_trigger();

DROP TRIGGER IF EXISTS trg_os_uvr_component_audit ON public.os_uvr_component;
CREATE TRIGGER trg_os_uvr_component_audit
    AFTER INSERT OR UPDATE OR DELETE ON public.os_uvr_component
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_audit_trigger();

DROP TRIGGER IF EXISTS trg_os_uvr_conversion_audit ON public.os_uvr_conversion;
CREATE TRIGGER trg_os_uvr_conversion_audit
    AFTER INSERT OR UPDATE OR DELETE ON public.os_uvr_conversion
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_audit_trigger();

DROP TRIGGER IF EXISTS trg_os_uvr_geo_index_audit ON public.os_uvr_geo_index;
CREATE TRIGGER trg_os_uvr_geo_index_audit
    AFTER INSERT OR UPDATE OR DELETE ON public.os_uvr_geo_index
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_audit_trigger();

-- ---------------------------------------------------------------------------
-- 7. Privilegios explícitos del panel (C8), sin DEFAULT ACL global
-- ---------------------------------------------------------------------------
-- Las tablas con BIGSERIAL necesitan además USAGE sobre su secuencia: sin ese
-- privilegio el primer INSERT de propose() falla y el panel responde
-- "El servicio no está disponible" (admin.errors.database).
REVOKE ALL PRIVILEGES ON SEQUENCE
    public.os_governance_request_id_seq,
    public.os_uvr_valuation_id_seq,
    public.os_uvr_component_id_seq
FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE
            public.os_governance_request_id_seq,
            public.os_uvr_valuation_id_seq,
            public.os_uvr_component_id_seq
            TO origen_admin';
        EXECUTE 'GRANT SELECT, INSERT, UPDATE ON TABLE
            public.os_uvr_valuation,
            public.os_uvr_component,
            public.os_uvr_conversion,
            public.os_uvr_geo_index
            TO origen_admin';

        EXECUTE 'GRANT SELECT ON TABLE
            public.v_os_uvr_valuation_total,
            public.v_os_uvr_valuation_governed
            TO origen_admin';

        EXECUTE 'GRANT SELECT, INSERT, UPDATE ON TABLE
            public.os_governance_request,
            public.os_governance_review,
            public.os_governance_decision
            TO origen_admin';

        EXECUTE 'GRANT SELECT ON TABLE public.os_audit_log TO origen_admin';
    END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- Comprobaciones posteriores (solo lectura, ejecutar por el responsable)
-- ---------------------------------------------------------------------------
SELECT '=== Gobernanza UVR ·columnas y triggers===' AS seccion;
SELECT table_name, column_name
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name IN ('os_uvr_valuation', 'os_uvr_component')
   AND column_name IN (
       'calculated_by_user_id', 'approved_by_user_id', 'published_at',
       'is_not_applicable', 'negative_adjustment_evidence'
   )
 ORDER BY table_name, column_name;

SELECT tgname, relname
  FROM pg_trigger t
  JOIN pg_class c ON c.oid = t.tgrelid
 WHERE NOT t.tgisinternal
   AND tgname IN (
       'trg_os_uvr_valuation_immutable',
       'trg_os_uvr_publication_ready',
       'trg_os_uvr_valuation_audit',
       'trg_os_uvr_component_audit',
       'trg_os_uvr_conversion_audit',
       'trg_os_uvr_geo_index_audit'
   )
 ORDER BY tgname;
