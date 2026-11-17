# Modelo multilingüe propuesto — Origen Salud

> Estado: **propuesta de diseño lista para aprobación independiente**. No se ha
> ejecutado ninguna migración, no se ha modificado PostgreSQL, la API, el sitio
> web ni los importadores. La referencia de decisiones es
> [`decisiones-arquitectura-multilingue.md`](decisiones-arquitectura-multilingue.md).
> Complementa [`auditoria-internacionalizacion.md`](auditoria-internacionalizacion.md)
> y [`plan-migracion-multilingue.md`](plan-migracion-multilingue.md).
>
> Idiomas objetivo: `es-AR`, `en`, `pt-BR` (BCP-47). Todo lo que aparece como
> `CREATE`/`ALTER`/`UPDATE` es **propuesta**, no código aplicado.
>
> Numeración de decisiones usada en este documento: **D-05 = SNOMED/CIE-10**,
> **D-09 = DENTAR**, **D-14 = `os_localized_text`**. Las aclaraciones finales
> **D-27 a D-38** son parte del contrato de este modelo y prevalecen sobre
> cualquier redacción anterior.

---

## 1. Principios rectores

1. **Identidad ≠ texto ≠ procedencia ≠ revisión.** Identidad = códigos
   inmutables; texto = filas con `language_code`; procedencia = de dónde viene;
   revisión = si puede publicarse.
2. **Un concepto, un `item`; un idioma, una fila de versión.** Nunca un catálogo
   o ítem por idioma, ni columnas `*_es`/`*_en`/`*_pt`.
3. **Reutilizar antes que duplicar.** `os_catalog_item_version` y
   `os_catalog_term` ya tienen `language_code`: son el almacenamiento
   terminológico.
4. **Cada estándar conserva su estructura.** SNOMED, CIE-10 y LOINC no se
   fuerzan en `os_localized_text`.
5. **Publicación pública `approved`-only.** Si no hay contenido aprobado, el
   campo es `null` con `untranslated=true`. La administración es un canal
   distinto.
6. **El idioma efectivo se informa por campo.** Una respuesta puede mezclar
   idiomas; no se declara un único idioma para toda ella salvo que sea cierto.
7. **Toda modificación deja rastro recuperable**, con identidad del actor real
   de aplicación o del proceso importador. No se afirma inmutabilidad
   criptográfica.
8. **Sin evidencia, no se inventa.** Procedencia, estado y idioma de origen
   desconocidos se marcan como `unknown`/`NULL`, nunca como `approved`.
9. **La aprobación es un acto editorial documentado.** El backfill nunca
   transforma procedencia oficial en aprobación (D-19).
10. **Dual-read no elude la publicación.** La compatibilidad de esquema no
    autoriza servir una columna original no aprobada (D-20).

---

## 2. Política de publicación: API pública vs. administración

### 2.1 API pública

| Regla | Comportamiento |
|---|---|
| Visibilidad | Solo filas con `review_status='approved'`. |
| Sin aprobado | Campo `null` + `untranslated=true` + `fallback_reason='no_approved_content'`. |
| Traducción automática | Nunca se sirve como aprobada, aunque el texto sea legible. |
| Original no aprobado | **No se sirve** en la API pública. `review_status='unreviewed'` del original no habilita su publicación. |
| `ALLOW_UNREVIEWED_DISPLAY` | No existe una opción que relaje esto en la API pública. La política es incondicional. |

### 2.2 Administración y revisión interna

- Puede consultar `unreviewed`, `draft`, `in_review` y `unknown`.
- Debe informar `provenance`, `review_status`, `source_language_code` y, si
  aplica, `dialect_determined=false`.
- Es un canal con contrato propio: **no** debe confundirse con la respuesta
  pública ni reutilizar su campo `approval_state` como si fuera aprobación.
- `ALLOW_UNREVIEWED_DISPLAY=false` (propuesto, hoy inexistente en el código)
  gobierna **solo** estos endpoints; nunca la API pública.

> Esto resuelve la contradicción histórica entre "visibilidad según
> `review_status`", "fallback solo `approved`" y "exposición del original
> `unreviewed`". Ver decisiones D-02 y D-03.

### 2.3 Aprobación inicial del contenido existente (D-19)

El backfill deja el contenido sin evidencia como `unknown`, y `unknown` no es
publicable. Para evitar que la API quede sin contenido, se incorpora una etapa
explícita y firmada **antes** de habilitar las pruebas de API:

| Camino | Condición | Resultado |
|---|---|---|
| Aprobación por autoridad demostrable | Fuente oficial, versión y ámbito verificables; revisor, fecha y evidencia registrados | `review_status='approved'` solo para los registros cubiertos por esa matriz |
| Pendiente editorial | Sin revisión efectiva | `unknown`/`unreviewed`; no publicable |

**No se aprueba automáticamente todo lo que provenga de una fuente oficial.**
La matriz de aprobación es un artefacto de revisión: tabla, campo, idioma,
release, fuente, motivo, revisor y fecha. Si un registro no aparece en esa
matriz, la API pública debe devolver `null` + `untranslated=true`.

---

## 3. Separación estricta: `provenance` vs `review_status`

| Dimensión | Columna | Valores | Pregunta que responde |
|---|---|---|---|
| Procedencia | `provenance` | `unknown`, `official_source`, `official_translation`, `origen_salud`, `community`, `machine` | ¿De dónde viene este texto? |
| Revisión | `review_status` | `unknown`, `unreviewed`, `draft`, `in_review`, `approved`, `deprecated` | ¿Puede publicarse? |

**Reglas obligatorias:**

- Son ortogonales: `official_source` **no** implica `approved`; `machine` no
  implica revisiones concretas por sí solo.
- La visibilidad pública depende **solo** de `review_status='approved'`.
- `unknown` es el valor por defecto del backfill sin evidencia; **no** es
  publicable (decisión D-18).
- El valor servido informa ambas dimensiones por separado.

> Corrige el error anterior: `review_status IN
> ('approved','official_translation')`, donde `official_translation` es un
> valor de procedencia y no un estado de revisión.

---

## 4. Tablas existentes reutilizadas

### 4.1 `os_catalog_item_version` — versión localizada del concepto

**Verificado** en `sql/02_catalogs/origen_catalog_engine.sql:72-82`: `id`,
`item_id`, `release_id`, `category_id`, `preferred_term NOT NULL`, `definition`,
`clinical_criteria`, `language_code VARCHAR(10) NOT NULL DEFAULT 'es-AR'`,
`UNIQUE (item_id, release_id, language_code)`.

