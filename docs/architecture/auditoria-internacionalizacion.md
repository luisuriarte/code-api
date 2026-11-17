# Auditoría de internacionalización — Origen Salud

> Estado: **auditoría y diseño únicamente**. No se ha ejecutado SQL, no se ha
> modificado PostgreSQL, la API, el sitio web, los importadores ni
> `tools/sources/**`. No se han borrado ni renombrado tablas, columnas o datos.
> No se ha hecho commit ni push.
>
> Idiomas objetivo: `es-AR`, `en`, `pt-BR` (etiquetas BCP-47).
>
> Reauditoría realizada el 2026-11-17 contra las definiciones reales del
> repositorio, con una última pasada de consistencia técnica. La referencia de
> decisiones es [`decisiones-arquitectura-multilingue.md`](decisiones-arquitectura-multilingue.md),
> incluidas las aclaraciones **D-27 a D-38**.
> Complementa [`modelo-multilingue-propuesto.md`](modelo-multilingue-propuesto.md)
> y [`plan-migracion-multilingue.md`](plan-migracion-multilingue.md).

---

## 1. Resumen ejecutivo

| # | Hallazgo verificado | Consecuencia para el diseño |
|---|---|---|
| 1 | `os_catalog_item_version` ya tiene `language_code VARCHAR(10) NOT NULL DEFAULT 'es-AR'` y `UNIQUE (item_id, release_id, language_code)`; `os_catalog_term` ya tiene `language_code` (`origen_catalog_engine.sql:72-90`). | Son el almacenamiento terminológico. No se duplican ni se crean columnas `name_en`/`name_pt`. |
| 2 | Toda la data semilla e importada en `os_*` es `es-AR`. No hay ningún concepto consultable en `en` ni `pt-BR`. | El problema no es falta de columnas, sino falta de filas por idioma y de resolución en la API. |
| 3 | `os_catalog`, `os_catalog_category`, `os_catalog_release`, `os_fee_schedule`, `os_pricing_unit`, `os_terminology_system` y `os_concept_mapping` tienen texto traducible **sin tabla de traducciones**. | Requieren `os_localized_text`, separada de la versión clínica del concepto. |
| 4 | **No existe** `os_localized_text`, `os_language`, `os_catalog_language`, `os_translation_review` ni `os_field_review`. | Son propuestas nuevas; el modelo debe definirlas por completo antes de aprobarlas. |
| 5 | `os_catalog` tiene `id SERIAL`, `product_role CHECK (family/catalog)` y `family_code`. La familia DENTAR **es una fila de `os_catalog`** (`code='dentar'`, `product_role='family'`), no una entidad aparte. | No existe entidad `catalog_family` con identificador propio. |
| 6 | DENTAR: `dentar_concept_version` y `dentar_diagnosis_version` **no tienen columna de idioma**; solo `dentar_term`, `dentar_diagnosis_term` y `dentar_category_version` tienen `language`. | `lay_terms`, `clinical_scope`, `short_definition`, `clinical_name`, `definition` y `clinical_criteria` son texto monoidioma con versionado editorial. Su procedencia no puede asumirse común. |
| 7 | LOINC: `loinc.id BIGSERIAL`, `loinc.loinc VARCHAR(20) UNIQUE`. Las capas es-MX y es-AR hacen `ON CONFLICT (loinc) DO UPDATE` sobre **las mismas columnas** (`importar_loinc.sql:162-182`, `:210-230`). `definition_description` queda en inglés. | El código LOINC es alfanumérico. Requiere modelo propio por idioma y **por archivo fuente**, con prioridad determinista. |
| 8 | `nomenclador_2025.codigo VARCHAR(20) PRIMARY KEY` (NN 2025) también es alfanumérico y no tiene mapeo a `os_*`. | Tampoco debe forzarse en `entity_id BIGINT`. |
| 9 | SNOMED/CIE-10 ya son multiidioma nativos (`snomed_descriptions.language_code`, `cie10_descriptions.language_code`, `effective_time` en SNOMED). `03_postcarga.sql:692` normaliza con `split_part`. | Conservar en sus tablas con `effective_time`, `module_id`, `type_id`, refsets y la etiqueta **real**, sin inferir `es-AR`. |
| 10 | La API documenta `Accept-Language` en `README-API.md` pero no lo lee; `lang` se reduce a `es`/`en`. `CatalogEngineService.php:207` usa `LIMIT 1` sin filtrar idioma. 15 literales `'es-AR'` en `TerminologySearchService`. | La resolución idiomática es inexistente en la práctica; `meta.language` puede mentir. |
| 11 | El sitio es una landing estática: no hay navegador, buscador ni `fetch` a la API; `i18n.php` solo `es`/`en`. | No hay hoy una UI que propague el locale. |
| 12 | Los scripts de `sql/04_pmo/` (Fase 4 del proyecto original) escriben `os_catalog_item.observation`, **columna inexistente** en el DDL y nunca agregada por `ALTER TABLE`. | Riesgo operativo crítico, independiente de i18n. Trabajo independiente y bloqueante para la carga PMO. |
| 13 | `provenance` (origen) y `review_status` (revisión) son conceptos distintos. El modelo anterior los mezclaba (`'official_translation'` como aprobado). | La visibilidad pública depende solo de `review_status='approved'`; `provenance` se reporta. |
| 14 | No existe ninguno de los campos `meta` propuestos (`requested_language`, `effective_language`, `source_language`, `provenance`, `approval_state`, `fallback_applied`, `fallback_reason`, `available_languages`, `untranslated`) en `api/**` (verificado: sin coincidencias). Tampoco `ALLOW_UNREVIEWED_DISPLAY`. | Todo el contrato de salida es nuevo. Los metadatos de catálogo/categoría/concepto pueden tener idiomas efectivos distintos y deben declararse por campo. |
| 15 | `os_catalog_term` admite `preferred` en su `CHECK` y **no tiene UNIQUE** (`origen_catalog_engine.sql:84-90`, índice GIN en `:104`). | No se puede afirmar que `preferred` esté prohibido hoy: hace falta trigger y UNIQUE. El sync ya excluye `preferred` y convierte `abbreviation→acronym` (`:305-324`). |
| 16 | `sct2.description.language_code` es ISO-639-1 `es`/`en` (`tools/sql/snomed/01_esquema.sql:72-87`); los refsets de idioma están en `sct2.refset_language` / `sct2.language_effective` (`03_postcarga.sql:119-124`, `:199-219`) y el catálogo incluye `450828004` "Español de América Latina" con `filter_code=NULL` (`:418`). | No hay evidencia de `es-AR` en el RF2. Conservar `es` y declarar dialecto no determinado. |
| 17 | Fuentes LOINC: `Loinc.csv`, `esMX28LinguisticVariant.csv`, `esAR7LinguisticVariant.csv`, `ConsumerName.csv` (`importar_loinc.sql:44-48`); capas secuenciales sobre las mismas columnas, `ConsumerName` sobrescribe `consumer_name` (`:247-251`). | hace falta prioridad determinista y preservación de `source_file` en la clave. |
| 18 | El backfill anterior asignaba `provenance='official_source'` y `review_status='approved'` de forma global, y `source_language_code=COALESCE(language_code,'es-AR')`. | Está prohibido: sin evidencia se usa `unknown`/`NULL`, con reporte reconciliable por tabla, campo, idioma y fuente. |
| 19 | Con backfill `unknown` y API `approved`-only, la API podría dejar de devolver prácticamente todo el contenido actual. Las pruebas 1-3 esperaban texto aprobado sin una fase que lo garantice. | Se incorpora la etapa 4.3 de clasificación y aprobación inicial (D-19): autoridad demostrable o pendiente editorial, nunca aprobación automática de lo oficial. |
| 20 | El dual-read de la Fase 11 caía a la columna original "solo si no hay fila", lo que podía publicar texto no aprobado. | D-20 condiciona la caída a un registro `approved` vigente; sin él, `null` + `untranslated=true`. |
| 21 | El sufijo `nombre_es` de CDT se consideraba evidencia de `es-AR`. | D-22: `nombre_es` justifica `es`, con `dialect_determined=false`; `es-AR` exige evidencia regional adicional. |
| 22 | `os_field_review` aparecía en varias fases sin definición formal de clave, responsabilidades ni precedencia. | D-12/D-21: estado vigente por campo; `os_translation_review` conserva el historial; prevalece el campo sobre la fila. |
| 23 | La política de idiomas no distinguía etiquetas admitidas, alias y etiquetas de origen; `Accept-Language` con solo `q=0` podía elegir silenciosamente un idioma. | D-15: tres clases, `es-MX` no aliasado, filas `is_source_only`, y `q_zero_only=true` con default declarado. |
| 24 | La Fase 3 decía "seis tablas de contenido" pero enumeraba cinco; faltaba la sexta (`os_localized_text`) y no se contemplaban `loinc_localized_text` ni `os_field_review`. | D-23: matriz única de auditoría de 8 tablas, con operaciones masivas, importadores y borrados. |
| 25 | `CREATE INDEX CONCURRENTLY IF NOT EXISTS` no valida un índice inválido preexistente. | D-24: verificar `indisvalid`, detectar duplicados, reparar y reintentar; el índice único no sustituye al trigger. |
| 26 | Restaurar solo en un esquema temporal no prueba extensiones, roles, funciones, triggers, secuencias ni permisos; los checksums no eran reproducibles. | D-25: base de datos independiente y consulta canónica documentada. |
| 27 | `is_source_only` se describía como "no servible", pero el diseño debía devolver textos originales `es` de SNOMED/CDT. | D-27: `is_active` gobierna la entrada; `is_source_only` no impide `effective_language='es'` aprobado. Sin reescritura a `es-AR`. |
| 28 | El modelo conservaba `PRIMARY KEY (target_table, target_id, field_name, language_code)` en `os_field_review` con `scope_release_id` opcional. | D-28: dos índices únicos parciales (`NULL`/`IS NOT NULL`) y precedencia release > global > fila. |
| 29 | La matriz de 8 tablas no decía cuándo se activaba cada una; Fase 3 parecía incluir `loinc_localized_text`. | D-29: Fase 2 = `os_field_review`; Fase 3 = 7 tablas; Fase 5 incorpora `loinc_localized_text` y completa 8. |
| 30 | `LanguageResolver` mezclaba selección de idioma con lectura de `os_field_review` y filtrado editorial. | D-30: resolvedor produce candidatos seleccionables; evaluador los amplía con el idioma de origen y los configurados (incluidas etiquetas `is_source_only`), filtra `approved`, aplica D-28 y calcula el efectivo por campo. |
| 31 | Un texto aprobado podía cambiar y conservar silenciosamente su aprobación. | D-31: `content_hash`, invalidación y limpieza de revisión en la misma transacción. |
| 32 | Los cambios de contenido y de estado no estaban claramente trazados con actor real. | D-32: `content_changed`, `approval_invalidated`, `review_state_changed` y `approval_granted` con actor de aplicación/`importer_run_id`. |
| 33 | `source_priority` de LOINC no tenía ubicación ni regla central; el desempate podía depender del orden de inserción. | D-33: columna materializada calculada por `loinc_source_priority(...)`; conflictos a reconciliar sin usar `id`. |
| 34 | La regla aditiva parecía prohibir todo `DROP`, pero D-24 exigía reparar índices inválidos. | D-34: excepción controlada y autorizada para `DROP INDEX CONCURRENTLY`; nunca para tablas/columnas/datos. |
| 35 | El trigger polimórfico se presentaba como sustituto de FK sin protección frente a operaciones concurrentes. | D-35: locks advisories transaccionales para entidad/release; no se afirma FK nativa. |
| 36 | Fase 13 aplicaba `SET NOT NULL`, contradiciendo la nullabilidad prevista en Fases 2/3. | D-36: `NOT NULL DEFAULT` desde la creación; Fase 13 solo verifica. |
| 37 | El modelo proyectaba CDT a `entity_type='nomenclador'` y a `/v1/nomenclador`, y a NN por rutas de nomenclador. | D-37: `nomenclador` = `nomencladores_argentina`; CDT usa tablas nativas y `/v1/search/odontologia`; NN sin endpoint. |
| 38 | `available_languages`, `effective_language` y `field_languages` no tenían cálculo preciso ni trataban idiomas efectivos mezclados. | D-38: `selectable`, efectivo por campo, `meta.effective_language=null` si hay mezcla y `field_languages` calculado por el evaluador. |

