-- =============================================================================
-- Origen Salud · Diagnóstico de visibilidad de un término de OFTAR-DX
-- sql/03_oftar/diagnostico_visibilidad_oftar_dx.sql
-- =============================================================================
-- No modifica datos: BEGIN READ ONLY / ROLLBACK.
--   sudo -u postgres psql -d origen_codes \
--     -f sql/03_oftar/diagnostico_visibilidad_oftar_dx.sql
--
-- Cambiá :codigo por otro CIE-10 si querés verificar otro diagnóstico.
-- =============================================================================
\set codigo 'H40.1110'

BEGIN READ ONLY;

SET client_encoding = 'UTF8';

\echo '=== 0A. Código externo -> permanente OFTAR-DX ==='
SELECT m.external_code, d.code AS permanent_code, d.clinical_name, d.status
  FROM public.oftar_diagnosis_mapping m
  JOIN public.oftar_diagnosis d ON d.id = m.diagnosis_id
 WHERE m.external_code = :'codigo';

\echo '=== 0B. Cómo viene el código en la fuente CIE-10 ==='
SELECT c.codigo, c.tipo
  FROM public.cie10_codes c
 WHERE c.codigo LIKE :'codigo' || '%'
 ORDER BY c.codigo;

\echo '=== 1. Ítem en el motor de catálogos ==='
SELECT i.id, i.permanent_code, cat.code AS catalog_code
  FROM public.os_catalog_item i
  JOIN public.os_catalog cat ON cat.id = i.catalog_id
  JOIN public.os_catalog_identifier ident ON ident.item_id = i.id
 WHERE ident.value = :'codigo';

\echo '=== 2. Identificadores del motor ==='
SELECT ident.item_id, ident.system_name, ident.value, ident.is_primary
  FROM public.os_catalog_identifier ident
 WHERE ident.value = :'codigo';

\echo '=== 3. Versiones del ítem ==='
SELECT iv.id, iv.item_id, iv.language_code, iv.preferred_term, iv.review_status
  FROM public.os_catalog_item_version iv
 WHERE iv.item_id IN (
       SELECT ident.item_id
         FROM public.os_catalog_identifier ident
        WHERE ident.value = :'codigo'
 )
 ORDER BY iv.language_code;

\echo '=== 4. Revisiones de campo de esas versiones ==='
SELECT f.target_table, f.target_id, f.field_name, f.language_code,
       f.review_status, f.provenance, f.scope_release_id
  FROM public.os_field_review f
 WHERE f.target_table = 'os_catalog_item_version'
   AND f.target_id IN (
       SELECT iv.id
         FROM public.os_catalog_item_version iv
        WHERE iv.item_id IN (
              SELECT ident.item_id
                FROM public.os_catalog_identifier ident
               WHERE ident.value = :'codigo'
        )
   )
 ORDER BY f.field_name, f.language_code;

\echo '=== 5. Verificación final (filas publicables; hash_valido debe ser t) ==='
SELECT i.permanent_code,
       ident.value AS official_code,
       iv.language_code,
       iv.preferred_term,
       iv.review_status AS version_status,
       f.review_status AS field_status,
       f.content_hash = md5(
           iv.preferred_term || E'\x1f' || f.language_code || E'\x1f'
           || COALESCE(f.source_reference, '')
       ) AS hash_valido
  FROM public.os_catalog_item i
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
  JOIN public.os_catalog_identifier ident ON ident.item_id = i.id
  JOIN public.os_catalog_item_version iv ON iv.item_id = i.id
  JOIN public.os_field_review f
         ON f.target_table = 'os_catalog_item_version'
        AND f.target_id = iv.id
        AND f.field_name = 'preferred_term'
 WHERE ident.value = :'codigo'
   AND iv.review_status = 'approved'
   AND f.review_status = 'approved';

\echo '=== 6. Totales generales de aprobación (control) ==='
SELECT f.field_name, f.review_status, count(*) AS revisiones
  FROM public.os_field_review f
 WHERE f.provenance = 'imported_cie10'
 GROUP BY f.field_name, f.review_status
 ORDER BY f.field_name, f.review_status;

ROLLBACK;