Columnas propuestas (`ADD COLUMN IF NOT EXISTS`, sin borrar nada):

```
source_language_code  VARCHAR(10) NULL   -- SIN FK: admite 'es', tags RF2; NULL si no hay evidencia
language_evidence     VARCHAR(24)        -- declared_by_source | inherited_from_column | undetermined
provenance            VARCHAR(24) NOT NULL DEFAULT 'unknown'
review_status         VARCHAR(20) NOT NULL DEFAULT 'unknown'
source_reference      TEXT
translator            VARCHAR(120)
reviewed_by           VARCHAR(120)
reviewed_at           TIMESTAMPTZ
content_hash          TEXT NOT NULL          -- D-31
updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
valid_from            DATE
valid_to              DATE
-- Campos clínicos de DENTAR hoy no publicados:
short_definition      VARCHAR(255)
lay_terms             TEXT
clinical_scope        TEXT
```

**Condición de validez de la procedencia a nivel de fila (decisión D-07):**
`provenance`, `review_status`, `source_language_code`, `source_reference`,
`reviewed_by` y `reviewed_at` son válidos para los seis campos clínicos
(`preferred_term`, `definition`, `clinical_criteria`, `short_definition`,
`lay_terms`, `clinical_scope`) **solo si todos comparten fuente, publicación y
estado**. No se asume que sea así:

- `preferred_term` y los términos vienen de `dentar_term` /
  `dentar_diagnosis_term` (`term_type='preferred'`).
- `definition` y `clinical_criteria` vienen de `dentar_concept_version` /
  `dentar_diagnosis_version`.
- `short_definition`, `lay_terms` y `clinical_scope` vienen de
  `dentar_concept_version` (verificados en `dentar_core_and_diagnosis.sql:256-276`).

Cuando cualquier campo tenga fuente o estado distinto, se registran sus valores
en `os_field_review` (§5.5). Si existe fila allí, prevalece; si no, los valores
de fila solo se usan bajo la condición de fuente común. Ante duda: `unknown` y
no publicable.

### 4.2 `os_catalog_term` — sinónimos, siglas y variantes

**DDL real verificado** (`origen_catalog_engine.sql:84-90`, índice en `:104`):

```
item_version_id  INT NOT NULL REFERENCES os_catalog_item_version(id) ON DELETE CASCADE
term             VARCHAR(255) NOT NULL
term_type        VARCHAR(20) NOT NULL DEFAULT 'synonym'
    CHECK (term_type IN ('preferred','synonym','acronym','search_variant'))
language_code    VARCHAR(10) NOT NULL DEFAULT 'es-AR'
-- índice GIN en term; NO existe ningún UNIQUE
```

Hechos que deben quedar claros:

- `preferred` **sí está permitido hoy** por el `CHECK`; no se afirma lo contrario.
- `abbreviation` **no** está permitido: el `CHECK` lo rechaza por no figurar en
  la lista.
- **No hay UNIQUE**: pueden existir duplicados exactos.
- `sql/03_dentar/sync_dentar_to_os.sql:305-312` ya convierte
  `abbreviation → acronym`, filtra `t.language='es-AR'` (`:323`), excluye
  `preferred` (`:324`) y escribe literal `'es-AR'` (`:312`). Las mismas reglas se
  repiten en `:427-434`, `:445`. **Conservar, no duplicar.**

Propuestas:

1. `preferred_term` de la versión es la única fuente autoritativa del término
   preferido. Un trigger rechaza `term_type='preferred'` en nuevos
   INSERT/UPDATE de `os_catalog_term`.
2. `UNIQUE (item_version_id, language_code, term, term_type)` para eliminar
   duplicados.
3. **Consistencia de idioma obligatoria:** `NEW.language_code` debe ser igual al
   `language_code` de la versión referenciada por `NEW.item_version_id`.
4. Columnas aditivas de procedencia/revisión con los mismos valores y reglas de
   §3; `source_language_code` sin FK; `content_hash` para invalidar aprobaciones
   cuando cambie `term` (D-31).

### 4.3 SNOMED CT y CIE-10 — estructuras nativas

**No se migran** a `os_localized_text`. Se conservan `id`, `term`,
`language_code`, `effective_time` (SNOMED), `module_id`, `type_id`,
`case_significance_id` y sus FK. CIE-10 no tiene `effective_time`: no se inventa.

Columnas propuestas:

- `snomed_descriptions`: `rf2_language_tag VARCHAR(10)`, `provenance`,
  `source_reference`, `dialect_determined BOOLEAN`, `language_evidence`,
  `content_hash` (D-31).
- `cie10_descriptions`: `provenance`, `source_reference`, `content_hash` (D-31).

**Hechos verificados sobre el RF2:**

- `sct2.description.language_code` es ISO-639-1: `es`, `en`
  (`tools/sql/snomed/01_esquema.sql:72-87`). El comentario de columna lo dice
  explícitamente.
- La información dialectal está en los **language reference sets**, cargados en
  `sct2.refset_language` (índices en `tools/sql/snomed/03_postcarga.sql:119-124`)
  y consolidados en `sct2.language_effective` (`:199-219`), con preferencia de
  módulo argentino `11000221109`.
- `sct2_refset_catalog` registra `450828004` "Español de América Latina",
  `900000000000509007` "Inglés (US)" y `900000000000508004` "Inglés (GB)", todos
  con `filter_code=NULL` (`:418-420`).
- `03_postcarga.sql:692` usa `split_part(language_code,'-',1)` al copiar a
  `snomed_descriptions`: con los datos actuales es una normalización defensiva,
  **no** una fuente de dialecto. `sct2.preferred_term` prioriza
  `d.language_code='es'` y luego `'en'` (`:238-239`).
- `sct2.v_search_term` filtra solo `es` (`:466-476`).

**Consecuencia (decisión D-05):** no inferir `es-AR` desde `es`. Si la fila no
trae un tag dialectal real, se conserva `language_code='es'`,
`dialect_determined=false` y se informa el refset de procedencia. Un cliente
`es-AR` puede recibir `es` solo como fallback declarado, con
`effective_language='es'`. `rf2_language_tag` guarda la etiqueta real del
staging, nunca un valor estimado. Los language reference sets se conservan en
`sct2`; no se copian a un `entity_type` genérico.

### 4.4 LOINC — tabla base existente + tabla especializada

