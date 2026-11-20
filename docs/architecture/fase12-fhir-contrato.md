# Fase 12 (§16) · FHIR R4 como proyección — contrato formal

**Estado:** PREPARADA (contrato documental). **No implementada.**
**Autorización:** respuesta `Solo contrato, sin endpoints (Recommended)` del
2026-11-20, dentro del plan del §16 de
[`propuesta-arquitectura-catalogos-sanitarios.md`](propuesta-arquitectura-catalogos-sanitarios.md).
**No incluye:** DDL/DML, migraciones SQL, rutas `/fhir/*`, serializadores,
dependencias FHIR, cambios en `api/index.php`, cambios en la guardia de API Key,
cambios en la OpenAPI ni publicación de endpoints. No requiere backup ni
ejecución por `postgres`: no hay cambios en base.

> Esta fase **formaliza el contrato** que ya era propuesto en
> [`README-FHIR.md`](../../README-FHIR.md) y en el §14 del documento de
> arquitectura. Ningún ejemplo de este documento debe interpretarse como un
> servicio disponible.

---

## 1. Realidad verificable [REPO]

| Hecho | Evidencia |
|---|---|
| `api/index.php` solo enruta `/v1/*`. | No hay cadena `/fhir` en `api/`. |
| La guardia de API Key cubre únicamente `/v1/*`. | `str_starts_with($path, '/v1/')` en `api/index.php`. |
| `README-FHIR.md` es un contrato propuesto. | Aviso `Estado: contrato propuesto, no implementado`. |
| La OpenAPI no declara `/fhir/*` como implementado. | No existe `paths./fhir/metadata`. |
| Docs y portal declaran FHIR como pendiente. | `pending.fhir_text`: «No existe ninguna ruta /fhir». |
| No hay serializadores ni dependencia FHIR. | Sin biblioteca FHIR en el repositorio. |

**Consecuencia:** cualquier implementación futura debe, en una fase posterior y
con autorización nueva, (a) extender la guardia de autenticación a `/fhir/*`,
(b) implementar serializadores, (c) actualizar la OpenAPI y (d) sustituir los
ejemplos ilustrativos por códigos reales. Nada de eso se hace aquí.

## 2. Principios de la proyección

1. **El modelo interno es la única fuente de verdad.** FHIR es una vista de
   solo lectura: nunca escribe en `os_*`, no crea conceptos y no corrige datos.
2. **Gestión antes que exposición.** Solo se proyecta lo que tenga
   `review_status` con `is_publication_allowed = TRUE` y `source_reference` no
   vacío.
3. **Una reserva no es un catálogo.** Las reservas de la Fase 8
   (`dentar-in`, `dentar-pd`, `dentar-eq`) y de la Fase 10 (`OS-*` y
   `OS-PRODUCTS`) tienen `catalog_id = NULL`: **no se proyectan** como
   `CodeSystem` ni como cualquier otro recurso publicable.
4. **Modelo vacío, recursos vacíos.** El modelo de productos de la Fase 6 y el
   staging de la Fase 11 están vacíos: `Medication`, `MedicationKnowledge`,
   `Device` y `DeviceDefinition` no pueden devolver instancias hasta que exista
   una aprobación editorial y una fuente verificada.
5. **Códigos reales únicamente.** Los ejemplos usan `DNT-PR-NNNNNN` y
   `DNT-DX-NNNNNN`; los códigos ilustrativos heredados del `README-FHIR.md`
   deben reemplazarse antes de cualquier publicación.
6. **Lo estimado se declara estimado.** `ChargeItemDefinition` deriva de UVR;
   el importe es una estimación metodológica, **nunca un arancel oficial**.

## 3. Mapa de recursos (§14.2 del documento de arquitectura)

