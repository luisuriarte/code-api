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

## Autorización

- Etapa 5: `docs/portal-clientes/acta-autorizacion-etapa-5.md`.
- Etapa 6: `docs/portal-clientes/acta-autorizacion-etapa-6.md`.

## Orden de migraciones

Aplicar: `V5.001 up` → `V6.001 up`.  
Revertir: `V6.001 down` → `V5.001 down`.

`V6.001` usa la función `os_customer.touch_updated_at()`, creada por `V5.001`. Por eso el `down` de V6 debe ejecutarse antes que el de V5.

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

**Prohibido:** ejecutar cualquiera de estos archivos en `origen_codes` productiva.
