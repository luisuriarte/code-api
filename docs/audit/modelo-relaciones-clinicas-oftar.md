# Modelo integral de relaciones clínicas de OFTAR

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** OFTAR v1.0 — Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada. (No autoriza ejecución.)
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta sujeta a aprobación explícita.
**Alcance:** relaciones clínicas internas entre conceptos OFTAR-PR, OFTAR-DX y anatomía/función. No cubre correspondencias con terminologías externas.

> Documento **solo de diseño**. Para su elaboración no se ejecutó SQL, seed, migración, importador ni consulta alguna a PostgreSQL: las fuentes se verificaron **por lectura**. Nada de lo aquí descrito autoriza escribir en la base de datos. El detalle de cada código está en `diccionario-tipos-relacion-oftar.md`.

---

## 1. Principio y límites verificados

**[H]** `os_catalog_relation` existe en `sql/03_dentar/nomenclador_odontologico_nacional.sql:534-559` y ya es el contenedor del motor para relaciones entre ítems del catálogo:

| Elemento | Hecho verificado |
|---|---|
| Extremos | `source_item_id` y `target_item_id`, `INT NOT NULL`, FK a `os_catalog_item(id)` con `ON DELETE CASCADE`. |
| Tipo | `relation_type VARCHAR(60) NOT NULL` con `CHECK` de **15 valores CDT**: `alternate_benefit`, `billed_in_conjunction_with`, `concurrent_to`, `denied_as_integral`, `frequency_limitations`, `integral_to`, `interchangeable_with`, `not_paid_separately`, `not_to_be_used_with`, `paid_as_code`, `procedure_code_not_used_for`, `refer_to_details`, `referencia_literal`, `shares_frequency_limitation_with`, `used_in_combination_with`. |
| Origen | `source_system_code VARCHAR(30) NOT NULL DEFAULT 'CDT-2025'`. |
| Campo fuente | `source_field VARCHAR(30) NOT NULL CHECK (description\|procedure\|notes\|req)`. |
| Valor fuente | `source_value VARCHAR(20) NOT NULL`: cualquier código canónico propuesto debe caber en 20 caracteres. |
| Contexto | `context_text TEXT` (sin `NOT NULL` en el esquema), con comentario posterior que lo declara parte de la clave única y no descartable al exportar (`fase3_relaciones_mapeos.sql:110-111`). |
| Estado | `review_status VARCHAR(20) NOT NULL DEFAULT 'reviewed' CHECK (draft\|reviewed\|approved\|deprecated)`. **No existen `pending_review` ni `rejected`**. |
| Trazabilidad | `provenance TEXT NOT NULL` y `created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP`. |
| Integridad | `ck_os_catalog_relation_not_self` prohíbe `source_item_id = target_item_id`; `uq_os_catalog_relation` es única sobre **7 columnas**: `(source_item_id, target_item_id, relation_type, source_system_code, source_field, source_value, context_text)`. |

**[H]** `sql/08_arquitectura/fase1_infraestructura.sql:42-81` crea `os_relation_kind` con siete valores-semilla (`unclassified`, `structural`, `clinical`, `editorial`, `billing`, `regulatory`, `mapping`) y `os_relation_type(code VARCHAR(60) PK, relation_kind VARCHAR(30) NOT NULL DEFAULT 'unclassified' FK, source TEXT NOT NULL, inverse_code VARCHAR(60) FK autoreferenciado, is_active, created_at)`. El bloque `DO` solo deriva tipos desde `os_catalog_relation` **si la tabla ya existe**, usando `source = 'os_catalog_relation:' || source_system_code` y `ON CONFLICT DO NOTHING`: no inventa códigos nuevos.

**[H]** `sql/08_arquitectura/fase3_relaciones_mapeos.sql:53-113` añade a `os_catalog_relation`, de forma aditiva y sin quitar el `CHECK` vigente: `valid_from`, `valid_to`, `source_catalog_id`, `source_release_id`, `target_catalog_id`, `target_release_id`, `relation_kind` (default `unclassified`), `mapping_method`, `confidence_level`, `reviewed_by`, `reviewed_at`, `license_reference` e `inverse_relation_type`. Agrega FK a catálogos/releases/`os_relation_kind`, el `CHECK ck_ocr_validity`, índices y el comentario de que las 603 filas previas quedan `unclassified` hasta revisión editorial. **No añade `relation_type_code`**: la migración propuesta en §3 es adicional, independiente y no ejecutada.

