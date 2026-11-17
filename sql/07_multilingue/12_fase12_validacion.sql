-- =============================================================================
-- FASE 12 · Validación y reconciliación (reporte de solo lectura)
-- =============================================================================
-- Entorno de PRUEBAS. NO contiene DDL, DML, DROP, TRUNCATE ni DELETE.
-- Ejecutar con psql o DBeaver; todas las sentencias son SELECT.
-- Fuentes: plan Fase 12/13; D-10, D-14, D-19, D-23, D-24, D-29, D-33,
--          D-34, D-35, D-36, D-41.
--
-- Este reporte dice el estado REAL de la base. Un número distinto de cero en
-- las consultas marcadas como "DEBE SER 0" es un hallazgo a revisar, no algo
-- que este script corrija. La aprobación editorial (D-19) y las pruebas §7
-- siguen siendo artefactos humanos / de aplicación.
-- =============================================================================

\echo '=== 1. Catálogo de idiomas ==='
SELECT code, display_name, is_active, is_source_only
FROM os_language ORDER BY code;

SELECT count(*) AS activos FROM os_language WHERE is_active;
SELECT count(*) AS source_only FROM os_language WHERE is_source_only;
SELECT count(*) AS activos_y_source_only
FROM os_language WHERE is_active AND is_source_only;              -- DEBE SER 0 (D-39)
SELECT alias, language_code FROM os_language_alias ORDER BY alias;

\echo '=== 2. Integridad polimórfica (DEBE SER 0) ==='
SELECT count(*) AS traducciones_huerfanas
FROM os_localized_text l
WHERE NOT EXISTS (
    SELECT 1 FROM os_catalog t            WHERE l.entity_type = 'catalog'            AND t.id = l.entity_id
    UNION ALL SELECT 1 FROM os_catalog_category WHERE l.entity_type = 'catalog_category' AND id = l.entity_id
    UNION ALL SELECT 1 FROM os_catalog_release  WHERE l.entity_type = 'catalog_release'  AND id = l.entity_id
    UNION ALL SELECT 1 FROM os_fee_schedule     WHERE l.entity_type = 'fee_schedule'     AND id = l.entity_id
    UNION ALL SELECT 1 FROM os_pricing_unit     WHERE l.entity_type = 'pricing_unit'     AND id = l.entity_id
    UNION ALL SELECT 1 FROM os_terminology_system WHERE l.entity_type = 'terminology_system' AND id = l.entity_id
    UNION ALL SELECT 1 FROM os_concept_mapping  WHERE l.entity_type = 'concept_mapping'  AND id = l.entity_id
    UNION ALL SELECT 1 FROM nomencladores_argentina WHERE l.entity_type = 'nomenclador'  AND id = l.entity_id
    UNION ALL SELECT 1 FROM vademecum_comercial WHERE l.entity_type = 'vademecum'        AND id = l.entity_id
    UNION ALL SELECT 1 FROM os_substance        WHERE l.entity_type = 'substance'        AND id = l.entity_id
    UNION ALL SELECT 1 FROM os_medicinal_product WHERE l.entity_type = 'medicinal_product' AND id = l.entity_id
    UNION ALL SELECT 1 FROM os_product_package  WHERE l.entity_type = 'product_package'  AND id = l.entity_id);

\echo '=== 3. Pertenencia de releases (DEBE SER 0) ==='
SELECT count(*) AS releases_ajenos
FROM os_localized_text l
JOIN os_catalog_release r ON r.id = l.scope_release_id
WHERE l.entity_type = 'catalog' AND r.catalog_id <> l.entity_id
   OR l.entity_type = 'catalog_category'
      AND r.catalog_id <> (SELECT catalog_id FROM os_catalog_category WHERE id = l.entity_id)
   OR l.entity_type = 'catalog_release'
      AND r.catalog_id <> (SELECT catalog_id FROM os_catalog_release WHERE id = l.entity_id)
   OR l.entity_type = 'fee_schedule'
      AND r.catalog_id <> (SELECT catalog_id FROM os_fee_schedule WHERE id = l.entity_id)
   OR l.entity_type = 'concept_mapping'
      AND r.catalog_id <> (SELECT i.catalog_id FROM os_concept_mapping m
                            JOIN os_catalog_item i ON i.id = m.item_id WHERE m.id = l.entity_id);

\echo '=== 4. Índices inválidos (DEBE SER 0) ==='
SELECT c.relname, i.indisvalid, i.indisready
FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
WHERE c.relname LIKE 'uq_%' AND (NOT i.indisvalid OR NOT i.indisready);

SELECT c.relname FROM pg_class c
WHERE c.relname IN ('uq_ocl_default','uq_ocl_fallback','uq_ocl_bridge',
                    'uq_olt_global','uq_olt_scoped','idx_olt_identity','idx_olt_value_trgm',
                    'uq_fr_global','uq_fr_scoped','uq_llt_source','idx_llt_identity',
                    'idx_llt_resolution','idx_llt_value_trgm','uq_oct_identity')
ORDER BY c.relname;

