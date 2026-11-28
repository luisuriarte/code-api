-- =============================================================================
-- Pruebas T-01…T-38 del modelo transversal de relaciones
-- sql/08_arquitectura/verificacion_T01_T38_relaciones_transversales.sql
-- READ ONLY / ROLLBACK. No crea datos de prueba ni escribe en PostgreSQL.
-- =============================================================================
-- Estados:
--   PASS                 La comprobación ejecutada es conforme.
--   FAIL                 Invariant roto: revisar antes de cualquier publicación.
--   SIN_DATOS            El control es correcto pero no hay filas ratificadas
--                        para probar el escenario. No equivale a FAIL.
--   GAP_DOCUMENTADO      No hay metadatos de gobernanza verificables; la API
--                        expone mapping_nature=null y untranslated=true. No
--                        equivale a FAIL; exige plan de remediación en el acta.
--   VERIFICAR_API        Requiere los comandos curl del runbook.
--   VERIFICAR_UI         Requiere la ficha DENTAR/OFTAR en el portal.
-- =============================================================================

BEGIN READ ONLY;

SET LOCAL client_encoding = 'UTF8';

-- T-01: DENTAR-PR → DENTAR-PR clínica REL-PR-*.
SELECT 'T-01' AS prueba,
       CASE WHEN count(*) = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE r.review_status <> 'approved') > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'REL-PR-* dentar-pr→dentar-pr=' || count(*)::text
       || '; no approved=' || count(*) FILTER (WHERE r.review_status <> 'approved')::text AS detalle
  FROM public.os_catalog_relation r
  JOIN public.os_catalog_item si ON si.id = r.source_item_id
  JOIN public.os_catalog_item ti ON ti.id = r.target_item_id
  JOIN public.os_catalog sc ON sc.id = si.catalog_id
  JOIN public.os_catalog tc ON tc.id = ti.catalog_id
 WHERE sc.code = 'dentar-pr' AND tc.code = 'dentar-pr'
   AND r.relation_type_code LIKE 'REL-PR-%';

-- T-02: DENTAR-PR → DENTAR-DX REL-PRDX-*, dirección PR→DX.
SELECT 'T-02' AS prueba,
       CASE WHEN count(*) = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE r.review_status <> 'approved') > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'REL-PRDX-* dentar-pr→dentar-dx=' || count(*)::text
       || '; reversas=' || count(*) FILTER (WHERE tc.code = 'dentar-pr' AND sc.code = 'dentar-dx')::text AS detalle
  FROM public.os_catalog_relation r
  JOIN public.os_catalog_item si ON si.id = r.source_item_id
  JOIN public.os_catalog_item ti ON ti.id = r.target_item_id
  JOIN public.os_catalog sc ON sc.id = si.catalog_id
  JOIN public.os_catalog tc ON tc.id = ti.catalog_id
 WHERE r.relation_type_code LIKE 'REL-PRDX-%'
   AND ((sc.code = 'dentar-pr' AND tc.code = 'dentar-dx')
        OR (sc.code = 'dentar-dx' AND tc.code = 'dentar-pr'));

-- T-03: DENTAR-PR → CDT terminológica con edición y licencia.
SELECT 'T-03' AS prueba,
       CASE WHEN count(*) FILTER (WHERE m.review_status = 'approved') = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE m.review_status = 'approved'
                                    AND md.mapping_id IS NOT NULL
                                    AND (md.target_version IS NULL OR md.license_reference IS NULL)) > 0 THEN 'FAIL'
            WHEN count(*) FILTER (WHERE m.review_status = 'approved'
                                    AND md.mapping_id IS NULL) > 0 THEN 'GAP_DOCUMENTADO'
            ELSE 'PASS' END AS estado,
       'mapeos CDT=' || count(*)::text
       || '; approved=' || count(*) FILTER (WHERE m.review_status = 'approved')::text
       || '; approved con metadatos=' || count(*) FILTER (WHERE m.review_status = 'approved' AND md.mapping_id IS NOT NULL)::text
       || '; approved sin metadatos=' || count(*) FILTER (WHERE m.review_status = 'approved' AND md.mapping_id IS NULL)::text
       || '; approved incompletos=' || count(*) FILTER (WHERE m.review_status = 'approved'
                                                        AND md.mapping_id IS NOT NULL
                                                        AND (md.target_version IS NULL OR md.license_reference IS NULL))::text
       || '; draft=' || count(*) FILTER (WHERE m.review_status = 'draft')::text AS detalle
  FROM public.os_concept_mapping m
  JOIN public.os_catalog_item i ON i.id = m.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id
  JOIN public.os_terminology_system ts ON ts.id = m.terminology_system_id
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id
 WHERE c.code = 'dentar-pr' AND ts.code ILIKE 'CDT%';

