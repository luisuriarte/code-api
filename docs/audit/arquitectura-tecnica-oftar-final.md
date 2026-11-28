# Arquitectura técnica definitiva de OFTAR

**Fecha:** 2026-11-28
**Versión:** 1.0
**Estado:** OFTAR v1.0 — Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada. (No autoriza ejecución; análisis documentado.)
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0. Ante contradicción, prevalece lo verificado y lo definido allí (§0, §7 y §9).
**Convención:** `[H]` hecho verificado en repositorio · `[I]` inferencia · `[P]` decisión propuesta.

---

## 1. Método y límite de verificación

**[H]** La inspección fue solo lectura de SQL, PHP, OpenAPI, generadores y tests. No hay cliente `psql` en este entorno y las variables de conexión (`DB_*`, `PG*`, PORTAL/ADMIN/SERVICE) están sin definir. No se ejecutó ninguna consulta contra PostgreSQL.

**[H]** `api/config/database.php:39-95,155-183` usa `DB_HOST/PORT/NAME/USER/PASSWORD/DB_SSLMODE/DB_CONNECT_TIMEOUT` con defaults `127.0.0.1:5432`, base `origen_salud`, usuario `origen_api`. `portal/Config.php:33-69,252-279` define DSNs por frente. No existe `config/entorno.php` ni `.env*` versionado.

**[I]** Por tanto, las afirmaciones sobre base de datos son de **código desplegable**, no de estado runtime. Toda verificación de producción queda como consulta `READ ONLY` para el responsable (§7).

---

## 2. Esquema real verificado

### 2.1 Núcleo canónico

**[H]** `sql/02_catalogs/origen_catalog_engine.sql`:

| Objeto | Columnas / restricciones verificadas | Líneas |
|---|---|---|
| `os_catalog` | `id` PK, `code UNIQUE`, `family_code`, `product_role CHECK(family\|catalog)`, `domain_type CHECK(dental\|medical\|biochemical\|rehabilitation\|mental_health\|pharma\|terminology)`, `country_code`, `is_active` | 13-51 |
| `os_catalog_release` | FK `catalog_id`, `version_tag`, `status CHECK(draft\|review\|published\|deprecated)`, `UNIQUE(catalog_id, version_tag)` | 13-51 |
| `os_catalog_category` | FK catálogo, `parent_category_id` self-FK, `UNIQUE(catalog_id, code)` | 54-60 |
| `os_catalog_item` | FK catálogo, `permanent_code`, `status CHECK(active\|retired\|superseded)`, `UNIQUE(catalog_id, permanent_code)` | 63-70 |
| `os_catalog_item_version` | FK ítem/release/categoría, `preferred_term`, `definition`, `clinical_criteria`, `language_code DEFAULT 'es-AR'`, `UNIQUE(item_id, release_id, language_code)`. `review_status` se agrega después: `NOT NULL DEFAULT 'unknown'`, **sin CHECK** (`sql/07_multilingue/04_fase3_columnas.sql:24-37`); los scripts OFTAR lo ponen en `approved`. **No existe `is_billable`** | 72-82; 04_fase3_columnas.sql:24-37 |
| `os_catalog_term` | FK versión, `term`, `term_type CHECK(preferred\|synonym\|acronym\|search_variant)`, `language_code DEFAULT 'es-AR'`. **No existen `lay_term` ni `abbreviation`** | 84-90 |
| `os_catalog_identifier` | FK ítem, `system_name`, `value`, `is_primary`, `UNIQUE(item_id, system_name, value)` | 92-98 |
| `os_concept_mapping` | FK ítem/sistema, `external_code`, `external_display`, `mapping_type CHECK(equivalent\|narrower\|broader\|related\|unmatched)`, `relationship_role CHECK(procedure_concept\|justifying_diagnosis\|observation_concept\|substance_concept)`, `provenance`, `source_reference`, `review_status CHECK(draft\|reviewed\|approved\|deprecated)`, `language_evidence`, `UNIQUE(item_id, terminology_system_id, external_code, relationship_role)`. Default original `approved`; `fase3_relaciones_mapeos.sql:183-184` lo cambia a `draft` sin modificar el CHECK | 119-134; fase3_relaciones_mapeos.sql:177-184 |

