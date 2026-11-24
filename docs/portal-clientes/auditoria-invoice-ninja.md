# Auditoría de sistemas externos: Invoice Ninja y FreeScout

> **Estado:** auditoría pública de solo lectura; incompleta por falta de credenciales autorizadas. No se autenticó, no se consultó API con token, no se crearon clientes, contactos, presupuestos, facturas ni pagos.
> **Fecha:** 2026-11-24.
>
> Cubre `https://gestion.uriarte.ar` (Invoice Ninja) y `https://soporte.uriarte.ar` (FreeScout). Separa lo observado de lo que aún debe verificarse en la etapa 1 con acceso autorizado.

## 1. Convenciones de estado

- **Estado actual comprobado:** respuesta HTTP pública observada.
- **No verificado:** requiere credenciales o inspección autorizada.
- **Propuesta:** se remite a `modelo-comercial-invoice-ninja.md`.
- **Decisión pendiente:** versión, API, permisos y flujo comercial.
- **Riesgo:** diseñar contra una versión distinta de la instalada.
- **Dependencia:** acceso de solo lectura autorizado por el propietario.
- **Requisito de autorización:** consultar API real o crear cualquier dato comercial.

## 2. Observación pública realizada

Se realizó una consulta HTTP `GET` de solo lectura a `https://gestion.uriarte.ar`.

Resultado comprobado:

- El documento responde con `<title>Invoice Ninja</title>`.
- Es una aplicación SPA con `<div id="root"></div>` y bundles JavaScript.
- El HTML incluye referencias a módulos como `clients`, `ClientCreate`, `invoices`, `payments`, `company-users`, `settings` y `LanguageSelector`.
- Incluye Cloudflare Insights y `lang="en"` en el HTML.
- No se obtuvo versión numérica de la instalación.
- No se observó configuración de API, tokens, webhooks ni Client Portal.

**Conclusión:** la instalación existe y está publicada, pero su versión y capacidades reales no son verificables desde la respuesta pública.

### 2.1 Evidencia complementaria del repositorio `[REPO]`

- `.env.example:55-59` declara `INVOICE_NINJA_BASE_URL=https://gestion.uriarte.ar`, `INVOICE_NINJA_API_TOKEN` y `INVOICE_NINJA_TIMEOUT=8`. El comentario dice «Invoice Ninja v5», pero la versión real **no** queda comprobada.
- `portal/Config.php:44-52` define `invoiceNinja()` con el mismo default. No se encontraron llamadores ni un `InvoiceNinjaService` implementado.
- `portal/Services/HttpClient.php` es un wrapper cURL genérico; su consumo comprobado corresponde a OpenWA, no a Invoice Ninja.
- Existen `RATE_CART` y `rateLimits()` en `.env.example:88` y `portal/Config.php:96-105`, pero no hay consumidor de `cart`.
- No existe ruta `/cart`, controlador de carrito ni lógica de checkout `[REPO portal/Router.php:81-152; web/sitemap.php:8-11]`.
- FreeScout y `soporte.uriarte.ar` no aparecen en archivos versionados; solo en esta documentación propuesta.

**Conclusión local:** la integración con Invoice Ninja hoy es configuración declarada, no funcionalidad implementada.

## 3. Elementos verificables en el HTML público

| Elemento | Observación |
|---|---|
| Marca | Invoice Ninja |
| Interfaz | SPA React/JavaScript |
| Área de clientes | No verificable desde el HTML inicial |
| Idioma del HTML | `en` |
| Versión instalada | No expuesta |
| API pública | No expuesta |
| Webhooks | No expuestos |
| Client Portal | No expuesto |
| Autenticación | No verificable sin credenciales |

## 4. Aspectos pendientes de verificación obligatoria

La etapa 1 debe verificar, con acceso autorizado:

### 4.1 Versión y configuración

- Versión exacta instalada.
- Modo: self-hosted o cloud.
- Configuración de API habilitada o no.
- Entorno: producción/pruebas.
- Política de HTTPS y dominios.

### 4.2 API

- Endpoint base real.
- Tipo de token y cabecera exacta.
- Permisos del token: lectura/escritura por entidad.
- Endpoints disponibles para clientes, contactos, productos, precios, presupuestos, facturas y pagos.
- Campos y filtros reales de la versión instalada.
- Códigos de error, paginación y límites.
- Idempotencia para creación.