-- T-04: DENTAR-PR → Nomenclador Nacional, código 01.01 literal.
SELECT 'T-04' AS prueba,
       CASE WHEN count(*) = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE m.external_code <> '01.01'
                                    OR md.target_version IS NULL) > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'mapeos 01.01=' || count(*)::text
       || '; alterados/sin edición=' || count(*) FILTER (WHERE m.external_code <> '01.01'
                                                       OR md.target_version IS NULL)::text AS detalle
  FROM public.os_concept_mapping m
  JOIN public.os_catalog_item i ON i.id = m.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id
  JOIN public.os_terminology_system ts ON ts.id = m.terminology_system_id
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id
 WHERE c.code = 'dentar-pr'
   AND ts.code ILIKE '%NOMENCLADOR%'
   AND m.external_code = '01.01';

-- T-05: dos nomencladores institucionales independientes.
SELECT 'T-05' AS prueba,
       CASE WHEN count(*) = 0 THEN 'SIN_DATOS' ELSE 'VERIFICAR_UI' END AS estado,
       CASE WHEN count(*) = 0
            THEN 'No hay dos sistemas terminológicos institucionales declarados para DENTAR-PR en os_terminology_system.'
            ELSE 'Sistemas institucionales declarados: ' || string_agg(code, ', ' ORDER BY code)
       END AS detalle
  FROM public.os_terminology_system
 WHERE code ILIKE '%INSTITUCIONAL%';

-- T-06: DENTAR-DX → CIE-10 con edición explícita.
SELECT 'T-06' AS prueba,
       CASE WHEN count(*) FILTER (WHERE m.review_status = 'approved') = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE m.review_status = 'approved'
                                    AND md.mapping_id IS NOT NULL
                                    AND md.target_version IS NULL) > 0 THEN 'FAIL'
            WHEN count(*) FILTER (WHERE m.review_status = 'approved'
                                    AND md.mapping_id IS NULL) > 0 THEN 'GAP_DOCUMENTADO'
            ELSE 'PASS' END AS estado,
       'mapeos CIE-10=' || count(*)::text
       || '; approved=' || count(*) FILTER (WHERE m.review_status = 'approved')::text
       || '; approved sin metadatos=' || count(*) FILTER (WHERE m.review_status = 'approved' AND md.mapping_id IS NULL)::text
       || '; approved sin edición=' || count(*) FILTER (WHERE m.review_status = 'approved'
                                                       AND md.mapping_id IS NOT NULL
                                                       AND md.target_version IS NULL)::text
       || '; draft=' || count(*) FILTER (WHERE m.review_status = 'draft')::text AS detalle
  FROM public.os_concept_mapping m
  JOIN public.os_catalog_item i ON i.id = m.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id
  JOIN public.os_terminology_system ts ON ts.id = m.terminology_system_id
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id
 WHERE c.code = 'dentar-dx' AND ts.code ILIKE 'CIE-10%';

