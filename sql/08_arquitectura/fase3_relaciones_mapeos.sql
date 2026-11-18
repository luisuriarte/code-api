-- FASE 3 — Relaciones y mapeos generales (propuesta, NO EJECUTAR sin aprobación)
-- Requiere fase1_infraestructura.sql y backup verificado.
-- Conserva los 15 tipos reales de CDT y el contexto de las 333 filas.

BEGIN;

-- Extensión aditiva de os_catalog_relation. No se eliminan columnas ni se
-- restringen los tipos existentes: el CHECK actual sigue vigente hasta una
-- migración aprobada específicamente.
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

-- Mapeos: metadatos de gobernanza sin alterar las filas existentes.
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

-- Unificación de sistemas terminológicos sin mover filas: alias declarados
-- entre os_terminology_system y dentar_terminology_system por código exacto.
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

-- Corrección del DEFAULT que nacía aprobado. No modifica filas existentes.
ALTER TABLE os_concept_mapping
    ALTER COLUMN review_status SET DEFAULT 'draft';

COMMIT;

-- Verificación sugerida (no ejecutar automáticamente):
-- SELECT count(*) FROM os_catalog_relation;
-- SELECT relation_type, count(*) FROM os_catalog_relation GROUP BY 1 ORDER BY 1;
-- SELECT review_status, count(*) FROM os_concept_mapping GROUP BY 1 ORDER BY 1;
-- SELECT * FROM os_terminology_system_alias ORDER BY alias_system_code;