---

## 2. Fuentes consultadas y método

Se reconstruyó el esquema leyendo código, no documentación previa:

- `sql/01_schema/design.sql` — SNOMED, CIE-10, tablas planas legacy.
- `sql/02_catalogs/origen_catalog_engine.sql` — **fuente de verdad** del motor `os_*` (incluye `nomencladores_argentina` y `vademecum_comercial` en `:7594-7630`).
- `sql/03_dentar/dentar_core_and_diagnosis.sql`, `dentar_family.sql`, `sync_dentar_to_os.sql`.
- `sql/04_pmo/*.sql`, `sql/05_loinc.sql/importar_loinc.sql`, `sql/06_nomencladores/*`.
- `tools/sql/snomed/01_esquema.sql`, `03_postcarga.sql`, `tools/sources/cdt/*`, `tools/sources/nn/*`.
- `api/index.php`, `api/services/*.php`, `api/controllers/*.php`, `api/http/*.php`.
- `web/**/*`, `.env.example`, `README.md`, `README-API.md`, `sql/01_schema/README.md`.

> `docs/architecture/analisis-integracion-pmo.md` menciona columnas inexistentes
> (`kind`, `domain`, `version_number`, `published_at`). **No se usa como fuente.**

---

## 3. Esquema real reconstruido

