# Auditoría de infraestructura y base del repositorio

> **Estado:** auditoría de solo lectura sobre el repositorio local y comprobaciones HTTP públicas. No se accedió al VPS, no se consultó la base en vivo, no se modificaron archivos de código, configuración, base, Nginx, FreeScout ni Invoice Ninja.
> **Fecha:** 2026-11-24.
> **Código versionado revisado:** HEAD `e904f4fe2c370fa248bf4dcf44c1f5abfcbe5073` (2026-11-23). El directorio `docs/portal-clientes/` es documentación nueva no versionada.

## 1. Convenciones de estado

- **Estado actual comprobado:** evidencia local `[REPO]` o HTTP público `[HTTP]`.
- **No verificado:** requiere acceso autorizado al VPS, base o sistemas externos.
- **Propuesta:** se remite a los documentos de diseño.
- **Decisión pendiente:** requiere pronunciamiento del propietario.
- **Riesgo:** consecuencia adversa potencial.
- **Dependencia:** acceso autorizado de solo lectura para cerrar la auditoría.
- **Requisito de autorización:** cualquier cambio en VPS, base, servicios o despliegue.

## 2. Dominios y frentes existentes

| Frente | Evidencia | Observación |
|---|---|---|
| `med.origen.ar` | `[REPO README.md:3-8; .env.example:37,42-43]` | Portal institucional y panel `/admin`, sobre la misma base de código. |
| `api.origen.ar` | `[REPO README.md:3-8; docs/api/openapi-3.1.yaml:28-30]` | API REST `/v1`, base de producción declarada en OpenAPI. |
| `gestion.uriarte.ar` | `[REPO .env.example:55-59; portal/Config.php:44-52; HTTP]` | Invoice Ninja; ver `auditoria-invoice-ninja.md`. |
| `soporte.uriarte.ar` | `[HTTP]` | FreeScout; ver `auditoria-invoice-ninja.md`. |

**DocumentRoot documental:** `api.origen.ar` → carpeta `api`; `med.origen.ar` → carpeta `web`; nunca la raíz del proyecto `[REPO README.md:689-694]`.

## 3. Superficie pública que debe permanecer estable

### 3.1 Rutas

`portal/Router.php` implementa, entre otras:

- `/` → `/es-AR/` `[REPO :53-57]`.
- `/{locale}/`, `/dentar`, `/oftar`, `/browse`, `/browse/{id}`, `/docs`, `/about`, `/contact`, `/contact/send` `[REPO :65-149]`.
- `/admin` y `/admin/*`, sin prefijo de idioma `[REPO :45-51,154-238]`.
- `/docs`, `/uvr`, `/search` y `/sitemap.xml` como archivos standalone o rewrites `[REPO :35-43; web/.htaccess:12-21]`.

**No existe** ruta `/cart` `[REPO portal/Router.php:81-152; web/sitemap.php:8-11; tests/README.md:20-22]`. El enlace del footer resuelve a `#plataforma`.

### 3.2 Navegación y CTAs

- Navegación principal: Inicio, DENTAR, OFTAR, Browse, Docs, UVR, About, Contact `[REPO portal/Views/partials/nav-links.php:11-19]`.
- Header: selector de idioma, enlace **Gestión** a `/admin/login` y CTA **Solicitar acceso** `[REPO portal/Views/partials/header.php:21-32,42-50]`.
- Footer: Docs, UVR, DENTAR, OFTAR, SNOMED, ANMAT, About, Contact y “Servicios” → `#plataforma` `[REPO portal/Views/partials/footer.php:7-18]`.

### 3.3 Funciones implementadas

