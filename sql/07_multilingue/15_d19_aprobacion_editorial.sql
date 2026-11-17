-- =============================================================================
-- D-19 · Registro de la aprobación editorial ya decidida
-- =============================================================================
-- Entorno de PRUEBAS con datos no reales. Aditivo e idempotente.
-- NO contiene DROP, TRUNCATE ni DELETE. Ejecutar DENTRO de transacción.
-- Válido en psql y en DBeaver-CE (sin meta-comandos de psql).
--
-- La autoridad editorial aprobó la matriz D-19. Este script NO cambia el
-- review_status de os_concept_mapping (ya era 'approved' heredado y no se
-- degrada): crea la revisión de campo que faltaba en os_field_review para que
-- la API pueda publicar el texto aprobado sin caer a una columna sin revisar.
--
-- Idioma: 'undet' es la etiqueta de AUSENCIA de idioma documentada en D-19.
-- os_concept_mapping no tiene language_code; no se inventa 'es-AR'.
-- Se registran solo los campos con texto no vacío: external_display y
-- clinical_rationale. El content_hash lo calcula el trigger de Fase 3.
-- El evento approval_granted se inserta solo para las revisiones creadas ahora;
-- una reejecución no duplica eventos ni aprobaciones.
-- =============================================================================

BEGIN;

-- Identidad del actor de aplicación que registra la decisión editorial.
SELECT set_config('app.actor_type', 'user', true);
SELECT set_config('app.actor_id', 'd19_editorial_approval', true);
SELECT set_config('app.importer_run_id', '', true);

WITH candidatas AS (
    SELECT m.id AS target_id,
           v.field_name,
           v.valor,
           m.provenance,
           m.source_reference
      FROM os_concept_mapping m
      CROSS JOIN LATERAL (
          VALUES ('external_display', m.external_display),
                 ('clinical_rationale', m.clinical_rationale)
      ) AS v(field_name, valor)
     WHERE m.review_status = 'approved'
       AND NULLIF(btrim(COALESCE(v.valor, '')), '') IS NOT NULL
       AND NOT EXISTS (
             SELECT 1
               FROM os_field_review f
              WHERE f.target_table = 'os_concept_mapping'
                AND f.target_id = m.id
                AND f.field_name = v.field_name
                AND f.language_code = 'undet'
                AND f.scope_release_id IS NULL
           )
),
insertadas AS (
    INSERT INTO os_field_review (
        target_table, target_id, field_name, language_code, scope_release_id,
        source_language_code, language_evidence, provenance, review_status,
        source_reference, reviewed_by, reviewed_at
    )
    SELECT 'os_concept_mapping',
           c.target_id,
           c.field_name,
           'undet',
           NULL,
           NULL,
           'undetermined',
           c.provenance,
           'approved',
           c.source_reference,
           'd19_editorial_approval',
           now()
      FROM candidatas c
     ON CONFLICT DO NOTHING
    RETURNING target_id, field_name, language_code, content_hash
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
       'approval_granted',
       'approve',
       NULL,
       i.content_hash,
       'approved',
       'user',
       'd19_editorial_approval',
       NULL,
       SESSION_USER::VARCHAR(80),
       TRUE,
       txid_current(),
       'D-19 aprobación editorial registrada; etiqueta de idioma undet (sin dialecto inferido).'
  FROM insertadas i;

COMMIT;

SELECT '=== D-19 · Revisiones de campo aprobadas ===' AS seccion;

SELECT target_table, language_code, review_status, count(*) AS filas
  FROM os_field_review
 WHERE target_table = 'os_concept_mapping'
 GROUP BY target_table, language_code, review_status
 ORDER BY language_code, review_status;

SELECT '=== D-19 · Control: aprobadas sin revisión de campo (DEBE SER 0) ===' AS seccion;

SELECT count(*) AS aprobadas_sin_os_field_review
  FROM os_concept_mapping m
 WHERE m.review_status = 'approved'
   AND NOT EXISTS (
         SELECT 1
           FROM os_field_review f
          WHERE f.target_table = 'os_concept_mapping'
            AND f.target_id = m.id
   );

SELECT '=== D-19 · Eventos de aprobación registrados ===' AS seccion;

SELECT event_type, action, count(*) AS eventos
  FROM os_translation_review
 WHERE target_table = 'os_field_review'
   AND event_type = 'approval_granted'
   AND notes LIKE 'D-19%'
 GROUP BY event_type, action;

-- Fin del registro de aprobación D-19.
