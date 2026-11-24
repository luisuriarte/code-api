# Auditoría del portal de gobernanza existente

> **Estado:** auditoría estática de solo lectura del repositorio local. No se conectó a PostgreSQL, no se ejecutó SQL, no se modificaron archivos, no se desplegó ni se probó la base en vivo.
> **Fecha:** 2026-11-24.
>
> Los estados «aplicado/no aplicado» citados son los que declaran los propios artefactos SQL/README; no son verificación independiente de base de datos.

## 1. Convenciones de estado

- **Estado actual comprobado `[REPO]`:** verificado en archivos del repositorio.
- **Documentado como aplicado `[DOC-BD]`:** la documentación afirma que fue ejecutado/verificado por el responsable; no reproducido aquí.
- **No verificado `[NO VERIFICADO]`:** requiere base en vivo, VPS o credenciales.
- **Propuesta:** se remite a los documentos de diseño del portal de clientes.
- **Decisión pendiente:** requiere pronunciamiento del propietario.
- **Riesgo:** consecuencia adversa potencial.
- **Dependencia:** condición previa.
- **Requisito de autorización:** permiso expreso para tocar este portal o su base.

## 2. Inventario comprobado

Bajo `portal/`: **118 archivos**, 114 `.php` y 4 `.yaml`, 1.296.142 bytes.

| Subdirectorio | Archivos |
|---|---:|
| `Controllers` | 15 |
| `Views` | 55 |
| `Repositories` | 18 |
| `Admin` | 12 |
| `Services` | 9 |
| `translations` | 4 |

## 3. Arranque y estructura

- `web/index.php:11-16` requiere `portal/bootstrap.php`, emite `Content-Type`, `Vary: Accept-Language, Cookie` y delega en `OrigenSalud\Portal\Router::dispatch()`.
- `portal/bootstrap.php:12-31` reutiliza el bootstrap raíz, registra autoloader PSR-4 liviano para `OrigenSalud\Portal\`, carga `I18n.php` e inicia `Services\Session::start()`.
- `bootstrap.php:17-29` define `BASE_PATH`, `API_PATH` y `WEB_PATH`, exige `vendor/autoload.php` y carga `.env` de forma tolerante. Si falta Composer, responde `503`.
- `portal/Config.php:12-17` define `baseUrl()` desde `WEB_BASE_URL`, con default `https://med.origen.ar`.
- `portal/Config.php:19-31` define `adminBaseUrl()` desde `ADMIN_BASE_URL`; si está vacío cae a `baseUrl()`. El comentario advierte que las URLs de invitación y reset **nunca** usan el `Host` de la petición, para evitar host header injection.
- `portal/Config.php:33-42` usa conexión pública con `PORTAL_DB_USER`, por defecto `origen_med`.
- `portal/Config.php:107-139` configura conexión administrativa y parámetros de autenticación.
- `.env.example:92-123` documenta `PORTAL_ADMIN_DB_DSN`, `PORTAL_ADMIN_DB_USER=origen_admin`, pepper, lifetimes, `ADMIN_REQUIRE_HTTPS=true`, `ADMIN_BASE_URL`, TTL de invitación y mínimo de reenvío.

**Restricción estructural comprobada:** hay dos conexiones separadas.

- `portal/Repositories/AdminDatabase.php:11-17`: rol `origen_admin` acotado a `os_admin`, sin privilegios sobre `os_catalog_*` ni API pública. `connection()` usa `PDO::ERRMODE_EXCEPTION`, `EMULATE_PREPARES=false` y statement timeout (`30-57`).
- `portal/Repositories/PortalDatabase.php:11-16`: conexión pública de solo lectura.

## 4. Rutas

### 4.1 Router principal

`portal/Router.php`:

