# Taxonomía OFTAR propuesta para aprobación

**Fecha:** 2026-11-28  
**Estado:** propuesta. **No implementada; no se renombraron categorías históricas.**  
**Principio:** el contrato público se conserva. `category` sigue siendo el capítulo fuente; `clinical_category` es aditivo; anatomía, área clínica y tipo de concepto se modelan como atributos o relaciones.

---

## 1. Taxonomía vigente

**[H]** `oftar_core.sql:83-101` y `oftar_categorias.csv` definen cuatro raíces y ocho hojas para OFTAR-PR:

- Raíces: `GRP-EVAL`, `GRP-DIAG`, `GRP-TER`, `GRP-OCUL`.
- Hojas: `CONSULT`, `EXAM`, `DIAG`, `IMG`, `TER`, `CIR`, `OCUL`, `LAGR`.
- OFTAR-DX: `CAT-DX`.

**[H]** `categorias_clinicas.sql` agrega 12 códigos `CLIN-*` sin renombrar `os_catalog_category`.

**[H]** La API conserva `category` y agrega `clinical_category`/`clinical_category_code` (`CatalogEngineService.php`).

---

## 2. Veredicto semántico

**[H]+[I]** `CONSULT, EXAM, DIAG, IMG, TER, CIR, OCUL, LAGR` son coherentes como **capítulos fuente de prestación**: combinan propósito, modalidad y anatomía en un mismo nivel. No deben reemplazarse por una taxonomía clínica nueva porque romperían deep links y contratos históricos.

**[H]** El importador de PR no usa `CONSULT`, `OCUL` ni `LAGR`; clasifica por un orden de regex `IMG > CIR > TER > DIAG > EXAM`. El conteo local de los 154 literales es `EXAM 93`, `CIR 36`, `TER 12`, `DIAG 10`, `IMG 3`.

**[I]** Ese orden es una regla técnica de importación, no una decisión clínica documentada. Produce solapamientos: `IMG` compite con `CIR` en cirugía con endoláser; `CIR` compite con `TER` en cirugía refractiva con láser.

**[I]** `GRP-OCUL → CLIN-ANAT` y `OCUL/LAGR → CLIN-PROC` son inconsistencias latentes si una versión llegara a usar una raíz. Hoy los 154 usan hojas; no hay evidencia de que el caso esté activo en producción.

---

## 3. Qué conservar

| Elemento | Decisión |
|---|---|
| Dominio `oftar` | Conservar; no crear dominios por catálogo. |
| Catálogos `oftar-pr`, `oftar-dx`, CAO, Regional | Conservar. |
| Prefijos `OFT-PR-`, `OFT-DX-` | Conservar; no reutilizar retirados. |
| `CONSULT, EXAM, DIAG, IMG, TER, CIR, OCUL, LAGR`, `CAT-DX`, `GRP-*` | Conservar como capítulos fuente/navegación; no renombrar. |
| 12 códigos `CLIN-*` | Conservar; no crear nuevos para OFTAR. |
| API `category` + `clinical_category` | Conservar. |
| `concept_type`, `concept_kind`, atributos OFTAR | Conservar como ejes separados. |

**[P]** Las raíces `GRP-*` deben documentarse como agregadores de navegación, no como categoría clínica asignable a versiones. No borrar sus filas históricas.

---

## 4. Qué agregar como atributo o relación

| Dimensión | Destino | Observación |
|---|---|---|
| Localización anatómica | `ATTR-STRUCTURE` o atributo anatómico específico | Un valor primario por ítem; dominio de valores, no nueva categoría. |
| Área clínica transversal | segundo atributo o relación | Glaucoma, refracción, traumatismo, sistémico. |
| Lateralidad | `ATTR-LATERALITY` | Ya existe y tiene valores sembrados. |
| Modalidad/técnica | `ATTR-MODALITY` | Definido sin dominio cargado; completar por gobernanza. |
| Tipo de concepto | `concept_kind` / `concept_type` | No convertir en `CLIN-*`. |
| Relación PR↔DX | `oftar_concept_diagnosis` | Indicación habitual/posible/contraindicación/contextual. |
| Capítulo del sistema externo | `os_catalog_item_version.category_id` + identificador CIE | No duplicar en una columna paralela. |

