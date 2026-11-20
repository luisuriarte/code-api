# Gobernanza UVR · auditoría de reutilización y arquitectura propuesta

**Estado:** PROPUESTA DOCUMENTAL. **No implementada.**
**Autorización:** ninguna para ejecutar cambios. Este paquete solo audita, reutiliza y propone.
**No modifica:** PostgreSQL, SQL/DDL/DML, datos, código, API pública, OpenAPI, portal,
traducciones aprobadas, dependencias, configuración del VPS ni despliegue. No hay
commits ni push.

> Al inicio de este paquete `git status --short` no devolvió salida: el árbol de
> trabajo estaba limpio. Los únicos archivos creados son los seis documentos
> `gobernanza-uvr-*.md` de `docs/architecture/`.

---

## 1. Alcance y método

Se contrastó el documento del usuario «Arquitectura y plan de implementación del
subsistema de Valoración UVR» con cuatro revisiones de solo lectura:

1. SQL y gobernanza (`sql/08_arquitectura`, `sql/09_admin`, `sql/07_multilingue`,
   `sql/02_catalogs`, `sql/03_dentar`, `sql/portal`).
2. Backend y permisos (`api/`, `portal/Admin/`, `portal/Repositories/`,
   `portal/Controllers/`).
3. Documentación y decisiones (`README-UVR.md`, `README.md`,
   `docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md`,
   `docs/architecture/decisiones-arquitectura-multilingue.md`,
   `docs/architecture/fase12-fhir-contrato.md`).
4. Portal e interfaz (`web/uvr.php`, `web/docs.php`, `web/sitemap.php`, vistas
   `portal/Views/`, traducciones y `tests/run.php`).

El documento del usuario **no está versionado como archivo autónomo** en el
repositorio; se trata aquí como especificación externa aportada en la consulta.
Por eso todo lo que se afirma sobre el repositorio se apoya en rutas y líneas
verificables, y todo lo que se propone queda marcado como propuesta.

## 2. Conclusión ejecutiva

> **Compatible con condiciones.** El núcleo metodológico del documento del
> usuario coincide con la arquitectura aprobada: UVR relativa, no arancel,
> componentes aditivos, `total_uvr` derivado, conversión separada, sin valores
> inventados y API pública intacta.
>
> **No está implementada la gobernanza operativa UVR.** Existe el esqueleto SQL
> (Fase 7, cerrada en base y deliberadamente vacía) y la gobernanza genérica
> (Fase 5, también vacía), pero no hay propuestas UVR enlazadas, tareas,
> responsables con identidad fuerte, revisiones independientes, aprobaciones
> vinculadas, auditoría UVR, guardias de publicación ni vistas administrativas.

No corresponde pasar a implementación sin cerrar primero los conflictos C1–C12
del §6 y sin aprobación expresa.

## 3. Estado real verificado [REPO]

| Hecho | Evidencia |
|---|---|
| La Fase 7 (§16) está ejecutada y verificada en base. | `sql/08_arquitectura/README.md:336-380` |
| Existen 5 tablas UVR; solo `os_uvr_eligible_catalog` tiene 1 fila (`dentar-pr`). | `sql/08_arquitectura/fase6_uvr.sql:66-80`, `sql/08_arquitectura/verificacion_fase7.sql:17-41` |
| `os_uvr_valuation`, `os_uvr_component`, `os_uvr_conversion` y `os_uvr_geo_index` están vacías. | `sql/08_arquitectura/README.md:373-380` |
| `total_uvr` se calcula en la vista; no hay columna almacenada. | `sql/08_arquitectura/fase6_uvr.sql:206-230`, `sql/08_arquitectura/verificacion_fase7.sql:82-86` |
| El trigger de elegibilidad solo permite prestaciones de catálogos elegibles activos. | `sql/08_arquitectura/fase6_uvr.sql:175-203` |
| Las 5 tablas UVR tienen `REVOKE` a `PUBLIC` y a `origen_admin`; no hay grant posterior. | `sql/08_arquitectura/fase6_uvr.sql:235-254` |
| No existe `/v1/uvr` ni ningún endpoint de valoración. | `sql/08_arquitectura/fase6_uvr.sql:34-35`, `sql/08_arquitectura/README.md:351-355` |
| M1 y M2 de identidad/gobernanza administrativa están aplicados y verificados. | `sql/09_admin/README.md:3-29` |
| La gobernanza pública Fase 5 existe: 4 tablas, 4 FKs de actor, 4 triggers, `evidence_reference NOT NULL`; 0 filas. | `sql/08_arquitectura/fase4_gobernanza.sql:58-147`, `sql/08_arquitectura/README.md:278-289` |
| El panel M2 no conecta con `os_governance_request/review/decision`. | `sql/09_admin/README.md:107-116` |
| La UI pública UVR es trilingüe, de solo lectura y advierte que no hay valores. | `web/uvr.php:5-10`, `portal/translations/messages.es-AR.yaml:946` |
| El panel admin expone Inicio, Organizaciones, Invitaciones, Memberships, Grants, Contexto y Auditoría; no UVR. | `portal/Views/layouts/admin.php:40-51`, `portal/Router.php:145-363` |
| FHIR R4 sigue siendo contrato documental, sin rutas `/fhir/*`. | `docs/architecture/fase12-fhir-contrato.md:1-33`, `README-FHIR.md:6-22` |
| Regresión estable: `603` relaciones, `22` idiomas, `0` solicitudes, `0` valoraciones, `3` reservas DENTAR, `7` reservas OS. | `sql/08_arquitectura/README.md:373-380` |