- `30-43`: fallback standalone para `/docs` y `/uvr`.
- `45-51`: `/admin` y `/admin/*` se despachan antes del router localizado, sin prefijo de idioma.
- `53-57`: `/` redirige `302` a `/es-AR/`.
- `59-78`: valida locale con `I18n::canonical()`, llama `I18n::boot($locale)` y compone `currentPath`; locale inválido → `404`.
- `81-152`: rutas públicas localizadas: home, docs, dentar, oftar, browse, browse/{id}, about, contact y `POST contact/send`.
- `139-149`: `contact/send` exige POST; si no, `404`.
- `593-614`: `redirect()` y `notFound()`; el `404` renderiza `errors/404`.

### 4.2 Rutas del panel

En `portal/Router.php`:

- `157`: toda petición `/admin*` pasa por `AdminGuard::requireSecure()`.
- `158`: `I18n::boot()` sin argumento.
- `163-174`: `GET /admin` → `AdminHomeController::index()`.
- `176-186`: `/admin/login`, GET y POST.
- `188-198`: `/admin/logout`, **solo POST**; GET → `404`.
- `200-210`: `/admin/forgot`, GET y POST.
- `212-222`: `/admin/reset`, GET y POST.
- `224-228`: `GET /admin/audit`.
- `257-297`: organizaciones, detalle, baja/reactivación y miembros.
- `299-313`: alta y listado de organizaciones.
- `315-329`: reenviar y revocar invitaciones.
- `331-345`: listar/crear invitaciones.
- `347-351`: `GET /admin/invite`, aceptación pública con token.
- `353-357`: `POST /admin/invite/accept`.
- `359-365`: cambio de estado de memberships.
- `367-371`: grants por catálogo.
- `373-377`: cambio de contexto.
- `401-415`: catálogos.
- `417-461`: propuestas, detalle, `review`, `decide`, `publish`.
- `463-475`: detalle de catálogo e ítem.
- `500-519`: `/admin/uvr` y vistas `catalogs`, `tasks`, `compare`, `methodologies`, `monetary`.
- `521-559`: propuestas UVR y `review`/`decide`.
- `561-567`: publicación de valoraciones UVR.

### 4.3 Lo que no existe

- No hay ruta GET `/admin/logout`; el logout existe como POST.
- No hay middleware: la búsqueda de `Middleware` en `portal/` devuelve 0 coincidencias. Las guardias están en `Router.php:157` y en cada controlador.
- No hay rutas `/v1` ni `/fhir` en el portal. `Router.php:480-482` lo declara explícitamente.
- No hay API pública UVR: `web/uvr.php:5-10` es informativa, trilingüe y de solo lectura.
- No hay ruta `/cart` ni controlador de carrito en el código versionado.
- No hay controlador ni vista que use `admin.users.manage` ni `admin.roles.manage`; solo aparecen declarados en `Rbac.php:20-21`.

## 5. Autenticación, sesión y logout

### 5.1 Guardias

`portal/Admin/AdminGuard.php`:

- `22-32`: `requireSecure()` exige HTTPS salvo `ADMIN_REQUIRE_HTTPS=false`; si no, responde `403` en texto plano.
- `73-79`: acepta `$_SERVER['HTTPS']` distinto de `off` o `HTTP_X_FORWARDED_PROTO: https`.
- `38-58`: `require()` exige HTTPS, valida sesión con `AuthService::current()`; sin sesión redirige a `/admin/login?next=...`; sin permiso llama a `denied()`.
- `61-71`: `denied()` responde `403` y renderiza `admin/denied`.

### 5.2 Servicio de autenticación

`portal/Admin/AuthService.php`:

- `52-146`: `attempt()`:
  - normaliza email y calcula fingerprints hasheados de IP y user-agent (`54-58`);
  - rechaza entradas vacías o password > 200 caracteres y registra `login_failed` (`60-64`);
  - aplica throttle por `Token::hash(email|ip)` con límites configurados (`66-73`);
  - exige usuario activo y verifica bloqueo temporal (`75-94`);
  - verifica contraseña con `PasswordHasher::verify()` (`96`);
  - resuelve contexto activo (`108-119`);
  - crea token opaco y guarda solo su hash SHA-256 en `os_admin.session` (`121-127`);
  - regenera ID de sesión y rota CSRF (`129-137`);
  - registra `login_success` (`139-143`).
