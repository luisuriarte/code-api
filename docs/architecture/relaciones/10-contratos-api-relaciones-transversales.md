# Contratos API transversales de relaciones

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** contrato implementado en código fuente; ejecución, verificación y publicación pendientes en entorno autorizado.

---

## 1. Compatibilidad obligatoria

**[H]** El envelope actual es `data`/`meta`/`request_id`; `api_response_headers()` emite `X-Request-Id`, `Vary: Accept-Language` y `Content-Language` (`api/index.php:143-174`). Las rutas `/v1/*` construyen ese envelope (`:247-601`). `CatalogEngineService` devuelve `mappings`, `related_codes` y `uvr` en el detalle (`CatalogEngineService.php:528-628`).

**[P] Reglas duras:**

- No crear `/v1/dentar/relations` ni `/v1/oftar/relations`. Una sola superficie para todas las familias.
- Conservar `mappings`, `related_codes`, `uvr`, defaults de paginación y exclusión mutua `domain`/`catalog`/`family`.
- Añadir `data.relations` de forma aditiva.
- Mantener `Vary: Accept-Language`, `Content-Language` y `request_id`.
- Un concepto sin relaciones públicas devuelve arrays vacíos, no error.

---

## 2. Formato propuesto

```json
{
  "data": {
    "permanent_code": "<CODIGO_PROPIO>",
    "catalog": { "code": "<CATALOGO>", "family": "<FAMILIA>", "domain_type": "<DOMINIO>" },
    "mappings": [],
    "related_codes": [],
    "relations": {
      "clinical": [
        {
          "relation_id": "<ID>",
          "class": "clinical",
          "type": "<REL-...>",
          "direction": "outgoing|incoming",
          "source": "<CODIGO_ORIGEN>",
          "target": "<CODIGO_DESTINO>",
          "source_system": "<SISTEMA>",
          "target_system": "<SISTEMA_DESTINO_O_PROPIO>",
          "family_source": "<FAMILIA>",
          "family_target": "<FAMILIA>",
          "edition": null,
          "valid_from": null,
          "valid_to": null,
          "review_status": "approved",
          "context": "<CONTEXTO>",
          "provenance": "<FUENTE>"
        }
      ],
      "terminological": [
        {
          "relation_id": "<ID>",
          "class": "terminological",
          "system": "<SISTEMA>",
          "code": "<CODIGO_EXTERNO>",
          "display": null,
          "mapping_type": "<equivalent|narrower|broader|related|unmatched>",
          "mapping_nature": "<univocal|multiple|partial|approximate|not_mappable>",
          "edition": "<EDICION>",
          "role": "<relationship_role>",
          "review_status": "approved",
          "untranslated": false,
          "provenance": "<FUENTE>"
        }
      ]
    }
  },
  "meta": { "effective_language": "es-AR", "pagination": {} },
  "request_id": "<REQUEST_ID_NO_UUID>"
}
```

**[P]** Todos los `<...>` son marcadores de maquetación: no son códigos, tipos ni aprobaciones reales. Los valores `mapping_type` y `mapping_nature` se limitan a los CHECK verificados.

---

## 3. Filtros

| Parámetro | Valores | Aplicación |
|---|---|---|
| `language` / `Accept-Language` | idiomas soportados | Misma resolución que el detalle actual. |

**[H]** La implementación entregada no añade parámetros nuevos: `data.relations` devuelve ambas clases completas, separadas y ya filtradas por `review_status='approved'`. **[P]** Filtros por clase, tipo, dirección o sistema quedan como ampliación futura; no crean relaciones ni justifican endpoints nuevos. El detalle mantiene `limit` 1–100 y `offset >= 0` en el listado; no se afirma un `MAX_OFFSET` en `CatalogEngineService::listItems()`.

---

## 4. Reglas de visibilidad

| Superficie | Regla |
|---|---|
| Pública | `review_status='approved'`; versión del concepto aprobada; campo vigente; perfil publicado. |
| Editorial autorizada | `draft`, `reviewed`, `deprecated`, `unmatched` y pendientes, con advertencia explícita. |
| Nunca | `pending_review`, `rejected` como valores de filtro; equivalencias por similitud textual; relaciones PR↔DX como mapeo. |

**[P]** `display`, `rationale` y `context` se entregan `null` + `untranslated=true` cuando no hay revisión vigente.

---

## 5. Ejemplos de respuesta vacía y error

- **200 con `relations: {clinical: [], terminological: []}`**: concepto válido sin relaciones públicas.
- **404**: concepto inexistente, inactivo o no visible para el perfil.
- **400**: filtro de tipo no admitido por el diccionario o combinación origen/destino inválida.
- **401/403**: vista editorial sin autorización.

**[P]** No se devuelve una relación aunque la fila exista si el perfil de dominio la marca como no pública.

---

## 6. Implementación entregada

**[H]** El cambio quedó en `CatalogEngineService::relationsForItem()` y en `CatalogRepository::itemRelationsByClass()`, sin alterar `mappings`/`related_codes` ni crear rutas por familia. La proyección pública solo incluye filas `approved`; `display` y `rationale` pasan por `MappingReviewReader`, y `mapping_nature` es `null` cuando Fase 3 no aporta metadatos vigentes. **[P]** Requiere PR revisado, tests en verde y gate de publicación antes de desplegar.