**[I]** `ATTR-STRUCTURE` está definido pero sin valores (`oftar_core.sql:257-286`). Cargar su dominio no es migración estructural.

---

## 5. Modelo de correspondencias

### 5.1 Tablas y campos a usar

- `os_concept_mapping`: equivalencia, related, broader, narrower; `relationship_role`; `review_status`.
- `os_mapping_metadata`: `mapping_nature` (`univocal`, `multiple`, `partial`, `approximate`, `not_mappable`), método, confianza, vigencia y revisión.
- `os_catalog_relation`: relaciones con `relation_kind`, `provenance`, `reviewed_by`, `context_text`, `valid_from/to`.
- `oftar_concept_mapping`, `oftar_diagnosis_mapping`: espejos editoriales de dominio.
- `os_oftar_nomenclador_match`: cola de propuestas CAO/Regional → OFTAR-PR.
- `os_field_review`: revisión por campo con hash; publica `external_display`/`clinical_rationale` solo cuando está aprobado.

### 5.2 Convención de clases

| Clase de la auditoría | Representación propuesta |
|---|---|
| `equivalencia_clinica_exacta` | `mapping_type='equivalent'` + `mapping_nature='univocal'` + evidencia y revisión. |
| `equivalencia_clinica_aproximada_parcial` | `mapping_type='related'` + `mapping_nature='partial'` o `approximate`. Nunca `equivalent`. |
| `concepto_mas_amplio` | `mapping_type='broader'` con dirección OFTAR → sistema externo, revisada. |
| `concepto_mas_especifico` | `mapping_type='narrower'` con la misma convención de dirección. |
| `procedimientos_relacionados` | `os_catalog_relation` con `relation_kind='clinical'`/`'editorial'` y `context_text`. |
| `procedimientos_diferentes` / sin correspondencia | sin fila publicable; conservar propuesta rechazada como histórico. |
| `correspondencia_incierta` | propuesta en `os_oftar_nomenclador_match` con revisión pendiente; no publicar. |

**[P]** La dirección de `broader`/`narrower` debe ratificarse por escrito: se propone que describa la relación del concepto OFTAR respecto del sistema externo. No asumir dirección de filas heredadas sin revisión.

---

## 6. Matriz sin migración frente a cambio estructural

| Necesidad | Sin migración | Requiere cambio estructural |
|---|---|---|
| Conservar categorías históricas y `clinical_category` | Sí | No |
| Documentar raíces como navegación | Sí | No |
| Clasificación DX por región/área | Sí, con atributos existentes | Solo si se exige multivaluado |
| Filtros por anatomía/área | Cambio de código de lectura | No |
| Equivalencia/parcial/broader/narrower | Sí, con `os_concept_mapping` + metadata | No |
| Relación asociativa PR↔DX | Sí, con `os_catalog_relation`/`oftar_concept_diagnosis` | No, salvo nuevos tipos semánticos innecesarios |
| Rol `diagnosis_concept` | Alternativa: `observation_concept` + metadata | Sí, si se agrega al `CHECK` |
| `not_mappable` en DX | Alternativa: `related` + `mapping_nature='not_mappable'` | Sí, si se agrega al `CHECK` |
| Publicación de pares CAO | Sí, resolviendo `target_code` por identificador | No |
| Gobernanza de textos de mapeo | Sí, con `os_field_review` | No |

**[I]** “Sin migración” no significa “sin revisión”: toda corrección de datos o publicación requiere evidencia y dos aprobaciones humanas.

---

## 7. Cierre

**[I]** La taxonomía actual es estable como contrato pero débil como semántica clínica. La solución no es renombrar, sino fijar los capítulos como dimensión de origen y mover anatomía/área/tipo a atributos y relaciones.

**[P]** Ninguna equivalencia nueva se publica sin evidencia, `review_status='approved'`, revisión humana y hash vigente.
