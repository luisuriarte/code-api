# Política de sistemas e identificación externa de OFTAR

**Fecha:** 2026-11-28  
**Estado:** propuesta para aprobación. **No implementada.**  
**Objetivo:** conservar sistema, edición, versión, release, procedencia e idioma de cada fuente sin crear un motor paralelo ni inventar códigos o traducciones.

---

## 1. Problema resuelto

**[H]** Hoy `oftar_external_identity` usa `system_code`, `code_raw`, `code_normalized`, `owner_catalog` y `entity_kind`, con unicidad por `(system_code, code_normalized)` (`oftar_external_identity.sql:59-76`).

**[H]** `os_catalog_identifier` registra `system_name/value/is_primary` (`origen_catalog_engine.sql:92-99`) y `os_concept_mapping` ya tiene `provenance`, `source_reference`, `content_hash`, `valid_from/valid_to` tras la Fase 3.

**[I]** Esa estructura es suficiente para la identidad básica, pero no distingue de forma explícita edición, versión y release. Por eso `CIE-10-ES 2026` e `ICD-10-CM 2027` pueden quedar indistintos si ambos se guardan como `CIE-10`.

---

## 2. Campos obligatorios de identidad externa

| Campo | Significado | Aplicación mínima sin DDL |
|---|---|---|
| `system_code` / `system_name` | Sistema terminológico | `CIE-10-ES`, `ICD-10-CM`, `NOMENCLADOR-AR`, `SNOMED-CT`, `ICD-10-PCS` |
| `edition` | Edición nacional/internacional | `ES`, `CM`, `AR` cuando corresponda |
| `version` | Año/versión mayor | `2026`, `2027`, `2025` |
| `release` | Paquete concreto | nombre del CSV/ZIP o fecha del refset |
| `provenance` | Procedencia institucional y de archivo | Ministerio de Sanidad, CDC/NCHS-CMS, CAO, Regional, SNOMED Argentina Edition |
| `language` | Idioma del display | `es`, `es-AR`, `en`, `undet` para textos de mapeo |
| `source_reference` | Referencia verificable dentro del paquete | número de línea, orden, refset, archivo |
| `content_hash` | Integridad del texto/mapeo | ya disponible en gobernanza |

**[P]** Mientras no se amplíe el esquema, la edición/versión/release deben conservarse de forma consistente en `source_reference`/`provenance` y en el `release` de `os_catalog_release`. La ampliación estructural se propone, pero requiere aprobación y migración.

---

## 3. Valores por sistema

### 3.1 CIE-10-ES 2026

- `system_code`: `CIE-10-ES` (o `CIE-10` con subtipo obligatorio `ES`).
- `edition`: `CIE-10-ES`.
- `version`: `2026`.
- `release`: `Diagnosticos_Tabla_Referencia_CIE10ES_2026`.
- `provenance`: Ministerio de Sanidad España / CSV local verificado.
- `language`: `es`, proyectado como `es-AR` en el portal.
- Rol: **núcleo de OFTAR-DX para Argentina**.

### 3.2 ICD-10-CM 2027

- `system_code`: `ICD-10-CM`.
- `edition`: `ICD-10-CM`.
- `version`: `2027`.
- `release`: `2027-code-descriptions-in-tabular-order.zip`.
- `provenance`: CDC/NCHS-CMS tabular order según el paquete local.
- `language`: `en`.
- Rol: **referencia externa separada**; los 17 códigos exclusivos no se incorporan automáticamente al núcleo CIE-10-ES.

### 3.3 CIE-10 de referencia para Argentina

**[I]** Debe tratarse como la familia de codificación diagnóstica usada por el motor, pero siempre con la edición concreta declarada. “CIE-10” solo no es suficiente para gobernanza.

### 3.4 SNOMED CT Argentina Edition

- `system_code`: `SNOMED-CT`.
- `edition`: `Argentina Edition`.
- `version/release`: `20260820` y `effectiveTime` del RF2.
- `provenance`: refset oficial `der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt`.
- `language`: según descripción RF2; los textos de mapeo se sirven con revisión aprobada.
- Rol: mapa semántico complementario; no núcleo de códigos OFTAR.

### 3.5 CIE-10-PCS

- `system_code`: `ICD-10-PCS`.
- `version`: `2026` para el CSV local de procedimientos; `2027` para el ZIP complementario si se usa.
- Rol: referencia de procedimientos para OFTAR-PR; no genera diagnósticos ni códigos OFTAR nuevos.

### 3.6 Nomencladores argentinos

- `NOMENCLADOR-AR`: NN 2025, dueño `oftar-pr`.
- `CAO`: fuente de origen inmutable, 143 códigos.
- `REGIONAL-NOA`: fuente de origen inmutable, 136 códigos.

**[P]** La numeración y las descripciones originales se conservan siempre. Los códigos permanentes `OFT-PR-`/`OFT-DX-` son la capa canónica, no una sustitución de la identidad externa.

---

## 4. Reglas de no invención

1. No crear códigos CIE-10-ES a partir de códigos ICD-10-CM exclusivos.
2. No traducir automáticamente los 17 códigos exclusivos al español.
3. No asignar SNOMED CT por similitud textual.
4. No usar CIE-10-PCS como diagnóstico.
5. No reutilizar prefijos OFTAR retirados.
6. No borrar ni renombrar identificadores históricos; las correcciones se hacen con nuevas versiones/revisiones.
7. No publicar mapeos sin `review_status='approved'`, evidencia y revisión humana.

---

## 5. Compatibilidad con el modelo actual

| Necesidad | Modelo existente | Cambio propuesto |
|---|---|---|
| Guardar sistema y código | `os_catalog_identifier`, `oftar_external_identity` | Conservar |
| Guardar procedencia y fecha | `provenance`, `source_reference`, `content_hash` | Conservar y hacer obligatorios por sistema |
| Separar edición/versión/release | parcial en `source_reference` | Agregar metadatos estructurados al sistema/release o a identidad versionada |
| Publicar solo con revisión | `os_field_review`, `os_concept_mapping.review_status` | Conservar |
| Evitar motor paralelo | `os_catalog` y extensiones | No crear tablas de catálogo paralelas |

**[P]** La extensión mínima recomendable es un conjunto de metadatos de edición/versión/release asociado al sistema o al release, no una tabla nueva de concepts duplicados. Debe aprobarse antes de cualquier migración.

---

## 6. Cierre

**[I]** La política actual es correcta al no traducir huecos idiomáticos, pero insuficiente al agrupar ediciones bajo un mismo `system_code`. La corrección debe ser gobernada y trazable.

**[P]** Los 17 códigos exclusivos quedan formalmente identificados como ICD-10-CM 2027; CIE-10-ES 2026 se mantiene como núcleo argentino; SNOMED CT Argentina Edition se incorpora solo como referencia semántica revisada.