### 4.3 Clientes y contactos

- Estructura real de cliente.
- Identificador fiscal y normalización disponible.
- Estados: activo, archivado, inactivo.
- Relación con contactos.
- Capacidad de que varias personas de una organización accedan al portal nativo.

### 4.4 Comercial

- Productos y servicios comercializables.
- Lista de precios vigente.
- Moneda e impuestos.
- Presupuestos: creación, envío y estados.
- Facturas y pagos: consulta de estados.
- Política de vencimientos.

### 4.5 Portal nativo de clientes

- URL oficial de acceso.
- Cómo se habilita para un cliente/contacto.
- Si requiere invitación, contraseña propia o enlace firmado.
- Cómo se vincula con la identidad comercial de Invoice Ninja.
- Qué se puede hacer desde el portal del cliente.

### 4.6 Webhooks

- Disponibilidad en la versión instalada.
- Eventos de clientes, presupuestos, facturas y pagos.
- Mecanismo de firma o validación.
- Reintentos y deduplicación.
- Registro de entregas.

### 4.7 FreeScout — `https://soporte.uriarte.ar`

Se realizó una consulta HTTP `GET` de solo lectura. Resultado comprobado `[HTTP]`:

- Responde con una pantalla de inicio de sesión de FreeScout.
- El formulario pide **Dirección de correo** y **Contraseña**, con opción **Recordarme** y botón **Iniciar sesión**.
- No se autenticó ni se consultaron tickets.
- No se obtuvo versión instalada, configuración de API, dominios de correo, departamentos ni flujos de formulario.
- No hay configuración ni integración de FreeScout en el repositorio versionado `[REPO]`.

Pendiente de verificación con acceso autorizado:

- Versión real y modo de despliegue.
- Disponibilidad de API y token con permisos mínimos.
- Departamentos, campos de ticket y estados.
- Cómo crear tickets desde el portal de clientes sin duplicar identidad.
- Cómo mostrar el enlace de soporte al usuario de cada organización.
- Política de datos personales y retención.

**Regla propuesta:** FreeScout puede ser destino de soporte, pero no debe otorgar acceso a servicios, credenciales ni datos financieros.

## 5. Restricciones derivadas

- No asumir que endpoints de documentación reciente existen en esta instalación.
- No construir URLs internas con tokens propios.
- No incrustar Invoice Ninja en iframe.
- No duplicar facturas, pagos ni presupuestos en Origen Salud.
- No enviar API token al navegador.
- No crear datos reales durante auditoría ni pruebas.
- No modificar la instalación.
- No autenticarse en FreeScout ni crear tickets de prueba sin autorización.
- No usar FreeScout como sistema de autorización del portal de clientes.

## 6. Riesgos

| Riesgo | Consecuencia |
|---|---|
| Versión distinta a la documentación pública | Integración con campos inexistentes. |
| Token con permisos amplios | Modificación accidental de datos financieros. |
| Client Portal no habilitado | La opción «Facturación y pagos» no funcione. |
| Webhooks sin firma | Procesar eventos falsos. |
| Duplicados comerciales | Facturación incorrecta o confusión contractual. |
| Sin idempotencia | Creación repetida ante reintentos. |
| FreeScout sin configurar | Enlace de soporte roto o tickets sin trazabilidad de organización. |

## 7. Decisiones pendientes

1. ¿Se autoriza crear un token de solo lectura para auditoría?
2. ¿Se autoriza crear datos de prueba en un entorno no productivo?
3. ¿Qué persona o rol aprueba la creación de clientes y presupuestos?
4. ¿Qué condición comercial habilita técnicamente un servicio?
5. ¿Se usarán webhooks o conciliación periódica?
6. ¿Cómo accederá cada contacto al Client Portal?
7. ¿Se autoriza una API de FreeScout o solo un enlace público?
8. ¿Qué política de retención y datos personales aplica al soporte?

## 8. Conclusión

La existencia de Invoice Ninja y FreeScout está comprobada públicamente. Su idoneidad para la integración **no** está comprobada. Antes de diseñar los adaptadores definitivos, la etapa 1 debe ejecutar una auditoría autenticada y de solo lectura sobre las versiones reales instaladas.
