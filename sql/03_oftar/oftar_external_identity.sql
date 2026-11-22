-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud · Identidad externa de OFTAR
-- sql/03_oftar/oftar_external_identity.sql
-- =============================================================================
--
-- QUÉ RESUELVE
--   Hoy el mismo código externo puede estar en dos conceptos, en dos
--   diagnósticos o en ambas tablas de mapeo: las UNIQUE existentes están
--   limitadas al concepto/diagnóstico dueño. Además la normalización del
--   código existe solo al leer en Browse (replace(...,'.','')), nunca al
--   escribir.
--
--   Este archivo crea un registro central con:
--     · normalización canónica: upper(btrim()) sin puntos, espacios ni guiones;
--     · UNIQUE (system_code, code_normalized);
--     · un dueño declarado por sistema, para que CIE-10 no pueda aterrizar en
--       oftar-pr ni el Nomenclador en oftar-dx;
--     · triggers que vinculan automáticamente ambos mapeos al registro.
--
--   Es aditivo: no modifica importadores existentes ni datos cargados.
--   Requiere oftar_family.sql y oftar_core.sql ya aplicados.
-- PostgreSQL 18.
-- =============================================================================
BEGIN;

SET client_encoding = 'UTF8';

DO $$
BEGIN
    IF to_regclass('public.oftar_catalog') IS NULL
       OR to_regclass('public.oftar_terminology_system') IS NULL
       OR to_regclass('public.oftar_concept_mapping') IS NULL
       OR to_regclass('public.oftar_diagnosis_mapping') IS NULL THEN
        RAISE EXCEPTION 'Falta la estructura base de OFTAR.'
            USING HINT = 'Ejecutá oftar_family.sql y oftar_core.sql antes que este archivo.';
    END IF;
END $$;

