-- =============================================================================
-- 06_nomencladores / 03_imagenes_snomed.sql
-- Carga y enriquecimiento de imagenes_practicas desde SNOMED CT Argentina 2026
--
-- Fuente (en VPS):
--   tools/sources/snomed_argentina/snomed_imagenes_536561.txt
--   Refset 536561000221108 — prácticas prescribibles de diagnóstico por imágenes (602 filas)
--
-- Acciones:
--   1. Carga los conceptos faltantes en imagenes_practicas (usando codigo_estudio = 'SCT-' || id)
--   2. Actualiza modalidad_dicom ('CT','MR','US','XR','MG','NM','PT','DX') y
--      requiere_contraste en registros existentes que estaban en 'OT'
-- =============================================================================

SET client_encoding = 'UTF8';
SET search_path = public;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Verificar dependencias
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'imagenes_practicas') THEN
        RAISE EXCEPTION 'Tabla imagenes_practicas no existe.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM snomed_concepts LIMIT 1) THEN
        RAISE EXCEPTION 'snomed_concepts está vacía.';
    END IF;
    RAISE NOTICE 'Dependencias OK.';
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Staging
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS _stg_img;
CREATE TEMP TABLE _stg_img (
    id_row             UUID,
    effective_time     TEXT,
    active             TEXT,
    module_id          BIGINT,
    refset_id          BIGINT,
    refset_term        TEXT,
    snomed_concept_id  BIGINT,
    termino            TEXT
);

\copy _stg_img FROM '/var/www/html/origen.ar/code-api/tools/sources/snomed_argentina/snomed_imagenes_536561.txt' WITH (FORMAT TEXT, DELIMITER E'\t', HEADER TRUE, ENCODING 'UTF8');

SELECT 'Filas staging Imágenes' AS descripcion, COUNT(*) AS total FROM _stg_img;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Función temporal para inferir modalidad DICOM estándar desde el término
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION pg_temp.infer_dicom_modality(p_term TEXT)
RETURNS VARCHAR(10)
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_term ~* '(emisión de positrones|\yPET\y)' THEN 'PT'
        WHEN p_term ~* '(tomografía computarizada|angiotomografía|\yTC\y)' THEN 'CT'
        WHEN p_term ~* '(resonancia magnética|angiorresonancia|colangiorresonancia|\yRM\y)' THEN 'MR'
        WHEN p_term ~* '(ecografía|ultrasonografía|ecocardiografía|eco-?doppler|\ydoppler\y)' THEN 'US'
        WHEN p_term ~* '(mamografía|galactografía)' THEN 'MG'
        WHEN p_term ~* '(centellografía|gammagrafía|radioisotóp|medicina nuclear|\ySPECT\y|captación de iodo)' THEN 'NM'
        WHEN p_term ~* '(densitometría|absorciometría)' THEN 'DX'
        WHEN p_term ~* '(radiografía|espinografía|telerradiografía|ortopantomografía|urografía|pielografía|histerosalpingografía|angiografía|arteriografía|flebografía|linfografía|colangiografía|cinecoronariografía|fluoroscop|tránsito|enema opaco|seriada)' THEN 'XR'
        ELSE 'OT'
    END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Actualizar registros ya existentes en imagenes_practicas (por snomed_concept_id)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_upd_snomed INTEGER := 0;
    v_ins_new    INTEGER := 0;
    v_upd_all    INTEGER := 0;
BEGIN
    -- 3a. Enriquecer los que ya existen con ese snomed_concept_id
    UPDATE imagenes_practicas ip
    SET
        nombre_estudio     = COALESCE(NULLIF(ip.nombre_estudio, ''), s.termino),
        modalidad_dicom    = CASE
                                WHEN ip.modalidad_dicom = 'OT'
                                THEN pg_temp.infer_dicom_modality(COALESCE(NULLIF(ip.nombre_estudio, ''), s.termino))
                                ELSE ip.modalidad_dicom
                             END,
        requiere_contraste = ip.requiere_contraste
                             OR (COALESCE(ip.nombre_estudio, s.termino) ~* 'contraste|gadolinio|bario|yodad|fluoresceína'),
        activo             = TRUE
    FROM _stg_img s
    WHERE s.active = '1'
      AND ip.snomed_concept_id = s.snomed_concept_id;

    GET DIAGNOSTICS v_upd_snomed = ROW_COUNT;

    -- 3b. Insertar los del refset 536561 que aún no existen en imagenes_practicas
    WITH ins AS (
        INSERT INTO imagenes_practicas (
            codigo_estudio, nombre_estudio, modalidad_dicom,
            snomed_concept_id, requiere_contraste, activo
        )
        SELECT
            'SCT-' || s.snomed_concept_id::TEXT,
            s.termino,
            pg_temp.infer_dicom_modality(s.termino),
            sc.id,
            (s.termino ~* 'contraste|gadolinio|bario|yodad|fluoresceína'),
            TRUE
        FROM _stg_img s
        JOIN snomed_concepts sc ON sc.id = s.snomed_concept_id
        WHERE s.active = '1'
          AND NOT EXISTS (
              SELECT 1 FROM imagenes_practicas ip
              WHERE ip.snomed_concept_id = sc.id
                 OR ip.codigo_estudio = 'SCT-' || s.snomed_concept_id::TEXT
          )
        ON CONFLICT (codigo_estudio) DO NOTHING
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_ins_new FROM ins;

    -- 3c. Clasificar cualquier otro registro previo que siga en 'OT'
    UPDATE imagenes_practicas
    SET
        modalidad_dicom    = pg_temp.infer_dicom_modality(nombre_estudio),
        requiere_contraste = requiere_contraste
                             OR (nombre_estudio ~* 'contraste|gadolinio|bario|yodad|fluoresceína')
    WHERE modalidad_dicom = 'OT';

    GET DIAGNOSTICS v_upd_all = ROW_COUNT;

    RAISE NOTICE 'Imágenes actualizadas por SNOMED: %', v_upd_snomed;
    RAISE NOTICE 'Imágenes nuevas insertadas      : %', v_ins_new;
    RAISE NOTICE 'Otros registros OT reclasificados: %', v_upd_all;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Verificación final
-- ─────────────────────────────────────────────────────────────────────────────
SELECT modalidad_dicom,
       COUNT(*) AS total,
       COUNT(*) FILTER (WHERE requiere_contraste) AS con_contraste
FROM imagenes_practicas
WHERE activo = TRUE
GROUP BY modalidad_dicom
ORDER BY total DESC;

SELECT COUNT(*) AS total_imagenes_activas FROM imagenes_practicas WHERE activo = TRUE;

ANALYZE imagenes_practicas;
DO $$ BEGIN RAISE NOTICE 'Carga y clasificación de Imágenes finalizada.'; END $$;
