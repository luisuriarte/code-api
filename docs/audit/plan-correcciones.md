# Auditoría integral — Plan de correcciones

- **Fecha:** 2026-11-26
- **Etapa:** 1 — Diagnóstico completado; plan propuesto para aprobación en la Etapa 2
- **Hallazgos:** 71 (2 P0, 20 P1, 39 P2, 10 P3) — detalle en `problemas-detectados.md`
- **Estado actual:** `estado-actual.md`
- **Entregable final:** `informe-final.md` (Etapa 5)

---

## 1. Principios que rigen el plan

1. **Consolidar, no reconstruir.** La arquitectura de tres frentes (API, portal público, portal-clientes) se conserva. La mayoría de los desvíos de API se resuelven corrigiendo documentación contra el comportamiento ya implementado.
2. **Sin cambio de identidad visual.** Se mantienen colores institucionales, logotipo, tipografía y componentes Tailwind existentes. El rediseño ya publicado de `/solicitud` se respeta.
3. **Contratos estables.** No se cambian URLs públicas, nombres de catálogos, envelopes `data/meta/request_id`, códigos de error ni reglas editoriales. La corrección de `404` en `API-07` se hace en la spec, no en el código.
4. **Sin secretos en el repo.** Token real de Invoice Ninja solo en `.env` del servidor; `.env.example` sin valores sensibles.
5. **Sin SQL en producción sin acta.** Cualquier migración, `DROP ROLE` o `ALTER ROLE` requiere autorización explícita y verificación previa. **`V10.002` no se reejecutará**; `origen_codes` se considera intacto.
6. **Sin deploy automático.** El responsable ejecuta commit, push, carga de archivos y cualquier acción en el VPS. El asistente solo prepara cambios y verificaciones locales.
7. **Cambios pequeños y verificables.** Cada oleada termina con `php tests/run.php` y revisión de `git diff`; se agrega una comprobación nueva por corrección relevante.
8. **Datos reales.** No se crean clientes, facturas, pagos ni datos ficticios en producción; no se habilitan servicios automáticamente por factura; se conserva Contacto para consultas generales.

---

## 2. Secuencia de etapas

| Etapa | Acción | Puerta de salida |
|---|---|---|
| 1 — Diagnóstico | **Completada.** Solo lectura; tres documentos generados. | Aceptación del diagnóstico por el responsable. |
| 2 — Aprobación | Elegir oleadas, decidir los puntos abiertos de la §4 y autorizar el alcance. | Acta de aprobación con IDs de hallazgos incluidos/excluidos. |
| 3 — Implementación | Correcciones por áreas, en oleadas, sin tocar producción. | Diff revisado y pruebas en verde por oleada. |
| 4 — Validación | Ejecución local de verificadores y comprobación de no regresión visual/contrato. | Resultados registrados con número de checks. |
| 5 — Informe final | `docs/audit/informe-final.md` con estado, encontrados/corregidos/pendientes, pruebas, riesgos y evaluación de lanzamiento. | Cierre formal de la auditoría. |

---

## 3. Oleadas de corrección

### Oleada 0 — Bloqueantes (P0)
**Requiere aprobación urgente y explícita.** Son los únicos hallazgos que degradan hoy la seguridad o la función principal del sitio.

| ID | Cambio | Archivos principales | Validación |
|---|---|---|---|
| SEG-01 | Sacar el token de reset del flash; envío SMTP real; mensaje genérico; sin token en logs/sesión | `AuthService.php`, `AuthController.php`, `TestNotification.php`, layout `customer.php`, traducciones | Prueba funcional: el HTML de `/forgot` no contiene `/reset/` ni hex de 64 caracteres; existe prueba de regresión |
| UX-01 | Mutua exclusión de `domain`/`catalog` en el selector; regla única compartida; mensaje específico | `browse.php`, `browse-explorer.js`, `BrowseService.php`, traducciones | Prueba UI→controlador→servicio con combinaciones válidas e inválidas |

**No incluido:** cambiar el diseño del explorador ni del formulario de solicitud.

### Oleada 1 — Autenticación, sesiones y credenciales

