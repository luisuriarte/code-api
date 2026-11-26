# Acta de autorización — Etapa 10: Solicitud de Servicios

> **Fecha:** 2026-11-26.
> **Autorizada por:** responsable del proyecto.
> **Alcance:** implementación local y preparación para prueba aislada. No incluye despliegue ni operaciones comerciales reales.

## 1. Nombre y denominaciones

El flujo se llama **Solicitud de Servicios**. No se usa «cart» ni «carrito» en rutas, clases, tablas, variables de entorno, textos ni documentación nueva. La ruta pública es `/{locale}/solicitud`, con las acciones `agregar`, `quitar` y `enviar`. La interfaz habla de «selección de servicios» y «enviar solicitud».

La ruta histórica rota `/cart` permanece retirada: no se reincorpora ni al enrutador, ni a la navegación, ni al sitemap.

## 2. Decisiones autorizadas

| Decisión | Elección |
| --- | --- |
| Registro de la solicitud | Tabla en la base aislada `origen_codes_portal_clientes_test`, con migración `V10.001`. |
| Catálogo y precios | Consulta a Invoice Ninja desde backend con **token de prueba**. Nunca token real. |
| Navegación pública | **Sin** enlaces en nav, footer ni home. Solo rutas y vistas para revisión. |
| Cuentas y accesos | No se crean cuentas técnicas, credenciales ni habilitaciones. |
| Operaciones comerciales | No se crean clientes, contactos, presupuestos, facturas ni pagos. |
| Rol de conexión pública | Autorizado `ALTER ROLE origen_med NOSUPERUSER` mediante `V10.002`. Es un cambio cluster-wide que también afecta a `origen_codes`; se ejecuta únicamente desde la base de prueba verificada. |

## 3. Migración autorizada

`V10.001__public_service_requests` crea dos tablas en `os_customer`:

- `public_service_request`: solicitud, datos mínimos de organización y contacto, estado y referencia.
- `public_service_request_item`: referencias opacas de productos y cantidades.

No hay columnas de precio, importe, total, moneda, factura ni pago. `origen_med` recibe `USAGE` en el esquema y `SELECT, INSERT` únicamente en esas dos tablas, más `USAGE` en sus secuencias. No recibe `UPDATE`, `DELETE` ni acceso a otras tablas. No se usa `ALTER DEFAULT PRIVILEGES`.

La migración lleva guarda de base de prueba, `down`, verificación `SELECT`-only y verificación de rollback. Producción queda intacta en cuanto a esquema y datos.

Durante la Etapa 11 se comprobó que `PORTAL_DB_DSN` apunta a `origen_codes` (producción), mientras que las tablas de la solicitud están en `origen_codes_portal_clientes_test`. Para no modificar el DSN público ni crear tablas en producción, la Solicitud de Servicios usa un DSN dedicado `SERVICE_REQUEST_DB_DSN`. El repositorio no emplea `PortalDatabase`. Si la variable no está configurada en el servidor, el flujo se deshabilita con un mensaje localizado en vez de producir un error 500.

La primera verificación en el VPS mostró que `origen_med` tenía `rolsuper = t`. Los ACL de las tablas nuevas eran correctos (`origen_med=ar`), pero un superusuario tiene implícitamente todos los privilegios, por lo que `sin_update`, `sin_delete`, `sin_insert_en_servicios` y `sin_insert_en_habilitaciones` dieron `f`. Se autorizó expresamente la corrección `V10.002__origen_med_no_superuser` para que los permisos por objeto sean efectivos. El cambio de atributo de rol es cluster-wide: afecta también a `origen_codes`, aunque el script se ejecute con `-d origen_codes_portal_clientes_test`. Tras aplicarlo deben repetirse las comprobaciones públicas de solo lectura.

## 4. Integración con Invoice Ninja

El acceso es de **solo lectura** (`GET`). El token se lee de `INVOICE_NINJA_API_TOKEN` y debe ser de prueba. Las llamadas requieren además `INVOICE_NINJA_ALLOW_TEST_CALLS=true` y `https`. Sin esas condiciones el catálogo aparece como no disponible, con un mensaje honesto en la vista.

El navegador envía solo identificadores de producto y cantidades. El servidor recupera los precios vigentes, valida los identificadores y recalcula el total. Los importes se muestran en la respuesta HTML y en el correo de notificación, pero **no se guardan** en PostgreSQL ni se escriben en el código.

La búsqueda de coincidencias con clientes se usa únicamente para marcar la solicitud como `needs_review`. Ante coincidencia ambigua o indisponibilidad del servicio, se escala a revisión humana; nunca se crea un cliente.

## 5. Defensas

- CSRF en todos los formularios (`agregar`, `quitar`, `enviar`) con rotación posterior al envío.
- Honeypot `website` y tiempo mínimo de llenado.
- `RATE_REQUEST` (5 por defecto) con ventana `RATE_WINDOW`, reutilizando `RateLimiter`.
- Validación estricta de identificadores y cantidades en servidor.
- Detección de duplicados por identificador fiscal normalizado o por organización + correo, dentro de una ventana de 30 días.
- Auditoría: la solicitud queda registrada en la tabla y se notifica por correo a `CONTACT_EMAIL`, con `CONTACT_BCC` opcional y `Reply-To` del solicitante.
- Sin secretos en HTML, JavaScript, URL, cookies ni logs.

## 6. Idiomas

Tres idiomas con paridad de claves: `es-AR`, `en` y `pt-BR`. No hay textos hardcodeados en la vista ni en los mensajes de correo.

## 7. Verificación local

Antes de entregar: `php -l` sin errores, `php tests/run.php` sin fallas, paridad de claves i18n y comprobación de que no aparecen «cart», «carrito», importes fijos ni llamadas de escritura a Invoice Ninja. En el VPS, después de `V10.001`, ejecutar `V10.002` y confirmar `sin_superuser = t` junto con los cuatro privilegios negativos en `t`.

Quedan fuera de esta autorización la publicación en la navegación, las pruebas de despliegue (Etapa 11), el despliegue (Etapa 12), la creación real de clientes o facturas y cualquier habilitación automática.
