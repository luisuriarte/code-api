-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud · Familia OFTAR
-- sql/03_oftar/oftar_family.sql
-- =============================================================================
--
-- QUÉ HACE
--   1. Crea `oftar_catalog`: identidad permanente de la familia OFTAR.
--   2. Declara los dos únicos productos editoriales de la familia:
--        · OFTAR-PR → procedimientos y prestaciones → prefijo OFTAR-PR
--        · OFTAR-DX → diagnósticos oftalmológicos    → prefijo OFTAR-DX
--      No se crean OFTAR-CIR, OFTAR-IMG, OFTAR-TER ni OFTAR-MED: las cirugías,
--      imágenes y tratamientos son categorías internas de OFTAR-PR, y los
--      medicamentos e insumos pertenecen a catálogos transversales.
--   3. Crea `oftar_catalog_id()` y el validador de prefijo por catálogo.
--   4. Aplica REVOKE explícito por tabla/función y GRANT de solo lectura a
--      `origen_med`. No modifica los privilegios por defecto del esquema.
--
-- ORDEN DE CARGA (en la base `origen_codes`)
--   psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/02_catalogs/origen_catalog_engine.sql
--   psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/03_oftar/oftar_family.sql
--   psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/03_oftar/oftar_core.sql
--
-- Idempotente: se puede volver a ejecutar sin duplicar catálogos ni códigos.
-- PostgreSQL 18.
-- =============================================================================
BEGIN;

SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. REGISTRO DE CATÁLOGOS DE LA FAMILIA
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.oftar_catalog (
    id SERIAL PRIMARY KEY,
    family_code VARCHAR(20) NOT NULL DEFAULT 'oftar',
    code VARCHAR(30) NOT NULL UNIQUE,
    short_name VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    code_prefix VARCHAR(20) NOT NULL UNIQUE,
    concept_kind VARCHAR(30) NOT NULL
        CHECK (concept_kind IN ('procedure', 'diagnosis')),
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('planned', 'active', 'inactive')),
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.oftar_catalog IS
    'Identidad de cada catálogo de la familia OFTAR. OFTAR es la marca paraguas; cada fila es un producto versionado e independiente.';
COMMENT ON COLUMN public.oftar_catalog.code_prefix IS
    'Prefijo permanente de los códigos del catálogo. Un código nunca cambia de catálogo ni se reutiliza.';

INSERT INTO public.oftar_catalog
    (family_code, code, short_name, name, code_prefix, concept_kind, description, status, sort_order)
VALUES
    ('oftar', 'oftar-pr', 'OFTAR-PR', 'OFTAR-PR · Catálogo de Procedimientos Oftalmológicos',
     'OFTAR-PR', 'procedure',
     'Prestaciones realizadas sobre el paciente: consultas, exámenes, estudios diagnósticos, tratamientos, láser, inyecciones intravítreas y cirugías. Único catálogo OFTAR con valoración UVR.',
     'active', 10),
    ('oftar', 'oftar-dx', 'OFTAR-DX', 'OFTAR-DX · Catálogo de Diagnósticos Oftalmológicos',
     'OFTAR-DX', 'diagnosis',
     'Enfermedades, trastornos y condiciones clínicas oftalmológicas (CIE-10 H00-H59). No recibe UVR: la valoración corresponde a la prestación, no al diagnóstico.',
     'active', 20)
ON CONFLICT (code) DO UPDATE
   SET family_code  = EXCLUDED.family_code,
       short_name   = EXCLUDED.short_name,
       name         = EXCLUDED.name,
       code_prefix  = EXCLUDED.code_prefix,
       concept_kind = EXCLUDED.concept_kind,
       description  = EXCLUDED.description,
       status       = EXCLUDED.status,
       sort_order   = EXCLUDED.sort_order;

