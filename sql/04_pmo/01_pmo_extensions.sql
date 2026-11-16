-- =============================================================================
-- Origen Salud · PMO · Extensiones y configuración
-- sql/04_pmo/01_pmo_extensions.sql
-- =============================================================================
-- Configuración y preparación del motor para integración PMO.
-- Idempotente: seguro reejecutarse.
-- =============================================================================

SET client_encoding = 'UTF8';

-- 1. Verificar extensión pg_trgm (déjase por diseño, ya está en base)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Verificar que el motor catalog engine está cargado
DO $$
BEGIN
    IF to_regclass('public.os_catalog') IS NULL THEN
        RAISE EXCEPTION 'Tabla os_catalog no existe. Ejecutá sql/01_schema/design.sql y sql/02_catalogs/origen_catalog_engine.sql primero.';
    END IF;

    IF to_regclass('public.os_catalog_item') IS NULL THEN
        RAISE EXCEPTION 'Tabla os_catalog_item no existe. Ejecutá primeramente sql/02_catalogs/origen_catalog_engine.sql.';
    END IF;

    IF to_regclass('public.os_catalog_category') IS NULL THEN
        RAISE EXCEPTION 'Tabla os_catalog_category no existe. Verificar esquema.';
    END IF;

    IF to_regclass('public.os_catalog_item_version') IS NULL THEN
        RAISE EXCEPTION 'Tabla os_catalog_item_version no existe. Verificar esquema.';
    END IF;
END
$$;

-- 3. Verificar que las columnas necesarias existen en os_catalog_item
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'os_catalog_item' AND column_name = 'permanent_code') THEN
        RAISE EXCEPTION 'Campo permanent_code no existe en os_catalog_item. Verificar esquema.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'os_catalog_item' AND column_name = 'catalog_id') THEN
        RAISE EXCEPTION 'Campo catalog_id no existe en os_catalog_item. Verificar esquema.';
    END IF;
END
$$;

-- 4. Verificar que las columnas necesarias existen en os_catalog_category
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'os_catalog_category' AND column_name = 'code') THEN
        RAISE EXCEPTION 'Campo code no existe en os_catalog_category. Verificar esquema.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'os_catalog_category' AND column_name = 'name') THEN
        RAISE EXCEPTION 'Campo name no existe en os_catalog_category. Verificar esquema.';
    END IF;
END
$$;

-- 5. Verificar columnas en os_catalog_item_version
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'os_catalog_item_version' AND column_name = 'preferred_term') THEN
        RAISE EXCEPTION 'Campo preferred_term no existe en os_catalog_item_version. Verificar esquema.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'os_catalog_item_version' AND column_name = 'clinical_criteria') THEN
        RAISE EXCEPTION 'Campo clinical_criteria no existe en os_catalog_item_version. Verificar esquema.';
    END IF;
END
$$;

-- 6. Asegurar secuencia para os_catalog_item (si no existe)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'os_catalog_item_id_seq') THEN
        CREATE SEQUENCE os_catalog_item_id_seq;
    END IF;
END
$$;

-- 7. Asegurar secuencia para os_catalog_category (si no existe)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'os_catalog_category_id_seq') THEN
        CREATE SEQUENCE os_catalog_category_id_seq;
    END IF;
END
$$;

-- 8. Comentario en el catálogo nn-pmo (solo si existe)
DO $$
DECLARE
    v_catalog_count INT;
BEGIN
    SELECT COUNT(*) INTO v_catalog_count FROM os_catalog WHERE code = 'nn-pmo';
    IF v_catalog_count > 0 THEN
        COMMENT ON TABLE os_catalog IS 'Catálogo nn-pmo: Nomenclador Nacional de Prestaciones Médicas y Sanatoriales. Datos históricos Res. 201/2002 + Actualización Normativa 1/2002. Integración PMO Fase 3.';
    END IF;
END
$$;

-- =============================================================================
-- Fin de extensiones PMO
-- =============================================================================