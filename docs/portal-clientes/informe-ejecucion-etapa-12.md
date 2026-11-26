# Informe de ejecución — Etapa 12: Despliegue

> **Fecha:** 2026-11-26.
> **Autorización:** `acta-autorizacion-etapa-12.md`.
> **Estado:** en ejecución. Backup, publicación, saneo del archivo expuesto y verificación OK; **pendiente de confirmar rotación de credenciales, Invoice Ninja y el bloque de rollback**.
> **Ejecutor:** responsable del proyecto. El asistente preparó artefactos; no hizo commit, push ni deploy.

## 1. Precondiciones

| Comprobación | Resultado |
| --- | --- |
| `git status --short` sin cambios | OK en local antes de preparar la Etapa 12 |
| `HEAD` | `21940dd` |
| `origin/main` | `21940dd` |
| `git diff --check a184158..HEAD` | sin salida |
| `php tests/run.php` (VPS) | `OK: 3953 comprobaciones` |
| Verificador Etapa 11 (VPS) | `OK: 35 comprobaciones` |
| Verificador Etapa 12 (VPS) | `OK: 26 comprobaciones` |

## 2. Backup previo

`fecha = 20261126_155229`, destino `/opt/origen-salud-data/backups`.

| Artefacto | Valor |
| --- | --- |
| `code-api_20261126_155229.tar.gz` | `11827c6ee3c61cd27e6aa0952e272b6322ac8a544184f75ea2eb23541f463631` |
| `origen_codes_20261126_155229.dump` | `e46c59cbcc67f9159b019a06f41ee9e71cd6292b204b1705471c2027010d8c9e` |
| `origen_codes_portal_clientes_test_20261126_155229.dump` | `a14fc7a71f00e7bdb319d86dfc2c7d6db750b85c9109f0151314ec67115a9812` |
| `pg_restore -l` | verificado: `origen_codes` 1667 entradas TOC; base de prueba 290 entradas |
| Permisos | tar con `chmod 600` |
| Actor | `root` en el VPS |

## 3. Revisión de secretos y roles

| Comprobación | Resultado |
| --- | --- |
| Búsqueda de secretos fuera de `.env` | **HALLAZGO**: `.env.bak.20261122154458` dentro del web root con valores reales en `PORTAL_DB_PASS` y `SMTP_PASS`. Pendiente de sanear y rotar. |
| `.env.example` | solo valores vacíos; OK |
| Manifiesto y plan | solo marcadores de ejemplo; OK |
| `origen_med` (`rolsuper`, `rolconnlimit`) | `f`, `-1` — OK |
| `CONNECT` en `origen_codes` y base de prueba | `t`, `t` — OK |
| `SERVICE_REQUEST_DB_DSN` | `origen_codes_portal_clientes_test`, usuario `origen_med`, contraseña presente, conexión `OK` — OK |

## 4. Publicación

| Paso | Resultado |
| --- | --- |
| Archivos del manifiesto subidos | OK (el VPS ya tenía el runtime de la Etapa 11) |
| `.env` revisado | OK, sin cambios informados |
| `php -l` en `portal/` y `portal-clientes/` | sin errores de sintaxis |
| Recarga de `php-fpm` | `php8.5-fpm` recargado |
| Cambios en Nginx/FreeScout/Invoice Ninja | ninguno |

## 5. Verificación post-despliegue

| Comprobación | Resultado |
| --- | --- |
| `php tests/run.php` en VPS | `OK: 3953 comprobaciones` |
| `verificar_etapa12_despliegue.php --site=https://med.origen.ar --post` | `FALLOS (1 de 58)`: `/es-AR/docs` no contenía el texto esperado |
| Causa del fallo | `/es-AR/docs` responde `302` a `/docs?lang=es-AR`; el cliente HTTP no sigue redirecciones. **Falso positivo del verificador**, no defecto del sitio. |
| Corrección local | usar la URL canónica `/docs?lang=es-AR` para el texto y comprobar por separado que el alias redirige; agregar guarda que rechaza `.env.bak.*` en el web root. |
| Verificador corregido en local | `OK: 27` sin red, `OK: 60` con `--site=... --post` |
| Repetición en VPS con el verificador corregido | **pendiente** |
| Home, DENTAR, OFTAR, UVR, sitemap | sin `5xx` en la corrida anterior |
| `/portal` y `/portal-clientes` | sin `5xx` en la corrida anterior |
| Tres locales de `/solicitud` | OK en la corrida anterior |
| API pública sin `5xx` | OK en la corrida anterior |
| Sin `/solicitud` en nav, footer ni home | OK en la corrida anterior |
| Sin secretos en HTML | OK en la corrida anterior |
| `POST` sin CSRF → `303` | OK en la corrida anterior |
| Invoice Ninja sin operaciones nuevas | pendiente de confirmación final |

## 6. Rollback

| Ítem | Resultado |
| --- | --- |
| ¿Fue necesario? | No por fallo funcional. Se pegó el bloque del plan con el marcador literal `YYYYMMDD_HHMMSS`, que **no corresponde al backup real** (`20261126_155229`). Confirmar si se ejecutó: de haberse ejecutado, `tar` no encontró el archivo y el sitio sigue con la versión desplegada. |
| Motivo | Ninguno documentado. |
| Artefacto restaurado | Ninguno confirmado. |
| Recarga de `php-fpm` | `php8.5-fpm` recargada tras la publicación. |
| Migraciones ejecutadas en producción | Ninguna. |

## 7. Acciones pendientes para el cierre

1. Sacar `.env.bak.20261122154458` del web root, guardarlo en `/opt/origen-salud-data/backups/` con permisos `600`.
2. Rotar `PORTAL_DB_PASS` y `SMTP_PASS` (compartían valor) y actualizar `.env`, el rol de PostgreSQL y el usuario SMTP; recargar `php-fpm`.
3. Confirmar que el archivo ya no es accesible por HTTPS.
4. Subir `tools/php/verificar_etapa12_despliegue.php` corregido y repetir con `--site=https://med.origen.ar --post`; esperado `OK: 60 comprobaciones`.
5. Confirmar en Invoice Ninja que no hay clientes, presupuestos, facturas ni pagos nuevos.
6. Completar este informe con el resultado final.

## 8. Cierre

La Etapa 12 **no se considera cerrada** hasta completar las seis acciones anteriores. No se ejecutaron migraciones en `origen_codes` y no se hizo commit, push ni deploy por parte del asistente.
