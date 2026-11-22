-- =============================================================================
-- Preflight de solo lectura para OFTAR-PR y UVR
-- sql/03_oftar/preflight_oftar_pr.sql
-- =============================================================================
BEGIN READ ONLY;

SET client_encoding = 'UTF8';

\echo '=== Tablas requeridas ==='
SELECT 'oftar_concept' AS objeto, to_regclass('public.oftar_concept') IS NOT NULL AS existe
UNION ALL SELECT 'oftar_attribute_value', to_regclass('public.oftar_attribute_value') IS NOT NULL
UNION ALL SELECT 'os_catalog_source_attribute', to_regclass('public.os_catalog_source_attribute') IS NOT NULL
UNION ALL SELECT 'os_catalog_identifier', to_regclass('public.os_catalog_identifier') IS NOT NULL
UNION ALL SELECT 'os_catalog_category', to_regclass('public.os_catalog_category') IS NOT NULL
UNION ALL SELECT 'os_field_review', to_regclass('public.os_field_review') IS NOT NULL
UNION ALL SELECT 'oftar_nomenclador_source', to_regclass('public.oftar_nomenclador_source') IS NOT NULL
UNION ALL SELECT 'nomenclador_2025', to_regclass('public.nomenclador_2025') IS NOT NULL
UNION ALL SELECT 'os_prestacion', to_regclass('public.os_prestacion') IS NOT NULL
UNION ALL SELECT 'os_uvr_profile', to_regclass('public.os_uvr_profile') IS NOT NULL
UNION ALL SELECT 'os_uvr_prestacion_valuation', to_regclass('public.os_uvr_prestacion_valuation') IS NOT NULL
UNION ALL SELECT 'v_os_uvr_prestacion_public', to_regclass('public.v_os_uvr_prestacion_public') IS NOT NULL
UNION ALL SELECT 'os_uvr_eligible_catalog', to_regclass('public.os_uvr_eligible_catalog') IS NOT NULL
 ORDER BY objeto;

\echo '=== Detalles (solo si las tablas existen) ==='
DO $$
DECLARE
    v_reg RECORD;
    v_num BIGINT;
    v_num2 BIGINT;
BEGIN
    IF to_regclass('public.os_catalog') IS NOT NULL
       AND to_regclass('public.os_catalog_release') IS NOT NULL THEN
        RAISE NOTICE '--- catálogo oftar-pr ---';
        FOR v_reg IN
            SELECT c.id, c.code, c.is_active, c.product_role,
                   r.id AS release_id, r.version_tag, r.status
              FROM public.os_catalog c
              LEFT JOIN public.os_catalog_release r ON r.catalog_id = c.id
             WHERE c.code = 'oftar-pr'
        LOOP
            RAISE NOTICE 'id=% code=% activo=% role=% release=% tag=% status=%',
                v_reg.id, v_reg.code, v_reg.is_active, v_reg.product_role,
                v_reg.release_id, v_reg.version_tag, v_reg.status;
        END LOOP;
    END IF;

    IF to_regclass('public.oftar_category') IS NOT NULL
       AND to_regclass('public.oftar_catalog') IS NOT NULL THEN
        RAISE NOTICE '--- categorías oftar-pr ---';
        FOR v_reg IN
            SELECT c.code, COALESCE(cv.name, '(sin versión ES)') AS name
              FROM public.oftar_category c
              LEFT JOIN public.oftar_category_version cv
                     ON cv.category_id = c.id
                    AND cv.version_number = 1
                    AND cv.language = 'es-AR'
             WHERE c.catalog_id = public.oftar_catalog_id('oftar-pr')
             ORDER BY c.code
        LOOP
            RAISE NOTICE '% | %', v_reg.code, v_reg.name;
        END LOOP;
    END IF;

    IF to_regclass('public.oftar_nomenclador_source') IS NOT NULL THEN
        RAISE NOTICE '--- fuente acotada oftalmológica ---';
        SELECT count(*), count(DISTINCT codigo) INTO v_num, v_num2
          FROM public.oftar_nomenclador_source;
        RAISE NOTICE 'filas=% códigos=%', v_num, v_num2;
    END IF;

    IF to_regclass('public.nomenclador_2025') IS NOT NULL THEN
        RAISE NOTICE '--- fuente NOMENCLADOR OFTALMOLOGIA ---';
        SELECT count(*), count(DISTINCT codigo) INTO v_num, v_num2
          FROM public.nomenclador_2025
         WHERE categoria = 'OFTALMOLOGIA';
        RAISE NOTICE 'filas=% códigos=%', v_num, v_num2;

        RAISE NOTICE '--- OCT 305111 ---';
        FOR v_reg IN
            SELECT codigo, descripcion, valor, categoria
              FROM public.nomenclador_2025 WHERE codigo = '305111'
        LOOP
            RAISE NOTICE '% | % | % | %', v_reg.codigo, v_reg.descripcion,
                v_reg.valor, v_reg.categoria;
        END LOOP;
    END IF;

    IF to_regclass('public.os_uvr_profile') IS NOT NULL THEN
        RAISE NOTICE '--- perfiles UVR ---';
        FOR v_reg IN SELECT id, code, scope, status FROM public.os_uvr_profile ORDER BY id
        LOOP
            RAISE NOTICE '% | % | % | %', v_reg.id, v_reg.code, v_reg.scope, v_reg.status;
        END LOOP;
    END IF;

    IF to_regclass('public.os_uvr_conversion') IS NOT NULL THEN
        RAISE NOTICE '--- conversiones UVR ---';
        FOR v_reg IN SELECT id, currency, uvr_value, review_status FROM public.os_uvr_conversion ORDER BY id
        LOOP
            RAISE NOTICE '% | % | % | %', v_reg.id, v_reg.currency, v_reg.uvr_value, v_reg.review_status;
        END LOOP;
    END IF;

    IF to_regclass('public.os_catalog_item') IS NOT NULL
       AND to_regclass('public.os_catalog_item_version') IS NOT NULL THEN
        RAISE NOTICE '--- estado actual de oftar-pr ---';
        SELECT count(DISTINCT i.id), count(iv.id)
          INTO v_num, v_num2
          FROM public.os_catalog_item i
          JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-pr'
          LEFT JOIN public.os_catalog_item_version iv ON iv.item_id = i.id;
        RAISE NOTICE 'items=% versiones=%', v_num, v_num2;
    END IF;

    IF to_regclass('public.os_uvr_eligible_catalog') IS NOT NULL THEN
        RAISE NOTICE '--- elegibilidad legacy ---';
        FOR v_reg IN SELECT catalog_code FROM public.os_uvr_eligible_catalog ORDER BY catalog_code
        LOOP
            RAISE NOTICE '%', v_reg.catalog_code;
        END LOOP;
    END IF;
END $$;

ROLLBACK;
