-- =============================================================================
-- Origen Salud · SNOMED CT Edición Argentina · PostgreSQL 18
-- 99_verificacion.sql :: controles de la carga
-- =============================================================================
--
-- QUÉ HACE
--   Sólo lee datos y devuelve una columna `estado` con OK o REVISAR para cada
--   control. Para los bloques opcionales (04 y 05) usa una tabla temporal de
--   sesión; no modifica ninguna tabla permanente.
--
-- CUÁNDO EJECUTARLO
--   Después de 03_postcarga.sql. Si se ejecutaron 04_codigos_opcional.sql o
--   05_map_excel.sql, sus controles se agregan automáticamente; si no, se
--   informan como "sin ejecutar".
--
-- CONTEOS DE REFERENCIA
--   Los valores esperados corresponden a la Edición Argentina 2026-08-20.
--   Si se cargó otra release, actualizá el bloque `expected` o interpretá los
--   REVISAR como diferencias normales de la edición. El resto de los controles
--   (integridad, cobertura, publicación) es independiente de la release.
-- =============================================================================

SET client_encoding = 'UTF8';

DO $$
BEGIN
    IF to_regclass('sct2.concept') IS NULL THEN
        RAISE EXCEPTION 'No existe el esquema sct2. Ejecutá 01_esquema.sql, 02_carga.sql y 03_postcarga.sql.';
    END IF;
END $$;

-- =============================================================================
-- 1. Volumen por tabla contra la edición de referencia 2026-08-20
-- =============================================================================

WITH expected (table_name, expected_rows) AS (
    VALUES
        ('concept',                 600374::bigint),
        ('description',            3337073::bigint),
        ('relationship',           4087686::bigint),
        ('stated_relationship',    1172419::bigint),
        ('text_definition',          29051::bigint),
        ('identifier',                   0::bigint),
        ('relationship_concrete',   152675::bigint),
        ('refset_simple',           120740::bigint),
        ('refset_language',        6394288::bigint),
        ('refset_attribute_value', 1045476::bigint),
        ('refset_association',      227886::bigint),
        ('refset_simple_map',       562075::bigint),
        ('refset_extended_map',     217373::bigint),
        ('refset_medicinal_products',19068::bigint),
        ('refset_owl',              520295::bigint)
),
actual (table_name, rows) AS (
    SELECT 'concept',                  count(*) FROM sct2.concept
    UNION ALL SELECT 'description',            count(*) FROM sct2.description
    UNION ALL SELECT 'relationship',           count(*) FROM sct2.relationship
    UNION ALL SELECT 'stated_relationship',    count(*) FROM sct2.stated_relationship
    UNION ALL SELECT 'text_definition',        count(*) FROM sct2.text_definition
    UNION ALL SELECT 'identifier',             count(*) FROM sct2.identifier
    UNION ALL SELECT 'relationship_concrete',  count(*) FROM sct2.relationship_concrete
    UNION ALL SELECT 'refset_simple',          count(*) FROM sct2.refset_simple
    UNION ALL SELECT 'refset_language',        count(*) FROM sct2.refset_language
    UNION ALL SELECT 'refset_attribute_value', count(*) FROM sct2.refset_attribute_value
    UNION ALL SELECT 'refset_association',     count(*) FROM sct2.refset_association
    UNION ALL SELECT 'refset_simple_map',      count(*) FROM sct2.refset_simple_map
    UNION ALL SELECT 'refset_extended_map',    count(*) FROM sct2.refset_extended_map
    UNION ALL SELECT 'refset_medicinal_products', count(*) FROM sct2.refset_medicinal_products
    UNION ALL SELECT 'refset_owl',             count(*) FROM sct2.refset_owl
)
SELECT a.table_name                                  AS tabla,
       a.rows                                        AS filas,
       e.expected_rows                               AS esperado_2026_08_20,
       CASE
           WHEN e.expected_rows IS NULL       THEN 'sin referencia'
           WHEN a.rows = e.expected_rows      THEN 'OK'
           ELSE 'REVISAR'
       END                                           AS estado
  FROM actual a
  LEFT JOIN expected e USING (table_name)
 ORDER BY a.table_name;

