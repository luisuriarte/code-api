-- =============================================================================
-- Origen Salud · SNOMED CT Edición Argentina · PostgreSQL 18
-- 01_esquema.sql :: esquema de staging para una carga masiva RF2
-- =============================================================================
--
-- QUÉ HACE
--   Borra y vuelve a crear el esquema `sct2`, un depósito temporal de
--   terminología con el layout real de Release Format 2 (RF2).
--   No toca las tablas clínicas ni los catálogos de la aplicación: esos viven
--   en `public` y se actualizan después, desde `03_postcarga.sql`.
--
-- POR QUÉ UN ESQUEMA APARTE
--   1. Permite cargar los archivos con COPY (la vía más rápida de PostgreSQL)
--      sin bloquear ni ensuciar las tablas que consulta la API.
--   2. Deja el esquema de la aplicación estable mientras se reconstruye la
--      terminología. Si la carga falla, se vuelve a correr desde cero.
--   3. Separa claramente "datos crudos de la release" de "tablas publicadas".
--
-- SÓLO SNAPSHOT, NUNCA FULL
--   Los archivos Snapshot traen el estado vigente: una fila por componente.
--   Los archivos Full traen todo el histórico y duplican identificadores.
--   `tools/php/generar_carga_snomed.php` ignora deliberadamente Full/ y Delta/.
--
-- SIN CLAVES NI ÍNDICES SECUNDARIOS
--   Las tablas se crean sin PRIMARY KEY y sin índices, y son UNLOGGED.
--   Eso acelera muchísimo el COPY. Las claves y los índices se agregan en
--   `03_postcarga.sql`, cuando los datos ya están adentro.
--
-- ORDEN DE EJECUCIÓN
--   01_esquema.sql          -> este archivo
--   02_carga.sql            -> generado por tools/php/generar_carga_snomed.php
--   03_postcarga.sql        -> claves, índices, derivadas, vistas y publicación
--   99_verificacion.sql     -> controles de conteo e integridad
--
-- ADVERTENCIA
--   `DROP SCHEMA sct2 CASCADE` es destructivo para todo lo que esté en `sct2`.
--   Es intencional: la release se reconstruye completa en cada actualización.
--   Los catálogos de `public` NO se borran.
-- =============================================================================

SET client_encoding = 'UTF8';
SET statement_timeout = 0;
SET lock_timeout = 0;

DROP SCHEMA IF EXISTS sct2 CASCADE;
CREATE SCHEMA sct2;

COMMENT ON SCHEMA sct2 IS
    'Staging de SNOMED CT en formato RF2. Se reconstruye en cada release y se publica en public.* desde 03_postcarga.sql.';

-- =============================================================================
-- 1. Terminología (Snapshot/Terminology)
-- =============================================================================

CREATE UNLOGGED TABLE sct2.concept (
    id                   BIGINT      NOT NULL,
    effective_time       DATE        NOT NULL,
    active               BOOLEAN     NOT NULL,
    module_id            BIGINT      NOT NULL,
    definition_status_id BIGINT      NOT NULL
);

COMMENT ON TABLE sct2.concept IS
    'Conceptos SNOMED CT (sct2_Concept_Snapshot). Un concepto toma su significado de su FSN.';
COMMENT ON COLUMN sct2.concept.id IS
    'SCTID. Identificador único del concepto; nunca se reutiliza.';
COMMENT ON COLUMN sct2.concept.active IS
    'TRUE = vigente. Un concepto inactivo sigue siendo válido por el principio de permanencia.';
COMMENT ON COLUMN sct2.concept.definition_status_id IS
    '900000000000073002 = definido; 900000000000074008 = primitivo.';

CREATE UNLOGGED TABLE sct2.description (
    id                    BIGINT       NOT NULL,
    effective_time        DATE         NOT NULL,
    active                BOOLEAN      NOT NULL,
    module_id             BIGINT       NOT NULL,
    concept_id            BIGINT       NOT NULL,
    language_code         VARCHAR(10)  NOT NULL,
    type_id               BIGINT       NOT NULL,
    term                  TEXT         NOT NULL,
    case_significance_id  BIGINT       NOT NULL
);

COMMENT ON TABLE sct2.description IS
    'Descripciones (términos y sinónimos) de los conceptos (sct2_Description_Snapshot).';
COMMENT ON COLUMN sct2.description.language_code IS
    'Idioma ISO-639-1 del texto: es, en. La base normaliza a la etiqueta primaria al publicar.';
COMMENT ON COLUMN sct2.description.type_id IS
    '900000000000003001 = FSN; 900000000000013009 = sinónimo.';
COMMENT ON COLUMN sct2.description.term IS
    'Texto UTF-8. En la edición argentina hay términos de más de 255 caracteres: por eso TEXT.';

