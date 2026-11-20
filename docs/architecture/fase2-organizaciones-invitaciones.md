# Fase 2 / M2 — Organizaciones, invitaciones y memberships de colaboradores

> **Estado: IMPLEMENTADO, APLICADO Y VERIFICADO en `origen_codes` (2026-11-19).**
>
> **Autorización recibida:** `Autorizo Fase 2 / M2` (2026-11-19).
>
> **Ejecución en VPS:** realizada por el responsable con
> `sudo -u postgres psql -v ON_ERROR_STOP=1`. La migración terminó en `COMMIT` y
> la verificación `SELECT`-only terminó en `ROLLBACK`, sin escribir datos.
>
> **Pendiente no bloqueante:** publicar el código PHP del panel y configurar
> `ADMIN_BASE_URL` y SMTP en el entorno.
>
> **Base:** M1 aplicado y verificado en `origen_codes` el 2026-11-19.
>
> **Alcance:** incorporación de colaboradores **solo por invitación**, sin
> autorregistro público, con organizaciones operativas, roles por organización,
> permisos por catálogo y trazabilidad completa.
>
> **No toca:** `os_catalog_*`, API pública, Browse Codes, importadores, fuentes
> originales ni catálogos publicados.
>
> **No incluye:** propuestas, revisión y publicación (Fases 3-5), hash de API
> keys (M6), estructuras lingüísticas de la Fase 2 multilingüe (documento
> distinto: `ddl-fase-2-propuesto.md`), deploy ni commit.

## 1. Resumen ejecutivo

M2 agrega la capa de gestión que M1 dejó preparada: las organizaciones ya
existen como tabla vacía, pero no tienen CRUD ni ciclo de vida; los memberships
existen, pero se resuelven como una unión global de roles; y `catalog_grant`
es global por usuario.

La propuesta es:

1. Convertir `organization` en una entidad operativa con código estable,
   contacto, estado y trazabilidad.
2. Incorporar colaboradores exclusivamente por invitación con token de un solo
   uso, hash en base y vencimiento.
3. Gestionar memberships por organización, con suspensión y revocación
   auditables, sin borrado físico.
4. Resolver permisos en un **contexto activo**: plataforma o una organización.
   Así un colaborador de la organización A no hereda permisos de la
   organización B.
5. Acotar los `catalog_grant` a la membership que los origina, conservando los
   grants globales existentes.
6. Agregar permisos administrativos nuevos, reservados a `superadmin` en esta
   fase, con techo de permisos para impedir escaladas.
7. Proteger el último superadministrador y registrar cada decisión en
   `os_admin.audit_log`.

## 2. Punto de partida (M1)

| Elemento | Estado en M1 | Necesidad M2 |
|---|---|---|
| `os_admin.organization` | Tabla creada, sin CRUD ni columnas de contacto/estado operativo. | Alta, edición, baja lógica, código estable, auditoría. |
| `os_admin.membership` | `user_id`, `organization_id`, `role_code`, `status`, fechas. | Trazabilidad de alta/baja, suspensión, revocación, protección del último superadmin. |
| `os_admin.catalog_grant` | Global por `user_id`; `UNIQUE (user_id, catalog_code, operation)`. | Grants globales y grants por membership, sin perder los existentes. |
| `os_admin.app_user` | Alta por CLI y reset por email. | Invitación con alta diferida; usuario existente acepta sin cambiar contraseña. |
| Invitaciones | No existen. | Tabla `invitation` + `invitation_grant`, token hasheado, un solo uso. |
| RBAC | `Rbac` puro + `RbacRepository` con unión global de memberships. | Contexto activo y permisos efectivos por organización. |
| Router `/admin/*` | Secciones exactas (`/admin`, `/admin/login`, …). | Rutas con identificadores y acciones (`/admin/organizations/{id}`). |
| Permisos | 10 permisos; `superadmin` con wildcard. | 4 permisos nuevos de gobernanza. |

## 3. Decisiones de diseño propuestas

Estas decisiones fueron propuestas en el acta y quedaron aceptadas al autorizarse
la implementación sin correcciones (`D1`–`D14`). Se conservan junto a su
alternativa como registro de la decisión.