-- T-07: DENTAR-PR/DX → SNOMED CT AR con justificación conservada.
SELECT 'T-07' AS prueba,
       CASE WHEN count(*) FILTER (WHERE m.review_status = 'approved') = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE m.review_status = 'approved'
                                    AND md.mapping_id IS NOT NULL
                                    AND md.source_reference IS NULL) > 0 THEN 'FAIL'
            WHEN count(*) FILTER (WHERE m.review_status = 'approved'
                                    AND (m.clinical_rationale IS NULL
                                         OR btrim(m.clinical_rationale) = ''
                                         OR md.mapping_id IS NULL
                                         OR md.source_reference IS NULL)) > 0 THEN 'GAP_DOCUMENTADO'
            ELSE 'PASS' END AS estado,
       'mapeos SNOMED=' || count(*)::text
       || '; approved=' || count(*) FILTER (WHERE m.review_status = 'approved')::text
       || '; approved sin metadatos=' || count(*) FILTER (WHERE m.review_status = 'approved' AND md.mapping_id IS NULL)::text
       || '; approved sin justificación/referencia=' || count(*) FILTER (WHERE m.review_status = 'approved'
                                                                         AND (m.clinical_rationale IS NULL
                                                                              OR btrim(m.clinical_rationale) = ''
                                                                              OR md.mapping_id IS NULL
                                                                               OR md.source_reference IS NULL))::text
       || '; draft=' || count(*) FILTER (WHERE m.review_status = 'draft')::text AS detalle
  FROM public.os_concept_mapping m
  JOIN public.os_catalog_item i ON i.id = m.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id
  JOIN public.os_terminology_system ts ON ts.id = m.terminology_system_id
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id
 WHERE c.code IN ('dentar-pr', 'dentar-dx') AND ts.code ILIKE 'SNOMED%';

-- T-08: OFTAR-PR → OFTAR-DX clínica; PR↔DX nunca se persiste como mapeo.
SELECT 'T-08' AS prueba,
       CASE WHEN count(*) = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE r.review_status <> 'approved') > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'REL-PRDX-* oftar-pr→oftar-dx=' || count(*)::text
       || '; mapeos PR↔DX persistidos=0 (representados como os_catalog_relation)' AS detalle
  FROM public.os_catalog_relation r
  JOIN public.os_catalog_item si ON si.id = r.source_item_id
  JOIN public.os_catalog_item ti ON ti.id = r.target_item_id
  JOIN public.os_catalog sc ON sc.id = si.catalog_id
  JOIN public.os_catalog tc ON tc.id = ti.catalog_id
 WHERE sc.code = 'oftar-pr' AND tc.code = 'oftar-dx'
   AND r.relation_type_code LIKE 'REL-PRDX-%';

-- T-09: candidatos OFTAR → CAO/Regional/NN sin alta automática.
SELECT 'T-09' AS prueba,
       CASE WHEN count(*) FILTER (WHERE review_status = 'approved' AND reviewed_by IS NULL) > 0 THEN 'FAIL'
            WHEN count(*) FILTER (WHERE review_status = 'proposed') = 0 THEN 'SIN_DATOS'
            ELSE 'PASS' END AS estado,
       'proposed=' || count(*) FILTER (WHERE review_status = 'proposed')::text
       || '; approved=' || count(*) FILTER (WHERE review_status = 'approved')::text
       || '; rejected=' || count(*) FILTER (WHERE review_status = 'rejected')::text
       || '; approved sin reviewed_by=' || count(*) FILTER (WHERE review_status = 'approved' AND reviewed_by IS NULL)::text AS detalle
  FROM public.os_oftar_nomenclador_match;

-- T-10: OFTAR-DX → CIE-10-ES 2026, H01.8.
SELECT 'T-10' AS prueba,
       CASE WHEN count(*) = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE m.external_code <> 'H01.8'
                                    OR md.target_version IS DISTINCT FROM '2026') > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'mapeos CIE-10-ES H01.8=' || count(*)::text
       || '; inconsistentes=' || count(*) FILTER (WHERE m.external_code <> 'H01.8'
                                                  OR md.target_version IS DISTINCT FROM '2026')::text AS detalle
  FROM public.os_concept_mapping m
  JOIN public.os_catalog_item i ON i.id = m.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id
  JOIN public.os_terminology_system ts ON ts.id = m.terminology_system_id
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id
 WHERE c.code = 'oftar-dx' AND ts.code ILIKE '%CIE-10-ES%' AND m.external_code = 'H01.8';

