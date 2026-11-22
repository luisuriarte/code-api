-- =============================================================================
-- Origen Salud · Verificación de solo lectura de la importación CIE-10 → OFTAR
-- sql/03_oftar/verificacion_oftar_cie10.sql
-- =============================================================================
-- No modifica datos: BEGIN READ ONLY / ROLLBACK.
--   sudo -u postgres psql -d origen_codes -f sql/03_oftar/verificacion_oftar_cie10.sql
-- =============================================================================
BEGIN READ ONLY;

SET client_encoding = 'UTF8';

\echo '=== 1. Identidad externa por sistema y dueño ==='
SELECT system_code, owner_catalog, entity_kind, count(*) AS codigos
  FROM public.oftar_external_identity
 GROUP BY system_code, owner_catalog, entity_kind
 ORDER BY system_code, owner_catalog;

\echo '=== 2. Cero códigos duplicados por (sistema, código normalizado) ==='
SELECT count(*) AS duplicados
  FROM (
      SELECT system_code, code_normalized
        FROM public.oftar_external_identity
       GROUP BY system_code, code_normalized
      HAVING count(*) > 1
  ) AS d;

\echo '=== 3. CIE-10 nunca debe tener dueño oftar-pr ==='
SELECT count(*) AS cie10_en_oftar_pr
  FROM public.oftar_external_identity
 WHERE system_code = 'CIE-10'
   AND owner_catalog <> 'oftar-dx';

\echo '=== 4. Mapeos sin identidad vinculada (debe ser 0) ==='
SELECT 'concept' AS origen, count(*) AS sin_identidad
  FROM public.oftar_concept_mapping WHERE identity_id IS NULL
UNION ALL
SELECT 'diagnosis', count(*)
  FROM public.oftar_diagnosis_mapping WHERE identity_id IS NULL;

\echo '=== 5. Ningún concepto OFTAR-PR debe mapear CIE-10 diagnóstico ==='
SELECT count(*) AS conceptos_con_cie10
  FROM public.oftar_concept_mapping
 WHERE system_code = 'CIE-10';

\echo '=== 6. Códigos permanentes y rango H00-H59 ==='
SELECT count(*) AS diagnosticos,
       count(*) FILTER (WHERE code ~ '^OFT-DX-[0-9]{6}$') AS codigos_validos,
       count(*) FILTER (
           WHERE EXISTS (
               SELECT 1 FROM public.oftar_diagnosis_mapping m
                WHERE m.diagnosis_id = public.oftar_diagnosis.id
                  AND m.system_code = 'CIE-10'
           )
       ) AS con_mapeo_cie10
  FROM public.oftar_diagnosis;

SELECT count(*) AS external_code_fuera_de_h00_h59
  FROM public.oftar_diagnosis_mapping
 WHERE system_code = 'CIE-10'
   AND external_code !~ '^H(0[0-9]|[1-5][0-9])';

\echo '=== 7. Cobertura idiomática: 18 huecos esperados por edición ==='
-- 1 código solo existe en CIE-10-ES 2026 (H01.8) y 17 solo en ICD-10-CM 2027.
-- No se inventa traducción: se conserva el idioma disponible de la fuente.
SELECT d.code,
       m.external_code,
       count(dt.id) FILTER (WHERE dt.language = 'es-AR') AS es_ar,
       count(dt.id) FILTER (WHERE dt.language = 'en') AS en,
       CASE WHEN m.external_code = 'H01.8'
            THEN 'solo en CIE-10-ES 2026'
            ELSE 'solo en ICD-10-CM 2027'
       END AS motivo
  FROM public.oftar_diagnosis d
  LEFT JOIN public.oftar_diagnosis_term dt ON dt.diagnosis_id = d.id
  JOIN public.oftar_diagnosis_mapping m
         ON m.diagnosis_id = d.id AND m.system_code = 'CIE-10'
 GROUP BY d.code, m.external_code
HAVING count(dt.id) FILTER (WHERE dt.language = 'es-AR') <> 1
    OR count(dt.id) FILTER (WHERE dt.language = 'en') <> 1
 ORDER BY m.external_code;

