# Acta de autorización — Etapa 6: Integración con Invoice Ninja

> **Estado:** ETAPA 6 AUTORIZADA para entorno de prueba. **Producción intacta.**
> **Fecha:** 2026-11-24.
> **Autorizado por:** responsable del proyecto.
> **Relación:** complementa `acta-autorizacion-etapa-5.md`.

## 1. Autorización recibida

> Autorizo la **Etapa 6 — Integración con Invoice Ninja** del portal `/portal-clientes`, únicamente en entorno de prueba/base independiente, conforme a `modelo-comercial-invoice-ninja.md` y `plan-implementacion-portal-clientes.md`.
>
> Se habilita la implementación del servicio backend `InvoiceNinjaService`, su adaptador de prueba, la configuración mediante variables de entorno con placeholders, el token exclusivamente en servidor, HTTPS, timeouts, reintentos controlados e idempotencia.
>
> Se habilita la creación, solo en la base de prueba, de las tablas de vinculación y revisión necesarias para asociar organizaciones del portal con identificadores de Invoice Ninja, mediante migración versionada, `down`, verificación `SELECT`-only y rollback ensayado. Solo se guardarán identificadores y metadatos técnicos: no se duplicarán productos, precios, presupuestos, facturas ni pagos.
>
> Se habilita la detección de duplicados por vínculo existente, identificador fiscal normalizado, razón social y contactos/correos institucionales. Ante coincidencia dudosa se exige revisión administrativa; no se crearán clientes automáticamente.
>
> No autorizo llamadas a Invoice Ninja con credenciales reales. La URL `https://gestion.uriarte.ar` queda designada expresamente como instancia de prueba para esta etapa, pero el token debe ser de prueba. No autorizo crear clientes, contactos, presupuestos, facturas ni pagos reales, ni configurar el Client Portal, ni habilitar servicios por factura emitida.
>
> No autorizo cambios en producción, credenciales reales, servicios/habilitaciones, credenciales API de Origen Salud, facturación propia, pagos, iframe de Invoice Ninja, SSO, asociación automática por correo, modificación de `/admin`, catálogos, API pública, Nginx, PHP-FPM, FreeScout ni sitio público.
>
> Tampoco autorizo commit, push ni deploy. Requiero backup verificado antes de aplicar migraciones y confirmación de la verificación `SELECT`-only y del rollback antes de avanzar a la Etapa 7.

## 2. Aclaración sobre instancia y token

- **URL designada para prueba:** `https://gestion.uriarte.ar`.
- **Token:** exclusivamente de prueba. Queda **prohibido** usar el token real de Invoice Ninja.
- El valor del token no debe pegarse en actas, documentos, logs, comandos ni repositorio.
- Si no se configura un token de prueba, el adaptador queda en modo `mock` y no realiza llamadas HTTP.

## 3. Alcance habilitado

1. Implementar `InvoiceNinjaService` y su adaptador de prueba.
2. Configurar base URL, token, timeout y rutas mediante variables de entorno con placeholders.
3. Mantener el token solo en servidor, con HTTPS, timeouts, reintentos controlados e idempotencia.
4. Crear en la base de prueba las tablas de vinculación y revisión, con migración `up`, `down`, verificación `SELECT`-only y rollback ensayado.
5. Guardar solo identificadores y metadatos técnicos: sin productos, precios, presupuestos, facturas ni pagos duplicados.
6. Detectar duplicados por vínculo existente, identificador fiscal normalizado, razón social y contactos/correos institucionales.
7. Exigir revisión administrativa ante coincidencia dudosa; nunca crear clientes automáticamente.

## 4. Alcance prohibido

- Credenciales reales de Invoice Ninja, FreeScout, SMTP ni API de Origen Salud.
- Creación de clientes, contactos, presupuestos, facturas ni pagos reales.
- Configuración del Client Portal ni generación de facturación propia.
- Activación automática de servicios por factura emitida.
- Iframe, SSO ni asociación automática por correo.
- Cambios en producción, `/admin`, catálogos, importadores, API pública, Nginx, PHP-FPM ni sitio público.
- Modificación de la autenticación real de `api_clients`.
- Commit, push ni deploy.

## 5. Estado de ejecución

| Elemento | Estado |
|---|---|
| Acta de autorización | **Emitida**. |
| Migración `up` | **Preparada**, no ejecutada. |
| Migración `down` | **Preparada**, no ejecutada. |
| Verificación `SELECT`-only | **Preparada** en `V6.001__invoice_ninja_links.verify.sql`; no ejecutada. |
| Verificación de rollback | **Preparada** en `V6.001__invoice_ninja_links.verify_rollback.sql`. |
| `InvoiceNinjaService` y adaptador | **Preparados**, no desplegados. |
| Repositorio de vínculos y revisiones | **Preparado**, no ejecutado. |
| Llamadas HTTP | **No realizadas**; modo `mock` por defecto. |
| Verificación local sin red ni base | **Ejecutada**: 13 comprobaciones, sin fallas. |
| Backup previo | **Responsable**: debe verificarlo antes de ejecutar. |
| Ejecución en base de prueba | **Pendiente**. |
| Etapa 7 | **No autorizada**. |

## 6. Artefactos preparados

- `sql/10_portal_clientes/V6.001__invoice_ninja_links.up.sql`
- `sql/10_portal_clientes/V6.001__invoice_ninja_links.down.sql`
- `sql/10_portal_clientes/V6.001__invoice_ninja_links.verify.sql`
- `sql/10_portal_clientes/V6.001__invoice_ninja_links.verify_rollback.sql`
- `portal-clientes/Services/InvoiceNinjaService.php`
- `portal-clientes/Services/InvoiceNinja/InvoiceNinjaTransport.php`
- `portal-clientes/Services/InvoiceNinja/MockInvoiceNinjaTransport.php`
- `portal-clientes/Services/InvoiceNinja/HttpInvoiceNinjaTransport.php`
- `portal-clientes/Repositories/InvoiceNinjaLinkRepository.php`
- Configuración `PORTAL_CUSTOMER_IN_*` en `portal-clientes/Config.php`

La migración `down` de V6 es re-ejecutable y no toca las tablas de V5 ni `os_customer.audit_log`. El orden de reversión es V6 y después V5.

El modo HTTP exige tres condiciones simultáneas: `PORTAL_CUSTOMER_IN_MODE=http`, `PORTAL_CUSTOMER_IN_ALLOW_TEST_CALLS=true` y token de prueba configurado. El token real sigue prohibido. Cabecera `X-Api-Token` y prefijo `/api/v1` son suposiciones pendientes de verificar contra la versión instalada.

## 7. Condición de avance

No se avanza a la Etapa 7 hasta que el responsable confirme:

- backup verificado;
- migración `up` aplicada en entorno de prueba;
- verificación `SELECT`-only sin hallazgos;
- rollback ensayado;
- ninguna llamada con token real;
- ningún cambio en producción.
