# Plan de despliegue — Etapa 12

> **Autorización:** `acta-autorizacion-etapa-12.md`.
> **Ejecutor:** responsable del proyecto. El asistente no hace commit, push ni deploy.
> **Commit esperado:** `21940dd` o posterior revisado, con `HEAD = origin/main`.

## 1. Principio

La Etapa 12 publica **código y configuración**, no esquema de producción. `origen_codes` queda intacto en esquema y datos. Las tablas del portal privado y de la Solicitud de Servicios siguen en `origen_codes_portal_clientes_test`.

No se ejecuta ninguna migración `V*` contra `origen_codes`. No se modifica Nginx, FreeScout ni Invoice Ninja.

## 2. Precondiciones

En local:

```bash
cd D:/docs/luis/Documentos/sitios/code-api   # o la ruta local equivalente

git status --short
git rev-parse HEAD
git rev-parse origin/main
git diff --check a184158..HEAD
php tests/run.php
php tools/php/verificar_etapa11_portal_clientes.php
php tools/php/verificar_etapa12_despliegue.php
```

Esperado:

```text
(git status sin cambios)
HEAD = origin/main
OK: 3942 comprobaciones
OK: 35 comprobaciones de la Etapa 11
OK: 26 comprobaciones de la Etapa 12
```

Si `git status` muestra cambios, el responsable decide commit/descartes antes de continuar. El asistente no ejecuta ninguna de esas acciones.

## 3. Backup previo

En el VPS, con `fecha=$(date +%Y%m%d_%H%M%S)`:

```bash
cd /var/www/html/origen.ar/code-api
fecha=$(date +%Y%m%d_%H%M%S)
dest=/opt/origen-salud-data/backups

sudo mkdir -p "$dest"

sudo tar -czf "$dest/code-api_${fecha}.tar.gz" \
  -C /var/www/html/origen.ar code-api
sudo chmod 600 "$dest/code-api_${fecha}.tar.gz"

sudo -u postgres pg_dump -Fc -d origen_codes \
  -f "$dest/origen_codes_${fecha}.dump"
sudo -u postgres pg_dump -Fc -d origen_codes_portal_clientes_test \
  -f "$dest/origen_codes_portal_clientes_test_${fecha}.dump"

sudo -u postgres pg_restore -l "$dest/origen_codes_${fecha}.dump" | head -20
sudo -u postgres pg_restore -l "$dest/origen_codes_portal_clientes_test_${fecha}.dump" | head -20

sha256sum "$dest/code-api_${fecha}.tar.gz" \
  "$dest/origen_codes_${fecha}.dump" \
  "$dest/origen_codes_portal_clientes_test_${fecha}.dump"
```

Registrar en el informe: `fecha`, rutas, tamaños, hashes y actor. Sin backup verificado, **no publicar**.

## 4. Revisión de secretos y diff

Antes de subir archivos:

```bash
cd /var/www/html/origen.ar/code-api

git status --short
git diff --check a184158..HEAD

grep -RIn --exclude-dir=.git --exclude=.env \
  -E 'INVOICE_NINJA_API_TOKEN=.+|SMTP_PASS=.+|PORTAL_DB_PASS=.+' . \
  | head -20

ls -la .env.bak.* 2>/dev/null || true
```

La última búsqueda no debe mostrar valores reales. Si aparece algo, detener y corregir antes de publicar. En particular, **ningún `.env.bak.*` debe quedar dentro del web root**: moverlo a `/opt/origen-salud-data/backups/`,chmod `600` y rotar las credenciales expuestas (`PORTAL_DB_PASS`, `SMTP_PASS`) antes de dar por cerrada la etapa. El verificador de despliegue falla si detecta esos archivos.

Verificación de rol y base, solo lectura:

```bash
sudo -u postgres psql -Atqc \
  "SELECT rolname, rolsuper, rolconnlimit FROM pg_roles WHERE rolname='origen_med'"

sudo -u postgres psql -Atqc \
  "SELECT datname, has_database_privilege('origen_med', datname, 'CONNECT')
     FROM pg_database
    WHERE datname IN ('origen_codes','origen_codes_portal_clientes_test')
    ORDER BY datname"
```

