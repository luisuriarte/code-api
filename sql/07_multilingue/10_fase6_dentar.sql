-- =============================================================================
-- FASE 6 · DENTAR: publicar campos clínicos omitidos (D-09)
-- =============================================================================
-- Entorno de PRUEBAS. Aditivo: solo UPDATE sobre columnas nuevas de Fase 3.
-- NO modifica sql/03_dentar/sync_dentar_to_os.sql ni el importador PHP.
-- NO contiene DROP, TRUNCATE ni DELETE de datos. Ejecutar dentro de transacción.
-- Fuentes: modelo §4.1; plan Fase 6; D-31.
--
-- Copia short_definition / lay_terms / clinical_scope desde la versión editorial
-- aprobada vigente de dentar_concept_version a la versión de catálogo que ya
-- publicó el sync (mismo permanent_code y misma release vigente de dentar-pr).
-- No toca preferred_term, definition ni clinical_criteria: el sync ya los carga.
-- El cambio dispara trg_civ_hash: recalcula el hash row_shared e invalida la
-- aprobación compartida, con evento en la misma transacción (D-31).
--
-- FUERA DE ESTE SCRIPT (es código, no SQL):
--   * cambiar los literales 'es-AR' y la exclusión de preferred en el sync;
--   * dentar_diagnosis.clinical_name como preferred_term de dentar-dx;
--   * el mapeo abbreviation -> acronym ya existe en el sync y NO se duplica.
-- =============================================================================

BEGIN;

DO $$
DECLARE
    v_catalog   INT;
    v_release   INT;
    v_maxver    INT;
    v_actualizadas INT;
    v_duplicados   INT;
BEGIN
    IF to_regclass('dentar_concept_version') IS NULL
       OR to_regclass('os_catalog_item_version') IS NULL THEN
        RAISE NOTICE 'Fase 6 omitida: no existen las tablas DENTAR/catálogo.';
        RETURN;
    END IF;

    SELECT id INTO v_catalog FROM os_catalog WHERE code = 'dentar-pr';
    IF v_catalog IS NULL THEN
        RAISE NOTICE 'Fase 6 omitida: no existe el catálogo dentar-pr.';
        RETURN;
    END IF;

    SELECT COALESCE(max(cv.version_number), 1) INTO v_maxver
      FROM dentar_concept_version cv
      JOIN dentar_concept dc ON dc.id = cv.concept_id
     WHERE dc.catalog_id = dentar_catalog_id('dentar-pr');

    SELECT id INTO v_release
      FROM os_catalog_release
     WHERE catalog_id = v_catalog
       AND version_tag = CASE WHEN v_maxver <= 1 THEN '2026-v1'
                              ELSE 'DENTAR-PR-v' || v_maxver::TEXT END;

    IF v_release IS NULL THEN
        RAISE NOTICE 'Fase 6 omitida: no se encontró la release vigente de dentar-pr.';
        RETURN;
    END IF;

    UPDATE os_catalog_item_version iv
       SET short_definition = l.short_definition,
           lay_terms        = l.lay_terms,
           clinical_scope   = l.clinical_scope,
           updated_at       = now()
      FROM (
            SELECT dc.code,
                   cv.short_definition,
                   cv.lay_terms,
                   cv.clinical_scope
              FROM dentar_concept_version cv
              JOIN dentar_concept dc ON dc.id = cv.concept_id
             WHERE dc.catalog_id = dentar_catalog_id('dentar-pr')
               AND cv.approval_status = 'approved'
               AND cv.version_number = (
                    SELECT max(v2.version_number)
                      FROM dentar_concept_version v2
                     WHERE v2.concept_id = cv.concept_id
                       AND v2.approval_status = 'approved')
           ) l
      JOIN os_catalog_item i
        ON i.catalog_id = v_catalog
       AND i.permanent_code = l.code
     WHERE iv.item_id = i.id
       AND iv.release_id = v_release;

    GET DIAGNOSTICS v_actualizadas = ROW_COUNT;
    RAISE NOTICE 'Fase 6: versiones de catálogo actualizadas: %', v_actualizadas;

    -- Unicidad propuesta en §4.2. Solo se crea si no hay duplicados previos:
    -- si los hay, se reporta y se deja para reconciliación (no se borra nada).
    SELECT count(*) INTO v_duplicados
      FROM (
            SELECT 1
              FROM os_catalog_term
             GROUP BY item_version_id, language_code, term, term_type
            HAVING count(*) > 1
           ) d;

    IF v_duplicados > 0 THEN
        RAISE NOTICE
            'Fase 6: % grupos duplicados en os_catalog_term; NO se crea uq_oct_identity. Reconciliar antes.',
            v_duplicados;
    ELSE
        CREATE UNIQUE INDEX IF NOT EXISTS uq_oct_identity
            ON os_catalog_term (item_version_id, language_code, term, term_type);
        RAISE NOTICE 'Fase 6: uq_oct_identity creada/verificada.';
    END IF;
END $$;

COMMIT;

-- Verificación de cierre
SELECT count(*) AS versiones_con_campos_clinicos
FROM os_catalog_item_version
WHERE short_definition IS NOT NULL OR lay_terms IS NOT NULL OR clinical_scope IS NOT NULL;

SELECT count(*) AS terminos_preferred_creados_por_fase6
FROM os_catalog_term
WHERE term_type = 'preferred';

SELECT indexname FROM pg_indexes
WHERE schemaname = current_schema()
  AND indexname = 'uq_oct_identity';

-- Fin de Fase 6 · DENTAR.
