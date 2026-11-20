-- =============================================================================
-- U7-B · GOBERNANZA TRANSVERSAL DE PRESTACIONES (PREPARADO, NO EJECUTAR)
-- =============================================================================
-- Autorización: acta `docs/architecture/gobernanza-uvr-acta-u7.md`, fases
-- U7-B/C/D aprobadas por el responsable el 2026-11-20.
--
-- ADITIVO PURO: CREATE TABLE IF NOT EXISTS, CREATE OR REPLACE VIEW/FUNCTION,
-- DROP/CREATE TRIGGER IF NOT EXISTS, REVOKE por tabla y GRANT puntual. No modifica
-- ni una sola fila existente: no hay sentencias de modificación de datos,
-- vaciado ni eliminación de columnas o tablas. No altera `os_uvr_valuation`,
-- sus componentes ni la conversión.
-- No crea `/v1/uvr` ni `/fhir/*` y no toca OpenAPI.
-- No hay ALTER DEFAULT PRIVILEGES: todo privilegio se concede por objeto.
--
-- ROLLBACK: restaurar el dump previo (ver README de esta carpeta). El
-- verificador `verificacion_uvr_transversal.sql` es BEGIN READ ONLY / ROLLBACK.
--
-- CERO DATOS INVENTADOS: las seis tablas y la vista se crean vacías. No se
-- cargan prestaciones, perfiles, componentes ni valores UVR.
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
       OR to_regclass('public.os_review_state') IS NULL
       OR to_regclass('public.os_audit_log') IS NULL
       OR to_regclass('os_admin.app_user') IS NULL
       OR to_regclass('public.os_uvr_valuation') IS NULL
       OR to_regclass('public.os_uvr_component') IS NULL
       OR to_regclass('public.os_uvr_conversion') IS NULL THEN
        RAISE EXCEPTION 'U7-B requiere Fase 1, Fase 5, Fase 7 y gobernanza U0–U6 ejecutadas';
    END IF;

    IF to_regprocedure('public.os_uvr_audit_trigger()') IS NULL THEN
        RAISE EXCEPTION 'U7-B requiere la función de auditoría append-only de U0–U6';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Identidad de la prestación (U7.2)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.os_prestacion (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(60) NOT NULL UNIQUE,
    display_name VARCHAR(500) NOT NULL,
    prestation_type VARCHAR(40) NOT NULL CHECK (prestation_type IN (
        'procedure', 'diagnostic_procedure', 'therapeutic_procedure',
        'surgical_procedure', 'other_valuable'
    )),
    is_valuable BOOLEAN NOT NULL DEFAULT FALSE,
    eligibility_evidence TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN (
        'draft', 'review', 'approved', 'published', 'retired'
    )),
    source_reference TEXT NOT NULL,
    created_by_user_id BIGINT REFERENCES os_admin.app_user(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_os_prestacion_valuable_evidence CHECK (
        is_valuable = FALSE
        OR (eligibility_evidence IS NOT NULL AND btrim(eligibility_evidence) <> '')
    )
);

COMMENT ON TABLE public.os_prestacion IS
    'Identidad de la prestación valorable, independiente del catálogo donde esté codificada (Acta U7).';
COMMENT ON COLUMN public.os_prestacion.is_valuable IS
    'Elegibilidad por tipo de prestación y evidencia, nunca por catálogo (U7.3 y U7.7).';

-- ---------------------------------------------------------------------------
-- 2. Vínculos validados a códigos de cualquier catálogo (U7.6)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.os_prestacion_codigo (
    id BIGSERIAL PRIMARY KEY,
    prestacion_id BIGINT NOT NULL REFERENCES public.os_prestacion(id) ON DELETE RESTRICT,
    catalog_code VARCHAR(60) NOT NULL REFERENCES public.os_catalog(code) ON DELETE RESTRICT,
    item_id INTEGER REFERENCES public.os_catalog_item(id) ON DELETE RESTRICT,
    external_code VARCHAR(255),
    correspondence_type VARCHAR(30) NOT NULL DEFAULT 'corresponding' CHECK (
        correspondence_type IN ('corresponding', 'equivalent', 'narrower', 'broader', 'related')
    ),
    review_status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (
        review_status IN ('draft', 'reviewed', 'approved', 'deprecated')
    ),
    source_reference TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_os_prestacion_codigo UNIQUE (prestacion_id, catalog_code, item_id, external_code),
    CONSTRAINT ck_os_prestacion_codigo_ref CHECK (
        item_id IS NOT NULL OR (external_code IS NOT NULL AND btrim(external_code) <> '')
    )
);

COMMENT ON TABLE public.os_prestacion_codigo IS
    'Correspondencia validada entre una prestación y un código. Nunca copia ni deriva UVR (U7.6).';