**[H] Corrección aplicada:** el valor real para equivalencia es `equivalent`, no `exact`. La afirmación anterior —`exact|no_map|reference`— era incorrecta y queda retirada: esos tres valores no existen en el `CHECK` versionado ni en el generador. Las apariciones de «exacta» en la matriz clínica son etiquetas documentales. La especificación definitiva usa `equivalent`/`unmatched`.

**[H] `oftar` no es un valor de `os_catalog.domain_type`.** El `CHECK` verificado admite `dental|medical|biochemical|rehabilitation|mental_health|pharma|terminology` (`origen_catalog_engine.sql:18`). La declaración real es:

| `code` | `country_code` | `domain_type` | `family_code` | `product_role` | Evidencia |
|---|---|---|---|---|---|
| `oftar` | `AR` | `medical` | `NULL` | `family` | `oftar_core.sql:142-144` |
| `oftar-pr` | `AR` | `medical` | `oftar` | `catalog` | `oftar_core.sql:145-147` |
| `oftar-dx` | `AR` | `medical` | `oftar` | `catalog` | `oftar_core.sql:148-150` |

**[H]** `oftar` es además **dominio funcional de búsqueda**: `TerminologySearchService.php:49` define `DOMAIN_OFTAR='oftar'`, `:52-68` lo incluye en `DOMAINS`, `:76-80` **no** lo incluye en `DEFAULT_DOMAINS`, y `:417-432` lo enlaza a `v_oftar_search_catalog`. `os_domain_registry` registra el dominio expuesto (`oftar_domain_search.sql:27-37`) pero la API no lo usa como fuente de verdad (`TerminologySearchService.php:444-453,2896-2921`).

**[H]** Los catálogos de origen `nomenclador-oftalmologico-cao-ar` y `nomenclador-oftalmologico-regional-ar` también tienen `family_code='oftar'`, `domain_type='medical'` y `product_role='catalog'`; son catálogos de la familia, **no dominios nuevos ni productos editoriales**.

**[P]** Mantener la arquitectura actual: no proponer `domain_type='oftar'`, no crear dominios `oftar-pr`/`oftar-dx` y no mezclar dominio funcional, familia, `product_role` y `domain_type`.

### 2.2 Internacionalización y gobernanza

**[H]** `sql/07_multilingue/01_fase2_tablas.sql:18-96,122+` crea `os_language`, `os_language_alias`, `os_catalog_language` (PK compuesta `catalog_id, language_code`, flags default/fallback/bridge, `coverage_status`), `os_localized_text` (`entity_type/entity_id/field_name`, `value`, `source_language_code`, `language_evidence`, `provenance`, `content_hash`, `scope_release_id` con `ON DELETE RESTRICT`; **no existe `is_current`**) y `os_field_review` (`review_status DEFAULT 'unknown'`, sin CHECK, `content_hash NOT NULL`).

**[H]** `sql/08_arquitectura/fase3_i18n.sql:1-93` activa D-31 con funciones/triggers y siembra `os_catalog_language` de forma idempotente; no reejecuta fases 01–15.

**[H]** `sql/08_arquitectura/fase4_gobernanza.sql:26-147,205-283` crea `os_governance_request`, `os_governance_review/decision` y `os_audit_log` **append-only** con trigger `trg_os_audit_log_immutable` que impide UPDATE/DELETE. `catalogos_gestion_gobernada.sql:48-311` define `os_catalog_apply_governed_change(BIGINT,BIGINT,TEXT)` SECURITY DEFINER, valida revisión/evidencia/estado y audita.

**[H]** `sql/08_arquitectura/categorias_clinicas.sql:12-29` crea `os_clinical_category` (`code` PK, `name`, `definition`, `examples`, `sort_order`, `status CHECK(active|inactive)`), aditiva; no renombra `os_catalog_category`.

### 2.3 OFTAR

