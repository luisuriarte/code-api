# Auditoría integral previa al lanzamiento — Informe final

- **Fecha de cierre:** 2026-11-26
- **Etapas:** 1 Diagnóstico → 2 Aprobación → 3 Implementación → 4 Validación → 5 Informe final
- **Alcance:** API (`api/`), portal público (`med.origen.ar`, `portal/`, `web/`) y portal privado de clientes (`portal-clientes/`), con sus migraciones versionadas y documentación técnica.
- **Método:** lectura de código y configuración vigente como fuente de verdad; corrección de documentación cuando divergía del comportamiento real; verificaciones locales sin acceso a producción.
- **Estado del repositorio:** `HEAD` local y `origin/main` = `61d5073ef984ec74480f2ef9e3a3131cd989e064`. Todos los cambios de esta auditoría siguen **sin commitear** en el árbol de trabajo.

---

## 1. Resumen ejecutivo

| Métrica | Resultado |
|---|---|
| Hallazgos de la Etapa 1 | **71** (2 P0, 20 P1, 39 P2, 10 P3) |
| Corregidos y verificados localmente | **61** |
| Implementados, pero condicionados a activación/evidencia en el VPS | **8** |
| Pendientes | **2** (SEG-10 y DOC-08, ambos requieren decisión/evidencia del responsable) |
| Bloqueantes P0 abiertos | **0** |
| Suite local | `php tests/run.php` → **OK: 4068 comprobaciones** |
| Sintaxis PHP | `php -l` sobre todos los archivos PHP modificados/nuevos → **0 errores** |
| Paridad i18n activa | `es-AR` / `en` / `pt-BR` → **1771/1771/1771 claves, sin faltantes ni sobrantes** |

**Evaluación de lanzamiento: LISTO CON CONDICIONES.** No quedan defectos bloqueantes ni regresiones locales. Las nueve correcciones condicionadas o pendientes no son errores de código sin resolver: dependen de actas, despliegue, configuración real del proxy/SMTP o verificación HTTP en producción, acciones que el responsable debe ejecutar y documentar (§5).

---

## 2. Estado de los 71 hallazgos

Leyenda: **Corregido** = change aplicado y verificado localmente. **Condicionado** = código/migración preparada o mitigate aplicada, pero su efectividad depende de un paso en el VPS (acta, variable de entorno, proxy, SMTP o verificación HTTP). **Pendiente** = requiere decisión o evidencia que no está disponible; no se implementó nada adicional.

### P0 — Bloqueantes (2/2 corregidos)

| ID | Pri. | Estado | Evidencia / nota |
|---|---|---|---|
| SEG-01 | P0 | Corregido | Reset e invitaciones por SMTP real vía `CustomerNotification` + `SmtpMailer`; token nunca en flash, sesión, URL ni logs. `portal-clientes/Services/AuthService.php`, `CustomerNotification.php`, `Controllers/AuthController.php`; regresiones en `tests/run.php:4454-4486`. Requiere SMTP real configurado en el VPS. |
| UX-01 | P0 | Corregido | Selector de `domain`/`catalog` mutuamente excluyente y canonicalización en `portal/Views/browse.php` y `web/assets/js/browse-explorer.js:917-1065`; mensajes por parámetro en los tres idiomas. El servicio conserva el rechazo de combinaciones inválidas (`BrowseService.php:57-60`). |

### P1 — Altos (15 corregidos, 5 condicionados)

