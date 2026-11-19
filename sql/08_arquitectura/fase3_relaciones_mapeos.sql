-- =============================================================================
-- FASE 4 (§16) · Relaciones y mapeos generales
-- =============================================================================
-- NOTA DE NUMERACIÓN: el nombre del archivo conserva la numeración histórica
-- de la carpeta. Según §16 del documento de arquitectura esto es la FASE 4.
-- Ver la tabla de alineación en sql/08_arquitectura/README.md.
--
-- PROPUESTA PREPARADA EL 2026-11-19. NO EJECUTAR SIN APROBACIÓN Y BACKUP.
-- Autorización registrada: "Fase 4: relaciones", que aprueba también la
-- decisión 10 del §15.2 (integración de itemRelations() con os_catalog_relation).
--
-- REQUISITOS: Fase 1 ejecutada (os_relation_kind, os_review_state) y backup
-- verificado. No reejecutar los scripts 01..15 de sql/07_multilingue.
--
-- ADITIVO Y TRANSACCIONAL:
--   · Solo agrega columnas y crea tablas si no existen.
--   · Constraints e índices creados solo si no existen.
--   · REVOKE sobre las tablas nuevas por el DEFAULT ACL de public (D-16).
--   · No elimina tablas, columnas ni datos.
--   · NO modifica importadores, API pública, catálogos publicados ni
--     Browse Codes. Las 603 relaciones existentes no se reescriben.
--
-- DECISIÓN 10: no requiere cambio de código. CatalogRepository::itemRelations()
-- ya consulta os_catalog_relation y tests/run.php ya lo exige. Esta fase solo
-- formaliza la aprobación y extiende el modelo de datos.
--
-- CAMBIO DE COMPORTAMIENTO DECLARADO: os_concept_mapping.review_status pasa a
-- tener DEFAULT 'draft' (hallazgo 13 del §1.6). Las filas existentes NO se
-- tocan; solo cambia el valor por omisión de inserciones futuras. Revisar con
-- el responsable de gobernanza antes de ejecutar.
--
-- ROLLBACK: restaurar el dump previo (ver README). No hay DDL destructivo.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Preflight: Fase 1 y tabla base deben existir
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.os_relation_kind') IS NULL
       OR to_regclass('public.os_review_state') IS NULL THEN
        RAISE EXCEPTION 'Fase 4 requiere la Fase 1 (os_relation_kind y os_review_state)';
    END IF;
    IF to_regclass('public.os_catalog_relation') IS NULL THEN
        RAISE EXCEPTION 'Fase 4 requiere os_catalog_relation';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Extensión aditiva de os_catalog_relation
-- ---------------------------------------------------------------------------
-- No se eliminan columnas ni se restringen los tipos existentes: el CHECK
-- actual de relation_type sigue vigente hasta una migración aprobada
-- específicamente. Las filas actuales conservan NULL en las columnas nuevas
-- y 'unclassified' en relation_kind; no se inventa clasificación editorial.
ALTER TABLE os_catalog_relation
    ADD COLUMN IF NOT EXISTS valid_from DATE,
    ADD COLUMN IF NOT EXISTS valid_to DATE,
    ADD COLUMN IF NOT EXISTS source_catalog_id INT,
    ADD COLUMN IF NOT EXISTS source_release_id INT,
    ADD COLUMN IF NOT EXISTS target_catalog_id INT,
    ADD COLUMN IF NOT EXISTS target_release_id INT,
    ADD COLUMN IF NOT EXISTS relation_kind VARCHAR(30) NOT NULL DEFAULT 'unclassified',
    ADD COLUMN IF NOT EXISTS mapping_method VARCHAR(80),
    ADD COLUMN IF NOT EXISTS confidence_level VARCHAR(20),
    ADD COLUMN IF NOT EXISTS reviewed_by TEXT,
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS license_reference TEXT,
    ADD COLUMN IF NOT EXISTS inverse_relation_type VARCHAR(60);