-- =============================================================================
-- 2. Integridad del Snapshot
-- =============================================================================

SELECT control, fallas, CASE WHEN fallas = 0 THEN 'OK' ELSE 'REVISAR' END AS estado
  FROM (
        SELECT 'descripciones sin concepto' AS control,
               count(*) AS fallas
          FROM sct2.description d
         WHERE NOT EXISTS (SELECT 1 FROM sct2.concept c WHERE c.id = d.concept_id)

        UNION ALL

        SELECT 'relaciones con origen inexistente',
               count(*)
          FROM sct2.relationship r
         WHERE NOT EXISTS (SELECT 1 FROM sct2.concept c WHERE c.id = r.source_id)

        UNION ALL

        SELECT 'relaciones con destino inexistente',
               count(*)
          FROM sct2.relationship r
         WHERE NOT EXISTS (SELECT 1 FROM sct2.concept c WHERE c.id = r.destination_id)

        UNION ALL

        SELECT 'descripciones con término vacío',
               count(*)
          FROM sct2.description
         WHERE btrim(term) = ''

        UNION ALL

        SELECT 'descripciones con idioma fuera de es/en',
               count(*)
          FROM sct2.description
         WHERE split_part(language_code, '-', 1) NOT IN ('es', 'en')

        UNION ALL

        SELECT 'conceptos activos sin descripción activa',
               count(*)
          FROM sct2.concept c
         WHERE c.active
           AND NOT EXISTS (
               SELECT 1
                 FROM sct2.description d
                WHERE d.concept_id = c.id
                  AND d.active
           )
       ) controles
 ORDER BY control;

-- =============================================================================
-- 3. Tablas derivadas
-- =============================================================================

SELECT control, valor, CASE WHEN valor = 0 THEN 'OK' ELSE 'REVISAR' END AS estado
  FROM (
        SELECT 'conceptos activos sin término preferido' AS control,
               count(*) AS valor
          FROM sct2.concept c
         WHERE c.active
           AND NOT EXISTS (
               SELECT 1 FROM sct2.preferred_term p WHERE p.concept_id = c.id
           )

        UNION ALL

        SELECT 'términos preferidos con texto vacío',
               count(*)
          FROM sct2.preferred_term
         WHERE btrim(term) = ''

        UNION ALL

        SELECT 'términos preferidos que no son de un concepto activo',
               count(*)
          FROM sct2.preferred_term p
         WHERE NOT EXISTS (
               SELECT 1 FROM sct2.concept c WHERE c.id = p.concept_id AND c.active
         )

        UNION ALL

        SELECT 'descripciones con más de un idioma efectivo',
               count(*)
          FROM (
                SELECT referenced_component_id
                  FROM sct2.language_effective
                 GROUP BY referenced_component_id
                HAVING count(*) > 1
               ) duplicados

        UNION ALL

        SELECT 'refsets sin nombre en el catálogo',
               count(*)
          FROM sct2.refset_summary
         WHERE name IS NULL
       ) controles
 ORDER BY control;

-- =============================================================================
-- 3.b Tablas derivadas del DNM (genéricos y marcas)
-- =============================================================================

SELECT control, valor, CASE WHEN valor = 0 THEN 'OK' ELSE 'REVISAR' END AS estado
  FROM (
        SELECT 'genéricos sin concepto SNOMED' AS control,
               count(*) AS valor
          FROM sct2.generic_drug g
         WHERE NOT EXISTS (SELECT 1 FROM sct2.concept c WHERE c.id = g.concept_id)

        UNION ALL

        SELECT 'genéricos con forma farmacéutica inexistente',
               count(*)
          FROM sct2.generic_drug g
         WHERE g.pharmaceutical_form_id IS NOT NULL
           AND NOT EXISTS (
               SELECT 1 FROM sct2.concept c WHERE c.id = g.pharmaceutical_form_id
           )

        UNION ALL

        SELECT 'marcas sin concepto SNOMED',
               count(*)
          FROM sct2.brand_generic b
         WHERE NOT EXISTS (SELECT 1 FROM sct2.concept c WHERE c.id = b.brand_id)

        UNION ALL

        SELECT 'marcas con genérico inexistente',
               count(*)
          FROM sct2.brand_generic b
         WHERE b.generic_id IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM sct2.concept c WHERE c.id = b.generic_id)
       ) controles
 ORDER BY control;

