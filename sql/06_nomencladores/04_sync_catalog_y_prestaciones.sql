-- =============================================================================
-- 06_nomencladores / 04_sync_catalog_y_prestaciones.sql
-- Sincronización gobernada (aditiva e idempotente) desde tablas fuente hacia:
--   1. os_catalog / os_catalog_release / os_catalog_language (es-AR, en, pt-BR)
--   2. os_catalog_item / os_catalog_item_version (es-AR + en desde SNOMED) /
--      os_catalog_identifier / os_concept_mapping (SNOMED, LOINC)
--   3. os_prestacion + os_prestacion_codigo (base transversal para UVR y mapeos)
--
-- Fuentes sincronizadas:
--   - nomencladores_argentina (NN_PMO -> nn-pmo, NBU -> nbu)
--   - imagenes_practicas -> imagenes-ar
--   - pmo_practicas -> pmo-ar
--
-- No borra ni pisa registros existentes de DENTAR, OFTAR ni versiones aprobadas.
-- =============================================================================

SET client_encoding = 'UTF8';
SET search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Verificar dependencias críticas
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF to_regclass('public.os_catalog') IS NULL
       OR to_regclass('public.os_catalog_item') IS NULL
       OR to_regclass('public.os_prestacion') IS NULL
       OR to_regclass('public.os_prestacion_codigo') IS NULL THEN
        RAISE EXCEPTION 'Faltan tablas núcleo (os_catalog / os_prestacion).';
    END IF;
    RAISE NOTICE 'Dependencias núcleo OK.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Asegurar catálogos faltantes (imagenes-ar, pmo-ar) y releases publicados
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO os_catalog (code, name, organization, country_code, domain_type, short_name, description, is_active)
VALUES
    ('imagenes-ar', 'Prácticas de Diagnóstico por Imágenes · Argentina', 'SNOMED CT Argentina / DICOM', 'AR', 'medical', 'IMAGENES-AR',
     'Prácticas prescribibles de diagnóstico por imágenes vinculadas a SNOMED CT y modalidad DICOM.', TRUE),
    ('pmo-ar', 'Programa Médico Obligatorio (PMO) · Res. 201/2002', 'Ministerio de Salud de la Nación', 'AR', 'medical', 'PMO-AR',
     'Canasta básica obligatoria de prestaciones médicas del Sistema Nacional del Seguro de Salud.', TRUE)
ON CONFLICT (code) DO NOTHING;

-- Asegurar release '2026-v1' published para los 4 catálogos si no tienen uno published
INSERT INTO os_catalog_release (catalog_id, version_tag, valid_from, official_norm_reference, status)
SELECT c.id, '2026-v1', DATE '2026-01-01',
       CASE c.code
           WHEN 'nn-pmo'      THEN 'Nomenclador Nacional Anexo I 2025'
           WHEN 'nbu'         THEN 'Nomenclador Bioquímico Único (CUBRA / SNOMED AR 2026)'
           WHEN 'imagenes-ar' THEN 'Refset Imágenes SNOMED CT AR 2026-08-20'
           WHEN 'pmo-ar'      THEN 'Resolución MSAL 201/2002 (PMO)'
       END,
       'published'
FROM os_catalog c
WHERE c.code IN ('nn-pmo', 'nbu', 'imagenes-ar', 'pmo-ar')
  AND NOT EXISTS (
      SELECT 1 FROM os_catalog_release r
      WHERE r.catalog_id = c.id AND r.status = 'published'
  )
ON CONFLICT (catalog_id, version_tag) DO UPDATE SET status = 'published';

