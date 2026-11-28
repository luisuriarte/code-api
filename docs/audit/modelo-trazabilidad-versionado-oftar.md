# Modelo de trazabilidad y versionado de OFTAR

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** OFTAR v1.0 — Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada. (No autoriza ejecución.)
**Convención:** `[H]` hecho verificado en repositorio · `[I]` inferencia · `[P]` propuesta no implementada.

**[P]** Perfil OFTAR de las reglas comunes de versionado y trazabilidad (`docs/architecture/relaciones/07-reglas-versionado-relaciones.md`).

---

## 0. Método y límite

**[H]** Este documento se elaboró **solo por lectura** de SQL y PHP versionados. No se ejecutaron consultas contra PostgreSQL, seeds, migraciones, importadores, aprobaciones ni pruebas. Toda afirmación sobre datos es una afirmación sobre **código desplegable**, no sobre estado runtime.

**[H]** Ante contradicción, prevalece el documento rector `especificacion-definitiva-reconstruccion-oftar.md` v1.0 (§0, §9, §11, §12) y lo efectivamente verificado en el repositorio.

---

## 1. Base verificada

### 1.1 Núcleo canónico (`sql/02_catalogs/origen_catalog_engine.sql:42-98`)

**[H]** `os_catalog_release` (`:42-52`): `version_tag`, `valid_from`, `valid_to`, `official_norm_reference`, `status VARCHAR(20) NOT NULL DEFAULT 'published' CHECK (status IN ('draft','review','published','deprecated'))` y `UNIQUE (catalog_id, version_tag)`.

**[H]** `os_catalog_item` (`:63-70`): `permanent_code`, `status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','retired','superseded'))` y `UNIQUE (catalog_id, permanent_code)`.

**[H]** `os_catalog_item_version` (`:72-82`): `item_id`, `release_id`, `category_id`, `preferred_term`, `definition`, `clinical_criteria`, `language_code VARCHAR(10) NOT NULL DEFAULT 'es-AR'` y `UNIQUE (item_id, release_id, language_code)`.

**[H]** `os_catalog_identifier` (`:92-99`): `item_id`, `system_name`, `value`, `is_primary` y `UNIQUE (item_id, system_name, value)`.

**[H]** `os_concept_mapping` (`:119-136`): `mapping_type CHECK (equivalent|narrower|broader|related|unmatched)`, `relationship_role CHECK (procedure_concept|justifying_diagnosis|observation_concept|substance_concept)`, `review_status VARCHAR(20) NOT NULL DEFAULT 'approved' CHECK (review_status IN ('draft','reviewed','approved','deprecated'))` y `UNIQUE (item_id, terminology_system_id, external_code, relationship_role)`.

### 1.2 Texto y revisión por campo (`sql/07_multilingue/01_fase2_tablas.sql:55-137`)

**[H]** `os_localized_text` (`:55-81`) tiene `entity_type`, `entity_id`, `field_name`, `language_code`, `value`, `source_language_code`, `language_evidence`, `provenance`, `review_status VARCHAR(20) NOT NULL DEFAULT 'unknown'` **sin CHECK**, `source_reference`, `translator`, `reviewed_by`, `reviewed_at`, `scope_release_id` con `ON DELETE RESTRICT`, `valid_from`, `valid_to` y `content_hash TEXT NOT NULL`.

**[H]** `os_field_review` (`:122-137`) tiene `target_table`, `target_id`, `field_name`, `language_code`, `scope_release_id` con `ON DELETE RESTRICT`, `source_language_code`, `language_evidence`, `provenance`, `review_status VARCHAR(20) NOT NULL DEFAULT 'unknown'` **sin CHECK**, `source_reference`, `reviewed_by`, `reviewed_at` y `content_hash TEXT NOT NULL`.

**[H]** `os_catalog_item_version.review_status` se agregó con `NOT NULL DEFAULT 'unknown'` y **sin CHECK** en `sql/07_multilingue/04_fase3_columnas.sql:24-37`. Los scripts OFTAR sí asignan `approved` explícitamente, por ejemplo `sql/03_oftar/aprobar_preferred_term_oftar_dx.sql:105-112`; esa aprobación es por campo y no habilita automáticamente `definition` (`:106-107`).

### 1.3 Gobernanza y auditoría (`sql/08_arquitectura/fase4_gobernanza.sql:26-147,205-283`)

**[H]** `os_governance_request` (`:58-73`) conserva `source_reference`, `license_reference`, `requested_by`, `requested_by_user_id` y `review_status` con default `'draft'` referido a `os_review_state`. `os_governance_review` (`:81-91`) registra revisor, rol, `outcome` y `rationale`. `os_governance_decision` (`:96-106`) exige `evidence_reference NOT NULL` y `effective_from`.

