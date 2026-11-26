# Portal privado de clientes — Etapas 5, 6, 7, 8 y 9

> **Estado:** Etapas 5, 6 y 7 verificadas en `origen_codes_portal_clientes_test`; Etapa 7 cerrada en prueba con el flujo visual completo y la auditoría `service.%`. Etapa 8 cerrada en prueba: self-service verificado, prueba HTTP real acotada completada y rollback de V8 ensayado. Etapa 9 implementada en local: navegación y secciones nuevas, sin medición de consumo, sin importes propios y sin despliegue. Etapa 10 implementada en local y preparada en base de prueba como **Solicitud de Servicios**, sin navegación pública ni operaciones comerciales reales. **No desplegado en producción.**
> **Autorizaciones:** `docs/portal-clientes/acta-autorizacion-etapa-5.md`, `acta-autorizacion-etapa-6.md`, `acta-autorizacion-etapa-7.md`, `acta-autorizacion-etapa-8.md` y `acta-autorizacion-etapa-9.md`.

## 1. Límites

Este código es independiente de `/portal` y de `/admin`:

- sesión PHP propia (`origen_customer_portal`);
- namespace propio (`OrigenSalud\CustomerPortal`);
- base y credenciales propias (`PORTAL_CUSTOMER_DB_*`);
- pepper de contraseñas y de huellas distinto;
- dominio i18n `customer_portal`, sin modificar los YAML del portal público.

No implementa FreeScout, facturación ni pagos. Tampoco modificó Nginx, PHP-FPM ni el front controller de `/portal`.

La Etapa 6 agregó un adaptador de **solo lectura** hacia Invoice Ninja. No crea clientes, contactos, presupuestos, facturas ni pagos. El modo por defecto es `mock`: sin llamadas de red.

La Etapa 7 agrega un catálogo técnico y habilitaciones administradas en el portal. No copia productos, precios, facturas ni pagos: la habilitación exige que un superadministrador de Origen Salud verifique manualmente el pago confirmado y después decida la habilitación. El catálogo inicial solo incluye rutas `GET` documentadas en la API real; no publica `/fhir/*`, `/v1/uvr` ni `/v1/cdt`.

La Etapa 8 agrega self-service de credenciales de la API propia (`/v1`). Respeta el mecanismo real: clave en texto plano, sin scopes, expiración, último uso ni medición. La escritura en `public.api_clients` la hace un servicio de servidor con una conexión operativa configurada solo en el VPS (Opción A), sin rol nuevo ni ampliación de grants. El secreto se muestra una sola vez y nunca se guarda en metadatos, sesión, URL ni logs.

La Etapa 9 completa la interfaz: `Mis API`, `Documentación técnica`, `Soporte` y `Facturación y pagos`. No publica `Consumo` porque no existe medición confiable, y no incorpora tabla de precios: muestra las tres modalidades comerciales (precio público, desde y cotización) como texto localizado, sin importes. Los importes publicados y las condiciones corresponden al sistema comercial y al sitio público; este portal solo muestra servicios habilitados y enlaza al portal de facturación cuando la URL está configurada en el servidor.

## 2. Estructura

- `bootstrap.php`: autoloader e inicio de sesión.
- `Config.php`: variables de configuración; sin secretos reales.
- `Router.php`: rutas `/portal-clientes/{locale}/...`.
- `I18n/CustomerI18n.php`: reutiliza Symfony Translator con dominio separado.
- `Services/`: sesión, CSRF, RBAC, autenticación, auditoría, base, notificaciones de prueba, `InvoiceNinjaService`, `EntitlementService`, `CredentialDatabase` y `ApiCredentialService`.
- `Services/InvoiceNinja/`: transporte `mock` determinista y transporte HTTP con HTTPS obligatorio, reintentos acotados y token solo en cabecera.
- `Repositories/`: acceso parametrizado a `os_customer`, incluidos vínculos, revisiones y metadatos de credenciales.
- `Controllers/`: login, logout, recuperación, invitaciones, organizaciones, miembros, servicios y credenciales.
- `Views/` y `translations/`: interfaz en `es-AR`, `en` y `pt-BR`.
- `bin/api-credential-probe.php`: prueba HTTP real acotada contra `https://api.origen.ar`, solo `GET`, sin imprimir la clave.
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
| `PORTAL_CUSTOMER_CREDENTIAL_DB_DSN` | DSN operativo de la Etapa 8. Vacío por defecto: self-service deshabilitado. |
| `PORTAL_CUSTOMER_CREDENTIAL_DB_USER` | Usuario operativo con permisos de escritura solo sobre `public.api_clients`. |
| `PORTAL_CUSTOMER_CREDENTIAL_DB_PASS` | Contraseña operativa; solo en `.env` del VPS, nunca en Git ni logs. |
| `PORTAL_CUSTOMER_CREDENTIAL_DB_STATEMENT_TIMEOUT` | Timeout en segundos de la conexión operativa. |
| `PORTAL_CUSTOMER_API_TEST_KEY` | Clave **de prueba** para el sondeo real; solo en el entorno del VPS. |
| `PORTAL_CUSTOMER_API_TEST_EXPECT` | `200` antes de revocar, `401` después; default `200`. |

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

