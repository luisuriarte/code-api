-- =============================================================================
-- Origen Salud · Importación Maestra de LOINC 2.83 para PostgreSQL 18
-- sql/importar_loinc.sql
-- =============================================================================
-- Versión Oficial: LOINC 2.83 (112.405 conceptos · Agosto 2026)
-- Ubicación de las fuentes CSV en tools:
--   tools/loinc/sources/Loinc.csv
--   tools/loinc/sources/MapTo.csv
--   tools/loinc/sources/esMX28LinguisticVariant.csv
--   tools/loinc/sources/esAR7LinguisticVariant.csv
--
-- Orden de precedencia y traducción:
--  1º Se importa la base oficial en Inglés (Loinc.csv, 112.405 registros).
--  2º Se actualiza con la variante de México (esMX28LinguisticVariant.csv, 83.231 registros),
--     que cuenta con la cobertura de traducción más amplia en español.
--  3º Se actualiza con la variante de Argentina (esAR7LinguisticVariant.csv, 38.293 registros),
--     sobrescribiendo con la terminología local argentina y preservando las
--     traducciones de México/Inglés en aquellos campos que Argentina no haya definido.
--
-- EJECUCIÓN RECOMENDADA EN EL VPS (desde el directorio raíz del proyecto):
--   cd /var/www/html/origen.ar/code-api
--   chmod -R a+rX tools/loinc
--   sudo -u postgres psql -d origen_salud -f sql/importar_loinc.sql
--
-- O pasando una ruta personalizada si los archivos están en otra carpeta:
--   sudo -u postgres psql -d origen_salud -v dir_loinc="/otra/ruta/sources" -f sql/importar_loinc.sql
-- =============================================================================

SET client_encoding = 'UTF8';
SET statement_timeout = 0;

-- Habilitar extensión para búsquedas trigram en texto clínico
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================================================
-- 0. RESOLUCIÓN DE RUTA DE FUENTES
-- =============================================================================
\if :{?dir_loinc}
\else
  \set dir_loinc 'tools/loinc/sources'
\endif

\set q ''''
\set f_loinc :dir_loinc '/Loinc.csv'
\set f_map :dir_loinc '/MapTo.csv'
\set f_mx :dir_loinc '/esMX28LinguisticVariant.csv'
\set f_ar :dir_loinc '/esAR7LinguisticVariant.csv'

-- Meta-comandos dinámicos \copy (con soporte para ConsumerName de LOINC 2.83)
\set cmd_loinc '\\copy loinc (loinc, component, property, time_aspct, system_type, scale_type, method_type, class_type, version_last_changed, chng_type, definition_description, status, consumer_name, classtype, formula, exmpl_answers, survey_quest_text, survey_quest_src, unitsrequired, relatednames2, shortname, order_obs, hl7_field_subfield_id, external_copyright_notice, example_units, long_common_name, example_ucum_units, status_reason, status_text, change_reason_public, common_test_rank, common_order_rank, hl7_attachment_structure, external_copyright_link, panel_type, ask_at_order_entry, associated_observations, version_first_released, valid_hl7_attachment_request, display_name) FROM ' :q :f_loinc :q ' WITH (FORMAT csv, HEADER true, QUOTE ''"'', ESCAPE ''"'', ENCODING ''UTF8'', NULL '''', FORCE_NULL (classtype, common_test_rank, common_order_rank))'

\set cmd_map '\\copy loinc_map (loinc, map, comment) FROM ' :q :f_map :q ' WITH (FORMAT csv, HEADER true, QUOTE ''"'', ESCAPE ''"'', ENCODING ''UTF8'', NULL '''')'

\set cmd_mx '\\copy temp_loinc_mx (loinc_num, component, property, time_aspct, system, scale_typ, method_typ, class, shortname, long_common_name, relatednames2, linguistic_variant_display_name, consumer_name) FROM ' :q :f_mx :q ' WITH (FORMAT csv, HEADER true, QUOTE ''"'', ESCAPE ''"'', ENCODING ''UTF8'', NULL '''')'