### 3.1 Núcleo `os_*` (`origen_catalog_engine.sql`)

| Tabla | Columnas relevantes | PK / UNIQUE / FK |
|---|---|---|
| `os_catalog` | `id SERIAL`, `code`, `name`, `organization`, `country_code`, `domain_type`, `family_code`, `product_role ('family'\|'catalog')`, `short_name`, `description`, `website_url`, `is_active`, `created_at` | PK `id`; UNIQUE `code`; CHECK `product_role` en `:33-40` |
| `os_catalog_release` | `id`, `catalog_id`, `version_tag`, `valid_from`, `valid_to`, `official_norm_reference`, `status` | FK `catalog_id`; UNIQUE `(catalog_id, version_tag)` |
| `os_catalog_category` | `id`, `catalog_id`, `code`, `name`, `parent_category_id` | UNIQUE `(catalog_id, code)` |
| `os_catalog_item` | `id`, `catalog_id`, `permanent_code`, `status`, `created_at` | UNIQUE `(catalog_id, permanent_code)` |
| `os_catalog_item_version` | `id`, `item_id`, `release_id`, `category_id`, `preferred_term`, `definition`, `clinical_criteria`, **`language_code VARCHAR(10) NOT NULL DEFAULT 'es-AR'`** (`:80`) | UNIQUE `(item_id, release_id, language_code)` (`:81`); GIN `preferred_term` |
| `os_catalog_term` | `id`, `item_version_id`, `term`, `term_type CHECK ('preferred'\|'synonym'\|'acronym'\|'search_variant')` (`:88`), **`language_code`** (`:89`) | FK a versión; GIN `term` (`:104`); **sin UNIQUE** |
| `os_catalog_identifier` | `id`, `item_id`, `system_name`, `value`, `is_primary` | UNIQUE `(item_id, system_name, value)` |
| `os_terminology_system` | `id`, `code`, `name`, `uri`, `default_version` | UNIQUE `code` |
| `os_concept_mapping` | `id`, `item_id`, `terminology_system_id`, `external_code`, `external_display`, `mapping_type`, `relationship_role`, `clinical_rationale`, `review_status`, `created_at` | UNIQUE `(item_id, terminology_system_id, external_code, relationship_role)` |
| `os_pricing_unit` | `id`, `code`, `name`, `organization`, `description` | UNIQUE `code` |
| `os_fee_schedule` | `id`, `catalog_id`, `name`, `valid_from`, `valid_to`, `currency`, `unit_monetary_value` | UNIQUE `(catalog_id, name)` |
| `os_pricing_values` | `id`, `catalog_code VARCHAR(20)`, `pricing_system`, …, `year_effective`, `effective_from/to`, `source` | UNIQUE `(catalog_code, pricing_system, year_effective)` |

