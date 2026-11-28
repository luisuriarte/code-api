# Integración de `os_concept_mapping` con los sistemas externos de OFTAR

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** OFTAR v1.0 — Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada. (No autoriza ejecución.)
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta sujeta a aprobación explícita.

> Documento de solo lectura. No se ejecutaron SQL, seeds, migraciones ni importadores; no se consultó ni se escribió en PostgreSQL. Las reglas de inserción de la sección 4 son **propuestas para el futuro**, no instrucciones ejecutadas.

---

## 1. Qué representar y qué NO

**[H]** `os_concept_mapping` representa una correspondencia entre un ítem de `os_catalog` y un código de un sistema terminológico externo: `item_id`, `terminology_system_id`, `external_code`, `external_display`, `mapping_type`, `relationship_role`, `clinical_rationale` y `review_status` (`sql/02_catalogs/origen_catalog_engine.sql:119-136`). La Fase 3 añadió `provenance`, `source_reference`, `source_language_code`, `language_evidence`, `content_hash`, `valid_from`/`valid_to` (`sql/07_multilingue/04_fase3_columnas.sql:74-83`).

| Representar en `os_concept_mapping` | NO representar aquí |
|---|---|
| Correspondencia entre un ítem OFTAR y un código de NN, CAO, Regional NOA, CIE-10-ES, ICD-10-CM, SNOMED o PCS. | Relaciones clínicas internas PR↔PR, DX↔DX, **PR↔DX**, anatómicas o funcionales: van a `os_catalog_relation` (rector §7.2). |
| `mapping_type ∈ equivalent|narrower|broader|related|unmatched` y `mapping_nature ∈ univocal|multiple|partial|approximate|not_mappable`. | Valores `exact`, `no_map`, `reference`, `pending_review` o `rejected`: no existen en los `CHECK` de `mapping_type` ni de `review_status` de estas tablas (`:126,130`; `fase3_relaciones_mapeos.sql:125-127`). |
| Rol del mapeo (`procedure_concept`, `justifying_diagnosis`, `observation_concept`, `substance_concept`). | Uso de `justifying_diagnosis` como si fuera una relación PR↔DX: es rol de mapeo, no puente clínico. |
| Justificación y fuente de la correspondencia (`clinical_rationale`, `source_reference`). | Conversiones automáticas: 17 códigos ICD-10-CM exclusivos → CIE-10-ES, traducciones inventadas, equivalencias SNOMED por similitud. |
| Metadatos de gobernanza en `os_mapping_metadata` (1:1 con la fila). | Duplicar sistemas o conceptos externos ya registrados en `os_terminology_system`, `os_catalog_identifier` u `oftar_external_identity`. |

**[P] Contrato canónico:** la dirección es desde el concepto OFTAR (`item_id`) hacia el sistema externo. `broader` = OFTAR más amplio que el destino; `narrower` = OFTAR más específico; convención sujeta a ratificación en el acta pero aplicada de forma uniforme junto con `modelo-relaciones-terminologicas-oftar.md`. La clasificación de las ocho clases, incluida la prohibición de mostrar parcial/asociativa como equivalencia, está en ese documento §3.

---

## 2. Anatomía de la tabla y la `UNIQUE`

**[H]** DDL verificado en `sql/02_catalogs/origen_catalog_engine.sql:111-136`:

| Elemento | Definición verificada | Consecuencia operativa |
|---|---|---|
| `os_terminology_system` | `id`, `code VARCHAR(50) NOT NULL UNIQUE`, `name`, `uri NOT NULL`, `default_version` (`:111-117`) | Un registro por sistema/edición normalizada; no crear un sistema nuevo para reutilizar un código ya existente. |
| `os_concept_mapping.item_id` | FK a `os_catalog_item(id) ON DELETE CASCADE` (`:121`) | La correspondencia siempre parte de un ítem canónico del motor. |
| `terminology_system_id` | FK a `os_terminology_system(id) ON DELETE CASCADE` (`:122`) | El destino se identifica por sistema, no por texto libre. |
| `external_code` / `external_display` | Ambos `NOT NULL` (`:123-124`) | Código y descripción original son obligatorios; el display se publica solo con revisión vigente (§5). |
| `mapping_type` | `NOT NULL DEFAULT 'equivalent'`, `CHECK(equivalent|narrower|broader|related|unmatched)` (`:125-126`) | No hay valor `exact` ni `no_map`; «exacta» es etiqueta documental. |
| `relationship_role` | `NOT NULL DEFAULT 'procedure_concept'`, `CHECK(procedure_concept|justifying_diagnosis|observation_concept|substance_concept)` (`:127-128`) | Rol del mapeo; no es clasificación clínica. |
| `clinical_rationale` | `TEXT` nullable (`:129`) | Soporte de clases aproximada/parcial/asociativa y de `mapAdvice` SNOMED. |
| `review_status` | `NOT NULL DEFAULT 'approved'`, `CHECK(draft|reviewed|approved|deprecated)` (`:130`) | El default vigente para inserciones futuras cambia a `draft` en `fase3_relaciones_mapeos.sql:183-184`, sin alterar filas ni el `CHECK`. |
| **`UNIQUE`** | `(item_id, terminology_system_id, external_code, relationship_role)` (`:132`) | **Un mismo `external_code` puede tener varios `relationship_role`**: el rol forma parte de la clave. La unicidad no es global por código externo. |
| Índices | `idx_os_mapping_ext(external_code)` e `idx_os_mapping_item(item_id, relationship_role)` (`:135-136`) | Búsquedas por código y por ítem/rol; no sustituyen a la `UNIQUE`. |

