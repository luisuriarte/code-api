# Reglas de gobernanza del modelo transversal de relaciones

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** reglas propuestas. (No aprueba relaciones ni correspondencias.)

---

## 1. Estados reales por objeto

| Objeto | Campo | Valores verificados | Regla |
|---|---|---|---|
| Versión del concepto | `os_catalog_item_version.review_status` | `unknown` por defecto, sin CHECK; scripts OFTAR asignan `approved` | La vista de búsqueda OFTAR exige `approved`. |
| Relación clínica | `os_catalog_relation.review_status` | `draft|reviewed|approved|deprecated` (`nomenclador_odontologico_nacional.sql:551-552`) | Solo `approved` en público. |
| Correspondencia | `os_concept_mapping.review_status` | `draft|reviewed|approved|deprecated` (`origen_catalog_engine.sql:130`) | `approved` más revisión de campo vigente. |
| Metadatos de correspondencia | `os_mapping_metadata.review_status` | `[H]` FK a `os_review_state`, default `unknown` (`fase3_relaciones_mapeos.sql:132-133`) | `unknown` no autoriza publicación. |
| Campo / traducción | `os_field_review`, `os_localized_text` | `unknown` por defecto, sin CHECK | Solo `approved` con hash vigente. |
| Release | `os_catalog_release.status` | `draft|review|published|deprecated` (`origen_catalog_engine.sql:49`) | La visibilidad depende también del perfil. |

**[H]** `os_review_state` define diez estados de gobernanza, con `approved` y `published` como únicos que permiten publicación por defecto (`fase1_infraestructura.sql:85-102`). **[P]** No se usan `pending_review` ni `rejected` como valores persistentes de los CHECK citados.

---

## 2. Flujo de aprobación

1. **Propuesta:** fila `draft`, con fuente, edición, contexto y evidencia. Sin aprobación automática.
2. **Validación técnica:** catálogos activos, tipo válido, dirección permitida, vigencia coherente, `UNIQUE` respetado, licencia declarada.
3. **Revisión clínica:** requerida para toda relación clínica y para equivalencias terminológicas; dos revisiones humanas distintas para equivalencia exacta.
4. **Revisión de campo:** `external_display` y `clinical_rationale` requieren `content_hash` vigente.
5. **Aprobación:** `review_status='approved'`; responsable y fecha en `reviewed_by`/`reviewed_at`, con traza en `os_audit_log`.
6. **Publicación:** solo en la sección correspondiente y con perfil de dominio habilitado.
7. **Deprecación:** nueva vigencia o nueva fila; nunca borrado silencioso.

---

## 3. Responsables por perfil

| Perfil | Responsable propuesto | Decisiones reservadas |
|---|---|---|
| DENTAR-PR/DX | Comité Odontológico + responsable de terminología | Equivalencias CDT/NN/institucionales; alcance de SNOMED; publicación AN/CL. |
| OFTAR-PR/DX | Comité Oftalmológico + responsable de taxonomía | 13 pares, 6 correcciones, 3 candidatos, RFG, dirección `broader`/`narrower`. |
| Arquitectura/DBA | Responsable de motor | Migración `relation_type_code`, FKs, backup y acta `READ ONLY`. |
| API/portal | Responsable de producto | Contrato `data.relations` y separación visual. |
| Gobernanza transversal | Responsable de catálogos | Perfiles de dominio, licencias, reglas de publicación. |

**[P]** La firma documental de conciliación no sustituye a la aprobación clínica ni aprueba relaciones. Las aprobaciones son específicas por objeto y por revisión.

**[H]** `CatalogGovernanceService` fija `review_status='approved'` al construir una relación gobernada y exige `target_item_id`, `relation_type`, `source_field`, `source_value` y `provenance` (`portal/Admin/CatalogGovernanceService.php:452-495`). **[P]** Ese `approved` es **técnico-administrativo**: no sustituye a la firma clínica ni habilita por sí solo la publicación de una relación clínica o de una equivalencia terminológica.

---

## 4. Prohibiciones

- No importar automáticamente códigos de nomencladores como equivalentes.
- No aprobar por coincidencia textual ni por `RelatedCodesResolver` (`equivalent` allí es etiqueta técnica, no aprobación OFTAR).
- No publicar relaciones `draft`/`deprecated`, sin correspondencia o pendientes en la consulta pública.
- No mezclar Clínica y Terminológica en una misma clase de respuesta.
- No usar una relación clínica como mapeo de nomenclador, ni un mapeo como justificación clínica.
- No alterar identificadores existentes ni reescribir códigos con separadores.
- No ejecutar `DELETE`, `DROP`, `TRUNCATE`, migraciones ni seeds sin autorización explícita.

---

## 5. Licencias y fuentes

**[P]** CDT, SNOMED CT, CIE-10 y nomencladores institucionales conservan organismos, ediciones y condiciones de uso. `source_reference`, `provenance` y `license_reference` son obligatorios cuando corresponda. La ausencia de licencia verificada bloquea la publicación; se documenta como `unknown`, nunca como `approved`.

---

## 6. Cambios gobernados

**[P]** Toda modificación de una relación o mapeo aprobado pasa por nueva propuesta con vigencia. El valor anterior permanece en el historial. No se reutiliza un `relation_type` heredado para un tipo clínico sin acta que lo autorice.

---

## 7. Puertas de cierre

| Puerta | Evidencia mínima |
|---|---|
| Arquitectura | Acta `READ ONLY` y verificación de FKs/CHECK vigentes. |
| Dominio | Perfil aprobado con tipos y sistemas pertinentes. |
| Clínica | Firma de pares y correcciones; 0 equivalencias automáticas. |
| Terminología | Edición/licencia verificadas; 0 aprobaciones por texto. |
| Técnica | Tests en verde; `mappings`/`related_codes` intactos; sin huérfanos. |
| Publicación | Revisión de campo vigente y superficie separada. |

**[P]** Estas puertas son documentales. No se han ejecutado ni se ejecutan en esta tarea.
