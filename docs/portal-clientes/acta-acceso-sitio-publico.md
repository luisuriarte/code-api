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
