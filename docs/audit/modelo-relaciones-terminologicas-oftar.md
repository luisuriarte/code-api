# Modelo de relaciones terminológicas de OFTAR

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** OFTAR v1.0 — Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada. (No autoriza ejecución.)
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta sujeta a aprobación explícita.

> Documento de solo lectura. No se ejecutaron SQL, seeds, migraciones ni importadores; no se consultó ni se escribió en PostgreSQL. Toda carga, aprobación o publicación requiere autorización posterior, acta y firmas clínicas (rector §0, §14 y `plan-implementacion-controlada-oftar.md`).

---

## 1. Principio rector

**[H]** `os_concept_mapping` es la tabla de correspondencias entre un **ítem de catálogo OFTAR** y un **concepto/código de un sistema externo**: `item_id` referencia `os_catalog_item`, `terminology_system_id` referencia `os_terminology_system`, y `external_code` es el código ajeno (`sql/02_catalogs/origen_catalog_engine.sql:111-136`). Su función es exactamente esa; no es un contenedor universal de relaciones.

**[P] Contrato canónico (obligatorio en esta documentación):**

- `os_concept_mapping` conserva su función: **correspondencias OFTAR → sistema externo**. Con él **no** se resuelven relaciones clínicas internas ni relaciones PR↔DX.
- Las relaciones clínicas internas (PR↔PR, DX↔DX, PR↔DX, anatomía/función, contexto clínico) pertenecen a `os_catalog_relation` con `context_text` (rector §7.2).
- `relationship_role='justifying_diagnosis'` es un **rol de mapeo**; no convierte una fila en una relación PR↔DX ni autoriza a usar la tabla como puente clínico (`:127-128`).
- `mapping_type` real es `equivalent|narrower|broader|related|unmatched` (`:125-126`). **`exact`, `no_map` y `reference` NO existen en ese `CHECK` de `mapping_type`; `pending_review` y `rejected` tampoco existen en el `CHECK` de `review_status` (`:130`)**. «Exacta» es etiqueta documental de la matriz de conciliación, no valor persistible (rector §7.3 y §8).

| Pregunta operativa | Destino correcto | Uso prohibido |
|---|---|---|
| ¿A qué código de otro sistema corresponde este ítem OFTAR? | `os_concept_mapping` + `os_mapping_metadata` | Inventar equivalencias por similitud textual. |
| ¿Qué diagnóstico justifica o acompaña a este procedimiento dentro de OFTAR? | `os_catalog_relation` | Convertirlo en `os_concept_mapping` con `justifying_diagnosis`. |
| ¿Cómo se agrupa anatómica o funcionalmente un concepto? | Atributos / `os_catalog_relation` | Crear códigos nuevos o propagar automáticamente la jerarquía. |

---

## 2. Sistemas y ediciones iniciales

**[H]** Los sistemas declarados y su rol se rigen por el rector §4 y §7.3, y por `politica-identificacion-oftar-final.md` §2. La edición **no** está estructurada limpiamente en el esquema actual: `os_terminology_system` solo ofrece `code`, `name`, `uri` y `default_version` (`origen_catalog_engine.sql:111-117`).

| Sistema | `system_code` normalizado por edición | Rol en OFTAR | Regla de identidad |
|---|---|---|---|
| Nomenclador Nacional 2025 | `NOMENCLADOR-AR-2025` (familia `NOMENCLADOR-AR`) | Núcleo de OFTAR-PR | Conservar número y descripción originales; prefijo canónico `OFT-PR-NNNNNN` (`politica-identificacion-oftar-final.md:40`; rector §2). |
| CAO | `CAO` | Fuente complementaria de OFTAR-PR | 143 códigos con numeración inmutable; no se convierten en `oftar-pr` (rector §2; `integracion-os-catalog-oftar.md` §2). |
| Regional NOA | `REGIONAL-NOA` | Fuente complementaria de OFTAR-PR | 136 códigos con numeración inmutable; misma restricción que CAO. |
| CIE-10 (familia) | Solo con subtipo explícito | Etiqueta general, no valor final de gobernanza | La edición argentina normativa está **pendiente de acta**; no usar `CIE-10` sin subtipo cuando convivan dos ediciones (`politica-identificacion-oftar-final.md:23-27,36`). |
| CIE-10-ES 2026 | `CIE-10-ES` | Fuente estructurada inicial en español y referencia complementaria de OFTAR-DX | **6.ª edición, Ministerio de Sanidad de España; NO norma argentina** (`politica-identificacion-oftar-final.md:13-19,35`; rector §4). |
| ICD-10-CM 2027 | `ICD-10-CM` | Referencia externa independiente | Modificación estadounidense; sus **17 códigos exclusivos** se conservan como referencia, no convertidos ni traducidos automáticamente; texto `en` (`politica-identificacion-oftar-final.md:37,44-50`). |
| SNOMED CT Argentina Edition | `SNOMED-CT` | Enriquecimiento semántico gobernado | Solo refset oficial `447562003`, selectivo; `mapping_type='related'`, `review_status='draft'`; `mapAdvice` se conserva en `clinical_rationale` (rector §3, §4; `politica-identificacion-oftar-final.md:38`). |
| CIE-10-PCS | `ICD-10-PCS` | Referencia de procedimientos | Solo cuando exista justificación clínica revisada; **nunca fuente de diagnósticos** ni de códigos OFTAR nuevos (`politica-identificacion-oftar-final.md:39`; rector §4). |