| ID | Pri. | Estado | Evidencia / nota |
|---|---|---|---|
| SEG-02 | P1 | Condicionado | `api/http/ApiKeyHash.php` (`SHA-256(clave + NUL + pepper)`, `key_prefix`, detección por `information_schema`) y doble lectura en `ApiKeyAuthenticator.php:51-70`; `ApiCredentialService` escribe hash cuando hay pepper y columnas. Migración `sql/10_portal_clientes/V11.001__api_key_hash.{up,down}.sql` **preparada, no ejecutada**: requiere acta, `API_KEY_PEPPER` y rotación autorizada. `tests/run.php:4509-4535`. |
| SEG-03 | P1 | Condicionado | `api/http/ApiRateLimiter.php` con `flock()` y sujeto `hash(clientId + REMOTE_ADDR)`; cableado en `api/index.php:231`; `429` + `Retry-After` en `ApiException` e `index.php:664-665`; documentado en README/OpenAPI. Verificado localmente (2 permitidas, 3.ª/4.ª denegadas). Requiere `var/api-rate` escribible en el VPS; si no lo está, falla abierto con `error_log` (`rate_limit_per_second=0` deniega siempre). |
| SEG-04 | P1 | Corregido | `session_regenerate_id(true)` tras validar credenciales en `portal-clientes/Services/AuthService.php`; cubierto en `tests/run.php:4489-4492`. |
| SEG-05 | P1 | Condicionado | Guardia `PORTAL_CUSTOMER_REQUIRE_HTTPS` y confianza restringida a `PORTAL_CUSTOMER_TRUSTED_PROXY_IPS` en `portal-clientes/Config.php:33-80`, `CustomerSession.php` y `web/portal-clientes/index.php`. Falta confirmar qué emite el proxy real; sin esa evidencia no se puede cerrar ni emitir HSTS/CSP. |
| SQL-01 | P1 | Corregido | `sql/10_portal_clientes/README.md` distingue las dos rutas (prueba y producción Etapa 13), prohíbe reejecutar `V10.002` y marca V11.001 como preparada/no ejecutada. |
| SQL-02 | P1 | Corregido | `DEV_ONLY__reset_os_customer.sql` con whitelist estricta de base de prueba; README actualizado. Ninguna ejecución SQL en la auditoría. |
| SQL-03 | P1 | Corregido | Guardas por base exacta en los `down` con `DROP ROLE`/`ALTER ROLE`; README advierte que esas operaciones son cluster-wide y requieren acta nueva. |
| SQL-04 | P1 | Corregido | Encabezado de `sql/09_admin/fase1_identidad.sql` unificado con `sql/09_admin/README.md` (Fase 1 aplicada y verificada el 2026-11-19). |
| SQL-05 | P1 | Corregido | Decisión del responsable: **documentar la excepción**. Las escrituras operativas sobre `public.api_clients` en `origen_codes` quedan descritas como autorizadas (acta Etapa 8), sin migración de datos. `portal-clientes/README.md:215,302`; `docs/portal-clientes/arquitectura-credenciales-api.md`. |
| COM-01 | P1 | Corregido | `priceDetail()` e `isTruncated()` en `portal/Services/InvoiceNinjaCatalogService.php`; la vista muestra moneda, periodicidad, impuestos y cargo solo cuando Invoice Ninja los devuelve; sin valores inventados. |
| COM-02 | P1 | Condicionado | `ServiceRequestService` propaga `sent`/`partial`/`failed` y envía correo de confirmación al solicitante; la vista refleja el estado real (`notification_partial`/`notification_failed`). **No se implementó** `notification_status` persistido con reintento/cola: queda como decisión comercial abierta. |
| I18-01 | P1 | Corregido | 25 claves `docs.*` agregadas con paridad en los tres idiomas activos; `/docs` deja de mostrar identificadores literales. |
| I18-02 | P1 | Corregido | Textos públicos de DENTAR/OFTAR/UVR ajustados a los catálogos publicados y a la semántica de UVR como unidad relativa; sin equivalencias clínicas inventadas. |
| DOC-01 | P1 | Corregido | Decisión **trilingüe con `?lang=` real**: sitemap con 30 URLs (3 locales × 10 rutas) y `x-default`; sin migración de router. `web/sitemap.php`, `web/docs.php`, `web/uvr.php`, `portal/Router.php`. |
| SEO-01 | P1 | Corregido | `x-default` emitido en HTML (`layouts/main.php`, `web/docs.php`, `web/uvr.php`) y en el sitemap. |
| SEO-02 | P1 | Condicionado | `web/sitemap.php` genera las 30 URLs canónicas reales; `web/robots.txt` versionado y `web/.htaccess` con `^robots\.txt$ - [L]`. Antes del despliegue `/sitemap.xml` respondía 404: **falta verificar** `/sitemap.xml` y `/robots.txt` en el VPS tras la publicación. |
| LEG-01 | P1 | Corregido | Páginas reales `/terminos` y `/privacidad`, localizadas, con versión/fecha de vigencia y contacto, enlazadas desde footer, Docs y Solicitud. Requieren publicación para verse en producción. |
| UX-02 | P1 | Corregido | `handleFetchError()`, `role="alert"`, reintento con fallback a navegación completa y estado “última actualización exitosa” en `web/assets/js/browse-explorer.js`; atributos `data-msg-*` en `browse.php`. |
| API-01 | P1 | Corregido | `X-Api-Token` y `/api/v1` rotulados como Invoice Ninja (externo); ejemplos propios usan solo `X-API-Key` o `Authorization: Bearer`. `README-API.md`, `docs/api/openapi-3.1.yaml`. |
| API-02 | P1 | Corregido | Textos de credenciales actualizados: self-service existe, está deshabilitado por defecto y V8.001 solo se aplicó en prueba. `docs/portal-clientes/*`, catálogos i18n. |

