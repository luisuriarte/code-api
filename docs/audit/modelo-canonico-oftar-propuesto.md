# Modelo canónico OFTAR propuesto

**Fecha:** 2026-11-28  
**Estado:** propuesta para aprobación. **No implementada.**  
**Principio rector:** no crear un motor paralelo; usar `os_catalog` como fuente de verdad y mantener los modelos editoriales OFTAR como capa de dominio.

---

## 1. Dimensiones separadas

La distinción solicitada se conserva y se hace explícita en los contratos:

| Dimensión | Tabla / campo | Qué responde | Ejemplo OFTAR |
|---|---|---|---|
| Familia / marca | `oftar_catalog.family_code`, `os_catalog.family_code` | “¿de qué familia es?” | `oftar` |
| Catálogo de origen o producto | `os_catalog.code` | “de dónde viene el código / a qué producto pertenece?” | `oftar-pr`, `oftar-dx`, `nomenclador-oftalmologico-cao-ar` |
| Categoría fuente del capítulo | `os_catalog_category` + `os_catalog_item_version.category_id` | “qué capítulo del catálogo usa la fuente?” | `GRP-DIAG`, `CONSULT`, `CAT-DX` |
| **Categoría del concepto** | `os_clinical_category` + `os_catalog_item_clinical_category` | “qué tipo de concepto clínico es?” | `CLIN-DIAG`, `CLIN-PROC`, `CLIN-EST` |
| Ítem y versión | `os_catalog_item` + `os_catalog_item_version` | “qué código publicado y qué texto en qué release/idioma?” | `OFT-PR-000154`, `es-AR` |
| Identidad externa | `os_catalog_identifier`, `oftar_external_identity`, `os_concept_mapping` | “qué código usa cada sistema?” | `306002`, `H01.8` |
| Estado editorial | `os_field_review`, `os_translation_review`, `os_review_state` | “qué texto/mapeo puede publicarse?” | `unknown` → `approved` |
| Valoración | `os_fee_schedule`, `os_fee_item`, `os_pricing_unit` | “cuánto vale la prestación”, nunca del diagnóstico | UVR solo en PR |

**Regla:** `CLIN-*` **no** es catálogo, dominio ni capítulo fuente. Es una taxonomía aditiva y transversal. Un ítem puede pertenecer a `oftar-pr` y tener categoría clínica `CLIN-EST`; un ítem de `nomenclador-oftalmologico-cao-ar` conserva el default `CLIN-PREST`.

---

## 2. Estructura objetivo

```text
oftar (familia / marca)
├── oftar-pr                       prefijo OFT-PR-NNNNNN · concept_kind=procedure
│   ├── ítem canónico  → os_catalog_item / os_catalog_item_version
│   ├── capítulo fuente → os_catalog_category (CONSULT, EXAM, DIAG, IMG, TER, CIR, OCUL, LAGR…)
│   ├── categoría clínica → CLIN-PROC | CLIN-EST | CLIN-DIAG | CLIN-ANAT
│   ├── identificador oficial → NOMENCLADOR-AR:NNNNNN
│   └── valoración → UVR opcional, por prestación
├── oftar-dx                       prefijo OFT-DX-NNNNNN · concept_kind=diagnosis
│   ├── ítem canónico → os_catalog_item / os_catalog_item_version
│   ├── capítulo fuente → CAT-DX
│   ├── categoría clínica → CLIN-DIAG
│   ├── identificador oficial → CIE-10:H00-H59 normalizado
│   └── sin UVR
├── nomenclador-oftalmologico-cao-ar        espejo de origen, 143 códigos, sin precios
└── nomenclador-oftalmologico-regional-ar   espejo de origen, 136 códigos, sin precios
```

Los catálogos de origen **no se renombran ni se convierten en `oftar-pr`**. Sus códigos históricos se conservan. Las correspondencias con OFTAR-PR se publican como relaciones gobernadas, no como sustitución de identificadores.

---

## 3. Identidad y propiedad por sistema

