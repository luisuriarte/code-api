-- =============================================================================
-- GESTIÓN DE CATÁLOGOS (C0–C6)
-- =============================================================================
-- PROPUESTA PREPARADA EL 2026-11-20. NO EJECUTAR SIN AUTORIZACIÓN Y BACKUP.
-- Autorización: decisión del responsable de usar el flujo gestionado, con todos
-- los campos (Ítem, Versión, Release, Relaciones e idiomas), botón UVR por
-- código y acceso Management en el portal público.
--
-- ALCANCE: publica en las tablas canónicas únicamente cambios que ya pasaron
-- dos revisiones aprobadas por actores distintos, decisión con evidencia y un
-- estado que permita publicación. No crea catálogos nuevos, no renombra legado,
-- no toca la API pública y no modifica el DEFAULT ACL global.
--
-- SEGURIDAD: la función es SECURITY DEFINER. origen_admin solo recibe EXECUTE;
-- NO recibe INSERT/UPDATE sobre os_catalog_*. Toda escritura queda auditada en
-- os_audit_log (append-only) con el actor real de os_admin.app_user.
--
-- ROLLBACK: restaurar el dump previo. La verificación es READ ONLY.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Preflight
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.os_catalog') IS NULL
       OR to_regclass('public.os_catalog_item') IS NULL
       OR to_regclass('public.os_catalog_item_version') IS NULL
       OR to_regclass('public.os_catalog_release') IS NULL
       OR to_regclass('public.os_catalog_relation') IS NULL
       OR to_regclass('public.os_catalog_language') IS NULL
       OR to_regclass('public.os_governance_request') IS NULL
       OR to_regclass('public.os_governance_review') IS NULL
       OR to_regclass('public.os_governance_decision') IS NULL
       OR to_regclass('public.os_audit_log') IS NULL
       OR to_regclass('public.os_review_state') IS NULL THEN
        RAISE EXCEPTION 'La gestión de catálogos requiere catálogos, gestión y auditoría';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Aplicador gestionado
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.os_catalog_apply_governed_change(
    p_request_id BIGINT,
    p_actor_id BIGINT,
    p_actor_email TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_request   public.os_governance_request%ROWTYPE;
    v_change    JSONB;
    v_catalog   public.os_catalog%ROWTYPE;
    v_item_id   INT;
    v_release_id INT;
    v_audits    INT;
    v_ok        INT;
BEGIN
    SELECT * INTO v_request
      FROM public.os_governance_request
     WHERE id = p_request_id
       AND subject_type = 'catalog_change';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'CATALOG_REQUEST_NOT_FOUND: solicitud de catálogo inexistente';
    END IF;

    SELECT count(*) INTO v_audits
      FROM public.os_audit_log
     WHERE request_id = p_request_id
       AND action = 'catalog_change_published';

    IF v_audits > 0 THEN
        RETURN 'already_applied';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM public.os_review_state s
         WHERE s.code = v_request.review_status
           AND s.is_publication_allowed
    ) THEN
        RAISE EXCEPTION 'CATALOG_STATE_NOT_PUBLISHABLE: el estado % no permite publicación', v_request.review_status;
    END IF;

    SELECT count(DISTINCT r.reviewer_user_id) INTO v_ok
      FROM public.os_governance_review r
     WHERE r.request_id = p_request_id
       AND r.outcome = 'approved'
       AND r.reviewer_user_id IS NOT NULL;

    IF v_ok < 2 THEN
        RAISE EXCEPTION 'CATALOG_REVIEWS_INCOMPLETE: se requieren dos revisiones aprobadas con actores distintos';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM public.os_governance_decision d
          JOIN public.os_governance_review r ON r.id = d.review_id
         WHERE r.request_id = p_request_id
           AND d.evidence_reference IS NOT NULL
           AND btrim(d.evidence_reference) <> ''
    ) THEN
        RAISE EXCEPTION 'CATALOG_DECISION_REQUIRED: falta decisión con evidencia';
    END IF;

    BEGIN
        v_change := v_request.proposed_change::JSONB;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'CATALOG_CHANGE_INVALID: proposed_change no es JSON válido';
    END;

    SELECT * INTO v_catalog
      FROM public.os_catalog
     WHERE code = NULLIF(v_change ->> 'catalog_code', '');

    IF NOT FOUND THEN
        RAISE EXCEPTION 'CATALOG_UNAVAILABLE: catálogo no encontrado';
    END IF;

    v_item_id := NULLIF(v_change ->> 'item_id', '')::INT;
    v_release_id := NULLIF(v_change #>> '{release,release_id}', '')::INT;

    IF v_item_id IS NULL AND COALESCE(v_change ->> 'operation', 'update') = 'create' THEN
        INSERT INTO public.os_catalog_item (catalog_id, permanent_code, status)
        VALUES (
            v_catalog.id,
            NULLIF(v_change #>> '{item,permanent_code}', ''),
            COALESCE(NULLIF(v_change #>> '{item,status}', ''), 'active')
        )
        RETURNING id INTO v_item_id;
    ELSIF v_item_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.os_catalog_item i
             WHERE i.id = v_item_id AND i.catalog_id = v_catalog.id
        ) THEN
            RAISE EXCEPTION 'CATALOG_ITEM_MISMATCH: el ítem no pertenece al catálogo';
        END IF;

        IF NULLIF(v_change #>> '{item,permanent_code}', '') IS NOT NULL
           OR NULLIF(v_change #>> '{item,status}', '') IS NOT NULL THEN
            UPDATE public.os_catalog_item i
               SET permanent_code = COALESCE(NULLIF(v_change #>> '{item,permanent_code}', ''), i.permanent_code),
                   status = COALESCE(NULLIF(v_change #>> '{item,status}', ''), i.status)
             WHERE i.id = v_item_id;
        END IF;
    ELSE
        RAISE EXCEPTION 'CATALOG_ITEM_REQUIRED: falta item_id o la operación create';
    END IF;

    IF v_release_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.os_catalog_release r
             WHERE r.id = v_release_id AND r.catalog_id = v_catalog.id
        ) THEN
            RAISE EXCEPTION 'CATALOG_RELEASE_MISMATCH: el release no pertenece al catálogo';
        END IF;

        UPDATE public.os_catalog_release r
           SET version_tag = COALESCE(NULLIF(v_change #>> '{release,version_tag}', ''), r.version_tag),
               valid_from = COALESCE(NULLIF(v_change #>> '{release,valid_from}', '')::DATE, r.valid_from),
               valid_to = COALESCE(NULLIF(v_change #>> '{release,valid_to}', '')::DATE, r.valid_to),
               status = COALESCE(NULLIF(v_change #>> '{release,status}', ''), r.status)
         WHERE r.id = v_release_id;
    END IF;

    IF NULLIF(v_change #>> '{version,preferred_term}', '') IS NOT NULL
       AND v_release_id IS NOT NULL THEN
        INSERT INTO public.os_catalog_item_version
            (item_id, release_id, preferred_term, definition, clinical_criteria, language_code)
        VALUES (
            v_item_id,
            v_release_id,
            v_change #>> '{version,preferred_term}',
            NULLIF(v_change #>> '{version,definition}', ''),
            NULLIF(v_change #>> '{version,clinical_criteria}', ''),
            COALESCE(NULLIF(v_change #>> '{version,language_code}', ''), 'es-AR')
        )
        ON CONFLICT (item_id, release_id, language_code) DO UPDATE
           SET preferred_term = EXCLUDED.preferred_term,
               definition = EXCLUDED.definition,
               clinical_criteria = EXCLUDED.clinical_criteria;
    END IF;

    IF jsonb_typeof(v_change -> 'relations') = 'array' THEN
        INSERT INTO public.os_catalog_relation
            (source_item_id, target_item_id, relation_type, source_system_code,
             source_field, source_value, context_text, review_status, provenance)
        SELECT
            v_item_id,
            (rel ->> 'target_item_id')::INT,
            rel ->> 'relation_type',
            COALESCE(NULLIF(rel ->> 'source_system_code', ''), 'CDT-2025'),
            rel ->> 'source_field',
            rel ->> 'source_value',
            NULLIF(rel ->> 'context_text', ''),
            COALESCE(NULLIF(rel ->> 'review_status', ''), 'approved'),
            COALESCE(NULLIF(rel ->> 'provenance', ''), 'governed_change')
          FROM jsonb_array_elements(v_change -> 'relations') AS rel
         WHERE NULLIF(rel ->> 'target_item_id', '') IS NOT NULL
           AND NULLIF(rel ->> 'relation_type', '') IS NOT NULL
           AND NULLIF(rel ->> 'source_field', '') IS NOT NULL
           AND NULLIF(rel ->> 'source_value', '') IS NOT NULL
           AND (rel ->> 'target_item_id')::INT <> v_item_id
        ON CONFLICT DO NOTHING;
    END IF;

    IF jsonb_typeof(v_change -> 'languages') = 'array' THEN
        INSERT INTO public.os_catalog_language
            (catalog_id, language_code, is_default, is_fallback, is_bridge, coverage_status)
        SELECT
            v_catalog.id,
            lang ->> 'language_code',
            COALESCE((lang ->> 'is_default')::BOOLEAN, FALSE),
            COALESCE((lang ->> 'is_fallback')::BOOLEAN, FALSE),
            COALESCE((lang ->> 'is_bridge')::BOOLEAN, FALSE),
            COALESCE(NULLIF(lang ->> 'coverage_status', ''), 'partial')
          FROM jsonb_array_elements(v_change -> 'languages') AS lang
         WHERE NULLIF(lang ->> 'language_code', '') IS NOT NULL
        ON CONFLICT (catalog_id, language_code) DO UPDATE
           SET is_default = EXCLUDED.is_default,
               is_fallback = EXCLUDED.is_fallback,
               is_bridge = EXCLUDED.is_bridge,
               coverage_status = EXCLUDED.coverage_status;
    END IF;

    -- Categoría del concepto: se graba en la tabla transversal, nunca en el
    -- catálogo de origen. La tabla puede no existir aún si no se aplicó la
    -- migración de categorías clínicas; en ese caso se omite sin romper la
    -- publicación gobernada existente.
    IF NULLIF(v_change #>> '{clinical_category,code}', '') IS NOT NULL
       AND to_regclass('public.os_catalog_item_clinical_category') IS NOT NULL THEN
        INSERT INTO public.os_catalog_item_clinical_category
            (item_id, clinical_category_code, updated_at, source_request_id)
        VALUES (
            v_item_id,
            v_change #>> '{clinical_category,code}',
            now(),
            p_request_id
        )
        ON CONFLICT (item_id) DO UPDATE SET
            clinical_category_code = EXCLUDED.clinical_category_code,
            updated_at = EXCLUDED.updated_at,
            source_request_id = EXCLUDED.source_request_id;
    END IF;

    INSERT INTO public.os_audit_log
        (entity_type, entity_id, action, actor, actor_user_id, request_id, before_state, after_state)
    VALUES (
        'catalog_change',
        v_item_id::TEXT,
        'catalog_change_published',
        COALESCE(NULLIF(p_actor_email, ''), NULL),
        p_actor_id,
        p_request_id,
        jsonb_build_object('catalog_code', v_catalog.code, 'item_id', NULLIF(v_change ->> 'item_id', '')::INT),
        v_change
    );

    UPDATE public.os_governance_request
       SET review_status = 'published'
     WHERE id = p_request_id;

    RETURN 'applied';
END;
$$;

COMMENT ON FUNCTION public.os_catalog_apply_governed_change(BIGINT, BIGINT, TEXT) IS
    'Aplica un cambio de catálogo ya aprobado; solo EXECUTE para origen_admin. Acta de gestión UVR y decisión C0–C6.';

-- ---------------------------------------------------------------------------
-- 2. Privilegios mínimos (sin DEFAULT ACL global)
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON FUNCTION public.os_catalog_apply_governed_change(BIGINT, BIGINT, TEXT) FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.os_catalog_apply_governed_change(BIGINT, BIGINT, TEXT) TO origen_admin';
    END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- Comprobaciones posteriores (solo lectura)
-- ---------------------------------------------------------------------------
SELECT '=== Gestión de catálogos · función y privilegios ===' AS seccion;

SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS argumentos,
       p.prosecdef AS security_definer
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname = 'os_catalog_apply_governed_change';

SELECT grantee, string_agg(privilege_type, ',' ORDER BY privilege_type) AS privilegios
  FROM information_schema.routine_privileges
 WHERE routine_schema = 'public'
   AND routine_name = 'os_catalog_apply_governed_change'
 GROUP BY grantee
 ORDER BY grantee;
