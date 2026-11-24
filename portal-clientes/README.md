# Portal privado de clientes — Etapas 5 y 6

> **Estado:** Etapa 5 cerrada en prueba; Etapa 6 preparada, pendiente de ejecución. **No desplegado.**
> **Autorizaciones:** `docs/portal-clientes/acta-autorizacion-etapa-5.md` y `acta-autorizacion-etapa-6.md`.

## 1. Límites

Este código es independiente de `/portal` y de `/admin`:

- sesión PHP propia (`origen_customer_portal`);
- namespace propio (`OrigenSalud\CustomerPortal`);
- base y credenciales propias (`PORTAL_CUSTOMER_DB_*`);
- pepper de contraseñas y de huellas distinto;
- dominio i18n `customer_portal`, sin modificar los YAML del portal público.

No implementa FreeScout, entitlements, credenciales API, facturación ni pagos. Tampoco modificó Nginx, PHP-FPM ni el front controller de `/portal`.

La Etapa 6 agregó un adaptador de **solo lectura** hacia Invoice Ninja. No crea clientes, contactos, presupuestos, facturas ni pagos. El modo por defecto es `mock`: sin llamadas de red.

## 2. Estructura

- `bootstrap.php`: autoloader e inicio de sesión.
- `Config.php`: variables de configuración; sin secretos reales.
- `Router.php`: rutas `/portal-clientes/{locale}/...`.
- `I18n/CustomerI18n.php`: reutiliza Symfony Translator con dominio separado.
- `Services/`: sesión, CSRF, RBAC, autenticación, auditoría, base, notificaciones de prueba e `InvoiceNinjaService`.
- `Services/InvoiceNinja/`: transporte `mock` determinista y transporte HTTP con HTTPS obligatorio, reintentos acotados y token solo en cabecera.
- `Repositories/`: acceso parametrizado a `os_customer`, incluidos vínculos y revisiones de Invoice Ninja.
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
| `PORTAL_CUSTOMER_IN_MODE` | `mock` (default) u `http`. |
| `PORTAL_CUSTOMER_IN_BASE_URL` | Instancia designada como de prueba. Default `https://gestion.uriarte.ar`. |
| `PORTAL_CUSTOMER_IN_API_PREFIX` | Prefijo de API asumido, `/api/v1`. Sin verificar en la instalación. |
| `PORTAL_CUSTOMER_IN_TOKEN` | Token **de prueba**. Nunca el real. Solo en servidor; jamás en Git ni logs. |
| `PORTAL_CUSTOMER_IN_ALLOW_TEST_CALLS` | Opt-in explícito para llamadas HTTP de prueba. Default `false`. |
| `PORTAL_CUSTOMER_IN_TIMEOUT` | Timeout en segundos, 1..30. |
| `PORTAL_CUSTOMER_IN_RETRIES` | Reintentos en respuestas transitorias, 0..2. |

Para que exista una llamada HTTP deben cumplirse **simultáneamente** las tres condiciones: `mode=http`, `allow_test_calls=true` y token de prueba configurado. Sin eso, el servicio usa el adaptador `mock` y no abre conexión. El token real está prohibido por el acta.

La cabecera `X-Api-Token` y el prefijo `/api/v1` son suposiciones documentadas: la versión y los endpoints de la instalación siguen sin verificar.

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

### Etapa 6

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V6.001__invoice_ninja_links.up.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V6.001__invoice_ninja_links.verify.sql
```

Revertir primero V6 y después V5:

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V6.001__invoice_ninja_links.down.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V6.001__invoice_ninja_links.verify_rollback.sql
```

**Prohibido:** ejecutar estos archivos contra `origen_codes` productiva.

## 5. Verificación local ya realizada

- `php -l` en todos los archivos PHP nuevos: sin errores.
- Carga de las clases por autoloader: correcta.
- Traducciones: 74 claves presentes en `es-AR`, `en` y `pt-BR`; sin faltantes.
- Suite existente: `php tests/run.php` → `OK: 3578 comprobaciones`.
- Etapa 6: 13 comprobaciones locales del modo `mock`, la clasificación y las guardias HTTP, sin red ni base: sin fallas.

## 6. Estado de producción

Sin cambios. No se creó esquema, rol, tabla, dato, usuario ni credencial real. No se hizo commit, push ni deploy.

## 7. Fuera de alcance de la Etapa 6

- Pantalla de revisión administrativa: el backend expone `resolveReview()`, pero no se modificó `/admin` ni se agregaron rutas de interfaz.
- Consulta de contactos, productos, precios, facturas o pagos.
- Webhooks, conciliación y creación de clientes.
- Enlace al Client Portal oficial de Invoice Ninja.

Cada uno requiere autorización específica.