Esperado: `origen_med|f|-1` y `t` para ambas bases.

## 5. Publicación

1. Subir por WinSCP los archivos del **apartado 1** del manifiesto.
2. Revisar `.env` en el servidor según el **apartado 4** del manifiesto. No subir secretos desde local.
3. Verificar sintaxis en el VPS:

```bash
cd /var/www/html/origen.ar/code-api

find portal portal-clientes -name '*.php' -print0 \
  | xargs -0 -n1 php -l
```

4. Recargar el `php-fpm` instalado:

```bash
sudo systemctl reload php8.5-fpm   # versión verificada en el VPS; ajustar si corresponde
```

5. No recargar Nginx: las rutas ya pasan por el front controller existente.

## 6. Verificación post-despliegue

```bash
cd /var/www/html/origen.ar/code-api

php tests/run.php
php tools/php/verificar_etapa12_despliegue.php --site=https://med.origen.ar --post
```

Cobertura esperada:

- `/es-AR`, `/es-AR/docs`, `/es-AR/dentar`, `/es-AR/oftar`, `/es-AR/sitemap`.
- `/es-AR/portal`, `/es-AR/portal-clientes`.
- Las tres locales de `/solicitud`.
- API pública `/v1/*`: sin `5xx`.
- Home, nav y footer sin `/solicitud`.
- Sin secretos en HTML.
- `POST /es-AR/solicitud/enviar` sin CSRF → `303`, nunca `5xx`.

Verificación de DSN activo sin exponer secretos:

```bash
php -r '
require "bootstrap.php";
require "portal/Config.php";
$c = \OrigenSalud\Portal\Config::serviceRequestDatabase();
echo "dsn=" . $c["dsn"] . "\n";
echo "user=" . $c["user"] . "\n";
echo "pass=" . ($c["pass"] === "" ? "VACIO" : "presente") . "\n";
try {
    $pdo = new PDO($c["dsn"], $c["user"], $c["pass"], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $row = $pdo->query("select current_database()")->fetchColumn();
    echo "OK: " . $row . "\n";
} catch (PDOException $e) {
    echo "FALLO PDO: " . $e->getCode() . "\n";
}
'
```

Esperado: base `origen_codes_portal_clientes_test`.

Confirmar en Invoice Ninja que no se creó ningún cliente, presupuesto, factura ni pago.

## 7. Rollback

Se ejecuta si hay `5xx`, secretos expuestos, enlaces no autorizados, escritura en `origen_codes` o fallo de regresión.

```bash
cd /var/www/html/origen.ar
fecha=$(date +%Y%m%d_%H%M%S)
backup=/opt/origen-salud-data/backups/code-api_YYYYMMDD_HHMMSS.tar.gz

sudo tar -xzf "$backup" -C /var/www/html/origen.ar
sudo chown -R www-data:www-data /var/www/html/origen.ar/code-api
sudo systemctl reload php8.5-fpm
```

El tar incluye el `.env` previo, por lo que también se revierte la configuración. Ajustar usuario/grupo según el VPS.

**No ejecutar** como rollback:

- `V10.001__public_service_requests.down.sql` en producción: la guarda lo rechaza.
- `V10.002__origen_med_no_superuser.down.sql`: devolvería `SUPERUSER`; requiere autorización separada.
- `TRUNCATE`, `DROP SCHEMA CASCADE` ni borrado de auditoría.

No hay rollback de esquema en `origen_codes` porque esta etapa no aplica migraciones allí.

## 8. Criterios de aborto

| Situación | Acción |
| --- | --- |
| Backup no verificado | No publicar. |
| `HEAD != origin/main` | No publicar hasta decisión del responsable. |
| `php -l` falla | Rollback y corrección. |
| Verificador con fallos | Rollback y documentación. |
| Escritura en `origen_codes` detectada | Rollback inmediato y revisión. |
| Operación comercial creada en Invoice Ninja | Detener, documentar y escalar. |

## 9. Registro

Completar `informe-ejecucion-etapa-12.md` con resultado, hashes, comandos ejecutados y decisión final.
