# Gobernanza UVR · roles y permisos

**Estado:** PROPUESTA DOCUMENTAL. **No implementada.**
**Depende de:** [`gobernanza-uvr-arquitectura.md`](gobernanza-uvr-arquitectura.md) §6 (C4, C5, C8, C11) y
[`gobernanza-uvr-flujos-revision.md`](gobernanza-uvr-flujos-revision.md).

> No se crean roles, permisos ni grants. Se describe el RBAC real y cómo se
> reutilizaría sin romper la arquitectura de identidad aprobada.

---

## 1. RBAC real [REPO]

| Hecho | Evidencia |
|---|---|
| 8 roles: `superadmin`, `catalog_admin`, `editor`, `reviewer`, `publisher`, `collaborator`, `auditor`, `viewer`. `superadmin => ['*']`. | `portal/Admin/Rbac.php:46-59`; `sql/09_admin/fase1_identidad.sql:214-223` |
| 14 permisos: los 10 de M1 más `admin.orgs.manage`, `admin.invites.manage`, `admin.memberships.manage`, `admin.grants.manage`. | `portal/Admin/Rbac.php:17-33`; `sql/09_admin/fase2_gobernanza.sql:192-207` |
| Los cuatro permisos nuevos de gobernanza se asignan solo a `superadmin`. | `sql/09_admin/fase2_gobernanza.sql:199-207`; `sql/09_admin/README.md:27` |
| Operaciones válidas de grant por catálogo: `view`, `propose`, `edit_draft`, `review`, `approve`, `publish`. | `portal/Admin/Rbac.php:41-44` |
| `catalog_grant` distingue alcance global (`membership_id IS NULL`) y por membership; la denegación explícita gana. | `sql/09_admin/fase2_gobernanza.sql:100-106`; `portal/Admin/Rbac.php:74-117` |
| `RbacRepository` calcula roles/permisos según contexto (`null` = Plataforma; entero = organización), ignora organizaciones inactivas y respeta vigencias. | `portal/Repositories/RbacRepository.php:9-16,22-146` |
| `AuthService::current()` revalida sesión, usuario, roles, permisos y grants en cada petición. | `portal/Admin/AuthService.php:195-258` |
| `AdminGuard::require()` comprueba sesión y permiso en backend; la UI solo oculta controles. | `portal/Admin/AdminGuard.php:34-70`; `portal/Admin/Rbac.php:7-12` |
| Todas las acciones del panel pasan por `POST` + CSRF. | `portal/Controllers/AdminForm.php:12-30` |
| Protección del último `superadmin` global activo. | `portal/Admin/GovernanceService.php:533-535,649-661` |
| Al suspender/revocar membership o usuario se revocan invitaciones pendientes. | Decisión D13; `portal/Admin/GovernanceService.php` y `sql/09_admin/fase2_gobernanza.sql` |
| `canApprove()` impide que el proponente apruebe su propia propuesta. | `portal/Admin/Rbac.php:119-130` |
| No hay scopes por cliente en la API B2B; la clave se almacena en texto plano y `rate_limit_per_second` no se aplica. | `api/http/ApiKeyAuthenticator.php:16-18,47-68`; `api/index.php:224-227` |

## 2. Mapeo propuesto de acciones UVR a permisos existentes

**No se propone aún ningún código de permiso nuevo.** Se reutilizan los 14
existentes para no modificar el RBAC aprobado. Los nombres de roles funcionales
son etiquetas de responsabilidad, no roles SQL nuevos.

| Acción UVR | Permiso existente | Grant sugerido | Responsable funcional | Observación |
|---|---|---|---|---|
| Ver propuestas/valoraciones en el panel | `catalog.view` | `view` sobre `dentar-pr` | `viewer` / `collaborator` | Solo datos publicables o propios según contexto. |
| Proponer valoración o cambio de componentes | `catalog.propose` | `propose` sobre `dentar-pr` | Proponente | Debe quedar registrado como `requested_by_user_id`. |
| Editar borrador | `catalog.edit_draft` | `edit_draft` sobre `dentar-pr` | `editor` | Sin efecto sobre valores publicados. |
| Revisión clínica/terminológica | `catalog.review` | `review` sobre `dentar-pr` | Revisor clínico | Evidencia centrada en prestación/indicación. |
| Revisión metodológica/económica UVR | `catalog.review` | `review` sobre `dentar-pr` | Revisor UVR/económico | Debe ser actor distinto del revisor clínico (C5). |
| Aprobar | `catalog.approve` | `approve` sobre `dentar-pr` | Aprobador | Exigir `Rbac::canApprove()` y `evidence_reference`. |
| Publicar | `catalog.publish` | `publish` sobre `dentar-pr` | `publisher` | Solo con `os_review_state.is_publication_allowed = TRUE`. |
| Consultar auditoría | `audit.view` | No aplica | `auditor` | `os_admin.audit_log` y `public.os_audit_log`. |
| Gestionar usuarios/roles/grants | `admin.users.manage`, `admin.roles.manage`, `admin.grants.manage` | No aplica | `superadmin` | Sin cambios; roles M2 siguen reservados. |

