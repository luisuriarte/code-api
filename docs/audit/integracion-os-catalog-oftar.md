# Integración de OFTAR con `os_catalog`

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** OFTAR v1.0 — Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada. (No autoriza ejecución.)

**Convención:** `[H]` hecho verificado en repositorio · `[I]` inferencia · `[P]` propuesta.

> Solo documentación: no se ejecutó SQL, no se consultó PostgreSQL y no se modificó ningún objeto. La verificación de base queda para el acta `READ ONLY` (rector §14 / `plan-implementacion-controlada-oftar.md` etapa 1; `arquitectura-tecnica-oftar-final.md` §1).

---

## 1. Cuatro conceptos que no son intercambiables

| Concepto | Definición operativa | Dónde vive | Evidencia |
|---|---|---|---|
| **Dominio funcional de búsqueda** | Etiqueta de la API para filtrar el buscador unificado: `DOMAIN_OFTAR='oftar'`. Está en `DOMAINS`, **no** en `DEFAULT_DOMAINS`, y se enlaza a `v_oftar_search_catalog`. | PHP + vista; `os_domain_registry` solo registra el dominio expuesto, la API no lo usa como fuente de verdad. | `TerminologySearchService.php:49,52-68,76-80,417-432`; `oftar_domain_search.sql:27-37` |
| **Familia** | Marca paraguas `code='oftar'`, `family_code=NULL`, `product_role='family'`; sus productos declaran `family_code='oftar'`. Tabla de dominio `oftar_catalog` registra los dos productos editoriales. | `os_catalog` + `oftar_catalog`. | `oftar_core.sql:138-156`; `oftar_family.sql:54-64` |
| **`product_role`** | Eje **estructural** del catálogo: `family` (paraguas) o `catalog` (producto). La vista de búsqueda exige `catalog`. | `os_catalog.product_role`. | `origen_catalog_engine.sql:20,33-40`; `oftar_domain_search.sql:70` |
| **`domain_type`** | Eje **temático** del catálogo, con CHECK cerrado. OFTAR se declara `medical`; **`oftar` no es un valor admitido**. | `os_catalog.domain_type`. | `origen_catalog_engine.sql:18` |

**[H]** Los tres registros canónicos de `os_catalog` (`oftar_core.sql:142-150`):

| `code` | `domain_type` | `family_code` | `product_role` | `short_name` | Uso |
|---|---|---|---|---|---|
| `oftar` | `medical` | `NULL` | `family` | `OFTAR` | Marca paraguas; sin códigos ni releases propios. |
| `oftar-pr` | `medical` | `oftar` | `catalog` | `OFTAR-PR` | Procedimientos; prefijo `OFT-PR`; único con UVR. |
| `oftar-dx` | `medical` | `oftar` | `catalog` | `OFT-DX` | Diagnósticos; prefijo `OFT-DX`; sin UVR. |

**[H]** `oftar_family.sql:57-64` completa la identidad editorial: `concept_kind='procedure'` para `oftar-pr` y `'diagnosis'` para `oftar-dx`. **[I]** `domain_type` y `product_role` responden preguntas distintas: cambiar uno no autoriza cambiar el otro.

---

## 2. Catálogos de origen: familia sí, producto editorial no

**[H]** `nomenclador_oftalmologico_cao.sql:230-252` y `nomenclador_oftalmologico_regional.sql:223-245` registran `NOM-CAO-AR` y `NOM-OFTAL-REG` con `domain_type='medical'`, `family_code='oftar'`, `product_role='catalog'` y release de origen `published`. Conservan su numeración y descripción originales y alimentan propuestas de conciliación (`nomencladores_oftar_mapping.sql:38-55`).

**[H]** No son dominios funcionales nuevos, no están en `oftar_catalog` (que solo declara `oftar-pr` y `oftar-dx`) y no deben convertirse en `oftar-pr` ni presentarse con prefijo `OFT-PR-`/`OFT-DX-` (rector §1 y §4; `politica-identificacion-oftar-final.md` §2).