**Convención de numeración:** los nombres de archivo de `sql/08_arquitectura/`
son históricos y no coinciden con §16 (`fase4_gobernanza.sql` = Fase 5,
`fase5_productos.sql` = Fase 6, `fase6_uvr.sql` = Fase 7). Ver
`sql/08_arquitectura/README.md:39-49`.

## 4. Reutilización posible [REPO → propuesta]

| Capacidad | Activo real | Uso previsto en la gobernanza UVR |
|---|---|---|
| Identidad de actores | `os_admin.app_user`, `os_admin.session`, `AuthService::current()` (`portal/Admin/AuthService.php:195-258`) | Responsable, revisor y aprobador con identidad verificable, sin contraseñas ni tokens en claro. |
| RBAC | 8 roles, 14 permisos, `superadmin => ['*']` (`portal/Admin/Rbac.php:17-59`) | Reutilizar `catalog.*` y `audit.view`; no inventar un sistema paralelo. |
| Grants por catálogo | `os_admin.catalog_grant` con índices parciales global/membership (`sql/09_admin/fase2_gobernanza.sql:70-106`) | Alcance por `dentar-pr` y por organización, con denegación explícita prioritaria. |
| Contexto activo | `Plataforma` = global; `Origen Salud` = organización creada | Misma resolución de contexto para UVR; sin nuevo ámbito. |
| Separación de funciones | `Rbac::canApprove()` (`portal/Admin/Rbac.php:119-130`) | Impedir que el proponente apruebe su propia valoración; hoy no está invocado. |
| Gobernanza genérica | `os_governance_request/review/decision` (`sql/08_arquitectura/fase4_gobernanza.sql:58-106`) | Una sola cadena propuesta → revisión → decisión para UVR. |
| Evidencia obligatoria | `evidence_reference TEXT NOT NULL` (`sql/08_arquitectura/fase4_gobernanza.sql:104`) | Toda aprobación UVR debe tener fuente escrita. |
| Auditoría append-only | `os_admin.audit_log` y `public.os_audit_log` con triggers inmutables (`fase1_identidad.sql:160-171`, `fase4_gobernanza.sql:136-147`) | Registro de propuestas, revisiones, decisiones y cambios de estado. |
| Estados de revisión | `os_review_state` con `is_publication_allowed` (`fase1_infraestructura.sql:85-102`) | Único semáforo de publicación; solo `approved`/`published`. |
| Revisión editorial y vigencia | `os_field_review`, D-19, D-31 (`sql/07_multilingue/15_d19_aprobacion_editorial.sql:28-95`, `18_fase11_invalidacion_mapeos.sql:43-94`) | Patrón de invalidación al cambiar texto o fuente; no cubre valoración. |
| Elegibilidad UVR | `os_uvr_eligible_catalog` + trigger (`fase6_uvr.sql:66-80,175-203`) | Único punto de autorización de prestaciones valorables. |
| Separación valoración/conversión | `os_uvr_valuation` vs `os_uvr_conversion` (`fase6_uvr.sql:85-144`) | Cambiar `uvr_value` no altera componentes y viceversa. |
| Patrones UI | UVR pública (`web/uvr.php`), Browse compare/history (`portal/Views/partials/browse/`), tablas/admin-tabs/grants (`portal/Views/admin/`), paridad i18n (`tests/run.php:1186-1215,1379-1408`) | Base para las vistas A–G sin rediseñar el portal. |

