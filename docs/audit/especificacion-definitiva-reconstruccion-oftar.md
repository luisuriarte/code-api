# Especificación definitiva para la reconstrucción de OFTAR

**Versión:** 1.0
**Fecha de revisión:** 2026-11-28
**Estado:** Aprobada como base técnica para iniciar la implementación controlada.
**Alcance:** OFTAR-PR y OFTAR-DX.
**Tipo de documento:** Especificación funcional y técnica.
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta sujeta a aprobación explícita.

> Esta aprobación es **documental y técnica**: fija la base sobre la que puede iniciarse la implementación controlada. **No autoriza seeds, migraciones, importaciones ni publicación.** Toda reconstrucción queda supeditada a una autorización explícita posterior, al acta de solo lectura de la etapa 1 y a las firmas clínicas correspondientes. El plan canónico de 10 etapas está en `plan-implementacion-controlada-oftar.md`.

---

## 0. Documentos integrados

Esta especificación integra y gobierna los nueve entregables de la tercera revisión:

1. `politica-identificacion-oftar-final.md`
2. `clasificacion-anatomica-oftar-final.md`
3. `aprobacion-conciliacion-oftar-pr.md`
4. `universo-diagnosticos-oftar-dx.md`
5. `taxonomia-oftar-final.md`
6. `modelo-funcional-canonico-oftar.md`
7. `extensibilidad-futura-oftar.md`
8. `arquitectura-tecnica-oftar-final.md`
9. `especificacion-definitiva-reconstruccion-oftar.md` (este documento)

**Regla de prevalencia `[P]`:**

1. Lo implementado y verificable (`os_catalog`, contratos API, categorías históricas, gobernanza) prevalece sobre narrativas históricas.
2. La semántica corregida de la tercera revisión prevalece sobre la segunda donde esta llamó “núcleo argentino” a CIE-10-ES.
3. Las matrices y conteos son **worklists u objetivos condicionados**, nunca afirmaciones de producción.
4. Ninguna cifra de una capa puede usarse como afirmación de otra.

---

## 1. Arquitectura definitiva

**[H]** El motor canónico es `os_catalog` con `os_catalog_release`, `os_catalog_category`, `os_catalog_item`, `os_catalog_item_version`, `os_catalog_term`, `os_catalog_identifier` y `os_concept_mapping` (`sql/02_catalogs/origen_catalog_engine.sql:13-134`). La gobernanza usa `os_field_review`, `os_localized_text`, `os_governance_request/review/decision`, `os_audit_log` append-only y `os_catalog_apply_governed_change` SECURITY DEFINER (`sql/07_multilingue`, `sql/08_arquitectura`).

**[P] Decisiones:**

- `oftar` es **dominio funcional de búsqueda y familia de catálogos**, no un valor de `os_catalog.domain_type` (cuyo `CHECK` no lo admite). Los catálogos son `oftar-pr` y `oftar-dx`. No crear motor paralelo, catálogos duplicados ni proponer `domain_type='oftar'` sin ampliación aprobada.
- Prefijos permanentes `OFT-PR-NNNNNN` y `OFT-DX-NNNNNN`; no reutilizar `OFTAR-PR-`/`OFTAR-DX-`.
- CAO y Regional NOA conservan su numeración original como catálogos de origen; no se convierten en `oftar-pr`.
- `v_oftar_search_catalog` publica solo versiones `review_status='approved'`.
- Toda escritura futura pasa por gobernanza con dos revisiones y traza en `os_audit_log`.

---

## 2. Estructura de OFTAR-PR

**[H]** Núcleo: 154 códigos del Nomenclador Nacional 2025 (`sql/03_oftar/fuente_nomenclador_oftar_pr.sql`), con descripción original conservada. Fuentes complementarias: CAO (143) y Regional NOA (136).

**[I]** El núcleo es válido pero no agota las fuentes. La conciliación clínica tiene 433 filas con 8 clases de relación; todas sin publicar.

**[P] Conciliación:**

