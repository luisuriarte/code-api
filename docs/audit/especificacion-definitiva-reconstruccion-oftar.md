# Especificación definitiva para la reconstrucción de OFTAR

**Fecha:** 2026-11-28
**Etapa:** tercera revisión — análisis, diseño y documentación.
**Estado:** **documento principal para la futura implementación. No autoriza seeds, migraciones ni publicación.**
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta sujeta a aprobación explícita.

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

- Dominio único `oftar`; catálogos `oftar-pr` y `oftar-dx`. No crear motor paralelo ni catálogos duplicados.
- Prefijos permanentes `OFT-PR-NNNNNN` y `OFT-DX-NNNNNN`; no reutilizar `OFTAR-PR-`/`OFTAR-DX-`.
- CAO y Regional NOA conservan su numeración original como catálogos de origen; no se convierten en `oftar-pr`.
- `v_oftar_search_catalog` publica solo versiones `review_status='approved'`.
- Toda escritura futura pasa por gobernanza con dos revisiones y traza en `os_audit_log`.

---

## 2. Estructura de OFTAR-PR

**[H]** Núcleo: 154 códigos del Nomenclador Nacional 2025 (`sql/03_oftar/fuente_nomenclador_oftar_pr.sql`), con descripción original conservada. Fuentes complementarias: CAO (143) y Regional NOA (136).

**[I]** El núcleo es válido pero no agota las fuentes. La conciliación clínica tiene 433 filas con 8 clases de relación; todas sin publicar.

**[P] Conciliación:**

- 13 pares / 26 filas sostenibles como `exact` (equivalencia clínica verificable).
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
| Candidatos iniciales | 2.661 CIE-10-ES 2026 H00-H59 | Fuente estructurada inicial en español; no etiquetada como norma argentina. |
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

**[P]** Son valores de atributo estables propuestos, no catálogos ni códigos `CLIN-*`. Descripciones internacionalizables; navegación aditiva `?anatomy=&clinical_area=`.

---

## 7. Modelo de relaciones

**[H]** `os_concept_mapping.mapping_type` acepta `exact|narrower|broader|related|no_map|reference`. No existe `equivalent`: el valor correcto es `exact`.

**[P]** Convención:

- Equivalencia verificable → `exact`.
- Aproximada/parcial → `related` con evidencia de parcialidad; nunca `exact`.
- Más amplio/más específico → `broader`/`narrower`, dirección OFTAR respecto del externo, a ratificar.
- Asociativa → `os_catalog_relation` con `context_text`.
- Variante/sustitución/requiere/incluye → `relation_kind` existente antes que ampliar `CHECK`.

**[P]** Publicar solo con `review_status='approved'`, evidencia, hash vigente y dos revisores.

---

## 8. Reglas de conciliación

**[P]** Ocho clases: equivalencia clínica exacta, aproximada/parcial, concepto más amplio, concepto más específico, procedimientos relacionados, procedimientos diferentes, correspondencia incierta y sin correspondencia identificada.

**[P]** La similitud textual es pista, nunca prueba. Se exigen ancla clínica, técnica, modalidad, lateralidad, región, alcance/sesiones y condiciones. Ante duda, `correspondencia_incierta`; sin ancla compartida, `sin_correspondencia_identificada`.

**[H]** Matriz: 433 filas; 38 exactas propuestas, 165 aproximadas/parciales, 2 más amplios, 1 más específico, 30 relacionados, 22 diferentes, 169 inciertas y 6 sin correspondencia. Todas no publicadas.

---

## 9. Gobernanza y revisión

**[P]** Estados: Pendiente (`draft`), En revisión (`pending_review`), Aprobado (`approved`), Rechazado (`rejected`) y Requiere información (`draft`/`pending_review` + nota en `os_field_review`).

**[P]** Cada revisión registra responsable, fecha, justificación, fuente de evidencia, decisión, vigencia, `content_hash` y traza en `os_audit_log`. Dos revisores distintos; `approved` es condición necesaria para publicar.

