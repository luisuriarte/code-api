# Matriz de estados y publicación de OFTAR

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** Aprobada como base técnica para iniciar la implementación controlada (no autoriza ejecución).

**Convención:** `[H]` hecho verificado en repositorio · `[I]` inferencia · `[P]` propuesta.

> Alcance exclusivamente documental: no se ejecutó SQL ni se consultó PostgreSQL (no hay `psql` ni variables `DB_*`/`PG*`). El estado runtime queda pendiente del acta `READ ONLY` prevista en el rector §14 / `plan-implementacion-controlada-oftar.md` etapa 1 y en `arquitectura-tecnica-oftar-final.md` §1.

---

## 1. Cinco objetos, cinco estados distintos

**[H]** Los valores se leen del DDL versionado; no se asume comportamiento de base.

| Objeto (columna exacta) | Valores admitidos | Default | CHECK | Significado y evidencia |
|---|---|---|---|---|
| **Versión de concepto** — `os_catalog_item_version.review_status` | `unknown` (default) y `approved` (asignado por script). El DDL no restringe el contenido: técnicamente admite cualquier `VARCHAR(20)`. | `unknown` | **No** (`sql/07_multilingue/04_fase3_columnas.sql:27`) | Aprobación **técnica/de gobernanza** de la versión; la vista OFTAR exige `='approved'` (`oftar_domain_search.sql:77`). **No equivale a aprobación clínica con firma profesional.** **`draft\|review\|published\|deprecated` NO son de aquí**: pertenecen a `os_catalog_release.status` (`origen_catalog_engine.sql:49`). |
| **Mapeo** — `os_concept_mapping.review_status` | `draft\|reviewed\|approved\|deprecated`. **No existen** `pending_review` ni `rejected` en esta tabla. | `approved` en el DDL original (`:130`); `draft` para inserciones futuras (`fase3_relaciones_mapeos.sql:183-184`, que **no** altera filas ni CHECK) | **Sí** (`origen_catalog_engine.sql:130`; coincides `tools/generate_unified_catalog_engine_sql.py:365`) | Estado de la correspondencia. `approved` de la fila no basta para publicar texto externo: se requiere revisión de campo vigente. |
| **Texto localizado / traducción** — `os_localized_text.review_status` (y `os_catalog_term.review_status`, `04_fase3_columnas.sql:45`) | `unknown` (default) y `approved` (exigido por los evaluadores); sin lista cerrada. | `unknown` | **No** (`01_fase2_tablas.sql:70`) | Revisión editorial por idioma/campo. `content_hash` es `NOT NULL`; `scope_release_id` con `ON DELETE RESTRICT`; **no existe `is_current`** (`:55-81`). `undet`/`undetermined` es evidencia de idioma, **no** un estado. |
| **Revisión de campo** — `os_field_review.review_status` | `unknown` (default) y `approved` (exigido); sin lista cerrada. | `unknown` | **No** (`01_fase2_tablas.sql:122-137`) | Aprobación granular de `preferred_term`, `definition`, `external_display`, etc. `content_hash NOT NULL`, `reviewed_by`, `reviewed_at`. Es la fuente que consultan los evaluadores. |
| **Publicación de catálogo** — `os_catalog_release.status` + `os_catalog_item.status` (con `os_catalog.is_active`) | Release: `draft\|review\|published\|deprecated`. Ítems: `active\|retired\|superseded`. | Release **`published`**; ítem `active`; catálogo `TRUE` | **Sí** en release (`:49`) e ítem (`:67`) | Visibilidad técnica. `product_role CHECK(family\|catalog)` en `:20,33-40` es otro eje, no un estado. |

**[H]** `os_review_state` contiene `unknown`, `unreviewed`, `draft`, `in_review`, `reviewed`, `approved`, `published`, `retired`, `obsolete`, `deprecated`, con `is_publication_allowed=TRUE` solo para `approved` y `published` (`fase1_infraestructura.sql:85-102`). **No es CHECK de columnas y la API no lo lee**: es vocabulario de gobernanza.

**[H]** `rejected` sí existe, pero solo en `os_oftar_nomenclador_match.review_status CHECK(proposed|approved|rejected)` (`nomencladores_oftar_mapping.sql:45-46`): tabla de **propuestas de conciliación**, no revisión de conceptos ni de mapeos.

---

## 2. Transiciones por objeto

