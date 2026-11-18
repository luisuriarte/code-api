-- =============================================================================
-- 02_carga.sql  ::  LOAD DATA de CIE-10-ES para OpenEMR
-- =============================================================================
-- GENERADO AUTOMÁTICAMENTE por scripts/generar_carga.php. No editar a mano.
--
-- Edición CIE-10-ES : 2026
-- Generado          : 2026-11-10 22:18:36
-- Carpeta fuente    : d:\docs\luis\Documentos\sitios\openemr\codigos\cie-10
-- Ruta en los LOAD  : d:\docs\luis\Documentos\sitios\openemr\codigos\cie-10
--
-- ANTES DE EJECUTAR
--   1) En el servidor MySQL: SET GLOBAL local_infile = 1;
--   2) En DBeaver: conexión → Propiedades driver → allowLoadLocalInfile = true
--   3) Ejecutar 01_esquema.sql antes de este archivo.
--   4) Las rutas son del equipo desde donde se EJECUTA el SQL.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- [1] icd10_dx_order_code  — Diagnósticos CIE-10-ES 2026
--     Columnas CSV: Código | Descripción | Nodo_Final | ...
--     dx_code = con punto (A00.0); formatted_dx_code = sin punto (A000)
--     valid_for_coding = Nodo_Final (1 = codificable, 0 = categoría padre)
--     short_desc = LEFT(Descripción, 60); long_desc = Descripción completa
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `icd10_dx_order_code`;
LOAD DATA LOCAL INFILE 'd:/docs/luis/Documentos/sitios/openemr/codigos/cie-10/Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv'
  INTO TABLE `icd10_dx_order_code`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (@dx_code, @long_desc, @valid_for_coding,
   @manifestacion, @perinatal, @pediatrico, @obstetrico,
   @adulto, @mujer, @hombre, @poa, @dp, @vcdp)
  SET
    `dx_code`           = @dx_code,
    `formatted_dx_code` = REPLACE(@dx_code, '.', ''),
    `valid_for_coding`  = IF(TRIM(@valid_for_coding) = '1', '1', '0'),
    `long_desc`         = @long_desc,
    `short_desc`        = LEFT(@long_desc, 60),
    `active`            = 1,
    `revision`          = 3
;

-- -----------------------------------------------------------------------------
-- [2] icd10_pcs_order_code  — Procedimientos CIE-10-ES 2026
--     Columnas CSV: Código | Descripción | Hombre | Mujer
--     pcs_code = 7 caracteres alfanuméricos (0016070)
--     Todos los códigos son codificables (valid_for_coding = 1)
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `icd10_pcs_order_code`;
LOAD DATA LOCAL INFILE 'd:/docs/luis/Documentos/sitios/openemr/codigos/cie-10/Procedimientos_Tabla_Referencia_CIE10ES_2026.csv'
  INTO TABLE `icd10_pcs_order_code`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (@pcs_code, @long_desc, @hombre, @mujer)
  SET
    `pcs_code`         = @pcs_code,
    `valid_for_coding` = '1',
    `long_desc`        = @long_desc,
    `short_desc`       = LEFT(@long_desc, 60),
    `active`           = 1,
    `revision`         = 3
;

-- -----------------------------------------------------------------------------
-- Registro de la versión importada
-- (lo lee OpenEMR en Administración → Codificación → Tablas estandarizadas)
-- -----------------------------------------------------------------------------
INSERT INTO `standardized_tables_track`
  (`imported_date`, `name`, `revision_version`, `revision_date`, `file_checksum`)
VALUES (NOW(), 'ICD10', 'CIE-10-ES 2026', '2026-01-01', '');

INSERT INTO `standardized_tables_track`
  (`imported_date`, `name`, `revision_version`, `revision_date`, `file_checksum`)
VALUES (NOW(), 'ICD10PCS', 'CIE-10-ES PCS 2026', '2026-01-01', '');

SELECT 'Carga terminada. Continúe con 03_postcarga.sql.' AS resultado;