**[H]** `sql/03_oftar/oftar_core.sql:45-104,490-539` crea `oftar_catalog`, versionado, categorías, sistemas terminológicos, atributos, reglas/mapeos/diagnósticos y la vista `v_oftar_family_concept`.

**[H]** `sql/03_oftar/oftar_external_identity.sql:62-92,210-214` crea `oftar_external_identity` con `system_code`, `code_raw`, `code_normalized`, `owner_catalog CHECK(oftar-pr|oftar-dx|shared)`, `entity_kind`, `UNIQUE(system_code, code_normalized)` e índices/triggers de vinculación.

**[H]** `sql/03_oftar/oftar_domain_search.sql:45-120` crea `v_oftar_search_catalog`: `DISTINCT ON (item.id)`, familia `oftar`, `product_role='catalog'`, catálogo e ítem activos, versión `review_status='approved'`. Prioriza `es-AR` y conserva `en` solo cuando existe en fuente. Expone `id, activo, snomed_concept_id, codigo, termino, subtitulo, catalogo, codigo_permanente, familia, categoria, idioma, estado_revision`.

**[H]** `sql/03_oftar/importar_nomenclador_oftar_pr.sql:123-332`, `sync_oftar_dx_to_os.sql:60-240` y `nomencladores_oftar_mapping.sql` proyectan OFTAR al motor y crean `os_field_review` pendiente. `aprobar_preferred_term_oftar_dx.sql` y `aprobar_mapeo_nomencladores_oftar.sql` son aprobaciones separadas por hash/actor.

### 2.4 Atributos, anatomía y relaciones: qué existe realmente

**[H]** `oftar_attribute_definition` (`oftar_core.sql:257-264`) contiene códigos como `ATTR-STRUCTURE` (`:269-270`), `ATTR-MODALITY` (`:273-274`) y `ATTR-LATERALITY` (`:267-268`). **`ATTR-*` son valores de `code`, no columnas.** `oftar_attribute_value` (`:288-296`) carga hoy dominios de lateralidad y rol de ejecución (`:298-306`); la proyección real al motor ocurre en `os_catalog_source_attribute` (`:314-323`; `importar_nomenclador_oftar_pr.sql:259-268`).

**[H]** No existen columnas `anatomy`, `clinical_area`, `anatomy_code` ni `area_code` en el SQL revisado. Los identificadores `ANAT-*` y `AREA-*` son **propuesta documental**, no valores sembrados (`clasificacion-anatomica-oftar-final.md:29,35-63`). Cargarlos sería inserción en tablas existentes, sin DDL, previa ratificación.

**[H]** `os_catalog_relation` existe con `source_item_id`, `target_item_id`, `relation_type`, `source_system_code`, `source_field`, `source_value`, `context_text`, `review_status` y `provenance` (`sql/03_dentar/nomenclador_odontologico_nacional.sql:534-559`). Su `CHECK relation_type` admite solo 15 valores CDT, `source_field` admite `description|procedure|notes|req`, `source_value` es `VARCHAR(20)`, `review_status` es `draft|reviewed|approved|deprecated`, la fila no puede ser self-relation y hay `UNIQUE` de siete columnas. **[I]** Usarlo para relaciones clínicas OFTAR requiere el puente documentado o la migración aditiva aprobada; no asumir que cualquier `relation_type` es aceptado.

**[H]** `sql/08_arquitectura/fase1_infraestructura.sql:42-81` define `os_relation_kind` (`unclassified|structural|clinical|editorial|billing|regulatory|mapping`) y `os_relation_type` con `code VARCHAR(60)`, `relation_kind` e `inverse_code`. `fase3_relaciones_mapeos.sql:53-113` agrega columnas aditivas (`valid_from/to`, catálogos/releases de origen/destino, `relation_kind`, `mapping_method`, `confidence_level`, `reviewed_by/at`, `license_reference`, `inverse_relation_type`). **[I]** La coexistencia de ambas definiciones exige verificar en el acta `READ ONLY` qué columnas están presentes en producción.

