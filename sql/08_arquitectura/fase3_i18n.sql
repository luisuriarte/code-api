-- =============================================================================
-- FASE 3 (§16) · i18n: activación de D-31 y configuración por catálogo
-- =============================================================================
-- PROPUESTA PREPARADA EL 2026-11-19. NO EJECUTAR SIN APROBACIÓN Y BACKUP.
--
-- Autorización registrada: Fase 3 / i18n del §16. Deja sin efecto, para esta
-- fase, el diferimiento M7 del Acta M0 (decisión 16 del §15.2).
--
-- ADITIVO Y TRANSACCIONAL:
--   · CREATE OR REPLACE FUNCTION / TRIGGER para D-31 (mismo cuerpo que
--     sql/07_multilingue/18_fase11_invalidacion_mapeos.sql).
--   · INSERT ... ON CONFLICT DO NOTHING en os_catalog_language.
--   · No elimina tablas, columnas ni datos: solo CREATE/REPLACE e INSERT.
--   · NO reejecuta los scripts 01..15 de sql/07_multilingue (ya cargados).
--   · NO modifica importadores, API pública, catálogos publicados ni OS_IMPORT_MODE.
--
-- EL MODO DE IMPORTACIÓN NO CAMBIA: OS_IMPORT_MODE sigue siendo efectivamente
-- `dual` (ImporterIdentity::MODE_DUAL). `new_only` continúa siendo un interlock
-- que falla explícitamente. La Fase 13 NO se activa.
--
-- ROLLBACK: restaurar el dump previo. No hay DDL destructivo en este archivo.
-- La reversión manual del trigger se documenta en sql/08_arquitectura/README.md.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. D-31 · invalidación de aprobaciones D-19 por cambio de contenido
-- ---------------------------------------------------------------------------
-- Cuerpo idéntico al de 18_fase11_invalidacion_mapeos.sql. El trigger
-- trg_ocm_hash de la Fase 3 multilingüe recalcula el hash y marca la fila como
-- 'draft'; este complementario retira la revisión individual del campo y deja
-- el evento approval_invalidated en la misma transacción (D-31, D-41).

CREATE OR REPLACE FUNCTION trg_ocm_invalidate_field_reviews() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_app         VARCHAR(80);
    v_imp         VARCHAR(80);
    v_actor       VARCHAR(16);
    v_identified  BOOLEAN;
BEGIN
    IF TG_OP <> 'UPDATE' THEN
        RETURN NULL;
    END IF;

    v_app := NULLIF(current_setting('app.actor_id', TRUE), '');
    v_imp := NULLIF(current_setting('app.importer_run_id', TRUE), '');
    v_actor := NULLIF(current_setting('app.actor_type', TRUE), '');

    IF v_actor IS NULL OR v_actor NOT IN ('user', 'importer', 'system', 'db_role') THEN
        v_actor := CASE WHEN v_app IS NOT NULL THEN 'user'
                        WHEN v_imp IS NOT NULL THEN 'importer'
                        ELSE 'db_role' END;
    END IF;
    v_identified := (v_app IS NOT NULL OR v_imp IS NOT NULL);

    WITH invalidadas AS (
        UPDATE os_field_review f
           SET review_status = 'unreviewed',
               reviewed_by = NULL,
               reviewed_at = NULL,
               updated_at = now()
         WHERE f.target_table = 'os_concept_mapping'
           AND f.target_id = NEW.id
           AND f.review_status IN ('approved', 'reviewed')
           AND (
                (f.field_name = 'external_display'
                 AND (OLD.external_display IS DISTINCT FROM NEW.external_display
                      OR OLD.source_reference IS DISTINCT FROM NEW.source_reference))
                OR
                (f.field_name = 'clinical_rationale'
                 AND (OLD.clinical_rationale IS DISTINCT FROM NEW.clinical_rationale
                      OR OLD.source_reference IS DISTINCT FROM NEW.source_reference))
           )
        RETURNING f.target_id, f.field_name, f.language_code
    )
    INSERT INTO os_translation_review (
        target_table, target_id, field_name, language_code, event_type, action,
        previous_value, new_value, review_status, actor_type,
        application_user_id, importer_run_id, "session_user", actor_identified,
        transaction_id, notes
    )
    SELECT 'os_field_review',
           i.target_id,
           i.field_name,
           i.language_code,
           'approval_invalidated',
           'invalidate',
           'approved',
           'unreviewed',
           'unreviewed',
           v_actor,
           v_app,
           v_imp,
           SESSION_USER::VARCHAR(80),
           v_identified,
           txid_current(),
           'D-31: cambió el texto/referencia de os_concept_mapping; se retira la aprobación D-19 de este campo.'
      FROM invalidadas i;

    RETURN NULL;
