# Arquitectura del portal privado de clientes

> **Estado:** propuesta arquitectónica para revisión. **No implementado.**
> **Fecha:** 2026-11-24.
>
> Este documento define límites y flujos. No autoriza cambios en código, base,
> infraestructura, Invoice Ninja, FreeScout ni en la API pública.

## 1. Convenciones de estado

- **Estado actual comprobado:** ver `auditoria-portal-gobernanza.md`, `auditoria-api.md`, `auditoria-invoice-ninja.md` y `auditoria-infraestructura.md`.
- **Propuesta:** diseño sin ejecutar.
- **Decisión pendiente:** requiere aprobación del propietario.
- **Riesgo:** consecuencia adversa potencial.
- **Dependencia:** etapa previa del plan.
- **Requisito de autorización:** permiso expreso para crear o modificar.

## 2. Nombre y ubicación

**Propuesta:** nuevo frente privado bajo `/portal-clientes`, con prefijos de idioma `/{locale}/portal-clientes/...`.

**Observación terminológica:** el repositorio versionado enruta el panel de gobernanza bajo `/admin` (`portal/Router.php:45-51,154-238`), mientras el proyecto lo denomina `/portal` de gobernanza. En esta documentación:

- **Portal de gobernanza** = panel actual de administración/catálogos, hoy en `/admin`.
- **Portal de clientes** = nuevo frente propuesto `/portal-clientes`.
- **Sitio público** = `med.origen.ar` con rutas localizadas existentes.

**Regla:** no convertir el panel de gobernanza en portal mixto.

## 3. Objetivo

Proporcionar a organizaciones clientes un espacio privado para:

- Gestionar su organización técnica y usuarios.
- Ver servicios habilitados.
- Solicitar servicios.
- Gestionar credenciales API compatibles con el mecanismo real.
- Consultar documentación técnica.
- Acceder al soporte.
- Enlazar a la facturación y pagos del portal nativo de Invoice Ninja.

No proporcionar:

- Facturación propia.
- Pagos propios.
- Precios propios.
- SSO con gobernanza ni con Invoice Ninja.
- Iframe de Invoice Ninja.
- Consumo inventado.

## 4. Límites de responsabilidad

| Sistema | Responsabilidad | No hace |
|---|---|---|
| Sitio público `med.origen.ar` | Contenido institucional, Browse, DENTAR, OFTAR, Docs, UVR, Contacto. | No gestiona clientes técnicos. |
| Portal de gobernanza `/admin` | Identidad de colaboradores, catálogos, propuestas, revisiones, UVR. | No atiende clientes comerciales. |
| Portal de clientes `/portal-clientes` | Organizaciones técnicas, usuarios, servicios, credenciales, enlaces de facturación y soporte. | No duplica facturación ni precios. |
| Invoice Ninja | Clientes, contactos, productos, precios, presupuestos, facturas, pagos y Client Portal. | No es la identidad del portal de clientes. |
| FreeScout | Soporte al cliente. | No autoriza servicios ni credenciales. |
| API `api.origen.ar` | Consulta de catálogos con API Key existente. | No gestiona clientes ni consume métricas. |

## 5. Principios arquitectónicos

1. **Separación de identidades:** `os_admin` solo para gobernanza; esquema propio para clientes.
2. **Sin SSO:** cuentas independientes; un correo igual no vincula identidades.
3. **Fuente de verdad comercial:** Invoice Ninja.
4. **Backend soberano:** todo permiso, precio y habilitación se valida en servidor.
5. **Multi-organización estricto:** contexto activo y filtro por organización en cada consulta.
6. **Sin duplicación financiera:** no guardar precios, facturas ni pagos locales como verdad.
7. **Activación administrativa:** ningún evento comercial habilita acceso por sí solo.
8. **Secretos fuera del navegador:** solo visibles una vez cuando sea posible.
9. **Observabilidad honesta:** si no hay medición real, no se muestra consumo.
10. **Regresión cero:** el sitio público, `/admin` y `/v1` no cambian por efecto colateral.

## 6. Componentes propuestos

### 6.1 Frente HTTP

- Router propio o extensión controlada del router actual con guardias distintas.
- Controladores de:
  - Autenticación y cuenta.
  - Organización y miembros.
  - Servicios y solicitudes.
  - Credenciales API.
  - Documentación.
  - Soporte.
  - Enlace de facturación.