-- =============================================================================
-- 2. FUNCIONES AUXILIARES
-- =============================================================================
-- Permite usar defaults en las tablas editoriales sin hardcodear IDs seriales.
CREATE OR REPLACE FUNCTION public.oftar_catalog_id(p_code TEXT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_id INT;
BEGIN
    SELECT id INTO v_id
      FROM public.oftar_catalog
     WHERE code = lower(btrim(p_code));

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Catálogo OFTAR desconocido: %', p_code
            USING HINT = 'Códigos válidos: oftar-pr, oftar-dx.';
    END IF;

    RETURN v_id;
END;
$$;

COMMENT ON FUNCTION public.oftar_catalog_id(TEXT) IS
    'Devuelve el id de oftar_catalog para un código de producto (oftar-pr, oftar-dx).';

-- Un código permanente no puede usar el prefijo del otro catálogo. El control
-- se hace con trigger para que valga para seed SQL, importador y edición manual.
CREATE OR REPLACE FUNCTION public.oftar_assert_catalog_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_prefix TEXT;
BEGIN
    SELECT upper(code_prefix) INTO v_prefix
      FROM public.oftar_catalog
     WHERE id = NEW.catalog_id;

    IF v_prefix IS NULL THEN
        RAISE EXCEPTION 'catalog_id % no existe en oftar_catalog', NEW.catalog_id;
    END IF;

    IF NEW.code !~ ('^' || v_prefix || '-[0-9]{6}$') THEN
        RAISE EXCEPTION
            'El código % no corresponde al catálogo seleccionado (prefijo esperado: %-NNNNNN).',
            NEW.code, v_prefix
            USING HINT = 'OFTAR-PR usa OFTAR-PR-NNNNNN; OFTAR-DX usa OFTAR-DX-NNNNNN.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.oftar_assert_catalog_code() IS
    'Valida que el código permanente use el prefijo del catálogo OFTAR al que pertenece.';

-- Los triggers se crean cuando existen las tablas editoriales (oftar_core.sql).
DO $$
BEGIN
    IF to_regclass('public.oftar_concept') IS NOT NULL THEN
        EXECUTE 'CREATE OR REPLACE TRIGGER trg_oftar_concept_code
                  BEFORE INSERT OR UPDATE OF code, catalog_id ON public.oftar_concept
                  FOR EACH ROW EXECUTE FUNCTION public.oftar_assert_catalog_code()';
    END IF;

    IF to_regclass('public.oftar_diagnosis') IS NOT NULL THEN
        EXECUTE 'CREATE OR REPLACE TRIGGER trg_oftar_diagnosis_code
                  BEFORE INSERT OR UPDATE OF code, catalog_id ON public.oftar_diagnosis
                  FOR EACH ROW EXECUTE FUNCTION public.oftar_assert_catalog_code()';
    END IF;
END $$;

-- =============================================================================
-- 3. PRIVILEGIOS EXPLÍCITOS
-- =============================================================================
REVOKE ALL PRIVILEGES ON TABLE public.oftar_catalog FROM PUBLIC;
REVOKE ALL PRIVILEGES ON FUNCTION public.oftar_catalog_id(TEXT) FROM PUBLIC;
REVOKE ALL PRIVILEGES ON FUNCTION public.oftar_assert_catalog_code() FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.oftar_catalog FROM origen_admin';
        EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION public.oftar_catalog_id(TEXT) FROM origen_admin';
        EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION public.oftar_assert_catalog_code() FROM origen_admin';
    END IF;

    IF to_regrole('origen_med') IS NOT NULL THEN
        EXECUTE 'GRANT USAGE ON SCHEMA public TO origen_med';
        EXECUTE 'GRANT SELECT ON TABLE public.oftar_catalog TO origen_med';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.oftar_catalog_id(TEXT) TO origen_med';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.oftar_assert_catalog_code() TO origen_med';
    END IF;
END $$;

-- =============================================================================
-- 4. VERIFICACIÓN (solo lectura)
-- =============================================================================
SELECT code AS catalogo,
       short_name AS nombre_corto,
       code_prefix AS prefijo,
       concept_kind AS tipo_concepto,
       status
  FROM public.oftar_catalog
 ORDER BY sort_order, code;

COMMIT;

-- Fin de oftar_family.sql
