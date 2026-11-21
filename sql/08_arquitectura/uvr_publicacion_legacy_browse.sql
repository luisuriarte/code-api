-- ---------------------------------------------------------------------------
-- Publicación UVR legacy → Browse Codes (aditivo, solo lectura pública)
-- ---------------------------------------------------------------------------
-- Motivo: v_os_uvr_prestacion_public solo expone valoraciones del modelo
-- transversal (os_prestacion + os_uvr_profile). Las valoraciones U0–U6 sobre
-- códigos de os_catalog (p. ej. dentar-pr / DNT-PR-000001) se publican en
-- os_uvr_valuation y, por eso, nunca llegaban a la ficha pública.
--
-- Esta vista NO modifica tablas ni vistas existentes. Expone únicamente
-- valoraciones publicadas, con el código permanente del ítem y componentes
-- derivados de v_os_uvr_valuation_governed. No se expone ningún importe
-- estimado interno: el único importe visible es importe_referencial, derivado de una conversión
-- aprobada/publicada vigente. Si no hay conversión, el importe es NULL.
--
-- Ejecutar como postgres:
--   sudo -u postgres psql -d origen_codes -f sql/08_arquitectura/uvr_publicacion_legacy_browse.sql
-- ---------------------------------------------------------------------------

BEGIN;

CREATE OR REPLACE VIEW public.v_os_uvr_valuation_public AS
SELECT g.valuation_id,
       c.code AS catalog_code,
       i.id AS item_id,
       i.permanent_code AS external_code,
       NULL::text AS prestacion_code,
       NULL::text AS prestacion_name,
       NULL::text AS profile_code,
       g.methodology,
       NULL::text AS scope,
       NULL::text AS jurisdiction,
       g.version_tag,
       g.review_status,
       g.published_at,
       v.valid_from,
       v.valid_to,
       g.work_uvr,
       g.practice_expense_uvr,
       g.professional_liability_uvr,
       g.total_uvr,
       money.currency,
       money.importe_referencial
  FROM public.v_os_uvr_valuation_governed g
  JOIN public.os_uvr_valuation v
    ON v.id = g.valuation_id
  JOIN public.os_catalog_item i
    ON i.id = g.service_item_id
  JOIN public.os_catalog c
    ON c.id = i.catalog_id AND c.is_active
  LEFT JOIN LATERAL (
      SELECT conv.currency,
             ROUND(g.total_uvr * conv.uvr_value, 2) AS importe_referencial
        FROM public.os_uvr_conversion conv
       WHERE conv.review_status IN ('approved', 'published')
         AND (conv.period_start IS NULL OR conv.period_start <= CURRENT_DATE)
         AND (conv.period_end IS NULL OR conv.period_end >= CURRENT_DATE)
       ORDER BY CASE WHEN conv.review_status = 'published' THEN 1 ELSE 0 END DESC,
                conv.period_start DESC NULLS LAST,
                conv.id DESC
       LIMIT 1
  ) money ON TRUE
 WHERE g.review_status = 'published'
   AND g.published_at IS NOT NULL
   -- dentar-dx está excluido del modelo UVR por diseño.
   AND c.code <> 'dentar-dx';

COMMENT ON VIEW public.v_os_uvr_valuation_public IS
    'Valoraciones UVR legacy publicadas sobre códigos de os_catalog. Solo lectura pública; importe_referencial derivado de conversión aprobada.';

-- No se modifican privilegios por defecto: se revoca y concede solo sobre esta vista.
REVOKE ALL PRIVILEGES ON TABLE public.v_os_uvr_valuation_public FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_med') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.v_os_uvr_valuation_public FROM origen_med';
        EXECUTE 'GRANT SELECT ON TABLE public.v_os_uvr_valuation_public TO origen_med';
    END IF;
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.v_os_uvr_valuation_public FROM origen_admin';
        EXECUTE 'GRANT SELECT ON TABLE public.v_os_uvr_valuation_public TO origen_admin';
    END IF;
END $$;

COMMIT;

-- Comprobaciones posteriores (solo lectura)
SELECT valuation_id, catalog_code, external_code, total_uvr, published_at
  FROM public.v_os_uvr_valuation_public
 ORDER BY published_at DESC
 LIMIT 10;

SELECT grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public'
   AND table_name = 'v_os_uvr_valuation_public'
 ORDER BY grantee, privilege_type;
