# DDL propuesto — Fase 2 (estructuras lingüísticas)

> **ARTEFACTO DOCUMENTAL. NO APLICADO. NO EJECUTAR.**
>
> Esta propuesta deriva de los documentos aprobados en `cc803b5`, en particular
> `modelo-multilingue-propuesto.md` §5.1-§5.5,
> `decisiones-arquitectura-multilingue.md` (D-06, D-07, D-10, D-14, D-15, D-21,
> D-24, D-27, D-28, D-29, D-31, D-32, D-34, D-35, D-36, D-39, D-41) y
> `plan-migracion-multilingue.md` Fase 2.
>
> **Autorización:** Luis A. Uriarte, `2026-11-17`. Levanta la restricción para
> **generar** este DDL como documento en `docs/architecture/`. **No autoriza
> ejecutarlo** en la base de datos: para eso hace falta una autorización
> operativa específica del DDL de Fase 2.
>
> **Alcance:** solo seis tablas nuevas (`CREATE TABLE IF NOT EXISTS`) y sus
> índices. No modifica tablas existentes, no contiene `DROP`, `TRUNCATE`, `DELETE`
> ni backfill. La auditoría activa en esta fase es exclusivamente
> `os_field_review` (D-29). No se incluye ninguna operación D-34: si aparece un
> índice inválido o duplicado, se requiere autorización escrita individual (A-2).

## 1. Conveniones de la propuesta

- Aditiva e idempotente: `CREATE TABLE IF NOT EXISTS`,
  `CREATE INDEX ... IF NOT EXISTS`.
- `scope_release_id` usa `ON DELETE RESTRICT`, **nunca** `SET NULL` (D-06).
- Semántica conocida se crea `NOT NULL` con `DEFAULT` explícito: `provenance`,
  `review_status`, `language_evidence`, `content_hash`, `actor_type`,
  `occurred_at` (D-36). Se deja `NULL`: `source_language_code`,
  `source_reference`, `translator`, `reviewed_by`, `reviewed_at`, `valid_from`,
  `valid_to`, `notes`, `previous_value`, `new_value` y `application_user_id`/
  `importer_run_id` cuando no aplican.
- Los índices `CONCURRENTLY` se crean **fuera de transacción** (plan Fase 2).
- Verificación previa obligatoria (D-24/D-34): consultar `pg_class`/`pg_index`
  por nombre, comprobar `indisvalid`/`indisready`, comparar `pg_get_indexdef` y
  detectar duplicados de datos en índices únicos, **antes** de crear. Si existe
  un índice inválido o duplicado, detener y pedir autorización individual; no se
  propone aquí ningún `DROP INDEX`.
- Los tipos `INT` para `catalog_id`/`scope_release_id` coinciden con `SERIAL`
  (`integer`) de `os_catalog.id` y `os_catalog_release.id` en
  `sql/02_catalogs/origen_catalog_engine.sql`.

---

## 2. DDL de tablas nuevas (no aplicado)

### 2.1 `os_language` y `os_language_alias` (§5.1, D-15, D-27, D-39)

```sql
CREATE TABLE IF NOT EXISTS os_language (
    code           VARCHAR(10) PRIMARY KEY,
    display_name   VARCHAR(80) NOT NULL,
    primary_tag    VARCHAR(5)  NOT NULL,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,   -- seleccionable por el cliente
    is_source_only BOOLEAN NOT NULL DEFAULT FALSE,  -- solo es / es-MX
    CONSTRAINT chk_os_language_no_source_only_activo
        CHECK (NOT (is_active AND is_source_only))
);

CREATE TABLE IF NOT EXISTS os_language_alias (
    alias         VARCHAR(10) PRIMARY KEY,          -- 'es', 'pt'
    language_code VARCHAR(10) NOT NULL REFERENCES os_language(code)
);
```

> El `CHECK` traduce la regla D-39: «un mismo código no puede ser a la vez
> `is_active=true` e `is_source_only=true`». No se crea el alias `es-MX → es-AR`
> ni `es-ES → es-AR`. Los datos base (`es-AR`, `en`, `pt-BR` activos; `es`,
> `es-MX` source-only; alias `es→es-AR`, `pt→pt-BR`) son DML de siembra y
> **no se incluyen** en esta propuesta de DDL (§4).