-- Volumen de las tablas derivadas. No son fallas: sirven para comparar con la
-- release cargada.
SELECT 'genéricos prescribibles' AS tabla, count(*) AS filas FROM sct2.generic_drug
UNION ALL
SELECT 'marcas comerciales', count(*) FROM sct2.brand_generic
UNION ALL
SELECT 'marcas con genérico resuelto', count(*) FROM sct2.brand_generic WHERE generic_id IS NOT NULL
UNION ALL
SELECT 'marcas comercializadas', count(*) FROM sct2.brand_generic WHERE commercialized;

-- =============================================================================
-- 4. Publicación en las tablas de la aplicación
-- =============================================================================

SELECT control, valor, esperado, CASE WHEN cumple THEN 'OK' ELSE 'REVISAR' END AS estado
  FROM (
        SELECT 'conceptos activos publicados' AS control,
               (SELECT count(*) FROM snomed_concepts WHERE active) AS valor,
               (SELECT count(*) FROM sct2.concept WHERE active)  AS esperado,
               (SELECT count(*) FROM snomed_concepts WHERE active)
                   = (SELECT count(*) FROM sct2.concept WHERE active) AS cumple

        UNION ALL

        SELECT 'descripciones publicadas',
               (SELECT count(*) FROM snomed_descriptions),
               (SELECT count(*) FROM sct2.description),
               (SELECT count(*) FROM snomed_descriptions)
                   = (SELECT count(*) FROM sct2.description)

        UNION ALL

        SELECT 'relaciones publicadas',
               (SELECT count(*) FROM snomed_relationships),
               (SELECT count(*) FROM sct2.relationship),
               (SELECT count(*) FROM snomed_relationships)
                   = (SELECT count(*) FROM sct2.relationship)

        UNION ALL

        SELECT 'descripciones publicadas sin concepto',
               (SELECT count(*)
                  FROM snomed_descriptions d
                 WHERE NOT EXISTS (
                       SELECT 1 FROM snomed_concepts c WHERE c.id = d.concept_id
                 )),
               0,
               NOT EXISTS (
                   SELECT 1
                     FROM snomed_descriptions d
                    WHERE NOT EXISTS (
                          SELECT 1 FROM snomed_concepts c WHERE c.id = d.concept_id
                    )
               )

        UNION ALL

        SELECT 'mapeos SNOMED/CIE-10 publicados',
               (SELECT count(*) FROM map_snomed_cie10),
               (SELECT count(*)
                  FROM (
                        SELECT DISTINCT sc.id, c.id
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
                       ) pares),
               (SELECT count(*) FROM map_snomed_cie10)
                   = (SELECT count(*)
                        FROM (
                              SELECT DISTINCT sc.id, c.id
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
                             ) pares)
       ) controles;

-- =============================================================================
-- 5. Catálogos clínicos derivados de los refsets
-- =============================================================================

SELECT catalogo, filas, minimo_2026_08_20 AS minimo,
       CASE WHEN filas >= minimo_2026_08_20 THEN 'OK' ELSE 'REVISAR' END AS estado
  FROM (
        SELECT 'laboratorio_practicas' AS catalogo,
               count(*) AS filas,
               1007::bigint AS minimo_2026_08_20
          FROM laboratorio_practicas

        UNION ALL

        SELECT 'vacunas_catalogo', count(*), 407 FROM vacunas_catalogo
        UNION ALL
        SELECT 'odontologia_prestaciones', count(*), 462 FROM odontologia_prestaciones
        UNION ALL
        SELECT 'prestaciones_medicas', count(*), 2143 FROM prestaciones_medicas
        UNION ALL
        SELECT 'imagenes_practicas', count(*), 579 FROM imagenes_practicas
       ) catalogs
 ORDER BY catalogo;