Otros `os_*` con texto y PK entera: `os_substance(id)`, `os_medicinal_product(id)`,
`os_product_package(id)`, `os_product_identifier(id)`; `nomencladores_argentina(id SERIAL)`
y `vademecum_comercial(id SERIAL)` en `:7594-7630`.

**No existe** ninguna columna `default_language_code`, `fallback_language_code`
ni `source_language_code` en `os_catalog`.

**Hecho operativo:** el propio engine ejecuta `DELETE` de ítems/categorías/aranceles
heredados de la familia DENTAR en `:288-317`. Es código existente; este diseño no
propone nuevos `DELETE`.

### 3.2 Datos semilla verificados

- 9 filas en `os_catalog`: la familia `dentar` (`product_role='family'`) más
  `dentar-pr`, `dentar-dx`, `nn-pmo`, `nbu`, `nhpgd`, `andis`, `kinesiologia` y
  `salud-mental`. `name`, `short_name` y `description` están en español dentro
  de la fila.
- La familia **no publica releases**: `os_catalog_release` se crea solo para
  `product_role='catalog' AND is_active` con `version_tag='2026-v1'` (`:319-324`).
- 12 categorías en `dentar-pr`, 1 en `dentar-dx` (`CAT-DX`).
- 15 ítems `DNT-PR-000001`…`DNT-PR-000015` (`:399-410`), todos con
  `language_code='es-AR'`.
- `os_concept_mapping.external_display` está en inglés en los ejemplos
  (`'ADA CDT 2025'`, `'SNOMED CT Procedure Concept'`, `'EKG study'` en `:5261+`).
- Los identificadores DENTAR usan `system_name='NOMENCLADOR_AR'` con valores
  como `01.01`, `02.09` (no `010101`).
- PMO: release real `2026-v1`; `PMOE-201-2002` aparece **solo en un comentario**
  de `sql/04_pmo/02_pmo_practicas.sql:192`. No se crea esa release histórica.

### 3.3 DENTAR (`sql/03_dentar/*`)

| Tabla | Columnas de texto | ¿Tiene idioma? |
|---|---|---|
| `dentar_release` | `description` | No |
| `dentar_category_version` | `name`, `description` | **Sí**: `language VARCHAR(10) DEFAULT 'es-AR'`, UNIQUE `(category_id, version_number, language)` |
| `dentar_concept_version` | `definition`, `short_definition`, `lay_terms`, `clinical_scope`, `clinical_criteria` | **No**. Se versiona por `version_number`, `effective_from/to`, `approval_status` (`:256-276`) |
| `dentar_term` | `term` | **Sí**: `language`, `term_type ('preferred'\|'synonym'\|'abbreviation')` (`:278-285`) |
| `dentar_unit`, `dentar_attribute_definition` | `name`, `description` | No |
| `dentar_terminology_system` | `name`, `description` | No |
| `dentar_diagnosis` | `clinical_name VARCHAR(500)` | No (`:7319-7327`) |
| `dentar_diagnosis_version` | `definition`, `clinical_criteria` | No (`:7329-7338`) |
| `dentar_diagnosis_term` | `term` | **Sí**: `language`, `term_type ('preferred'\|'synonym'\|'abbreviation')` (`:7340-7348`) |

`sync_dentar_to_os.sql` publica:

- `preferred_term` desde `dentar_term` con `term_type='preferred'` y
  `language='es-AR'` (`:273-274`, `:404-405`).
- `definition`/`clinical_criteria` desde `dentar_concept_version` y
  `dentar_diagnosis_version`, forzando `language_code='es-AR'` (`:262`, `:393`).
- `os_catalog_term` con `CASE WHEN term_type='abbreviation' THEN 'acronym'`
  (`:305-312` y `:427-434`), excluyendo `preferred` (`:324`, `:445`) y con
  literal `'es-AR'` (`:312`, `:323`). **Conservar el mapeo, parametrizar el idioma.**
- **`short_definition`, `lay_terms` y `clinical_scope` no se publican** a `os_*`.

Conclusión: esas tres columnas son texto español monolingüe con versionado
editorial; no son traducciones. Su procedencia debe registrarse por campo si
difiere de la de `definition`/`clinical_criteria` o del término preferido.

### 3.4 SNOMED CT y CIE-10 (`sql/01_schema/design.sql`, `tools/sql/snomed/*`)

- `snomed_concepts(id BIGINT PK, active, effective_time, module_id, definition_status_id)`.
- `snomed_descriptions(id BIGINT PK, active, effective_time, module_id,
  concept_id FK, language_code, type_id, term, case_significance_id)`;
  `type_id` FSN `900000000000003001`, sinónimo `900000000000013009`; índices GIN,
  por concepto y por idioma.
- `snomed_relationships(...)`, `map_snomed_cie10(...)`.
- `cie10_codes(id SERIAL, codigo UNIQUE, tipo)`;
  `cie10_descriptions(id SERIAL, cie10_id FK, language_code, descripcion)`.
- **Idioma del RF2:** `sct2.description.language_code` es ISO-639-1 `es`/`en`
  según `tools/sql/snomed/01_esquema.sql:72-87` (comentario de columna:
  "Idioma ISO-639-1 del texto: es, en"). No contiene `es-AR`/`es-MX`.
- **Language reference sets:** se cargan en `sct2.refset_language` (índices en
  `03_postcarga.sql:119-124`); `sct2.language_effective` selecciona el registro
  prevalente por aceptabilidad, módulo argentino `11000221109` y `effective_time`
  (`:199-219`). `sct2_refset_catalog` incluye `450828004` "Español de América
  Latina", `900000000000509007` "Inglés (US)" y `900000000000508004` "Inglés
  (GB)", todos con `filter_code=NULL` (`:418-420`).