| ID | Decisión | Recomendación | Alternativa |
|---|---|---|---|
| D1 | Alcance de los permisos | Contexto activo: plataforma o una organización. | Unión global de todos los memberships (más simple, pero filtra privilegios entre organizaciones). |
| D2 | Alcance de `catalog_grant` | Global (`membership_id NULL`) o por membership. | Mantener todos los grants globales por usuario. |
| D3 | Invitación a un usuario existente | Exigir login con el mismo correo y confirmar la invitación; nunca cambiar la contraseña por el token. | Permitir definir contraseña nueva con el token de invitación. |
| D4 | Quién gestiona en M2 | Solo `superadmin` recibe los permisos nuevos. | Delegar en `catalog_admin` desde el inicio. |
| D5 | Código de organización | Inmutable después del alta; el nombre sí es editable. | Permitir cambiar el código con auditoría. |
| D6 | Baja de organización | Bloquear si tiene memberships activos o invitaciones pendientes. | Revocar automáticamente memberships e invitaciones. |
| D7 | Vencimiento de invitación | 7 días por defecto; máximo 30. | 48 horas fijas. |
| D8 | Después de aceptar | Redirigir al login para que la persona ingrese con su contraseña. | Iniciar sesión automáticamente. |
| D9 | Verificación de correo | El token de invitación prueba el correo; se setea `email_verified_at`. | Enviar un segundo correo de verificación. |
| D10 | Validación de `catalog_code` | Validar contra `os_catalog.code` usando la conexión pública de solo lectura; nunca escribir en `os_catalog_*`. | Aceptar texto libre y validar recién al usar el catálogo. |
| D11 | Suspensión/revocación de membership | Revocar también las invitaciones pendientes de ese correo en esa organización. | Dejar las invitaciones vigentes. |
| D12 | Último superadministrador | Impedir suspender, revocar o desactivar al último `superadmin` global activo. | Permitir y recuperar por CLI. |
| D13 | Unicidad del nombre de organización | Solo el `code` es único; el nombre se indexa para búsqueda y la UI advierte duplicados. | Forzar nombre único por país. |
| D14 | URL base del panel | Agregar `ADMIN_BASE_URL` (fallback `WEB_BASE_URL`) y usarla en invitaciones y reset. | Usar solo `WEB_BASE_URL`. |

## 4. Modelo de autorización

### 4.1 Dos contextos

Un usuario puede tener:

- **Memberships globales** (`organization_id IS NULL`): capacidades de
  plataforma. Ejemplo: `superadmin`, `auditor`.
- **Memberships de organización** (`organization_id = X`): capacidades dentro
  de esa organización. Ejemplo: `collaborator` en el Hospital A, `reviewer` en
  el Ministerio B.

La sesión guarda `admin.active_org_id`:

- `NULL` = contexto **Plataforma**.
- Un entero = contexto de esa organización.

Al iniciar sesión se elige:

1. Plataforma, si el usuario tiene al menos un membership global activo.
2. Si no, la primera organización activa donde tenga membership.
3. Si no tiene ninguno, no puede entrar al panel.

El usuario puede cambiar de contexto desde el panel. El cambio se valida contra
sus memberships activos y se audita. Si la organización activa se desactiva o
el membership se revoca, el contexto guardado se invalida y se elige el
siguiente contexto válido; si no queda ninguno, se deniega el acceso. El
contexto también se limpia al cerrar sesión.

### 4.2 Permisos efectivos

En el contexto activo:

```text
permisos = permisos(memberships globales activos)
         ∪ permisos(memberships activos de la organización activa)
```

Los permisos de organizaciones no activas **no** se suman. Esto evita que un
colaborador de A use un rol de B mientras actúa en A.

`superadmin` conserva el wildcard `*` y, por lo tanto, acceso total en
cualquier contexto. El wildcard es una regla de código: no se guarda como fila
en `os_admin.permission`. Para que sea consistente en todos los controles,
`AuthService::current()` agrega `*` a los permisos efectivos cuando el usuario
tiene el rol `superadmin`. La tabla `role_permission` sigue teniendo los
permisos explícitos para reportes y auditoría.

### 4.3 Grants por catálogo

```text
grants efectivos = grants globales del usuario
                 ∪ grants de sus memberships globales
                 ∪ grants de sus memberships de la organización activa
```

Un grant con `allowed = false` sigue siendo una denegación explícita y gana
sobre cualquier permiso amplio, tal como ya implementa `Rbac::canAccessCatalog`.

### 4.4 Techo de permisos

Nadie puede otorgar un rol con permisos que no tiene. Reglas:

- `superadmin` puede otorgar cualquier rol.
- Un actor sin wildcard solo puede otorgar un rol si **todos** los permisos de
  ese rol están incluidos en sus permisos efectivos.
- Solo un `superadmin` puede otorgar el rol `superadmin`. La comprobación usa
  los roles del actor además de sus permisos, porque `superadmin` se representa
  con el wildcard de código y no con una fila `*` en la base.
- Solo se puede invitar o asignar dentro de una organización activa donde el
  actor tenga alcance (global o membership de esa organización).
- El actor no puede elevar su propio rol ni asignarse permisos nuevos.

### 4.5 Protección del último superadministrador

Antes de suspender, revocar o desactivar un membership global `superadmin`, el
servicio cuenta los `superadmin` globales activos. Si quedaría cero, la
operación se rechaza con un error explícito y se audita el intento.

### 4.6 Falla cerrada

- Si no se pueden leer roles/permisos/grants, `AuthService::current()` devuelve
  `null` y el panel redirige al login.
- Si se revoca o suspende un membership, el cambio impacta en la siguiente
  petición porque los permisos se recalculan siempre desde la base.
