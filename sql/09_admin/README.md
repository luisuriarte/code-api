# M1 — Esquema de identidad y RBAC (`os_admin`)

**Estado: PROPUESTO. NO EJECUTADO.**

Este directorio contiene la migración de la Fase 1 (identidad, autenticación,
RBAC y auditoría de acceso). Fue aprobada en el Acta M0 del 2026-11-19 como
diseño de referencia, pero **no se ha aplicado a `origen_codes`**.

## Reglas de la migración

- Aditiva: solo `CREATE SCHEMA`, `CREATE TABLE`, `CREATE INDEX`, `CREATE OR REPLACE FUNCTION/TRIGGER` e `INSERT ... ON CONFLICT DO NOTHING`.
- Transaccional: `BEGIN;` / `COMMIT;`.
- No toca `public`, `os_catalog_*`, importadores, API pública ni catálogos publicados.
- No contiene `DROP TABLE`, `DROP COLUMN`, `TRUNCATE` ni sentencias de borrado de datos terminológicos.
- El esquema `os_admin` es de metadatos administrativos: no guarda conceptos,
  versiones, términos ni valores clínicos. Todo apunta a `os_catalog*` existente.

## Contenido

| Archivo | Objetivo |
|---|---|
| `fase1_identidad.sql` | Esquema `os_admin`, tablas de usuario/sesión/roles/permisos/auditoría, rol `origen_admin` y datos base de roles y permisos. |
| `verificacion.sql` | Verificación `SELECT`-only dentro de `BEGIN READ ONLY` / `ROLLBACK`. |

## Si M1 ya está aplicado

La migración es idempotente y puede volver a ejecutarse completa. Si solo se
necesita corregir el permiso de alta de roles, alcanza con aplicar el `GRANT`
incremental como superusuario:

```sql
GRANT SELECT, INSERT ON os_admin.membership TO origen_admin;
```

Luego, si el usuario se creó pero el bootstrap falló antes de asignar roles:

```bash
php tools/php/admin_bootstrap.php --repair-existing
```

## Requisitos previos del operador

1. Backup verify de `origen_codes` (D-16, D-25).
2. Revisar el SQL y ejecutarlo como superusuario con `psql -v ON_ERROR_STOP=1`.
3. Asignar contraseña al rol `origen_admin` fuera de la migración y cargarla en
   `PORTAL_ADMIN_DB_PASS` desde el gestor de secretos.
4. Definir `ADMIN_PASSWORD_PEPPER` antes de crear el primer usuario.
5. Crear el primer superadministrador con `tools/php/admin_bootstrap.php`.
6. Verificar con `sql/09_admin/verificacion.sql` (solo `SELECT`).

## Rollback propuesto

No se provee `DROP SCHEMA`. Si la migración debe deshacerse antes de contener
datos, el operador debe hacerlo manualmente y por escrito, con aprobación
separada. Una vez creados usuarios o auditoría, la tabla `audit_log` debe
conservarse como evidencia histórica.

## Lo que NO cubre esta fase

- Organizaciones operativas, invitaciones y memberships de colaboradores (Fase 2).
- Propuestas, revisiones, comentarios y decisiones (Fases 3-4).
- Publicación atómica de releases y relaciones (Fases 5-6).
- Hash de `api_clients.api_key`, scopes y 429 (M6, requiere autorización aparte).
- Activación de D-31 y llenado de `os_catalog_language` (M7, diferido por Acta M0).