CREATE UNLOGGED TABLE sct2.relationship (
    id                    BIGINT   NOT NULL,
    effective_time        DATE     NOT NULL,
    active                BOOLEAN  NOT NULL,
    module_id             BIGINT   NOT NULL,
    source_id             BIGINT   NOT NULL,
    destination_id        BIGINT   NOT NULL,
    relationship_group    INTEGER  NOT NULL,
    type_id               BIGINT   NOT NULL,
    characteristic_type_id BIGINT  NOT NULL,
    modifier_id           BIGINT   NOT NULL
);

COMMENT ON TABLE sct2.relationship IS
    'Relaciones inferidas entre conceptos (sct2_Relationship_Snapshot). Base del vínculo marca -> genérico.';
COMMENT ON COLUMN sct2.relationship.relationship_group IS
    'Agrupa relaciones que describen una misma característica. 0 = sin agrupar.';
COMMENT ON COLUMN sct2.relationship.type_id IS
    '116680003 = es un; 774159003 = laboratorio; 574941000221106 = condición de expendio.';

CREATE UNLOGGED TABLE sct2.stated_relationship (
    id                    BIGINT   NOT NULL,
    effective_time        DATE     NOT NULL,
    active                BOOLEAN  NOT NULL,
    module_id             BIGINT   NOT NULL,
    source_id             BIGINT   NOT NULL,
    destination_id        BIGINT   NOT NULL,
    relationship_group    INTEGER  NOT NULL,
    type_id               BIGINT   NOT NULL,
    characteristic_type_id BIGINT  NOT NULL,
    modifier_id           BIGINT   NOT NULL
);

COMMENT ON TABLE sct2.stated_relationship IS
    'Relaciones declaradas por el autor (sct2_StatedRelationship_Snapshot). Opcional.';

CREATE UNLOGGED TABLE sct2.text_definition (
    id                    BIGINT       NOT NULL,
    effective_time        DATE         NOT NULL,
    active                BOOLEAN      NOT NULL,
    module_id             BIGINT       NOT NULL,
    concept_id            BIGINT       NOT NULL,
    language_code         VARCHAR(10)  NOT NULL,
    type_id               BIGINT       NOT NULL,
    term                  TEXT         NOT NULL,
    case_significance_id  BIGINT       NOT NULL
);

COMMENT ON TABLE sct2.text_definition IS
    'Definiciones textuales de conceptos (sct2_TextDefinition_Snapshot). Opcional.';

CREATE UNLOGGED TABLE sct2.identifier (
    alternate_identifier   VARCHAR(255) NOT NULL,
    effective_time         DATE         NOT NULL,
    active                 BOOLEAN      NOT NULL,
    module_id              BIGINT       NOT NULL,
    identifier_scheme_id   BIGINT       NOT NULL,
    referenced_component_id BIGINT      NOT NULL
);

COMMENT ON TABLE sct2.identifier IS
    'Identificadores alternos vinculados a componentes SNOMED (sct2_Identifier_Snapshot). Opcional; suele venir vacío.';

CREATE UNLOGGED TABLE sct2.relationship_concrete (
    id                    BIGINT        NOT NULL,
    effective_time        DATE          NOT NULL,
    active                BOOLEAN       NOT NULL,
    module_id             BIGINT        NOT NULL,
    source_id             BIGINT        NOT NULL,
    concrete_value        VARCHAR(255)  NOT NULL,
    relationship_group    INTEGER       NOT NULL,
    type_id               BIGINT        NOT NULL,
    characteristic_type_id BIGINT       NOT NULL,
    modifier_id           BIGINT        NOT NULL
);

COMMENT ON TABLE sct2.relationship_concrete IS
    'Relaciones con valor concreto: dosis, cantidades y unidades (sct2_RelationshipConcreteValues_Snapshot). Opcional.';

-- =============================================================================
-- 2. Conjuntos de referencia (Snapshot/Refset)
-- =============================================================================

CREATE UNLOGGED TABLE sct2.refset_simple (
    id                      UUID     NOT NULL,
    effective_time          DATE     NOT NULL,
    active                  BOOLEAN  NOT NULL,
    module_id               BIGINT   NOT NULL,
    refset_id               BIGINT   NOT NULL,
    referenced_component_id BIGINT   NOT NULL
);

COMMENT ON TABLE sct2.refset_simple IS
    'Refsets simples: subconjuntos de conceptos (laboratorio, vacunas, odontología, ENO, dispositivos, etc.).';
COMMENT ON COLUMN sct2.refset_simple.refset_id IS
    'Concepto SNOMED que nombra el conjunto, p. ej. 537301000221103 = laboratorio Argentina.';

CREATE UNLOGGED TABLE sct2.refset_language (
    id                      UUID     NOT NULL,
    effective_time          DATE     NOT NULL,
    active                  BOOLEAN  NOT NULL,
    module_id               BIGINT   NOT NULL,
    refset_id               BIGINT   NOT NULL,
    referenced_component_id BIGINT   NOT NULL,
    acceptability_id        BIGINT   NOT NULL
);