- 13 pares / 26 filas **propuestos documentalmente** como equivalentes (la etiqueta de la matriz dice «exactas»; el valor persistible real es `mapping_type='equivalent'`); no están clínicamente aprobados.
- 6 pares / 12 filas a degradar o corregir: HD Analizer, láser femto, `306116`↔`461302`, `306129`↔`460111`, informes clínicos y autorefractometría digital.
- Corrección obligatoria de la justificación RFG: las descripciones dicen “no incluye fluoresceína”.
- 48 registros de CAO/Regional sin cobertura NN: 18 atributos, 8 variantes, 6 duplicados, 3 relacionados, 3 candidatos a concepto nuevo, 2 no incorporables y 8 pendientes de revisión.
- Candidatos a concepto canónico nuevo: CAO `460106`, Regional `305003`, Regional `305041`. Requieren aprobación; no se crean automáticamente.

**[P] UVR:** se incorporarán en etapa posterior solo para prestaciones `oftar-pr`, con UVR de trabajo profesional, gastos de práctica, responsabilidad profesional y total, unidad de valoración, modelo/versión, vigencia, justificación y aprobación. Los importes de CAO y Regional se mantienen separados; no se convierten a UVR. **OFTAR-DX no recibe UVR.**

---

## 3. Estructura de OFTAR-DX

**[H]** CIE-10-ES 2026 tiene 2.661 códigos H00-H59, todos finales. ICD-10-CM 2027 tiene 2.677 códigos H; intersección 2.660; 17 exclusivos CM; 1 exclusivo ES (`H01.8`).

**[P] Conjuntos:**

| Conjunto | Cómputo | Estado |
|---|---|---|
| Candidatos iniciales | 2.661 CIE-10-ES 2026 H00-H59 | **Conjunto candidato, no aprobado para publicación**; fuente estructurada inicial en español, no etiquetada como norma argentina. |
| Núcleo propuesto | Los candidatos aprobados por gobernanza | “Núcleo inicial” hasta acta sobre la edición CIE-10 argentina. |
| Referencia externa CM | 17 códigos exclusivos | Identidad ICD-10-CM 2027; no auto-incorporados, no traducidos. |
| Referencias externas adicionales | S05, T15, T26, T85, E11.\* | Solo con decisión de alcance justificada. |
| Proyección condicional | 2.661 + 17 = 2.678 | Solo si se aprueba; escribir siempre “2.661 CIE-10-ES + 17 ICD-10-CM”. |

**[H]** Hay 90 códigos S05 finales fuera de H00-H59 y 9 códigos H36.8\* finales dentro. H48 no existe como nodo final utilizable.

**[P]** Las manifestaciones sistémicas H36.8\* se navegan con `AREA-SIST` sin duplicar el diagnóstico. Los códigos S05/T/E11 quedan como referencias externas candidatas; no se importan masivamente. La multi-estructura se resuelve con atributos y relaciones, no con nuevos códigos.

**[P]** SNOMED CT Argentina Edition se vincula solo desde el refset oficial `447562003`, filtrando destino H00-H59: 6.783 de 130.055 mapeos activos con destino. `mapping_type='related'`, `review_status='draft'`, `mapAdvice` conservado en `clinical_rationale`; no importar SNOMED completo ni usarlo para equivalencias de procedimientos.

---

## 4. Política de identificación externa

**[H]** `tools/sources/cie10_argentina/readme.md:3-7` declara que CIE-10-ES 2026 es la 6.ª edición publicada por el Ministerio de Sanidad de España. No hay evidencia local de una edición argentina normativa de CIE-10.

**[P] Todo identificador externo debe distinguir:** sistema, edición, versión, release/fecha de publicación, código original, descripción original, idioma, procedencia y vigencia cuando esté disponible.

| Sistema | Rol | Regla |
|---|---|---|
| CIE-10-ES 2026 | Fuente estructurada inicial y referencia complementaria | No presentarla como norma argentina sin acta. |
| CIE-10 referencia Argentina | Pendiente de acta | Declarar organismo, edición, versión, release y procedencia antes de usarla como norma. |
| ICD-10-CM 2027 | Modificación clínica estadounidense independiente | Sus 17 códigos exclusivos conservan identidad CM y texto `en`. |
| SNOMED CT Argentina Edition | Terminología complementaria | Enriquecimiento gobernado; no importación masiva. |
| CIE-10-PCS | Referencia de procedimientos | No genera diagnósticos ni códigos OFTAR nuevos. |

**[P]** Prohibido usar `system_code='CIE-10'` sin subtipo cuando haya dos ediciones implicadas; prohibido inventar traducciones, códigos o equivalencias.

