-- V5.001__os_customer_identity.up.sql
-- Etapa 5: identidad y organizaciones del portal de clientes.
-- Autorizado por docs/portal-clientes/acta-autorizacion-etapa-5.md.
-- SOLO entorno de prueba/base independiente. NO ejecutar en producción.
-- No usa ALTER DEFAULT PRIVILEGES. Los privilegios se otorgan objeto por objeto.

BEGIN;

DO $role$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'origen_customer') THEN
        CREATE ROLE origen_customer LOGIN;
    END IF;
END
$role$;

DO $grant$
BEGIN
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO origen_customer', current_database());
END
$grant$;

CREATE SCHEMA IF NOT EXISTS os_customer;
REVOKE ALL ON SCHEMA os_customer FROM PUBLIC;
GRANT USAGE ON SCHEMA os_customer TO origen_customer;

-- ---------------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS os_customer.organization (
    id                BIGSERIAL PRIMARY KEY,
    code              VARCHAR(64)  NOT NULL UNIQUE,
    legal_name        VARCHAR(200) NOT NULL,
    display_name      VARCHAR(200),
    tax_id_normalized VARCHAR(32),
    country           VARCHAR(2)   NOT NULL DEFAULT 'AR',
    kind              VARCHAR(40)  NOT NULL DEFAULT 'institution',
    status            VARCHAR(20)  NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended', 'deactivated')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_customer.app_user (
    id                 BIGSERIAL PRIMARY KEY,
    email              VARCHAR(254) NOT NULL,
    full_name          VARCHAR(200) NOT NULL,
    password_hash      TEXT         NOT NULL,
    status             VARCHAR(20)  NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'active', 'suspended')),
    email_verified_at  TIMESTAMPTZ,
    failed_logins      INTEGER      NOT NULL DEFAULT 0,
    locked_until       TIMESTAMPTZ,
    last_login_at      TIMESTAMPTZ,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS app_user_email_ci
    ON os_customer.app_user (lower(email));