| ID | Cambio | Riesgo | Requiere decisión |
|---|---|---|---|
| SEG-02 | Hash de API keys con pepper + doble lectura transitoria | Contrato de credenciales / migración | **Sí** (§4.1) |
| SEG-03 | Limitador por `api_client.id` con `429`/`Retry-After` | Comportamiento observable de la API | **Sí** (§4.2) |
| SEG-04 | `session_regenerate_id(true)` en login de clientes | Bajo | No |
| SEG-05 | Guardia HTTPS en portal-clientes y criterio de proxy de confianza | Medio (puede afectar accesos) | **Sí** (§4.3) |
| SEG-06 | Aplicar `blocked` a reset e invitación | Bajo | No |
| SEG-07 | Límite por IP + timestamp firmado en formularios | Medio | **Sí** (§4.4) |
| SEG-08 | SMTP para invitaciones; modo test prohibido en producción | Medio | **Sí** (misma decisión que SEG-01) |
| SEG-09 | Rechazar `*` en `API_CORS_ORIGINS` | Bajo | No |
| SEG-10 | CSP/HSTS: primero confirmar qué emite el proxy; solo luego decidir dónde ponerlos | Medio | **Sí** (§4.5) |
| SEG-11 | CSRF en `/admin/logout` | Bajo | No |
| SEG-12 | Lista explícita de roles asignables al cliente | Medio | No |
| SEG-13 | Token de reset del admin por POST; sin reinyección en flash | Bajo | No |

**Orden sugerido:** SEG-04, SEG-06, SEG-09, SEG-11, SEG-12, SEG-13 → SEG-05 → SEG-07/08/10 → SEG-02/03 (evoluciones con contrato).

### Oleada 2 — SQL y gobernanza de migraciones (**solo texto y guardas**)

| ID | Cambio | Ejecución en VPS |
|---|---|---|
| SQL-01 | Dos rutas documentales: prueba y producción Etapa 13; prohibición de `V10.002` | **Ninguna** |
| SQL-02 | Whitelist estricta de base en `DEV_ONLY__reset_os_customer.sql`; mover fuera de migraciones desplegables | **Ninguna** |
| SQL-03 | Guardas exactas; sacar `DROP ROLE`/`ALTER ROLE` de `down` versionados o exigir confirmación cluster-wide | **Ninguna** |
| SQL-04 | Unificar estado de Fase 1 / `os_admin` | **Ninguna** |
| SQL-05 | Una sola regla documentada para el DSN de credenciales | **Ninguna** |
| SQL-09 | Guarda de base en los dos `verify_rollback` | **Ninguna** |

**Regla absoluta:** esta oleada no ejecuta migraciones, rollback ni `psql` contra ninguna base. Solo edita archivos y comprueba con `tests/run.php` y lectura de_diff.

### Oleada 3 — Solicitud de Servicios y flujo comercial

| ID | Cambio | Requiere decisión |
|---|---|---|
| COM-01 | Mostrar moneda real, periodicidad, impuestos y cargo único/recurrente **solo si Invoice Ninja los devuelve** | **Sí** (§4.6) |
| COM-02 | Propagar fallo SMTP; `notification_status`; correo de confirmación al solicitante | **Sí** (§4.7) |
| COM-03 | Paginación o aviso de límite de 100 productos | No |
| COM-04 | Eliminar doble `Session::set()` | No |
| SQL-08 | Validar parámetros de `/clients` contra la versión instalada o marcar todo para revisión humana | **Sí** (§4.8) |

**Restricciones:** el navegador sigue enviando solo IDs y cantidades; importes calculados en servidor; precios nunca en PostgreSQL; sin creación de clientes/facturas/pagos; sin “cart” en rutas, código, SQL ni textos nuevos; denominación “Solicitud de Servicios” intacta.

### Oleada 4 — API y documentación técnica (consolidación, sin reconstrucción)

| Grupo | IDs | Cambio |
|---|---|---|
| Contrato de auth | API-01, API-03, API-04, API-05 | Rotular `X-Api-Token` como externo; headers equivalentes; mensajes `401`; `OPTIONS` global |
| Parámetros y status | API-06, API-07, API-08, API-17 | `q` por ruta; `404` documentado; paginación coherente; `refsets` real |
| Descubrimiento e i18n | API-09, API-10, API-11, API-16 | `es/en`, `oftar` en el enum, sin “fonética”, errores documentados como es-AR |
| Ejemplos | API-12, API-13, API-14, API-15 | Fixture canónico para hero y quickstarts; una sola verdad sobre OpenAPI y CORS |
| Gobernanza | API-02, API-18, API-19 | Estado real del self-service; servicios informativos; `APP_DEBUG=false` |

