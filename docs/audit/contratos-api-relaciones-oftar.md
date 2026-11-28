# Contratos de API para relaciones OFTAR

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** OFTAR v1.0 — Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada. (No autoriza ejecución.)
**Convención:** `[H]` hecho verificado en repositorio · `[I]` inferencia · `[P]` propuesta no implementada.

**[P]** Perfil OFTAR del contrato transversal `data.relations` (`docs/architecture/relaciones/10-contratos-api-relaciones-transversales.md`); no se crean endpoints por familia y `mappings`/`related_codes` permanecen intactos.

---

## 0. Método y límite

**[H]** Verificación exclusivamente por lectura de `api/`, `portal/` y `sql/`. No se ejecutaron consultas, seeds, migraciones ni pruebas. Los ejemplos JSON son **ilustrativos de forma**, no datos leídos de PostgreSQL ni resultados de una petición real.

---

## 1. Contrato canónico obligatorio

**[P] C1.** Ningún endpoint ni campo existente cambia de nombre, forma ni semántica. Se proponen **solo adiciones opcionales e ignorables**.

**[P] C2.** Las relaciones **clínicas** viven en `os_catalog_relation`; las **terminológicas** en `os_concept_mapping` + `os_mapping_metadata`. Nunca se mezclan en una misma clase de respuesta: `data.relations.clinical` y `data.relations.terminological` son subclases separadas.

**[P] C3.** `data.mappings` y `data.related_codes` actuales se conservan intactos por compatibilidad, aunque `data.relations` esté presente.

**[P] C4.** En superficie pública: `clinical` solo con `review_status='approved'`; `terminological` solo con `review_status='approved'` **y** revisión de campo vigente para el texto externo. `draft`/`deprecated` y `unmatched` solo en vista editorial autorizada.

**[P] C5.** No se exponen pendientes ni rechazados en búsqueda pública. `rejected` no es valor de CHECK: se documenta en gobernanza (rector §9.2).

**[P] C6.** Todo lo aquí descrito como nuevo (`data.relations`, `/v1/relations`, parámetros y `meta.pagination`) está **NO IMPLEMENTADO**.

---

## 2. Base verificada

### 2.1 Envelope y rutas (`api/index.php:143-174,194-601`)

**[H]** `api_response_headers()` (`:143-174`) emite `X-Request-Id`, `Vary: Accept-Language` y `Content-Language`, y no reemplaza el `Vary` de CORS. Las rutas construyen el envelope `data` / `meta` / `request_id`, por ejemplo `/v1/domains` (`:247-254`), `/v1/search` (`:288-292`), catálogos (`:302-345`), `/v1/mappings` (`:355-359`) y el resto de `/v1/*` hasta `:601`.

**[H]** `/health` es público (`:194-222`); toda ruta `/v1/` exige API Key y rate limit (`:224-239`). Los errores usan `error{code,message,details}` + `request_id` (`api/http/Response.php:54-80`) y códigos existentes `bad_request`, `unauthorized`, `not_found`, `method_not_allowed`, `rate_limit_exceeded`, `internal_error` (`api/http/ApiException.php:20-77`).

### 2.2 Detalle y mapeos (`api/services/CatalogEngineService.php:125-146,528-628,641-729`)

**[H]** El listado de ítems exige release `published` e ítem `active` (`:126-146`).

**[H]** El detalle devuelve `mappings` (`:601-620`), `related_codes` (`:621`) y `uvr` (`:622`), con resolución editorial por campo (`:528-546`). **No devuelve `os_catalog_relation`**: no hay consulta a esa tabla en `:528-628`. Esa es la brecha que `data.relations` vendría a cubrir sin reemplazar los campos actuales.

**[H]** `/v1/mappings` consulta `os_concept_mapping` con release `published` (`:641-662`), filtros `system`, `code` y `catalog` (`:637-639,665-677`) y `ORDER BY ... LIMIT 50` (`:679`). Su `meta.total` es `count($rows)` (`:717-727`): **no hay paginación real** (`offset` ni `meta.pagination`).

### 2.3 Búsqueda OFTAR (`api/services/TerminologySearchService.php:49,52-80,417-432`)

**[H]** `DOMAIN_OFTAR = 'oftar'` (`:49`) está incluido en `DOMAINS` (`:52-68`) y **no** en `DEFAULT_DOMAINS` (`:76-80`, acotado a `snomed`, `cie10`, `anmat`). La rama OFTAR usa la vista `v_oftar_search_catalog` (`:417-432`), con `catalog_code`, `permanent_code`, `family_code`, `category`, `language_code` y `review_status` en metadata.