-- =============================================================================
-- 6. Índices críticos
-- =============================================================================

SELECT control,
       encontrados,
       CASE WHEN encontrados > 0 THEN 'OK' ELSE 'REVISAR' END AS estado
  FROM (
        SELECT 'GIN trigram de sct2.description.term' AS control,
               count(*) AS encontrados
          FROM pg_indexes
         WHERE schemaname = 'sct2'
           AND indexname = 'sct2_description_term_trgm'

        UNION ALL

        SELECT 'GIN trigram de sct2.preferred_term.term',
               count(*)
          FROM pg_indexes
         WHERE schemaname = 'sct2'
           AND indexname = 'sct2_preferred_term_term_trgm'

        UNION ALL

        SELECT 'único de sct2.concept.id',
               count(*)
          FROM pg_indexes
         WHERE schemaname = 'sct2'
           AND indexname = 'sct2_concept_id_uq'

        UNION ALL

        SELECT 'único de sct2.description.id',
               count(*)
          FROM pg_indexes
         WHERE schemaname = 'sct2'
           AND indexname = 'sct2_description_id_uq'

        UNION ALL

        SELECT 'único de sct2.relationship.id',
               count(*)
          FROM pg_indexes
         WHERE schemaname = 'sct2'
           AND indexname = 'sct2_relationship_id_uq'
       ) indices
 ORDER BY control;

-- =============================================================================
-- 7. Cobertura de los refsets nominados en el catálogo
-- =============================================================================

SELECT c.refset_id,
       c.name                                   AS nombre,
       c.category                               AS categoria,
       c.filter_code                            AS filtro,
       coalesce(s.active_members, 0)            AS activos,
       coalesce(s.total_members, 0)             AS totales,
       CASE
           WHEN s.refset_id IS NULL THEN 'REVISAR'
           WHEN coalesce(s.active_members, 0) = 0 THEN 'REVISAR'
           ELSE 'OK'
       END                                      AS estado
  FROM public.sct2_refset_catalog c
  LEFT JOIN sct2.refset_summary s USING (refset_id)
 WHERE c.filter_code IS NOT NULL
 ORDER BY c.category, c.name;

-- =============================================================================
-- 8. Artefactos opcionales: 04 (refsets publicados) y 05 (mapas NBU/GTIN)
-- =============================================================================

CREATE TEMP TABLE IF NOT EXISTS verificacion_opcional (
    bloque   VARCHAR(8)  NOT NULL,
    control  TEXT        NOT NULL,
    valor    BIGINT      NOT NULL,
    esperado BIGINT      NOT NULL,
    estado   VARCHAR(16) NOT NULL
);

TRUNCATE verificacion_opcional;

DO $$
DECLARE
    v_valor    BIGINT;
    v_esperado BIGINT;
