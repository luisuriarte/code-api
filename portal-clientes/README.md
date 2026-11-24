# Portal privado de clientes — Etapa 5

> **Estado:** artefactos preparados para entorno de prueba. **No ejecutados en base. No desplegados.**
> **Autorización:** `docs/portal-clientes/acta-autorizacion-etapa-5.md`.

## 1. Límites

Este código es independiente de `/portal` y de `/admin`:

- sesión PHP propia (`origen_customer_portal`);
- namespace propio (`OrigenSalud\CustomerPortal`);
- base y credenciales propias (`PORTAL_CUSTOMER_DB_*`);
- pepper de contraseñas y de huellas distinto;
- dominio i18n `customer_portal`, sin modificar los YAML del portal público.

No implementa Invoice Ninja, FreeScout, entitlements, credenciales API, facturación ni pagos. Tampoco modificó Nginx, PHP-FPM ni el front controller de `/portal`.

## 2. Estructura

- `bootstrap.php`: autoloader e inicio de sesión.
- `Config.php`: variables de configuración; sin secretos reales.
- `Router.php`: rutas `/portal-clientes/{locale}/...`.
- `I18n/CustomerI18n.php`: reutiliza Symfony Translator con dominio separado.
- `Services/`: sesión, CSRF, RBAC, autenticación, auditoría, base y notificaciones de prueba.
- `Repositories/`: acceso parametrizado a `os_customer`.
- `Controllers/`: login, logout, recuperación, invitaciones, organizaciones y miembros.
- `Views/` y `translations/`: interfaz en `es-AR`, `en` y `pt-BR`.
- `../sql/10_portal_clientes/`: migraciones `up`, `down` y verificaciones.

El front controller nuevo es `web/portal-clientes/index.php`, con un `.htaccess` propio dentro de ese directorio.

## 3. Variables de entorno — solo nombres

| Variable | Uso |
|---|---|
| `PORTAL_CUSTOMER_BASE_URL` | Base canónica para links. Nunca usar `Host` de la petición. |
| `PORTAL_CUSTOMER_DB_DSN` | DSN de la base de prueba. Vacío por defecto: la app no conecta. |
| `PORTAL_CUSTOMER_DB_USER` | Usuario de base, por defecto `origen_customer`. |
| `PORTAL_CUSTOMER_DB_PASS` | Contraseña; solo en gestor seguro, nunca en Git. |
| `PORTAL_CUSTOMER_DB_STATEMENT_TIMEOUT` | Timeout en segundos. |
| `PORTAL_CUSTOMER_PASSWORD_PEPPER` | Pepper de contraseñas, distinto de `os_admin`. |
| `PORTAL_CUSTOMER_TOKEN_PEPPER` | Pepper para hashes de IP/user-agent. |
| `PORTAL_CUSTOMER_SESSION_TTL` | TTL de sesión en segundos. |
| `PORTAL_CUSTOMER_LOGIN_LIMIT` | Intentos por ventana. |
| `PORTAL_CUSTOMER_LOGIN_WINDOW` | Ventana en segundos. |
| `PORTAL_CUSTOMER_LOCK_MINUTES` | Minutos de bloqueo. |
| `PORTAL_CUSTOMER_RESET_TTL` | Vigencia del reset. |
| `PORTAL_CUSTOMER_INVITE_TTL` | Vigencia de invitaciones. |
| `PORTAL_CUSTOMER_REQUIRE_HTTPS` | Exigencia HTTPS. |

No hay SMTP real en esta etapa. `TestNotification` devuelve el link de invitación o reset al administrador que hace la prueba, sin enviar correo.

## 4. Ejecución por el responsable

Solo en base independiente de prueba:

```bash
cd /var/www/html/origen.ar/code-api
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V5.001__os_customer_identity.up.sql
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V5.001__os_customer_identity.verify.sql
```

Rollback ensayado:

```bash
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V5.001__os_customer_identity.down.sql
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V5.001__os_customer_identity.verify_rollback.sql
```

El `down` conserva `os_customer.audit_log` y su trigger. Una nueva ejecución del `up` reutiliza esa tabla sin borrar historial.

**Prohibido:** ejecutar estos archivos contra `origen_codes` productiva.

## 5. Verificación local ya realizada

- `php -l` en todos los archivos PHP nuevos: sin errores.
- Carga de las 28 clases por autoloader: correcta.
- Traducciones: 74 claves presentes en `es-AR`, `en` y `pt-BR`; sin faltantes.
- Suite existente: `php tests/run.php` → `OK: 3578 comprobaciones`.

## 6. Estado de producción

Sin cambios. No se creó esquema, rol, tabla, dato, usuario ni credencial real. No se hizo commit, push ni deploy.
