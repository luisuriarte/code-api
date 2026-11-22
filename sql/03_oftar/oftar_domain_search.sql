-- =============================================================================
-- OFTAR · REGISTRO DE DOMINIO Y VISTA DE BÚSQUEDA UNIFICADA
-- sql/03_oftar/oftar_domain_search.sql
-- =============================================================================
-- ADITIVO: CREATE OR REPLACE VIEW, INSERT ... ON CONFLICT DO NOTHING y
-- REVOKE/GRANT por objeto. No modifica filas existentes, no crea rutas nuevas,
-- no toca OpenAPI ni ALTER DEFAULT PRIVILEGES.
--
-- Dominio único `oftar`: abarca los dos productos de la familia
-- (`oftar-pr` y `oftar-dx`). Esos códigos siguen siendo catálogos, no dominios.
-- DEFAULT_DOMAINS de la API no cambia: sigue siendo snomed, cie10, anmat.
--
-- La vista expone el contrato que consume TerminologySearchService::
-- CATALOG_SOURCES[oftar] (id, activo, snomed_concept_id, codigo, termino,
-- subtitulo y metadata) y solo publica versiones aprobadas de la familia.
-- =============================================================================

BEGIN;

SET client_encoding = 'UTF8';

-- -----------------------------------------------------------------------------
-- 1. Registro del dominio (sin editar la Fase 1)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.os_domain_registry') IS NULL THEN
        RAISE EXCEPTION 'Falta public.os_domain_registry: aplicar sql/08_arquitectura/fase1_infraestructura.sql.';
    END IF;
END $$;

INSERT INTO public.os_domain_registry
    (code, label_es, label_en, mode, source_of_truth)
VALUES
    ('oftar', 'OFTAR (Oftalmología)', 'OFTAR (Ophthalmology)', 'catalog',
     'TerminologySearchService::DOMAINS/DOMAIN_CATALOG')
ON CONFLICT (code) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 2. Vista de búsqueda
-- -----------------------------------------------------------------------------
-- DISTINCT ON evita duplicar un mismo ítem cuando tiene versión es-AR y en.
-- Se prefiere es-AR; los 18 códigos con hueco idiomático conservan su versión
-- en (no se inventa una traducción).
CREATE OR REPLACE VIEW public.v_oftar_search_catalog AS
SELECT DISTINCT ON (item.id)
       item.id,
       TRUE AS activo,
       NULL::bigint AS snomed_concept_id,
       COALESCE(
           (SELECT ident.value
              FROM public.os_catalog_identifier ident
             WHERE ident.item_id = item.id
               AND ident.is_primary = TRUE
             LIMIT 1),
           item.permanent_code
       ) AS codigo,
       ver.preferred_term AS termino,
       cat.short_name || ' · ' || COALESCE(catcat.name, '') AS subtitulo,
       cat.code AS catalogo,
       item.permanent_code AS codigo_permanente,
       cat.family_code AS familia,
       catcat.name AS categoria,
       ver.language_code AS idioma,
       ver.review_status AS estado_revision
  FROM public.os_catalog_item item
  JOIN public.os_catalog cat
         ON cat.id = item.catalog_id
        AND cat.family_code = 'oftar'
        AND cat.product_role = 'catalog'
        AND cat.is_active = TRUE
  JOIN public.os_catalog_item_version ver
         ON ver.item_id = item.id
  LEFT JOIN public.os_catalog_category catcat
         ON catcat.id = ver.category_id
 WHERE item.status = 'active'
   AND ver.review_status = 'approved'
 ORDER BY item.id,
          (ver.language_code = 'es-AR') DESC,
          ver.id ASC;

COMMENT ON VIEW public.v_oftar_search_catalog IS
    'Proyección de los catálogos OFTAR-PR y OFTAR-DX al buscador unificado. Solo versiones aprobadas; sin UVR.';

-- -----------------------------------------------------------------------------
-- 3. Privilegios por objeto (sin ALTER DEFAULT PRIVILEGES)
-- -----------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON TABLE public.v_oftar_search_catalog FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.v_oftar_search_catalog FROM origen_admin';
        EXECUTE 'GRANT SELECT ON TABLE public.v_oftar_search_catalog TO origen_admin';
    END IF;

    IF to_regrole('origen_med') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.v_oftar_search_catalog FROM origen_med';
        EXECUTE 'GRANT SELECT ON TABLE public.v_oftar_search_catalog TO origen_med';
    END IF;

    -- La API se conecta con origen_api (api/config/database.php). Sin este
    -- GRANT, /v1/search?domains=oftar responde 500 permission denied.
    IF to_regrole('origen_api') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.v_oftar_search_catalog FROM origen_api';
        EXECUTE 'GRANT SELECT ON TABLE public.v_oftar_search_catalog TO origen_api';
    END IF;
END $$;

COMMIT;

-- =============================================================================
-- Verificación (solo lectura; ejecutar por separado)
-- =============================================================================
-- BEGIN READ ONLY;
-- SELECT code, label_es, mode FROM public.os_domain_registry WHERE code = 'oftar';
-- SELECT catalogo, count(*) FROM public.v_oftar_search_catalog GROUP BY 1 ORDER BY 1;
-- SELECT codigo, termino, categoria, idioma FROM public.v_oftar_search_catalog
--  WHERE codigo = 'H40.1110';
-- ROLLBACK;