## 5. Brechas críticas

| ID | Brecha | Evidencia |
|---|---|---|
| B1 | No hay tareas/asignaciones, Responsable UVR con FK, `reviewed_by_user_id` ni `approved_by_user_id` en las tablas UVR. | `fase6_uvr.sql:85-102`; `calculated_by TEXT` en `:93` |
| B2 | No hay propuestas UVR enlazadas a `os_uvr_valuation`; `os_governance_request` está vacía y `source_reference` es nullable. | `fase4_gobernanza.sql:58-73`; `sql/08_arquitectura/README.md:278-289` |
| B3 | No hay revisión clínica y económica/metodológica separada y obligatoria. | `README-UVR.md:435-450`; `fase6_uvr.sql:94-95` |
| B4 | `Rbac::canApprove()` no está invocado por controladores ni servicios. | `portal/Admin/Rbac.php:123`; `tests/run.php:1310,1314` |
| B5 | No hay trigger de auditoría sobre ninguna tabla UVR. | `fase4_gobernanza.sql:217-227`; `fase6_uvr.sql:85-167` |
| B6 | No hay guardián de publicación que exija `is_publication_allowed` ni estado aprobado en UVR. | `fase1_infraestructura.sql:91-102`; `fase6_uvr.sql:94-95` |
| B7 | La vista aplica `COALESCE(...,0)` y los componentes exigen `value >= 0`: no hay representación de «no aplicable» ni de ajustes negativos. | `fase6_uvr.sql:110,215-220` |
| B8 | Metodología, fuente e índices son texto libre o tablas vacías; no hay catálogo de metodologías con versión aprobada. | `fase6_uvr.sql:90,132,156-157` |
| B9 | Las siete vistas solicitadas A–G no existen como flujo administrativo. | `portal/Router.php:145-363`; `portal/Views/layouts/admin.php:40-51` |
| B10 | No hay `uvr_value` ni índices geográficos cargados: la conversión no se consume en ninguna vista. | `fase6_uvr.sql:121-170,208-227`; `sql/08_arquitectura/README.md:373-380` |
| B11 | Los modelos heredados `rvu`/`*_uvr` conviven sin reconciliación explícita. | `sql/02_catalogs/origen_catalog_engine.sql:181-186`; `sql/03_dentar/dentar_core_and_diagnosis.sql:263-267` |
| B12 | Documentación interna contradictoria: §10 enumera 4 de 5 tablas, usa `version/country/period` frente a `version_tag/country_code/period_start`, y §11 marca UVR como no ejecutado. | `propuesta-arquitectura-catalogos-sanitarios.md:730-738,784-785,1028,1038,1119-1125` |

## 6. Conflictos a escalar y decisiones requeridas

**Ninguno se resuelve unilateralmente.** Se requiere aprobación o acta formal antes de cualquier cambio.

| ID | Conflicto / decisión | Por qué no se decide aquí |
|---|---|---|
| C1 | El documento habla de `total_uvr` como campo; la arquitectura aprobada lo define derivado. | La Fase 7 lo deriva y el verificador prohíbe almacenarlo. Cambiarlo sería modificar arquitectura aprobada. |
| C2 | Precisión, escala y redondeo de componentes, total, conversión e importe. | La documentación no los define; el SQL usa `NUMERIC(12,4)`, `(14,6)` y `(12,6)`. Elegir regla es decisión metodológica. |
| C3 | Componente `0`, no aplicable o negativo. | Hoy `CHECK (value >= 0)` y `COALESCE(...,0)`. El documento advierte sobre componentes no aplicables/negativos; hace falta semántica autorizada. |
| C4 | Responsable y aprobador UVR. | Las decisiones 7 y 11 siguen pendientes en `propuesta-arquitectura-catalogos-sanitarios.md:1028,1038`; `calculated_by` es texto libre. |
| C5 | Revisiones clínicas y UVR/económicas independientes. | No están modeladas ni documentadas formalmente; requiere definir evidencias y roles. |
| C6 | «Dominios separados clínico/valoración/económico/publicación» con «gobernanza única». | `os_domain_registry` es terminológico y ninguna tabla UVR lo usa; crear dominios nuevos o tablas de gobernanza propias sería un cambio arquitectónico. |
| C7 | `importe_referencial` frente a `estimated_payment`. | El contrato FHIR y la Fase 7 usan `estimated_payment`; el documento usa `importe_referencial`. Requiere nombre canónico visible. |
| C8 | Conexión del panel con Fase 5 y construcción de las vistas A–G. | `sql/09_admin/README.md:107-116` exige autorización nueva; hoy no hay rutas ni UI. |
| C9 | Corrección de §10/§11 y de nombres `version`, `country`, `period`, typo `professioniabial_liability_uvr`. | Son documentos aprobados; no se editan sin acta. |
| C10 | No usar `malpractice` como denominación visible. | Coincide con la regla del documento, pero la columna heredada `dentar_concept_version.malpractice_uvr` no debe renombrarse. Requiere glosario aprobado. |
| C11 | API keys en texto plano y `rate_limit_per_second` no aplicado. | Reutilizar la API sin tocarla implica no ampliar superficie; cualquier cambio de seguridad es decisión independiente. |
| C12 | Inmutabilidad histórica: «nueva valoración = nueva fila, nunca UPDATE». | El trigger actual solo valida elegibilidad en `UPDATE OF service_item_id`; reforzar inmutabilidad cambia comportamiento de base. |