**[I]** Como la vista filtra por familia + rol + `is_active`, un catálogo de origen con versión `approved` también podría aparecer en `/v1/search?domains=oftar`. **[P]** No promoverlos a producto editorial; si se decide excluirlos de la vista, hacerlo por código explícito en la vista y con aprobación, **no** inventando un `domain_type` ni un rol nuevos. Verificar el hecho en producción con §7.3.

---

## 3. Cumplimiento del patrón DENTAR

| Patrón DENTAR | Aplicación en OFTAR | Estado |
|---|---|---|
| Familia `family` con `family_code=NULL`; productos `catalog` con `family_code='dentar'` (`docs/dentar/README.md:32-34`) | Familia `oftar` y productos `oftar-pr`/`oftar-dx` con `family_code='oftar'`. | **[H]** |
| Prefijos propios y estables por producto | `OFT-PR-NNNNNN` / `OFT-DX-NNNNNN` (`oftar_family.sql:57-64`). | **[H]** |
| Catálogos de origen con numeración secundaria | CAO y Regional conservan su numeración; la visible es la de OFTAR-PR. | **[H]/[P]** según rector §4. |
| CHECK cerrado de `domain_type` y `product_role` | Sin ampliación: `domain_type` sigue con siete valores y `product_role` con dos. | **[H]** `origen_catalog_engine.sql:18,33-40`. |

**[H]** El generador coincide con el DDL manual (`tools/generate_unified_catalog_engine_sql.py:360-365`). **[P]** Cualquier valor nuevo en esos CHECK exige migración aprobada y acta previa; este documento no propone ninguno. OFTAR no crea catálogos AN/CL/NOM-CAO-equivalentes como productos nuevos.

---

## 4. Campos canónicos OFTAR → tablas reales

