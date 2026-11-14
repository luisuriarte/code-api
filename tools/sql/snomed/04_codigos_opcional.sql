-- =============================================================================
-- Origen Salud · SNOMED CT Edición Argentina · PostgreSQL 18
-- 04_codigos_opcional.sql :: publicación de refsets para filtrado
-- =============================================================================
--
-- QUÉ HACE
--   Publica en `public.snomed_refset_member` los miembros de todos los refsets
--   que tienen `filter_code` en `public.sct2_refset_catalog`. Así la API (o
--   cualquier consulta) puede filtrar por un código corto y estable sin
--   conocer los SCTID de los refsets ni depender del esquema `sct2`.
--
--   Es el equivalente PostgreSQL de `04_codigos_opcional.sql` del proyecto
--   MariaDB/OpenEMR, que publica la terminología en la tabla `codes` con los
--   tipos 201 a 206. Allí el filtro es `code_type`; acá es `filter_code`.
--
-- QUÉ NO HACE
--   * No toca los catálogos curados (`laboratorio_practicas`,
--     `vacunas_catalogo`, `odontologia_prestaciones`, `prestaciones_medicas`,
--     `imagenes_practicas`, `anmat_medicamentos`, `programas_sociales`).
--   * No borra miembros de la tabla: la reconstruye completa con TRUNCATE.
--   * No publica refsets sin `filter_code` (idioma, mapas, refsets inactivos).
--
-- REQUISITOS
--   Haber ejecutado 03_postcarga.sql. Usa `sct2.preferred_term`,
--   `sct2.refset_simple`, `sct2.refset_simple_map` y
--   `public.sct2_refset_catalog`.
--
-- IDEMPOTENCIA
--   Se puede volver a ejecutar: recrea la tabla si falta, la vacía y la carga
--   de nuevo. No duplica filas.
--
-- VENTANA DE MANTENIMIENTO
--   El TRUNCATE toma un lock exclusivo sobre `snomed_refset_member`. Si la API
--   ya la consulta, programar la ejecución junto con la actualización
--   trimestral de SNOMED.
-- =============================================================================

SET client_encoding = 'UTF8';
SET statement_timeout = 0;
SET lock_timeout = 0;

-- =============================================================================
-- 0. Comprobaciones previas
-- =============================================================================

DO $$
BEGIN
    IF to_regclass('sct2.refset_simple') IS NULL
       OR to_regclass('sct2.preferred_term') IS NULL
       OR to_regclass('public.sct2_refset_catalog') IS NULL THEN
        RAISE EXCEPTION 'Falta la postcarga. Ejecutá 03_postcarga.sql antes de 04_codigos_opcional.sql.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM public.sct2_refset_catalog
         WHERE filter_code IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'El catálogo no tiene filter_code. Volvé a ejecutar 03_postcarga.sql.';
    END IF;
END $$;

-- =============================================================================
-- 1. Tabla de publicación
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.snomed_refset_member (
    refset_id   BIGINT       NOT NULL,
    filter_code VARCHAR(24)  NOT NULL,
    concept_id  BIGINT       NOT NULL,
    term        TEXT         NOT NULL,
    map_target  VARCHAR(64)  NULL,
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (refset_id, concept_id),
    FOREIGN KEY (refset_id)
        REFERENCES public.sct2_refset_catalog (refset_id)
        ON DELETE CASCADE,
    FOREIGN KEY (concept_id)
        REFERENCES public.snomed_concepts (id)
        ON DELETE CASCADE
);

-- Compatibilidad con instalaciones creadas por una versión anterior.
ALTER TABLE public.snomed_refset_member
    ADD COLUMN IF NOT EXISTS filter_code VARCHAR(24);
ALTER TABLE public.snomed_refset_member
    ADD COLUMN IF NOT EXISTS map_target VARCHAR(64);
ALTER TABLE public.snomed_refset_member
    ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE public.snomed_refset_member
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

COMMENT ON TABLE public.snomed_refset_member IS
    'Miembros de los refsets publicados para filtrado (código estable en filter_code).';
COMMENT ON COLUMN public.snomed_refset_member.filter_code IS
    'Código corto del refset, tomado de public.sct2_refset_catalog.filter_code.';
COMMENT ON COLUMN public.snomed_refset_member.map_target IS
    'Código destino cuando el refset es un mapa simple (por ejemplo NOMIVAC).';
COMMENT ON COLUMN public.snomed_refset_member.active IS
    'Vigencia del miembro en la release cargada.';

-- =============================================================================
-- 2. Carga
-- =============================================================================

BEGIN;

TRUNCATE TABLE public.snomed_refset_member;

INSERT INTO public.snomed_refset_member (
    refset_id, filter_code, concept_id, term, map_target, active
)
SELECT DISTINCT ON (m.refset_id, m.concept_id)
       m.refset_id,
       cat.filter_code,
       m.concept_id,
       coalesce(tp.term, ''),
       m.map_target,
       m.active
  FROM (
        SELECT refset_id,
               referenced_component_id AS concept_id,
               active,
               NULL::VARCHAR(64)       AS map_target
          FROM sct2.refset_simple
        UNION ALL
        SELECT refset_id,
               referenced_component_id,
               active,
               map_target
          FROM sct2.refset_simple_map
       ) m
  JOIN public.sct2_refset_catalog cat
    ON cat.refset_id = m.refset_id
   AND cat.filter_code IS NOT NULL
  LEFT JOIN sct2.preferred_term tp
    ON tp.concept_id = m.concept_id
 ORDER BY m.refset_id, m.concept_id, m.active DESC, m.map_target;

COMMIT;

-- =============================================================================
-- 3. Índices
-- =============================================================================

-- PK (refset_id, concept_id) ya cubre las búsquedas por refset.
CREATE INDEX IF NOT EXISTS snomed_refset_member_filter_idx
    ON public.snomed_refset_member (filter_code) WHERE active;
CREATE INDEX IF NOT EXISTS snomed_refset_member_concept_idx
    ON public.snomed_refset_member (concept_id);
CREATE INDEX IF NOT EXISTS snomed_refset_member_target_idx
    ON public.snomed_refset_member (map_target) WHERE map_target IS NOT NULL;
CREATE INDEX IF NOT EXISTS snomed_refset_member_term_trgm
    ON public.snomed_refset_member USING gin (term gin_trgm_ops);

-- =============================================================================
-- 4. Vista de consulta
-- =============================================================================

CREATE OR REPLACE VIEW public.v_snomed_refset AS
SELECT m.filter_code,
       c.name        AS refset_name,
       c.category,
       m.refset_id,
       m.concept_id,
       m.term,
       m.map_target,
       m.active
  FROM public.snomed_refset_member m
  JOIN public.sct2_refset_catalog c ON c.refset_id = m.refset_id;

COMMENT ON VIEW public.v_snomed_refset IS
    'Miembros de refsets con nombre y categoría, listos para filtrar por filter_code.';

-- =============================================================================
-- 5. Estadísticas y resumen
-- =============================================================================

ANALYZE public.snomed_refset_member;
ANALYZE public.sct2_refset_catalog;

SELECT filter_code,
       count(*) FILTER (WHERE active) AS miembros_activos,
       count(*)                       AS miembros_totales,
       count(DISTINCT concept_id)     AS conceptos
  FROM public.snomed_refset_member
 GROUP BY filter_code
 ORDER BY filter_code;

SELECT 'Refsets publicados para filtrado. Consultar public.v_snomed_refset.' AS resultado;