- Si se desactiva un usuario, `current()` lo rechaza y limpia la sesión local.
- Las sesiones no se borran físicamente; se revocan cuando corresponde y
  expiran solas.

## 5. Modelo de datos propuesto

> **Este DDL es un artefacto documental.** No se ejecutó ni se ejecutará sin la
> autorización `Autorizo Fase 2 / M2`. El archivo definitivo sería
> `sql/09_admin/fase2_gobernanza.sql`.

### 5.1 Organizaciones

```sql
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

CREATE INDEX IF NOT EXISTS idx_organization_name_lower
    ON os_admin.organization (lower(name));
```

Reglas de aplicación:

- `code`: `^[a-z0-9][a-z0-9-]{1,39}$`, obligatorio para altas nuevas,
  inmutable después del alta (D5). Es la clave estable de la organización.
- El nombre **no** se fuerza único: puede haber organizaciones homónimas en
  distintas jurisdicciones. La UI advierte si ya existe un nombre igual y pide
  confirmación explícita antes de crear otra (D13).
- `type`: valores controlados por la aplicación
  (`external`, `ministry`, `health_center`, `university`,
  `professional_council`, `vendor`, `ngo`, `other`). Se mantiene `VARCHAR` para
  no romper datos existentes.
- `country_code`: ISO 3166-1 alfa-2 en mayúsculas.
- `contact_email`: email válido o `NULL`.
- `is_active = false` + `deactivated_at` para baja lógica. **No hay borrado
  físico.**

### 5.2 Memberships

```sql
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
```

Reglas:

- `status`: `active`, `suspended`, `revoked` (ya existe el CHECK en M1).
- `valid_from` / `valid_to` siguen siendo opcionales; `RbacRepository` ya las
  respeta al calcular permisos.
- Suspender o revocar **no borra** la fila. Se completa `revoked_at`,
  `revoked_by_user_id` y `revoke_reason` cuando corresponde.
- Reasignar el mismo rol en la misma organización reactiva la fila existente
  (con auditoría), en lugar de duplicarla.

### 5.3 Grants por membership

```sql
ALTER TABLE os_admin.catalog_grant
    ADD COLUMN IF NOT EXISTS membership_id BIGINT
        REFERENCES os_admin.membership(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS created_by_user_id BIGINT
        REFERENCES os_admin.app_user(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- La unicidad global de M1 impide tener el mismo catálogo/operación en dos
-- memberships. Se reemplaza por dos índices parciales, sin borrar datos.
DO $$
DECLARE
    constraint_name record;
BEGIN
    FOR constraint_name IN
        SELECT conname
          FROM pg_constraint
         WHERE conrelid = 'os_admin.catalog_grant'::regclass
           AND contype = 'u'
           AND position('user_id, catalog_code, operation'
                        in pg_get_constraintdef(oid)) > 0
    LOOP
        EXECUTE format(
            'ALTER TABLE os_admin.catalog_grant DROP CONSTRAINT %I',
            constraint_name.conname
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
```

Integridad: el `membership_id` debe pertenecer al mismo `user_id`.

```sql
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
                'catalog_grant.membership_id no pertenece al usuario';
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
```

Los grants existentes de M1 quedan con `membership_id NULL` y siguen siendo
globales. No se backfillean ni se eliminan.

Revocar un grant no lo borra: se actualiza `allowed = false` y se audita el
antes/después. Reotorgarlo actualiza `allowed = true`.

### 5.4 Invitaciones

```sql
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
```

Reglas:

- Una sola invitación pendiente por correo y organización. Antes de crear una
  nueva, la aplicación revoca las vencidas (`revoke_reason = 'expired'`).
- `token_hash` guarda `sha256(token)`; el token en claro solo viaja en el
  correo y nunca se persiste ni se registra en auditoría.
- `expires_at` por defecto: ahora + 7 días; máximo 30 días.
- Una invitación aceptada o revocada no se reutiliza. Reenviar rota el token y
  extiende el vencimiento.
- No se permite invitar a un rol `superadmin` salvo que el actor sea
  `superadmin` (D4).
- No se permiten invitaciones globales en M2; siempre llevan organización.

### 5.5 Grants de la invitación

```sql
CREATE TABLE IF NOT EXISTS os_admin.invitation_grant (
    invitation_id  BIGINT NOT NULL
                   REFERENCES os_admin.invitation(id) ON DELETE RESTRICT,
    catalog_code   VARCHAR(50) NOT NULL,
    operation      VARCHAR(40) NOT NULL,
    allowed        BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (invitation_id, catalog_code, operation)
);
```

Al aceptar la invitación, cada fila se copia a `catalog_grant` con el
`membership_id` recién creado. Si la invitación se revoca, estas filas quedan
como evidencia y nunca se aplican.