| Campo canónico | Tabla/columna real | Regla verificada |
|---|---|---|
| Código permanente | `os_catalog_item.permanent_code` (`:66`) | Inmutable; `UNIQUE(catalog_id, permanent_code)`; prefijos `OFT-PR`/`OFT-DX`. El código **visible** puede ser `os_catalog_identifier.value` con `is_primary=TRUE` (`oftar_domain_search.sql:50-57`). |
| Término preferido / sinónimos | `os_catalog_item_version.preferred_term`, `os_catalog_term.term` | `term_type CHECK(preferred\|synonym\|acronym\|search_variant)`, `language_code DEFAULT 'es-AR'` (`origen_catalog_engine.sql:84-90`). Aprobación por campo con hash; sin `lay_term` ni `abbreviation` como columnas: las siglas son `term_type='acronym'` y `lay_terms TEXT` vive en la versión (`04_fase3_columnas.sql:36`). |
| Identificador externo | `os_catalog_identifier(system_name, value, is_primary)` | `UNIQUE(item_id, system_name, value)` (`:92-99`). Edición/versión/release/procedencia se rigen por `politica-identificacion-oftar-final.md`; `oftar_external_identity` guarda identidad cruda/normalizada. |
| Mapeo | `os_concept_mapping(mapping_type, relationship_role, external_code, clinical_rationale, review_status)` | `mapping_type CHECK(equivalent\|narrower\|broader\|related\|unmatched)`, `relationship_role CHECK(procedure_concept\|justifying_diagnosis\|observation_concept\|substance_concept)`, `review_status CHECK(draft\|reviewed\|approved\|deprecated)` (`origen_catalog_engine.sql:119-133`; generador `:360-365`). **[H]** El rector §7 y la arquitectura ya usan el vocabulario real: `exact`/`no_map`/`reference` **no existen** en el `CHECK` y no deben persistirse; la equivalencia se registra como `equivalent` y la ausencia de correspondencia como `unmatched`. |
| Atributos (estructura, modalidad, lateralidad) | Códigos en `oftar_attribute_definition` (`ATTR-STRUCTURE`, `ATTR-MODALITY`, `ATTR-LATERALITY`), no columnas (`oftar_core.sql:257-274`; rector §6) | `ANAT-*` y `AREA-*` aún no sembrados en SQL; `category` + `clinical_category` son ejes distintos (`os_catalog_item_version.category_id`, `os_catalog_item_clinical_category`). |
| Relación clínica | `os_catalog_relation(source_item_id, target_item_id, relation_type, source_system_code, source_field, source_value, context_text, review_status, provenance)` | **[H]** `nomenclador_odontologico_nacional.sql:534-559`: `relation_type` solo 15 tipos CDT, `source_value VARCHAR(20)`, `review_status draft\|reviewed\|approved\|deprecated`, `UNIQUE` de 7 columnas, sin self-relations. **[P]** Las relaciones OFTAR se modelan aquí con el puente `referencia_literal` o con `relation_type_code` aditivo; **nunca** en `os_concept_mapping`. Detalle en `modelo-relaciones-clinicas-oftar.md`. |
| Relación terminológica | `os_concept_mapping` + `os_mapping_metadata` | **[H]** `mapping_type CHECK(equivalent\|narrower\|broader\|related\|unmatched)`; la metadatos aporta `mapping_nature`, edición/versión y vigencia (`fase3_relaciones_mapeos.sql:115-148`). **[P]** Solo para sistemas externos; no PR↔DX. Detalle en `modelo-relaciones-terminologicas-oftar.md` e `integracion-os-concept-mapping-oftar.md`. |
| Gobernanza | `os_field_review`, `os_localized_text`, `os_review_state`, `os_audit_log`, `os_catalog_apply_governed_change` | Aprobación por campo con `content_hash` vigente y dos revisiones; `os_review_state` es vocabulario, **no** CHECK ni fuente leída por la API (`fase1_infraestructura.sql:85-102`). Detalle en `matriz-estados-publicacion-oftar.md`. |

**[H]** La API pasa `mapping_type` sin interpretarlo como `equivalence` (`CatalogEngineService.php:612,708`; `CatalogRepository.php:3055`): el frontend no debe inferir semántica clínica de ese campo.

---

## 5. Lo que NO existe

- **[H]** `domain_type='oftar'`: el CHECK admite solo `dental|medical|biochemical|rehabilitation|mental_health|pharma|terminology` (`origen_catalog_engine.sql:18`).
- **[H]** Dominios funcionales `oftar-pr` u `oftar-dx`: solo existe `oftar` en `DOMAINS` (`TerminologySearchService.php:49,67`). PR/DX son **códigos de catálogo**.
- **[H]** Catálogos `OFTAR-AN`, `OFTAR-IN`, `OFTAR-DI`: no están en `oftar_core.sql:142-150` ni en `oftar_family.sql:57-64`; los prefijos son `OFT-PR`/`OFT-DX`, nunca `OFTAR-PR-`/`OFTAR-DX-`.
- **[H]** Columnas `anatomy` ni `clinical_area`: la anatomía y el área se expresan con atributos/categorías/relaciones, no con columnas; el rector §6 prevé navegación `?anatomy=&clinical_area=` como aditiva y no implementada.
- **[H]** Columna `is_billable` en ningún SQL; tampoco `is_current` en `os_localized_text` (`01_fase2_tablas.sql:55-81`). La valorización vive en `os_fee_*`/`os_pricing_unit`, no en la versión.
- **[H]** En `os_concept_mapping` no existen `exact`, `no_map`, `reference`, `pending_review` ni `rejected`. `rejected` existe solo en `os_oftar_nomenclador_match.review_status CHECK(proposed|approved|rejected)` (`nomencladores_oftar_mapping.sql:45-46`), tabla de propuestas de conciliación.
- **[H]** En `os_catalog_term` no hay columnas `lay_term` ni `abbreviation`; `term_type` usa `acronym` (`origen_catalog_engine.sql:84-90`). `undet`/`undetermined` es evidencia de idioma, no un estado de revisión.
- **[H]** `v_oftar_search_catalog` no consulta `os_catalog_release` ni `os_field_review`; valorar `'approved'` solo en la versión (`oftar_domain_search.sql:66-80`).