COMMENT ON TABLE sct2.refset_language IS
    'Refsets de idioma: aceptabilidad de cada descripción (preferida o aceptable).';
COMMENT ON COLUMN sct2.refset_language.referenced_component_id IS
    'descriptionId, NO es un conceptId.';
COMMENT ON COLUMN sct2.refset_language.acceptability_id IS
    '900000000000548007 = preferido; 900000000000549004 = aceptable.';

CREATE UNLOGGED TABLE sct2.refset_attribute_value (
    id                      UUID     NOT NULL,
    effective_time          DATE     NOT NULL,
    active                  BOOLEAN  NOT NULL,
    module_id               BIGINT   NOT NULL,
    refset_id               BIGINT   NOT NULL,
    referenced_component_id BIGINT   NOT NULL,
    value_id                BIGINT   NOT NULL
);

COMMENT ON TABLE sct2.refset_attribute_value IS
    'Refsets de valor de atributo: etiquetan un componente con un valor de la jerarquía de metadatos.';

CREATE UNLOGGED TABLE sct2.refset_association (
    id                      UUID     NOT NULL,
    effective_time          DATE     NOT NULL,
    active                  BOOLEAN  NOT NULL,
    module_id               BIGINT   NOT NULL,
    refset_id               BIGINT   NOT NULL,
    referenced_component_id BIGINT   NOT NULL,
    target_component_id     BIGINT   NOT NULL
);

COMMENT ON TABLE sct2.refset_association IS
    'Refsets de asociación: reemplazos y vínculos entre componentes.';

CREATE UNLOGGED TABLE sct2.refset_simple_map (
    id                      UUID         NOT NULL,
    effective_time          DATE         NOT NULL,
    active                  BOOLEAN      NOT NULL,
    module_id               BIGINT       NOT NULL,
    refset_id               BIGINT       NOT NULL,
    referenced_component_id BIGINT       NOT NULL,
    map_target              VARCHAR(64)  NOT NULL
);

COMMENT ON TABLE sct2.refset_simple_map IS
    'Mapas simples SNOMED CT -> otro esquema, uno a uno (900000000000497000 = CIE-10).';

CREATE UNLOGGED TABLE sct2.refset_extended_map (
    id                      UUID          NOT NULL,
    effective_time          DATE          NOT NULL,
    active                  BOOLEAN       NOT NULL,
    module_id               BIGINT        NOT NULL,
    refset_id               BIGINT        NOT NULL,
    referenced_component_id BIGINT        NOT NULL,
    map_group               INTEGER       NOT NULL,
    map_priority            INTEGER       NOT NULL,
    map_rule                VARCHAR(512)  NOT NULL,
    map_advice              VARCHAR(512)  NOT NULL,
    map_target              VARCHAR(64)   NULL,
    correlation_id          BIGINT        NOT NULL,
    map_category_id         BIGINT        NOT NULL
);

COMMENT ON TABLE sct2.refset_extended_map IS
    'Mapas complejos SNOMED CT -> CIE-10 con reglas de selección (447562003).';
COMMENT ON COLUMN sct2.refset_extended_map.map_target IS
    'NULL = el concepto no tiene equivalencia en el esquema destino.';

CREATE UNLOGGED TABLE sct2.refset_medicinal_products (
    id                             UUID     NOT NULL,
    effective_time                 DATE     NOT NULL,
    active                         BOOLEAN  NOT NULL,
    module_id                      BIGINT   NOT NULL,
    refset_id                      BIGINT   NOT NULL,
    referenced_component_id        BIGINT   NOT NULL,
    referenced_component_id_rcd    BIGINT   NULL,
    referenced_component_id_cd_up  BIGINT   NULL,
    referenced_component_id_cd     BIGINT   NULL,
    referenced_component_id_mpf_only BIGINT NULL,
    referenced_component_id_mp_only  BIGINT NULL,
    reference_component_id_mp        BIGINT NULL
);

COMMENT ON TABLE sct2.refset_medicinal_products IS
    'Refset de productos medicinales del DNM (552511000221107). En 2026-08 está íntegramente inactivo.';

CREATE UNLOGGED TABLE sct2.refset_owl (
    id                      UUID     NOT NULL,
    effective_time          DATE     NOT NULL,
    active                  BOOLEAN  NOT NULL,
    module_id               BIGINT   NOT NULL,
    refset_id               BIGINT   NOT NULL,
    referenced_component_id BIGINT   NOT NULL,
    owl_expression          TEXT     NOT NULL
);

COMMENT ON TABLE sct2.refset_owl IS
    'Expresiones OWL en sintaxis funcional (sct2_sRefset_OWLExpressionSnapshot). Opcional.';

-- =============================================================================
-- 3. Comprobación final
-- =============================================================================

SELECT 'Esquema sct2 creado (' || count(*) || ' tablas). Siguiente paso: 02_carga.sql.'
       AS resultado
  FROM information_schema.tables
 WHERE table_schema = 'sct2';