`catalog_code` se valida contra `os_catalog.code` mediante la conexión pública
de solo lectura (D10). `operation` se valida contra la lista de operaciones
conocidas (`view`, `propose`, `edit_draft`, `review`, `approve`, `publish`).
No se agrega FK contra `os_catalog` para no dar privilegios nuevos a
`origen_admin` sobre `os_catalog_*`.

### 5.6 Permisos nuevos

```sql
INSERT INTO os_admin.permission (code, description) VALUES
    ('admin.orgs.manage',        'Gestionar organizaciones'),
    ('admin.invites.manage',     'Gestionar invitaciones de colaboradores'),
    ('admin.memberships.manage', 'Gestionar memberships y roles'),
    ('admin.grants.manage',      'Gestionar permisos por catálogo')
ON CONFLICT (code) DO NOTHING;

INSERT INTO os_admin.role_permission (role_code, permission_code)
SELECT 'superadmin', code
  FROM (VALUES
      ('admin.orgs.manage'),
      ('admin.invites.manage'),
      ('admin.memberships.manage'),
      ('admin.grants.manage')
  ) AS nuevos(code)
ON CONFLICT (role_code, permission_code) DO NOTHING;
```

En M2 solo `superadmin` recibe estos permisos. La delegación a
`catalog_admin` requiere antes un modelo de alcance por organización y una
autorización separada.

### 5.7 Privilegios de `origen_admin`

```sql
GRANT SELECT, INSERT, UPDATE ON os_admin.organization TO origen_admin;
GRANT SELECT, INSERT, UPDATE ON os_admin.membership TO origen_admin;
GRANT SELECT, INSERT, UPDATE ON os_admin.catalog_grant TO origen_admin;
GRANT SELECT, INSERT, UPDATE ON os_admin.invitation TO origen_admin;
GRANT SELECT, INSERT ON os_admin.invitation_grant TO origen_admin;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA os_admin TO origen_admin;
```

No se agrega ningún privilegio sobre `os_catalog_*`, `public` ni la API
pública. `origen_admin` sigue sin `DELETE` en las tablas de gobernanza.

## 6. Flujos operativos

### 6.1 Alta de organización

1. `POST /admin/organizations` con CSRF y permiso `admin.orgs.manage`.
2. Validar código, nombre, tipo, país, contacto y sitio web.
3. Insertar con `created_by_user_id` y `updated_by_user_id`.
4. Auditar `organization_created` con `after_state` (sin datos sensibles).
5. Redirigir a `/admin/organizations/{id}`.

### 6.2 Invitación de colaborador

1. `POST /admin/invitations` con CSRF y permiso `admin.invites.manage`.
2. Validar correo, organización activa, rol, techo de permisos y grants.
3. Revocar invitaciones vencidas del mismo correo/organización.
4. Rechazar si ya hay una invitación pendiente o un membership activo con ese
   rol.
5. Generar token de 32 bytes, guardar solo `sha256(token)`, insertar
   `invitation` y `invitation_grant` en una transacción, y auditar
   `invitation_created`.
6. Después del commit, enviar el correo con el vínculo
   `https://…/admin/invite?token=…`.
7. Si el correo falla, auditar `invitation_mail_failed`; la invitación queda
   pendiente y puede reenviarse.

### 6.3 Aceptación por una persona nueva

1. `GET /admin/invite?token=…` sin sesión, sobre HTTPS.
2. Validar formato del token, hash, vencimiento, estado y correo.
3. Mostrar organización, rol, vencimiento y formulario de alta (nombre,
   contraseña, confirmación).
4. `POST /admin/invite/accept` con CSRF.
5. En una transacción:
   - bloquear la invitación con `FOR UPDATE`;
   - revalidar;
   - crear `app_user` con `status = 'active'` y `email_verified_at = now()`;
   - crear `membership` activo en la organización;
   - copiar `invitation_grant` a `catalog_grant` con `membership_id`;
   - marcar `accepted_at` y `accepted_by_user_id`;
   - auditar `invitation_accepted` y `membership_created`.
6. Redirigir al login con un mensaje de éxito. No se inicia sesión
   automáticamente (D8).

### 6.4 Aceptación por un usuario existente

1. Si el correo ya pertenece a un usuario activo, la página de invitación pide
   iniciar sesión con ese correo.
2. Después del login, el usuario vuelve a `/admin/invite?token=…`.
3. Solo puede aceptar si el correo de la sesión coincide con el de la
   invitación.
4. La aceptación crea el membership y los grants, pero **no cambia la
   contraseña** (D3).
5. Si el usuario está suspendido, deshabilitado o no coincide, se rechaza con
   un mensaje genérico y se audita el motivo interno.

### 6.5 Reenvío y revocación

- Reenviar (`POST /admin/invitations/{id}/resend`): rota el token, extiende el
  vencimiento, incrementa `send_count` y audita `invitation_resent`. Se aplica
  un mínimo de 5 minutos entre reenvíos.
- Revocar (`POST /admin/invitations/{id}/revoke`): setea `revoked_at`,
  `revoked_by_user_id` y `revoke_reason`, y audita `invitation_revoked`.
