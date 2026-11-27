# Informe de ejecución — Etapa 13: Producción real

> **Fecha:** 2026-11-26.
> **Autorización:** `acta-autorizacion-etapa-13.md`.
> **Estado:** cerrada en el servidor; quedan tres datos de registro pendientes.
> **Ejecutor:** responsable del proyecto. El asistente preparó artefactos; no hizo commit, push ni deploy.

## 1. Precondiciones

| Comprobación | Resultado |
| --- | --- |
| `git status --short` en el PC del responsable | árbol limpio |
| `git rev-parse HEAD` / `git rev-parse origin/main` | `552903b8121cefe6d2b6a6de7eb2ee5d63c7493c` (ambos) |

Git se gestiona en el PC del responsable, **no en el VPS**. El HEAD se registró desde el repositorio local, sin ejecutar comandos de Git en el servidor.
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

1. Hash SHA-256 de `origen_codes_portal_clientes_test_20261126_163857.dump`.
2. Salida del `grep` de DSNs de `.env` en el VPS que confirme `PORTAL_DB_DSN` y `PORTAL_CUSTOMER_CREDENTIAL_DB_DSN` en `origen_codes`.

## 8. Anexo de consolidación documental (posterior a la ejecución)

Este anexo no reescribe lo ejecutado: solo deja constancia de la documentación reconciliada con el código vigente. No se inventan los datos de registro enumerados en §7; siguen como **no disponibles** en la transcripción.

| Ítem | Estado documentado |
| --- | --- |
| Reset y invitaciones del portal de clientes | Se envían por **SMTP real** mediante `CustomerNotification`, reutilizando el transporte del portal público sin iniciar su sesión. El token sin cifrar viaja solo por correo al destinatario legítimo: nunca se muestra en pantalla, se guarda en flash ni se escribe en logs. Fallo de envío: invitación expirada / reset revocado, con auditoría y respuesta genérica. |
| Guardia HTTPS del portal de clientes | Depende de `PORTAL_CUSTOMER_REQUIRE_HTTPS` (default `true`) y de `PORTAL_CUSTOMER_TRUSTED_PROXY_IPS`. `X-Forwarded-Proto: https` solo se acepta si `REMOTE_ADDR` está en la lista (IP exacta o CIDR IPv4); lista vacía = no confiar. |
| Copias ocultas de notificaciones | `PORTAL_CUSTOMER_NOTIFICATION_BCC`, opcional; valores de ejemplo solo en `.env.example`, nunca en Git. |
| Evolución M6 de credenciales de API | `sql/10_portal_clientes/V11.001__api_key_hash.up.sql` y su `.down.sql` están **preparados, no ejecutados**: requieren acta de despliegue. Agregan `key_prefix`/`key_hash` y permiten `api_key = NULL` sin backfill; el `down` solo restaura `NOT NULL` si no hay filas con `api_key IS NULL` y exige revisión humana. |
| Ejecución de SQL en esta auditoría | Ninguna. No se aplicaron migraciones, rollback, `psql` ni pruebas de base; las verificaciones fueron de lectura y `grep`. |

La documentación de estado de la Etapa 13 (§7 y `portal-clientes/README.md`) se conserva sin cambios: la base operativa sigue siendo `origen_codes_portal_clientes`, `origen_codes` no recibió cambios de esquema ni datos y V10.002 no se reejecutó.

## 9. Anexo de registro posterior a la auditoría

Este anexo se agrega sin reescribir el cuerpo del informe; solo aclara el estado de registro posterior a la ejecución de la Etapa 13:

| Ítem | Registro |
| --- | --- |
| HEAD local y `origin/main` | `61d5073ef984ec74480f2ef9e3a3131cd989e064` (ambos). El hash de §1 corresponde al momento de la ejecución; este es el estado posterior. |
| Publicación posterior | Rediseño de `/solicitud` publicado con `portal/Views/service-request.php`, `web/assets/css/public.css` y `tests/run.php`. No modifica la base operativa ni el cierre de la Etapa 13. |
| Entorno real del VPS | PHP 8.5.4 CLI NTS con OPcache 8.5.4 y PostgreSQL 18.6. |

**Este anexo NO es acta de un nuevo deploy**: no autoriza ni registra una ejecución adicional de SQL, migraciones, rollback ni despliegue.
