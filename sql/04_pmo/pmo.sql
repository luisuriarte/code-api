-- =============================================================================
-- Origen Salud · PMO (Programa Médico Obligatorio) · Actualizado 2026
-- sql/04_pmo/pmo.sql
-- =============================================================================
-- Actualización del script original pmo_2002.sql al sistema de códigos actual.
-- Este script forma parte del motor canonical os_* y sigue las convenciones:
--   - Identificadores: codigos PMO con prefijo adecuado
--   - Integración con catálogos dentar-pr/dentar-dx
--   - Uso de extensiones y tipos definidos en design.sql
-- =============================================================================

SET client_encoding = 'UTF8';
SET search_path = public;

-- =============================================================================
-- 1. Verificación de dependencias
-- =============================================================================
-- Asegurar que la extensión pg_trgm esté disponible (creada por design.sql)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Verificar que el catálogo DENTAR-PR existe (ejecutado previamente dentar_family.sql)
DO $$
BEGIN
    IF to_regclass('public.dentar_catalog') IS NULL THEN
        RAISE EXCEPTION 'La tabla dentar_catalog no existe. Ejecutá antes sql/03_dentar/dentar_family.sql';
    END IF;
    
    IF to_regclass('public.os_catalog') IS NULL THEN
        RAISE EXCEPTION 'La tabla os_catalog no existe. Ejecutá antes sql/02_catalogs/origen_catalog_engine.sql';
    END IF;
END
$$;

