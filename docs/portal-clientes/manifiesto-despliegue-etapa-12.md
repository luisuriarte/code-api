# Manifiesto de despliegue — Etapa 12

> Commit de referencia: `21940dd` (`HEAD` = `origin/main` al preparar esta etapa).
> Rango de cambios relevantes: `a184158..21940dd` (Etapas 10 y 11 más documentación de cierre).
> El responsable debe confirmar que el VPS despliega exactamente ese `HEAD` o uno posterior revisado.

## 1. Archivos que sí se publican en el VPS

Código de ejecución del sitio público y del portal de clientes:

```text
portal/Config.php
portal/Controllers/ServiceRequestController.php
portal/Repositories/PublicServiceRequestRepository.php
portal/Repositories/ServiceRequestDatabase.php
portal/Router.php
portal/Services/InvoiceNinjaCatalogService.php
portal/Services/ServiceRequestService.php
portal/Views/service-request.php
portal/translations/messages.es-AR.yaml
portal/translations/messages.en.yaml
portal/translations/messages.pt-BR.yaml
portal-clientes/Config.php
portal-clientes/README.md
```

El resto del árbol `portal/`, `portal-clientes/`, `web/`, `api/` y `vendor/` se considera ya desplegado en las etapas previas y no debe reemplazarse ciegamente. Si el VPS está detrás de `HEAD`, publicar el árbol completo después de revisar el diff.

## 2. Archivos que se suben solo como referencia/verificación

No afectan la ejecución, pero deben estar disponibles para el runbook:

```text
.env.example
tests/run.php
tools/php/verificar_etapa11_portal_clientes.php
tools/php/verificar_etapa12_despliegue.php
docs/portal-clientes/*.md
```

**No copiar `.env.example` sobre `.env`.**

## 3. SQL que NO se ejecuta en producción

Estos archivos están correctamente protegidos por `current_database() NOT LIKE 'origen_codes_portal_clientes%'` y **deben permanecer así**:

```text
sql/10_portal_clientes/V5.*   (etapas anteriores)
sql/10_portal_clientes/V6.*   (etapas anteriores)
sql/10_portal_clientes/V7.*   (etapas anteriores)
sql/10_portal_clientes/V7.002__dentar_oftar_services.*
sql/10_portal_clientes/V8.*   (etapas anteriores)
sql/10_portal_clientes/V10.001__public_service_requests.*
sql/10_portal_clientes/V10.002__origen_med_no_superuser.*
sql/10_portal_clientes/ETAPA11__verificacion_solicitudes.sql
```

No ejecutar ninguno contra `origen_codes`. `V10.001` crea las tablas de la Solicitud de Servicios en la base aislada; `V10.002` es cluster-wide y ya fue aplicada.

## 4. Variables de entorno a revisar en el VPS

Solo en `.env`, con permisos restringidos:

```ini
PORTAL_DB_DSN=pgsql:host=127.0.0.1;port=5432;dbname=origen_codes
PORTAL_CUSTOMER_DB_DSN=pgsql:host=127.0.0.1;port=5432;dbname=origen_codes_portal_clientes_test
PORTAL_CUSTOMER_CREDENTIAL_DB_DSN=pgsql:host=127.0.0.1;port=5432;dbname=origen_codes
SERVICE_REQUEST_DB_DSN=pgsql:host=127.0.0.1;port=5432;dbname=origen_codes_portal_clientes_test
SERVICE_REQUEST_DB_USER=origen_med
SERVICE_REQUEST_DB_PASS=<configurado en el servidor>
INVOICE_NINJA_BASE_URL=https://gestion.uriarte.ar
INVOICE_NINJA_ALLOW_TEST_CALLS=true
INVOICE_NINJA_API_TOKEN=<token de prueba, nunca real>
RATE_REQUEST=5
CONTACT_EMAIL=med@origen.ar
PORTAL_CUSTOMER_BILLING_URL=<vacío o https://...>
```

Si `PORTAL_CUSTOMER_BILLING_URL` está configurada, debe comenzar con `https://`. Nunca se deriva del encabezado `Host`.
