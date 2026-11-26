# Manifiesto de producción real — Etapa 13

> Commit de referencia: el que contenga esta Etapa 13. Verificar con `git rev-parse HEAD` antes de publicar.
> Base operativa: `origen_codes_portal_clientes`. Base de lectura pública: `origen_codes` (sin cambios).

## 1. Archivos a subir al VPS

Cambios de código de esta etapa:

```text
portal/Config.php
portal/Views/home.php
portal/Views/partials/nav-links.php
portal/Views/partials/footer.php
.env.example
sql/10_portal_clientes/V5.001__os_customer_identity.up.sql
sql/10_portal_clientes/V5.001__os_customer_identity.down.sql
sql/10_portal_clientes/V6.001__invoice_ninja_links.up.sql
sql/10_portal_clientes/V6.001__invoice_ninja_links.down.sql
sql/10_portal_clientes/ETAPA13__preflight.sql
sql/10_portal_clientes/ETAPA13__verificacion_produccion.sql
tools/php/verificar_etapa13_produccion.php
docs/portal-clientes/acta-autorizacion-etapa-13.md
docs/portal-clientes/plan-etapa-13-produccion.md
docs/portal-clientes/informe-ejecucion-etapa-13.md
tests/run.php
tools/php/verificar_etapa11_portal_clientes.php
```

**No copiar `.env.example` sobre `.env`.**

## 2. Variables en `.env` del servidor

Solo valores, nunca en Git. Los secretos se escriben a mano en el VPS.

```ini
PORTAL_DB_DSN=pgsql:host=127.0.0.1;port=5432;dbname=origen_codes
PORTAL_CUSTOMER_DB_DSN=pgsql:host=127.0.0.1;port=5432;dbname=origen_codes_portal_clientes
PORTAL_CUSTOMER_DB_USER=origen_customer
PORTAL_CUSTOMER_DB_PASS=<solo en el servidor>
PORTAL_CUSTOMER_CREDENTIAL_DB_DSN=pgsql:host=127.0.0.1;port=5432;dbname=origen_codes
SERVICE_REQUEST_DB_DSN=pgsql:host=127.0.0.1;port=5432;dbname=origen_codes_portal_clientes
SERVICE_REQUEST_DB_USER=origen_med
SERVICE_REQUEST_DB_PASS=<solo en el servidor>
PORTAL_SERVICE_REQUEST_LINK_ENABLED=false

INVOICE_NINJA_BASE_URL=https://gestion.uriarte.ar
INVOICE_NINJA_API_TOKEN=<token real de solo lectura, solo en el servidor>
INVOICE_NINJA_ALLOW_TEST_CALLS=false
INVOICE_NINJA_ALLOW_LIVE_CALLS=true
```

`PORTAL_SERVICE_REQUEST_LINK_ENABLED` se pone en `true` recién después de verificar la base y el catálogo.

## 3. SQL que sí se ejecuta

Solo contra `origen_codes_portal_clientes` y en este orden:

```text
ETAPA13__preflight.sql
V5.001__os_customer_identity.up.sql
V6.001__invoice_ninja_links.up.sql
V7.001__services_entitlements.up.sql
V7.002__dentar_oftar_services.up.sql
V8.001__api_credentials.up.sql
V10.001__public_service_requests.up.sql
ETAPA13__verificacion_produccion.sql
```

## 4. SQL que NO se ejecuta

```text
V10.002__origen_med_no_superuser.up.sql   (ya aplicado; cluster-wide)
Cualquier *.down.sql                       (salvo rollback autorizado)
DEV_ONLY__reset_os_customer.sql            (borra auditoría)
Cualquier migración contra origen_codes
```

## 5. Verificación de modo Invoice Ninja

Sin imprimir el token:

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