- **Home:** construye ejemplo de respuesta con `request_id`, `field_languages`, fallback y `dialect_determined` `[REPO portal/Controllers/HomeController.php:13-20,22-66,75-86]`.
- **Browse Codes:** procesa `fragment`, `q`, `domain`, `catalog`, filtros, página, `focus`, `tab`, `rel_view`, `compare` e `history` `[REPO portal/Controllers/BrowseController.php:15-17,33-77]`.
- **DENTAR y OFTAR:** enlazan al explorador compartido, sin segundo motor de búsqueda `[REPO portal/Controllers/DentarController.php:11-23; OftarController.php:11-16,39-50]`.
- **Docs:** página trilingüe de solo lectura con base `https://api.origen.ar` `[REPO web/docs.php:5-10,32]`.
- **UVR pública:** metodológica, sin valores cargados, índices publicados ni endpoints `[REPO web/uvr.php:5-10; README-UVR.md:7-9,19-26]`.
- **Search legacy:** consume `GET /v1/search` desde servidor y mantiene la clave fuera del navegador `[REPO web/search.php:5-11]`.
- **Contacto:** CSRF, honeypot, retardo mínimo, validación, rate limit y SMTP `[REPO portal/Controllers/ContactController.php:16-31; portal/Services/ContactService.php:15,20-26,37-62,80-89]`.
- **Sitemap:** URL por locale para siete secciones, con `hreflang` y `x-default` `[REPO web/sitemap.php:6-24,36-54]`.

### 3.4 Internacionalización

- Locales canónicos `es-AR`, `en`, `pt-BR` `[REPO portal/i18n/I18n.php:5-17,25-33]`.
- Resolución: segmento URL, `?lang=`, cookie `origen_locale`, default y `Accept-Language`; la URL explícita prevalece `[REPO :25-33,72-90]`.
- Tres YAML activos con paridad de 1101 claves; `messages.es.yaml` es legado `[REPO README.md:670-685]`.
- `/search` genera alternativas `/{locale}/search` que no existen en el router; pendiente documentado `[REPO README.md:673-675]`.

**Restricción para el portal de clientes:** usar el mismo mecanismo I18n, sin textos hardcodeados y sin mezclar terminología clínica aprobada con nombres comerciales o de servicios.

## 4. API y panel de gobernanza

- API `/v1`: solo lectura, guardia `/v1/*`, sin `/fhir/*` ni `/v1/uvr` `[REPO README-API.md:19-37,94-120; api/index.php:193,223-224,230-628]`.
- Panel `/admin`: autenticación, organizaciones, invitaciones, memberships, grants, catálogos, propuestas, revisiones y UVR `[REPO portal/Router.php:154-238,257-377,388-477,486-569]`.
- El panel no posee registro self-service de API Keys `[REPO portal/translations/messages.es-AR.yaml:234]`.

Ver `auditoria-api.md` y `auditoria-portal-gobernanza.md`.

## 5. Infraestructura versionada

### 5.1 Existe en el repositorio

- `.htaccess` raíz: deniega `.env*`, `composer.*`, `bootstrap.php`, `sql/` y `vendor/` `[REPO .htaccess:1-19]`.
- `api/.htaccess`: bloquea `config|controllers|http`, reenvía a `index.php`, añade `nosniff` y `no-referrer` `[REPO api/.htaccess:1-21]`.
- `web/.htaccess`: bloquea `includes|translations`, rewrites legacy, front controller, `nosniff`, `strict-origin-when-cross-origin` y `SAMEORIGIN` `[REPO web/.htaccess:1-28]`.
- Fragmento Nginx documental en `README.md:700-745`: `try_files`, `deny`, `include fastcgi_params`, `fastcgi_param HTTP_PROXY ""`, `fastcgi_pass unix:/run/php/php8.2-fpm.sock`.
- Checklist de seguridad documental en `README.md:748-757`: API Keys en texto plano, `rate_limit_per_second` no aplicado, HTTPS/HSTS y CORS a nivel de servidor, logs sin términos clínicos, base de solo lectura, backups verificados, secretos fuera de Git y `APP_DEBUG=false`.
- Runbook de staging documental para base independiente, sin automatización ni credenciales de staging `[REPO docs/architecture/ejecucion-staging-runbook.md:1-18,29-45]`.
- Procedimientos documentales de `pg_dump -Fc` y `pg_restore` `[REPO manual-carga-catalogos.md:170-180,859-875; sql/08_arquitectura/README.md:616-619]`.
- Estructura propuesta `/opt/origen-salud-data/{sources,processed,imports,backups,logs}`; `ORIGEN_DATA_DIR` declarada pero no consumida activamente por los importadores `[REPO manual-carga-catalogos.md:80-129]`.

