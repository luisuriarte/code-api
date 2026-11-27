-- =====================================================================
-- M1 / Fase 1 — Identidad, autenticación, RBAC y auditoría de acceso
-- =====================================================================
-- Histórico: ARTEFACTO PROPUESTO, aprobado como diseño por Acta M0 (2026-11-19).
-- Estado real: APLICADO Y VERIFICADO en `origen_codes` el 2026-11-19, con Acta M0 y autorización expresa del responsable para Fase 1 / M1.
-- Verificador: comprobación `SELECT`-only que confirmó 11 tablas, el rol `origen_admin`, el trigger append-only y los roles/permisos base (ver `sql/09_admin/README.md`).
-- No reejecutar sin autorización nueva. El SQL histórico se conserva sin reescritura.
-- Aditivo, transaccional y aislado en el esquema os_admin.
-- No modifica public, os_catalog_*, importadores ni la API pública.
-- =====================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS os_admin;

COMMENT ON SCHEMA os_admin IS
    'Metadatos de gobernanza (Fase 1). No contiene conceptos ni versiones clínicas.';

-- ---------------------------------------------------------------------
-- 1. Catálogos de roles y permisos
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_admin.role (
    code        VARCHAR(40) PRIMARY KEY,
    name        VARCHAR(120) NOT NULL,
    description TEXT,
    is_system   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_admin.permission (
    code        VARCHAR(80) PRIMARY KEY,
    description TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_admin.role_permission (
    role_code       VARCHAR(40) NOT NULL REFERENCES os_admin.role(code) ON DELETE RESTRICT,
    permission_code VARCHAR(80) NOT NULL REFERENCES os_admin.permission(code) ON DELETE RESTRICT,
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (role_code, permission_code)
);

-- ---------------------------------------------------------------------
-- 2. Usuarios, organizaciones y memberships
--    Las organizaciones se crean ahora para no rehacer claves foráneas en Fase 2.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_admin.organization (
    id            BIGSERIAL PRIMARY KEY,
    name          VARCHAR(180) NOT NULL,
    type          VARCHAR(40) NOT NULL DEFAULT 'external',
    country_code  VARCHAR(2) NOT NULL DEFAULT 'AR',
    contact_email VARCHAR(254),
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_admin.app_user (
    id                 BIGSERIAL PRIMARY KEY,
    email              VARCHAR(254) NOT NULL,
    password_hash      TEXT NOT NULL,
    full_name          VARCHAR(180) NOT NULL,
    status             VARCHAR(20) NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active', 'suspended', 'invited', 'disabled')),
    email_verified_at  TIMESTAMPTZ,
    failed_login_count INT NOT NULL DEFAULT 0,
    locked_until       TIMESTAMPTZ,
    last_login_at      TIMESTAMPTZ,
    last_login_ip_hash VARCHAR(64),
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_app_user_email ON os_admin.app_user (email);
CREATE UNIQUE INDEX IF NOT EXISTS uq_app_user_email_lower ON os_admin.app_user (lower(email));

CREATE TABLE IF NOT EXISTS os_admin.membership (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES os_admin.app_user(id) ON DELETE RESTRICT,
    organization_id BIGINT REFERENCES os_admin.organization(id) ON DELETE RESTRICT,
    role_code       VARCHAR(40) NOT NULL REFERENCES os_admin.role(code) ON DELETE RESTRICT,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'suspended', 'revoked')),
    valid_from      DATE,
    valid_to        DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, organization_id, role_code)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_membership_global
    ON os_admin.membership (user_id, role_code) WHERE organization_id IS NULL;

CREATE TABLE IF NOT EXISTS os_admin.catalog_grant (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT NOT NULL REFERENCES os_admin.app_user(id) ON DELETE CASCADE,
    catalog_code VARCHAR(50) NOT NULL,
    operation    VARCHAR(40) NOT NULL,
    allowed      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, catalog_code, operation)
);

-- ---------------------------------------------------------------------
-- 3. Sesiones, reset de contraseña y aceleración de login
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_admin.session (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES os_admin.app_user(id) ON DELETE CASCADE,
    token_hash      VARCHAR(64) NOT NULL UNIQUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at      TIMESTAMPTZ,
    ip_hash         VARCHAR(64),
    user_agent_hash VARCHAR(64)
);

CREATE INDEX IF NOT EXISTS idx_session_user ON os_admin.session (user_id);
CREATE INDEX IF NOT EXISTS idx_session_active ON os_admin.session (token_hash, expires_at)
    WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS os_admin.password_reset (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES os_admin.app_user(id) ON DELETE CASCADE,
    token_hash      VARCHAR(64) NOT NULL UNIQUE,
    requested_ip_hash VARCHAR(64),
    expires_at      TIMESTAMPTZ NOT NULL,
    used_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_admin.auth_throttle (
    key_hash          VARCHAR(64) PRIMARY KEY,
    attempts          INT NOT NULL DEFAULT 0,
    window_started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    blocked_until     TIMESTAMPTZ
);

-- ---------------------------------------------------------------------
-- 4. Auditoría de acceso (append-only)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_admin.audit_log (
    id              BIGSERIAL PRIMARY KEY,
    actor_user_id   BIGINT,
    actor_email     VARCHAR(254),
    action          VARCHAR(60) NOT NULL,
    entity_type     VARCHAR(60),
    entity_id       VARCHAR(80),
    catalog_code    VARCHAR(50),
    before_state    JSONB,
    after_state     JSONB,
    reason          TEXT,
    ip_hash         VARCHAR(64),
    user_agent_hash VARCHAR(64),
    request_id      VARCHAR(80),
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_actor ON os_admin.audit_log (actor_user_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_action ON os_admin.audit_log (action, occurred_at DESC);

CREATE OR REPLACE FUNCTION os_admin.audit_log_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'os_admin.audit_log es append-only';
END;
$$;

CREATE OR REPLACE TRIGGER trg_audit_log_immutable
BEFORE UPDATE OR DELETE ON os_admin.audit_log
FOR EACH ROW EXECUTE FUNCTION os_admin.audit_log_immutable();

-- ---------------------------------------------------------------------
-- 5. Rol de aplicación y privilegios mínimos
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'origen_admin') THEN
        CREATE ROLE origen_admin LOGIN;
    END IF;
END
$$;

REVOKE ALL ON ALL TABLES IN SCHEMA os_admin FROM PUBLIC;
REVOKE ALL ON SCHEMA os_admin FROM PUBLIC;

GRANT USAGE ON SCHEMA os_admin TO origen_admin;

GRANT SELECT, INSERT, UPDATE ON
    os_admin.app_user,
    os_admin.session,
    os_admin.password_reset,
    os_admin.auth_throttle
TO origen_admin;

GRANT SELECT ON
    os_admin.role,
    os_admin.permission,
    os_admin.role_permission,
    os_admin.organization,
    os_admin.catalog_grant
TO origen_admin;

-- El alta de usuarios asigna roles globales durante el bootstrap.
GRANT SELECT, INSERT ON os_admin.membership TO origen_admin;

-- La auditoría solo permite lectura e inserción: el trigger impide UPDATE/DELETE.
GRANT SELECT, INSERT ON os_admin.audit_log TO origen_admin;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA os_admin TO origen_admin;

-- ---------------------------------------------------------------------
-- 6. Datos base: roles y permisos (idempotente)
-- ---------------------------------------------------------------------
INSERT INTO os_admin.role (code, name, description, is_system) VALUES
    ('superadmin',  'Superadministrador', 'Acceso total a la administración', TRUE),
    ('catalog_admin', 'Administrador de catálogos', 'Gestiona catálogos asignados', TRUE),
    ('editor',      'Editor terminológico', 'Propone y edita borradores', TRUE),
    ('reviewer',    'Revisor', 'Revisa propuestas ajenas', TRUE),
    ('publisher',   'Publicador', 'Publica propuestas aprobadas', TRUE),
    ('collaborator','Colaborador', 'Propone cambios sobre catálogos habilitados', TRUE),
    ('auditor',     'Auditor', 'Solo lectura de auditoría', TRUE),
    ('viewer',      'Consulta', 'Solo lectura de catálogos habilitados', TRUE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO os_admin.permission (code, description) VALUES
    ('admin.view',             'Ver el panel de administración'),
    ('admin.users.manage',     'Gestionar usuarios y estados'),
    ('admin.roles.manage',     'Gestionar roles y permisos'),
    ('catalog.view',           'Ver catálogos habilitados'),
    ('catalog.propose',        'Enviar propuestas de cambio'),
    ('catalog.edit_draft',     'Editar borradores propios'),
    ('catalog.review',         'Revisar propuestas ajenas'),
    ('catalog.approve',        'Aprobar propuestas revisadas'),
    ('catalog.publish',        'Publicar versiones aprobadas'),
    ('audit.view',             'Consultar auditoría de acceso')
ON CONFLICT (code) DO NOTHING;

INSERT INTO os_admin.role_permission (role_code, permission_code) VALUES
    ('superadmin',   'admin.view'),
    ('superadmin',   'admin.users.manage'),
    ('superadmin',   'admin.roles.manage'),
    ('superadmin',   'catalog.view'),
    ('superadmin',   'catalog.propose'),
    ('superadmin',   'catalog.edit_draft'),
    ('superadmin',   'catalog.review'),
    ('superadmin',   'catalog.approve'),
    ('superadmin',   'catalog.publish'),
    ('superadmin',   'audit.view'),
    ('catalog_admin','admin.view'),
    ('catalog_admin','catalog.view'),
    ('catalog_admin','catalog.propose'),
    ('catalog_admin','catalog.edit_draft'),
    ('catalog_admin','catalog.review'),
    ('catalog_admin','catalog.publish'),
    ('catalog_admin','audit.view'),
    ('editor',       'admin.view'),
    ('editor',       'catalog.view'),
    ('editor',       'catalog.propose'),
    ('editor',       'catalog.edit_draft'),
    ('reviewer',     'admin.view'),
    ('reviewer',     'catalog.view'),
    ('reviewer',     'catalog.review'),
    ('reviewer',     'catalog.approve'),
    ('reviewer',     'audit.view'),
    ('publisher',    'admin.view'),
    ('publisher',    'catalog.view'),
    ('publisher',    'catalog.publish'),
    ('publisher',    'audit.view'),
    ('collaborator', 'admin.view'),
    ('collaborator', 'catalog.view'),
    ('collaborator', 'catalog.propose'),
    ('auditor',      'admin.view'),
    ('auditor',      'audit.view'),
    ('viewer',       'admin.view'),
    ('viewer',       'catalog.view')
ON CONFLICT (role_code, permission_code) DO NOTHING;

COMMIT;

-- Fin del artefacto M1. Estado: aplicado y verificado en `origen_codes` (2026-11-19).
