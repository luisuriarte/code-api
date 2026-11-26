# Informe de ejecución — Etapa 13: Producción real

> **Fecha:** 2026-11-26.
> **Autorización:** `acta-autorizacion-etapa-13.md`.
> **Estado:** pendiente de ejecución por el responsable.
> **Ejecutor:** responsable del proyecto. El asistente preparó artefactos; no hizo commit, push ni deploy.

## 1. Precondiciones

| Comprobación | Resultado |
| --- | --- |
| `git status --short` | pendiente |
| `HEAD` | pendiente |
| `php tests/run.php` | pendiente en VPS |
| Verificador Etapa 12 | pendiente en VPS |
| Verificador Etapa 13 | pendiente en VPS |

## 2. Backup previo

| Artefacto | Valor |
| --- | --- |
| Fecha/hora | pendiente |
| `code-api_*.tar.gz` | pendiente |
| `origen_codes_*.dump` | pendiente |
| `origen_codes_portal_clientes_test_*.dump` | pendiente |
| Hashes SHA-256 | pendiente |
| Actor | pendiente |

## 3. Base operativa

| Comprobación | Resultado |
| --- | --- |
| `CREATE DATABASE origen_codes_portal_clientes` | pendiente |
| `GRANT CONNECT` a `origen_customer` y `origen_med` | pendiente |
| `ALTER ROLE origen_customer PASSWORD` | pendiente (no registrar el valor) |
| `ETAPA13__preflight.sql` | pendiente |
| Migraciones V5.001 → V10.001 | pendiente |
| Verificaciones `*.verify.sql` | pendiente |
| `ETAPA13__verificacion_produccion.sql` | pendiente |
| `to_regnamespace('os_customer')` en `origen_codes` | pendiente; esperado vacío |

## 4. Configuración

| Comprobación | Resultado |
| --- | --- |
| `PORTAL_CUSTOMER_DB_DSN` → base operativa | pendiente |
| `SERVICE_REQUEST_DB_DSN` → base operativa | pendiente |
| `PORTAL_DB_DSN` → `origen_codes` sin cambios | pendiente |
| `PORTAL_CUSTOMER_CREDENTIAL_DB_DSN` → `origen_codes` sin cambios | pendiente |
| `INVOICE_NINJA_ALLOW_TEST_CALLS=false` | pendiente |
| `INVOICE_NINJA_ALLOW_LIVE_CALLS=true` | pendiente |
| Token real solo en `.env`, sin imprimir | pendiente |
| `PORTAL_SERVICE_REQUEST_LINK_ENABLED=false` inicial | pendiente |

## 5. Publicación y enlaces

| Paso | Resultado |
| --- | --- |
| Archivos del manifiesto subidos | pendiente |
| `php -l` en VPS | pendiente |
| `php8.5-fpm` recargado | pendiente |
| Verificador sin `--links-enabled` | pendiente |
| `PORTAL_SERVICE_REQUEST_LINK_ENABLED=true` | pendiente |
| Verificador con `--links-enabled` | pendiente |
| Enlace ocultable mediante flag | pendiente |

## 6. Rollback

| Ítem | Resultado |
| --- | --- |
| ¿Fue necesario? | pendiente |
| Motivo | pendiente |
| Flags desactivados | pendiente |
| DSNs restaurados | pendiente |
| Código restaurado desde tar | pendiente |
| Cambios en `origen_codes` | ninguno esperado |

## 7. Cierre

La Etapa 13 se considera cerrada cuando todas las filas estén completas, el verificador termine sin fallos y se confirme que Invoice Ninja no tiene clientes, presupuestos, facturas ni pagos nuevos.