END $$;

CREATE OR REPLACE TRIGGER trg_ocm_invalidate_fr
    AFTER UPDATE OF external_display, clinical_rationale, source_reference
    ON os_concept_mapping
    FOR EACH ROW
    EXECUTE FUNCTION trg_ocm_invalidate_field_reviews();

-- ---------------------------------------------------------------------------
-- 2. D-13 · idioma por catálogo, derivado de los datos ya cargados
-- ---------------------------------------------------------------------------
-- Regla D-13: exactamente 1 is_default y 1 is_fallback por catálogo; is_bridge
-- 0 o 1 (aquí siempre 0). No se agregan columnas de idioma a os_catalog.
--
-- El idioma predeterminado es el más frecuente en os_catalog_item_version de
-- cada catálogo, entre los idiomas activos y seleccionables (D-27, D-38): los
-- códigos source-only pueden ser idioma efectivo de una fila, pero no pueden
-- pedirse como locale ni ser default. Si el catálogo aún
-- no tiene versiones seleccionables, se usa 'es-AR', que es el locale del
-- portal y el literal con el que el importador DENTAR escribe. El fallback es
-- 'en' cuando hay contenido en ese idioma o cuando el default es 'es-AR'; en
-- caso contrario es 'es-AR'. En empate gana 'es-AR' (locale del portal y regla
-- global D-27), no el orden alfabético. coverage_status queda 'undetermined':
-- la cobertura editorial real no se ha verificado y no se inventa.

WITH contenido AS (
    SELECT i.catalog_id, v.language_code, count(*) AS filas
      FROM os_catalog_item i
      JOIN os_catalog_item_version v ON v.item_id = i.id
      JOIN os_language idi ON idi.code = v.language_code
     WHERE v.language_code IS NOT NULL
       AND idi.is_active
       AND NOT idi.is_source_only
     GROUP BY i.catalog_id, v.language_code
),
dominante AS (
    SELECT catalog_id, language_code
      FROM (
        SELECT catalog_id,
               language_code,
               row_number() OVER (
                   PARTITION BY catalog_id
                   ORDER BY filas DESC,
                            CASE language_code WHEN 'es-AR' THEN 0
                                               WHEN 'en' THEN 1
                                               ELSE 2 END,
                            language_code ASC
               ) AS rn
          FROM contenido
      ) r
     WHERE r.rn = 1
),
predeterminado AS (
    SELECT c.id AS catalog_id,
           COALESCE(d.language_code, 'es-AR') AS language_code
      FROM os_catalog c
      LEFT JOIN dominante d ON d.catalog_id = c.id
     WHERE c.product_role IS DISTINCT FROM 'family'
),
fallback AS (
    SELECT p.catalog_id,
           CASE
             WHEN p.language_code <> 'en'
                  AND EXISTS (
                      SELECT 1 FROM contenido k
                       WHERE k.catalog_id = p.catalog_id
                         AND k.language_code = 'en'
                  )
               THEN 'en'
             WHEN p.language_code <> 'es-AR' THEN 'es-AR'
             ELSE 'en'
           END AS language_code
      FROM predeterminado p
),
semilla AS (
    SELECT p.catalog_id, p.language_code AS lang,
           TRUE AS es_default, FALSE AS es_fallback
      FROM predeterminado p
    UNION ALL
    SELECT f.catalog_id, f.language_code,
           FALSE, TRUE
      FROM fallback f
)
INSERT INTO os_catalog_language
       (catalog_id, language_code, is_default, is_fallback, is_bridge, coverage_status)
SELECT s.catalog_id, s.lang, s.es_default, s.es_fallback, FALSE, 'undetermined'
  FROM semilla s
  JOIN os_language l ON l.code = s.lang
ON CONFLICT (catalog_id, language_code) DO NOTHING;

COMMIT;

-- ---------------------------------------------------------------------------
-- Comprobaciones posteriores (solo lectura)
-- ---------------------------------------------------------------------------
SELECT '=== Fase 3 · D-31 instalado ===' AS seccion;
SELECT tgname, tgenabled
  FROM pg_trigger
 WHERE tgrelid = to_regclass('public.os_concept_mapping')
   AND tgname = 'trg_ocm_invalidate_fr';

SELECT '=== Fase 3 · configuración idiomática por catálogo ===' AS seccion;
SELECT c.code,
       l.language_code,
       l.is_default,
       l.is_fallback,
       l.coverage_status
  FROM os_catalog c
  JOIN os_catalog_language l ON l.catalog_id = c.id
 WHERE c.product_role IS DISTINCT FROM 'family'
 ORDER BY c.code, l.is_default DESC, l.is_fallback DESC;

-- Fin de Fase 3 (§16) · i18n.