- Ninguna de las dos acciones borra filas.

### 6.6 Gestión de memberships

- Asignar rol (`POST /admin/organizations/{id}/members`): busca o crea el
  membership, valida techo de permisos y audita `membership_created` o
  `membership_reactivated`.
- Suspender (`POST /admin/memberships/{id}/status` con `suspended`): audita
  `membership_suspended` y revoca invitaciones pendientes de ese correo en esa
  organización (D11).
- Revocar (`revoked`): setea campos de revocación, audita
  `membership_revoked` y revoca invitaciones pendientes.
- Reactivar (`active`): limpia `revoked_at`/`revoked_by_user_id` y audita
  `membership_reactivated`.
- El último `superadmin` global no puede quedar sin reemplazo (D12).
- Suspender un membership de organización no bloquea el acceso global del
  usuario. Para bloquear la cuenta completa se desactiva `app_user` o se revoca
  su membership global.

### 6.7 Cambio de contexto

1. `POST /admin/context` con CSRF.
2. Valor vacío = Plataforma; entero = organización.
3. Validar que el usuario tenga un membership activo en ese contexto.
4. Guardar `admin.active_org_id` en la sesión.
5. Auditar `organization_context_switched` con el contexto anterior y el nuevo.
6. Redirigir a `/admin`.

### 6.8 Baja de organización

1. `POST /admin/organizations/{id}/deactivate` con CSRF y permiso.
2. Rechazar si hay memberships activos o invitaciones pendientes (D6).
3. Setear `is_active = false`, `deactivated_at` y `updated_by_user_id`.
4. Auditar `organization_deactivated`.
5. Reactivar con `POST /admin/organizations/{id}/reactivate`; audita
   `organization_reactivated`.

### 6.9 URL base del panel

El panel puede vivir en un host distinto del portal público. Para que los
vínculos de invitación y de recuperación de contraseña apunten al lugar
correcto, M2 agrega `ADMIN_BASE_URL`:

```dotenv
ADMIN_BASE_URL=https://origen.ar
```

`Config::adminBaseUrl()` usa `ADMIN_BASE_URL` y, si está vacío, cae en
`WEB_BASE_URL`. Los enlaces se construyen siempre con esa base, nunca con el
host de la petición, para evitar *host header injection*.

## 7. Seguridad de las invitaciones

| Control | Implementación |
|---|---|
| Token | 32 bytes aleatorios; en base solo `sha256(token)`; comparación con `hash_equals`. |
| Un solo uso | `accepted_at` se setea en la misma transacción; un segundo intento falla. |
| Vencimiento | 7 días por defecto, máximo 30; reenviar extiende y rota el token. |
| Enumeración | La aceptación devuelve un mensaje genérico para token inválido, vencido, revocado o correo incorrecto. |
| Fuerza bruta | Límite por IP y por hash de token usando `os_admin.auth_throttle`. |
| CSRF | Token de sesión en todos los POST, incluida la aceptación. |
| HTTPS | `AdminGuard::requireSecure()` también en `/admin/invite`. |
| Cabeceras | `Cache-Control: no-store` y `Referrer-Policy: no-referrer` en páginas con token. |
| Correo | El vínculo solo viaja por SMTP; nunca se registra en auditoría ni en logs. |
| Usuario existente | Debe iniciar sesión con el mismo correo; el token no permite cambiar la contraseña. |
| Escalada | Techo de permisos, `superadmin` solo por `superadmin`, y auditoría de intentos. |
| Último superadmin | Protección explícita antes de suspender, revocar o desactivar. |
| Datos personales | La auditoría guarda IDs, rol, organización y correo del actor; no guarda tokens ni contraseñas. |

## 8. Rutas y UI

| Método | Ruta | Permiso | CSRF | Descripción |
|---|---|---|---|---|
| GET | `/admin` | `admin.view` | — | Panel con contexto activo y accesos. |
| GET | `/admin/organizations` | `admin.orgs.manage` | — | Listado de organizaciones. |
| POST | `/admin/organizations` | `admin.orgs.manage` | Sí | Alta. |
| GET | `/admin/organizations/{id}` | `admin.orgs.manage` | — | Detalle, memberships e invitaciones. |
| POST | `/admin/organizations/{id}` | `admin.orgs.manage` | Sí | Edición. |
| POST | `/admin/organizations/{id}/deactivate` | `admin.orgs.manage` | Sí | Baja lógica. |
| POST | `/admin/organizations/{id}/reactivate` | `admin.orgs.manage` | Sí | Reactivación. |
| POST | `/admin/organizations/{id}/members` | `admin.memberships.manage` | Sí | Asignar rol. |
| GET | `/admin/invitations` | `admin.invites.manage` | — | Invitaciones pendientes, vencidas y aceptadas. |
| POST | `/admin/invitations` | `admin.invites.manage` | Sí | Crear invitación. |
| POST | `/admin/invitations/{id}/resend` | `admin.invites.manage` | Sí | Reenviar y rotar token. |
| POST | `/admin/invitations/{id}/revoke` | `admin.invites.manage` | Sí | Revocar. |
| GET | `/admin/invite` | token válido | — | Página pública de aceptación. |
| POST | `/admin/invite/accept` | token válido | Sí | Aceptar invitación. |
| POST | `/admin/memberships/{id}/status` | `admin.memberships.manage` | Sí | Suspender, revocar o reactivar. |
| POST | `/admin/context` | sesión válida | Sí | Cambiar contexto. |