**[P]** Modelo integral: relaciones clínicas en `os_catalog_relation` y correspondencias terminológicas en `os_concept_mapping`, sin motor paralelo. El diccionario de 31 tipos OFTAR, la direccionalidad y las reglas de simetría están en `modelo-relaciones-clinicas-oftar.md` y `diccionario-tipos-relacion-oftar.md`; las ocho clases de correspondencia en `modelo-relaciones-terminologicas-oftar.md`. La migración aditiva de `relation_type_code VARCHAR(60)` con FK a `os_relation_type` está propuesta y **no ejecutada**. `itemRelations()` mezcla hoy ambos tipos en una sola lista (`CatalogRepository.php:2992-3121`); la separación en `data.relations.clinical` y `data.relations.terminological` es un contrato propuesto (`contratos-api-relaciones-oftar.md`).

**[P]** Las consultas de anatomía/área vía `?anatomy=` o `?clinical_area=` no existen hoy en `api/`; serían un cambio aditivo de capa de lectura, no un cambio de esquema. La API ya expone `clinical_category`/`clinical_category_code` (`CatalogEngineService.php:109-123,196-200`).

### 2.5 Estados editoriales y publicación — valores reales

| Objeto | Estado real verificado | Condición de publicación |
|---|---|---|
| `os_catalog_item_version.review_status` | `NOT NULL DEFAULT 'unknown'`, **sin CHECK** (`04_fase3_columnas.sql:24-37`). `approved` es asignado por los scripts de aprobación OFTAR (`aprobar_preferred_term_oftar_dx.sql:108-112`). | `v_oftar_search_catalog` exige `ver.review_status='approved'` (`oftar_domain_search.sql:77`). |
| `os_concept_mapping.review_status` | `CHECK(draft\|reviewed\|approved\|deprecated)`, default actual `draft` (`fase3_relaciones_mapeos.sql:183-184`). No existen `pending_review` ni `rejected` en el SQL versionado. | La fila debe estar `approved`; además `external_display`/`clinical_rationale` requieren revisión de campo aprobada y hash vigente (`MappingReviewReader.php:10-130`). |
| `os_catalog_relation.review_status` | `CHECK(draft\|reviewed\|approved\|deprecated)`, default `reviewed` (`nomenclador_odontologico_nacional.sql:551-552`). `relation_type` está limitado a los 15 tipos CDT (`:538-545`). | Solo `approved` puede entrar en la superficie pública propuesta `data.relations.clinical`; el rechazo se documenta en gobernanza, nunca como valor de `CHECK`. |
| `os_field_review.review_status` | `DEFAULT 'unknown'`, **sin CHECK** (`01_fase2_tablas.sql:122-137`). | `EditorialEvaluator.php:209-211,308-310` y `CatalogRepository.php:2312-2319` solo aceptan `approved` con hash vigente y scope/release compatible. |
| `os_localized_text.review_status` | `DEFAULT 'unknown'`, **sin CHECK** (`01_fase2_tablas.sql:55-81`). | Igual que `os_field_review`; si no hay contenido aprobado, la API devuelve `null` y `untranslated=true`. |
| `os_catalog_release.status` | `CHECK(draft\|review\|published\|deprecated)`, default `published` (`origen_catalog_engine.sql:49`). | Los endpoints de catálogo exigen release `published` (`CatalogEngineService.php:137,304-305`). |
| `os_catalog_item.status` | `CHECK(active\|retired\|superseded)` (`origen_catalog_engine.sql:67`). | La vista OFTAR exige ítem `active` (`oftar_domain_search.sql:76`). |
| `os_review_state` | Catálogo de referencia con `unknown`, `unreviewed`, `draft`, `in_review`, `reviewed`, `approved`, `published`, `retired`, `obsolete`, `deprecated`; solo `approved`/`published` tienen `is_publication_allowed=TRUE` (`fase1_infraestructura.sql:85-102`). | No es un CHECK de las columnas anteriores ni es leído por la API; sirve como vocabulario de gobernanza. |

