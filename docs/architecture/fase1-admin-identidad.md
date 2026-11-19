# Fase 1 / M1 — Identidad, autenticación y RBAC del panel de administración

**Estado del código:** IMPLEMENTADO EN EL REPOSITORIO.
**Estado de la base:** M1 **NO EJECUTADO**. El artefacto `sql/09_admin/fase1_identidad.sql` está propuesto y requiere revisión y ejecución manual.
**Autorización:** Acta M0 (2026-11-19) + autorización expresa del responsable para Fase 1 / M1.
**No incluye:** DDL sobre `os_*`, cambios en la API pública, deploy ni commit.

## 1. Alcance

Esta fase crea la línea base de identidad para la gobernanza de catálogos:

- Usuarios humanos con contraseña hasheada (Argon2id + pepper de aplicación).
- Login, logout y recuperación de contraseña por vínculo de un solo uso.
- Sesiones persistidas como hash de token, con expiración y revocación.
- RBAC con roles y permisos efectivos calculados en backend.
- Grants por catálogo y operación, con denegación explícita prevaleciente.
- Auditoría append-only de acceso (`os_admin.audit_log`).
- Panel mínimo: `/admin`, `/admin/audit`, `/admin/login`, `/admin/forgot`, `/admin/reset`, `/admin/logout`.

**No se modificó:** `api/`, `os_catalog_*`, importadores, Browse Codes, Docs ni UVR.

## 2. Arquitectura de la fase

```text
web/index.php → portal/bootstrap.php → portal/Router.php
                                          │
                              /admin/* (sin prefijo de idioma)
                                          │
                       AdminGuard (HTTPS + sesión + permiso)
                                          │
             ┌────────────────────────────┼──────────────────────────────┐
             │                            │                              │
      AuthService                   Rbac / RbacRepository         AuditLogger
             │                            │                              │
   UserRepository, SessionRepository,   catalog_grant            AuditRepository
   AuthThrottleRepository,
   PasswordResetRepository
             │
   AdminDatabase (rol origen_admin, solo os_admin)
             │
   PostgreSQL: origen_codes / esquema os_admin
```

La conexión pública (`origen_med`, solo lectura) queda intacta. La conexión
administrativa usa `origen_admin`, sin privilegios sobre `os_catalog_*`.

## 3. Seguridad aplicada

| Control | Implementación |
|---|---|
| Contraseñas | `password_hash` Argon2id (bcrypt como reserva) + pepper desde `ADMIN_PASSWORD_PEPPER`. Nunca se guarda en claro. |
| Tokens | 32 bytes aleatorios; en base solo `sha256(token)`. Comparación con `hash_equals`. |
| Sesión | `session_regenerate_id(true)` al entrar y al salir; validación contra `os_admin.session` en cada petición. |
| CSRF | `Csrf::valid()` en todo POST y rotación después de login/reset/logout. |
| Fuerza bruta | `os_admin.auth_throttle` con bloqueo por ventana y clave hash(email+IP), más bloqueo por usuario. |
| HTTPS | `ADMIN_REQUIRE_HTTPS=true` por defecto; el panel rechaza credenciales sobre HTTP. |
| Separación de funciones | `Rbac::canApprove()` impide aprobar la propia propuesta (se usa en Fase 4). |
| Auditoría | `audit_log` append-only por trigger; IP y user-agent se guardan como hash con pepper. |
| Redirecciones | `next` solo acepta rutas internas `/admin/...`. |
| Respuesta de error | Mensajes genéricos: no revela si un email existe. |
| Base no disponible | Los POST devuelven un error genérico vía PRG (sin 500); `current()` falla cerrado y `logout()` siempre limpia la sesión local. |

## 4. Archivos nuevos / modificados

Ver `git status` para la lista exacta. Los principales son:

- `sql/09_admin/fase1_identidad.sql` — migración propuesta, **no ejecutada**.
- `sql/09_admin/verificacion.sql` — verificación `SELECT`-only.
- `sql/09_admin/README.md` — requisitos y rollback propuesto.
- `portal/Admin/` — `PasswordHasher`, `Token`, `Rbac`, `AuthService`, `AuditLogger`, `AdminGuard`.
- `portal/Repositories/` — `AdminDatabase`, `UserRepository`, `SessionRepository`, `RbacRepository`, `AuthThrottleRepository`, `PasswordResetRepository`, `AuditRepository`.
- `portal/Controllers/` — `AdminAuthController`, `AdminHomeController`.
- `portal/Views/admin/` y `portal/Views/layouts/admin.php` — panel aislado de la navegación pública.
- `portal/Config.php`, `.env.example`, `portal/Router.php`, `web/assets/css/app.css`.
- Traducciones `admin.*` en `es-AR`, `en`, `pt-BR` y `es`.
- `tools/php/admin_bootstrap.php` — alta del primer superadministrador (solo CLI).
- `tests/run.php` — 102 comprobaciones nuevas.

## 5. Verificación local

```bash
php -l <cada archivo PHP nuevo>
php tests/run.php
# OK: 2448 comprobaciones.
```

Prueba HTTP local sin base (`php -S 127.0.0.1:8899 -t web`, con
`ADMIN_REQUIRE_HTTPS=false` solo para la prueba):

- `GET /admin` → 302 a `/admin/login?next=%2Fadmin`.
- `GET /admin/login`, `/admin/forgot`, `/admin/reset` → 200, con selector
  de idioma y token CSRF presente.
- `GET /admin/audit` sin sesión → 302 al login conservando `next`.
- `GET /admin/desconocido` → 404.
- `POST /admin/login` y `/admin/forgot` sin base configurada → 303 con
  mensaje genérico «servicio de autenticación no disponible», sin 500.
- `POST /admin/login` con CSRF inválido → 303 con error de sesión expirada.

El servidor de prueba se detuvo al finalizar; no hubo conexión a PostgreSQL.

## 6. Pasos pendientes del operador (NO realizados)

1. Revisar y ejecutar `sql/09_admin/fase1_identidad.sql` contra `origen_codes` con `psql -v ON_ERROR_STOP=1`.
2. Ejecutar `sql/09_admin/verificacion.sql` y archivar la salida.
3. Asignar contraseña a `origen_admin` y completar `PORTAL_ADMIN_DB_*` y `ADMIN_PASSWORD_PEPPER` en el entorno del VPS.
4. Configurar SMTP para la recuperación de contraseña.
5. Crear el primer superadministrador:
   ```bash
   php tools/php/admin_bootstrap.php
   ```
   Si el usuario quedó creado pero falló la asignación de roles (por ejemplo,
   por el permiso `INSERT` sobre `os_admin.membership`), completar sin cambiar
   la contraseña con:
   ```bash
   php tools/php/admin_bootstrap.php --repair-existing
   ```
6. Forzar HTTPS en el vhost y mantener `ADMIN_REQUIRE_HTTPS=true`.
7. Verificar `/admin/login` en los tres idiomas y que `/admin/audit` exija el permiso `audit.view`.
8. Recién entonces solicitar autorización para Fase 2.

## 7. Gate de salida

La Fase 1 se considera cerrada cuando:

- M1 está aplicado y verificado en `origen_codes`.
- Existe al menos un superadministrador creado por CLI.
- Login/logout/reset funcionan sobre HTTPS con CSRF y auditoría.
- Las pruebas siguen en verde y no hay cambios en la API pública.

## 8. Fuera de alcance (requiere autorización nueva)

- Fase 2: organizaciones, invitaciones y memberships de colaboradores.
- Fases 3-5: propuestas, revisión y publicación atómica.
- M6: hash de API keys, scopes, 429 y consola self-service.
- M7: D-31 y llenado de `os_catalog_language`.
- Cualquier deploy o push a producción.
