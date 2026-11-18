-- =============================================================================
-- CIE-10-ES Edición Española para OpenEMR
-- 99_verificacion.sql  ::  controles de la carga
-- =============================================================================
--
-- Solo SELECT. No modifica nada.
-- Ejecutar después de 03_postcarga.sql.
--
-- Los valores esperados corresponden a la edición CIE-10-ES 2026.
-- Si se cargó otra edición, los conteos variarán levemente.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1) Conteos generales
-- -----------------------------------------------------------------------------
SELECT 'icd10_dx_order_code (total)'      AS `tabla`, 74260  AS `esperado_2026`,
       COUNT(*) AS `obtenido`,
       IF(COUNT(*) BETWEEN 70000 AND 80000, 'OK', 'REVISAR') AS `estado`
  FROM `icd10_dx_order_code`
UNION ALL
SELECT 'icd10_dx_order_code (codificables)', 74258, COUNT(*),
       IF(COUNT(*) BETWEEN 70000 AND 80000, 'OK', 'REVISAR')
  FROM `icd10_dx_order_code` WHERE `valid_for_coding` = '1'
UNION ALL
SELECT 'icd10_pcs_order_code (total)', 78948, COUNT(*),
       IF(COUNT(*) BETWEEN 75000 AND 85000, 'OK', 'REVISAR')
  FROM `icd10_pcs_order_code`
UNION ALL
SELECT 'icd10_pcs_order_code (activos)', 78948, COUNT(*),
       IF(COUNT(*) BETWEEN 75000 AND 85000, 'OK', 'REVISAR')
  FROM `icd10_pcs_order_code` WHERE `active` = 1;

-- -----------------------------------------------------------------------------
-- 2) Integridad de datos
-- -----------------------------------------------------------------------------
SELECT 'dx_code vacío' AS `control`, 0 AS `esperado`,
       COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 0, 'OK', 'REVISAR') AS `estado`
  FROM `icd10_dx_order_code` WHERE TRIM(`dx_code`) = ''
UNION ALL
SELECT 'long_desc vacío en dx', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `icd10_dx_order_code` WHERE TRIM(`long_desc`) = ''
UNION ALL
SELECT 'pcs_code vacío', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `icd10_pcs_order_code` WHERE TRIM(`pcs_code`) = ''
UNION ALL
SELECT 'long_desc vacío en pcs', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `icd10_pcs_order_code` WHERE TRIM(`long_desc`) = ''
UNION ALL
-- Los dx_code deben tener punto decimal (formato A00.0)
SELECT 'dx_code sin punto decimal', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `icd10_dx_order_code` WHERE `dx_code` NOT LIKE '%.%'
UNION ALL
-- formatted_dx_code NO debe tener punto
SELECT 'formatted_dx_code con punto', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `icd10_dx_order_code` WHERE `formatted_dx_code` LIKE '%.%'
UNION ALL
-- pcs_code debe tener exactamente 7 caracteres
SELECT 'pcs_code distinto de 7 chars', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `icd10_pcs_order_code` WHERE CHAR_LENGTH(`pcs_code`) <> 7;

-- -----------------------------------------------------------------------------
-- 3) Descripciones largas (control de truncado)
-- -----------------------------------------------------------------------------
SELECT 'long_desc dx > 300 chars' AS `control`, 0 AS `esperado`,
       COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 0, 'OK', 'REVISAR') AS `estado`
  FROM `icd10_dx_order_code` WHERE CHAR_LENGTH(`long_desc`) > 300
UNION ALL
SELECT 'short_desc dx > 60 chars', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `icd10_dx_order_code` WHERE CHAR_LENGTH(`short_desc`) > 60
UNION ALL
SELECT 'long_desc pcs > 300 chars', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `icd10_pcs_order_code` WHERE CHAR_LENGTH(`long_desc`) > 300;

-- -----------------------------------------------------------------------------
-- 4) Muestra de datos para inspección visual
-- -----------------------------------------------------------------------------
SELECT 'Muestra diagnósticos' AS info;
SELECT `dx_code`, `formatted_dx_code`, `valid_for_coding`,
       LEFT(`long_desc`, 60) AS `desc_60`, `revision`
  FROM `icd10_dx_order_code`
 ORDER BY `dx_id` LIMIT 5;

SELECT 'Muestra procedimientos' AS info;
SELECT `pcs_code`, `valid_for_coding`,
       LEFT(`long_desc`, 60) AS `desc_60`, `revision`
  FROM `icd10_pcs_order_code`
 ORDER BY `pcs_id` LIMIT 5;

-- -----------------------------------------------------------------------------
-- 5) Versión importada
-- -----------------------------------------------------------------------------
SELECT `imported_date`, `name`, `revision_version`, `revision_date`
  FROM `standardized_tables_track`
 WHERE `name` IN ('ICD10', 'ICD10PCS')
 ORDER BY `imported_date` DESC
 LIMIT 10;

SELECT 'Verificación terminada. Revisá que todas las filas digan OK.' AS resultado;