---

## 5. Taxonomía

**[H]** Se conservan `CONSULT, EXAM, DIAG, IMG, TER, CIR, OCUL, LAGR`, las raíces `GRP-*`, `CAT-DX` y los 12 códigos `CLIN-*`; la API conserva `category` y agrega `clinical_category`.

**[P]** Secuencia de asignación exclusiva: `CONSULT` → `CIR` (cirugía, aunque use láser) → `TER` (terapia no quirúrgica) → `IMG` (adquisición de imagen) → `DIAG` (estudio funcional) → `EXAM` (examen/medición simple) → centinela `REVISION`. `OCUL`/`LAGR` dejan de asignarse automáticamente; la anatomía pasa a `ANAT-*`.

**[P]** `REVISION` y `SIN_CLASIFICAR` nunca se publican como `category` ni `clinical_category`: se interpretan como “sin relación gobernada”.

---

## 6. Clasificación anatómica y clínica

**[P]** Cuatro dimensiones separadas: categoría clínica (`CLIN-DIAG`), localización anatómica (`ANAT-*`), área clínica (`AREA-*`) y tipo de concepto (`concept_kind`). Una categoría clínica por concepto; anatomía y área pueden ser múltiples.

**[P]** Regiones: párpados, aparato lagrimal, órbita, conjuntiva, córnea, esclera, cristalino, úvea, retina, coroides, nervio óptico, músculos extraoculares, superficie ocular. Áreas: glaucoma, neurooftalmología, estrabismo/motilidad, refracción/acomodación, retina médica, retina quirúrgica, oculoplastia, pediátrica, traumatología, infecciosas/inflamatorias y manifestaciones sistémicas.

**[H]** `ATTR-STRUCTURE`, `ATTR-MODALITY` y `ATTR-LATERALITY` son códigos en `oftar_attribute_definition`, no columnas; `ANAT-*` y `AREA-*` aún no están sembrados en SQL (`oftar_core.sql:257-274,298-306`).

**[P]** Son valores de atributo estables propuestos, no catálogos ni códigos `CLIN-*`. Descripciones internacionalizables; navegación aditiva `?anatomy=&clinical_area=` (no existe hoy en la API y requiere aprobación de implementación).

**[P]** Jerarquía anatómica: `ANAT-UVE` es agrupación y `ANAT-COROID` estructura miembro; `ANAT-SUP` es agrupación funcional de córnea, conjuntiva y película lagrimal, no una estructura nueva; `ANAT-NEU` es el nervio óptico y `ANAT-MOT` los músculos extraoculares, mientras que motilidad y visión binocular son `AREA-ESTRAB`. Una agrupación **no** genera automáticamente relaciones con todas sus estructuras hijas; la multi-estructura se registra solo con soporte clínico explícito.

---

## 7. Modelo de relaciones

**[H]** `os_concept_mapping.mapping_type` acepta `equivalent|narrower|broader|related|unmatched` (`origen_catalog_engine.sql:125-126`; confirmado en `tools/generate_unified_catalog_engine_sql.py:360-361`). **No existen `exact`, `no_map` ni `reference` en el `CHECK`.** Corrección documental: las versiones anteriores de esta especificación afirmaban lo contrario; esa afirmación queda retirada. La API reenvía el valor sin interpretarlo (`CatalogEngineService.php:612,708`; `CatalogRepository.php:3055`).

**[P]** Convención:

- Equivalencia verificable → `equivalent` (la palabra «exacta» de la matriz clínica es una etiqueta documental, no un valor de base de datos).
- Aproximada/parcial → `related` con evidencia de parcialidad; nunca `equivalent`.
- Sin correspondencia identificada → `unmatched`.
- Más amplio/más específico → `broader`/`narrower`, dirección OFTAR respecto del externo, a ratificar.
- Asociativa → `os_catalog_relation` con `context_text`.
- Variante/sustitución/requiere/incluye → tipo existente de `os_catalog_relation` antes que ampliar `CHECK`; verificar que el `relation_type` permitido cubre el caso, porque el dominio actual enumera tipos CDT (`aprobar_mapeo_nomencladores_oftar.sql:200-207`).

**[P]** Publicar solo con `review_status='approved'`, evidencia, hash vigente y dos revisores.

