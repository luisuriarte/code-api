-- =============================================================================
-- FASE 13 · Verificación final de nulabilidad (D-36) y estado del corte
-- =============================================================================
-- SOLO LECTURA: todas las sentencias son SELECT. Sin DDL, DML, DROP,
-- TRUNCATE, DELETE ni meta-comandos de psql. Válido en psql y DBeaver-CE.
--
-- Fase 13 NO introduce NOT NULL nuevos. Este reporte solo comprueba que el
-- estado real coincide con D-36 y que la auditoría/cantidades siguen intactas.
-- No activa el corte, no pide backup y no cambia ningún estado.
-- =============================================================================

SELECT '=== 1. Nulabilidad D-36 (divergencias_totales DEBE SER 0) ===' AS seccion;

WITH esperado (schema_name, table_name, column_name, is_nullable_esperado) AS (
    VALUES
    -- Semántica conocida: NOT NULL con DEFAULT desde Fases 2/3.
    ('public', 'os_catalog_item_version', 'language_code', 'NO'),
    ('public', 'os_catalog_item_version', 'provenance', 'NO'),
    ('public', 'os_catalog_item_version', 'review_status', 'NO'),
    ('public', 'os_catalog_item_version', 'language_evidence', 'NO'),
    ('public', 'os_catalog_item_version', 'content_hash', 'NO'),
    ('public', 'os_catalog_item_version', 'updated_at', 'NO'),
    ('public', 'os_catalog_term', 'language_code', 'NO'),
    ('public', 'os_catalog_term', 'provenance', 'NO'),
    ('public', 'os_catalog_term', 'review_status', 'NO'),
    ('public', 'os_catalog_term', 'language_evidence', 'NO'),
    ('public', 'os_catalog_term', 'content_hash', 'NO'),
    ('public', 'os_catalog_term', 'updated_at', 'NO'),
    ('public', 'os_localized_text', 'entity_type', 'NO'),
    ('public', 'os_localized_text', 'entity_id', 'NO'),
    ('public', 'os_localized_text', 'field_name', 'NO'),
    ('public', 'os_localized_text', 'language_code', 'NO'),
    ('public', 'os_localized_text', 'value', 'NO'),
    ('public', 'os_localized_text', 'provenance', 'NO'),
    ('public', 'os_localized_text', 'review_status', 'NO'),
    ('public', 'os_localized_text', 'language_evidence', 'NO'),
    ('public', 'os_localized_text', 'content_hash', 'NO'),
    ('public', 'os_localized_text', 'updated_at', 'NO'),
    ('public', 'os_field_review', 'target_table', 'NO'),
    ('public', 'os_field_review', 'target_id', 'NO'),
    ('public', 'os_field_review', 'field_name', 'NO'),
    ('public', 'os_field_review', 'language_code', 'NO'),
    ('public', 'os_field_review', 'provenance', 'NO'),
    ('public', 'os_field_review', 'review_status', 'NO'),
    ('public', 'os_field_review', 'language_evidence', 'NO'),
    ('public', 'os_field_review', 'content_hash', 'NO'),
    ('public', 'os_field_review', 'updated_at', 'NO'),
    ('public', 'os_translation_review', 'target_table', 'NO'),
    ('public', 'os_translation_review', 'target_id', 'NO'),
    ('public', 'os_translation_review', 'field_name', 'NO'),
    ('public', 'os_translation_review', 'language_code', 'NO'),
    ('public', 'os_translation_review', 'event_type', 'NO'),
    ('public', 'os_translation_review', 'action', 'NO'),
    ('public', 'os_translation_review', 'actor_type', 'NO'),
    ('public', 'os_translation_review', 'session_user', 'NO'),
    ('public', 'os_translation_review', 'occurred_at', 'NO'),
    ('public', 'snomed_descriptions', 'provenance', 'NO'),
    ('public', 'snomed_descriptions', 'language_evidence', 'NO'),
    ('public', 'snomed_descriptions', 'content_hash', 'NO'),
    ('public', 'cie10_descriptions', 'provenance', 'NO'),
    ('public', 'cie10_descriptions', 'content_hash', 'NO'),
    ('public', 'os_concept_mapping', 'external_display', 'NO'),
    ('public', 'os_concept_mapping', 'mapping_type', 'NO'),
    ('public', 'os_concept_mapping', 'relationship_role', 'NO'),
    ('public', 'os_concept_mapping', 'review_status', 'NO'),
    ('public', 'os_concept_mapping', 'provenance', 'NO'),
    ('public', 'os_concept_mapping', 'language_evidence', 'NO'),
    ('public', 'os_concept_mapping', 'content_hash', 'NO'),
    ('public', 'os_concept_mapping', 'updated_at', 'NO'),
    -- Sin evidencia: permanece nullable.
    ('public', 'os_catalog_item_version', 'source_language_code', 'YES'),
    ('public', 'os_catalog_item_version', 'source_reference', 'YES'),
    ('public', 'os_catalog_item_version', 'reviewed_by', 'YES'),
    ('public', 'os_catalog_item_version', 'reviewed_at', 'YES'),
    ('public', 'os_catalog_item_version', 'valid_from', 'YES'),
    ('public', 'os_catalog_item_version', 'valid_to', 'YES'),
    ('public', 'os_catalog_term', 'source_language_code', 'YES'),
    ('public', 'os_catalog_term', 'source_reference', 'YES'),
    ('public', 'os_catalog_term', 'reviewed_by', 'YES'),
    ('public', 'os_catalog_term', 'reviewed_at', 'YES'),
    ('public', 'os_catalog_term', 'valid_from', 'YES'),
    ('public', 'os_catalog_term', 'valid_to', 'YES'),
    ('public', 'os_localized_text', 'source_language_code', 'YES'),
    ('public', 'os_localized_text', 'source_reference', 'YES'),
    ('public', 'os_localized_text', 'translator', 'YES'),
    ('public', 'os_localized_text', 'reviewed_by', 'YES'),
    ('public', 'os_localized_text', 'reviewed_at', 'YES'),
    ('public', 'os_localized_text', 'scope_release_id', 'YES'),
    ('public', 'os_localized_text', 'valid_from', 'YES'),
    ('public', 'os_localized_text', 'valid_to', 'YES'),
    ('public', 'os_field_review', 'scope_release_id', 'YES'),
    ('public', 'os_field_review', 'source_language_code', 'YES'),
    ('public', 'os_field_review', 'source_reference', 'YES'),
    ('public', 'os_field_review', 'reviewed_by', 'YES'),
    ('public', 'os_field_review', 'reviewed_at', 'YES'),
    ('public', 'os_translation_review', 'previous_value', 'YES'),
    ('public', 'os_translation_review', 'new_value', 'YES'),
    ('public', 'os_translation_review', 'source_language_code', 'YES'),
    ('public', 'os_translation_review', 'provenance', 'YES'),
    ('public', 'os_translation_review', 'review_status', 'YES'),
    ('public', 'os_translation_review', 'application_user_id', 'YES'),
    ('public', 'os_translation_review', 'importer_run_id', 'YES'),
    ('public', 'os_translation_review', 'notes', 'YES'),
    ('public', 'snomed_descriptions', 'rf2_language_tag', 'YES'),
    ('public', 'snomed_descriptions', 'source_reference', 'YES'),
    ('public', 'snomed_descriptions', 'dialect_determined', 'YES'),
    ('public', 'cie10_descriptions', 'source_reference', 'YES'),
    ('public', 'os_concept_mapping', 'source_language_code', 'YES'),
    ('public', 'os_concept_mapping', 'source_reference', 'YES'),
    ('public', 'os_concept_mapping', 'reviewed_by', 'YES'),
    ('public', 'os_concept_mapping', 'reviewed_at', 'YES'),
    ('public', 'os_concept_mapping', 'valid_from', 'YES'),
    ('public', 'os_concept_mapping', 'valid_to', 'YES'),
    ('public', 'os_concept_mapping', 'source_language_code_display', 'YES')
),
verificado AS (
    SELECT e.table_name,
           e.column_name,
           e.is_nullable_esperado,
           c.is_nullable AS is_nullable_real,
           CASE
               WHEN c.column_name IS NULL THEN 'FALTA COLUMNA'
               WHEN c.is_nullable = e.is_nullable_esperado THEN 'OK'
               ELSE 'DIVERGE'
           END AS estado
      FROM esperado e
      LEFT JOIN information_schema.columns c
        ON c.table_schema = e.schema_name
       AND c.table_name = e.table_name
       AND c.column_name = e.column_name
)
SELECT table_name, column_name, is_nullable_esperado, is_nullable_real, estado,
       count(*) FILTER (WHERE estado <> 'OK') OVER () AS divergencias_totales
  FROM verificado
 ORDER BY estado DESC, table_name, column_name;