-- ---------------------------------------------------------------------------
-- 3. Perfil de valoración (U7.4 y U7.5)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.os_uvr_profile (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(60) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    methodology TEXT NOT NULL,
    scope VARCHAR(40) NOT NULL CHECK (scope IN (
        'dental', 'medical', 'surgical', 'diagnostic', 'therapeutic', 'institutional'
    )),
    jurisdiction VARCHAR(10),
    version_tag VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (
        status IN ('draft', 'review', 'approved', 'published', 'retired')
    ),
    source_reference TEXT NOT NULL,
    approved_by_user_id BIGINT REFERENCES os_admin.app_user(id) ON DELETE SET NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.os_uvr_profile_component (
    id BIGSERIAL PRIMARY KEY,
    profile_id BIGINT NOT NULL REFERENCES public.os_uvr_profile(id) ON DELETE CASCADE,
    component_type VARCHAR(40) NOT NULL,
    applicability VARCHAR(20) NOT NULL DEFAULT 'applicable' CHECK (
        applicability IN ('applicable', 'not_applicable', 'pending')
    ),
    source_reference TEXT NOT NULL,
    CONSTRAINT uq_os_uvr_profile_component UNIQUE (profile_id, component_type)
);

COMMENT ON TABLE public.os_uvr_profile IS
    'Metodología, alcance, jurisdicción, versión y aprobación de un perfil de valoración (U7.4).';
COMMENT ON TABLE public.os_uvr_profile_component IS
    'Aplicabilidad de cada componente dentro del perfil; sin CHECK cerrado a tres tipos (U7.5).';

-- ---------------------------------------------------------------------------
-- 4. Valoración de la prestación: tablas propias, legado intacto
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.os_uvr_prestacion_valuation (
    id BIGSERIAL PRIMARY KEY,
    prestacion_id BIGINT NOT NULL REFERENCES public.os_prestacion(id) ON DELETE RESTRICT,
    profile_id BIGINT NOT NULL REFERENCES public.os_uvr_profile(id) ON DELETE RESTRICT,
    version_tag VARCHAR(50) NOT NULL,
    source_reference TEXT NOT NULL,
    evaluated_at DATE NOT NULL,
    calculated_by_user_id BIGINT REFERENCES os_admin.app_user(id) ON DELETE SET NULL,
    approved_by_user_id BIGINT REFERENCES os_admin.app_user(id) ON DELETE SET NULL,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unknown'
        REFERENCES public.os_review_state(code),
    published_at TIMESTAMP WITH TIME ZONE,
    valid_from DATE,
    valid_to DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_os_uvr_prestacion_valuation UNIQUE (prestacion_id, profile_id, version_tag)
);

CREATE TABLE IF NOT EXISTS public.os_uvr_prestacion_component (
    id BIGSERIAL PRIMARY KEY,
    valuation_id BIGINT NOT NULL
        REFERENCES public.os_uvr_prestacion_valuation(id) ON DELETE CASCADE,
    component_type VARCHAR(40) NOT NULL,
    value NUMERIC(18,6) NOT NULL,
    is_not_applicable BOOLEAN NOT NULL DEFAULT FALSE,
    negative_adjustment_evidence TEXT,
    calculation_note TEXT,
    source_reference TEXT NOT NULL,
    CONSTRAINT uq_os_uvr_prestacion_component UNIQUE (valuation_id, component_type),
    CONSTRAINT ck_os_uvr_prestacion_component_value CHECK (
        (is_not_applicable = TRUE AND value = 0 AND negative_adjustment_evidence IS NULL)
        OR (is_not_applicable = FALSE AND value >= 0 AND negative_adjustment_evidence IS NULL)
        OR (is_not_applicable = FALSE AND value < 0
            AND negative_adjustment_evidence IS NOT NULL
            AND btrim(negative_adjustment_evidence) <> '')
    )
);

COMMENT ON TABLE public.os_uvr_prestacion_valuation IS
    'Valoración asociada a una prestación de referencia y a un perfil, no a un catálogo (Acta U7).';
COMMENT ON COLUMN public.os_uvr_prestacion_component.value IS
    '0 = medido; ausencia se representa con is_not_applicable; negativo exige evidencia (C3).';

-- ---------------------------------------------------------------------------
-- 5. Total derivado (C1): nunca columna almacenada
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_os_uvr_prestacion_total AS
SELECT v.id AS valuation_id,
       v.prestacion_id,
       p.code AS prestacion_code,
       p.display_name AS prestacion_name,
       v.profile_id,
       pr.code AS profile_code,
       pr.methodology,
       pr.scope,
       pr.jurisdiction,
       v.version_tag,
       v.review_status,
       v.published_at,
       v.valid_from,
       v.valid_to,
       COALESCE(w.value, 0) AS work_uvr,
       COALESCE(e.value, 0) AS practice_expense_uvr,
       COALESCE(l.value, 0) AS professional_liability_uvr,
       (COALESCE(w.value, 0) + COALESCE(e.value, 0) + COALESCE(l.value, 0)) AS total_uvr
  FROM public.os_uvr_prestacion_valuation v
  JOIN public.os_prestacion p ON p.id = v.prestacion_id
  JOIN public.os_uvr_profile pr ON pr.id = v.profile_id
  LEFT JOIN public.os_uvr_prestacion_component w
    ON w.valuation_id = v.id AND w.component_type = 'work'
  LEFT JOIN public.os_uvr_prestacion_component e
    ON e.valuation_id = v.id AND e.component_type = 'practice_expense'
  LEFT JOIN public.os_uvr_prestacion_component l
    ON l.valuation_id = v.id AND l.component_type = 'professional_liability';

COMMENT ON VIEW public.v_os_uvr_prestacion_total IS
    'Total UVR derivado por prestación y perfil; total_uvr nunca se almacena (C1/U7).';

-- Vista pública: solo valoraciones publicadas de prestaciones y perfiles
-- publicados. El portal lee esta vista con el rol de solo lectura origen_med;
-- nunca recibe privilegios sobre las tablas base.
CREATE OR REPLACE VIEW public.v_os_uvr_prestacion_public AS
SELECT c.code AS catalog_code,
       pc.item_id,
       pc.external_code,
       t.valuation_id,
       t.prestacion_id,
       t.prestacion_code,
       t.prestacion_name,
       t.profile_id,
       t.profile_code,
       t.methodology,
       t.scope,
       t.jurisdiction,
       t.version_tag,
       t.review_status,
       t.published_at,
       t.valid_from,
       t.valid_to,
       t.work_uvr,
       t.practice_expense_uvr,
       t.professional_liability_uvr,
       t.total_uvr,
       money.currency,
       money.importe_referencial
  FROM public.v_os_uvr_prestacion_total t
  JOIN public.os_prestacion p
    ON p.id = t.prestacion_id AND p.status = 'published' AND p.is_valuable
  JOIN public.os_uvr_profile pr
    ON pr.id = t.profile_id AND pr.status = 'published'
  JOIN public.os_prestacion_codigo pc
    ON pc.prestacion_id = t.prestacion_id
   AND pc.review_status IN ('approved', 'deprecated')
  JOIN public.os_catalog c ON c.code = pc.catalog_code AND c.is_active
  LEFT JOIN LATERAL (
      SELECT conv.currency,
             ROUND(t.total_uvr * conv.uvr_value, 2) AS importe_referencial
        FROM public.os_uvr_conversion conv
       WHERE conv.review_status IN ('approved', 'published')
         AND (conv.period_start IS NULL OR conv.period_start <= CURRENT_DATE)
         AND (conv.period_end IS NULL OR conv.period_end >= CURRENT_DATE)
       ORDER BY CASE WHEN conv.review_status = 'published' THEN 1 ELSE 0 END DESC,
                conv.period_start DESC NULLS LAST,
                conv.id DESC
       LIMIT 1
  ) money ON TRUE
 WHERE t.review_status = 'published'
   AND t.published_at IS NOT NULL;

COMMENT ON VIEW public.v_os_uvr_prestacion_public IS
    'Exposición pública de la prestación valorada publicada (U7-D). Sin importes estimados: el importe referencial se deriva solo de conversión aprobada.';

-- ---------------------------------------------------------------------------
-- 6. Inmutabilidad de lo publicado (C12) y auditoría append-only
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.os_uvr_prestacion_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.published_at IS NOT NULL THEN
        RAISE EXCEPTION 'UVR_PRESTACION_PUBLISHED_IMMUTABLE: nueva valoración = nueva fila';
    END IF;

    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_os_uvr_prestacion_immutable
    ON public.os_uvr_prestacion_valuation;
CREATE TRIGGER trg_os_uvr_prestacion_immutable
    BEFORE UPDATE ON public.os_uvr_prestacion_valuation
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_prestacion_immutable();

DROP TRIGGER IF EXISTS trg_os_prestacion_audit ON public.os_prestacion;
CREATE TRIGGER trg_os_prestacion_audit
    AFTER INSERT OR UPDATE OR DELETE ON public.os_prestacion
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_audit_trigger();

DROP TRIGGER IF EXISTS trg_os_prestacion_codigo_audit ON public.os_prestacion_codigo;
CREATE TRIGGER trg_os_prestacion_codigo_audit
    AFTER INSERT OR UPDATE OR DELETE ON public.os_prestacion_codigo
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_audit_trigger();

DROP TRIGGER IF EXISTS trg_os_uvr_profile_audit ON public.os_uvr_profile;
CREATE TRIGGER trg_os_uvr_profile_audit
    AFTER INSERT OR UPDATE OR DELETE ON public.os_uvr_profile
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_audit_trigger();

DROP TRIGGER IF EXISTS trg_os_uvr_profile_component_audit ON public.os_uvr_profile_component;
CREATE TRIGGER trg_os_uvr_profile_component_audit
    AFTER INSERT OR UPDATE OR DELETE ON public.os_uvr_profile_component
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_audit_trigger();

DROP TRIGGER IF EXISTS trg_os_uvr_prestacion_valuation_audit
    ON public.os_uvr_prestacion_valuation;
CREATE TRIGGER trg_os_uvr_prestacion_valuation_audit
    AFTER INSERT OR UPDATE OR DELETE ON public.os_uvr_prestacion_valuation
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_audit_trigger();

DROP TRIGGER IF EXISTS trg_os_uvr_prestacion_component_audit
    ON public.os_uvr_prestacion_component;
CREATE TRIGGER trg_os_uvr_prestacion_component_audit
    AFTER INSERT OR UPDATE OR DELETE ON public.os_uvr_prestacion_component
    FOR EACH ROW EXECUTE FUNCTION public.os_uvr_audit_trigger();

-- ---------------------------------------------------------------------------
-- 7. Privilegios: REVOKE por tabla, sin DEFAULT ACL global
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON TABLE
    public.os_prestacion,
    public.os_prestacion_codigo,
    public.os_uvr_profile,
    public.os_uvr_profile_component,
    public.os_uvr_prestacion_valuation,
    public.os_uvr_prestacion_component,
    public.v_os_uvr_prestacion_total,
    public.v_os_uvr_prestacion_public
FROM PUBLIC;

REVOKE ALL PRIVILEGES ON SEQUENCE
    public.os_prestacion_id_seq,
    public.os_prestacion_codigo_id_seq,
    public.os_uvr_profile_id_seq,
    public.os_uvr_profile_component_id_seq,
    public.os_uvr_prestacion_valuation_id_seq,
    public.os_uvr_prestacion_component_id_seq
FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE
            public.os_prestacion,
            public.os_prestacion_codigo,
            public.os_uvr_profile,
            public.os_uvr_profile_component,
            public.os_uvr_prestacion_valuation,
            public.os_uvr_prestacion_component,
            public.v_os_uvr_prestacion_total,
            public.v_os_uvr_prestacion_public
            FROM origen_admin';

        EXECUTE 'GRANT SELECT, INSERT, UPDATE ON TABLE
            public.os_prestacion,
            public.os_prestacion_codigo,
            public.os_uvr_profile,
            public.os_uvr_profile_component,
            public.os_uvr_prestacion_valuation,
            public.os_uvr_prestacion_component
            TO origen_admin';

        EXECUTE 'GRANT SELECT ON TABLE
            public.v_os_uvr_prestacion_total,
            public.v_os_uvr_prestacion_public
            TO origen_admin';
    END IF;

    -- El portal público solo lee la vista filtrada; nunca las tablas base.
    IF to_regrole('origen_med') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.v_os_uvr_prestacion_public FROM origen_med';
        EXECUTE 'GRANT SELECT ON TABLE public.v_os_uvr_prestacion_public TO origen_med';
    END IF;

    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE
            public.os_prestacion_id_seq,
            public.os_prestacion_codigo_id_seq,
            public.os_uvr_profile_id_seq,
            public.os_uvr_profile_component_id_seq,
            public.os_uvr_prestacion_valuation_id_seq,
            public.os_uvr_prestacion_component_id_seq
            TO origen_admin';
    END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- Comprobaciones posteriores (solo lectura)
-- ---------------------------------------------------------------------------
SELECT '=== U7-B · objetos ===' AS seccion;
SELECT tabla, filas FROM (
    SELECT 'os_prestacion' AS tabla, count(*) AS filas FROM public.os_prestacion
    UNION ALL SELECT 'os_prestacion_codigo', count(*) FROM public.os_prestacion_codigo
    UNION ALL SELECT 'os_uvr_profile', count(*) FROM public.os_uvr_profile
    UNION ALL SELECT 'os_uvr_profile_component', count(*) FROM public.os_uvr_profile_component
    UNION ALL SELECT 'os_uvr_prestacion_valuation', count(*) FROM public.os_uvr_prestacion_valuation
    UNION ALL SELECT 'os_uvr_prestacion_component', count(*) FROM public.os_uvr_prestacion_component
) x ORDER BY tabla;

-- Fin U7-B · gobernanza transversal de prestaciones.