**[I]** La `UNIQUE` impide repetir la misma combinación ítem+sistema+código+rol, pero permite que un código externo aparezca en varios ítems y con varios roles. Por eso la llave de idempotencia futura debe ser esa combinación completa, no `external_code` aislado (§4).

**[H]** `os_mapping_metadata` se crea en `sql/08_arquitectura/fase3_relaciones_mapeos.sql:115-148` con `mapping_id INT PRIMARY KEY REFERENCES os_concept_mapping(id) ON DELETE CASCADE` (`:118-119`): es una extensión **1:1** de gobernanza, no una segunda tabla de mapeos.

---

## 3. Convivencia con las tablas y el resolvedor existentes

### 3.1 `os_terminology_system` y alias

**[H]** Registro canónico de sistemas (`origen_catalog_engine.sql:111-117`). `os_terminology_system_alias` permite declarar equivalencia donde el código **ya coincide exactamente**, sin mover filas (`fase3_relaciones_mapeos.sql:150-160`). **[P]** Reutilizar el sistema por `code` normalizado por edición; no fundir ediciones distintas aunque el alfanumérico del código coincida.

### 3.2 `os_mapping_metadata`

**[H]** Campos verificados (`fase3_relaciones_mapeos.sql:118-141`): `source_system_id` y `target_system_id` (FK a `os_terminology_system`, `ON DELETE SET NULL`), `source_version`/`target_version`, `mapping_type_ext`, `mapping_nature CHECK(univocal|multiple|partial|approximate|not_mappable)`, `method`, `confidence_level`, `source_reference`, `license_reference`, `review_status NOT NULL DEFAULT 'unknown'` con FK a `os_review_state(code) ON UPDATE CASCADE`, `reviewed_by`, `reviewed_at`, `valid_from`/`valid_to` y `ck_os_mapping_metadata_validity` (`valid_to > valid_from` cuando ambas existen). El comentario de tabla aclara que **la visibilidad depende de `review_status`, no de `provenance`** (`:146-147`).

**[I]** `mapping_type` (CHECK cerrado) y `mapping_type_ext` (texto de 40 caracteres) responden a necesidades distintas: el primero es la semántica persistible; el segundo puede conservar la etiqueta de origen siempre que no se use para eludir el `CHECK`. **[P]** Ninguno de los dos puede contener `exact`/`no_map`/`reference` como reemplazo del valor canónico.

### 3.3 `os_catalog_identifier`

**[H]** `system_name`, `value`, `is_primary`, con `UNIQUE(item_id, system_name, value)` (`origen_catalog_engine.sql:92-99`). Es el identificador visible del ítem cuando `is_primary=TRUE`; la búsqueda de mapeos lo usa como `official_code` (`api/services/CatalogEngineService.php:641-662`). **[P]** Reutilizarlo para la identidad del lado OFTAR; no convertirlo en tabla de correspondencias ni duplicar allí el código externo destino.

### 3.4 `oftar_external_identity`

**[H]** Registro central de identidad externa (`sql/03_oftar/oftar_external_identity.sql:62-92`): `system_code`, `code_raw`, `code_normalized` (generada en mayúsculas sin espacios, puntos ni guiones, `:50-54`), `owner_catalog CHECK(oftar-pr|oftar-dx|shared)`, `entity_kind CHECK(concept|diagnosis|shared)`, `UNIQUE(system_code, code_normalized)` (`:71`) y un solo dueño por código. SNOMED es la excepción `shared` (`:77-78,145-147`). Las tablas `oftar_concept_mapping` y `oftar_diagnosis_mapping` enlazan `identity_id` con `ON DELETE RESTRICT` (`:86-92`).

**[P]** Antes de proponer una fila, resolver la identidad existente por `system_code` + `code_normalized`; si existe, reutilizarla. No crear una segunda fila con otra forma de escribir el mismo código, ni asignar dueño distinto al declarado.