- `148-175`: `logout()` revoca el token, registra `logout`, limpia sesión local, rota CSRF y regenera ID. Captura `RepositoryException` para no dejar al usuario atrapado en un panel roto; el token expirará server-side.
- `195-280`: `current()` revalida en cada petición token, usuario, contexto, `touch` y recarga roles/permisos/grants (`250-254`). Si es `superadmin`, inyecta `Rbac::WILDCARD` (`260-265`). Si falla la RBAC fresca, devuelve `null`.
- `286-318`: `switchContext()` exige membership vigente, audita el cambio y rota CSRF.
- `323-357`: `resolveContext()` solo acepta contextos con memberships globales o de organizaciones activas; si el contexto guardado dejó de ser válido, elige uno disponible y registra `organization_context_invalidated`.
- `360-402`: recuperación con throttle por IP, token opaco, enlace construido con `Config::adminBaseUrl()`, SMTP y auditoría. Si falla el correo, revoca tokens y registra `password_reset_mail_failed`.
- `405-443`: reset valida token hex de 32 bytes, password de 12 a 200 caracteres, hash con pepper, revoca sesiones, marca token usado, rota CSRF y registra `password_reset_completed`.

### 5.3 Hash, tokens y cookie

| Archivo | Hecho comprobado |
|---|---|
| `portal/Admin/PasswordHasher.php:23-39` | `password_hash($password . pepper, ...)`, `password_verify()`. Argon2id con `memory_cost=65536`, `time_cost=4`, `threads=1`, reserva bcrypt cost 12; pepper desde `ADMIN_PASSWORD_PEPPER`, no guardado en base. |
| `portal/Admin/Token.php:15-39` | `random_bytes`, hash SHA-256, `hash_equals`, `isValidHex()` y `fingerprint()` con pepper. En claro solo viaja en cookie/URL; en base se guarda hash. |
| `portal/Services/Session.php:12-31` | Cookie `origen_portal`, `lifetime=0`, `path=/`, `secure=$https`, `httponly=true`, `samesite=Lax`. Detecta HTTPS por `HTTP_X_FORWARDED_PROTO`. |
| `portal/Services/Csrf.php:12-40` | Campo `_csrf`, token `bin2hex(random_bytes(32))`, validación con `hash_equals` y `rotate()`. |

### 5.4 Precisión sobre logout

- El formulario de la barra admin envía `_csrf` en `portal/Views/layouts/admin.php:179-186`.
- `AdminAuthController::logout():65-70` **no ejecuta `Csrf::valid()`**.
- Sí está restringido a POST por `Router.php:188-198`.

**Riesgo:** logout POST sin validación CSRF en controlador. No se propone cambio; se registra como limitación comprobada.

## 6. RBAC

`portal/Admin/Rbac.php`:

- `15`: comodín `WILDCARD='*'`.
- `18-33`: 14 permisos declarados: `admin.view`, `admin.users.manage`, `admin.roles.manage`, `catalog.view`, `catalog.propose`, `catalog.edit_draft`, `catalog.review`, `catalog.approve`, `catalog.publish`, `audit.view`, `admin.orgs.manage`, `admin.invites.manage`, `admin.memberships.manage`, `admin.grants.manage`.
- `46-59`: 8 roles: `superadmin`, `catalog_admin`, `editor`, `reviewer`, `publisher`, `collaborator`, `auditor`, `viewer`. `superadmin` tiene `['*']`.
- `64-72`: `hasPermission()` solo acepta códigos declarados y respeta wildcard.
- `80-117`: `canAccessCatalog()` aplica wildcard, denegación explícita prioritaria (`109-111`) y requiere coincidencia de catálogo/operación.
- `123-130`: `canApprove()` impide autoprobación: `proposerId !== reviewerId` y permiso `catalog.approve`.
- `191-222`: `canGrantRole()` impide otorgar `superadmin` salvo wildcard/rol superadmin y aplica techo de permisos.