**Verificado** (`sql/05_loinc.sql/importar_loinc.sql`): versión 2.83 (`:2-5`);
fuentes `Loinc.csv`, `MapTo.csv`, `esMX28LinguisticVariant.csv`,
`esAR7LinguisticVariant.csv`, `ConsumerName.csv` (`:44-48`); capas secuenciales
EN → es-MX → es-AR → ConsumerName (`:127-251`) que hacen
`ON CONFLICT (loinc) DO UPDATE` sobre **las mismas columnas** (`:170-182`,
`:218-230`); `ConsumerName` sobrescribe `consumer_name` (`:247-251`).
`loinc.loinc` es `VARCHAR(20) UNIQUE`: no cabe en `entity_id BIGINT`.

Tabla nueva propuesta:

```
loinc_localized_text
  id                              BIGSERIAL PRIMARY KEY
  loinc_code                      VARCHAR(20) NOT NULL REFERENCES loinc(loinc) ON DELETE CASCADE
  language_code                   VARCHAR(10) NOT NULL     -- 'en' | 'es-MX' | 'es-AR'
  field_name                      VARCHAR(40) NOT NULL
  value                           TEXT NOT NULL
  source_file                     VARCHAR(80) NOT NULL
  source_release                  VARCHAR(20) NOT NULL     -- confirmar contra el CSV real
  version_last_changed            VARCHAR(50)
  version_last_changed_normalizada VARCHAR(50) NOT NULL    -- derivada en el trigger de carga
  source_priority                 INT NOT NULL             -- calculado por la regla central D-33
  provenance                      VARCHAR(24) NOT NULL DEFAULT 'unknown'
  review_status                   VARCHAR(20) NOT NULL DEFAULT 'unknown'
  source_reference                TEXT
  content_hash                    TEXT NOT NULL            -- D-31
  created_at                      TIMESTAMPTZ NOT NULL DEFAULT now()
  updated_at                      TIMESTAMPTZ NOT NULL DEFAULT now()

UNIQUE (loinc_code, language_code, field_name, source_file, source_release,
        version_last_changed_normalizada)
```

**Política determinista de prioridad (D-08, D-33):**

| Idioma | `source_file` | `source_priority` | Ámbito |
|---|---|---|---|
| `en` | `Loinc.csv` | 10 | todos los campos, incluido `definition_description` |
| `en` | `ConsumerName.csv` | 20 | **solo** `consumer_name` |
| `es-MX` | `esMX28LinguisticVariant.csv` | 10 | campos de la capa MX |
| `es-AR` | `esAR7LinguisticVariant.csv` | 10 | campos de la capa AR |

- `source_priority` se **materializa** en la columna, pero se calcula en un único
  lugar: la función/regla central `loinc_source_priority(language_code,
  source_file, field_name)`. La invocan el trigger de carga y la vista de
  resolución. No se reparte entre importadores ni controladores.
- `version_last_changed_normalizada` aplica una normalización documentada
  (incluido `NULL` → centinela) en el trigger de carga; forma parte de la clave
  para distinguir publicaciones reales.
- Para `(loinc_code, language_code, field_name, source_release)`, el valor
  efectivo se elige por: mayor `source_priority` → menor `source_file`
  (alfabético) → `version_last_changed` más reciente. El `id` **no interviene**:
  nunca se decide por orden de inserción.
- Duplicados exactos: `ON CONFLICT DO NOTHING`. Si dos filas comparten la clave
  y tienen `value` distinto, se marca **conflicto a reconciliar** y no se publica
  ninguna hasta resolución humana, registrada en `os_translation_review`.

Propiedades:

- Conviven EN, es-MX y es-AR: `source_file` forma parte de la clave, por lo que
  **ninguna variante sobrescribe a otra** (a diferencia del importador actual).
- La procedencia se preserva en `source_file`, `source_release`,
  `version_last_changed` y `source_reference`.
- `source_release='2.83'` **debe confirmarse** contra el archivo realmente usado
  en el backfill antes de escribirlo; el valor aparece en
  `importar_loinc.sql:2-5`, pero no se asume.
- `source_language_code` no se inventa: se deriva del `source_file` declarado.
- `es-MX` **no** se aliasa a `es-AR`.

---

## 5. Tablas nuevas

### 5.1 `os_language` y `os_language_alias`

```
os_language
  code          VARCHAR(10) PRIMARY KEY        -- 'es-AR','en','pt-BR','es','es-MX'
  display_name  VARCHAR(80) NOT NULL
  primary_tag   VARCHAR(5) NOT NULL            -- 'es','en','pt'
  is_active     BOOLEAN NOT NULL DEFAULT TRUE   -- seleccionable por el cliente
  is_source_only BOOLEAN NOT NULL DEFAULT FALSE -- etiqueta de origen; válida como efectiva

os_language_alias
  alias         VARCHAR(10) PRIMARY KEY        -- 'es','pt'
  language_code VARCHAR(10) NOT NULL REFERENCES os_language(code)
```

**Tres clases (D-15, D-27):** filas con `is_active=true` son las
**seleccionables por el cliente** (`es-AR`, `en`, `pt-BR`); `os_language_alias`
contiene los alias (`es→es-AR`, `pt→pt-BR`); `es` y `es-MX` se registran con
`is_active=false, is_source_only=true` para conservar la etiqueta real sin
convertirla en `es-AR`.

`is_active` gobierna la **entrada** (`lang`, `Accept-Language`). Ni `is_active`
ni `is_source_only` impiden que una fila aprobada con `language_code='es'` se
devuelva como `effective_language='es'`: el `LanguageResolver` solo produce
candidatos seleccionables, pero el **evaluador editorial** puede elegir una fila
`is_source_only` aprobada y declararla idioma efectivo del campo. El alias `es`
se resuelve primero a `es-AR`, por lo que no colisiona con la etiqueta de origen
`es`. **No** se crea el alias `es-MX → es-AR` ni `es-ES → es-AR`.

- **SNOMED `es`:** cliente `es-AR` + fila `es` aprobada →
  `effective_language='es'`, `fallback_reason='rf2_dialect_undetermined'`,
  `dialect_determined=false`. Nunca `effective_language='es-AR'`.
- **CDT `es`:** `nombre_es`/`descripcion_es` → `language_code='es'`,
  `source_language_code='es'`, `dialect_determined=false`. Nunca se reescribe a
  `es-AR`.

### 5.2 `os_catalog_language`