| Objeto | Origen → destino | Condición | Quién puede hacerlo | Efecto en búsqueda |
|---|---|---|---|---|
| Versión | `unknown` → `approved` | Fila en `os_field_review` aprobada para `preferred_term`, mismo `language_code` y `scope_release_id` (`aprobar_preferred_term_oftar_dx.sql:100-112`); **[P]** dos revisores según rector §9.2. | Comité/gobernanza mediante script revisado; no acción de API pública. | La versión entra en `v_oftar_search_catalog` si cumple además familia/ítem activo. |
| Versión | `approved` → invalidación **[I]** | Cambio de contenido: triggers de `05_fase3_triggers.sql` (rector §9.2); el valor destino exacto se confirma en el acta. | Sistema (trigger). | Sale de la vista al dejar de ser `approved`. |
| Mapeo | `approved` → `draft` (solo default) | `fase3_relaciones_mapeos.sql:183-184` cambia el default de **inserciones futuras**; no modifica filas existentes. | DDL de arquitectura (fuera de este trabajo). | Las filas nuevas no son elegibles hasta aprobación; las antiguas conservan `approved`. |
| Mapeo | `draft` → `reviewed` → `approved` | Evidencia, hash vigente y **[P]** dos revisiones (rector §9.2). | Comité/gobernanza. | Necesario pero **no suficiente**: `/v1/mappings` exige además revisión de campo de `external_display`/`clinical_rationale`. |
| Mapeo | `approved` → `deprecated`; rechazo → **sin transición** | Retiro gobernado. El rechazo se documenta en gobernanza; la fila conserva su estado técnico (rector §9.1), porque `rejected` no es valor de esta tabla. | Comité. | Deja de publicarse. No inventar `rejected`/`pending_review` aquí. |
| Texto localizado | `unknown` → `approved` | Revisión aprobada, `content_hash` vigente y `scope_release_id` compatible (`EditorialEvaluator.php`, `FieldReviewRepository.php:176-224`). | Revisores/gobernanza. | Texto visible en API; sin ello, `null` + `untranslated=true`. |
| Texto localizado | `approved` → invalidado **[I]** | Cambio de contenido (`05_fase3_triggers.sql`); sin `is_current`, la vigencia se resuelve por hash + scope. | Sistema (trigger). | Deja de publicarse. |
| Revisión de campo | `unknown` → `approved` | `source_reference`, hash vigente y dos revisiones humanas; se registran `reviewed_by`/`reviewed_at`. | Revisores/gobernanza. | Habilita `preferred_term` en la vista vía script y el resto de campos en API/Browse. |
| Revisión de campo | `approved` → invalidado **[I]** | Cambio del contenido revisado. | Sistema (trigger). | Texto y campo dejan de publicarse. |
| Publicación | Release `draft` → `review` → `published` → `deprecated`; ítem `active` → `retired`/`superseded` | CHECK de `origen_catalog_engine.sql:49,67`; **default de release es `published`**. | Responsable de release/gobernanza. | `/v1/catalogs/{code}/items` y Browse exigen release `published` + ítem `active`; la vista OFTAR **no** consulta release. |
| Publicación | Release publicado ⇏ aprobar versión ni campo **[I]** | Son capas independientes; no hay disparador que por publicar el release apruebe contenido. | — | Publicar sin aprobación produce ítems sin texto en búsqueda/API, no un fallback. |

---

## 3. Qué significa «publicado» por superficie

| Superficie | Condición exacta | Matiz |
|---|---|---|
| `/v1/search?domains=oftar` | Fila en `v_oftar_search_catalog` + solicitud explícita del dominio: `DOMAIN_OFTAR` está en `DOMAINS`, **no** en `DEFAULT_DOMAINS` (`TerminologySearchService.php:49,52-68,76-80,417-432`), y el rol consultor tiene `GRANT SELECT` sobre la vista (`oftar_domain_search.sql:88-94`). | La vista **no** hace JOIN con `os_catalog_release`; la búsqueda no exige release publicado. |
| `/v1/catalogs/{code}/items` | `rel.status='published'` e `item.status='active'` (`CatalogEngineService.php:126-146`). | El listado **no filtra** `ver.review_status`; el detalle sí aplica evaluación editorial por campo. |
| Texto en API | Candidato `approved`, revisión de campo aprobada, scope compatible y hash vigente (`EditorialEvaluator.php`, `FieldReviewRepository.php`). | Sin contenido aprobado: `null` + `untranslated=true`; `undet` es etiqueta de idioma, no estado. |
| `/v1/mappings` | Release `published` + revisión de campo vigente para `external_display`/`clinical_rationale` (`MappingReviewReader.php`). | El `approved` de la fila no basta. `mapping_type` se pasa sin interpretarlo como `equivalence` (`CatalogEngineService.php:612,708`; `CatalogRepository.php:3055`). |
| Browse Codes | No usa la vista OFTAR: consulta ítems/versiones con release `published` y aplica aprobación por campo en PHP (`CatalogRepository.php:2197-2381`). | Comportamiento independiente de `/v1/search`; no compartir supuestos entre ambas superficies. |