- **Normalización:** `03_postcarga.sql:692` aplica
  `split_part(language_code,'-',1)` al insertar en `snomed_descriptions`: con los
  datos actuales es una normalización defensiva, **no** una fuente de dialecto.
  `sct2.preferred_term` ordena por `d.language_code='es'` y luego `'en'`
  (`:238-239`). `sct2.v_search_term` filtra solo `es` (`:466-476`).
- No se pierde `effective_time`: está en las tres tablas SNOMED. CIE-10 **no
  tiene** columna `effective_time` en el esquema real (no inventar una).

**Conclusión:** no inferir `es-AR` desde `es`. Conservar `es`, declarar
`dialect_determined=false`, exponer el refset de procedencia y el tag real.

### 3.5 LOINC (`sql/05_loinc.sql/importar_loinc.sql`)

- El importador ejecuta `DROP TABLE IF EXISTS loinc CASCADE` (código existente,
  no modificado por este diseño).
- Versión oficial 2.83 (`:2-5`); `loinc(id BIGSERIAL PK, loinc VARCHAR(20) NOT
  NULL UNIQUE, component, …, definition_description, …, version_last_changed,
  version_first_released, display_name)` — **sin `language_code`**.
- Fuentes (`:44-48`): `Loinc.csv`, `MapTo.csv`, `esMX28LinguisticVariant.csv`,
  `esAR7LinguisticVariant.csv`, `ConsumerName.csv`.
- Orden de capas: EN (`:127-133`) → MX (`:139-184`) → AR (`:187-232`) →
  `ConsumerName.csv` (`:235-253`). MX y AR usan
  `ON CONFLICT (loinc) DO UPDATE` sobre las mismas columnas (`:170-182`,
  `:218-230`); `ConsumerName` sobrescribe `consumer_name` (`:247-251`).
- Las variantes son `es-MX` y `es-AR`: identificadores de origen distintos, no
  alias intercambiables. El importador declara precedencia "MX más cobertura, AR
  sobrescribe" (`:12-18`), pero no preserva ambas capas.

### 3.6 PMO y nomencladores

- Fuente `pmo_practicas`: `practica`, `capitulo`, `subcapitulo`, `notas`,
  `cobertura_condicionada`, `revisar`; sin columna de idioma.
- `02_pmo_practicas.sql` usa `tmp.codigo` como `os_catalog_category.code`
  (el comentario dice `cap_cod`) y `COALESCE(NULLIF(practica,''),'Sin descripción')`.
- Fase 4 (`01_formulario_terapeutico`, `02_precios_historial`, `03_odontologia`,
  `04_normativa`) escribe `os_catalog_item.observation` con tags
  `FORMULARIO:`, `PRECIO:`, `ODONTOLOGICO`, `NORMATIVA:`. **La columna no existe**.
- `nomencladores_argentina` (`tipo_nomenclador`, `codigo`, `capitulo`,
  `descripcion`, …) y `vademecum_comercial` sin idioma; definidas 3 veces
  (`design.sql`, engine, `nomencladores_argentina.sql`). Gana la primera.
- CDT 2025 (`tools/sources/cdt/Argentina_dental_cdt_codes_2025.sql`):
  `nombre_en/nombre_es`, `descripcion_en/descripcion_es`; la sincronización
  propaga solo la rama española a `odontologia_prestaciones`. No escribe `os_*`.
- NN 2025 (`tools/sources/nn/Nomenclador_Nacional_2025.sql`):
  `nomenclador_2025(codigo PK, descripcion, valor, categoria)` monolingüe, índice
  `to_tsvector('spanish', descripcion)`, sin mapeo a `os_*`.

---

## 4. API y sitio web

### 4.1 API (`api/**`)

- 30 rutas GET. `GET /v1/catalogs`, `/releases`, `/items`,
  `/items/{permanent_code}`, búsqueda, mapeos, SNOMED, CIE-10, LOINC, PMO, etc.
- `GET /v1/catalogs/dentar-pr/items/{code}` acepta `item.permanent_code`
  (p. ej. `DNT-PR-000001`) **o** `ident.value` (`01.01`) / su forma sin puntos
  (`0101`). El código `010101` usado en documentación anterior **no es un código
  DENTAR válido**.
- `Request`/`ConceptController::resolveLanguage()` (`:372-399`) valida solo
  `es`/`en`; `API_DEFAULT_LANG='es'` (`.env.example:33`). `Accept-Language` no se
  lee en ningún archivo PHP.
- `CatalogEngineService::getItem()` (`api/services/CatalogEngineService.php:207`)
  usa `LIMIT 1` sin `language_code`.
- `TerminologySearchService` tiene literales `'es-AR'` en las consultas
  DENTAR (`:829`, `:836`, `:841`, `:861`, `:982`, `:989`, `:994`, `:1015`,
  `:1023`, `:1028`, `:1151`, `:1159`, …). El `lang` recibido solo se refleja en
  `meta`.
- `ConceptController::show()` devuelve `descriptions` de todos los idiomas
  agrupados, sin respetar `lang`.
- No hay `Content-Language` ni `Vary: Accept-Language`.
- **No existen** los campos `meta` propuestos ni `ALLOW_UNREVIEWED_DISPLAY`
  (búsqueda sin coincidencias en `api/**`, `.env.example`, `README-API.md`).
  Por tanto, la política `approved`-only y el contrato per-field son
  **propuestas**, no comportamientos actuales.