```
catalog_id      INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE
language_code   VARCHAR(10) NOT NULL REFERENCES os_language(code)
is_default      BOOLEAN NOT NULL DEFAULT FALSE
is_fallback     BOOLEAN NOT NULL DEFAULT FALSE
is_bridge       BOOLEAN NOT NULL DEFAULT FALSE
coverage_status VARCHAR(20) NOT NULL DEFAULT 'partial'
    CHECK (original | complete | partial | planned | undetermined)
PRIMARY KEY (catalog_id, language_code)
```

Un único `is_default`, `is_fallback` e `is_bridge` por catálogo (índices
únicos parciales). **No se agregan columnas de idioma a `os_catalog`**: no tiene
`default_language_code`, `fallback_language_code` ni `source_language_code`.

### 5.3 `os_localized_text` — metadatos con identidad entera

```
id                    BIGSERIAL PRIMARY KEY
entity_type           VARCHAR(32) NOT NULL
    CHECK (catalog | catalog_category | catalog_release | fee_schedule |
           pricing_unit | terminology_system | concept_mapping |
           nomenclador | vademecum | substance | medicinal_product |
           product_package)
entity_id             BIGINT NOT NULL
field_name            VARCHAR(48) NOT NULL
language_code         VARCHAR(10) NOT NULL REFERENCES os_language(code)
value                 TEXT NOT NULL
source_language_code  VARCHAR(10) NULL   -- SIN FK: 'es', 'es-MX', tags RF2; NULL si no hay evidencia
language_evidence     VARCHAR(24)        -- declared_by_source | inherited_from_column | undetermined
provenance            VARCHAR(24) NOT NULL DEFAULT 'unknown'
review_status         VARCHAR(20) NOT NULL DEFAULT 'unknown'
source_reference      TEXT
translator            VARCHAR(120)
reviewed_by           VARCHAR(120)
reviewed_at           TIMESTAMPTZ
scope_release_id      INT NULL REFERENCES os_catalog_release(id) ON DELETE RESTRICT
valid_from            DATE
valid_to              DATE
content_hash          TEXT NOT NULL          -- D-31
created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
```

**`scope_release_id` (decisión D-06):** se rechaza explícitamente
`ON DELETE SET NULL`: borrar un release no puede convertir una traducción
ligada a él en un metadato global. Se usa `RESTRICT`. Además, la FK simple no
garantiza pertenencia al catálogo: el trigger debe comprobar que
`os_catalog_release.catalog_id` coincide con el catálogo de la entidad
(`catalog_category`, `catalog_release`, `fee_schedule`, `concept_mapping` vía
`os_catalog_item`). Para entidades sin ámbito de catálogo (`substance`,
`medicinal_product`, `product_package`, `nomenclador`, `vademecum`),
`scope_release_id` debe ser `NULL` salvo declaración explícita.

**Entidades verificadas:**

| `entity_type` | Entidad real | Identificador | `field_name` permitidos |
|---|---|---|---|
| `catalog` | `os_catalog` (incluye `product_role='family'`) | `id` | `name`, `short_name`, `description` |
| `catalog_category` | `os_catalog_category` | `id` | `name` |
| `catalog_release` | `os_catalog_release` | `id` | `official_norm_reference` |
| `fee_schedule` | `os_fee_schedule` | `id` | `name` |
| `pricing_unit` | `os_pricing_unit` | `id` | `name`, `description`, `organization` |
| `terminology_system` | `os_terminology_system` | `id` | `name` |
| `concept_mapping` | `os_concept_mapping` | `id` | `external_display`, `clinical_rationale` |
| `nomenclador` | `nomencladores_argentina` | `id` | `capitulo`, `descripcion` |
| `vademecum` | `vademecum_comercial` | `id` | `monodroga`, `nombre_comercial`, `presentacion` |
| `substance` | `os_substance` | `id` | `name` |
| `medicinal_product` | `os_medicinal_product` | `id` | `brand_name`, `pharmacological_action` |
| `product_package` | `os_product_package` | `id` | `presentation_text`, `dosage_form` |

Excluidos: `catalog_family` (la familia es fila de `os_catalog`),
`dental_structure` (no existe como entidad), `loinc` y `nomenclador_2025`
(claves alfanuméricas), versiones/términos de concepto y tablas SNOMED/CIE-10.

**Limitaciones de la relación polimórfica y controles (decisión D-14):**
`entity_type + entity_id` **no es una FK nativa**. El trigger no cubre
`TRUNCATE` ni cambios de mapeo: se requieren además privilegios restringidos o
un event trigger y reconciliación periódica. Controles propuestos:

| Riesgo | Control |
|---|---|
| INSERT/UPDATE con entidad inexistente | Trigger `BEFORE INSERT OR UPDATE` con `CASE(entity_type)` que verifica existencia. |
| Cambio de `entity_type`/`entity_id` | Trigger los declara inmutables; para "mover" se requiere baja + alta auditada. |
| Eliminación de la entidad | Trigger `ON DELETE` en las 12 tablas referenciadas con RESTRICT mientras existan traducciones; sin borrado en cascada automático. |
| Operaciones masivas | Las filas disparan triggers, pero se exige límite de lote y reconciliación posterior por `(tabla, campo, idioma, fuente)`. |
| Concurrencia (D-35) | `INSERT`/`UPDATE` toman `pg_advisory_xact_lock(hashtext(entity_type || ':' || entity_id))` y, si aplica, `pg_advisory_xact_lock(hashtext('release:' || scope_release_id))`. Los `BEFORE DELETE` de las 12 entidades toman el mismo lock antes de aplicar `RESTRICT`. El índice único parcial arbitra además dos inserciones simultáneas. El trigger de existencia **no es FK nativa**. |
| Releases | `RESTRICT` + comprobación de pertenencia al catálogo descrita arriba. |
| `field_name` inválido | Validación contra la lista por `entity_type` de la tabla anterior, dentro del mismo trigger. |
| Deriva futura del mapeo | Consulta de reconciliación periódica: toda fila debe seguir apuntando a una entidad viva y a un `field_name` permitido. |

**Unicidad correcta (índices parciales, sintaxis PostgreSQL válida):**

```
CREATE UNIQUE INDEX uq_olt_global
    ON os_localized_text (entity_type, entity_id, field_name, language_code)
    WHERE scope_release_id IS NULL;

CREATE UNIQUE INDEX uq_olt_scoped
    ON os_localized_text (entity_type, entity_id, field_name, language_code, scope_release_id)
    WHERE scope_release_id IS NOT NULL;
```