`portal/Repositories/RbacRepository.php`:

- `11-15`: contexto `null` = plataforma, solo memberships globales; entero = globales + memberships de esa organización; las organizaciones inactivas nunca se suman.
- `22-87`: roles/permisos con `contextClause()`, filtro `m.status = active`, vigencia y `organization.is_active = true`.
- `93-130`: grants por catálogo.
- `127-129`: fallback `legacyGrantsForUser()` ante `PDOException`, para mantener válidos grants globales M1.
- `136-145`: `contextClause()`.
- `165-179`: fallback legacy sobre `os_admin.catalog_grant` sin `membership_id`.

Uso en servicios/controladores:

- `CatalogGovernanceService.php:303` y `UvrGovernanceService.php:518` invocan `Rbac::canApprove()`.
- `GovernanceService.php:154,455` usan `Rbac::canGrantRole()`.
- `CatalogGovernanceService.php:524-530` y `UvrGovernanceService.php:663-675` concentran autorización por catálogo.
- `AdminGuard::require(['permission' => ...])` aparece en los controladores admin.

**Regla comprobada:** la UI oculta controles, pero la autorización real se verifica en backend.

## 7. CSRF

`portal/Controllers/AdminForm.php`:

- `16-22`: `requirePost()` → `404` si no es POST.
- `24-31`: `validCsrf()` lee `_csrf` y delega en `Csrf::valid()`.
- `33-99`: PRG, flash, excepciones y redirect `303`.

Cobertura comprobada:

| Archivo | Líneas |
|---|---|
| `AdminAuthController.php` | login `37-43`; forgot `88-94`; reset `136-142`; logout sin validación `65-70`. |
| `AdminOrganizationController.php` | `49,122,154,176`. |
| `AdminInvitationController.php` | `61,93,179` (aceptación pública en `179`). |
| `AdminMembershipController.php` | `19,49`. |
| `AdminContextController.php` | `17`. |
| `AdminCatalogController.php` | `163,190,213,236`. |
| `AdminUvrController.php` | `345,391,414,437`. |
| `Services/ContactService.php` | `37`; además `RateLimiter::hit('contact', ...)` en `60`. |

`RateLimiter.php:7-12` declara que el limitador es por sesión y acción y **no sustituye** un límite por IP en capa de servidor web.

## 8. Auditoría

### 8.1 Escritura

- `portal/Admin/AuditLogger.php:11-17`: escribe en `os_admin.audit_log`; IP y user-agent solo como hash con pepper; si falla la auditoría, la operación falla también (`fail closed`). `record()` en `21-52`.
- `portal/Repositories/AuditRepository.php:10-15`: append-only, sin `UPDATE` ni `DELETE`.
- `AuditRepository.php:19-49`: solo `INSERT`.
- `AuditRepository.php:53-69`: `recent()` limita entre 1 y 100, ordena por `occurred_at DESC, id DESC`.

### 8.2 Base de datos

`sql/09_admin/fase1_identidad.sql`:

- `140-155`: tabla `os_admin.audit_log`.
- `160-171`: función `os_admin.audit_log_immutable()` y trigger `trg_audit_log_immutable` antes de `UPDATE OR DELETE`.
- `176-209`: rol `origen_admin`, `REVOKE` a `PUBLIC`, `GRANT SELECT, INSERT ON os_admin.audit_log` y grants de secuencias.

`sql/08_arquitectura/fase4_gobernanza.sql:232-249`: `REVOKE ALL` sobre `public.os_governance_request`, `os_governance_review`, `os_governance_decision` y `os_audit_log`, incluido `origen_admin`.

### 8.3 Eventos registrados en código

Autenticación/contexto en `AuthService.php`:

`login_failed`, `login_throttled`, `login_success`, `logout`, `organization_context_invalidated`, `organization_context_switched`, `password_reset_throttled`, `password_reset_mail_failed`, `password_reset_requested`, `password_reset_failed`, `password_reset_completed`.