CREATE TABLE IF NOT EXISTS os_customer.role (
    id          BIGSERIAL PRIMARY KEY,
    code        VARCHAR(64) NOT NULL UNIQUE,
    label       VARCHAR(120) NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_customer.permission (
    id          BIGSERIAL PRIMARY KEY,
    code        VARCHAR(80) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_customer.role_permission (
    role_id       BIGINT NOT NULL REFERENCES os_customer.role(id) ON DELETE CASCADE,
    permission_id BIGINT NOT NULL REFERENCES os_customer.permission(id) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS os_customer.membership (
    id            BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NOT NULL REFERENCES os_customer.organization(id) ON DELETE RESTRICT,
    user_id       BIGINT NOT NULL REFERENCES os_customer.app_user(id) ON DELETE RESTRICT,
    role_code     VARCHAR(64) NOT NULL REFERENCES os_customer.role(code) ON DELETE RESTRICT,
    status        VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended', 'revoked')),
    valid_from    TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to      TIMESTAMPTZ,
    invited_by    BIGINT REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    accepted_at   TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organization_id, user_id)
);

CREATE TABLE IF NOT EXISTS os_customer.invitation (
    id            BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NOT NULL REFERENCES os_customer.organization(id) ON DELETE RESTRICT,
    email         VARCHAR(254) NOT NULL,
    role_code     VARCHAR(64) NOT NULL REFERENCES os_customer.role(code) ON DELETE RESTRICT,
    token_hash    CHAR(64) NOT NULL UNIQUE,
    status        VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'revoked', 'expired')),
    expires_at    TIMESTAMPTZ NOT NULL,
    invited_by    BIGINT REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    accepted_by   BIGINT REFERENCES os_customer.app_user(id) ON DELETE SET NULL,
    accepted_at   TIMESTAMPTZ,
    revoked_at    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_customer.session (
    id                    BIGSERIAL PRIMARY KEY,
    user_id               BIGINT NOT NULL REFERENCES os_customer.app_user(id) ON DELETE CASCADE,
    token_hash            CHAR(64) NOT NULL UNIQUE,
    context_organization_id BIGINT REFERENCES os_customer.organization(id) ON DELETE SET NULL,
    ip_hash               CHAR(64),
    ua_hash               CHAR(64),
    expires_at            TIMESTAMPTZ NOT NULL,
    revoked_at            TIMESTAMPTZ,
    last_seen_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_customer.password_reset (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES os_customer.app_user(id) ON DELETE CASCADE,
    token_hash  CHAR(64) NOT NULL UNIQUE,
    ip_hash     CHAR(64),
    ua_hash     CHAR(64),
    expires_at  TIMESTAMPTZ NOT NULL,
    used_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS os_customer.auth_throttle (
    id               BIGSERIAL PRIMARY KEY,
    bucket           VARCHAR(40) NOT NULL,
    subject_hash     CHAR(64) NOT NULL,
    attempts         INTEGER NOT NULL DEFAULT 0,
    window_started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    blocked_until    TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (bucket, subject_hash, window_started_at)
);

CREATE TABLE IF NOT EXISTS os_customer.audit_log (
    id             BIGSERIAL PRIMARY KEY,
    occurred_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    actor_user_id  BIGINT,
    organization_id BIGINT,
    action         VARCHAR(80) NOT NULL,
    object_type    VARCHAR(60),
    object_id      VARCHAR(80),
    result         VARCHAR(20) NOT NULL DEFAULT 'success'
        CHECK (result IN ('success', 'failure', 'denied')),
    ip_hash        CHAR(64),
    ua_hash        CHAR(64),
    request_id     VARCHAR(64),
    context        JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS membership_user_idx
    ON os_customer.membership (user_id, status);
CREATE INDEX IF NOT EXISTS membership_org_idx
    ON os_customer.membership (organization_id, status);
CREATE INDEX IF NOT EXISTS invitation_email_idx
    ON os_customer.invitation (lower(email), status);
CREATE INDEX IF NOT EXISTS session_user_idx
    ON os_customer.session (user_id, revoked_at);
CREATE INDEX IF NOT EXISTS audit_occurred_idx
    ON os_customer.audit_log (occurred_at DESC, id DESC);

-- ---------------------------------------------------------------------------
-- Funciones y triggers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION os_customer.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END
$fn$;

DROP TRIGGER IF EXISTS trg_organization_touch ON os_customer.organization;
CREATE TRIGGER trg_organization_touch
    BEFORE UPDATE ON os_customer.organization
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

DROP TRIGGER IF EXISTS trg_app_user_touch ON os_customer.app_user;
CREATE TRIGGER trg_app_user_touch
    BEFORE UPDATE ON os_customer.app_user
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

DROP TRIGGER IF EXISTS trg_membership_touch ON os_customer.membership;
CREATE TRIGGER trg_membership_touch
    BEFORE UPDATE ON os_customer.membership
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

DROP TRIGGER IF EXISTS trg_auth_throttle_touch ON os_customer.auth_throttle;
CREATE TRIGGER trg_auth_throttle_touch
    BEFORE UPDATE ON os_customer.auth_throttle
    FOR EACH ROW EXECUTE FUNCTION os_customer.touch_updated_at();

CREATE OR REPLACE FUNCTION os_customer.audit_log_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
    RAISE EXCEPTION 'os_customer.audit_log es append-only';
END
$fn$;

DROP TRIGGER IF EXISTS trg_audit_log_immutable ON os_customer.audit_log;
CREATE TRIGGER trg_audit_log_immutable
    BEFORE UPDATE OR DELETE ON os_customer.audit_log
    FOR EACH ROW EXECUTE FUNCTION os_customer.audit_log_immutable();

-- ---------------------------------------------------------------------------
-- Datos base de roles y permisos
-- ---------------------------------------------------------------------------

INSERT INTO os_customer.role (code, label, description) VALUES
    ('organization_owner', 'Owner de organización', 'Administrador inicial de la organización.'),
    ('organization_admin', 'Administrador de organización', 'Gestiona usuarios y configuración técnica autorizada.'),
    ('technical_admin', 'Administrador técnico', 'Gestiona credenciales y documentación técnica.'),
    ('developer', 'Desarrollador', 'Consulta documentación y usa servicios autorizados.'),
    ('viewer', 'Observador', 'Solo lectura de información autorizada.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO os_customer.permission (code, description) VALUES
    ('org.read', 'Leer datos de la organización.'),
    ('org.update', 'Actualizar datos de la organización.'),
    ('member.read', 'Listar miembros.'),
    ('member.invite', 'Invitar miembros.'),
    ('member.update', 'Cambiar roles de miembros.'),
    ('member.revoke', 'Revocar membresías.'),
    ('service.read', 'Ver servicios habilitados.'),
    ('credential.read', 'Ver metadatos de credenciales.'),
    ('credential.create', 'Crear credenciales.'),
    ('credential.rotate', 'Rotar credenciales.'),
    ('credential.revoke', 'Revocar credenciales.'),
    ('docs.read', 'Leer documentación técnica.'),
    ('usage.read', 'Ver consumo real cuando exista medición.'),
    ('billing.link.read', 'Ver metadatos del vínculo comercial.'),
    ('support.create', 'Crear solicitudes de soporte.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO os_customer.role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM os_customer.role r
JOIN os_customer.permission p ON (
    (r.code = 'organization_owner' AND p.code IN (
        'org.read','org.update','member.read','member.invite','member.update',
        'member.revoke','service.read','docs.read','billing.link.read','support.create'))
    OR (r.code = 'organization_admin' AND p.code IN (
        'org.read','org.update','member.read','member.invite','member.update',
        'member.revoke','service.read','docs.read','billing.link.read','support.create'))
    OR (r.code = 'technical_admin' AND p.code IN (
        'org.read','member.read','service.read','credential.read','credential.create',
        'credential.rotate','credential.revoke','docs.read','usage.read','support.create'))
    OR (r.code = 'developer' AND p.code IN (
        'org.read','member.read','service.read','credential.read','docs.read'))
    OR (r.code = 'viewer' AND p.code IN (
        'org.read','member.read','service.read','docs.read'))
)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Privilegios: objeto por objeto. Sin ALTER DEFAULT PRIVILEGES.
-- ---------------------------------------------------------------------------

DO $priv$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'organization','app_user','membership','invitation','session',
        'password_reset','auth_throttle'
    ] LOOP
        EXECUTE format('REVOKE ALL ON TABLE os_customer.%I FROM PUBLIC', t);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE os_customer.%I TO origen_customer', t);
    END LOOP;

    FOREACH t IN ARRAY ARRAY['role','permission','role_permission'] LOOP
        EXECUTE format('REVOKE ALL ON TABLE os_customer.%I FROM PUBLIC', t);
        EXECUTE format('GRANT SELECT ON TABLE os_customer.%I TO origen_customer', t);
    END LOOP;

    EXECUTE format('REVOKE ALL ON TABLE os_customer.%I FROM PUBLIC', 'audit_log');
    EXECUTE format('GRANT SELECT, INSERT ON TABLE os_customer.%I TO origen_customer', 'audit_log');

    FOREACH t IN ARRAY ARRAY[
        'organization_id_seq','app_user_id_seq','role_id_seq','permission_id_seq',
        'membership_id_seq','invitation_id_seq','session_id_seq',
        'password_reset_id_seq','auth_throttle_id_seq','audit_log_id_seq'
    ] LOOP
        EXECUTE format('REVOKE ALL ON SEQUENCE os_customer.%I FROM PUBLIC', t);
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE os_customer.%I TO origen_customer', t);
    END LOOP;
END
$priv$;

COMMIT;