- Vistas propias, sin reutilizar navegación de gobernanza.
- CSRF en todo POST.
- Respuestas sin secretos ni datos financieros duplicados.

**Reutilizables sin mezclar identidad:** mecanismo I18n (`portal/i18n/I18n.php`), motor de vistas (`portal/View.php`), validación común (`portal/Services/Validator.php`), patrón PRG/CSRF (`AdminForm.php`), `RateLimiter`, `SmtpMailer` y `HttpClient`. La reutilización quedó comprobada como patrón en `auditoria-portal-gobernanza.md`; las tablas y sesiones de `os_admin` no se reutilizan.

**No reutilizables para clientes:** sesiones, cookies, roles, memberships ni auditoría de `os_admin`.

### 6.2 Servicios de dominio

| Servicio propuesto | Responsabilidad |
|---|---|
| `CustomerIdentityService` | Usuarios, contraseñas, sesiones, recuperación, verificación. |
| `CustomerOrganizationService` | Organizaciones, membresías, contexto activo. |
| `CustomerInvitationService` | Invitaciones con token hasheado y vencimiento. |
| `EntitlementService` | Servicios técnicos, solicitudes y habilitaciones. |
| `CredentialService` | Creación, rotación y revocación compatibles con API real. |
| `InvoiceNinjaService` | Consulta comercial en backend y vinculación segura. |
| `SupportLinkService` | Enlace a FreeScout sin duplicar tickets. |
| `AuditService` | Eventos append-only del portal de clientes. |

### 6.3 Capa de datos

- Esquema propio propuesto `os_customer.*`.
- Rol de base propio propuesto, sin privilegios sobre `os_admin`, `os_catalog_*`, `snomed_*`, `cie10_*` ni importadores.
- `public.api_clients` se consume solo con permisos mínimos y autorización específica.
- Auditoría append-only por trigger.
- `REVOKE` explícito por tabla, función o vista nueva; sin `ALTER DEFAULT PRIVILEGES`.

### 6.4 Integraciones

- **Invoice Ninja:** API token en servidor, HTTPS, timeouts, reintentos controlados, idempotencia y validación de respuestas.
- **FreeScout:** enlace o integración de soporte sin convertirlo en autoridad de acceso.
- **API `code-api`:** misma clave B2B real; el portal no cambia la autenticación sin autorización.
- **SMTP:** invitaciones y recuperación, sin secretos en cuerpo ni logs.

## 7. Modelo de sesión y autorización

### 7.1 Autenticación

- Contraseña hasheada con mecanismo seguro existente o equivalente autorizado.
- Sesión propia con token hasheado, expiración y revocación.
- Cookies propias, `HttpOnly`, `Secure`, `SameSite` apropiado.
- Regeneración de identificador al login y logout.
- Rate limiting en login, recuperación, invitaciones y solicitudes.
- Mensajes genéricos que no revelen existencia de cuentas.

### 7.2 Autorización

- RBAC propio de clientes.
- Permiso evaluado en servidor para cada acción.
- Contexto activo de organización almacenado en sesión.
- Los permisos de una organización no se suman a los de otra.
- Cambio de contexto recalcula permisos.
- Revocación efectiva en la petición siguiente.

### 7.3 Aislamiento

Toda consulta de negocio sigue la forma:

1. Obtener `organization_id` del contexto de sesión.
2. Validar que el objeto pertenezca a esa organización.
3. Aplicar filtro de organización en SQL.
4. Verificar permiso específico.
5. Registrar operación sensible.

Un `id` recibido del navegador nunca determina autorización por sí solo.

## 8. Flujos principales

### 8.1 Acceso

1. Usuario entra a `/{locale}/portal-clientes/login`.
2. Autenticación contra esquema de clientes.
3. Si tiene una membresía, se establece contexto activo.
4. Si tiene varias, elige explícitamente una.
5. El panel muestra solo datos de esa organización.

### 8.2 Invitación

1. Usuario autorizado invita a una persona por correo.
2. Se crea token hasheado, vencimiento y auditoría.
3. El invitado acepta y crea/vincula su cuenta de cliente.
4. Se crea membresía con rol asignado.
5. La invitación queda `accepted` y no es reutilizable.

### 8.3 Solicitud y habilitación

