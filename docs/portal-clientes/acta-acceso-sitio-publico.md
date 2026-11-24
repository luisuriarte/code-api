# Acta de autorización — Acceso al portal de clientes desde med.origen.ar

> **Estado:** AUTORIZADO y preparado. **No desplegado.**
> **Fecha:** 2026-11-24.
> **Autorizado por:** responsable del proyecto.
> **Relación:** excepción puntual a la prohibición de modificar el sitio público establecida en `acta-autorizacion-etapa-6.md`.

## 1. Autorización recibida

> Que sea un botón en lugar de «Solicitar Acceso», que sea «Portal Cliente».
> Destino relativo por idioma.

Esta autorización deja sin efecto, **solo para este cambio**, la prohibición de modificar el sitio público `med.origen.ar`. No habilita ningún otro cambio en el sitio público.

## 2. Alcance habilitado

- Reemplazar el botón «Solicitar acceso» por «Portal Cliente» en el header del sitio público.
- Destino relativo por idioma: `/portal-clientes/es-AR/`, `/portal-clientes/en/`, `/portal-clientes/pt-BR/`.
- Mantener el botón «Gestión» (`/admin/login`) sin cambios.
- Aplicar el mismo reemplazo en las tres cabeceras que componen el sitio: portal principal, `/docs` y `/uvr`.
- Agregar la clave i18n `nav.customer_portal` en `es-AR`, `en`, `pt-BR` y `es`.

## 3. Alcance no habilitado

- Cambios en `/admin`, catálogos, API pública, Nginx, PHP-FPM, Invoice Ninja ni FreeScout.
- Cambios en la lógica de autenticación ni en el front controller de `/portal`.
- Inserción del enlace en el menú principal (`nav-links.php`): el responsable eligió **solo el botón**.
- Credenciales reales, commit, push ni deploy.

## 4. Archivos modificados

- `portal/Views/partials/header.php`
- `portal/Views/partials/customer-portal-href.php` (nuevo)
- `web/docs.php`
- `web/uvr.php`
- `portal/translations/messages.es-AR.yaml`
- `portal/translations/messages.en.yaml`
- `portal/translations/messages.pt-BR.yaml`
- `portal/translations/messages.es.yaml`

## 5. Verificación local

- `php -l` en los cuatro archivos PHP modificados o nuevos: sin errores.
- 19 comprobaciones de etiquetas, claves i18n, destino y ausencia del botón anterior: sin fallas.
- Suite existente: `OK: 3578 comprobaciones`.

## 6. Corrección de enrutamiento autorizada

El primer intento devolvió el 404 del **portal público**: el texto «La página solicitada no existe.» está en `portal/Router.php`, mientras que el 404 del portal de clientes dice «La ruta solicitada no existe en este portal.»

**Causa real:** el servidor usa **nginx**, no Apache. Los archivos `.htaccess` son ignorados por completo. El `try_files` del server block envía `/portal-clientes/es-AR/` al front controller público `web/index.php`, porque no existe ni archivo ni directorio con esa ruta.

**Corrección autorizada por el responsable:** revertir la regla de Apache, que era inerte, y preparar una ubicación dedicada en la configuración de nginx. El responsable aplicará el cambio en el VPS y hará el `reload`.

El responsable aportó `/etc/nginx/sites-available/med.origen.ar.conf`:

- `root /var/www/html/origen.ar/code-api/web;`
- `location / { try_files $uri $uri/ /index.php?$query_string; }`
- `location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/run/php/php-fpm.sock; ... include fastcgi_params; }`

`fastcgi_params` pasa `REQUEST_URI=$request_uri`, es decir la URI original, que es lo que necesita el router del portal de clientes. Por eso no hace falta reescribir la URI manualmente.

**Bloque a insertar antes de `location /`:**

```nginx
    # Portal privado de clientes: front controller propio.
    location /portal-clientes/ {
        try_files $uri $uri/ /portal-clientes/index.php?$query_string;
    }
```

Es un `location` de prefijo **sin `^~`**, así que las ubicaciones regex siguen evaluándose: `/portal-clientes/index.php` continúa siendo procesado por `location ~ \.php$`. No se modifica ninguna otra ubicación.

También se requiere subir por WinSCP el front controller `web/portal-clientes/index.php`; el servidor no lo tiene todavía.

**No se debe mover** el directorio `portal-clientes/` de la raíz de `code-api`. Es el código de aplicación y debe seguir fuera del `DocumentRoot`. El front controller lo localiza con `dirname(__DIR__, 2) . '/portal-clientes/bootstrap.php'`; si se moviera a `web/`, esa ruta dejaría de existir. Localmente ambos archivos ya están versionados (`git ls-files web/portal-clientes` → `.htaccess` e `index.php`, commit `d9669eb`).

## 7. Condición para que el botón funcione

El enlace apunta a una aplicación que todavía no tiene credenciales de base configuradas. La página de login se renderiza sin tocar la base; el `503 — Portal no disponible` aparece cuando una acción intenta usar el repositorio sin `PORTAL_CUSTOMER_DB_DSN`, `PORTAL_CUSTOMER_DB_USER` y `PORTAL_CUSTOMER_DB_PASS`. Es el comportamiento previsto: no se intenta ninguna conexión a producción.