### P2 — Medios (35 corregidos, 3 condicionados, 1 pendiente)

| ID | Pri. | Estado | Evidencia / nota |
|---|---|---|---|
| SEG-06 | P2 | Condicionado | `blocked` aplicado a reset y a los flujos de token en `AuthService.php:134-243`; **la invitación no tiene throttle** (`MemberController.php:40-92`), solo CSRF, permiso y SMTP. |
| SEG-07 | P2 | Condicionado | Throttle persistente por hash de correo/token (`AuthThrottleRepository` + `Token::fingerprint`) en login, reset y aceptación; IP/UA hasheados en auditoría. **No se agregó timestamp firmado en formularios ni límite por IP** como pedía la decisión §4.4. |
| SEG-08 | P2 | Corregido | Invitaciones por SMTP real con `CustomerNotification::invitation`; el fallo invalida la invitación y se audita (`MemberController.php:81-92`). Sin enlaces de prueba en textos activos. |
| SEG-09 | P2 | Corregido | `api/http/Cors.php` rechaza `*` y emite cabeceras solo si `API_CORS_ORIGINS` está configurado; `Vary: Origin` se conserva. |
| SEG-10 | P2 | **Pendiente** | No se agregaron HSTS/CSP sin conocer qué emite el proxy del VPS. Requiere evidencia del responsable para decidir dónde emitirlos. |
| SEG-11 | P2 | Corregido | CSRF validado en `/admin/logout` (`portal/Controllers/AdminAuthController.php`); regresión en `tests/run.php:4559-4563`. |
| SEG-12 | P2 | Corregido | `RoleRepository::CUSTOMER_ASSIGNABLE` restringe los roles invitables; `origen_superadmin` excluido. |
| QA-01 | P2 | Condicionado | Suite ampliada a 4068 comprobaciones con regresiones por ID y verificaciones funcionales ligeras (429, limiter, YAML/i18n). **No se ejecutaron pruebas live de SMTP, Invoice Ninja ni navegador.** |
| SQL-08 | P2 | Corregido | Matching automático opt-in (`INVOICE_NINJA_CLIENT_MATCHING=false`); toda solicitud queda `needs_review` con `ninja_client_status='not_checked'` salvo coincidencia exacta validada. |
| API-03 | P2 | Corregido | `Authorization: Bearer` y `X-API-Key` documentados como alternativas, con prioridad de `X-API-Key` si ambas llegan. |
| API-04 | P2 | Corregido | Documentados los tres mensajes reales de `401` (sin clave, inactiva, inválida) sin prometer uniformidad inexistente. |
| API-05 | P2 | Corregido | `OPTIONS` → `204` documentado para cualquier ruta, antes de autenticar. |
| API-06 | P2 | Corregido | `SearchQ` (2–80) solo en `/v1/search`; `FreeTextQ` en el resto; sin cambios de validación en código. |
| API-07 | P2 | Corregido | Spec: eliminado `200 data: []` del detalle y declarado `404` con `ErrorEnvelope`, como hace el código. |
| API-08 | P2 | Corregido | Decisión **documentar topes actuales**, sin paginación nueva: `LIMIT 50` fijo en `/v1/mappings`, sin `limit` en diagnósticos, `offset` sin tope 5000 en catálogos. |
| API-09 | P2 | Corregido | `Domain.label/description` corregido a `es`/`en` (el catálogo estático no tiene `pt-BR`). |
| API-10 | P2 | Corregido | `oftar` agregado al enum `DomainPath` de la spec y al ejemplo del README. |
| API-11 | P2 | Corregido | “Coincidencia fonética” reemplazada por trigramas `pg_trgm`, coincidencia exacta/prefijo/contención y scoring por similitud. |
| API-12 | P2 | Corregido | Ejemplo del hero generado desde la proyección real de `/v1/concepts/search` (`HomeController.php`), sin aprobación editorial inventada. |
| API-13 | P2 | Corregido | Quickstart de `web/docs.php` con el `meta` real del wrapper común (`field_languages.items`, `next_offset`, sin fallback inventado). |
| API-14 | P2 | Corregido | Traducciones dejan de afirmar que la OpenAPI está desalineada; la spec vigente es la fuente del contrato. |
| API-15 | P2 | Corregido | CORS: `https://med.origen.ar` figura como ejemplo, no como valor por defecto. |
| API-16 | P2 | Corregido | `error.code` declarado contrato estable; `error.message` informativo en es-AR y no localizado. |
| I18-03 | P2 | Corregido | Decisión confirmada: un único esquema `?lang=` para Docs/UVR/Solicitud, con alternates y `x-default` coherentes. |
| I18-04 | P2 | Corregido | `/search` emite `Vary: Accept-Language, Cookie` y `noindex,follow`, sin alternates inválidos. |
| I18-05 | P2 | Corregido | `portal/Views/service-request.php` usa el formateador compartido `partials/format.php` (`1.234,56` / `1,234.56`) en lugar de `number_format` fijo en es-AR. |
| UX-03 | P2 | Corregido | `activeNav` derivado de `$currentPath` y `aria-current` cableado en las vistas públicas. |
| UX-04 | P2 | Corregido | Página 404 localizada con `errors.not_found.*` en los tres idiomas. |
| UX-05 | P2 | Corregido | Orden fijo y aviso de tope de `offset` documentados en la vista; sin parámetro `sort` inexistente. |
| UX-06 | P2 | Corregido | Textos de `exact`/`partial` reformulados como coincidencia textual, sin afirmar equivalencia clínica. |
| UX-07 | P2 | Corregido | El flag `/solicitud` también cierra la ruta, no solo los enlaces (`portal/Router.php`). |
| SEO-03 | P2 | Corregido | `web/robots.txt` versionado y excluido del rewrite por `web/.htaccess`; requiere publicación. |
| SEO-04 | P2 | Corregido | Alternativas `hreflang` de `/search` eliminadas; la ruta queda `noindex,follow`. |
| DOC-02 | P2 | Corregido | `README.md` actualizado: tres frentes, 142 `.sql` en 12 directorios (140 versionados + V11.001 preparada), estado DENTAR y socket `php8.5-fpm.sock`. |
| DOC-03 | P2 | Corregido | `portal-clientes/README.md` refleja la publicación de la Etapa 13 y sus excepciones autorizadas. |
| DOC-04 | P2 | Corregido | `.env.example` documenta las variables usadas por el código y las nuevas (`API_KEY_PEPPER`, `PORTAL_CUSTOMER_REQUIRE_HTTPS`, `PORTAL_CUSTOMER_TRUSTED_PROXY_IPS`, `INVOICE_NINJA_CLIENT_MATCHING`, `INVOICE_NINJA_CATALOG_LIMIT`), sin secretos. |
| DOC-05 | P2 | Corregido | Bandas “Histórico — superado” agregadas a los documentos de propuesta/inventarios, conservando el contenido original. |
| DOC-06 | P2 | Corregido | Anexo en `informe-ejecucion-etapa-13.md` con `HEAD` `61d5073`, los tres archivos del rediseño publicado y PHP 8.5.4/PostgreSQL 18.6 reales; no constituye acta de un nuevo deploy. |
| DOC-07 | P2 | Corregido | Contadores vigentes reemplazados por “verificar con `php tests/run.php`”; el `OK: 3647` histórico queda etiquetado como registro de la Etapa 7; `tests/README.md` describe la cobertura actual. |

