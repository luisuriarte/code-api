# Acta de decisión de publicación — modelo transversal de relaciones

**Fecha:** `<REGISTRAR>` · **Versión:** 1.0
**Estado:** **PENDIENTE DE FIRMA**. No publica por sí sola.

---

## 1. Objeto

Decidir la publicación de:

1. El contrato aditivo `data.relations{clinical,terminological}` en la API.
2. La ficha reutilizable con insignias Clínica/Terminológica en el portal.
3. El diccionario común de 31 tipos `REL-*`, ya verificado en `origen_codes`.

**No comprende:** la carga de relaciones clínicas por par ni la aprobación de equivalencias terminológicas.

---

## 2. Evidencia mínima exigida

| Evidencia | Referencia |
|---|---|
| Acta de ejecución | `docs/audit/acta-ejecucion-relaciones-transversales.md` |
| Resultado T-01…T-38 | `docs/audit/resultado-T01-T38-relaciones-transversales.md` |
| Verificación SQL | `/tmp/T01_T38_sql.log` |
| Contrato API | `/tmp/T31_dentar-pr.json`, `/tmp/T31_oftar-pr.json`, `/tmp/T32.json`, `/tmp/T34_headers.txt` |
| UI y accesibilidad | `/tmp/T35_T36_estatico.log`, `/tmp/T35_T36_manual.log` |
| Regresión estática | `/tmp/fase5_tests_corregido.log` → `OK: 4110 comprobaciones` |

**[P]** Sin estas referencias completas, la decisión queda `PENDIENTE`.

---

## 3. Regla de decisión

| Condición | Decisión |
|---|---|
| Cualquier `FAIL` en T-01…T-38 | **NO PUBLICAR**. Corregir y repetir. |
| API/UI sin evidencia | **NO PUBLICAR**. Completar runbook. |
| Solo `PASS` y `SIN_DATOS`; sin relaciones clínicas por par cargadas | **PUBLICAR SOSTÉN TÉCNICO**: contrato y ficha con arrays vacíos o solo correspondencias ya aprobadas. |
| Existencia de artefacto ratificado por par | Evaluar carga gobernada en acta separada. |

---

## 4. Recomendación preparada

**[H]** El estado verificado permite publicar el **sostén técnico** del modelo: API, ficha reutilizable y diccionario de tipos.

**[P]** No se recomienda publicar contenido clínico nuevo: sigue sin haber un artefacto ratificado que asigne `REL-*` por par. Las matrices `matriz-conciliacion-clinica-oftar-pr.csv` y `matriz-equivalencias-oftar-pr.csv` permanecen como `propuesta_no_publicada`.

---

## 5. Firma

| Rol | Nombre | Decisión | Fecha |
|---|---|---|---|
| Responsable de ejecución | Luis A. Uriarte | `<REGISTRAR>` | `<REGISTRAR>` |
| Responsable clínico | Luis A. Uriarte | `<REGISTRAR>` | `<REGISTRAR>` |
| Responsable DBA | Luis A. Uriarte | `<REGISTRAR>` | `<REGISTRAR>` |

**Decisión final:** `<REGISTRAR: PUBLICAR SOSTÉN TÉCNICO / NO PUBLICAR>`

**[P]** Esta acta se cierra solo con las tres firmas y la decisión final registrada.
