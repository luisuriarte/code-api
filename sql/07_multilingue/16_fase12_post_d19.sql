-- =============================================================================
-- FASE 12 · Validación y reconciliación posterior a la aprobación D-19
-- =============================================================================
-- SOLO LECTURA: todas las sentencias son SELECT. Sin DDL, DML, DROP,
-- TRUNCATE, DELETE ni meta-comandos de psql. Válido en psql y DBeaver-CE.
--
-- Se ejecuta DESPUÉS de 15_d19_aprobacion_editorial.sql. Comprueba que la
-- aprobación editorial quedó registrada por campo, que el hash sigue vigente
-- y que la API no tenga aprobaciones huérfanas. No corrige nada.
-- =============================================================================

SELECT '=== 1. Cobertura D-19 por campo (DEBE SER 0 en los controles) ===' AS seccion;

SELECT count(*) AS mapeos_aprobados
  FROM os_concept_mapping
 WHERE review_status = 'approved';

SELECT field_name, language_code, review_status, count(*) AS revisiones
  FROM os_field_review
 WHERE target_table = 'os_concept_mapping'
 GROUP BY field_name, language_code, review_status
 ORDER BY field_name, language_code, review_status;

SELECT count(*) AS aprobadas_sin_os_field_review
  FROM os_concept_mapping m
 WHERE m.review_status = 'approved'
   AND NOT EXISTS (
         SELECT 1
           FROM os_field_review f
          WHERE f.target_table = 'os_concept_mapping'
            AND f.target_id = m.id
   );                                                          -- DEBE SER 0

SELECT count(*) AS campos_no_vacios_sin_revision
  FROM os_concept_mapping m
  CROSS JOIN LATERAL (
      VALUES ('external_display', m.external_display),
             ('clinical_rationale', m.clinical_rationale)
  ) AS v(field_name, valor)
 WHERE m.review_status = 'approved'
   AND NULLIF(btrim(COALESCE(v.valor, '')), '') IS NOT NULL
   AND NOT EXISTS (
         SELECT 1
           FROM os_field_review f
          WHERE f.target_table = 'os_concept_mapping'
            AND f.target_id = m.id
            AND f.field_name = v.field_name
            AND f.language_code = 'undet'
            AND f.scope_release_id IS NULL
   );                                                          -- DEBE SER 0

SELECT '=== 2. Vigencia del hash de aprobación (DEBE SER 0) ===' AS seccion;

SELECT count(*) AS aprobaciones_con_hash_desactualizado
  FROM os_field_review f
  JOIN os_concept_mapping m ON m.id = f.target_id
 CROSS JOIN LATERAL (
      SELECT CASE f.field_name
                 WHEN 'external_display' THEN m.external_display
                 WHEN 'clinical_rationale' THEN m.clinical_rationale
             END AS valor
 ) AS v
 WHERE f.target_table = 'os_concept_mapping'
   AND f.language_code = 'undet'
   AND f.review_status = 'approved'
   AND f.content_hash IS DISTINCT FROM md5(
          COALESCE(v.valor, '') || E'\x1f' || 'undet' || E'\x1f'
          || COALESCE(m.source_reference, '')
       );                                                      -- DEBE SER 0

SELECT '=== 3. Eventos de aprobación editorial ===' AS seccion;

SELECT event_type, action, count(*) AS eventos
  FROM os_translation_review
 WHERE target_table = 'os_field_review'
   AND event_type = 'approval_granted'
   AND notes LIKE 'D-19%'
 GROUP BY event_type, action
 ORDER BY event_type, action;

SELECT '=== 4. Campos publicables por el dual-read condicionado ===' AS seccion;

SELECT v.field_name, count(*) AS campos_publicables
  FROM os_concept_mapping m
  CROSS JOIN LATERAL (
      VALUES ('external_display', m.external_display),
             ('clinical_rationale', m.clinical_rationale)
  ) AS v(field_name, valor)
  JOIN os_field_review f
    ON f.target_table = 'os_concept_mapping'
   AND f.target_id = m.id
   AND f.field_name = v.field_name
   AND f.language_code = 'undet'
   AND f.scope_release_id IS NULL
   AND f.review_status = 'approved'
   AND f.content_hash = md5(
          COALESCE(v.valor, '') || E'\x1f' || 'undet' || E'\x1f'
          || COALESCE(m.source_reference, '')
       )
 WHERE m.review_status = 'approved'
   AND NULLIF(btrim(COALESCE(v.valor, '')), '') IS NOT NULL
 GROUP BY v.field_name
 ORDER BY v.field_name;

SELECT '=== 5. Identidad de importador en la auditoría ===' AS seccion;

SELECT actor_type, count(*) AS eventos,
       count(*) FILTER (WHERE actor_identified) AS identificados,
       count(*) FILTER (WHERE importer_run_id IS NOT NULL) AS con_run_id
  FROM os_translation_review
 GROUP BY actor_type
 ORDER BY actor_type;

SELECT '=== 6. Conteos base (informativo; no deben bajar) ===' AS seccion;

SELECT 'os_catalog_item_version' AS tabla, count(*) AS filas
  FROM os_catalog_item_version
UNION ALL SELECT 'os_concept_mapping', count(*) FROM os_concept_mapping
UNION ALL SELECT 'os_field_review', count(*) FROM os_field_review
UNION ALL SELECT 'os_translation_review', count(*) FROM os_translation_review
UNION ALL SELECT 'loinc_localized_text', count(*) FROM loinc_localized_text
UNION ALL SELECT 'os_localized_text', count(*) FROM os_localized_text
ORDER BY tabla;

SELECT '=== 7. Nota ===' AS seccion;
SELECT 'La nulabilidad D-36 se verifica en 17_fase13_verificacion_final.sql; '
       'este reporte no activa el corte ni cambia estados.' AS detalle;

-- Fin de Fase 12 posterior a D-19.