\echo '=== 5. Nullabilidad D-36 ==='
SELECT table_name, column_name, is_nullable
FROM information_schema.columns
WHERE table_schema = current_schema()
  AND ((table_name IN ('os_localized_text','os_field_review','os_translation_review',
                        'os_catalog_item_version','os_catalog_term','snomed_descriptions',
                        'cie10_descriptions','os_concept_mapping','loinc_localized_text')
        AND column_name IN ('provenance','review_status','language_evidence','content_hash',
                            'updated_at','actor_type','occurred_at',
                            'source_language_code','source_reference','reviewed_by',
                            'reviewed_at','valid_from','valid_to','scope_release_id',
                            'dialect_determined')))
ORDER BY table_name, column_name;

\echo '=== 6. Hashes centinela (DEBE SER 0) ==='
SELECT 'os_catalog_item_version' AS tabla, count(*) FROM os_catalog_item_version WHERE content_hash = ''
UNION ALL SELECT 'os_catalog_term',           count(*) FROM os_catalog_term WHERE content_hash = ''
UNION ALL SELECT 'snomed_descriptions',       count(*) FROM snomed_descriptions WHERE content_hash = ''
UNION ALL SELECT 'cie10_descriptions',        count(*) FROM cie10_descriptions WHERE content_hash = ''
UNION ALL SELECT 'os_concept_mapping',        count(*) FROM os_concept_mapping WHERE content_hash = ''
UNION ALL SELECT 'loinc_localized_text',      count(*) FROM loinc_localized_text WHERE content_hash = '';

\echo '=== 7. Auditoría: 8 tablas cubiertas ==='
SELECT event_object_table, count(*) AS triggers_auditoria
FROM information_schema.triggers
WHERE trigger_schema = current_schema()
  AND action_timing = 'AFTER'
  AND event_object_table IN ('os_catalog_item_version','os_catalog_term','os_localized_text',
                             'os_field_review','snomed_descriptions','cie10_descriptions',
                             'os_concept_mapping','loinc_localized_text')
GROUP BY event_object_table ORDER BY event_object_table;

SELECT actor_type, actor_identified, count(*) AS eventos
FROM os_translation_review GROUP BY actor_type, actor_identified ORDER BY actor_type;

SELECT count(*) AS eventos_sin_transaccion
FROM os_translation_review WHERE transaction_id IS NULL;          -- DEBE SER 0

\echo '=== 8. LOINC: prioridad centralizada (DEBE SER 0) ==='
SELECT count(*) AS prioridades_divergentes
FROM loinc_localized_text
WHERE source_priority IS DISTINCT FROM
      loinc_source_priority(language_code, source_file, field_name);

SELECT language_code, source_file, count(*) AS filas,
       min(source_priority) AS prioridad,
       count(*) FILTER (WHERE language_evidence = 'undetermined') AS sin_evidencia
FROM loinc_localized_text GROUP BY language_code, source_file ORDER BY 1,2;

SELECT count(*) AS conflictos
FROM v_loinc_resolved WHERE es_conflicto;

SELECT count(*) AS aprobados_sin_evidencia
FROM loinc_localized_text WHERE review_status = 'approved';       -- DEBE SER 0

\echo '=== 9. Idiomas inferidos / dialectos (DEBE SER 0) ==='
SELECT count(*) AS source_language_inferido
FROM os_catalog_item_version WHERE source_language_code IS NOT NULL
UNION ALL SELECT count(*) FROM os_catalog_term WHERE source_language_code IS NOT NULL;
SELECT count(*) AS es_ar_inferido FROM snomed_descriptions
WHERE language_code = 'es-AR' OR dialect_determined IS TRUE;

\echo '=== 10. Aprobación editorial pendiente (D-19) ==='
SELECT review_status, count(*) AS filas
FROM os_concept_mapping GROUP BY review_status ORDER BY review_status;

SELECT count(*) AS aprobados_sin_revision_de_campo
FROM os_concept_mapping m
WHERE m.review_status = 'approved'
  AND NOT EXISTS (SELECT 1 FROM os_field_review f
                   WHERE f.target_table = 'os_concept_mapping' AND f.target_id = m.id);

\echo '=== 11. Conteos base (informativo) ==='
SELECT 'os_catalog_item_version' AS tabla, count(*) FROM os_catalog_item_version
UNION ALL SELECT 'os_catalog_term',           count(*) FROM os_catalog_term
UNION ALL SELECT 'snomed_descriptions',       count(*) FROM snomed_descriptions
UNION ALL SELECT 'cie10_descriptions',        count(*) FROM cie10_descriptions
UNION ALL SELECT 'os_concept_mapping',        count(*) FROM os_concept_mapping
UNION ALL SELECT 'loinc',                     count(*) FROM loinc
UNION ALL SELECT 'loinc_localized_text',      count(*) FROM loinc_localized_text
UNION ALL SELECT 'os_localized_text',         count(*) FROM os_localized_text
UNION ALL SELECT 'os_field_review',           count(*) FROM os_field_review
UNION ALL SELECT 'os_translation_review',     count(*) FROM os_translation_review;

-- Fin de Fase 12 · validación.