Gobernanza M2 en `GovernanceService.php`:

`organization_created`, `organization_updated`, `organization_reactivated`, `organization_deactivated`, `invitation_created`, `invitation_resent`, `invitation_revoked`, `invitation_accepted`, `invitation_accept_failed`, `invitation_mail_failed`, `catalog_grant_created`, `catalog_grant_updated`, estados de membership.

Catálogos en `CatalogGovernanceService.php`:

`catalog_change_proposed`, `catalog_review_recorded`, `catalog_decision_recorded`.

UVR en `UvrGovernanceService.php`:

`uvr_valuation_proposed`, `uvr_review_clinical_recorded`, `uvr_review_economic_recorded`, `uvr_decision_recorded`, `uvr_published`.

### 8.4 Consulta

`portal/Controllers/AdminHomeController.php:32-50` exige `audit.view`, obtiene `AuditRepository::recent(50)` y renderiza `admin/audit`. Si falla la consulta, muestra `events = []`.

## 9. Gobernanza de catálogos y UVR

### 9.1 Catálogos

`portal/Repositories/CatalogGovernanceRepository.php`:

- `9-16`: lecturas con conexión pública de solo lectura; solicitudes, revisiones, decisiones y publicación con conexión administrativa. La publicación invoca `public.os_catalog_apply_governed_change()`, declarada `SECURITY DEFINER`. El comentario afirma que `origen_admin` nunca recibe `INSERT/UPDATE` directo sobre `os_catalog_*`.
- `139-180`: lecturas de `public.os_governance_request`, `os_governance_review` y `os_governance_decision`.
- `191,218,240`: `INSERT` en tablas de gobernanza pública.
- `257`: `UPDATE ... SET review_status`.
- `266`: `SELECT public.os_catalog_apply_governed_change(:id, :actor, :email)`.

`sql/08_arquitectura/catalogos_gestion_gobernada.sql`:

- `1-16`: propuesta del 2026-11-20; publicación solo tras dos revisiones aprobadas por actores distintos; decisión con evidencia; `SECURITY DEFINER`; `origen_admin` solo recibe `EXECUTE`.
- `48-59`: función `public.os_catalog_apply_governed_change(...)`.
- `262-269`: `REVOKE ALL` a `PUBLIC` y `GRANT EXECUTE` condicionado a `to_regrole('origen_admin')`.

### 9.2 UVR

`portal/Repositories/UvrRepository.php`:

- `11-16`: usa `AdminDatabase`; no escribe en `os_catalog_*`, no carga valores inventados ni expone datos a API pública.
- `28-56`: transacciones sobre conexión administrativa.
- `63-75`: detecta esquema U7-B con `to_regclass` sobre `public.os_prestacion`, `public.os_uvr_profile`, `public.os_uvr_prestacion_valuation` y `public.v_os_uvr_prestacion_public`.
- `187-267`: escrituras en `public.os_uvr_*`.
- `435-603`: propuestas, valoraciones, componentes, revisiones, decisiones, estados, aprobaciones y publicación.

`portal/Admin/UvrImporteService.php`:

- `7-13`: `importe_referencial` es derivado, nunca almacenado; nombre interno/FHIR `estimated_payment`; redondeo solo de presentación; sin conversión aprobada, resultado `null`.
- `19-53`: `calcular()` exige conversión aprobada y `uvr_value > 0`; devuelve `total_uvr`, `uvr_value`, `currency`, `importe_referencial`, `estimated_payment` y `es_estimacion => true`.
- `63-104`: normaliza decimales con punto/coma y separadores de miles.

`portal/Admin/UvrGovernanceService.php`:

- `181-186`: `transversal()` exige esquema U7-B y datos no vacíos.
- `189-217`: lecturas con permiso `catalog.view` o acceso por catálogo.
- `518`: separación de funciones mediante `Rbac::canApprove()`.
- `573`: publicación con `catalog.publish`.

