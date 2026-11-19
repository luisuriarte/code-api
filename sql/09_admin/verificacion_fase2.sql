-- Verificación de M2 — SOLO LECTURA.
-- Ejecutar en psql contra origen_codes:
--   psql -d origen_codes -f sql/09_admin/verificacion_fase2.sql
-- Envuelve la sesión en READ ONLY y hace ROLLBACK: no puede escribir.

BEGIN READ ONLY;

SELECT current_database() AS base, current_user AS usuario;

-- 1. Columnas nuevas de gobernanza
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'os_admin'
  AND (
    (table_name = 'organization' AND column_name IN
        ('code', 'legal_name', 'website', 'notes',
         'created_by_user_id', 'updated_by_user_id', 'deactivated_at'))
    OR (table_name = 'membership' AND column_name IN
        ('created_by_user_id', 'updated_at', 'revoked_at',
         'revoked_by_user_id', 'revoke_reason'))
    OR (table_name = 'catalog_grant' AND column_name IN
        ('membership_id', 'created_by_user_id', 'updated_at'))
  )
ORDER BY table_name, column_name;

-- 2. Tablas de invitaciones
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'os_admin' AND table_name IN ('invitation', 'invitation_grant')
ORDER BY table_name;

-- 3. índices parciales y de integridad
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'os_admin'
  AND indexname IN (
      'uq_organization_code_lower', 'idx_organization_name_lower',
      'idx_organization_active', 'idx_membership_org_status',
      'idx_membership_user_status', 'idx_membership_global_superadmin',
      'uq_catalog_grant_global', 'uq_catalog_grant_membership',
      'uq_invitation_pending', 'idx_invitation_email',
      'idx_invitation_expiry', 'idx_invitation_org'
  )
ORDER BY indexname;

-- Debe quedar exactamente una constraint única global en catalog_grant.
SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'os_admin.catalog_grant'::regclass AND contype = 'u';

-- 4. Trigger de integridad membership_id <-> user_id
SELECT t.tgname, t.tgenabled, c.relname AS tabla
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'os_admin'
  AND t.tgname = 'trg_catalog_grant_membership_user';

-- 5. Permisos nuevos asignados a superadmin
SELECT p.code, p.description, count(rp.role_code) AS roles
FROM os_admin.permission p
LEFT JOIN os_admin.role_permission rp ON rp.permission_code = p.code
WHERE p.code IN (
    'admin.orgs.manage', 'admin.invites.manage',
    'admin.memberships.manage', 'admin.grants.manage'
)
GROUP BY p.code, p.description
ORDER BY p.code;

SELECT role_code, permission_code
FROM os_admin.role_permission
WHERE permission_code IN (
    'admin.orgs.manage', 'admin.invites.manage',
    'admin.memberships.manage', 'admin.grants.manage'
)
ORDER BY permission_code, role_code;

-- 6. Privilegios de origen_admin (no debe aparecer ninguna tabla os_catalog_*)
SELECT table_schema, table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE grantee = 'origen_admin'
GROUP BY table_schema, table_name
ORDER BY table_schema, table_name;

-- 7. Grants existentes: los globales conservan membership_id NULL
SELECT membership_id IS NULL AS es_global, count(*) AS cantidad
FROM os_admin.catalog_grant
GROUP BY 1 ORDER BY 1;

-- 8. Auditoría append-only sigue activa
SELECT t.tgname, t.tgenabled
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'os_admin' AND t.tgname = 'trg_audit_log_immutable';

ROLLBACK;
