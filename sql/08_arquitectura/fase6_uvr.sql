-- FASE 6 — Módulo UVR (propuesta, NO EJECUTAR sin aprobación)
-- Requiere fase1 y fase4. ESTRUCTURA VACÍA: no carga valores UVR, conversiones
-- monetarias, índices geográficos ni pagos estimados.
-- Regla canónica: total_uvr = work_uvr + practice_expense_uvr + professional_liability_uvr

BEGIN;

-- Elegibilidad: solo prestaciones. Se siembra desde un catálogo REAL ya
-- existente; no se inventan dominios ni se habilita DENTAR-DX.
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

-- Conversión monetaria: aislada de la valoración relativa. Cambiar uvr_value
-- no modifica componentes y revisar un componente no modifica uvr_value.
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
    'Índices por componente y jurisdicción. Sin evidencia no se cargan filas: el valor nacional uniforme es el default implícito.';

-- Solo prestaciones elegibles pueden tener valoración UVR.
CREATE OR REPLACE FUNCTION os_uvr_assert_eligible_service()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_allowed BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
          FROM os_catalog_item i
          JOIN os_catalog c ON c.id = i.catalog_id
          JOIN os_uvr_eligible_catalog e ON e.catalog_code = c.code AND e.is_active
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

-- Total derivado: nunca se almacena como columna editable.
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
    'total_uvr es derivado de los tres componentes. No constituye arancel ni pago oficial.';

COMMIT;

-- Verificación sugerida (no ejecutar automáticamente):
-- SELECT * FROM os_uvr_eligible_catalog;
-- SELECT 'os_uvr_valuation' AS tabla, count(*) FROM os_uvr_valuation
-- UNION ALL SELECT 'os_uvr_component', count(*) FROM os_uvr_component
-- UNION ALL SELECT 'os_uvr_conversion', count(*) FROM os_uvr_conversion
-- UNION ALL SELECT 'os_uvr_geo_index', count(*) FROM os_uvr_geo_index;