**Regla:** cuando código y documentación divergen, se prefiere el código como fuente y se corrige la documentación. Solo `API-07` cambia la spec (no el código) y `API-08` puede requerir código si se decide implementar paginación (decisión §4.9). La API no se rehace.

### Oleada 5 — Sitio público, i18n, SEO, legal y documentación

| Grupo | IDs | Cambio |
|---|---|---|
| i18n de contenido | I18-01, I18-02, I18-05, I18-06, I18-07 | 25 claves `docs.*`; textos DENTAR/UVR reales; formateador por locale; catálogo legacy marcado; placeholder neutral |
| UX / accesibilidad | UX-02, UX-03, UX-04, UX-05, UX-06, UX-07 | Errores `fetch` con `role="alert"` y reintento; `activeNav`; 404 localizado; orden/`has_more`; semántica de coincidencias; flag documentado |
| SEO | SEO-01, SEO-02, SEO-03, SEO-04, I18-03, I18-04 | `x-default` en HTML; sitemap completo y despliegue verificado; `robots.txt` versionado; alternates de `/search`; esquema único de URLs; `Vary` completo |
| Legal | LEG-01 | Páginas `/terminos` y `/privacidad` localizadas (decisión §4.10) |
| Documentación y estado | DOC-01 a DOC-08, QA-01 | Alcance idiomático; READMEs; `.env.example`; marcas de “superado”; HEAD/PHP del informe de Etapa 13; contadores; tests funcionales |

---

## 4. Decisiones pendientes del responsable (Etapa 2)

1. **SEG-02 — API keys:** ¿migrar a hash con pepper y rotación, o mantener texto plano con documentación explícita del riesgo? Si se migra, la rotación de credenciales existentes debe ser autorizada por separado.
2. **SEG-03 — Rate limit:** ¿implementar limitador real con `429`, o declarar la columna como informativa y quitarla del contrato visible?
3. **SEG-05 — HTTPS:** ¿exigir HTTPS en todo el portal de clientes con guardia dura, o solo cookies `Secure` forzadas? Requiere confirmar cómo el proxy gestiona `X-Forwarded-Proto`.
4. **SEG-07/08/10 — Anti-spam y headers:** ¿hay configuración del proxy versionable? ¿Se puede enviar correo real para invitaciones? ¿Dónde deben emitirse HSTS/CSP?
5. **SQL-05 — DSN de credenciales:** ¿mover las escrituras a `origen_codes_portal_clientes` o mantener y documentar la excepción sobre `public.api_clients` en `origen_codes`?
6. **COM-01 — Precios:** qué campos devuelve realmente la versión instalada de Invoice Ninja para moneda, periodicidad e impuestos. No se inventarán valores.
7. **COM-02 — Notificaciones:** ¿confirmación al solicitante por correo, estado persistido con reintento, o ambos? ¿Alinear el texto visible con el estado real?
8. **SQL-08 — Matching:** ¿validar parámetros reales o deshabilitar el matching automático y marcar todo para revisión humana?
9. **API-08 — Paginación:** ¿documentar topes actuales o implementar `limit/offset/has_more` en las tres rutas?
10. **DOC-01 / I18-03 — Alcance:** ¿producto trilingüe confirmado y esquema de URLs único? Elegir entre `/{locale}/docs` y `/docs?lang=`; afecta router, vistas, sitemap y tests.
11. **LEG-01 — Legal:** ¿crear páginas legales reales o mantener correo con textos diferenciados? Requiere decidir contenido y fecha de vigencia.
12. **API-18 — Entitlements:** ¿catálogo informativo etiquetado como tal o enforcement real con scopes? El enforcement es una evolución separada.

---

## 5. Verificación y criterios de aceptación

### 5.1 Local (ejecutado por el asistente, sin acceso a producción)

```
php tests/run.php
git status --short
git diff --stat
```