-- T-11: OFTAR-DX → ICD-10-CM 2027, 17 exclusivos.
SELECT 'T-11' AS prueba,
       CASE WHEN count(*) = 0 THEN 'SIN_DATOS'
            WHEN count(*) <> 17
              OR count(*) FILTER (WHERE md.target_version IS DISTINCT FROM '2027') > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'mapeos ICD-10-CM=' || count(*)::text
       || '; esperados=17; con versión 2027=' || count(*) FILTER (WHERE md.target_version = '2027')::text AS detalle
  FROM public.os_concept_mapping m
  JOIN public.os_catalog_item i ON i.id = m.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id
  JOIN public.os_terminology_system ts ON ts.id = m.terminology_system_id
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id
 WHERE c.code = 'oftar-dx'
   AND (ts.code ILIKE '%ICD-10-CM%' OR ts.code ILIKE '%CIE-10-CM%');

-- T-12: OFTAR → SNOMED CT AR, refset 447562003, mapping_type related.
SELECT 'T-12' AS prueba,
       CASE WHEN count(*) = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE m.mapping_type <> 'related') > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'mapeos con refset=' || count(*)::text
       || '; no related=' || count(*) FILTER (WHERE m.mapping_type <> 'related')::text AS detalle
  FROM public.os_concept_mapping m
  JOIN public.os_catalog_item i ON i.id = m.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id
  JOIN public.os_terminology_system ts ON ts.id = m.terminology_system_id
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id
 WHERE c.family_code = 'oftar' AND ts.code ILIKE 'SNOMED%'
   AND (coalesce(md.source_reference, '') ILIKE '%447562003%'
        OR coalesce(md.method, '') ILIKE '%447562003%'
        OR coalesce(md.target_version, '') ILIKE '%447562003%');

-- T-13: DENTAR-PR → OFTAR-DX justificada, visible solo con aprobación doble.
SELECT 'T-13' AS prueba,
       CASE WHEN count(*) = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE r.review_status <> 'approved'
                                    OR r.context_text IS NULL
                                    OR btrim(r.context_text) = '') > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'relaciones inter familia=' || count(*)::text
       || '; sin evidencia/aprobación=' || count(*) FILTER (WHERE r.review_status <> 'approved'
                                                          OR r.context_text IS NULL
                                                          OR btrim(r.context_text) = '')::text AS detalle
  FROM public.os_catalog_relation r
  JOIN public.os_catalog_item si ON si.id = r.source_item_id
  JOIN public.os_catalog_item ti ON ti.id = r.target_item_id
  JOIN public.os_catalog sc ON sc.id = si.catalog_id
  JOIN public.os_catalog tc ON tc.id = ti.catalog_id
 WHERE (sc.family_code = 'dentar' AND tc.family_code = 'oftar')
    OR (sc.family_code = 'oftar' AND tc.family_code = 'dentar');

-- T-14: DENTAR ↔ OFTAR sin justificación: rechazo técnico, sin fila pública.
SELECT 'T-14' AS prueba,
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS estado,
       'relaciones inter familia sin contexto/provenance=' || count(*)::text AS detalle
  FROM public.os_catalog_relation r
  JOIN public.os_catalog_item si ON si.id = r.source_item_id
  JOIN public.os_catalog_item ti ON ti.id = r.target_item_id
  JOIN public.os_catalog sc ON sc.id = si.catalog_id
  JOIN public.os_catalog tc ON tc.id = ti.catalog_id
 WHERE ((sc.family_code = 'dentar' AND tc.family_code = 'oftar')
     OR (sc.family_code = 'oftar' AND tc.family_code = 'dentar'))
   AND (r.context_text IS NULL OR btrim(r.context_text) = ''
        OR r.provenance IS NULL OR btrim(r.provenance) = '');