`sql/08_arquitectura/uvr_correccion_secuencias_panel.sql:8-12`: los triggers `os_uvr_audit_trigger()` y `os_governance_audit_trigger()` insertan en `public.os_audit_log` y requieren GRANT de secuencias e `INSERT` para `origen_admin` porque no son `SECURITY DEFINER`.

## 10. Componentes reutilizables sin mezclar identidad

| Componente | Evidencia | Posible reutilización en clientes |
|---|---|---|
| `portal/View.php:15-33` | Render de plantillas, inyecta locale, `t`, `baseUrl`, `year`, mailtos; `EXTR_SKIP`; layout. | Sí, con vistas propias. |
| `portal/Views/layouts/main.php:15-24` | Canonical, alternates, `og:locale`, `lang`. | Sí, adaptado. |
| `portal/Views/layouts/admin.php:61-68,159-187,202-210` | Navegación por permisos, contexto, logout y selector `?lang=`. | No reutilizar tal cual; es de gobernanza. |
| `portal/Controllers/AdminForm.php:33-99` | PRG, flash, CSRF, excepciones. | Sí, como patrón. |
| `portal/Admin/Rbac.php:7-12` | Reglas puras sin PDO. | No reutilizar roles; sí como referencia de diseño. |
| `portal/Admin/AuditLogger.php` | Registro central con hashes. | No reutilizar tabla; sí como patrón. |
| `portal/Services/Validator.php:12-36` | `text`, `email`, `choice`. | Sí. |
| `portal/Services/RateLimiter.php:7-12` | Por sesión y acción. | Sí, con límite por IP en servidor además. |
| `portal/Services/SmtpMailer.php`, `OpenWaClient.php`, `HttpClient.php` | Correo y HTTP. | Sí, con configuración separada. |
| `portal/i18n/I18n.php` | Ver sección 11. | Sí. |
| `portal/Repositories/*` | 18 repositorios con separación pública/administrativa. | No reutilizar los de `os_admin`; sí el patrón de conexiones. |

**No reutilizables para clientes:** `os_admin.app_user`, `os_admin.session`, `os_admin.role`, `os_admin.membership`, `os_admin.invitation`, `os_admin.catalog_grant` ni `os_admin.audit_log`.

## 11. Idiomas

`portal/i18n/I18n.php`:

- `25-33`: `SUPPORTED = ['es-AR','en','pt-BR']`, `DEFAULT_LOCALE='es-AR'`, cookie `origen_locale`, alias `es→es-AR`, `pt→pt-BR`.
- `35-50`: metadatos por locale (`hreflang`, `og_locale`, etiqueta, short, `api_language`).
- `199-214`: resolución por `Accept-Language`, fallback `es-AR`.
- `216-226`: crea `Symfony\Component\Translation\Translator`, fallback `es-AR`, carga YAML con `YamlFileLoader`.

Catálogos en `portal/translations`:

| Archivo | Líneas | Observación |
|---|---:|---|
| `messages.es-AR.yaml` | 1762 | Sección `admin:` en `1371`. |
| `messages.en.yaml` | 1762 | Sección `admin:` en `1371`. |
| `messages.pt-BR.yaml` | 1762 | Sección `admin:` en `1371`. |
| `messages.es.yaml` | 1038 | Existe, pero no está en `I18n::SUPPORTED`; no es seleccionable. |

El panel usa `I18n::boot()` en `Router.php:158`; el selector admin modifica `?lang=` en `layouts/admin.php:202-210`.

## 12. Dependencias y activos

