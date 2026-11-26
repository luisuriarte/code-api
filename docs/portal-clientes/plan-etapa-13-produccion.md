# Plan de producción real — Etapa 13

> **Autorización:** `acta-autorizacion-etapa-13.md`.
> **Ejecutor:** responsable del proyecto. El asistente no hace commit, push ni deploy.
> **Base operativa:** `origen_codes_portal_clientes`. `origen_codes` queda intacto.

## 1. Principio

Esta etapa crea una base nueva para el portal de clientes y cambia la configuración del sitio para usarla. No escribe en `origen_codes` y no aplica `V10.002` (ya ejecutada).

El enlace a la Solicitud de Servicios queda detrás de un flag del servidor. El token real de Invoice Ninja también queda detrás de un flag distinto; ambos se pueden desactivar sin tocar código.

## 2. Precondiciones

```bash
cd /var/www/html/origen.ar/code-api

git status --short
git rev-parse HEAD

php tests/run.php
php tools/php/verificar_etapa12_despliegue.php
php tools/php/verificar_etapa13_produccion.php
```

Esperado: árbol limpio, suite OK, verificadores OK, base de la Etapa 12 cerrada.

## 3. Backup previo

```bash
cd /var/www/html/origen.ar/code-api
fecha=$(date +%Y%m%d_%H%M%S)
dest=/opt/origen-salud-data/backups

sudo mkdir -p "$dest"
sudo tar -czf "$dest/code-api_${fecha}.tar.gz" -C /var/www/html/origen.ar code-api
sudo chmod 600 "$dest/code-api_${fecha}.tar.gz"

sudo -u postgres pg_dump -Fc -d origen_codes \
  -f "$dest/origen_codes_${fecha}.dump"
sudo -u postgres pg_dump -Fc -d origen_codes_portal_clientes_test \
  -f "$dest/origen_codes_portal_clientes_test_${fecha}.dump"

sudo -u postgres pg_restore -l "$dest/origen_codes_${fecha}.dump" | head -20
sha256sum "$dest/code-api_${fecha}.tar.gz" "$dest/origen_codes_${fecha}.dump"
```

Sin backup verificado, **no continuar**.

## 4. Crear la base operativa

Comprobar que no existe:

```bash
sudo -u postgres psql -Atqc \
  "SELECT datname FROM pg_database WHERE datname='origen_codes_portal_clientes'"
```

Si no devuelve nada:

```bash
sudo -u postgres psql -v ON_ERROR_STOP=1 -c \
  "CREATE DATABASE origen_codes_portal_clientes OWNER postgres;"
```

Grants de conexión y credencial del rol de aplicación:

```bash
sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c \
  "GRANT CONNECT ON DATABASE origen_codes_portal_clientes TO origen_customer;"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c \
  "GRANT CONNECT ON DATABASE origen_codes_portal_clientes TO origen_med;"

sudo -u postgres psql -v ON_ERROR_STOP=1 -c \
  "ALTER ROLE origen_customer PASSWORD 'CLAVE_SEGURA_GENERADA_EN_EL_SERVIDOR';"
```

No reutilizar la clave ya expuesta en la Etapa 12. No ponerla en `.env.example` ni en Git.

## 5. Preflight y migraciones

```bash
cd /var/www/html/origen.ar/code-api
DB=origen_codes_portal_clientes

sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/ETAPA13__preflight.sql

for migration in \
  V5.001__os_customer_identity.up \
  V6.001__invoice_ninja_links.up \
  V7.001__services_entitlements.up \
  V7.002__dentar_oftar_services.up \
  V8.001__api_credentials.up \
  V10.001__public_service_requests.up; do
  sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 \
    -f "sql/10_portal_clientes/${migration}.sql"
done

for verification in \
  V5.001__os_customer_identity.verify \
  V6.001__invoice_ninja_links.verify \
  V7.001__services_entitlements.verify \
  V7.002__dentar_oftar_services.verify \
  V8.001__api_credentials.verify \
  V10.001__public_service_requests.verify; do
  sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 \
    -f "sql/10_portal_clientes/${verification}.sql"
done

sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/ETAPA13__verificacion_produccion.sql
```

**No ejecutar `V10.002`.** No ejecutar `*.down.sql` ni `DEV_ONLY__reset_os_customer.sql`.

Confirmar que `origen_codes` no fue tocado:

```bash
sudo -u postgres psql -d origen_codes -Atqc \
  "SELECT to_regnamespace('os_customer'), to_regclass('os_customer.public_service_request')"
```

Esperado: dos filas vacías.

## 6. Configuración del servidor

Editar `.env` a mano, sin subir secretos:

```ini
PORTAL_CUSTOMER_DB_DSN=pgsql:host=127.0.0.1;port=5432;dbname=origen_codes_portal_clientes
SERVICE_REQUEST_DB_DSN=pgsql:host=127.0.0.1;port=5432;dbname=origen_codes_portal_clientes
PORTAL_SERVICE_REQUEST_LINK_ENABLED=false
INVOICE_NINJA_ALLOW_TEST_CALLS=false
INVOICE_NINJA_ALLOW_LIVE_CALLS=true
INVOICE_NINJA_API_TOKEN=<token real de solo lectura>
```

`PORTAL_DB_DSN` y `PORTAL_CUSTOMER_CREDENTIAL_DB_DSN` siguen en `origen_codes`.

Comprobar modo Invoice Ninja sin imprimir el token:

```bash
php -r '
require "bootstrap.php";
require "portal/Config.php";
$c = \OrigenSalud\Portal\Config::invoiceNinja();
echo "https=" . (str_starts_with($c["base_url"], "https://") ? "si" : "no") . "\n";
echo "token=" . ($c["token"] === "" ? "VACIO" : "presente") . "\n";
echo "test=" . ($c["allow_test_calls"] ? "on" : "off") . "\n";
echo "live=" . ($c["allow_live_calls"] ? "on" : "off") . "\n";
echo "enabled=" . (\OrigenSalud\Portal\Config::invoiceNinjaHttpEnabled() ? "si" : "no") . "\n";
'
```

Esperado: `https=si`, `token=presente`, `test=off`, `live=on`, `enabled=si`.

Comprobar conectividad de la Solicitud de Servicios:

```bash
php -r '
require "bootstrap.php";
require "portal/Config.php";
$c = \OrigenSalud\Portal\Config::serviceRequestDatabase();
$pdo = new PDO($c["dsn"], $c["user"], $c["pass"], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
echo "OK: " . $pdo->query("select current_database()")->fetchColumn() . "\n";
'
```

Esperado: `OK: origen_codes_portal_clientes`.

## 7. Publicación del código

Subir los archivos del manifiesto y verificar sintaxis:

```bash
cd /var/www/html/origen.ar/code-api
find portal portal-clientes -name '*.php' -print0 | xargs -0 -n1 php -l
sudo systemctl reload php8.5-fpm
```

Verificación con enlaces todavía desactivados:

```bash
php tools/php/verificar_etapa13_produccion.php --site=https://med.origen.ar
```

Aquí se comprueba que **no** hay `/solicitud` en nav, footer ni home.

## 8. Activación controlada de enlaces

Recién después de lo anterior:

```bash
# Editar .env: PORTAL_SERVICE_REQUEST_LINK_ENABLED=true
sudo systemctl reload php8.5-fpm

php tools/php/verificar_etapa13_produccion.php --site=https://med.origen.ar --links-enabled
```

Ahora se comprueba que el enlace aparece en nav, footer y home en las tres locales. Si se necesita ocultar urgentemente, volver a `false` y recargar `php-fpm`.

## 9. Rollback

Si hay `5xx`, secretos expuestos, enlaces no deseados o escritura en `origen_codes`:

```bash
# 1) Desactivar flags en .env
#    PORTAL_SERVICE_REQUEST_LINK_ENABLED=false
#    INVOICE_NINJA_ALLOW_LIVE_CALLS=false
# 2) Restaurar DSNs de la Etapa 12
#    PORTAL_CUSTOMER_DB_DSN=...dbname=origen_codes_portal_clientes_test
#    SERVICE_REQUEST_DB_DSN=...dbname=origen_codes_portal_clientes_test
sudo systemctl reload php8.5-fpm
```

Si además hay que revertir código, restaurar el tar de la sección 3 con su nombre real. **No ejecutar `V10.002.down.sql`** ni borrar `origen_codes`. La base nueva puede conservarse; eliminarla requiere decisión separada y backup previo.

## 10. Criterios de aborto

| Situación | Acción |
| --- | --- |
| `current_database()` distinto de `origen_codes_portal_clientes` | Abortar antes de cualquier migración. |
| `os_customer` ya existe en la base nueva | Abortar; no re-ejecutar migraciones. |
| `origen_codes` con `os_customer` | Abortar y revisar. |
| Token real impreso o commiteado | Rotar de inmediato y abortar. |
| Verificador con fallos | Rollback y documentar. |
| Operación comercial creada en Invoice Ninja | Detener, documentar y escalar. |

## 11. Registro

Completar `informe-ejecucion-etapa-13.md` con fecha, hashes, actor, resultados y decisión final.
