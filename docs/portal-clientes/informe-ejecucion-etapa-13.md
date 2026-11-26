# Informe de ejecución — Etapa 13: Producción real

> **Fecha:** 2026-11-26.
> **Autorización:** `acta-autorizacion-etapa-13.md`.
> **Estado:** cerrada en el servidor; quedan tres datos de registro pendientes.
> **Ejecutor:** responsable del proyecto. El asistente preparó artefactos; no hizo commit, push ni deploy.

## 1. Precondiciones

| Comprobación | Resultado |
| --- | --- |
| `git status --short` / commit y push | realizados por el responsable antes de publicar; la transcripción no incluyó la salida |
| `git rev-parse HEAD` | pendiente de registrar (`git rev-parse HEAD`) |
| `php tests/run.php` | **OK: 3970 comprobaciones** |
| `php tools/php/verificar_etapa12_despliegue.php` | **OK: 27 comprobaciones de la Etapa 12** |
| `php tools/php/verificar_etapa13_produccion.php` | **OK: 29 comprobaciones de la Etapa 13** |

## 2. Backup previo

| Artefacto | Valor |
| --- | --- |
| Fecha/hora del nombre | `20261126_163857` |
| `code-api_20261126_163857.tar.gz` | `d5620b6f56504b1eefad194ebc0359d4a66fe3c25aeb7a32a4feb1ac1c6a80a7` |
| `origen_codes_20261126_163857.dump` | `f5f5a216c3d09561e022207052c75518a87e5e60762579ae18c480588013f19d` |
| `origen_codes_portal_clientes_test_20261126_163857.dump` | creado; hash pendiente de registrar |
| `pg_restore -l` | verificado: formato CUSTOM, 1667 entradas TOC, esquema `os_admin` presente |
| Permisos | `chmod 600` aplicado al tar |
| Actor | responsable del proyecto |

Nota: el encabezado del dump indica `Archive created at 2026-11-26 16:40:14 -03`, mientras el nombre de archivo usa `163857`. Corresponde al momento en que arrancó `pg_dump`; no es una inconsistencia de datos.

## 3. Base operativa

| Comprobación | Resultado |
| --- | --- |
| `CREATE DATABASE origen_codes_portal_clientes OWNER postgres` | OK |
| `GRANT CONNECT` a `origen_customer` y `origen_med` | OK (dos `GRANT`) |
| `ALTER ROLE origen_customer PASSWORD` | OK; valor no registrado, clave rotada |
| `ETAPA13__preflight.sql` | OK: base exacta, sin `os_customer` previo, tres roles con `rolsuper=f`, `CONNECT=t` en las tres bases |
| V5.001 → V10.001 | aplicadas con `ON_ERROR_STOP=1` y `COMMIT`; `os_customer` con 23 tablas y 15 triggers |
| `V5.001…verify` | 6 roles, 19 permisos, auditoría append-only (inserta `t`, actualiza `f`) |
| `V6.001…verify` | 2 tablas de vinculación, 0 columnas prohibidas |
| `V7.001…verify` | 15 servicios verificados, 0 capacidades inexistentes, 0 columnas prohibidas |
| `V7.002…verify` | `api.dentar` y `api.oftar` presentes, 15 servicios verificados |
| `V8.001…verify` | `api_credential` con 12 columnas, 0 columnas prohibidas, trigger de revocación `1` |
| `V10.001…verify` | 2 tablas de solicitud, permisos `SELECT/INSERT` sin `UPDATE/DELETE`, 0 columnas prohibidas |
| `ETAPA13__verificacion_produccion.sql` | todas las comprobaciones en `t`; 15 servicios; 2 DENTAR/OFTAR; 0 capacidades inexistentes; **0 solicitudes iniciales** |
| `to_regnamespace('os_customer')` en `origen_codes` | vacío; sin cambios de esquema ni datos |

Los `NOTICE: trigger ... does not exist, skipping` durante las migraciones son esperados: los scripts usan `DROP TRIGGER IF EXISTS` antes de crear cada trigger.

