# Universo de diagnósticos de OFTAR-DX

**Fecha:** 2026-11-28
**Etapa:** tercera revisión — definición documentada del universo.
**Estado:** propuesta para aprobación. **No se generaron seeds ni se importaron diagnósticos.**
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0. Ante contradicción, prevalece lo verificado y lo definido allí (§0 y §3).
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta.

---

## 1. Conteos verificados

| Fuente | Evidencia | Conteo |
|---|---|---:|
| CIE-10-ES 2026 | `tools/sources/cie10/Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv` (74.260 filas) | **2.661** códigos H00-H59, todos `Nodo_Final=1` |
| ICD-10-CM 2027 | `tools/sources/cie10/2027-code-descriptions-in-tabular-order.zip` → `Code Descriptions/icd10cm_codes_2027.txt` (74.879 líneas; 3.330 códigos `H*`) | **2.677** códigos H00-H59 |
| Intersección por código normalizado | cruce sin puntos | **2.660** |
| Exclusivo CIE-10-ES | `H01.8` | **1** |
| Exclusivos ICD-10-CM | `H01.81`…`H018B`, `H05.831`…`H05.839`, `H40.841`…`H40.849` | **17** |
| Unión documentada | 2.661 + 17 | **2.678** |
| Versiones esperadas documentadas | 2.661 ES + 2.677 EN | **5.338** |

**[H]** Conteo directo del CSV español: 74.260 filas de datos, 2.661 H00-H59, 90 S05 y 9 H36.8\*. Conteo directo del archivo inglés principal: 74.879 líneas, 3.330 códigos `H*` y 2.677 H00-H59.

**[I]** La cifra de 23.292 códigos totales del archivo inglés, citada en documentos anteriores, no se reproduce con el conteo directo (74.879). No se incorpora a la especificación; los conteos H sí son reproducibles.

**[H]** El importador `tools/sources/oftalmologico/oftar/importar_cie10_dx.sql:69` filtra con `c.codigo ~ '^H(0[0-9]|[1-5][0-9])'`. Por diseño quedan fuera S05, T15, T26, T85 y las manifestaciones sistémicas de otros capítulos.

---

## 2. Definición de conjuntos

| Conjunto | Composición | Tratamiento propuesto |
|---|---|---|
| **Candidatos iniciales** | 2.661 códigos CIE-10-ES 2026 H00-H59, `Nodo_Final=1` | **Conjunto candidato, no aprobado para publicación**. Fuente estructurada inicial; no etiquetada como norma argentina sin acta. |
| **Núcleo propuesto de OFTAR-DX** | Los candidatos iniciales que la gobernanza apruebe | Se denominará “núcleo inicial” hasta que exista acta sobre la edición CIE-10 de referencia en Argentina. No se afirma normatividad. |
| **Referencias externas** | 17 códigos exclusivos ICD-10-CM 2027 | Identidad `ICD-10-CM`, `version=2027`, `language=en`, procedencia CDC/NCHS-CMS según paquete local. No se incorporan automáticamente como CIE-10 ni se traducen. |
| **Referencias externas adicionales** | S05, T15, T26, T85, E11.\* y afines | Solo con justificación de pertinencia oftalmológica y decisión de alcance. No se importan masivamente. |
| **Proyección condicional** | 2.661 + 17 = 2.678 | Solo si se aprueba proyectar los códigos CM como ítems `OFT-DX-NNNNNN`; la cifra debe escribirse “2.661 CIE-10-ES + 17 ICD-10-CM”. |

**[P] Regla de incorporación justificada:** un código se incorpora solo si (1) es `Nodo_Final=1` o equivalente verificable, (2) pertenece al dominio oftalmológico por anatomía, función o manifestación documentada, (3) conserva sistema/edición/versión/release/idioma/procedencia y (4) supera revisión humana con dos aprobaciones.

**[P]** No limitar artificialmente OFTAR-DX a H00-H59: la restricción actual del importador es técnica, no clínica. Tampoco incorporar indiscriminadamente todos los diagnósticos de otros capítulos.

---

## 3. Diagnósticos fuera de H00-H59

**[H]** `Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv` contiene **90 códigos S05**, todos finales. Ejemplos verificados:

| Código | Línea CSV | Descripción original | Tratamiento `[P]` |
|---|---:|---|---|
| `S05.00XA` | 25651 | Traumatismo de conjuntiva y abrasión de córnea sin cuerpo extraño de ojo no especificado, contacto inicial | Referencia traumatológica; requiere decisión de alcance. |
| `S05.01XA` | 25654 | Traumatismo de conjuntiva y abrasión de córnea sin cuerpo extraño del ojo derecho, contacto inicial | No importar automáticamente como OFTAR-DX. |
| `S05.10XA` | 25660 | Contusión de globo ocular y tejidos orbitarios de ojo no especificado, contacto inicial | Igual criterio. |
| `T15.00XA` | 55416 | Cuerpo extraño en córnea, ojo no especificado, contacto inicial | Igual criterio. |
| `T26.00XA` | 57981 | Quemadura de párpado y área periocular no especificados, contacto inicial | Igual criterio. |
| `T85.21XA` | 65056 | Fallo mecánico de lente intraocular, contacto inicial | Igual criterio. |
| `E11.319` | 3429 | Diabetes mellitus tipo 2 con retinopatía diabética no especificada sin edema macular | Manifestación sistémica; no modifica el núcleo H. |
| `E11.3211` | 3430 | Diabetes mellitus tipo 2 con retinopatía diabética no proliferativa leve con edema macular, ojo derecho | Igual criterio. |

