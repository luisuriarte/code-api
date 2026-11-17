-- =============================================================================
-- FASE 4 · Backfill seguro (sin inventar procedencia, idioma ni aprobación)
-- =============================================================================
-- Entorno de PRUEBAS. Ejecutar DENTRO de transacción.
-- Aditivo: solo UPDATE sobre columnas nuevas; NO toca columnas originales.
-- NO contiene DROP, TRUNCATE ni DELETE. Idempotente (WHERE content_hash = '').
-- Fuentes: plan Fase 4; D-05, D-19, D-22, D-31, D-36, D-40.
--
-- Qué NO hace este script:
--   * NO marca nada como 'approved' ni 'official_source'.
--   * NO deriva 'es-AR' desde 'es' (D-05, D-22).
--   * NO deriva rf2_language_tag desde language_code: esa columna guarda la
--     etiqueta REAL del staging RF2; sin evidencia queda NULL (D-05).
--   * NO inventa source_language_code, source_reference ni reviewed_by.
--   * NO copia CDT a os_localized_text: sus claves VARCHAR no caben en
--     entity_id BIGINT y permanece en sus tablas nativas (D-22).
--   * NO crea todavía loinc_localized_text (Fase 5) ni deriva su idioma
--     con loinc_source_language (D-40).
--
-- Las filas nuevas (os_localized_text, os_field_review) no tienen backfill:
-- se poblaron vacías en Fase 2 y sus hashes los calculan sus triggers.
-- Si una tabla es muy grande, ejecutar este UPDATE en lotes acotados por id.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Sustituir el centinela '' por el md5 real calculado en los triggers de 05.
--    El trigger registra content_changed, pero NO approval_invalidated cuando
--    el valor anterior era '' (no era evidencia de contenido).
-- ---------------------------------------------------------------------------
UPDATE os_catalog_item_version SET content_hash = content_hash WHERE content_hash = '';
UPDATE os_catalog_term           SET content_hash = content_hash WHERE content_hash = '';
UPDATE snomed_descriptions       SET content_hash = content_hash WHERE content_hash = '';
UPDATE cie10_descriptions        SET content_hash = content_hash WHERE content_hash = '';
UPDATE os_concept_mapping        SET content_hash = content_hash WHERE content_hash = '';

-- ---------------------------------------------------------------------------
-- 2) Valores neutros explícitos (ya aplicados por DEFAULT en 04).
--    Solo se escriben donde estén NULL; nunca se sobrescribe evidencia.
--    'unknown' / 'undetermined' / NULL son NO publicables (D-19).
-- ---------------------------------------------------------------------------
UPDATE os_catalog_item_version
   SET provenance = 'unknown', review_status = 'unknown', language_evidence = 'undetermined'
 WHERE provenance IS NULL OR review_status IS NULL OR language_evidence IS NULL;

UPDATE os_catalog_term
   SET provenance = 'unknown', review_status = 'unknown', language_evidence = 'undetermined'
 WHERE provenance IS NULL OR review_status IS NULL OR language_evidence IS NULL;

UPDATE snomed_descriptions
   SET provenance = 'unknown', language_evidence = 'undetermined'
 WHERE provenance IS NULL OR language_evidence IS NULL;

UPDATE cie10_descriptions
   SET provenance = 'unknown'
 WHERE provenance IS NULL;

-- os_concept_mapping.review_status NO se toca: pertenece a la columna
-- preexistente con CHECK propio (draft|reviewed|approved|deprecated).
UPDATE os_concept_mapping
   SET provenance = 'unknown', language_evidence = 'undetermined'
 WHERE provenance IS NULL OR language_evidence IS NULL;

-- ---------------------------------------------------------------------------
-- 3) Verificación de cierre (leer los resultados)
-- ---------------------------------------------------------------------------
-- (a) Ningún hash queda en centinela.
SELECT 'os_catalog_item_version' AS tabla, count(*) AS hashes_pendientes
  FROM os_catalog_item_version WHERE content_hash = ''
UNION ALL
SELECT 'os_catalog_term',           count(*) FROM os_catalog_term WHERE content_hash = ''
UNION ALL
SELECT 'snomed_descriptions',       count(*) FROM snomed_descriptions WHERE content_hash = ''
UNION ALL
SELECT 'cie10_descriptions',        count(*) FROM cie10_descriptions WHERE content_hash = ''
UNION ALL
SELECT 'os_concept_mapping',        count(*) FROM os_concept_mapping WHERE content_hash = '';

-- (b) Ningún idioma inferido por este backfill.
SELECT 'os_catalog_item_version' AS tabla, count(*) AS source_language_inferido
  FROM os_catalog_item_version WHERE source_language_code IS NOT NULL
UNION ALL
SELECT 'os_catalog_term',    count(*) FROM os_catalog_term WHERE source_language_code IS NOT NULL
UNION ALL
SELECT 'os_concept_mapping', count(*) FROM os_concept_mapping WHERE source_language_code IS NOT NULL;

-- (c) Ningún dialecto inferido en SNOMED ni rf2_language_tag estimado.
SELECT count(*) AS snomed_dialecto_inferido
  FROM snomed_descriptions
 WHERE dialect_determined IS TRUE OR rf2_language_tag IS NOT NULL;

-- (d) Revisión editorial pendiente. Los 'approved' preexistentes de
--     os_concept_mapping vienen del DEFAULT de la columna original, NO de una
--     aprobación demostrable (D-19). No se degradan automáticamente: quedan
--     reportados aquí para la matriz de aprobación, que es un artefacto humano.
SELECT review_status, count(*) AS filas
  FROM os_concept_mapping
 GROUP BY review_status ORDER BY review_status;

COMMIT;

-- Fin de Fase 4 · backfill seguro.
-- Pendiente para avanzar: matriz de aprobación revisada (D-19) y decisiones
-- de Fase 5 (LOINC), Fases 8-10 (resolver/API/sitio) y NN 2025.