### 3.5 `RelatedCodesResolver`

**[H]** Es un lector de códigos transversales (`api/services/RelatedCodesResolver.php:25-83`): deduplica por `strtolower(system)|code` (`:53-57`), consulta `os_prestacion_codigo` (incluye filas `approved` **y** `draft`, `:98-106`) y tablas heredadas `map_snomed_cie10`, `map_snomed_nbu`, `nomencladores_argentina`, etc. (`:131-200`), y emite etiquetas como `mapped`, `related_snomed` o `equivalent` en el campo `relationship` (`:156,172,186`).

**[H]** `CatalogEngineService.php:528-562` toma el primer `external_code` numérico de un sistema SNOMED entre los mapeos del ítem y lo pasa al resolvedor; el resultado se publica como `related_codes` (`:621`).

**[P]** `related_codes` es una **lista de visualización**, no una fuente de verdad de mapeos: no se escribe en ella, no cambia `mapping_type`, no aprueba borradores y no sustituye a `os_mapping_metadata`. Una etiqueta `equivalent` del resolvedor no autoriza a persistir `mapping_type='equivalent'`. La frontera PR↔DX se mantiene en `os_catalog_relation`.

---

## 4. Reglas de inserción idempotente futura (sin ejecutar)

**[P]** Secuencia propuesta para una futura implementación controlada. **No se ha ejecutado ninguna de estas acciones.**

1. **Resolver el sistema:** buscar/crear `os_terminology_system` por `code` normalizado por edición; reutilizar el registro existente. Declarar `source_version`/`target_version` y `source_reference` con edición y release.
2. **Resolver el ítem y la identidad:** confirmar `item_id` por `permanent_code` (`OFT-PR-`/`OFT-DX-`); buscar `oftar_external_identity` por `(system_code, code_normalized)`; reutilizar `identity_id`. Verificar dueño (`oftar-pr`, `oftar-dx` o `shared` para SNOMED).
3. **Validar la clasificación:** aplicar la tabla de ocho clases de `modelo-relaciones-terminologicas-oftar.md` §3; verificar `mapping_type`, `relationship_role` y `mapping_nature` contra sus `CHECK` antes de cualquier inserción; `review_status` inicial `draft`.
4. **Clave de idempotencia:** la combinación `item_id + terminology_system_id + external_code + relationship_role` de la `UNIQUE` (`:132`). Ante repetición, no duplicar: conservar la fila existente y registrar el hallazgo en gobernanza. Nunca borrar ni reemplazar una fila aprobada; para retirarla, usar `deprecated` con traza.
5. **Completar evidencia:** `external_display`, `clinical_rationale`, `source_reference`, `provenance`, idioma, licencia, método, confianza, `valid_from`/`valid_to` y `content_hash`. Los datos ausentes se marcan como desconocidos; no se infieren.
6. **Metadatos 1:1:** crear/actualizar `os_mapping_metadata` por `mapping_id`, respetando el FK de `review_status` a `os_review_state` y el `CHECK` de vigencia. Actualizar solo con decisión de gobernanza trazada.
7. **Sin inversión automática:** no insertar la fila contraria por simetría de `equivalent` ni por inversión de `narrower`/`broader`; toda inversa requiere revisión propia.
8. **Sin mezcla de sistemas:** códigos alfanuméricamente iguales de CIE-10-ES 2026 e ICD-10-CM 2027, o de NN/CAO/Regional, se resuelven por sistema + edición + release.
9. **Gobernanza y cierre:** propuesta → revisión documental → revisión clínica → aprobación o rechazo documentado (sin valor `rejected`), con dos revisiones y traza en `os_audit_log`. Solo entonces se habilita publicación con revisión de campo vigente y hash.

**[I]** Estas reglas son aditivas y no requieren, por sí solas, ampliar el esquema. La ampliación estructural de edición/versión/release sigue siendo una propuesta no ejecutada (`modelo-relaciones-terminologicas-oftar.md` §8).

---

## 5. Visibilidad pública

**[H]** En el detalle de ítem, `CatalogEngineService.php:531-546` consulta los mapeos del ítem y delega en `MappingReviewReader`; la respuesta expone `system`, `uri`, `code`, `display`, `equivalence` (= `mapping_type` sin interpretar), `role`, `rationale`, `field_languages` y `untranslated` (`:601-620`). En `/v1/mappings`, la consulta exige release `published`, une `os_catalog_identifier` primario y filtra por `system`, `code` o `catalog` (`:641-679`); la respuesta incluye `target_system`, `target_code`, `target_display`, `equivalence`, `role`, `rationale` y `untranslated` (`:694-713`).