| Recurso FHIR R4 | Origen interno | Estado actual de la proyección |
|---|---|---|
| `CodeSystem` | `os_catalog` + `os_catalog_item` | Factible para `dentar-pr`, `dentar-dx` y `nomenclador-odontologico-ar` (activos). Reservas DENTAR/OS excluidas por `catalog_id` nulo. |
| `ValueSet` | `os_catalog_category` / listas por release | Factible desde releases publicadas; sin categorías de reservas. |
| `ConceptMap` | `os_catalog_relation` + mapeos | 603 relaciones intactas; equivalencias sin juicio clínico nuevo. La decisión 10 se mantiene en `itemRelations()`. |
| `Procedure` / `ServiceRequest` | `dentar-pr` | Códigos `DNT-PR-NNNNNN`. |
| `Condition` | `dentar-dx` + CIE-10 | Códigos `DNT-DX-NNNNNN` y sistemas externos nativos. |
| `HealthcareService` | catálogo de servicios | Solo si existe fuente aprobada. |
| `Medication` | `os_product` (Fase 6) | **0 instancias** mientras el modelo esté vacío. El legado (`os_medicinal_product`, 10 filas) no se migra ni se proyecta como si fuera el modelo nuevo. |
| `MedicationKnowledge` | `os_regulatory_records` + presentación + fabricante | **0 instancias**; requiere fuente ANMAT registrada en la Fase 11. |
| `Device` / `DeviceDefinition` | `os_product` con clase `device` / `equipment` (Fase 10) | **0 instancias**; las etiquetas `OS-DIS`/`OS-EQP` son reservas, no dispositivos. |
| `ChargeItem` / `ChargeItemDefinition` | UVR (`os_uvr_valuation` y vista derivada) | Sin `total_uvr` almacenado; importe estimado y derivado, nunca tarifa oficial. |

### 3.1 Reglas de proyección para `ChargeItemDefinition`

- El valor mostrado debe proceder de la vista derivada de UVR, nunca de
  `os_pricing_values` ni de `os_fee_item` (lista de precios de un financiador).
- Toda respuesta debe declarar explícitamente el carácter estimado y la
  metodología UVR de origen.
- No se inventan valores de conversión cuando no existe fila de valoración.

## 4. Operaciones propuestas (NO enrutadas)

Las siguientes firmas son el contrato objetivo. **Ninguna está disponible hoy**;
se listan para que una futura implementación tenga un alcance definido.

| Operación | Propósito | Origen interno | Estado |
|---|---|---|---|
| `GET /fhir/metadata` | `CapabilityStatement` de terminología | Configuración editorial | Propuesta, no enrutada |
| `GET /CodeSystem/$lookup` | Inspección de un concepto | `os_catalog_item` | Propuesta, no enrutada |
| `GET /ValueSet/$expand` | Expansión por release/categoría | `os_catalog_category` | Propuesta, no enrutada |
| `GET /ConceptMap/$translate` | Traducción entre códigos | `os_catalog_relation` | Propuesta, no enrutada |
| `GET /Medication`, `/Device`, `/ChargeItemDefinition` | Proyección del modelo de productos y UVR | Fases 6, 10 y 11 | Propuesta, sin instancias |

**Autenticación prevista:** cabecera `Authorization: Bearer <API_KEY>`, con la
guardia extendida explícitamente a `/fhir/*` antes de publicar. La guardia
actual solo cubre `/v1/*`; este documento no la modifica.

## 5. Criterios de aceptación de esta fase

Esta fase se verifica **documentalmente**, no con SQL: no hay DDL, DML ni tablas
nuevas que auditar. El verificador canónico (`tests/run.php`) comprueba que:

- Existe este contrato y declara su estado no implementado.
- El contrato reúne el mapa de recursos del §14.2, incluidos `Medication`,
  `Device` y `ChargeItemDefinition`.
- El contrato excluye las reservas de las Fases 8 y 10 de la proyección.
- El contrato declara el importe UVR como estimado, nunca arancel oficial.
- El contrato no crea rutas ni modifica la guardia de autenticación.
- `README-FHIR.md` sigue declarando el contrato como propuesto y referencia
  este documento.
- La OpenAPI sigue sin declarar `/fhir/*` como implementado.
- Docs sigue declarando que no existe ninguna ruta `/fhir`.

## 6. Salida y trabajo futuro

No hay cambios en base ni en código, por lo que no existe rollback operativo.
Si se decide implementar la proyección, será necesaria una **autorización
nueva** que cubra: extensión de la guardia, serializadores, rutas, OpenAPI,
sustitución de ejemplos y verificación de regresión. Hasta entonces, FHIR R4
permanece como contrato propuesto.

---

**Fin de la Fase 12 (§16).** Con esta fase queda cubierto el plan completo del
§16; las fases 0–11 están cerradas en base o documentalmente según corresponda,
y la 12 queda preparada como contrato sin endpoints.