**[H]** `os_audit_log` (`:120-131`) guarda `entity_type`, `entity_id`, `action`, `actor`, `actor_user_id`, `request_id`, `before_state`, `after_state` y `occurred_at`. El trigger `trg_os_audit_log_immutable` (`:136-147`) ejecuta `os_governance_audit_immutable()` antes de `UPDATE` o `DELETE` y lanza `public.os_audit_log es append-only`: **no se puede reescribir ni borrar la traza**.

**[H]** Los triggers de request/review/decision insertan en `os_audit_log` en `INSERT`, `UPDATE` y `DELETE` (`:152-227`); el actor se toma de `app.actor_id` si la aplicación lo informa (`:192-203`). Las comprobaciones finales son de solo lectura (`:253-283`).

**[H]** Con precisión de archivo: `os_catalog_apply_governed_change` **no está definido en `fase4_gobernanza.sql`**; se define en `sql/08_arquitectura/catalogos_gestion_gobernada.sql:48-311` (`CREATE OR REPLACE FUNCTION` en `:48-56`). Es `SECURITY DEFINER`, exige estado publicable en `os_review_state` (`:85-92`), **dos revisiones aprobadas por actores distintos** (`:94-102`) y decisión con `evidence_reference` no vacía (`:104-113`). El comentario y los permisos están en `:276-287`.

### 1.4 Relaciones, mapeos y vocabularios

**[H]** `sql/08_arquitectura/fase3_relaciones_mapeos.sql:53-147` agrega a `os_catalog_relation` las columnas `valid_from`, `valid_to`, `source_catalog_id`, `source_release_id`, `target_catalog_id`, `target_release_id`, `relation_kind NOT NULL DEFAULT 'unclassified'`, `mapping_method`, `confidence_level`, `reviewed_by`, `reviewed_at`, `license_reference` e `inverse_relation_type` (`:60-73`), con FK, `ck_ocr_validity` (`:75-105`) e índices (`:107-108`). Las filas previas conservan `NULL` y `unclassified`; no se inventa clasificación editorial (`:56-59`, `:110-113`).

**[H]** El mismo archivo crea `os_mapping_metadata` (`:118-141`) con `mapping_id`, `source_system_id`, `target_system_id`, `source_version`, `target_version`, `mapping_type_ext`, `mapping_nature CHECK (univocal|multiple|partial|approximate|not_mappable)`, `method`, `confidence_level`, `source_reference`, `license_reference`, `review_status NOT NULL DEFAULT 'unknown'` referido a `os_review_state`, `reviewed_by`, `reviewed_at`, `valid_from`, `valid_to` y `created_at`. La visibilidad depende de `review_status`, no de `provenance` (`:146-147`).

**[H]** La tabla base `os_catalog_relation` está en `sql/03_dentar/nomenclador_odontologico_nacional.sql:534-559`: `source_item_id`, `target_item_id`, `relation_type` con CHECK de 15 tipos CDT, `source_system_code`, `source_field`, `source_value`, `context_text`, `review_status CHECK (draft|reviewed|approved|deprecated)`, `provenance`, `created_at`, restricción de no autorrelación y UNIQUE compuesta (`:555-558`).

**[H]** `os_relation_kind` incluye `unclassified`, `structural`, `clinical`, `editorial`, `billing`, `regulatory` y `mapping` (`sql/08_arquitectura/fase1_infraestructura.sql:42-56`); `os_relation_type` tiene `code`, `relation_kind`, `source`, `inverse_code` e `is_active` (`:60-68`).

**[H]** `os_review_state` enumera `unknown`, `unreviewed`, `draft`, `in_review`, `reviewed`, `approved`, `published`, `retired`, `obsolete`, `deprecated`, con `is_publication_allowed=TRUE` solo para `approved` y `published` (`fase1_infraestructura.sql:85-102`). **Es vocabulario de gobernanza: no es un CHECK de las columnas anteriores ni es leído por la API.**

---

## 2. Tabla campo → destino real → soporte → obligatoriedad

La columna «Obligatoriedad» es la regla `[P]` propuesta para toda fila publicable; no declara una restricción `NOT NULL` nueva salvo donde el SQL ya la tiene.