### 2.2 `os_catalog_language` (§5.2)

```sql
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
```

Índices únicos parciales (uno por catálogo y rol). Se ejecutan fuera de
transacción con `CONCURRENTLY`:

```sql
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_ocl_default
    ON os_catalog_language (catalog_id) WHERE is_default;

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_ocl_fallback
    ON os_catalog_language (catalog_id) WHERE is_fallback;

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_ocl_bridge
    ON os_catalog_language (catalog_id) WHERE is_bridge;
```

> `is_bridge` es **opcional** (0 o 1 por catálogo); `is_default` e
> `is_fallback`, exactamente 1. No se agregan columnas de idioma a `os_catalog`.

### 2.3 `os_localized_text` (§5.3, D-14, D-35)

```sql
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
    source_language_code  VARCHAR(10) NULL,  -- SIN FK
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
    content_hash          TEXT NOT NULL,      -- D-31
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Índices (fuera de transacción, `CONCURRENTLY`):

```sql
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_olt_global
    ON os_localized_text (entity_type, entity_id, field_name, language_code)
    WHERE scope_release_id IS NULL;

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_olt_scoped
    ON os_localized_text (entity_type, entity_id, field_name, language_code, scope_release_id)
    WHERE scope_release_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_olt_identity
    ON os_localized_text (entity_type, entity_id, field_name, language_code);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_olt_value_trgm
    ON os_localized_text USING gin (value gin_trgm_ops);
