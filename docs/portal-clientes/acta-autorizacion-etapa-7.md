# Acta de autorización — Etapa 7: Servicios y habilitaciones

> **Estado:** AUTORIZADA. **Implementación en curso.** **No desplegada en producción.**
> **Fecha:** 2026-11-24.
> **Autorizado por:** responsable del proyecto.
> **Relación:** continuación de las Etapas 5 y 6, cerradas en entorno de prueba.

## 1. Autorización recibida

El responsable autorizó expresamente:

> «Sí, solo en prueba», con relación a la Etapa 7: migración V7 `up`/`down`/`verify`, código en `portal-clientes/` y verificación en `origen_codes_portal_clientes_test`.

## 2. Decisiones de la Etapa 7

| Decisión | Valor aprobado |
|---|---|
| Condición comercial previa | **Pago confirmado + aprobación manual** |
| Quién habilita, suspende o revoca | **Solo superadministrador de Origen Salud** |
| Catálogo inicial | **Solo servicios verificables en la API actual** |
| Entorno | **Únicamente base de prueba aislada** `origen_codes_portal_clientes_test` |

La aprobación manual se registra en dos momentos distintos: verificación comercial (pago confirmado consultado por el superadministrador en Invoice Ninja) y decisión técnica de habilitación. Ninguno de los dos pasos se dispara automáticamente por factura, webhook ni pago.

## 3. Alcance habilitado

- Crear el esquema de servicios, relación comercial ↔ servicio, solicitudes, contratos e habilitaciones dentro de `os_customer`.
- Grants por objeto al rol `origen_customer`; **sin** `ALTER DEFAULT PRIVILEGES`.
- Registrar operadores `superadmin` de Origen Salud dentro de `os_customer`, aprovisionados manualmente. No se comparte identidad con `os_admin`.
- Backend de servicios: catálogo, solicitudes, verificación comercial, habilitación, suspensión y revocación con auditoría.
- Vista mínima «Mis servicios» en `/portal-clientes/{locale}/servicios`, en `es-AR`, `en` y `pt-BR`.
- Flujo manual completo: solicitud del cliente → contrato registrado por el superadministrador → verificación manual del pago → creación de la habilitación pendiente → habilitación, suspensión o revocación. Cada paso queda auditado.
- Corrección de valores inválidos en `os_customer.audit_log` detectada en la Etapa 6 (`ok`, `needs_review`, `approved`, `rejected`, `discarded` → `success`/`denied`/`failure`), porque la columna tiene un `CHECK` y esas escrituras fallarían.

## 4. Alcance no habilitado

- Producción (`origen_codes`) ni ninguna otra base.
- Cambios en Invoice Ninja, FreeScout, `/admin`, catálogos ni API pública.
- Copiar precios, importes, ítems de factura, pagos, razones sociales ni correos al portal de clientes.
- Crear clientes, contactos, presupuestos, facturas ni pagos.
- Habilitar servicios reales a organizaciones reales durante la verificación.
- Publicar servicios que no existan en el ecosistema real.
- Commits, push ni deploy.

## 5. Reglas de verificación

1. Backup previo con `pg_dump -Fc` y hash SHA-256.
2. Aplicar `V7.001__services_entitlements.up.sql`.
3. Ejecutar `V7.001__services_entitlements.verify.sql` en `BEGIN READ ONLY`.
4. Verificar rechazo de escrituras inválidas: doble habilitación activa, activación sin pago verificado, activación por no superadministrador.
5. Ejecutar `V7.001__services_entitlements.down.sql` y `verify_rollback.sql`.
6. Reaplicar `up` y dejar la base de prueba en estado consistente.
7. `php -l`, verificaciones i18n y `php tests/run.php`.

## 6. Estado

La Etapa 7 se considerará cerrada solo cuando el responsable ejecute los pasos anteriores en el VPS y reporte los resultados. Hasta entonces, el estado es **implementada localmente, pendiente de verificación en prueba**.
