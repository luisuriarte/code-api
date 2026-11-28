# Clasificación anatómica y áreas clínicas de OFTAR-DX

**Fecha:** 2026-11-28  
**Estado:** propuesta para aprobación. **No implementada; no se crearon categorías de catálogo.**  
**Objetivo:** permitir navegar diagnósticos oftalmológicos por región anatómica y área clínica sin alterar `category`, `clinical_category`, el capítulo fuente CIE-10 ni los identificadores externos.

---

## 1. Principios

**[H]** `CAT-DX` es el único capítulo fuente de OFTAR-DX y `CLIN-DIAG` su categoría clínica por defecto (`categorias_clinicas.sql:107-119,143`).

**[I]** La anatomía, el área clínica, el tipo de concepto y el capítulo del sistema de origen son cuatro dimensiones distintas:

1. **Categoría clínica:** qué tipo clínico general es el ítem: diagnóstico, estudio, procedimiento, etc.
2. **Localización anatómica:** párpado, córnea, retina, glaucoma como eje topográfico/funcional asociado, etc.
3. **Tipo de concepto:** `diagnosis` en OFTAR-DX; en OFTAR-PR, `procedure`, `imaging`, `surgery`, etc.
4. **Capítulo/categoría del sistema de origen:** `CAT-DX` en el catálogo y el prefijo CIE-10 real (`H40`, `H53`, etc.) derivado del identificador externo.

**[P]** No convertir estas cuatro dimensiones en catálogos nuevos ni en códigos `CLIN-*`. La navegación secundaria debe resolverse con atributos y relaciones existentes.

---

## 2. Códigos de trabajo propuestos — no definitivos

> Los códigos `ANAT-*` y `AREA-*` son solo nombres de trabajo de esta propuesta. No son códigos OFTAR, no son CIE-10 y no deben publicarse sin aprobación.

| Código de trabajo | Región/área evaluada | Naturaleza | Evidencia CIE-10-ES 2026 |
|---|---|---|---|
| `ANAT-PAL` | Párpados | Anatómica | H00-H02 |
| `ANAT-LAG` | Aparato lagrimal | Anatómica | H04 |
| `ANAT-ORB` | Órbita | Anatómica | H05 |
| `ANAT-CON` | Conjuntiva | Anatómica | H10-H11 |
| `ANAT-COR` | Córnea/esclera | Anatómica | H15-H18, H22 |
| `ANAT-UVE` | Úvea | Anatómica | H20-H21 |
| `ANAT-CRY` | Cristalino | Anatómica | H25-H28 |
| `ANAT-RET` | Retina/coroides | Anatómica | H30-H36 |
| `ANAT-NEU` | Nervio óptico/neurooftalmología | Anatómica-funcional | H46-H47; H48 sin finales en el CSV |
| `ANAT-MOT` | Motilidad/estrabismo | Anatómica-funcional | H49-H51 |
| `AREA-GLA` | Glaucoma | Área clínica, no anatomía pura | H40, H42 |
| `AREA-REF` | Refracción/trastornos de visión | Funcional | H52-H54 |
| `AREA-TRAU` | Traumatismos oculares | Cross-cutting | S05, fuera de H00-H59 |
| `AREA-SIST` | Manifestaciones oculares de enfermedades sistémicas | Cross-cutting | H36.89, H36.81x/82x |

**[H]** Los traumatismos oculares `S05` están fuera del rango H00-H59 declarado para OFTAR-DX. Su inclusión requiere una decisión de alcance; no debe crearse una categoría DX automáticamente.

**[H]** El área sistémica aparece dentro de H36, por lo que el capítulo fuente sigue siendo H36 aunque se navegue también por `AREA-SIST`.

---

## 3. Implementación sin migración

**[P]** La clasificación secundaria puede implementarse con tablas y campos ya existentes:

| Dimensión | Destino propuesto |
|---|---|
| Región anatómica primaria | `oftar_attribute_definition` / `oftar_attribute_value`, con proyección a `os_catalog_source_attribute` |
| Área clínica secundaria | segundo atributo o relación controlada, según revisión |
| Prefijo CIE-10 derivado | cálculo desde `os_catalog_identifier.value` / `external_code`; no columna nueva |
| Catálogo y capítulo fuente | `os_catalog` + `os_catalog_item_version.category_id='CAT-DX'` |
| Categoría clínica | `os_catalog_item_clinical_category.clinical_category_code='CLIN-DIAG'` |
| Tipo de concepto | `oftar_catalog.concept_kind='diagnosis'` |

**[I]** `ATTR-STRUCTURE` está definido en `oftar_core.sql:257-286` pero no tiene dominio de valores cargado. Cargar valores es inserción de datos en tablas existentes, no cambio estructural.

**[P]** Filtros API aditivos sugeridos: `?anatomy=ANAT-RET&clinical_area=AREA-GLA`. Deben conservar `category` y `clinical_category`; no sustituirlos.

---

## 4. Cuándo sí requeriría cambio estructural

| Necesidad | Sin migración | Requiere cambio estructural |
|---|---|---|
| Una región principal por diagnóstico | Sí, vía atributo existente | No |
| Área clínica simple por diagnóstico | Sí, segundo atributo | No |
| Múltiples regiones simultáneas por diagnóstico | No de forma limpia con una sola columna de atributo | Sí: tabla de relación o estructura multivaluada |
| Mantener `category` y `clinical_category` | Sí, contrato actual | No |
| Derivar prefijo CIE-10 | Sí, desde identificador externo | No |
| Filtros por anatomía/área | Cambio de código de lectura, no DDL | Solo si se exige un campo propio en la API |

**[P]** Recomendación: empezar con un valor anatómico primario y un área clínica cuando aplique. Evitar crear nuevos `relation_type` o `CLIN-*` para cada región.

---

## 5. Gobernanza

**[P]** Toda asignación debe conservar: código OFTAR-DX, identificador CIE-10 original, sistema/edición/versión, región o área propuesta, `source_reference`, `provenance`, `review_status` y revisores.

**[P]** La navegación clínica no modifica el código permanente ni el texto preferido. Si un diagnóstico pertenece a varias áreas, la decisión debe pasar por revisión humana antes de convertirla en relación multivaluada.