## 7. Principios de la arquitectura propuesta

1. **Aditividad:** no `DROP`, `TRUNCATE`, `DELETE`, renombrado ni migración de datos heredados.
2. **Una sola gobernanza:** `os_governance_request → review → decision → os_audit_log`, sin circuitos UVR paralelos.
3. **Cuatro planos lógicos, una sola base:** clínico/terminológico, valoración UVR, económico/conversión y publicación. No son esquemas ni tablas nuevas por defecto.
4. **Derivación:** `total_uvr` y el importe referencial se calculan; nunca se almacenan como columnas editables.
5. **Sin invención:** sin fuente verificable y aprobación, no se cargan valores, índices ni metodologías.
6. **Publicación fail-closed:** solo lo que tenga fuente, evidencia y `is_publication_allowed = TRUE`.
7. **Identidad fuerte:** actores referenciados a `os_admin.app_user`; tokens y secretos jamás en auditoría.
8. **API intacta:** ninguna ruta `/v1/uvr`, ningún `/fhir/*`, ningún cambio en la guardia actual.
9. **Paridad idiomática:** cualquier texto nuevo se publica en `es-AR`, `en` y `pt-BR`.
10. **Verificación antes que ejecución:** toda fase SQL se prepara en archivos y se valida en `BEGIN READ ONLY`/`ROLLBACK`; el responsable la ejecuta con backup verificado.

## 8. Paquete de entregables

| Documento | Contenido |
|---|---|
| [`gobernanza-uvr-arquitectura.md`](gobernanza-uvr-arquitectura.md) | Este documento: auditoría, reutilización y conflictos. |
| [`gobernanza-uvr-modelo-datos.md`](gobernanza-uvr-modelo-datos.md) | Esquema real, planos lógicos, nombres, precisión y reglas de datos. |
| [`gobernanza-uvr-roles-permisos.md`](gobernanza-uvr-roles-permisos.md) | RBAC real, mapeo de permisos y brechas de autorización. |
| [`gobernanza-uvr-flujos-revision.md`](gobernanza-uvr-flujos-revision.md) | Flujo propuesta/revisión/aprobación/publicación y vistas A–G. |
| [`gobernanza-uvr-auditoria-y-versionado.md`](gobernanza-uvr-auditoria-y-versionado.md) | Auditoría append-only, versionado, inmutabilidad y verificación. |
| [`gobernanza-uvr-plan-implementacion.md`](gobernanza-uvr-plan-implementacion.md) | Fases futuras, compuertas, protocolo SQL y criterios de cierre. |

## 9. Compuerta de aprobación

Antes de cualquier implementación se requiere aprobación expresa para:

- Cerrar C1–C12, en particular decisiones 7 y 11.
- Confirmar que `total_uvr` e `importe_referencial` permanecen derivados.
- Confirmar la política de precisión/redondeo y el tratamiento de `0`/no aplicable/negativo.
- Autorizar la conexión del panel con la gobernanza Fase 5 y las vistas A–G.
- Autorizar cualquier corrección del documento de arquitectura aprobado.

**Hasta entonces: solo análisis. No se ejecuta SQL, no se modifica código ni se despliega.**
