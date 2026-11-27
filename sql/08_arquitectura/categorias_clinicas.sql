-- Origen Salud · Categorías del concepto (taxonomía clínica transversal)
--
-- Este script es aditivo y no destructivo:
--   · no renombra ni borra os_catalog_category;
--   · no altera los capítulos fuente de DENTAR, OFTAR, PMO ni CDT;
--   · no cambia el catálogo al que pertenece cada código;
--   · separa "categoría del concepto" de "catálogo de origen".
--
-- Responsable: ejecutar en ventana controlada, con backup previo. El asistente
-- no ejecuta SQL.

BEGIN;

-- 1. Taxonomía global del concepto ------------------------------------------------
CREATE TABLE IF NOT EXISTS public.os_clinical_category (
    code        VARCHAR(50) PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    definition  TEXT NOT NULL,
    examples    TEXT,
    sort_order  INT NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'active'
                CHECK (status IN ('active', 'inactive'))
);

COMMENT ON TABLE public.os_clinical_category IS
    'Categoría clínica del concepto, independiente del catálogo al que pertenece el código.';

INSERT INTO public.os_clinical_category
    (code, name, definition, examples, sort_order)
VALUES
    ('CLIN-DIAG', 'Diagnósticos',
     'Enfermedades y condiciones patológicas',
     'CIE-10, diagnósticos odontológicos', 10),
    ('CLIN-PROC', 'Procedimientos',
     'Intervenciones diagnósticas y terapéuticas',
     'Cirugías, prácticas odontológicas', 20),
    ('CLIN-PREST', 'Prestaciones sanitarias',
     'Servicios y prácticas facturables o reconocibles',
     'PMO, nomencladores médicos', 30),
    ('CLIN-MED', 'Medicamentos',
     'Fármacos, principios activos y presentaciones',
     'ANMAT, medicamentos', 40),
    ('CLIN-EST', 'Estudios y pruebas diagnósticas',
     'Análisis, pruebas y estudios complementarios',
     'LOINC, laboratorio', 50),
    ('CLIN-OBS', 'Observaciones y mediciones clínicas',
     'Variables clínicas y resultados observables',
     'Presión arterial, glucemia, temperatura', 60),
    ('CLIN-SINT', 'Signos y síntomas',
     'Manifestaciones clínicas referidas u observadas',
     'Dolor, fiebre, disnea', 70),
    ('CLIN-DISP', 'Dispositivos médicos e insumos',
     'Equipamiento, prótesis, implantes y materiales',
     'Prótesis, catéteres, implantes', 80),
    ('CLIN-ANAT', 'Anatomía y estructuras corporales',
     'Órganos, tejidos, regiones y estructuras anatómicas',
     'Dientes, superficies dentarias, órganos', 90),
    ('CLIN-MICRO', 'Microorganismos y agentes biológicos',
     'Bacterias, virus, hongos y otros agentes',
     'SARS-CoV-2, Escherichia coli', 100),
    ('CLIN-ALERG', 'Alergias e intolerancias',
     'Reacciones alérgicas e intolerancias',
     'Alergia a penicilina', 110),
    ('CLIN-HALLAZGO', 'Hallazgos clínicos',
     'Hallazgos de exploración, imágenes y anatomía patológica',
     'Lesiones, masas, hallazgos radiológicos', 120)
ON CONFLICT (code) DO UPDATE SET
    name       = EXCLUDED.name,
    definition = EXCLUDED.definition,
    examples   = EXCLUDED.examples,
    sort_order = EXCLUDED.sort_order,
    status     = EXCLUDED.status;

-- 2. Trazabilidad desde la categoría fuente ------------------------------------
-- La categoría fuente (capítulo del catálogo) se conserva. Nunca se sobreescribe.
CREATE TABLE IF NOT EXISTS public.os_catalog_category_clinical_map (
    category_id            INT NOT NULL
        REFERENCES public.os_catalog_category(id) ON DELETE CASCADE,
    clinical_category_code VARCHAR(50) NOT NULL
        REFERENCES public.os_clinical_category(code),
    is_primary             BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (category_id, clinical_category_code)
);

CREATE INDEX IF NOT EXISTS os_catalog_category_clinical_map_code_idx
    ON public.os_catalog_category_clinical_map(clinical_category_code);

INSERT INTO public.os_catalog_category_clinical_map
       (category_id, clinical_category_code, is_primary)