**[H]** `portal/Repositories/CatalogRepository.php:2992-3121` construye **una sola lista** `$relations`: primero los mapeos de `os_concept_mapping` (con sistema externo, `mapping_type`, `relationship_role`, `review_status`, `provenance` y `result_key`) y luego las filas de `os_catalog_relation`. Para estas últimas calcula `CASE WHEN r.source_item_id = ? THEN 'outgoing' ELSE 'incoming' END`, ordena por dirección/tipo/código y expone `source_field`, `source_value` y `context_text`. El resultado pasa por `dedupeRelations()` (`:3121`, `:3124-3164`), que colapsa espejos por `sistema|código|tipo` y prefiere la versión saliente/aprobada/enlazada.

**[I]** Por lo tanto, `outgoing`/`incoming` es **presentación de la ficha**, no una inversa semántica: el motor no deduce equivalencia, jerarquía ni simetría a partir de la dirección mostrada por la API.

**[P] Contrato canónico — límites que no se negocian:**

1. `os_concept_mapping` queda **reservado a correspondencias terminológicas con sistemas EXTERNOS** (p. ej. SNOMED CT Argentina Edition, CIE-10-ES/ICD-10-CM). **No se usa para relaciones clínicas internas OFTAR ni para PR↔DX.**
2. Las relaciones clínicas se modelan en `os_catalog_relation`, integradas al motor existente. **No se crea un motor paralelo**, tabla propia ni repositorio alternativo.
3. La dirección canónica es siempre `source_item_id → target_item_id`.
4. No se generan inversas automáticas salvo equivalencia semántica aprobada. Simétricas: declaradas explícitamente. Jerárquicas: direccionales. Asociativas: no equivalentes.
5. Un procedimiento puede tener muchos diagnósticos y un diagnóstico muchos procedimientos: cardinalidad **muchos a muchos**, sin equivalencia entre PR y DX.
6. `exact`, `no_map` y `rejected` **no son valores persistibles** en ninguno de los modelos aquí descritos.

---

## 2. Inventario de clases A–E

| Clase | Nombre | Par permitido | Prefijo de los códigos canónicos | Qué modela | Qué no modela |
|---|---|---|---|---|---|
| **A** | Procedimiento ↔ procedimiento | OFTAR-PR ↔ OFTAR-PR | `REL-PR-*` (7) | Relación, complementariedad, alternativa, parte, combinación, requerimiento y secuencia entre prestaciones. | Equivalencia facturada ni cobertura: los valores CDT `billed_in_conjunction_with`, `not_paid_separately`, `integral_to`, etc. conservan su dominio. |
| **B** | Diagnóstico ↔ diagnóstico | OFTAR-DX ↔ OFTAR-DX | `REL-DX-*` (9) | Relación, asociación, diferencial, especificidad/amplitud, manifestación, complicación, etiología y coexistencia. | Un diagnóstico nuevo, duplicado ni conversión entre ediciones CIE. |
| **C** | Procedimiento ↔ diagnóstico | OFTAR-PR → OFTAR-DX | `REL-PRDX-*` (9) | Diagnóstico, evaluación, terapia, tratamiento, seguimiento, control, prevención, contraindicación y no recomendación. | Equivalencia PR↔DX. `os_concept_mapping` queda fuera de esta clase. |
| **D** | Anatomía | Concepto clínico ↔ `ANAT-*`, o `ANAT-* ↔ ANAT-*` | `REL-ANAT-*` (5) | Afectación, intervención, evaluación, localización y pertenencia anatómica. | Propagación desde agrupaciones (`ANAT-UVE`, `ANAT-SUP`) a sus miembros. |
| **E** | Función | Concepto clínico ↔ área/función gobernada | `REL-FUNC-*` (1) | Deterioro funcional con evidencia, p. ej. motilidad/visión binocular bajo `AREA-ESTRAB`. | Confundir `ANAT-MOT` o `ANAT-NEU` con el área funcional. |

**[H]** `ATTR-STRUCTURE`, `ATTR-MODALITY` y `ATTR-LATERALITY` son códigos en `oftar_attribute_definition`, no columnas; `ANAT-*` y `AREA-*` aún no están sembrados en SQL (`oftar_core.sql:257-274,298-306`; rector §6).

**[P]** `ANAT-UVE` es agrupación y `ANAT-COROID` es estructura miembro; `ANAT-SUP` es agrupación funcional de córnea, conjuntiva y película lagrimal, **no una estructura nueva**; `ANAT-NEU` es el nervio óptico y `ANAT-MOT` los músculos extraoculares, mientras que motilidad y visión binocular se navegan como `AREA-ESTRAB` (rector §6 y §15.3, criterio 11).