-- =============================================================================
-- 2. Tabla PMO: Estructura de Prestaciones
-- =============================================================================
-- Tabla de prestaciones del Programa Médico Obligatorio
CREATE TABLE IF NOT EXISTS pmo_prestacion (
    id BIGSERIAL PRIMARY KEY,
    codigo_vinculado VARCHAR(20) NOT NULL UNIQUE,     -- Código PMO (ej: PMO-0101)
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    categoria VARCHAR(100),                          -- Ej: 'Gral', 'Especializada'
    codigo_dentar_pr VARCHAR(20),                    -- Vinculación DENTAR-PR (DNT-PR-NNNNNN)
    codigo_dentar_dx VARCHAR(20),                    -- Vinculación DENTAR-DX (DNT-DX-NNNNNN)
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_vigencia_desde DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_vigencia_hasta DATE,                       -- NULL = vigente actual
    fecha_creacion TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Índices para búsquedas PMO
CREATE INDEX IF NOT EXISTS idx_pmo_prestacion_codigo ON pmo_prestacion(codigo_vinculado);
CREATE INDEX IF NOT EXISTS idx_pmo_prestacion_dentar_pr ON pmo_prestacion(codigo_dentar_pr);
CREATE INDEX IF NOT EXISTS idx_pmo_prestacion_categoria ON pmo_prestacion(categoria);
CREATE INDEX IF NOT EXISTS idx_pmo_prestacion_activo ON pmo_prestacion(activo);

-- Comentario en la tabla
COMMENT ON TABLE pmo_prestacion IS 'Tabla de prestaciones del Programa Médico Obligatorio (PMO), integrada con catálogos DENTAR.';

-- =============================================================================
-- 3. Tabla PMO: Vinculación con Catálogos DENTAR
-- =============================================================================
-- Tabla de mapeos PMO ↔ DENTAR
CREATE TABLE IF NOT EXISTS pmo_dentar_mapping (
    id BIGSERIAL PRIMARY KEY,
    codigo_pmo VARCHAR(20) NOT NULL,
    codigo_dentar VARCHAR(20) NOT NULL,             -- DNT-PR-NNNNNN o DNT-DX-NNNNNN
    tipo_relacion VARCHAR(20) NOT NULL,              -- 'equivalent', 'related', 'precursor'
    fecha_vigencia_desde DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_vigencia_hasta DATE,                       -- NULL = vigente actual
    fuente VARCHAR(50) NOT NULL DEFAULT 'actualizacion_2025', -- 'pmo_2002', 'actualizacion_2025', etc.
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(codigo_pmo, codigo_dentar, tipo_relacion, fecha_vigencia_desde)
);

-- Índices para búsquedas de mapping
CREATE INDEX IF NOT EXISTS idx_pmo_dentar_mapping_pmo ON pmo_dentar_mapping(codigo_pmo);
CREATE INDEX IF NOT EXISTS idx_pmo_dentar_mapping_dentar ON pmo_dentar_mapping(codigo_dentar);
CREATE INDEX IF NOT EXISTS idx_pmo_dentar_mapping_activo ON pmo_dentar_mapping(activo);

-- Restricción de integridad referencial opcional (si las tablas existen)
DO $$
BEGIN
    IF to_regclass('public.dentar_catalog') IS NOT NULL THEN
        -- Agregar FK condicional solo si la tabla dentar_catalog existe
        PERFORM 1; -- Placeholder - FKs completas gestionadas por aplicación
    END IF;
END
$$;

-- =============================================================================
-- 4. Datos Iniciales PMO (Base 2025 actualizada)
-- =============================================================================
-- Datos del PMO actualizados (reemplaza/o complementa pmo_2002.sql)
-- Estos datos consideran la integración con catálogos DENTAR actuales

INSERT INTO pmo_prestacion (codigo_vinculado, nombre, descripcion, categoria, codigo_dentar_pr, codigo_dentar_dx, activo, fecha_vigencia_desde)
VALUES
-- Prestaciones generales de medicina
('PMO-0101', 'Consulta general', 'Consulta médica general de atención primaria', 'Gral', NULL, NULL, TRUE, CURRENT_DATE),
('PMO-0102', 'Control nutricional', 'Control y seguimiento nutricional', 'Gral', NULL, NULL, TRUE, CURRENT_DATE),
('PMO-0103', 'Vacunación', 'Aplicación de vacunas del calendario nacional', 'Gral', NULL, NULL, TRUE, CURRENT_DATE),

-- Prestaciones odontológicas (vinculadas a DENTAR-PR)
('PMO-1001', 'Consulta odontológica', 'Consulta de control bucal', 'Odontológica', 'DNT-PR-010101', NULL, TRUE, CURRENT_DATE),
('PMO-1002', 'Obturación simple', 'Obturación de caries en pieza única', 'Odontológica', 'DNT-PR-020101', NULL, TRUE, CURRENT_DATE),
('PMO-1003', 'Extracción simple', 'Extracción de pieza dental permanente', 'Odontológica', 'DNT-PR-030101', NULL, TRUE, CURRENT_DATE),

-- Vinculaciones DENTAR-DX (diagnósticos)
('PMO-2001', 'Dolor dental', 'Dolor de origen dental o paradental', 'Odontológica', NULL, 'DNT-DX-010101', TRUE, CURRENT_DATE),
('PMO-2002', 'Caries dental', 'Caries en esmalte y dentina', 'Odontológica', NULL, 'DNT-DX-020101', TRUE, CURRENT_DATE);

-- Mapeos PMO ↔ DENTAR
INSERT INTO pmo_dentar_mapping (codigo_pmo, codigo_dentar, tipo_relacion, fuente, activo)
VALUES
('PMO-1001', 'DNT-PR-010101', 'equivalent', 'pmo_2002_actualizacion', TRUE),
('PMO-1002', 'DNT-PR-020101', 'equivalent', 'pmo_2002_actualizacion', TRUE),
('PMO-1003', 'DNT-PR-030101', 'equivalent', 'pmo_2002_actualizacion', TRUE),
('PMO-2001', 'DNT-DX-010101', 'equivalent', 'pmo_2002_actualizacion', TRUE),
('PMO-2002', 'DNT-DX-020101', 'equivalent', 'pmo_2002_actualizacion', TRUE);

-- =============================================================================
-- 5. Vista PMO para Consultas
-- =============================================================================
-- Vista consolidada para consultas y reportes
CREATE OR REPLACE VIEW v_pmo_resumen AS
SELECT
    p.codigo_vinculado,
    p.nombre,
    p.categoria,
    p.codigo_dentar_pr,
    p.codigo_dentar_dx,
    m.tipo_relacion,
    m.codigo_dentar AS codigo_dentar_detalle,
    m.fecha_vigencia_desde
FROM pmo_prestacion p
LEFT JOIN pmo_dentar_mapping m ON p.codigo_vinculado = m.codigo_pmo AND m.activo = TRUE
WHERE p.activo = TRUE;

-- Índice en la vista
CREATE INDEX IF NOT EXISTS idx_v_pmo_resumen_codigo ON v_pmo_resumen(codigo_vinculado);

-- =============================================================================
-- 6. Funciones Útiles PMO
-- =============================================================================
-- Función para obtener código DENTAR vinculado a un PMO
CREATE OR REPLACE FUNCTION pmo_obtener_codigo_dentat(codigo_pmo VARCHAR(20))
RETURNS TABLE (
    codigo_dentar VARCHAR(20),
    tipo_relacion VARCHAR(20),
    activo BOOLEAN
)
LANGUAGE sql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT codigo_dentar, tipo_relacion, activo
    FROM pmo_dentar_mapping
    WHERE codigo_pmo = pmo_obtener_codigo_dentat.codigo_pmo AND activo = TRUE;
END
$$;

-- Función para validar si un código PMO está vigente
CREATE OR REPLACE FUNCTION pmo_es_vigente(codigo_pmo VARCHAR(20), fecha_consulta DATE DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
BEGIN
    IF fecha_consulta IS NULL THEN
        fecha_consulta := CURRENT_DATE;
    END IF;
    
    RETURN EXISTS (
        SELECT 1 FROM pmo_prestacion
        WHERE codigo_vinculado = pmo_es_vigente.codigo_pmo
        AND activo = TRUE
        AND fecha_vigencia_desde <= fecha_consulta
        AND (fecha_vigencia_hasta IS NULL OR fecha_vigencia_hasta >= fecha_consulta)
    );
END
$$;

-- =============================================================================
-- Fin del script PMO 2026 actualizado
-- =============================================================================

-- Nota: Este script depende de:
--   - sql/01_schema/design.sql (extensiones, tipos base)
--   - sql/02_catalogs/origen_catalog_engine.sql (os_catalog, catálogos)
--   - sql/03_dentar/dentar_family.sql (catálogos dentar-pr/dentar-dx)
--   - sql/03_dentar/dantar_core_and_diagnosis.sql (estructura tables)
--
-- Ejecución recomendada en VPS:
--   sudo -u postgres psql -d origen_salud -f sql/04_pmo/pmo.sql