### Etapa 7

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.001__services_entitlements.up.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.001__services_entitlements.verify.sql
```

Revertir V7 antes que V6 y V5:

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.001__services_entitlements.down.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.001__services_entitlements.verify_rollback.sql
```

El permiso de superadministrador se aprovisiona a mano, nunca por correo ni por factura; el procedimiento está en `../sql/10_portal_clientes/README.md`.

**Prohibido:** ejecutar estos archivos contra `origen_codes` productiva.

## 5. Verificación local ya realizada

- `php -l` en todos los archivos PHP nuevos: sin errores.
- Carga de las clases por autoloader: correcta.
- Traducciones: 74 claves en la Etapa 5; 141 claves hasta la Etapa 7; 168 claves con Etapa 8, presentes en `es-AR`, `en` y `pt-BR`; sin faltantes.
- Suite existente: `php tests/run.php` → `OK: 3695 comprobaciones` (48 comprobaciones nuevas de Etapa 8).
- Etapa 6: 13 comprobaciones locales del modo `mock`, la clasificación y las guardias HTTP, sin red ni base: sin fallas.
- Etapa 7: 518 comprobaciones locales de SQL, rutas, permisos, i18n, diseño y resultados de auditoría: sin fallas.
- Etapa 8: comprobaciones locales de migración, guardas, grants, self-service, secreto de un solo uso, rutas, i18n y sondeo `GET`-only: sin fallas.
- Los resultados de auditoría inválidos detectados en la Etapa 6 (`ok`, `needs_review`, `approved`, `rejected`, `discarded`) se corrigieron a `success`/`denied`, porque `os_customer.audit_log` tiene un `CHECK` y esas escrituras habrían fallado.

### Verificación en el VPS de prueba

- Con Etapa 7: `OK: 3647 comprobaciones`, sin avisos `Deprecated`. Con Etapa 8, en VPS: `OK: 3695 comprobaciones`, sin avisos `Deprecated`.
- Cabeceras: `/portal-clientes/es-AR/login` → `X-Frame-Options: DENY`; `/es-AR/` → `SAMEORIGIN`; una sola línea en cada caso.
- Flujo ejecutado en navegador: solicitud → contrato → pago confirmado verificado → habilitación pendiente → activación → suspensión → revocación.
- Estado final de la habilitación de prueba: `1|revoked`.
- Auditoría `os_customer.audit_log` filtrada por `service.%`:

```text
service.contract.created|success|1
service.contract.payment_verified|success|1
service.entitlement.activated|success|1
service.entitlement.created|success|1
service.entitlement.status_changed|success|2
service.request.created|success|1
```

`status_changed` con count `2` corresponde a la suspensión y a la revocación de la misma habilitación.

## 6. Etapa 8 — Credenciales API

### Migración

Solo en `origen_codes_portal_clientes_test`:

```bash
cd /var/www/html/origen.ar/code-api
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V8.001__api_credentials.up.sql
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V8.001__api_credentials.verify.sql
```

Rollback ensayado y reaplicación:

```bash
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V8.001__api_credentials.down.sql
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V8.001__api_credentials.verify_rollback.sql
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V8.001__api_credentials.up.sql
```