---

## 8. Reglas de conciliación

**[P]** Ocho clases: equivalencia clínica exacta, aproximada/parcial, concepto más amplio, concepto más específico, procedimientos relacionados, procedimientos diferentes, correspondencia incierta y sin correspondencia identificada.

**[P]** La similitud textual es pista, nunca prueba. Se exigen ancla clínica, técnica, modalidad, lateralidad, región, alcance/sesiones y condiciones. Ante duda, `correspondencia_incierta`; sin ancla compartida, `sin_correspondencia_identificada`.

**[H]** Matriz: 433 filas; 38 «exactas» propuestas (etiqueta documental de la clase, no valor de `mapping_type`), 165 aproximadas/parciales, 2 más amplios, 1 más específico, 30 relacionados, 22 diferentes, 169 inciertas y 6 sin correspondencia. Todas `propuesta_no_publicada`.

---

## 9. Gobernanza, estados y publicación

### 9.1 Cuatro estados que no deben confundirse

| Objeto | Estado real verificado | Valores / default | Condición de publicación |
|---|---|---|---|
| **Versión del concepto** | `os_catalog_item_version.review_status` | `NOT NULL DEFAULT 'unknown'`, **sin CHECK** (`04_fase3_columnas.sql:24-37`). Los scripts OFTAR asignan `approved` (`aprobar_preferred_term_oftar_dx.sql:108-112`). | `v_oftar_search_catalog` exige `='approved'` (`oftar_domain_search.sql:77`). |
| **Correspondencia / mapeo** | `os_concept_mapping.review_status` | `CHECK(draft\|reviewed\|approved\|deprecated)`; default original `approved`, cambiado a `draft` por `fase3_relaciones_mapeos.sql:183-184` sin tocar el CHECK. **No existen `pending_review` ni `rejected` en el SQL versionado.** | Fila `approved` **y** revisión de campo vigente para `external_display`/`clinical_rationale` (`MappingReviewReader.php:10-130`). |
| **Revisión de campo / traducción** | `os_field_review.review_status` y `os_localized_text.review_status` | Ambos `DEFAULT 'unknown'`, **sin CHECK** (`01_fase2_tablas.sql:70,131`). | Solo `approved` con `content_hash` vigente y scope/release compatible (`EditorialEvaluator.php:209-211,308-310`; `CatalogRepository.php:2312-2333`). |
| **Publicación** | `os_catalog_release.status` y `os_catalog_item.status` | Release `CHECK(draft\|review\|published\|deprecated)`; ítem `CHECK(active\|retired\|superseded)` (`origen_catalog_engine.sql:49,67`). | Release `published`, catálogo e ítem activos. |

**[H]** `os_review_state` enumera `unknown`, `unreviewed`, `draft`, `in_review`, `reviewed`, `approved`, `published`, `retired`, `obsolete`, `deprecated`, con `is_publication_allowed=TRUE` solo para `approved` y `published` (`fase1_infraestructura.sql:85-102`). **No es un CHECK de las columnas y la API no lo lee**: es vocabulario de gobernanza, no sustituto de los estados persistidos.

### 9.2 Flujo editorial completo

1. **Creación:** versión de concepto con `review_status='unknown'` (default), ítem `active`, release en `draft`; mapeo con `review_status='draft'` (default actual).
2. **Carga de texto:** `os_catalog_term`/`os_localized_text` con `language_code` y `source_language_code`; `os_field_review` con `provenance`, `source_reference`, `language_evidence` y `content_hash`.
3. **En revisión:** `in_review` se usa como etiqueta de gobernanza de `os_review_state` o nota de `os_governance_request`, **no como valor de CHECK**. Mientras tanto las columnas permanecen en `unknown`/`draft`. «Requiere información» se registra en gobernanza y en `os_field_review` sin aprobar; no es un estado persistido propio.
4. **Aprobación:** dos revisiones humanas distintas; `os_field_review.review_status='approved'` con hash vigente; los scripts OFTAR ponen la versión en `approved` y el mapeo en `approved` cuando corresponde.
5. **Publicación:** release `published`; catálogo e ítem activos; vista OFTAR exige versión `approved`; los evaluadores exigen además aprobación de campo y hash vigente. Si falta texto aprobado, la respuesta es `null` + `untranslated=true`, nunca un fallback a texto sin revisar.
6. **Cambio o retiro:** los triggers de invalidación devuelven `draft` en `os_concept_mapping` y `unreviewed` en las tablas que lo permiten, y retiran aprobaciones cuando cambia el contenido (`05_fase3_triggers.sql:86-103,110-135`). El histórico queda en `os_audit_log`, append-only (`fase4_gobernanza.sql:120-147`).

