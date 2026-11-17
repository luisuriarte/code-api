-- =============================================================================
-- FASE 2 · Tablas lingüísticas nuevas
-- =============================================================================
-- Entorno de PRUEBAS con datos no reales. Base: origen_codes.
-- Aditivo e idempotente: CREATE TABLE IF NOT EXISTS.
-- NO contiene DROP, TRUNCATE ni DELETE de datos.
-- Ejecutar DENTRO de transacción (BEGIN/COMMIT): correcto en psql y DBeaver-CE.
-- Fuentes: modelo-multilingue-propuesto.md §5.1-§5.5; D-06, D-10, D-14,
--          D-21, D-27, D-28, D-29, D-31, D-36, D-39.
-- Tipos verificados: os_catalog.id y os_catalog_release.id son SERIAL (integer).
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 5.1 Catálogo de idiomas y alias (D-15, D-27, D-39)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_language (
    code           VARCHAR(10) PRIMARY KEY,
    display_name   VARCHAR(80) NOT NULL,
    primary_tag    VARCHAR(5)  NOT NULL,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,    -- seleccionable por el cliente
    is_source_only BOOLEAN NOT NULL DEFAULT FALSE,   -- solo etiquetas de origen
    CONSTRAINT chk_os_language_no_source_only_activo
        CHECK (NOT (is_active AND is_source_only))
);

-- 'es' y 'pt' son alias de resolver; NO se crea 'es-MX -> es-AR' (D-39).
CREATE TABLE IF NOT EXISTS os_language_alias (
    alias         VARCHAR(10) PRIMARY KEY,
    language_code VARCHAR(10) NOT NULL REFERENCES os_language(code)
);

-- ---------------------------------------------------------------------------
-- 5.2 Idiomas por catálogo (§5.2)
-- ---------------------------------------------------------------------------
-- No se agregan columnas de idioma a os_catalog.
CREATE TABLE IF NOT EXISTS os_catalog_language (
    catalog_id      INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    language_code   VARCHAR(10) NOT NULL REFERENCES os_language(code),
    is_default      BOOLEAN NOT NULL DEFAULT FALSE,
    is_fallback     BOOLEAN NOT NULL DEFAULT FALSE,
    is_bridge       BOOLEAN NOT NULL DEFAULT FALSE,
    coverage_status VARCHAR(20) NOT NULL DEFAULT 'partial'
        CHECK (coverage_status IN
               ('original','complete','partial','planned','undetermined')),
    PRIMARY KEY (catalog_id, language_code)
);

-- ---------------------------------------------------------------------------
-- 5.3 Texto localizado con identidad entera (D-14, D-35)
-- ---------------------------------------------------------------------------
-- entity_type + entity_id NO es FK nativa: se valida con trigger en 05.
-- scope_release_id usa RESTRICT, nunca SET NULL (D-06).
CREATE TABLE IF NOT EXISTS os_localized_text (
    id                    BIGSERIAL PRIMARY KEY,
    entity_type           VARCHAR(32) NOT NULL
        CHECK (entity_type IN (
            'catalog', 'catalog_category', 'catalog_release', 'fee_schedule',
            'pricing_unit', 'terminology_system', 'concept_mapping',
            'nomenclador', 'vademecum', 'substance', 'medicinal_product',
            'product_package')),
    entity_id             BIGINT NOT NULL,
    field_name            VARCHAR(48) NOT NULL,
    language_code         VARCHAR(10) NOT NULL REFERENCES os_language(code),
    value                 TEXT NOT NULL,
    source_language_code  VARCHAR(10),                -- SIN FK (D-36)
    language_evidence     VARCHAR(24) NOT NULL DEFAULT 'undetermined',
    provenance            VARCHAR(24) NOT NULL DEFAULT 'unknown',
    review_status         VARCHAR(20) NOT NULL DEFAULT 'unknown',
    source_reference      TEXT,
    translator            VARCHAR(120),
    reviewed_by           VARCHAR(120),
    reviewed_at           TIMESTAMPTZ,
    scope_release_id      INT NULL REFERENCES os_catalog_release(id) ON DELETE RESTRICT,
    valid_from            DATE,
    valid_to              DATE,
    content_hash          TEXT NOT NULL,               -- calculado en trigger 05
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 5.4 Historial de auditoría recuperable (D-10, D-31, D-32)
-- ---------------------------------------------------------------------------
-- "session_user" entre comillas: SESSION_USER es palabra reservada SQL;
-- se conserva el nombre del contrato y se usa como evidencia de respaldo,
-- nunca como identidad del autor (D-10).
CREATE TABLE IF NOT EXISTS os_translation_review (
    id                    BIGSERIAL PRIMARY KEY,
    target_table          VARCHAR(40) NOT NULL,
    target_id             BIGINT NOT NULL,
    field_name            VARCHAR(48) NOT NULL,
    language_code         VARCHAR(10) NOT NULL,
    event_type            VARCHAR(24) NOT NULL
        CHECK (event_type IN (
            'content_changed', 'approval_invalidated', 'approval_granted',
            'review_state_changed', 'new_translation',
            'new_official_publication', 'editorial_correction', 'deprecate')),
    action                VARCHAR(20) NOT NULL
        CHECK (action IN ('create','update','approve','invalidate','deprecate')),
    previous_value        TEXT,
    new_value             TEXT,
    source_language_code  VARCHAR(10),
    provenance            VARCHAR(24),
    review_status         VARCHAR(20),
    actor_type            VARCHAR(16) NOT NULL
        CHECK (actor_type IN ('user','importer','system','db_role')),
    application_user_id   VARCHAR(80),
    importer_run_id       VARCHAR(80),
    "session_user"        VARCHAR(80) NOT NULL,
    actor_identified      BOOLEAN NOT NULL DEFAULT FALSE,
    transaction_id        BIGINT,
    occurred_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes                 TEXT
);

-- ---------------------------------------------------------------------------
-- 5.5 Procedencia por campo clínico (D-07, D-21, D-28, D-31, D-36)
-- ---------------------------------------------------------------------------
-- Sin PRIMARY KEY de cuatro columnas: unicidad por índices parciales en 02.
CREATE TABLE IF NOT EXISTS os_field_review (
    target_table          VARCHAR(40) NOT NULL,
    target_id             BIGINT NOT NULL,
    field_name            VARCHAR(48) NOT NULL,
    language_code         VARCHAR(10) NOT NULL,
    scope_release_id      INT NULL REFERENCES os_catalog_release(id) ON DELETE RESTRICT,
    source_language_code  VARCHAR(10),
    language_evidence     VARCHAR(24) NOT NULL DEFAULT 'undetermined',
    provenance            VARCHAR(24) NOT NULL DEFAULT 'unknown',
    review_status         VARCHAR(20) NOT NULL DEFAULT 'unknown',
    source_reference      TEXT,
    reviewed_by           VARCHAR(120),
    reviewed_at           TIMESTAMPTZ,
    content_hash          TEXT NOT NULL,               -- calculado en trigger 05
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMIT;

-- Fin de Fase 2 · tablas.