**[H]** `v_oftar_search_catalog` filtra `family_code='oftar'`, `product_role='catalog'`, catálogo activo, ítem activo y versión `approved`; prioriza `es-AR` y no inventa traducciones (`oftar_domain_search.sql:45-83`). **`untranslated` es una señal de respuesta, no un valor persistido** (`EditorialEvaluator.php:385-397`). `undet` es una etiqueta de idioma para mapeos, no un estado editorial (`MappingReviewReader.php:92`).

**[H]** Browse Codes no consulta la vista para OFTAR: usa `os_catalog_item`/`os_catalog_item_version` con release `published` y aplica aprobación por campo en PHP (`CatalogRepository.php:82-90,1154-1188,1802-1810,2197-2381`).

---

## 3. Identidad externa: qué se puede guardar hoy

| Dato | Soporte real | Conclusión |
|---|---|---|
| Sistema | `os_catalog_identifier.system_name`, `oftar_external_identity.system_code`, `os_terminology_system` | Sí |
| Código original | `os_catalog_identifier.value`, `code_raw`/`code_normalized` | Sí |
| Descripción original | `external_display`, `os_localized_text.value` | Sí |
| Idioma | `os_catalog_term.language_code`, `source_language_code`, `language_evidence` | Sí |
| Procedencia | `provenance`, `source_reference` en `os_concept_mapping`/`os_localized_text` | Sí |
| Vigencia | `valid_from`/`valid_to`, `active`, `effectiveTime` RF2 | Parcial, según fuente |
| Versión | `os_catalog_release.version_tag`, `os_terminology_system.default_version` | Parcial |
| **Edición** | Solo en texto libre (`source_reference`/`provenance`) | **No estructurado** |
| **Release/fecha** | `os_catalog_release` y RF2 `effectiveTime`, pero no unificado para identidad externa | **Parcial** |

**[I]** El motor ya tiene dos mecanismos complementarios: `os_catalog_identifier` (canónico) y `oftar_external_identity` (normalizado y con dueño). No hace falta una tabla paralela para OFTAR.

**[P] Sin migración:** normalizar `system_name`/`system_code` por edición (`CIE-10-ES`, `ICD-10-CM`), completar `source_reference`, `provenance`, `language_evidence` y usar `os_catalog_release` para la versión.
**[P] Ampliación futura:** metadatos estructurados de `edition/version/release/provenance` en el sistema/release o en una identidad externa versionada, alineados con ambos mecanismos, sin duplicar dueño ni bypass de normalización. Solo si la gobernanza lo aprueba.

---

## 4. Compatibilidad API y frontend — contratos a preservar

**[H]** API: `/health`, `/v1/domains`, `/v1/refsets`, `/v1/search[/{domain}]`, `/v1/catalogs[/{code}/releases|items|items/{item}]`, `/v1/mappings`, `/v1/pricing-units` y rutas de nomencladores/LOINC/PMO/CIE10/ANMAT/odontología (`api/index.php:194-601+`). Envelope `data/meta/request_id`, `Vary: Accept-Language`, `X-Request-Id` (`:143-174`). OpenAPI documenta que `catalogs/*/releases` e `items` pueden devolver 200 vacío, `items/{item}` 404 y `/v1/mappings` sin paginación real con `LIMIT 50` (`docs/api/openapi-3.1.yaml:187-263`).

**[H]** `CatalogEngineService.php:245-527` resuelve idioma y evalúa `meta.field_languages/available_languages/untranslated/dialect_determined`. `MappingReviewReader.php:10-130` publica `external_display`/`clinical_rationale` solo con revisión aprobada vigente y hash coincidente. El detalle de `CatalogEngineService.php:528-628` devuelve `mappings` y `related_codes`, pero no consulta `os_catalog_relation`; la pestaña Relaciones de Browse usa `itemRelations()` y mezcla mapeos con relaciones en una lista con `type`, `role`, `direction` y `result_key` (`CatalogRepository.php:2992-3121`).

