-- =============================================================================
-- Origen Salud - Carga de Nombres para Pacientes LOINC (ConsumerName.csv)
-- =============================================================================
-- Este script actualiza la columna consumer_name en la tabla loinc existente
-- y crea el índice trigram correspondiente.
--
-- Uso en VPS:
--   sudo -u postgres psql -d origen_salud -f sql/cargar_loinc_consumer_names.sql
-- =============================================================================

\if :{?dir_loinc}
\else
  \set dir_loinc 'tools/loinc/sources'
\endif

\set q ''''
\set f_consumer :dir_loinc '/ConsumerName.csv'
\set cmd_consumer '\\copy temp_consumer_name (loinc_num, consumer_name) FROM ' :q :f_consumer :q ' WITH (FORMAT csv, HEADER true, QUOTE ''"'', ESCAPE ''"'', ENCODING ''UTF8'', NULL '''')'

\echo '-----------------------------------------------------------------------------'
\echo 'Cargando nombres para pacientes LOINC desde:' :f_consumer
\echo '-----------------------------------------------------------------------------'

DROP TABLE IF EXISTS temp_consumer_name;

CREATE TEMP TABLE temp_consumer_name (
    loinc_num VARCHAR(20) NOT NULL,
    consumer_name TEXT
);

:cmd_consumer

\echo 'Actualizando tabla loinc...'
UPDATE loinc l
   SET consumer_name = c.consumer_name
  FROM temp_consumer_name c
 WHERE l.loinc = c.loinc_num
   AND NULLIF(c.consumer_name, '') IS NOT NULL;

DROP TABLE IF EXISTS temp_consumer_name;

CREATE INDEX IF NOT EXISTS idx_loinc_consumer_trgm ON loinc USING gin (consumer_name gin_trgm_ops);

ANALYZE loinc;

SELECT count(*) AS total_conceptos,
       count(NULLIF(consumer_name, '')) AS con_consumer_name
  FROM loinc;
