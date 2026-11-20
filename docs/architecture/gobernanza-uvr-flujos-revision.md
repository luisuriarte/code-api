# Gobernanza UVR · flujos de propuesta, revisión, aprobación y publicación

**Estado:** PROPUESTA DOCUMENTAL. **No implementada.**
**Depende de:** [`gobernanza-uvr-arquitectura.md`](gobernanza-uvr-arquitectura.md) §6 (C1, C4, C5, C6, C8),
[`gobernanza-uvr-roles-permisos.md`](gobernanza-uvr-roles-permisos.md).

> No se crean tablas, rutas ni vistas. Se describe el circuito objetivo usando
> la gobernanza genérica que ya existe y las vistas solicitadas A–G como
> pantallas futuras.

---

## 1. Cadena de gobernanza existente [REPO]

`sql/08_arquitectura/fase4_gobernanza.sql` (Fase 5 del §16, nombre histórico)
implementa una sola cadena:

```
os_governance_request  →  os_governance_review  →  os_governance_decision
        │                        │                        │
        └──────────── os_audit_log (append-only) ──────────┘
```

| Elemento | Realidad verificable | Evidencia |
|---|---|---|
| Solicitud | `request_type`, `subject_type`, `subject_id`, `proposed_change`, `source_reference` (nullable), `license_reference`, `requested_by`, `requested_by_user_id`, `review_status` default `draft`. | `fase4_gobernanza.sql:58-73` |
| Revisión | `request_id`, `reviewer_actor`, `reviewer_user_id`, `reviewer_role`, `outcome` default `unreviewed`, `rationale`, `reviewed_at`. | `fase4_gobernanza.sql:81-91` |
| Decisión | `review_id`, `decision_code`, `approved_by`, `approved_by_user_id`, `approved_at`, `effective_from`, `evidence_reference TEXT NOT NULL`. | `fase4_gobernanza.sql:96-106` |
| Auditoría | `os_audit_log` con `before_state`/`after_state` JSONB y trigger inmutable. | `fase4_gobernanza.sql:120-147,217-227` |
| Actores | Cuatro columnas FK a `os_admin.app_user` con `ON DELETE SET NULL`, además de su texto legible. | `fase4_gobernanza.sql:67,85,101,126` |
| Estado operativo | 4 tablas vacías; el panel no las consume. | `sql/08_arquitectura/README.md:278-289`; `sql/09_admin/README.md:107-116` |

No existen hoy: propuestas enlazadas a `os_uvr_valuation`, tareas, revisiones
UVR separadas, aprobaciones vinculadas ni guardián de publicación.

## 2. Flujo propuesto (estados)

Se reutiliza `os_review_state` como único semáforo
(`fase1_infraestructura.sql:85-102`):

| Estado | `is_publication_allowed` | Uso en UVR |
|---|---:|---|
| `unknown`, `unreviewed`, `draft`, `in_review`, `reviewed` | `FALSE` | Borrador y revisión en curso. Nunca visible como valores. |
| `approved` | `TRUE` | Metodología/componentes/conversión aprobados; aún no publicados. |
| `published` | `TRUE` | Único estado apto para exposición controlada. |
| `retired`, `obsolete`, `deprecated` | `FALSE` | Retiro controlado; requiere nueva fila/versión. |

Secuencia objetivo:

1. **Propuesta** (`draft`). Se crea `os_governance_request` con `subject_type`
   apuntando a una valoración UVR y `source_reference` verificable. El
   proponente queda como `requested_by_user_id`.
2. **Revisión clínica/terminológica.** `os_governance_review` con
   `reviewer_role` clínico y `rationale` sobre prestación/indicación.
3. **Revisión metodológica/económica UVR.** Segunda fila de revisión, actor
   distinto, `rationale` sobre componentes, metodología, índices y conversión.
4. **Decisión.** `os_governance_decision` con `evidence_reference NOT NULL`,
   `approved_by_user_id` y `effective_from`. Se exige `Rbac::canApprove()`:
   quien propuso no aprueba su propia propuesta.
5. **Transición a `approved`.** Solo después de las dos revisiones y la decisión.
6. **Publicación.** Solo si `is_publication_allowed = TRUE`, la fuente existe y
   el ítem pertenece a un catálogo elegible activo. Hoy **no hay guardián** que
   lo impida; se propone incorporarlo en fase futura.
7. **Cambio posterior.** Nueva fila/versión, nunca `UPDATE` destructivo sobre
   valoración publicada. Pending de decisión C12.

Las revisiones clínica y económica son **independientes** pero no forman
sistemas de gobernanza separados: ambas alimentan la misma solicitud y la misma
auditoría. Esto respeta la regla de gobernanza única y la separación de planos
del §7 de la arquitectura.

## 3. Elementos ausentes y tratamiento