---

## 4. Condiciones exactas para aparecer en búsqueda pública OFTAR

**[H]** `v_oftar_search_catalog` (`oftar_domain_search.sql:45-80`) exige simultáneamente:

1. `cat.family_code = 'oftar'` **y** `cat.product_role = 'catalog'` **y** `cat.is_active = TRUE`.
2. `item.status = 'active'`.
3. `ver.review_status = 'approved'`.
4. `DISTINCT ON (item.id)` con prioridad `es-AR` y luego `ver.id ASC`: un ítem, una sola fila; los huecos idiomáticos conservan `en` sin inventar traducción.
5. `codigo = COALESCE(identificador con `is_primary=TRUE`, `item.permanent_code`)`; se exponen `catalogo`, `codigo_permanente`, `familia`, `categoria`, `idioma` y `estado_revision = ver.review_status`.

**[I]** La vista no consulta `os_field_review` ni `os_catalog_release`: la garantía de que el texto aprobado provenga de revisión de campo depende del script de aprobación, no de la vista. **[H]** El valor `approved` **sí es asignado por los scripts** (`aprobar_preferred_term_oftar_dx.sql:108-112`) aunque la columna no tenga CHECK; por tanto el filtro de la vista es válido. **[H]** El error estaba en la documentación que atribuía a la **versión** los valores `draft|review|published|deprecated`, que son de **release** (`arquitectura-tecnica-oftar-final.md` §2.1; corregido en el rector §9.1).

---

## 5. Regla de no mezclar

| Capa | Se mide en | No implica |
|---|---|---|
| Aprobación de versión (técnica; no clínica) | `os_catalog_item_version.review_status` (`approved`) | Que el release esté publicado, que cada campo tenga revisión vigente ni que exista firma profesional de aprobación clínica. |
| Revisión editorial | `os_field_review` / `os_localized_text.review_status` + `content_hash` | Que la versión esté `approved` ni que el ítem sea visible. |
| Publicación técnica | `os_catalog_release.status='published'` + `os_catalog_item.status='active'` + `is_active` | Que el texto o el mapeo estén aprobados. |
| Vocabulario de gobernanza | `os_review_state` (`in_review`, `reviewed`, etc.) | Ser un CHECK o ser leído por la API. |

**[P]** Toda aprobación queda trazada en `os_audit_log` (append-only) con responsable, fecha, evidencia, hash y dos revisiones (rector §9.2, §12). `rejected` se documenta como decisión negativa sin crear valores nuevos en SQL; `undet` nunca se interpreta como estado de revisión.

---

## 6. Propuesta [P] de migración aditiva independiente — NO EJECUTAR

**[P]** Formalizar el CHECK de `os_catalog_item_version.review_status` en una migración **independiente**, sin tocar release, mapeo, texto localizado ni revisión de campo, sin `UPDATE` y sin cambiar el default `unknown`:

```sql
-- PROPUESTA · NO EJECUTAR · requiere acta READ ONLY previa (rector §14 / plan etapa 1; ver §7 de esta matriz)
BEGIN;
ALTER TABLE os_catalog_item_version
  ADD CONSTRAINT chk_os_catalog_item_version_review_status
  CHECK (review_status IN ('unknown','draft','reviewed','approved','deprecated'))
  NOT VALID;
-- Solo si el acta confirma 0 filas con valores fuera de la lista:
ALTER TABLE os_catalog_item_version
  VALIDATE CONSTRAINT chk_os_catalog_item_version_review_status;
COMMIT;
```

**Justificación de valores [P]:** `unknown` conserva el default actual y la procedencia no demostrada; `draft` y `reviewed` alinean la versión con `os_review_state` y con el ciclo del mapeo; `approved` es el único valor que habilita la vista y el que ya usan los scripts; `deprecated` permite retiro sin inventar valores. Se excluyen `published`/`retired`/`obsolete` (pertenecen a release/ítem) y `in_review`/`rejected`/`unreviewed` (etiquetas de gobernanza, no estados persistidos en esta tabla). **`review` (release) no se incluye; `reviewed` (mapeo) sí.**

