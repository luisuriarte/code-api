# Modelo de identidad y organizaciones — Portal de clientes

> **Estado:** propuesta arquitectónica. **No implementado.**
> **Fecha:** 2026-11-24.
>
> Los nombres de tablas son ilustrativos. No se crearon tablas, roles ni datos.

## 1. Convenciones de estado

- **Estado actual comprobado:** documentado en `docs/architecture/fase1-admin-identidad.md` y `fase2-organizaciones-invitaciones.md`, y contrastado con `auditoria-portal-gobernanza.md` y la sección PostgreSQL de `auditoria-infraestructura.md`. La existencia en base en vivo sigue sin verificarse en esta auditoría.
- **Propuesta:** modelo de clientes sin ejecutar.
- **Decisión pendiente:** aprobación del propietario.
- **Riesgo:** consecuencia adversa potencial.
- **Dependencia:** etapa 5 del plan.
- **Requisito de autorización:** creación de esquema, tablas y rol de base.

## 2. Estado actual relevante

El portal de gobernanza ya dispone de identidad y organizaciones **propias de gobernanza**:

- Esquema `os_admin`.
- Tablas `app_user`, `organization`, `membership`, `role`, `role_permission`, `permission`, `invitation`, `invitation_grant`, `session`, `password_reset`, `auth_throttle`, `catalog_grant` y `audit_log`.
- Usuarios con contraseña hasheada (Argon2id + pepper), sesiones persistidas como hash de token, CSRF, RBAC por contexto activo (plataforma u organización), invitaciones por token hasheado y auditoría append-only.
- Rol de base `origen_admin`, con acceso a `os_admin` y sin privilegios sobre `os_catalog_*`.

**Conclusión comprobada:** esa identidad pertenece a colaboradores, revisores, auditores y administradores de catálogos. No representa clientes comerciales.

**Restricción:** no reutilizar estas tablas, roles ni sesiones para el portal de clientes. No modificarlas para adaptarlas.

## 3. Principio de separación

| Ámbito | Identidad | Sesión | Autorización | Datos |
|---|---|---|---|---|
| `/portal` | `os_admin.app_user` | `os_admin.session` | `os_admin.role`/`membership`/`catalog_grant` | Catálogos y gobernanza |
| `/portal-clientes` | Esquema propio propuesto `os_customer.*` | Sesión propia propuesta | Roles propios propuestos | Organizaciones, servicios, credenciales y vínculos comerciales |
| Invoice Ninja | Contactos comerciales | Portal nativo | Permisos de Invoice Ninja | Clientes, facturas, pagos |

Una persona puede tener cuentas en ambos ámbitos, pero **no se vinculan automáticamente**. El correo igual no prueba identidad compartida.

## 4. Entidades propuestas

Los nombres siguientes son ilustrativos y están sujetos a aprobación.

### 4.1 `os_customer_organization`

Representa la organización cliente: empresa, clínica, hospital, universidad, institución pública, estudio de desarrollo o desarrollador independiente.

Atributos conceptuales:

- Identificador interno estable.
- Código público estable e inmutable.
- Razón social y nombre comercial.
- Identificador fiscal normalizado y país emisor.
- País, provincia o región, dirección.
- Sitio web y tipo de organización.
- Responsable principal.
- Estado: `active`, `suspended`, `deactivated`.
- Trazabilidad de alta, modificación y baja lógica.

**Regla:** los datos fiscales de Invoice Ninja no se duplican. Esta entidad guarda solo la referencia de vínculo y los datos técnicos necesarios.

### 4.2 `os_customer_user`

Usuario técnico del portal de clientes.

Atributos conceptuales:

- Correo electrónico único dentro del esquema de clientes.
- Nombre completo.
- Hash de contraseña.
- Estado: `pending`, `active`, `suspended`.
- Verificación de correo.
- Fechas de creación, último login y vencimiento de contraseña si se adopta.
- Nunca contraseña en claro ni hash de Invoice Ninja.

### 4.3 `os_customer_membership`

Relación explícita y auditable entre usuario y organización.

Atributos conceptuales:

- `organization_id`, `user_id`, `role_code`.
- Estado: `active`, `suspended`, `revoked`.
- Quién invitó, quién aceptó, cuándo.
- Baja lógica; no borrado físico.

**Regla:** un usuario puede pertenecer a más de una organización solo si cada membresía es explícita y se resuelve en un contexto activo.

### 4.4 `os_customer_role` y `os_customer_permission`

Propuesta de roles iniciales:

| Rol | Permisos conceptuales |
|---|---|
| `organization_owner` | Administrar organización, invitar, asignar roles, consultar servicios y datos técnicos autorizados, solicitar cambios o cancelaciones. |
| `organization_admin` | Administrar usuarios según permisos, gestionar integraciones, consultar servicios, administrar credenciales autorizadas. |
| `technical_admin` | Gestionar credenciales API, documentación, integraciones y consumo real; configurar entornos técnicos. |
| `developer` | Consultar documentación y credenciales autorizadas, usar API habilitada; sin facturación ni gestión de miembros salvo delegación explícita. |
| `viewer` | Solo lectura de información autorizada. |