---

## 3. Representación destino y puente

### 3.1 Representación destino `[P]` — no implementada

- Nuevos tipos en `os_relation_type` con `relation_kind = 'clinical'`, `source = 'OFTAR-v1.0'` e `inverse_code` **solo** cuando exista inversa semánticamente equivalente (en el diccionario, el par `REL-DX-NARROW` ↔ `REL-DX-BROAD`).
- Migración **aditiva e independiente**, preparada pero **no ejecutada**: añadir `relation_type_code VARCHAR(60) NULL` a `os_catalog_relation`, con FK a `os_relation_type(code)`. La columna legada `relation_type` se conserva intacta, con su `CHECK` CDT de 15 valores.
- **No se inventan valores nuevos dentro del `CHECK` actual** de `os_catalog_relation.relation_type`. El destino tipado se resuelve por la columna nueva, no por ensanchar el dominio heredado.
- Si Fase 3 está aplicada en el entorno, `relation_kind`, `mapping_method`, `confidence_level`, `reviewed_by/at`, `license_reference`, `inverse_relation_type`, `valid_from/to` y los pares catálogo/release quedan disponibles sin otro DDL; su sola existencia no implica que estén cargados.

### 3.2 Puente sin migración `[P]` — solo mientras se aprueba la migración

| Columna | Valor del puente | Origen |
|---|---|---|
| `source_item_id` | ítem OFTAR desde el cual se afirma la relación | dirección canónica |
| `target_item_id` | ítem OFTAR hacia el cual se afirma la relación | dirección canónica |
| `relation_type` | `referencia_literal` | valor ya permitido por el `CHECK` (`nomenclador_odontologico_nacional.sql:543`) |
| `source_system_code` | `OFTAR-CLINICAL` | `VARCHAR(30)`, coherente con el contrato |
| `source_field` | `notes` | valor ya permitido por el `CHECK` (`:547`) |
| `source_value` | código corto de la relación (≤20 caracteres), p. ej. `REL-PRDX-DIAG` | `VARCHAR(20)` (`:548`) |
| `context_text` | condiciones, lateralidad declarada, alcance, secuencia u observaciones | `TEXT` (`:549`); parte de la clave única (`:556-558`) |
| `provenance` | **obligatoria**: fuente, archivo/fila y sistema+edición | `NOT NULL` (`:553`) |
| `review_status` | valor real del esquema: `draft`, `reviewed`, `approved` o `deprecated` | `CHECK` (`:551-552`) |

**[I]** Dado que `context_text` es nullable y forma parte de `uq_os_catalog_relation` (`:556-558`), dejarlo en `NULL` puede impedir que la unicidad detecte duplicados. En el puente debe registrarse contexto incluso cuando sea mínimo; nunca se usa `NULL` como sustituto de la decisión clínica.

**[P] Advertencia:** sin Fase 3 no hay `relation_kind` ni vigencia estructurada (`valid_from/to`), y `inverse_relation_type` tampoco existe. El puente es **transitorio e insuficiente para el modelo definitivo**: sirve para conservar la afirmación clínica con trazabilidad mientras se aprueba la migración, pero no sustituye los tipos `clinical` en `os_relation_type`, la inversión declarada ni la vigencia gobernada. No debe publicarse como modelo final ni generalizarse sin aprobación.

---

## 4. Cardinalidad y direccionalidad

| Regla | Contenido |
|---|---|
| Sentido | `source_item_id → target_item_id`. La API informa `outgoing`/`incoming`, pero eso no cambia el sentido de la afirmación (`CatalogRepository.php:3069,3078-3082`). |
| PR ↔ DX | Muchos a muchos. Varios procedimientos pueden diagnosticar/evaluar/tratar un mismo DX; un procedimiento puede referirse a varios DX. **No hay equivalencia PR↔DX.** |
| Simétricas | La simetría se declara con una **segunda fila explícita** y contexto equivalente (`REL-DX-COEX` es el caso canónico). No se genera por espejo automático. |
| Jerárquicas | Direccionales: `REL-PR-PART` (parte → todo), `REL-DX-NARROW` (específico → amplio), `REL-DX-BROAD` (amplio → específico). Solo `NARROW`/`BROAD` tienen inversa semánticamente equivalente. |
| Asociativas | No equivalentes: `REL-PR-REL`, `REL-DX-REL`, `REL-DX-ASSOC`, `REL-PR-COMP`, `REL-PR-COMB`, `REL-PR-ALT`, `REL-PR-REQR`, `REL-PR-SEQ`, `REL-DX-DIFF`, `REL-DX-MANIF`, `REL-DX-COMPL`, `REL-DX-ETIOL`, `REL-PRDX-*`. No implican `equivalent` ni sustitibilidad. |
| Espejos en API | `dedupeRelations()` colapsa espejos por `sistema|código|tipo` y prioriza `outgoing` (`CatalogRepository.php:3124-3164`). Ese comportamiento es de presentación: **no autoriza a crear la fila inversa por defecto**. |
| No propagación | Una agrupación anatómica no genera relaciones con todas sus estructuras hijas; la multi-estructura exige soporte clínico explícito (rector §6 y §15.3). |

