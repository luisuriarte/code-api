-- =============================================================================
-- FASE 7 · SNOMED CT y CIE-10: conservar semántica RF2 (D-05)
-- =============================================================================
-- Entorno de PRUEBAS. Aditivo: solo UPDATE sobre columnas nuevas de Fase 3.
-- NO modifica tools/sql/snomed/03_postcarga.sql ni design.sql.
-- NO contiene DROP, TRUNCATE ni DELETE. Ejecutar dentro de transacción.
-- Fuentes: modelo §4.3; plan Fase 7; D-05, D-27, D-31, D-36.
--
-- rf2_language_tag se toma del valor REAL de sct2.description.language_code
-- ('es' | 'en'). NO se deriva dialecto: sin tag dialectal, dialect_determined=false
-- y language_evidence='inherited_from_column'. Nunca se escribe 'es-AR' desde 'es'.
-- Si sct2.description no está cargada, el script lo reporta y no inventa valores.
-- CIE-10: no tiene effective_time; solo se documenta la procedencia, ya cargada
-- como 'unknown' en Fase 3. No se agrega ni se calcula nada.
-- =============================================================================

BEGIN;

DO $$
DECLARE
    v_actualizadas INT;
BEGIN
    IF to_regclass('sct2.description') IS NULL THEN
        RAISE NOTICE
            'Fase 7: sct2.description no existe en esta base; no se inventa rf2_language_tag.';
        RETURN;
    END IF;

    UPDATE snomed_descriptions d
       SET rf2_language_tag  = s.language_code,
           dialect_determined = FALSE,
           language_evidence  = 'inherited_from_column'
      FROM sct2.description s
     WHERE s.id = d.id
       AND d.rf2_language_tag IS NULL;

    GET DIAGNOSTICS v_actualizadas = ROW_COUNT;
    RAISE NOTICE 'Fase 7: descripciones SNOMED con tag RF2 real asignado: %', v_actualizadas;
END $$;

COMMENT ON COLUMN snomed_descriptions.rf2_language_tag IS
    'Etiqueta REAL de sct2.description.language_code (es/en). Nunca estimada desde split_part ni inferida a es-AR (D-05).';
COMMENT ON COLUMN cie10_descriptions.provenance IS
    'Procedencia documentada. CIE-10 no tiene effective_time: no se inventa (D-05).';

COMMIT;

-- Verificación de cierre
SELECT rf2_language_tag, count(*) AS filas
FROM snomed_descriptions
GROUP BY rf2_language_tag
ORDER BY rf2_language_tag;

SELECT count(*) AS dialectos_inferidos_a_es_ar
FROM snomed_descriptions
WHERE language_code = 'es-AR' OR dialect_determined IS TRUE;

SELECT count(*) AS descripciones_sin_tag
FROM snomed_descriptions
WHERE rf2_language_tag IS NULL;

SELECT count(*) AS cie10_con_effective_time_inventado
FROM cie10_descriptions
WHERE EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'cie10_descriptions' AND column_name = 'effective_time');

-- Fin de Fase 7 · SNOMED / CIE-10.