**[P]** Concepto de «rechazado»: no existe como valor `rejected` en el SQL versionado. Se documenta como decisión de gobernanza negativa; la fila conserva su estado técnico (`draft`, `unknown` o `deprecated`) y su traza. No inventar un valor `rejected` sin ampliación aprobada.

### 9.3 Condiciones exactas de visibilidad

| Superficie | Condiciones |
|---|---|
| `/v1/search?domains=oftar` | `v_oftar_search_catalog`: familia `oftar`, `product_role='catalog'`, catálogo activo, ítem `active`, versión `approved`; requiere `GRANT SELECT` sobre la vista. La rama de búsqueda solo añade coincidencia de texto/activo (`TerminologySearchService.php:2670-2728`). |
| `/v1/catalogs/{code}/items` | Release `published` e ítem `active` (`CatalogEngineService.php:126-146`); **no filtra `ver.review_status` en el listado**. El detalle aplica evaluación editorial por campo. |
| Textos en API | `EditorialEvaluator`/`FieldReviewRepository`: candidato `approved`, revisión aprobada, scope compatible y hash vigente; si no, `null` + `untranslated=true`. |
| `/v1/mappings` | Release `published`; `external_display` y `clinical_rationale` solo con revisión de campo aprobada y hash vigente. El `approved` de la fila de mapeo no basta por sí solo. |
| Browse Codes | No usa la vista OFTAR: consulta ítems/versiones con release `published` y aplica la aprobación por campo en PHP (`CatalogRepository.php:2197-2381`). |

---

## 10. Internacionalización

**[P]** `es-AR` es idioma principal, fallback y **obligatorio para todo concepto publicado**. `en` y `pt-BR` tienen **cobertura progresiva**: no se exige paridad absoluta. Los huecos idiomáticos deben informarse con estado explícito (`untranslated` cuando no hay texto; y los estados reales de revisión del modelo cuando existe texto). No se publican traducciones automáticas ni textos sin revisión aprobada. Sin columnas `name_en`/`name_pt`; se usan `os_catalog_term` y `os_localized_text`. Los 17 códigos ICD-10-CM exclusivos conservan `en` y se registran como no traducidos hasta que exista `es-AR` aprobado. `MappingReviewReader` publica texto externo solo con revisión vigente y hash coincidente.

---

## 11. Versionado

**[P]** Cada corrección publicable crea nueva versión en `os_catalog_item_version` dentro de un release; el código `OFT-PR-`/`OFT-DX-` permanece. `os_catalog_release.status` ∈ `draft|review|published|deprecated`. No sobrescribir versiones publicadas ni reutilizar identificadores retirados.

---

## 12. Trazabilidad

**[P]** Toda fila publicable conserva: sistema, edición, versión, release/fecha, código y descripción originales, idioma, procedencia, `source_reference`, `content_hash`, `valid_from/to`, `review_status` y audit trail. Los informes y matrices son worklists; la verdad publicada vive en `os_catalog` y sus extensiones gobernadas.

---

## 13. Compatibilidad con API y frontend

**[H]** No romper rutas `/v1/*`, envelope `data/meta/request_id`, `Vary: Accept-Language`, semántica 200 vacío frente a 404, paginación documentada de `/v1/mappings`, defaults de dominios ni exclusión mutua `domain`/`catalog`/`family` en Browse.

**[P]** Se pueden agregar: campos opcionales en `data/meta`, filtros query ignorables y facets de anatomía/área apoyados en atributos existentes. Si no hay atributos cargados, la API y el frontend siguen funcionando con el facet histórico.

---

## 14. Plan de reconstrucción — solo tras autorización

**[P]** El plan operativo canónico es `plan-implementacion-controlada-oftar.md`: **10 etapas** con entradas, salidas verificables, criterios de aceptación y gates. La tabla histórica siguiente se conserva solo como índice de compatibilidad; **no es el plan vigente** y ninguna de sus fases autoriza por sí misma una escritura.

