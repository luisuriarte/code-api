-- =============================================================================
-- Origen Salud · SNOMED CT Edición Argentina · PostgreSQL 18
-- 05_map_excel.sql :: carga de los mapeos NBU y GTIN
-- =============================================================================
--
-- CUÁNDO SE EJECUTA
--   Después de 03_postcarga.sql. Es opcional: sólo hace falta si se quieren
--   usar los mapeos NBU (Nomenclador Bioquímico Único) y GTIN (código de
--   barras) que vienen en la carpeta Resources/ del paquete argentino.
--
-- FUENTES
--   NBU  → Mapeo_NBU_SCT_Agosto26.xlsx                     (~425 filas)
--   GTIN → MAP_GTIN_a_RPCD_comercializadas_20260820.xlsx  (~15.500 filas)
--
-- PASOS PREVIOS
--   1. Convertir los XLSX a TSV con:
--        php tools/php/convertir_excel_maps.php <carpeta Resources>
--      El conversor escribe los .tsv junto a los .xlsx (o en --salida=DIR).
--   2. Ejecutar este script con psql, indicando las rutas de los TSV:
--        psql -d origen_salud -v ON_ERROR_STOP=1 \
--             -v ruta_nbu="D:/sct/Resources/Mapeo_NBU_SCT_Agosto26.tsv" \
--             -v ruta_gtin="D:/sct/Resources/MAP_GTIN_a_RPCD_comercializadas_20260820.tsv" \
--             -f tools/sql/snomed/05_map_excel.sql
--
--   Si no se pasan las variables, se usan los nombres por defecto en el
--   directorio desde donde corre psql.
--
-- POR QUÉ \copy
--   `\copy` es el equivalente directo de `LOAD DATA LOCAL INFILE` de MariaDB:
--   psql lee los archivos en la máquina cliente y los envía por la conexión.
--   No requiere permiso de superusuario ni que los archivos estén en el
--   servidor. Como todo comando meta, sólo funciona con `psql -f`; DBeaver no
--   lo interpreta. Al final del archivo hay una variante con `COPY` para
--   cargar desde el disco del servidor.
--
-- IDEMPOTENCIA
--   Hace TRUNCATE + carga en cada ejecución. No duplica filas.
--
-- NOTA SOBRE GTIN
--   El GTIN se guarda tal como viene en el Excel (13 o 14 dígitos). Para
--   comparar con el EAN-13 de un lector lineal:
--     WHERE gtin = lpad(:ean13, 14, '0')
-- =============================================================================

SET client_encoding = 'UTF8';
SET statement_timeout = 0;
SET lock_timeout = 0;

-- =============================================================================
-- 0. Comprobaciones previas
-- =============================================================================

DO $$
BEGIN
    IF to_regclass('sct2.concept') IS NULL
       OR to_regclass('sct2.preferred_term') IS NULL THEN
        RAISE EXCEPTION 'Falta la postcarga. Ejecutá 01, 02 y 03 antes de 05_map_excel.sql.';
    END IF;
END $$;

-- =============================================================================
-- 1. Tablas de mapeo
-- =============================================================================

CREATE TABLE IF NOT EXISTS sct2.map_nbu (
    sctid        BIGINT       NOT NULL,
    codigo_nbu   INTEGER      NOT NULL,
    determinacion VARCHAR(512) NOT NULL,
    PRIMARY KEY (sctid, codigo_nbu)
);

COMMENT ON TABLE sct2.map_nbu IS
    'Mapeo SNOMED CT -> Nomenclador Bioquímico Único (NBU). Fuente: Resources/Mapeo_NBU_SCT*.xlsx.';
COMMENT ON COLUMN sct2.map_nbu.sctid IS
    'Concepto SNOMED CT de la práctica de laboratorio.';
COMMENT ON COLUMN sct2.map_nbu.codigo_nbu IS
    'Código numérico del NBU.';
COMMENT ON COLUMN sct2.map_nbu.determinacion IS
    'Nombre de la determinación según el NBU.';

CREATE TABLE IF NOT EXISTS sct2.map_gtin (
    gtin      VARCHAR(20)   NOT NULL,
    condicion VARCHAR(30)   NOT NULL,
    rpcd_id   BIGINT        NOT NULL,
    rpcd_fsn  VARCHAR(1024) NOT NULL,
    PRIMARY KEY (gtin)
);

COMMENT ON TABLE sct2.map_gtin IS
    'Mapeo GTIN -> presentación farmacéutica comercial SNOMED CT (RPCD). Fuente: Resources/MAP_GTIN*.xlsx.';
COMMENT ON COLUMN sct2.map_gtin.gtin IS
    'Global Trade Item Number (EAN-13/GTIN-14) del producto comercial.';
COMMENT ON COLUMN sct2.map_gtin.condicion IS
    'Estado de comercialización: COMERCIALIZADO u otro.';
COMMENT ON COLUMN sct2.map_gtin.rpcd_id IS
    'Concepto SNOMED CT de la presentación farmacéutica comercial.';
COMMENT ON COLUMN sct2.map_gtin.rpcd_fsn IS
    'Fully Specified Name de la presentación comercial en SNOMED CT.';