La navegación del layout `admin` muestra solo las secciones permitidas. El
selector de contexto aparece si el usuario tiene más de un contexto activo.
Las vistas nuevas usan las clases `admin-*` existentes y mantienen el panel
aislado de la navegación pública.

## 9. Auditoría

Todos los eventos usan `AuditLogger::record()` y la tabla append-only de M1.

| Acción | Entidad | Datos mínimos |
|---|---|---|
| `organization_created` | `organization` | id, código, nombre, tipo, país. |
| `organization_updated` | `organization` | id, campos modificados (antes/después). |
| `organization_deactivated` | `organization` | id, motivo. |
| `organization_reactivated` | `organization` | id. |
| `invitation_created` | `invitation` | id, organización, rol, vencimiento, cantidad de grants. |
| `invitation_resent` | `invitation` | id, vencimiento anterior/nuevo, `send_count`. |
| `invitation_revoked` | `invitation` | id, motivo. |
| `invitation_accepted` | `invitation` | id, usuario, organización, rol. |
| `invitation_accept_failed` | `invitation` | motivo interno (`invalid_token`, `expired`, `revoked`, `email_mismatch`). |
| `invitation_mail_failed` | `invitation` | id, motivo técnico acotado. |
| `membership_created` | `membership` | id, usuario, organización, rol, vigencia. |
| `membership_reactivated` | `membership` | id, usuario, organización, rol. |
| `membership_suspended` | `membership` | id, usuario, organización, rol, motivo. |
| `membership_revoked` | `membership` | id, usuario, organización, rol, motivo. |
| `catalog_grant_created` | `catalog_grant` | usuario, organización/membership, catálogo, operación, `allowed`. |
| `catalog_grant_updated` | `catalog_grant` | antes/después de `allowed`. |
| `catalog_grant_revoked` | `catalog_grant` | usuario, catálogo, operación, motivo. |
| `organization_context_switched` | `app_user` | contexto anterior y nuevo. |

Nunca se registran contraseñas, tokens, hashes de token, IPs ni user-agents en
texto plano. La auditoría no se actualiza ni se borra.

## 10. Migración y operación

### 10.1 Archivos a crear después de la aprobación

| Archivo | Contenido |
|---|---|
| `sql/09_admin/fase2_gobernanza.sql` | Migración aditiva y transaccional. |
| `sql/09_admin/verificacion_fase2.sql` | Verificación `SELECT`-only con `BEGIN READ ONLY` / `ROLLBACK`. |
| `sql/09_admin/README.md` | Actualización de reglas, requisitos y rollback. |

### 10.2 Reglas de la migración

- `BEGIN;` / `COMMIT;`.
- `CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`,
  `CREATE INDEX IF NOT EXISTS`, `INSERT ... ON CONFLICT DO NOTHING`.
- Sin `DROP TABLE`, `DROP COLUMN`, `TRUNCATE` ni `DELETE FROM`.
- El único reemplazo estructural es la constraint única de `catalog_grant`,
  necesaria para separar grants globales de grants por membership. No se
  borran datos: solo se sustituye la restricción por dos índices parciales.
- No toca `public`, `os_catalog_*`, importadores ni la API pública.
- `origen_admin` recibe solo los privilegios nuevos indicados en §5.7.

### 10.3 Operación

1. Backup verificado de `origen_codes` (D-16, D-25).
2. Revisar el SQL y ejecutarlo como superusuario con
   `psql -v ON_ERROR_STOP=1`.
3. Ejecutar `verificacion_fase2.sql` y archivar la salida.
4. Probar el flujo completo con una organización y un correo de prueba.
5. Recién después invitar colaboradores reales.

La sustitución de la constraint toma un bloqueo breve sobre
`os_admin.catalog_grant`. La tabla es pequeña y solo contiene grants
administrativos; aun así, la migración se ejecuta en ventana controlada.

### 10.4 Rollback

No se provee `DROP SCHEMA` ni borrado de tablas. Si la migración falla, la
transacción revierte todo. Si ya fue aplicada y debe deshacerse, se restaura el
backup o se prepara una migración correctiva aprobada por escrito. Las
invitaciones, memberships y eventos de auditoría se conservan como evidencia.

## 11. Criterios de aceptación

1. La migración se aplica sin errores y la verificación confirma columnas,
   índices, trigger de integridad, permisos y privilegios.