### 5.2 No existe en el repositorio

No se encontraron archivos versionados de:

- `nginx.conf`, virtual hosts, `*.conf` de servidor, `php-fpm.conf` ni pools.
- `Dockerfile`, `docker-compose*`, systemd, cron, `Makefile` ni `.github/workflows`.
- Scripts de despliegue o rollback.
- Certificados, claves, CSR ni configuración de Certbot/Let’s Encrypt.
- Jobs de backup con schedule, retención o verificación automática.
- Configuración real de dominios, PHP-FPM o Nginx aplicada en producción.

### 5.3 No verificable sin acceso autorizado

- Versión real de PHP, PHP-FPM, Nginx y PostgreSQL.
- Si `fastcgi_pass unix:/run/php/php8.2-fpm.sock` coincide con el servidor.
- Emisor, vencimiento y renovación de certificados.
- Existencia, frecuencia y estado real de backups.
- Reglas efectivas de HTTPS, HSTS, CORS y `limit_req`.
- Configuración de FastCGI para `HTTP_AUTHORIZATION` y `HTTP_X_API_KEY`.

## 6. Configuración y dependencias

- PHP >= 8.2, Composer 2, Symfony Translation/YAML 7.3, phpdotenv 5.6 `[REPO composer.json:6-15]`.
- Tailwind 4.3.5, Alpine 3.17.5, Flowbite 4.0.2 y Lucide 1.77.0 para build local sin CDN `[REPO package.json:14-20]`.
- PostgreSQL 18 con PDO y `pg_trgm` `[REPO README.md:36-42]`.
- `.env.example` usa Dotenv `safeLoad`; `env()` prioriza `$_ENV`, `$_SERVER` y `getenv()` `[REPO bootstrap.php:31-65]`.
- Variables relevantes: `API_CORS_ORIGINS=https://med.origen.ar`, `WEB_DEFAULT_LOCALE=es-AR`, `WEB_BASE_URL=https://med.origen.ar`, `DB_NAME=origen_salud` en la plantilla, base de trabajo documental `origen_codes` `[REPO .env.example:18,37,42-43; README.md:137-145]`.

**Observación:** la plantilla no fija `DB_NAME=origen_codes`; la configuración desplegada debe hacerlo. No se verificó el `.env` real.

## 7. Inventario PostgreSQL desde artefactos del repositorio

**Estado:** existe en el repositorio; **no verificado en base en vivo**.

### 7.1 Base y roles documentados

| Elemento | Estado `[REPO]` |
|---|---|
| `origen_codes` | Base de trabajo ratificada documentalmente `[README.md:137-141]`. |
| `origen_salud` | Base antigua `[README.md:137-141]`. |
| `origen_med` | Rol público de solo lectura `[.env.example:45-52; portal/Config.php:107-122]`. |
| `origen_api` | `CONNECT`, `USAGE ON SCHEMA public` y `SELECT` en todas las tablas de `public` se documenta en `[README.md:148-155]`; **no se encontró `CREATE ROLE origen_api` ejecutable** en el repositorio. |
| `origen_admin` | Rol administrativo con esquema `os_admin`, sin privilegios sobre `os_catalog_*` `[sql/09_admin/fase1_identidad.sql:176-209]`. |

### 7.2 Identidad de gobernanza existente

M1/M2 documentan `os_admin.app_user`, `organization`, `membership`, `role`, `role_permission`, `permission`, `invitation`, `invitation_grant`, `session`, `password_reset`, `auth_throttle`, `catalog_grant` y `audit_log` `[REPO docs/architecture/fase1-admin-identidad.md; fase2-organizaciones-invitaciones.md]`.