| Necesidad | Situación actual | Tratamiento propuesto |
|---|---|---|
| `responsable` con identidad fuerte | `calculated_by TEXT` anulable. | Actor de gobernanza con FK a `os_admin.app_user`. |
| `revisores` | `reviewer_role TEXT` sin CHECK ni roles UVR. | Dos filas de revisión con roles funcionales controlados y actores distintos. |
| `aprobador` | `approved_by_user_id` existe en la decisión, pero no está enlazado a UVR. | Enlazar la decisión al `subject_id` de la valoración. |
| `tareas/asignaciones` | No existe entidad ni cola. | Worklist derivado del estado de `os_governance_request/review` antes de crear tabla de tareas. |
| `publicación` | No hay `published_at` ni guardián en UVR. | Un único guardián basado en `os_review_state.is_publication_allowed`. |
| `importe referencial` | Solo fórmula documental; no hay vista que consuma `uvr_value`. | Vista derivada, nunca columna; nombre visible pendiente de C7. |

## 4. Vistas administrativas A–G (futuras)

Ninguna existe hoy. Se listan como **pantallas propuestas**, no como rutas
implementadas. La evidencia de la ausencia es `portal/Router.php:145-363` y
`portal/Views/layouts/admin.php:40-51`.

| ID | Vista | Propósito | Permisos existentes que la sustentan | Estado |
|---|---|---|---|---|
| A | UVR | Listado de valoraciones, componentes derivados, estado y fuentes. | `catalog.view` + grant `view`. | No implementada |
| B | Catálogos editables | Catálogos/borradores sobre los que se puede proponer; no crea catálogos. | `catalog.view`, `catalog.edit_draft`. | No implementada |
| C | Propuestas | Bandeja de propuestas, detalle, cambio de estado y separación de funciones. | `catalog.propose`, `catalog.review`, `catalog.approve`. | No implementada |
| D | Tareas | Worklist derivado de revisiones pendientes por actor/contexto. | `catalog.review`, `catalog.approve`. | No implementada |
| E | Comparación | Comparar versiones/valoraciones, con topes y texto descriptivo. | `catalog.view`. | No implementada |
| F | Metodologías | Metodología, versión, fuente, vigencia y aprobación. | `catalog.propose`, `catalog.review`, `catalog.approve`. | No implementada |
| G | Valores monetarios | Conversión e índices con estado y fuente; importe solo derivado. | `catalog.review`, `catalog.approve`, `audit.view`. | No implementada |

Patrones de UI reutilizables:

- Tablas y estados del panel: `portal/Views/admin/organizations.php:70-94`,
  `portal/Views/admin/invitations.php:101-108`, `web/assets/css/app.css:3340-3360`.
- Pestañas y filtros: `portal/Views/admin/invitations.php:68-77`.
- Chips de grants: `portal/Views/admin/_grant_choices.php:5-74`.
- Comparación e historial públicos como referencia de límites y accesibilidad:
  `portal/Views/partials/browse/compare.php:5-30`,
  `portal/Views/partials/browse/history.php:5-29`.
- Paridad trilingüe obligatoria:
  `tests/run.php:1186-1215,1379-1408`.

**Importante:** las vistas B–G no deben convertir reservas en catálogos reales ni
mostrar valores no aprobados. La UI debe seguir el patrón «no publicado» ya
usado en Browse.

## 5. Reglas de presentación y límites

1. No existe `/v1/uvr`: ninguna vista puede anunciar un endpoint inexistente
   (`tests/run.php:1171`).
2. La página pública `/uvr` sigue siendo solo metodología, trilingüe y sin
   valores (`web/uvr.php:5-10`).
3. Los ejemplos numéricos son ilustrativos y no arancelarios
   (`portal/translations/messages.es-AR.yaml:1086-1096`).
4. `estimated_payment`/`importe_referencial` siempre se rotulan como estimación,
   nunca como tarifa, pago oficial ni convenio.
5. Todo cambio de texto o estado se audita y, si afecta contenido terminológico
   aprobado, dispara invalidación tipo D-31.
6. La baja lógica bloqueante y la protección del último `superadmin` se mantienen.

## 6. Criterios de cierre del flujo (futuros)

- Toda valoración publicada tiene solicitud, dos revisiones, decisión con
  evidencia, fuente verificable y estado publicable.
- Quien propone no puede aprobar; se comprueba en servicio, no solo en UI.
- No hay columna `total_uvr` ni importe almacenado.
- No hay rutas nuevas en la API pública ni `/fhir/*`.
- Las vistas A–G usan permisos existentes y pasan `AdminGuard`, CSRF y auditoría.
- `tests/run.php` y la verificación SQL read-only confirman las regresiones
  `603 / 22 / 0 / 0 / 3 / 7` y el legado `9 / 10 / 10 / 40`.
