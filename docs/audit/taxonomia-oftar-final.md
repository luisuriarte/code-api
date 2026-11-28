# Taxonomía definitiva de OFTAR-PR

**Fecha:** 2026-11-28
**Etapa:** tercera revisión — solo documentación.
**Estado:** propuesta para aprobación. **No se renombraron ni movieron categorías históricas.**
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta.

---

## 1. Decisión de conservación

**[H]** `oftar_categorias.csv` contiene 13 filas: **4 raíces** (`GRP-EVAL`, `GRP-DIAG`, `GRP-TER`, `GRP-OCUL`) y **8 hojas** (`CONSULT`, `EXAM`, `DIAG`, `IMG`, `TER`, `CIR`, `OCUL`, `LAGR`) en OFTAR-PR, más `CAT-DX`.

**[H]** `categorias_clinicas.sql` define 12 códigos `CLIN-*`, 26 mapas de categoría fuente y 8 defaults por catálogo. La API conserva `category` y agrega `clinical_category`/`clinical_category_code` (`CatalogEngineService.php`; `browse-y-categorias.md:60-63`).

**[P] Decisión:** conservar `CONSULT, EXAM, DIAG, IMG, TER, CIR, OCUL, LAGR`, `GRP-*`, `CAT-DX` y los 12 `CLIN-*`. **No crear nuevos códigos `CLIN-*` para OFTAR**, no renombrar capítulos y no tocar URLs ni contratos.

**[I]** Renombrar `IMG` a `DIAG-IMG` o fusionar `OCUL/LAGR` en una sola categoría anatómica rompería deep links y el facet histórico sin aportar semántica que ya puede resolverse con atributos.

---

## 2. Dimensiones que la taxonomía debe separar

| Dimensión | Dónde vive hoy | Tratamiento definitivo |
|---|---|---|
| Tipo de prestación | `os_catalog_category` (`CONSULT`, `EXAM`, `CIR`, …) | **Categoría fuente**; sigue siendo `category` en API. |
| Área anatómica | Hoy mezclada en `OCUL`, `LAGR` y en el texto | Atributo `ATTR-STRUCTURE` / valores `ANAT-*` (`clasificacion-anatomica-oftar-final.md`). |
| Especialidad | No existe como categoría | Área clínica `AREA-*`; no nueva `CLIN-*`. |
| Modalidad diagnóstica | Mezclada en `IMG`/`DIAG` | Atributo `ATTR-MODALITY` (OCT, RFG, ecografía, Goldmann, electrofisiología). |
| Técnica terapéutica | Mezclada en `TER`/`CIR` | Atributo de técnica (láser, crioterapia, IPL, facoemulsificación). |
| Tipo de intervención | `CIR` frente a `TER` | Se decide por el acto, no por el instrumento: cirugía con láser sigue siendo `CIR`. |

**[I]** La regla anterior (`IMG > CIR > TER > DIAG > EXAM`) clasificaba por aparición de palabras clave, por lo que un mismo acto podía caer en `IMG` y `CIR`, o en `CIR` y `TER`, según el orden de evaluación.

---

## 3. Reglas de asignación corregidas

**[H]** El conteo de los 154 códigos del Nomenclador Nacional con la regla actual es `EXAM 93`, `CIR 36`, `TER 12`, `DIAG 10`, `IMG 3`. `CONSULT`, `OCUL` y `LAGR` no son usados por el importador actual (`taxonomia-oftar-propuesta.md:27`).

**[P]** Secuencia de decisión exclusiva, aplicada en este orden (la primera coincidencia gana):

