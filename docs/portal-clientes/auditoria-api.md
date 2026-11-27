# Auditoría de la API — `code-api`

> **Estado:** auditoría de solo lectura sobre el repositorio local. No se consultó la base en vivo, no se modificó código, no se ejecutaron cambios ni se desplegó.
> **Fecha:** 2026-11-24.
> **Evidencia:** archivos del repositorio. Se marcan como `[REPO]` las afirmaciones verificadas localmente.
>
> **Estado vigente (auditoría integral 2026-11-26):** este documento describe el estado de 2026-11-24 y se conserva como registro histórico. Desde la Etapa 8 existe self-service de crear/rotar/revocar credenciales en `/portal-clientes`, **implementado pero deshabilitado por defecto**: requiere `PORTAL_CUSTOMER_CREDENTIAL_DB_DSN` / `USER` / `PASS` y permisos. La migración V8.001 quedó en entorno de prueba; no se desplegó en producción. La evolución M6 (hash con pepper y `429`) está preparada en código; la migración V11.001 no está ejecutada y necesita acta. Ver `docs/audit/informe-final.md`.

## 1. Convenciones de estado

- **Estado actual comprobado:** `[REPO]` con archivo y líneas.
- **Propuesta:** no forma parte de esta auditoría; se remite a los documentos de diseño.
- **Decisión pendiente:** puntualizado por el propio repositorio como fuera de alcance.
- **Riesgo:** consecuencia de usar el mecanismo actual sin evolución.
- **Dependencia:** etapa 8 para cualquier cambio.
- **Requisito de autorización:** modificar autenticación, esquema `api_clients`, OpenAPI o guardia `/v1/*`.

## 2. Resumen ejecutivo

- API REST **solo lectura**, prefijo `/v1`, front controller `api/index.php` `[REPO api/index.php:1-16,175,642]`.
- Autenticación por **API Key B2B en texto plano**, aceptada en `X-API-Key` o `Authorization: Bearer`, con prioridad de `X-API-Key` `[REPO api/http/ApiKeyAuthenticator.php:10-18,31-41]`.
- No hay hash/pepper, scopes, OAuth/JWT, expiración, revocación por endpoint, consola self-service, `403`, `429`, cuotas ejecutadas, log de solicitudes ni «último uso» de credenciales `[REPO README-API.md:104-120]`.
- `/health` es público; toda ruta que empieza con `/v1/` exige clave válida, incluso una inexistente `[REPO api/index.php:192-227]`.
- No existe `/fhir/*` en el enrutador; `README-FHIR.md` es un contrato propuesto `[REPO README-FHIR.md:6-16,35-39]`.
- El panel de `/admin` gestiona gobernanza, **no credenciales de API** `[REPO portal/Router.php:154-238,243-379]`.

## 3. Mecanismo real de autenticación

### 3.1 Cabeceras

| Hecho | Evidencia |
|---|---|
| Se acepta `X-API-Key` y `Authorization: Bearer <clave>` | `[REPO api/http/ApiKeyAuthenticator.php:12-14,33]` |
| Si ambas llegan, gana `X-API-Key` | `[REPO api/http/ApiKeyAuthenticator.php:33]` |
| Bearer se extrae con `^Bearer\s+(\S+)$`, case-insensitive | `[REPO api/http/Request.php:46-62]` |
| Cabeceras normalizadas desde `$_SERVER['HTTP_*']` | `[REPO api/http/Request.php:41-44,112-134]` |
| CORS permite `Content-Type, X-API-Key, Authorization, X-Request-Id` | `[REPO api/http/Cors.php:40-46]` |
| Documentación pública coincide | `[REPO README-API.md:27-38]` |

### 3.2 Validación

`ApiKeyAuthenticator::authenticate()`:

1. Falta o vacío → `401 unauthorized` con mensaje que nombra ambas cabeceras `[REPO :35-39]`.
2. Formato: `strlen <= 128` y `^[\x21-\x7E]+$` `[REPO :41-45]`.
3. SQL preparada por igualdad exacta contra `api_clients.api_key`, con `is_active = TRUE` y `LIMIT 1` `[REPO :47-56]`.
4. Clave inexistente o inactiva produce el mismo mensaje, sin filtrar información `[REPO :58-62]`.
5. Devuelve `id`, `institution_name` y `rate_limit_per_second`, pero el front controller descarta el resultado `[REPO :26-28,64-68; api/index.php:224-227]`.

En `401` se emite `WWW-Authenticate: Bearer realm="origen-salud-api"` `[REPO api/index.php:643-646]`.

## 4. Credenciales