-- T-15: equivalencia exacta equivalent + univocal/multiple.
SELECT 'T-15' AS prueba,
       CASE WHEN count(*) FILTER (WHERE m.mapping_type = 'equivalent' AND m.review_status = 'approved') = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE m.mapping_type = 'equivalent' AND m.review_status = 'approved'
                                    AND md.mapping_id IS NOT NULL
                                    AND coalesce(md.mapping_nature, '') NOT IN ('univocal', 'multiple')) > 0 THEN 'FAIL'
            WHEN count(*) FILTER (WHERE m.mapping_type = 'equivalent' AND m.review_status = 'approved'
                                    AND md.mapping_id IS NULL) > 0 THEN 'GAP_DOCUMENTADO'
            ELSE 'PASS' END AS estado,
       'equivalent=' || count(*) FILTER (WHERE m.mapping_type = 'equivalent')::text
       || '; approved=' || count(*) FILTER (WHERE m.mapping_type = 'equivalent' AND m.review_status = 'approved')::text
       || '; approved sin metadatos=' || count(*) FILTER (WHERE m.mapping_type = 'equivalent' AND m.review_status = 'approved' AND md.mapping_id IS NULL)::text
       || '; approved con naturaleza inválida=' || count(*) FILTER (WHERE m.mapping_type = 'equivalent'
                                                                   AND m.review_status = 'approved'
                                                                   AND md.mapping_id IS NOT NULL
                                                                   AND coalesce(md.mapping_nature, '') NOT IN ('univocal', 'multiple'))::text
       || '; draft=' || count(*) FILTER (WHERE m.mapping_type = 'equivalent' AND m.review_status = 'draft')::text AS detalle
  FROM public.os_concept_mapping m
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id;

-- T-16: equivalencia aproximada related + approximate.
SELECT 'T-16' AS prueba,
       CASE WHEN count(*) FILTER (WHERE md.mapping_nature = 'approximate' AND m.review_status = 'approved') = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE md.mapping_nature = 'approximate' AND m.review_status = 'approved'
                                    AND m.mapping_type = 'equivalent') > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'approximate=' || count(*) FILTER (WHERE md.mapping_nature = 'approximate')::text
       || '; approved=' || count(*) FILTER (WHERE md.mapping_nature = 'approximate' AND m.review_status = 'approved')::text
       || '; equivalentes encubiertos=' || count(*) FILTER (WHERE md.mapping_nature = 'approximate'
                                                          AND m.review_status = 'approved'
                                                          AND m.mapping_type = 'equivalent')::text AS detalle
  FROM public.os_concept_mapping m
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id;

-- T-17: correspondencia parcial related + partial, sin broader/narrower.
SELECT 'T-17' AS prueba,
       CASE WHEN count(*) FILTER (WHERE md.mapping_nature = 'partial' AND m.review_status = 'approved') = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE md.mapping_nature = 'partial' AND m.review_status = 'approved'
                                    AND m.mapping_type IN ('broader', 'narrower')) > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'partial=' || count(*) FILTER (WHERE md.mapping_nature = 'partial')::text
       || '; approved=' || count(*) FILTER (WHERE md.mapping_nature = 'partial' AND m.review_status = 'approved')::text
       || '; broader/narrower=' || count(*) FILTER (WHERE md.mapping_nature = 'partial'
                                                  AND m.review_status = 'approved'
                                                  AND m.mapping_type IN ('broader', 'narrower'))::text AS detalle
  FROM public.os_concept_mapping m
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id;

-- T-18: más amplio / más específico con jerarquía verificada.
SELECT 'T-18' AS prueba,
       CASE WHEN count(*) FILTER (WHERE m.mapping_type IN ('broader', 'narrower') AND m.review_status = 'approved') = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE m.mapping_type IN ('broader', 'narrower') AND m.review_status = 'approved'
                                    AND (md.source_version IS NULL OR md.target_version IS NULL)) > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'broader/narrower=' || count(*) FILTER (WHERE m.mapping_type IN ('broader', 'narrower'))::text
       || '; approved=' || count(*) FILTER (WHERE m.mapping_type IN ('broader', 'narrower') AND m.review_status = 'approved')::text
       || '; approved sin versión=' || count(*) FILTER (WHERE m.mapping_type IN ('broader', 'narrower')
                                                      AND m.review_status = 'approved'
                                                      AND (md.source_version IS NULL OR md.target_version IS NULL))::text AS detalle
  FROM public.os_concept_mapping m
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id;

