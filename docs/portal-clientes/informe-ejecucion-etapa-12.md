# Informe de ejecución — Etapa 12: Despliegue

> **Fecha:** 2026-11-26.
> **Autorización:** `acta-autorizacion-etapa-12.md`.
> **Estado:** **cerrada**. Publicación verificada; hallazgo de seguridad saneado; sin cambios de esquema en producción.
> **Ejecutor:** responsable del proyecto. El asistente preparó artefactos; no hizo commit, push ni deploy.

## 1. Precondiciones

| Comprobación | Resultado |
| --- | --- |
| `git status --short` sin cambios | OK en local antes de preparar la Etapa 12 |
| `HEAD` | `21940dd` |
| `origin/main` | `21940dd` |
| `git diff --check a184158..HEAD` | sin salida |
| `php tests/run.php` (VPS) | `OK: 3955 comprobaciones` |
| Verificador Etapa 11 (VPS) | `OK: 35 comprobaciones` |
| Verificador Etapa 12 (VPS) | `OK: 60 comprobaciones` con `--site=https://med.origen.ar --post` |

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
| Búsqueda de secretos fuera de `.env` | Hallazgo saneado: `.env.bak.20261122154458` se movió a `/opt/origen-salud-data/backups/env-history/` con permisos `600`. La URL pública responde `403`. |
| Rotación | Confirmada por el responsable: rotadas las credenciales de `origen_med` (`PORTAL_DB_PASS`, `SERVICE_REQUEST_DB_PASS`) y `SMTP_PASS`, con `.env` actualizado y `php8.5-fpm` recargado. |
| `.env.example` | solo valores vacíos; OK |
| Manifiesto y plan | solo marcadores de ejemplo; OK |
| `origen_med` (`rolsuper`, `rolconnlimit`) | `f`, `-1` — OK |
| `CONNECT` en `origen_codes` y base de prueba | `t`, `t` — OK |
| `SERVICE_REQUEST_DB_DSN` | `origen_codes_portal_clientes_test`, usuario `origen_med`, contraseña presente, conexión `OK` — OK |

## 4. Publicación

| Paso | Resultado |
| --- | --- |
| Archivos del manifiesto subidos | OK (el VPS ya tenía el runtime de la Etapa 11) |
| `.env` revisado | OK; actualizado tras la rotación |
| `php -l` en `portal/` y `portal-clientes/` | sin errores de sintaxis |
| Recarga de `php-fpm` | `php8.5-fpm` recargado tras la publicación y tras la rotación |
| Cambios en Nginx/FreeScout/Invoice Ninja | ninguno |

## 5. Verificación post-despliegue

| Comprobación | Resultado |
| --- | --- |
| `php tests/run.php` en VPS | `OK: 3955 comprobaciones` |
| `verificar_etapa12_despliegue.php --site=https://med.origen.ar --post` | `OK: 60 comprobaciones` |
| Home, Docs, DENTAR, OFTAR, UVR, sitemap | sin `5xx`; Docs comprobado en su URL canónica `/docs?lang=es-AR` y el alias `/es-AR/docs` redirige con `302` |
| `/portal` y `/portal-clientes` | sin `5xx` |
| Tres locales de `/solicitud` | OK |
| API pública sin `5xx` | OK |
| Sin `/solicitud` en nav, footer ni home | OK |
| Sin secretos en HTML | OK |
| Sin `.env.bak.*` en el web root | OK |
| `POST` sin CSRF → `303` | OK |
| Invoice Ninja sin operaciones nuevas | **confirmado** por el responsable: ningún cliente, presupuesto, factura ni pago |

### Hallazgo cerrado: `/es-AR/docs`

La primera corrida dio `FALLOS (1 de 58)`: `/es-AR/docs` responde `302` a `/docs?lang=es-AR` y el verificador no seguía redirecciones. Era un falso positivo: el contenido sí estaba publicado. Se corrigió el verificador para consultar la URL canónica y validar el alias por separado.

### Hallazgo cerrado: copia de `.env` en el web root

El escaneo encontró `.env.bak.20261122154458` con valores reales en `PORTAL_DB_PASS` y `SMTP_PASS`. Se movió fuera del web root, se dejó con permisos `600`, se confirmó `403` por HTTPS y se rotaron las credenciales. El verificador ahora falla si detecta `.env.bak.*`.

## 6. Rollback

| Ítem | Resultado |
| --- | --- |
| ¿Fue necesario? | No por fallo funcional. |
| Intento registrado | Se ejecutó el bloque con el marcador literal `YYYYMMDD_HHMMSS`. Ese archivo no existe: `tar` no pudo abrirlo, por lo que **no hubo restauración de archivos**. Sí se ejecutaron `chown -R www-data:www-data` y la recarga de `php8.5-fpm`. |
| Estado posterior | Verificado: `OK: 3955 comprobaciones` y `OK: 60 comprobaciones` después del intento, por lo que el sitio quedó en la versión desplegada. |
| Artefacto restaurado | Ninguno; no fue necesario. |
| Migraciones ejecutadas en producción | Ninguna. |

Si en el futuro hiciera falta rollback, usar el nombre real:

```bash
sudo tar -xzf /opt/origen-salud-data/backups/code-api_20261126_155229.tar.gz \
  -C /var/www/html/origen.ar
sudo chown -R www-data:www-data /var/www/html/origen.ar/code-api
sudo systemctl reload php8.5-fpm
```

## 7. Acciones pendientes

Ninguna.

## 8. Cierre

La **Etapa 12 — Despliegue** queda **cerrada**:

- Backup lógico y de código verificado con hashes.
- Código publicado y `php -l` sin errores.
- Verificadores: `OK: 3955`, `OK: 35`, `OK: 60`.
- Hallazgo de secreto expuesto saneado y credenciales rotadas.
- Sin cambios de esquema ni datos en `origen_codes`; sin migraciones `V*` en producción.
- Invoice Ninja sin clientes, presupuestos, facturas ni pagos nuevos.
- El asistente no hizo commit, push ni deploy.