## 8. Base canónica configurada en el VPS

Una vez corregido el enrutamiento, la navegación redirigía a `https://portal-clientes.test.example.invalid/es-AR/login`. Ese dominio es el default de `Config::baseUrl()` y no es un error de nginx: `Services\Http::redirect()` usa siempre la base canónica y deliberadamente nunca usa el header `Host`.

Configuración requerida en `/var/www/html/origen.ar/code-api/.env`:

```dotenv
PORTAL_CUSTOMER_BASE_URL=https://med.origen.ar/portal-clientes
```

`bootstrap.php` carga `.env` desde `BASE_PATH` con `Dotenv::createImmutable()->safeLoad()`, por lo que no hace falta recargar nginx ni PHP-FPM: se lee en cada request. Si la variable ya estuviera definida en el pool de PHP-FPM con otro valor, `createImmutable` no la sobrescribe y habría que corregirla también en el pool.

Verificación esperada:

```bash
curl -sSI "https://med.origen.ar/portal-clientes/" | grep -i '^location'
# Location: https://med.origen.ar/portal-clientes/es-AR/

curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' \
  "https://med.origen.ar/portal-clientes/es-AR/"
# 302 https://med.origen.ar/portal-clientes/es-AR/login

curl -sS -o /tmp/pc.html -w 'HTTP=%{http_code}\n' \
  "https://med.origen.ar/portal-clientes/es-AR/login?cb=$(date +%s)"
# HTTP=200
```

La segunda comprobación usa `GET`, no `HEAD`: el router actual solo trata `GET` como método válido para la página de inicio, así que un `curl -I` sobre `/es-AR/` devuelve 404 sin `Location`. Ese detalle no afecta la navegación desde el navegador.

Resultado observado en el VPS: redirección correcta a `/es-AR/login`, `HTTP=200` y cabeceras `X-Frame-Options: DENY` y `Cache-Control: private, no-store` provenientes del front controller.

## 9. Conflicto de cabeceras `X-Frame-Options`

El `curl -sSI` mostró dos valores contradictorios:

```
x-frame-options: DENY
x-frame-options: SAMEORIGIN
```

`DENY` lo emite `web/portal-clientes/index.php`; `SAMEORIGIN` lo agrega el bloque `server` de nginx con `add_header ... always`. La directiva `add_header` no se hereda cuando el `location` define las suyas, por lo que la corrección es declarar las tres cabeceras dentro del `location /portal-clientes/`:

```nginx
    location /portal-clientes/ {
        add_header X-Frame-Options "DENY" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        try_files $uri $uri/ /portal-clientes/index.php?$query_string;
    }
```

Así desaparece el `SAMEORIGIN` heredado. La cabecera `DENY` del PHP queda como redundancia intencional (defensa en profundidad) y ya no contradice a nginx.

## 10. Diagnóstico de conexión a la base de prueba

`CustomerDatabase::connection()` transforma cualquier `PDOException` en `customer_database_unavailable`, por lo que ese mensaje no distingue entre driver ausente, credenciales inválidas y falta de grants. Antes de otorgar permisos hay que verificar, en este orden:

1. `php -m | grep -i pgsql` → debe existir `pdo_pgsql`.
2. Conexión PDO directa con el DSN/usuario/contraseña de `.env`, imprimiendo solo el mensaje de `PDOException` (nunca la contraseña).
3. `current_database()`, `current_user`, `has_schema_privilege(..., 'os_customer', 'USAGE')` y `count(*)` de `information_schema.tables` para `os_customer`.

Grants requeridos por el rol `origen_customer`, ya definidos en V5/V6 y que deben volver a aplicarse después de cada migración porque **no** se usan `ALTER DEFAULT PRIVILEGES`:

- `CONNECT ON DATABASE origen_codes_portal_clientes_test`
- `USAGE ON SCHEMA os_customer`
- `SELECT, INSERT, UPDATE, DELETE` en todas las tablas excepto `audit_log`
- `SELECT, INSERT` en `os_customer.audit_log` (append-only)
- `USAGE, SELECT` en todas las secuencias de `os_customer`

El rol también necesita `LOGIN` y contraseña coincidente con `.env`, y `pg_hba.conf` debe permitir autenticación por password desde el usuario de PHP-FPM.

**Hallazgo en el VPS:** el DSN configurado usa `PORTAL_CUSTOMER_DB_USER=origen_codes_portal`, no `origen_customer`. El error real fue:

```
FATAL: too many connections for role "origen_codes_portal"
```

No era un problema de grants ni de driver (`pdo_pgsql` está presente). El portal estaba compartiendo el rol con otras aplicaciones y agotó su `CONNECTION LIMIT`. La corrección arquitectónica es usar el rol dedicado `origen_customer`, con su propio límite y sus grants, y dejar `origen_codes_portal` para las aplicaciones que ya lo usan.

**Resolución confirmada en el VPS:** con `PORTAL_CUSTOMER_DB_USER=origen_customer` y su contraseña actualizada en `.env`, la conexión PDO directa devolvió `connect=ok`, `db=origen_codes_portal_clientes_test`, `current_user=origen_customer`, `schema_usage=true` y `tables=13`. Queda pendiente repetir el check con `CustomerDatabase::connection()` y verificar el login desde el navegador.