\echo '=== 8. Un solo término preferido por idioma (índice único) ==='
SELECT count(*) AS terminos_preferidos_duplicados
  FROM (
      SELECT diagnosis_id, language, term_type
        FROM public.oftar_diagnosis_term
       WHERE term_type = 'preferred'
       GROUP BY diagnosis_id, language, term_type
      HAVING count(*) > 1
  ) AS t;

\echo '=== 9. Estado de aprobación editorial ==='
SELECT approval_status, count(*) AS versiones
  FROM public.oftar_diagnosis_version
 GROUP BY approval_status
 ORDER BY approval_status;

\echo '=== 10. Conteo final y aserción ==='
DO $$
DECLARE
    v_duplicados INT;
    v_dueno_mal INT;
    v_sin_identidad INT;
    v_cie10_en_pr INT;
    v_fuera_rango INT;
    v_gaps_fuera_lista INT;
    v_diagnosticos INT;
BEGIN
    SELECT count(*) INTO v_duplicados
      FROM (SELECT system_code, code_normalized
              FROM public.oftar_external_identity
             GROUP BY system_code, code_normalized HAVING count(*) > 1) d;

    SELECT count(*) INTO v_dueno_mal
      FROM public.oftar_external_identity
     WHERE system_code = 'CIE-10' AND owner_catalog <> 'oftar-dx';

    SELECT count(*) INTO v_sin_identidad
      FROM public.oftar_diagnosis_mapping WHERE identity_id IS NULL;

    SELECT count(*) INTO v_cie10_en_pr
      FROM public.oftar_concept_mapping WHERE system_code = 'CIE-10';

    SELECT count(*) INTO v_fuera_rango
      FROM public.oftar_diagnosis_mapping
     WHERE system_code = 'CIE-10'
       AND external_code !~ '^H(0[0-9]|[1-5][0-9])';

    SELECT count(*) INTO v_diagnosticos FROM public.oftar_diagnosis;

    -- Todo hueco idiomático debe estar en la lista documentada de 18 códigos.
    SELECT count(*) INTO v_gaps_fuera_lista
      FROM (
          SELECT d.id
            FROM public.oftar_diagnosis d
            LEFT JOIN public.oftar_diagnosis_term dt ON dt.diagnosis_id = d.id
           GROUP BY d.id
          HAVING count(dt.id) FILTER (WHERE dt.language = 'es-AR') <> 1
              OR count(dt.id) FILTER (WHERE dt.language = 'en') <> 1
      ) AS g
      JOIN public.oftar_diagnosis d ON d.id = g.id
      JOIN public.oftar_diagnosis_mapping m
             ON m.diagnosis_id = d.id AND m.system_code = 'CIE-10'
     WHERE m.external_code NOT IN (
         'H01.8', 'H01.81', 'H01.82', 'H01.83', 'H01.84', 'H01.85', 'H01.86',
         'H01.89', 'H01.8A', 'H01.8B', 'H05.831', 'H05.832', 'H05.833',
         'H05.839', 'H40.841', 'H40.842', 'H40.843', 'H40.849'
     );

    RAISE NOTICE 'oftar-dx: diagnósticos=%; duplicados=%; dueño_invalido=%; sin_identidad=%; cie10_en_pr=%; fuera_rango=%; huecos_no_documentados=%',
        v_diagnosticos, v_duplicados, v_dueno_mal, v_sin_identidad,
        v_cie10_en_pr, v_fuera_rango, v_gaps_fuera_lista;

    IF v_duplicados <> 0 OR v_dueno_mal <> 0 OR v_sin_identidad <> 0
       OR v_cie10_en_pr <> 0 OR v_fuera_rango <> 0 OR v_diagnosticos = 0
       OR v_gaps_fuera_lista <> 0 THEN
        RAISE EXCEPTION 'La importación CIE-10 de OFTAR no cumple las reglas de deduplicación o de cobertura documentada.';
    END IF;
END $$;

ROLLBACK;

-- Fin de verificacion_oftar_cie10.sql
