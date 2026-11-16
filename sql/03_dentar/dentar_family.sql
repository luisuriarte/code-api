-- =============================================================================
-- Origen Salud · Familia DENTAR · Registro de catálogos y migración de códigos
-- dentar_family.sql
-- =============================================================================
--
-- QUÉ HACE
--   1. Crea el registro de la familia DENTAR (`dentar_catalog`).
--   2. Declara los productos editoriales activos:
--        · DENTAR-PR → procedimientos / prestaciones → prefijo DNT-PR
--        · DENTAR-DX → diagnósticos odontológicos   → prefijo DNT-DX
--      DENTAR-AN (anatomía) y DENTAR-CL (hallazgos clínicos) quedan para una
--      segunda etapa; no se crean todavía.
--   3. Migra una base existente:
--        · agrega `catalog_id` a `dentar_concept`, `dentar_diagnosis` y
--          `dentar_category`;
--        · recodifica `DNT-000001…`  → `DNT-PR-000001…`
--        · recodifica `DNT-DX-0001…` → `DNT-DX-000001…`
--        · agrega los controles que impiden que un código use el prefijo de
--          otro catálogo.
--
-- ORDEN DE CARGA
--   Este archivo va ANTES de `sql/dentar_core_and_diagnosis.sql`:
--
--     psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/origen_catalog_engine.sql
--     psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/pmo.sql
--     psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/dentar_family.sql
--     psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/dentar_core_and_diagnosis.sql
--
--   En una base nueva, `dentar_family.sql` sólo crea el registro y la función
--   `dentar_catalog_id()`; el resto de las tablas las crea el núcleo.
--
-- Es idempotente: se puede volver a ejecutar sin duplicar catálogos ni códigos.
-- =============================================================================
SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. REGISTRO DE CATÁLOGOS DE LA FAMILIA
-- =============================================================================
CREATE TABLE IF NOT EXISTS dentar_catalog (
    id SERIAL PRIMARY KEY,
    family_code VARCHAR(20) NOT NULL DEFAULT 'dentar',
    code VARCHAR(20) NOT NULL UNIQUE,              -- 'dentar-pr', 'dentar-dx'
    short_name VARCHAR(20) NOT NULL UNIQUE,        -- 'DENTAR-PR', 'DENTAR-DX'
    name VARCHAR(150) NOT NULL,
    code_prefix VARCHAR(10) NOT NULL UNIQUE,       -- 'DNT-PR', 'DNT-DX'
    concept_kind VARCHAR(30) NOT NULL
        CHECK (concept_kind IN ('procedure', 'diagnosis', 'anatomy', 'clinical_finding')),
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('planned', 'active', 'inactive')),
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE dentar_catalog IS
    'Identidad de cada catálogo de la familia DENTAR. DENTAR es la marca paraguas; cada fila es un producto versionado e independiente.';
COMMENT ON COLUMN dentar_catalog.code_prefix IS
    'Prefijo permanente de los códigos del catálogo. Un código nunca cambia de catálogo ni se reutiliza.';

INSERT INTO dentar_catalog
    (family_code, code, short_name, name, code_prefix, concept_kind, description, status, sort_order)
