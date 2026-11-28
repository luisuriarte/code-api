-- =============================================================================
-- NO EJECUTAR SIN ACTA, BACKUP Y VERIFICACIÓN READ ONLY
-- sql/08_arquitectura/fase5_relaciones_transversales.sql
-- =============================================================================
-- DDL aditivo del modelo transversal de relaciones de Origen Salud.
--
-- Qué hace:
--   1. Agrega relation_type_code a os_catalog_relation con FK a os_relation_type.
--
-- Qué NO hace:
--   - No amplía el CHECK heredado de relation_type (15 tipos CDT intactos).
--   - No reescribe las 603 relaciones existentes ni sus relation_type.
--   - No hace backfill: las filas heredadas quedan con relation_type_code NULL.
--   - No ejecuta sentencias destructivas.
--   - No siembra el diccionario: eso se hace en fase5_semillas_tipos_relacion.sql.
-- =============================================================================

BEGIN;

SET LOCAL client_encoding = 'UTF8';
SET LOCAL standard_conforming_strings = on;

DO $$
BEGIN
    IF to_regclass('public.os_catalog_relation') IS NULL THEN
        RAISE EXCEPTION 'Falta public.os_catalog_relation; aplique primero el núcleo DENTAR.';
    END IF;
    IF to_regclass('public.os_relation_type') IS NULL THEN
        RAISE EXCEPTION 'Falta public.os_relation_type; aplique primero fase1_infraestructura.sql.';
    END IF;
    IF to_regclass('public.os_relation_kind') IS NULL THEN
        RAISE EXCEPTION 'Falta public.os_relation_kind; aplique primero fase1_infraestructura.sql.';
    END IF;
END
$$;

ALTER TABLE public.os_catalog_relation
    ADD COLUMN IF NOT EXISTS relation_type_code VARCHAR(60);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_ocr_relation_type_code'
          AND conrelid = 'public.os_catalog_relation'::regclass
    ) THEN
        ALTER TABLE public.os_catalog_relation
            ADD CONSTRAINT fk_ocr_relation_type_code
            FOREIGN KEY (relation_type_code)
            REFERENCES public.os_relation_type(code)
            ON UPDATE CASCADE;
    END IF;
END
$$;

COMMIT;

-- Verificación posterior obligatoria (fuera de esta transacción):
--   SELECT count(*) FROM os_catalog_relation;                           -- 603
--   SELECT count(*) FROM os_catalog_relation WHERE relation_type_code IS NOT NULL; -- 0
--   SELECT count(DISTINCT relation_type) FROM os_catalog_relation;      -- 15
