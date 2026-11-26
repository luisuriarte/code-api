# Auditoría integral — Problemas detectados

- **Fecha:** 2026-11-26
- **Etapa:** 1 — Diagnóstico (solo lectura)
- **Convención:** cada hallazgo tiene ID único, área, descripción, evidencia (`archivo:línea`), impacto, prioridad P0-P3, solución propuesta y archivos afectados.
- **Origen de los ID:** `SEG` seguridad/autenticación, `SQL` esquema y migraciones, `COM` Solicitud de Servicios, `API` contrato/documentación técnica, `UX` sitio público, `I18` internacionalización, `SEO` indexación, `LEG` legal, `DOC` documentación/estado, `QA` pruebas.
- **Duplicados:** cuando varios informes coincidieron, se unificó el hallazgo y se conservan las referencias originales.

**Estado:** diagnóstico solamente. Ninguno de estos hallazgos fue corregido en la Etapa 1. Los cambios requieren aprobación en la Etapa 2, salvo las correcciones documentales menores explícitamente autorizadas.

## Resumen por prioridad

| Prioridad | Cantidad | Naturaleza |
|---|---:|---|
| P0 | 2 | 1 toma de control de cuenta; 1 flujo público roto desde la propia UI |
| P1 | 20 | credenciales, rate limiting, sesiones, migraciones destructivas, precios, notificaciones, i18n visible, SEO y legal |
| P2 | 39 | endurecimiento, contrato API/docs, UX/accesibilidad, formatos y gobernanza documental |
| P3 | 10 | higiene, artefactos históricos y registro operativo |

> Nota sobre entorno: el responsable informó las versiones del VPS: PHP 8.5.4 (CLI NTS, OPcache 8.5.4), PostgreSQL 18.6 y cliente MariaDB 11.8.6 presente pero no utilizado por este proyecto. El entorno local de auditoría usa PHP 8.2.12. Ver `estado-actual.md` §2.

---

# P0 — Bloqueantes

### SEG-01 — Token de reset de contraseña expuesto a cualquier visitante
- **Área:** Portal-clientes / autenticación / account takeover.
- **Descripción:** El endpoint público `forgot` genera el token sin cifrar, lo guarda hasheado en base y devuelve el enlace real al solicitante dentro del mensaje flash. Cualquier persona que conozca el correo de un usuario activo recibe en pantalla un enlace válido para cambiar su contraseña.
- **Evidencia:** `portal-clientes/Services/AuthService.php:126-165` (raw token en `:148`, `TestNotification::prepare('reset', $raw)['link']` en `:163`); `portal-clientes/Controllers/AuthController.php:67-80` (flash `%link%` en `:76-79`); `portal-clientes/Views/layouts/customer.php:163-169` (render del flash); `portal-clientes/Router.php:100-104` (ruta pública); `portal-clientes/translations/messages.es-AR.yaml:25`.
- **Impacto:** Toma de control de cualquier cuenta de cliente sin autenticación, con acceso posterior a organizaciones, credenciales API y servicios. Agravado por SEG-06 (sin throttle en reset).
- **Prioridad:** **P0**.
- **Solución propuesta:** Eliminar `TestNotification` del flujo de reset en producción; enviar el enlace solo por SMTP al correo registrado; responder siempre mensaje genérico (existencia o no de la cuenta no debe distinguirse); el token raw nunca debe entrar en sesión, flash, URL de respuesta ni logs; expirar tras primer uso y rotar la sesión; agregar prueba de regresión que falle si el HTML contiene un token.
- **Archivos afectados:** `portal-clientes/Services/AuthService.php`, `portal-clientes/Controllers/AuthController.php`, `portal-clientes/Services/TestNotification.php`, `portal-clientes/Views/layouts/customer.php`, `portal-clientes/translations/messages.{es-AR,en,pt-BR}.yaml`, `tests/run.php`.
- **Referencias:** informe de seguridad P0-01; informe SQL AUD-01 (verificado por lectura directa).

### UX-01 — El explorador ofrece combinaciones de dominio y catálogo que el servidor rechaza
- **Área:** Sitio público / Browse Codes / funcionalidad.
- **Descripción:** Sin familia seleccionada, el selector muestra dominios y catálogos en la misma lista y permite selección múltipla de ambos tipos; el JavaScript escribe los dos campos ocultos. El servicio rechaza cualquier combinación de catálogo con dominio que no sea `odontologia` u `oftar`, de modo que la propia interfaz genera búsquedas que devuelven `invalid_catalog`.
- **Evidencia:** `portal/Views/browse.php:202-232` (opciones `data-code-kind="domain"` en `:213-218` y `"catalog"` en `:222-228`, ambos habilitados cuando `family === ''`; hidden inputs en `:231-232`); `web/assets/js/browse-explorer.js:875-912` (`updateCodeHidden()` rellena ambos hidden); `portal/Services/BrowseService.php:57-60` (rechazo); `portal/Repositories/CatalogRepository.php:20-24`; `portal/translations/messages.es-AR.yaml:603-604` (mensaje genérico, además incorrecto para OFTAR).
- **Impacto:** El usuario ve “El catálogo DENTAR seleccionado no es válido” después de elegir una opción ofrecida por la interfaz; la búsqueda queda sin resultados. Afecta la función principal de descubrimiento del sitio.
- **Prioridad:** **P0**.
- **Solución propuesta:** Hacer mutuamente excluyentes `domain` y `catalog` en el selector, o centralizar una única regla de combinaciones válidas compartida por vista, JS y servicio. Canonicalizar antes de validar, devolver mensaje específico por parámetro y agregar pruebas de la ruta UI → controlador → servicio.
- **Archivos afectados:** `portal/Views/browse.php`, `web/assets/js/browse-explorer.js`, `portal/Services/BrowseService.php`, `portal/Repositories/CatalogRepository.php`, `portal/translations/messages.{es-AR,en,pt-BR}.yaml`, `tests/run.php`.
- **Referencias:** informe de sitio público AUD-01 (verificado por lectura directa).

---

# P1 — Altos

### SEG-02 — API keys de clientes B2B almacenadas en texto plano
- **Área:** API / gestión de secretos.
- **Descripción:** La autenticación compara la clave recibida por igualdad SQL exacta contra `api_clients.api_key`, que se almacena en claro. El propio código y el servicio de credenciales lo reconocen.
- **Evidencia:** `api/http/ApiKeyAuthenticator.php:16-18,47-55`; `sql/01_schema/design.sql:79`; `portal-clientes/Services/ApiCredentialService.php:15-18,58-70`; `sql/10_portal_clientes/V8.001__api_credentials.up.sql:7-11`.
- **Impacto:** Cualquier lectura de base, dump o backup expone todas las credenciales vigentes y permite su reutilización hasta revocación manual.
- **Prioridad:** **P1**.
- **Solución propuesta:** Migración planificada a `key_prefix` + `key_hash = SHA-256(clave || pepper)` con pepper en `.env`, comparación con `hash_equals()`, doble lectura transitoria y revocación de claves expuestas. Restringir privilegios de lectura mientras tanto.
- **Archivos afectados:** `api/http/ApiKeyAuthenticator.php`, `portal-clientes/Services/ApiCredentialService.php`, `portal-clientes/Repositories/ApiCredentialRepository.php`, `sql/01_schema/design.sql`, nueva migración en `sql/10_portal_clientes/`, `.env.example`, `docs/portal-clientes/arquitectura-credenciales-api.md`.
- **Referencias:** seguridad P1-02; API AUD-03 (verificado).

### SEG-03 — `rate_limit_per_second` se consulta pero nunca se aplica
- **Área:** API / disponibilidad y abuso.
- **Descripción:** El autenticador devuelve el cupo por cliente; el front controller descarta el valor y no existe limitador, `429` ni `Retry-After` en la capa API.
- **Evidencia:** `api/http/ApiKeyAuthenticator.php:27,64-68`; `api/index.php:224-227`; búsqueda sin otras apariciones en `api/`; `README-API.md:117-120`; `docs/portal-clientes/auditoria-infraestructura.md:83`.
- **Impacto:** Un cliente o una clave filtrada puede saturar PostgreSQL con búsquedas trigram; el `statement_timeout` de 5 s limita cada consulta, no el volumen. Los clientes pueden dimensionar mal su consumo.
- **Prioridad:** **P1**.
- **Solución propuesta:** Implementar limitador por `api_client.id` antes de enrutar, con `429` y `Retry-After`; o, si se decide no implementarlo, quitar la columna del contrato visible y documentarla como meramente informativa. Defensa en profundidad en el proxy.
- **Archivos afectados:** `api/index.php`, `api/http/ApiKeyAuthenticator.php`, nuevo servicio de rate limit, `README-API.md`, `docs/api/openapi-3.1.yaml`, `.env.example`.
- **Referencias:** seguridad P1-03; API AUD-04 (verificado).

### SEG-04 — Session fixation en el login del portal de clientes
- **Área:** Portal-clientes / sesiones.
- **Descripción:** Tras validar credenciales se escriben `customer_token`, `customer_user_id` y `customer_session_id` en la sesión existente, sin `session_regenerate_id(true)`. El panel `/admin` sí lo hace.
- **Evidencia:** `portal-clientes/Services/CustomerSession.php:16-35`; `portal-clientes/Services/AuthService.php:72-90`; contraste `portal/Admin/AuthService.php:129-135`; `tests/run.php:1848-1851` cubre solo `/admin`.
- **Impacto:** Un atacante que fije un `PHPSESSID` válido puede reutilizarlo después de que la víctima inicie sesión.
- **Prioridad:** **P1**.
- **Solución propuesta:** Regenerar el identificador después de validar credenciales y antes de almacenar datos autenticados; también tras aceptar invitación o completar reset si se crea sesión. Agregar verificación en `tests/run.php`.
- **Archivos afectados:** `portal-clientes/Services/AuthService.php`, `portal-clientes/Services/CustomerSession.php`, `tests/run.php`.

### SEG-05 — HTTPS no exigido en el portal de clientes y confianza en `X-Forwarded-Proto`
- **Área:** Portal-clientes / transporte / cookies.
- **Descripción:** `PORTAL_CUSTOMER_REQUIRE_HTTPS` existe en configuración pero no se aplica como guardia. La cookie se marca `secure` según `$_SERVER['HTTPS']` o una cabecera controlable por el cliente; no hay configuración de proxy versionada que garantice su sobrescritura.
- **Evidencia:** `portal-clientes/Config.php:33-58`; `portal-clientes/Services/CustomerSession.php:22-31`; `web/portal-clientes/index.php:14-20`; contraste `portal/Admin/AdminGuard.php:22-30,73-79`; `docs/portal-clientes/auditoria-portal-gobernanza.md:106,137`.
- **Impacto:** Posible envío de cookies por HTTP y evasión del criterio `secure`. Riesgo real si el proxy reenvía la cabecera del cliente; teórico si la fija. La opción de configuración no produce efecto.
- **Prioridad:** **P1**.
- **Solución propuesta:** Aplicar guardia equivalente a `AdminGuard::requireSecure()`; confiar en `X-Forwarded-Proto` solo desde proxy de confianza o eliminar esa fuente; fijar `secure=true` en producción; documentar HSTS en el servidor.
- **Archivos afectados:** `portal-clientes/Config.php`, `portal-clientes/Services/CustomerSession.php`, `web/portal-clientes/index.php`, `portal-clientes/Router.php`, configuración del proxy (fuera del repo).
- **Referencias:** SQL AUD-03; seguridad P2-05 (parcial).