SELECT '=== 2. Etiqueta undet no es un idioma seleccionable ===' AS seccion;

SELECT count(*) AS undet_en_os_language FROM os_language WHERE code = 'undet'; -- DEBE SER 0

SELECT language_code, review_status, count(*) AS filas
  FROM os_field_review
 WHERE target_table = 'os_concept_mapping'
 GROUP BY language_code, review_status
 ORDER BY language_code, review_status;

SELECT '=== 3. Auditoría y conteos bases (informativo) ===' AS seccion;

SELECT event_type, count(*) AS eventos
  FROM os_translation_review
 GROUP BY event_type
 ORDER BY event_type;

SELECT 'os_catalog_item_version' AS tabla, count(*) AS filas
  FROM os_catalog_item_version
UNION ALL SELECT 'os_concept_mapping', count(*) FROM os_concept_mapping
UNION ALL SELECT 'os_field_review', count(*) FROM os_field_review
UNION ALL SELECT 'os_translation_review', count(*) FROM os_translation_review
UNION ALL SELECT 'loinc_localized_text', count(*) FROM loinc_localized_text
UNION ALL SELECT 'os_localized_text', count(*) FROM os_localized_text
ORDER BY tabla;

SELECT '=== 4. Estado del corte ===' AS seccion;
SELECT 'Fase 13 prepara la compuerta OS_IMPORT_MODE=dual. '
       'El cambio a new_only no se activa desde SQL y no se ejecuta sin decisión operativa explícita.' AS detalle;

-- Fin de Fase 13 · verificación final.
