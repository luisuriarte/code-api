-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud
-- sql/03_oftar/aprobar_preferred_term_oftar_dx.sql
-- =============================================================================
--
-- QUÉ APRUEBA
--   Solo `preferred_term` de los 5338 textos importados desde CIE-10 a
--   oftar-dx. NO aprueba `definition` ni `external_display`: esos campos
--   quedan en `unknown` para revisión humana posterior.
--
-- GOBERNANZA
--   · Actor explícito en la sesión (app.actor_id / app.actor_type) para que
--     trg_audit_content registre el evento `approval_granted` en
--     os_translation_review (append-only). No se inserta auditoría a mano
--     porque ese trigger ya lo hace al cambiar unknown -> approved.
--   · Verificación de content_hash vigente antes de aprobar: si el texto
--     cambió desde la importación, el script aborta en vez de aprobar un
--     contenido distinto del revisado.
--   · Idempotente: una segunda ejecución no encuentra filas `unknown` y no
--     modifica nada.
--
--   Requiere: sync_oftar_dx_to_os.sql ya ejecutado.
-- PostgreSQL 18.
-- =============================================================================
BEGIN;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- Identidad del aprobador: la usan los triggers de auditoría.
SET LOCAL app.actor_id = 'oftar_cie10_editorial_approval';
SET LOCAL app.actor_type = 'user';

DO $$
BEGIN
    IF to_regclass('public.os_field_review') IS NULL
       OR to_regclass('public.os_catalog_item_version') IS NULL
       OR to_regclass('public.os_translation_review') IS NULL THEN
        RAISE EXCEPTION 'Falta la estructura de gobernanza editorial.'
            USING HINT = 'Ejecutá la Fase 2/3 de i18n y sync_oftar_dx_to_os.sql.';
    END IF;
END $$;

-- =============================================================================
-- 1. CANDIDATAS: solo preferred_term de oftar-dx, sin aprobar todavía
-- =============================================================================
CREATE TEMP TABLE _oftar_aprobables ON COMMIT DROP AS
SELECT f.target_id AS version_id,
       f.language_code,
       f.scope_release_id,
       f.content_hash,
       md5(
           iv.preferred_term || E'\x1f'
           || f.language_code || E'\x1f'
           || COALESCE(f.source_reference, '')
       ) AS hash_esperado
  FROM public.os_field_review f
  JOIN public.os_catalog_item_version iv ON iv.id = f.target_id
  JOIN public.os_catalog_item i ON i.id = iv.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
 WHERE f.target_table = 'os_catalog_item_version'
   AND f.field_name = 'preferred_term'
   AND f.provenance = 'imported_cie10'
   AND f.review_status = 'unknown'
   AND f.language_code IN ('es-AR', 'en')
   AND f.scope_release_id = iv.release_id
   AND NULLIF(btrim(iv.preferred_term), '') IS NOT NULL;

-- =============================================================================
-- 2. GUARDA DE CONTENIDO VIGENTE
-- =============================================================================
DO $$
DECLARE
    v_hash_desactualizado INT;
BEGIN
    SELECT count(*) INTO v_hash_desactualizado
      FROM _oftar_aprobables
     WHERE content_hash IS DISTINCT FROM hash_esperado;

    IF v_hash_desactualizado > 0 THEN
        RAISE EXCEPTION
            'Hay % términos preferidos con hash desactualizado; no se aprueba nada.',
            v_hash_desactualizado
            USING HINT = 'Revisá esas revisiones y vuelve a sincronizar antes de aprobar.';
    END IF;
END $$;

-- =============================================================================
-- 3. APROBACIÓN DE CAMPO
-- =============================================================================
-- trg_fr_hash recalcula el hash (idéntico, verificado arriba) y
-- trg_audit_content escribe review_state_changed + approval_granted.
UPDATE public.os_field_review f
   SET review_status = 'approved',
       reviewed_by = 'oftar_cie10_editorial_approval',
       reviewed_at = now(),
       updated_at = now()
  FROM _oftar_aprobables a
 WHERE f.target_table = 'os_catalog_item_version'
   AND f.target_id = a.version_id
   AND f.field_name = 'preferred_term'
   AND f.language_code = a.language_code
   AND f.scope_release_id IS NOT DISTINCT FROM a.scope_release_id;

-- La versión debe pasar a 'approved' para que selectApproved() la considere.
-- Esto NO aprueba `definition`: ese campo sigue con su propia revisión
-- individual en 'unknown' y Browse lo mostrará como borrador.
UPDATE public.os_catalog_item_version iv
   SET review_status = 'approved'
  FROM _oftar_aprobables a
 WHERE iv.id = a.version_id
   AND iv.review_status <> 'approved';

-- =============================================================================
-- 4. RESULTADO Y ASERCIÓN
-- =============================================================================
SELECT count(*) AS aprobadas_ahora FROM _oftar_aprobables;

SELECT
    count(*) FILTER (WHERE f.field_name = 'preferred_term' AND f.review_status = 'approved') AS preferred_term_aprobados,
    count(*) FILTER (WHERE f.field_name = 'definition' AND f.review_status = 'unknown') AS definition_pendientes,
    count(*) FILTER (WHERE f.field_name = 'external_display' AND f.review_status = 'unknown') AS external_display_pendientes
  FROM public.os_field_review f
 WHERE f.provenance = 'imported_cie10';

DO $$
DECLARE
    v_esperados INT;
    v_aprobados INT;
    v_definition_pendientes INT;
    v_versiones_aprobadas INT;
    v_hashes_invalidos INT;
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

    RAISE NOTICE 'oftar-dx aprobación: esperados=%; aprobados=%; definition_pendientes=%; versiones_aprobadas=%; hashes_invalidos=%',
        v_esperados, v_aprobados, v_definition_pendientes,
        v_versiones_aprobadas, v_hashes_invalidos;

    IF v_aprobados <> v_esperados
       OR v_definition_pendientes <> v_esperados
       OR v_versiones_aprobadas <> v_esperados
       OR v_hashes_invalidos <> 0 THEN
        RAISE EXCEPTION 'La aprobación de preferred_term de oftar-dx no es completa o aprobó contenido no revisado.';
    END IF;
END $$;

COMMIT;

-- Fin de aprobar_preferred_term_oftar_dx.sql