No se usa `UNIQUE (..., COALESCE(scope_release_id, 0))`: una restricción
`UNIQUE` de tabla no acepta expresiones. Índices adicionales:
`(entity_type, entity_id, field_name, language_code)` y `GIN (value
gin_trgm_ops)`, creados con `CONCURRENTLY` fuera de transacción.

**Verificación obligatoria (D-24, D-34):** `CREATE INDEX CONCURRENTLY IF NOT
EXISTS` no valida un índice inválido preexistente. Antes de crear: consultar
`pg_class`/`pg_index` por nombre y comprobar `indisvalid`/`indisready`; comparar
definiciones con `pg_get_indexdef` para detectar duplicados; en índices únicos,
detectar duplicados de datos. Si el índice es inválido o duplicado exacto, se
permite `DROP INDEX CONCURRENTLY IF EXISTS <nombre>` **solo** como excepción
controlada: creado por esta migración o con autorización escrita del DBA y del
responsable del plan, motivo y definición previa registrados en el reporte de
fase y en `os_translation_review` como evento de sistema, ejecución fuera de
transacción y recreación con `CONCURRENTLY`. La regla aditiva sigue prohibiendo
`DROP TABLE`, `DROP COLUMN`, `TRUNCATE` y `DELETE` de datos. Verificar al final
`indisvalid=true`. El índice único parcial **no reemplaza** las validaciones del
trigger polimórfico (D-35).

### 5.4 `os_translation_review` — auditoría recuperable

```
id                    BIGSERIAL PRIMARY KEY
target_table          VARCHAR(40) NOT NULL
target_id             BIGINT NOT NULL
field_name            VARCHAR(48) NOT NULL
language_code         VARCHAR(10) NOT NULL
event_type            VARCHAR(24) NOT NULL
   CHECK (event_type IN ('content_changed', 'approval_invalidated',
                         'approval_granted', 'review_state_changed',
                         'new_translation', 'new_official_publication',
                         'editorial_correction', 'deprecate'))
action                VARCHAR(20) NOT NULL
   CHECK (action IN ('create', 'update', 'approve', 'invalidate', 'deprecate'))
previous_value        TEXT
new_value             TEXT
source_language_code  VARCHAR(10)
provenance            VARCHAR(24)
review_status         VARCHAR(20)
-- Identidad del actor (decisión D-10):
actor_type            VARCHAR(16) NOT NULL
   CHECK (user | importer | system | db_role)
application_user_id   VARCHAR(80)
importer_run_id       VARCHAR(80)
session_user          VARCHAR(80) NOT NULL      -- evidencia de respaldo, no identidad del autor
actor_identified      BOOLEAN NOT NULL DEFAULT FALSE
transaction_id        BIGINT                    -- txid de la transacción
occurred_at           TIMESTAMPTZ NOT NULL DEFAULT now()
notes                 TEXT
```

**Identificación del usuario real:** la aplicación y el importador fijan su
identidad dentro de la misma transacción mediante configuración local de sesión
(por ejemplo `app.actor_id`, `app.importer_run_id` con ámbito transaccional). El
trigger lee esos valores. Si no están presentes, se registra
`actor_type='db_role'`, `actor_identified=false` y `SESSION_USER` queda como
evidencia. Varias personas pueden compartir la cuenta PostgreSQL de
aplicación: `SESSION_USER` **no** identifica al autor.

**Trazabilidad obligatoria (D-31, D-32):** todo cambio de estado en
`os_field_review` genera un evento con `target_table='os_field_review'` y
`event_type='review_state_changed'`; todo cambio de contenido genera un evento
con la tabla de contenido correspondiente y `event_type='content_changed'`. Un
cambio de texto fuerza `review_status='unreviewed'`, limpia
`reviewed_by`/`reviewed_at`, regenera `content_hash` e inserta
`approval_invalidated` **en la misma transacción**. Un cambio de estado genera
`approval_granted` cuando corresponde. Ambos eventos comparten
`transaction_id`. La re-aprobación es siempre un acto editorial posterior
(D-19). Nunca se usa `SESSION_USER` como sustituto del actor real.

**Cobertura (matriz única, decisión D-23):** tabla y registro afectados, campo,
valor anterior y nuevo, idioma, acción, fecha/hora, procedencia y estado de
revisión.

| Tabla auditada | Fase de incorporación |
|---|---|
| `os_catalog_item_version` | 3 |
| `os_catalog_term` | 3 |
| `os_localized_text` | 3 |
| `os_field_review` | 2 |
| `loinc_localized_text` | 5 |
| `snomed_descriptions` | 3 |
| `cie10_descriptions` | 3 |
| `os_concept_mapping` | 3 | 

La columna indica **fase de incorporación acumulativa** (D-29): al cierre de la
Fase 2 solo está activa la auditoría de `os_field_review`; al cierre de la Fase
3 están activas 7 tablas; `loinc_localized_text` se incorpora en la Fase 5 y
completa las 8. `os_translation_review` es el historial de esas 8 tablas, no una
novena tabla auditada.

Triggers transaccionales `BEFORE UPDATE`/`AFTER INSERT`/`AFTER DELETE` para las
8 tablas. La cobertura del 100 % se refiere a **escrituras confirmadas**;
también se auditan los intentos de borrado y las operaciones masivas con límite
de lote e identidad de importador. Los intentos rechazados que revierten la
transacción se registran en el log de la aplicación/importador y se declaran
como tal: PostgreSQL no ofrece una auditoría independiente de la transacción.

Las 8 tablas de la matriz deben exponer `content_hash` sobre su campo de texto
auditable para que la invalidación de D-31 sea uniforme, incluida
`os_concept_mapping` (`external_display`, `clinical_rationale`).

**Protección:** la tabla es *append-only* por permisos: sin `UPDATE`/`DELETE`
para el rol de aplicación, propietario separado y privilegio de auditoría
distinto. Escritura en la misma transacción que el cambio: si la transacción se
revierte, se revierte también la entrada de auditoría.

**Declaración honesta:** auditoría **recuperable**, no inmutable en sentido
criptográfico. No hay hash encadenado, firma ni sello de tiempo externo; se
afirma solo lo que el diseño garantiza.

### 5.5 `os_field_review` — procedencia por campo clínico

Tabla estrecha **única** para todos los campos y tablas de contenido (decisión
D-07). No guarda texto: el valor sigue en su columna clínica.

