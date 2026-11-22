-- =============================================================================
-- Origen Salud · Verificación de solo lectura de la aprobación de términos
-- sql/03_oftar/verificacion_aprobacion_oftar_dx.sql
-- =============================================================================
-- No modifica datos: BEGIN READ ONLY / ROLLBACK.
--   sudo -u postgres psql -d origen_codes -f sql/03_oftar/verificacion_aprobacion_oftar_dx.sql
-- =============================================================================
BEGIN READ ONLY;

SET client_encoding = 'UTF8';

\echo '=== 1. Estado de las revisiones de campo importadas ==='
SELECT f.field_name, f.review_status, count(*) AS revisiones
  FROM public.os_field_review f
 WHERE f.provenance = 'imported_cie10'
 GROUP BY f.field_name, f.review_status
 ORDER BY f.field_name, f.review_status;

\echo '=== 2. Estado de las versiones de oftar-dx ==='
SELECT iv.review_status, iv.language_code, count(*) AS versiones
  FROM public.os_catalog_item_version iv
  JOIN public.os_catalog_item i ON i.id = iv.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
 GROUP BY iv.review_status, iv.language_code
 ORDER BY iv.review_status, iv.language_code;

\echo '=== 3. Hashes vigentes de preferred_term aprobados (debe ser 0 inválidos) ==='
SELECT count(*) AS hashes_invalidos
  FROM public.os_field_review f
  JOIN public.os_catalog_item_version iv ON iv.id = f.target_id
 WHERE f.provenance = 'imported_cie10'
   AND f.field_name = 'preferred_term'
   AND f.review_status = 'approved'
   AND f.content_hash IS DISTINCT FROM
       md5(iv.preferred_term || E'\x1f' || f.language_code || E'\x1f'
           || COALESCE(f.source_reference, ''));

\echo '=== 4. definition y external_display NO deben estar aprobados ==='
SELECT count(*) AS definition_aprobados
  FROM public.os_field_review f
 WHERE f.provenance = 'imported_cie10'
   AND f.field_name = 'definition'
   AND f.review_status = 'approved';

SELECT count(*) AS external_display_aprobados
  FROM public.os_field_review f
 WHERE f.provenance = 'imported_cie10'
   AND f.field_name = 'external_display'
   AND f.review_status = 'approved';

\echo '=== 5. Eventos append-only de aprobación ==='
SELECT target_table, event_type, action, count(*) AS eventos
  FROM public.os_translation_review
 WHERE application_user_id = 'oftar_cie10_editorial_approval'
 GROUP BY target_table, event_type, action
 ORDER BY target_table, event_type, action;

\echo '=== 6. Conteo final y aserción ==='
DO $$
DECLARE
    v_esperados INT;
    v_aprobados INT;
    v_definition_pendientes INT;
    v_external_display_pendientes INT;
    v_versiones_aprobadas INT;
    v_hashes_invalidos INT;
    v_no_debian_aprobarse INT;
    v_eventos INT;
BEGIN
    SELECT count(*) INTO v_esperados
      FROM public.oftar_diagnosis d
      JOIN public.oftar_diagnosis_term dt
             ON dt.diagnosis_id = d.id AND dt.term_type = 'preferred'
     WHERE dt.language IN ('es-AR', 'en');

    SELECT count(*) INTO v_aprobados
      FROM public.os_field_review f
     WHERE f.provenance = 'imported_cie10'
       AND f.field_name = 'preferred_term'
       AND f.review_status = 'approved';

    SELECT count(*) INTO v_definition_pendientes
      FROM public.os_field_review f
     WHERE f.provenance = 'imported_cie10'
       AND f.field_name = 'definition'
       AND f.review_status = 'unknown';

    SELECT count(*) INTO v_external_display_pendientes
      FROM public.os_field_review f
     WHERE f.provenance = 'imported_cie10'
       AND f.field_name = 'external_display'
       AND f.review_status = 'unknown';

    SELECT count(*) INTO v_versiones_aprobadas
      FROM public.os_catalog_item_version iv
      JOIN public.os_catalog_item i ON i.id = iv.item_id
      JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
     WHERE iv.review_status = 'approved';

    SELECT count(*) INTO v_hashes_invalidos
      FROM public.os_field_review f
      JOIN public.os_catalog_item_version iv ON iv.id = f.target_id
     WHERE f.provenance = 'imported_cie10'
       AND f.field_name = 'preferred_term'
       AND f.review_status = 'approved'
       AND f.content_hash IS DISTINCT FROM
           md5(iv.preferred_term || E'\x1f' || f.language_code || E'\x1f'
               || COALESCE(f.source_reference, ''));

    SELECT count(*) INTO v_no_debian_aprobarse
      FROM public.os_field_review f
     WHERE f.provenance = 'imported_cie10'
       AND f.field_name IN ('definition', 'external_display')
       AND f.review_status = 'approved';

    SELECT count(*) INTO v_eventos
      FROM public.os_translation_review
     WHERE application_user_id = 'oftar_cie10_editorial_approval'
       AND target_table = 'os_field_review'
       AND event_type = 'approval_granted';

    RAISE NOTICE 'aprobación oftar-dx: esperados=%; aprobados=%; definition_pendientes=%; external_display_pendientes=%; versiones_aprobadas=%; hashes_invalidos=%; aprobados_indebidos=%; eventos=%',
        v_esperados, v_aprobados, v_definition_pendientes,
        v_external_display_pendientes, v_versiones_aprobadas,
        v_hashes_invalidos, v_no_debian_aprobarse, v_eventos;

    IF v_aprobados <> v_esperados
       OR v_definition_pendientes <> v_esperados
       OR v_external_display_pendientes = 0
       OR v_versiones_aprobadas <> v_esperados
       OR v_hashes_invalidos <> 0
       OR v_no_debian_aprobarse <> 0
       OR v_eventos <> v_esperados THEN
        RAISE EXCEPTION 'La aprobación de preferred_term de oftar-dx no cumple las reglas de gobernanza.';
    END IF;
END $$;

ROLLBACK;

-- Fin de verificacion_aprobacion_oftar_dx.sql
