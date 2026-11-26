# Auditoría integral — Estado actual

- **Fecha:** 2026-11-26
- **Etapa:** 1 — Diagnóstico (solo lectura; sin cambios de código, SQL ni despliegues)
- **Repositorio:** `luisuriarte/code-api`, rama `main`
- **HEAD local y `origin/main`:** `61d5073ef984ec74480f2ef9e3a3131cd989e064` (`feat: add service request view, test runner, and public styles`)
- **Árbol de trabajo:** limpio
- **Sitio público:** `https://med.origen.ar`

Este documento describe **lo que el código y la configuración vigentes hacen**, no lo que la documentación histórica declara. Las discrepancias se detallan en `problemas-detectados.md`.

---

## 1. Alcance y metodología

Se inspectaron los tres frentes HTTP vivos, el árbol SQL, los componentes compartidos, la documentación, las traducciones, los mecanismos de seguridad y el verificador local. No se ejecutaron migraciones, pruebas intrusivas contra producción, commits, push ni despliegues. Las comprobaciones HTTP al sitio público fueron de solo lectura (`GET`), sin envío de credenciales.

Fuente de verdad para rutas: los routers ejecutables, no los README. Fuente de verdad para producción: el código desplegado y los informes de Etapas 12-13, con las salvedades registradas más abajo.

---

## 2. Stack tecnológico

| Componente | Versión / detalle | Evidencia |
|---|---|---|
| PHP | **VPS: 8.5.4** (CLI NTS, Zend Engine 4.5.4, OPcache 8.5.4). Entorno local de auditoría: 8.2.12. Requisito del proyecto: `>=8.2` | salida de `php -v` en el VPS (proporcionada por el responsable, 2026-11-26); `composer.json:7` |
| Composer | Symfony Translation/YAML 7.4.23, phpdotenv 5.8.0 | `composer.json:12-14`, `composer.lock` |
| Node / npm | v24.13.0 / 11.6.2 | entorno local de auditoría |
| Tailwind CSS | 4.3.5 (`@tailwindcss/cli`) | `package.json:15,19` |
| Alpine.js / Flowbite / Lucide | 3.17.5 / 4.0.2 / 1.77.0 | `package.json:16-18` |
| PostgreSQL | **VPS: 18.6** (paquete Ubuntu `18.6-0ubuntu0.26.04.1`), cliente `psql` 18.6 | salida de `psql --version` en el VPS (proporcionada por el responsable, 2026-11-26); `README.md:41,125,139-141` |
| MariaDB | Cliente `11.8.6-MariaDB`, library 15.2, presente en el VPS. **No es el motor de este proyecto**: la persistencia está en PostgreSQL | salida de `mariadb --version` en el VPS (proporcionada por el responsable, 2026-11-26) |
| Autoload | PSR-4 + classmap, bootstraps propios por frente | `composer.json:16-26` |
| SQL | 140 archivos en 12 directorios | `sql/01_schema` … `sql/10_portal_clientes` |

Las versiones marcadas como “VPS” fueron **proporcionadas por el responsable** (ejecutadas por él en el servidor); el asistente no accedió al VPS. El dato de PHP 8.5.4 confirma que las rutas `php8.5-fpm` usadas en los planes de Etapas 12-13 corresponden al servidor real, y que el `php8.2-fpm.sock` del README principal es obsoleto (ver hallazgo DOC-05). No se introdujeron dependencias nuevas durante la auditoría.

---

## 3. Frentes y puntos de entrada

| Frente | Front controller | Bootstrap |
|---|---|---|
| API REST | `api/index.php` | `bootstrap.php` (`api/index.php:175-187`) |
| Portal público | `web/index.php` + `portal/Router.php` | `bootstrap.php`, `portal/bootstrap.php` |
| Documentación / UVR / búsqueda | `web/docs.php`, `web/uvr.php`, `web/search.php` | `bootstrap.php`, `portal/i18n/I18n.php` |
| Sitemap | `web/sitemap.php` | `portal/bootstrap.php` (`web/sitemap.php:14-19`) |
| Portal privado de clientes | `web/portal-clientes/index.php` | `portal-clientes/bootstrap.php` |

El front controller de clientes convierte `CustomerRepositoryException` en `503` con vista `errors/unavailable` (`web/portal-clientes/index.php:22-29`).

---

## 4. Rutas implementadas

### 4.1 API REST (`api/index.php`)