| Numeración histórica | Equivalencia en el plan de 10 etapas |
|---|---|
| 0 — acta `READ ONLY` | Etapa 1 (acta y congelación) |
| 1 — aprobación documental | Etapas 2–4 (correcciones, decisión PR, alcance DX) |
| 2 — corrección de las 12 filas y decisión sobre 3 conceptos | Etapa 3 |
| 3 — preparación de seeds sin ejecutar | Etapas 6–9 y `propuesta-dry-run-seeds-oftar.md` |
| 4 — ejecución controlada y publicación | Etapa 10, solo con autorización explícita |
| 5 — validación de solo lectura | Etapa 9 y actas posteriores |

**[P]** Queda prohibido hasta la autorización explícita de la etapa 10: ejecutar migraciones, importadores, generadores, seeds, `DELETE`/`DROP`/`TRUNCATE`, asignar UVR o publicar equivalencias no aprobadas. El cierre de esta especificación como base técnica **no** constituye esa autorización.

---

## 15. Pruebas de aceptación

**Regla:** las verificaciones se ejecutan con consultas de solo lectura y se comparan contra el acta de Fase 0. No dependen de datos ficticios ni de aprobaciones asumidas.

### 15.1 Identidad

| # | Criterio | Verificación |
|---:|---|---|
| 1 | Sin motor paralelo | `to_regclass('public.os_catalog')` existe; no hay catálogos duplicados con sufijo alternativo. |
| 2 | Códigos propios únicos | 0 duplicados de `OFT-PR-NNNNNN`/`OFT-DX-NNNNNN` por catálogo; 0 usos de `OFTAR-PR-`/`OFTAR-DX-`. |
| 3 | Independencia de códigos externos | Al cambiar el código/edición externa en un entorno controlado, el `permanent_code` OFTAR no cambia. |
| 4 | Identidad externa completa | Cada identificador publicado conserva sistema, edición, versión, release/fecha, código y descripción originales, idioma, procedencia y vigencia declarada o `desconocida`. |
| 5 | Fuentes con números repetidos | `305022`, `305025` y `305047` se resuelven por `(catálogo, identificador)`, no por número aislado. |

### 15.2 Datos

| # | Criterio | Verificación |
|---:|---|---|
| 6 | Descripción `es-AR` obligatoria | Todo concepto publicado tiene término preferido `es-AR` aprobado. |
| 7 | Sin equivalencias no aprobadas | 0 filas con `review_status` distinto de `approved` son devueltas por consultas públicas de mapeos. |
| 8 | Sin duplicados injustificados | 0 pares de conceptos con misma fuente, mismo código original y distinto `OFT-*` sin justificación de variante. |
| 9 | Procedencia trazable | Toda fila publicada tiene `provenance`, `source_reference` y `content_hash` vigente. |
| 10 | UVR | 0 UVR en `oftar-dx`; importes CAO/Regional conservados sin conversión automática. |

### 15.3 Relaciones

| # | Criterio | Verificación |
|---:|---|---|
| 11 | Jerarquía anatómica coherente | `ANAT-UVE` no sustituye a `ANAT-COROID`; `ANAT-SUP` no genera `ANAT-COR`+`ANAT-CON`; `ANAT-NEU` no se usa para motilidad. |
| 12 | Multi-estructura | Un concepto puede tener varias estructuras/áreas con evidencia; no se duplica el código OFTAR ni se propaga automáticamente desde un padre. |
| 13 | Equivalentes frente a parciales | Solo las propuestas documentalmente justificadas pueden llegar a `equivalent` tras aprobación; las parciales usan `related` con evidencia. |
| 14 | Clínica frente a facturación | Las columnas de equivalencia de facturación e importe migrado permanecen `NO` salvo aprobación separada. |
| 15 | SNOMED filtrado | Solo refset `447562003`, `active=1`, destino H00-H59, sin importación masiva ni equivalencia automática. |

### 15.4 Internacionalización

