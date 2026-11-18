-- =============================================================================
-- CIE-10-ES Edición Española para OpenEMR
-- 03_postcarga.sql  ::  índices y verificación post-carga
-- =============================================================================
--
-- Cuándo ejecutar: DESPUÉS de 02_carga.sql.
-- Es idempotente: se puede volver a ejecutar.
--
-- Qué hace:
--   1. Agrega índices secundarios (que en 01 no se crean, para que la carga
--      de millones de filas sea más rápida).
--   2. Muestra un resumen de lo cargado.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 0) Procedimiento auxiliar: agregar índice solo si no existe
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `cie10_agregar_indice`;
DELIMITER $$
CREATE PROCEDURE `cie10_agregar_indice`(
  IN p_tabla   VARCHAR(64),
  IN p_indice  VARCHAR(64),
  IN p_clausula VARCHAR(512)
)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.statistics
     WHERE table_schema = DATABASE()
       AND table_name   = p_tabla
       AND index_name   = p_indice
  ) THEN
    SET @cie10_ddl = CONCAT('ALTER TABLE `', p_tabla, '` ADD ', p_clausula);
    PREPARE cie10_stmt FROM @cie10_ddl;
    EXECUTE cie10_stmt;
    DEALLOCATE PREPARE cie10_stmt;
  END IF;
END$$
DELIMITER ;

-- -----------------------------------------------------------------------------
-- 1) Índices: icd10_dx_order_code
-- -----------------------------------------------------------------------------
CALL cie10_agregar_indice('icd10_dx_order_code', 'dx_id',
  'UNIQUE KEY `dx_id` (`dx_id`)');
CALL cie10_agregar_indice('icd10_dx_order_code', 'formatted_dx_code',
  'KEY `formatted_dx_code` (`formatted_dx_code`)');
CALL cie10_agregar_indice('icd10_dx_order_code', 'active',
  'KEY `active` (`active`)');
CALL cie10_agregar_indice('icd10_dx_order_code', 'valid_for_coding',
  'KEY `valid_for_coding` (`valid_for_coding`(10))');

-- -----------------------------------------------------------------------------
-- 2) Índices: icd10_pcs_order_code
-- -----------------------------------------------------------------------------
CALL cie10_agregar_indice('icd10_pcs_order_code', 'pcs_id',
  'UNIQUE KEY `pcs_id` (`pcs_id`)');
CALL cie10_agregar_indice('icd10_pcs_order_code', 'pcs_code',
  'KEY `pcs_code` (`pcs_code`)');
CALL cie10_agregar_indice('icd10_pcs_order_code', 'active',
  'KEY `active` (`active`)');

-- -----------------------------------------------------------------------------
-- 3) AUTO_INCREMENT (para mantener compatibilidad con el dump nativo)
-- -----------------------------------------------------------------------------
-- (AUTO_INCREMENT ya se define en la tabla; esta sección es informativa)

-- -----------------------------------------------------------------------------
-- 4) ANALYZE TABLE
-- -----------------------------------------------------------------------------
ANALYZE TABLE `icd10_dx_order_code`, `icd10_pcs_order_code`;

-- -----------------------------------------------------------------------------
-- 5) Limpiar el procedimiento auxiliar
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `cie10_agregar_indice`;

SELECT 'Postcarga terminada: índices listos.' AS resultado;

