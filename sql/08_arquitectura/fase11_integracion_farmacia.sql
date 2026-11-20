-- =============================================================================
-- FASE 11 (§16) · Integración ANMAT / UDI / GTIN (estructura, SIN datos)
-- =============================================================================
-- PROPUESTA PREPARADA EL 2026-11-20. NO EJECUTAR SIN APROBACIÓN Y BACKUP.
-- Autorización registrada: "Solo integración, sin cargar datos". Requiere la
-- Fase 1, la Fase 5 (os_admin.app_user), la Fase 6 (modelo de productos) y
-- backup verificado.
--
-- ALCANCE (§8.3): preparar fuentes, trazabilidad y validación para integrar
-- ANMAT/UDI/GTIN con el modelo de la Fase 6. TODAS las tablas nuevas quedan
-- VACÍAS. No se migran las filas farmacéuticas heredadas (9 sustancias,
-- 10 productos, 10 presentaciones y 40 identificadores), no se crean conceptos,
-- productos, presentaciones, identificadores ni registros sanitarios nuevos.
-- No se tocan importadores, API pública, catálogos publicados ni Browse Codes.
--
-- GOBERNANZA: cada fuente, lote y fila de staging tiene `source_reference`
-- obligatorio y `review_status` referenciado a `os_review_state` (default
-- 'unreviewed'). El trigger `trg_os_pharma_import_row_review` impide aprobar
-- una fila de staging sin fuente activa aprobada, lote aprobado y destino
-- resuelto. `estimated`/derivados no se almacenan.
--
-- ADITIVO Y TRANSACCIONAL: CREATE TABLE IF NOT EXISTS, CREATE OR REPLACE
-- FUNCTION/VIEW, CREATE TRIGGER IF NOT EXISTS, REVOKE. No hay sentencias
-- destructivas de datos.
--
-- PRIVILEGIOS: se revoca PUBLIC/origen_admin sobre las tres tablas nuevas por
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
       OR to_regclass('os_admin.app_user') IS NULL
       OR to_regclass('public.os_concept') IS NULL
       OR to_regclass('public.os_product') IS NULL
       OR to_regclass('public.os_product_presentation') IS NULL
       OR to_regclass('public.os_product_identifiers') IS NULL
       OR to_regclass('public.os_regulatory_records') IS NULL
       OR to_regclass('public.os_substance') IS NULL THEN
        RAISE EXCEPTION 'Fase 11 requiere la Fase 1, la Fase 5, la Fase 6 y el legado farmacéutico';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Registro de fuentes verificables (vacío)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_pharma_source (
    code VARCHAR(50) PRIMARY KEY,
    authority_name VARCHAR(200) NOT NULL,
    country_code VARCHAR(2),
    source_reference TEXT NOT NULL,
    license_reference TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unreviewed'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE os_pharma_source IS
    'Fuentes reales pendientes de registro (ANMAT, UDI, GS1/GTIN). Sin filas cargadas: cada fuente debe documentarse antes de usarla.';

-- ---------------------------------------------------------------------------
-- 2. Lotes de integración con actores reales (vacío)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_pharma_import_batch (
    id BIGSERIAL PRIMARY KEY,
    source_code VARCHAR(50) NOT NULL
        REFERENCES os_pharma_source(code) ON UPDATE CASCADE,
    batch_tag VARCHAR(80) NOT NULL,
    methodology VARCHAR(120) NOT NULL,
    source_reference TEXT NOT NULL,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unreviewed'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    imported_by_user_id BIGINT REFERENCES os_admin.app_user(id) ON DELETE SET NULL,
    imported_at DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_os_pharma_import_batch UNIQUE (source_code, batch_tag)
);

-- ---------------------------------------------------------------------------
-- 3. Staging de filas a integrar (vacío)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_pharma_import_row (
    id BIGSERIAL PRIMARY KEY,
    batch_id BIGINT NOT NULL
        REFERENCES os_pharma_import_batch(id) ON DELETE CASCADE,
    external_key VARCHAR(200) NOT NULL,
    target_entity VARCHAR(60) NOT NULL CHECK (target_entity IN (
        'os_concept', 'os_manufacturer', 'os_product',
        'os_product_presentation', 'os_product_identifiers',
        'os_regulatory_records'
    )),
    target_id BIGINT,
    raw_payload JSONB NOT NULL,
    source_reference TEXT NOT NULL,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unreviewed'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_os_pharma_import_row UNIQUE (batch_id, external_key, target_entity)
);

COMMENT ON TABLE os_pharma_import_row IS
    'Staging sin destino resuelto. target_id se completa solo tras validar la fuente; no se copian filas del legado automáticamente.';

-- ---------------------------------------------------------------------------
-- 4. Validación de aprobación de staging
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION os_pharma_import_row_assert_review()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_review_allows BOOLEAN;
    v_source_ok BOOLEAN;
    v_batch_ok  BOOLEAN;
BEGIN
    IF NEW.raw_payload IS NULL OR NEW.raw_payload = '{}'::jsonb THEN
        RAISE EXCEPTION 'La fila de staging % no tiene payload verificable.', NEW.external_key;
    END IF;

    IF NEW.source_reference IS NULL OR NEW.source_reference = '' THEN
        RAISE EXCEPTION 'La fila de staging % no tiene fuente verificable (§8.3).', NEW.external_key;
    END IF;

    SELECT is_publication_allowed
      INTO v_review_allows
      FROM os_review_state
     WHERE code = NEW.review_status;

    IF v_review_allows IS DISTINCT FROM TRUE THEN
        RETURN NEW;
    END IF;

    SELECT COALESCE(bool_and(s.is_active AND rs.is_publication_allowed), FALSE)
      INTO v_source_ok
      FROM os_pharma_import_batch b
      JOIN os_pharma_source s ON s.code = b.source_code
      JOIN os_review_state rs ON rs.code = s.review_status
     WHERE b.id = NEW.batch_id;

    SELECT COALESCE(bool_and(rs.is_publication_allowed), FALSE)
      INTO v_batch_ok
      FROM os_pharma_import_batch b
      JOIN os_review_state rs ON rs.code = b.review_status
     WHERE b.id = NEW.batch_id;

    IF v_source_ok IS NOT TRUE OR v_batch_ok IS NOT TRUE OR NEW.target_id IS NULL THEN
        RAISE EXCEPTION
            'La fila % no puede aprobarse: fuente/lote sin publicación permitida o destino sin resolver.',
            NEW.external_key;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_os_pharma_import_row_review ON os_pharma_import_row;
CREATE TRIGGER trg_os_pharma_import_row_review
    BEFORE INSERT OR UPDATE OF review_status, target_id ON os_pharma_import_row
    FOR EACH ROW EXECUTE FUNCTION os_pharma_import_row_assert_review();

-- ---------------------------------------------------------------------------
-- 5. Conciliación informativa: legado vs modelo nuevo (solo lectura)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_os_pharma_reconciliation AS
SELECT 'os_substance -> os_concept' AS mapping,
       (SELECT count(*) FROM os_substance) AS filas_legado,
       (SELECT count(*) FROM os_concept) AS filas_modelo
UNION ALL
SELECT 'os_medicinal_product -> os_product',
       (SELECT count(*) FROM os_medicinal_product),
       (SELECT count(*) FROM os_product)
UNION ALL
SELECT 'os_product_package -> os_product_presentation',
       (SELECT count(*) FROM os_product_package),
       (SELECT count(*) FROM os_product_presentation)
UNION ALL
SELECT 'os_product_identifier -> os_product_identifiers',
       (SELECT count(*) FROM os_product_identifier),
       (SELECT count(*) FROM os_product_identifiers)
UNION ALL
SELECT 'os_regulatory_records (sin equivalente legado)',
       0,
       (SELECT count(*) FROM os_regulatory_records);

COMMENT ON VIEW v_os_pharma_reconciliation IS
    'Diferencia entre el legado farmacéutico y el modelo de la Fase 6. No transfiere datos: solo expone el estado para gobernanza.';

-- ---------------------------------------------------------------------------
-- 6. DEFAULT ACL: retirar privilegios automáticos sobre las tablas nuevas
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON TABLE
    public.os_pharma_source,
    public.os_pharma_import_batch,
    public.os_pharma_import_row
FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE
            public.os_pharma_source,
            public.os_pharma_import_batch,
            public.os_pharma_import_row
            FROM origen_admin';
    END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- Comprobaciones posteriores (solo lectura)
-- ---------------------------------------------------------------------------
SELECT '=== Fase 11 · staging VACÍO ===' AS seccion;
SELECT 'os_pharma_source' AS tabla, count(*) AS filas FROM os_pharma_source
UNION ALL SELECT 'os_pharma_import_batch', count(*) FROM os_pharma_import_batch
UNION ALL SELECT 'os_pharma_import_row', count(*) FROM os_pharma_import_row;

SELECT '=== Fase 11 · conciliación (legado intacto, modelo vacío) ===' AS seccion;
SELECT * FROM v_os_pharma_reconciliation ORDER BY mapping;

-- Fin de Fase 11 (§16) · integración ANMAT/UDI/GTIN sin cargar datos.
