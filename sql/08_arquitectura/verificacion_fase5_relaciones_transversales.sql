-- =============================================================================
-- Verificación READ ONLY del modelo transversal de relaciones
-- sql/08_arquitectura/verificacion_fase5_relaciones_transversales.sql
-- No escribe. Se ejecuta antes y después del DDL y de las semillas autorizadas.
-- Antes del DDL, relation_type_code no existe: la consulta correspondiente se
-- omite con \if en lugar de fallar. Después del DDL, se ejecuta normalmente.
-- =============================================================================

BEGIN READ ONLY;

SET LOCAL client_encoding = 'UTF8';

SELECT
    to_regclass('public.os_catalog_relation') AS relation_table,
    to_regclass('public.os_relation_type')    AS type_table,
    to_regclass('public.os_relation_kind')    AS kind_table;

SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'os_catalog_relation'
   AND column_name IN ('relation_type', 'relation_type_code', 'relation_kind',
                       'valid_from', 'valid_to', 'source_catalog_id',
                       'target_catalog_id', 'source_release_id', 'target_release_id')
 ORDER BY column_name;

SELECT conname, pg_get_constraintdef(oid) AS definition
  FROM pg_constraint
 WHERE conrelid = 'public.os_catalog_relation'::regclass
   AND conname IN ('fk_ocr_relation_type_code');

SELECT EXISTS (
    SELECT 1
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'os_catalog_relation'
       AND column_name = 'relation_type_code'
) AS has_relation_type_code \gset

\if :has_relation_type_code
SELECT count(*) AS relaciones_totales,
       count(DISTINCT relation_type) AS tipos_heredados,
       count(*) FILTER (WHERE relation_type_code IS NOT NULL) AS con_tipo_gobernado,
       count(*) FILTER (WHERE relation_type = 'referencia_literal') AS referencias_literales
  FROM public.os_catalog_relation;
\else
SELECT count(*) AS relaciones_totales,
       count(DISTINCT relation_type) AS tipos_heredados,
       NULL::bigint AS con_tipo_gobernado,
       count(*) FILTER (WHERE relation_type = 'referencia_literal') AS referencias_literales
  FROM public.os_catalog_relation;
\endif

SELECT count(*) AS tipos_oftar
  FROM public.os_relation_type
 WHERE source = 'OFTAR-v1.0';

SELECT code, relation_kind, inverse_code
  FROM public.os_relation_type
 WHERE source = 'OFTAR-v1.0'
 ORDER BY code;

SELECT count(*) AS inversas_declaradas
  FROM public.os_relation_type
 WHERE source = 'OFTAR-v1.0'
   AND inverse_code IS NOT NULL;

SELECT count(*) AS huérfanos
  FROM public.os_catalog_relation r
  LEFT JOIN public.os_catalog_item s ON s.id = r.source_item_id
  LEFT JOIN public.os_catalog_item t ON t.id = r.target_item_id
 WHERE s.id IS NULL OR t.id IS NULL;

ROLLBACK;