`verify.sql` debe dar `tablas_v8 = 1`, `columnas_prohibidas = 0`, `capacidades_inexistentes = 0`, `trigger_revocacion = 1` y `sin_borrado = t`. En la base de prueba aislada `columnas_api_clients = 0`: ese esquema nunca tuvo el catálogo público. La base real que sirve a `api.origen.ar` sí debe tener las 6 columnas originales de `api_clients`.

### Configuración del servidor

La escritura en `public.api_clients` requiere la conexión operativa de la Opción A. Sin estas variables, el panel muestra el aviso `customer.credential.unavailable` y no abre conexión:

```dotenv
PORTAL_CUSTOMER_CREDENTIAL_DB_DSN=pgsql:host=...;dbname=...
PORTAL_CUSTOMER_CREDENTIAL_DB_USER=...
PORTAL_CUSTOMER_CREDENTIAL_DB_PASS=...
PORTAL_CUSTOMER_CREDENTIAL_DB_STATEMENT_TIMEOUT=3
```

Los valores se ponen solo en `.env` del VPS, con permisos restringidos. No se creó ningún rol nuevo de base ni se ampliaron los grants de `origen_customer`. Para la base real `origen_codes` el responsable autorizó un grant sobre el rol existente `origen_admin`, documentado en el acta: `SELECT, INSERT, UPDATE` en `public.api_clients` y `USAGE` en `public.api_clients_id_seq` (necesarios por `INSERT ... RETURNING id` y por `id SERIAL`).

### Uso

`/portal-clientes/{locale}/credentials` con un usuario `technical_admin` permite crear, rotar y revocar. `developer` y `viewer` solo listan. La institución se deriva de la organización activa. Toda escritura exige CSRF y un nonce de un solo uso por formulario: si el navegador reenvía el POST al recargar, se convierte en un GET inofensivo y **no crea una credencial duplicada**. Cada operación queda auditada como `credential.created`, `credential.rotated` o `credential.revoked`.

### Prueba HTTP real acotada

Solo después de confirmar la base que sirve a `api.origen.ar` y su backup:

```bash
PORTAL_CUSTOMER_API_TEST_KEY=<clave-de-prueba> php portal-clientes/bin/api-credential-probe.php
# Revocar la credencial de prueba desde el portal y repetir:
PORTAL_CUSTOMER_API_TEST_KEY=<clave-de-prueba> PORTAL_CUSTOMER_API_TEST_EXPECT=401 \
  php portal-clientes/bin/api-credential-probe.php
```

Esperado: `200` en `/health` y `/v1/domains` antes de revocar; después de revocar, `401` solo en `/v1/domains` (`/health` es público y sigue dando `200`, por lo que el modo `401` no lo consulta). El script solo hace `GET`, no imprime la clave ni el cuerpo y verifica HTTPS y host `api.origen.ar`.

## 7. Etapa 9 — Interfaz del portal

Sin migración SQL de estructura: solo controladores, vistas, traducciones y rutas `GET`. La adenda autorizada DENTAR/OFTAR agrega dos filas al catálogo técnico con `V7.002`; no crea tablas ni columnas.

### Rutas nuevas

| Ruta | Contenido |
| --- | --- |
| `/portal-clientes/{locale}/api` | Habilitaciones activas o suspendidas de la organización, con ruta y método reales. Enlaces a credenciales y documentación. Aviso honesto de consumo no disponible. |
| `/portal-clientes/{locale}/documentation` | Enlace a la documentación pública de la API y, según permisos, a las credenciales. No duplica el contenido de `/docs`. |
| `/portal-clientes/{locale}/support` | Enlace al formulario público de contacto y a la documentación. No crea tickets ni envía correo desde este portal. |
| `/portal-clientes/{locale}/billing` | Enlace opcional al portal nativo de facturación, con `rel="noopener noreferrer"` y apertura en pestaña nueva. Sin importes ni creación de facturas. |

`Consumo` queda deliberadamente fuera de la navegación hasta que exista medición real. Cobrar por consumo sin medición quedaría expuesto a facturación incorrecta.

### Modalidades comerciales

La vista `Mis servicios` muestra tres modalidades como texto localizado, sin precios en PostgreSQL ni en el código:

1. **Precio público**: servicios estandarizados con alcance definido.
2. **Desde un importe**: el valor depende de volumen, catálogos o características.
3. **Cotización personalizada**: instituciones grandes, integraciones y convenios.

