-- =============================================================================
-- CIE-10-ES Edición Argentina para OpenEMR
-- 01_esquema.sql  ::  crea las tablas de trabajo
-- =============================================================================
--
-- Fuente: Ministerio de Sanidad de España - CIE-10-ES (Edición Española)
-- Distribución oficial: https://www.sanidad.gob.es/estadEstudios/estadisticas/normalizacion/home.htm
-- Consulta interactiva:  https://www.eciemaps.sanidad.gob.es/
--
-- QUÉ HACE ESTE SCRIPT
--   Borra y vuelve a crear las tablas `icd10_dx_order_code` e
--   `icd10_pcs_order_code`, que son las tablas nativas de OpenEMR para
--   diagnósticos y procedimientos CIE-10. No toca ninguna otra tabla clínica.
--
-- DECISIÓN DE DISEÑO
--   Se usan los nombres de tabla nativos de OpenEMR para que el autocompletado
--   de diagnósticos, el módulo de recetas y los formularios clínicos los
--   reconozcan sin necesidad de ningún parche.
--
-- CAMPOS
--   icd10_dx_order_code:
--     dx_code          → código con punto (A00.0)
--     formatted_dx_code → código sin punto (A000), que usa OpenEMR internamente
--     valid_for_coding  → 1 = nodo final (codificable), 0 = categoría padre
--     short_desc        → truncado a 60 caracteres (compatibilidad OpenEMR)
--     long_desc         → descripción completa (hasta 300 caracteres en CIE-10-ES)
--     active            → 1 = activo
--     revision          → número de edición cargada
--
--   icd10_pcs_order_code:
--     pcs_code         → código de 7 caracteres (0016070)
--     valid_for_coding → siempre 1 (todos los procedimientos son codificables)
--     short_desc        → truncado a 60 caracteres
--     long_desc         → descripción completa (hasta 220 caracteres)
--     active            → 1 = activo
--     revision          → número de edición cargada
--
-- ORDEN DE EJECUCIÓN
--   01_esquema.sql   → este archivo
--   02_carga.sql     → generado con scripts/generar_carga.php
--   03_postcarga.sql → índices y registro de versión
--   99_verificacion.sql
--
-- REQUISITOS: MySQL 8.0+ o MariaDB 10.4+. utf8mb4.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- 1. Diagnósticos CIE-10-ES
-- =============================================================================

DROP TABLE IF EXISTS `icd10_dx_order_code`;
CREATE TABLE `icd10_dx_order_code` (
  `dx_id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT
                         COMMENT 'Identificador interno secuencial. Auto-generado en la carga.',
  `dx_code`            VARCHAR(15)     DEFAULT NULL
                         COMMENT 'Código CIE-10 con punto decimal tal como aparece en la tabla de referencia (ej.: A00.0, A18.02).',
  `formatted_dx_code`  VARCHAR(10)     DEFAULT NULL
                         COMMENT 'Código sin punto decimal, formato que usa OpenEMR internamente (ej.: A000, A1802).',
  `valid_for_coding`   VARCHAR(50)     DEFAULT NULL
                         COMMENT '1 = nodo final (código codificable). 0 = categoría padre no codificable. Corresponde a Nodo_Final del CSV.',
  `short_desc`         VARCHAR(60)     DEFAULT NULL
                         COMMENT 'Descripción truncada a 60 caracteres para compatibilidad con campos cortos de OpenEMR.',
  `long_desc`          TEXT            DEFAULT NULL
                         COMMENT 'Descripción completa. En CIE-10-ES 2026 el texto más largo mide 251 caracteres.',
  `active`             TINYINT(4)      DEFAULT 1
                         COMMENT '1 = activo (todos los cargados están activos).',
  `revision`           INT(11)         DEFAULT 0
                         COMMENT 'Número de edición: 1 = 2022, 2 = 2024, 3 = 2026, etc. Permite identificar la versión cargada.',
  PRIMARY KEY (`dx_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  ROW_FORMAT=DYNAMIC
  COMMENT='CIE-10-ES Diagnósticos. Tabla nativa de OpenEMR. Fuente: Ministerio de Sanidad de España.';

-- =============================================================================
-- 2. Procedimientos CIE-10-ES (ICD-10-PCS)
-- =============================================================================

DROP TABLE IF EXISTS `icd10_pcs_order_code`;
CREATE TABLE `icd10_pcs_order_code` (
  `pcs_id`             BIGINT(20)      NOT NULL AUTO_INCREMENT
                         COMMENT 'Identificador interno secuencial.',
  `pcs_code`           VARCHAR(7)      DEFAULT NULL
                         COMMENT 'Código ICD-10-PCS de 7 caracteres alfanuméricos (ej.: 0016070).',
  `valid_for_coding`   CHAR(1)         DEFAULT '1'
                         COMMENT 'Siempre 1: todos los procedimientos en la tabla de referencia son codificables.',
  `short_desc`         VARCHAR(60)     DEFAULT NULL
                         COMMENT 'Descripción truncada a 60 caracteres.',
  `long_desc`          TEXT            DEFAULT NULL
                         COMMENT 'Descripción completa. En CIE-10-ES 2026 el texto más largo mide 210 caracteres.',
  `active`             TINYINT(4)      DEFAULT 1
                         COMMENT '1 = activo.',
  `revision`           INT(11)         DEFAULT 0
                         COMMENT 'Número de edición cargada.',
  PRIMARY KEY (`pcs_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  ROW_FORMAT=DYNAMIC
  COMMENT='CIE-10-ES Procedimientos (ICD-10-PCS). Tabla nativa de OpenEMR. Fuente: Ministerio de Sanidad de España.';

SELECT 'Esquema CIE-10 creado. Continúe con 02_carga.sql.' AS resultado;

