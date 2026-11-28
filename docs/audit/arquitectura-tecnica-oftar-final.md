# Arquitectura técnica definitiva de OFTAR

**Fecha:** 2026-11-28
**Etapa:** tercera revisión — verificación de la arquitectura real.
**Estado:** análisis documentado. **No se ejecutaron migraciones, importadores, seeds ni sentencias de escritura.**
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
| `os_catalog_item_version` | FK ítem/release/categoría, `preferred_term`, `definition`, `clinical_criteria`, `is_billable`, `review_status CHECK(draft\|review\|published\|deprecated)`, `UNIQUE(item_id, release_id)` | 72-82 |
| `os_catalog_term` | FK versión, `term`, `term_type CHECK(synonym\|lay_term\|abbreviation)`, `language_code DEFAULT 'es'` | 84-90 |
| `os_catalog_identifier` | FK ítem, `system_name`, `value`, `is_primary`, `UNIQUE(item_id, system_name, value)` | 92-98 |
| `os_concept_mapping` | FK ítem/sistema, `external_code`, `external_display`, `mapping_type CHECK(exact\|narrower\|broader\|related\|no_map\|reference)`, `relationship_role`, `provenance`, `source_reference`, `review_status CHECK(draft\|pending_review\|approved\|rejected)`, `language_evidence`, `UNIQUE(item_id, terminology_system_id, external_code)` | 119-134 |

**[H] Corrección necesaria:** el valor real para equivalencia es `exact`, no `equivalent`. Los documentos de trabajo que usaron `equivalent` deben leerse como intención, no como valor persistible. La especificación definitiva usa `exact`.

### 2.2 Internacionalización y gobernanza

**[H]** `sql/07_multilingue/01_fase2_tablas.sql:18-96,122+` crea `os_language`, `os_language_alias`, `os_catalog_language` (PK compuesta `catalog_id, language_code`, flags default/fallback/bridge, `coverage_status`), `os_localized_text` (`entity_type/entity_id/field_name`, `value`, `source_language_code`, `language_evidence`, `provenance`, `content_hash`, `scope_release_id`, `is_current`) y `os_field_review`.

**[H]** `sql/08_arquitectura/fase3_i18n.sql:1-93` activa D-31 con funciones/triggers y siembra `os_catalog_language` de forma idempotente; no reejecuta fases 01–15.

**[H]** `sql/08_arquitectura/fase4_gobernanza.sql:26-147,205-283` crea `os_governance_request`, `os_governance_review/decision` y `os_audit_log` **append-only** con trigger `trg_os_audit_log_immutable` que impide UPDATE/DELETE. `catalogos_gestion_gobernada.sql:48-311` define `os_catalog_apply_governed_change(BIGINT,BIGINT,TEXT)` SECURITY DEFINER, valida revisión/evidencia/estado y audita.

**[H]** `sql/08_arquitectura/categorias_clinicas.sql:12-29` crea `os_clinical_category` (`code` PK, `name`, `definition`, `examples`, `sort_order`, `status CHECK(active|inactive)`), aditiva; no renombra `os_catalog_category`.

### 2.3 OFTAR

**[H]** `sql/03_oftar/oftar_core.sql:45-104,490-539` crea `oftar_catalog`, versionado, categorías, sistemas terminológicos, atributos, reglas/mapeos/diagnósticos y la vista `v_oftar_family_concept`.

**[H]** `sql/03_oftar/oftar_external_identity.sql:62-92,210-214` crea `oftar_external_identity` con `system_code`, `code_raw`, `code_normalized`, `owner_catalog CHECK(oftar-pr|oftar-dx|shared)`, `entity_kind`, `UNIQUE(system_code, code_normalized)` e índices/triggers de vinculación.