-- =============================================================================
-- 2. Carga de los TSV generados por tools/php/convertir_excel_maps.php
-- =============================================================================

\if :{?ruta_nbu}
\else
  \set ruta_nbu 'Mapeo_NBU_SCT_Agosto26.tsv'
\endif

\if :{?ruta_gtin}
\else
  \set ruta_gtin 'MAP_GTIN_a_RPCD_comercializadas_20260820.tsv'
\endif

TRUNCATE TABLE sct2.map_nbu;

\copy sct2.map_nbu (sctid, codigo_nbu, determinacion) FROM :'ruta_nbu' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, ENCODING 'UTF8', FORCE_NOT_NULL (determinacion))

TRUNCATE TABLE sct2.map_gtin;

\copy sct2.map_gtin (gtin, condicion, rpcd_id, rpcd_fsn) FROM :'ruta_gtin' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, ENCODING 'UTF8', FORCE_NOT_NULL (condicion, rpcd_fsn))

-- =============================================================================
-- 3. Índices
-- =============================================================================

-- La PK de map_nbu ya cubre (sctid, codigo_nbu). Falta buscar por código NBU.
CREATE INDEX IF NOT EXISTS sct2_map_nbu_codigo_idx
    ON sct2.map_nbu (codigo_nbu);

-- La PK de map_gtin es el GTIN. Falta buscar por presentación SNOMED.
CREATE INDEX IF NOT EXISTS sct2_map_gtin_rpcd_idx
    ON sct2.map_gtin (rpcd_id);

-- =============================================================================
-- 4. Vistas
-- =============================================================================

CREATE OR REPLACE VIEW sct2.v_map_nbu AS
SELECT n.sctid,
       tp.term         AS sct_term,
       n.codigo_nbu,
       n.determinacion
  FROM sct2.map_nbu n
  LEFT JOIN sct2.preferred_term tp ON tp.concept_id = n.sctid;

COMMENT ON VIEW sct2.v_map_nbu IS
    'Mapeo NBU con el término preferido del concepto SNOMED CT.';

CREATE OR REPLACE VIEW sct2.v_map_gtin AS
SELECT g.gtin,
       g.condicion,
       g.rpcd_id       AS sctid,
       tp.term         AS sct_term,
       g.rpcd_fsn
  FROM sct2.map_gtin g
  LEFT JOIN sct2.preferred_term tp ON tp.concept_id = g.rpcd_id;

COMMENT ON VIEW sct2.v_map_gtin IS
    'Mapeo GTIN con el término preferido de la presentación SNOMED CT.';

-- =============================================================================
-- 5. Integridad, estadísticas y resumen
-- =============================================================================

SELECT 'NBU sin concepto SNOMED' AS control, count(*) AS fallas
  FROM sct2.map_nbu n
 WHERE NOT EXISTS (SELECT 1 FROM sct2.concept c WHERE c.id = n.sctid)
UNION ALL
SELECT 'GTIN sin presentación SNOMED', count(*)
  FROM sct2.map_gtin g
 WHERE NOT EXISTS (SELECT 1 FROM sct2.concept c WHERE c.id = g.rpcd_id)
UNION ALL
SELECT 'NBU con determinación vacía', count(*)
  FROM sct2.map_nbu
 WHERE btrim(determinacion) = ''
UNION ALL
SELECT 'GTIN con FSN vacío', count(*)
  FROM sct2.map_gtin
 WHERE btrim(rpcd_fsn) = '';

ANALYZE sct2.map_nbu;
ANALYZE sct2.map_gtin;

SELECT 'sct2.map_nbu' AS tabla, count(*) AS filas FROM sct2.map_nbu
UNION ALL
SELECT 'sct2.map_gtin', count(*) FROM sct2.map_gtin;

SELECT 'Mapeos NBU y GTIN cargados. Verificar con 99_verificacion.sql.' AS resultado;

-- =============================================================================
-- APÉNDICE: carga con COPY desde el disco del servidor
-- =============================================================================
--
-- Si los TSV están en el mismo servidor que PostgreSQL y el usuario tiene
-- permiso de lectura (superusuario o pg_read_server_files), reemplazar los
-- \copy de arriba por:
--
--   TRUNCATE TABLE sct2.map_nbu;
--   COPY sct2.map_nbu (sctid, codigo_nbu, determinacion)
--     FROM '/opt/sct/Resources/Mapeo_NBU_SCT_Agosto26.tsv'
--     WITH (FORMAT csv, DELIMITER E'\t', HEADER true, ENCODING 'UTF8',
--           FORCE_NOT_NULL (determinacion));
--
--   TRUNCATE TABLE sct2.map_gtin;
--   COPY sct2.map_gtin (gtin, condicion, rpcd_id, rpcd_fsn)
--     FROM '/opt/sct/Resources/MAP_GTIN_a_RPCD_comercializadas_20260820.tsv'
--     WITH (FORMAT csv, DELIMITER E'\t', HEADER true, ENCODING 'UTF8',
--           FORCE_NOT_NULL (condicion, rpcd_fsn));
--
-- En ese caso el script se puede ejecutar también desde DBeaver.