- `/health` público (`api/index.php:193-220`); `OPTIONS` responde `204` sin API Key (`:183-187`).
- Toda ruta `/v1/*` exige API Key mediante `ApiKeyAuthenticator` (`:223-227`).
- ~30 rutas GET: `/v1/domains`, `/refsets`, `/search[/{domain}]`, `/catalogs[/{code}/releases|items|items/{item}]`, `/mappings`, `/pricing-units`, `/medicines/identifiers/{system}/{code}`, `/nomenclador`, `/vademecum`, `/loinc[/{code}]`, `/pmo/*`, `/cie10/{code}`, `/anmat/{id}`, `/odontologia/*`, `/{laboratorio|vacunas|prestaciones|programas|imagenes}/{id}`, `/snomed/{sctid}`, `/concepts/search`, `/concepts/{id}` (`api/index.php:230-640`).
- No existe ninguna ruta `/fhir/*`: FHIR R4 es solo contrato propuesto (`README-FHIR.md:7-16`, `docs/api/openapi-3.1.yaml:20`).
- El contrato `docs/api/openapi-3.1.yaml` documenta las rutas anteriores, incluida la genérica `/v1/{catalogo}/{id}`.

### 4.2 Portal público (`portal/Router.php`)

- `GET /` → redirect a `/es-AR/` (`:54-57`).
- `GET /{locale}/`, `/{locale}/docs`, `/{locale}/dentar`, `/{locale}/oftar`, `/{locale}/browse[/{id}]`, `/{locale}/about`, `/{locale}/contact` (`:66-138`).
- `POST /{locale}/contact/send` (`:140-150`).
- **Solicitud de Servicios** (denominación vigente; sin `cart`): `GET /{locale}/solicitud` y `POST /{locale}/solicitud/{agregar|quitar|restar|enviar}` (`:152-174`).
- Idiomas: `es-AR`, `en`, `pt-BR` (`portal/i18n/I18n.php:35-52`).

### 4.3 Panel administrativo (`/admin`)

Todas las rutas pasan por `AdminGuard::requireSecure()` (`portal/Router.php:182`). Las acciones privadas exigen permisos específicos mediante `AdminGuard::require([...])`. Cubre: login/forgot/reset/invite (públicos con token y CSRF en POST), auditoría, organizaciones, invitaciones, memberships, grants, contexto, catálogos y UVR (`portal/Router.php:188-595`).

### 4.4 Portal privado de clientes (`portal-clientes/Router.php`)

Prefijo `/portal-clientes/{locale}/`. Autenticación real en controladores vía `AccessControl` (`portal-clientes/Services/AccessControl.php:17-34`). Cubre: login/logout/forgot/reset, invitaciones, organizaciones, miembros, credenciales API self-service, servicios, API, documentación, soporte y facturación (`portal-clientes/Router.php:70-280`).

---

## 5. Estado de producción verificado (solo lectura, 2026-11-26)

| URL | Resultado |
|---|---|
| `https://med.origen.ar/es-AR/` | 200 |
| `https://med.origen.ar/es-AR/solicitud` | 200 — contiene marcadores del rediseño (`hover:-translate-y-0.5`, `bg-gradient-to-b`) |
| `https://med.origen.ar/en/solicitud` | 200 |
| `https://med.origen.ar/pt-BR/solicitud` | 200 |
| `https://med.origen.ar/es-AR/docs` | 302 → `/docs?lang=es-AR` (comportamiento legacy esperado) |
| `https://med.origen.ar/robots.txt` | 200, contenido genérico no versionado en el repo |
| `https://med.origen.ar/sitemap.xml` | **404** pese a existir `web/sitemap.php` y la regla `^sitemap\.xml$` en `web/.htaccess:16` |

El rediseño de `/solicitud` está publicado; el commit `61d5073` incluye `portal/Views/service-request.php`, `web/assets/css/public.css` y `tests/run.php`. El informe de Etapa 13 registró el commit anterior `552903b` (`informe-ejecucion-etapa-13.md:13`), por lo que su registro no cubre este cambio.

Configuración declarada en producción según `docs/portal-clientes/informe-ejecucion-etapa-13.md`: base operativa `origen_codes_portal_clientes`, `origen_codes` intacto, `V10.002` no reejecutada, token real de Invoice Ninja solo en `.env` del servidor, `INVOICE_NINJA_ALLOW_TEST_CALLS=false`, `INVOICE_NINJA_ALLOW_LIVE_CALLS=true`, enlaces controlados por `PORTAL_SERVICE_REQUEST_LINK_ENABLED=true`. No se manipularon credenciales durante esta auditoría.

---

## 6. Funcionalidades implementadas