### SQL-01 — El README de migraciones contradice el estado de producción de la Etapa 13
- **Área:** SQL / gobernanza de migraciones.
- **Descripción:** `sql/10_portal_clientes/README.md` declara las migraciones “preparadas para entorno de prueba. No ejecutar en producción” e incluye `V10.002`, mientras el acta y el informe de Etapa 13 registran `V5.001`→`V10.001` aplicadas en `origen_codes_portal_clientes` y prohibición expresa de reejecutar `V10.002` (ya aplicada cluster-wide).
- **Evidencia:** `sql/10_portal_clientes/README.md:3,49-54`; `docs/portal-clientes/acta-autorizacion-etapa-13.md:22-36`; `docs/portal-clientes/plan-etapa-13-produccion.md:89-115`; `docs/portal-clientes/informe-ejecucion-etapa-13.md:38-49`.
- **Impacto:** Un operador puede aplicar `V10.002` o un rollback completo sobre producción con efecto cluster-wide, o creer que la base operativa es solo de prueba.
- **Prioridad:** **P1**.
- **Solución propuesta:** Documentar dos rutas explícitas (“prueba” y “producción Etapa 13”), con orden exacto y prohibición de `V10.002` en producción; agregar preflight que distinga `..._test` de la base operativa. Sin ejecutar nada en esta etapa.
- **Archivos afectados:** `sql/10_portal_clientes/README.md`, `sql/10_portal_clientes/ETAPA13__preflight.sql`, `docs/portal-clientes/manifiesto-etapa-13-produccion.md`.
- **Referencias:** SQL AUD-04.

### SQL-02 — Script destructivo `DEV_ONLY` con guarda insuficiente
- **Área:** SQL / seguridad operativa.
- **Descripción:** El script dice “NUNCA en producción”, pero solo rechaza `origen_codes`; la base operativa `origen_codes_portal_clientes` pasaría la guarda. Ejecuta `DROP SCHEMA os_customer CASCADE`, elimina `audit_log` y hace `DROP ROLE IF EXISTS origen_customer` (cluster-wide).
- **Evidencia:** `sql/10_portal_clientes/DEV_ONLY__reset_os_customer.sql:1-10,15-21,33-37`; `sql/10_portal_clientes/README.md:11`. Verificado por lectura directa.
- **Impacto:** Destrucción irreversible de auditoría y datos del portal privado en producción; el `DROP ROLE` afecta otras bases.
- **Prioridad:** **P1**.
- **Solución propuesta:** Whitelist estricta de bases de desarrollo (por ejemplo solo `origen_codes_portal_clientes_test`), confirmación interactiva o variable obligatoria, y mover el script fuera del directorio de migraciones desplegables.
- **Archivos afectados:** `sql/10_portal_clientes/DEV_ONLY__reset_os_customer.sql`, `sql/10_portal_clientes/README.md`.
- **Referencias:** SQL AUD-05 (verificado).

### SQL-03 — Rollbacks con efecto cluster-wide
- **Área:** SQL / migraciones / roles.
- **Descripción:** La guarda del `down` de V5.001 usa `LIKE 'origen_codes_portal_clientes%'`, por lo que permite ejecutarse en la base operativa. El `down` contiene `DROP ROLE IF EXISTS origen_customer`; el `down` de V10.002 puede restaurar `SUPERUSER` a `origen_med`. Los roles son cluster-wide, no por base.
- **Evidencia:** `sql/10_portal_clientes/V5.001__os_customer_identity.down.sql:13-20,75-76`; `sql/10_portal_clientes/V10.002__origen_med_no_superuser.up.sql:5-9,17-31`; `sql/10_portal_clientes/README.md:32-34,49-54`.
- **Impacto:** Un rollback desde producción puede eliminar el rol de aplicación usado por otras bases o anular el `NOSUPERUSER` verificados en Etapa 10/13.
- **Prioridad:** **P1**.
- **Solución propuesta:** Guardas por base exacta; exigir confirmación cluster-wide explícita y registro de decisión para `DROP ROLE`/`ALTER ROLE`, o sacar esas operaciones de los `down` versionados y dejarlas como procedimientos administrativos auditados.
- **Archivos afectados:** `sql/10_portal_clientes/V5.001__os_customer_identity.down.sql`, `sql/10_portal_clientes/V10.002__origen_med_no_superuser.down.sql`, `sql/10_portal_clientes/README.md`.
- **Referencias:** SQL AUD-06.

### SQL-04 — Estado contradictorio del esquema `os_admin` / Fase 1
- **Área:** SQL / trazabilidad.
- **Descripción:** El encabezado de `fase1_identidad.sql` dice que no debe ejecutarse sin aprobación y cierra con “No se ha ejecutado”, mientras el README del directorio afirma que Fase 1 fue aplicada y verificada en `origen_codes` el 2026-11-19.
- **Evidencia:** `sql/09_admin/fase1_identidad.sql:4-6,280`; `sql/09_admin/README.md:3-10`; `docs/portal-clientes/auditoria-portal-gobernanza.md:354`.
- **Impacto:** No es posible determinar desde el repo cuál es el estado autoritativo de M1 en producción; afecta trazabilidad, rollback y migraciones futuras.
- **Prioridad:** **P1**.
- **Solución propuesta:** Actualizar el encabezado con fecha, acta y verificador, o corregir el README si la afirmación fue errónea; unificar un único registro de estado por migración.
- **Archivos afectados:** `sql/09_admin/fase1_identidad.sql`, `sql/09_admin/README.md`, `docs/portal-clientes/auditoria-portal-gobernanza.md`.
- **Referencias:** SQL AUD-07.

### SQL-05 — El DSN de credenciales apunta a `origen_codes` y el self-service escribe allí
- **Área:** Portal-clientes / separación de bases / gobernanza.
- **Descripción:** Etapa 13 documenta `PORTAL_CUSTOMER_CREDENTIAL_DB_DSN` apuntando a `origen_codes` “sin escribir allí”. Sin embargo el self-service de credenciales hace `INSERT`, `UPDATE api_key` y `UPDATE is_active` en `public.api_clients` de esa base. La excepción de grant a `origen_admin` fue autorizada en Etapa 8 pero no queda reflejada coherentemente en Etapa 13.
- **Evidencia:** `docs/portal-clientes/acta-autorizacion-etapa-13.md:26-34`; `portal-clientes/README.md:291-299`; `.env.example:158-160`; `portal-clientes/Services/ApiCredentialService.php:58-70,126-139,184-193`; `docs/portal-clientes/acta-autorizacion-etapa-8.md:80-91,169`.
- **Impacto:** Las verificaciones de “`origen_codes` sin cambios” pueden ser válidas solo para migraciones, no para operación normal; se pierde trazabilidad de escrituras operativas.
- **Prioridad:** **P1**.
- **Solución propuesta:** Decidir y documentar una sola regla: trasladar escrituras a la base operativa o mantener la excepción describiéndola explícitamente como “escritura autorizada sobre `public.api_clients` en `origen_codes`”, con auditoría y monitorización.
- **Archivos afectados:** `portal-clientes/Services/ApiCredentialService.php`, `portal-clientes/Config.php`, `docs/portal-clientes/acta-autorizacion-etapa-13.md`, `portal-clientes/README.md`.
- **Referencias:** SQL AUD-08; API AUD-02.

### COM-01 — Precios sin moneda, periodicidad, condición impositiva ni cargo único/recurrente
- **Área:** Solicitud de Servicios / presentación comercial.
- **Descripción:** La vista y el correo muestran un número con dos decimales y la etiqueta “Precio publicado”/“Cotización personalizada”, pero no el código de moneda (`ARS`/`USD`), periodicidad, condiciones impositivas ni si el cargo es único o recurrente. El servicio solo extrae `price` y deriva `modality` de si el precio existe.
- **Evidencia:** `portal/Services/InvoiceNinjaCatalogService.php:80-101,214-225`; `portal/Views/service-request.php:123-133,197-203`; `portal/Services/ServiceRequestService.php:256-267`; `portal/translations/messages.es-AR.yaml:1801-1820,1855-1856`; sin coincidencias de `ARS|USD|currency|periodicidad|recurren|IVA` en la vista ni en el catálogo.
- **Impacto:** Importes ambiguos en un flujo con token real de Invoice Ninja; un cargo recurrente puede interpretarse como único o una moneda por otra. El aviso “no es una factura” mitiga pero no resuelve.
- **Prioridad:** **P1**.
- **Solución propuesta:** Obtener de la versión instalada de Invoice Ninja solo los campos que realmente exponga; mostrar el código de moneda junto a importes y total; mostrar periodicidad, impuestos y cargo único/recurrente únicamente si la API los devuelve; si no, usar texto neutral y documentar la limitación. No inventar valores por defecto.
- **Archivos afectados:** `portal/Services/InvoiceNinjaCatalogService.php`, `portal/Views/service-request.php`, `portal/Services/ServiceRequestService.php`, `portal/translations/messages.{es-AR,en,pt-BR}.yaml`.
- **Referencias:** SQL AUD-09.

### COM-02 — Éxito confirmado aunque falle el SMTP; sin correo al solicitante
- **Área:** Solicitud de Servicios / notificaciones.
- **Descripción:** `notify()` envía solo al correo de contacto interno (con BCC opcional y `Reply-To` del solicitante), no al solicitante, y si falla solo escribe `error_log()`. La operación se devuelve como exitosa y la vista muestra “Solicitud recibida”, prometiendo respuesta por correo.
- **Evidencia:** `portal/Services/ServiceRequestService.php:141-152,232-287` (fallo en `:283-286`); `portal/Views/service-request.php:56-68`; `portal/Config.php:179-181,191-220`; `portal/translations/messages.es-AR.yaml:1834-1836`; contraste correcto en `portal/Services/ContactService.php:80-86`.
- **Impacto:** Pérdida silenciosa del lead comercial; el solicitante cree que el proceso terminó y no recibe comprobación; la revisión humana depende de un correo que puede no haberse entregado.
- **Prioridad:** **P1**.
- **Solución propuesta:** Propagar el resultado de `notify()`; persistir `notification_status` (por ejemplo `pending`/`failed`) y reintentar; enviar confirmación al solicitante con la referencia; alinear el texto visible con el estado real sin exponer detalles internos. No limpiar selección ni rotar CSRF hasta conocer el resultado o existir cola de reintentos.
- **Archivos afectados:** `portal/Services/ServiceRequestService.php`, `portal/Services/SmtpMailer.php`, `portal/Controllers/ServiceRequestController.php`, `portal/Views/service-request.php`, `sql/10_portal_clientes/V10.001__public_service_requests.up.sql`, `portal/translations/messages.{es-AR,en,pt-BR}.yaml`, `tests/run.php`.
- **Referencias:** SQL AUD-10; sitio público AUD-02 (verificado).