- `composer.json:6-15`: PHP `>=8.2`, extensiones `json`, `mbstring`, `pdo`, `pdo_pgsql`; `symfony/translation ^7.3`, `symfony/yaml ^7.3`, `vlucas/phpdotenv ^5.6`.
- `composer.json:16-25`: PSR-4 solo para `OrigenSalud\Api\*` y `OrigenSalud\Tools\Php\*`; el portal usa su autoloader en `portal/bootstrap.php:14-27`.
- `package.json:5,7-20`: build local sin CDN; scripts CSS/JS; Tailwind 4.3.5, Alpine 3.17.5, Flowbite 4.0.2, Lucide 1.77.0.
- `tools/build-assets.js:9-27`: copia JS desde `node_modules`.
- Existen `composer.lock`, `package-lock.json`, `vendor/` y `node_modules/`.
- Activos generados: `web/assets/css/{admin,public,app}.css` y `web/assets/js/{alpine.min,flowbite.min,lucide.min,browse-explorer}.js`.

## 13. Restricciones que el código respeta

1. Código de aplicación fuera del DocumentRoot (`web/index.php:8`, `portal/bootstrap.php:6`).
2. HTTPS obligatorio para el panel, conmutable por `ADMIN_REQUIRE_HTTPS`.
3. Separación de conexiones `origen_med` vs `origen_admin`.
4. Menor privilegio sobre catálogos: sin `INSERT/UPDATE` directo de `origen_admin` en `os_catalog_*`; publicación vía `SECURITY DEFINER`.
5. Auditoría append-only con trigger de inmutabilidad.
6. Datos sensibles hasheados: tokens SHA-256, IP/UA con pepper, contraseñas con pepper y Argon2id/bcrypt.
7. RBAC verificado en backend aunque la UI oculte controles.
8. Denegación explícita y separación de funciones.
9. Contexto organizacional vigente: memberships activos y organizaciones activas.
10. Valores UVR derivados, sin importes almacenados ni conversiones inventadas.
11. URLs de invitación/reset construidas con base configurada, nunca con `Host`.
12. SQL aditivo y sujeto a autorización; el portal no ejecuta migraciones automáticamente.

## 14. Riesgos y limitaciones comprobadas

1. Logout POST sin validación CSRF en `AdminAuthController::logout():65-70`.
2. No hay middleware; las guardias están dispersas.
3. `admin.users.manage` y `admin.roles.manage` declarados pero sin uso.
4. Fallback RBAC M1 ante `PDOException` en `RbacRepository.php:127-129`: dependencia funcional del esquema desplegado.
5. Rate limit de contacto por sesión, no por IP en capa web.
6. Contradicción documental M1: `fase1_identidad.sql:1-7` dice «NO EJECUTAR», mientras `sql/09_admin/README.md:3-10` afirma aplicado y verificado.
7. Contradicción en gobernanza: `fase4_gobernanza.sql:1-10` sigue marcada como propuesta, pero el código y otros artefactos usan sus tablas.
8. Triggers UVR no `SECURITY DEFINER`, con dependencia de grants explícitos.
9. `messages.es.yaml` existe pero no es seleccionable.
10. No hay API pública UVR.
11. No hay recuperación ni logout por GET; la recuperación sí existe en `forgot/reset`.
12. `admin.view` declarado pero no usado como guardia explícita en los controladores revisados.
13. No se verificó base en vivo; ningún estado `[DOC-BD]` fue reproducido aquí.

## 15. Implicaciones para el portal de clientes

- La identidad existente es adecuada para gobernanza, **no** para clientes comerciales.
- La separación de conexiones es un patrón sano que debe replicarse con un rol propio.
- El patrón de token opaco hasheado, pepper, CSRF, regeneración de ID y auditoría append-only puede servir como referencia, sin reutilizar tablas ni sesiones.
- La ausencia de middleware es una limitación a considerar si se agrega un segundo frente privado.
- El logout sin CSRF y los permisos declarados sin uso son hallazgos del portal actual; no se modifican en esta auditoría.
- Las contradicciones documentales refuerzan la regla de no ejecutar nada sin verificación previa en base.

## 16. Decisión pendiente y autorización

No se propone cambio en este portal. Cualquier modificación a `portal/`, `os_admin`, rutas, vistas, traducciones, conexiones o políticas de autenticación requiere autorización expresa y separada de la aprobación del portal de clientes.
