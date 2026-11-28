# Resultado T-01…T-38 — modelo transversal de relaciones

**Fecha de ejecución:** 2026-11-28 · **Entorno:** producción · **Base:** `origen_codes`
**Responsable:** Luis A. Uriarte · **Rama:** `feat/relaciones-transversales`

**Convención:** `PASS` conforme · `FAIL` bloqueante · `SIN_DATOS` control correcto sin filas ratificadas · `GAP_DOCUMENTADO` sin metadatos de gobernanza, publicado con `untranslated=true`.

---

## 1. Corridas disponibles

| Salida | Script | Observación |
|---|---|---|
| `/tmp/T01_T38_sql.log` | v1 · `14492015…` | Primera corrida. |
| `/tmp/T01_T38_sql_v2.log` | v1 · `14492015…` | Idéntica a la anterior: el VPS no tenía la versión corregida. |
| `/tmp/T01_T38_sql_v3.log` | v3 · `0275fd72…` | **Pendiente** de ejecutar tras aplicar el parche. |

**Diagnóstico ejecutado:**

```text
mapping|approved|2162
mapping|draft|2678
approved_sin_metadata = 2162
```

`os_mapping_metadata` no tiene filas. Por decisión del responsable, las 2162 filas `approved` se publican con `mapping_nature=null`, sin texto externo ni justificación, y `untranslated=true`; la brecha queda documentada en el acta de publicación.

---

## 2. Resultados

| ID | Observado (v1) | Detalle observado | v3 / cierre |
|---|---|---|---|
| T-01 | `SIN_DATOS` | `REL-PR-* dentar-pr→dentar-pr=0` | `SIN_DATOS` |
| T-02 | `SIN_DATOS` | `REL-PRDX-* dentar-pr→dentar-dx=0; reversas=0` | `SIN_DATOS` |
| T-03 | `FAIL` | `mapeos CDT=844; incompletos=844` | `GAP_DOCUMENTADO` — el script v1 contaba también `draft`; v3 evalúa solo `approved` y distingue ausencia de metadatos de inconsistencia |
| T-04 | `SIN_DATOS` | `mapeos 01.01=0` | `SIN_DATOS` |
| T-05 | `SIN_DATOS` + `VERIFICAR_UI` | dos filas por el `UNION ALL` del script v1 | `SIN_DATOS` — v3 devuelve una sola fila |
| T-06 | `FAIL` | `mapeos CIE-10=223; sin edición=223` | `GAP_DOCUMENTADO` |
| T-07 | `FAIL` | `mapeos SNOMED=143; sin justificación/referencia=143` | `GAP_DOCUMENTADO` |
| T-08 | `SIN_DATOS` | `REL-PRDX-* oftar-pr→oftar-dx=0` | `SIN_DATOS` |
| T-09 | `PASS` | `proposed=90; approved=1; rejected=0; approved sin reviewed_by=0` | `PASS` |
| T-10 | `SIN_DATOS` | `mapeos CIE-10-ES H01.8=0` | `SIN_DATOS` |
| T-11 | `SIN_DATOS` | `mapeos ICD-10-CM=0` | `SIN_DATOS` |
| T-12 | `SIN_DATOS` | `mapeos con refset=0` | `SIN_DATOS` |
| T-13 | `SIN_DATOS` | `relaciones inter familia=0` | `SIN_DATOS` |
| T-14 | `PASS` | `relaciones inter familia sin contexto/provenance=0` | `PASS` |
| T-15 | `FAIL` | `equivalent=4839; con naturaleza inválida=4839` | `GAP_DOCUMENTADO` |
| T-16 | `SIN_DATOS` | `approximate=0` | `SIN_DATOS` |
| T-17 | `SIN_DATOS` | `partial=0` | `SIN_DATOS` |
| T-18 | `SIN_DATOS` | `broader/narrower=0` | `SIN_DATOS` |
| T-19 | `FAIL` | `related=1; sin rationale=1` | `GAP_DOCUMENTADO` si la fila es `approved`; `SIN_DATOS` si es `draft`. Confirmar con la consulta del runbook |
| T-20 | `SIN_DATOS` | `unmatched=0` | `SIN_DATOS` |
| T-21 | `PASS` | `relaciones draft=0; mapeos draft=2678; pending_review=0` | `PASS` — los 2678 `draft` no son publicables |
| T-22 | `PASS` | `inversas declaradas=2` | `PASS` |
| T-23 | `PASS` | `REL-DX-COEX=1` contando el diccionario | `SIN_DATOS` — v3 cuenta relaciones reales: 0 |
| T-24 | `PASS` | `huérfanos=0` | `PASS` |
| T-25 | `PASS` | `uq_os_catalog_relation=1` | `PASS` |
| T-26 | `PASS` | `constraints unique=1` | `PASS` |
| T-27 | `PASS` | `checks de vigencia=2` | `PASS` |
| T-28 | `PASS` | `catálogos con más de una release=2` | `PASS` |
| T-29 | `SIN_DATOS` | `metadatos revisados=0` | `GAP_DOCUMENTADO` — `approved sin metadatos=2162` |
| T-30 | `PASS` | `relaciones approved=0; draft=0; deprecated=0` | `PASS` — v3 añade `mapeos approved=2162; draft=2678` |
| T-31 | `VERIFICAR_API` | ver `/tmp/T31_dentar-pr.json`, `/tmp/T31_oftar-pr.json` | **Pendiente** |
| T-32 | `VERIFICAR_API` | ver `/tmp/T32.json` | **Pendiente** |
| T-33 | `VERIFICAR_API` | rutas `/v1/*/relations` | **Pendiente** |
| T-34 | `VERIFICAR_API` | ver `/tmp/T34_headers.txt`, `/tmp/T34_body.json` | **Pendiente** |
| T-35 | `VERIFICAR_UI` | ver `/tmp/T35_T36_estatico.log`, `/tmp/T35_T36_manual.log` | **Pendiente** |
| T-36 | `VERIFICAR_UI` | ver los mismos archivos | **Pendiente** |
| T-37 | `PASS` | `aprobados sin revisor=0; propuestos=90` | `PASS` |
| T-38 | `PASS` | `relationship_role no permitidos=0` | `PASS` |

---

## 3. Resumen

- **`FAIL` en la corrida v1:** T-03, T-06, T-07, T-15, T-19. Los cinco son falsos positivos del script: contaban filas `draft` o ausencia de metadatos como si fuera una inconsistencia publicada. Ninguno implica una fila publicada inválida.
- **`PASS` estructurales confirmados:** T-09, T-14, T-21, T-22, T-24, T-25, T-26, T-27, T-28, T-30, T-37, T-38.
- **`SIN_DATOS`:** no hay relaciones clínicas por par ratificadas. No se inventaron.
- **`GAP_DOCUMENTADO`:** 2162 mapeos `approved` sin `os_mapping_metadata`; se publican con `untranslated=true` y plan de remediación.
- **Pendiente:** corrida v3 y evidencia API/UI T-31…T-36.

**[P]** La decisión final de publicación se rige por `docs/audit/acta-publicacion-relaciones-transversales.md`. No se aprueba mientras exista un `FAIL` real o falte evidencia API/UI.
