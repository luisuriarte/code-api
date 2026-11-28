# Revisión clínica de OFTAR-DX

**Fecha:** 2026-11-28  
**Alcance:** segunda auditoría clínica y semántica de diagnósticos, previa a aprobación de nuevos seeds.  
**Estado:** propuesta documentada. **No implementada; no publicada; no se generaron seeds definitivos.**  
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` propuesta sujeta a aprobación.

---

## 1. Sistemas identificados

OFTAR-DX no debe presentarse como una sola fuente “CIE-10”. En el repositorio conviven sistemas distintos:

| Sistema / edición | Archivo verificado | Rol propuesto | Idioma de display |
|---|---|---|---|
| **CIE-10-ES 2026** | `tools/sources/cie10/Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv` | **Núcleo para mercado argentino** | `es` de origen, proyectado como `es-AR` |
| **ICD-10-CM 2027** | `tools/sources/cie10/2027-code-descriptions-in-tabular-order.zip` | Referencia externa separada; cubre textos `en` | `en` |
| **CIE-10 de referencia para Argentina** | documentación local y convención del motor | Familia de codificación diagnóstica; requiere declarar edición/procedencia cuando se use | según fuente gobernada |
| **SNOMED CT Argentina Edition** | `tools/sources/snomed_argentina/der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt` | Mapa semántico complementario, **no núcleo de codificación** | RF2/refset, con `effectiveTime` y módulo |
| **CIE-10-PCS** | `tools/sources/cie10/Procedimientos_Tabla_Referencia_CIE10ES_2026.csv` | Procedimientos, referencia para OFTAR-PR; **no diagnóstico** | `es` |

**[H]** CIE-10-ES e ICD-10-CM **no son la misma edición**. El CSV español tiene el año en el nombre y columnas clínicas propias; el ZIP inglés contiene `icd10cm_codes_2027.txt`, `icd10cm_order_2027.txt`, addendas y PDFs.

**[H]** El CSV español H00-H59 tiene **2.661 códigos**, todos `Nodo_Final=1`. El ZIP ICD-10-CM 2027 tiene **2.677 códigos H**; la intersección por código normalizado es **2.660**.

**[H]** La unión propuesta anteriormente es **2.678**: 2.661 del núcleo español más 17 exclusivos ICD-10-CM 2027. `H01.8` existe solo en el CSV español.

---

## 2. Los 17 códigos exclusivos de ICD-10-CM 2027

**[H]** Ninguno aparece en `Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv`. Se conserva la descripción original en inglés; no se inventa traducción.

| # | Código | Descripción original | ¿En CIE-10-ES 2026? | Ubicación en fuente |
|---:|---|---|:---:|---|
| 1 | `H01.81` | Other specified inflammation of right upper eyelid | No | `icd10cm_codes_2027.txt:5751` |
| 2 | `H01.82` | Other specified inflammation of right lower eyelid | No | `icd10cm_codes_2027.txt:5752` |
| 3 | `H01.83` | Other specified inflammation of right eye, unspecified eyelid | No | `icd10cm_codes_2027.txt:5753` |
| 4 | `H01.84` | Other specified inflammation of left upper eyelid | No | `icd10cm_codes_2027.txt:5754` |
| 5 | `H01.85` | Other specified inflammation of left lower eyelid | No | `icd10cm_codes_2027.txt:5755` |
| 6 | `H01.86` | Other specified inflammation of left eye, unspecified eyelid | No | `icd10cm_codes_2027.txt:5756` |
| 7 | `H01.89` | Other specified inflammation of unspecified eye, unspecified eyelid | No | `icd10cm_codes_2027.txt:5757` |
| 8 | `H018A` | Other specified inflammation of right eye, upper and lower eyelids | No | `icd10cm_codes_2027.txt:5758` |
| 9 | `H018B` | Other specified inflammation of left eye, upper and lower eyelids | No | `icd10cm_codes_2027.txt:5759` |
| 10 | `H05.831` | Thyroid orbitopathy, right orbit | No | `icd10cm_codes_2027.txt:6236` |
| 11 | `H05.832` | Thyroid orbitopathy, left orbit | No | `icd10cm_codes_2027.txt:6237` |
| 12 | `H05.833` | Thyroid orbitopathy, bilateral | No | `icd10cm_codes_2027.txt:6238` |
| 13 | `H05.839` | Thyroid orbitopathy, unspecified orbit | No | `icd10cm_codes_2027.txt:6239` |
| 14 | `H40.841` | Neovascular secondary angle closure glaucoma, right eye | No | `icd10cm_codes_2027.txt:7681` |
| 15 | `H40.842` | Neovascular secondary angle closure glaucoma, left eye | No | `icd10cm_codes_2027.txt:7682` |
| 16 | `H40.843` | Neovascular secondary angle closure glaucoma, bilateral | No | `icd10cm_codes_2027.txt:7683` |
| 17 | `H40.849` | Neovascular secondary angle closure glaucoma, unspecified eye | No | `icd10cm_codes_2027.txt:7684` |

**[H]** Los 17 códigos tampoco aparecen en los archivos de addenda 2027 revisados.

**[I]** Son subespecificaciones propias de ICD-10-CM por lateralidad, localización o granularidad. `H01.8` en CIE-10-ES es un código final más general; no puede declararse equivalencia uno a uno con `H01.81`…`H018B` sin decisión gobernada.

**[P]** Tratamiento: conservarlos como **referencia externa ICD-10-CM 2027**, con identidad explícita de sistema, edición, versión, release e idioma. No incorporarlos automáticamente al conjunto CIE-10-ES ni asignarles texto `es-AR` inventado.

---

## 3. Riesgo semántico de la propuesta actual

**[H]** `tools/sources/oftalmologico/oftar/importar_cie10_dx.sql:153-164` registra `system_code='CIE-10'` para todo el conjunto importado.

**[H]** `sql/03_oftar/sync_oftar_dx_to_os.sql` usa `source_reference='CIE-10-ES 2026 / ICD-10-CM 2027'` y `provenance='imported_cie10'` en la proyección al motor canónico.

**[H]** `oftar_external_identity.sql` tiene unicidad por `(system_code, code_normalized)` sin edición ni release.

**[I]** Reutilizar `CIE-10` para dos ediciones pierde trazabilidad: un código exclusivo CM podría parecer parte del núcleo ES/argentino. Además, los textos en inglés se están tratando como huecos idiomáticos del mismo conjunto, cuando en realidad son fuentes distintas.

---

## 4. Política de núcleo y referencias

**[P] Núcleo:** CIE-10-ES 2026, H00-H59, con texto español oficial y 2.661 códigos. Es la base diagnóstica para el mercado argentino de OFTAR-DX.

**[P] Referencia externa:** ICD-10-CM 2027, con los 17 códigos exclusivos identificados como tales. Pueden proyectarse como ítems OFTAR-DX solo si la gobernanza decide mantenerlos en el catálogo, pero siempre con identidad `ICD-10-CM`, `version=2027`, `release` del ZIP, `language=en` y procedencia CDC/NCHS-CMS según el paquete local.

**[P] SNOMED CT Argentina Edition:** sistema complementario. No reemplaza CIE-10-ES, no inventa códigos OFTAR-DX y no se asocia por similitud de texto. Su refset oficial aporta `effectiveTime`, `moduleId`, `refsetId` y `mapTarget` para relaciones verificadas.

**[P] CIE-10-PCS:** referencia de procedimientos, no diagnósticos. No debe generar códigos OFTAR-DX ni confundirse con CIE-10-ES.

---

## 5. Cobertura idiomática correcta

| Situación | Cantidad | Tratamiento propuesto |
|---|---:|---|
| Códigos con texto ES y EN | 2.660 | Dos versiones; la vista prefiere `es-AR`. |
| Solo ES | 1 (`H01.8`) | Sin versión `en`; no se inventa texto inglés. |
| Solo EN, exclusivos ICD-10-CM | 17 | Sin versión `es-AR`; se conservan como referencia CM, no como hueco del núcleo ES. |
| Total esperado | 2.678 | Solo tras aprobación y con identidad por edición. |

**[H]** `sync_oftar_dx_to_os.sql:71-84` no rellena el idioma ausente. Esa regla es correcta y debe conservarse.

---

## 6. Cierre

**[I]** El error semántico principal no es el conteo de 2.678, sino presentar dos ediciones como una sola fuente CIE-10. La corrección debe hacerse en la capa de identidad y procedencia antes de generar nuevos seeds.

**[P]** No aprobar seeds hasta que se decida formalmente: (1) sistema canónico, (2) sistema para los 17 códigos CM, (3) campos de edición/versión/release/procedencia, y (4) regla de idioma para textos ausentes.