| # | Criterio | Verificación |
|---:|---|---|
| 16 | `es-AR` íntegro | 100% de conceptos publicados con término `es-AR` aprobado; `en` y `pt-BR` son progresivos, sin exigencia de paridad. |
| 17 | Huecos explícitos | Los textos faltantes se informan con estado explícito y se cuentan por idioma; no se inventan. |
| 18 | Traducciones publicadas | Solo textos con revisión aprobada, hash vigente, idioma de origen y procedencia coherente aparecen en respuestas públicas. |
| 19 | Sin traducción automática | Ningún texto con origen automático o sin revisión se publica como término aprobado. |
| 20 | Códigos ICD-10-CM | Los 17 exclusivos conservan descripción `en` y se registran como no traducidos hasta aprobación de `es-AR`. |

### 15.5 API y frontend

| # | Criterio | Verificación |
|---:|---|---|
| 21 | Contratos preservados | Rutas `/v1/*`, envelope `data/meta/request_id`, `Vary: Accept-Language` y semántica 200 vacío frente a 404 sin cambios. |
| 22 | Browse Codes | Filtros históricos `q/domain/catalog/family/type/category/status/version/validity` y exclusión mutua `domain` vs `catalog/family` sin cambios. |
| 23 | Identificadores históricos | Los códigos NN/CAO/Regional siguen resolviéndose por `(catálogo, identificador)`. |
| 24 | Filtros aditivos | `?anatomy=` y `?clinical_area=` son opcionales e ignorables; `category` y `clinical_category` permanecen. |

### 15.6 Gobernanza

| # | Criterio | Verificación |
|---:|---|---|
| 25 | Aprobación trazable | Cada aprobación registra responsable, fecha, justificación, evidencia, decisión, vigencia y hash. |
| 26 | Decisiones auditables | Existe fila en `os_audit_log` append-only por publicación; el trigger impide UPDATE/DELETE. |
| 27 | Pendientes privados | Mapeos y traducciones pendientes no aparecen en respuestas públicas ni en Browse Codes. |
| 28 | Release publicado | Solo versiones en release `published` y con estado de revisión publicable son visibles en búsqueda. |

---

## 16. Riesgos pendientes

1. **Acta Fase 0 no ejecutada:** estado real de PostgreSQL, privilegios y conteos no verificados.
2. **Edición CIE-10 argentina:** sin evidencia local; no se inventa.
3. **17 códigos ICD-10-CM:** decisión de proyección pendiente (2.661 frente a 2.678).
4. **S05/T/E11:** alcance fuera de H00-H59 pendiente de decisión.
5. **Conceptos nuevos vs atributos:** tres candidatos y ocho variantes requieren fallo editorial.
6. **Dirección `broader`/`narrower`:** ratificar.
7. **Multivaluado:** si `os_catalog_relation` no basta, ampliación futura.
8. **Metadatos de edición/release:** estructuración pendiente de aprobación.
9. **H-02 `target_code`:** resolver por identificador de origen sin reescribir histórico.
10. **Cifra 23.292 del ZIP inglés:** no reproducible; el archivo principal tiene 74.879 líneas. No usar; sí son reproducibles 2.677 H00-H59.

**[I]** Ninguno de estos riesgos bloquea la especificación; todos bloquean la generación de seeds.

---

## 17. Informe ejecutivo obligatorio

### 17.1 ¿Qué decisiones quedaron definitivamente resueltas?

Arquitectura sobre `os_catalog` sin motor paralelo; `oftar` como dominio funcional y familia, con `domain_type='medical'` real; prefijos `OFT-PR-`/`OFT-DX-`; conservación de 8 categorías, raíces, `CAT-DX` y 12 `CLIN-*`; separación de cuatro dimensiones; jerarquía anatómica sin propagación automática; CIE-10-ES como fuente estructurada **no normativa argentina**; ICD-10-CM 2027 como referencia externa; SNOMED como enriquecimiento gobernado; 8 clases de relación; flujo editorial con cinco etiquetas de gobernanza y estados persistentes definidos por objeto (§9); i18n con `es-AR` obligatorio y cobertura progresiva; sin UVR en DX; sin importes convertidos.

### 17.2 ¿Qué decisiones continúan pendientes?

Acta real de PostgreSQL; edición CIE-10 de referencia en Argentina; proyección de los 17 códigos CM; incorporación de S05/T/E11; aprobación de 3 conceptos nuevos y 8 variantes; dirección de `broader`/`narrower`; soporte multivaluado; metadatos estructurados de edición/release; resolución de H-02.

