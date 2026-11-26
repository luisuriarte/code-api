# Informe de ejecución — Etapa 12: Despliegue

> **Fecha:** 2026-11-26.
> **Autorización:** `acta-autorizacion-etapa-12.md`.
> **Estado:** pendiente de ejecución por el responsable.
> **Ejecutor:** responsable del proyecto. El asistente preparó artefactos; no hizo commit, push ni deploy.

## 1. Precondiciones

| Comprobación | Resultado |
| --- | --- |
| `git status --short` sin cambios | pendiente |
| `HEAD` | `21940dd` |
| `origin/main` | `21940dd` |
| `git diff --check a184158..HEAD` | pendiente |
| `php tests/run.php` | `OK: 3942 comprobaciones` (local) |
| Verificador Etapa 11 (local) | `OK: 35 comprobaciones` |
| Verificador Etapa 12 (local) | `OK: 26 comprobaciones` |

## 2. Backup previo

| Artefacto | Valor |
| --- | --- |
| Fecha/hora | pendiente |
| `code-api_*.tar.gz` | pendiente |
| `origen_codes_*.dump` | pendiente |
| `origen_codes_portal_clientes_test_*.dump` | pendiente |
| Hashes SHA-256 | pendiente |
| `pg_restore -l` verificado | pendiente |
| Actor | pendiente |

## 3. Revisión de secretos y roles

| Comprobación | Resultado |
| --- | --- |
| Búsqueda de secretos en archivos fuera de `.env` | pendiente |
| `origen_med` (`rolsuper`, `rolconnlimit`) | esperado `f`, `-1` |
| `CONNECT` en `origen_codes` y base de prueba | esperado `t`, `t` |
| `SERVICE_REQUEST_DB_DSN` | esperado `origen_codes_portal_clientes_test` |

## 4. Publicación

| Paso | Resultado |
| --- | --- |
| Archivos del manifiesto subidos | pendiente |
| `.env` revisado | pendiente |
| `php -l` en VPS | pendiente |
| Recarga de `php-fpm` | pendiente |
| Cambios en Nginx/FreeScout/Invoice Ninja | ninguno esperado |

## 5. Verificación post-despliegue

| Comprobación | Resultado |
| --- | --- |
| `php tests/run.php` en VPS | pendiente |
| `verificar_etapa12_despliegue.php --site=... --post` | pendiente |
| Home, Docs, DENTAR, OFTAR, UVR, sitemap | pendiente |
| `/portal` y `/portal-clientes` | pendiente |
| Tres locales de `/solicitud` | pendiente |
| API pública sin `5xx` | pendiente |
| Sin `/solicitud` en nav, footer ni home | pendiente |
| Sin secretos en HTML | pendiente |
| `POST` sin CSRF → `303` | pendiente |
| Invoice Ninja sin operaciones nuevas | pendiente |

## 6. Rollback

| Ítem | Resultado |
| --- | --- |
| ¿Fue necesario? | pendiente |
| Motivo | pendiente |
| Artefacto restaurado | pendiente |
| Recarga de `php-fpm` | pendiente |
| Migraciones ejecutadas en producción | ninguna esperada |

## 7. Cierre

La Etapa 12 se considera cerrada cuando todas las filas anteriores estén completas y el verificador termine sin fallos. Hasta entonces, el despliegue queda documentado como **pendiente de ejecución**.