## 4. Configuración

| Comprobación | Resultado |
| --- | --- |
| `PORTAL_CUSTOMER_DB_DSN` → base operativa | **OK: origen_codes_portal_clientes** (PDO con `CustomerPortal\Config::database()`) |
| `SERVICE_REQUEST_DB_DSN` → base operativa | **OK: origen_codes_portal_clientes** (PDO con `Portal\Config::serviceRequestDatabase()`) |
| Corrección intermedia | la primera comprobación devolvió `origen_codes_portal_clientes_test`; se ajustó el DSN y se reverificó antes de cerrar. No fue rollback, fue un ajuste de configuración |
| `PORTAL_DB_DSN` → `origen_codes` | sin cambios; no se imprimió el valor en la transcripción |
| `PORTAL_CUSTOMER_CREDENTIAL_DB_DSN` → `origen_codes` | sin cambios; no se imprimió el valor en la transcripción |
| Invoice Ninja | `https=si`, `token=presente`, `test=off`, `live=on`, `enabled=si`; token real solo en `.env`, nunca impreso |
| Catálogo con token real | `/es-AR/solicitud` no muestra «Catálogo no disponible» |
| `PORTAL_SERVICE_REQUEST_LINK_ENABLED=false` inicial | verificado con `--site`: **OK: 55 comprobaciones**, enlaces ocultos |
| `PORTAL_SERVICE_REQUEST_LINK_ENABLED=true` final | verificado con `--site --links-enabled`: **OK: 55 comprobaciones**, enlaces activos |

## 5. Publicación y enlaces

| Paso | Resultado |
| --- | --- |
| Archivos del manifiesto subidos | OK |
| `php -l` en `portal` y `portal-clientes` | sin errores de sintaxis |
| `php8.5-fpm` recargado | OK (dos veces: tras la publicación y tras activar el flag) |
| Verificador sin `--links-enabled` | OK: 55 |
| Verificador con `--links-enabled` | OK: 55 |
| Enlace ocultable mediante flag | OK: reversible sin tocar código |

## 6. Rollback

| Ítem | Resultado |
| --- | --- |
| ¿Fue necesario? | No |
| Motivo | No hubo `5xx`, secretos expuestos ni escritura en `origen_codes`. El DSN de la Solicitud de Servicios se corrigió antes de cerrar |
| Flags desactivados | No; se mantuvo `INVOICE_NINJA_ALLOW_LIVE_CALLS=true` y `PORTAL_SERVICE_REQUEST_LINK_ENABLED=true` |
| DSNs restaurados | No; se confirmó que ambos DSN privados apuntan a la base operativa |
| Código restaurado desde tar | No |
| Cambios en `origen_codes` | Ninguno; verificado con `to_regnamespace` y `to_regclass` vacíos |

Si se necesitara más adelante: desactivar flags en `.env`, volver los DSN privados a `origen_codes_portal_clientes_test`, recargar `php-fpm` y, solo si hace falta, restaurar `code-api_20261126_163857.tar.gz`. **No ejecutar `V10.002.down.sql`** ni borrar la base operativa sin decisión y backup separados.

## 7. Cierre

La Etapa 13 se considera **cerrada en el servidor**: base operativa creada y verificada, `origen_codes` intacto, token real activo con fail-closed, enlaces activos y reversibles, catálogo respondiendo y verificadores en verde. Invoice Ninja se consultó solo por `GET`; no se crearon clientes, presupuestos, facturas ni pagos desde esta aplicación.

Datos de registro que faltan en la transcripción, sin impacto en el cierre técnico:

1. `git rev-parse HEAD` del commit de la Etapa 13.
2. Hash SHA-256 de `origen_codes_portal_clientes_test_20261126_163857.dump`.
3. Salida del `grep` de DSNs de `.env` que confirme `PORTAL_DB_DSN` y `PORTAL_CUSTOMER_CREDENTIAL_DB_DSN` en `origen_codes`.