### I18-01 — 25 claves inexistentes renderizan el identificador literal en `/docs`
- **Área:** Internacionalización / documentación pública.
- **Descripción:** `web/docs.php` usa claves sin prefijo `docs.` que no existen en ningún catálogo. El traductor devuelve la propia clave, por lo que se muestran textos como `common.production`, `common.authenticated` o `search.params_title` en los tres idiomas. Las equivalentes `docs.*` sí existen.
- **Evidencia:** `web/docs.php:23,96-99,118,122,149-154,688-689,704-705,712,716,728,767,797,817-823,828,862,892-894,982,993,1026`; `portal/i18n/I18n.php:241-250,352-358` (sin prefijos automáticos); `portal/translations/messages.es-AR.yaml:106` (`docs:`), `:191-198` (`common.*`), `:282` (`docs.search.params_title`); mismo patrón en `messages.en.yaml:194,196,282` y `messages.pt-BR.yaml:194,196,282`. Verificado: `common.production` no existe como clave raíz; `docs.common.production` sí.
- **Impacto:** Encabezados de tabla, badges, breadcrumbs, pestañas de código, notas y advertencias se muestran como identificadores crudos en es-AR, en y pt-BR. Afecta comprensión, accesibilidad y SEO. El test de paridad no lo detecta porque omite claves sin prefijo (`tests/run.php:1605-1609`).
- **Prioridad:** **P1**.
- **Solución propuesta:** Reemplazar las 25 llamadas por su forma `docs.*` o usar un helper con prefijo condicional (`str_starts_with($key, 'docs.') ? $key : 'docs.' . $key`). Actualizar `tests/run.php` para validar también claves sin prefijo y agregar regresión que falle si `trans()` devuelve una clave que existe como `docs.*`.
- **Archivos afectados:** `web/docs.php`, `tests/run.php`, `portal/translations/messages.{es-AR,en,pt-BR}.yaml` (solo como fuente, sin edición de valores).
- **Referencias:** i18n I18N-001.

### I18-02 — Textos públicos contradicen los catálogos publicados y la metodología UVR vigente
- **Área:** Contenido / reglas editoriales / i18n.
- **Descripción:** Los catálogos activos conservan frases que describen DENTAR como pendiente, etiquetas “en preparación”, tablas UVR “propuestas y vacías” y una fórmula UVR distinta de la implementada. El código y el SQL muestran PR/DX publicados, componentes `work`, `practice_expense`, `professional_liability` y un ejemplo verificado de 33,00 UVR.
- **Evidencia:** `portal/Views/browse.php:10-19` (publicación real); `portal/translations/messages.es-AR.yaml:109,380,802,808`; `sql/08_arquitectura/fase6_uvr.sql:104-109,212-224`; `sql/03_oftar/uvr_ejemplo_oct_oftar_pr_u7b.sql:156`; `tests/run.php:3290-3299`; `docs/api/openapi-3.1.yaml` y `portal/i18n/I18n.php:378` (sin ruta `/fhir`).
- **Impacto:** El sitio afirma que algo está “en preparación” cuando ya está publicado; describe una fórmula UVR diferente; niega valores cuando existe un fixture verificable. Afecta confianza, consistencia y explicación de la metodología. No se debe inventar equivalencias ni valores nuevos.
- **Prioridad:** **P1**.
- **Solución propuesta:** Reescribir las claves en los tres idiomas desde el estado real del código/SQL, distinguiendo “metodología documentada”, “fixture cargado” y “valor publicado”. Agregar tests que fallen si reaparecen frases obsoletas. Mantener AN/CL como no publicados.
- **Archivos afectados:** `portal/translations/messages.{es-AR,en,pt-BR}.yaml`, `web/docs.php`, `portal/Views/partials/browse/detail.php`, `tests/run.php`.
- **Referencias:** sitio público AUD-04.

### DOC-01 — Alcance idiomático sin definir: el sitio es trilingüe en código y producción
- **Área:** Gobernanza de contenido / i18n.
- **Descripción:** La premisa de trabajo “solo es-AR, sin traducir aún” es falsa frente al código: `SUPPORTED` incluye `es-AR`, `en` y `pt-BR`, hay selector público, alternates y sitemap por idioma, y los catálogos activos tienen paridad total (1714 claves en `portal`, 208 en `portal-clientes`).
- **Evidencia:** `portal/i18n/I18n.php:25-26,230-235`; `portal/Views/partials/language-switcher.php:16-31`; `portal/Views/layouts/main.php:16-18`; `web/sitemap.php:24-52`; catálogos `messages.{es-AR,en,pt-BR}.yaml`.
- **Impacto:** Cualquier decisión de UX, QA, SEO o contenido basada en “monolingüe” es inválida; conviven dos afirmaciones sobre el producto.
- **Prioridad:** **P1** (decisión de alcance; no implementación).
- **Solución propuesta:** Definir formalmente una sola regla: si monolingüe, retirar `en`/`pt-BR` de `SUPPORTED`, selector, hreflang y sitemap y archivar traducciones; si trilingüe, actualizar documentación, QA y flujo de revisión de traducciones. No dejar ambos estados conviviendo.
- **Archivos afectados:** `portal/i18n/I18n.php`, `portal/Views/partials/language-switcher.php`, `portal/Views/layouts/main.php`, `web/sitemap.php`, catálogos de traducción, documentación de producto.
- **Referencias:** sitio público AUD-03; i18n (paridad confirmada).

### SEO-01 — `x-default` en el sitemap pero no en el HTML
- **Área:** SEO / hreflang.
- **Descripción:** El layout público emite solo los alternates devueltos por `I18n::alternateLinks()`, que itera los idiomas soportados sin `x-default`. El sitemap sí lo incluye apuntando al locale por defecto.
- **Evidencia:** `portal/Views/layouts/main.php:15-18`; `portal/i18n/I18n.php:151-165`; `web/sitemap.php:43-52`.
- **Impacto:** Conjuntos de alternates distintos entre HTML y sitemap; los motores pueden elegir un locale distinto del esperado para usuarios sin coincidencia exacta.
- **Prioridad:** **P1**.
- **Solución propuesta:** Emitir `x-default` en `alternateLinks()` o directamente en `main.php` con la misma URL del sitemap; verificar que canonical, `og:url`, hreflang y sitemap coincidan por ruta.
- **Archivos afectados:** `portal/i18n/I18n.php`, `portal/Views/layouts/main.php`, `web/sitemap.php`, `tests/run.php`.

### SEO-02 — Sitemap incompleto y `/sitemap.xml` responde 404 en producción
- **Área:** SEO operativo / despliegue.
- **Descripción:** El sitemap incluye solo siete rutas por idioma y excluye explícitamente UVR; no incluye `/solicitud` (pública y enlazada en los tres idiomas) ni fichas de browse. Además, la comprobación en vivo del 2026-11-26 devolvió 404 pese a existir `web/sitemap.php` y la regla de rewrite.
- **Evidencia:** `web/sitemap.php:8-12,22,36-53`; `portal/Config.php:64-71`; `web/.htaccess:16`; comprobación HTTP en vivo: `https://med.origen.ar/sitemap.xml` → 404; `docs/audit/estado-actual.md` §5.
- **Impacto:** Las pocas señales definidas no llegan a los motores; páginas públicas reales no son descubribles. Requiere contraste con la configuración del VPS (no auditada aquí).
- **Prioridad:** **P1**.
- **Solución propuesta:** Generar el sitemap desde un registro único de rutas públicas canónicas; incluir `/uvr`, `/solicitud` y fichas estables si no son `noindex`; verificar el despliegue de `web/sitemap.php` y la regla de rewrite en el VPS; separar exclusiones legítimas de olvidos.
- **Archivos afectados:** `web/sitemap.php`, `web/.htaccess`, `portal/Router.php`, `web/uvr.php`, `portal/Config.php`, `tests/run.php`, configuración del VPS.

### LEG-01 — “Términos” y “Privacidad” apuntan al mismo `mailto:` y no hay documentos legales
- **Área:** Legal / cumplimiento / consentimiento.
- **Descripción:** El footer usa la misma dirección `mailto:legal@origen.ar` para ambos enlaces; `docs.php` solo cambia el asunto; no hay rutas `/terminos` ni `/privacidad`. El checkbox de la Solicitud de Servicios pide aceptar términos sin enlace a un documento real.
- **Evidencia:** `portal/View.php:22-24`; `portal/Views/partials/footer.php:63-68`; `web/docs.php:59-60`; `portal/Views/service-request.php:250-254`; `portal/Router.php` (sin rutas legales).
- **Impacto:** No existe diferencia material entre ambos enlaces; insuficiente para consentimiento informado y para cualquier auditoría legal.
- **Prioridad:** **P1**.
- **Solución propuesta:** Crear páginas localizadas `/terminos` y `/privacidad` con versión y fecha de vigencia, enlazarlas desde footer, docs y el checkbox. Si por decisión legal se prefiere correo, al menos diferenciar texto y asunto de forma explícita y accesible.
- **Archivos afectados:** `portal/View.php`, `portal/Views/partials/footer.php`, `web/docs.php`, `portal/Views/service-request.php`, `portal/Router.php`, `portal/translations/messages.{es-AR,en,pt-BR}.yaml`.

### UX-02 — Fallos de `fetch` silenciosos en el explorador
- **Área:** Sitio público / JS / accesibilidad.
- **Descripción:** Los `catch` de `fetchResults()` y `appendResults()` solo quitan `aria-busy`; no muestran mensaje, no ofrecen reintento y conservan resultados anteriores como si estuvieran actualizados. El patrón de error sí existe en la ficha de detalle.
- **Evidencia:** `web/assets/js/browse-explorer.js:1022-1027,1094-1096`; `portal/Views/partials/browse/results.php:70-109`; contraste `portal/Views/partials/browse/detail.php:24-33`.
- **Impacto:** Ante fallo de red, servidor o parseo, el usuario ve datos desactualizados sin aviso; las tecnologías asistivas tampoco detectan el fallo.
- **Prioridad:** **P1**.
- **Solución propuesta:** Centralizar `handleFetchError()`: mensaje localizado con `role="alert"`, marcar los resultados como “última actualización exitosa”, ofrecer “Reintentar” y fallback a navegación completa como en `requestFragment()`.
- **Archivos afectados:** `web/assets/js/browse-explorer.js`, `portal/Views/partials/browse/results.php`, `portal/Views/partials/browse/detail.php`, `portal/translations/messages.{es-AR,en,pt-BR}.yaml`.

### API-01 — `X-Api-Token` mezcla el contrato de Invoice Ninja con el de la API propia
- **Área:** API / ejemplos / portal-clientes.
- **Descripción:** La API de Origen Salud acepta solo `X-API-Key` o `Authorization: Bearer`. El header `X-Api-Token` y el prefijo `/api/v1` aparecen en documentación del portal de clientes como si fueran propios; en realidad corresponden a Invoice Ninja.
- **Evidencia:** `api/http/ApiKeyAuthenticator.php:33`; `portal-clientes/README.md:76`; `portal-clientes/Services/InvoiceNinja/HttpInvoiceNinjaTransport.php:98-101`; `portal/Services/InvoiceNinjaCatalogService.php:171-177`.
- **Impacto:** Un integrador que copie `X-Api-Token` recibe 401; se mezclan dos contratos en documentación pública.
- **Prioridad:** **P1**.
- **Solución propuesta:** Rotular explícitamente esos ejemplos como “externos / Invoice Ninja, no Origen Salud API” y usar solo `X-API-Key` o Bearer en todos los ejemplos propios.
- **Archivos afectados:** `portal-clientes/README.md`, `docs/portal-clientes/acta-autorizacion-etapa-6.md`, `docs/api/openapi-3.1.yaml`, `README-API.md`, `web/docs.php`, `portal/Views/home.php`.