**[H]** El tope de búsqueda es `MAX_OFFSET=5000` (`:82`). En Browse, `MAX_OFFSET=5000` y `MAX_PAGE_SIZE=100` están en `portal/Repositories/CatalogRepository.php:56-57,621,632,743`.

### 2.4 Portal (`portal/Repositories/CatalogRepository.php:2992-3121` y `portal/Controllers/BrowseController.php:15,54,92`)

**[H]** `itemRelations()` mezcla mapeos y relaciones en **una sola lista**: mapeos (`:3011-3062`) y relaciones (`:3064-3119`) con `type`, `role`, `direction`, `result_key` y campos comunes `system`, `code`, `display`, `review_status`, `provenance`. El `dedupeRelations()` elimina espejos por `system|code|type` en minúsculas (`:3124-3149`). Sin tablas o sin filas devuelve `[]`; la pestaña no se rellena con datos inventados (`:2985-2988`).

**[H]** `BrowseController` conserva las pestañas `concept`, `relations`, `values`, `validity`, `clinical`, `trace` (`:15`), normaliza `rel_view` a `table|diagram` con default `table` (`:54-55`) y mantiene `rel_view` en el estado canónico de la URL (`:92`).

**[H]** `portal/Views/partials/browse/detail/relations.php` muestra el conmutador `table`/`diagram` con `aria-pressed` (`:40-52`), filtros por tipo y sistema (`:54-71`), tabla con encabezados con `scope="col"` (`:121-180`) y diagrama con nodos (`:74-119`). El enlace a ficha existe solo si `result_key` resuelve a destino (`:93-97,145-161`).

---

## 3. Endpoints actuales vs propuestos

| Superficie | Estado actual verificado | Propuesta aditiva (NO implementada) | Compatibilidad |
|---|---|---|---|
| `GET /v1/domains` | `data/meta/request_id`; `meta.domains` y `meta.default_domains` (`index.php:242-255`) | Sin cambios | Sin cambio |
| `GET /v1/search[/{domain}]` | `oftar` en `DOMAINS`, no en `DEFAULT_DOMAINS`; vista `v_oftar_search_catalog` | Sin exponer pendientes/rechazados; sin cambiar defaults | Sin cambio; solo regla de visibilidad |
| `GET /v1/catalogs/{code}/items` | Release `published`, ítem `active`; `limit`/`offset` con `meta.limit/offset/returned` (`CatalogEngineService.php:100-217`) | Sin cambios en este listado | Sin cambio |
| `GET /v1/catalogs/{code}/items/{code}` | `mappings`, `related_codes`, `uvr`; **sin relaciones clínicas** (`:528-628`) | Campo opcional `data.relations{clinical,terminological}` cuando el cliente envía `relations`; parámetros opcionales ignorables | Aditivo; sin `relations` la respuesta es idéntica |
| `GET /v1/mappings` | `LIMIT 50` sin paginación real (`:641-729`) | **No se modifica**. Se mantiene `LIMIT 50` y su envelope | Sin cambio; la paginación se ofrece en el nuevo endpoint |
| `GET /v1/relations` (NUEVO) | No existe | Lectura separada de relaciones clínicas y terminológicas con `limit`/`offset` y `meta.pagination` | Ruta nueva; no colisiona con `/v1/mappings` |
| Browse `/browse` y `/browse/{id}` | Filtros `q/domain/catalog/family/type/category/status/version/validity`, `tab`, `rel_view`; `MAX_OFFSET=5000`, `MAX_PAGE_SIZE=100`; exclusión mutua `domain` vs `catalog/family` | Reutilizar los mismos nombres y topes para los nuevos filtros de relaciones | Sin cambio de nombres ni semántica |

---

## 4. Formato propuesto de `data.relations`

**[P]** Cada entrada, cualquiera sea su subclase, usa exactamente estos campos:

| Campo | Significado |
|---|---|
| `relation_id` | Identificador de la fila de origen (`os_catalog_relation.id` o `os_concept_mapping.id`) |
| `class` | `clinical` o `terminological` |
| `type` | Tipo de relación clínica o `mapping_type` terminológico |
| `direction` | `outgoing` / `incoming` / `both`; clínica desde `source_item_id`, terminológica desde OFTAR al sistema externo |
| `source` / `target` | Códigos legibles de los extremos |
| `source_system` / `target_system` | Sistemas de cada extremo; en terminológica, el externo es `target_system` |
| `edition` | Edición declarada del sistema externo; si no consta, `null` y se informa en `meta` |
| `version` | Versión del sistema o release aplicable |
| `scope` | Alcance clínico declarado |
| `laterality` | Lateralidad cuando aplique; si no, `null` |
| `context` | `context_text` o justificación conservada, sin inventar juicio de equivalencia |
| `provenance` | Procedencia textual de la fuente |
| `source_reference` | Referencia a archivo/fila o acta |
| `review_status` | Estado persistido real del objeto |
| `valid_from` / `valid_to` | Vigencia declarada; `null` si se desconoce |

### 4.1 Ejemplo ilustrativo (NO implementado, NO consultado)

```json
{
  "data": {
    "permanent_code": "OFT-PR-000001",
    "preferred_term": "Ejemplo estructural de prestación OFTAR",
    "mappings": [
      {
        "system": "<SISTEMA>",
        "code": "<CODIGO_EXTERNO>",
        "display": null,
        "equivalence": "<mapping_type>",
        "role": "<relationship_role>",
        "rationale": null,
        "field_languages": {},
        "untranslated": true
      }
    ],
    "related_codes": [],
    "relations": {
      "clinical": [
        {
          "relation_id": 1001,
          "class": "clinical",
          "type": "REL-PRDX-DIAG",
          "direction": "outgoing",
          "source": "OFT-PR-000001",
          "target": "OFT-DX-000001",
          "source_system": "OFTAR-CLINICAL",
          "target_system": "OFTAR",
          "edition": null,
          "version": "v1.0",
          "scope": "relación clínica documentada",
          "laterality": null,
          "context": "Ejemplo de contexto literal de la fuente",
          "provenance": "matriz de conciliación · fila de ejemplo",
          "source_reference": "docs/audit/ejemplo.md:fila",
          "review_status": "approved",
          "valid_from": "2026-01-01",
          "valid_to": null
        }
      ],
      "terminological": [
        {
          "relation_id": 2001,
          "class": "terminological",
          "type": "related",
          "direction": "outgoing",
          "source": "OFT-PR-000001",
          "target": "0000000",
          "source_system": "OFTAR",
          "target_system": "SNOMED-CT-AR",
          "edition": "Argentina Edition",
          "version": "2026",
          "scope": "correspondencia asociativa del refset 447562003",
          "laterality": null,
          "context": "mapAdvice conservado como justificación",
          "provenance": "refset oficial 447562003",
          "source_reference": "ejemplo de referencia",
          "review_status": "approved",
          "valid_from": "2026-01-01",
          "valid_to": null
        }
      ]
    }
  },
  "meta": {
    "requested_language": "es-AR",
    "effective_language": "es-AR",
    "untranslated": true,
    "pagination": {
      "relations": {
        "clinical": { "limit": 20, "offset": 0, "returned": 1, "total": 1 },
        "terminological": { "limit": 20, "offset": 0, "returned": 1, "total": 1 }
      }
    }
  },
  "request_id": "req-ejemplo"
}
```

**[I]** Los códigos, IDs y textos del ejemplo son marcadores de posición. No deben interpretarse como relaciones aprobadas ni como datos existentes.

---

## 5. Parámetros opcionales propuestos (NO implementados)

| Parámetro | Valores propuestos | Regla |
|---|---|---|
| `relations` | `clinical` / `terminological` / `all` | En el detalle, **si falta el parámetro no se emite `data.relations`** y la respuesta es la actual. Si se envía, default `all` solo donde no rompa; en público se recomienda filtrar a aprobados |
| `relation_type` | Código del tipo | Filtro por `type`; no cambia `category` ni `clinical_category` |
| `relation_direction` | `outgoing` / `incoming` / `both` | `both` no duplica la misma fila; respeta el dedupe histórico |
| `relation_class` | `clinical` / `terminological` | Equivalente a `relations`, se admite por claridad; ante conflicto, se rechaza con `bad_request` |
| `include_unpublished=0` | `0` (default) / `1` | `1` solo para editor autorizado; en público se ignora sin cambiar la respuesta, nunca filtra hacia afuera |
| `limit` / `offset` | Enteros | Aplican **solo al campo nuevo o al nuevo endpoint**; topes `MAX_PAGE_SIZE=100` y `MAX_OFFSET=5000` |
| `q` / `domain` / `catalog` / `family` / `type` / `category` / `status` / `version` / `validity` | Como en Browse | Se conservan sin cambio; `domain` es mutuamente excluyente con `catalog`/`family` salvo los casos históricos ya permitidos para `odontologia`/`oftar` (`BrowseService.php:57-59`) |

