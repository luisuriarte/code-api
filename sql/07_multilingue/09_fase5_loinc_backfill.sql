-- =============================================================================
-- FASE 5 · Backfill LOINC desde los CSV + vista de resolución
-- =============================================================================
-- Aditivo: INSERT ... ON CONFLICT DO NOTHING. NO modifica la tabla loinc,
-- NO borra nada. Ejecutar DENTRO de transacción. Idempotente.
-- Fuentes: modelo §4.4; plan Fase 5; D-08, D-19, D-27, D-33, D-39, D-40.
--
-- source_release='2.83' confirmado en tools/sources/loinc/Loinc.csv
-- (VersionLastChanged="2.83") y en importar_loinc.sql:2-5.
--
-- CORRECCIÓN: la versión anterior recuperaba la capa EN desde `loinc`.
-- Eso era incorrecto: importar_loinc.sql sobreescribe 12 campos con es-MX y
-- después con es-AR, por lo que `loinc.component`, `loinc.long_common_name`,
-- etc. ya no contienen el texto inglés. La capa EN se lee aquí directamente
-- de Loinc.csv y ConsumerName.csv, que son las fuentes acreditadas (D-40).
-- Las capas es-MX/es-AR las carga 13_fase5b_variantes_es.sql desde sus CSV.
--
-- Nada se marca approved: provenance='unknown', review_status='unknown'.
-- ConsumerName.csv se acredita SOLO al campo consumer_name (prioridad 20).
-- definition_description solo se escribe desde Loinc.csv en inglés.
-- Requisito: el usuario postgres del servidor debe poder LEER los CSV.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Etapa 1 · staging de las fuentes inglesas
-- ---------------------------------------------------------------------------
-- La tabla temporal declara las 40 columnas del CSV en el mismo orden.
-- COPY FROM con lista de columnas NO admite campos extra en el archivo:
-- aunque sólo nos interesen 12, hay que staged las 40 y luego proyectar.
CREATE TEMP TABLE _loinc_en_base (
    loinc_num                     TEXT,
    component                     TEXT,
    property                      TEXT,
    time_aspct                    TEXT,
    system                        TEXT,
    scale_typ                     TEXT,
    method_typ                    TEXT,
    class                         TEXT,
    versionlastchanged            TEXT,
    chng_type                     TEXT,
    definitiondescription         TEXT,
    status                        TEXT,
    consumer_name                 TEXT,
    classtype                     TEXT,
    formula                       TEXT,
    exmpl_answers                 TEXT,
    survey_quest_text             TEXT,
    survey_quest_src              TEXT,
    unitsrequired                 TEXT,
    relatednames2                 TEXT,
    shortname                     TEXT,
    order_obs                     TEXT,
    hl7_field_subfield_id         TEXT,
    external_copyright_notice     TEXT,
    example_units                 TEXT,
    long_common_name              TEXT,
    example_ucum_units            TEXT,
    status_reason                 TEXT,
    status_text                   TEXT,
    change_reason_public          TEXT,
    common_test_rank              TEXT,
    common_order_rank             TEXT,
    hl7_attachment_structure      TEXT,
    external_copyright_link       TEXT,
    paneltype                     TEXT,
    askatorderentry               TEXT,
    associatedobservations        TEXT,
    versionfirstreleased          TEXT,
    validhl7attachmentrequest     TEXT,
    displayname                   TEXT
);

COPY _loinc_en_base (
    loinc_num, component, property, time_aspct, system, scale_typ, method_typ,
    class, versionlastchanged, chng_type, definitiondescription, status,
    consumer_name, classtype, formula, exmpl_answers, survey_quest_text,
    survey_quest_src, unitsrequired, relatednames2, shortname, order_obs,
    hl7_field_subfield_id, external_copyright_notice, example_units,
    long_common_name, example_ucum_units, status_reason, status_text,
    change_reason_public, common_test_rank, common_order_rank,
    hl7_attachment_structure, external_copyright_link, paneltype,
    askatorderentry, associatedobservations, versionfirstreleased,
    validhl7attachmentrequest, displayname)
FROM '/var/www/html/origen.ar/code-api/tools/sources/loinc/Loinc.csv'
WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"', ENCODING 'UTF8', NULL '');

CREATE TEMP TABLE _loinc_en_consumer (
    loincnumber   TEXT,
    consumername  TEXT
);

COPY _loinc_en_consumer (loincnumber, consumername)
FROM '/var/www/html/origen.ar/code-api/tools/sources/loinc/ConsumerName.csv'
WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"', ENCODING 'UTF8', NULL '');

SELECT 'control de códigos (ausentes DEBE SER 0)' AS progreso;
SELECT 'en/Loinc.csv' AS capa, count(*) AS filas_csv,
       count(l.loinc) AS codigos_validos,
       count(*) - count(l.loinc) AS codigos_ausentes_en_loinc
FROM _loinc_en_base s LEFT JOIN loinc l ON l.loinc = s.loinc_num
UNION ALL
SELECT 'en/ConsumerName.csv', count(*), count(l.loinc), count(*) - count(l.loinc)
FROM _loinc_en_consumer s LEFT JOIN loinc l ON l.loinc = s.loincnumber;

-- ---------------------------------------------------------------------------
-- Etapa 2 · capa EN / Loinc.csv (prioridad 10)
-- Un solo INSERT "despivotado": una fila por (código, campo) con texto no vacío.
-- ---------------------------------------------------------------------------
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value,
     source_file, source_release, version_last_changed,
     provenance, review_status, source_reference)
SELECT s.loinc_num, 'en', v.field_name, v.value,
       'Loinc.csv', '2.83', s.versionlastchanged,
       'unknown', 'unknown', NULL
FROM _loinc_en_base s
JOIN loinc l ON l.loinc = s.loinc_num
CROSS JOIN LATERAL (VALUES
    ('component', s.component),
    ('property', s.property),
    ('time_aspct', s.time_aspct),
    ('system_type', s.system),
    ('scale_type', s.scale_typ),
    ('method_type', s.method_typ),
    ('class_type', s.class),
    ('definition_description', s.definitiondescription),
    ('relatednames2', s.relatednames2),
    ('shortname', s.shortname),
    ('long_common_name', s.long_common_name),
    ('display_name', s.displayname)
) AS v(field_name, value)
WHERE NULLIF(btrim(COALESCE(v.value, '')), '') IS NOT NULL
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Etapa 3 · capa EN / ConsumerName.csv (prioridad 20, SOLO consumer_name)
-- ---------------------------------------------------------------------------
INSERT INTO loinc_localized_text
    (loinc_code, language_code, field_name, value,
     source_file, source_release, version_last_changed,
     provenance, review_status, source_reference)
SELECT s.loincnumber, 'en', 'consumer_name', s.consumername,
       'ConsumerName.csv', '2.83', NULL,
       'unknown', 'unknown', NULL
FROM _loinc_en_consumer s
JOIN loinc l ON l.loinc = s.loincnumber
WHERE NULLIF(btrim(COALESCE(s.consumername, '')), '') IS NOT NULL
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

-- Fin de Fase 5 · backfill LOINC EN desde CSV.
-- Las capas es-MX y es-AR las carga 13_fase5b_variantes_es.sql.
