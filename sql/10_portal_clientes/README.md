# Migraciones del portal de clientes

> **Estado:** preparadas para entorno de prueba. **No ejecutar en producción.**

## Archivos

- `V5.001__os_customer_identity.up.sql`: crea esquema, rol, tablas, índices, funciones, triggers, datos base de roles/permisos y grants.
- `V5.001__os_customer_identity.down.sql`: revierte los objetos creados, **sin borrar `os_customer.audit_log` ni su trigger**.
- `V5.001__os_customer_identity.verify.sql`: verificaciones `SELECT`-only.
- `V5.001__os_customer_identity.verify_rollback.sql`: comprueba que el rollback conservó la auditoría.

## Autorización

Ver `docs/portal-clientes/acta-autorizacion-etapa-5.md`.

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

**Prohibido:** ejecutar en `origen_codes` productiva.
