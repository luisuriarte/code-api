# Acta de autorización — Etapa 5: Identidad y organizaciones

> **Estado:** ETAPA 5 AUTORIZADA para entorno de prueba. **Producción intacta.**
> **Fecha:** 2026-11-24.
> **Autorizado por:** responsable del proyecto.
> **Relación:** complementa `acta-autorizacion-etapa-4.md`.

## 1. Autorización recibida

> Autorizo la Etapa 5 — Identidad y organizaciones del portal `/portal-clientes`, únicamente en entorno de prueba/base independiente, conforme a `modelo-identidad-organizaciones.md` y `plan-migraciones-versionadas.md`.
>
> Se habilita la creación del esquema `os_customer`, sus tablas de organizaciones, usuarios, membresías, roles, permisos, invitaciones, sesiones, recuperación, throttle y auditoría append-only; sus funciones/triggers; el rol de base `origen_customer`; y los grants/revokes objeto por objeto, sin `ALTER DEFAULT PRIVILEGES`.
>
> También se habilita la implementación de autenticación, sesiones propias, CSRF, RBAC, invitaciones y auditoría del portal de clientes en dicho entorno de prueba.
>
> No autorizo cambios en producción, credenciales reales, Invoice Ninja, FreeScout, servicios/habilitaciones, credenciales API, facturación, pagos, modificación de `/admin`, catálogos, API pública, Nginx ni commit, push o deploy.
>
> Requiero backup verificado, migración `up` y `down`, verificación `SELECT`-only y rollback ensayado antes de avanzar a la Etapa 6.

## 2. Alcance habilitado

Se autoriza:

1. Crear artefactos SQL versionados para `os_customer`.
2. Crear el rol `origen_customer` y privilegios objeto por objeto.
3. Crear tablas, índices, funciones y triggers de auditoría append-only.
4. Implementar autenticación, sesiones, CSRF, RBAC, invitaciones y auditoría del portal de clientes.
5. Ejecutar esos artefactos **solo en base independiente de prueba**.
6. Verificar con sentencias `SELECT`-only.
7. Ensayar rollback en el entorno de prueba.

## 3. Alcance prohibido

No se autoriza:

- Producción ni `origen_codes` real.
- Credenciales reales de SMTP, Invoice Ninja, FreeScout ni API.
- Servicios, habilitaciones, credenciales API, facturación ni pagos.
- Cambios en `/admin`, catálogos, importadores, API pública, Nginx ni sitio público.
- Commit, push ni deploy.
- `ALTER DEFAULT PRIVILEGES`.
- Auditoría modificable o borrable.

## 4. Estado de ejecución

| Elemento | Estado |
|---|---|
| Acta de autorización | **Emitida**. |
| Migración `up` | **Preparada** en `sql/10_portal_clientes/V5.001__os_customer_identity.up.sql`; no ejecutada. |
| Migración `down` | **Preparada**; revierte objetos sin borrar `os_customer.audit_log`; no ejecutada. |
| Verificación `SELECT`-only | **Preparada** en `V5.001__os_customer_identity.verify.sql`; no ejecutada. |
| Verificación de rollback | **Preparada** en `V5.001__os_customer_identity.verify_rollback.sql`. |
| Código PHP del portal de clientes | **Preparado** en `portal-clientes/` y `web/portal-clientes/`; no desplegado. |
| i18n `es-AR`, `en`, `pt-BR` | **Preparado** con el mecanismo existente; 74 claves comprobadas. |
| Lint PHP y suite existente | **Ejecutados en local**: sin errores de sintaxis; `OK: 3578 comprobaciones`. |
| Backup previo | **Responsable**: debe verificarlo antes de ejecutar. |
| Ejecución en base de prueba | **Pendiente**; el asistente no tiene SSH. |
| Etapa 6 | **No autorizada**. |

## 5. Artefactos preparados

- `sql/10_portal_clientes/README.md`
- `sql/10_portal_clientes/V5.001__os_customer_identity.up.sql`
- `sql/10_portal_clientes/V5.001__os_customer_identity.down.sql`
- `sql/10_portal_clientes/V5.001__os_customer_identity.verify.sql`
- `sql/10_portal_clientes/V5.001__os_customer_identity.verify_rollback.sql`
- `portal-clientes/` con configuración, sesión, CSRF, RBAC, repositorios, servicios, controladores, vistas y traducciones propias.
- `web/portal-clientes/index.php` y `.htaccess` nuevos, sin modificar el front controller ni el `.htaccess` de `/portal`.

No se crearon secretos reales. Las credenciales de base y peppers quedan vacíos en la configuración; la aplicación no puede conectarse sin que el responsable los inyecte en el entorno de prueba.

## 6. Condición de avance

No se avanza a la Etapa 6 hasta que el responsable confirme:

- migración aplicada en entorno de prueba;
- verificación `SELECT`-only sin hallazgos;
- rollback ensayado;
- ningún cambio en producción.

## 7. Aclaración posterior sobre bases de prueba

El responsable aclaró que **todas las bases con las que está trabajando son exclusivamente de prueba**. En consecuencia, se habilita ajustar iterativamente los scripts ubicados en `sql/10_portal_clientes/` mientras el destino sea una base independiente de prueba.

Esta aclaración **no** habilita:

- ejecutar scripts contra `origen_codes` u otra base productiva;
- usar credenciales reales;
- modificar `/admin`, catálogos, API, Nginx, Invoice Ninja ni FreeScout;
- hacer commit, push ni deploy;
- avanzar a la Etapa 6 sin autorización expresa.

Tampoco cambia la regla de conservar la auditoría append-only en la migración `down` de entrega. Si se necesita un reseteo completo de auditoría durante desarrollo, debe hacerse mediante un script separado, explícitamente marcado como `DEV ONLY` y nunca aplicable en producción.