### 17.3 ¿Qué debe conservarse de OFTAR actual?

Dominio y catálogos, códigos permanentes, numeración y descripciones originales de NN/CAO/Regional, capítulos históricos, `category` + `clinical_category`, gobernanza por hash y dos revisiones, vista de búsqueda con `es-AR` y URL/API sin cambios.

### 17.4 ¿Qué debe reconstruirse?

La capa semántica: conciliación PR corregida, atributos de anatomía/modalidad/lateralidad, identidad externa por edición, clasificación DX y vinculación SNOMED filtrada. La reconstrucción es aditiva; no reescribe catálogos publicados.

### 17.5 ¿Qué cambios estructurales son necesarios?

Solo si se aprueban: metadatos de `edition/version/release/provenance` estructurados en identidad externa, relaciones multivaluadas nativas y, eventualmente, nuevos `relation_type` o `CHECK`. Ninguno es imprescindible para empezar.

### 17.6 ¿Qué puede implementarse sin migraciones?

Cargar dominios de atributos en tablas existentes; publicar pares revisados con `os_concept_mapping`/`os_field_review`; derivar prefijo CIE-10 desde identificador; filtros aditivos en capa de servicio; corregir reglas de asignación en el generador (sin ejecutarlo); resolver `target_code` por `os_catalog_identifier`.

### 17.7 ¿Qué fuentes serán las referencias principales?

OFTAR-PR: Nomenclador Nacional 2025 como núcleo; CAO y Regional NOA como fuentes de observación; SNOMED CT y CIE-10-PCS como referencias complementarias validadas. OFTAR-DX: CIE-10-ES 2026 como fuente estructurada inicial; ICD-10-CM 2027 como referencia externa; SNOMED CT Argentina Edition para mapeos gobernados; CIE-10 argentina pendiente de acta.

### 17.8 ¿Cómo se preservará la trazabilidad?

Con sistema+edición+versión+release+idioma+procedencia por identificador, `source_reference` con archivo y fila, `content_hash`, `valid_from/to`, `os_field_review`, `os_governance_*` y `os_audit_log` append-only. Las matrices quedan como evidencia, no como verdad publicada.

### 17.9 ¿Qué riesgos quedan abiertos?

Los diez listados en §16; el más crítico es la ausencia de acta de Fase 0 y la decisión sobre la edición CIE-10 argentina.

### 17.10 ¿Está OFTAR listo para pasar a la generación de seeds?

**No.** La especificación está cerrada como diseño, pero faltan: aprobación explícita del responsable, acta `READ ONLY` de Fase 0, firma del dictamen de conciliación y decisión sobre los 17 códigos CM y el alcance S05. Cumplido eso, se podrán preparar seeds en una etapa posterior; **esta etapa no los genera**.

---

## 18. Cierre

**[I]** La reconstrucción no necesita un nuevo motor ni una nueva nomenclatura. Necesita decisiones clínicas explícitas, identidad por edición y gobernanza que impida publicar equivalencias no revisadas.

**[P]** Esta especificación es el documento principal para la futura implementación y queda **aprobada como base técnica**. No ejecuta cambios, no modifica PostgreSQL ni seeds y espera una autorización explícita adicional antes de cualquier reconstrucción de datos.

---

## 19. Historial de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | 2026-11-28 | Cierre de la especificación funcional y técnica, aprobada como base técnica para la implementación controlada. Separa estados editoriales por objeto, aclara `oftar` como dominio funcional frente a `domain_type`, consolida política i18n sin paridad absoluta, corrige jerarquía anatómica, conserva el dictamen PR como propuesta no aprobada, mantiene el universo DX como conjunto candidato, amplía las pruebas de aceptación y registra los cambios futuros que requieren aprobación. Corrección adicional: `mapping_type` usa `equivalent\|unmatched` (no `exact\|no_map\|reference`) y `draft\|review\|published\|deprecated` pertenece a release, no a versión. Se añaden matriz de estados, integración con `os_catalog`, verificaciones PR/DX, inconsistencias, pendientes, plan de 10 etapas y propuesta de `dry-run`. |

**Historial preservado:** las auditorías, propuestas y matrices previas en `docs/audit/` se conservan como evidencia histórica. Esta versión no las borra ni las sobrescribe; solo establece qué capa prevalece cuando existan contradicciones (§0).
