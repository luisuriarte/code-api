-- =============================================================================
-- FASE 7 (§16) · Módulo de valoración relativa UVR
-- =============================================================================
-- NOTA DE NUMERACIÓN: el nombre del archivo conserva la numeración histórica
-- de la carpeta. Según §16 del documento de arquitectura esto es la FASE 7.
-- Ver la tabla de alineación en sql/08_arquitectura/README.md.
--
-- PROPUESTA PREPARADA EL 2026-11-20. NO EJECUTAR SIN APROBACIÓN Y BACKUP.
-- Autorización registrada: "Fase 7: UVR". Requiere la Fase 1 y la Fase 4
-- ejecutadas (os_review_state, os_catalog_relation) y backup verificado.
--
-- ESTRUCTURA VACÍA: no carga valores UVR, componentes, conversiones monetarias,
-- índices geográficos ni pagos estimados. La única fila sembrada es la
-- elegibilidad del catálogo REAL 'dentar-pr' (prestaciones odontológicas),
-- derivada de os_catalog; no se inventan dominios ni se habilita DENTAR-DX.
--
-- REGLAS DURAS §10.3 aplicadas:
--   1. Solo prestaciones: trigger de elegibilidad bloquea ítems que no
--      pertenezcan a un catálogo elegible activo. DENTAR-DX queda sin UVR.
--   2. Valoración relativa y conversión monetaria en tablas separadas.
--   3. Histórico versionado: nueva valoración = nueva fila (version_tag en la
--      UNIQUE); no se renombran columnas ni se borran tablas.
--   4. Sin evidencia no se cargan índices regionales ni valores monetarios.
--   5. total_uvr es derivado: se calcula en la vista, nunca se almacena como
--      columna editable. No constituye arancel ni pago oficial.
--   6. Fuentes verificables y revisión son obligatorias en todas las tablas.
--
-- ADITIVO Y TRANSACCIONAL:
--   · CREATE TABLE IF NOT EXISTS, CREATE OR REPLACE FUNCTION/VIEW,
--     CREATE TRIGGER IF NOT EXISTS, INSERT ... ON CONFLICT DO NOTHING, REVOKE.
--   · DROP TRIGGER IF EXISTS solo sobre el trigger propio de este módulo, para
--     idempotencia. No elimina tablas, columnas ni datos; no hay sentencias
--     destructivas de datos.
--   · No modifica importadores, API pública, catálogos publicados ni
--     Browse Codes. No existe ruta /v1/uvr; no se crea ninguna.
--
-- PRIVILEGIOS: se revoca PUBLIC/origen_admin sobre las cinco tablas nuevas por
-- el DEFAULT ACL de public, en la misma transacción.
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
    IF to_regclass('public.os_review_state') IS NULL
       OR to_regclass('public.os_catalog') IS NULL
       OR to_regclass('public.os_catalog_item') IS NULL
       OR to_regclass('public.os_catalog_release') IS NULL THEN
        RAISE EXCEPTION 'Fase 7 requiere la Fase 1 y el motor de catálogos';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM os_catalog WHERE code = 'dentar-pr' AND is_active) THEN
        RAISE EXCEPTION 'Fase 7 requiere el catálogo real dentar-pr activo';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Elegibilidad: solo prestaciones, nunca diagnósticos ni productos
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_uvr_eligible_catalog (
    catalog_code VARCHAR(60) PRIMARY KEY,
    source_reference TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO os_uvr_eligible_catalog (catalog_code, source_reference)
SELECT c.code, 'os_catalog(code=''' || c.code || ''')'
  FROM os_catalog c
 WHERE c.code = 'dentar-pr'
ON CONFLICT (catalog_code) DO NOTHING;

COMMENT ON TABLE os_uvr_eligible_catalog IS
    'Catálogos elegibles para UVR. Solo prestaciones; DENTAR-DX queda excluido (§10.3 regla 1).';

-- ---------------------------------------------------------------------------
-- 2. Valoración relativa y componentes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_uvr_valuation (
    id BIGSERIAL PRIMARY KEY,
    service_item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE RESTRICT,
    release_id INT REFERENCES os_catalog_release(id) ON DELETE SET NULL,
    version_tag VARCHAR(50) NOT NULL,
    methodology VARCHAR(120) NOT NULL,
    source_reference TEXT NOT NULL,
    evaluated_at DATE NOT NULL,
    calculated_by TEXT,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unknown'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    valid_from DATE,
    valid_to DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_os_uvr_valuation UNIQUE (service_item_id, release_id, version_tag, methodology),
    CONSTRAINT ck_os_uvr_valuation_validity
        CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to > valid_from)
);

CREATE TABLE IF NOT EXISTS os_uvr_component (
    id BIGSERIAL PRIMARY KEY,
    valuation_id BIGINT NOT NULL REFERENCES os_uvr_valuation(id) ON DELETE CASCADE,
    component_type VARCHAR(40) NOT NULL CHECK (component_type IN (
        'work', 'practice_expense', 'professional_liability'
    )),
    value NUMERIC(12, 4) NOT NULL CHECK (value >= 0),
    calculation_note TEXT,
    UNIQUE (valuation_id, component_type)
);

COMMENT ON TABLE os_uvr_valuation IS
    'Valoración relativa por release/metodología. total_uvr NO se almacena: se deriva en v_os_uvr_valuation_total (§10.3 regla 5).';

-- ---------------------------------------------------------------------------
-- 3. Conversión monetaria: aislada de la valoración relativa
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_uvr_conversion (
    id BIGSERIAL PRIMARY KEY,
    uvr_value NUMERIC(14, 6) NOT NULL CHECK (uvr_value > 0),
    currency VARCHAR(5) NOT NULL DEFAULT 'ARS',
    country_code VARCHAR(2),
    jurisdiction VARCHAR(120),
    payer VARCHAR(150),
    contract VARCHAR(150),
    period_start DATE,
    period_end DATE,
    index_reference TEXT,
    source_reference TEXT NOT NULL,
    license_reference TEXT,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unknown'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_os_uvr_conversion UNIQUE
        (uvr_value, currency, country_code, jurisdiction, payer, contract, period_start),
    CONSTRAINT ck_os_uvr_conversion_validity
        CHECK (period_end IS NULL OR period_start IS NULL OR period_end > period_start)
);

COMMENT ON TABLE os_uvr_conversion IS
    'Conversión a money. Cambiar uvr_value por inflación no modifica los *_uvr; revisar una prestación no modifica uvr_value (§10.3 regla 2).';

-- ---------------------------------------------------------------------------
-- 4. Índices geográficos por componente y jurisdicción
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_uvr_geo_index (
    id BIGSERIAL PRIMARY KEY,
    component_type VARCHAR(40) NOT NULL CHECK (component_type IN (
        'work', 'practice_expense', 'professional_liability'
    )),
    jurisdiction VARCHAR(120) NOT NULL,
    index_value NUMERIC(12, 6) NOT NULL DEFAULT 1.000000 CHECK (index_value > 0),
    methodology VARCHAR(120),
    source_reference TEXT NOT NULL,
    period_start DATE,
    period_end DATE,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unknown'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_os_uvr_geo_index UNIQUE
        (component_type, jurisdiction, period_start, source_reference),
    CONSTRAINT ck_os_uvr_geo_index_validity
        CHECK (period_end IS NULL OR period_start IS NULL OR period_end > period_start)
);

COMMENT ON TABLE os_uvr_geo_index IS
    'Índices por componente y jurisdicción. Sin evidencia no se cargan filas: el valor nacional uniforme es el default implícito (§10.3 regla 4).';

-- ---------------------------------------------------------------------------
-- 5. Trigger de elegibilidad (§10.3 regla 1)
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER: origen_admin no tiene privilegios sobre os_catalog_* y esta
-- función debe poder leer los catálogos al validar la elegibilidad del ítem.
CREATE OR REPLACE FUNCTION os_uvr_assert_eligible_service()
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

DROP TRIGGER IF EXISTS trg_os_uvr_valuation_eligible ON os_uvr_valuation;
CREATE TRIGGER trg_os_uvr_valuation_eligible
    BEFORE INSERT OR UPDATE OF service_item_id ON os_uvr_valuation
    FOR EACH ROW EXECUTE FUNCTION os_uvr_assert_eligible_service();

-- ---------------------------------------------------------------------------
-- 6. Vista derivada: total_uvr nunca se almacena (§10.3 regla 5)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_os_uvr_valuation_total AS
SELECT v.id AS valuation_id,
       v.service_item_id,
       v.release_id,
       v.version_tag,
       v.methodology,
       v.review_status,
       COALESCE(c_work.value, 0) AS work_uvr,
       COALESCE(c_practice.value, 0) AS practice_expense_uvr,
       COALESCE(c_liability.value, 0) AS professional_liability_uvr,
       COALESCE(c_work.value, 0)
         + COALESCE(c_practice.value, 0)
         + COALESCE(c_liability.value, 0) AS total_uvr
  FROM os_uvr_valuation v
  LEFT JOIN os_uvr_component c_work
    ON c_work.valuation_id = v.id AND c_work.component_type = 'work'
  LEFT JOIN os_uvr_component c_practice
    ON c_practice.valuation_id = v.id AND c_practice.component_type = 'practice_expense'
  LEFT JOIN os_uvr_component c_liability
    ON c_liability.valuation_id = v.id AND c_liability.component_type = 'professional_liability';

COMMENT ON VIEW v_os_uvr_valuation_total IS
    'total_uvr es derivado de los tres componentes. No constituye arancel ni pago oficial. estimated_payment se calcula en la capa de presentación con uvr_value.';

-- ---------------------------------------------------------------------------
-- 7. DEFAULT ACL: retirar privilegios automáticos sobre las tablas nuevas
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON TABLE
    public.os_uvr_eligible_catalog,
    public.os_uvr_valuation,
    public.os_uvr_component,
    public.os_uvr_conversion,
    public.os_uvr_geo_index
FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE
            public.os_uvr_eligible_catalog,
            public.os_uvr_valuation,
            public.os_uvr_component,
            public.os_uvr_conversion,
            public.os_uvr_geo_index
            FROM origen_admin';
    END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- Comprobaciones posteriores (solo lectura)
-- ---------------------------------------------------------------------------
SELECT '=== Fase 7 · elegibilidad ===' AS seccion;
SELECT * FROM os_uvr_eligible_catalog;

SELECT '=== Fase 7 · tablas VACÍAS ===' AS seccion;
SELECT 'os_uvr_valuation' AS tabla, count(*) AS filas FROM os_uvr_valuation
UNION ALL SELECT 'os_uvr_component', count(*) FROM os_uvr_component
UNION ALL SELECT 'os_uvr_conversion', count(*) FROM os_uvr_conversion
UNION ALL SELECT 'os_uvr_geo_index', count(*) FROM os_uvr_geo_index;

-- Fin de Fase 7 (§16) · módulo UVR sin valores inventados.
