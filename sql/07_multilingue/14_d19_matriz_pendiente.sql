-- =============================================================================
-- D-19 · Reporte para la matriz de aprobación editorial inicial
-- =============================================================================
-- FASE 12 / etapa 4.3. SOLO LECTURA: todas las sentencias son SELECT.
-- Sin DDL, DML, DROP, TRUNCATE, DELETE ni meta-comandos de psql.
-- Válido en psql y en DBeaver-CE.
-- Fuentes: modelo §2.3; decisión D-19; plan etapa 4.3; runbook compuerta 2.
--
-- La matriz de aprobación es un ARTEFACTO HUMANO: tabla, campo, idioma,
-- release, fuente, motivo, revisor y fecha (modelo §2.3). Este reporte NO
-- aprueba nada: entrega las filas pendientes con motivo/revisor/fecha en NULL
-- para que la autoridad editorial los complete y firme.
--
-- Estado real: las 419 filas de os_concept_mapping quedaron 'approved' por el
-- DEFAULT original del esquema, no por una revisión. No se degradaron: el
-- reporte las expone para que la matriz decida. Ninguna tiene os_field_review.
--
-- os_concept_mapping NO tiene columna language_code: se informa 'undet' como
-- etiqueta de ausencia (VARCHAR(10), mismo criterio del evento de auditoría).
-- =============================================================================

SELECT '=== 1. Alcance de la matriz: filas approved por tabla (informativo) ===' AS seccion;

SELECT 'os_catalog_item_version' AS tabla, count(*) AS aprobadas
FROM os_catalog_item_version WHERE review_status = 'approved'
UNION ALL SELECT 'os_catalog_term', count(*)
FROM os_catalog_term WHERE review_status = 'approved'
UNION ALL SELECT 'os_localized_text', count(*)
FROM os_localized_text WHERE review_status = 'approved'
UNION ALL SELECT 'os_field_review', count(*)
FROM os_field_review WHERE review_status = 'approved'
UNION ALL SELECT 'os_concept_mapping', count(*)
FROM os_concept_mapping WHERE review_status = 'approved'
UNION ALL SELECT 'loinc_localized_text', count(*)
FROM loinc_localized_text WHERE review_status = 'approved'
-- snomed_descriptions y cie10_descriptions NO tienen columna review_status:
-- conservan su estructura nativa (modelo §4.3) y su aprobación, si se da,
-- vive en os_field_review. No se inventa la columna en este reporte.
ORDER BY tabla;

SELECT '=== 2. Detalle a revisar: campos approved sin os_field_review ===' AS seccion;

SELECT 'os_concept_mapping'::VARCHAR(40) AS tabla,
       v.campo::VARCHAR(48) AS campo,
       'undet'::VARCHAR(10) AS idioma,        -- la tabla no tiene language_code
       NULL::VARCHAR(20) AS release,          -- la tabla no tiene release
       m.provenance::VARCHAR(24) AS fuente,
       m.source_reference AS referencia,
       v.valor AS valor_a_revisar,
       m.review_status::VARCHAR(20) AS estado_actual,
       m.id AS registro_id,
       NULL::TEXT AS motivo,
       NULL::VARCHAR(120) AS revisor,
       NULL::DATE AS fecha
FROM os_concept_mapping m
CROSS JOIN LATERAL (
    VALUES ('external_display', m.external_display),
           ('clinical_rationale', m.clinical_rationale)
) AS v(campo, valor)
WHERE m.review_status = 'approved'
  AND NULLIF(btrim(COALESCE(v.valor, '')), '') IS NOT NULL
  AND NOT EXISTS (
        SELECT 1 FROM os_field_review f
         WHERE f.target_table = 'os_concept_mapping'
           AND f.target_id = m.id)
ORDER BY m.id, v.campo;

SELECT '=== 3. Control: filas approved sin revisión de campo (DEBE SER 0 tras la matriz) ===' AS seccion;

SELECT count(*) AS aprobadas_sin_os_field_review
FROM os_concept_mapping m
WHERE m.review_status = 'approved'
  AND NOT EXISTS (
        SELECT 1 FROM os_field_review f
         WHERE f.target_table = 'os_concept_mapping' AND f.target_id = m.id);

-- Fin del reporte D-19 · la aprobación la decide la autoridad editorial.
