# Acta de aprobación — Etapas 1 y 2 del portal privado de clientes

> **Estado:** aprobación documental de las etapas 1 y 2. **No autoriza implementación.**
> **Fecha:** 2026-11-24.
> **Aprobado por:** responsable del proyecto.
> **Alcance:** auditoría y diseño arquitectónico de `/portal-clientes`.

## 1. Aprobación concedida

El responsable del proyecto revisó y aprobó los 12 entregables ubicados en `docs/portal-clientes/`:

### Etapa 1 — Auditoría

1. `auditoria-portal-gobernanza.md`
2. `auditoria-api.md`
3. `auditoria-invoice-ninja.md`
4. `auditoria-infraestructura.md`

### Etapa 2 — Diseño

5. `arquitectura-portal-clientes.md`
6. `modelo-identidad-organizaciones.md`
7. `modelo-comercial-invoice-ninja.md`
8. `modelo-servicios-entitlements.md`
9. `arquitectura-credenciales-api.md`
10. `plan-implementacion-portal-clientes.md`
11. `plan-pruebas-portal-clientes.md`
12. `registro-de-decisiones-arquitectonicas.md`

## 2. Qué significa esta aprobación

Se aprueba como línea base de diseño:

- La separación estricta entre gobernanza y clientes.
- La identidad, sesiones y permisos propios para `/portal-clientes`.
- La ausencia de SSO y de vinculación automática por correo.
- Invoice Ninja como fuente de verdad comercial y financiera.
- La prohibición de duplicar productos, precios, facturas ni pagos.
- La habilitación técnica administrativa, no automática por factura.
- La integración con el mecanismo real de credenciales API y la prohibición de publicar capacidades inexistentes.
- El uso de i18n `es-AR`, `en` y `pt-BR` con el mecanismo existente.
- El plan de etapas, el plan de pruebas y el registro de decisiones como referencia de trabajo.

## 3. Qué NO autoriza esta aprobación

Esta acta **no** autoriza:

1. Crear esquemas, tablas, funciones, triggers, roles ni grants.
2. Modificar `os_admin`, `os_catalog_*`, `api_clients` ni la autenticación de la API.
3. Crear rutas, controladores, vistas ni navegación del portal de clientes.
4. Modificar el sitio público, `/admin`, Browse Codes, DENTAR, OFTAR, Docs ni UVR.
5. Cambiar Nginx, PHP-FPM, certificados, backups ni servicios del VPS.
6. Configurar o modificar Invoice Ninja ni FreeScout.
7. Crear clientes, contactos, presupuestos, facturas ni pagos reales.
8. Usar credenciales reales de sistemas externos.
9. Instrumentar medición de consumo sin autorización específica.
10. Ejecutar DDL, DML, `COMMIT`, commit, push ni deploy.

Cualquier implementación requiere una autorización posterior, por etapa y con su propio alcance.

## 4. Puntos que siguen pendientes

Aunque el paquete de diseño esté aprobado, siguen pendientes de decisión o verificación específica los temas marcados como `PENDIENTE` o `NO VERIFICADO`, en particular:

- Versión exacta, API, webhooks y Client Portal de Invoice Ninja.
- Configuración real de FreeScout.
- Condición comercial que habilita técnicamente un servicio.
- Quién puede habilitar servicios y quién puede crear clientes/presupuestos.
- Política de pertenencia múltiple a organizaciones.
- Política de invitación, contraseña y recuperación.
- Creación de un rol de escritura para credenciales.
- Hash, scopes, expiración, medición de consumo y `rate limiting` de la API.
- Servicios reales que se publicarán en la primera versión.
- Acceso autorizado de solo lectura al VPS/base para cerrar verificaciones en vivo.

## 5. Estado del proceso

| Etapa | Estado |
|---|---|
| 1 — Auditoría | **APROBADA** |
| 2 — Diseño arquitectónico | **APROBADA** |
| 3 — Decisión de implementación | **CERRADA** con el acta de aprobación del diseño. |
| 4 — Preparación técnica | **AUTORIZADA** posteriormente; ver `acta-autorizacion-etapa-4.md`. |
| 5 en adelante — Identidad e implementación | **NO AUTORIZADA** |

## 6. Regla de cierre

La Etapa 4 fue autorizada con un alcance limitado mediante `acta-autorizacion-etapa-4.md`. Las etapas 5 en adelante siguen sin autorización y requieren un acta posterior que indique etapas, alcance, entorno y condiciones de rollback.
