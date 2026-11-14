-- ==========================================================================
-- Origen Salud - Mantenimiento posterior a una carga masiva
--
-- Uso: ejecutar con AUTocommit activado (DBeaver: SQL Editor > Transaction
--      mode > Auto-commit). VACUUM no puede correr dentro de una transacción.
--
-- No modifica datos de negocio: solo refresca estadísticas y reclama espacio.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- 1. Estadísticas del planner
--    Después de importar RF2 (o cualquier catálogo grande) PostgreSQL necesita
--    estadísticas frescas para elegir bien los índices GIN.
-- --------------------------------------------------------------------------
ANALYZE snomed_concepts;
ANALYZE snomed_descriptions;
ANALYZE snomed_relationships;
ANALYZE cie10_codes;
ANALYZE cie10_descriptions;
ANALYZE map_snomed_cie10;
ANALYZE anmat_medicamentos;
ANALYZE laboratorio_practicas;
ANALYZE vacunas_catalogo;
ANALYZE odontologia_prestaciones;
ANALYZE prestaciones_medicas;
ANALYZE programas_sociales;
ANALYZE imagenes_practicas;

-- --------------------------------------------------------------------------
-- 2. Recuperar espacio y actualizar estadísticas
--    VACUUM (ANALYZE) es suficiente para cargas normales. Evitar VACUUM FULL
--    en producción: bloquea la tabla y requiere el doble de disco.
--    Ejecutar solo si la carga fue muy grande (millones de filas).
-- --------------------------------------------------------------------------
-- VACUUM (ANALYZE) snomed_descriptions;
-- VACUUM (ANALYZE) snomed_concepts;
-- VACUUM (ANALYZE) snomed_relationships;

-- --------------------------------------------------------------------------
-- 3. Estado de mantenimiento de las tablas
-- --------------------------------------------------------------------------
SELECT relname AS tabla,
       n_live_tup AS filas_estimadas,
       last_vacuum,
       last_autovacuum,
       last_analyze,
       last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;

-- --------------------------------------------------------------------------
-- 4. Tamaño en disco (incluye índices)
-- --------------------------------------------------------------------------
SELECT relname AS tabla,
       pg_size_pretty(pg_total_relation_size(relid)) AS tamano_total,
       pg_size_pretty(pg_relation_size(relid)) AS datos,
       pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS indices
FROM pg_catalog.pg_statio_user_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(relid) DESC;

-- --------------------------------------------------------------------------
-- 5. Uso real de índices
--    Ejecutar después de un período de tráfico. Un índice con idx_scan = 0
--    puede ser prescindible; no borrarlo sin medir el impacto de escritura.
-- --------------------------------------------------------------------------
SELECT relname AS tabla,
       indexrelname AS indice,
       idx_scan AS usos,
       idx_tup_read AS filas_leidas,
       idx_tup_fetch AS filas_recuperadas,
       pg_size_pretty(pg_relation_size(indexrelid)) AS tamano
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC, pg_relation_size(indexrelid) DESC;

-- --------------------------------------------------------------------------
-- 6. Verificación de plan de búsqueda
--    Confirmar que las búsquedas por trigramas usan los índices GIN y no un
--    Seq Scan sobre snomed_descriptions.
-- --------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT d.id, d.term
FROM snomed_descriptions d
INNER JOIN snomed_concepts c ON c.id = d.concept_id
WHERE d.active
  AND c.active
  AND d.language_code = 'es'
  AND d.term ILIKE '%infarto%'
ORDER BY similarity(d.term, 'infarto') DESC
LIMIT 20;