VALUES
    ('dentar', 'dentar-pr', 'DENTAR-PR', 'DENTAR-PR · Procedimientos odontológicos',
     'DNT-PR', 'procedure',
     'Prestaciones y prácticas odontológicas. Mapeos previstos: Nomenclador Argentino, ADA CDT 2025 y SNOMED CT.',
     'active', 10),
    ('dentar', 'dentar-dx', 'DENTAR-DX', 'DENTAR-DX · Diagnósticos odontológicos',
     'DNT-DX', 'diagnosis',
     'Enfermedades, condiciones y alteraciones bucomaxilofaciales. Mapeos previstos: CIE-10 (K00-K14) y SNOMED CT.',
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
-- 2. FUNCIÓN AUXILIAR
-- =============================================================================
-- Permite usar defaults en las tablas editoriales sin hardcodear IDs seriales:
--     catalog_id INT NOT NULL DEFAULT dentar_catalog_id('dentar-pr')
CREATE OR REPLACE FUNCTION dentar_catalog_id(p_code TEXT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_id INT;
BEGIN
    SELECT id INTO v_id
      FROM dentar_catalog
     WHERE code = lower(btrim(p_code));

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Catálogo DENTAR desconocido: %', p_code
            USING HINT = 'Códigos válidos: dentar-pr, dentar-dx.';
    END IF;

    RETURN v_id;
END;
$$;

COMMENT ON FUNCTION dentar_catalog_id(TEXT) IS
    'Devuelve el id de dentar_catalog para un código de producto (dentar-pr, dentar-dx).';

-- =============================================================================
-- 3. MIGRACIÓN DE UNA BASE EXISTENTE
-- =============================================================================
-- Todo va condicionado a que la tabla exista: en una base nueva este bloque no
-- hace nada y el núcleo crea las columnas con el default correcto.

-- 3.1 dentar_concept (procedimientos)
DO $$
BEGIN
    IF to_regclass('public.dentar_concept') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE dentar_concept
                 ADD COLUMN IF NOT EXISTS catalog_id INT NOT NULL
                 DEFAULT dentar_catalog_id(''dentar-pr'')';

        EXECUTE 'ALTER TABLE dentar_concept
                 ALTER COLUMN catalog_id SET DEFAULT dentar_catalog_id(''dentar-pr'')';
        EXECUTE 'UPDATE dentar_concept SET catalog_id = dentar_catalog_id(''dentar-pr'')
                  WHERE catalog_id IS NULL';
        EXECUTE 'ALTER TABLE dentar_concept ALTER COLUMN catalog_id SET NOT NULL';

        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'fk_dentar_concept_catalog'
        ) THEN
            EXECUTE 'ALTER TABLE dentar_concept
                     ADD CONSTRAINT fk_dentar_concept_catalog
                     FOREIGN KEY (catalog_id) REFERENCES dentar_catalog(id)';
        END IF;
    END IF;
END $$;

-- 3.2 dentar_diagnosis (diagnósticos)
DO $$
BEGIN
    IF to_regclass('public.dentar_diagnosis') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE dentar_diagnosis
                 ADD COLUMN IF NOT EXISTS catalog_id INT NOT NULL
                 DEFAULT dentar_catalog_id(''dentar-dx'')';

        EXECUTE 'ALTER TABLE dentar_diagnosis
                 ALTER COLUMN catalog_id SET DEFAULT dentar_catalog_id(''dentar-dx'')';
        EXECUTE 'UPDATE dentar_diagnosis SET catalog_id = dentar_catalog_id(''dentar-dx'')
                  WHERE catalog_id IS NULL';
        EXECUTE 'ALTER TABLE dentar_diagnosis ALTER COLUMN catalog_id SET NOT NULL';

        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'fk_dentar_diagnosis_catalog'
        ) THEN
            EXECUTE 'ALTER TABLE dentar_diagnosis
                     ADD CONSTRAINT fk_dentar_diagnosis_catalog
                     FOREIGN KEY (catalog_id) REFERENCES dentar_catalog(id)';
        END IF;
    END IF;
END $$;

-- 3.3 dentar_category (las categorías pertenecen a un catálogo)
DO $$
BEGIN
    IF to_regclass('public.dentar_category') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE dentar_category
                 ADD COLUMN IF NOT EXISTS catalog_id INT NOT NULL
                 DEFAULT dentar_catalog_id(''dentar-pr'')';
        EXECUTE 'UPDATE dentar_category SET catalog_id = dentar_catalog_id(''dentar-pr'')
                  WHERE catalog_id IS NULL';

        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'fk_dentar_category_catalog'
        ) THEN
            EXECUTE 'ALTER TABLE dentar_category
                     ADD CONSTRAINT fk_dentar_category_catalog
                     FOREIGN KEY (catalog_id) REFERENCES dentar_catalog(id)';
        END IF;
    END IF;
END $$;

-- 3.4 Recodificación: procedimientos DNT-NNNNNN -> DNT-PR-NNNNNN
DO $$
DECLARE
    v_viejos INT;
    v_nuevos INT;
