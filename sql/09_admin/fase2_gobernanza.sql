-- =====================================================================
-- M2 / Fase 2 — Gobernanza: organizaciones, invitaciones y memberships
-- =====================================================================
-- ARTEFACTO PROPUESTO — NO EJECUTAR SIN AUTORIZACIÓN OPERATIVA EXPLÍCITA.
-- Autorización de diseño: "Autorizo Fase 2 / M2" (2026-11-19).
-- Aditiva y transaccional. Requiere M1 aplicado previamente.
-- No modifica public, os_catalog_*, importadores, fuentes originales ni la
-- API pública. No contiene DROP TABLE, DROP COLUMN, TRUNCATE ni DELETE FROM.
-- La única sustitución estructural es la constraint única de catalog_grant,
-- reemplazada por dos índices parciales sin borrar filas.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Organizaciones: código estable, contacto, trazabilidad y baja lógica
-- ---------------------------------------------------------------------
ALTER TABLE os_admin.organization
    ADD COLUMN IF NOT EXISTS code VARCHAR(40),
    ADD COLUMN IF NOT EXISTS legal_name VARCHAR(240),
    ADD COLUMN IF NOT EXISTS website VARCHAR(254),
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS created_by_user_id BIGINT
        REFERENCES os_admin.app_user(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS updated_by_user_id BIGINT
        REFERENCES os_admin.app_user(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS uq_organization_code_lower
    ON os_admin.organization (lower(code))
    WHERE code IS NOT NULL;

-- El nombre no es único: puede haber homónimos en jurisdicciones distintas.
CREATE INDEX IF NOT EXISTS idx_organization_name_lower
    ON os_admin.organization (lower(name));

CREATE INDEX IF NOT EXISTS idx_organization_active
    ON os_admin.organization (is_active, id)
    WHERE is_active;

COMMENT ON COLUMN os_admin.organization.code IS
    'Clave estable inmutable de la organización; se valida ^[a-z0-9][a-z0-9-]{1,39}$.';

-- ---------------------------------------------------------------------
-- 2. Memberships: suspensión, revocación y trazabilidad sin borrado
-- ---------------------------------------------------------------------
ALTER TABLE os_admin.membership
    ADD COLUMN IF NOT EXISTS created_by_user_id BIGINT
        REFERENCES os_admin.app_user(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS revoked_by_user_id BIGINT
        REFERENCES os_admin.app_user(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS revoke_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_membership_org_status
    ON os_admin.membership (organization_id, status)
    WHERE organization_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_membership_user_status
    ON os_admin.membership (user_id, status);

CREATE INDEX IF NOT EXISTS idx_membership_global_superadmin
    ON os_admin.membership (status)
    WHERE organization_id IS NULL AND role_code = 'superadmin';

-- ---------------------------------------------------------------------
-- 3. Grants por membership (los grants globales de M1 quedan intactos)
-- ---------------------------------------------------------------------
ALTER TABLE os_admin.catalog_grant
    ADD COLUMN IF NOT EXISTS membership_id BIGINT
        REFERENCES os_admin.membership(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS created_by_user_id BIGINT
        REFERENCES os_admin.app_user(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Se sustituye UNIQUE (user_id, catalog_code, operation) por dos índices
-- parciales. No se elimina ninguna fila: los grants existentes quedan con
-- membership_id NULL y conservan su alcance global.
DO $$
DECLARE
    restriccion record;
BEGIN
    FOR restriccion IN
        SELECT conname
          FROM pg_constraint
         WHERE conrelid = 'os_admin.catalog_grant'::regclass
           AND contype = 'u'
           AND position('user_id, catalog_code, operation'
                        in pg_get_constraintdef(oid)) > 0
    LOOP
        EXECUTE format(
            'ALTER TABLE os_admin.catalog_grant DROP CONSTRAINT %I',
            restriccion.conname
        );
    END LOOP;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_catalog_grant_global
    ON os_admin.catalog_grant (user_id, catalog_code, operation)
    WHERE membership_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_catalog_grant_membership
    ON os_admin.catalog_grant (membership_id, catalog_code, operation)
    WHERE membership_id IS NOT NULL;

CREATE OR REPLACE FUNCTION os_admin.catalog_grant_membership_user()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.membership_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1
              FROM os_admin.membership m
             WHERE m.id = NEW.membership_id
               AND m.user_id = NEW.user_id
        ) THEN
            RAISE EXCEPTION
                'catalog_grant.membership_id no pertenece al usuario del grant';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_catalog_grant_membership_user
BEFORE INSERT OR UPDATE OF membership_id, user_id
ON os_admin.catalog_grant
FOR EACH ROW
EXECUTE FUNCTION os_admin.catalog_grant_membership_user();

-- ---------------------------------------------------------------------
-- 4. Invitaciones: token hasheado, un solo uso, vencimiento y revocación
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_admin.invitation (
    id                    BIGSERIAL PRIMARY KEY,
    email                 VARCHAR(254) NOT NULL,
    organization_id       BIGINT NOT NULL
                          REFERENCES os_admin.organization(id) ON DELETE RESTRICT,
    role_code             VARCHAR(40) NOT NULL
                          REFERENCES os_admin.role(code) ON DELETE RESTRICT,
    token_hash            VARCHAR(64) NOT NULL UNIQUE,
    invited_by_user_id    BIGINT NOT NULL
                          REFERENCES os_admin.app_user(id) ON DELETE RESTRICT,
    message               TEXT,
    expires_at            TIMESTAMPTZ NOT NULL,
    accepted_at           TIMESTAMPTZ,
    accepted_by_user_id   BIGINT
                          REFERENCES os_admin.app_user(id) ON DELETE RESTRICT,
    revoked_at            TIMESTAMPTZ,
    revoked_by_user_id    BIGINT
                          REFERENCES os_admin.app_user(id) ON DELETE RESTRICT,
    revoke_reason         VARCHAR(40),
    send_count            INT NOT NULL DEFAULT 0,
    last_sent_at          TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_invitation_pending
    ON os_admin.invitation (lower(email), organization_id)
    WHERE accepted_at IS NULL AND revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_invitation_email
    ON os_admin.invitation (lower(email), created_at DESC);

CREATE INDEX IF NOT EXISTS idx_invitation_expiry
    ON os_admin.invitation (expires_at)
    WHERE accepted_at IS NULL AND revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_invitation_org
    ON os_admin.invitation (organization_id, created_at DESC);

-- ---------------------------------------------------------------------
-- 5. Grants cerealizados en la invitación; se copian al aceptar
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_admin.invitation_grant (
    invitation_id  BIGINT NOT NULL
                   REFERENCES os_admin.invitation(id) ON DELETE RESTRICT,
    catalog_code   VARCHAR(50) NOT NULL,
    operation      VARCHAR(40) NOT NULL,
    allowed        BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (invitation_id, catalog_code, operation)
);

-- ---------------------------------------------------------------------
-- 6. Permisos nuevos de gobernanza (solo superadmin en M2)
-- ---------------------------------------------------------------------
INSERT INTO os_admin.permission (code, description) VALUES
    ('admin.orgs.manage',        'Gestionar organizaciones'),
    ('admin.invites.manage',     'Gestionar invitaciones de colaboradores'),
    ('admin.memberships.manage', 'Gestionar memberships y roles'),
    ('admin.grants.manage',      'Gestionar permisos por catálogo')
ON CONFLICT (code) DO NOTHING;

INSERT INTO os_admin.role_permission (role_code, permission_code)
SELECT 'superadmin', permisos.code
  FROM (VALUES
      ('admin.orgs.manage'),
      ('admin.invites.manage'),
      ('admin.memberships.manage'),
      ('admin.grants.manage')
  ) AS permisos(code)
ON CONFLICT (role_code, permission_code) DO NOTHING;

-- ---------------------------------------------------------------------
-- 7. Privilegios mínimos nuevos para origen_admin
-- ---------------------------------------------------------------------
REVOKE ALL ON os_admin.organization, os_admin.catalog_grant FROM PUBLIC;
REVOKE ALL ON os_admin.invitation, os_admin.invitation_grant FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE ON os_admin.organization TO origen_admin;
GRANT SELECT, INSERT, UPDATE ON os_admin.membership TO origen_admin;
GRANT SELECT, INSERT, UPDATE ON os_admin.catalog_grant TO origen_admin;
GRANT SELECT, INSERT, UPDATE ON os_admin.invitation TO origen_admin;
GRANT SELECT, INSERT ON os_admin.invitation_grant TO origen_admin;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA os_admin TO origen_admin;

COMMIT;

-- Fin del artefacto M2. No se ha ejecutado.
