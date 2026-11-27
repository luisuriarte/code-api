-- =============================================================================
-- Origen Salud · PMO · Precios Históricos
-- sql/04_pmo/02_precios_historial.sql
-- =============================================================================
-- Registra precios históricos de las prestaciones PMO (Res. 201/2002 +
-- Actualización 1/2002) en la tabla os_fee_item, usando el schedule existente
-- de nn-pmo. Los precios se expresan en GALENO (unidad arancelaria histórica).
-- Idempotente: seguro reejecutarse sin duplicar registros.
-- =============================================================================

SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. Verificar que el catálogo nn-pmo y sus prácticas existen
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM os_catalog WHERE code = 'nn-pmo') THEN
        RAISE EXCEPTION 'El catálogo nn-pmo no existe. Ejecutar 02_pmo_practicas.sql primero.';
    END IF;

    IF (SELECT COUNT(*) FROM os_catalog_item WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')) = 0 THEN
        RAISE EXCEPTION 'No hay prácticas importadas en nn-pmo. Ejecutar 02_pmo_practicas.sql primero.';
    END IF;
END$$;

-- =============================================================================
-- 2. Crear fee schedule histórico para nn-pmo (si no existe)
-- =============================================================================
INSERT INTO os_fee_schedule (catalog_id, name, valid_from, valid_to)
SELECT
    (SELECT id FROM os_catalog WHERE code = 'nn-pmo'),
    'PMO Res. 201/2002',
    '2002-01-01'::date,
    NULL
WHERE NOT EXISTS (
    SELECT 1 FROM os_fee_schedule
    WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
      AND name = 'PMO Res. 201/2002'
);

-- =============================================================================
-- 3. Cargar valores base en GALENO para las prácticas importadas
-- =============================================================================
-- Valor de referencia histórico: 1 GALENO por práctica como base.
-- Actualizar con valores reales según Res. 201/2002.
INSERT INTO os_fee_item (item_id, fee_schedule_id, pricing_unit_id, units_amount)
SELECT
    i.id,
    fs.id,
    (SELECT id FROM os_pricing_unit WHERE code = 'GALENO'),
    1.00
FROM os_catalog_item i
CROSS JOIN (
    SELECT id FROM os_fee_schedule
    WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
      AND name = 'PMO Res. 201/2002'
) fs
WHERE i.catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo')
ON CONFLICT (item_id, fee_schedule_id) DO NOTHING;

-- =============================================================================
-- 4. Validación
-- =============================================================================
SELECT
    'Fee items cargados para nn-pmo' AS descripcion,
    COUNT(*) AS total
FROM os_fee_item fi
JOIN os_catalog_item i ON i.id = fi.item_id
WHERE i.catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo');

SELECT
    'Fee schedule registrado' AS descripcion,
    name,
    valid_from,
    valid_to,
    currency
FROM os_fee_schedule
WHERE catalog_id = (SELECT id FROM os_catalog WHERE code = 'nn-pmo');