### 4.2 Sitio web (`web/**`)

- `web/index.php`: landing estática; sin navegador de catálogos, buscador ni
  `fetch`.
- `i18n.php`: solo `es`/`en`; `canonical()` colapsa variantes regionales.
- `docs.php`: ~99 ternarios `$isEn`; ejemplos y JSON quedan en español en modo EN.
- El locale solo se propaga a un cURL/JSON de ejemplo.

---

## 5. Inventario de campos traducibles omitidos

Además de los ya documentados (`os_catalog.name/short_name/description`,
`os_catalog_category.name`, `official_norm_reference`, `os_fee_schedule.name`,
`os_pricing_unit.name/description/organization`, `os_terminology_system.name`,
`os_concept_mapping.external_display/clinical_rationale`), el modelo anterior
**no cubría**:

| Origen | Campo | Situación |
|---|---|---|
| `dentar_concept_version` | `short_definition`, `lay_terms`, `clinical_scope` | Texto español monolingüe, no publicado a `os_*` |
| `dentar_diagnosis` | `clinical_name` | Texto español monolingüe |
| `dentar_diagnosis_version` | `definition`, `clinical_criteria` | Texto español monolingüe, versionado |
| `dentar_diagnosis_term` | `term` | Sí tiene `language` |
| `dentar_release`, `dentar_unit`, `dentar_attribute_definition`, `dentar_terminology_system` | `description`, `name` | Sin idioma |
| `os_substance`, `os_medicinal_product`, `os_product_package` | `name`, `brand_name`, `presentation_text`, … | Sin idioma, PK entera |

Estos campos aparecen ahora en el modelo y en el plan; su procedencia se rige
por `os_field_review` cuando no compartan fuente/estado.

---

## 6. Problemas consolidados (mapa de correcciones)

| Corrección requerida | Evidencia en el repositorio | Estado en la documentación revisada |
|---|---|---|
| Separar `provenance` de `review_status` | No existen aún; se proponen con `unknown` | ✅ Cerrado (D-01, D-18) |
| API pública `approved`-only; admin aparte | Sin campos `meta` ni flag en la API | ✅ Cerrado (D-02, D-03) |
| Idioma efectivo por campo | Catálogo/categoría/concepto resuelven por separado | ✅ Cerrado (D-03, modelo §7.6) |
| LOINC con modelo propio y prioridad | `loinc.loinc VARCHAR(20)`; capas sobrescriben | ✅ Cerrado (D-08) |
| `catalog_family` sin entidad | La familia es fila de `os_catalog` | ✅ Hecho verificado (§3.1) |
| `os_localized_text` con límites polimórficos | No existe | ✅ Cerrado (D-14); trigger no presentado como FK |
| `scope_release_id RESTRICT` + pertenencia | No existe | ✅ Cerrado (D-06) |
| Procedencia por campo clínico | Fuentes DENTAR distintas | ✅ Cerrado (D-07, D-12, D-21) |
| RF2: `es` no implica `es-AR` | `01_esquema.sql:72-87`; refsets en `03_postcarga.sql` | ✅ Cerrado (D-05) |
| Auditoría con actor real | No existe tabla de auditoría | ✅ Cerrado (D-10) |
| `os_catalog_term` DDL real | `preferred` permitido; sin UNIQUE | ✅ Cerrado (D-11) |
| Historial recuperable | No existe | ✅ Cerrado (D-12); sin afirmación criptográfica |
| Fallback único y declarado | `lang` roto; `Accept-Language` ignorado | ✅ Cerrado (D-03) |
| Concepto/release/idioma | UNIQUE existente; `LIMIT 1` | ✅ Cerrado (modelo §8) |
| Inconsistencias del plan | `os_catalog` no tiene columnas de idioma | ✅ Cerrado (Fases 1-14) |
| SNOMED/CIE-10/LOINC nativos | Tablas con `effective_time` y códigos propios | ✅ Cerrado (D-05, D-08) |
| Migración/rollback | — | ✅ Cerrado (D-16, Fase 14) |
| PMO separado y bloqueante | `observation` inexistente | ✅ Cerrado (D-17, plan §6) |
| Aprobación inicial `unknown`→`approved` | Sin fase que garantice texto aprobado para pruebas 1-3 | ✅ Cerrado (D-19, etapa 4.3) |
| Dual-read sin eludir publicación | Caída automática a columna original | ✅ Cerrado (D-20, Fase 11) |
| CDT `es`≠`es-AR` | `nombre_es` no demuestra variante regional | ✅ Cerrado (D-22, Fases 4/10) |
| `os_field_review` formal | Clave, responsabilidades y precedencia ausentes | ✅ Cerrado (D-12, D-21) |
| Tres clases de idioma y `q=0` | Alias y etiquetas de origen mezclados | ✅ Cerrado (D-15, modelo §7.1) |
| Matriz de auditoría de 8 tablas | "Seis tablas" pero solo cinco enumeradas | ✅ Cerrado (D-23) |
| Índices concurrentes inválidos | `IF NOT EXISTS` no valida `indisvalid` | ✅ Cerrado (D-24) |
| Restauración en base independiente | Solo esquema temporal; checksums no reproducibles | ✅ Cerrado (D-25) |
| Códigos de prueba verificados en staging | `DNT-PR-000001` solo verificado en SQL | ✅ Cerrado (D-26, plan §7) |
| Seleccionable vs. efectivo | RF2 `es`; sufijo CDT `nombre_es` | ✅ Cerrado (D-27, modelo §5.1/§7.1) |
| Unicidad `os_field_review` | `scope_release_id` opcional en la clave propuesta | ✅ Cerrado (D-28, modelo §5.5) |
| Auditoría por fase | Fase 3 no podía incluir `loinc_localized_text` | ✅ Cerrado (D-29, modelo §5.4, plan Fases 2/3/5) |
| Resolver vs. evaluador editorial | Estado de revisión mezclado con selección de idioma | ✅ Cerrado (D-30, modelo §7.4, plan Fase 8) |
| Invalidación de aprobación | Cambio de texto sin invalidación | ✅ Cerrado (D-31, modelo §5.5, plan Fases 3/11) |
| Trazabilidad de cambios | Actor real e importador no distinguidos | ✅ Cerrado (D-32, modelo §5.4) |
| Prioridad LOINC centralizada | Regla repartida y desempate por inserción | ✅ Cerrado (D-33, modelo §4.4, plan Fase 5) |
| Excepción `DROP INDEX` | Reparación D-24 vs. prohibición D-16 | ✅ Cerrado (D-34, plan §2.1/Fase 2) |
| Concurrencia polimórfica | Trigger de existencia presentado como FK | ✅ Cerrado (D-35, modelo §5.3) |
| Nullabilidad final | Fase 13 introducía `NOT NULL` | ✅ Cerrado (D-36, plan Fase 13) |
| CDT/NN reales | `/v1/nomenclador` no es CDT | ✅ Cerrado (D-37, modelo §6, plan Fase 10) |
| Contrato API | `meta.effective_language` único con campos mezclados | ✅ Cerrado (D-38, modelo §7.6, plan Fase 8) |

