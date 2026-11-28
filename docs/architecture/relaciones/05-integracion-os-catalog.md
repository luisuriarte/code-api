# Integración del modelo transversal con `os_catalog`

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** diseño de integración. (No ejecuta DDL ni DML.)

---

## 1. Motor único

**[H]** `os_catalog` es el núcleo canónico: catálogo, release, categoría, ítem, versión, término e identificador (`origen_catalog_engine.sql:12-105`). `os_catalog` tiene `domain_type`, `family_code` y `product_role='family'|'catalog'` (`:12-40`). DENTAR y OFTAR ya están modelados como familias/catálogos dentro de ese motor (`origen_catalog_engine.sql:267-270`; `arquitectura-tecnica-oftar-final.md:48`).

**[P]** El modelo transversal no crea otro motor. Las relaciones se cuelgan de `os_catalog_item(id)` en ambos extremos; las correspondencias cuelgan del mismo ítem hacia `os_terminology_system`.

---

## 2. Resolución de contexto

| Dato | Consulta canónica | Uso |
|---|---|---|
| Catálogo de origen/destino | `os_catalog_item.catalog_id → os_catalog.code` | Filtro y ficha. |
| Familia | `os_catalog.family_code` | Perfil de dominio y agrupación. |
| Dominio | `os_catalog.domain_type` | Reglas de validez; `oftar` es `family_code`, no `domain_type`. |
| Release | `os_catalog_release` vía `source_release_id`/`target_release_id` o versión del ítem | Vigencia y edición. |
| Código permanente | `os_catalog_item.permanent_code` | Identidad estable: `DNT-*`, `OFT-*`. |
| Identificador original | `os_catalog_identifier(system_name, value)` | Código NN/CAO/Regional/CDT sin reescribirlo. |

**[H]** Fase 3 añadió `source_catalog_id`, `target_catalog_id`, `source_release_id`, `target_release_id` a `os_catalog_relation` (`fase3_relaciones_mapeos.sql:63-66`) con FKs a `os_catalog` y `os_catalog_release` (`:91-97`).

**[P]** Estas columnas son opcionales y deben poblarse solo con evidencia. Si están vacías, el contexto se deriva de los ítems; no se inventa release.

---

## 3. Superficies de consulta

**[H]** `v_oftar_search_catalog` filtra `family_code='oftar'`, `product_role='catalog'`, catálogo activo, ítem activo y versión `approved`; no consulta release ni `os_field_review` (`oftar_domain_search.sql:77`; `arquitectura-tecnica-oftar-final.md:103`). **[H]** Browse aplica aprobación por campo en PHP (`CatalogRepository.php:82-90,1154-1188,1802-1810,2197-2381`).

**[P]** La capa de relaciones debe reutilizar esas mismas reglas de visibilidad. Una relación cuya versión o campo no esté aprobado no se publica aunque la fila de relación esté `approved`.

---

## 4. Puente y migración

| Situación | Mecanismo | Límite |
|---|---|---|
| Hoy, sin `relation_type_code` | `relation_type='referencia_literal'`, `source_system_code='<FAMILIA>-CLINICAL'`, `source_field='notes'`, `source_value` ≤20, `context_text` + `provenance` | Transitorio; no sustituye al tipo gobernado. |
| Destino propuesto | `relation_type_code VARCHAR(60)` + FK a `os_relation_type`, con `relation_kind='clinical'` | Migración aditiva no ejecutada; conservar los 15 tipos CDT. |
| Tipos CDT existentes | `relation_type` legado | No reescribir; solo clasificar cuando haya acta. |

**[H]** `os_relation_type` admite `code VARCHAR(60)`, `relation_kind`, `source`, `inverse_code` (`fase1_infraestructura.sql:60-68`). **[P]** Los códigos `REL-*` caben en esa longitud y en `source_value VARCHAR(20)`.

---

## 5. Compatibilidad API/portal

**[H]** `CatalogEngineService` expone `mappings` y `related_codes`, sin relaciones clínicas (`CatalogEngineService.php:528-628`). `itemRelations()` mezcla ambas clases en una lista (`CatalogRepository.php:2992-3121`).

**[P]** La integración es aditiva:

- conservar `mappings` y `related_codes` sin cambios;
- añadir `data.relations` con subclases separadas;
- mantener envelope `data`/`meta`/`request_id`, `Vary: Accept-Language`, defaults y exclusión mutua `domain`/`catalog`/`family`;
- no crear endpoints por familia.

---

## 6. Verificaciones obligatorias antes de cualquier implementación

1. Acta `READ ONLY` de columnas y constraints vigentes de `os_catalog_relation`.
2. Confirmar si Fase 1/Fase 4 están aplicadas en el entorno destino (`os_relation_kind`, `os_review_state`, `os_mapping_metadata`).
3. Confirmar que las relaciones documentadas (333 CDT + 270 Nomenclador) permanecen intactas.
4. Confirmar que no se usan `domain_type='oftar'` ni catálogos `OFTAR-AN/IN/DI`.
5. Confirmar que `DENTAR-PR/DX` y `OFTAR-PR/DX` conservan sus códigos permanentes.

**[P]** Sin esas verificaciones no se afirma compatibilidad con PostgreSQL en ejecución; solo con el SQL versionado y el código leídos.