```
target_table          VARCHAR(40) NOT NULL   -- p. ej. os_catalog_item_version
target_id             BIGINT NOT NULL
field_name            VARCHAR(48) NOT NULL   -- preferred_term | definition | clinical_criteria |
                                            -- short_definition | lay_terms | clinical_scope
language_code         VARCHAR(10) NOT NULL
scope_release_id      INT NULL REFERENCES os_catalog_release(id) ON DELETE RESTRICT
source_language_code  VARCHAR(10) NULL
language_evidence     VARCHAR(24) NOT NULL DEFAULT 'undetermined'
provenance            VARCHAR(24) NOT NULL DEFAULT 'unknown'
review_status         VARCHAR(20) NOT NULL DEFAULT 'unknown'
source_reference      TEXT
reviewed_by           VARCHAR(120)
reviewed_at           TIMESTAMPTZ
content_hash          TEXT NOT NULL          -- D-31
updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()

NO se define PRIMARY KEY con scope_release_id opcional.
```

**Unicidad correcta (D-21, D-28):** se usan dos índices únicos parciales, uno
para cada dominio de nulidad:

```
CREATE UNIQUE INDEX uq_fr_global
    ON os_field_review (target_table, target_id, field_name, language_code)
    WHERE scope_release_id IS NULL;

CREATE UNIQUE INDEX uq_fr_scoped
    ON os_field_review (target_table, target_id, field_name, language_code, scope_release_id)
    WHERE scope_release_id IS NOT NULL;
```

`UNIQUE NULLS NOT DISTINCT` es alternativa válida en PostgreSQL 18, pero se
prefiere esta solución por coherencia con `os_localized_text`.

**Definición formal (D-12, D-21, D-28, D-31):**

- **Clave lógica:** `(target_table, target_id, field_name, language_code,
  scope_release_id cuando corresponda)`, materializada por los dos índices
  anteriores. No hay PK de cuatro columnas que trate `NULL` como un valor más.
- **Columnas:** procedencia, estado, idioma de origen, `language_evidence`,
  `source_reference`, `reviewed_by`, `reviewed_at`, `content_hash` y
  `updated_at`.
- **Responsabilidad:** representa el **estado editorial vigente por campo**;
  no guarda el texto, que permanece en su columna. Los cambios se registran en
  `os_translation_review`, que conserva el historial. No duplican
  responsabilidades: uno responde "¿qué vale ahora?", el otro "¿qué pasó?".
- **Precedencia:** fila con `scope_release_id` igual al release solicitado > fila
  global (`scope_release_id IS NULL`) > valores de fila (solo si se cumple la
  condición de fuente común de §4.1) > `unknown`. Una fila específica de **otro**
  release no se aplica ni se hereda.
- **Invalidación:** si cambia el contenido, `content_hash` cambia y la
  aprobación se invalida en la misma transacción (D-31/D-32).
- **Cobertura:** una sola tabla cubre los seis campos clínicos y cualquier otro
  campo que en el futuro requiera procedencia distinta.

---

## 6. Estructuras que conservan su modelo específico

| Sistema | Se conserva | No se hace |
|---|---|---|
| SNOMED CT | `snomed_concepts`, `snomed_descriptions`, `effective_time`, `module_id`, `type_id`, refsets en `sct2` | No inferir `es-AR`; no copiar a `os_localized_text` |
| CIE-10 | `cie10_codes`, `cie10_descriptions`, `language_code` | No inventar `effective_time` |
| LOINC | `loinc` intacto + `loinc_localized_text` con prioridad determinista | No usar `entity_id BIGINT`; no sobrescribir variantes |
| CDT 2025 | Tablas nativas `odontologia_cdt_categorias` (PK `codigo` VARCHAR), `odontologia_cdt_catalogo` (PK `codigo_cdt` VARCHAR(10)) y `odontologia_prestaciones` (PK `id SERIAL`, `codigo_nomenclador` UNIQUE); `nombre_en→en`, `nombre_es→es` con `dialect_determined=false` (D-22, D-37) | No modificar la fuente, no inferir `es-AR` de `nombre_es`, no escribir CDT en `os_localized_text` bajo `entity_type='nomenclador'` |
| NN 2025 | `nomenclador_2025(codigo VARCHAR(20) PK, descripcion, valor, categoria)` y su índice `to_tsvector('spanish', descripcion)` | No forzar en `entity_id BIGINT`; sin mapeo a `os_*` ni endpoint propio en esta versión |
| DENTAR | Modelo editorial propio; `abbreviation→acronym` en sync | No crear `catalog_family` ni `dental_structure` |

**Exposición real verificada (D-37, Fase 10):**

- `entity_type='nomenclador'` pertenece **únicamente** a
  `nomencladores_argentina` (`origen_catalog_engine.sql:7594-7609`; `id SERIAL`,
  `codigo VARCHAR(30)`, `capitulo`, `descripcion`), con `field_name`
  `capitulo`/`descripcion`. No se usa para CDT ni para NN 2025.
- `GET /v1/nomenclador` consulta `nomencladores_argentina`
  (`api/index.php:234-239`; `TerminologySearchService.php:1423-1442`). **No
  sirve CDT.**
- CDT se consulta por `GET /v1/search/odontologia` (ruta genérica
  `/v1/search/{domain}` en `api/index.php:115-129`, dominio
  `TerminologySearchService::DOMAIN_ODONTOLOGIA='odontologia'` en `:40`, tabla
  `odontologia_prestaciones` en `:256-278`) y por
  `GET /v1/odontologia/{id}` (`api/index.php:439-444`). No existe `/v1/cdt`.
- NN 2025 **no tiene endpoint propio** ni mapeo a `os_*` en esta versión. Su
  exposición futura y vocabulario quedan como decisión pendiente.
- Las claves VARCHAR de CDT/NN no caben en `entity_id BIGINT`: no se inventa
  una relación polimórfica.

---

## 7. Resolución idiomática y fallback

### 7.1 Tres clases de etiquetas de idioma (D-15, D-27)

| Clase | Definición | Ejemplos |
|---|---|---|
| Seleccionables por el cliente | Filas activas de `os_language` (`is_active=true`) | `es-AR`, `en`, `pt-BR` |
| Alias | Se convierten a una etiqueta seleccionable | `es→es-AR`, `pt→pt-BR` |
| Etiquetas de origen | `is_source_only=true`, no pedibles como `lang`, pero **válidas como `effective_language`** si están aprobadas | `es` (SNOMED/CDT), `es-MX` y `es-AR` como variantes LOINC |