`oftar_external_identity.sql:44-80` normaliza `upper(btrim())` sin puntos, espacios ni guiones y aplica unicidad `(system_code, code_normalized)`. La propiedad por sistema es:

| Sistema | Dueño | Regla verificada |
|---|---|---|
| `NOMENCLADOR-AR` | `oftar-pr` | Obligatorio para procedimientos. |
| `CIE-10` | `oftar-dx` | Obligatorio para diagnósticos H00-H59; no puede mapearse desde `oftar-pr`. |
| `ICD-10-PCS` | `oftar-pr` | Opcional; no genera diagnósticos ni códigos nuevos por defecto. |
| `CPT`, `LOINC` | `oftar-pr` | Opcionales, solo como mapeo de prestaciones/observaciones ya existentes. |
| `SNOMED-CT` | compartido | Opcional en PR y DX; nunca se inventa una equivalencia por similitud de texto. |

**Numeración permanente:** `OFT-PR-NNNNNN` y `OFT-DX-NNNNNN`, validados por `oftar_assert_catalog_code()`. Los prefijos retirados `OFTAR-PR-`/`OFTAR-DX-` no se reutilizan. La asignación crece por máximo + `row_number()`; un código retirado no se recicla.

---

## 4. Categoría clínica: resolución por precedencia

La API ya implementa la precedencia en `CatalogEngineService.php:107-124`:

1. **Asignación administrativa:** `os_catalog_item_clinical_category`. Solo por gobernanza con dos revisiones y evidencia (`categorias_clinicas.sql:149-159`; `catalogos_gestion_gobernada.sql:94-113`).
2. **Mapa de categoría fuente:** `os_catalog_category_clinical_map`, sin sobrescribir `os_catalog_category`.
3. **Default del catálogo:** `os_catalog_clinical_default`.

Valores vigentes para OFTAR (`categorias_clinicas.sql:107-119,142-145`):

| Catálogo / capítulo | Categoría clínica |
|---|---|
| `oftar-pr` / `GRP-EVAL`, `CONSULT`, `GRP-TER`, `TER`, `CIR`, `OCUL`, `LAGR` | `CLIN-PROC` |
| `oftar-pr` / `GRP-DIAG` | `CLIN-DIAG` |
| `oftar-pr` / `EXAM`, `DIAG`, `IMG` | `CLIN-EST` |
| `oftar-pr` / `GRP-OCUL` | `CLIN-ANAT` |
| `oftar-dx` / `CAT-DX` | `CLIN-DIAG` |
| CAO / Regional (default de catálogo) | `CLIN-PREST` |

---

## 5. Textos e internacionalización

- No existen columnas `name_en`/`name_pt`. La localización vive en `os_catalog_item_version(language_code, ...)`, `os_localized_text`, `os_catalog_language` y los archivos YAML `messages.{es-AR,en,pt-BR}.yaml`.
- `es-AR` es default/fallback; `en` es parcial; `pt-BR` está declarado como `planned` (`oftar_core.sql:165-185`).
- Los huecos idiomáticos de OFTAR-DX (1 en español, 17 en inglés) se conservan como datos explícitos. No se rellenan con traducción automática.
- `os_field_review` registra `source_language_code`, `language_evidence`, `provenance`, `review_status`, `source_reference` y `content_hash` por campo (`01_fase2_tablas.sql:122-137`). Una edición invalida la aprobación previa por cambio de hash.
- `v_oftar_search_catalog` solo publica versiones `approved` y prefiere `es-AR` (`oftar_domain_search.sql:45-80`).

---

## 6. Correspondencias y equivalencias

| Nivel | Qué se guarda | Qué **no** afirma |
|---|---|---|
| Propuesta textual | `os_oftar_nomenclador_match`, `match_basis='texto_identico_normalizado'` | No afirma equivalencia clínica ni de facturación. |
| Revisión humana | `review_status='approved'` con revisor y evidencia | No convierte la coincidencia en juicio clínico automático. |
| Relación publicada | `os_catalog_relation` con `review_status`, `provenance` y `context_text` | No cambia el catálogo de origen del código fuente. |
| Mapeo externo | `os_concept_mapping` / `oftar_*_mapping` con `mapping_type` y `relationship_role` | No importa SNOMED/CIE-10-PCS completos. |