\set cmd_ar '\\copy temp_loinc_ar (loinc_num, component, property, time_aspct, system, scale_typ, method_typ, class, shortname, long_common_name, relatednames2, linguistic_variant_display_name, consumer_name) FROM ' :q :f_ar :q ' WITH (FORMAT csv, HEADER true, QUOTE ''"'', ESCAPE ''"'', ENCODING ''UTF8'', NULL '''')'

\echo '-----------------------------------------------------------------------------'
\echo 'Iniciando carga de LOINC 2.83 desde:' :dir_loinc
\echo '-----------------------------------------------------------------------------'

-- =============================================================================
-- 1. CREACIÓN DE LA TABLA PRINCIPAL: loinc
-- =============================================================================
DROP TABLE IF EXISTS loinc CASCADE;

CREATE TABLE loinc (
    id BIGSERIAL PRIMARY KEY,
    loinc VARCHAR(20) NOT NULL UNIQUE,
    component TEXT,
    property VARCHAR(255),
    time_aspct VARCHAR(255),
    system_type VARCHAR(255),
    scale_type VARCHAR(255),
    method_type VARCHAR(255),
    class_type VARCHAR(255),
    version_last_changed VARCHAR(50),
    chng_type VARCHAR(50),
    definition_description TEXT,
    status VARCHAR(50),
    consumer_name TEXT,
    classtype INTEGER,
    formula TEXT,
    exmpl_answers TEXT,
    survey_quest_text TEXT,
    survey_quest_src VARCHAR(100),
    unitsrequired VARCHAR(50),
    relatednames2 TEXT,
    shortname TEXT,
    order_obs VARCHAR(50),
    hl7_field_subfield_id VARCHAR(50),
    external_copyright_notice TEXT,
    example_units VARCHAR(255),
    long_common_name TEXT,
    example_ucum_units VARCHAR(255),
    status_reason VARCHAR(50),
    status_text TEXT,
    change_reason_public TEXT,
    common_test_rank INTEGER,
    common_order_rank INTEGER,
    hl7_attachment_structure VARCHAR(50),
    external_copyright_link TEXT,
    panel_type VARCHAR(50),
    ask_at_order_entry TEXT,
    associated_observations TEXT,
    version_first_released VARCHAR(50),
    valid_hl7_attachment_request VARCHAR(50),
    display_name TEXT
);

-- =============================================================================
-- 2. CREACIÓN DE LA TABLA DE MAPEOS: loinc_map
-- =============================================================================
DROP TABLE IF EXISTS loinc_map CASCADE;

CREATE TABLE loinc_map (
    loinc VARCHAR(20) NOT NULL,
    map VARCHAR(20) NOT NULL,
    comment TEXT,
    PRIMARY KEY (loinc, map)
);

-- =============================================================================
-- 3. CARGA DE DATOS BASE EN INGLÉS (Loinc.csv - 112.405 filas)
-- =============================================================================
\echo 'Cargando base en inglés (Loinc.csv)...'
:cmd_loinc

-- =============================================================================
-- 4. CARGA DE TABLA DE MAPEOS (MapTo.csv - 4.667 filas)
-- =============================================================================
\echo 'Cargando mapeos (MapTo.csv)...'
:cmd_map

-- =============================================================================
-- 5. CAPA DE TRADUCCIÓN MÉXICO: esMX28LinguisticVariant.csv (83.231 filas)
-- =============================================================================
\echo 'Cargando variante lingüística México (esMX28LinguisticVariant.csv)...'
DROP TABLE IF EXISTS temp_loinc_mx;

CREATE TEMP TABLE temp_loinc_mx (
    loinc_num VARCHAR(20) NOT NULL,
    component TEXT,
    property VARCHAR(255),
    time_aspct VARCHAR(255),
    system VARCHAR(255),
    scale_typ VARCHAR(255),
    method_typ VARCHAR(255),
    class VARCHAR(255),
    shortname TEXT,
    long_common_name TEXT,
    relatednames2 TEXT,
    linguistic_variant_display_name TEXT,
    consumer_name TEXT
);

:cmd_mx

INSERT INTO loinc (
    loinc, component, property, time_aspct, system_type, scale_type,
    method_type, class_type, shortname, long_common_name, relatednames2, display_name, consumer_name
)
SELECT
    loinc_num, component, property, time_aspct, system, scale_typ,
    method_typ, class, shortname, long_common_name, relatednames2, linguistic_variant_display_name, consumer_name
FROM temp_loinc_mx
ON CONFLICT (loinc) DO UPDATE SET
    component = COALESCE(NULLIF(EXCLUDED.component, ''), loinc.component),
    property = COALESCE(NULLIF(EXCLUDED.property, ''), loinc.property),
    time_aspct = COALESCE(NULLIF(EXCLUDED.time_aspct, ''), loinc.time_aspct),
    system_type = COALESCE(NULLIF(EXCLUDED.system_type, ''), loinc.system_type),
    scale_type = COALESCE(NULLIF(EXCLUDED.scale_type, ''), loinc.scale_type),
    method_type = COALESCE(NULLIF(EXCLUDED.method_type, ''), loinc.method_type),
    class_type = COALESCE(NULLIF(EXCLUDED.class_type, ''), loinc.class_type),
    shortname = COALESCE(NULLIF(EXCLUDED.shortname, ''), loinc.shortname),
    long_common_name = COALESCE(NULLIF(EXCLUDED.long_common_name, ''), loinc.long_common_name),
    relatednames2 = COALESCE(NULLIF(EXCLUDED.relatednames2, ''), loinc.relatednames2),
    display_name = COALESCE(NULLIF(EXCLUDED.display_name, ''), loinc.display_name),
    consumer_name = COALESCE(NULLIF(EXCLUDED.consumer_name, ''), loinc.consumer_name);

DROP TABLE IF EXISTS temp_loinc_mx;

-- =============================================================================
-- 6. CAPA DE TRADUCCIÓN ARGENTINA: esAR7LinguisticVariant.csv (38.293 filas)
-- =============================================================================
\echo 'Cargando y sobreescribiendo con variante Argentina (esAR7LinguisticVariant.csv)...'
DROP TABLE IF EXISTS temp_loinc_ar;

CREATE TEMP TABLE temp_loinc_ar (
    loinc_num VARCHAR(20) NOT NULL,
    component TEXT,
    property VARCHAR(255),
    time_aspct VARCHAR(255),
    system VARCHAR(255),
    scale_typ VARCHAR(255),
    method_typ VARCHAR(255),
    class VARCHAR(255),
    shortname TEXT,
    long_common_name TEXT,
    relatednames2 TEXT,
    linguistic_variant_display_name TEXT,
    consumer_name TEXT
);

:cmd_ar

INSERT INTO loinc (
    loinc, component, property, time_aspct, system_type, scale_type,
    method_type, class_type, shortname, long_common_name, relatednames2, display_name, consumer_name
)
SELECT
    loinc_num, component, property, time_aspct, system, scale_typ,
    method_typ, class, shortname, long_common_name, relatednames2, linguistic_variant_display_name, consumer_name
FROM temp_loinc_ar
ON CONFLICT (loinc) DO UPDATE SET
    component = COALESCE(NULLIF(EXCLUDED.component, ''), loinc.component),
    property = COALESCE(NULLIF(EXCLUDED.property, ''), loinc.property),
    time_aspct = COALESCE(NULLIF(EXCLUDED.time_aspct, ''), loinc.time_aspct),
    system_type = COALESCE(NULLIF(EXCLUDED.system_type, ''), loinc.system_type),
    scale_type = COALESCE(NULLIF(EXCLUDED.scale_type, ''), loinc.scale_type),
    method_type = COALESCE(NULLIF(EXCLUDED.method_type, ''), loinc.method_type),
    class_type = COALESCE(NULLIF(EXCLUDED.class_type, ''), loinc.class_type),
    shortname = COALESCE(NULLIF(EXCLUDED.shortname, ''), loinc.shortname),
    long_common_name = COALESCE(NULLIF(EXCLUDED.long_common_name, ''), loinc.long_common_name),
    relatednames2 = COALESCE(NULLIF(EXCLUDED.relatednames2, ''), loinc.relatednames2),
    display_name = COALESCE(NULLIF(EXCLUDED.display_name, ''), loinc.display_name),
    consumer_name = COALESCE(NULLIF(EXCLUDED.consumer_name, ''), loinc.consumer_name);

DROP TABLE IF EXISTS temp_loinc_ar;

-- =============================================================================
-- 7. CREACIÓN DE ÍNDICES OPTIMIZADOS (B-Tree y GIN Trigram)
-- =============================================================================
\echo 'Creando índices B-Tree y GIN Trigram...'
CREATE UNIQUE INDEX IF NOT EXISTS idx_loinc_code ON loinc(loinc);
CREATE INDEX IF NOT EXISTS idx_loinc_class_type ON loinc(class_type);
CREATE INDEX IF NOT EXISTS idx_loinc_status ON loinc(status);
CREATE INDEX IF NOT EXISTS idx_loinc_system_type ON loinc(system_type);

-- Índices Trigram para autocompletado y búsqueda difusa en APIs y buscadores
CREATE INDEX IF NOT EXISTS idx_loinc_lcn_trgm ON loinc USING gin (long_common_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_loinc_display_trgm ON loinc USING gin (display_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_loinc_component_trgm ON loinc USING gin (component gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_loinc_shortname_trgm ON loinc USING gin (shortname gin_trgm_ops);

-- Índices para loinc_map
CREATE INDEX IF NOT EXISTS idx_loinc_map_target ON loinc_map(map);

-- =============================================================================
-- 8. ESTADÍSTICAS Y VERIFICACIÓN FINAL
-- =============================================================================
\echo 'Analizando tablas y verificando resultados...'
ANALYZE loinc;
ANALYZE loinc_map;

SELECT count(*) AS total_conceptos_loinc,
       count(NULLIF(long_common_name, '')) AS con_nombre_comun,
       count(NULLIF(display_name, '')) AS con_display_name,
       count(NULLIF(component, '')) AS con_componente,
       count(NULLIF(consumer_name, '')) AS con_consumer_name
  FROM loinc;

SELECT count(*) AS total_mapeos_loinc FROM loinc_map;