---

## 5. Campos obligatorios y opcionales por clase

**[P]** En todas las clases: `provenance` es obligatoria, `review_status` usa solo los cuatro valores reales del esquema y `source_value` respeta `VARCHAR(20)`. `source_field='notes'` y `relation_type='referencia_literal'` son del puente; en el destino el tipo se resuelve por `relation_type_code` con `relation_kind='clinical'`.

| Clase | Obligatorios además de los comunes | Opcionales / condicionales | Contexto y lateralidad | Vigencia |
|---|---|---|---|---|
| **A · PR-PR** | `context_text` con ancla técnica/clínica; justificación de combinación, secuencia o dependencia según el caso. | `mapping_method`, `confidence_level`, `license_reference` si Fase 3 existe y la fuente los declara. | Condiciones y exclusiones en `context_text` / `clinical_rationale`; lateralidad solo `ATTR-LATERALITY` = `OD`, `OI`, `AO`, `NA` (o `no_especificado` como decisión de gobernanza, nunca inventada). | `valid_from/to` solo con Fase 3 aplicada y fecha declarada por la fuente. |
| **B · DX-DX** | `context_text` con criterio de diferenciación, especificidad, manifestación, complicación, etiología o coexistencia; `source_reference` para la edición CIE implicada. | `inverse_relation_type` / `inverse_code` solo para `NARROW`↔`BROAD`. | `H36.8*` se navega con `AREA-SIST`; la relación etiológica o de manifestación requiere evidencia explícita, no se infiere del área. | Igual que A; si la fuente no declara vigencia, se registra como desconocida. |
| **C · PR-DX** | `context_text` y `clinical_rationale`/`source_reference` que expliquen qué DX justifica, evalúa o contraindica al PR. | `confidence_level`, `reviewed_by/at` si Fase 3 existe. | Condiciones, sesiones y alcance en texto gobernado; nunca `equivalent` en `os_concept_mapping`. | Igual que A. |
| **D · ANAT** | `context_text` con soporte clínico de la estructura o área; `source_reference` para la jerarquía anatómica gobernada. | Atributos `ATTR-STRUCTURE` y `ATTR-LATERALITY` cuando la fuente los declara. | `OD`/`OI`/`AO`/`NA` o `no_especificado` gobernanza; multi-estructura solo con evidencia. | Solo si la fuente declara vigencia y Fase 3 existe. |
| **E · FUNC** | `context_text` y `clinical_rationale` con la medida/evidencia funcional. | `confidence_level` si Fase 3 existe. | Motilidad y visión binocular bajo `AREA-ESTRAB`; no usar `ANAT-NEU`/`ANAT-MOT` como área funcional. | Solo si la fuente declara vigencia y Fase 3 existe. |

**[P] Convención de lateralidad:** `OD`, `OI`, `AO`, `NA` son los valores estables de `ATTR-LATERALITY`; `no_especificado` es una decisión de gobernanza documentada, no un valor clínico inferido. La lateralidad **nunca** se codifica dentro de `source_value` ni se usa para duplicar el ítem OFTAR.

---

## 6. Gobernanza

**[H]** Cuestiones distintas que no deben confundirse (rector §9.1-9.2): propuesta automática, revisión documental, revisión clínica y aprobación son **cuatro momentos diferentes**. `os_review_state` es vocabulario de gobernanza, no un `CHECK` leído por la API (`fase1_infraestructura.sql:85-102`).

| Momento | Qué es | Estado persistible que corresponde |
|---|---|---|
| Propuesta automática | Candidato generado por similitud o importación. No es verdad clínica. | `review_status='draft'`; solo worklist, nunca publicación. |
| Revisión documental | Contraste con fuente, edición, fila, hash y texto original. | `review_status='reviewed'` cuando la comprobación quedó registrada; no equivale a aprobación. |
| Revisión clínica | Ratificación humana del ancla, dirección, condiciones y ausencia de equivalencia indebida. | Dos revisiones humanas distintas con `source_reference`, `content_hash` vigente y `reviewed_by/at` si Fase 3 existe. |
| Aprobación | Decisión gobernada final. | `review_status='approved'`; habilita publicación junto con el resto de condiciones. |

