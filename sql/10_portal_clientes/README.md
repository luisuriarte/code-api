# Migraciones del portal de clientes

> **Estado:** preparadas para entorno de prueba. **No ejecutar en producción.**

## Archivos

- `V5.001__os_customer_identity.up.sql`: crea esquema, rol, tablas, índices, funciones, triggers, datos base de roles/permisos y grants.
- `V5.001__os_customer_identity.down.sql`: revierte los objetos creados, **sin borrar `os_customer.audit_log` ni su trigger**.
- `V5.001__os_customer_identity.verify.sql`: verificaciones `SELECT`-only.
- `V5.001__os_customer_identity.verify_rollback.sql`: comprueba que el rollback conservó la auditoría.
- `DEV_ONLY__reset_os_customer.sql`: reseteo completo **solo para desarrollo**; borra también la auditoría. No es una migración versionada.
- `V6.001__invoice_ninja_links.up.sql`: crea las tablas de vinculación y revisión de la Etapa 6. Solo identificadores y metadatos técnicos.
- `V6.001__invoice_ninja_links.down.sql`: revierte solo las tablas de la Etapa 6; re-ejecutable; no toca V5 ni la auditoría.
- `V6.001__invoice_ninja_links.verify.sql`: verificación `SELECT`-only de la Etapa 6.
- `V6.001__invoice_ninja_links.verify_rollback.sql`: verificación `SELECT`-only tras el `down` de V6.
- `V7.001__services_entitlements.up.sql`: catálogo técnico, solicitudes, contratos verificados, habilitaciones y operadores de la Etapa 7.
- `V7.001__services_entitlements.down.sql`: revierte solo la Etapa 7; conserva V5, V6 y la auditoría.
- `V7.001__services_entitlements.verify.sql`: verificación `SELECT`-only de la Etapa 7.
- `V7.001__services_entitlements.verify_rollback.sql`: verificación `SELECT`-only tras el `down` de V7.
- `V8.001__api_credentials.up.sql`: metadatos de credenciales de la API propia. No modifica `public.api_clients` ni guarda claves.
- `V8.001__api_credentials.down.sql`: revierte solo la Etapa 8; conserva V5, V6, V7 y la auditoría.
- `V8.001__api_credentials.verify.sql`: verificación `SELECT`-only de la Etapa 8.
- `V8.001__api_credentials.verify_rollback.sql`: verificación `SELECT`-only tras el `down` de V8.

## Autorización

- Etapa 5: `docs/portal-clientes/acta-autorizacion-etapa-5.md`.
- Etapa 6: `docs/portal-clientes/acta-autorizacion-etapa-6.md`.
- Etapa 7: `docs/portal-clientes/acta-autorizacion-etapa-7.md`.
- Etapa 8: `docs/portal-clientes/acta-autorizacion-etapa-8.md`.

## Orden de migraciones

Aplicar: `V5.001 up` → `V6.001 up` → `V7.001 up` → `V8.001 up`.  
Revertir: `V8.001 down` → `V7.001 down` → `V6.001 down` → `V5.001 down`.

`V6.001` y `V7.001` usan la función `os_customer.touch_updated_at()`, creada por `V5.001`. Por eso sus `down` deben ejecutarse antes que el de V5.

## Regla de ejecución

Solo en base independiente de prueba, por ejemplo:

```bash
sudo -u postgres psql -d origen_codes_portal_clientes_test \
  -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V5.001__os_customer_identity.up.sql
```

Antes de ejecutar:

1. Verificar backup.
2. Confirmar `current_database()`.
3. Confirmar que no existe `os_customer`.

Después de ejecutar:

```bash
sudo -u postgres psql -d origen_codes_portal_clientes_test \
  -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V5.001__os_customer_identity.verify.sql
```

Para revertir:

```bash
sudo -u postgres psql -d origen_codes_portal_clientes_test \
  -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V5.001__os_customer_identity.down.sql
```

La migración `down` es re-ejecutable: puede correrse varias veces seguidas sin fallar aunque el rol o las tablas ya no existan. Conserva `os_customer.audit_log`.

Para reiniciar por completo una base de desarrollo, incluida la auditoría, usar el script separado:

```bash
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/DEV_ONLY__reset_os_customer.sql
```

Ese script se niega a ejecutarse si `current_database()` es `origen_codes`. **No es una migración versionada** y nunca debe incluirse en un despliegue.

### Etapa 6

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V6.001__invoice_ninja_links.up.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V6.001__invoice_ninja_links.verify.sql
```

Rollback de V6, sin afectar las tablas de V5 ni la auditoría:

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V6.001__invoice_ninja_links.down.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V6.001__invoice_ninja_links.verify_rollback.sql
```

La verificación de V6 debe devolver **0 filas** y `columnas_prohibidas = 0`: no se guardan precios, importes, productos, facturas, pagos, correos ni razones sociales.

### Etapa 7

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.001__services_entitlements.up.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.001__services_entitlements.verify.sql
```

Rollback de V7, sin afectar V5, V6 ni la auditoría:

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.001__services_entitlements.down.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.001__services_entitlements.verify_rollback.sql
```

La verificación de V7 debe devolver `columnas_prohibidas = 0`, `capacidades_inexistentes = 0`, `servicios_verificados = 13`, `catalogo_solo_lectura = t` y `trigger_pago_verificado = 1`. El catálogo inicial contiene solo rutas `GET` documentadas en `api/index.php`, `docs/api/openapi-3.1.yaml`, `README-API.md`, `web/docs.php` y `portal/Router.php`.

La base rechaza por trigger cualquier habilitación en `active` cuyo contrato no tenga pago confirmado verificado. La identidad del superadministrador se valida en la aplicación, no en la base: el rol de base es compartido por la app.

El permiso de superadministrador **no se asigna automáticamente**. Después de aplicar `up`, un administrador de la base debe aprovisionar explícitamente cada operador, sin contraseñas ni datos personales:

```sql
INSERT INTO os_customer.operator (user_id, created_by)
VALUES (<id de app_user de prueba>, <id de app_user de prueba>);
```

Si se ejecuta el `down`, esa fila se elimina con la tabla y debe aprovisionarse de nuevo tras reaplicar `up`. Sin ese paso, ningún usuario puede verificar pagos ni habilitar servicios.

Los cuatro archivos de V7 llevan una guarda: se niegan a ejecutarse si `current_database()` no empieza con `origen_codes_portal_clientes`. Esto evita accidentes con variables de shell vacías.

**Prohibido:** ejecutar cualquiera de estos archivos en `origen_codes` productiva.