2. `origen_admin` no tiene privilegios nuevos sobre `os_catalog_*`.
3. Un `superadmin` puede crear una organización y el evento queda auditado.
4. No se permiten códigos duplicados; los nombres duplicados requieren
   confirmación explícita. No se permite borrar organizaciones.
5. Un `superadmin` puede invitar un correo a una organización con un rol y
   grants opcionales.
6. En base solo se guarda el hash del token; el token en claro no aparece en
   tablas, logs ni auditoría.
7. Una persona nueva acepta la invitación, queda activa, con
   `email_verified_at`, membership activo y grants aplicados.
8. Un usuario existente acepta después de iniciar sesión con el mismo correo,
   sin que cambie su contraseña.
9. Un token vencido, revocado, ya usado o de otro correo se rechaza con un
   mensaje genérico y queda auditado el motivo interno.
10. Reenviar rota el token: el vínculo anterior deja de funcionar.
11. Suspender o revocar un membership impacta en la siguiente petición y
    revoca las invitaciones pendientes de ese correo en esa organización.
12. El cambio de contexto altera los permisos efectivos: un rol de la
    organización A no se aplica en la organización B.
13. El último `superadmin` global no puede quedar suspendido, revocado ni
    desactivado.
14. La baja de una organización con memberships activos o invitaciones
    pendientes se rechaza.
15. La auditoría registra todos los eventos de §9 sin secretos.
16. Las pruebas `php tests/run.php` y `php -l` siguen en verde.
17. La API pública, Browse Codes, `os_catalog_*` e importadores no cambian.
18. La interfaz funciona en `es-AR`, `en` y `pt-BR`, con paridad de claves.
19. Los vínculos de invitación y reset usan `ADMIN_BASE_URL` y no el host de la
    petición.

## 12. Pruebas previstas

### 12.1 Pruebas puras

- `Rbac::canGrantRole()`: wildcard, subconjunto de permisos, rol desconocido y
  `superadmin`.
- `Rbac::canAccessCatalog()`: grants globales, grants por membership,
  denegación explícita y wildcard.
- `Rbac::hasPermission()`.
- `Token`: formato, hash y comparación.
- Validación de códigos de organización, emails, roles y operaciones.
- Parseo de rutas `/admin/organizations/{id}` y `/admin/invitations/{id}/...`.
- Aserciones sobre el SQL: tablas, columnas, índices, permisos, ausencia de
  escrituras a `os_catalog_*` y ausencia de borrados.
- Paridad de claves i18n en los cuatro archivos.

### 12.2 Pruebas HTTP locales sin base

- `/admin/organizations` sin sesión → 302 al login conservando `next`.
- `/admin/invitations` sin sesión → 302 al login.
- `/admin/invite?token=invalido` → página genérica, sin 500.
- `POST` sin CSRF → rechazo.
- Ruta desconocida → 404.
- Sin base configurada, los POST devuelven error genérico por PRG, no 500.

### 12.3 Pruebas en el VPS

- Crear organización de prueba.
- Invitar un correo de prueba y aceptar.
- Verificar en base: usuario, membership, grants, invitación aceptada y
  auditoría.
- Reutilizar el token: debe fallar.
- Reenviar: el token anterior debe fallar.
- Vencimiento, revocación y correo incorrecto.
- Cambio de contexto con un usuario de dos organizaciones.
- Suspender/revocar membership y comprobar que el permiso desaparece.
- Confirmar que no cambió ninguna fila de `os_catalog_*`.

## 13. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Filtración de privilegios entre organizaciones | Contexto activo y permisos recalculados por contexto; pruebas con dos organizaciones. |
| Robo o reutilización de un vínculo de invitación | Token de alta entropía, hash en base, un solo uso, vencimiento, rotación al reenviar, HTTPS y `no-referrer`. |
| Enumeración de correos | Mensajes genéricos en la aceptación; errores específicos solo para administradores autenticados. |
| Escalada de privilegios | Techo de permisos, `superadmin` solo por `superadmin`, auditoría de intentos. |
| Bloqueo total del panel | Protección del último `superadmin` y recuperación por CLI. |
| Invitaciones vencidas que bloquean nuevas | Revocación automática de vencidas antes de crear otra. |
| Falla de SMTP | La invitación queda pendiente, se audita la falla y se permite reenviar. |
| Reemplazo de la constraint de grants | Backup previo, transacción, verificación y ventana controlada. |
| Complejidad operativa | UI acotada, permisos solo para `superadmin` en M2 y pruebas de flujo completo. |
| Pérdida de historial | Sin borrado físico de organizaciones, memberships, invitaciones ni auditoría. |

## 14. Fuera de alcance

- Autorregistro público y aprobación posterior.
- Invitaciones globales sin organización.
- Delegación de la gestión a `catalog_admin` u otros roles.
- Propuestas, revisión, aprobación y publicación (Fases 3-5).
- Hash de `api_clients.api_key`, scopes y 429 (M6).
- Estructuras lingüísticas de la Fase 2 multilingüe.
- Deploy, commit o push.

