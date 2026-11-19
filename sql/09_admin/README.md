# Esquema administrativo (`os_admin`)

## M1 — Identidad y RBAC

**Estado: APLICADO Y VERIFICADO en `origen_codes` (2026-11-19).**

La migración de la Fase 1 (identidad, autenticación, RBAC y auditoría de
acceso) fue aprobada en el Acta M0 y ejecutada por el responsable. La
verificación `SELECT`-only confirmó 11 tablas, el rol `origen_admin`, el trigger
append-only y los roles/permisos base.

## M2 — Gobernanza: organizaciones, invitaciones y memberships

**Estado: APLICADO Y VERIFICADO en `origen_codes` (2026-11-19).**

La migración `fase2_gobernanza.sql` fue ejecutada por el responsable como
`postgres` con `sudo -u postgres psql -v ON_ERROR_STOP=1` y terminó en `COMMIT`.
La verificación `SELECT`-only confirmó:

- 15 columnas nuevas de gobernanza en `organization`, `membership` y
  `catalog_grant`;
- las 2 tablas `invitation` e `invitation_grant`;
- 12 índices, incluidos los dos índices parciales que sustituyeron la constraint
  única global de `catalog_grant` (la consulta de constraints devolvió 0 filas,
  tal como se esperaba);
- el trigger `trg_catalog_grant_membership_user` activo;
- los 4 permisos nuevos asignados solo a `superadmin`;
- `origen_admin` sin privilegios fuera de `os_admin`;
- el trigger append-only `trg_audit_log_immutable` activo.

El diseño y las decisiones están en
[`docs/architecture/fase2-organizaciones-invitaciones.md`](../../docs/architecture/fase2-organizaciones-invitaciones.md).

Sigue pendiente de configuración operativa (no bloquea la base):

1. `ADMIN_BASE_URL` si el panel vive en un host distinto del portal.
2. SMTP si se quiere entrega real de las invitaciones.
3. Publicar el código PHP del panel en el VPS; la base ya está lista.

## Reglas de las migraciones

- Aditivas: solo `CREATE TABLE`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`,
  `CREATE INDEX IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION/TRIGGER` e
  `INSERT ... ON CONFLICT DO NOTHING`.
- Transaccionales: `BEGIN;` / `COMMIT;`.
- No tocan `public`, `os_catalog_*`, importadores, API pública ni catálogos
  publicados.
- No contienen `DROP TABLE`, `DROP COLUMN`, `TRUNCATE` ni borrado de datos.
- Única excepción estructural en M2: la constraint única global de
  `catalog_grant` se sustituye por dos índices parciales para separar grants
  globales de grants por membership. No se elimina ninguna fila.
- El esquema `os_admin` es de metadatos administrativos: no guarda conceptos,
  versiones, términos ni valores clínicos.

## Contenido

| Archivo | Objetivo |
|---|---|
| `fase1_identidad.sql` | M1: esquema `os_admin`, usuarios, sesiones, roles, permisos y auditoría. **Aplicado.** |
| `verificacion.sql` | Verificación `SELECT`-only de M1. |
| `fase2_gobernanza.sql` | M2: organizaciones, invitaciones, memberships y grants por membership. **Aplicado.** |
| `verificacion_fase2.sql` | Verificación `SELECT`-only de M2 (`BEGIN READ ONLY` / `ROLLBACK`). |

## Si M1 ya está aplicado

La migración M1 es idempotente. Si solo se necesita corregir el permiso de alta
de roles, alcanza con aplicar el `GRANT` incremental como superusuario:

```sql
GRANT SELECT, INSERT ON os_admin.membership TO origen_admin;
```

Luego, si el usuario se creó pero el bootstrap falló antes de asignar roles:

```bash
php tools/php/admin_bootstrap.php --repair-existing
```

## Operación de M2

```bash
# Como superusuario de PostgreSQL, desde la raíz del repositorio:
psql -v ON_ERROR_STOP=1 -d origen_codes -f sql/09_admin/fase2_gobernanza.sql
psql -v ON_ERROR_STOP=1 -d origen_codes -f sql/09_admin/verificacion_fase2.sql
```

Después de aplicarla:

1. Archivar la salida de la verificación.
2. Crear una organización de prueba y verificar el evento en `audit_log`.
3. Invitar un correo de prueba, aceptar la invitación y comprobar usuario,
   membership, grants e invitación aceptada.
4. Reutilizar el token: debe fallar. Reenviar: el token anterior debe fallar.
5. Probar cambio de contexto con un usuario de dos organizaciones.
6. Confirmar que no cambió ninguna fila de `os_catalog_*`.

La sustitución de la constraint de `catalog_grant` toma un bloqueo breve sobre
una tabla pequeña; aun así, ejecutar la migración en ventana controlada.

## Rollback propuesto

No se provee `DROP SCHEMA` ni borrado de tablas. Si la migración falla, la
transacción revierte todo. Si ya fue aplicada y debe deshacerse, se restaura el
backup o se prepara una migración correctiva aprobada por escrito. Las
invitaciones, memberships y eventos de auditoría se conservan como evidencia.

## Lo que NO cubre esta fase

- Autorregistro público ni invitaciones globales sin organización.
- Propuestas, revisiones, comentarios y decisiones (Fases 3-4 del panel). La
  Fase 5 del §16 preparó su modelo en `public` con
  `sql/08_arquitectura/fase4_gobernanza.sql`: actores referenciados a
  `os_admin.app_user`, auditoría append-only y sin grants de escritura. Conectar
  el panel a esas tablas requiere autorización nueva.
- Publicación atómica de releases y relaciones (Fases 5-6).
- Hash de `api_clients.api_key`, scopes y 429 (M6, requiere autorización aparte).
- Activación de D-31 y llenado de `os_catalog_language` (M7; el Acta M0 lo
  difirió, pero el 2026-11-19 se autorizó como Fase 3 del §16 y los artefactos
  están preparados en `sql/08_arquitectura/fase3_i18n.sql`).