| Campo de trazabilidad | Destino real | Soporte verificado | Obligatoriedad propuesta |
|---|---|---|---|
| Identificador propio OFTAR | `os_catalog_item.permanent_code` | `origen_catalog_engine.sql:63-70`; prefijos `OFT-PR-`/`OFT-DX-` en el rector §1 | **Obligatorio**; inmutable entre ediciones |
| Catálogo y familia | `os_catalog.code`, `os_catalog.family_code`, `product_role` | `origen_catalog_engine.sql:12-40`; rector §1 | **Obligatorio** para resolver el ítem |
| Sistema externo | `os_terminology_system.code/uri/default_version` o `os_catalog_identifier.system_name` | `origen_catalog_engine.sql:92-99,111-117` | **Obligatorio**; prohibido `CIE-10` sin subtipo cuando haya dos ediciones |
| Edición externa | Sin columna nativa: se conserva en el subtipo del sistema, `os_catalog_release.version_tag`, `source_version`/`target_version` o texto de procedencia | `origen_catalog_engine.sql:42-52`; `fase3_relaciones_mapeos.sql:118-141`; rector §4 | **Obligatoria como dato**, con soporte hoy **parcial/convencional**; estructuración pendiente (§4) |
| Versión del sistema | `os_terminology_system.default_version`, `os_mapping_metadata.source_version/target_version` | `origen_catalog_engine.sql:111-117`; `fase3_relaciones_mapeos.sql:122-123` | **Obligatoria cuando exista**; si no, declarar `desconocida` |
| Release / fecha de publicación | `os_catalog_release.version_tag`, `valid_from`, `valid_to`, `status` | `origen_catalog_engine.sql:42-52` | **Obligatoria** (`published` para consulta pública) |
| Código original | `os_catalog_identifier.value` o `os_concept_mapping.external_code` | `origen_catalog_engine.sql:92-99,119-136` | **Obligatorio**; nunca sustituido por el permanente |
| Descripción original | `os_concept_mapping.external_display`, `os_catalog_item_version.preferred_term`, `os_localized_text.value` | `origen_catalog_engine.sql:72-90,119-136`; `01_fase2_tablas.sql:55-81` | **Obligatoria**; publicación sujeta a revisión aprobada |
| Idioma y idioma de origen | `language_code`, `source_language_code`, `language_evidence` | `origen_catalog_engine.sql:72-90`; `01_fase2_tablas.sql:65,67-68,126-129`; `04_fase3_columnas.sql:24-25` | **Obligatorios**; `es-AR` principal y obligatorio en publicación |
| Procedencia | `provenance` en versión, mapeo, relación y revisión de campo | `04_fase3_columnas.sql:26`; `origen_catalog_engine.sql:129-131,553`; `fase3_relaciones_mapeos.sql:130-135`; `01_fase2_tablas.sql:69,130` | **Obligatoria**; no equivale a aprobación |
| Referencia de fuente | `source_reference` | `01_fase2_tablas.sql:71,132`; `fase3_relaciones_mapeos.sql:130`; `fase4_gobernanza.sql:64`; rector §12 | **Obligatoria** con archivo/fila o acta identificable |
| Hash de contenido | `content_hash` | `01_fase2_tablas.sql:78,135`; `04_fase3_columnas.sql:31` | **Obligatorio** donde la tabla lo exige; cambio de contenido invalida aprobación |
| Vigencia | `valid_from`, `valid_to` | `origen_catalog_engine.sql:46-47`; `fase3_relaciones_mapeos.sql:61-62,136-140`; `01_fase2_tablas.sql:76-77` | **Obligatoria cuando se conozca**; si no, `desconocida`, nunca `CURRENT_DATE` inventado |
| Estado de revisión | Ver §3: distinto por objeto | `origen_catalog_engine.sql:49,67,130`; `01_fase2_tablas.sql:70,131`; `fase3_relaciones_mapeos.sql:132` | **Obligatorio**; solo los valores reales de cada objeto |
| Responsable y fechas | `reviewed_by`, `reviewed_at`, `requested_by_user_id`, `reviewer_user_id`, `approved_by_user_id`, `occurred_at` | `fase3_relaciones_mapeos.sql:70-71,134-135`; `fase4_gobernanza.sql:67,85,101,130` | **Obligatorios** para aprobación/publicación |
| Relación clínica | `os_catalog_relation` | `nomenclador_odontologico_nacional.sql:534-559`; `fase3_relaciones_mapeos.sql:60-113` | **Obligatoria** para toda vinculación PR↔PR, DX↔DX, PR↔DX, anatomía/función o contexto |
| Correspondencia terminológica | `os_concept_mapping` + `os_mapping_metadata` | `origen_catalog_engine.sql:119-136`; `fase3_relaciones_mapeos.sql:118-147` | **Obligatoria**; nunca en `os_catalog_relation` |
| Clase de relación | `os_catalog_relation.relation_kind` / `os_relation_kind` | `fase3_relaciones_mapeos.sql:67,99,112`; `fase1_infraestructura.sql:42-56` | **Obligatoria**; valor actual por defecto `unclassified` hasta revisión |
| Tipo de relación OFTAR | Puente transitorio en `relation_type='referencia_literal'`, `source_system_code='OFTAR-CLINICAL'`, `source_field='notes'`, `source_value` + `context_text` | `nomenclador_odontologico_nacional.sql:538-553`; rector §7.2 | **Obligatorio con evidencia**; migración definitiva pendiente (§4) |
| Alcance / lateralidad / contexto | `context_text`, atributos `ATTR-STRUCTURE`, `ATTR-MODALITY`, `ATTR-LATERALITY` como códigos | `nomenclador_odontologico_nacional.sql:549`; rector §6 y §7.2 | **Obligatorios cuando apliquen**; `ATTR-*` son códigos, no columnas |
| Decisión y evidencia | `os_governance_decision.evidence_reference`, `effective_from` | `fase4_gobernanza.sql:96-115`; `catalogos_gestion_gobernada.sql:94-113` | **Obligatorias** para publicar; sin aprobación implícita |
| Traza inmutable | `os_audit_log` | `fase4_gobernanza.sql:120-147,205-227` | **Obligatoria**; append-only por trigger |