**[P]** No mezclar códigos de sistemas distintos aunque coincidan alfanuméricamente. Toda correspondencia se resuelve por **sistema + edición + release**, y se documentan organismo, versión, procedencia e idioma. Mientras no exista ampliación estructural, normalizar `system_code` por edición y completar `source_reference`/`provenance` de forma obligatoria (ver §8).

---

## 3. Las ocho clases y su destino persistible

**[H]** El `CHECK` de `mapping_type` admite cinco valores y el de `mapping_nature` (en `os_mapping_metadata`) admite `univocal|multiple|partial|approximate|not_mappable` (`origen_catalog_engine.sql:126`; `sql/08_arquitectura/fase3_relaciones_mapeos.sql:125-127`). No se persisten palabras de la matriz directamente.

| # | Clase solicitada | Destino persistible | Regla y límite |
|---:|---|---|---|
| 1 | Equivalencia exacta | `mapping_type='equivalent'` + `mapping_nature='univocal'` | Solo con ancla clínica verificable, evidencia, doble revisión y aprobación. «Exacta» queda como etiqueta documental; el valor real es `equivalent`. |
| 2 | Equivalencia aproximada | `mapping_type='related'` + `mapping_nature='approximate'` | Nunca `equivalent`; la diferencia debe quedar explicada en `clinical_rationale`/`source_reference`. |
| 3 | Correspondencia parcial | `mapping_type='related'` + `mapping_nature='partial'` | `narrower`/`broader` **solo** si la jerarquía es real y verificada. No se muestra como equivalencia. |
| 4 | Correspondencia más amplia | `mapping_type='broader'` | Dirección canónica OFTAR → externo (§4). |
| 5 | Correspondencia más específica | `mapping_type='narrower'` | Dirección canónica OFTAR → externo (§4). |
| 6 | Relación asociativa | `mapping_type='related'` con justificación explícita en `clinical_rationale`/`source_reference` | **No es equivalencia**. Si la asociación es entre conceptos internos de OFTAR, va a `os_catalog_relation`, no aquí. |
| 7 | Sin correspondencia | `mapping_type='unmatched'` + `mapping_nature='not_mappable'` | Nunca publicada como equivalencia; se conserva con traza como decisión negativa documentada. |
| 8 | Pendiente de evaluación | `review_status='draft'` y metadatos sin aprobar | No visible como equivalencia aprobada ni con texto externo publicado (§5 y §7). `pending_review` no es valor de `CHECK`. |

**[I]** Puente documental con las ocho clases operativas del rector §8: «procedimientos diferentes» se registran como clase 7 cuando no hay ancla compartida, y «correspondencia incierta» como clase 8 hasta que exista evidencia; «aproximada/parcial», «más amplio/más específico» y «relacionados» corresponden a las clases 2/3, 4/5 y 6. **[P]** Este puente es una correspondencia de trabajo de la matriz, no una reclasificación clínica ni una autorización de publicación.

**[P]** Ninguna clase se degrade a `equivalent` por similitud textual. La similitud es pista; se exigen ancla clínica, técnica, modalidad, lateralidad, región, alcance/sesiones y condiciones (rector §8).

---

## 4. Dirección canónica y reglas de simetría

**[P] Dirección canónica:** desde el concepto OFTAR (`item_id`) hacia el sistema externo (`terminology_system_id` + `external_code`). En esa dirección:

- `broader` = el concepto OFTAR es **más amplio** que el destino externo.
- `narrower` = el concepto OFTAR es **más específico** que el destino externo.

Esta regla queda **sujeta a ratificación formal en el acta**, pero se aplica de forma consistente en este documento y en `integracion-os-concept-mapping-oftar.md` (rector §7.3).

**[P] Simetría:**

- La **equivalencia conceptual** admite regla de simetría documental: si A equivale a B, B equivale a A. No se inserta la fila inversa sin revisión, porque la fila siempre parte de un ítem OFTAR y su clave incluye `item_id`.
- `narrower` y `broader` son **inversas entre sí**: la inversa documental de «OFTAR más amplio» es «OFTAR más específico». **No se genera automáticamente** la fila inversa; requiere revisión y su propia traza.
- `related` **no implica simetría**: una asociación justificada en un sentido no autoriza la contraria sin evidencia nueva.
- `unmatched` no implica simetría computable: significa ausencia de correspondencia verificable desde ese ítem hacia ese sistema/edición.

**[H]** La unicidad es `UNIQUE(item_id, terminology_system_id, external_code, relationship_role)` (`:132`). Por tanto, **un mismo `external_code` puede tener varios `relationship_role`** sin colisión; el rol forma parte de la clave y no sustituye a la dirección del mapeo (ver `integracion-os-concept-mapping-oftar.md` §2).

---

## 5. Campos obligatorios de una proposición

| Grupo | Campos | Verificación / regla |
|---|---|---|
| Identidad del mapeo | `item_id`, `terminology_system_id`, `external_code`, `external_display` (`NOT NULL`) | `origen_catalog_engine.sql:119-124`. `external_display` conserva la descripción original de la fuente. |
| Clasificación | `mapping_type`, `relationship_role` | `CHECK` de cinco y cuatro valores respectivamente (`:125-128`); usar la tabla de la sección 3. |
| Gobernanza de la fila | `review_status` | `CHECK(draft|reviewed|approved|deprecated)` (`:130`); el default original `approved` pasa a `draft` para inserciones futuras en `fase3_relaciones_mapeos.sql:183-184`, sin tocar el `CHECK`. |
| Evidencia y vigencia | `clinical_rationale`, `source_reference`, `provenance`, `source_language_code`, `language_evidence`, `content_hash`, `valid_from`, `valid_to` | Columnas añadidas en `sql/07_multilingue/04_fase3_columnas.sql:74-83`. `content_hash` es condición de publicación del texto. |
| Metadatos de gobernanza | `os_mapping_metadata(mapping_id, source_system_id, target_system_id, source_version, target_version, mapping_type_ext, mapping_nature, method, confidence_level, source_reference, license_reference, review_status, reviewed_by, reviewed_at, valid_from, valid_to)` | `sql/08_arquitectura/fase3_relaciones_mapeos.sql:115-148`; `review_status` es FK a `os_review_state`, y `valid_to > valid_from` cuando ambas están presentes (`:139-140`). |
| Publicación de texto | `external_display`, `clinical_rationale` | `api/services/MappingReviewReader.php:10-16,71-119`: solo con revisión aprobada vigente y hash coincidente; si no, `null` + `untranslated=true`. |

**[P]** Toda propuesta originada en la matriz debe declarar: sistema/edición/release, código y display originales, idioma, procedencia, referencia de fuente (archivo/línea/refset), naturaleza de la correspondencia, método, confianza, licencia, vigencia y responsable. Si el dato no existe, se registra como desconocido o `undetermined`; nunca se inventa.

---

## 6. Vinculación SNOMED y frontera PR/DX

**[H]** SNOMED CT Argentina Edition se vincula solo desde el refset oficial `447562003`, con filtro de destino H00-H59: 6.783 de 130.055 mapeos activos con destino (rector §3). El rector fija `mapping_type='related'` y `review_status='draft'`, con `mapAdvice` conservado en `clinical_rationale`; prohíbe la importación masiva y el uso de SNOMED para equivalencias de procedimientos (rector §3, §4).

**[P]** En consecuencia:

- SNOMED es enriquecimiento gobernado y **selectivo**, no núcleo de códigos OFTAR ni atajo para «exactas».
- Se conserva `mapRule`/`mapAdvice` como justificación; una coincidencia textual no eleva `related` a `equivalent` ni `draft` a `approved`.
- El dueño legítimo de SNOMED en la identidad externa es `shared`, porque describe prestaciones y diagnósticos (`sql/03_oftar/oftar_external_identity.sql:77-78,145-147`).
- CIE-10-PCS solo se cita como referencia de procedimientos cuando la correspondencia clínica esté justificada; nunca como diagnóstico.