### API-02 — Self-service de credenciales: documentación niega una función que el código implementa
- **Área:** Portal-clientes / gobernanza de credenciales.
- **Descripción:** Traducciones y auditorías afirman que no hay emisión, rotación ni revocación de credenciales; el portal implementa create/rotate/revoke, protegido por permisos y deshabilitado por defecto según configuración.
- **Evidencia:** `portal/translations/messages.{es-AR,en,pt-BR}.yaml:235,386`; `docs/portal-clientes/auditoria-api.md:20,170,195`; `portal-clientes/Services/ApiCredentialService.php:39-58,110-131,168-203`; `portal-clientes/Router.php:204-228`; `sql/10_portal_clientes/V8.001__api_credentials.up.sql:1-24`.
- **Impacto:** Información falsa al usuario: o cree que la función no existe, o que está habilitada en producción cuando el default es deshabilitada.
- **Prioridad:** **P1**.
- **Solución propuesta:** Redactar una única verdad en los tres idiomas: “implementado en portal-clientes, deshabilitado por defecto; requiere `PORTAL_CUSTOMER_CREDENTIAL_DB_DSN/USER/PASS`; V8 es solo entorno de prueba”.
- **Archivos afectados:** `portal/translations/messages.{es-AR,en,pt-BR}.yaml`, `docs/portal-clientes/auditoria-api.md`, `docs/portal-clientes/arquitectura-credenciales-api.md`, `portal-clientes/Views/credentials.php`, `portal-clientes/Config.php`.

---

# P2 — Medios

### SEG-06 — Throttle de reset calculado pero ignorado
- **Área:** Portal-clientes / fuerza bruta.
- **Descripción:** `requestReset()` registra el intento en `auth_throttle` pero descarta el resultado; el login sí comprueba `blocked`. Tampoco hay throttle en `resetSubmit()` ni en `invitation acceptSubmit()`.
- **Evidencia:** `portal-clientes/Services/AuthService.php:21-39,126-139`; `portal-clientes/Repositories/AuthThrottleRepository.php:49-73`; `portal-clientes/Controllers/AuthController.php:94-108`; `portal-clientes/Controllers/InvitationController.php:31-46`.
- **Impacto:** Tokens de reset ilimitados por víctima; agrava SEG-01. Posible enumeración por timing/respuesta.
- **Prioridad:** **P2** (P1 si se corrige SEG-01 sin este freno).
- **Solución propuesta:** Comprobar `blocked`, devolver mensaje genérico, usar buckets separados `reset_request`, `reset_submit`, `invitation_accept` y auditar bloqueos; añadir throttle por IP además de por correo.
- **Archivos afectados:** `portal-clientes/Services/AuthService.php`, `portal-clientes/Controllers/AuthController.php`, `portal-clientes/Controllers/InvitationController.php`.

### SEG-07 — Anti-spam y rate limiting de formularios eludibles por sesión
- **Área:** Formularios públicos / contacto y Solicitud.
- **Descripción:** El limitador guarda eventos en `$_SESSION`; honeypot y tiempo mínimo son campos enviados por el cliente, falsificables. No hay límite por IP versionado en el servidor web.
- **Evidencia:** `portal/Services/RateLimiter.php:7-12,15-39`; `portal/Services/ContactService.php:41-48,59-62`; `portal/Services/ServiceRequestService.php:47-62`; `portal/Config.php:222-230`.
- **Impacto:** Rotando cookies o enviando HTTP sin cookie se evita el límite; posible inundación de SMTP e inserción de solicitudes (dedupe de 30 días).
- **Prioridad:** **P2**.
- **Solución propuesta:** Límite por IP (hash) en aplicación o proxy, campo honeypot ofuscado y timestamp firmado por servidor en el formulario; documentar y verificar la configuración real.
- **Archivos afectados:** `portal/Services/RateLimiter.php`, `portal/Services/ContactService.php`, `portal/Services/ServiceRequestService.php`, vistas de formularios, configuración del proxy.

### SEG-08 — Enlaces de invitación “de prueba” visibles en producción
- **Área:** Portal-clientes / gobernanza de invitaciones.
- **Descripción:** El flujo de invitación sigue usando `TestNotification`: el token raw se muestra en el flash del invitador. No hay adaptador SMTP real para invitaciones.
- **Evidencia:** `portal-clientes/Controllers/MemberController.php:57-83`; `portal-clientes/Services/TestNotification.php:20-28`; `portal-clientes/translations/messages.es-AR.yaml:61`; `portal-clientes/README.md:74-78`.
- **Impacto:** El enlace queda en sesión, historial y capturas; quien acceda a esa sesión puede aceptar la invitación. Menor que SEG-01 porque requiere permiso `member.invite`.
- **Prioridad:** **P2**.
- **Solución propuesta:** Enviar por SMTP con el mismo adaptador de SEG-01; mostrar solo “invitación creada”; prohibir el modo test en producción con fail-closed.
- **Archivos afectados:** `portal-clientes/Controllers/MemberController.php`, `portal-clientes/Services/TestNotification.php`, `portal-clientes/translations/messages.{es-AR,en,pt-BR}.yaml`.

### SEG-09 — CORS comodín configurable sin validación
- **Área:** API / CORS.
- **Descripción:** Si `API_CORS_ORIGINS` contiene `*`, se emite `Access-Control-Allow-Origin: *`. El valor de ejemplo es seguro, pero el código no prohíbe el comodín.
- **Evidencia:** `api/http/Cors.php:34-41`; `.env.example:37`.
- **Impacto:** Con `*`, cualquier origen puede leer respuestas `/v1`. No hay cookies en la API, por lo que el impacto es divulgación de catálogo, no robo de sesión. Riesgo condicionado a configuración, no explotable con el ejemplo.
- **Prioridad:** **P2**.
- **Solución propuesta:** Rechazar `*` en código o exigir lista explícita y fallar cerrado en producción.
- **Archivos afectados:** `api/http/Cors.php`, `.env.example`.

### SEG-10 — CSP y HSTS ausentes en el código
- **Área:** Headers HTTP / defensa en profundidad.
- **Descripción:** No se emiten `Content-Security-Policy` ni `Strict-Transport-Security` en front controllers ni `.htaccess`. Sí existen `nosniff`, `Referrer-Policy` y `X-Frame-Options`.
- **Evidencia:** `web/index.php:13-14`; `web/.htaccess:24-28`; `web/portal-clientes/index.php:14-20`; `web/portal-clientes/.htaccess:14-19`; `api/http/Response.php:21-37`; sin coincidencias en el repo.
- **Impacto:** Si el proxy tampoco los añade (configuración no versionada), no hay mitigación de XSS inyectado ni de downgrade TLS. Riesgo defensivo, no vulnerabilidad explotable actualmente.
- **Prioridad:** **P2** (teórico hasta confirmar proxy).
- **Solución propuesta:** Versionar configuración del proxy con HSTS y CSP probadas, o emitirlas desde los front controllers con directivas validadas.
- **Archivos afectados:** `web/index.php`, `web/portal-clientes/index.php`, `web/.htaccess`, `web/portal-clientes/.htaccess`, `api/http/Response.php`, configuración del proxy.

### SEG-11 — `/admin/logout` sin validación CSRF
- **Área:** Panel administrativo / CSRF.
- **Descripción:** La ruta exige POST y pasa por `AdminGuard::requireSecure()`, pero el controlador cierra sesión sin verificar `Csrf::valid`, a diferencia del resto de POST del panel y del logout del portal de clientes.
- **Evidencia:** `portal/Router.php:213-223`; `portal/Controllers/AdminAuthController.php:65-69`; contraste `:37-39,88-90,136-139` y `portal-clientes/Controllers/AuthController.php:52-53`.
- **Impacto:** Asimetría de protección; posibilidad de forzar el cierre de sesión mediante un formulario cross-site. Impacto limitado (logout, no escalada).
- **Prioridad:** **P2**.
- **Solución propuesta:** Validar CSRF en `logout()` y añadir el token al formulario de salida en la vista del panel.
- **Archivos afectados:** `portal/Controllers/AdminAuthController.php`, `portal/Router.php`, `portal/Views/layouts/admin.php`, `tests/run.php`.

### SEG-12 — Rol interno `origen_superadmin` asignable desde invitaciones de clientes
- **Área:** Portal-clientes / RBAC.
- **Descripción:** `RoleRepository::assignable()` excluye solo `organization_owner`, por lo que el rol interno `origen_superadmin` aparece como asignable. No otorga el rol global de operador, pero sí permisos `service.*` dentro de la organización.
- **Evidencia:** `portal-clientes/Repositories/RoleRepository.php:21-31` (verificado); `portal-clientes/Controllers/MemberController.php:46-52,92-100`; `sql/10_portal_clientes/V7.001__services_entitlements.up.sql:246-266`; `portal-clientes/Services/AccessControl.php:132-155`.
- **Impacto:** Un administrador de organización podría asignar un rol interno de Origen Salud a un miembro externo, rompiendo la separación de roles.
- **Prioridad:** **P2**.
- **Solución propuesta:** Filtrar por lista explícita de roles de cliente o columna `assignable_by_customer`; bloquear `origen_superadmin` y roles de operador en `inviteSubmit()` y `roleSubmit()`; agregar prueba.
- **Archivos afectados:** `portal-clientes/Repositories/RoleRepository.php`, `portal-clientes/Controllers/MemberController.php`, `sql/10_portal_clientes/V7.001__services_entitlements.up.sql`, `tests/run.php`.

### QA-01 — La suite de pruebas es casi totalmente estática
- **Área:** Pruebas / calidad.
- **Descripción:** `tests/run.php` y los verificadores validan mayormente cadenas del código fuente (`str_contains`, `file_get_contents`), no comportamiento en ejecución. No hay tests funcionales de CSRF inválido, XSS, RBAC, reset ni autenticación API.
- **Evidencia:** `tests/run.php:21-26`; 774 `$check(`, 1270 `str_contains`, 259 `file_get_contents`; `tests/README.md:3-24`; `tools/php/verificar_etapa12_despliegue.php:114-174`.
- **Impacto:** Los 3971 checks en verde dan falsa sensación de cobertura: SEG-01 y SEG-03 pasan inadvertidos; un cambio que rompa `Csrf::valid()` en runtime no se detectaría.
- **Prioridad:** **P2**.
- **Solución propuesta:** Añadir tests funcionales con servidor embebido y base de prueba: CSRF inválido → 400, token de reset ausente en la respuesta, 429 por tasa, RBAC denegado, API key hasheada, escaping XSS. Ejecutarlos antes de publicar.
- **Archivos afectados:** `tests/run.php`, `tools/php/verificar_*.php`, `tests/README.md`, eventual CI.

### SQL-08 — Matching con Invoice Ninja basado en parámetros no validados contra la versión instalada
- **Área:** Solicitud de Servicios / integración.
- **Descripción:** `findClients()` consulta `/clients` con `tax_id`, `legal_name` y `email` y clasifica cualquier cantidad de filas como `none`, `exact` o `ambiguous`. El modelo comercial documentaba que esos campos no estaban verificados; con token real de Etapa 13 no hay evidencia en el repo de que se validaran.
- **Evidencia:** `portal/Services/InvoiceNinjaCatalogService.php:109-151`; `docs/portal-clientes/modelo-comercial-invoice-ninja.md:9-16,51-60`; `portal/Services/ServiceRequestService.php:105-111`.
- **Impacto:** Clasificaciones erróneas que afectan la marca `needs_review`. No crea datos comerciales.
- **Prioridad:** **P2**.
- **Solución propuesta:** Validar los parámetros reales de la versión instalada; si no son confiables, deshabilitar el matching automático y marcar todas las solicitudes para revisión humana con mensaje honesto. No usar correo como criterio único.
- **Archivos afectados:** `portal/Services/InvoiceNinjaCatalogService.php`, `docs/portal-clientes/auditoria-invoice-ninja.md`, `docs/portal-clientes/modelo-comercial-invoice-ninja.md`.