SELECT c.id, m.clinical_code, TRUE
  FROM public.os_catalog_category c
  JOIN public.os_catalog cat ON cat.id = c.catalog_id
  JOIN (VALUES
      ('dentar-pr', 'CAT-DIAG', 'CLIN-DIAG'),
      ('dentar-pr', 'CAT-PREV', 'CLIN-PROC'),
      ('dentar-pr', 'CAT-REST', 'CLIN-PROC'),
      ('dentar-pr', 'CAT-ENDO', 'CLIN-PROC'),
      ('dentar-pr', 'CAT-PERI', 'CLIN-PROC'),
      ('dentar-pr', 'CAT-SURG', 'CLIN-PROC'),
      ('dentar-pr', 'CAT-SURG-MAX', 'CLIN-PROC'),
      ('dentar-pr', 'CAT-ORTHO', 'CLIN-PROC'),
      ('dentar-pr', 'CAT-IMPL', 'CLIN-DISP'),
      ('dentar-pr', 'CAT-PROSTH-R', 'CLIN-DISP'),
      ('dentar-pr', 'CAT-PROSTH-F', 'CLIN-DISP'),
      ('dentar-pr', 'CAT-ADJ', 'CLIN-PREST'),
      ('dentar-dx', 'CAT-DX', 'CLIN-DIAG'),
      ('oftar-pr', 'GRP-EVAL', 'CLIN-PROC'),
      ('oftar-pr', 'GRP-DIAG', 'CLIN-DIAG'),
      ('oftar-pr', 'GRP-TER', 'CLIN-PROC'),
      ('oftar-pr', 'GRP-OCUL', 'CLIN-ANAT'),
      ('oftar-pr', 'CONSULT', 'CLIN-PROC'),
      ('oftar-pr', 'EXAM', 'CLIN-EST'),
      ('oftar-pr', 'DIAG', 'CLIN-EST'),
      ('oftar-pr', 'IMG', 'CLIN-EST'),
      ('oftar-pr', 'TER', 'CLIN-PROC'),
      ('oftar-pr', 'CIR', 'CLIN-PROC'),
      ('oftar-pr', 'OCUL', 'CLIN-PROC'),
      ('oftar-pr', 'LAGR', 'CLIN-PROC'),
      ('oftar-dx', 'CAT-DX', 'CLIN-DIAG')
  ) AS m(catalog_code, legacy_code, clinical_code)
    ON m.catalog_code = cat.code
   AND m.legacy_code = c.code
ON CONFLICT DO NOTHING;

-- 3. Valor por catálogo cuando la categoría fuente no es estable ----------------
-- PMO usa el código de práctica como os_catalog_category.code; por eso se
-- resuelve por catálogo y no por capítulo.
CREATE TABLE IF NOT EXISTS public.os_catalog_clinical_default (
    catalog_code           VARCHAR(50) PRIMARY KEY
        REFERENCES public.os_catalog(code) ON DELETE CASCADE,
    clinical_category_code VARCHAR(50) NOT NULL
        REFERENCES public.os_clinical_category(code)
);

INSERT INTO public.os_catalog_clinical_default
    (catalog_code, clinical_category_code)
VALUES
    ('nn-pmo', 'CLIN-PREST'),
    ('dentar-pr', 'CLIN-PROC'),
    ('dentar-dx', 'CLIN-DIAG'),
    ('nomenclador-odontologico-ar', 'CLIN-PROC'),
    ('oftar-pr', 'CLIN-PROC'),
    ('oftar-dx', 'CLIN-DIAG'),
    ('nomenclador-oftalmologico-cao-ar', 'CLIN-PREST'),
    ('nomenclador-oftalmologico-regional-ar', 'CLIN-PREST')
ON CONFLICT (catalog_code) DO UPDATE SET
    clinical_category_code = EXCLUDED.clinical_category_code;

-- 4. Categoría asignada administrativamente a un código --------------------------
-- Es la única tabla que edita la administración, siempre mediante propuesta
-- gobernada con dos revisiones y decisión con evidencia.
CREATE TABLE IF NOT EXISTS public.os_catalog_item_clinical_category (
    item_id                INT PRIMARY KEY
        REFERENCES public.os_catalog_item(id) ON DELETE CASCADE,
    clinical_category_code VARCHAR(50) NOT NULL
        REFERENCES public.os_clinical_category(code),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_request_id      BIGINT
);

COMMENT ON TABLE public.os_catalog_item_clinical_category IS
    'Categoría clínica del concepto, asignada por gobernanza; no redefine el catálogo de origen.';

CREATE INDEX IF NOT EXISTS os_catalog_item_clinical_category_code_idx
    ON public.os_catalog_item_clinical_category(clinical_category_code);

-- 5. Permisos de lectura pública -------------------------------------------------
-- El frente usa la conexión origen_med. El rol puede no existir en entornos de
-- desarrollo: el bloque es idempotente y omite la concesión si no está creado.
DO $grants$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'origen_med') THEN
        GRANT SELECT ON TABLE
            public.os_clinical_category,
            public.os_catalog_category_clinical_map,
            public.os_catalog_clinical_default,
            public.os_catalog_item_clinical_category
        TO origen_med;
    END IF;
END
$grants$;

COMMIT;

-- Verificación rápida (solo lectura):
-- SELECT code, name, sort_order FROM public.os_clinical_category ORDER BY sort_order;
-- SELECT count(*) AS mapas FROM public.os_catalog_category_clinical_map;
-- SELECT count(*) AS defaults FROM public.os_catalog_clinical_default;