**[P]** Los filtros históricos no se renombran. `family` sigue siendo la familia del catálogo; `type` sigue siendo el tipo de nomenclador/categoría según el contexto actual. Los nuevos filtros son aditivos: un cliente que los ignore obtiene exactamente el contrato actual.

---

## 6. Paginación, filtro y errores

**[P] P1.** `limit` se acota a `1..100`; `offset` a `0..5000`. Fuera de rango: `400 bad_request` con `details` indicando el parámetro y el tope. No se devuelve un `total` global nuevo en `/v1/mappings`.

**[P] P2.** `meta.pagination` aparece **solo** cuando el cliente pidió el campo nuevo o usó `/v1/relations`. No se agrega a respuestas históricas. Incluye `limit`, `offset`, `returned` y `total` por subclase.

**[P] P3.** En público, la consulta de relaciones aplica: release `published`, ítem `active`, `clinical.review_status='approved'`; para `terminological`, además revisión de campo aprobada con `content_hash` vigente. `draft`, `deprecated` y `unmatched` quedan fuera (rector §9.3).

**[P] P4.** `rejected` no se filtra porque no es un valor persistido de esos CHECK; la negativa se documenta en gobernanza. No se devuelven solicitudes pendientes ni decisiones sin evidencia en búsqueda pública.

**[P] P5.** Errores: se reutilizan los códigos existentes y el envelope actual (`error` + `request_id`). `include_unpublished=1` se ignora en público; solo una superficie editorial explícitamente restringida puede responder `401 unauthorized`. Valor inválido → `400 bad_request`; ítem inexistente → `404 not_found` con la misma semántica actual de 200 vacío en listados frente a 404 en detalle; método distinto de `GET` → `405 method_not_allowed`; exceso de tasa → `429 rate_limit_exceeded`.

**[P] P6.** `Vary: Accept-Language`, `X-Request-Id` y `Content-Language` se mantienen. Los textos externos sin revisión vigente siguen publicándose como `null` con `untranslated=true`, nunca como texto sin revisar.

**[P] P7.** La paginación es estable: orden por subclase, tipo, sistema/código y `relation_id`. El dedupe histórico de Browse por `system|code|type` (`CatalogRepository.php:3136-3149`) se aplica también a la proyección nueva para no duplicar espejos.

---

## 7. Matriz de compatibilidad

| Elemento | Cambio propuesto | Compatibilidad |
|---|---|---|
| Rutas `/v1/*` existentes | Ninguno | Total |
| Envelope `data/meta/request_id` | Ninguno | Total |
| `Vary: Accept-Language`, `X-Request-Id`, `Content-Language` | Ninguno | Total |
| `data.mappings` | Ninguno; se mantiene con `equivalence`, `role`, `rationale`, `field_languages`, `untranslated` | Total |
| `data.related_codes` y `uvr` | Ninguno | Total |
| `/v1/mappings` `LIMIT 50` y `meta.total=count(rows)` | Ninguno | Total |
| `DEFAULT_DOMAINS` sin `oftar` | Ninguno | Total |
| 200 vacío en listados / 404 en detalle | Ninguno | Total |
| Filtros históricos y exclusión mutua `domain` vs `catalog/family` | Ninguno | Total |
| `MAX_OFFSET=5000`, `MAX_PAGE_SIZE=100` | Se reutilizan en el campo nuevo | Total |
| `tab=relations`, `rel_view=table\|diagram` | Ninguno | Total |
| Lista mixta de `itemRelations()` en portal | No se reemplaza; la API nueva es paralela y separada | Total en portal; la separación es solo en la respuesta nueva |
| `data.relations.clinical` / `.terminological` | Adición opcional | Ignorable |
| `/v1/relations` | Ruta nueva | Sin impacto en rutas actuales |
| `meta.pagination` | Solo en respuesta nueva o cuando se pide | Ignorable |
| `include_unpublished=1` | Solo editor autorizado | Restringido; no cambia respuesta pública |

---

## 8. Cierre

**[P]** Este contrato cierra la brecha verificada entre la API actual (que publica `mappings`/`related_codes` pero no relaciones clínicas) y el modelo integral del rector §7, sin tocar un solo nombre o semántica existente. Está preparado para implementación controlada; **no autoriza ejecución**.