**[H]** Las discrepancias históricas (`is_billable`, `lay_term`/`abbreviation` y `exact|no_map|reference`) ya fueron corregidas en el rector §7, en `arquitectura-tecnica-oftar-final.md` §2.1 y en `modelo-funcional-canonico-oftar.md` §4; prevalece lo verificado conforme al rector §0. El detalle está en `inconsistencias-resueltas-oftar.md`.

---

## 6. Reglas de compatibilidad API y frontend

**[H]** Conservar sin cambios: rutas `/v1/*`, envelope `data/meta/request_id`, `Vary: Accept-Language`, semántica 200 vacío frente a 404, paginación documentada de `/v1/mappings`, `DEFAULT_DOMAINS` y la exclusión mutua `domain`/`catalog`/`family` en Browse (rector §13).

**[H]** `oftar` debe solicitarse explícitamente (`domains=oftar` o `domains=all`) porque no está en los dominios por defecto; el buscador usa la vista con `GRANT SELECT` y expone `catalog_code`, `permanent_code`, `family_code`, `category`, `language_code` y `review_status` como metadatos (`TerminologySearchService.php:417-432`; `oftar_domain_search.sql:88-94`).

**[P]** Solo cambios aditivos: campos opcionales en `data/meta`, filtros query ignorables y facets de anatomía/área apoyados en atributos existentes; si no hay atributos cargados, API y frontend siguen funcionando con el facet histórico. Mantener `category` y agregar `clinical_category` sin reinterpretar `mapping_type`; no crear dominios nuevos ni exponer catálogos de origen como productos OFTAR.

**[P]** El detalle actual de API devuelve `mappings` y `related_codes`, sin exponer `os_catalog_relation` (`CatalogEngineService.php:528-628`), y Browse mezcla mapeos con relaciones en `itemRelations()` (`CatalogRepository.php:2992-3121`). El contrato propuesto `data.relations` separa `clinical` y `terminological`, conserva los campos actuales y filtra en público solo filas `approved`; la ficha distingue visualmente ambas clases y agrupa los códigos en ocho sistemas. No implementado. Ver `contratos-api-relaciones-oftar.md` y `diseno-interfaz-consulta-oftar.md`.

---

## 7. Consultas READ ONLY de verificación

> Solo `SELECT`, en sesión de solo lectura. No ejecutadas en este trabajo.

**7.1 Registros y CHECK de `os_catalog`**

```sql
SELECT code, domain_type, family_code, product_role, short_name, is_active
FROM os_catalog
WHERE code IN ('oftar','oftar-pr','oftar-dx','nomenclador-oftalmologico-cao-ar',
               'nomenclador-oftalmologico-regional-ar')
ORDER BY code;

SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'public.os_catalog'::regclass AND contype = 'c'
ORDER BY conname;
```

**7.2 Catálogos de la familia y prefijos reales**

```sql
SELECT c.code, c.domain_type, c.family_code, c.product_role,
       f.code_prefix, f.concept_kind
FROM os_catalog c
LEFT JOIN oftar_catalog f ON f.code = c.code
WHERE c.family_code = 'oftar' OR c.code = 'oftar'
ORDER BY c.code;
-- Toda fila con family_code='oftar' y code_prefix IS NULL es catálogo de origen, no producto editorial.
```

**7.3 Vista, dominio y ausencia de release en el filtro**