BEGIN
    -- 04_codigos_opcional.sql
    IF to_regclass('public.snomed_refset_member') IS NOT NULL THEN
        EXECUTE 'SELECT count(*) FROM public.snomed_refset_member'
           INTO v_valor;

        SELECT count(*)
          INTO v_esperado
          FROM (
                SELECT DISTINCT ON (m.refset_id, m.concept_id)
                       m.refset_id, m.concept_id
                  FROM (
                        SELECT refset_id, referenced_component_id AS concept_id
                          FROM sct2.refset_simple
                        UNION ALL
                        SELECT refset_id, referenced_component_id
                          FROM sct2.refset_simple_map
                       ) m
                  JOIN public.sct2_refset_catalog cat
                    ON cat.refset_id = m.refset_id
                   AND cat.filter_code IS NOT NULL
                 ORDER BY m.refset_id, m.concept_id
               ) publicables;

        INSERT INTO verificacion_opcional VALUES (
            '04',
            'miembros publicados en snomed_refset_member',
            v_valor,
            v_esperado,
            CASE WHEN v_valor = v_esperado THEN 'OK' ELSE 'REVISAR' END
        );

        EXECUTE $q$
            SELECT count(*)
              FROM public.snomed_refset_member m
             WHERE NOT EXISTS (
                   SELECT 1 FROM public.snomed_concepts c WHERE c.id = m.concept_id
             )
        $q$ INTO v_valor;

        INSERT INTO verificacion_opcional VALUES (
            '04',
            'miembros publicados sin concepto',
            v_valor,
            0,
            CASE WHEN v_valor = 0 THEN 'OK' ELSE 'REVISAR' END
        );
    ELSE
        INSERT INTO verificacion_opcional VALUES (
            '04', 'publicación de refsets (opcional)', 0, 0, 'sin ejecutar'
        );
    END IF;

    -- 05_map_excel.sql · NBU
    IF to_regclass('sct2.map_nbu') IS NOT NULL THEN
        EXECUTE 'SELECT count(*) FROM sct2.map_nbu' INTO v_valor;

        INSERT INTO verificacion_opcional VALUES (
            '05',
            'filas del mapeo NBU',
            v_valor,
            425,
            CASE WHEN v_valor > 0 THEN 'OK' ELSE 'REVISAR' END
        );

        EXECUTE $q$
            SELECT count(*)
              FROM sct2.map_nbu n
             WHERE NOT EXISTS (
                   SELECT 1 FROM sct2.concept c WHERE c.id = n.sctid
             )
        $q$ INTO v_valor;

        INSERT INTO verificacion_opcional VALUES (
            '05',
            'NBU sin concepto SNOMED',
            v_valor,
            0,
            CASE WHEN v_valor = 0 THEN 'OK' ELSE 'REVISAR' END
        );
    ELSE
        INSERT INTO verificacion_opcional VALUES (
            '05', 'mapeo NBU (opcional)', 0, 0, 'sin ejecutar'
        );
    END IF;

    -- 05_map_excel.sql · GTIN
    IF to_regclass('sct2.map_gtin') IS NOT NULL THEN
        EXECUTE 'SELECT count(*) FROM sct2.map_gtin' INTO v_valor;

        INSERT INTO verificacion_opcional VALUES (
            '05',
            'filas del mapeo GTIN',
            v_valor,
            15500,
            CASE WHEN v_valor > 0 THEN 'OK' ELSE 'REVISAR' END
        );

        EXECUTE $q$
            SELECT count(*)
              FROM sct2.map_gtin g
             WHERE NOT EXISTS (
                   SELECT 1 FROM sct2.concept c WHERE c.id = g.rpcd_id
             )
        $q$ INTO v_valor;

        INSERT INTO verificacion_opcional VALUES (
            '05',
            'GTIN sin presentación SNOMED',
            v_valor,
            0,
            CASE WHEN v_valor = 0 THEN 'OK' ELSE 'REVISAR' END
        );
    ELSE
        INSERT INTO verificacion_opcional VALUES (
            '05', 'mapeo GTIN (opcional)', 0, 0, 'sin ejecutar'
        );
    END IF;
END $$;

SELECT bloque, control, valor, esperado, estado
  FROM verificacion_opcional
 ORDER BY bloque, control;

-- =============================================================================
-- 9. Refsets de la release (los 25 con más miembros activos)
-- =============================================================================

SELECT refset_id,
       coalesce(name, 'Refset ' || refset_id) AS nombre,
       category                               AS categoria,
       active_members                         AS activos,
       total_members                          AS totales
  FROM sct2.refset_summary
 ORDER BY active_members DESC, refset_id
 LIMIT 25;

-- =============================================================================
-- 10. Muestra de términos preferidos (control visual de acentos y UTF-8)
-- =============================================================================

SELECT p.concept_id,
       left(p.term, 100) AS termino,
       p.language_code   AS idioma
  FROM sct2.preferred_term p
 ORDER BY p.term
 LIMIT 20;