### API-03 — README marca `Authorization` como obligatorio cuando ambas opciones son equivalentes
- **Área:** Contrato HTTP / ejemplos.
- **Descripción:** La tabla de headers dice `Authorization` “Sí” y `X-API-Key` “Alternativo”; el código y OpenAPI los tratan como alternativas con prioridad de `X-API-Key`.
- **Evidencia:** `README-API.md:29-32`; `api/http/ApiKeyAuthenticator.php:33`; `docs/api/openapi-3.1.yaml:38-40,589-597`.
- **Impacto:** Clientes innecesariamente rígidos y falsos fallos en validación documental.
- **Prioridad:** **P2**.
- **Solución propuesta:** Redactar “una de estas dos opciones; si ambas llegan, gana `X-API-Key`”.
- **Archivos afectados:** `README-API.md`, `docs/api/openapi-3.1.yaml`, `web/docs.php`.

### API-04 — Mensajes de error 401 no idénticos
- **Área:** Errores / contrato.
- **Descripción:** README afirma mensaje idéntico para clave faltante, inactiva o inválida; el código produce tres textos distintos (aunque no distingue inexistente de inactiva).
- **Evidencia:** `README-API.md:111`; `api/http/ApiKeyAuthenticator.php:35-61`; `api/http/ApiException.php:32-64`.
- **Impacto:** Tests de contrato y clientes que comparan `error.message` pueden fallar.
- **Prioridad:** **P2**.
- **Solución propuesta:** Documentar los tres casos o unificar el mensaje y dejar la causa solo en `details`/log.
- **Archivos afectados:** `README-API.md`, `docs/api/openapi-3.1.yaml`, `tests/run.php`.

### API-05 — `OPTIONS` respondido globalmente frente a “rutas conocidas”
- **Área:** Métodos HTTP / CORS.
- **Descripción:** La spec dice que `204` se responde en rutas conocidas; el front controller responde `204` para cualquier path antes de autenticar y enrutar.
- **Evidencia:** `docs/api/openapi-3.1.yaml:16-18`; `api/index.php:185-187`; `api/http/Response.php:83-91`.
- **Impacto:** Un preflight a ruta inexistente no revela `404`; desvío para generadores y gateways.
- **Prioridad:** **P2**.
- **Solución propuesta:** Corregir la redacción a “cualquier ruta” o mover el manejo después del match. Mantener `Allow: GET, OPTIONS` solo en `405`.
- **Archivos afectados:** `docs/api/openapi-3.1.yaml`, `api/index.php`, `web/docs.php`, `portal/translations/messages.{es-AR,en,pt-BR}.yaml`.

### API-06 — `q` documentado como 2–80 en todas las rutas pero validado solo en búsqueda
- **Área:** Parámetros / validación.
- **Descripción:** El parámetro `q` se reutiliza en catálogos, nomenclador, vademécum, LOINC, PMO, odontología y conceptos; solo `/v1/search` valida longitud y UTF-8.
- **Evidencia:** `docs/api/openapi-3.1.yaml:600-604` y refs en `:188,262,285,319,351,383,397,467,510`; `api/services/TerminologySearchService.php:3051-3084`; `api/services/CatalogEngineService.php:102`; `api/services/TerminologySearchService.php:831`.
- **Impacto:** Clientes generados pueden rechazar `q=K02` en catálogos; el servidor acepta términos no validados en esas rutas.
- **Prioridad:** **P2**.
- **Solución propuesta:** Dividir en `SearchQ` (2–80) y `FreeTextQ`, o aplicar `normalizeTerm()` de forma consistente; ajustar descripciones y ejemplos.
- **Archivos afectados:** `docs/api/openapi-3.1.yaml`, `api/services/TerminologySearchService.php`, `api/services/CatalogEngineService.php`, `README-API.md`, `web/docs.php`.

### API-07 — Detalle de ítem: la spec anuncia `200 data: []` y el código devuelve `404`
- **Área:** Status codes / esquema JSON.
- **Descripción:** La descripción de `/v1/catalogs/{catalog_code}/items/{item}` afirma que catálogo o ítem inexistente devuelve `200` con `data: []`; la implementación lanza `404` y la operación no declara esa respuesta.
- **Evidencia:** `docs/api/openapi-3.1.yaml:204-219`; `api/services/CatalogEngineService.php:194-196,269-271`; `api/http/ApiException.php:42-45`.
- **Impacto:** Manejo de error incorrecto en clientes generados; divergencia clara de contrato.
- **Prioridad:** **P2**.
- **Solución propuesta:** Conservar `404` (coherente con el resto), quitar la frase `data: []` y agregar respuesta `404` con `ErrorEnvelope` en la spec.
- **Archivos afectados:** `docs/api/openapi-3.1.yaml`, `README-API.md`, `tests/run.php`.

### API-08 — Paginación parcial o no documentada en tres rutas
- **Área:** Paginación / rendimiento.
- **Descripción:** `/v1/mappings` tiene `LIMIT 50` fijo; `/v1/odontologia/diagnosticos` declara `limit` pero no pagina; `/v1/catalogs/*/items` declara `offset≤5000` pero solo aplica `max(0, …)` y recorta `limit` silenciosamente.
- **Evidencia:** `docs/api/openapi-3.1.yaml:199,512`; `api/services/CatalogEngineService.php:104-105,588,627`; `api/services/TerminologySearchService.php:827-858,915-959`.
- **Impacto:** Truncamiento silencioso, respuestas grandes y parámetros ignorados.
- **Prioridad:** **P2**.
- **Solución propuesta:** Elegir convención: documentar topes e quitar `limit` donde no se usa, o implementar `limit/offset/has_more/next_offset`. Alinear `offset≤5000` con el código.
- **Archivos afectados:** `docs/api/openapi-3.1.yaml`, `api/services/CatalogEngineService.php`, `api/services/TerminologySearchService.php`, `README-API.md`.

### API-09 — `Domain.label/description` anuncia tres idiomas pero devuelve dos
- **Área:** i18n de `/v1/domains`.
- **Descripción:** La spec dice que las claves son `es-AR`, `en` y `pt-BR`; el catálogo estático solo contiene `es` y `en`.
- **Evidencia:** `docs/api/openapi-3.1.yaml:770-781`; `api/services/TerminologySearchService.php:106-223,394-406`; `README-API.md:136-137` (sí correcto).
- **Impacto:** Clientes que pidan `label['pt-BR']` obtienen `undefined`.
- **Prioridad:** **P2**.
- **Solución propuesta:** Corregir la descripción a `es/en`; si se quiere `pt-BR`, cargarlo antes de documentarlo.
- **Archivos afectados:** `docs/api/openapi-3.1.yaml`, `api/services/TerminologySearchService.php`, `README-API.md`.

### API-10 — `oftar` implementado pero ausente del enum y del ejemplo principal
- **Área:** Dominios / descubrimiento.
- **Descripción:** `oftar` está en `DOMAINS`, en el catálogo de dominios, en SQL y es aceptado por `normalizeDomains()`, pero falta en el enum `DomainPath` de OpenAPI y en el ejemplo del README.
- **Evidencia:** `api/services/TerminologySearchService.php:47,63,215-223,371-376,2832-2857`; `docs/api/openapi-3.1.yaml:612-618`; `README-API.md:174`; `portal/translations/messages.es-AR.yaml:281`.
- **Impacto:** `/v1/search/oftar` no es descubrible por clientes generados desde la spec; tres fuentes documentales divergen.
- **Prioridad:** **P2**.
- **Solución propuesta:** Agregar `oftar` al enum y al README; mantener una sola lista canónica derivada de `DOMAINS`.
- **Archivos afectados:** `docs/api/openapi-3.1.yaml`, `README-API.md`, `api/services/TerminologySearchService.php`, traducciones.

### API-11 — Claim de “coincidencia fonética” sin implementación
- **Área:** Búsqueda aproximada / documentación.
- **Descripción:** README atribuye trigramas, coincidencia fonética y ponderación semántica. Trigramas y similitud existen; no hay `soundex`, `metaphone`, `levenshtein` ni equivalente en el código de la API.
- **Evidencia:** `README-API.md:293`; `api/services/TerminologySearchService.php:492-505,2275,2312-2327`; `api/config/database.php:163-175`; índices GIN en `sql/01_schema/design.sql:33,70-71,107,159-160` y `sql/05_loinc/importar_loinc.sql:33,265-269`.
- **Impacto:** Expectativa funcional falsa; soporte puede prometer búsqueda por pronunciación inexistente.
- **Prioridad:** **P2**.
- **Solución propuesta:** Reemplazar por “trigramas (`pg_trgm`), coincidencia exacta/prefijo/contención y scoring por similitud”; la fonética, si se desea, requiere propuesta aparte.
- **Archivos afectados:** `README-API.md`, `portal/translations/messages.en.yaml:66`, `docs/api/openapi-3.1.yaml`, `web/docs.php`.

### API-12 — Ejemplo JSON del hero de home no reproducible
- **Área:** Ejemplos públicos / hero.
- **Descripción:** El hero publica `meta.field_languages.term` con `provenance='snomed_rf2'` y `approval_state='approved'`; la proyección real genera `field_languages.items` con esos valores en `null`. También faltan `language`, `domains`, `page_counts`, `next_offset`, `cie10_type` y `refsets`.
- **Evidencia:** `portal/Controllers/HomeController.php:22-65`; `api/Controllers/ConceptController.php:50-79`; `api/index.php:99-114`; `api/services/TerminologySearchService.php:544-559`; `portal/Views/home.php:198-201`.
- **Impacto:** El ejemplo más visible del sitio no coincide con la API; puede copiarse en integraciones.
- **Prioridad:** **P2**.
- **Solución propuesta:** Generar el ejemplo desde un fixture canónico compartido con la spec y `tests/run.php`; usar `field_languages.items` o quitar el bloque; incluir el `meta` completo.
- **Archivos afectados:** `portal/Controllers/HomeController.php`, `portal/Views/home.php`, `portal/translations/messages.{es-AR,en,pt-BR}.yaml`, `docs/api/openapi-3.1.yaml`, `tests/run.php`.

### API-13 — Quickstart de `web/docs.php` con `meta` incompleto e inexacto
- **Área:** Documentación web / ejemplos publicados.
- **Descripción:** El ejemplo de `/v1/catalogs/dentar-pr/items` omite nueve claves de `meta` y muestra `effective_language: "es"` y `fallback_applied: true`, cuando el servicio no informa `language` y el wrapper calcula `null`/`false` para esa ruta.
- **Evidencia:** `web/docs.php:213-350,410-435`; `api/services/CatalogEngineService.php:163-170`; `api/index.php:79-115`; `api/services/LanguageResolver.php:71-96`.
- **Impacto:** Los desarrolladores infieren un contrato idiomático distinto; los snippets en seis lenguajes son válidos en header/URL, pero la respuesta esperada no.
- **Prioridad:** **P2**.
- **Solución propuesta:** Sustituir el JSON ilustrativo por una respuesta capturada del verificador canónico y marcar los campos generados por el wrapper común.
- **Archivos afectados:** `web/docs.php`, `docs/api/openapi-3.1.yaml`, `portal/translations/messages.{es-AR,en,pt-BR}.yaml`, `tests/run.php`.