### P3 — Bajos (9 corregidos, 1 pendiente)

| ID | Pri. | Estado | Evidencia / nota |
|---|---|---|---|
| SEG-13 | P3 | Corregido | Reset del panel por POST con campo oculto, `Referrer-Policy: no-referrer` y sin reinyección del token en flash (`AdminAuthController.php:119,138-156`). |
| SQL-09 | P3 | Corregido | Guarda `current_database()` agregada a los dos `verify_rollback` de V5 y V6; consultas `SELECT` intactas. |
| COM-03 | P3 | Corregido | `catalogTruncated()` y aviso `service_request.catalog_limited` cuando Invoice Ninja limita el catálogo a 100 productos; sin paginación nueva. |
| I18-06 | P3 | Corregido | `messages.es.yaml` marcado como catálogo legacy no cargado por `I18n`; la fuente activa es `messages.es-AR.yaml`. |
| I18-07 | P3 | Corregido | Placeholder del correo en `/admin/login` traducido vía `admin.login.email_placeholder`. |
| COM-04 | P3 | Corregido | Eliminada la doble escritura de selección en `ServiceRequestService.php`; regresión `tests/run.php:4585-4587`. |
| API-17 | P3 | Corregido | `refsets.maxLength` y su descripción ajustados a la validación real del código. |
| API-18 | P3 | Corregido | `os_customer.service` documentado como catálogo informativo; el código no deriva permisos ni habilita accesos por factura. |
| API-19 | P3 | Corregido | `tools/php/verificar_etapa13_produccion.php` exige `APP_DEBUG=false`, detecta trazas en HTML y verifica `/sitemap.xml` con `<urlset`. |
| DOC-08 | P3 | **Pendiente** | El runbook de cierre de Etapa 13 no fue ensayado y faltan datos de registro que solo puede aportar el responsable con acceso al VPS. |