La decisión de cobro híbrido (tarifa base con volumen incluido) queda registrada como preferencia comercial, pero no se factura excedentes mientras no haya medición confiable. Precio de lista y precio presupuestado no se confunden: las condiciones especiales se registran en el sistema comercial, no en este portal.

### Configuración

```dotenv
# Solo https. Vacío => la vista informa que el enlace no está configurado.
PORTAL_CUSTOMER_BILLING_URL=
```

La URL se lee del entorno del servidor; nunca se deriva del `Host` de la petición ni se escribe en el repositorio. Las URLs públicas de documentación y contacto se construyen con el locale de la ruta y caracteres validados.

### Verificación local

- `php -l` en todos los archivos PHP del portal de clientes: sin errores.
- `php tests/run.php`: comprobaciones de rutas, controladores, vistas, claves i18n en los tres idiomas, ausencia de ruta de consumo y ausencia de importes en las vistas.
- 39 claves i18n nuevas; las mismas en `es-AR`, `en` y `pt-BR`.
- Adenda DENTAR/OFTAR: cuatro archivos `V7.002`, con guarda de base de prueba, verificación de dos filas y rollback sin cascada.
- Sin llamadas HTTP nuevas a Invoice Ninja y sin acceso a la base de producción.

## 8. Etapa 10 — Solicitud de Servicios

Flujo público sin cuenta en `/{locale}/solicitud`, con las acciones `agregar`, `quitar` y `enviar`. No se llama «cart» ni «carrito» en rutas, código, SQL ni textos. No aparece en nav, footer ni home: solo se alcanza por URL directa hasta nueva autorización.

- `V10.001` crea `os_customer.public_service_request` e `..._item`, sin precios, importes, facturas ni pagos. `origen_med` recibe `USAGE` en el esquema y `SELECT, INSERT` solo en esas dos tablas.
- `V10.002` quita `SUPERUSER` a `origen_med`, autorizado expresamente. Es un cambio cluster-wide que también afecta a `origen_codes`; se ejecuta desde la base de prueba. Sin él, los chequeos de privilegios daban `f` aunque los ACL fueran correctos.
- Invoice Ninja se consulta solo por `GET`, con token **de prueba** y `INVOICE_NINJA_ALLOW_TEST_CALLS=true`. El navegador envía IDs y cantidades; los precios se validan y recalculan en servidor y no se guardan en PostgreSQL.
- CSRF, honeypot, tiempo mínimo, `RATE_REQUEST`, deduplicación y escalado a revisión humana. Nunca se crean clientes, presupuestos, facturas, pagos ni credenciales.
- 55 claves i18n nuevas por idioma en `es-AR`, `en` y `pt-BR`; sin textos hardcodeados. Suite local: `OK: 3924 comprobaciones`.

## 9. Estado de producción

Sin cambios de esquema. No se creó rol ni tabla nueva en producción. Las excepciones autorizadas son el grant operativo a `origen_admin` (punto 4.2 del acta), las credenciales **de prueba** del sondeo real, que quedaron revocadas (`api_clients` `id=3,4,5` con `is_active = f`; el `id=1` preexistente intacto), y el cambio de atributo `NOSUPERUSER` de `origen_med` autorizado en la Etapa 10, que por ser cluster-wide también aplica a `origen_codes`. El asistente no hizo commit, push ni deploy; el responsable gestionó la versión del código.

## 10. Fuera de alcance

- Pantalla de revisión administrativa de la Etapa 6: el backend expone `resolveReview()`, pero no se modificó `/admin` ni se agregaron rutas de interfaz.
- Consulta de contactos, facturas o pagos en este portal privado. La Solicitud de Servicios pública consulta productos y precios de solo lectura desde Invoice Ninja, sin crear ni modificar datos comerciales.
- Webhooks, conciliación y creación de clientes.
- Consulta de facturas, comprobantes o pagos dentro de este portal: solo se ofrece un enlace configurable al portal de facturación.
- Vencimiento automático, suspensión parcial y planes institucionales.
- Evolución M6 de la API: hash con pepper, scopes, expiración, último uso, medición y `429`.

Cada uno requiere autorización específica.