```

> No se usa `UNIQUE (..., COALESCE(scope_release_id, 0))`: una restricción
> `UNIQUE` de tabla no acepta expresiones. `entity_type + entity_id` **no es una
> FK nativa**; se controla con trigger (§3) y privilegios/event trigger.

### 2.4 `os_translation_review` (§5.4, D-10, D-31, D-32)

```sql
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
    session_user          VARCHAR(80) NOT NULL, -- evidencia de respaldo, NO autor
    actor_identified      BOOLEAN NOT NULL DEFAULT FALSE,
    transaction_id        BIGINT,              -- txid de la transacción
    occurred_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes                 TEXT
);
```

> No se añaden columnas: la lista de columnas es la del contrato aprobado §5.4.
> D-41 se cumple registrando en `notes` el ámbito (`row_shared`/
> `field_individual`) y los campos afectados, además del `transaction_id`
> compartido. **Protección requerida (no expressionable en este DDL):** tabla *append-only*
> por permisos, sin `UPDATE`/`DELETE` para el rol de aplicación `origen_api`,
> propietario separado y privilegio de auditoría distinto. Auditoría
> **recuperable**, no inmutable: sin hash encadenado ni sello de tiempo externo.

### 2.5 `os_field_review` (§5.5, D-07, D-21, D-28, D-31, D-36)

```sql
CREATE TABLE IF NOT EXISTS os_field_review (
    target_table          VARCHAR(40) NOT NULL,
    target_id             BIGINT NOT NULL,
    field_name            VARCHAR(48) NOT NULL,
    language_code         VARCHAR(10) NOT NULL,
    scope_release_id      INT NULL REFERENCES os_catalog_release(id) ON DELETE RESTRICT,
    source_language_code  VARCHAR(10) NULL,
    language_evidence     VARCHAR(24) NOT NULL DEFAULT 'undetermined',
    provenance            VARCHAR(24) NOT NULL DEFAULT 'unknown',
    review_status         VARCHAR(20) NOT NULL DEFAULT 'unknown',
    source_reference      TEXT,
    reviewed_by           VARCHAR(120),
    reviewed_at           TIMESTAMPTZ,
    content_hash          TEXT NOT NULL,        -- D-31: ámbito field_individual
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- SIN PRIMARY KEY de cuatro columnas (D-21, D-28).

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_fr_global
    ON os_field_review (target_table, target_id, field_name, language_code)
    WHERE scope_release_id IS NULL;

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_fr_scoped
    ON os_field_review (target_table, target_id, field_name, language_code, scope_release_id)
    WHERE scope_release_id IS NOT NULL;
```

> Precedencia: release solicitado > global > fila > `unknown`. `content_hash`
> cubre solo el campo de esta fila (D-41 `field_individual`), frente al hash
> agregado `row_shared` de `os_catalog_item_version` (Fase 3).

---

## 3. Especificación de triggers (no se incluye cuerpo ejecutable)

El modelo aprobado describe el comportamiento pero **no proporciona el cuerpo
SQL completo de los triggers**; por coherencia con D-35 y la regla de no
inventar lógica no aprobada, esta propuesta registra la especificación y deja
su implementación a la autorización operativa de Fase 2:

| Trigger | Tabla | Requisito (fuente) |
|---|---|---|
| `BEFORE INSERT OR UPDATE` | `os_localized_text` | Verificar existencia de la entidad con `CASE(entity_type)`; validar `field_name` contra la lista por `entity_type` del modelo §5.3; declarar `entity_type`/`entity_id` inmutables (mover = baja + alta auditada); comprobar que `os_catalog_release.catalog_id` coincide con el catálogo de la entidad; `scope_release_id` obligatoriamente `NULL` para `substance`, `medicinal_product`, `product_package`, `nomenclador`, `vademecum` salvo declaración explícita (§5.3, D-06, D-14) |
| `BEFORE DELETE` en las 12 entidades | tablas reales del modelo §5.3 | Tomar `pg_advisory_xact_lock(hashtext(entity_type || ':' || entity_id))` y aplicar `RESTRICT` mientras existan traducciones; sin borrado en cascada automático (D-14, D-35) |
| `INSERT`/`UPDATE` | `os_localized_text` | `pg_advisory_xact_lock(hashtext(entity_type || ':' || entity_id))` y, si aplica, `pg_advisory_xact_lock(hashtext('release:' || scope_release_id))`; el índice único parcial arbitra inserciones simultáneas (D-35) |
| `BEFORE UPDATE` / `AFTER INSERT` / `AFTER DELETE` | `os_field_review` | Todo cambio de contenido: `review_status='unreviewed'`, limpiar `reviewed_by`/`reviewed_at`, regenerar `content_hash`, insertar `approval_invalidated` en `os_translation_review` con el ámbito (`row_shared`/`field_individual`) y campos afectados en `notes`, en la **misma transacción**; todo cambio de estado: evento `review_state_changed`; ambos con el mismo `transaction_id` (D-31, D-32, D-41) |

> El trigger de existencia **no se presenta como FK nativa**. No cubre
> `TRUNCATE` ni cambios de mapeo: se requieren además privilegios restringidos o
> event trigger y reconciliación periódica (D-14).

---

## 4. Fuera de esta propuesta

- **DML de siembra:** filas base de `os_language` (`es-AR`, `en`, `pt-BR`
  activos; `es`, `es-MX` con `is_source_only=true`) y alias (`es→es-AR`,
  `pt→pt-BR`). Requiere autorización específica; no se incluye.
- **D-40:** `source_language_code` de LOINC se deriva con
  `loinc_source_language(...)`; no se almacena como columna nueva. No aplica a
  Fase 2.
- **Fase 3:** columnas aditivas en `os_catalog_item_version`,
  `os_catalog_term`, etc.; hash agregado `row_shared` (D-41).
- **Auditoría de las otras 7 tablas:** se incorpora en Fase 3;
  `loinc_localized_text` en Fase 5 (D-29). En Fase 2 solo `os_field_review`.
- **D-34:** ningún `DROP INDEX`; exige autorización individual por índice.
- **Ejecución en base:** no autorizada por este documento.

## 5. Validaciones exigidas al cierre de Fase 2 (plan de migración)

3 idiomas activos; `is_bridge` opcional (0 o 1) e `is_default`/`is_fallback`
exactamente 1; 0 filas huérfanas; `indisvalid=true` y sin índices duplicados;
ambos pares de índices parciales presentes; locks ejercitados en prueba de
concurrencia; triggers presentes; auditoría protegida contra el rol de
aplicación; `es`/`es-MX` no seleccionables pero aceptados como
`effective_language` si hay fila aprobada; ninguna tabla existente alterada;
`SET NULL` ausente; ausencia de PK con `scope_release_id` opcional.

**Fin del artefacto documental. No aplicar ni ejecutar.**