-- Asegurar idiomas (es-AR default, en fallback, pt-BR habilitado) en os_catalog_language
INSERT INTO os_catalog_language (catalog_id, language_code, is_default, is_fallback, coverage_status)
SELECT c.id, l.language_code, l.is_default, l.is_fallback, 'undetermined'
FROM os_catalog c
CROSS JOIN (
    VALUES
        ('es-AR', TRUE,  FALSE),
        ('en',    FALSE, TRUE),
        ('pt-BR', FALSE, FALSE)
) AS l(language_code, is_default, is_fallback)
WHERE c.code IN ('nn-pmo', 'nbu', 'imagenes-ar', 'pmo-ar')
  AND EXISTS (SELECT 1 FROM os_language ol WHERE ol.code = l.language_code)
  AND NOT EXISTS (
      SELECT 1 FROM os_catalog_language ocl
      WHERE ocl.catalog_id = c.id AND ocl.language_code = l.language_code
  )
ON CONFLICT (catalog_id, language_code) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Staging unificado de prestaciones desde las 4 fuentes
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS _stg_sync_items;
CREATE TEMP TABLE _stg_sync_items (
    catalog_code      VARCHAR(50) NOT NULL,
    permanent_code    VARCHAR(50) NOT NULL,
    official_code     VARCHAR(50) NOT NULL,
    system_name       VARCHAR(50) NOT NULL,
    preferred_term    TEXT NOT NULL,
    capitulo          TEXT,
    snomed_concept_id BIGINT,
    codigo_loinc      VARCHAR(20),
    prestation_type   VARCHAR(40) NOT NULL,
    source_reference  TEXT NOT NULL,
    PRIMARY KEY (catalog_code, permanent_code)
);

-- 2a. NN_PMO (nomencladores_argentina)
INSERT INTO _stg_sync_items
SELECT DISTINCT ON (LEFT(TRIM(n.codigo), 40))
    'nn-pmo',
    'NN-' || LEFT(TRIM(n.codigo), 40),
    LEFT(TRIM(n.codigo), 50),
    'NOMENCLADOR_AR',
    TRIM(n.descripcion),
    n.capitulo,
    n.snomed_concept_id,
    n.codigo_loinc,
    'procedure',
    'nomencladores_argentina:NN_PMO'
FROM nomencladores_argentina n
WHERE n.tipo_nomenclador = 'NN_PMO' AND n.activo = TRUE
  AND TRIM(n.codigo) <> '' AND TRIM(n.descripcion) <> ''
ORDER BY LEFT(TRIM(n.codigo), 40), n.id;

-- 2b. NBU (nomencladores_argentina)
INSERT INTO _stg_sync_items
SELECT DISTINCT ON (LEFT(TRIM(n.codigo), 40))
    'nbu',
    'NBU-' || LEFT(TRIM(n.codigo), 40),
    LEFT(TRIM(n.codigo), 50),
    'NBU_AR',
    TRIM(n.descripcion),
    n.capitulo,
    n.snomed_concept_id,
    n.codigo_loinc,
    'diagnostic_procedure',
    'nomencladores_argentina:NBU'
FROM nomencladores_argentina n
WHERE n.tipo_nomenclador = 'NBU' AND n.activo = TRUE
  AND TRIM(n.codigo) <> '' AND TRIM(n.descripcion) <> ''
ORDER BY LEFT(TRIM(n.codigo), 40), n.id;

-- 2c. Imágenes (imagenes_practicas)
INSERT INTO _stg_sync_items
SELECT DISTINCT ON (LEFT(TRIM(ip.codigo_estudio), 40))
    'imagenes-ar',
    'IMG-' || LEFT(TRIM(ip.codigo_estudio), 40),
    LEFT(TRIM(ip.codigo_estudio), 50),
    'DICOM_SNOMED_AR',
    TRIM(ip.nombre_estudio),
    'Modalidad ' || ip.modalidad_dicom,
    ip.snomed_concept_id,
    ip.codigo_loinc,
    'diagnostic_procedure',
    'imagenes_practicas'
FROM imagenes_practicas ip
WHERE ip.activo = TRUE
  AND TRIM(ip.codigo_estudio) <> '' AND TRIM(ip.nombre_estudio) <> ''
ORDER BY LEFT(TRIM(ip.codigo_estudio), 40), ip.id;