### API-14 — Traducciones se contradicen sobre el estado de OpenAPI
- **Área:** Documentación trilingüe / gobernanza.
- **Descripción:** En los tres idiomas, `alignment_text` dice que la spec aún tiene desvíos pendientes, mientras `divergences_text` y `div_*` dicen que ya se corrigieron en Fase 2. La spec actual confirma la segunda versión.
- **Evidencia:** `portal/translations/messages.{es-AR,en,pt-BR}.yaml:390,398-406`; `docs/api/openapi-3.1.yaml:14-17,603,622,759-769`; `README-API.md:10-15`.
- **Impacto:** No hay fuente de verdad clara para usuarios de Docs; parece que la reconciliación no se hizo.
- **Prioridad:** **P2**.
- **Solución propuesta:** Eliminar `alignment_text` o convertirlo en historial (“desvíos corregidos en Fase 2”); dejar una sola sección vigente con fecha/versión de spec.
- **Archivos afectados:** `portal/translations/messages.{es-AR,en,pt-BR}.yaml`.

### API-15 — Documentación afirma que CORS permite `med.origen.ar` por defecto
- **Área:** CORS / configuración.
- **Descripción:** Las traducciones dicen que por defecto se permite `https://med.origen.ar`. El código no emite headers si `API_CORS_ORIGINS` está vacío; el valor aparece solo en `.env.example`.
- **Evidencia:** `api/http/Cors.php:8-13,25-32,40-45`; `.env.example:37`; `portal/translations/messages.{es-AR,en,pt-BR}.yaml:251`.
- **Impacto:** Expectativa incorrecta en integraciones browser; el modo real es sin headers CORS hasta configurar.
- **Prioridad:** **P2**.
- **Solución propuesta:** Redactar “CORS se habilita solo si `API_CORS_ORIGINS` no está vacío; el ejemplo incluye `https://med.origen.ar`; sin configuración, same-origin only”.
- **Archivos afectados:** `portal/translations/messages.{es-AR,en,pt-BR}.yaml`, `.env.example`, `docs/api/openapi-3.1.yaml`, `web/docs.php`.

### API-16 — Mensajes de error de API no localizados
- **Área:** i18n de respuestas de error.
- **Descripción:** Contenido y `meta` son idiomáticos, pero `error.message` está hardcodeado en español y no consulta `lang` ni `Accept-Language`. `error.code` sí es estable.
- **Evidencia:** `api/http/ApiKeyAuthenticator.php:35-61`; `api/http/ApiException.php:32-63`; `api/index.php:642-668`; `portal/translations/messages.es-AR.yaml:40`.
- **Impacto:** Clientes en inglés/portugués reciben mensajes en español; complicación para soporte.
- **Prioridad:** **P2**.
- **Solución propuesta:** Mantener `error.code` como contrato y documentar “mensajes en español”, o localizar `error.message` desde el catálogo sin tocar códigos ni status.
- **Archivos afectados:** `api/http/ApiException.php`, `api/http/ApiKeyAuthenticator.php`, `api/index.php`, `docs/api/openapi-3.1.yaml`, traducciones.

### I18-03 — Dos esquemas de URL canónicas incompatibles (`/{locale}/…` vs `?lang=`)
- **Área:** SEO / i18n / arquitectura de URLs.
- **Descripción:** El portal usa prefijo de idioma; Docs y UVR usan query `lang`. El sitemap publica `/{locale}/docs`, pero el router redirige a `/docs?lang=…`, cuyo canonical es la URL con query. Docs/UVR no emiten `x-default` y UVR no está en el sitemap.
- **Evidencia:** `web/docs.php:33,37-47,489-491`; `web/uvr.php:33,37-48,198-201`; `portal/i18n/I18n.php:140-169`; `portal/Views/layouts/main.php:15-17`; `web/sitemap.php:22,36-53`; `portal/Router.php:90-91,609-615`; `tests/run.php:1517,1519,1623,1626` fija el esquema actual.
- **Impacto:** Señales canónicas competidoras, URLs del sitemap que terminan en 302, ausencia de `x-default` en standalone y UVR no descubierto. Los tests actuales lo declaran “esperado”: cualquier cambio debe actualizar router, vistas, sitemap y tests en conjunto.
- **Prioridad:** **P2**.
- **Solución propuesta:** Elegir un esquema: (a) mantener `?lang=`, publicar esas URLs en el sitemap, agregar `x-default` y quitar `/{locale}/docs`; o (b) migrar a `/{locale}/docs` y `/{locale}/uvr`. Decisión única, no parcial.
- **Archivos afectados:** `web/docs.php`, `web/uvr.php`, `web/sitemap.php`, `portal/Router.php`, `portal/Views/partials/nav-links.php`, `tests/run.php`.

### I18-04 — `Vary` incompleto en `/search`
- **Área:** Caché / negociación de idioma.
- **Descripción:** `/search` resuelve el idioma desde URL, query, cookie y cabecera, pero solo emite `Vary: Accept-Language`; Docs, UVR y el front controller incluyen también `Cookie`.
- **Evidencia:** `web/search.php:20-24`; `portal/i18n/I18n.php:72-88,172-214`; `web/docs.php:20`; `web/uvr.php:21`; `web/index.php:14`.
- **Impacto:** Proxies o CDNs pueden servir resultados en el idioma equivocado cuando la diferencia está en la cookie.
- **Prioridad:** **P2**.
- **Solución propuesta:** Alinear con el resto: `Vary: Accept-Language, Cookie` y verificar que el selector de idioma use la misma estrategia.
- **Archivos afectados:** `web/search.php`.

### I18-05 — Formato numérico monetario fijo en es-AR para todos los idiomas
- **Área:** Formatos de fecha y moneda.
- **Descripción:** Los importes usan `number_format(..., 2, ',', '.')` en vistas públicas, vistas de administración y correos, sin conmutación por locale.
- **Evidencia:** `portal/Views/service-request.php:126,200`; `portal/Views/partials/browse/detail.php:9,123`; `portal/Views/partials/browse/detail/uvr.php:6,66`; `portal/Views/admin/uvr/*.php`; `portal/Services/ServiceRequestService.php:261,267`; contraste en textos localizados `messages.en.yaml:1317` (`$1,000`) y `messages.pt-BR.yaml:1317` (`$1.000`).
- **Impacto:** Inconsistencia visible en tablas de precios, totales estimados y correos en `en`/`pt-BR`. Los tokens `ARS`/`USD` se mantienen correctamente sin traducir.
- **Prioridad:** **P2**.
- **Solución propuesta:** Centralizar formateador por locale (`Intl NumberFormatter` o mapa explícito: es-AR/pt-BR `1.234,56`, en `1,234.56`) y usarlo en vistas y correo.
- **Archivos afectados:** los archivos de evidencia y los catálogos de traducción si se agregan claves.

### UX-03 — `activeNav` / `aria-current` implementado pero no cableado en la mayoría de las páginas
- **Área:** UX / accesibilidad de navegación.
- **Descripción:** El partial de navegación soporta sección activa, pero ningún controlador público la pasa; solo Docs y UVR lo configuran.
- **Evidencia:** `portal/Views/partials/nav-links.php:8-11,36-40`; `web/docs.php:593`; `web/uvr.php:292`; sin `activeNav` en `portal/Controllers/`; `portal/View.php:14-24` sin valor por defecto.
- **Impacto:** El menú no marca la sección actual en home, dentar, oftar, browse, about, contact ni solicitud; se pierde orientación visual y semántica.
- **Prioridad:** **P2**.
- **Solución propuesta:** Pasar `activeNav` desde cada controlador o derivarlo de `$currentPath` en `View::render()` con valor por defecto.
- **Archivos afectados:** `portal/View.php` y los controladores públicos listados.

### UX-04 — Metadatos de la página 404 fijos en español
- **Área:** SEO / i18n / errores.
- **Descripción:** `Router::notFound()` fija título y descripción en español para cualquier idioma, mientras `og:locale` usa el locale activo.
- **Evidencia:** `portal/Router.php:624-638`; `portal/Views/errors/404.php:10-12`; `portal/Views/layouts/main.php:13-14,24`.
- **Impacto:** Un 404 en `/en/…` o `/pt-BR/…` tiene metadata española con `og:locale` inglés/portugués.
- **Prioridad:** **P2**.
- **Solución propuesta:** Crear claves `errors.404.title/description` en los tres catálogos y pasarlas desde el router con el locale correspondiente.
- **Archivos afectados:** `portal/Router.php`, `portal/Views/errors/404.php`, catálogos de traducción.

### UX-05 — Orden fijo y tope de offset de 5000 sin aviso en Browse
- **Área:** Sitio público / resultados.
- **Descripción:** El orden es fijo (`score DESC, length(term) ASC, term ASC`) y el servicio topa el offset en 5000; la interfaz no ofrece orden ni comunica el límite.
- **Evidencia:** `portal/Repositories/CatalogRepository.php:615-617`; `portal/Services/BrowseService.php:44`; `portal/Views/browse.php:184-240`; `portal/Views/partials/browse/results.php:70-109`.
- **Impacto:** El usuario no puede ordenar por código, vigencia o fecha; al superar 5000 resultados la paginación deja de avanzar sin explicación.
- **Prioridad:** **P2**.
- **Solución propuesta:** Parámetro `sort` con whitelist, `has_more`/`limit_reached` en la respuesta y mensaje localizado; evaluar keyset pagination para colecciones grandes.
- **Archivos afectados:** `portal/Repositories/CatalogRepository.php`, `portal/Services/BrowseService.php`, `portal/Controllers/BrowseController.php`, vistas browse/results, traducciones, `tests/run.php`.

### UX-06 — Coincidencias `exact`/`partial` no distinguen equivalencia de aproximación textual
- **Área:** Sitio público / semántica de resultados.
- **Descripción:** `match_type` es `exact` solo con score ≥ 1.0, todo lo demás es `partial`. Esa etiqueta agrupa substring, prefijo, normalización, sinónimo y relación clínica.
- **Evidencia:** `portal/Repositories/CatalogRepository.php:1643-1651`; `portal/Views/partials/browse/results.php:83-91`; `portal/translations/messages.es-AR.yaml:777-778`.
- **Impacto:** El usuario no puede saber si el resultado es el mismo concepto, un término relacionado o una aproximación textual; riesgo de interpretar equivalencias no declaradas.
- **Prioridad:** **P2**.
- **Solución propuesta:** Ampliar la taxonomía (`exact`, `code`, `prefix`, `token`, `synonym`, `related`, `text`) en modelo, i18n y filtro; documentar diferencia entre coincidencia textual y equivalencia clínica. No inventar equivalencias.
- **Archivos afectados:** `portal/Repositories/CatalogRepository.php`, `portal/Views/partials/browse/results.php`, catálogos de traducción.