- Contraseñas hasheadas con Argon2id + pepper de aplicación `[REPO fase1-admin-identidad.md:18]`.
- Sesiones persistidas como hash de token, con expiración y revocación `[REPO fase1-admin-identidad.md:19-21]`.
- Auditoría append-only `[REPO fase1_identidad.sql:140-171]`.
- No hay sentencias ejecutables `ALTER DEFAULT PRIVILEGES`; las coincidencias son comentarios, documentación o prohibiciones `[REPO]`.
- Esquema `os_admin` con conexión acotada en `portal/Repositories/AdminDatabase.php:11-17`; la conexión pública de solo lectura es `PortalDatabase.php:11-16`.

### 7.3 Credenciales API

- `public.api_clients` con `id`, `institution_name`, `api_key`, `rate_limit_per_second`, `is_active`, `created_at` `[REPO sql/01_schema/design.sql:73-83]`.
- Sin hash, scopes, expiración, revocación, organización ni último uso `[REPO ídem]`.
- Rotación manual documentada en `tools/rotar_clave_api.sh`.

### 7.4 Entidades del portal de clientes que NO existen en el repositorio

No hay evidencia de tablas para:

- Organizaciones de clientes separadas de `os_admin.organization`.
- Usuarios de clientes separados de `os_admin.app_user`.
- Membresías, roles, invitaciones o sesiones de clientes.
- Vínculos con clientes/contactos de Invoice Ninja.
- Productos comerciales locales, contratos, servicios técnicos ni habilitaciones.
- Metadatos de credenciales por organización.
- Medición real de consumo de API por cliente.

### 7.5 Convenciones que deben respetarse

- Crear objetos nuevos con propietario y privilegios explícitos.
- Usar `REVOKE` por tabla, función o vista nueva.
- No usar `ALTER DEFAULT PRIVILEGES`.
- Auditoría append-only, sin actualizaciones ni borrados de eventos.
- No reutilizar `os_admin` para clientes.
- No ampliar `origen_api` ni `origen_admin` sin autorización.

### 7.6 Otros objetos versionados relevantes

Inventario adicional `[REPO]`; su existencia en base en vivo es `[NO VERIFICADO]`:

| Ámbito | Fuentes | Objetos principales |
|---|---|---|
| Base/`public` | `sql/01_schema/design.sql` | `snomed_concepts`, `snomed_descriptions`, `snomed_relationships`, `anmat_medicamentos`, `api_clients`, `cie10_codes`, `cie10_descriptions`, `map_snomed_cie10`, `sct2_refset_catalog`, `snomed_refset_member`, tablas de laboratorio, vacunas, odontología, prestaciones, programas sociales, imágenes, nomencladores y vademécum. |
| Motor canónico | `sql/02_catalogs/origen_catalog_engine.sql` | `os_catalog`, `os_catalog_release`, `os_catalog_category`, `os_catalog_item`, `os_catalog_item_version`, `os_catalog_term`, `os_catalog_identifier`, `os_terminology_system`, `os_concept_mapping`, `os_pricing_unit`, `os_fee_schedule`, `os_fee_item`, `os_pricing_values`, `os_substance`, `os_medicinal_product`, `os_product_package`, `os_product_identifier`. |
| DENTAR | `sql/03_dentar/*.sql` | `dentar_catalog`, `dentar_release`, `dentar_concept`, `dentar_diagnosis`, `dentar_term`, relaciones y mappings; `os_source_odontologico_nacional`. |
| OFTAR | `sql/03_oftar/*.sql` | `oftar_catalog`, `oftar_release`, `oftar_category`, `oftar_concept`, `oftar_term`, `oftar_diagnosis`, `oftar_external_identity`, `os_source_oftar_cao`, `os_source_oftar_regional`, `os_oftar_nomenclador_match`, `v_oftar_search_catalog`. |
| PMO / LOINC | `sql/04_pmo/pmo.sql`, `sql/05_loinc/importar_loinc.sql` | `pmo_prestacion`, `pmo_dentar_mapping`, `loinc`, `loinc_map`. |
| Gobernanza | `sql/09_admin/fase1_identidad.sql`, `fase2_gobernanza.sql` | `os_admin.role`, `permission`, `role_permission`, `organization`, `app_user`, `membership`, `catalog_grant`, `session`, `password_reset`, `auth_throttle`, `audit_log`, `invitation`, `invitation_grant`. |
| Multilingüe | `sql/07_multilingue/*.sql` | `os_language`, `os_language_alias`, `os_catalog_language`, `os_localized_text`, `os_translation_review`, `os_field_review`, `loinc_localized_text`. Idiomas sembrados: `es-AR`, `en`, `pt-BR`; `es` y `es-MX` como `is_source_only`; alias `es→es-AR`, `pt→pt-BR`. |
| Arquitectura/UVR | `sql/08_arquitectura/*.sql` | `os_domain_registry`, `os_relation_kind`, `os_relation_type`, `os_review_state`, `os_mapping_metadata`, `os_governance_request`, `os_governance_review`, `os_governance_decision`, `os_audit_log`, `os_product*`, `os_uvr_*` y U7-B (`os_prestacion`, `os_uvr_profile`, `os_uvr_prestacion_valuation`, `v_os_uvr_prestacion_public`). |