**[H]** `api/services/MappingReviewReader.php:10-16` fija la regla: `external_display` y `clinical_rationale` se sirven desde la columna original **solo** si existe revisión aprobada vigente en `os_field_review` (`language_code='undet'`, sin release); si no hay aprobación, o el texto cambió y el `content_hash` ya no coincide, el valor es `null` y `untranslated=true`. Nunca se usa la columna original como atajo editorial (`:71-119`).

**[P] Regla de gobernanza:** una fila en `draft` (clase 8) no se publica como equivalencia ni con texto externo visible. La aprobación requiere fila `approved`, revisión de campo aprobada, hash vigente, dos revisiones y release `published` (rector §9.2 y §9.3).

**[I] Hueco de implementación a subsanar con aprobación:** el `SELECT` actual de `/v1/mappings` (`:641-662`) **no filtra** `m.review_status`, por lo que un borrador podría aparecer con código/tipo, aunque sin `display`/`rationale` aprobados. No debe afirmarse que hoy el filtro de borradores ya existe: la regla anterior es la política a aplicar, y hacerla efectiva en la consulta requiere un cambio aprobado. Lo mismo vale para los códigos `draft` que `RelatedCodesResolver` puede mostrar (§3.5).

---

## 6. Checklist de compatibilidad

| # | Comprobación documental | Estado |
|---:|---|---|
| 1 | `mapping_type` solo `equivalent|narrower|broader|related|unmatched`; `exact`/`no_map`/`reference` ausentes del `CHECK`. | **[H]** `origen_catalog_engine.sql:125-126`; rector §7.3. |
| 2 | Ocho clases con destino coherente entre ambos documentos; parcial/asociativa nunca mostradas como exacta. | **[P]** `modelo-relaciones-terminologicas-oftar.md` §3; rector §7.3. |
| 3 | Dirección OFTAR → externo; `broader`/`narrower` con la misma Convención en ambos documentos, sujeta a acta. | **[P]** rector §7.3. |
| 4 | `UNIQUE(item_id, terminology_system_id, external_code, relationship_role)` respetada; un código externo admite varios roles. | **[H]** `origen_catalog_engine.sql:132`. |
| 5 | `justifying_diagnosis` tratado como rol de mapeo, no como relación PR↔DX. | **[H]/[P]** `:127-128`; rector §7.2. |
| 6 | Sistemas por sistema + edición + release; sin mezcla de CIE-10-ES 2026, ICD-10-CM 2027 ni nomencladores argentinos. | **[P]** rector §4 y §7.3; `politica-identificacion-oftar-final.md` §2. |
| 7 | Reutilización de `os_terminology_system`, `os_catalog_identifier` y `oftar_external_identity`; sin conceptos externos duplicados. | **[H]/[P]** `:111-117,92-99`; `oftar_external_identity.sql:59-92`. |
| 8 | `os_mapping_metadata` 1:1 con `mapping_id`, `mapping_nature` válido, `review_status` FK a `os_review_state`, vigencia coherente. | **[H]** `fase3_relaciones_mapeos.sql:115-148`. |
| 9 | Texto externo solo con revisión aprobada y hash vigente; sin fallback editorial. | **[H]** `MappingReviewReader.php:10-16,71-119`; `CatalogEngineService.php:528-546,601-620,641-713`. |
| 10 | Sin `rejected`/`pending_review` como valores de `CHECK`; rechazo documentado en gobernanza. | **[H]** `:130`; rector §9.2. |
| 11 | Contratos de API sin cambios de rutas ni envelope; `equivalence` reenvía el valor real. | **[H]** `CatalogEngineService.php:601-620,694-713`. |
| 12 | Cero escrituras: este documento no ejecuta SQL, seeds, migraciones ni importaciones. | **[H]** alcance documental; rector §0 y §14. |

---

## 7. Cierre

**[I]** La integración correcta consiste en mantener `os_concept_mapping` como canal estrecho y gobernado de correspondencias externas, apoyado en `os_mapping_metadata` para naturaleza, evidencia y vigencia; la identidad externa se reutiliza, el rol no se confunde con relación clínica y la API solo publica texto revisado.

**[P] Dudas abiertas para el acta:** ratificación de dirección `broader`/`narrower`; definición de la edición CIE-10 argentina; aprobación de la extensión de metadatos de edición/versión/release; y decisión de filtrar `review_status='draft'` en `/v1/mappings` y en `RelatedCodesResolver` para hacer efectiva la regla de no visibilidad. Ninguna de ellas autoriza ejecución en este momento.

**Documento relacionado:** `modelo-relaciones-terminologicas-oftar.md` (principio, sistemas, ocho clases, simetría y gobernanza).