DO $$
DECLARE
    v_constraint TEXT;
BEGIN
    FOREACH v_constraint IN ARRAY ARRAY[
        'fk_ocr_source_catalog', 'fk_ocr_target_catalog',
        'fk_ocr_source_release', 'fk_ocr_target_release',
        'fk_ocr_relation_kind', 'ck_ocr_validity'
    ] LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
             WHERE conrelid = 'os_catalog_relation'::regclass
               AND conname = v_constraint
        ) THEN
            CASE v_constraint
                WHEN 'fk_ocr_source_catalog' THEN
                    EXECUTE 'ALTER TABLE os_catalog_relation ADD CONSTRAINT fk_ocr_source_catalog FOREIGN KEY (source_catalog_id) REFERENCES os_catalog(id) ON DELETE SET NULL';
                WHEN 'fk_ocr_target_catalog' THEN
                    EXECUTE 'ALTER TABLE os_catalog_relation ADD CONSTRAINT fk_ocr_target_catalog FOREIGN KEY (target_catalog_id) REFERENCES os_catalog(id) ON DELETE SET NULL';
                WHEN 'fk_ocr_source_release' THEN
                    EXECUTE 'ALTER TABLE os_catalog_relation ADD CONSTRAINT fk_ocr_source_release FOREIGN KEY (source_release_id) REFERENCES os_catalog_release(id) ON DELETE SET NULL';
                WHEN 'fk_ocr_target_release' THEN
                    EXECUTE 'ALTER TABLE os_catalog_relation ADD CONSTRAINT fk_ocr_target_release FOREIGN KEY (target_release_id) REFERENCES os_catalog_release(id) ON DELETE SET NULL';
                WHEN 'fk_ocr_relation_kind' THEN
                    EXECUTE 'ALTER TABLE os_catalog_relation ADD CONSTRAINT fk_ocr_relation_kind FOREIGN KEY (relation_kind) REFERENCES os_relation_kind(code) ON UPDATE CASCADE';
                WHEN 'ck_ocr_validity' THEN
                    EXECUTE 'ALTER TABLE os_catalog_relation ADD CONSTRAINT ck_ocr_validity CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to > valid_from)';
            END CASE;
        END IF;
    END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_ocr_validity ON os_catalog_relation (valid_from, valid_to);
CREATE INDEX IF NOT EXISTS idx_ocr_kind ON os_catalog_relation (relation_kind);

COMMENT ON COLUMN os_catalog_relation.context_text IS
    'Contexto literal de la fuente; integra la clave única y no debe descartarse al exportar.';
COMMENT ON COLUMN os_catalog_relation.relation_kind IS
    'Clasificación gruesa (§7.2). Las 603 filas previas quedan unclassified hasta revisión editorial.';

-- ---------------------------------------------------------------------------
-- 2. Metadatos de gobernanza de mapeos (sin tocar filas existentes)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_mapping_metadata (
    mapping_id INT PRIMARY KEY REFERENCES os_concept_mapping(id) ON DELETE CASCADE,
    source_system_id INT REFERENCES os_terminology_system(id) ON DELETE SET NULL,
    target_system_id INT REFERENCES os_terminology_system(id) ON DELETE SET NULL,
    source_version VARCHAR(50),
    target_version VARCHAR(50),
    mapping_type_ext VARCHAR(40),
    mapping_nature VARCHAR(30) CHECK (mapping_nature IN (
        'univocal', 'multiple', 'partial', 'approximate', 'not_mappable'
    )),
    method VARCHAR(80),
    confidence_level VARCHAR(20),
    source_reference TEXT,
    license_reference TEXT,
    review_status VARCHAR(30) NOT NULL DEFAULT 'unknown'
        REFERENCES os_review_state(code) ON UPDATE CASCADE,
    reviewed_by TEXT,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    valid_from DATE,
    valid_to DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_os_mapping_metadata_validity
        CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to > valid_from)
);