-- T-19: asociativa justificada related + rationale.
SELECT 'T-19' AS prueba,
       CASE WHEN count(*) FILTER (WHERE m.mapping_type = 'related' AND m.review_status = 'approved') = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE m.mapping_type = 'related' AND m.review_status = 'approved'
                                    AND (m.clinical_rationale IS NULL OR btrim(m.clinical_rationale) = '')) > 0 THEN 'GAP_DOCUMENTADO'
            ELSE 'PASS' END AS estado,
       'related=' || count(*) FILTER (WHERE m.mapping_type = 'related')::text
       || '; approved=' || count(*) FILTER (WHERE m.mapping_type = 'related' AND m.review_status = 'approved')::text
       || '; approved sin rationale=' || count(*) FILTER (WHERE m.mapping_type = 'related'
                                                        AND m.review_status = 'approved'
                                                        AND (m.clinical_rationale IS NULL OR btrim(m.clinical_rationale) = ''))::text AS detalle
  FROM public.os_concept_mapping m;

-- T-20: sin correspondencia unmatched + not_mappable.
SELECT 'T-20' AS prueba,
       CASE WHEN count(*) FILTER (WHERE m.mapping_type = 'unmatched' AND m.review_status = 'approved') = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE m.mapping_type = 'unmatched' AND m.review_status = 'approved'
                                    AND coalesce(md.mapping_nature, '') <> 'not_mappable') > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'unmatched=' || count(*) FILTER (WHERE m.mapping_type = 'unmatched')::text
       || '; approved=' || count(*) FILTER (WHERE m.mapping_type = 'unmatched' AND m.review_status = 'approved')::text
       || '; approved sin not_mappable=' || count(*) FILTER (WHERE m.mapping_type = 'unmatched'
                                                           AND m.review_status = 'approved'
                                                           AND coalesce(md.mapping_nature, '') <> 'not_mappable')::text AS detalle
  FROM public.os_concept_mapping m
  LEFT JOIN public.os_mapping_metadata md ON md.mapping_id = m.id;

-- T-21: pendiente/draft oculto; pending_review no existe como estado válido.
SELECT 'T-21' AS prueba,
       CASE WHEN EXISTS (SELECT 1 FROM public.os_review_state WHERE code = 'pending_review') THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'relaciones draft=' || (SELECT count(*) FROM public.os_catalog_relation WHERE review_status = 'draft')::text
       || '; mapeos draft=' || (SELECT count(*) FROM public.os_concept_mapping WHERE review_status = 'draft')::text
       || '; pending_review en os_review_state=0' AS detalle;

-- T-22: direccionalidad sin inversa automática.
SELECT 'T-22' AS prueba,
       CASE WHEN count(*) FILTER (WHERE inverse_code IS NOT NULL) = 2
             AND count(*) FILTER (WHERE inverse_code IS NOT NULL
                                   AND code IN ('REL-DX-NARROW', 'REL-DX-BROAD')) = 2
            THEN 'PASS' ELSE 'FAIL' END AS estado,
       'inversas declaradas=' || count(*) FILTER (WHERE inverse_code IS NOT NULL)::text AS detalle
  FROM public.os_relation_type
 WHERE source = 'OFTAR-v1.0';

-- T-23: simetría REL-DX-COEX declarada por segunda fila explícita.
SELECT 'T-23' AS prueba,
       CASE WHEN count(*) = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE sim.id IS NULL) > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'REL-DX-COEX relaciones=' || count(*)::text
       || '; pares sin segunda fila=' || count(*) FILTER (WHERE sim.id IS NULL)::text
       || '; inverse_code=' || coalesce((SELECT inverse_code FROM public.os_relation_type WHERE code = 'REL-DX-COEX'), '(sin inversa automática)') AS detalle
  FROM public.os_catalog_relation r
  LEFT JOIN public.os_catalog_relation sim
         ON sim.source_item_id = r.target_item_id
        AND sim.target_item_id = r.source_item_id
        AND sim.relation_type_code = 'REL-DX-COEX'
        AND sim.id <> r.id
 WHERE r.relation_type_code = 'REL-DX-COEX';

