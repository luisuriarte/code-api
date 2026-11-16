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
--   2. Ubicarse en la carpeta donde quedaron los TSV y ejecutar desde ahí:
--        cd /ruta/al/SnomedCT_.../Resources
--        sudo -u postgres psql -d origen_salud -v ON_ERROR_STOP=1 \
--             -f /var/www/html/origen.ar/code-api/tools/sql/snomed/05_map_excel.sql
--
--   IMPORTANTE: `\copy` NO expande variables de psql, así que NO sirve pasar
--   -v ruta_nbu=... / -v ruta_gtin=.... Los nombres de archivo son literales y
--   se resuelven contra el directorio de trabajo de psql (el del shell desde
--   donde se lanza). Si los TSV están en otra carpeta, descomentar la línea
--   `\cd` de la sección 2 y poner ahí la ruta absoluta.
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

-- Cortar en el primer error: si un \copy no encuentra el archivo, no tiene
-- sentido seguir creando índices y vistas sobre tablas vacías.
\set ON_ERROR_STOP on

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
--
-- \copy es un meta-comando de psql: lee los archivos en la máquina cliente y
-- NO expande variables de psql. Si se escribe `FROM :'ruta_nbu'`, psql busca un
-- archivo llamado literalmente ":'ruta_nbu'" y falla con:
--     error: : No such file or directory
-- Por eso los nombres de archivo van literales en este script.
--
-- Los nombres se resuelven contra el directorio de trabajo de psql, es decir
-- el del shell desde donde se lanza (por ejemplo .../Resources). Si los TSV
-- están en otra carpeta, descomentar y ajustar la línea \cd (ruta absoluta,
-- sin comillas y sin ~):
--
-- \cd /root/SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z/Resources

TRUNCATE TABLE sct2.map_nbu;
\copy sct2.map_nbu (sctid, codigo_nbu, determinacion) FROM 'Mapeo_NBU_SCT_Agosto26.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, ENCODING 'UTF8', FORCE_NOT_NULL (determinacion))

TRUNCATE TABLE sct2.map_gtin;
\copy sct2.map_gtin (gtin, condicion, rpcd_id, rpcd_fsn) FROM 'MAP_GTIN_a_RPCD_comercializadas_20260820.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, ENCODING 'UTF8', FORCE_NOT_NULL (condicion, rpcd_fsn))

-- Guarda explícita: si los archivos no se encontraron (o venían sólo con el
-- encabezado) las tablas quedan en 0 filas y hay que cortar acá, en lugar de
-- terminar con el mensaje optimista de "mapeos cargados".
DO $$
DECLARE
    v_nbu  BIGINT;
    v_gtin BIGINT;
BEGIN
    SELECT count(*) INTO v_nbu  FROM sct2.map_nbu;
    SELECT count(*) INTO v_gtin FROM sct2.map_gtin;

    IF v_nbu = 0 OR v_gtin = 0 THEN
        RAISE EXCEPTION
            'Carga vacía: sct2.map_nbu=%, sct2.map_gtin=%. Los TSV no se encontraron: ejecutá psql parado en la carpeta Resources/ o descomentá la línea \cd de la sección 2.',
            v_nbu, v_gtin;
    END IF;
END $$;

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