## 15. Autorización y estado de entrega

El responsable autorizó la implementación con el texto exacto:

```text
Autorizo Fase 2 / M2
```

No se indicaron correcciones a las decisiones `D1`–`D14`, por lo que se aplicaron
las recomendaciones del acta.

La entrega en el repositorio comprende:

- `sql/09_admin/fase2_gobernanza.sql`: migración aditiva y transaccional,
  **aplicada y verificada** en `origen_codes` (2026-11-19);
- `sql/09_admin/verificacion_fase2.sql`: verificación `SELECT`-only con
  `BEGIN READ ONLY` / `ROLLBACK`;
- `sql/09_admin/README.md`: instrucciones de operación y rollback propuesto;
- código: `Config`, `Rbac`, `AuthService`, `GovernanceService`, repositorios,
  controladores, rutas, vistas y claves i18n en cuatro idiomas;
- `tests/run.php`: verificaciones M2 (2566 comprobaciones en total);
- ninguna modificación a `os_catalog_*`, API pública, Browse Codes ni
  importadores;
- sin commit, push ni deploy.

## 16. Verificación realizada y pasos restantes

La ejecución y la verificación ya se realizaron en `origen_codes`:

1. `sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes -f sql/09_admin/fase2_gobernanza.sql`
   → `COMMIT` sin errores.
2. `sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes -f sql/09_admin/verificacion_fase2.sql`
   → 15 columnas nuevas, 2 tablas, 12 índices, 0 constraints únicas en
   `catalog_grant` (esperado tras la sustitución por índices parciales), trigger
   de integridad activo, 4 permisos asignados solo a `superadmin`,
   `origen_admin` sin privilegios fuera de `os_admin` y trigger append-only
   activo. La sesión terminó en `ROLLBACK`.

### 16.1 Incidencia detectada en la prueba funcional (2026-11-19)

Al asignar un miembro, el panel respondió *"El servicio no está disponible"*.
La causa fue un desajuste entre código y esquema: `MembershipRepository`
referenciaba `updated_by_user_id` en el `INSERT` y en dos `UPDATE`, pero ni el
diseño (§5.2) ni la migración aplicada agregan esa columna a `membership`
(solo `organization` la tiene; `catalog_grant` tampoco). PostgreSQL devolvió
`column "updated_by_user_id" of relation "membership" does not exist` y la
transacción se revirtió, por lo que **no quedaron filas parciales**.

Corrección aplicada: se eliminaron esas tres referencias del repositorio; la
trazabilidad se conserva con `created_by_user_id`, `updated_at`,
`revoked_by_user_id` y, sobre todo, con `audit_log`. No requirió cambios en la
base ni una nueva migración. Se agregó una comprobación de regresión en
`tests/run.php` para impedir que el repositorio vuelva a referenciar columnas
inexistentes en `membership`.

Queda para el responsable:

1. Publicar el código PHP corregido en el VPS; la base no requiere cambios.
2. Definir `ADMIN_BASE_URL` y los parámetros `ADMIN_INVITE_*` en el entorno.
3. Configurar SMTP si se desea entrega real de invitaciones.
4. Probar en un correo de prueba: crear invitación, aceptar, reutilizar el token
   (debe fallar), reenviar (token anterior debe fallar) y cambiar de contexto.
5. Confirmar que no cambió ninguna fila de `os_catalog_*`.

### 16.2 Selección de grants con casillas

La asignación de miembros y las invitaciones exigían escribir a mano el código
de catálogo (`catalogo:operacion:allow|deny`). Se reemplazó por un selector
compacto y reutilizable (`portal/Views/admin/_grant_choices.php`) que lista los
catálogos activos desde `public.os_catalog`, con la conexión pública de solo
lectura. Cada catálogo muestra sus seis operaciones válidas del RBAC como
"chips" de un solo clic para **permitir**. Las denegaciones explícitas se
agrupan en una sección plegable, para no recargar la pantalla; la denegación
sigue prevaleciendo si ambas están marcadas. El editor de permisos de cada
colaborador también está plegado dentro de la tabla, de modo que la lista no
crece aunque haya muchos miembros.

El servicio conserva la validación original: cada valor se comprueba contra
`Rbac::isValidOperation()` y `CatalogReferenceRepository::exists()` antes de
persistirse, y se mantiene la ruta de compatibilidad con el formato de texto
para formularios que aún no se hayan actualizado. No hay cambios de esquema ni
de permisos. La edición de grants de un membership existente precarga los chips
según los grants vigentes.

Limitación conocida: desmarcar un chip en un membership existente no elimina el
grant (M2 no prevé baja de grants); para anularlo debe marcarse la operación en
la sección de denegaciones.

M1 y M2 quedan así cerrados en base. Las fases 3-6 siguen como propuestas no
ejecutadas.