Los importes presentes en CAO (`valor`) y Regional (`honorario_medico`, `gasto`, `valor_total`) son datos económicos de la fuente. El espejo canónico **no los copia** y **no los convierte a UVR**. La UVR, cuando exista, se decide editorialmente por prestación (`uvr_ejemplo_oct_oftar_pr_u7b.sql`).

---

## 7. Cadena de dependencias obligatoria

1. `sql/02_catalogs/origen_catalog_engine.sql` — núcleo `os_*`.
2. `sql/07_multilingue/01_fase2_tablas.sql` — `os_localized_text`, `os_field_review`, `os_translation_review`.
3. `sql/07_multilingue/04_fase3_columnas.sql` — columnas de revisión/proveniencia en `os_catalog_item_version`.
4. `sql/07_multilingue/05_fase3_triggers.sql` — hashes y auditoría.
5. `sql/03_oftar/oftar_family.sql` + `oftar_core.sql` — familia, catálogos y modelos editoriales.
6. `sql/03_oftar/oftar_external_identity.sql` — dueño por sistema y dedupe.
7. `sql/08_arquitectura/categorias_clinicas.sql` — taxonomía aditiva `CLIN-*`.
8. `sql/08_arquitectura/catalogos_gestion_gobernada.sql` — aplicador con dos revisiones. **Ejecución en producción no confirmada.**
9. API: `CatalogEngineService.php` y `TerminologySearchService.php` — contrato público inmutable.

---

## 8. Contrato público conservado

- Dominio único: `oftar`. No se crean dominios `oftar-pr`/`oftar-dx` nuevos.
- Rutas: `/{locale}/oftar`, `/v1/search?domains=oftar`, `/v1/catalogs/{catalogCode}/items`.
- API conserva `category` para deep links históricos y agrega `clinical_category` / `clinical_category_code`.
- El selector de “Todos” significa **sin filtro**; las casillas son persistentes por familia; DENTAR/OFTAR/nomenclador se inyectan como fallback (`browse-y-categorias.md`).

---

## 9. Propiedades que debe cumplir la reconstrucción

| Propiedad | Cómo se logra |
|---|---|
| Aditiva | Nuevas versiones/releases; nunca borrar filas ni reutilizar códigos. |
| Idempotente | Claves naturales + `ON CONFLICT DO UPDATE` sobre espejos, sin `DELETE`. |
| Trazable | Cada texto y mapeo tiene `provenance`, `source_reference`, `content_hash` y revisores. |
| Gobernada | Dos revisiones aprobadas por actores distintos y decisión con evidencia antes de publicar. |
| Multiidioma sin columnas paralelas | `language_code` + `os_localized_text` + YAML. |
| Sin equivalencias inventadas | Solo `texto_identico_normalizado` como candidato; revisión humana para publicar. |
| Sin UVR en diagnósticos | Regla de familia y exclusión explícita en `UvrPublicRepository.php`. |
| Sin motor paralelo | Todo aterriza en `os_catalog` y sus extensiones ya aprobadas. |

---

## 10. Puntos que requieren decisión antes de implementar

1. Confirmar en PostgreSQL si `catalogos_gestion_gobernada.sql` está aplicado; de no estarlo, la reconstrucción no debe publicar cambios hasta que el responsable lo autorice.
2. Confirmar si los 91 pares CAO tienen `target_code` de 6 dígitos o `OFT-PR-NNNNNN` (hallazgo H-02).
3. Definir si se publican las relaciones CAO→OFTAR-PR con `os_catalog_relation`, `os_concept_mapping` o ambos, conservando el catálogo fuente.
4. Ratificar que no se corregirá todavía la regresión de rutas en tests/generador, conforme a la restricción actual de no implementar.