**[H]** `TerminologySearchService.php:35-79,417-432,448-453,520-607` incluye `oftar` en dominios y usa `v_oftar_search_catalog`; `DEFAULT_DOMAINS` sigue acotado a `snomed, cie10, anmat`. La respuesta incluye `meta.query/language/domains/.../page_counts/took_ms`.

**[H]** Frontend: `BrowseController.php:15-148` normaliza `q, domain, catalog, family, type, category, status, version, validity, page, limit, tab, rel_view, compare, history` y fragmentos `detail|results`. `BrowseService.php:17-221` y `CatalogRepository.php:20-58,333-506,557-655` aplican whitelists, `MAX_OFFSET=5000`, `MAX_PAGE_SIZE=100` y exclusión mutua `domain` vs `catalog/family`. OFTAR y DENTAR son catálogos publicados admitidos.

**[P] Se puede agregar sin romper:** campos opcionales en `data/meta`, filtros query opcionales ignorables, facets de anatomía/área apoyados en atributos ya presentes y, previo cambio de código aprobado, `data.relations` con `clinical`/`terminological`, filtros `relations`, `relation_type`, `relation_class`, `relation_direction`, `include_unpublished` y `meta.pagination`. `mappings` y `related_codes` se conservan intactos. Detalle en `contratos-api-relaciones-oftar.md`; diseño visual en `diseno-interfaz-consulta-oftar.md`.
**[P] No se puede cambiar sin versionado:** rutas, nombres de parámetros, forma de `result_key`/`catalog_code`/`code`/`term`, semántica 200 vacío frente a 404, paginación de `/v1/mappings` (`LIMIT 50`), defaults de dominios (`oftar` en `DOMAINS`, no en `DEFAULT_DOMAINS`) y gating editorial de `MappingReviewReader`.

---

## 5. Internacionalización real

**[H]** `es-AR` es principal/fallback; `en` parcial; `pt-BR` planificado en la documentación (`auditoria-oftar-actual.md:46,50`; `cobertura-oftar-dx.md:73`). No hay columnas `name_en`/`name_pt`; se usan `os_catalog_term` y `os_localized_text`.

**[H]** `v_oftar_search_catalog` no inventa traducciones: mantiene `en` solo donde la fuente lo tiene. `sync_oftar_dx_to_os.sql:11-21,167-240` crea revisiones pendientes `unknown` para textos faltantes.

**[P]** Regla definitiva: publicar solo términos aprobados por `os_field_review` con hash vigente; los 17 códigos ICD-10-CM exclusivos conservan `en` y se registran como no traducidos, sin inventar `es-AR`.

---

## 6. Generadores, seeds e importadores

**[H]** Artefactos presentes: `tools/generate_nomencladores_oftalmologicos_sql.py`; `sql/03_oftar/importar_nomenclador_oftar_pr.sql`; `sql/03_oftar/sync_oftar_dx_to_os.sql`; `tools/sources/oftalmologico/oftar/importar_cie10_dx.sql`; `aprobar_preferred_term_oftar_dx.sql`; `aprobar_mapeo_nomencladores_oftar.sql`; `diagnostico_api_oftar.sql`; `grant_oftar_search_api.sql`; verificaciones `verificacion_*.sql`. `tests/run.php` contiene aserciones OFTAR en varias secciones.

**[H]** Riesgos confirmados en código: dependencia de privilegios sobre `v_oftar_search_catalog` y tablas de gobernanza; ítems sin versión `approved` no aparecen en búsqueda; importar/sincronizar crea revisiones pendientes que requieren aprobación separada.

**[P] Prohibición vigente:** no ejecutar generadores, seeds, importadores, aprobaciones, sincronizaciones ni scripts de grant en esta etapa. Cualquier ejecución queda para la fase de reconstrucción autorizada.

---

## 7. Verificación de PostgreSQL pendiente — solo lectura

**[P]** El responsable debe ejecutar, con credenciales autorizadas y sin escribir:

