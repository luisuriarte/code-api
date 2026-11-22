-- =============================================================================
-- Origen Salud · Verificación de solo lectura de la sincronización OFTAR-DX → os_*
-- sql/03_oftar/verificacion_sync_oftar_dx.sql
-- =============================================================================
-- No modifica datos: BEGIN READ ONLY / ROLLBACK.
--   sudo -u postgres psql -d origen_codes -f sql/03_oftar/verificacion_sync_oftar_dx.sql
-- =============================================================================
BEGIN READ ONLY;

SET client_encoding = 'UTF8';

\echo '=== 1. Ítems, versiones, identificadores y mapeos ==='
SELECT 'os_catalog_item' AS entidad, count(*) AS filas
  FROM public.os_catalog_item i
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
UNION ALL
SELECT 'os_catalog_item_version', count(*)
  FROM public.os_catalog_item_version iv
  JOIN public.os_catalog_item i ON i.id = iv.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
UNION ALL
SELECT 'os_catalog_identifier', count(*)
  FROM public.os_catalog_identifier ident
  JOIN public.os_catalog_item i ON i.id = ident.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
UNION ALL
SELECT 'os_concept_mapping', count(*)
  FROM public.os_concept_mapping m
  JOIN public.os_catalog_item i ON i.id = m.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
 ORDER BY entidad;

\echo '=== 2. Versiones por idioma (2661 es-AR, 2677 en = 5338) ==='
SELECT iv.language_code, count(*) AS versiones
  FROM public.os_catalog_item_version iv
  JOIN public.os_catalog_item i ON i.id = iv.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
 GROUP BY iv.language_code
 ORDER BY iv.language_code;

\echo '=== 3. Coincidencia uno a uno con el modelo editorial ==='
SELECT count(*) AS diagnosticos_sin_item
  FROM public.oftar_diagnosis d
 WHERE NOT EXISTS (
       SELECT 1 FROM public.os_catalog_item i
         JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
        WHERE i.permanent_code = d.code
   );

SELECT count(*) AS items_sin_diagnostico
  FROM public.os_catalog_item i
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
 WHERE NOT EXISTS (
       SELECT 1 FROM public.oftar_diagnosis d WHERE d.code = i.permanent_code
   );

\echo '=== 4. Identificadores CIE-10 dentro de H00-H59 ==='
SELECT count(*) AS identificadores_fuera_de_rango
  FROM public.os_catalog_identifier ident
  JOIN public.os_catalog_item i ON i.id = ident.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
 WHERE ident.system_name = 'CIE-10'
   AND ident.value !~ '^H(0[0-9]|[1-5][0-9])';

\echo '=== 5. Ningún diagnóstico CIE-10 en oftar-pr ==='
SELECT count(*) AS cie10_en_oftar_pr
  FROM public.os_concept_mapping m
  JOIN public.os_terminology_system ts ON ts.id = m.terminology_system_id
  JOIN public.os_catalog_item i ON i.id = m.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-pr'
 WHERE ts.code = 'CIE-10';

\echo '=== 6. Revisiones de campo pendientes ==='
SELECT review_status, count(*) AS revisiones
  FROM public.os_field_review
 WHERE provenance = 'imported_cie10'
 GROUP BY review_status
 ORDER BY review_status;

\echo '=== 7. Contenido aún no aprobado (esperado antes de la aprobación humana) ==='
SELECT count(*) AS versiones_aprobadas
  FROM public.os_catalog_item_version iv
  JOIN public.os_catalog_item i ON i.id = iv.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
 WHERE iv.review_status = 'approved';

\echo '=== 8. Conteo final y aserción ==='
DO $$
DECLARE
    v_items INT;
    v_versiones INT;
    v_versiones_esperadas INT;
    v_ids INT;
    v_mapeos INT;
    v_pendientes INT;
    v_aprobadas INT;
    v_invalidos INT;
BEGIN
    SELECT count(*) INTO v_items
      FROM public.os_catalog_item i
      JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx';

    SELECT count(*) INTO v_versiones
      FROM public.os_catalog_item_version iv
      JOIN public.os_catalog_item i ON i.id = iv.item_id
      JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx';

    -- Un diagnóstico produce una versión por idioma disponible (5338 en total).
    SELECT count(*) INTO v_versiones_esperadas
      FROM public.oftar_diagnosis d
      JOIN public.oftar_diagnosis_term dt
             ON dt.diagnosis_id = d.id AND dt.term_type = 'preferred'
     WHERE dt.language IN ('es-AR', 'en');

    SELECT count(*) INTO v_ids
      FROM public.os_catalog_identifier ident
      JOIN public.os_catalog_item i ON i.id = ident.item_id
      JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
     WHERE ident.system_name = 'CIE-10';

    SELECT count(*) INTO v_mapeos
      FROM public.os_concept_mapping m
      JOIN public.os_catalog_item i ON i.id = m.item_id
      JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx';

    SELECT count(*) INTO v_pendientes
      FROM public.os_field_review
     WHERE provenance = 'imported_cie10' AND review_status = 'unknown';

    SELECT count(*) INTO v_aprobadas
      FROM public.os_catalog_item_version iv
      JOIN public.os_catalog_item i ON i.id = iv.item_id
      JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
     WHERE iv.review_status = 'approved';

    SELECT (
        (SELECT count(*) FROM public.oftar_diagnosis d
          WHERE NOT EXISTS (
              SELECT 1 FROM public.os_catalog_item i
                JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
               WHERE i.permanent_code = d.code
          ))
      + (SELECT count(*) FROM public.os_catalog_item i
           JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
          WHERE NOT EXISTS (
              SELECT 1 FROM public.oftar_diagnosis d WHERE d.code = i.permanent_code
          ))
      + (SELECT count(*) FROM public.os_catalog_identifier ident
           JOIN public.os_catalog_item i ON i.id = ident.item_id
           JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
          WHERE ident.system_name = 'CIE-10'
            AND ident.value !~ '^H(0[0-9]|[1-5][0-9])')
      + (SELECT count(*) FROM public.os_concept_mapping m
           JOIN public.os_terminology_system ts ON ts.id = m.terminology_system_id
           JOIN public.os_catalog_item i ON i.id = m.item_id
           JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-pr'
          WHERE ts.code = 'CIE-10')
    ) INTO v_invalidos;

    RAISE NOTICE 'sync oftar-dx: ítems=%; versiones=%/%; identificadores=%; mapeos=%; revisiones_pendientes=%; aprobadas=%; inválidos=%',
        v_items, v_versiones, v_versiones_esperadas, v_ids, v_mapeos,
        v_pendientes, v_aprobadas, v_invalidos;

    IF v_items = 0 OR v_versiones <> v_versiones_esperadas
       OR v_items <> v_ids OR v_items <> v_mapeos
       OR v_pendientes = 0 OR v_aprobadas <> 0 OR v_invalidos <> 0 THEN
        RAISE EXCEPTION 'La sincronización OFTAR-DX → os_* no es completa o aprobó contenido sin revisión.';
    END IF;
END $$;

ROLLBACK;

-- Fin de verificacion_sync_oftar_dx.sql