**[I]** La única brecha estructural relevante para esta tabla es la edición externa y el tipo de relación OFTAR nativo. Hoy se resuelven por convención gobernada y campos de texto/metadatos existentes; no hace falta un motor paralelo.

---

## 3. Reglas de sustitución sin borrar historial

**[P] R1 — Cambiar de edición no cambia la identidad OFTAR.** Al pasar de CIE-10-ES 2026 a ICD-10-CM 2027, o de NN 2025 a una edición posterior, `OFT-PR-NNNNNN`/`OFT-DX-NNNNNN` permanece. Se crea otra fila de identificador/versión/mapeo con su sistema, edición, vigencia y procedencia; no se sobrescribe la fila anterior.

**[P] R2 — Nueva versión, no sobrescritura.** Toda corrección publicable crea una nueva `os_catalog_item_version` dentro de un `os_catalog_release` (`origen_catalog_engine.sql:72-82`). La versión anterior conserva su `language_code`, `content_hash`, `reviewed_by` y `reviewed_at`. No se reutiliza un `permanent_code` retirado ni un `version_tag` deprecado.

**[P] R3 — Sustitución temporal por vigencia.** Para cerrar una vigencia se actualiza **solo** `valid_to` de la fila anterior y se inserta la nueva con `valid_from` posterior. El `CHECK` `valid_to > valid_from` ya existe en `fase3_relaciones_mapeos.sql:100-101,139-140`. No se hace `DELETE`, `TRUNCATE` ni `DROP`.

**[P] R4 — Relaciones y mapeos.**Una relación clínica o correspondencia terminológica reemplazada se marca `review_status='deprecated'` con `valid_to`, y se inserta una nueva fila con nueva evidencia. La UNIQUE compuesta de `os_catalog_relation` (`nomenclador_odontologico_nacional.sql:556-558`) y de `os_concept_mapping` (`origen_catalog_engine.sql:132`) se respeta; no se altera para forzar una sustitución.

**[P] R5 — Retiro de publicación.** `os_catalog_release.status='deprecated'` o `os_catalog_item.status='retired'/'superseded'` retira la visibilidad pública sin eliminar filas (`origen_catalog_engine.sql:49,67`). La búsqueda OFTAR sigue exigiendo versión `approved`, catálogo activo e ítem activo (rector §9.3).

**[P] R6 — Cambio de contenido.** Si cambia el texto, el `content_hash` deja de coincidir y la aprobación se invalida (`01_fase2_tablas.sql:78,135`; rector §9.2). Se crea una nueva revisión de campo; el texto aprobado anterior queda como historial. No se publica `null` como si fuera una traducción.

**[P] R7 — Rechazo.** `rejected` **no es valor de CHECK**. Un rechazo se documenta como decisión de gobernanza negativa con evidencia; la fila conserva su estado técnico real (`draft`, `unknown` o `deprecated`) y su traza en `os_audit_log`. No se inventa `pending_review` ni `rejected` en columnas persistentes.