**[I]** `AREA-TRAUMA` permite navegar sobre códigos H relacionados con traumatismo (p. ej. H21.1, H26.8) sin extender el rango. Los códigos S05/T/T85/E11 requieren una decisión editorial explícita: si se incorporan, deben ser conceptos propios con identidad de capítulo de origen, no una reetiquetación de H00-H59.

**[P] Decisión propuesta:** conservarlos fuera del núcleo inicial y registrarlos como referencias externas candidatas a incorporación justificada, con Revisión de alcance dedicada. No se crea una categoría `CLIN-*` para ellos.

---

## 4. Manifestaciones oculares de enfermedades sistémicas

**[H]** Hay **9 códigos `H36.8*`**, todos `Nodo_Final=1`, dentro de H00-H59:

`H36.811`, `H36.812`, `H36.813`, `H36.819`, `H36.821`, `H36.822`, `H36.823`, `H36.829` (retinopatía drepanocítica no proliferativa/proliferativa por lateralidad) y `H36.89` (otros trastornos de retina en enfermedades clasificadas bajo otro concepto).

**[P]** Pertenecen al núcleo por su código H y se navegan adicionalmente con el área clínica `AREA-SIST`. Eso no crea un nuevo diagnóstico ni duplica el código. Los códigos E11.\* de la tabla anterior quedan como referencia externa: describen la enfermedad sistémica, no el trastorno oftalmológico codificado en H.

---

## 5. Diagnósticos que afectan múltiples estructuras

**[P]** Representación sin duplicar conceptos:

1. **Región principal:** atributo gobernado `ATTR-STRUCTURE` o equivalente (`oftar_core.sql:257-286`).
2. **Área clínica secundaria:** segundo atributo controlado, p. ej. `AREA-SIST` para H36.8\* o `AREA-TRAUMA` para navegación trauma-related.
3. **Múltiples regiones/áreas simultáneas:** relación desde `os_catalog_relation` o estructura multivaluada existente. Si no hay soporte limpio, evaluar ampliación futura, **sin** crear nuevos códigos OFTAR-DX ni repetir el diagnóstico.
4. **Contrato:** conservar `category` y `clinical_category`; derivar el prefijo CIE-10 desde el identificador externo. Filtros aditivos sugeridos: `?anatomy=ANAT-RET&clinical_area=AREA-SIST`.

**[I]** Un mismo diagnóstico puede pertenecer a retina y coroides, o a retina médica y enfermedad sistémica; la cardinalidad uno a uno sería clínicamente incorrecta.

---

## 6. Vinculación con SNOMED CT Argentina Edition

**[H]** Archivo `der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt`: columnas RF2 `id, effectiveTime, active, moduleId, refsetId, referencedComponentId, mapGroup, mapPriority, mapRule, mapAdvice, mapTarget, correlationId, mapCategoryId`. Refset usado: `447562003` (`tools/sources/snomed_argentina/03_postcarga.sql:356-369`).

| Métrica verificada | Valor |
|---|---:|
| Filas de datos | 217.373 |
| Filas `active=1` | 155.106 |
| Activas con `mapTarget` no vacío | 130.055 |
| Activas con destino CIE-10 H00-H59 | **6.783** |
| Conceptos SNOMED únicos con destino H | 6.538 |
| Códigos CIE-10 H destino únicos | 260 |

**[P]** Cadena mínima de vinculación, sin importar SNOMED completo:

```text
SNOMED referencedComponentId
  → v_sct_cie10.mapTarget (active=1, refsetId=447562003)
  → cie10_codes.codigo (normalización cuando aplique)
  → oftar_diagnosis_mapping (system_code declarado por edición)
  → OFT-DX-NNNNNN
  → os_catalog_item / os_concept_mapping (review_status='draft')
```

**[P]** Filtrar el destino con `^H(0[0-9]|[1-5][0-9])`: solo 6.783 de los 130.055 mapeos activos caen en H00-H59. Registrar `mapping_type='related'` inicialmente, nunca `exact` por similitud; conservar `mapRule`, `mapAdvice` y `mapCategoryId` en `clinical_rationale` (p. ej. la advertencia de posición primaria de `82571000119107 → H36.0`). Mantener `review_status='draft'` hasta revisión humana.

**[P]** No usar este mapa para equivalencias de OFTAR-PR.

---

## 7. Cierre

**[I]** El universo real no es una sola lista de 2.678 códigos equivalentes: es un núcleo estructurado en español, una referencia externa estadounidense separada y un conjunto de diagnósticos oftalmológicos de otros capítulos pendientes de decisión de alcance.

**[P]** Queda resuelto el criterio de incorporación y la representación de multi-estructura. Quedan pendientes: el acta sobre la edición CIE-10 argentina, la decisión sobre los 17 códigos CM, la incorporación o no de S05/T/E11 y la ratificación de los identificadores `ANAT-*`/`AREA-*`.