CREATE INDEX IF NOT EXISTS idx_os_mapping_metadata_status
    ON os_mapping_metadata (review_status);

COMMENT ON TABLE os_mapping_metadata IS
    'Metadatos de vigencia, método y gobernanza de os_concept_mapping. La visibilidad depende de review_status, no de provenance.';

-- ---------------------------------------------------------------------------
-- 3. Unificación de sistemas terminológicos (alias por código exacto)
-- ---------------------------------------------------------------------------
-- No mueve filas: solo declara la equivalencia donde el código ya coincide.
CREATE TABLE IF NOT EXISTS os_terminology_system_alias (
    canonical_system_id INT NOT NULL REFERENCES os_terminology_system(id) ON DELETE CASCADE,
    alias_system_code VARCHAR(30) NOT NULL,
    alias_table VARCHAR(80) NOT NULL,
    alias_system_id INT,
    note TEXT,
    PRIMARY KEY (alias_table, alias_system_code)
);

DO $$
BEGIN
    IF to_regclass('public.dentar_terminology_system') IS NOT NULL THEN
        EXECUTE '
            INSERT INTO os_terminology_system_alias
                (canonical_system_id, alias_system_code, alias_table, alias_system_id, note)
            SELECT c.id, d.code, ''dentar_terminology_system'', d.id,
                   ''Alias declarado por coincidencia exacta de código.''
              FROM dentar_terminology_system d
              JOIN os_terminology_system c ON c.code = d.code
            ON CONFLICT (alias_table, alias_system_code) DO NOTHING
        ';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 4. Gobernanza de mapeos: DEFAULT 'draft' (hallazgo 13)
-- ---------------------------------------------------------------------------
-- Solo cambia el valor por omisión de inserciones futuras. Las filas ya
-- existentes con 'approved' NO se modifican. Revisar antes de ejecutar:
-- los mapeos creados por el sync necesitarán aprobación D-19 para publicarse.
ALTER TABLE os_concept_mapping
    ALTER COLUMN review_status SET DEFAULT 'draft';

-- ---------------------------------------------------------------------------
-- 5. DEFAULT ACL: retirar privilegios automáticos sobre las tablas nuevas
-- ---------------------------------------------------------------------------
-- El DEFAULT PRIVILEGES FOR TABLES postgres de public concede privilegios a
-- origen_admin sobre toda tabla nueva. Se revoca aquí, en la misma
-- transacción, sin modificar el DEFAULT ACL global (afectaría a otras fases).
REVOKE ALL PRIVILEGES ON TABLE
    public.os_mapping_metadata,
    public.os_terminology_system_alias
FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE
            public.os_mapping_metadata,
            public.os_terminology_system_alias
            FROM origen_admin';
    END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- Comprobaciones posteriores (solo lectura)
-- ---------------------------------------------------------------------------
SELECT '=== Fase 4 · os_catalog_relation intacta ===' AS seccion;
SELECT count(*) AS relaciones, count(DISTINCT relation_type) AS tipos
  FROM os_catalog_relation;

SELECT '=== Fase 4 · columnas y tablas nuevas ===' AS seccion;
SELECT table_name, count(*) AS columnas_nuevas
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'os_catalog_relation'
   AND column_name IN (
       'valid_from', 'valid_to', 'source_catalog_id', 'source_release_id',
       'target_catalog_id', 'target_release_id', 'relation_kind',
       'mapping_method', 'confidence_level', 'reviewed_by', 'reviewed_at',
       'license_reference', 'inverse_relation_type'
   )
 GROUP BY table_name;

SELECT '=== Fase 4 · DEFAULT de review_status ===' AS seccion;
SELECT column_default
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'os_concept_mapping'
   AND column_name = 'review_status';

-- Fin de Fase 4 (§16) · relaciones y mapeos generales.
