-- =============================================================================
-- FASE 10 (§16) · Catálogos generales OS-*: familia OS-PRODUCTS
-- =============================================================================
-- PROPUESTA PREPARADA EL 2026-11-20. NO EJECUTAR SIN APROBACIÓN Y BACKUP.
-- Autorización registrada: "Preparar con OS-PRODUCTS". Requiere la Fase 1 y la
-- Fase 8 ejecutadas y backup verificado.
--
-- NOTA DE NUMERACIÓN: a partir de aquí el número del archivo coincide con §16.
-- La Fase 9 se ejecutó desde sql/03_dentar/nomenclador_odontologico_nacional.sql,
-- por lo que no hay `fase9_*` en esta carpeta. Ver README.md.
--
-- ALCANCE (§5.3): no adoptar los seis códigos OS-* como catálogos
-- independientes. Se registra la familia `OS-PRODUCTS` (rol `family`) con cinco
-- clases documentadas (`consumable`, `medicine`, `device`, `equipment`,
-- `implant`) y los códigos `OS-INS`, `OS-PROD`, `OS-MED`, `OS-DIS`, `OS-EQP` y
-- `OS-IMPL` como ETIQUETAS RESERVADAS. `OS-PROD` queda sin clase porque el
-- documento lo describe como etiqueta paraguas que solapa con `OS-MED`/`OS-DIS`.
-- No se crean filas en `os_catalog`, ni releases, categorías, ítems, términos,
-- identificadores ni relaciones. No se duplica ningún producto de
-- `DENTAR-IN`/`DENTAR-EQ` (Fase 8). No se tocan API, Browse Codes, Docs ni UVR.
--
-- GOBERNANZA PROPIA: `review_status` referenciado a `os_review_state`,
-- `source_reference` obligatorio y `catalog_id` nulo. El trigger
-- `trg_os_product_family_reservation_publication` impide vincular catálogos
-- reales sin aprobación editorial.
--
-- ADITIVO Y TRANSACCIONAL: CREATE TABLE IF NOT EXISTS, CREATE OR REPLACE
-- FUNCTION, CREATE TRIGGER IF NOT EXISTS, INSERT ... ON CONFLICT DO NOTHING y
-- REVOKE. No hay sentencias destructivas de datos.
--
-- PRIVILEGIOS: se revoca PUBLIC/origen_admin sobre las dos tablas nuevas por el
-- DEFAULT ACL de public, en la misma transacción.
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
       OR to_regclass('public.os_catalog_reservation') IS NULL THEN
        RAISE EXCEPTION 'Fase 10 requiere la Fase 1 y la Fase 8';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM os_review_state WHERE code = 'unreviewed') THEN
        RAISE EXCEPTION 'Fase 10 requiere el estado unreviewed de la Fase 1';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Clases de la familia (§5.3 / §6): una dimensión, no una tabla por dominio
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_product_class (
    code VARCHAR(30) PRIMARY KEY,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO os_product_class (code) VALUES
    ('consumable'),
    ('medicine'),
    ('device'),
    ('equipment'),
    ('implant')
ON CONFLICT (code) DO NOTHING;

COMMENT ON TABLE os_product_class IS
    'Clasificación de la familia OS-PRODUCTS (§5.3). Evita duplicar un mismo artículo en OS-INS, OS-DIS y DENTAR-IN.';

-- ---------------------------------------------------------------------------
-- 2. Familia y etiquetas reservadas: metadatos de gobernanza, sin contenido
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_product_family_reservation (
    code VARCHAR(60) PRIMARY KEY,
    kind VARCHAR(20) NOT NULL CHECK (kind IN ('family', 'label')),
    family_code VARCHAR(60) NOT NULL DEFAULT 'OS-PRODUCTS'
        CHECK (family_code = 'OS-PRODUCTS'),
    label_es VARCHAR(150),
    class_code VARCHAR(30) REFERENCES os_product_class(code) ON UPDATE CASCADE,
    catalog_id INT REFERENCES os_catalog(id) ON DELETE SET NULL,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unreviewed'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    source_reference TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_os_product_family_reservation_scope
        CHECK (code IN (
            'OS-PRODUCTS', 'OS-INS', 'OS-PROD', 'OS-MED',
            'OS-DIS', 'OS-EQP', 'OS-IMPL'
        ))
);

COMMENT ON TABLE os_product_family_reservation IS
    'Reserva de la familia OS-PRODUCTS y sus etiquetas OS-* (§5.3). catalog_id permanece nulo hasta aprobación editorial; ninguna etiqueta es un catálogo consultable.';

INSERT INTO os_product_family_reservation
    (code, kind, label_es, class_code, source_reference)
VALUES
    ('OS-PRODUCTS', 'family', NULL, NULL,
     'docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md#5.3'),
    ('OS-INS', 'label', 'Insumos sanitarios', 'consumable',
     'docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md#5.3'),
    ('OS-PROD', 'label', 'Productos sanitarios', NULL,
     'docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md#5.3'),
    ('OS-MED', 'label', 'Medicamentos', 'medicine',
     'docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md#5.3'),
    ('OS-DIS', 'label', 'Dispositivos médicos', 'device',
     'docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md#5.3'),
    ('OS-EQP', 'label', 'Equipamiento', 'equipment',
     'docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md#5.3'),
    ('OS-IMPL', 'label', 'Implantes y prótesis', 'implant',
     'docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md#5.3')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Guardián de publicación (gobernanza propia)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION os_product_family_reservation_assert_unpublished()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_allowed BOOLEAN;
BEGIN
    IF NEW.catalog_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT is_publication_allowed
      INTO v_allowed
      FROM os_review_state
     WHERE code = NEW.review_status;

    IF v_allowed IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION
            'La reserva % no puede vincularse a un catálogo sin aprobación editorial (§16 Fase 10).',
            NEW.code;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_os_product_family_reservation_publication
    ON os_product_family_reservation;
CREATE TRIGGER trg_os_product_family_reservation_publication
    BEFORE INSERT OR UPDATE OF catalog_id, review_status ON os_product_family_reservation
    FOR EACH ROW EXECUTE FUNCTION os_product_family_reservation_assert_unpublished();

-- ---------------------------------------------------------------------------
-- 4. DEFAULT ACL: retirar privilegios automáticos sobre las tablas nuevas
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON TABLE
    public.os_product_class,
    public.os_product_family_reservation
FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE
            public.os_product_class,
            public.os_product_family_reservation
            FROM origen_admin';
    END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- Comprobaciones posteriores (solo lectura)
-- ---------------------------------------------------------------------------
SELECT '=== Fase 10 · clases (5) ===' AS seccion;
SELECT code FROM os_product_class ORDER BY code;

SELECT '=== Fase 10 · familia y etiquetas reservadas (7) ===' AS seccion;
SELECT code, kind, class_code, review_status, catalog_id
  FROM os_product_family_reservation
 ORDER BY code;

-- Fin de Fase 10 (§16) · catálogos generales OS-* con familia OS-PRODUCTS.