---

## 3. Pruebas y validación (Etapa 4)

| Comando | Resultado |
|---|---|
| `php tests/run.php` | `OK: 4068 comprobaciones.` Sin avisos `Deprecated` ni fallos. |
| `php -l` sobre los archivos PHP modificados y nuevos | 0 errores de sintaxis. |
| `node --check web/assets/js/browse-explorer.js` | Sin errores. |
| Paridad de catálogos i18n activos | `es-AR`/`en`/`pt-BR`: 1771/1771/1771; `missing=0`, `extra=0`. |
| Verificación funcional local del limitador | 2 solicitudes permitidas, 3.ª y 4.ª con `429` y `Retry-After`. |
| `git status --short` / `git diff --stat` | Revisados; los cambios están en el árbol de trabajo, sin commit. |

La suite incorpora regresiones específicas por ID (SEG-01/02/03/04/05/06/11/12, COM-01/02/03/04, SQL-08, API-12/13, I18-05), además de las comprobaciones históricas de contrato, rutas, SQL, i18n y diseño. Ninguna comprobación fue eliminada para ocultar fallos; el número creció desde 3971 (Etapa 1) hasta 4068.

**No ejecutado:** SQL/psql contra ninguna base, despliegue, commit, push, pruebas live de SMTP/Invoice Ninja, ni verificación HTTP en producción posterior a estos cambios.

---

## 4. Cambios aplicados por área

| Área | Archivos principales | Verificación |
|---|---|---|
| Seguridad y sesiones (Oleada 0/1) | `portal-clientes/Services/{AuthService,CustomerSession,CustomerNotification,ApiCredentialService}.php`, `portal-clientes/Controllers/{AuthController,MemberController}.php`, `portal-clientes/Config.php`, `portal/Controllers/AdminAuthController.php`, `portal-clientes/Repositories/{RoleRepository,AuthThrottleRepository}.php` | Regresiones SEG-01/04/05/06/08/11/12; sin token en flash ni logs. |
| API y credenciales | `api/http/{ApiKeyHash,ApiRateLimiter,ApiKeyAuthenticator,ApiException,Cors}.php`, `api/index.php`, `.env.example`, `sql/10_portal_clientes/V11.001__api_key_hash.{up,down}.sql` | `429`/`Retry-After`, doble lectura hash→legacy, migración preparada sin ejecutar. |
| Solicitud de Servicios | `portal/Services/{ServiceRequestService,InvoiceNinjaCatalogService}.php`, `portal/Controllers/ServiceRequestController.php`, `portal/Views/service-request.php`, `portal/translations/messages.*.yaml` | Importes calculados en servidor; moneda real o texto neutral; sin “cart”, precios en PostgreSQL ni creación comercial automática. |
| SQL y gobernanza | `sql/10_portal_clientes/README.md`, `sql/09_admin/fase1_identidad.sql`, scripts `DEV_ONLY`, `down` y `verify_rollback` | Solo texto y guardas; **ninguna ejecución SQL**. |
| Sitio público, i18n, SEO y legal | `portal/Router.php`, `portal/Views/{browse,layouts/main}.php`, `portal/Views/partials/{format,browse/*}.php`, `portal/Views/legal/{terms,privacy}.php`, `web/{sitemap,docs,uvr,search}.php`, `web/{robots.txt,.htaccess}`, `web/assets/js/browse-explorer.js`, catálogos i18n | 30 URLs canónicas con `x-default`; paridad 1771/1771/1771; sin cambios de identidad visual. |
| Documentación técnica | `README.md`, `README-API.md`, `docs/api/openapi-3.1.yaml`, `docs/portal-clientes/*`, `tests/README.md` | Código como fuente; marcas históricas en vez de reescrituras; contrato sin cambios rompientes. |

