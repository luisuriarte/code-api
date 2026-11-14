-- =============================================================================
-- Origen Salud · SNOMED CT Edición Argentina · PostgreSQL 18
-- 03_postcarga.sql :: índices, tablas derivadas, vistas y publicación
-- =============================================================================
--
-- QUÉ HACE
--   1. Crea las claves e índices que se omitieron durante el COPY.
--   2. Construye las tablas derivadas de idioma y término preferido.
--   3. Crea vistas de los refsets clínicos argentinos y del DNM.
--   4. Publica el Snapshot en las tablas que consulta la API
--      (snomed_concepts, snomed_descriptions, snomed_relationships).
--   5. Agrega a los catálogos locales las prácticas de laboratorio, vacunas,
--      odontología, prestaciones e imágenes que trae la propia release.
--   6. Publica el mapeo SNOMED CT -> CIE-10 en map_snomed_cie10.
--
-- POR QUÉ LOS ÍNDICES VAN AL FINAL
--   Cargar 3,3 millones de descripciones y 6,4 millones de filas del refset de
--   idioma con los índices puestos es varias veces más lento que cargar en
--   tablas limpias y construir los índices después. Es la misma decisión que
--   se toma en las cargas masivas de MySQL/MariaDB.
--
-- IDEMPOTENCIA
--   El script se puede volver a ejecutar: usa IF NOT EXISTS / OR REPLACE y
--   reconstruye las derivadas y los catálogos derivados sin duplicar filas.
--
-- VENTANA DE MANTENIMIENTO
--   La publicación usa TRUNCATE dentro de una transacción. TRUNCATE toma un
--   lock exclusivo: la API no puede leer esas tablas hasta el COMMIT. Programar
--   la carga en una ventana de mantenimiento.
--
-- MEMORIA
--   Ajustar maintenance_work_mem/work_mem a la RAM real del servidor. Los
--   valores de abajo son conservadores para un servidor de 8 GB.
-- =============================================================================

SET client_encoding = 'UTF8';
SET statement_timeout = 0;
SET lock_timeout = 0;
SET maintenance_work_mem = '512MB';
SET work_mem = '256MB';

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================================================
-- 0. Comprobaciones previas
-- =============================================================================

DO $$
BEGIN
    IF to_regclass('sct2.concept') IS NULL THEN
        RAISE EXCEPTION 'No existe sct2.concept. Ejecutá 01_esquema.sql y 02_carga.sql antes.';
    END IF;

    IF (SELECT count(*) FROM sct2.concept) = 0 THEN
        RAISE EXCEPTION 'sct2.concept está vacía. Ejecutá 02_carga.sql antes.';
    END IF;
END $$;

-- =============================================================================
-- 1. Claves e índices (después del COPY)
-- =============================================================================

-- Terminología ---------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS sct2_concept_id_uq
    ON sct2.concept (id);
CREATE INDEX IF NOT EXISTS sct2_concept_active_idx
    ON sct2.concept (id) WHERE active;

CREATE UNIQUE INDEX IF NOT EXISTS sct2_description_id_uq
    ON sct2.description (id);
CREATE INDEX IF NOT EXISTS sct2_description_concept_idx
    ON sct2.description (concept_id);