1. Solicitud pública o desde portal.
2. Backend valida servicios y detecta duplicados.
3. Se identifica o vincula cliente comercial.
4. Se verifica condición comercial en Invoice Ninja.
5. Un administrador habilita el servicio técnico.
6. Se crea `entitlement` y se registra auditoría.
7. Se invita al responsable técnico si corresponde.

### 8.4 Credencial API

1. Usuario autorizado crea credencial.
2. Backend genera clave y la registra en `api_clients`.
3. Metadatos quedan asociados a la organización.
4. Secreto se muestra una sola vez.
5. Rotación y revocación se registran y surten efecto real.
6. No se muestran scopes, consumo ni último uso inexistentes.

### 8.5 Facturación y soporte

- «Facturación y pagos» redirige al portal nativo de Invoice Ninja.
- «Soporte» redirige a FreeScout o usa integración autorizada.
- Ninguno de los dos sistemas delega autorización en el portal de clientes.

## 9. Rutas propuestas

Solo como diseño; no publicadas:

| Ruta | Finalidad |
|---|---|
| `/{locale}/portal-clientes/login` | Acceso. |
| `/{locale}/portal-clientes` | Inicio privado. |
| `/{locale}/portal-clientes/organization` | Mi organización. |
| `/{locale}/portal-clientes/members` | Usuarios y permisos. |
| `/{locale}/portal-clientes/services` | Mis servicios. |
| `/{locale}/portal-clientes/requests` | Solicitudes. |
| `/{locale}/portal-clientes/credentials` | Mis API. |
| `/{locale}/portal-clientes/docs` | Documentación técnica. |
| `/{locale}/portal-clientes/support` | Soporte. |
| `/{locale}/portal-clientes/billing` | Enlace de facturación. |

**Regla:** no alterar las rutas públicas actuales ni sus parámetros GET, fragments AJAX ni hooks JS.

## 10. Internacionalización

- Idiomas `es-AR`, `en`, `pt-BR`.
- URL explícita prevalece sobre navegador.
- Selector conserva idioma entre secciones privadas.
- Claves nuevas en los YAML existentes, con paridad.
- Ningún texto hardcodeado en PHP, JS ni plantillas.
- Los nombres de servicios técnicos no se traducen como términos clínicos.

## 11. Observabilidad y secretos

- Auditoría append-only para: login, logout, invitación, aceptación, cambio de rol, revocación, solicitud, habilitación, suspensión, creación/rotación/revocación de credenciales y cambio de contexto.
- IP y user-agent hasheados con pepper de aplicación.
- Sin contraseñas, tokens ni claves API en logs.
- `X-Request-Id` puede correlacionar cuando exista; no se inventa consumo.
- La sección «Consumo» solo se publica si se implementa medición real verificable.

## 12. Despliegue propuesto

1. Aprobación por acta.
2. Entorno de prueba o base independiente.
3. Migraciones versionadas y reversibles.
4. Backup previo verificado.
5. Revisión de diff y secretos fuera de Git.
6. Publicación controlada.
7. Pruebas de regresión: sitio público, `/admin`, `/v1`, Browse, DENTAR, OFTAR, Docs, UVR y sitemap.
8. Rollback documentado y ensayado.

## 13. Riesgos principales

- Portal mixto por reutilización de `os_admin`.
- Escalada lateral entre organizaciones.
- Duplicados comerciales por vinculación automática por correo.
- Habilitación automática por evento financiero no verificado.
- Exposición de secretos en frontend o logs.
- Consumo o scopes inexistentes presentados como reales.
- Regresión del buscador público por cambios en API.
- Confusión entre `/admin`, `/portal` y `/portal-clientes`.

## 14. Decisiones pendientes

1. ¿El nuevo frente comparte router/base de código o es una aplicación separada?
2. ¿Un usuario pertenece a una o varias organizaciones?
3. ¿Quién habilita servicios técnicamente?
4. ¿Qué se considera condición comercial suficiente?
5. ¿Se creará rol de escritura para credenciales?
6. ¿FreeScout se enlaza solo o se integra más profundamente?
7. ¿Qué servicios reales se publican en la primera versión?
8. ¿Se autorizará acceso de solo lectura a producción para cerrar auditorías?

## 15. Requisito de autorización

No crear rutas, controladores, vistas, esquemas, tablas, roles, grants, integraciones ni despliegues sin aprobación expresa y por etapa.