### UX-07 — Feature flag de `/solicitud` oculta los enlaces pero no la ruta
- **Área:** Configuración / descubrimiento.
- **Descripción:** Sin `PORTAL_SERVICE_REQUEST_LINK_ENABLED`, nav, home y footer ocultan la Solicitud de Servicios, pero la ruta sigue pública. En producción el flag está activo, según Etapa 13.
- **Evidencia:** `portal/Config.php:64-71`; `portal/Views/partials/nav-links.php:23-29`; `portal/Views/home.php:35-36`; `docs/portal-clientes/informe-ejecucion-etapa-13.md:65-77`.
- **Impacto:** Comportamiento ambiguo para usuarios, QA y sitemap si el entorno se recrea sin la variable; dependencia de configuración no versionada.
- **Prioridad:** **P2**.
- **Solución propuesta:** Decidir si es flag temporal o configuración permanente: documentar valor por entorno, o publicar enlaces siempre, o deshabilitar también la ruta con el mismo flag.
- **Archivos afectados:** `portal/Config.php`, `portal/Router.php`, `portal/Views/partials/nav-links.php`, `portal/Views/home.php`, `portal/Views/partials/footer.php`, `web/sitemap.php`.

### SEO-03 — `robots.txt` no versionado
- **Área:** Indexación / áreas privadas.
- **Descripción:** No hay `robots.txt` en el repositorio; producción sirve un contenido genérico. Las áreas privadas sí llevan `noindex` en sus layouts.
- **Evidencia:** sin archivo `web/robots.txt`; comprobación HTTP en vivo → 200 con contenido genérico; `portal-clientes/Views/layouts/customer.php:66`; `portal/Views/layouts/admin.php:75`; `web/sitemap.php:21-22`.
- **Impacto:** Directivas no reproducibles desde el repo; mayor superficie de rastreo/enumeración de URLs privadas.
- **Prioridad:** **P2**.
- **Solución propuesta:** Añadir `web/robots.txt` controlado por Git con `User-agent: *`, `Allow: /` y `Sitemap: https://med.origen.ar/sitemap.xml`; solo agregar `Disallow` para rutas confirmadas como privadas.
- **Archivos afectados:** nuevo `web/robots.txt`, `web/.htaccess`, `tests/run.php`.

### SEO-04 — Alternativas `hreflang` de `/search` apuntan a rutas inexistentes
- **Área:** SEO / i18n / buscador heredado.
- **Descripción:** `web/search.php` emite alternates con `/search`, que generan `/{locale}/search`; esa ruta no existe en el router. Ya estaba documentado como pendiente.
- **Evidencia:** `web/search.php:99-100`; `README.md:673-675`; `portal/Router.php:82-177` (sin `search`).
- **Impacto:** `hreflang` inválidos y URLs alternativas que devuelven 404.
- **Prioridad:** **P2**.
- **Solución propuesta:** Registrar la ruta localizada en el router, o generar alternates válidos hacia la ruta canónica existente, o marcar `/search` como `noindex` y quitar alternates.
- **Archivos afectados:** `web/search.php`, `portal/Router.php`, `README.md`, `tests/run.php`.

### DOC-02 — README principal desactualizado en arquitectura, recuentos y rutas
- **Área:** Documentación / onboarding.
- **Descripción:** El README describe solo dos frentes, omite el portal privado de clientes, cifra el SQL en 44 archivos/9 directorios (real: 140/12), cita un directorio inexistente (`05_loinc.sql/`), marca DENTAR como “no ejecutado” pese a los datos cargados y usa `php8.2-fpm.sock` frente al PHP 8.5.4 real del VPS.
- **Evidencia:** `README.md:3-8,44-56,65,159-161,721,743`; `web/portal-clientes/index.php:1-29`; `portal-clientes/Router.php:25-65`; 140 `.sql` en 12 directorios; versiones del VPS informadas por el responsable (PHP 8.5.4, PostgreSQL 18.6).
- **Impacto:** Onboarding, despliegue y auditoría incompletos; copiar el bloque Nginx del README puede fallar por ruta de socket inexistente; riesgo de repetir cargas SQL.
- **Prioridad:** **P2**.
- **Solución propuesta:** Actualizar frentes, árbol, recuentos, estado de carga por catálogo y ruta del socket a `php8.5-fpm.sock`; separar claramente “artefacto no ejecutado” de “base ya cargada”.
- **Archivos afectados:** `README.md`, `docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md:79,84`, `sql/01_schema/README.md`.

### DOC-03 — `portal-clientes/README.md` se contradice sobre producción
- **Área:** Documentación / estado de despliegue.
- **Descripción:** El resumen inicial dice “No desplegado en producción”, pero la sección final describe Etapa 12 publicada, Etapa 13 ejecutada, base operativa, enlaces activos y token real.
- **Evidencia:** `portal-clientes/README.md:3` frente a `:291-299`; `docs/portal-clientes/informe-ejecucion-etapa-13.md:92-99`.
- **Impacto:** El resumen induce a error sobre el estado real del portal privado.
- **Prioridad:** **P2**.
- **Solución propuesta:** Corregir el encabezado para reflejar “desplegado en producción (Etapa 13)” y conservar las excepciones autorizadas.
- **Archivos afectados:** `portal-clientes/README.md`.

### DOC-04 — Variables requeridas por código ausentes en `.env.example`
- **Área:** Configuración / reproducibilidad.
- **Descripción:** No aparecen `PORTAL_CUSTOMER_SESSION_TTL`, `PORTAL_CUSTOMER_LOGIN_LIMIT`, `PORTAL_CUSTOMER_RESET_TTL`, `PORTAL_CUSTOMER_IN_MODE`, `PORTAL_CUSTOMER_IN_TOKEN`, `PORTAL_CUSTOMER_API_TEST_EXPECT`, `PORTAL_CUSTOMER_IN_BASE_URL`, `WEB_API_KEY`, `WEB_API_TOKEN`, `OS_IMPORT_MODE`, `SMTP_ALLOW_INSECURE`; `PORTAL_CUSTOMER_API_TEST_KEY` está solo comentada.
- **Evidencia:** `portal-clientes/Config.php:50-70,82-109`; `web/includes/ApiClient.php:10-12`; `portal-clientes/README.md:50-72`; `.env.example:152-169`.
- **Impacto:** Un `.env` creado desde el ejemplo queda incompleto para sesión, login, modo Invoice Ninja y buscador público; el código falla en modo degradado o 503 sin que la configuración esperada sea reproducible.
- **Prioridad:** **P2**.
- **Solución propuesta:** Documentar todas las variables con valores de ejemplo no sensibles, indicando cuáles son obligatorias en producción y cuáles solo de prueba. No publicar secretos.
- **Archivos afectados:** `.env.example`, `portal-clientes/README.md`.

### DOC-05 — Documentos de propuesta e inventarios históricos sin marca de “superados”
- **Área:** Documentación / gobernanza.
- **Descripción:** Varios documentos siguen diciendo “No implementado”, “No autorizado” o “SIN EJECUTAR EN VPS” aunque el código y las Etapas 12-13 están desplegados. Incluye el runbook de staging y `inventario_audit.md`.
- **Evidencia:** `docs/portal-clientes/arquitectura-portal-clientes.md:3`; `plan-implementacion-portal-clientes.md:3`; `registro-de-decisiones-arquitectonicas.md:4`; `docs/architecture/ejecucion-staging-runbook.md:3,306-319`; `inventario_audit.md:5-14,41-43,59`; `docs/architecture/fase1-admin-identidad.md:3-4`.
- **Impacto:** Riesgo de tratar propuestas superadas como estado actual y bloquear decisiones ya tomadas; obliga a leer la documentación por fecha en vez de por nombre.
- **Prioridad:** **P2**.
- **Solución propuesta:** Añadir banda visible “Histórico — superado por Etapas N” con fecha y enlace al informe de ejecución vigente; no reescribir el contenido histórico.
- **Archivos afectados:** los documentos citados.

### DOC-06 — Registro de la Etapa 13 no cubre el commit actual ni la versión real de PHP
- **Área:** Documentación / trazabilidad de despliegue.
- **Descripción:** El informe de Etapa 13 registra el commit `552903b`, pero `HEAD` local y `origin/main` son `61d5073` (rediseño de `/solicitud`). Además el README usa `php8.2-fpm.sock` mientras el servidor informó PHP 8.5.4 y los planes usan `php8.5-fpm`.
- **Evidencia:** `docs/portal-clientes/informe-ejecucion-etapa-13.md:13,74`; git log local (`61d5073`); `README.md:721,743`; versiones del VPS informadas por el responsable.
- **Impacto:** La reproducción exacta del despliegue documentado corresponde a dos commits anteriores; no hay acta que cubra el rediseño publicado. El bloque Nginx del README apuntaría a un socket inexistente.
- **Prioridad:** **P2**.
- **Solución propuesta:** Anexar al informe (sin reescribirlo) el cambio de HEAD, los tres archivos publicados y la confirmación de PHP 8.5.4; actualizar el socket en el README.
- **Archivos afectados:** `docs/portal-clientes/informe-ejecucion-etapa-13.md`, `README.md`, `portal/Views/service-request.php`, `web/assets/css/public.css`, `tests/run.php`.

### DOC-07 — Contadores del verificador canónico desactualizados
- **Área:** Documentación / pruebas.
- **Descripción:** Los README mencionan `OK: 3924` y `OK: 3932`; la ejecución real de la Etapa 1 dio `OK: 3971`. `tests/README.md` no describe la cobertura actual del portal de clientes.
- **Evidencia:** `portal-clientes/README.md:280,289`; `tests/README.md:9-22`; `tests/run.php` (más de 4300 líneas); ejecución local en Etapa 1.
- **Impacto:** Subestimación de la cobertura y desalineación entre documentación y suite.
- **Prioridad:** **P2**.
- **Solución propuesta:** Reemplazar los números fijos por “verificar con `php tests/run.php`” y actualizar `tests/README.md` con los dominios cubiertos.
- **Archivos afectados:** `portal-clientes/README.md`, `tests/README.md`.

---

# P3 — Bajos

### SEG-13 — Token de reset del panel administrativo transportado en query string y flash
- **Área:** Panel administrativo / higiene de tokens.
- **Descripción:** El token de reset se recibe por GET y se reinyecta en la URL y en el flash cuando falla el CSRF. El envío por correo sí es real.
- **Evidencia:** `portal/Controllers/AdminAuthController.php:109-123,136-141`; `portal/Views/admin/reset.php`; `portal/Admin/AuthService.php:387-391`.
- **Impacto:** El token puede quedar en logs de acceso, historial del navegador y `Referer` same-origin. No hay evidencia de envío a terceros (`Referrer-Policy` presente).
- **Prioridad:** **P3**.
- **Solución propuesta:** Enviar el token en campo oculto mediante POST; cabecera `Referrer-Policy: no-referrer` en `/admin/reset`; no reinyectarlo en flash.
- **Archivos afectados:** `portal/Controllers/AdminAuthController.php`, `portal/Views/admin/reset.php`.

### SQL-09 — `verify_rollback` sin guarda de base
- **Área:** SQL / verificaciones.
- **Descripción:** Los scripts `verify_rollback` de V5 y V6 son solo `SELECT`, pero no incluyen la guarda `current_database()` que sí tienen V7, V7.002, V8 y V10.
- **Evidencia:** `sql/10_portal_clientes/V5.001__os_customer_identity.verify_rollback.sql:1-31`; `V6.001__invoice_ninja_links.verify_rollback.sql:1-27`; contraste `V7.001__services_entitlements.verify_rollback.sql:6-13` y `V10.001__public_service_requests.verify_rollback.sql:6-13`.
- **Impacto:** Riesgo operativo bajo: si se ejecutan contra otra base devuelven información engañosa en lugar de fallar. No modifican datos.
- **Prioridad:** **P3**.
- **Solución propuesta:** Agregar la misma guarda de base usada por los `up`/`down` de cada versión.
- **Archivos afectados:** los dos scripts de evidencia.