CREATE INDEX IF NOT EXISTS sct2_description_active_concept_idx
    ON sct2.description (concept_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_description_lang_type_idx
    ON sct2.description (language_code, type_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_description_term_trgm
    ON sct2.description USING gin (term gin_trgm_ops);

CREATE UNIQUE INDEX IF NOT EXISTS sct2_relationship_id_uq
    ON sct2.relationship (id);
CREATE INDEX IF NOT EXISTS sct2_relationship_source_idx
    ON sct2.relationship (source_id, type_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_relationship_destination_idx
    ON sct2.relationship (destination_id, type_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_relationship_type_idx
    ON sct2.relationship (type_id) WHERE active;

CREATE UNIQUE INDEX IF NOT EXISTS sct2_stated_relationship_id_uq
    ON sct2.stated_relationship (id);
CREATE INDEX IF NOT EXISTS sct2_stated_relationship_source_idx
    ON sct2.stated_relationship (source_id, type_id) WHERE active;

CREATE UNIQUE INDEX IF NOT EXISTS sct2_text_definition_id_uq
    ON sct2.text_definition (id);
CREATE INDEX IF NOT EXISTS sct2_text_definition_concept_idx
    ON sct2.text_definition (concept_id);

CREATE UNIQUE INDEX IF NOT EXISTS sct2_identifier_uq
    ON sct2.identifier (identifier_scheme_id, alternate_identifier);
CREATE INDEX IF NOT EXISTS sct2_identifier_component_idx
    ON sct2.identifier (referenced_component_id);

CREATE UNIQUE INDEX IF NOT EXISTS sct2_relationship_concrete_id_uq
    ON sct2.relationship_concrete (id);
CREATE INDEX IF NOT EXISTS sct2_relationship_concrete_source_idx
    ON sct2.relationship_concrete (source_id, type_id) WHERE active;

-- Refsets --------------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS sct2_refset_simple_id_uq
    ON sct2.refset_simple (id);
CREATE INDEX IF NOT EXISTS sct2_refset_simple_member_idx
    ON sct2.refset_simple (refset_id, referenced_component_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_refset_simple_component_idx
    ON sct2.refset_simple (referenced_component_id);

CREATE UNIQUE INDEX IF NOT EXISTS sct2_refset_language_id_uq
    ON sct2.refset_language (id);
CREATE INDEX IF NOT EXISTS sct2_refset_language_component_idx
    ON sct2.refset_language (referenced_component_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_refset_language_refset_idx
    ON sct2.refset_language (refset_id) WHERE active;

CREATE UNIQUE INDEX IF NOT EXISTS sct2_refset_attribute_value_id_uq
    ON sct2.refset_attribute_value (id);
CREATE INDEX IF NOT EXISTS sct2_refset_attribute_value_member_idx
    ON sct2.refset_attribute_value (refset_id, referenced_component_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_refset_attribute_value_component_idx
    ON sct2.refset_attribute_value (referenced_component_id);

CREATE UNIQUE INDEX IF NOT EXISTS sct2_refset_association_id_uq
    ON sct2.refset_association (id);
CREATE INDEX IF NOT EXISTS sct2_refset_association_member_idx
    ON sct2.refset_association (refset_id, referenced_component_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_refset_association_component_idx
    ON sct2.refset_association (referenced_component_id);

CREATE UNIQUE INDEX IF NOT EXISTS sct2_refset_simple_map_id_uq
    ON sct2.refset_simple_map (id);
CREATE INDEX IF NOT EXISTS sct2_refset_simple_map_member_idx
    ON sct2.refset_simple_map (refset_id, referenced_component_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_refset_simple_map_target_idx
    ON sct2.refset_simple_map (map_target) WHERE active;

CREATE UNIQUE INDEX IF NOT EXISTS sct2_refset_extended_map_id_uq
    ON sct2.refset_extended_map (id);
CREATE INDEX IF NOT EXISTS sct2_refset_extended_map_member_idx
    ON sct2.refset_extended_map (refset_id, referenced_component_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_refset_extended_map_target_idx
    ON sct2.refset_extended_map (map_target) WHERE active;

CREATE UNIQUE INDEX IF NOT EXISTS sct2_refset_medicinal_products_id_uq
    ON sct2.refset_medicinal_products (id);
CREATE INDEX IF NOT EXISTS sct2_refset_medicinal_products_refset_idx
    ON sct2.refset_medicinal_products (refset_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_refset_medicinal_products_component_idx
    ON sct2.refset_medicinal_products (referenced_component_id);

CREATE UNIQUE INDEX IF NOT EXISTS sct2_refset_owl_id_uq
    ON sct2.refset_owl (id);
CREATE INDEX IF NOT EXISTS sct2_refset_owl_refset_idx
    ON sct2.refset_owl (refset_id) WHERE active;
CREATE INDEX IF NOT EXISTS sct2_refset_owl_component_idx
    ON sct2.refset_owl (referenced_component_id);

-- =============================================================================
-- 2. Integridad referencial del Snapshot
-- =============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM sct2.description d
         WHERE NOT EXISTS (SELECT 1 FROM sct2.concept c WHERE c.id = d.concept_id)
    ) THEN
        RAISE EXCEPTION 'Hay descripciones sin concepto. La carga de conceptos está incompleta.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM sct2.relationship r
         WHERE NOT EXISTS (SELECT 1 FROM sct2.concept c WHERE c.id = r.source_id)
            OR NOT EXISTS (SELECT 1 FROM sct2.concept c WHERE c.id = r.destination_id)
    ) THEN
        RAISE EXCEPTION 'Hay relaciones con origen o destino inexistente. Revisá la carga de conceptos y relaciones.';
    END IF;
END $$;

-- =============================================================================
-- 3. Tablas derivadas
-- =============================================================================

-- 3.1 Idioma y aceptabilidad efectiva de cada descripción.
--     Regla: preferida > aceptable; módulo argentino > internacional;
--     effectiveTime más reciente; id como desempate.
DROP TABLE IF EXISTS sct2.language_effective CASCADE;

CREATE TABLE sct2.language_effective AS
SELECT DISTINCT ON (rl.referenced_component_id)
       rl.referenced_component_id,
       rl.acceptability_id,
       rl.module_id,
       rl.effective_time
  FROM sct2.refset_language rl
 WHERE rl.active
 ORDER BY rl.referenced_component_id,
          (rl.acceptability_id = 900000000000548007) DESC,
          (rl.module_id = 11000221109) DESC,
          rl.effective_time DESC,
          rl.id DESC;

CREATE UNIQUE INDEX IF NOT EXISTS sct2_language_effective_pkey
    ON sct2.language_effective (referenced_component_id);

COMMENT ON TABLE sct2.language_effective IS
    'Una fila por descripción con el registro de idioma que prevalece (argentino sobre internacional).';

-- 3.2 Término preferido de cada concepto: español primero, inglés de respaldo.
DROP TABLE IF EXISTS sct2.preferred_term CASCADE;

CREATE TABLE sct2.preferred_term AS
SELECT DISTINCT ON (c.id)
       c.id   AS concept_id,
       d.id   AS description_id,
       d.term,
       d.language_code
  FROM sct2.concept c
  JOIN sct2.description d
    ON d.concept_id = c.id
   AND d.active
  LEFT JOIN sct2.language_effective le
    ON le.referenced_component_id = d.id
 WHERE c.active
 ORDER BY c.id,
          (d.language_code = 'es') DESC,
          (d.language_code = 'en') DESC,
          (le.acceptability_id = 900000000000548007) DESC NULLS LAST,
          (le.module_id = 11000221109) DESC NULLS LAST,
          (d.type_id = 900000000000013009) DESC,
          length(d.term),
          d.term,
          d.id;

CREATE UNIQUE INDEX IF NOT EXISTS sct2_preferred_term_pkey
    ON sct2.preferred_term (concept_id);
CREATE INDEX IF NOT EXISTS sct2_preferred_term_term_trgm
    ON sct2.preferred_term USING gin (term gin_trgm_ops);

COMMENT ON TABLE sct2.preferred_term IS
    'Un término por concepto activo. Prioriza español, aceptabilidad preferida y sinónimo sobre FSN.';

-- 3.3 Catálogo de fármacos genéricos prescribibles del DNM.
--     574471000221107 = genérico con unidad de presentación definida.
--     574481000221105 = genérico sin unidad de presentación definida.
--     La forma farmacéutica sale de la relación 411116001.
DROP TABLE IF EXISTS sct2.generic_drug CASCADE;

CREATE TABLE sct2.generic_drug AS
SELECT g.concept_id,
       bool_or(g.has_unit = 1) AS has_unit,
       (
           SELECT max(r.destination_id)
             FROM sct2.relationship r
            WHERE r.source_id = g.concept_id
              AND r.active
              AND r.type_id = 411116001
       ) AS pharmaceutical_form_id
  FROM (
        SELECT referenced_component_id AS concept_id, 1 AS has_unit
          FROM sct2.refset_simple
         WHERE active
           AND refset_id = 574471000221107
        UNION
        SELECT referenced_component_id, 0
          FROM sct2.refset_simple
         WHERE active
           AND refset_id = 574481000221105
       ) g
 GROUP BY g.concept_id;

CREATE UNIQUE INDEX IF NOT EXISTS sct2_generic_drug_pkey
    ON sct2.generic_drug (concept_id);

COMMENT ON TABLE sct2.generic_drug IS
    'Fármacos genéricos prescribibles del DNM, con unidad de presentación y forma farmacéutica.';

-- 3.4 Vínculo marca comercial -> genérico y atributos del DNM.
--     El genérico se toma de la relación inferida 116680003 (es un) sólo cuando
--     la marca tiene un único destino; si tiene varios, el vínculo es ambiguo.
--     425071000221108 = marcas comerciales; 574461000221103 = comercializadas.
DROP TABLE IF EXISTS sct2.brand_generic CASCADE;

CREATE TABLE sct2.brand_generic AS
WITH brands AS (
    SELECT DISTINCT referenced_component_id AS brand_id
      FROM sct2.refset_simple
     WHERE active
       AND refset_id = 425071000221108
),
is_a AS (
    SELECT r.source_id,
           count(*)                 AS relations,
           min(r.destination_id)    AS generic_id
      FROM sct2.relationship r
      JOIN brands b ON b.brand_id = r.source_id
     WHERE r.active
       AND r.type_id = 116680003
     GROUP BY r.source_id
),
commercialized AS (
    SELECT DISTINCT referenced_component_id AS brand_id
      FROM sct2.refset_simple
     WHERE active
       AND refset_id = 574461000221103
),
laboratory AS (
    SELECT source_id, min(destination_id) AS laboratory_id
      FROM sct2.relationship
     WHERE active
       AND type_id = 774159003
     GROUP BY source_id
),
dispense AS (
    SELECT source_id, min(destination_id) AS dispense_condition_id
      FROM sct2.relationship
     WHERE active
       AND type_id = 574941000221106
     GROUP BY source_id
),
controlled AS (
    SELECT source_id, min(destination_id) AS controlled_category_id
      FROM sct2.relationship
     WHERE active
       AND type_id = 579631000221106
     GROUP BY source_id
)
SELECT b.brand_id,
       CASE WHEN ia.relations = 1 THEN ia.generic_id END AS generic_id,
       coalesce(ia.relations, 0)                          AS relations,
       (c.brand_id IS NOT NULL)                           AS commercialized,
       lab.laboratory_id,
       d.dispense_condition_id,
       ctrl.controlled_category_id
  FROM brands b
  LEFT JOIN is_a ia          ON ia.source_id = b.brand_id
  LEFT JOIN commercialized c ON c.brand_id = b.brand_id
  LEFT JOIN laboratory lab   ON lab.source_id = b.brand_id
  LEFT JOIN dispense d       ON d.source_id = b.brand_id
  LEFT JOIN controlled ctrl  ON ctrl.source_id = b.brand_id;

CREATE UNIQUE INDEX IF NOT EXISTS sct2_brand_generic_pkey
    ON sct2.brand_generic (brand_id);
CREATE INDEX IF NOT EXISTS sct2_brand_generic_generic_idx
    ON sct2.brand_generic (generic_id);

COMMENT ON TABLE sct2.brand_generic IS
    'Marca comercial -> genérico, con laboratorio, condición de expendio y categoría de control.';

-- 3.5 Catálogo de refsets. `filter_code` es el nombre corto y estable que usa
--     la publicación opcional de 04_codigos_opcional.sql. Los refsets sin
--     filter_code no se publican para filtrado (idioma, mapas, refsets
--     inactivos o de uso interno).
CREATE TABLE IF NOT EXISTS public.sct2_refset_catalog (
    refset_id   BIGINT       PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    category    VARCHAR(32)  NOT NULL DEFAULT 'otros',
    description VARCHAR(512) NOT NULL DEFAULT '',
    filter_code VARCHAR(24)  NULL
);

-- Para instalaciones creadas antes de esta versión.
ALTER TABLE public.sct2_refset_catalog
    ADD COLUMN IF NOT EXISTS filter_code VARCHAR(24);

CREATE UNIQUE INDEX IF NOT EXISTS sct2_refset_catalog_filter_code_uq
    ON public.sct2_refset_catalog (filter_code)
    WHERE filter_code IS NOT NULL;

COMMENT ON TABLE public.sct2_refset_catalog IS
    'Catálogo de refsets con nombre, categoría y código de filtro. Lo mantiene el proyecto; sobrevive a las recargas de sct2.';
COMMENT ON COLUMN public.sct2_refset_catalog.filter_code IS
    'Nombre corto usado por snomed_refset_member (04_codigos_opcional.sql). NULL = no se publica para filtrado.';

INSERT INTO public.sct2_refset_catalog
    (refset_id, name, category, description, filter_code)
VALUES
    (425071000221108, 'Fármacos de uso clínico comerciales', 'medicamentos', 'Marcas comerciales del DNM.', 'MARCAS'),
    (425081000221106, 'Fármacos de uso clínico con unidad de presentación definida', 'medicamentos', 'Genéricos con unidad.', NULL),
    (425091000221109, 'Fármacos de uso clínico sin unidad de presentación definida', 'medicamentos', 'Genéricos sin unidad.', NULL),
    (331101000221109, 'Presentaciones farmacéuticas comercializadas', 'medicamentos', 'Presentaciones en estado comercializado.', 'PRESENT_COMERCIALIZADAS'),
    (723264001,       'Presentaciones farmacéuticas comerciales (VNM)', 'medicamentos', 'Catálogo internacional de presentaciones (VNM).', NULL),
    (574451000221100, 'Presentaciones farmacéuticas comerciales', 'medicamentos', 'Presentaciones del DNM.', 'PRESENTACIONES'),
    (574461000221103, 'Fármacos de uso clínico comercializados', 'medicamentos', 'Marcas comercializadas.', 'MARCAS_COMERCIALIZADAS'),
    (574471000221107, 'Genéricos con unidad de presentación, comercializados', 'medicamentos', 'Genéricos prescribibles con unidad.', 'GENERICO_CON_UNIDAD'),
    (574481000221105, 'Genéricos sin unidad de presentación, comercializados', 'medicamentos', 'Genéricos prescribibles sin unidad.', 'GENERICO_SIN_UNIDAD'),
    (552511000221107, 'Productos medicinales del DNM', 'medicamentos', 'Refset inactivo en la edición 2026-08.', NULL),
    (577281000221100, 'Prácticas y procedimientos de la Edición Argentina', 'practicas', 'Nomenclador de prácticas.', 'PRESTACIONES'),
    (537301000221103, 'Prácticas de laboratorio de Argentina', 'practicas', 'Determinaciones de laboratorio.', 'LABORATORIO'),
    (536561000221108, 'Prácticas prescribibles de diagnóstico por imágenes', 'practicas', 'Estudios de imágenes.', 'IMAGENES'),
    (371201000221100, 'Prácticas y procedimientos SUMAR', 'practicas', 'Cobertura SUMAR.', 'SUMAR_PROC'),
    (371191000221103, 'Diagnósticos del Programa SUMAR', 'programas', 'Diagnósticos para facturación SUMAR.', 'SUMAR_DX'),
    (371221000221107, 'Ámbitos de atención del Programa SUMAR', 'programas', 'Ámbitos de atención SUMAR.', 'SUMAR_AMBITO'),
    (371211000221102, 'Profesionales del Programa SUMAR', 'programas', 'Profesionales vinculados a SUMAR.', 'SUMAR_PROF'),
    (349091000221101, 'Medicamentos esenciales del Programa Remediar', 'programas', 'Fármacos del Programa Remediar.', 'REMEDIAR'),
    (2281000221106,  'Inmunizaciones de Argentina', 'vacunas', 'Calendario nacional de vacunas.', 'VACUNAS'),
    (401211000221103, 'Mapeo SNOMED CT a NOMIVAC', 'vacunas', 'Mapa simple de vacunas al código NOMIVAC.', 'NOMIVAC'),
    (398711000221107, 'Diagnósticos de odontología de Argentina', 'odontologia', 'Diagnósticos odontológicos.', 'ODONTO_DX'),
    (399211000221109, 'Procedimientos de odontología de Argentina', 'odontologia', 'Procedimientos odontológicos.', 'ODONTO_PROC'),
    (651000221107,   'Enfermedades de notificación obligatoria', 'eno', 'Eventos de notificación obligatoria.', 'ENO'),
    (869651000221108, 'Productos sanitarios y dispositivos médicos', 'dispositivos', 'Dispositivos y productos sanitarios.', 'DISPOSITIVOS'),
    (93491000221103, 'Pueblos originarios', 'poblaciones', 'Atributos poblacionales.', 'PUEBLOS'),
    (331151000221108, 'Especialidades médicas reconocidas', 'profesionales', 'Especialidades del Ministerio de Salud.', 'ESPECIALIDADES'),
    (2271000221108,  'Profesiones matriculadas de salud', 'profesionales', 'Profesiones vinculadas a la atención.', 'PROFESIONES'),
    (331131000221104, 'Ocupaciones vinculadas a especialidades', 'profesionales', 'Ocupaciones del Ministerio de Salud.', 'OCUPACIONES'),
    (450828004,      'Español de América Latina', 'idioma', 'Aceptabilidad de términos en español.', NULL),
    (900000000000509007, 'Inglés (US)', 'idioma', 'Aceptabilidad de términos en inglés US.', NULL),
    (900000000000508004, 'Inglés (GB)', 'idioma', 'Aceptabilidad de términos en inglés GB.', NULL),
    (447562003,      'Mapa extendido SNOMED CT a CIE-10', 'mapas', 'Mapa complejo con reglas.', NULL),
    (900000000000497000, 'Mapa simple SNOMED CT a CIE-10', 'mapas', 'Mapa uno a uno.', NULL)
ON CONFLICT (refset_id) DO UPDATE
    SET name = EXCLUDED.name,
        category = EXCLUDED.category,
        description = EXCLUDED.description,
        filter_code = EXCLUDED.filter_code;

DROP TABLE IF EXISTS sct2.refset_summary;

CREATE TABLE sct2.refset_summary AS
SELECT r.refset_id,
       cat.name,
       cat.category,
       cat.description,
       cat.filter_code,
       count(*) FILTER (WHERE r.active) AS active_members,
       count(*)                          AS total_members
  FROM (
        SELECT refset_id, active FROM sct2.refset_simple
        UNION ALL SELECT refset_id, active FROM sct2.refset_language
        UNION ALL SELECT refset_id, active FROM sct2.refset_attribute_value
        UNION ALL SELECT refset_id, active FROM sct2.refset_association
        UNION ALL SELECT refset_id, active FROM sct2.refset_simple_map
        UNION ALL SELECT refset_id, active FROM sct2.refset_extended_map
        UNION ALL SELECT refset_id, active FROM sct2.refset_medicinal_products
        UNION ALL SELECT refset_id, active FROM sct2.refset_owl
       ) r
  LEFT JOIN public.sct2_refset_catalog cat ON cat.refset_id = r.refset_id
 GROUP BY r.refset_id, cat.name, cat.category, cat.description, cat.filter_code;

CREATE UNIQUE INDEX IF NOT EXISTS sct2_refset_summary_pkey
    ON sct2.refset_summary (refset_id);

COMMENT ON TABLE sct2.refset_summary IS
    'Cantidad de miembros activos y totales de cada refset de la release.';

-- =============================================================================
-- 4. Vistas de consulta
-- =============================================================================

-- 4.1 Índice de búsqueda: descripciones activas en español + término preferido.
--     Equivale a la tabla `sct2_termino_busqueda` del proyecto MySQL/MariaDB,
--     pero como vista: en PostgreSQL el índice GIN de sct2.description ya
--     resuelve el autocompletado sin duplicar 1,4 millones de filas.
CREATE OR REPLACE VIEW sct2.v_search_term AS
SELECT d.id            AS description_id,
       d.concept_id,
       d.term,
       tp.term         AS preferred_term,
       d.language_code
  FROM sct2.description d
  JOIN sct2.concept c      ON c.id = d.concept_id AND c.active
  JOIN sct2.preferred_term tp ON tp.concept_id = c.id
 WHERE d.active
   AND d.language_code = 'es';

-- 4.2 Miembros de cualquier refset simple, con su término preferido.
CREATE OR REPLACE VIEW sct2.v_refset_member AS
SELECT rs.refset_id,
       rs.referenced_component_id AS concept_id,
       tp.term,
       rs.active
  FROM sct2.refset_simple rs
  LEFT JOIN sct2.preferred_term tp ON tp.concept_id = rs.referenced_component_id;

-- 4.3 Catálogos clínicos argentinos.
CREATE OR REPLACE VIEW sct2.v_lab_practice AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 537301000221103 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_imaging_practice AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 536561000221108 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_procedure AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id IN (577281000221100, 371201000221100) AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_vaccine AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 2281000221106 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_dental_diagnosis AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 398711000221107 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_dental_procedure AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 399211000221109 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_notifiable_disease AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 651000221107 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_device AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 869651000221108 AND term IS NOT NULL;

-- 4.4 RefSets de profesionales, programas nacionales y poblaciones.
CREATE OR REPLACE VIEW sct2.v_specialty AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 331151000221108 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_profession AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 2271000221108 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_occupation AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 331131000221104 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_remediar AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 349091000221101 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_sumar_diagnosis AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 371191000221103 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_sumar_procedure AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 371201000221100 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_sumar_scope AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 371221000221107 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_sumar_professional AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 371211000221102 AND term IS NOT NULL;

CREATE OR REPLACE VIEW sct2.v_aboriginal_people AS
SELECT concept_id, term
  FROM sct2.v_refset_member
 WHERE active AND refset_id = 93491000221103 AND term IS NOT NULL;

-- 4.5 Mapas. El de NOMIVAC es un refset simple; el de CIE-10, uno extendido.
CREATE OR REPLACE VIEW sct2.v_nomivac AS
SELECT sm.referenced_component_id AS concept_id,
       tp.term                    AS term,
       sm.map_target              AS nomivac_code
  FROM sct2.refset_simple_map sm
  LEFT JOIN sct2.preferred_term tp ON tp.concept_id = sm.referenced_component_id
 WHERE sm.active
   AND sm.refset_id = 401211000221103;

CREATE OR REPLACE VIEW sct2.v_cie10_map AS
SELECT em.referenced_component_id AS concept_id,
       tp.term                    AS term,
       em.map_target              AS cie10_code,
       em.map_group,
       em.map_priority,
       em.map_rule,
       em.correlation_id
  FROM sct2.refset_extended_map em
  LEFT JOIN sct2.preferred_term tp ON tp.concept_id = em.referenced_component_id
 WHERE em.active
   AND em.refset_id = 447562003
   AND em.map_target IS NOT NULL;

-- 4.6 DNM: genéricos, marcas y presentaciones.
CREATE OR REPLACE VIEW sct2.v_generic AS
SELECT g.concept_id,
       tp.term                    AS term,
       g.has_unit,
       g.pharmaceutical_form_id,
       ff.term                    AS pharmaceutical_form
  FROM sct2.generic_drug g
  LEFT JOIN sct2.preferred_term tp ON tp.concept_id = g.concept_id
  LEFT JOIN sct2.preferred_term ff ON ff.concept_id = g.pharmaceutical_form_id;

CREATE OR REPLACE VIEW sct2.v_brand AS
SELECT b.brand_id,
       bp.term                    AS brand,
       b.commercialized,
       b.generic_id,
       gp.term                    AS generic,
       b.laboratory_id,
       lp.term                    AS laboratory,
       b.dispense_condition_id,
       dp.term                    AS dispense_condition,
       b.controlled_category_id,
       cp.term                    AS controlled_category
  FROM sct2.brand_generic b
  LEFT JOIN sct2.preferred_term bp ON bp.concept_id = b.brand_id
  LEFT JOIN sct2.preferred_term gp ON gp.concept_id = b.generic_id
  LEFT JOIN sct2.preferred_term lp ON lp.concept_id = b.laboratory_id
  LEFT JOIN sct2.preferred_term dp ON dp.concept_id = b.dispense_condition_id
  LEFT JOIN sct2.preferred_term cp ON cp.concept_id = b.controlled_category_id;

CREATE OR REPLACE VIEW sct2.v_generic_brand AS
SELECT g.concept_id AS generic_id,
       tp.term       AS generic,
       count(b.brand_id)                                 AS brands,
       count(b.brand_id) FILTER (WHERE b.commercialized) AS commercialized_brands
  FROM sct2.generic_drug g
  JOIN sct2.preferred_term tp ON tp.concept_id = g.concept_id
  LEFT JOIN sct2.brand_generic b ON b.generic_id = g.concept_id
 GROUP BY g.concept_id, tp.term;

CREATE OR REPLACE VIEW sct2.v_presentation AS
SELECT DISTINCT ON (rs.referenced_component_id)
       rs.referenced_component_id AS concept_id,
       tp.term,
       EXISTS (
           SELECT 1
             FROM sct2.refset_simple c
            WHERE c.active
              AND c.refset_id = 331101000221109
              AND c.referenced_component_id = rs.referenced_component_id
       ) AS commercialized
  FROM sct2.refset_simple rs
  JOIN sct2.preferred_term tp ON tp.concept_id = rs.referenced_component_id
 WHERE rs.active
   AND rs.refset_id = 574451000221100
 ORDER BY rs.referenced_component_id;

-- =============================================================================
-- 5. Publicación en las tablas de la aplicación
-- =============================================================================

BEGIN;

-- 5.1 Conceptos: UPSERT y baja lógica de los que ya no están en la release.
--     No se borran para no romper las referencias de anmat_medicamentos y de
--     los catálogos locales.
INSERT INTO snomed_concepts (id, active, effective_time, module_id, definition_status_id)
SELECT id, active, effective_time, module_id, definition_status_id
  FROM sct2.concept
ON CONFLICT (id) DO UPDATE
    SET active               = EXCLUDED.active,
        effective_time       = EXCLUDED.effective_time,
        module_id            = EXCLUDED.module_id,
        definition_status_id = EXCLUDED.definition_status_id;

UPDATE snomed_concepts c
   SET active = FALSE
 WHERE c.active
   AND NOT EXISTS (SELECT 1 FROM sct2.concept s WHERE s.id = c.id);

-- 5.2 Descripciones y relaciones: recarga completa.
--     TRUNCATE es transaccional y mucho más rápido que un UPSERT de 4 millones
--     de filas. La base normaliza el idioma a su etiqueta primaria.
TRUNCATE snomed_descriptions;

INSERT INTO snomed_descriptions (
    id, active, effective_time, module_id, concept_id,
    language_code, type_id, term, case_significance_id
)
SELECT id,
       active,
       effective_time,
       module_id,
       concept_id,
       split_part(language_code, '-', 1),
       type_id,
       term,
       case_significance_id
  FROM sct2.description;

TRUNCATE snomed_relationships;

INSERT INTO snomed_relationships (
    id, active, effective_time, module_id, source_id, destination_id,
    relationship_group, type_id, characteristic_type_id, modifier_id
)
SELECT id, active, effective_time, module_id, source_id, destination_id,
       relationship_group, type_id, characteristic_type_id, modifier_id
  FROM sct2.relationship;

-- 5.3 Mapa SNOMED CT -> CIE-10. Se cruza por código normalizado (sin punto) y
--     se ignoran los destinos que no existan en cie10_codes.
INSERT INTO map_snomed_cie10 (snomed_concept_id, cie10_id)
SELECT DISTINCT m.referenced_component_id, c.id
  FROM (
        SELECT referenced_component_id, map_target
          FROM sct2.refset_extended_map
         WHERE active
           AND map_target IS NOT NULL
           AND btrim(map_target) <> ''
        UNION
        SELECT referenced_component_id, map_target
          FROM sct2.refset_simple_map
         WHERE active
           AND map_target IS NOT NULL
           AND btrim(map_target) <> ''
       ) m
  JOIN snomed_concepts sc
    ON sc.id = m.referenced_component_id
  JOIN cie10_codes c
    ON upper(replace(c.codigo, '.', '')) = upper(replace(m.map_target, '.', ''))
ON CONFLICT DO NOTHING;

-- 5.4 Catálogos locales derivados de los refsets argentinos.
--     El código local es el SCTID, para poder reconocer las filas derivadas.
--     Las filas curadas (con otro código) nunca se pisan.

-- Laboratorio
INSERT INTO laboratorio_practicas (codigo_loinc, nombre_prueba, unidad_medida, snomed_concept_id, activo)
SELECT NULL, v.term, NULL, v.concept_id, TRUE
  FROM (
        SELECT DISTINCT ON (rs.referenced_component_id)
               rs.referenced_component_id AS concept_id,
               tp.term
          FROM sct2.refset_simple rs
          JOIN sct2.preferred_term tp ON tp.concept_id = rs.referenced_component_id
         WHERE rs.active
           AND rs.refset_id = 537301000221103
         ORDER BY rs.referenced_component_id
       ) v
 WHERE NOT EXISTS (
       SELECT 1
         FROM laboratorio_practicas l
        WHERE l.snomed_concept_id = v.concept_id
 );

-- Vacunas
INSERT INTO vacunas_catalogo (
    codigo_vacuna_msal, nombre_comercial, principio_activo,
    dosis_esquema, snomed_concept_id, activo
)
SELECT DISTINCT ON (rs.referenced_component_id)
       CAST(rs.referenced_component_id AS VARCHAR(30)),
       tp.term,
       tp.term,
       NULL,
       rs.referenced_component_id,
       TRUE
  FROM sct2.refset_simple rs
  JOIN sct2.preferred_term tp ON tp.concept_id = rs.referenced_component_id
 WHERE rs.active
   AND rs.refset_id = 2281000221106
 ORDER BY rs.referenced_component_id
ON CONFLICT (codigo_vacuna_msal) DO UPDATE
    SET nombre_comercial  = EXCLUDED.nombre_comercial,
        principio_activo  = EXCLUDED.principio_activo,
        snomed_concept_id = EXCLUDED.snomed_concept_id,
        activo            = TRUE
  WHERE vacunas_catalogo.snomed_concept_id = EXCLUDED.snomed_concept_id;

-- Odontología (diagnósticos + procedimientos)
INSERT INTO odontologia_prestaciones (
    codigo_nomenclador, descripcion, snomed_concept_id,
    face_specification, activo
)
SELECT DISTINCT ON (rs.referenced_component_id)
       CAST(rs.referenced_component_id AS VARCHAR(20)),
       tp.term,
       rs.referenced_component_id,
       FALSE,
       TRUE
  FROM sct2.refset_simple rs
  JOIN sct2.preferred_term tp ON tp.concept_id = rs.referenced_component_id
 WHERE rs.active
   AND rs.refset_id IN (398711000221107, 399211000221109)
 ORDER BY rs.referenced_component_id
ON CONFLICT (codigo_nomenclador) DO UPDATE
    SET descripcion       = EXCLUDED.descripcion,
        snomed_concept_id = EXCLUDED.snomed_concept_id,
        activo            = TRUE
  WHERE odontologia_prestaciones.snomed_concept_id = EXCLUDED.snomed_concept_id;

-- Prestaciones médicas (nomenclador general + SUMAR)
INSERT INTO prestaciones_medicas (
    codigo_prestacion, nombre, categoria, snomed_concept_id, activo
)
SELECT DISTINCT ON (rs.referenced_component_id)
       CAST(rs.referenced_component_id AS VARCHAR(30)),
       tp.term,
       CASE rs.refset_id
           WHEN 371201000221100 THEN 'SUMAR'
           ELSE 'SNOMED CT Argentina'
       END,
       rs.referenced_component_id,
       TRUE
  FROM sct2.refset_simple rs
  JOIN sct2.preferred_term tp ON tp.concept_id = rs.referenced_component_id
 WHERE rs.active
   AND rs.refset_id IN (577281000221100, 371201000221100)
 ORDER BY rs.referenced_component_id,
          (rs.refset_id = 371201000221100) DESC
ON CONFLICT (codigo_prestacion) DO UPDATE
    SET nombre            = EXCLUDED.nombre,
        categoria         = EXCLUDED.categoria,
        snomed_concept_id = EXCLUDED.snomed_concept_id,
        activo            = TRUE
  WHERE prestaciones_medicas.snomed_concept_id = EXCLUDED.snomed_concept_id;

-- Diagnóstico por imágenes. La modalidad DICOM no viene en RF2: 'OT' (Other)
-- es el valor DICOM válido para "otro"; la institución la ajusta si lo desea.
INSERT INTO imagenes_practicas (
    codigo_estudio, nombre_estudio, modalidad_dicom,
    snomed_concept_id, codigo_loinc, requiere_contraste, activo
)
SELECT DISTINCT ON (rs.referenced_component_id)
       CAST(rs.referenced_component_id AS VARCHAR(50)),
       tp.term,
       'OT',
       rs.referenced_component_id,
       NULL,
       FALSE,
       TRUE
  FROM sct2.refset_simple rs
  JOIN sct2.preferred_term tp ON tp.concept_id = rs.referenced_component_id
 WHERE rs.active
   AND rs.refset_id = 536561000221108
 ORDER BY rs.referenced_component_id
ON CONFLICT (codigo_estudio) DO UPDATE
    SET nombre_estudio    = EXCLUDED.nombre_estudio,
        snomed_concept_id = EXCLUDED.snomed_concept_id,
        activo            = TRUE
  WHERE imagenes_practicas.snomed_concept_id = EXCLUDED.snomed_concept_id;

-- 5.5 Baja lógica de las filas derivadas que ya no están en el refset.
UPDATE imagenes_practicas t
   SET activo = FALSE
 WHERE t.activo
   AND t.snomed_concept_id IS NOT NULL
   AND t.codigo_estudio = CAST(t.snomed_concept_id AS TEXT)
   AND NOT EXISTS (
       SELECT 1 FROM sct2.refset_simple r
        WHERE r.active
          AND r.refset_id = 536561000221108
          AND r.referenced_component_id = t.snomed_concept_id
   );

UPDATE odontologia_prestaciones t
   SET activo = FALSE
 WHERE t.activo
   AND t.snomed_concept_id IS NOT NULL
   AND t.codigo_nomenclador = CAST(t.snomed_concept_id AS TEXT)
   AND NOT EXISTS (
       SELECT 1 FROM sct2.refset_simple r
        WHERE r.active
          AND r.refset_id IN (398711000221107, 399211000221109)
          AND r.referenced_component_id = t.snomed_concept_id
   );

UPDATE prestaciones_medicas t
   SET activo = FALSE
 WHERE t.activo
   AND t.snomed_concept_id IS NOT NULL
   AND t.codigo_prestacion = CAST(t.snomed_concept_id AS TEXT)
   AND NOT EXISTS (
       SELECT 1 FROM sct2.refset_simple r
        WHERE r.active
          AND r.refset_id IN (577281000221100, 371201000221100)
          AND r.referenced_component_id = t.snomed_concept_id
   );

UPDATE vacunas_catalogo t
   SET activo = FALSE
 WHERE t.activo
   AND t.snomed_concept_id IS NOT NULL
   AND t.codigo_vacuna_msal = CAST(t.snomed_concept_id AS TEXT)
   AND NOT EXISTS (
       SELECT 1 FROM sct2.refset_simple r
        WHERE r.active
          AND r.refset_id = 2281000221106
          AND r.referenced_component_id = t.snomed_concept_id
   );

COMMIT;

-- =============================================================================
-- 6. Estadísticas para el planner
-- =============================================================================

ANALYZE sct2.concept;
ANALYZE sct2.description;
ANALYZE sct2.relationship;
ANALYZE sct2.stated_relationship;
ANALYZE sct2.text_definition;
ANALYZE sct2.identifier;
ANALYZE sct2.relationship_concrete;
ANALYZE sct2.refset_simple;
ANALYZE sct2.refset_language;
ANALYZE sct2.refset_attribute_value;
ANALYZE sct2.refset_association;
ANALYZE sct2.refset_simple_map;
ANALYZE sct2.refset_extended_map;
ANALYZE sct2.refset_medicinal_products;
ANALYZE sct2.refset_owl;
ANALYZE sct2.language_effective;
ANALYZE sct2.preferred_term;
ANALYZE sct2.generic_drug;
ANALYZE sct2.brand_generic;
ANALYZE sct2.refset_summary;
ANALYZE public.sct2_refset_catalog;

ANALYZE snomed_concepts;
ANALYZE snomed_descriptions;
ANALYZE snomed_relationships;
ANALYZE map_snomed_cie10;

-- =============================================================================
-- 7. Resumen de la publicación
-- =============================================================================

SELECT 'conceptos publicados'  AS metrica, count(*) AS valor FROM snomed_concepts
UNION ALL
SELECT 'descripciones publicadas', count(*) FROM snomed_descriptions
UNION ALL
SELECT 'relaciones publicadas', count(*) FROM snomed_relationships
UNION ALL
SELECT 'términos preferidos', count(*) FROM sct2.preferred_term
UNION ALL
SELECT 'genéricos', count(*) FROM sct2.generic_drug
UNION ALL
SELECT 'marcas comerciales', count(*) FROM sct2.brand_generic
UNION ALL
SELECT 'refsets filtrables', count(*) FROM public.sct2_refset_catalog WHERE filter_code IS NOT NULL
UNION ALL
SELECT 'mapeos SNOMED/CIE-10', count(*) FROM map_snomed_cie10
UNION ALL
SELECT 'laboratorio', count(*) FROM laboratorio_practicas
UNION ALL
SELECT 'vacunas', count(*) FROM vacunas_catalogo
UNION ALL
SELECT 'odontología', count(*) FROM odontologia_prestaciones
UNION ALL
SELECT 'prestaciones', count(*) FROM prestaciones_medicas
UNION ALL
SELECT 'imágenes', count(*) FROM imagenes_practicas
ORDER BY metrica;