-- =============================================================================
-- 1. NORMALIZACIÓN CANÓNICA
-- =============================================================================
-- 'H40.111' -> 'H40111'; ' 01.01 ' -> '0101'; '080N0ZZ' -> '080N0ZZ'.
-- IMMUTABLE para poder usarla como columna generada y en índices.
CREATE OR REPLACE FUNCTION public.oftar_normalize_external_code(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
    SELECT upper(regexp_replace(btrim(p_code), '[\s.\-]+', '', 'g'));
$$;

COMMENT ON FUNCTION public.oftar_normalize_external_code(TEXT) IS
    'Normaliza un código externo a mayúsculas, sin espacios, puntos ni guiones. Clave de dedupe de OFTAR.';

-- =============================================================================
-- 2. REGISTRO CENTRAL DE IDENTIDAD EXTERNA
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.oftar_external_identity (
    id BIGSERIAL PRIMARY KEY,
    system_code VARCHAR(30) NOT NULL
        REFERENCES public.oftar_terminology_system(code) ON UPDATE CASCADE,
    code_raw VARCHAR(200) NOT NULL,
    code_normalized VARCHAR(200)
        GENERATED ALWAYS AS (public.oftar_normalize_external_code(code_raw)) STORED,
    owner_catalog VARCHAR(30) NOT NULL
        CHECK (owner_catalog IN ('oftar-pr', 'oftar-dx', 'shared')),
    entity_kind VARCHAR(20) NOT NULL
        CHECK (entity_kind IN ('concept', 'diagnosis', 'shared')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_oftar_external_identity UNIQUE (system_code, code_normalized),
    CONSTRAINT ck_oftar_external_identity_not_empty CHECK (length(code_normalized) > 0)
);

COMMENT ON TABLE public.oftar_external_identity IS
    'Un código externo normalizado tiene un solo dueño. Las UNIQUE por concepto/diagnóstico no impedían duplicados entre ítems.';
COMMENT ON COLUMN public.oftar_external_identity.owner_catalog IS
    'oftar-pr para prestaciones, oftar-dx para diagnósticos, shared para sistemas legítimamente compartidos como SNOMED-CT.';

CREATE INDEX IF NOT EXISTS idx_oftar_external_identity_owner
    ON public.oftar_external_identity (owner_catalog, system_code);

-- =============================================================================
-- 3. VÍNCULO DESDE LOS MAPEOS
-- =============================================================================
ALTER TABLE public.oftar_concept_mapping
    ADD COLUMN IF NOT EXISTS identity_id BIGINT
        REFERENCES public.oftar_external_identity(id) ON DELETE RESTRICT;

ALTER TABLE public.oftar_diagnosis_mapping
    ADD COLUMN IF NOT EXISTS identity_id BIGINT
        REFERENCES public.oftar_external_identity(id) ON DELETE RESTRICT;

-- =============================================================================
-- 4. TRIGGER DE REGISTRO Y CONTROL DE DUEÑO
-- =============================================================================
CREATE OR REPLACE FUNCTION public.oftar_bind_external_identity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_parent_owner VARCHAR(30);
    v_owner VARCHAR(30);
    v_kind VARCHAR(20);
    v_existing_owner VARCHAR(30);
    v_existing_kind VARCHAR(20);
    v_id BIGINT;
BEGIN
    IF TG_TABLE_NAME = 'oftar_concept_mapping' THEN
        SELECT oc.code INTO v_parent_owner
          FROM public.oftar_concept_version cv
          JOIN public.oftar_concept c ON c.id = cv.concept_id
          JOIN public.oftar_catalog oc ON oc.id = c.catalog_id
         WHERE cv.id = NEW.concept_version_id;
        v_kind := 'concept';
    ELSE
        SELECT oc.code INTO v_parent_owner
          FROM public.oftar_diagnosis d
          JOIN public.oftar_catalog oc ON oc.id = d.catalog_id
         WHERE d.id = NEW.diagnosis_id;
        v_kind := 'diagnosis';
    END IF;

    IF v_parent_owner IS NULL THEN
        RAISE EXCEPTION 'No se pudo resolver el catálogo dueño del mapeo %', NEW.id
            USING HINT = 'Revise concept_version_id / diagnosis_id.';
    END IF;

    -- Un sistema tiene un dueño declarado. SNOMED-CT es la excepción legítima:
    -- describe procedimientos y diagnósticos y puede compartirse.
    IF NEW.system_code = 'CIE-10' THEN
        IF v_parent_owner <> 'oftar-dx' THEN
            RAISE EXCEPTION 'CIE-10 no puede mapearse desde %: es un sistema de diagnósticos.', v_parent_owner
                USING HINT = 'Los diagnósticos CIE-10 pertenecen a oftar-dx.';
        END IF;
        v_owner := 'oftar-dx';
        v_kind := 'diagnosis';
    ELSIF NEW.system_code IN ('NOMENCLADOR-AR', 'ICD-10-PCS', 'CPT', 'LOINC') THEN
        IF v_parent_owner <> 'oftar-pr' THEN
            RAISE EXCEPTION '% no puede mapearse desde %: describe prestaciones.', NEW.system_code, v_parent_owner
                USING HINT = 'Ese sistema pertenece a oftar-pr.';
        END IF;
        v_owner := 'oftar-pr';
        v_kind := 'concept';
    ELSIF NEW.system_code = 'SNOMED-CT' THEN
        v_owner := 'shared';
        v_kind := 'shared';
    ELSE
        v_owner := v_parent_owner;
    END IF;

    SELECT id, owner_catalog, entity_kind
      INTO v_id, v_existing_owner, v_existing_kind
      FROM public.oftar_external_identity
     WHERE system_code = NEW.system_code
       AND code_normalized = public.oftar_normalize_external_code(NEW.external_code);

    IF FOUND THEN
        IF v_existing_owner <> 'shared'
           AND v_owner <> 'shared'
           AND v_existing_owner <> v_owner THEN
            RAISE EXCEPTION
                'El código externo % (%) ya pertenece a %; no puede registrarse también en %.',
                NEW.external_code, NEW.system_code, v_existing_owner, v_owner
                USING HINT = 'Un código externo tiene un solo dueño: CIE-10 → oftar-dx; Nomenclador/PCS/CPT/LOINC → oftar-pr.';
        END IF;
    ELSE
        INSERT INTO public.oftar_external_identity
               (system_code, code_raw, owner_catalog, entity_kind)
        VALUES (NEW.system_code, NEW.external_code, v_owner, v_kind)
        ON CONFLICT (system_code, code_normalized) DO NOTHING
        RETURNING id INTO v_id;

        IF v_id IS NULL THEN
            SELECT id, owner_catalog, entity_kind
              INTO v_id, v_existing_owner, v_existing_kind
              FROM public.oftar_external_identity
             WHERE system_code = NEW.system_code
               AND code_normalized = public.oftar_normalize_external_code(NEW.external_code);

            IF v_existing_owner <> 'shared'
               AND v_owner <> 'shared'
               AND v_existing_owner <> v_owner THEN
                RAISE EXCEPTION
                    'El código externo % (%) ya pertenece a %; no puede registrarse también en %.',
                    NEW.external_code, NEW.system_code, v_existing_owner, v_owner;
            END IF;
        END IF;
    END IF;

    NEW.identity_id := v_id;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.oftar_bind_external_identity() IS
    'Registra y vincula el external_code de un mapeo OFTAR; rechaza el mismo código normalizado con distinto dueño.';

CREATE OR REPLACE TRIGGER trg_oftar_concept_mapping_identity
    BEFORE INSERT OR UPDATE OF external_code, system_code ON public.oftar_concept_mapping
    FOR EACH ROW EXECUTE FUNCTION public.oftar_bind_external_identity();

CREATE OR REPLACE TRIGGER trg_oftar_diagnosis_mapping_identity
    BEFORE INSERT OR UPDATE OF external_code, system_code ON public.oftar_diagnosis_mapping
    FOR EACH ROW EXECUTE FUNCTION public.oftar_bind_external_identity();

-- =============================================================================
-- 5. UN TÉRMINO PREFERIDO POR IDIOMA Y VERSIÓN
-- =============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS uq_oftar_term_preferred
    ON public.oftar_term (concept_version_id, language, term_type)
    WHERE term_type = 'preferred';

CREATE UNIQUE INDEX IF NOT EXISTS uq_oftar_diagnosis_term_preferred
    ON public.oftar_diagnosis_term (diagnosis_id, language, term_type)
    WHERE term_type = 'preferred';

-- =============================================================================
-- 6. PRIVILEGIOS EXPLÍCITOS
-- =============================================================================
REVOKE ALL PRIVILEGES ON TABLE public.oftar_external_identity FROM PUBLIC;
REVOKE ALL PRIVILEGES ON FUNCTION public.oftar_normalize_external_code(TEXT) FROM PUBLIC;
REVOKE ALL PRIVILEGES ON FUNCTION public.oftar_bind_external_identity() FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.oftar_external_identity FROM origen_admin';
        EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION public.oftar_normalize_external_code(TEXT) FROM origen_admin';
        EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION public.oftar_bind_external_identity() FROM origen_admin';
    END IF;

    IF to_regrole('origen_med') IS NOT NULL THEN
        EXECUTE 'GRANT SELECT ON TABLE public.oftar_external_identity TO origen_med';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.oftar_normalize_external_code(TEXT) TO origen_med';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.oftar_bind_external_identity() TO origen_med';
    END IF;
END $$;

-- =============================================================================
-- 7. VERIFICACIÓN (solo lectura)
-- =============================================================================
SELECT system_code, owner_catalog, entity_kind, count(*) AS codigos
  FROM public.oftar_external_identity
 GROUP BY system_code, owner_catalog, entity_kind
 ORDER BY system_code, owner_catalog;

SELECT count(*) AS codigos_duplicados_por_sistema
  FROM (
      SELECT system_code, code_normalized
        FROM public.oftar_external_identity
       GROUP BY system_code, code_normalized
      HAVING count(*) > 1
  ) AS d;

SELECT 'concept' AS origen, count(*) AS mapeos_sin_identidad
  FROM public.oftar_concept_mapping WHERE identity_id IS NULL
UNION ALL
SELECT 'diagnosis', count(*)
  FROM public.oftar_diagnosis_mapping WHERE identity_id IS NULL;

COMMIT;

-- Fin de oftar_external_identity.sql
