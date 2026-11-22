-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud
-- sql/03_oftar/renombrar_codigos_oftar.sql
-- =============================================================================
--
-- QUÉ HACE
--   Alinea los códigos permanentes de OFTAR con el patrón de DENTAR:
--     OFTAR-PR-NNNNNN  ->  OFT-PR-NNNNNN     (154 procedimientos)
--     OFTAR-DX-NNNNNN  ->  OFT-DX-NNNNNN     (2678 diagnósticos)
--   Ejemplo: DNT-DX-000054 en DENTAR  =>  OFT-DX-000054 en OFTAR.
--
--   El DOMINIO sigue siendo uno solo: `oftar`. `oftar-pr` y `oftar-dx` siguen
--   siendo CÓDIGOS DE CATÁLOGO, no dominios (igual que dentar-dx no es dominio;
--   en DENTAR el dominio es `odontologia`).
--
--   Actualiza también `oftar_catalog.code_prefix` ANTES que los códigos, para
--   que el trigger `oftar_assert_catalog_code` acepte el nuevo prefijo.
--
--   Los patrones usan el operador regex `~`, NO LIKE: en SQL estándar LIKE
--   trata `[0-9]` como caracteres literales, por lo que un patrón con corchetes
--   no coincide nunca con `OFTAR-PR-000001`.
--
-- QUÉ NO HACE
--   · No toca identificadores externos (NOMENCLADOR-AR, CIE-10): esos códigos
--     son la fuente y no deben cambiar.
--   · No toca vínculos U7-B: `os_prestacion_codigo.external_code` = 305111.
--   · No crea objetos nuevos: no hay ACL nueva que conceder.
--   · No ejecuta ALTER DEFAULT PRIVILEGES. La auditoría la escriben los
--     triggers append-only existentes con el actor de sesión.
--   · Idempotente: una segunda ejecución no modifica nada.
-- =============================================================================

BEGIN;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET LOCAL app.actor_id = 'oftar_codigo_renombrado';
SET LOCAL app.actor_type = 'user';

-- -----------------------------------------------------------------------------
-- 0. Preflight de seguridad
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_pr_viejos INT;
    v_dx_viejos INT;
    v_pr_regex INT;
    v_dx_regex INT;
    v_pr_nuevos INT;
    v_dx_nuevos INT;
BEGIN
    IF to_regclass('public.os_catalog_item') IS NULL
       OR to_regclass('public.oftar_catalog') IS NULL
       OR to_regclass('public.oftar_concept') IS NULL
       OR to_regclass('public.oftar_diagnosis') IS NULL THEN
        RAISE EXCEPTION 'Falta la estructura OFTAR.';
    END IF;

    SELECT count(*) INTO v_pr_viejos FROM public.os_catalog_item WHERE permanent_code LIKE 'OFTAR-PR-%';
    SELECT count(*) INTO v_dx_viejos FROM public.os_catalog_item WHERE permanent_code LIKE 'OFTAR-DX-%';
    SELECT count(*) INTO v_pr_regex FROM public.os_catalog_item WHERE permanent_code ~ '^OFTAR-PR-[0-9]{6}$';
    SELECT count(*) INTO v_dx_regex FROM public.os_catalog_item WHERE permanent_code ~ '^OFTAR-DX-[0-9]{6}$';
    SELECT count(*) INTO v_pr_nuevos FROM public.os_catalog_item WHERE permanent_code LIKE 'OFT-PR-%';
    SELECT count(*) INTO v_dx_nuevos FROM public.os_catalog_item WHERE permanent_code LIKE 'OFT-DX-%';

    IF v_pr_regex <> v_pr_viejos OR v_dx_regex <> v_dx_viejos THEN
        RAISE EXCEPTION
            'Formato inesperado: PR LIKE=%, regex=%; DX LIKE=%, regex=%. Revisá antes de continuar.',
            v_pr_viejos, v_pr_regex, v_dx_viejos, v_dx_regex;
    END IF;

    IF (v_pr_viejos > 0 AND v_pr_nuevos > 0)
       OR (v_dx_viejos > 0 AND v_dx_nuevos > 0) THEN
        RAISE EXCEPTION
            'Hay códigos mezclados (PR viejo=%, nuevo=%; DX viejo=%, nuevo=%). Revisá antes de continuar.',
            v_pr_viejos, v_pr_nuevos, v_dx_viejos, v_dx_nuevos;
    END IF;

    IF v_pr_viejos = 0 AND v_dx_viejos = 0 THEN
        RAISE NOTICE 'No hay códigos con el prefijo viejo: el script no modifica nada (idempotente).';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 1. Prefijos canónicos (antes que los códigos: los valida el trigger)