**[P] Rechazo:** `rejected` y `pending_review` **no existen** en `os_catalog_relation.review_status`. Un rechazo es una **decisión de gobernanza**, no un valor de columna: se documenta en la solicitud/revisión/decisión y en `os_audit_log`, y la fila conserva `draft`, `approved` o `deprecated` según corresponda. **No se borra historial**; no se inserta un valor nuevo sin migración aprobada.

**[P] Publicación:** exige `review_status='approved'`, evidencia trazable (`provenance` y `source_reference`), `content_hash` vigente, dos revisores distintos, release publicado y ítem activo (rector §9.2, §15.6). Toda aprobación queda en `os_audit_log` **append-only** (`fase4_gobernanza.sql:120-147`); no se reescriben ni se eliminan filas de auditoría.

**[P] Cambio o retiro:** se crea una nueva versión gobernada o se marca `deprecated`; nunca se sobrescribe la versión publicada ni se reutiliza el identificador retirado. Los disparadores de invalidación pueden devolver `draft` cuando cambia el contenido (rector §9.2, paso 6).

---

## 7. Ejemplos concretos — propuestas documentales, no publicadas

1. **`306002` ↔ `460105` (RFG bilateral).** El par NN `306002` y CAO `460105` aparece como propuesta de correspondencia en `docs/audit/aprobacion-conciliacion-oftar-pr.md:34` y `docs/audit/cobertura-oftar-pr.md:88`. `[H]` la matriz de conciliación registra 38 propuestas «exactas» como **etiqueta documental**, todas `propuesta_no_publicada` (rector §8); `[H]` subsiste la duda sobre el texto «con fluoresceína» frente a «no incluye fluoresceína» (`cuestiones-pendientes-oftar.md:17`). `[P]` No está aprobada, no se ha publicado y no debe registrarse como `equivalent` en `os_concept_mapping`: ambas son prestaciones internas de OFTAR-PR. Si se ratifica como relación clínica, se documentaría con un tipo de la clase A (p. ej. `REL-PR-REL`) en `review_status='draft'` hasta aprobación; la apariencia de «exactitud» no autoriza la equivalencia persistida.

2. **`H36.8*` con `AREA-SIST`.** `[H]` son 9 códigos finales dentro de H00-H59 y se navegan adicionalmente con el área clínica `AREA-SIST`, sin duplicar el diagnóstico (rector §3; `universo-diagnosticos-oftar-dx.md:70-74`). `[P]` `AREA-SIST` es navegación aditiva, **no** una relación automática ni un código nuevo. Solo con evidencia y aprobación cabría una `REL-DX-MANIF` o `REL-DX-ETIOL` hacia la entidad sistémica correspondiente; E11.\* permanece como referencia externa candidata, no importada masivamente. La vigencia no se inventa: se registra solo si la fuente la declara y Fase 3 existe.

---

## 8. Cierre y pendientes

- Ratificación clínica de los 31 códigos canónicos y de sus etiquetas es-AR (`diccionario-tipos-relacion-oftar.md`). El encargo menciona «~36»; la lista obligatoria enumerada contiene **31** (7+9+9+5+1). No se inventan códigos adicionales para completar el número aproximado.
- Aprobación explícita de la migración aditiva `relation_type_code VARCHAR(60) NULL` con FK a `os_relation_type`; hasta entonces, solo el puente `referencia_literal`/`OFTAR-CLINICAL`/`notes`, documentado como transitorio.
- Verificación, en el entorno que se autorice, de si Fase 3 está aplicada, antes de usar `relation_kind`, `valid_from/to` o `inverse_relation_type`. **Aquí no se verificó ni consultó el estado de la base.**
- Decisión gobernada sobre simetrías explícitas y sobre el único par con inversa semántica (`NARROW`/`BROAD`).
- Carga gobernada de `ANAT-*`, `AREA-*` y `ATTR-LATERALITY`, hoy no sembrados en SQL según el rector §6.
- Cierre del riesgo P-07 (texto de fluoresceína) antes de cualquier uso del par `306002`/`460105`.
- Ninguna de estas tareas autoriza seeds, migraciones, importaciones ni publicación. La autorización debe ser explícita y posterior, conforme al rector §14 y §17.10.
