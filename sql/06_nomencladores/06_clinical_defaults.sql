-- =============================================================================
-- 06_nomencladores / 06_clinical_defaults.sql
-- Asigna la categoría clínica por defecto (os_catalog_clinical_default) para
-- que los catálogos sincronizados muestren su concepto/categoría clínica en
-- el Code Browser y en la API.
-- =============================================================================

SET client_encoding = 'UTF8';
SET search_path = public;

INSERT INTO os_catalog_clinical_default (catalog_code, clinical_category_code)
VALUES
    ('imagenes-ar',  'CLIN-EST'),
    ('pmo-ar',       'CLIN-PREST'),
    ('nbu',          'CLIN-EST'),
    ('nn-pmo',       'CLIN-PREST'),
    ('andis',        'CLIN-PREST'),
    ('kinesiologia', 'CLIN-PROC'),
    ('nhpgd',        'CLIN-PREST'),
    ('salud-mental', 'CLIN-PREST')
ON CONFLICT (catalog_code) DO NOTHING;

SELECT d.catalog_code, d.clinical_category_code, cc.name
FROM os_catalog_clinical_default d
JOIN os_clinical_category cc ON cc.code = d.clinical_category_code
ORDER BY d.catalog_code;
