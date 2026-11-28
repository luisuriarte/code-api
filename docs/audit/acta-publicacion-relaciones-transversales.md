# Acta de decisión de publicación — modelo transversal de relaciones

**Fecha:** 2026-11-28 · **Versión:** 1.1
**Estado:** **DECIÓN REGISTRADA — PUBLICAR SOSTÉN TÉCNICO**. Corrida SQL v3 y evidencia API completas; pendiente la revisión visual UI y las tres firmas.

---

## 1. Objeto

Decidir la publicación de:

1. El contrato aditivo `data.relations{clinical,terminological}` en la API.
2. La ficha reutilizable con insignias Clínica/Terminológica en el portal.
3. El diccionario común de 31 tipos `REL-*`, ya verificado en `origen_codes`.

**No comprende:** la carga de relaciones clínicas por par ni la aprobación de equivalencias terminológicas nuevas.

---

## 2. Evidencia mínima exigida

| Evidencia | Referencia |
|---|---|
| Acta de ejecución | `docs/audit/acta-ejecucion-relaciones-transversales.md` |
| Resultado T-01…T-38 | `docs/audit/resultado-T01-T38-relaciones-transversales.md` |
| Verificación SQL v3 | `/tmp/T01_T38_sql_v3.log` — ejecutada, `EXIT=0`, `SIN FAIL` |
| Diagnóstico de metadatos | `mapping approved=2162`, `mapping draft=2678`, `approved sin metadatos=2162` |
| Contrato API | `/tmp/T31_dentar-pr.json`, `/tmp/T31_oftar-pr.json`, `/tmp/T34_headers.txt`, `/tmp/T34_body.json` — `PASS`; T-32 `SIN_DATOS` |
| UI y accesibilidad | `/tmp/T35_T36_estatico.log` → `PASS` estático; `/tmp/T35_T36_manual.log` — pendiente de revisión visual |
| Regresión estática | `/tmp/T35_T36_estatico.log` → `OK: 4149 comprobaciones` |

**[H]** La credencial se envió como `X-API-Key`; `Authorization: Bearer` no llega al PHP en este vhost porque nginx no reenvía `HTTP_AUTHORIZATION`. El autenticador acepta ambas formas, así que la verificación es válida sin modificar nginx.

**[P]** Sin la revisión visual `/tmp/T35_T36_manual.log` y las tres firmas, la decisión queda registrada pero no se considera cerrada.

---

## 3. Regla aplicada

| Condición | Decisión |
|---|---|
| Cualquier `FAIL` real en T-01…T-38 | **NO PUBLICAR**. Corregir y repetir. |
| API/UI sin evidencia | **NO PUBLICAR** la ficha ni el contrato hasta completar el runbook. |
| Solo `PASS`, `SIN_DATOS` y `GAP_DOCUMENTADO` | **PUBLICAR SOSTÉN TÉCNICO**. |
| Existencia de artefacto ratificado por par | Evaluar carga gobernada en acta separada. |

Los cinco `FAIL` de la corrida v1 se reclasifican en v3 como `GAP_DOCUMENTADO` o `SIN_DATOS`: ninguno representa una fila publicada inválida. Ver detalle en `resultado-T01-T38-relaciones-transversales.md`.

---

## 4. Decisión

**PUBLICAR SOSTÉN TÉCNICO** del modelo transversal de relaciones:

- Contrato aditivo `data.relations{clinical,terminological}` conservando `mappings`, `related_codes` y `uvr`.
- Ficha reutilizable con insignias Clínica/Terminológica en DENTAR y OFTAR.
- Diccionario de 31 tipos `REL-*` ya cargado y verificado.

**No se publica:** contenido clínico nuevo por par. Las matrices `matriz-conciliacion-clinica-oftar-pr.csv` y `matriz-equivalencias-oftar-pr.csv` permanecen como `propuesta_no_publicada`.

---

## 5. Brecha de metadatos y remediación

**[H]** Hay 2162 mapeos `review_status='approved'` sin fila en `os_mapping_metadata`, y 2678 filas `draft` que no son publicables.

**Tratamiento acordado:**

- La API mantiene el mapeo con `mapping_nature=null`, sin `external_display` ni `clinical_rationale`, y marca `untranslated=true`.
- No se inventan ediciones, licencias, referencias ni justificaciones.
- No se exponen filas `pending_review` ni `rejected` (el primero ni siquiera es un estado válido).

**Plan de remediación:**

1. Identificar las 2162 filas `approved` sin metadatos y clasificarlas por sistema terminológico.
2. Priorizar CDT, CIE-10 y SNOMED CT AR por riesgo de uso indebido.
3. Completar `target_version`, `license_reference`, `source_reference`, `mapping_nature` y `reviewed_by` solo con fuentes verificables; dejar `untranslated=true` mientras falte cualquiera.
4. Revisar T-03, T-06, T-07, T-15, T-19 y T-29 tras el backfill; exigir `PASS` antes de publicar cualquier equivalencia como gobernada.
5. Registrar cada avance en un acta separada; no modificar esta decisión sin nueva firma.

**[P]** El backfill no se ejecutó en esta tarea y no está autorizado por el acta de ejecución.

---

## 6. Firma

| Rol | Nombre | Decisión | Fecha |
|---|---|---|---|
| Responsable de ejecución | Luis A. Uriarte | `REGISTRADA: PUBLICAR SOSTÉN TÉCNICO` — firma pendiente | `<REGISTRAR>` |
| Responsable clínico | Luis A. Uriarte | `REGISTRADA: PUBLICAR SOSTÉN TÉCNICO` — firma pendiente | `<REGISTRAR>` |
| Responsable DBA | Luis A. Uriarte | `REGISTRADA: PUBLICAR SOSTÉN TÉCNICO` — firma pendiente | `<REGISTRAR>` |

**Decisión final:** `PUBLICAR SOSTÉN TÉCNICO`.

**[P]** Esta acta se cierra solo con las tres firmas y `/tmp/T35_T36_manual.log`. La corrida v3 y la evidencia API ya están incorporadas.