```sql
SELECT pg_get_viewdef('public.v_oftar_search_catalog'::regclass, true);

SELECT catalogo, count(*) AS filas,
       count(*) FILTER (WHERE estado_revision <> 'approved') AS no_aprobadas
FROM v_oftar_search_catalog GROUP BY 1 ORDER BY 1;

SELECT code, description FROM os_domain_registry WHERE code = 'oftar';
-- La API no usa os_domain_registry como fuente de verdad: cotejar con TerminologySearchService.php.
```

**7.4 Tipos y estados persistidos en mapeos**

```sql
SELECT mapping_type, relationship_role, review_status, count(*) AS filas
FROM os_concept_mapping GROUP BY 1,2,3 ORDER BY 1,2,3;

SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'public.os_concept_mapping'::regclass AND contype = 'c'
ORDER BY conname;
```

**7.5 Relaciones clínicas y tipo de relación real**

```sql
SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'public.os_catalog_relation'::regclass AND contype IN ('c','u')
ORDER BY conname;

SELECT review_status, count(*) AS filas
FROM os_catalog_relation GROUP BY 1 ORDER BY 1;

SELECT code, relation_kind, inverse_code
FROM os_relation_type
WHERE source = 'OFTAR-v1.0'
ORDER BY code;
-- Antes de la migración aditiva aprobada, la última consulta debe devolver 0 filas.
```

**7.6 Columnas que NO deben existir**

```sql
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name IN ('is_billable','is_current','anatomy','clinical_area','lay_term','abbreviation')
  AND table_name IN ('os_catalog_item_version','os_catalog_term','os_localized_text',
                     'os_catalog_item','os_concept_mapping')
ORDER BY 1, 2;
-- Resultado esperado: 0 filas (lay_terms TEXT en la versión no es la columna lay_term).
```

**7.7 Coincidencia con el generador**

```sql
-- Comparar fuera de base: tools/generate_unified_catalog_engine_sql.py:360-365
-- contra pg_get_constraintdef(oid) de os_concept_mapping y contra
-- sql/02_catalogs/origen_catalog_engine.sql:18,20,33-40,119-133.
```

---

## 8. Decisión [P]: no crear motor paralelo

**[P]** OFTAR se integra **dentro de `os_catalog`**: un ítem por concepto, una versión por release/idioma, identificadores en `os_catalog_identifier`, relaciones clínicas en `os_catalog_relation`, correspondencias terminológicas en `os_concept_mapping` y revisión en `os_field_review`/`os_localized_text`. Las tablas `oftar_*` son extensiones de dominio (identidad, catálogos, atributos), **no** un segundo motor ni un duplicado de catálogos publicables. No se crearán tablas paralelas de ítems, de relaciones ni catálogos `OFTAR-AN/IN/DI`.

**[P]** Toda escritura futura pasa por gobernanza con dos revisiones y traza en `os_audit_log` (rector §1 y §12); ninguna de esas acciones está autorizada por este documento. La etapa 1 (`READ ONLY`) debe preceder a cualquier implementación; `matriz-estados-publicacion-oftar.md` §7 comparte las verificaciones de estados.

---

## 9. Referencias

- `especificacion-definitiva-reconstruccion-oftar.md` §0 (prevalencia), §1, §4, §6, §7 y §13.
- `politica-identificacion-oftar-final.md` (identidad externa por edición/release) y `modelo-funcional-canonico-oftar.md` §2 (campos canónicos).
- `taxonomia-oftar-final.md` y `clasificacion-anatomica-oftar-final.md` (propuestas funcionales aún no persistidas).
- `matriz-estados-publicacion-oftar.md` (seis estados, transiciones y superficies de publicación).
- `modelo-relaciones-clinicas-oftar.md`, `modelo-relaciones-terminologicas-oftar.md`, `diccionario-tipos-relacion-oftar.md`, `integracion-os-concept-mapping-oftar.md`, `modelo-trazabilidad-versionado-oftar.md` y `plan-pruebas-oftar.md` (modelo integral y verificación).