- Resultado esperado: `OK: N comprobaciones.` con N ≥ 3971, sin comprobaciones eliminadas para ocultar fallos.
- Toda corrección funcional incorpora al menos una comprobación nueva o un test funcional (QA-01).
- Las correcciones documentales se validan buscando claves y cadenas obsoletas y con el verificador canónico.

### 5.2 En el VPS (ejecutado por el responsable, solo si autoriza)

- Carga de archivos por WinSCP; recarga de `php-fpm` solo si `opcache.validate_timestamps=0`.
- Comprobaciones de solo lectura: estados HTTP de `/`, `/solicitud` (3 idiomas), `/docs`, `/sitemap.xml`, `/robots.txt`; verificación de encabezados y de que `/forgot` no expone tokens.
- **No ejecutar** migraciones, `DROP ROLE`, `ALTER ROLE`, `V10.002`, ni llamadas de escritura a Invoice Ninja sin acta nueva.

### 5.3 Criterios por oleada

| Oleada | Criterio de aceptación |
|---|---|
| 0 | Ningún token de reset en respuesta; explorador sin combinaciones inválidas ofrecidas; tests en verde |
| 1 | Sin regresión de login/logout; 401/403/429 coherentes; sesiones regeneradas; CORS sin comodín |
| 2 | Diff solo de texto/guardas; ninguna ejecución SQL; `git diff` revisado |
| 3 | Importes calculados en servidor; moneda real o texto neutral; sin precios en PostgreSQL; sin creación comercial automática |
| 4 | OpenAPI, README, Docs y ejemplos coinciden con el código; sin cambios rompientes |
| 5 | Paridad i18n mantenida; canonical/hreflang/sitemap consistentes; textos DENTAR/OFTAR/UVR verdaderos |

---

## 6. Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| Cambiar documentación histórica y perder trazabilidad | Añadir marcas de “superado” en vez de reescribir; conservar actas y fechas |
| Corregir la spec y romper clientes generados | Preferir el comportamiento real; changelog explícito; sin cambios de estado HTTP salvo `404` documentado |
|Introducir HSTS/CSP sin conocer el proxy | Confirmar primero la configuración real; aplicar en el punto que corresponda y probar en staging |
| Migrar credenciales y dejar clientes sin acceso | Doble lectura transitoria, rotación autorizada y rollback documentado; nunca en la misma oleada que otros cambios |
| Tocar `os_customer` por error | Ninguna ejecución SQL en la auditoría; guardas estrictas; preflight antes de cualquier acción futura |
| Falsar datos comerciales | Mostrar solo lo que Invoice Ninja devuelve; texto neutral si falta información |

---

## 7. Exclusiones explícitas

Quedan **fuera** de este plan, salvo autorización nueva:

- Reestructurar la API, cambiar rutas públicas o envelopes.
- Cambiar colores, logotipo, tipografía o identidad visual.
- Introducir “cart”/“carrito” en rutas, código, SQL o textos.
- Guardar precios en PostgreSQL o generar facturas, pagos y clientes automáticamente.
- SSO, vinculación automática por correo, duplicación de productos/precios/facturas/pagos, habilitación automática por factura.
- `ALTER DEFAULT PRIVILEGES`, reejecutar `V10.002`, modificar credenciales de producción sin acta.
- Crear funcionalidades nuevas por iniciativa propia (por ejemplo enforcement de entitlements o búsqueda fonética).
- Publicar DENTAR AN/CL ni inventar equivalencias, compatibilidades o valores UVR.

---

## 8. Entregable de cierre

Al terminar la Etapa 5, `docs/audit/informe-final.md` debe contener:

1. Estado final de la auditoría y versiones de entrega.
2. Tabla de hallazgos: encontrados (71), corregidos, pendientes, con ID y prioridad.
3. Pruebas ejecutadas: comandos, fecha y resultados (`OK: N comprobaciones`).
4. Cambios aplicados por archivo y verificación de no regresión.
5. Riesgos residuales, decisiones no autorizadas y recomendaciones.
6. Evaluación de lanzamiento: "listo / listo con condiciones / no listo", con justificación.
7. Confirmación de que no se ejecutaron SQL, deploy, commit ni push desde el asistente.