---

## 7. Verificaciones puntuales de la revisión final

| Afirmación | Verificación real |
|---|---|
| `os_catalog_term` admite `preferred` | `origen_catalog_engine.sql:88` — `CHECK (term_type IN ('preferred','synonym','acronym','search_variant'))`. |
| No hay UNIQUE en `os_catalog_term` | Solo `CREATE INDEX ... USING gin (term gin_trgm_ops)` en `:104`. |
| `abbreviation → acronym` ya existe | `sync_dentar_to_os.sql:305-312` y `:427-434`; `preferred` excluido en `:324`, `:445`. |
| SNOMED RF2 no trae dialecto en `language_code` | `tools/sql/snomed/01_esquema.sql:86-87` — comentario "Idioma ISO-639-1 del texto: es, en". |
| Language reference sets conservados en staging | `03_postcarga.sql:119-124` (índices), `:199-219` (`language_effective`), `:418-420` (catálogo). |
| `split_part` es normalización, no dialecto | `03_postcarga.sql:692` copia de `sct2.description` a `snomed_descriptions`. |
| LOINC sobrescribe capas | `importar_loinc.sql:170-182`, `:218-230` (`ON CONFLICT DO UPDATE`), `:247-251` (`ConsumerName`). |
| Fuentes LOINC reales | `importar_loinc.sql:44-48`; versión 2.83 en `:2-5`. |
| Códigos de ejemplo válidos | `DNT-PR-000001` en `origen_catalog_engine.sql:399-410`; `01.01` en identificadores DENTAR. `010101` no válido. |
| Default de idioma actual | `.env.example:33` — `API_DEFAULT_LANG=es`. |
| Campos `meta` propuestos inexistentes | Sin coincidencias en `api/**` ni `.env.example`. |
| CDT con sufijos de idioma | `tools/sources/cdt/Argentina_dental_cdt_codes_2025.sql` — `nombre_en/nombre_es`, `descripcion_en/descripcion_es`; `es` no implica `es-AR`. |
| NN 2025 sin idioma | `tools/sources/nn/Nomenclador_Nacional_2025.sql` — `codigo`, `descripcion`, `categoria`, sin mapeo a `os_*`. |
| Rutas existentes para CDT/NN | `/v1/nomenclador` (`api/index.php:234`) consulta `nomencladores_argentina`, **no CDT**; odontología se consulta por `/v1/search/odontologia` y `/v1/odontologia/{id}` (`:115-129`, `:439-444`). NN 2025 no tiene endpoint propio. |
| `os_catalog_term` sin UNIQUE y con `preferred` | `origen_catalog_engine.sql:84-90`; GIN en `:104`. |
| Seis tablas enumeradas como cinco | Fase 3 del plan anterior: faltaba `os_localized_text`; ahora hay matriz de 8 (D-23). |
| `/v1/nomenclador` consulta `nomencladores_argentina` | `api/index.php:234-239` invoca `searchNomencladorArgentina`; `TerminologySearchService.php:1423-1442` selecciona `FROM nomencladores_argentina`. No consulta CDT. |
| Dominio odontología y ruta de búsqueda | `/v1/search/{domain}` en `api/index.php:115-129`; `TerminologySearchService.php:40` define `DOMAIN_ODONTOLOGIA='odontologia'`; `:256-278` mapea ese dominio a `odontologia_prestaciones`. |
| Detalle de odontología | `api/index.php:439-444` — `GET /v1/(laboratorio\|vacunas\|odontologia\|...)/{id}` llama a `findCatalog`. |
| No existe `/v1/cdt` | Búsqueda literal sin coincidencias en `api/**`; la ruta genérica es `/v1/search/odontologia`. |
| CDT conserva claves VARCHAR | `tools/sources/cdt/Argentina_dental_cdt_codes_2025.sql:28-33` (`odontologia_cdt_categorias.codigo`), `:136-140` (`odontologia_cdt_catalogo.codigo_cdt VARCHAR(10)`), `:4594-4601` (`odontologia_prestaciones.id SERIAL`, `codigo_nomenclador` UNIQUE). No caben en `entity_id BIGINT`. |
| NN 2025 monolingüe y sin endpoint | `tools/sources/nn/Nomenclador_Nacional_2025.sql:8-12` (`codigo VARCHAR(20) PK`, `descripcion`, `categoria`); índice `to_tsvector('spanish', descripcion)` en `:3534`. |
| `nomencladores_argentina` es el único `nomenclador` | `sql/02_catalogs/origen_catalog_engine.sql:7594-7609` — `id SERIAL`, `codigo VARCHAR(30)`, `capitulo`, `descripcion`, UNIQUE `(tipo_nomenclador, codigo)`. |
| SNOMED `es` sin dialecto | `tools/sql/snomed/01_esquema.sql:86-87` — comentario "Idioma ISO-639-1 del texto: es, en"; refsets en `03_postcarga.sql:119-124`, `:199-219`, catálogo `450828004` en `:418`. |
| `split_part` no inventa dialecto | `tools/sql/snomed/03_postcarga.sql:692` copia de `sct2.description` a `snomed_descriptions`; `v_search_term` filtra `es` en `:466-476`. |
| LOINC 2.83 y capas sobrescritas | `sql/05_loinc.sql/importar_loinc.sql:2-5`, fuentes en `:44-48`, `ON CONFLICT DO UPDATE` en `:170-182` y `:218-230`, `ConsumerName` en `:247-251`. |
| Idioma por defecto actual | `.env.example:33` — `API_DEFAULT_LANG=es`. |
| Campos `meta` propuestos inexistentes | Búsqueda sin coincidencias en `api/**` ni `.env.example`; el contrato per-field es propuesta, no comportamiento actual. |

