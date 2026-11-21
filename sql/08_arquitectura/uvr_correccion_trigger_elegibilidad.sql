-- =============================================================================
-- Corrección de triggers UVR que leen catálogos (permission denied)
-- =============================================================================
-- Error observado en el log de PostgreSQL al enviar una propuesta:
--   origen_admin@origen_codes ERROR: permission denied for table os_catalog_item
--
-- Los triggers de elegibilidad y publicación leen os_catalog / os_catalog_item,
--pero por diseño origen_admin NO tiene privilegios sobre os_catalog_*. Al no ser
--SECURITY DEFINER, esas lecturas se hacen con el rol que dispara el INSERT y
--fallan. La corrección es ejecutar solo esas funciones como su propietario,
--con search_path explícito y sin conceder privileges nuevos a origen_admin.
--
-- Ejecutar por el responsable contra la base del PANEL:
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 \
--     -f sql/08_arquitectura/uvr_correccion_trigger_elegibilidad.sql
--
-- Idempotente. No modifica datos ni DEFAULT ACL. No toca os_catalog_*.
-- =============================================================================

BEGIN;

-- 1) Elegibilidad en el alta de la valoración (§10.3 regla 1).
CREATE OR REPLACE FUNCTION public.os_uvr_assert_eligible_service()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_allowed BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
          FROM public.os_catalog_item i
          JOIN public.os_catalog c ON c.id = i.catalog_id
          JOIN public.os_uvr_eligible_catalog e ON e.catalog_code = c.code AND e.is_active
         WHERE i.id = NEW.service_item_id
    ) INTO v_allowed;

    IF NOT v_allowed THEN
        RAISE EXCEPTION
            'El ítem % no pertenece a un catálogo elegible para UVR (§10.3).',
            NEW.service_item_id;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.os_uvr_assert_eligible_service() IS
    'Valida elegibilidad UVR leyendo catálogos como propietario; origen_admin no recibe privilegios sobre os_catalog_*.';

-- 2) Guardián de publicación (C4/C5/C8): misma lectura al aprobar/publicar.
CREATE OR REPLACE FUNCTION public.os_uvr_assert_publication_ready()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
END;
$$;

COMMENT ON FUNCTION public.os_uvr_assert_publication_ready() IS
    'Guardián de publicación UVR; lee catálogos como propietario, sin privileges de catálogo para origen_admin.';

-- 3) Privilegios mínimos de ejecución, sin DEFAULT ACL global.
REVOKE ALL PRIVILEGES ON FUNCTION public.os_uvr_assert_eligible_service() FROM PUBLIC;
REVOKE ALL PRIVILEGES ON FUNCTION public.os_uvr_assert_publication_ready() FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.os_uvr_assert_eligible_service() TO origen_admin';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.os_uvr_assert_publication_ready() TO origen_admin';
    END IF;
END $$;

COMMIT;

-- Comprobación posterior: ambas deben dar security_definer = t.
-- SELECT proname, prosecdef AS security_definer
--   FROM pg_proc
--  WHERE proname IN ('os_uvr_assert_eligible_service', 'os_uvr_assert_publication_ready')
--  ORDER BY proname;