BEGIN
    IF to_regclass('public.dentar_concept') IS NULL THEN
        RETURN;
    END IF;

    SELECT count(*) INTO v_viejos FROM dentar_concept WHERE code ~ '^DNT-[0-9]{6}$';
    SELECT count(*) INTO v_nuevos FROM dentar_concept WHERE code ~ '^DNT-PR-[0-9]{6}$';

    IF v_viejos > 0 AND v_nuevos > 0 THEN
        RAISE EXCEPTION
            'Conviven códigos DENTAR antiguos (DNT-NNNNNN) y nuevos (DNT-PR-NNNNNN). Revisá y unificá antes de migrar.'
            USING HINT = 'SELECT code FROM dentar_concept WHERE code ~ ''^DNT-(PR-)?[0-9]{6}$'' ORDER BY code;';
    END IF;

    IF v_viejos > 0 THEN
        UPDATE dentar_concept
           SET code = 'DNT-PR-' || substring(code FROM 5)
         WHERE code ~ '^DNT-[0-9]{6}$';

        RAISE NOTICE 'DENTAR-PR: % códigos migrados a DNT-PR-NNNNNN.', v_viejos;
    END IF;
END $$;

-- 3.5 Recodificación: diagnósticos DNT-DX-NNNN -> DNT-DX-NNNNNN
DO $$
DECLARE
    v_viejos INT;
    v_nuevos INT;
BEGIN
    IF to_regclass('public.dentar_diagnosis') IS NULL THEN
        RETURN;
    END IF;

    SELECT count(*) INTO v_viejos FROM dentar_diagnosis WHERE code ~ '^DNT-DX-[0-9]{1,5}$';
    SELECT count(*) INTO v_nuevos FROM dentar_diagnosis WHERE code ~ '^DNT-DX-[0-9]{6}$';

    IF v_viejos > 0 AND v_nuevos > 0 THEN
        RAISE EXCEPTION
            'Conviven códigos DENTAR-DX antiguos y nuevos. Revisá y unificá antes de migrar.'
            USING HINT = 'SELECT code FROM dentar_diagnosis WHERE code ~ ''^DNT-DX-[0-9]{1,6}$'' ORDER BY code;';
    END IF;

    IF v_viejos > 0 THEN
        UPDATE dentar_diagnosis
           SET code = 'DNT-DX-' || lpad(substring(code FROM 8), 6, '0')
         WHERE code ~ '^DNT-DX-[0-9]{1,5}$';

        RAISE NOTICE 'DENTAR-DX: % códigos migrados a DNT-DX-NNNNNN.', v_viejos;
    END IF;
END $$;

-- =============================================================================
-- 4. CONTROL DE PREFIJO POR CATÁLOGO
-- =============================================================================
-- Un código permanente no puede usar el prefijo de otro catálogo. El control se
-- hace con un trigger para que valga tanto para el seed SQL como para el
-- importador CSV y para cualquier edición manual.
CREATE OR REPLACE FUNCTION dentar_assert_catalog_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_prefix TEXT;
BEGIN
    SELECT upper(code_prefix) INTO v_prefix
      FROM dentar_catalog
     WHERE id = NEW.catalog_id;

    IF v_prefix IS NULL THEN
        RAISE EXCEPTION 'catalog_id % no existe en dentar_catalog', NEW.catalog_id;
    END IF;

    IF NEW.code !~ ('^' || v_prefix || '-[0-9]{6}$') THEN
        RAISE EXCEPTION
            'El código % no corresponde al catálogo seleccionado (prefijo esperado: %-NNNNNN).',
            NEW.code, v_prefix
            USING HINT = 'DENTAR-PR usa DNT-PR-NNNNNN; DENTAR-DX usa DNT-DX-NNNNNN.';
    END IF;

    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF to_regclass('public.dentar_concept') IS NOT NULL THEN
        EXECUTE 'CREATE OR REPLACE TRIGGER trg_dentar_concept_code
                 BEFORE INSERT OR UPDATE OF code, catalog_id ON dentar_concept
                 FOR EACH ROW EXECUTE FUNCTION dentar_assert_catalog_code()';
    END IF;

    IF to_regclass('public.dentar_diagnosis') IS NOT NULL THEN
        EXECUTE 'CREATE OR REPLACE TRIGGER trg_dentar_diagnosis_code
                 BEFORE INSERT OR UPDATE OF code, catalog_id ON dentar_diagnosis
                 FOR EACH ROW EXECUTE FUNCTION dentar_assert_catalog_code()';
    END IF;
END $$;

-- =============================================================================
-- 5. VERIFICACIÓN
-- =============================================================================
SELECT code AS catalogo,
       short_name AS nombre_corto,
       code_prefix AS prefijo,
       concept_kind AS tipo_concepto,
       status
  FROM dentar_catalog
 ORDER BY sort_order, code;