-- -----------------------------------------------------------------------------
UPDATE public.oftar_catalog
   SET code_prefix = CASE code
                         WHEN 'oftar-pr' THEN 'OFT-PR'
                         WHEN 'oftar-dx' THEN 'OFT-DX'
                     END
 WHERE code IN ('oftar-pr', 'oftar-dx')
   AND code_prefix <> CASE code
                          WHEN 'oftar-pr' THEN 'OFT-PR'
                          WHEN 'oftar-dx' THEN 'OFT-DX'
                      END;

-- -----------------------------------------------------------------------------
-- 2. Códigos permanentes en el motor de catálogos
-- -----------------------------------------------------------------------------
UPDATE public.os_catalog_item
   SET permanent_code = 'OFT-PR-' || substring(permanent_code FROM 10)
 WHERE permanent_code ~ '^OFTAR-PR-[0-9]{6}$';

UPDATE public.os_catalog_item
   SET permanent_code = 'OFT-DX-' || substring(permanent_code FROM 10)
 WHERE permanent_code ~ '^OFTAR-DX-[0-9]{6}$';

-- -----------------------------------------------------------------------------
-- 3. Códigos editoriales OFTAR (mismo valor, validado por el trigger)
-- -----------------------------------------------------------------------------
UPDATE public.oftar_concept
   SET code = 'OFT-PR-' || substring(code FROM 10)
 WHERE code ~ '^OFTAR-PR-[0-9]{6}$';

UPDATE public.oftar_diagnosis
   SET code = 'OFT-DX-' || substring(code FROM 10)
 WHERE code ~ '^OFTAR-DX-[0-9]{6}$';

-- -----------------------------------------------------------------------------
-- 4. Verificación dentro de la transacción
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_viejos INT;
    v_pr INT;
    v_dx INT;
BEGIN
    SELECT count(*) INTO v_viejos
      FROM public.os_catalog_item
     WHERE permanent_code LIKE 'OFTAR-%';
    SELECT count(*) INTO v_pr FROM public.os_catalog_item WHERE permanent_code LIKE 'OFT-PR-%';
    SELECT count(*) INTO v_dx FROM public.os_catalog_item WHERE permanent_code LIKE 'OFT-DX-%';

    IF v_viejos <> 0 THEN
        RAISE EXCEPTION 'Quedan % códigos con prefijo viejo; se revierte todo.', v_viejos;
    END IF;
    RAISE NOTICE 'Códigos renombrados: PR=%, DX=%', v_pr, v_dx;
END $$;

SELECT code, code_prefix, short_name
  FROM public.oftar_catalog
 WHERE code IN ('oftar-pr', 'oftar-dx')
 ORDER BY code;

SELECT permanent_code
  FROM public.os_catalog_item
 WHERE permanent_code IN ('OFT-PR-000022', 'OFT-DX-000054')
 ORDER BY permanent_code;

SELECT c.code AS catalogo, count(*) AS items
  FROM public.os_catalog_item i
  JOIN public.os_catalog c ON c.id = i.catalog_id
 WHERE c.family_code = 'oftar'
 GROUP BY c.code
 ORDER BY c.code;

COMMIT;
