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

**Causa:** el catch-all de `web/.htaccess` capturaba `/portal-clientes/es-AR/` porque `web/portal-clientes/es-AR` no existe como archivo ni directorio. El `.htaccess` interno de `web/portal-clientes/` nunca se ejecutaba.

**Corrección autorizada por el responsable:** agregar, antes del catch-all, una regla que excluya el prefijo sin reescribirlo:

```apache
RewriteRule ^portal-clientes(?:/|$) - [L]
```

Esto preserva las URLs limpias y permite que se aplique el `.htaccess` interno del portal de clientes. No se modificó ninguna otra regla ni la configuración global de Apache.

## 7. Condición para que el botón funcione

El enlace apunta a una aplicación que todavía no tiene credenciales de base configuradas. Sin `PORTAL_CUSTOMER_DB_DSN`, `PORTAL_CUSTOMER_DB_USER` y `PORTAL_CUSTOMER_DB_PASS`, el portal responde `503 — Portal no disponible`. Eso es esperado: no se intenta ninguna conexión a producción.
