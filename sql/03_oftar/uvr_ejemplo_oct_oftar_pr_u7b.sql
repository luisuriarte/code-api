-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud
-- sql/03_oftar/uvr_ejemplo_oct_oftar_pr_u7b.sql
-- =============================================================================
--
-- MODELO TRANSVERSAL U7-B (prestación + perfil + vínculo validado).
-- Usar SOLO si `public.v_os_uvr_prestacion_public` existe en la base.
-- Si no existe, usar `uvr_ejemplo_oct_oftar_pr_legacy.sql`.
--
-- EJEMPLO: OCT (Nomenclador Nacional 2025, código 305111) = 33,00 UVR,
-- declaradas por el responsable del proyecto. No se inventa conversión
-- monetaria: `importe_referencial` queda NULL hasta que exista una conversión
-- aprobada/publicada vigente. `estimated_payment` no se expone en lectura
-- pública (U0 / acta U7).
--
-- `total_uvr` NO se almacena: se deriva en v_os_uvr_prestacion_total.
-- La auditoría la escriben los triggers append-only existentes, con actor
-- explícito de sesión. No se inserta en os_audit_log a mano.
-- No crea objetos nuevos: no hay ACL nueva que conceder.
-- =============================================================================

BEGIN;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET LOCAL app.actor_id = 'oftar_oct_uvr_example';
SET LOCAL app.actor_type = 'user';

DO $$
BEGIN
    IF to_regclass('public.v_os_uvr_prestacion_public') IS NULL
       OR to_regclass('public.os_uvr_prestacion_valuation') IS NULL
       OR to_regclass('public.os_catalog_identifier') IS NULL THEN
        RAISE EXCEPTION 'El modelo U7-B no está aplicado en esta base.'
            USING HINT = 'Aplicar sql/08_arquitectura/uvr_transversal_prestaciones.sql o usar el script legacy.';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 1. Identidad de la prestación (elegibilidad por tipo + evidencia, no catálogo)
-- -----------------------------------------------------------------------------
INSERT INTO public.os_prestacion
       (code, display_name, prestation_type, is_valuable, eligibility_evidence,
        status, source_reference)
VALUES
       ('OCT-305111',
        'Oct (tomografía de coherencia óptica)',
        'diagnostic_procedure',
        TRUE,
        'Prestación de imagen diagnóstica listada en el Nomenclador Nacional 2025, categoría OFTALMOLOGIA, código 305111.',
        'published',
        'Nomenclador Nacional 2025 / OFTALMOLOGIA / código 305111')
ON CONFLICT (code) DO UPDATE
   SET display_name        = EXCLUDED.display_name,
       eligibility_evidence = EXCLUDED.eligibility_evidence,
       status              = EXCLUDED.status,
       source_reference    = EXCLUDED.source_reference;

-- -----------------------------------------------------------------------------
-- 2. Vínculo validado con el ítem de oftar-pr
-- -----------------------------------------------------------------------------
INSERT INTO public.os_prestacion_codigo
       (prestacion_id, catalog_code, item_id, external_code,
        correspondence_type, review_status, source_reference)
SELECT p.id, 'oftar-pr', i.id, '305111', 'corresponding', 'approved',
       'Nomenclador Nacional 2025 / OFTALMOLOGIA / código 305111'
  FROM public.os_prestacion p
  JOIN public.os_catalog c ON c.code = 'oftar-pr' AND c.is_active
  JOIN public.os_catalog_identifier ident
         ON ident.system_name = 'NOMENCLADOR-AR' AND ident.value = '305111'
  JOIN public.os_catalog_item i
         ON i.id = ident.item_id AND i.catalog_id = c.id
 WHERE p.code = 'OCT-305111'
ON CONFLICT (prestacion_id, catalog_code, item_id, external_code) DO UPDATE
   SET review_status = EXCLUDED.review_status,
       source_reference = EXCLUDED.source_reference;

DO $$
DECLARE
    v_vinculos INT;
BEGIN
    SELECT count(*) INTO v_vinculos
      FROM public.os_prestacion_codigo pc
      JOIN public.os_prestacion p ON p.id = pc.prestacion_id
     WHERE p.code = 'OCT-305111'
       AND pc.catalog_code = 'oftar-pr'
       AND pc.item_id IS NOT NULL
       AND pc.review_status = 'approved';
    IF v_vinculos = 0 THEN
        RAISE EXCEPTION
            'No se pudo vincular OCT 305111 con un ítem de oftar-pr. Importar primero NOMENCLADOR-AR.';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 3. Perfil de valoración oftalmológico