Los repositorios PHP que consumen `os_admin` son `UserRepository`, `SessionRepository`, `RbacRepository`, `OrganizationRepository`, `InvitationRepository`, `AuditRepository`, `AuthThrottleRepository` y `PasswordResetRepository`. `CatalogGovernanceRepository` y `UvrRepository` consumen `public.os_governance_*`, `os_catalog_*` y `os_uvr_*`.

### 7.7 Contradicciones documentales detectadas

No se debe usar un único resumen como fuente de estado operativo:

- `sql/08_arquitectura/README.md:8` dice “Fases 1–10: no ejecutadas”, pero más adelante describe fases ejecutadas y cerradas; `README.md:59` también las describe como propuestas no ejecutadas.
- `docs/architecture/plan-migracion-multilingue.md` dice “CERO migraciones ejecutadas”, mientras `sql/07_multilingue/README.md:9-13` afirma que los scripts `01` a `14` fueron ejecutados en `origen_codes`.
- `docs/architecture/auditoria-internacionalizacion.md` es anterior al DDL y decía que las tablas multilingües no existían; el DDL sí está en el repositorio.
- Algunos artefactos DENTAR siguen rotulados “NO EJECUTADO”, pero el README de DENTAR aclara que el rótulo describe al archivo, no a la base.
- Los conteos de DENTAR/OFTAR citados en documentación son `[DOC-BD]`, no verificados en esta auditoría.

**Regla:** en los entregables se distingue “existe en el repositorio”, “documentado como aplicado” y “verificado en base en vivo”. Esta auditoría solo puede afirmar lo primero.

## 8. Riesgos

1. Publicar `/portal-clientes` sin verificar la configuración real de FastCGI y cabeceras puede romper autenticación por API Key.
2. Crear un esquema de clientes sin rol propio mezclaría gobernanza con clientes.
3. Asumir que `DB_NAME=origen_codes` está aplicado puede dejar la API apuntando a la base antigua.
4. Inventar `staging`, `sandbox` o URLs de API no verificadas produciría documentación falsa.
5. No versionar Nginx, certificados ni backups impide reproducir y revertir cambios con seguridad.
6. Reutilizar el carrito inexistente o el CTA de `#plataforma` como flujo comercial real sería una decisión no aprobada.
7. Tomar como estado real un resumen documental desactualizado puede llevar a ejecutar migraciones ya aplicadas o a omitir objetos existentes.

## 9. Decisiones pendientes

1. ¿Se autorizará acceso de solo lectura al VPS para cerrar la infraestructura real?
2. ¿Qué configuración de `.env` está activa en producción, sin revelar secretos?
3. ¿Existen backups verificados y con qué retención?
4. ¿Se creará un entorno de prueba o solo se trabajará con base independiente?
5. ¿Se permitirá ampliar roles de base para gestión de credenciales?
6. ¿Qué servicios reales se publicarán en la primera versión?

## 10. Requisito de autorización

No ejecutar comandos en VPS, conectarse a producción, modificar `.env`, Nginx, PHP-FPM, certificados, backups, esquemas, roles, grants ni servicios sin autorización expresa del propietario.