**[P]** `NOT VALID` preserva filas existentes y aplica la restricción a escrituras nuevas; `VALIDATE` solo verifica filas ya almacenadas. Si aparece cualquier otro valor, se detiene y se resuelve por gobernanza antes de validar. La corrección de las afirmaciones documentales antiguas es una tarea documental separada, no parte de esta migración.

---

## 7. Consultas READ ONLY para verificar en producción

> Solo `SELECT`, en sesión de solo lectura. No se ejecutaron en este trabajo.

**7.1 Defaults y CHECK reales de los cinco objetos**

```sql
SELECT table_name, column_name, column_default, is_nullable, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND ((table_name = 'os_catalog_item_version' AND column_name = 'review_status')
    OR (table_name IN ('os_concept_mapping','os_localized_text','os_field_review')
        AND column_name = 'review_status')
    OR (table_name = 'os_catalog_release' AND column_name = 'status')
    OR (table_name = 'os_catalog_item' AND column_name = 'status'))
ORDER BY 1, 2;

SELECT conrelid::regclass AS tabla, conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE contype = 'c'
  AND conrelid IN ('public.os_catalog_item_version'::regclass,
                   'public.os_concept_mapping'::regclass,
                   'public.os_catalog_release'::regclass,
                   'public.os_catalog_item'::regclass)
ORDER BY 1, 2;
```

**7.2 Distribución de estados (precondición de la migración propuesta)**

```sql
SELECT 'item_version' AS objeto, COALESCE(review_status,'<NULL>') AS estado, count(*) AS filas
FROM os_catalog_item_version GROUP BY 1,2
UNION ALL SELECT 'mapping', COALESCE(review_status,'<NULL>'), count(*) FROM os_concept_mapping GROUP BY 1,2
UNION ALL SELECT 'localized_text', COALESCE(review_status,'<NULL>'), count(*) FROM os_localized_text GROUP BY 1,2
UNION ALL SELECT 'field_review', COALESCE(review_status,'<NULL>'), count(*) FROM os_field_review GROUP BY 1,2
UNION ALL SELECT 'release', COALESCE(status,'<NULL>'), count(*) FROM os_catalog_release GROUP BY 1,2
UNION ALL SELECT 'item', COALESCE(status,'<NULL>'), count(*) FROM os_catalog_item GROUP BY 1,2
ORDER BY 1, 2;
```

**7.3 Vista vigente, cobertura y huecos**

```sql
SELECT pg_get_viewdef('public.v_oftar_search_catalog'::regclass, true);

SELECT c.code AS catalogo, count(*) AS filas_en_vista
FROM v_oftar_search_catalog v
JOIN os_catalog c ON c.code = v.catalogo
GROUP BY 1 ORDER BY 1;

SELECT count(*) AS items_elegibles_sin_fila_en_vista
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id
WHERE c.family_code = 'oftar' AND c.product_role = 'catalog' AND c.is_active
  AND i.status = 'active'
  AND EXISTS (SELECT 1 FROM os_catalog_item_version iv
               WHERE iv.item_id = i.id AND iv.review_status = 'approved')
  AND NOT EXISTS (SELECT 1 FROM v_oftar_search_catalog v WHERE v.id = i.id);
```

**7.4 Aprobación por campo y mapeos**

```sql
SELECT f.field_name, f.language_code, f.review_status, count(*) AS filas,
       count(DISTINCT f.content_hash) AS hashes_distintos
FROM os_field_review f
JOIN os_catalog_item_version iv
  ON iv.id = f.target_id AND f.target_table = 'os_catalog_item_version'
WHERE f.field_name = 'preferred_term'
GROUP BY 1,2,3 ORDER BY 1,2,3;
-- La coincidencia de hash se verifica con la regla de FieldReviewRepository.php:176-224.

SELECT review_status, mapping_type, relationship_role, count(*) AS filas
FROM os_concept_mapping GROUP BY 1,2,3 ORDER BY 1,2,3;

SELECT code, is_publication_allowed FROM os_review_state ORDER BY code;
```

---

## 8. Referencias

- `especificacion-definitiva-reconstruccion-oftar.md` §9 (flujo editorial y visibilidad), §14 (plan; etapa 1 = `READ ONLY`) y §15 (aceptación).
- `arquitectura-tecnica-oftar-final.md` §1 (límite de verificación) y §2.2 (gobernanza).
- `politica-identificacion-oftar-final.md` (identidad externa) y `modelo-funcional-canonico-oftar.md` §2 (campos canónicos).
- `integracion-os-catalog-oftar.md` (dominio, familia, `product_role` y `domain_type`).
