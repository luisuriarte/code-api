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
- `V7.002__dentar_oftar_services.up.sql`: agrega DENTAR y OFTAR al catálogo técnico; dos filas, sin precios ni UVR.
- `V7.002__dentar_oftar_services.down.sql`: elimina solo esas dos filas; no toca V7.001 ni las habilitaciones.
- `V7.002__dentar_oftar_services.verify.sql`: verificación `SELECT`-only de V7.002.
- `V7.002__dentar_oftar_services.verify_rollback.sql`: verificación `SELECT`-only tras el `down` de V7.002.
- `V8.001__api_credentials.up.sql`: metadatos de credenciales de la API propia. No modifica `public.api_clients` ni guarda claves.
- `V8.001__api_credentials.down.sql`: revierte solo la Etapa 8; conserva V5, V6, V7 y la auditoría.
- `V8.001__api_credentials.verify.sql`: verificación `SELECT`-only de la Etapa 8.
- `V8.001__api_credentials.verify_rollback.sql`: verificación `SELECT`-only tras el `down` de V8.
- `V10.001__public_service_requests.up.sql`: dos tablas para la Solicitud de Servicios pública; sin precios ni importes.
- `V10.001__public_service_requests.down.sql`: elimina solo esas dos tablas; sin cascada.
- `V10.001__public_service_requests.verify.sql`: verificación `SELECT`-only de V10.001.
- `V10.001__public_service_requests.verify_rollback.sql`: verificación `SELECT`-only tras el `down` de V10.001.
- `V10.002__origen_med_no_superuser.up.sql`: retira `SUPERUSER` a `origen_med` para que los ACL por objeto sean efectivos. **Cambio cluster-wide.**
- `V10.002__origen_med_no_superuser.down.sql`: restaura `SUPERUSER`; solo para deshacer la corrección con autorización.
- `V10.002__origen_med_no_superuser.verify.sql`: verificación `SELECT`-only de V10.002.
- `V10.002__origen_med_no_superuser.verify_rollback.sql`: verificación `SELECT`-only tras el `down` de V10.002.

## Autorización

- Etapa 5: `docs/portal-clientes/acta-autorizacion-etapa-5.md`.
- Etapa 6: `docs/portal-clientes/acta-autorizacion-etapa-6.md`.
- Etapa 7: `docs/portal-clientes/acta-autorizacion-etapa-7.md`.
- Adenda DENTAR/OFTAR: `docs/portal-clientes/acta-autorizacion-etapa-9.md`.
- Etapa 8: `docs/portal-clientes/acta-autorizacion-etapa-8.md`.
- Etapa 10: `docs/portal-clientes/acta-autorizacion-etapa-10.md`.

## Orden de migraciones

Aplicar: `V5.001 up` → `V6.001 up` → `V7.001 up` → `V7.002 up` → `V8.001 up` → `V10.001 up` → `V10.002 up`.  
Revertir: `V10.002 down` → `V10.001 down` → `V8.001 down` → `V7.002 down` → `V7.001 down` → `V6.001 down` → `V5.001 down`.

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

### Adenda DENTAR y OFTAR (V7.002)

Autorizada en `docs/portal-clientes/acta-autorizacion-etapa-9.md`. Se aplica **después** de V7.001 y antes de V8.001:

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.002__dentar_oftar_services.up.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.002__dentar_oftar_services.verify.sql
```

La verificación debe devolver `servicios_dentar_oftar = 2`, `servicios_verificados = 15`, `capacidades_inexistentes = 0`, `columnas_prohibidas = 0` y `catalogo_solo_lectura = t`. No se crean tablas, columnas, grants ni precios; solo dos filas en `os_customer.service`.

Rollback antes del `down` de V7.001:

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.002__dentar_oftar_services.down.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V7.002__dentar_oftar_services.verify_rollback.sql
```

El rollback debe devolver `servicios_dentar_oftar_restantes = 0` y `servicios_verificados = 13`. Si ya existen habilitaciones o relaciones de servicio para DENTAR/OFTAR, el `DELETE` falla por la restricción de integridad: no se borra en cascada.

### Etapa 10 — Solicitud de Servicios (V10.001)

Se aplica **después** de V8.001. No modifica V5, V6, V7, V7.002 ni V8:

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.001__public_service_requests.up.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.001__public_service_requests.verify.sql
```

Esperado después de V10.002: `tablas_v10 = 2`, `columnas_prohibidas = 0`, `servicios_verificados = 15`, `capacidades_inexistentes = 0`, `usa_esquema = t`, `lee_solicitudes = t`, `escribe_solicitudes = t`, `sin_update = t`, `sin_delete = t`, `escribe_items = t`, `secuencia_solicitudes = t`, `sin_insert_en_servicios = t`, `sin_insert_en_habilitaciones = t` y `total_tablas = 23`.

Si `origen_med` todavía tiene `SUPERUSER`, los cuatro valores negativos (`sin_update`, `sin_delete`, `sin_insert_en_servicios`, `sin_insert_en_habilitaciones`) saldrán `f` aunque los ACL sean correctos: un superusuario tiene implícitamente todos los privilegios. Ese fue el resultado observado en la primera verificación. Aplicar V10.002 y volver a verificar.

`origen_med` recibe `USAGE` en `os_customer` y `SELECT, INSERT` solo en las dos tablas nuevas, más `USAGE` en sus secuencias. No recibe `UPDATE`, `DELETE` ni acceso a `service`, `entitlement` ni al resto del esquema. No se usa `ALTER DEFAULT PRIVILEGES`.

Rollback **antes** del `down` de V8.001:

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.001__public_service_requests.down.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.001__public_service_requests.verify_rollback.sql
```

Esperado: `tablas_v10_restantes = 0`, `servicios_verificados = 15` y `total_tablas = 21`. No hay `CASCADE`: si existen filas relacionadas, el `DROP` falla y debe revisarse antes de forzar cualquier acción.

### Corrección de privilegios — V10.002

Se aplica **después** de V10.001, una vez verificadas las tablas. Retira el atributo `SUPERUSER` de `origen_med`, autorizado en el acta de la Etapa 10:

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.002__origen_med_no_superuser.up.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.002__origen_med_no_superuser.verify.sql
```

Esperado: `sin_superuser = t`, `usa_esquema = t`, `lee_solicitudes = t`, `escribe_solicitudes = t`, `sin_update = t`, `sin_delete = t`, `sin_insert_en_servicios = t`, `sin_insert_en_habilitaciones = t`, `tablas_v10 = 2` y `total_tablas = 23`.

**`ALTER ROLE` es cluster-wide:** aunque se ejecute con `-d "$TEST_DB"`, el cambio de atributo afecta también a `origen_codes`. Está autorizado para este caso; no repetirlo en otra ocasión sin autorización nueva. Después del cambio conviene repetir las comprobaciones HTTP públicas (`/health`, páginas de catálogo y browse) para confirmar que los `SELECT` existentes siguen alcanzando.

Rollback **antes** del `down` de V10.001, y solo si se decide deshacer la corrección:

```bash
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.002__origen_med_no_superuser.down.sql
sudo -u postgres psql -d "$TEST_DB" -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.002__origen_med_no_superuser.verify_rollback.sql
```

Esperado: `superuser_restorado = t`.

**Prohibido:** ejecutar cualquiera de estos archivos en `origen_codes` productiva.
