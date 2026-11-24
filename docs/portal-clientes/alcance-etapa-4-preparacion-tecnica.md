# Alcance de la Etapa 4 — Preparación técnica

> **Estado:** autorizada por `acta-autorizacion-etapa-4.md`. **En preparación documental.**
> **Producción:** intacta. No se crearon esquemas, roles, datos ni credenciales.

## 1. Objetivo

Dejar lista la base técnica para la Etapa 5 sin tocar producción:

- entorno separado;
- configuración sin secretos;
- migraciones numeradas y reversibles;
- backup y rollback;
- datos ficticios;
- verificaciones de solo lectura.

## 2. Entregables de la Etapa 4

| Artefacto | Finalidad | Estado |
|---|---|---|
| `acta-autorizacion-etapa-4.md` | Registro de la autorización y sus límites. | Emitida. |
| `alcance-etapa-4-preparacion-tecnica.md` | Delimita qué se hace y qué no. | Este documento. |
| `entorno-prueba-configuracion.md` | Nombres, variables y placeholders; sin secretos. | Preparado. |
| `plan-migraciones-versionadas.md` | Convención de migraciones y rollback. | Preparado. |
| `plan-backup-rollback-etapa4.md` | Backup y restauración en entorno de prueba. | Preparado. |
| `datos-ficticios-etapa4.md` | Conjunto de datos sintéticos para prueba. | Preparado. |
| `verificaciones-solo-lectura-etapa4.md` | Consultas y comprobaciones sin escritura. | Preparado. |

## 3. Actividades permitidas

1. Escribir documentación en `docs/portal-clientes/`.
2. Definir nombres de base, roles y variables, sin crearlos.
3. Preparar plantillas SQL con comentarios y sentencias de verificación.
4. Preparar procedimientos de backup y restauración para el responsable.
5. Definir datos sintéticos con dominios reservados (`example.invalid`).
6. Ejecutar comprobaciones locales de solo lectura sobre el repositorio.
7. Entregar comandos de solo lectura para que el responsable los ejecute en VPS si decide.

## 4. Actividades no permitidas

1. Crear base, esquema, tabla, función, trigger, rol ni grant.
2. Ejecutar DDL o DML contra cualquier base.
3. Escribir secretos reales en archivos, logs,.chat ni documentos.
4. Consultar o modificar `api_clients` con claves reales.
5. Llamar APIs de Invoice Ninja, FreeScout ni SMTP con credenciales.
6. Crear tickets, clientes, presupuestos, facturas ni pagos.
7. Modificar `.env` real, Nginx, PHP-FPM, certificados ni servicios.
8. Hacer commit, push ni deploy.

## 5. Criterios de salida

La Etapa 4 se considera lista para revisión cuando:

- [x] Existe acta de autorización con límites explícitos.
- [x] Existe alcance documentado.
- [x] Existe catálogo de variables sin secretos reales.
- [x] Existe convención de migraciones reversibles.
- [x] Existe procedimiento de backup y rollback.
- [x] Existen datos ficticios sin datos reales.
- [x] Existe lista de verificaciones de solo lectura.
- [ ] El responsable revisa y aprueba los artefactos.
- [ ] El responsable ejecuta, si lo decide, las verificaciones en vivo.
- [ ] Se emite autorización expresa para la Etapa 5.

## 6. Dependencias para la Etapa 5

Antes de crear `os_customer_*` se deben resolver o aceptar formalmente:

- Versión real de PostgreSQL y configuración efectiva de `.env`.
- Existencia real de roles `origen_api`, `origen_med` y `origen_admin`.
- Verificación de que no existe `os_customer` en la base objetivo.
- Decisión sobre pertenencia múltiple a organizaciones.
- Decisión sobre política de invitación y contraseñas.
- Decisión sobre rol de escritura de credenciales.
- Condición comercial que habilita servicios técnicamente.

## 7. Estado de producción

No se ejecutó ninguna acción sobre producción en esta etapa. El repositorio solo contiene documentación nueva bajo `docs/portal-clientes/`.
