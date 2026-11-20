-- =============================================================================
-- FASE 8 (§16) · Catálogos DENTAR reservados IN / PD / EQ
-- =============================================================================
-- NOTA DE NUMERACIÓN: el nombre del archivo conserva la numeración histórica
-- de la carpeta. Según §16 del documento de arquitectura esto es la FASE 8.
-- Ver la tabla de alineación en sql/08_arquitectura/README.md.
--
-- PROPUESTA PREPARADA EL 2026-11-20. NO EJECUTAR SIN APROBACIÓN Y BACKUP.
-- Autorización registrada: "Preparar Fase 8". Requiere la Fase 1 ejecutada
-- (os_domain_registry, os_review_state) y backup verificado.
--
-- ALCANCE: formalizar en base la RESERVA de los tres códigos documentados en
-- §5.1 (`dentar-in`, `dentar-pd`, `dentar-eq`). No se crean filas en
-- `os_catalog`, ni releases, categorías, ítems, términos, identificadores ni
-- relaciones. No se inventan prefijos de códigos permanentes para estos
-- catálogos; sus únicos códigos son los de la reserva ya documentada.
-- No se modifica la API pública, Browse Codes, Docs ni UVR.
--
-- GOBERNANZA PROPIA: cada reserva tiene `review_status` referenciado a
-- `os_review_state`, `source_reference` obligatorio y `catalog_id` nulo hasta
-- que exista aprobación editorial. El trigger
-- `trg_os_catalog_reservation_publication` impide vincular un catálogo real
-- mientras el estado no permita publicación (`is_publication_allowed`).
--
-- ADITIVO Y TRANSACCIONAL:
--   · CREATE TABLE IF NOT EXISTS, CREATE OR REPLACE FUNCTION,
--     CREATE TRIGGER IF NOT EXISTS, INSERT ... ON CONFLICT DO NOTHING, REVOKE.
--   · No elimina tablas, columnas ni datos. No hay sentencias destructivas.
--
-- PRIVILEGIOS: se revoca PUBLIC/origen_admin sobre la tabla nueva por el
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
    IF to_regclass('public.os_domain_registry') IS NULL
       OR to_regclass('public.os_review_state') IS NULL
       OR to_regclass('public.os_catalog') IS NULL THEN
        RAISE EXCEPTION 'Fase 8 requiere la Fase 1 y el motor de catálogos';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM os_domain_registry WHERE code = 'odontologia') THEN
        RAISE EXCEPTION 'Fase 8 requiere el dominio odontologia de la Fase 1';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM os_review_state WHERE code = 'unreviewed') THEN
        RAISE EXCEPTION 'Fase 8 requiere el estado unreviewed de la Fase 1';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Registro de reserva: solo metadatos de gobernanza, sin contenido
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_catalog_reservation (
    code VARCHAR(60) PRIMARY KEY,
    label_es VARCHAR(150) NOT NULL,
    label_en VARCHAR(150),
    family_code VARCHAR(50) NOT NULL,
    domain_code VARCHAR(50) REFERENCES os_domain_registry(code) ON UPDATE CASCADE,
    catalog_id INT REFERENCES os_catalog(id) ON DELETE SET NULL,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unreviewed'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    source_reference TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_os_catalog_reservation_scope
        CHECK (code IN ('dentar-in', 'dentar-pd', 'dentar-eq')),
    CONSTRAINT uq_os_catalog_reservation_catalog UNIQUE (catalog_id)
);

COMMENT ON TABLE os_catalog_reservation IS
    'Reserva formal de DENTAR-IN/PD/EQ (§5.1). No habilita consulta pública: catalog_id permanece nulo hasta aprobación editorial.';

INSERT INTO os_catalog_reservation
    (code, label_es, family_code, domain_code, source_reference, notes)
VALUES
    ('dentar-in', 'Insumos y materiales',   'dentar', 'odontologia',
     'docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md#5.1',
     'Reservado; sin códigos aprobados.'),
    ('dentar-pd', 'Productos odontológicos', 'dentar', 'odontologia',
     'docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md#5.1',
     'Reservado; sin códigos aprobados.'),
    ('dentar-eq', 'Equipamiento',            'dentar', 'odontologia',
     'docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md#5.1',
     'Reservado; sin códigos aprobados.')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Guardián de publicación (gobernanza propia, §16 Fase 8)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION os_catalog_reservation_assert_unpublished()
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
            'La reserva % no puede vincularse a un catálogo sin aprobación editorial (§16 Fase 8).',
            NEW.code;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_os_catalog_reservation_publication ON os_catalog_reservation;
CREATE TRIGGER trg_os_catalog_reservation_publication
    BEFORE INSERT OR UPDATE OF catalog_id, review_status ON os_catalog_reservation
    FOR EACH ROW EXECUTE FUNCTION os_catalog_reservation_assert_unpublished();

-- ---------------------------------------------------------------------------
-- 3. DEFAULT ACL: retirar privilegios automáticos sobre la tabla nueva
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON TABLE public.os_catalog_reservation FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.os_catalog_reservation FROM origen_admin';
    END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- Comprobaciones posteriores (solo lectura)
-- ---------------------------------------------------------------------------
SELECT '=== Fase 8 · reservas (3) ===' AS seccion;
SELECT code, label_es, family_code, review_status, catalog_id, source_reference
  FROM os_catalog_reservation
 ORDER BY code;

SELECT '=== Fase 8 · ningún catálogo creado ni ítem cargado ===' AS seccion;
SELECT count(*) AS catalogos_vinculados
  FROM os_catalog_reservation WHERE catalog_id IS NOT NULL;

SELECT count(*) AS catalogos_reales
  FROM os_catalog WHERE code IN ('dentar-in', 'dentar-pd', 'dentar-eq');

-- Fin de Fase 8 (§16) · catálogos DENTAR reservados IN/PD/EQ.