| Orden | Regla | Categoría | Atributos obligatorios |
|---:|---|---|---|
| 1 | Texto declara contacto de consulta sin acto instrumental propio | `CONSULT` | área clínica, rango etario si aplica |
| 2 | Texto declara cirugía, resección, implante, sutura, queratoplastia, trabeculectomía, vitrectomía o abordaje quirúrgico | `CIR` | `ANAT-*`, técnica, lateralidad |
| 3 | Texto declara terapia no quirúrgica: láser terapéutico, crioterapia, inyección, IPL, termoterapia | `TER` | técnica, sesiones |
| 4 | Texto declara adquisición de imagen: OCT, angio-OCT, RFG/angiografía, retinografía, ecografía, HRT, confocal | `IMG` | `ANAT-*`, modalidad, lateralidad |
| 5 | Texto declara estudio funcional: campo visual, electrofisiología, test sensorial/motor, curva de presión | `DIAG` | modalidad, protocolo |
| 6 | Examen clínico directo o medición simple: oftalmoscopia, biomicroscopía, tonometría, agudeza visual, exoftalmometría | `EXAM` | `ANAT-*`, lateralidad |
| 7 | Sin coincidencia con las reglas anteriores | `REVISION` (**centinela interno**) | ninguna publicación automática |

**[P]** Resolución de conflictos:

- Si aparece “cirugía” y también “láser”, gana `CIR`; el láser se registra como técnica. Ejemplo: cirugía refractiva con excimer → `CIR` + técnica `excimer`, no `TER`.
- Si aparece “láser” y el propósito es imagen (p. ej. confocal), gana `IMG` o `EXAM` según corresponda; no `TER`.
- Si aparece “por sesión” y “tratamiento completo”, la unidad es atributo de alcance, no categoría distinta.
- `OCUL` y `LAGR` dejan de asignarse automáticamente: pasan a ser capítulos históricos vigentes para lectura de datos existentes; la anatomía se expresa con `ANAT-*` y la clasificación de prestación con las reglas 1–6.

**[I]** Esta secuencia no modifica datos existentes: solo documenta cómo debe asignarse la categoría cuando se apruebe la reconstrucción. Las filas publicadas con `OCUL`/`LAGR` conservan su valor histórico.

---

## 4. Precedencia y contradicciones entre capas

**[H]** Tres clasificaciones del mismo universo conviven en los documentos: la taxonomía oficial (8 hojas), las etiquetas literales de la primera matriz (`EXAM 107`, `CIR 81`, `OCUL 37`, `CONSULT 22`, `LAGR 19`, `TER 13`) y la inferencia de la segunda matriz (`CIR 104`, `EXAM 101`, `IMG 44`, `TER 51`, `OCUL 50`, `CONSULT 35`, `LAGR 26`, `REVISION 22`).

**[P]** Regla de prevalencia:

1. `category` en API = capítulo fuente histórico aprobado; nunca se recalcula en lectura.
2. Las etiquetas literales y la inferencia clínica son **worklists**; no sustituyen `category`.
3. `REVISION` y `SIN_CLASIFICAR` son centinelas de revisión: si una fila queda en ellos, se publica como “sin relación gobernada”, nunca como categoría API ni `CLIN-*`.
4. `DIAG` e `IMG` son capítulos oficiales vigentes aunque una matriz no los use; esa matriz clasificaba texto literal, no la taxonomía.
5. `GRP-*` son agregadores de navegación; no se asignan a versiones de concepto.

**[I]** La aparente inconsistencia `GRP-OCUL → CLIN-ANAT` frente a `OCUL/LAGR → CLIN-PROC` no está activa en los 154 códigos, que usan hojas. Debe documentarse como riesgo latente, no corregirse borrando filas.

---

## 5. Cierre

**[I]** La taxonomía actual es estable como contrato; su debilidad era operativa (reglas de asignación solapadas) y de semántica (anatomía y técnica dentro de la categoría).

**[P]** Queda resuelto: conservar 8 hojas + raíces + `CAT-DX` + 12 `CLIN-*`, mover anatomía/modalidad/técnica a atributos y usar la secuencia de decisión exclusiva para futuras asignaciones. Queda pendiente la aprobación de esa secuencia antes de aplicarla en cualquier generador de seeds.