- API REST con `/health`, ~30 rutas `/v1/*`, API Key, OpenAPI 3.1, `request_id`, CORS, errores genéricos y `405` transversal.
- Búsqueda unificada, catálogos, mapeos, LOINC, PMO, DENTAR PR/DX, ANMAT, CIE-10, SNOMED y odontología.
- Portal público trilingüe con selector persistente, Docs, UVR metodológico, sitemap y Solicitud de Servicios.
- Panel `/admin` con RBAC: identidad, organizaciones, invitaciones, memberships, grants, contexto, catálogos y UVR.
- Portal privado de clientes con sesión propia, CSRF, RBAC, credenciales self-service, servicios, Invoice Ninja solo lectura y páginas API/Docs/Soporte/Facturación.
- Assets compilados localmente con Tailwind v4 + Alpine/Flowbite/Lucide, sin CDN (`package.json:6-19`, `tools/build-assets.js:9-26`).
- Verificador local `tests/run.php`: **OK: 3971 comprobaciones** (ejecutado en la Etapa 1; no modifica archivos).

## 7. Funcionalidades pendientes o con alcance limitado

- FHIR R4: solo contrato; sin endpoints públicos.
- UVR público: metodología sin valores cargados ni endpoints de API pública; U7-C/D implementados en código pero no desplegados (`docs/architecture/gobernanza-uvr-cierre.md:9-15`).
- API Key con hash/pepper, `hash_equals`, scopes/expiración/último uso y limitador de tasa aplicado.
- Exposición pública de DENTAR AN/CL y decisión editorial NN 2025: **no autorizada**.
- Corrección de `hreflang` alternativos de `/search` y de CSRF en `/admin/logout`.
- Medición de consumo, importes propios, webhooks, escritura en Invoice Ninja y FreeScout.

## 8. Artefactos históricos / obsoletos

Conviven tres capas documentales: propuestas 2026-11-24 marcadas “no implementado/no ejecutado”, inventarios de Fase 1 y documentación reciente de Etapas 12-13. Ejemplos: `inventario_audit.md:59` (“SIN EJECUTAR EN VPS”), `portal-clientes/README.md:3` (“No desplegado en producción”) frente a `:291-299`, `README.md:51` (“44 archivos .sql en 9 subdirectorios”) frente a 140/12, `README.md:721,743` (`php8.2-fpm.sock`) frente a `php8.5-fpm` en los planes de producción. La secuencia correcta de lectura es cronológica; ninguno de estos archivos fue modificado en esta etapa.

---

## 9. Controles de seguridad existentes (verificación inicial)

- **CSRF:** tokens `random_bytes(32)` + `hash_equals`, por sesión y con rotación, en `portal/Services/Csrf.php` y `portal-clientes/Services/CustomerCsrf.php`. Presentes en los POST del panel y del portal de clientes; ver excepción en `problemas-detectados.md`.
- **XSS:** escapado consistente con `e()` / `htmlspecialchars(ENT_QUOTES|ENT_SUBSTITUTE)`.
- **SQLi:** prepared statements en repositorios/servicios; interpolaciones dinámicas restringidas por whitelist.
- **RBAC:** decisión en backend (`AdminGuard`, `Rbac`, `AccessControl`), con prevención de auto-aprobación y techo de permisos.
- **Sesiones:** `HttpOnly`, `SameSite=Lax`, cookies separadas por frente; logout con opciones correctas en el portal de clientes.
- **Secretos:** `.gitignore` excluye `.env`, `.env.*`, `/var/` y `*.log`; `.htaccess` niega `.env*`, `composer.*`, `bootstrap.php`, `sql/`, `vendor/`. No se encontraron secretos reales versionados.
- **Errores:** `APP_DEBUG=false`, `display_errors=0`, respuestas API genéricas.
- **Subidas de archivos:** no existe superficie de upload.

Las debilidades confirmadas se enumeran en `problemas-detectados.md`.

---

## 10. Verificación local ejecutada

```
php tests/run.php
OK: 3971 comprobaciones.
```

El árbol de trabajo permaneció limpio después de la ejecución. No se ejecutaron verificadores contra producción.

---

## 11. Cierre de la Etapa 1

La Etapa 1 quedó completa con las seis revisiones especializadas: estructura y documentación, sitio público/UX, API y documentación técnica, SQL y flujo comercial, internacionalización, y seguridad/pruebas. El diagnóstico consolidado está en `problemas-detectados.md` (71 hallazgos: 2 P0, 20 P1, 39 P2, 10 P3) y la propuesta de corrección en `plan-correcciones.md`.

Ninguno de los hallazgos fue corregido en esta etapa. La Etapa 2 requiere aprobación explícita del responsable, en particular para los cambios de autenticación, credenciales, migraciones, alcance idiomático, esquema de URLs y páginas legales.
