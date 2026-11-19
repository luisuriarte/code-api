-- =============================================================================
-- VERIFICACIÓN DE LA FASE 4 (§16) · relaciones y mapeos generales
-- =============================================================================
-- Solo lectura. BEGIN READ_ONLY / ROLLBACK: no escribe en la base.
-- Ejecutar después de sql/08_arquitectura/fase3_relaciones_mapeos.sql:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
--     -f sql/08_arquitectura/verificacion_fase4.sql
--
-- El nombre del archivo de migración conserva la numeración histórica; según
-- §16 esta es la Fase 4. Ver sql/08_arquitectura/README.md.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN READ ONLY;

\echo '========== 1. Tablas de referencia de la Fase 1 =========='
SELECT tablename
  FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN ('os_relation_kind', 'os_review_state', 'os_relation_type')
 ORDER BY tablename;

\echo '========== 2. Columnas nuevas en os_catalog_relation (debe ser 13) =========='
SELECT count(*) AS columnas_presentes
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'os_catalog_relation'
   AND column_name IN (
       'valid_from', 'valid_to', 'source_catalog_id', 'source_release_id',
       'target_catalog_id', 'target_release_id', 'relation_kind',
       'mapping_method', 'confidence_level', 'reviewed_by', 'reviewed_at',
       'license_reference', 'inverse_relation_type'
   );

\echo '========== 3. Constraints e índices nuevos =========='
SELECT conname
  FROM pg_constraint
 WHERE conrelid = to_regclass('public.os_catalog_relation')
   AND conname IN (
       'fk_ocr_source_catalog', 'fk_ocr_target_catalog',
       'fk_ocr_source_release', 'fk_ocr_target_release',
       'fk_ocr_relation_kind', 'ck_ocr_validity'
   )
 ORDER BY conname;

SELECT indexname
  FROM pg_indexes
 WHERE schemaname = 'public'
   AND tablename = 'os_catalog_relation'
   AND indexname IN ('idx_ocr_validity', 'idx_ocr_kind')
 ORDER BY indexname;

\echo '========== 4. Integridad de las 603 relaciones preexistentes =========='
-- Esperado: 603 relaciones, 15 tipos, 0 kinds inválidos, 0 vigencias inválidas.
SELECT count(*) AS relaciones,
       count(DISTINCT relation_type) AS tipos,
       count(*) FILTER (
           WHERE relation_kind IS NULL
              OR relation_kind NOT IN (SELECT code FROM os_relation_kind)
       ) AS kinds_invalidos,
       count(*) FILTER (
           WHERE valid_to IS NOT NULL
             AND valid_from IS NOT NULL
             AND valid_to <= valid_from
       ) AS vigencias_invalidas
  FROM os_catalog_relation;

\echo '========== 5. Tablas nuevas creadas =========='
SELECT tablename
  FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN ('os_mapping_metadata', 'os_terminology_system_alias')
 ORDER BY tablename;

\echo '========== 6. Alias derivados de coincidencia exacta (0 filas) =========='
SELECT a.alias_system_code, c.code AS canonical_code
  FROM os_terminology_system_alias a
  JOIN os_terminology_system c ON c.id = a.canonical_system_id
 WHERE a.alias_system_code <> c.code;

\echo '========== 7. DEFAULT de review_status en os_concept_mapping =========='
-- Debe devolver 'draft'::character varying. Las filas existentes no cambiaron.
SELECT column_default
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'os_concept_mapping'
   AND column_name = 'review_status';

\echo '========== 8. DEFAULT ACL: grantees no deseados (0 filas) =========='
-- tras la Fase 1; las fases posteriores deben aplicar el mismo criterio.
SELECT table_name, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND table_name IN ('os_mapping_metadata', 'os_terminology_system_alias')
   AND grantee IN ('origen_admin', 'PUBLIC')
 ORDER BY table_name, grantee, privilege_type;

\echo '========== 9. Navegabilidad (decisión 10) =========='
-- Huérfanos: debe ser 0. itemRelations() solo puede mostrar relaciones cuyos
-- extremos existan en os_catalog_item.
SELECT count(*) AS relaciones_huerfanas
  FROM os_catalog_relation r
  LEFT JOIN os_catalog_item si ON si.id = r.source_item_id
  LEFT JOIN os_catalog_item ti ON ti.id = r.target_item_id
 WHERE si.id IS NULL OR ti.id IS NULL;

-- Informativo: relaciones con ambos extremos en catálogos activos y en un
-- domain_type que osCatalogResultKey() puede convertir en enlace navegable.
SELECT count(*) AS relaciones_navegables
  FROM os_catalog_relation r
  JOIN os_catalog_item si ON si.id = r.source_item_id
  JOIN os_catalog sc ON sc.id = si.catalog_id AND sc.is_active
  JOIN os_catalog_item ti ON ti.id = r.target_item_id
  JOIN os_catalog tc ON tc.id = ti.catalog_id AND tc.is_active
 WHERE sc.domain_type IN ('dental', 'biochemical', 'medical', 'mental_health', 'rehabilitation', 'pharma')
   AND tc.domain_type IN ('dental', 'biochemical', 'medical', 'mental_health', 'rehabilitation', 'pharma');

\echo '========== 10. Conteo por tipo (informativo) =========='
SELECT relation_type, count(*) AS filas
  FROM os_catalog_relation
 GROUP BY relation_type
 ORDER BY relation_type;

ROLLBACK;