**[H]/[P]** La distinción PR↔DX es estructural: un `justifying_diagnosis` en `os_concept_mapping` describe el **rol del mapeo externo**, no vincula dos ítems OFTAR. La justificación PR↔DX se modela en `os_catalog_relation` con `context_text`; la ruta transversal de lectura `RelatedCodesResolver` es solo visualización de códigos relacionados y no una autoridad de correspondencia (ver `integracion-os-concept-mapping-oftar.md` §3).

---

## 7. Gobernanza

**[P]** Son etapas distintas y no sustituibles: **propuesta automática → revisión documental → revisión clínica → aprobación → rechazo**. La coincidencia textual nunca aprueba una relación ni una equivalencia. La aprobación documental de 13 pares PR no es aprobación clínica (rector §7.4 y §2).

**[H]** Los estados persistentes reales del mapeo son `draft|reviewed|approved|deprecated` (`origen_catalog_engine.sql:130`). **`rejected` y `pending_review` no existen** en ese `CHECK`. El rechazo se documenta en gobernanza (`os_governance_request`/`review`/`decision`, `os_audit_log`) y la fila conserva `draft`, `unknown` o `deprecated` según corresponda (rector §9.2).

**[P]** Publicar exige: fila `approved`, revisión de campo aprobada con `content_hash` vigente, evidencia trazable, dos revisiones humanas distintas y release `published`. Sin texto aprobado, la API responde `null` + `untranslated=true`, nunca un fallback a texto sin revisar (rector §9.2 y §9.3; `MappingReviewReader.php:10-16`).

---

## 8. Límites actuales y ampliación propuesta

**[H]** `os_terminology_system` no distingue edición/versión/release estructurados (`:111-117`). `oftar_external_identity` registra `system_code`, `code_raw` y `code_normalized` —esta última generada en mayúsculas, sin espacios, puntos ni guiones— con `UNIQUE(system_code, code_normalized)` y un único dueño por código (`sql/03_oftar/oftar_external_identity.sql:50-54,62-76`). Los mapas OFTAR enlazan esa identidad mediante `identity_id` (`oftar_external_identity.sql:86-92`).

**[I]** La estructura actual permite identidad básica, pero `CIE-10-ES 2026` e `ICD-10-CM 2027` pueden quedar indistintos si ambos se guardan como `CIE-10`; la edición solo sobrevive en texto (`politica-sistemas-identificacion-oftar.md:15,32`).

**[P] Sin migración:** reutilizar `os_terminology_system`, `os_catalog_identifier` y `oftar_external_identity` sin duplicar conceptos externos; normalizar `system_code` por edición y completar `source_reference`/`provenance`/idioma de forma consistente, apoyándose también en `os_catalog_release` para la versión.

**[P] Ampliación futura, propuesta y NO ejecutada:** metadatos estructurados de `edition`/`version`/`release`/`provenance` asociados al sistema o a una identidad externa versionada, sin crear un motor paralelo ni tablas de conceptos duplicadas. Requiere aprobación y migración aditiva previa (`politica-identificacion-oftar-final.md:74-75`; `politica-sistemas-identificacion-oftar.md:105-109`).

---

## 9. Cierre

**[I]** El modelo separa dos planos que históricamente se confundieron: la correspondencia terminológica verificable (`os_concept_mapping`, con dirección OFTAR → externo) y la relación clínica interna (`os_catalog_relation`). Las ocho clases de la matriz tienen destino persistible sin falsas equivalencias, y la gobernanza impide que una propuesta automática se convierta en publicación sin revisión y hash vigente.

**[P] Puntos que siguen sujetos a decisión formal:** (a) ratificación en el acta de la dirección `broader`/`narrower` aquí aplicada; (b) acta sobre la edición CIE-10 de referencia en Argentina; (c) aprobación de la ampliación estructural de edición/versión/release; (d) criterio para insertar o no filas inversas en equivalencias ya revisadas. Ninguno de estos puntos autoriza por sí solo escritura, seed o migración.

**Documento relacionado:** `integracion-os-concept-mapping-oftar.md` (detalle de tabla, UNIQUE, convivencia y visibilidad pública).