---

## 8. Impacto esperado (resumen)

- La resolución idiomática debe centralizarse en dos componentes separados:
  `LanguageResolver` (solo `lang` → alias → `Accept-Language` (q) → default y
  lista ordenada de candidatos) y el evaluador editorial, que amplía esa lista
  con el idioma de origen declarado y los idiomas configurados (incluidas
  etiquetas `is_source_only` como `es`), filtra `approved`, aplica precedencia
  D-28 y calcula `effective_language` por campo. El estado de `os_field_review`
  no selecciona idioma (D-30).
- `available_languages` informa `selectable`; un contenido `es` aprobado se
  entrega como `effective_language='es'` aunque no sea seleccionable como
  `lang`. `meta.effective_language` es `null` si los campos mezclan idiomas y
  `field_languages` es la fuente de verdad (D-27, D-38).
- Un cambio de contenido recalcula `content_hash`, invalida la aprobación y
  registra `content_changed`/`approval_invalidated` en la misma transacción; los
  cambios de estado quedan trazados con actor real (D-31, D-32).
- La API pública sirve solo `approved`; sin aprobado, `null` + `untranslated=true`.
  La administración es un canal separado con estado y procedencia explícitos.
- La etapa 4.3 documenta la aprobación inicial: autoridad demostrable o
  pendiente editorial, nunca aprobación automática de lo oficial (D-19). Sin
  esa matriz, las pruebas 1-3 esperan contenido vacío declarado.
- El dual-read es compatibilidad de esquema, no excepción editorial: sin
  `approved` vigente no se cae a la columna original (D-20).
- CDT conserva `es` desde `nombre_es`, sin inferir `es-AR`, y permanece en sus
  tablas nativas: `/v1/search/odontologia` y `/v1/odontologia/{id}` son sus
  rutas reales; `/v1/nomenclador` consulta `nomencladores_argentina`, que es el
  único `entity_type='nomenclador'`. NN 2025 no tiene endpoint propio ni mapeo a
  `os_*` en esta versión (D-22, D-37).
- `CatalogEngineService` debe filtrar `language_code` y dejar de depender del
  orden físico de filas; `os_catalog_term` debe pasar a ser consultado con
  consistencia de idioma.
- Los endpoints DENTAR sustituyen literales `'es-AR'`, conservan
  `abbreviation→acronym` y publican los tres campos clínicos omitidos.
- SNOMED conserva `es` sin dialecto inventado; LOINC conserva EN/es-MX/es-AR con
  prioridad determinista y procedencia por `source_file`.
- Auditoría transaccional con actor de aplicación/proceso importador; recuperable
  y protegida, sin afirmar inmutabilidad criptográfica. Matriz única de 8
  tablas, incluidas `os_localized_text`, `os_field_review` y
  `loinc_localized_text` (D-23).
- Índices concurrentes con verificación de `indisvalid` y reparación de
  duplicados/inválidos solo mediante la excepción autorizada de D-34 (D-24);
  integridad polimórfica reforzada con locks advisories, sin presentar el
  trigger como FK nativa (D-35); nullabilidad definida en Fases 2/3 y solo
  verificada en Fase 13 (D-36); backups restaurados en base independiente con
  checksums canónicos (D-25); códigos de prueba verificados en staging (D-26).
- El sitio debe incorporar el navegador/buscador que hoy no existe e inyectar el
  locale en cada petición.
- PMO queda como trabajo independiente y bloqueante para su carga.

---

## 9. Estado

El modelo, el plan y las decisiones revisadas están en los documentos hermanos.
**Ninguna de estas acciones ha sido ejecutada.** No se han modificado SQL, PHP,
JavaScript, datos, base de datos, importadores ni fuentes originales. No hubo
commits ni push.
