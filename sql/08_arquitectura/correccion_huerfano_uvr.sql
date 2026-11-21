-- =============================================================================
-- Borrado controlado de UNA valoración UVR huérfana (id = 5)
-- =============================================================================
-- Autorizado por el responsable el 2026-11-21.
-- Contexto: intento de propuesta del 14:33 que insertó la valoración y falló
-- después en el componente, dejando la fila sin componentes ni solicitud.
-- Reusar el tag DENTAR-PR-v2 chocaba con uq_os_uvr_valuation.
--
-- Seguridad:
--   * Solo id = 5.
--   * Solo review_status = 'draft'.
--   * Solo si no tiene componentes ni solicitud de gobernanza asociada.
--   * Si alguna guarda falla, RAISE EXCEPTION y no se borra nada.
--   * No toca os_audit_log: el alta quedó registrada como append-only.
--
-- Ejecutar contra la base del PANEL:
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 \
--     -f sql/08_arquitectura/correccion_huerfano_uvr.sql
-- =============================================================================

BEGIN;

DO $$
DECLARE
    v_coincidencias INT;
BEGIN
    SELECT count(*) INTO v_coincidencias
      FROM public.os_uvr_valuation v
     WHERE v.id = 5
       AND v.review_status = 'draft'
       AND NOT EXISTS (
           SELECT 1 FROM public.os_uvr_component c WHERE c.valuation_id = v.id
       )
       AND NOT EXISTS (
           SELECT 1 FROM public.os_governance_request g
            WHERE g.subject_type = 'uvr_valuation'
              AND g.subject_id = v.id::text
       );

    IF v_coincidencias <> 1 THEN
        RAISE EXCEPTION
            'No se borra nada: la fila 5 no cumple las guardas (coincidencias=%)',
            v_coincidencias;
    END IF;
END $$;

DELETE FROM public.os_uvr_valuation
 WHERE id = 5
   AND review_status = 'draft'
   AND NOT EXISTS (
       SELECT 1 FROM public.os_uvr_component c WHERE c.valuation_id = 5
   )
   AND NOT EXISTS (
       SELECT 1 FROM public.os_governance_request g
        WHERE g.subject_type = 'uvr_valuation'
          AND g.subject_id = '5'
   );

COMMIT;

-- Verificación: debe devolver 0 filas.
-- SELECT id, version_tag, review_status FROM public.os_uvr_valuation WHERE id = 5;