**[H]** `os_audit_log` es append-only con trigger que impide UPDATE/DELETE (`fase4_gobernanza.sql:120-147`).

---

## 10. Internacionalización

**[P]** `es-AR` principal y fallback; `en` y `pt-BR` solo con revisión aprobada. Sin columnas `name_en`/`name_pt`. Los 17 códigos ICD-10-CM exclusivos conservan `en` y se registran como no traducidos. `MappingReviewReader` publica texto externo solo con revisión vigente y hash coincidente.

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

## 14. Plan de reconstrucción — solo tras aprobación

| Fase | Acción | Quién |
|---|---|---|
| 0 | Acta `READ ONLY` de PostgreSQL: objetos, privilegios, conteos, `target_code` (H-02), estado de `categorias_clinicas.sql`. | Responsable |
| 1 | Aprobación de esta especificación y firma del dictamen PR / universo DX. | Responsable |
| 2 | Corrección documental de las 12 filas exactas y decisión sobre los 3 conceptos nuevos. | Asistente (documentos), responsable (aprobación) |
| 3 | Preparación de seeds y verificaciones, sin ejecutarlos, aditivos e idempotentes. | Asistente |
| 4 | Ejecución controlada, aprobaciones por campo y publicación gobernada. | Responsable |
| 5 | Validación con consultas de solo lectura y pruebas de aceptación. | Responsable |

**[P]** Queda prohibido hasta la Fase 3 autorizada: ejecutar migraciones, importadores, generadores, `DELETE`/`DROP`/`TRUNCATE`, asignar UVR o publicar equivalencias no aprobadas.

---

## 15. Pruebas de aceptación propuestas

| # | Criterio | Verificación |
|---:|---|---|
| 1 | Sin motor paralelo | `SELECT to_regclass('public.os_catalog')` y ausencia de tablas de catálogo duplicadas. |
| 2 | Catálogos | Conteos publicados coherentes con el acta; CAO y Regional conservan su identidad. |
| 3 | Códigos propios | `OFT-PR-`/`OFT-DX-` únicos; 0 códigos con prefijos retirados. |
| 4 | Taxonomía | 8 hojas + raíces + `CAT-DX` sin renombrar; 12 `CLIN-*`. |
| 5 | Conciliación | 13 pares `exact` aprobados y 6 pares corregidos/degradados; 0 equivalencias publicadas sin `approved`. |
| 6 | Identidad | `CIE-10-ES` e `ICD-10-CM` diferenciados; 17 códigos CM con `language=en` y sin traducción inventada. |
| 7 | Anatomía | Filtros `?anatomy=&clinical_area=` aditivos; `category` y `clinical_category` presentes. |
| 8 | Idiomas | Paridad `es-AR`/`en`/`pt-BR` sin claves faltantes; textos no aprobados devuelven `untranslated`. |
| 9 | Gobernanza | Toda publicación con dos revisiones, hash vigente y fila en `os_audit_log`. |
| 10 | UVR | 0 UVR en `oftar-dx`; importes CAO/Regional no convertidos. |
| 11 | API/frontend | Rutas, envelopes y semántica 200/404 sin cambios; Browse “Todos” sin `error_query`. |
| 12 | SNOMED | Solo refset `447562003`, destino H00-H59, `review_status='draft'` hasta aprobación. |

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

Arquitectura sobre `os_catalog` sin motor paralelo; prefijos `OFT-PR-`/`OFT-DX-`; conservación de 8 categorías, raíces, `CAT-DX` y 12 `CLIN-*`; separación de cuatro dimensiones; CIE-10-ES como fuente estructurada **no normativa argentina**; ICD-10-CM 2027 como referencia externa; SNOMED como enriquecimiento gobernado; 8 clases de relación; flujo de cinco estados editoriales; sin UVR en DX; sin importes convertidos.

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

**[P]** Esta especificación es el documento principal para la futura implementación. No ejecuta cambios, no modifica PostgreSQL ni seeds y espera aprobación explícita antes de cualquier reconstrucción de datos.