**Propuesta:** permisos granulares mínimos, por ejemplo:

- `org.read`, `org.update`.
- `member.read`, `member.invite`, `member.update`, `member.revoke`.
- `service.read`.
- `credential.read`, `credential.create`, `credential.rotate`, `credential.revoke`.
- `docs.read`.
- `usage.read`.
- `billing.link.read` (solo metadatos del vínculo, nunca datos financieros duplicados).
- `support.create`.

**Regla:** `organization_owner` no tiene acceso implícito a todas las organizaciones; sus permisos se evalúan dentro de la membresía correspondiente.

### 4.5 `os_customer_invitation`

Invitación segura, sin registro abierto.

Atributos conceptuales:

- Organización, correo invitado, rol propuesto.
- Token hasheado, vencimiento, estado `pending`, `accepted`, `revoked`, `expired`.
- Quién invitó y cuándo.
- Usuario creado o vinculado al aceptar.

**Propuesta de política:**

- Sin contraseña predefinida en la invitación.
- Nombre completo obligatorio al aceptar.
- Contraseña elegida por el invitado, 12–200 caracteres.
- Token de un solo uso.
- Si el correo ya existe en el portal de clientes, exigir login con esa cuenta antes de aceptar; nunca cambiar la contraseña por el token.
- Revocar invitaciones pendientes al suspender o revocar la membresía de ese correo en esa organización.

### 4.6 `os_customer_session` y autenticación

- Sesión propia, token aleatorio persistido como hash.
- Regeneración de identificador al iniciar y cerrar sesión.
- Cookies con `HttpOnly`, `Secure`, `SameSite` estricto o lax según flujo.
- expiración y revocación.
- CSRF en todo POST.
- Rate limiting y bloqueo por ventana para login y recuperación.
- Recuperación con token de un solo uso y vencimiento.
- Mensajes genéricos: no revelar si un correo existe.

### 4.7 `os_customer_audit_log`

- Registro append-only por trigger.
- Actor, organización, acción, objeto, resultado, fecha.
- IP y user-agent hasheados con pepper de aplicación.
- Sin secretos, tokens ni contraseñas.
- No reutilizar `os_admin.audit_log`.

## 5. Aislamiento multi-organización

Reglas obligatorias propuestas:

1. El contexto activo se guarda en sesión del portal de clientes.
2. Toda consulta incluye filtro de organización derivado del servidor.
3. Un identificador enviado por el navegador nunca decide autorización por sí solo.
4. Antes de operar sobre un objeto, se verifica que pertenezca a la organización activa.
5. Cambiar de contexto recalcula permisos en backend.
6. Los permisos de organizaciones inactivas no se suman.
7. Una revocación surte efecto en la siguiente petición.
8. Las listas y búsquedas nunca filtran por cliente solo en JS.

## 6. Relación con identidades de otros sistemas

| Situación | Regla propuesta |
|---|---|
| Mismo correo en `/portal` y `/portal-clientes` | No vincula cuentas ni permisos. |
| Mismo correo en Invoice Ninja y portal de clientes | No comparte contraseña ni sesión. |
| Necesidad futura de vincular identidades | Procedimiento explícito, auditado y autorizado. |
| SSO | Fuera de la primera versión. |

## 7. Rol de base de datos propuesto

- Rol nuevo, por ejemplo `origen_customer`.
- Solo `LOGIN` y privilegios sobre el esquema de clientes.
- Sin privilegios sobre `os_admin`, `os_catalog_*`, `snomed_*`, `cie10_*` ni tablas de importación.
- Sin `ALTER DEFAULT PRIVILEGES`.
- `REVOKE` explícito por objeto nuevo, según convención del proyecto.
- Conexión separada de la conexión pública `origen_med` y de `origen_admin`.

## 8. Riesgos

- Reutilizar `os_admin` convertiría el portal en mixto y violaría la separación obligatoria.
- Compartir cookies o secreto de sesión permitiría elevación lateral.
- Permitir registro abierto habilitaría acceso a servicios pagos sin contratación.
- No auditar invitaciones dificultaría investigar accesos indebidos.
- Duplicar datos fiscales de Invoice Ninja generaría divergencia comercial.

## 9. Decisiones pendientes

1. ¿Un usuario pertenece a una sola organización o a varias con contexto activo?
2. ¿Quién puede invitar: solo `organization_owner` o también `organization_admin`?
3. ¿Se permite delegar gestión de credenciales a `developer`?
4. ¿Plazo de vencimiento de invitaciones?
5. ¿Recuperación por SMTP con qué remitente y plantilla?
6. ¿Política de contraseña y vencimiento?
7. ¿Nombre definitivo del esquema y del rol de base?

## 10. Requisito de autorización

No crear esquema, tablas, funciones, triggers, roles ni datos hasta que el propietario apruebe este modelo y autorice expresamente la etapa 5.