**[P] R8 — Trazabilidad de la operación.** Toda apertura, publicación, sustitución o retiro pasa por `os_governance_request/review/decision` y queda en `os_audit_log`. El aplicador `os_catalog_apply_governed_change` exige dos revisores distintos y evidencia escrita (`catalogos_gestion_gobernada.sql:85-113`); es idempotente frente a una publicación ya auditada (`:76-83`).

**[P] R9 — Sin inversión automática.** Las relaciones direccionales registran inversa explícita solo si el significado es equivalente (`os_relation_type.inverse_code`, `fase1_infraestructura.sql:65`; rector §7.2). No se generan espejos automáticos que luego haya que borrar.

---

## 4. Migración aditiva pendiente (NO EJECUTADA)

**[P]** Propuesta para aprobación futura; **no está implementada, no se ejecutará en este documento y no autoriza DDL**. Requiere backup verificado, autorización explícita y revisión de gobernanza.

| Objetivo | DDL propuesto (texto de diseño, no ejecutado) | Compatibilidad |
|---|---|---|
| Edición estructurada de metadatos de mapeo | `ALTER TABLE os_mapping_metadata ADD COLUMN IF NOT EXISTS edition VARCHAR(60);` y, si se aprueba, columnas análogas de edición de origen/destino en la identidad externa | Columna nullable; ninguna fila existente se reescribe; se conservan `source_version`, `target_version`, `source_reference` y `provenance` |
| Tipo de relación OFTAR nativo | `ALTER TABLE os_catalog_relation ADD COLUMN IF NOT EXISTS relation_type_code VARCHAR(60) NULL REFERENCES os_relation_type(code) ON UPDATE CASCADE;` | `relation_type` y su CHECK de 15 tipos CDT permanecen intactos; las filas actuales quedan con `relation_type_code NULL` |
| Clasificación y vigencia | Ya soportadas por `relation_kind`, `valid_from` y `valid_to` (`fase3_relaciones_mapeos.sql:60-73`) | Sin cambios adicionales |

**[P]** El backfill de `relation_type_code` y `edition` sería una operación gobernada separada, con `os_governance_request/review/decision`, dos revisiones y traza en `os_audit_log`. Hasta entonces rige el puente transitorio `OFTAR-CLINICAL` documentado en el rector §7.2.

**[P]** No se propone ampliar el CHECK de `relation_type`, renombrar columnas, crear un motor paralelo ni introducir `domain_type='oftar'`.

---

## 5. Estados persistentes reales

| Objeto | Estado persistido | Default / CHECK | Fuente |
|---|---|---|---|
| Versión de concepto | `unknown` | `NOT NULL DEFAULT 'unknown'`, **sin CHECK**; scripts OFTAR asignan `approved` | `04_fase3_columnas.sql:24-37`; `aprobar_preferred_term_oftar_dx.sql:105-112` |
| Mapeo terminológico | `draft\|reviewed\|approved\|deprecated` | CHECK real; default original `approved`, `fase3_relaciones_mapeos.sql:183-184` lo cambia a `draft` sin tocar el CHECK | `origen_catalog_engine.sql:130`; `fase3_relaciones_mapeos.sql:27-30,183-184` |
| Relación clínica | `draft\|reviewed\|approved\|deprecated` | CHECK real; default `reviewed` en la tabla base | `nomenclador_odontologico_nacional.sql:551-552` |
| Campo / traducción | `unknown` | `NOT NULL DEFAULT 'unknown'`, **sin CHECK** en `os_localized_text` y `os_field_review` | `01_fase2_tablas.sql:70,131` |
| Release | `draft\|review\|published\|deprecated` | CHECK real; default `published` | `origen_catalog_engine.sql:49` |
| Ítem | `active\|retired\|superseded` | CHECK real; default `active` | `origen_catalog_engine.sql:67` |
| Gobernanza | `os_review_state` | Vocabulario con `approved`/`published` publicables; **no CHECK ni leído por API** | `fase1_infraestructura.sql:85-102` |

**[H]** `mapping_type` usa `equivalent\|narrower\|broader\|related\|unmatched` (`origen_catalog_engine.sql:125-126`). «Exacta» es etiqueta documental de matriz; el valor persistible es `equivalent` (rector §7.3). `unmatched` tampoco es un estado de revisión.

---

## 6. Cierre

**[P]** La trazabilidad OFTAR se apoya en lo ya versionado y en reglas de sustitución aditivas. La única ampliación estructural propuesta —`edition` y `relation_type_code`— queda pendiente de aprobación. Este documento **no autoriza ejecución**, no modifica PostgreSQL y no cambia contratos existentes.