-- -----------------------------------------------------------------------------
INSERT INTO public.os_uvr_profile
       (code, name, methodology, scope, jurisdiction, version_tag,
        status, source_reference, approved_at)
VALUES
       ('OFTAR-PR-2026-V1',
        'Perfil oftalmológico ORIGEN/UVR 2026-v1',
        'Valoración relativa por componentes; valor declarado, sin conversión monetaria incluida.',
        'diagnostic',
        'AR',
        '2026-v1',
        'published',
        'Acta U7 y decisión editorial OFTAR-PR; ejemplo OCT 305111 = 33,00 UVR.',
        now())
ON CONFLICT (code) DO UPDATE
   SET name             = EXCLUDED.name,
       methodology      = EXCLUDED.methodology,
       status           = EXCLUDED.status,
       source_reference = EXCLUDED.source_reference;

-- El perfil declara qué componentes aplican; los no aplicables se marcan
-- explícitamente para no confundir "0" con "ausente".
INSERT INTO public.os_uvr_profile_component
       (profile_id, component_type, applicability, source_reference)
SELECT pr.id, v.component_type, v.applicability, v.source_reference
  FROM public.os_uvr_profile pr
  CROSS JOIN (VALUES
      ('work'::text,  'applicable'::text,      'Componente profesional · 33,00 UVR.'),
      ('practice_expense', 'not_applicable',  'Sin gasto de práctica declarado en el ejemplo.'),
      ('professional_liability', 'not_applicable', 'Sin prima de responsabilidad civil declarada en el ejemplo.')
  ) AS v(component_type, applicability, source_reference)
 WHERE pr.code = 'OFTAR-PR-2026-V1'
ON CONFLICT (profile_id, component_type) DO UPDATE
   SET applicability    = EXCLUDED.applicability,
       source_reference = EXCLUDED.source_reference;

-- -----------------------------------------------------------------------------
-- 4. Valoración publicada: 33,00 UVR en `work`
-- -----------------------------------------------------------------------------
-- ON CONFLICT DO NOTHING: una valoración publicada es inmutable (C12).
INSERT INTO public.os_uvr_prestacion_valuation
       (prestacion_id, profile_id, version_tag, source_reference, evaluated_at,
        review_status, published_at, valid_from)
SELECT p.id, pr.id, '2026-v1',
       'Ejemplo editorial OFTAR-PR · OCT 305111 · 33,00 UVR declaradas por el responsable.',
       DATE '2026-01-01', 'published', now(), DATE '2026-01-01'
  FROM public.os_prestacion p
  CROSS JOIN public.os_uvr_profile pr
 WHERE p.code = 'OCT-305111'
   AND pr.code = 'OFTAR-PR-2026-V1'
ON CONFLICT (prestacion_id, profile_id, version_tag) DO NOTHING;

INSERT INTO public.os_uvr_prestacion_component
       (valuation_id, component_type, value, is_not_applicable, source_reference)
SELECT v.id, c.component_type, c.value, c.is_not_applicable, c.source_reference
  FROM public.os_uvr_prestacion_valuation v
  JOIN public.os_prestacion p ON p.id = v.prestacion_id
  JOIN public.os_uvr_profile pr ON pr.id = v.profile_id
  CROSS JOIN (VALUES
      ('work'::text,                33.000000::numeric, FALSE, '33,00 UVR · OCT 305111.'),
      ('practice_expense',           0.000000::numeric, TRUE,  'No aplicable en el ejemplo.'),
      ('professional_liability',     0.000000::numeric, TRUE,  'No aplicable en el ejemplo.')
  ) AS c(component_type, value, is_not_applicable, source_reference)
 WHERE p.code = 'OCT-305111'
   AND pr.code = 'OFTAR-PR-2026-V1'
   AND v.version_tag = '2026-v1'
ON CONFLICT (valuation_id, component_type) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 5. Resultado (total derivado, sin importe inventado)
-- -----------------------------------------------------------------------------
SELECT prestacion_code, catalog_code, external_code, item_id,
       work_uvr, practice_expense_uvr, professional_liability_uvr,
       total_uvr, currency, importe_referencial
  FROM public.v_os_uvr_prestacion_public
 WHERE prestacion_code = 'OCT-305111';

COMMIT;