```sql
BEGIN READ ONLY;
SELECT current_database(), current_user, version();
SELECT to_regclass('public.os_catalog') AS os_catalog,
       to_regclass('public.os_catalog_item_version') AS os_catalog_item_version,
       to_regclass('public.os_concept_mapping') AS os_concept_mapping,
       to_regclass('public.os_catalog_relation') AS os_catalog_relation,
       to_regclass('public.os_relation_type') AS os_relation_type,
       to_regclass('public.os_field_review') AS os_field_review,
       to_regclass('public.os_localized_text') AS os_localized_text,
       to_regclass('public.os_audit_log') AS os_audit_log,
       to_regclass('public.os_governance_request') AS os_governance_request,
       to_regclass('public.v_oftar_search_catalog') AS v_oftar_search_catalog,
       to_regclass('public.oftar_external_identity') AS oftar_external_identity,
       to_regclass('public.os_oftar_nomenclador_match') AS os_oftar_nomenclador_match;
SELECT catalogo, count(*) FROM public.v_oftar_search_catalog GROUP BY 1 ORDER BY 1;
SELECT review_status, count(*) FROM public.os_concept_mapping GROUP BY 1 ORDER BY 1;
SELECT review_status, count(*) FROM public.os_catalog_relation GROUP BY 1 ORDER BY 1;
SELECT code, name FROM public.os_clinical_category ORDER BY sort_order;
SELECT conname, pg_get_constraintdef(oid) AS check_def
  FROM pg_constraint
 WHERE conrelid IN ('public.os_catalog_item_version'::regclass,
                   'public.os_concept_mapping'::regclass,
                   'public.os_catalog_relation'::regclass,
                   'public.os_localized_text'::regclass,
                   'public.os_field_review'::regclass)
   AND contype = 'c'
 ORDER BY conrelid::regclass::text, conname;
SELECT code, country_code, domain_type, family_code, product_role
  FROM public.os_catalog
 WHERE code IN ('oftar', 'oftar-pr', 'oftar-dx')
 ORDER BY code;
SELECT pg_get_viewdef('public.v_oftar_search_catalog'::regclass, true) AS view_def;
ROLLBACK;
```

**[P]** También verificar con `SELECT` los conteos de `oftar-pr` (154), CAO (143), Regional (136) y `oftar-dx`, y el valor de `target_code` en `os_oftar_nomenclador_match` (H-02). Sin este acta no debe afirmarse estado de producción.

---

## 8. Sin migración frente a ampliación futura

| Necesidad | Sin migración | Ampliación futura |
|---|---|---|
| Documentar contratos y corregir reglas de asignación | Sí | No |
| Cargar dominios de atributos anatómicos y modalidad | Sí, filas en tablas existentes | No |
| Publicar pares revisados con `os_concept_mapping`/`os_field_review` | Sí | No |
| Filtros de navegación aditivos | Sí, capa de servicio | No |
| Identidad externa con `edition/version/release` estructurados | No de forma limpia | Sí, SQL aditivo aprobado |
| Tipos clínicos OFTAR con inversa y vigencia estructurada | Puente `referencia_literal` documentado, sin DDL | Sí: `relation_type_code` + `os_relation_type`, SQL aditivo aprobado |
| Separar clínicas/terminológicas en lectura pública | No: `itemRelations()` mezcla clases | Sí, contrato `data.relations` aprobado y versionado |
| Relaciones multivaluadas nativas para anatomía/área | No de forma limpia | Sí, si no bastan `os_catalog_relation` |
| Cambiar paginación de `/v1/mappings` o defaults de dominios | No | Sí, con versionado de contrato |

---

## 9. Cierre

**[I]** La arquitectura real es compatible con la especificación propuesta: no hace falta motor paralelo y la mayoría de las decisiones se apoyan en tablas y contratos existentes. El riesgo está en la brecha entre intención documentada y estado runtime no verificado.

**[P]** Queda resuelto qué se puede implementar sin DDL y qué requiere ampliación, incluida la distinción entre relaciones clínicas y terminológicas. Queda pendiente el acta de solo lectura de §7, la ratificación de la dirección `broader`/`narrower` y la aprobación de la migración aditiva de `relation_type_code` antes de cualquier reconstrucción de datos.
