-- =============================================================================
-- FASE 5 · Backfill LOINC desde la tabla loinc actual + vista de resolución
-- =============================================================================
-- Entorno de PRUEBAS. Aditivo: INSERT ... ON CONFLICT DO NOTHING.
-- NO modifica la tabla loinc, NO borra nada. Ejecutar DENTRO de transacción.
-- Idempotente: repetirlo no duplica filas.
-- Fuentes: modelo §4.4; plan Fase 5; D-08, D-19, D-27, D-33, D-39, D-40.
--
-- source_release='2.83' confirmado en tools/sources/loinc/Loinc.csv
-- (VersionLastChanged="2.83") y en importar_loinc.sql:2-5.
-- Solo se recupera la capa EN desde la BD. Las capas es-MX/es-AR ya fueron
-- sobrescritas por el importador actual: NO se inventan ni se derivan de `es`.
-- Nada se marca approved: provenance='unknown', review_status='unknown'.
-- ConsumerName.csv se acredita SOLO al campo consumer_name (prioridad 20).
-- definition_description solo se escribe desde Loinc.csv en inglés.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Capa EN / Loinc.csv (prioridad 10)
-- ---------------------------------------------------------------------------
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value,
     source_file, source_release, version_last_changed,
     provenance, review_status, source_reference)
SELECT loinc, 'en', 'component', component,
       'Loinc.csv', '2.83', version_last_changed,
       'unknown', 'unknown', NULL
FROM loinc
WHERE NULLIF(btrim(COALESCE(component, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value,
     source_file, source_release, version_last_changed,
     provenance, review_status, source_reference)
SELECT loinc, 'en', 'definition_description', definition_description,
       'Loinc.csv', '2.83', version_last_changed,
       'unknown', 'unknown', NULL
FROM loinc
WHERE NULLIF(btrim(COALESCE(definition_description, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value,
     source_file, source_release, version_last_changed,
     provenance, review_status, source_reference)
SELECT loinc, 'en', 'long_common_name', long_common_name,
       'Loinc.csv', '2.83', version_last_changed,
       'unknown', 'unknown', NULL
FROM loinc
WHERE NULLIF(btrim(COALESCE(long_common_name, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value,
     source_file, source_release, version_last_changed,
     provenance, review_status, source_reference)
SELECT loinc, 'en', 'shortname', shortname,
       'Loinc.csv', '2.83', version_last_changed,
       'unknown', 'unknown', NULL
FROM loinc
WHERE NULLIF(btrim(COALESCE(shortname, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value,
     source_file, source_release, version_last_changed,
     provenance, review_status, source_reference)
SELECT loinc, 'en', 'display_name', display_name,
       'Loinc.csv', '2.83', version_last_changed,
       'unknown', 'unknown', NULL
FROM loinc
WHERE NULLIF(btrim(COALESCE(display_name, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Capa EN / ConsumerName.csv (prioridad 20, SOLO consumer_name)
-- El importador actual sobrescribió loinc.consumer_name con este archivo.
-- ---------------------------------------------------------------------------
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value,
     source_file, source_release, version_last_changed,
     provenance, review_status, source_reference)
SELECT loinc, 'en', 'consumer_name', consumer_name,
       'ConsumerName.csv', '2.83', version_last_changed,
       'unknown', 'unknown', NULL
FROM loinc
WHERE NULLIF(btrim(COALESCE(consumer_name, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Vista de resolución determinista (D-33)
-- Desempate: mayor prioridad -> menor source_file -> versión más reciente.
-- Persistiendo el empate: es_conflicto = true y NO debe publicarse.
-- El id NO interviene nunca.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_loinc_resolved AS
WITH ranked AS (
    SELECT l.*,
           rank() OVER (
               PARTITION BY loinc_code, language_code, field_name, source_release
               ORDER BY source_priority DESC, source_file ASC,
                        version_last_changed DESC NULLS LAST) AS rnk,
           count(*) OVER (
               PARTITION BY loinc_code, language_code, field_name, source_release,
                            source_priority, source_file, version_last_changed) AS empatados
    FROM loinc_localized_text l
)
SELECT loinc_code,
       language_code,
       field_name,
       source_release,
       value,
       source_file,
       source_priority,
       version_last_changed,
       loinc_source_language(language_code, source_file) AS source_language,
       language_evidence,
       provenance,
       review_status,
       (empatados > 1) AS es_conflicto
FROM ranked
WHERE rnk = 1;

COMMENT ON VIEW v_loinc_resolved IS
    'Una fila efectiva por (código, idioma, campo, release). Prioridad central D-33; conflictos marcados, nunca publicados.';

COMMIT;

-- ---------------------------------------------------------------------------
-- Verificación de cierre (leer los resultados)
-- ---------------------------------------------------------------------------
SELECT language_code, source_file, count(*) AS filas
FROM loinc_localized_text
GROUP BY language_code, source_file
ORDER BY language_code, source_file;

SELECT count(*) AS codigos_huerfanos
FROM loinc_localized_text l
LEFT JOIN loinc ON loinc.loinc = l.loinc_code
WHERE loinc.loinc IS NULL;

SELECT count(*) AS sin_evidencia_acreditada
FROM loinc_localized_text
WHERE language_evidence = 'undetermined' OR source_priority = 0;

SELECT count(*) AS campos_en_no_loinc
FROM loinc_localized_text
WHERE language_code = 'en'
  AND field_name = 'definition_description'
  AND source_file <> 'Loinc.csv';

SELECT count(*) AS conflictos_sin_resolver
FROM v_loinc_resolved
WHERE es_conflicto;

SELECT count(*) AS aprobados_sin_evidencia
FROM loinc_localized_text
WHERE review_status = 'approved';

-- Fin de Fase 5 · backfill LOINC.
-- Pendiente: reimportar esMX28LinguisticVariant.csv y esAR7LinguisticVariant.csv
-- con un importador actualizado (cambio de código, no reconstruible desde la BD).