**Decisión pendiente C5:** si se exige que la revisión económica tenga un
permiso propio y distinto, habría que añadir un código nuevo (por ejemplo
`catalog.review_uvr`) y su asignación. **No se hace aquí**: sería una modificación
del RBAC aprobado.

## 3. Brechas de autorización

| Brecha | Evidencia | Tratamiento propuesto |
|---|---|---|
| `canApprove()` existe pero no está invocado por controladores ni servicios. | `portal/Admin/Rbac.php:123`; `tests/run.php:1310,1314` | Conectar `GovernanceService` al aprobar una decisión UVR, con fallo cerrado. |
| `calculated_by` es texto libre y anulable. | `sql/08_arquitectura/fase6_uvr.sql:93` | Sustituir/complementar por actor con FK a `os_admin.app_user` (C4). |
| No hay `assigned_to_user_id`, `reviewed_by_user_id` ni `approved_by_user_id` en UVR. | `fase6_uvr.sql:85-167` | Usar los actores de `os_governance_*` en lugar de duplicar columnas, salvo aprobación de columnas nuevas. |
| No hay tareas ni cola de revisión. | `portal/Router.php:145-363` | Derivar worklist de estados de gobernanza antes de crear tabla de tareas. |
| El panel no consume `os_governance_request/review/decision`. | `sql/09_admin/README.md:107-116` | Requiere autorización nueva (C8). |
| No hay permisos UVR específicos y las seis operaciones de grant no tienen pantalla de flujo. | `portal/Admin/Rbac.php:22-27,41-44`; `portal/Views/layouts/admin.php:40-51` | Las vistas A–G deben apoyarse en los permisos existentes. |
| Sesión y contexto se revalidan por petición, pero el cambio de contexto no exige permiso adicional. | `AuthService.php:282-318`; `AdminContextController.php:12-27` | Mantener; la autorización UVR depende del contexto activo. |
| API B2B sin scopes y con clave en texto plano. | `ApiKeyAuthenticator.php:16-18,47-68` | Fuera de alcance: no ampliar la API ni tocar seguridad sin decisión separada (C11). |

## 4. Gobernanza de grants aplicada a UVR

1. **Un contexto, una autoridad.** En `Plataforma` rigen los grants globales; en
   `Origen Salud` rigen los grants de membership. No se crea un tercer ámbito.
2. **Denegación explícita gana.** Un `allowed = FALSE` bloquea la operación UVR
   aunque el usuario tenga el permiso por rol.
3. **Catalog_code estable.** La validación de códigos se hace contra
   `public.os_catalog` con la conexión pública de solo lectura
   (`portal/Repositories/CatalogReferenceRepository.php:9-68`), nunca con
   privilegios nuevos desde `os_admin`.
4. **Invitaciones.** Los grants UVR se copian al aceptar una invitación y se
   revocan al suspender/revocar membership o usuario, según las decisiones ya
   aprobadas.
5. **Último `superadmin`.** La protección existente se mantiene: ninguna
   operación UVR puede dejar la plataforma sin superadministrador activo.
6. **Auditoría.** Toda creación/cambio de grant UVR queda en
   `os_admin.audit_log` con actor de sesión y `request_id`; sin tokens.

## 5. Decisiones requeridas antes de implementar

- **C4:** quién es el responsable de cálculo y quién aprueba valores UVR; si el
  aprobador debe ser `superadmin` o un rol funcional con `catalog.approve`.
- **C5:** si la revisión económica requiere permiso propio distinto de
  `catalog.review` y cómo se garantiza la independencia de la revisión clínica.
- **C8:** autorización para conectar el panel con la gobernanza Fase 5 y para
  construir las vistas A–G.
- **C11:** confirmar que la API pública permanece intacta y que no se modifica
  el manejo de API keys en esta iniciativa.
- Confirmar que `Rbac::canApprove()` se conecta en la capa de servicio antes de
  habilitar cualquier aprobación.

**Sin estas decisiones no se añade ningún rol, permiso ni grant.**