### 4.1 Esquema comprobado

```sql
CREATE TABLE api_clients (
    id SERIAL PRIMARY KEY,
    institution_name VARCHAR(150) NOT NULL,
    api_key VARCHAR(64) UNIQUE NOT NULL,
    rate_limit_per_second INT DEFAULT 20,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Evidencia: `[REPO sql/01_schema/design.sql:73-83]`.

**Observaciones comprobadas:**

- La clave se guarda en texto plano; la comparación es directa `[REPO api/http/ApiKeyAuthenticator.php:47-56]`. El propio código lo advierte `[REPO :16-18]` y el README `[REPO README.md:750]`.
- No hay `last_used_at`, `expires_at`, `revoked_at`, `scopes`, `organization_id`, `updated_at` ni hash `[REPO design.sql:76-83]`.
- `institution_name` es texto libre, sin FK a `os_admin.organization` `[REPO design.sql:78; fase1_identidad.sql:78-89]`.
- No hay `ALTER TABLE api_clients` adicional en el repositorio `[REPO búsqueda sin resultados]`.

### 4.2 Generación y rotación

- Procedimiento documentado: `php -r "echo bin2hex(random_bytes(32)), PHP_EOL;"` e `INSERT` en `api_clients` `[REPO README.md:163-172]`.
- Script idempotente para cliente de verificación: `gen_random_bytes(32)` en hex, inserción solo si no existe el `institution_name`, escritura de la clave a `/var/lib/postgresql/.origen_api_key` con `chmod 600` `[REPO sql/09_admin/crear_cliente_api_verificacion_oftar.sql:1-13,17-39,43-57]`.
- Rotación manual: `UPDATE public.api_clients SET api_key = encode(gen_random_bytes(32), 'hex') ...`, salida a `/root/.origen_api_key` `[REPO tools/rotar_clave_api.sh:1-18]`. Es la única sentencia `UPDATE api_clients` encontrada.

### 4.3 Revocación, scopes y expiración

- No hay ruta ni script de revocación; solo existe `is_active` y el autenticador lo exige en el `WHERE` `[REPO design.sql:81; ApiKeyAuthenticator.php:51]`.
- No hay código que cambie `is_active` en el repositorio.
- No hay scopes ni permisos por clave `[REPO ApiKeyAuthenticator.php:48,64-68; api/index.php:226]`.
- El RBAC de `os_admin` (8 roles, 14 permisos) pertenece a gobernanza, no a la API `[REPO docs/architecture/gobernanza-uvr-roles-permisos.md:16-28]`.
- Las sesiones del panel tienen `token_hash`, `expires_at` y `revoked_at`; la API Key no `[REPO portal/Repositories/SessionRepository.php:42-43,73-74]`.

## 5. Guardia, versionado y superficie

- `OPTIONS` responde `204` antes de autenticar `[REPO api/index.php:183-187]`.
- `/health` es exacto, público y comprueba BD con `SELECT 1`; si falla, `503` `[REPO :192-221]`.
- Guardia: `str_starts_with($path, '/v1/')` → autenticar `[REPO :223-227]`.
  - Ruta inexistente bajo `/v1/` sin clave → `401`; con clave → `404` `[REPO :642]`.
  - `/v1` sin barra final no coincide con la guardia y no está enrutado.
- Rutas implementadas: todas `GET`; entre ellas `/v1/domains`, `/v1/refsets`, `/v1/search`, `/v1/search/{domain}`, `/v1/catalogs`, `/v1/catalogs/{code}/releases`, `/v1/catalogs/{code}/items`, `/v1/mappings`, `/v1/pricing-units` (la documentación menciona `pricing-unities`), `/v1/loinc`, `/v1/nomenclador`, `/v1/vademecum`, `/v1/pmo/*`, `/v1/cie10/{code}`, `/v1/anmat/{id}`, `/v1/odontologia/*`, `/v1/snomed/{sctid}`, `/v1/concepts/search`, `/v1/concepts/{sctid}` `[REPO api/index.php:230-640]`.
- No hay `POST`, `PUT`, `PATCH` ni `DELETE` `[REPO README-API.md:117-120]`.
- Versionado solo por prefijo de ruta `/v1`; `APP_VERSION` solo aparece en `/health` `[REPO api/index.php:217; .env.example:8]`.
- No hay `/v1/uvr` `[REPO docs/architecture/gobernanza-uvr-plan-implementacion.md:19,84]`.
- No hay `/fhir/*`; la guardia actual tampoco lo cubriría `[REPO README-FHIR.md:6-16,34-39; docs/architecture/fase12-fhir-contrato.md:19-33]`.

## 6. Rate limiting y cuotas

- `api_clients.rate_limit_per_second` existe y se selecciona, pero se descarta `[REPO design.sql:80; ApiKeyAuthenticator.php:48,67; api/index.php:226]`.
- No se emiten `403` ni `429`; no hay suspensión por comportamiento ni cuotas ejecutadas `[REPO README-API.md:117-120]`.
- `ApiException` construye `400`, `401`, `404`, `405`, `500` `[REPO api/http/ApiException.php:32-64]`.
- Existen límites de paginación/consulta, no de consumo por cliente: `limit` efectivo 50 (hasta 100 por `API_PAGE_LIMIT_MAX`), `MAX_OFFSET=5000`, `MAX_DETAIL_RELATIONS=50`, `MAX_REFSETS=10` `[REPO api/services/TerminologySearchService.php:78-80,3121; README-API.md:302]`.
- Defensa de recursos: `DB_STATEMENT_TIMEOUT_MS=5000` por defecto, aplicado con `SET statement_timeout` `[REPO api/config/database.php:161,166-175]`.
- `RATE_CONTACT`, `RATE_CART`, `RATE_BROWSE`, `RATE_WINDOW` pertenecen al portal web, no a la API `[REPO portal/Config.php:96-104]`.

## 7. Registro de solicitudes y medición real

- No hay tabla de log de requests de API en el esquema versionado.
- La única escritura de log en `api/` es `error_log($context)`, invocada solo en `catch(Throwable)` de errores internos/BD `[REPO api/index.php:694-717,200-204,659-660,678-679]`.
- El log contiene `request_id`, método, ruta, excepción, archivo/línea y stack solo si `APP_DEBUG`; no términos de búsqueda ni datos clínicos `[REPO :696-715]`.
- No se registra ninguna solicitud exitosa, ni contadores por cliente, bytes ni latencia persistida.
- `X-Request-Id` se acepta con formato `8-64 [A-Za-z0-9._-]` o se genera con `bin2hex(random_bytes(16))`; se devuelve en cabecera y cuerpo, pero no se inserta en BD `[REPO api/http/Request.php:35-36,136-147; api/index.php:144-147,178]`.
- **Último uso de credencial: inexistente.** No hay columna y el autenticador solo hace `SELECT`.
- `os_admin.audit_log` audita acciones del panel, no tráfico `/v1` `[REPO sql/09_admin/fase1_identidad.sql:140-171]`.

**Consecuencia:** hoy no es posible facturar por consumo, mostrar «último uso» ni reconstruir el histórico de una clave desde la API.

## 8. Errores y cabeceras

| Código | Origen comprobado |
|---|---|
| `200` | Respuestas normales `[REPO api/index.php:214-220 y ss.]` |
| `204` | `OPTIONS` global `[REPO :185-187]` |
| `400 bad_request` | Validación de parámetros `[REPO ApiException.php:32-35]` |
| `401 unauthorized` | Credencial faltante, inválida o inactiva `[REPO ApiKeyAuthenticator.php:35-45,58-62]` |
| `404 not_found` | Ruta o recurso inexistente `[REPO api/index.php:642]` |
| `405 method_not_allowed` | Método distinto de `GET`; `Allow: GET, OPTIONS` `[REPO ApiException.php:47-55]` |
| `500 internal_error` | Error genérico; detalle en log `[REPO api/index.php:659-668,713-717]` |
| `503 service_unavailable` | BD no disponible `[REPO :198-212,674-689]` |

Envelope de error: `{"error":{"code","message","details?"},"request_id"}` `[REPO api/http/Response.php:54-81]`.
Cabeceras comunes: `Content-Type`, `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `X-Request-Id`, `Vary: Accept-Language`, `Content-Language` `[REPO api/index.php:177-181,142-173; Response.php:19-38]`.

## 9. Entornos y configuración

- `.env.example` es plantilla; `bootstrap.php` usa Dotenv `safeLoad` y `env()` prioriza `$_ENV`, `$_SERVER`, `getenv()` `[REPO bootstrap.php:31-65]`.
- Variables relevantes: `DB_NAME=origen_salud` en la plantilla `[REPO .env.example:18]`, pero la base de trabajo documentada es `origen_codes` `[REPO README.md:137-145]`. La configuración desplegada debe fijar `DB_NAME=origen_codes`.
- `API_CORS_ORIGINS` por defecto cadena vacía → sin CORS; el ejemplo la fija a `https://med.origen.ar` `[REPO api/http/Cors.php:25-32; .env.example:37]`.
- `WEB_API_KEY`/`WEB_API_TOKEN` los usa el buscador público en servidor `[REPO web/includes/ApiClient.php:7-13,58-78]`; no figuran en `.env.example`.
- No hay URL de staging para API; el runbook de staging cubre una base independiente para migraciones `[REPO docs/architecture/ejecucion-staging-runbook.md:1-17,32-43]`.
- No hay archivos `*.conf` de Nginx versionados; solo fragmentos documentales en `README.md:700-745` y `.htaccess` `[REPO]`.

## 10. Base y roles

- Base de trabajo: `origen_codes`; `origen_salud` es la antigua `[REPO README.md:137-141]`.
- Rol API `origen_api`: `CONNECT`, `USAGE ON SCHEMA public` y `SELECT` en todas las tablas de `public` `[REPO README.md:148-155]`.
- La API no consulta `os_admin`; solo `public.api_clients` `[REPO ApiKeyAuthenticator.php:47-53]`.
- Crear/rotar claves se ejecuta como `postgres`, no con `origen_api`, coherente con su rol de solo lectura `[REPO sql/09_admin/crear_cliente_api_verificacion_oftar.sql:6-8; tools/rotar_clave_api.sh:3,9-13]`.

## 11. FastCGI / Nginx / Apache

- Fragmento Nginx documental: `try_files`, `deny` a `config|controllers|http`, `include fastcgi_params`, `fastcgi_param HTTP_PROXY ""`, `fastcgi_pass unix:/run/php/php8.2-fpm.sock` `[REPO README.md:700-745]`.
- **No aparece** en el repositorio `fastcgi_param HTTP_AUTHORIZATION`, `HTTP_X_API_KEY`, `proxy_set_header` ni `limit_req`.
- Apache: `api/.htaccess` bloquea directorios internos y reenvía a `index.php`; `.htaccess` raíz deniega `.env*`, `composer.*`, `bootstrap.php`, `sql/` y `vendor/` `[REPO]`.

## 12. Limitaciones para el portal de clientes

### Hoy se puede gestionar

- Identidad y gobernanza en `/admin`: login, logout, forgot/reset, organizaciones, invitaciones, memberships y auditoría `[REPO portal/Router.php:154-228,257-377]`.
- Documentación pública de API.
- Obtención de clave por contacto humano `[REPO portal/translations/messages.es-AR.yaml:271,416]`.

### Hoy NO se puede gestionar

- Alta, edición, rotación automática, expiración ni revocación desde UI.
- Identidad del cliente detrás de una clave más allá de `institution_name`.
- Scopes, cuotas, límites por endpoint ni suspensiones.
- Consumo, último uso ni facturación por uso.
- `/v1/uvr`, `/fhir/*` ni operaciones de escritura.

## 13. Decisiones pendientes ya registradas en el repositorio

- M6: hash de API keys, scopes, `429` y consola self-service `[REPO docs/architecture/fase1-admin-identidad.md:144-150]`.
- C11: API keys en texto plano y `rate_limit_per_second` no aplicado `[REPO docs/architecture/gobernanza-uvr-arquitectura.md:127]`.
- Decisión 12: aprobar rate limiting, hash, OAuth/scopes y consola como decisiones separadas `[REPO docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md:1042-1048]`.
- Decisión 13: alcance y momento de FHIR `[REPO ídem]`.
- Ratificación formal de `origen_codes` como base única `[REPO :1028-1029]`.

## 14. Riesgos para el nuevo portal

1. Publicar gestión de credenciales sobre un mecanismo que guarda secretos en texto plano.
2. Mostrar «último uso» o consumo cuando no existe medición real.
3. Prometer scopes o revocación inmediata sin soporte real.
4. Modificar `api_clients` o la guardia `/v1/*` sin autorización específica.
5. Romper el buscador público, que depende de `WEB_API_KEY` en servidor.
6. Confundir el RBAC de `os_admin` con permisos de API.

## 15. Conclusión

El portal de clientes debe integrarse con el mecanismo real mientras no se autorice su evolución: API Key por cliente, sin scopes ni métricas. Cualquier funcionalidad adicional (hash, rotación self-service, revocación, scopes, rates, consumo) debe figurar como propuesta dependiente de una decisión aprobada por separado.

> **Actualización vigente (2026-11-26):** la rotación y revocación self-service quedaron aprobadas en la Etapa 8 y existen en código, con la DSN de credenciales apuntando a `origen_codes` como excepción autorizada. Sigue sin activarse en producción. El hash con pepper y el limitador `429` son evoluciones preparadas, no cambios del contrato `/v1`.