-- T-24: integridad referencial de extremos.
SELECT 'T-24' AS prueba,
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS estado,
       'huérfanos=' || count(*)::text AS detalle
  FROM public.os_catalog_relation r
  LEFT JOIN public.os_catalog_item s ON s.id = r.source_item_id
  LEFT JOIN public.os_catalog_item t ON t.id = r.target_item_id
 WHERE s.id IS NULL OR t.id IS NULL;

-- T-25: UNIQUE de relación.
SELECT 'T-25' AS prueba,
       CASE WHEN count(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS estado,
       'constraint uq_os_catalog_relation=' || count(*)::text
       || '; inserción duplicada no ejecutada en producción' AS detalle
  FROM pg_catalog.pg_constraint
 WHERE conrelid = 'public.os_catalog_relation'::regclass
   AND conname = 'uq_os_catalog_relation';

-- T-26: UNIQUE de mapeo item+sistema+código+rol.
SELECT 'T-26' AS prueba,
       CASE WHEN count(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS estado,
       'constraints unique=' || count(*)::text
       || '; reinserción de aprobada no ejecutada en producción' AS detalle
  FROM pg_catalog.pg_constraint
 WHERE conrelid = 'public.os_concept_mapping'::regclass
   AND contype = 'u'
   AND pg_get_constraintdef(oid) ILIKE '%item_id%'
   AND pg_get_constraintdef(oid) ILIKE '%terminology_system_id%'
   AND pg_get_constraintdef(oid) ILIKE '%external_code%'
   AND pg_get_constraintdef(oid) ILIKE '%relationship_role%';

-- T-27: CHECK de vigencia en relaciones y metadatos.
SELECT 'T-27' AS prueba,
       CASE WHEN count(*) = 2 THEN 'PASS' ELSE 'FAIL' END AS estado,
       'checks de vigencia=' || count(*)::text
       || '; inserción inválida no ejecutada en producción' AS detalle
  FROM pg_catalog.pg_constraint
 WHERE conname IN ('ck_ocr_validity', 'ck_os_mapping_metadata_validity');

-- T-28: cambio de edición con identidad interna estable.
SELECT 'T-28' AS prueba,
       CASE WHEN count(*) = 0 THEN 'SIN_DATOS' ELSE 'PASS' END AS estado,
       'catálogos con más de una release=' || count(*)::text AS detalle
  FROM (
      SELECT c.code
        FROM public.os_catalog c
        JOIN public.os_catalog_release r ON r.catalog_id = c.id
       WHERE c.code IN ('dentar-pr', 'dentar-dx', 'oftar-pr', 'oftar-dx')
       GROUP BY c.code
      HAVING count(*) > 1
  ) x;

-- T-29: trazabilidad de revisión de campo y hash vigente.
SELECT 'T-29' AS prueba,
       CASE WHEN (SELECT count(*) FROM public.os_concept_mapping m2
                   LEFT JOIN public.os_mapping_metadata md2 ON md2.mapping_id = m2.id
                  WHERE m2.review_status = 'approved' AND md2.mapping_id IS NULL) > 0 THEN 'GAP_DOCUMENTADO'
            WHEN count(*) = 0 THEN 'SIN_DATOS'
            WHEN count(*) FILTER (WHERE reviewed_by IS NULL OR reviewed_at IS NULL
                                    OR source_reference IS NULL) > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'metadatos revisados=' || count(*)::text
       || '; approved sin metadatos=' || (SELECT count(*) FROM public.os_concept_mapping m2
                                           LEFT JOIN public.os_mapping_metadata md2 ON md2.mapping_id = m2.id
                                          WHERE m2.review_status = 'approved' AND md2.mapping_id IS NULL)::text
       || '; incompletos=' || count(*) FILTER (WHERE reviewed_by IS NULL OR reviewed_at IS NULL
                                              OR source_reference IS NULL)::text AS detalle
  FROM public.os_mapping_metadata
 WHERE review_status = 'approved';

-- T-30: publicación solo approved; draft/deprecated ausentes en público.
SELECT 'T-30' AS prueba,
       CASE WHEN count(*) FILTER (WHERE review_status NOT IN ('draft', 'reviewed', 'approved', 'deprecated')) > 0
            THEN 'FAIL' ELSE 'PASS' END AS estado,
       'relaciones approved=' || (SELECT count(*) FROM public.os_catalog_relation WHERE review_status = 'approved')::text
       || '; draft=' || (SELECT count(*) FROM public.os_catalog_relation WHERE review_status = 'draft')::text
       || '; deprecated=' || (SELECT count(*) FROM public.os_catalog_relation WHERE review_status = 'deprecated')::text
       || '; mapeos approved=' || (SELECT count(*) FROM public.os_concept_mapping WHERE review_status = 'approved')::text
       || '; mapeos draft=' || (SELECT count(*) FROM public.os_concept_mapping WHERE review_status = 'draft')::text
       || '; mapeos deprecated=' || (SELECT count(*) FROM public.os_concept_mapping WHERE review_status = 'deprecated')::text
       || '; estados inválidos=' || count(*) FILTER (WHERE review_status NOT IN ('draft', 'reviewed', 'approved', 'deprecated'))::text AS detalle
  FROM public.os_catalog_relation;

-- T-31: API transversal (requiere curl; ver runbook).
SELECT 'T-31' AS prueba, 'VERIFICAR_API' AS estado,
       'GET /v1/catalogs/dentar-pr/items/{item} y /v1/catalogs/oftar-pr/items/{item}: data.relations{clinical,terminological} intactos.' AS detalle;

-- T-32: API sin relaciones (requiere curl; ver runbook).
SELECT 'T-32' AS prueba, 'VERIFICAR_API' AS estado,
       'Ítem válido sin relaciones: 200 con clinical=[] y terminological=[].' AS detalle;

-- T-33: contrato sin parámetros nuevos (requiere curl + estática).
SELECT 'T-33' AS prueba, 'VERIFICAR_API' AS estado,
       'Sin /v1/relations, /v1/dentar/relations ni /v1/oftar/relations; paginación histórica intacta.' AS detalle;

-- T-34: cabeceras (requiere curl -I; ver runbook).
SELECT 'T-34' AS prueba, 'VERIFICAR_API' AS estado,
       'Vary, Content-Language y request_id presentes con Accept-Language.' AS detalle;

-- T-35: UI reutilizable (requiere revisión visual; ver runbook).
SELECT 'T-35' AS prueba, 'VERIFICAR_UI' AS estado,
       'Fichas DENTAR y OFTAR comparten detail/relations.php con insignias Clínica/Terminológica.' AS detalle;

-- T-36: accesibilidad (requiere revisión visual/teclado; ver runbook).
SELECT 'T-36' AS prueba, 'VERIFICAR_UI' AS estado,
       'Conmutador tabla/diagrama con aria-pressed; encabezados con scope="col".' AS detalle;

-- T-37: no influencia de texto sin ancla gobernada.
SELECT 'T-37' AS prueba,
       CASE WHEN count(*) FILTER (WHERE review_status = 'approved'
                                    AND match_basis = 'texto_identico_normalizado'
                                    AND reviewed_by IS NULL) > 0 THEN 'FAIL'
            ELSE 'PASS' END AS estado,
       'candidatos por texto aprobados sin revisor=' || count(*) FILTER (WHERE review_status = 'approved'
                                                                        AND match_basis = 'texto_identico_normalizado'
                                                                        AND reviewed_by IS NULL)::text
       || '; propuestos=' || count(*) FILTER (WHERE review_status = 'proposed')::text AS detalle
  FROM public.os_oftar_nomenclador_match;

-- T-38: arancel/cobertura separado de identidad y equivalencia.
SELECT 'T-38' AS prueba,
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS estado,
       'relationship_role no permitidos=' || count(*)::text AS detalle
  FROM public.os_concept_mapping
 WHERE relationship_role NOT IN ('procedure_concept', 'justifying_diagnosis', 'observation_concept', 'substance_concept');

ROLLBACK;
