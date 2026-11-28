# Modelo funcional canónico de OFTAR

**Fecha:** 2026-11-28
**Etapa:** tercera revisión — diseño documentado.
**Estado:** propuesta para aprobación. **No implementado; sin DDL ni seeds.**
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0. Ante contradicción, prevalece lo verificado y lo definido allí (§0 y §9).
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta.

---

## 1. Principio

**[H]** La fuente de verdad es `os_catalog` y sus extensiones de gobernanza, multilingüe y mapeos (`sql/02_catalogs/origen_catalog_engine.sql`, `sql/07_multilingue`). No existe motor paralelo.

**[P]** Cada concepto canónico de OFTAR-PR u OFTAR-DX es un ítem de `os_catalog_item` con una versión gobernada, un código propio permanente y una identidad externa trazable. La fuente externa **nunca** reemplaza al identificador OFTAR.

---

## 2. Campos obligatorios del concepto canónico

| Campo requerido | Destino en el modelo actual | Estado | Regla |
|---|---|---|---|
| Identificador permanente | `os_catalog_item.id` / código estable del ítem | Existente | Inmutable; no se reutilizan retirados. |
| Código propio OFTAR | `os_catalog_identifier.value` con `is_primary` | Existente | `OFT-PR-NNNNNN` / `OFT-DX-NNNNNN`; no depende de fuente externa. |
| Descripción preferida | `os_catalog_term` con `preferred_term` aprobado | Existente | Publicada solo tras `os_field_review` con hash. |
| Sinónimos | `os_catalog_term` adicionales por idioma | Existente | Revisados; nunca por similitud automática. |
| Definición clínica | `definition` / campo de definición de dominio OFTAR | Parcial | Redactada con evidencia; si no hay campo propio, usar extensión OFTAR existente. |
| Alcance | Extensión de dominio OFTAR / metadato de versión | A confirmar | Incluye técnica, regionalidad y condición de realización. |
| Exclusiones | Extensión de dominio OFTAR / texto governado | A confirmar | Ej.: “no incluye lente”, “no incluye insumos”. |
| Categoría | `os_catalog_item_version.category_id` + `os_catalog_item_clinical_category` | Existente | `category` fuente + `clinical_category` aditiva. |
| Relaciones anatómicas | `ATTR-STRUCTURE` / `os_catalog_relation` | Existente | Una o varias; `ANAT-*`. Diferenciar estructura, agrupación y función; las agrupaciones no propagan hijos automáticamente. |
| Área clínica | Atributo o relación controlada | Existente | `AREA-*`; no `CLIN-*` nuevo. Función, motilidad y práctica clínica se expresan aquí, no como `ANAT-*`. |
| Lateralidad | `ATTR-LATERALITY` | Existente | OD/OI/AO/NA; atributo, nunca código nuevo. |
| Modalidad / técnica | `ATTR-MODALITY` / técnica en extensión | Existente | Definido; dominio a cargar por gobernanza. |
| Identificadores externos | `os_catalog_identifier`, `os_concept_mapping`, `oftar_external_identity` | Existente | Sistema, edición, versión y procedencia según política final. |
| Procedencia | `provenance`, `source_reference` | Existente | Obligatoria, específica por fuente. |
| Estado editorial | `review_status`, `os_field_review`, `os_audit_log` | Existente | Depende del objeto: versión `unknown`/`approved` sin CHECK; mapeo `draft\|reviewed\|approved\|deprecated`; campo/traducción `unknown`/`approved` con hash. `in_review` y `rejected` son etiquetas de gobernanza, no valores persistidos. |
| Vigencia | `valid_from`, `valid_to`, `active` | Parcial | Solo si la fuente la declara; si no, `desconocida`. |
| Versión | `os_catalog_release`, versión de ítem | Existente | Toda corrección crea versión nueva; no sobrescribe la publicada. |

**[H]** Los campos base verificados incluyen `os_catalog_item_version.category_id`, `os_catalog_term`, `os_catalog_identifier`, `os_concept_mapping` con `review_status`/`provenance`/`source_reference`/`content_hash`/`valid_from`/`valid_to`, y `os_field_review` con aprobación por campo. **[H]** `ATTR-STRUCTURE`, `ATTR-MODALITY` y `ATTR-LATERALITY` son códigos en `oftar_attribute_definition` (`oftar_core.sql:257-274`), no columnas; `ANAT-*` y `AREA-*` son propuestas documentales no sembradas en SQL.

**[I]** Los campos “alcance” y “exclusiones” son los que tienen menos soporte estructurado explícito. Pueden resolverse con la extensión de dominio OFTAR ya existente; si se decide darles campo propio en el motor, esa sería una ampliación futura.

---

## 3. Identificadores propios

**[P]** Reglas inmutables:

1. `OFT-PR-NNNNNN` para procedimientos; `OFT-DX-NNNNNN` para diagnósticos.
2. La numeración se asigna por máximo + 1 dentro del prefijo vigente, con control de concurrencia.
3. No se reutilizan `OFTAR-PR-` ni `OFTAR-DX-` retirados.
4. El código propio no se deriva del código externo: un cambio de edición externa no cambia `OFT-PR-`/`OFT-DX-`.
5. Los códigos de fuente (NN 2025, CAO, Regional) conservan su numeración original como identificador de origen.

**[I]** Los 3 números repetidos entre NN y Regional (`305022`, `305025`, `305047`) confirman que la resolución debe hacerse por `(catálogo, identificador)`, no por número aislado.

---

## 4. Relaciones permitidas

| Relación solicitada | Soporte actual propuesto | Uso clínico |
|---|---|---|
| Equivalente a | `os_concept_mapping.mapping_type='exact'` (valor real del `CHECK`) | Solo con evidencia y doble revisión. |
| Más amplio que | `mapping_type='broader'` | Dirección: concepto OFTAR respecto del externo, a ratificar. |
| Más específico que | `mapping_type='narrower'` | Misma convención de dirección. |
| Relacionado con | `mapping_type='related'` o `os_catalog_relation` | Asociación clínica/editorial, no equivalencia. |
| Variante de | `os_catalog_relation` con `relation_kind` de variante, o metadata de atributo | Preferir atributo cuando solo cambia lateralidad/sesión. |
| Sustituido por | `os_catalog_relation` con vigencia | Para códigos retirados; nunca borrar el histórico. |
| Requiere | `os_catalog_relation` con contexto | Solo si la dependencia está documentada. |
| Incluye | `os_catalog_relation` / jerarquía de versión | Para paquetes con sesiones incluidas. |

**[H]** `os_concept_mapping` y `os_catalog_relation` ya soportan tipos de mapeo/relación con `provenance`, `reviewed_by`, `context_text` y `valid_from/to` (`taxonomia-oftar-propuesta.md:78-90`).

**[I]** Algunas relaciones (`variante de`, `sustituido por`, `requiere`, `incluye`) pueden necesitar un `relation_type` específico. Se prefiere reutilizar `relation_kind` existente con `context_text` antes que ampliar el `CHECK` de la base.

**[P]** No usar `exact` para aproximaciones parciales: estas deben ser `related` + evidencia de parcialidad en `mapping_nature` o en la metadata de gobernanza, con `review_status='approved'` solo tras revisión.

---

## 5. Versionado, idiomas y gobernanza

**[P] Versionado:** cada cambio publicable crea una versión nueva de `os_catalog_item_version` dentro de un release; el código `OFT-PR-`/`OFT-DX-` permanece. Las correcciones de texto pasan por `os_field_review` con hash vigente.

**[P] Idiomas:** `es-AR` es idioma principal, fallback y obligatorio para conceptos publicados; `en` y `pt-BR` tienen cobertura progresiva, sin exigencia de paridad. Los huecos se informan con estado explícito (`untranslated`); solo se publican textos con revisión aprobada y hash vigente. No inventar traducciones para los 17 códigos ICD-10-CM exclusivos.

**[P] Gobernanza:** dos revisiones humanas distintas y traza en `os_audit_log`. Los estados de trabajo **Pendiente, En revisión, Aprobado, Rechazado y Requiere información** son etiquetas de gobernanza, **no valores de `CHECK`**. Los valores persistentes reales son: `os_concept_mapping.review_status ∈ draft|reviewed|approved|deprecated` (default `draft`); `os_catalog_item_version.review_status` sin CHECK y default `unknown`, al que los scripts OFTAR ponen `approved` (`04_fase3_columnas.sql:24-37`); `os_field_review`/`os_localized_text.review_status` sin CHECK y default `unknown`, con aprobación por hash vigente. `draft|review|published|deprecated` pertenece a `os_catalog_release.status`. No existen `pending_review` ni `rejected` en el SQL versionado. `v_oftar_search_catalog` publica solo versiones `approved` (`oftar_domain_search.sql:77`). La definición autorizada es §9 de `especificacion-definitiva-reconstruccion-oftar.md`.

**[P] UVR:** las UVR son atributo de prestación `oftar-pr`; `oftar-dx` no recibe UVR. Los importes de CAO y Regional se mantienen separados y no se convierten.

---

## 6. Cierre

**[I]** El modelo actual cubre casi todos los campos requeridos; la debilidad está en la disciplina de uso (textos no aprobados publicados como verdades, ediciones mezcladas), no en falta de estructura.

**[P]** Queda resuelto el modelo funcional. Quedan pendientes de aprobación: los nombres concretos de dominio para `alcance`/`exclusiones`, la dirección de `broader`/`narrower` y la convención de `relation_kind` para variante/sustitución.