`es-MX` no se aliasa a `es-AR`. `es` de SNOMED/CDT no se convierte en `es-AR`.
Una variante LOINC `es-AR` es etiqueta de origen aunque coincida textualmente
con un locale admitido: no habilita selección automática de respuesta general,
pero sí puede devolverse como idioma efectivo de un campo aprobado.

### 7.2 Entrada

1. `?lang=` válido (`es-AR`, `en`, `pt-BR`) o alias (`es→es-AR`, `pt→pt-BR`).
   `es-MX` y `es-ES` se rechazan como alias; se tratan como etiquetas de origen
   no seleccionables en la entrada, sin colapsarlas a `es-AR`. Como contenido
   aprobado sí pueden aparecer en `effective_language`.
2. Sin `lang`: `Accept-Language`, descartando `q=0`, ordenando por `q`
   descendente y por orden de aparición en empate; se ignoran entradas no
   resolubles.
3. **Si todas las entradas tienen `q=0`:** el cliente no acepta ninguna; no se
   elige silenciosamente una de ellas. Se aplica `API_DEFAULT_LANG` con
   `fallback_reason='no_acceptable_language'` y `q_zero_only=true`.
4. Si nada resolve: `API_DEFAULT_LANG` (hoy `es` en `.env.example:33`; migrar a
   `es-AR` solo con aprobación).

### 7.3 Identificadores de la resolución

| Nombre | Significado |
|---|---|
| `requested_language` | Idioma canónico pedido (tras alias). |
| `effective_language` | Idioma del candidato aprobado elegido **por campo**; puede ser una etiqueta `is_source_only` aprobada como `es`. En `meta` es `null` si los campos no comparten idioma. |
| `source_language` | Idioma declarado del texto original; `null` si no hay evidencia. |
| `provenance` | Origen informativo; no decide visibilidad. |
| `approval_state` | `review_status` de la fila efectiva. |
| `fallback_applied` | `effective_language != requested_language`. |
| `fallback_reason` | Motivo de la desviación. |
| `available_languages` | Lista de códigos con al menos un campo `approved`, cada uno con `selectable = os_language.is_active`. |
| `field_languages` | Mapa por campo calculado por el evaluador editorial; fuente de verdad cuando hay mezcla de idiomas. |
| `untranslated` | `true` si el campo quedó `null` por falta de contenido aprobado. |
| `dialect_determined` | `false` cuando el idioma es `es` sin evidencia regional (SNOMED). |

### 7.4 Cadena única (solo API pública)

**Etapa 1 — `LanguageResolver` (solo idioma, D-30).** Lee `lang` → alias →
`Accept-Language` con `q` → `API_DEFAULT_LANG`, valida contra
`os_language.is_active` y `os_catalog_language`, y produce una **lista ordenada
de idiomas candidatos**. **No consulta** `os_field_review`, `review_status` ni
contenido. Las etiquetas `is_source_only` no entran en esta lista porque no son
seleccionables por el cliente.

**Etapa 2 — Evaluador editorial (solo publicación, D-30).** Para el objeto, el
release vigente y **cada campo**, toma la lista seleccionable del resolvedor y la
**amplía** con el idioma de origen declarado y los idiomas configurados del
catálogo. Esa ampliación es indispensable: un contenido aprobado puede tener
`language_code='es'` (`is_source_only`), que no es pedible como `lang` pero sí
devolvable como `effective_language`. Orden resultante:

1. `requested_language` (de la lista del resolvedor).
2. Idioma de origen declarado (`source_language_code`), si hay evidencia; puede
   ser `es` u otra etiqueta `is_source_only`.
3. `is_fallback` del catálogo.
4. `is_bridge` del catálogo (normalmente `en`).
5. `is_default` del catálogo.
6. `es-AR` global (último recurso del sistema; los pasos 2-6 pueden incluir
   etiquetas no seleccionables).

Para cada candidato, el evaluador resuelve primero la precedencia
`scope_release_id` del release solicitado > global > valores de fila bajo D-07
> `unknown`. Descarta todo candidato cuyo `review_status` no sea `approved`. Elige
el **primer candidato aprobado**. Si ninguno está aprobado, devuelve `null` +
`untranslated=true` + `fallback_reason='no_approved_content'`. Antes de servir,
verifica que `content_hash` siga vigente; un cambio de texto invalidó la
aprobación en la misma transacción (D-31).

**Reglas para campos sin registro editorial (D-20):** no hay un paso que caiga a
la columna original. Si el evaluador no encontró contenido aprobado, la API
pública devuelve `null` + `untranslated=true`; el dual-read de Fase 11 solo
opera después de la evaluación y bajo esta misma política (§9).

**No existe** el paso "servir el original `unreviewed`" en la API pública.

**SNOMED `es`:** si el cliente pide `es-AR` y solo hay `language_code='es'` sin
tag dialectal, se sirve `es` con `fallback_applied=true`,
`fallback_reason='rf2_dialect_undetermined'`, `dialect_determined=false` y
`effective_language='es'`. Nunca se declara `effective_language='es-AR'`.

**Búsqueda por código** (`permanent_code`, `os_catalog_identifier.value` como
`01.01`, `external_code`, SCTID, código LOINC/CIE-10) es independiente del
idioma: no aplica fallback.

**Búsqueda por término:** se ejecuta en el idioma efectivo; si no hay resultados
y el original es distinto, se reintenta en el idioma de origen con
`fallback_applied=true`. Incluye sinónimos de `os_catalog_term` (mismo idioma
que su versión), `snomed_descriptions` y `loinc_localized_text`. Dos sinónimos
con idiomas distintos no se mezclan en un mismo resultado sin declararlo.

### 7.5 Administración

Ver §2.2. Los endpoints internos pueden mostrar `unreviewed`/`draft`/
`in_review` con su estado y procedencia; su contrato es distinto y no debe
reutilizarse para responder peticiones públicas.

### 7.6 Contrato de salida con idioma efectivo por campo (D-38)

`meta` informa la resolución a nivel de petición y `field_languages` describe
cada campo. Ejemplo con idiomas efectivos mezclados:

```json
{
  "data": {
    "permanent_code": "DNT-PR-000001",
    "preferred_term": "...",
    "definition": null,
    "name": "..."
  },
  "meta": {
    "requested_language": "pt-BR",
    "effective_language": null,
    "source_language": null,
    "provenance": null,
    "approval_state": null,
    "fallback_applied": null,
    "fallback_reason": null,
    "available_languages": [
      { "code": "es-AR", "selectable": true },
      { "code": "en", "selectable": true },
      { "code": "es", "selectable": false }
    ],
    "untranslated": true,
    "field_languages": {
      "preferred_term": {
        "effective_language": "en",
        "source_language": "es-AR",
        "provenance": "official_translation",
        "approval_state": "approved",
        "fallback_applied": true,
        "fallback_reason": "bridge_language",
        "untranslated": false
      },
      "definition": {
        "effective_language": null,
        "source_language": null,
        "provenance": null,
        "approval_state": null,
        "fallback_applied": false,
        "fallback_reason": "no_approved_content",
        "untranslated": true
      },
      "name": {
        "effective_language": "es-AR",
        "source_language": "es-AR",
        "provenance": "origen_salud",
        "approval_state": "approved",
        "fallback_applied": false,
        "fallback_reason": null,
        "untranslated": false
      }
    }
  }
}
```

Reglas:

- `available_languages` contiene los `language_code` distintos con al menos un
  campo `approved` para el recurso/release. Cada entrada lleva
  `selectable = os_language.is_active`. Las etiquetas `is_source_only` aprobadas
  (por ejemplo `es`) aparecen con `selectable=false`.
- `effective_language` se calcula **por campo**. Solo se informa a nivel `meta`
  si todos los campos de texto comparten idioma; si hay mezcla,
  `meta.effective_language=null` y `field_languages` es la fuente de verdad.
- `field_languages` se incluye siempre e incluye **todo campo de texto** de
  `data`, con `effective_language`, `source_language`, `provenance`,
  `approval_state`, `fallback_applied`, `fallback_reason` y `untranslated`.
- `untranslated` a nivel `meta` es `true` si **algún** campo quedó sin contenido
  aprobado.
- `Content-Language` se emite **solo** si todos los campos comparten
  `effective_language`. Si hay mezcla, se omite. `Vary: Accept-Language` se
  emite siempre.
- Los metadatos de catálogo/categoría se resuelven por su propia fila en
  `os_localized_text`; el concepto por `os_catalog_item_version`. Pueden diferir
  y así se declara.

---

## 8. Concepto, release e idioma

| Situación | Acción | Historia |
|---|---|---|
| Cambio clínico | Nuevo `os_catalog_release` + nuevas filas de versión por idioma | `new_official_publication` |
| Corrección editorial | `UPDATE` de la fila `(item, release, language)` | `editorial_correction` con `previous_value` |
| Cambio de contenido (D-31) | `UPDATE`/`ON CONFLICT DO UPDATE` recalcula `content_hash`, fuerza `unreviewed`, limpia revisor/fecha y exige re-aprobación | `content_changed` + `approval_invalidated`, misma transacción |
| Nueva traducción | `INSERT` de otra fila con distinto `language_code` | `new_translation` |
| Procedencia divergente por campo | Fila en `os_field_review` | Auditoría del campo |
| Retraducción tras deprecar | `review_status='deprecated'` + nueva fila | Ambas recuperables |
| Actualización RF2/LOINC | Nuevas filas con `effective_time`/`source_release` distinto | Nunca `DELETE` |

- Un `os_catalog_item` por `permanent_code` (UNIQUE existente).
- Una versión por `(item_id, release_id, language_code)` (UNIQUE existente).
- Identidad de códigos e historia de publicaciones se preservan: ningún
  `DROP TABLE`, `DROP COLUMN`, `TRUNCATE` ni `DELETE` de datos existentes. La
  única excepción es la reparación autorizada de índices inválidos/duplicados
  (D-34), nunca de tablas, columnas ni datos.

---

## 9. Impacto resumido en API, sitio e importadores

- **API:** `LanguageResolver` central **separado** del evaluador editorial
  (D-30); `CatalogEngineService` filtra idioma y elimina el `LIMIT 1` de
  `api/services/CatalogEngineService.php:207`; `TerminologySearchService`
  sustituye los literales `'es-AR'`; `ConceptController` respeta `lang`;
  cabeceras y contrato `meta` per-field con `available_languages`,
  `effective_language` y `field_languages` según D-38.
- **Sitio:** `SUPPORTED=['es-AR','en','pt-BR']`; selector con `hreflang`;
  navegador/buscador hoy inexistente; migrar `i18n.php` y los ~99 ternarios
  `$isEn` de `docs.php`.
- **Importadores:** parametrizar idioma; **sin asignar** `official_source` ni
  `approved` automáticamente (D-18); conservar `abbreviation→acronym`; SNOMED
  mantiene `es`; LOINC separa variantes por `source_file` y calcula
  `source_priority` con la regla central (D-33). Todo `ON CONFLICT DO UPDATE`
  que cambie texto invalida la aprobación y registra el evento (D-31/D-32).
- **PMO:** trabajo independiente y bloqueante para su carga; no se mezcla con
  esta migración (D-17).

El detalle por fase y las pruebas están en `plan-migracion-multilingue.md`.

---

## 10. Qué NO se hará

- No crear catálogos/ítems por idioma ni columnas `*_en`/`*_es`/`*_pt`.
- No inferir `es-AR` desde `es`, ni aliasar `es-MX` a `es-AR`. Sí se entrega
  `effective_language='es'` cuando esa fila `is_source_only` está aprobada.
- No dejar que el estado de `os_field_review` seleccione el idioma: resuelve el
  `LanguageResolver`, filtra el evaluador editorial (D-30).
- No conservar silenciosamente una aprobación tras cambiar el contenido
  (D-31/D-32).
- No servir contenido no aprobado en la API pública, con o sin
  `ALLOW_UNREVIEWED_DISPLAY`.
- No marcar datos sin evidencia como `official_source` ni `approved`.
- No usar `entity_type='catalog_family'` ni `'dental_structure'`, ni
  `entity_id BIGINT` para códigos alfanuméricos; `entity_type='nomenclador'` es
  solo `nomencladores_argentina`, nunca CDT/NN.
- No usar `scope_release_id ... ON DELETE SET NULL`.
- No presentar el trigger polimórfico como FK nativa ni omitir los locks
  advisories de D-35.
- No sobrescribir variantes de LOINC ni duplicar el mapeo
  `abbreviation→acronym`; no decidir por orden de inserción.
- No afirmar inmutabilidad criptográfica de la auditoría.
- No borrar columnas/tablas/datos ni usar `DROP INDEX` sin la autorización
  controlada de D-34; no modificar `tools/sources/**`, no ejecutar nada en
  PostgreSQL ni operar sobre producción sin aprobación.
- No introducir `NOT NULL` nuevos en Fase 13: solo verificar lo definido en
  Fases 2/3 (D-36).