**[H]** `sql/03_oftar/oftar_domain_search.sql:45-120` crea `v_oftar_search_catalog`: `DISTINCT ON (item.id)`, familia `oftar`, `product_role='catalog'`, catálogo e ítem activos, versión `review_status='approved'`. Prioriza `es-AR` y conserva `en` solo cuando existe en fuente. Expone `id, activo, snomed_concept_id, codigo, termino, subtitulo, catalogo, codigo_permanente, familia, categoria, idioma, estado_revision`.

**[H]** `sql/03_oftar/importar_nomenclador_oftar_pr.sql:123-332`, `sync_oftar_dx_to_os.sql:60-240` y `nomencladores_oftar_mapping.sql` proyectan OFTAR al motor y crean `os_field_review` pendiente. `aprobar_preferred_term_oftar_dx.sql` y `aprobar_mapeo_nomencladores_oftar.sql` son aprobaciones separadas por hash/actor.

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

**[H]** `CatalogEngineService.php:245-527` resuelve idioma y evalúa `meta.field_languages/available_languages/untranslated/dialect_determined`. `MappingReviewReader.php:10-130` publica `external_display`/`clinical_rationale` solo con revisión aprobada vigente y hash coincidente.

**[H]** `TerminologySearchService.php:35-79,417-432,448-453,520-607` incluye `oftar` en dominios y usa `v_oftar_search_catalog`; `DEFAULT_DOMAINS` sigue acotado a `snomed, cie10, anmat`. La respuesta incluye `meta.query/language/domains/.../page_counts/took_ms`.

**[H]** Frontend: `BrowseController.php:15-148` normaliza `q, domain, catalog, family, type, category, status, version, validity, page, limit, tab, rel_view, compare, history` y fragmentos `detail|results`. `BrowseService.php:17-221` y `CatalogRepository.php:20-58,333-506,557-655` aplican whitelists, `MAX_OFFSET=5000`, `MAX_PAGE_SIZE=100` y exclusión mutua `domain` vs `catalog/family`. OFTAR y DENTAR son catálogos publicados admitidos.

**[P] Se puede agregar sin romper:** campos opcionales en `data/meta`, filtros query opcionales ignorables, facets de anatomía/área apoyados en atributos ya presentes.
**[P] No se puede cambiar sin versionado:** rutas, nombres de parámetros, forma de `result_key`/`catalog_code`/`code`/`term`, semántica 200 vacío frente a 404, paginación de `/v1/mappings`, defaults de dominios y gating editorial de `MappingReviewReader`.

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
       to_regclass('public.os_field_review') AS os_field_review,
       to_regclass('public.os_localized_text') AS os_localized_text,
       to_regclass('public.os_audit_log') AS os_audit_log,
       to_regclass('public.os_governance_request') AS os_governance_request,
       to_regclass('public.v_oftar_search_catalog') AS v_oftar_search_catalog,
       to_regclass('public.oftar_external_identity') AS oftar_external_identity,
       to_regclass('public.os_oftar_nomenclador_match') AS os_oftar_nomenclador_match;
SELECT catalogo, count(*) FROM public.v_oftar_search_catalog GROUP BY 1 ORDER BY 1;
SELECT review_status, count(*) FROM public.os_concept_mapping GROUP BY 1 ORDER BY 1;
SELECT code, name FROM public.os_clinical_category ORDER BY sort_order;
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
| Relaciones multivaluadas nativas para anatomía/área | No de forma limpia | Sí, si no bastan `os_catalog_relation` |
| Cambiar paginación de `/v1/mappings` o defaults de dominios | No | Sí, con versionado de contrato |

---

## 9. Cierre

**[I]** La arquitectura real es compatible con la especificación propuesta: no hace falta motor paralelo y la mayoría de las decisiones se apoyan en tablas y contratos existentes. El riesgo está en la brecha entre intención documentada y estado runtime no verificado.

**[P]** Queda resuelto qué se puede implementar sin DDL y qué requiere ampliación. Queda pendiente el acta de solo lectura de §7 antes de cualquier reconstrucción de datos.