-- 2d. PMO (pmo_practicas, si existe)
DO $$
BEGIN
    IF to_regclass('public.pmo_practicas') IS NOT NULL THEN
        INSERT INTO _stg_sync_items
        SELECT DISTINCT ON (LEFT(TRIM(p.codigo), 40))
            'pmo-ar',
            'PMO-' || LEFT(TRIM(p.codigo), 40),
            LEFT(TRIM(p.codigo), 50),
            'PMO_AR',
            TRIM(p.practica),
            NULL,
            NULL,
            NULL,
            'procedure',
            'pmo_practicas'
        FROM pmo_practicas p
        WHERE TRIM(COALESCE(p.codigo, '')) <> ''
          AND TRIM(COALESCE(p.practica, '')) <> ''
        ORDER BY LEFT(TRIM(p.codigo), 40), p.id
        ON CONFLICT (catalog_code, permanent_code) DO NOTHING;
    END IF;
END $$;

SELECT catalog_code, COUNT(*) AS items_staging
FROM _stg_sync_items
GROUP BY catalog_code
ORDER BY catalog_code;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Insertar en os_catalog_item + os_catalog_identifier + os_catalog_item_version
-- ─────────────────────────────────────────────────────────────────────────────
-- 3a. os_catalog_item
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT c.id, s.permanent_code, 'active'
FROM _stg_sync_items s
JOIN os_catalog c ON c.code = s.catalog_code
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

-- 3b. os_catalog_identifier
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, s.system_name, s.official_code, TRUE
FROM _stg_sync_items s
JOIN os_catalog c ON c.code = s.catalog_code
JOIN os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.permanent_code
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- 3c. os_catalog_item_version en 'es-AR' (solo inserta si no existe para ese item/release/idioma)
INSERT INTO os_catalog_item_version (
    item_id, release_id, preferred_term, definition, language_code,
    source_language_code, source_reference
)
SELECT DISTINCT ON (i.id, r.id)
    i.id,
    r.id,
    LEFT(s.preferred_term, 255),
    CASE WHEN LENGTH(s.preferred_term) > 255 OR s.capitulo IS NOT NULL
         THEN COALESCE(s.capitulo || ' · ', '') || s.preferred_term
         ELSE NULL
    END,
    'es-AR',
    'es-AR',
    s.source_reference
FROM _stg_sync_items s
JOIN os_catalog c ON c.code = s.catalog_code
JOIN os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.permanent_code
JOIN LATERAL (
    SELECT id FROM os_catalog_release
    WHERE catalog_id = c.id AND status = 'published'
    ORDER BY id DESC LIMIT 1
) r ON TRUE
ORDER BY i.id, r.id
ON CONFLICT (item_id, release_id, language_code) DO NOTHING;

-- 3d. os_catalog_item_version en 'en' (cuando el concepto SNOMED tiene término en inglés)
INSERT INTO os_catalog_item_version (
    item_id, release_id, preferred_term, language_code,
    source_language_code, source_reference
)
SELECT DISTINCT ON (i.id, r.id)
    i.id,
    r.id,
    LEFT(sd.term, 255),
    'en',
    'en',
    'snomed_descriptions:en'
FROM _stg_sync_items s
JOIN os_catalog c ON c.code = s.catalog_code
JOIN os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.permanent_code
JOIN LATERAL (
    SELECT id FROM os_catalog_release
    WHERE catalog_id = c.id AND status = 'published'
    ORDER BY id DESC LIMIT 1
) r ON TRUE
JOIN LATERAL (
    SELECT term FROM snomed_descriptions
    WHERE concept_id = s.snomed_concept_id
      AND language_code = 'en'
      AND active = TRUE
    ORDER BY (type_id = 900000000000013009) DESC, id
    LIMIT 1
) sd ON s.snomed_concept_id IS NOT NULL
ORDER BY i.id, r.id
ON CONFLICT (item_id, release_id, language_code) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Mapeos en os_concept_mapping (SNOMED CT y LOINC)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_snomed_sys_id INT;
    v_loinc_sys_id  INT;