### COM-03 — Catálogo de la Solicitud truncado silenciosamente a 100 productos
- **Área:** Solicitud de Servicios / catálogo.
- **Descripción:** El catálogo pide `per_page` con tope de 100 y no sigue páginas. Si Invoice Ninja publica más productos, la vista muestra solo el primer bloque sin aviso.
- **Evidencia:** `portal/Config.php:104-113`; `portal/Services/InvoiceNinjaCatalogService.php:59-67`.
- **Impacto:** Servicios disponibles pueden no aparecer y un ID de otra página se rechaza como selección inválida.
- **Prioridad:** **P3**.
- **Solución propuesta:** Implementar paginación o mostrar aviso explícito del límite; resolver el total de páginas desde la respuesta de Invoice Ninja si está disponible.
- **Archivos afectados:** `portal/Config.php`, `portal/Services/InvoiceNinjaCatalogService.php`, `portal/Views/service-request.php`.

### I18-06 — Catálogo `messages.es.yaml` legacy, divergente y con textos FHIR obsoletos
- **Área:** Catálogos / artefactos históricos.
- **Descripción:** No es cargado por `I18n`, pero difiere del catálogo base (999 claves, 809 ausentes, 94 exclusivas) y afirma soporte FHIR R4 que el contrato vigente desmiente. Herramientas históricas aún lo inspeccionan.
- **Evidencia:** `portal/i18n/I18n.php:25,230-235`; `portal/translations/messages.es.yaml:132-137,191-198`; `portal/translations/messages.es-AR.yaml:378`; `tests/run.php:1611-1613`; `tools/php/verificar_fase10.php:114-129`.
- **Impacto:** No afecta runtime, pero puede inducir a editar el archivo equivocado o reintroducir documentación obsoleta.
- **Prioridad:** **P3**.
- **Solución propuesta:** Conservarlo como histórico con marca explícita, moverlo a `legacy/` o quitarlo del mapa de catálogos de herramientas; nunca copiar sus claves sin revisión.
- **Archivos afectados:** `portal/translations/messages.es.yaml`, `tools/php/verificar_fase10.php`.

### I18-07 — Texto hardcodeado menor en el login del panel
- **Área:** Textos en vistas.
- **Descripción:** El placeholder del correo en `/admin/login` está fijo en español y se muestra igual en los tres idiomas. Es el único texto visible no técnico sin `$t`; el resto son marcas o identificadores correctamente no traducidos.
- **Evidencia:** `portal/Views/admin/login.php:52`; `portal/Views/contact.php:55-57` (honeypot oculto, no defecto).
- **Impacto:** Fuga mínima de español en el panel administrativo en `en`/`pt-BR`.
- **Prioridad:** **P3**.
- **Solución propuesta:** Reemplazar por una clave de catálogo o un ejemplo neutral `name@example.com`. No traducir DENTAR, OFTAR, UVR ni códigos.
- **Archivos afectados:** `portal/Views/admin/login.php`, catálogos si se agrega la clave.

### COM-04 — Doble escritura de selección en `ServiceRequestService`
- **Área:** Solicitud de Servicios / calidad de código.
- **Descripción:** `addToSelection()` ejecuta dos veces seguidas la misma escritura en sesión.
- **Evidencia:** `portal/Services/ServiceRequestService.php:192-194`.
- **Impacto:** No cambia el resultado funcional; puede confundir futuras modificaciones de persistencia.
- **Prioridad:** **P3**.
- **Solución propuesta:** Eliminar una de las dos líneas, dejando una sola escritura tras validar límites.
- **Archivos afectados:** `portal/Services/ServiceRequestService.php`.

### API-17 — `refsets.maxLength` no describe la validación real
- **Área:** Parámetros / contrato.
- **Descripción:** La spec declara `maxLength: 200`; el código no mide longitud, sino que admite hasta 10 códigos `[A-Z0-9_]{2,24}` y exige `snomed` entre los dominios.
- **Evidencia:** `docs/api/openapi-3.1.yaml:633-636`; `api/services/TerminologySearchService.php:80,2889-2931`.
- **Impacto:** Desvío menor; clientes generados pueden rechazar entradas que el servidor aceptaría.
- **Prioridad:** **P3**.
- **Solución propuesta:** Reemplazar `maxLength` por la descripción real de reglas.
- **Archivos afectados:** `docs/api/openapi-3.1.yaml`, `README-API.md`.

### API-18 — `os_customer.service` es catálogo informativo, no control de acceso
- **Área:** Capacidades por cliente / portal-clientes.
- **Descripción:** El catálogo de servicios cubre un subconjunto de rutas; la API no consulta `os_customer`, entitlements ni `organization_id`. Cualquier API key válida alcanza todas las rutas `/v1/*`.
- **Evidencia:** `sql/10_portal_clientes/V7.001__services_entitlements.up.sql:269-327`; `V7.002__dentar_oftar_services.up.sql:24-47`; `portal-clientes/Views/api.php:43-49`; `api/http/ApiKeyAuthenticator.php:47-68`; sin referencias a `os_customer` en `api/`.
- **Impacto:** La UI puede sugerir permisos por servicio que el backend no aplica; el catálogo queda desincronizado frente a ~30 paths.
- **Prioridad:** **P3**.
- **Solución propuesta:** Etiquetar la vista como “servicios informativos / entitlements declarativos” y sincronizar el catálogo con la spec. El enforcement real, si se decide, requiere una evolución separada con scopes en la clave.
- **Archivos afectados:** `sql/10_portal_clientes/V7.001__services_entitlements.up.sql`, `V7.002__dentar_oftar_services.up.sql`, `portal-clientes/Views/api.php`, documentación de portal-clientes.

### API-19 — Verificación de despliegue debe forzar `APP_DEBUG=false`
- **Área:** Logging / exposición de errores.
- **Descripción:** El log registra `request_id`, método, path, excepción y mensaje, sin términos de búsqueda ni datos clínicos. Con `APP_DEBUG=true` agrega stack trace, aunque la respuesta al cliente sigue genérica.
- **Evidencia:** `api/index.php:14-15,659-668,691-717`; `api/http/Response.php:54-80`; `.env.example`.
- **Impacto:** Riesgo operativo bajo si el flag se activa en producción; exposición al cliente controlada.
- **Prioridad:** **P3**.
- **Solución propuesta:** Verificación de despliegue que fuerce `APP_DEBUG=false` y compruebe que body y headers no incluyen stack, SQL ni secretos.
- **Archivos afectados:** `api/index.php`, `.env.example`, `tools/php/verificar_etapa13_produccion.php`, guías de operación.

### DOC-08 — Cierre de Etapa 13 con datos de registro pendientes y runbook no ensayado
- **Área:** Despliegue / backup / rollback.
- **Descripción:** El informe de Etapa 13 deja hashes y datos de registro pendientes, y el procedimiento de rollback en producción está documentado pero no ensayado.
- **Evidencia:** `docs/portal-clientes/informe-ejecucion-etapa-13.md:27,96-99`; `docs/portal-clientes/plan-backup-rollback-etapa4.md:3-4,95`; contraste positivo en `:20-32,65-77` del informe y `manifiesto-etapa-13-produccion.md:6-77`.
- **Impacto:** En un incidente real la recuperación dependería de decisiones ad hoc; un dump no puede verificarse por hash.
- **Prioridad:** **P3**.
- **Solución propuesta:** Completar los hashes y los datos de registro, ensayar un restore en base aislada y publicar un runbook de incidentes con responsables y criterios de rollback. Sin ejecutar nada contra producción sin autorización.
- **Archivos afectados:** `docs/portal-clientes/informe-ejecucion-etapa-13.md`, `docs/portal-clientes/plan-backup-rollback-etapa4.md`, nuevo runbook.

---

## Controles verificados como correctos (no hallazgos)

Para evitar correcciones innecesarias, se registran explícitamente los controles que funcionan:

- **CSRF:** tokens `random_bytes(32)` + `hash_equals`, por sesión y con rotación, en `portal/Services/Csrf.php` y `portal-clientes/Services/CustomerCsrf.php`; presentes en los POST revisados (salvo SEG-11).
- **XSS:** escapado consistente con `e()` / `htmlspecialchars(ENT_QUOTES|ENT_SUBSTITUTE)`; las salidas directas son booleanos, IDs o constantes.
- **SQLi:** prepared statements en repositorios y servicios; interpolaciones dinámicas restringidas por whitelist de catálogos/columnas fijas.
- **RBAC:** decisión en backend (`AdminGuard`, `Rbac`, `AccessControl`), con prevención de auto-aprobación y techo de permisos (salvo SEG-12).
- **Sesiones:** `HttpOnly`, `SameSite=Lax`, cookies separadas por frente; logout correcto en portal-clientes (salvo SEG-04).
- **Secretos:** `.gitignore` excluye `.env`, `.env.*`, `/var/` y `*.log`; `.htaccess` niega acceso a `.env*`, `composer.*`, `bootstrap.php`, `sql/` y `vendor/`; no se encontraron secretos versionados.
- **Errores:** `APP_DEBUG=false`, `display_errors=0` y respuestas API genéricas con `request_id` y `WWW-Authenticate` en `401`.
- **Esquema y auditoría:** `audit_log` append-only en `os_customer` y `os_admin`; grants por objeto; sin `ALTER DEFAULT PRIVILEGES`; `origen_med` con `NOSUPERUSER` cluster-wide ya aplicado (no reejecutar `V10.002`).
- **Solicitud de Servicios — núcleo correcto:** el navegador envía solo IDs y cantidades; importes se recalculan en servidor; no se guardan precios en PostgreSQL; Invoice Ninja se consulta solo por `GET`; no se crean clientes, facturas ni pagos; CSRF, dedupe y escalado a `needs_review` presentes; flags fail-closed y `PORTAL_CUSTOMER_BILLING_URL` validado como `https://` sin derivar de `Host`.
- **Reglas editoriales en SQL:** solo DENTAR PR/DX publicados; AN/CL reservados; OFTAR-PR con UVR y OFTAR-DX sin UVR; componentes UVR correctos en el modelo; sin equivalencias inventadas.
- **i18n:** paridad total de claves (1714/1714/1714 en `portal`, 208/208/208 en `portal-clientes`), sin valores vacíos ni placeholders divergentes; `hreflang`/`og:locale` y metadatos localizados correctos en las vistas principales.
- **API:** envelope `data/meta/request_id`, `/health` plano y documentado, 30 rutas correspondidas, `204`/`405`/`404`/`500`/`503` según contrato, búsqueda con `pg_trgm` + GIN + similitud, y snippets con `X-API-Key` válido.
- **Build y accesibilidad base:** Tailwind v4 integrado sin CDN, skip link, soporte de `aria-current` y estados `role="status"`/`role="alert"` en formularios.

## Criterio de cierre de la Etapa 1

El diagnóstico está completo. No se corrigió ningún hallazgo. LaEtapa 2 requiere aprobación explícita del responsable, con decisión particular sobre:
1. SEG-01 y SEG-02/03 (cambios de autenticación y credenciales).
2. SQL-01/02/03 (textos y guardas de migraciones; **ninguna ejecución de SQL**).
3. DOC-01 e I18-03 (alcance idiomático y esquema de URLs).
4. LEG-01 (creación de páginas legales, fuera del alcance técnico).
5. API-03 a API-16 (contrato: conviene corregir documentación contra el código, no rehacer la API).