**No regresión:** se conservan la identidad visual, los colores, el logotipo, la arquitectura de tres frentes, los envelopes `data/meta/request_id`, las URLs públicas, los nombres de catálogos, la denominación “Solicitud de Servicios”, la publicación de DENTAR PR/DX y OFTAR PR con UVR (AN/CL no publicados) y la conexión `origen_med` como pública por defecto. **V10.002 no se reejecutó**; `origen_codes` queda intacto salvo la excepción documentada de escrituras en `public.api_clients`.

---

## 5. Condiciones de lanzamiento y acciones del responsable

Estas acciones **no fueron ejecutadas por el asistente** y son necesarias para convertir los estados condicionados/pendientes en cierres definitivos:

1. **Publicación.** Revisar `git diff`, hacer commit y push, cargar archivos en el VPS y recargar `php-fpm` si `opcache.validate_timestamps=0`.
2. **Variables de entorno.** Configurar `API_KEY_PEPPER` (secreto real), `PORTAL_CUSTOMER_REQUIRE_HTTPS=true`, `PORTAL_CUSTOMER_TRUSTED_PROXY_IPS` con la IP del proxy real, `SMTP_*` reales, `INVOICE_NINJA_CLIENT_MATCHING=false` e `INVOICE_NINJA_CATALOG_LIMIT=100`. `APP_DEBUG=false`.
3. **Migración V11.001.** Solo con acta de despliegue y rotación autorizada. La doble lectura permite que las credenciales legacy sigan funcionando; el `down` exige revisión humana si hay filas con `api_key IS NULL`.
4. **Limitador.** Asegurar que `var/api-rate` exista y sea escribible por el usuario de `php-fpm`; sin eso el limitador falla abierto (se registra en `error_log`). Verificar una respuesta `429` controlada.
5. **Proxy y headers (SEG-05 / SEG-10).** Aportar evidencia de qué emite el proxy (`X-Forwarded-Proto`, HSTS, CSP). Con esa información se decide dónde emitir HSTS/CSP; no se agregaron cabeceras a ciegas.
6. **Verificación HTTP posterior al despliegue.** Estados de `/es-AR/`, `/docs?lang=es-AR`, `/sitemap.xml` (debe contener `<urlset`), `/robots.txt`, `/terminos`, `/privacidad`, las tres variantes de `/solicitud`, `/forgot` (sin token de 64 hex en HTML) y una `429` controlada. Antes del despliegue, `/sitemap.xml` daba 404 y `/robots.txt` daba 200.
7. **Correo comercial (COM-02).** Decidir si se requiere `notification_status` persistido con reintento/cola; hoy el fallo SMTP se informa en la respuesta y se registra, sin reintento automático.
8. **Runbook (DOC-08).** Ensayar el cierre de la Etapa 13 con datos reales del VPS y completar el registro.

---

## 6. Riesgos residuales

| Riesgo | Mitigación / estado |
|---|---|
| El pepper y las credenciales viven solo en el VPS | No se versionaron secretos; rotación y acta quedan a cargo del responsable. |
| Limitador dependiente de filesystem | Fail-open documentado y registrado; no bloquea la API si `var/api-rate` no es escribible. |
| Matching de Invoice Ninja no validado contra la versión instalada | Deshabilitado por defecto; todo queda para revisión humana. |
| Campos de moneda/periodicidad/impuestos no confirmados en la versión instalada | Se muestran solo si la respuesta real los trae; texto neutral en caso contrario. |
| Sin verificación en producción posterior a estos cambios | Runbook de la §5; el auditor solo validó localmente. |
| Documentación histórica con estados superados | Marcas “Histórico — superado” conservando actas y fechas. |
| HSTS/CSP sin decidir | No se emitieron cabeceras sin evidencia del proxy; SEG-10 permanece pendiente. |

---

## 7. Declaración final

Se completaron las cinco etapas de la auditoría sobre el código y la configuración vigentes, sin reconstruir la arquitectura ni cambiar contratos, URLs, catálogos, reglas editoriales o identidad visual. Los 2 hallazgos P0 están cerrados; 61 de 71 hallazgos están corregidos y verificados localmente, 8 quedan condicionados a pasos en el VPS y 2 requieren una decisión o evidencia del responsable.

**Desde el asistente no se ejecutaron migraciones ni consultas SQL contra ninguna base, ni se realizaron commit, push, despliegue, creación de clientes/facturas/pagos ni pruebas intrusivas en producción.** Todas las modificaciones permanecen en el árbol de trabajo para revisión del responsable.

**Cierre: LISTO CON CONDICIONES** para el lanzamiento comercial, supeditado a la §5.