BEGIN
    SELECT id INTO v_snomed_sys_id FROM os_terminology_system WHERE code ILIKE 'SNOMED%' ORDER BY id LIMIT 1;
    SELECT id INTO v_loinc_sys_id  FROM os_terminology_system WHERE code ILIKE 'LOINC%'  ORDER BY id LIMIT 1;

    IF v_snomed_sys_id IS NOT NULL THEN
        INSERT INTO os_concept_mapping (
            item_id, terminology_system_id, external_code, external_display,
            mapping_type, relationship_role, review_status
        )
        SELECT
            i.id,
            v_snomed_sys_id,
            s.snomed_concept_id::TEXT,
            LEFT(COALESCE(sd.term, s.preferred_term), 255),
            'equivalent',
            'procedure_concept',
            'approved'
        FROM _stg_sync_items s
        JOIN os_catalog c ON c.code = s.catalog_code
        JOIN os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.permanent_code
        LEFT JOIN LATERAL (
            SELECT term FROM snomed_descriptions
            WHERE concept_id = s.snomed_concept_id AND active = TRUE
            ORDER BY (language_code = 'es') DESC, id LIMIT 1
        ) sd ON TRUE
        WHERE s.snomed_concept_id IS NOT NULL
        ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
    END IF;

    IF v_loinc_sys_id IS NOT NULL THEN
        INSERT INTO os_concept_mapping (
            item_id, terminology_system_id, external_code, external_display,
            mapping_type, relationship_role, review_status
        )
        SELECT
            i.id,
            v_loinc_sys_id,
            s.codigo_loinc,
            LEFT(s.preferred_term, 255),
            'equivalent',
            'observation_concept',
            'approved'
        FROM _stg_sync_items s
        JOIN os_catalog c ON c.code = s.catalog_code
        JOIN os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.permanent_code
        WHERE s.codigo_loinc IS NOT NULL AND TRIM(s.codigo_loinc) <> ''
        ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Poblar os_prestacion + os_prestacion_codigo (base transversal para UVR)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO os_prestacion (
    code, display_name, prestation_type, is_valuable, eligibility_evidence, status, source_reference
)
SELECT
    s.permanent_code,
    LEFT(s.preferred_term, 500),
    s.prestation_type,
    TRUE,
    s.source_reference,
    'published',
    s.source_reference
FROM _stg_sync_items s
ON CONFLICT (code) DO NOTHING;

INSERT INTO os_prestacion_codigo (
    prestacion_id, catalog_code, item_id, external_code,
    correspondence_type, review_status, source_reference
)
SELECT
    p.id,
    s.catalog_code,
    i.id,
    s.official_code,
    'corresponding',
    'approved',
    s.source_reference
FROM _stg_sync_items s
JOIN os_prestacion p ON p.code = s.permanent_code
JOIN os_catalog c ON c.code = s.catalog_code
JOIN os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.permanent_code
ON CONFLICT (prestacion_id, catalog_code, item_id, external_code) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Verificación final
-- ─────────────────────────────────────────────────────────────────────────────
SELECT c.code AS catalog_code, COUNT(*) AS items
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id
WHERE c.code IN ('nn-pmo', 'nbu', 'imagenes-ar', 'pmo-ar')
GROUP BY c.code
ORDER BY c.code;

SELECT language_code, COUNT(*) AS versiones
FROM os_catalog_item_version v
JOIN os_catalog_item i ON i.id = v.item_id
JOIN os_catalog c ON c.id = i.catalog_id
WHERE c.code IN ('nn-pmo', 'nbu', 'imagenes-ar', 'pmo-ar')
GROUP BY language_code
ORDER BY language_code;

SELECT catalog_code, COUNT(*) AS prestaciones_vinculadas
FROM os_prestacion_codigo
GROUP BY catalog_code
ORDER BY catalog_code;

ANALYZE os_catalog_item;
ANALYZE os_catalog_item_version;
ANALYZE os_prestacion;
ANALYZE os_prestacion_codigo;

DO $$ BEGIN RAISE NOTICE 'Sincronización a os_catalog_item + os_prestacion finalizada.'; END $$;
