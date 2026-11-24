# Acta de autorización — Etapa 4: Preparación técnica

> **Estado:** ETAPA 4 AUTORIZADA. Ejecución documental en curso. **Producción intacta.**
> **Fecha:** 2026-11-24.
> **Autorizado por:** responsable del proyecto.
> **Relación:** complementa `acta-aprobacion-etapas-1-2.md`.

## 1. Autorización recibida

> Autorizo la Etapa 4 — Preparación técnica del portal `/portal-clientes`, limitada a entorno de prueba/base independiente, configuración sin secretos reales, migraciones versionadas reversibles, backup y rollback, datos ficticios y verificaciones de solo lectura autorizadas. No autorizo la Etapa 5 ni siguientes, cambios en producción, creación de esquemas de clientes, credenciales reales, operaciones comerciales reales, modificación de Nginx/Invoice Ninja/FreeScout ni commit, push o deploy.

## 2. Alcance habilitado

Se autoriza únicamente:

1. Definir un entorno de prueba o base independiente, separada de `origen_codes` productiva.
2. Documentar variables de configuración con placeholders, sin secretos reales.
3. Definir convención de migraciones versionadas y reversibles.
4. Definir procedimiento de backup y rollback para ese entorno.
5. Definir datos ficticios de prueba.
6. Ejecutar verificaciones de solo lectura autorizadas.
7. Producir documentación revisable en `docs/portal-clientes/`.

## 3. Alcance prohibido

No se autoriza:

- Etapa 5 ni siguientes.
- Creación real de `os_customer_*` ni de otros esquemas de clientes.
- DDL, DML, `COMMIT`, `INSERT`, `UPDATE`, `DELETE`, `CREATE`, `ALTER` ni `DROP` en producción.
- Cambios en `os_admin`, `os_catalog_*`, `api_clients`, autenticación de API, catálogos ni importadores.
- Creación de roles o grants reales.
- Uso de credenciales reales de Invoice Ninja, FreeScout, SMTP ni API.
- Creación de clientes, contactos, presupuestos, facturas ni pagos reales.
- Modificación de Nginx, PHP-FPM, certificados, backups reales ni servicios del VPS.
- Commit, push ni deploy.

## 4. Estado actual de ejecución

| Elemento | Estado |
|---|---|
| Acta de autorización | **Emitida**. |
| Documentación de alcance | **En preparación**. |
| Entorno de prueba real | **No creado**; requiere ejecución por el responsable. |
| Migraciones reales | **No ejecutadas**. |
| Backup real | **No ejecutado**; solo procedimiento documentado. |
| Datos ficticios reales cargados | **No cargados**. |
| Verificaciones en vivo | **Pendientes**; el asistente no tiene SSH. |
| Etapa 5 | **No autorizada**. |

## 5. Regla de cierre

La Etapa 4 termina cuando el responsable revisa los artefactos, ejecuta —si lo decide— las verificaciones de solo lectura, y emite una nueva autorización para la Etapa 5. Hasta entonces no se crea nada en producción.
