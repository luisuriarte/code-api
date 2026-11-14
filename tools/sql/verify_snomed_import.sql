-- ==========================================================================
-- Origen Salud - Verificación de importación SNOMED-CT (RF2)
--
-- Uso: ejecutar en DBeaver / pgAdmin / psql después de importar los archivos
--      de conceptos, descripciones y relaciones.
--
-- Solo lectura: no modifica datos.
-- Esquema de referencia: sql/design.sql
-- ==========================================================================

-- --------------------------------------------------------------------------
-- 1. Volumen por tabla
-- --------------------------------------------------------------------------
SELECT 'snomed_concepts' AS tabla, count(*) AS filas FROM snomed_concepts
UNION ALL
SELECT 'snomed_descriptions', count(*) FROM snomed_descriptions
UNION ALL
SELECT 'snomed_relationships', count(*) FROM snomed_relationships;

-- --------------------------------------------------------------------------
-- 2. Distribución de activos / inactivos
-- --------------------------------------------------------------------------
SELECT 'concepts' AS tabla,
       count(*) FILTER (WHERE active) AS activos,
       count(*) FILTER (WHERE NOT active) AS inactivos
FROM snomed_concepts
UNION ALL
SELECT 'descriptions',
       count(*) FILTER (WHERE active),
       count(*) FILTER (WHERE NOT active)
FROM snomed_descriptions
UNION ALL
SELECT 'relationships',
       count(*) FILTER (WHERE active),
       count(*) FILTER (WHERE NOT active)
FROM snomed_relationships;

-- --------------------------------------------------------------------------
-- 3. Descripciones por idioma (debería incluir al menos es y en)
-- --------------------------------------------------------------------------
SELECT language_code, count(*) AS descripciones
FROM snomed_descriptions
GROUP BY language_code
ORDER BY descripciones DESC;

-- --------------------------------------------------------------------------
-- 4. Tipos de descripción
--    900000000000003001 = Fully Specified Name
--    900000000000013009 = Synonym
-- --------------------------------------------------------------------------
SELECT type_id, count(*) AS descripciones
FROM snomed_descriptions
GROUP BY type_id
ORDER BY descripciones DESC;

-- --------------------------------------------------------------------------
-- 5. Integridad referencial
--    Con las FK activas estos conteos deben ser 0. Si alguien cargó datos
--    con constraints deshabilitadas, acá aparecen los huérfanos.
-- --------------------------------------------------------------------------
SELECT count(*) AS descripciones_huerfanas
FROM snomed_descriptions d
LEFT JOIN snomed_concepts c ON c.id = d.concept_id
WHERE c.id IS NULL;

SELECT count(*) AS relaciones_huerfanas
FROM snomed_relationships r
LEFT JOIN snomed_concepts source ON source.id = r.source_id
LEFT JOIN snomed_concepts destination ON destination.id = r.destination_id
WHERE source.id IS NULL OR destination.id IS NULL;

-- --------------------------------------------------------------------------
-- 6. Calidad de términos
-- --------------------------------------------------------------------------
SELECT count(*) AS terminos_vacios
FROM snomed_descriptions
WHERE trim(term) = '';

SELECT count(*) AS terminos_con_espacios_al_borde
FROM snomed_descriptions
WHERE term <> trim(term);

-- --------------------------------------------------------------------------
-- 7. Conceptos activos sin ninguna descripción activa
--    Es informativo: SNOMED-CT puede tener conceptos sin descripciones en
--    una edición parcial o en un idioma puntual.
-- --------------------------------------------------------------------------
SELECT count(*) AS conceptos_activos_sin_descripcion
FROM snomed_concepts c
WHERE c.active
  AND NOT EXISTS (
      SELECT 1
      FROM snomed_descriptions d
      WHERE d.concept_id = c.id
        AND d.active
  );

-- --------------------------------------------------------------------------
-- 8. Fecha efectiva más reciente por tabla (para confirmar la release)
-- --------------------------------------------------------------------------
SELECT 'concepts' AS tabla, max(effective_time) AS ultima_fecha FROM snomed_concepts
UNION ALL
SELECT 'descriptions', max(effective_time) FROM snomed_descriptions
UNION ALL
SELECT 'relationships', max(effective_time) FROM snomed_relationships;

-- --------------------------------------------------------------------------
-- 9. Duplicados lógicos de descripciones activas
--    Un mismo término para el mismo concepto e idioma suele ser un error de
--    carga, aunque puede existir en ediciones parciales.
-- --------------------------------------------------------------------------
SELECT concept_id, language_code, term, count(*) AS repeticiones
FROM snomed_descriptions
WHERE active
GROUP BY concept_id, language_code, term
HAVING count(*) > 1
ORDER BY repeticiones DESC
LIMIT 50;

-- --------------------------------------------------------------------------
-- 10. Índices GIN de trigramas declarados en sql/design.sql
-- --------------------------------------------------------------------------
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
      'idx_descriptions_term_trgm',
      'idx_anmat_comercial_trgm',
      'idx_anmat_generico_trgm',
      'idx_lab_trgm',
      'idx_vacunas_trgm',
      'idx_odontologia_trgm',
      'idx_prestaciones_trgm',
      'idx_programas_trgm',
      'idx_imagenes_nombre_trgm'
  )
ORDER BY tablename, indexname;

-- --------------------------------------------------------------------------
-- 11. Extensión pg_trgm habilitada
-- --------------------------------------------------------------------------
SELECT extname, extversion
FROM pg_extension
WHERE extname = 'pg_trgm';
