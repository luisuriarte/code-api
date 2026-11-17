# Decisiones de arquitectura multilingüe — Origen Salud

> Estado: **registro de decisiones para aprobación independiente**. No se ha
> implementado nada. Es la **referencia principal de coherencia** entre
> [`auditoria-internacionalizacion.md`](auditoria-internacionalizacion.md),
> [`modelo-multilingue-propuesto.md`](modelo-multilingue-propuesto.md) y
> [`plan-migracion-multilingue.md`](plan-migracion-multilingue.md). Ante cualquier
> discrepancia prevalece lo decidido aquí.
>
> Idiomas objetivo: `es-AR`, `en`, `pt-BR`. Ninguna decisión ha sido ejecutada en
> PostgreSQL, API, sitio web o importadores.
>
> **Nota de numeración:** **D-05 = SNOMED CT/CIE-10**, **D-09 = DENTAR**,
> **D-14 = `os_localized_text`**. La revisión final añade las aclaraciones
> **D-27 a D-38**, que resuelven las últimas contradicciones técnicas detectadas.
> Las decisiones D-01 a D-26 se mantienen salvo las aclaraciones indicadas.

---

## 1. Decisiones adoptadas

### D-01 — Procedencia y revisión son ortogonales; `unknown` es explícito

- `provenance` ∈ {`unknown`, `official_source`, `official_translation`,
  `origen_salud`, `community`, `machine`}; `review_status` ∈ {`unknown`,
  `unreviewed`, `draft`, `in_review`, `approved`, `deprecated`}.
- `unknown` es obligatorio cuando no hay evidencia; la visibilidad pública
  depende solo de `review_status='approved'`. `provenance` nunca decide
  visibilidad.

### D-02 — Dos políticas de publicación

- **API pública:** solo `approved`; sin aprobado → `null` + `untranslated=true`.
  Nunca se sirve `machine`/`unreviewed`/`draft`/`in_review` como aprobado,
  aunque sea el texto original.
- **Administración:** puede consultar estados no aprobados informando estado y
  procedencia; es un canal con contrato propio.
- `ALLOW_UNREVIEWED_DISPLAY=false` gobierna **solo** administración; no existe
  opción que relaje la API pública. Hoy no existe en el código.

### D-03 — Fallback único y declarado, con idioma efectivo por campo

- Cadena pública: `requested_language` → idioma de origen declarado →
  `is_fallback` → `is_bridge` → `is_default` → `es-AR` global → `null`.
- Solo se consideran candidatos `approved`. No existe el paso "servir original
  `unreviewed`".
- `meta.field_languages` informa el idioma efectivo de cada campo.
  `Content-Language` se emite solo si **todos** los campos comparten idioma; si
  hay mezcla se omite.
- La generación de la cadena y el filtro editorial son dos etapas separadas
  (D-30). El cálculo preciso de `available_languages`, `effective_language` y
  `field_languages` se define en D-38.

### D-04 — Reutilizar `os_catalog_item_version` y `os_catalog_term`

- Ya tienen `language_code` y la versión tiene `UNIQUE (item_id, release_id,
  language_code)` (`origen_catalog_engine.sql:72-90`). Se enriquecen, no se
  duplican; sin columnas `*_es`/`*_en`/`*_pt`.

### D-05 — SNOMED CT y CIE-10: estructura nativa y `es` sin dialecto inventado

- Se conservan `snomed_descriptions` y `cie10_descriptions` con `id`,
  `effective_time`, `module_id`, `type_id`, `case_significance_id`; CIE-10 no
  tiene `effective_time` y no se inventa.
- **Verificado:** `sct2.description.language_code` es ISO-639-1 `es`/`en`
  (`tools/sql/snomed/01_esquema.sql:72-87`); los refsets están en
  `sct2.refset_language`/`sct2.language_effective`
  (`tools/sql/snomed/03_postcarga.sql:119-124`, `:199-219`) y el catálogo
  registra `450828004` "Español de América Latina" con `filter_code=NULL`
  (`:418`). `split_part(language_code,'-',1)` en `:692` es normalización
  defensiva, no fuente de dialecto.
- **No inferir `es-AR` desde `es`:** conservar `es`, `dialect_determined=false`,
  exponer `rf2_language_tag` real y el refset de procedencia. Un cliente `es-AR`
  recibe `es` con `effective_language='es'` y
  `fallback_reason='rf2_dialect_undetermined'` cuando `es` está aprobado.
- **Búsqueda:** las descripciones `es` no se mezclan con traducciones regionales
  sin declararlo; `v_search_term` filtra hoy solo `es` (`:466-476`).

### D-06 — `scope_release_id`: `ON DELETE RESTRICT` y pertenencia al catálogo

- Se rechaza `ON DELETE SET NULL`: borrar un release no puede volver global una
  traducción ligada a él.
- La FK simple no basta: el trigger comprueba que
  `os_catalog_release.catalog_id` coincida con el catálogo de la entidad
  (`catalog_category`, `catalog_release`, `fee_schedule`, `concept_mapping` vía
  ítem). Entidades sin ámbito de catálogo requieren `scope_release_id IS NULL`
  salvo declaración explícita. La concurrencia se controla según D-35.

### D-07 — Procedencia por campo clínico

- Las columnas de fila de `os_catalog_item_version` solo son válidas para los
  seis campos clínicos si **todos comparten fuente, publicación y estado**.
- Si difieren, `os_field_review` guarda el estado vigente por campo. Ante duda:
  `unknown`, no publicable.

### D-08 — LOINC: tabla especializada y prioridad determinista

- `loinc_localized_text` con `loinc_code VARCHAR(20) REFERENCES loinc(loinc)`,
  `language_code` (`en`/`es-MX`/`es-AR`), `field_name`, `source_file`,
  `source_release`, `version_last_changed`, `source_priority`.
- Conviven todas las capas: `source_file` forma parte de la clave. Ninguna
  variante sobrescribe a otra (el importador actual sí lo hace:
  `importar_loinc.sql:170-182`, `:218-230`, `:247-251`).
- Prioridad: mayor `source_priority` → menor `source_file` (alfabético) →
  `version_last_changed` más reciente → conflicto a reconciliar, nunca orden de
  inserción. `en`/`Loinc.csv`=10; `en`/`ConsumerName.csv`=20 solo para
  `consumer_name`; `es-MX` y `es-AR`=10 desde su único CSV.
  `definition_description` solo desde `Loinc.csv` en `en`.
- `source_release='2.83'` debe **confirmarse** contra el archivo realmente
  usado en el backfill antes de escribirlo; no se asume.
- La prioridad se mantiene centralizada y los duplicados reales se resuelven
  según D-33.

### D-09 — DENTAR: campos clínicos omitidos y términos

- Agregar `short_definition`, `lay_terms`, `clinical_scope` a
  `os_catalog_item_version`; publicar `dentar_diagnosis.clinical_name` como
  `preferred_term` del ítem `dentar-dx`.
- Conservar `abbreviation→acronym` de `sync_dentar_to_os.sql:305-312` y
  `:427-434`, y la exclusión de `preferred` en `:324`/`:445`. No duplicar.
- El término debe tener el mismo `language_code` que su versión padre.
- `preferred_term` obligatorio **solo para ítems con denominación clínica**
  (procedimientos DENTAR-PR y diagnósticos DENTAR-DX), no para ítems
  administrativos o de catálogo sin esa semántica.

### D-10 — Auditoría con actor real

- `os_translation_review` registra `actor_type`
  (`user`/`importer`/`system`/`db_role`), `application_user_id`,
  `importer_run_id`, `session_user` (evidencia), `actor_identified`, tabla,
  registro, campo, idioma, acción, valores anterior/nuevo, fecha, procedencia,
  estado y transacción.
- La aplicación y el importador fijan su identidad en la misma transacción;
  `SESSION_USER` no identifica al autor porque varias personas comparten la
  cuenta de aplicación. Si falta identidad: `db_role` + `actor_identified=false`.
- Es auditoría **recuperable** y append-only por permisos: no se afirma
  inmutabilidad criptográfica.
- La trazabilidad de cambios de contenido y de estado se detalla en D-31/D-32.

### D-11 — `os_catalog_term`: DDL real

- `term_type` admite `preferred` hoy y **no hay UNIQUE**
  (`origen_catalog_engine.sql:84-90`, GIN en `:104`). Se añaden trigger que
  rechaza `preferred` y `UNIQUE (item_version_id, language_code, term,
  term_type)`; `preferred_term` de la versión sigue siendo autoritativo.

### D-12 — Responsabilidades separadas: vigente vs histórico

- `os_field_review` = **estado editorial vigente por campo**.
  `os_translation_review` = **historial de cambios**. No duplican
  responsabilidades: el primero responde "¿qué vale ahora?", el segundo
  "¿qué pasó?".
- Precedencia: fila de `os_field_review` > valores de fila (solo si se cumple
  D-07) > `unknown`. El desempate entre registros globales y por release se
  define en D-28.

### D-13 — Configuración de idioma en `os_catalog_language`

- `is_default`, `is_fallback`, `is_bridge` y `coverage_status` viven en la tabla
  nueva. `is_bridge` es **opcional**: 0 o 1 por catálogo, nunca más de uno.
  `is_default` e `is_fallback` son exactamente 1 por catálogo.
- `os_catalog` no tiene columnas de idioma: no inventarlas.

### D-14 — `os_localized_text`: lista cerrada y límites polimórficos

- 12 `entity_type` verificados; excluidos `catalog_family`,
  `dental_structure`, `loinc`, `nomenclador_2025`, CDT, SNOMED/CIE-10 y
  versión/término de concepto. `entity_type='nomenclador'` corresponde
  únicamente a `nomencladores_argentina` (D-37).
- `entity_type + entity_id` **no es FK nativa**. Controles: validación en
  INSERT/UPDATE, inmutabilidad de entidad, RESTRICT en borrado, operaciones
  masivas con reconciliación, concurrencia resuelta por índice único,
  `field_name` por entidad, pertenencia de release y reconciliación periódica.
  `TRUNCATE` y cambios de mapeo requieren además restricción de privilegios o
  event trigger; la concurrencia se detalla en D-35.

### D-15 — Tres clases de etiquetas de idioma y `q=0`

1. **Admitidas/seleccionables por el cliente** (`os_language.is_active=true`):
   `es-AR`, `en`, `pt-BR`.
2. **Alias** (`os_language_alias`): `es→es-AR`, `pt→pt-BR`.
3. **Etiquetas de origen** (`is_source_only=true`, `is_active=false`): `es`
   (SNOMED/CDT), `es-MX` y `es-AR` como variantes LOINC. No son seleccionables
   como `lang`, pero **sí pueden ser `effective_language`** de contenido
   aprobado; no se convierten a `es-AR` (D-27).
- `es-MX` no se aliasa a `es-AR`. La variante LOINC `es-AR` es origen aunque
  coincida textualmente con un locale admitido.
- `Accept-Language` con **todos los valores `q=0`**: no se elige silenciosamente
  uno de ellos. Se aplica `API_DEFAULT_LANG` con
  `fallback_reason='no_acceptable_language'` y `q_zero_only=true`.

### D-16 — Migración aditiva y rollback verificable

- DDL en transacción; `CREATE INDEX CONCURRENTLY` fuera; backups por fase;
  rollback = restauración + reproceso, **sin reversibilidad automática** tras
  escrituras nuevas.
- La prohibición de `DROP` se refiere a tablas, columnas y datos; la excepción
  controlada para índices inválidos se define en D-34.

### D-17 — PMO independiente y bloqueante para su carga

- `os_catalog_item.observation` no existe; `PMOE-201-2002` solo en comentario
  (`02_pmo_practicas.sql:192`), release real `2026-v1`. No se mezcla con la
  migración, pero bloquea la carga PMO.

### D-18 — Backfill sin invención

- Prohibido asignar `official_source`, `approved` o `source_language_code` sin
  evidencia. Sin evidencia: `unknown`/`NULL`/`language_evidence='undetermined'`.
- Reporte de reconciliación por fase con clave `(tabla, campo, idioma, fuente)`,
  filas y checksums. No se crea tabla nueva para el reporte.

### D-19 — Clasificación y aprobación inicial del contenido existente

- Se incorpora una **etapa explícita** entre el backfill y las pruebas de API.
- Dos caminos, ambos documentados y firmados:
  1. **Aprobación por autoridad demostrable:** solo registros cuya fuente
     oficial, versión y ámbito puedan probarse; se registra quién aprueba,
     cuándo y con qué evidencia. **No** se aprueba automáticamente todo lo que
     venga de una fuente oficial.
  2. **Pendiente editorial:** se mantiene `unknown`/`unreviewed` hasta que
     exista revisión real; mientras tanto no es publicable.
- Si no hay aprobación documentada, las pruebas 1-3 del plan **no** pueden
  esperar texto aprobado: el resultado esperado pasa a ser `null` +
  `untranslated=true`. La aprobación es un prerrequisito verificable de esas
  pruebas, no una suposición.

### D-20 — Dual-read condicionado por la política de publicación

- `dual-read` es un mecanismo de **compatibilidad de esquema**, no una
  excepción editorial. La lectura a columna original solo se permite si:
  - el campo tiene un registro vigente `approved` en `os_field_review` o en la
    versión (bajo D-07), **y** el endpoint aplica la política pública; o
  - el endpoint es de administración y declara estado/procedencia.
- Si no hay registro aprobado, **no se cae** a la columna original en la API
  pública: se devuelve `null` + `untranslated=true`.

### D-21 — Definición formal de `os_field_review`

- Clave lógica: `(target_table, target_id, field_name, language_code,
  scope_release_id)`. Se materializa con **dos índices únicos parciales**, uno
  para `scope_release_id IS NULL` y otro para `IS NOT NULL` (D-28); no una PK de
  cuatro columnas con `scope_release_id` opcional.
- Columnas: procedencia, estado, idioma de origen, `language_evidence`,
  `source_reference`, `reviewed_by`, `reviewed_at`, `updated_at` y
  `content_hash` (D-31).
- Representa el **estado editorial vigente**; los cambios se registran en
  `os_translation_review` (D-12, D-32). Si difieren versión y campo, prevalece
  el campo según D-28.

### D-22 — CDT: `nombre_es` justifica `es`, no `es-AR`

- `nombre_en` → `source_language_code='en'`, `language_code='en'`.
- `nombre_es` → `source_language_code='es'`, `language_code='es'`,
  `dialect_determined=false`. `es-AR` solo con evidencia regional adicional.
  Igual criterio para `descripcion_es`.
- CDT conserva sus tablas nativas; **no** se escribe en `os_localized_text` bajo
  `entity_type='nomenclador'` (D-37).

### D-23 — Matriz única de auditoría y cobertura

- Tablas auditadas (8): `os_catalog_item_version`, `os_catalog_term`,
  `os_localized_text`, `os_field_review`, `loinc_localized_text`,
  `snomed_descriptions`, `cie10_descriptions`, `os_concept_mapping`.
- La frase "seis tablas" queda eliminada: la sexta que faltaba en la Fase 3 era
  `os_localized_text`. La incorporación por fase se detalla en D-29:
  `loinc_localized_text` entra en **Fase 5**, no en Fase 3.
- Cobertura del 100 % de **escrituras confirmadas**: triggers de fila para
  INSERT/UPDATE/DELETE, guardas de operaciones masivas, identidad de importador
  y auditoría de intentos de borrado desde la aplicación. PostgreSQL no ofrece
  auditoría autónoma equivalente a transacción independiente: los intentos
  rechazados que revierten la transacción se registran en el log de la
  aplicación/importador y se declaran como tal.

### D-24 — Índices concurrentes: verificación y reparación

- `CREATE INDEX CONCURRENTLY IF NOT EXISTS` no valida un índice inválido
  preexistente. Procedimiento: consultar `pg_class`/`pg_index` por nombre y
  `indisvalid`/`indisready`; comparar definiciones con `pg_get_indexdef` para
  detectar duplicados; antes de un índice único, detectar duplicados de datos;
  si existe índice inválido, retirarlo con la excepción controlada de D-34 y
  recrearlo; reintentar con nombre nuevo si hace falta; verificar
  `indisvalid=true`.
- El índice único parcial **no reemplaza** las validaciones del trigger
  polimórfico (D-35).

### D-25 — Restauración y checksums reproducibles

- Probar el backup en una **base de datos independiente**, no solo en un esquema
  temporal: verificar extensiones, roles, funciones, triggers, secuencias y
  permisos.
- Checksum por tabla con consulta canónica documentada: columnas explícitas en
  orden fijo, `ORDER BY` por PK, representación determinista de `NULL`, sin
  recortes ni normalizaciones ocultas; registrar versión de PostgreSQL,
  codificación y collation. Guardar la consulta exacta usada.

### D-26 — Verificación de códigos de prueba en staging

- `DNT-PR-000001` aparece en el SQL del proyecto, pero eso no demuestra que
  exista en staging ni que tenga contenido aprobado. Antes de usarlo: verificar
  catálogo, ítem, versión vigente, texto `es-AR` aprobado y comportamiento de
  `en`/`pt-BR`. Si no cumple, elegir otro código real de staging y documentarlo.
- Igual criterio para `<loinc_con_capas>` y `<sctid_real>`.

---

## 2. Aclaraciones finales (D-27 a D-38)

### D-27 — Idioma seleccionable por el cliente vs. idioma efectivo del contenido

- `is_active` gobierna la **entrada** (`lang`, `Accept-Language`); `is_source_only`
  identifica etiquetas que no pueden pedirse como locale. Ninguna de las dos
  impide que una fila aprobada tenga `language_code='es'` y se devuelva como
  `effective_language='es'`.
- **SNOMED `es`:** el cliente pide `es-AR`; el resolvedor propone `es-AR`, no
  hay candidato aprobado en ese idioma; el evaluador encuentra `es` aprobado y
  devuelve `effective_language='es'`, `source_language='es'`,
  `fallback_reason='rf2_dialect_undetermined'`, `dialect_determined=false`.
  Nunca se reescribe como `es-AR`.
- **CDT `es`:** el cliente pide `es` (alias a `es-AR`) o `es-AR`; si el texto
  aprobado es `nombre_es`/`descripcion_es`, se devuelve
  `effective_language='es'`, `source_language='es'`, `dialect_determined=false`.
  `es` no se convierte en `es-AR`.
- Las etiquetas `is_source_only` aparecen en `available_languages` marcadas como
  no seleccionables (D-38).

### D-28 — Unicidad de `os_field_review` y precedencia global/release

- Se rechaza la PK de cuatro columnas con `scope_release_id` opcional. Se usan
  dos índices únicos parciales:
  - `uq_fr_global ON os_field_review (target_table, target_id, field_name,
    language_code) WHERE scope_release_id IS NULL`.
  - `uq_fr_scoped ON os_field_review (target_table, target_id, field_name,
    language_code, scope_release_id) WHERE scope_release_id IS NOT NULL`.
- `UNIQUE NULLS NOT DISTINCT` es alternativa válida en PostgreSQL 18, pero se
  prefiere la solución de índices parciales por coherencia con
  `os_localized_text`.
- Precedencia para un mismo campo: fila con `scope_release_id` igual al release
  solicitado > fila global (`NULL`) > valores de fila bajo D-07 > `unknown`.
  Una fila específica de **otro** release no se aplica; no se "hereda" entre
  releases.

### D-29 — Matriz de auditoría por fase

| Fase | Tablas con auditoría activa al cierre de la fase |
|---|---|
| 2 | `os_field_review` (tabla creada en esta fase). |
| 3 | `os_catalog_item_version`, `os_catalog_term`, `os_localized_text`, `os_field_review`, `snomed_descriptions`, `cie10_descriptions`, `os_concept_mapping` (**7**). |
| 4 | Las 7 anteriores; la matriz de aprobación 4.3 se registra como eventos de `os_field_review`/`os_translation_review`. |
| 5 | Las 7 anteriores **+ `loinc_localized_text`** (**8**). |
| 6-14 | Las 8 permanecen activas; no se añaden tablas nuevas a la auditoría. |

`os_translation_review` es el historial, no una novena tabla auditada: registra
los cambios de las 8 tablas.

### D-30 — LanguageResolver separado del evaluador editorial

1. **LanguageResolver (solo idioma):** lee `lang` → alias → `Accept-Language`
   con `q` → `API_DEFAULT_LANG`, valida contra `os_language.is_active` y
   `os_catalog_language`, y produce una **lista ordenada de idiomas candidatos**.
   **No consulta** `os_field_review`, `review_status` ni contenido.
2. **Evaluador editorial (solo publicación):** para cada campo toma esa lista de
   idiomas seleccionables y la **amplía** con el idioma de origen declarado
   (`source_language_code`) y los idiomas configurados del catálogo
   (`is_fallback`, `is_bridge` si existe, `is_default`) y el `es-AR` global. Esa
   ampliación es necesaria porque, según D-27, el contenido aprobado puede tener
   una etiqueta `is_source_only` como `es` que el resolvedor no propone como
   entrada. Para cada candidato ampliado consulta el estado vigente según D-28
   y descarta todo `review_status` distinto de `approved`. Elige el primer
   candidato aprobado y declara su `language_code` como `effective_language` del
   campo (sin reescribir `es` a `es-AR`). Si ninguno está aprobado, devuelve
   `null` + `untranslated=true` + `fallback_reason='no_approved_content'`.
3. El `content_hash` y la invalidación de D-31 se evalúan aquí, antes de servir.
   El evaluador calcula además `field_languages` por campo, `available_languages`
   con `selectable` y `meta.effective_language=null` si los campos mezclan
   idiomas (D-38).
4. El dual-read de D-20 se aplica **después** de esta evaluación: si el
   evaluador no encontró contenido aprobado, la columna original no se usa como
   atajo.

### D-31 — Invalidación de aprobación cuando cambia el contenido

- Se añade `content_hash` a `os_field_review` y a las tablas de contenido
  auditadas: resumen determinista del valor del campo, su `language_code` y su
  `source_reference`. No es una firma criptográfica.
- Un trigger `BEFORE UPDATE` compara el hash antiguo y el nuevo. Si el contenido
  cambia, **en la misma transacción**:
  1. se actualiza el contenido;
  2. se fuerza `review_status='unreviewed'` (o `draft` si el flujo editorial lo
     define así) en `os_field_review` o en la fila equivalente;
  3. se limpian `reviewed_by`/`reviewed_at` y se regenera `content_hash`;
  4. se inserta el evento `approval_invalidated` en `os_translation_review`.
- Aplica también a `INSERT ... ON CONFLICT DO UPDATE` de importadores. Una
  aprobación anterior nunca permanece silenciosamente vigente tras un cambio de
  texto.
- La re-aprobación es un acto editorial posterior (D-19), con actor identificado
  y nuevo evento `approval_granted`.

### D-32 — Trazabilidad en `os_translation_review`

- `event_type` incluye: `content_changed`, `approval_invalidated`,
  `approval_granted`, `review_state_changed`, `new_translation`,
  `new_official_publication`, `editorial_correction`, `deprecate`.
- `action` incluye: `create`, `update`, `approve`, `invalidate`, `deprecate`.
- Todo cambio de estado en `os_field_review` genera un evento con
  `target_table='os_field_review'`; todo cambio de texto genera un evento con la
  tabla de contenido correspondiente. Ambos comparten `transaction_id`.
- `actor_type`, `application_user_id`/`importer_run_id` o `db_role` son
  obligatorios según D-10; `SESSION_USER` nunca sustituye al actor real.

### D-33 — LOINC: prioridad centralizada y duplicados reales

- `source_priority` se **materializa** en `loinc_localized_text.source_priority`,
  pero se calcula en un único lugar: la regla central
  `loinc_source_priority(language_code, source_file, field_name)`, invocada por
  el trigger de carga y por la vista de resolución. No se reparte la regla entre
  importadores ni controladores.
- Clave de unicidad: `(loinc_code, language_code, field_name, source_file,
  source_release, version_last_changed_normalizada)`. La normalización de
  `version_last_changed` (incluido `NULL` → centinela documentado) se aplica en
  el trigger de carga.
- Resolución determinista: mayor `source_priority` → menor `source_file` →
  `version_last_changed` más reciente. El `id` no interviene: nunca se decide
  por orden de inserción.
- Duplicados exactos se descartan con `ON CONFLICT DO NOTHING`. Si dos filas
  comparten clave y tienen `value` distinto, se marca **conflicto a
  reconciliar** y no se publica ninguna hasta resolución humana; la resolución
  se registra en `os_translation_review`.

### D-34 — Excepción controlada a la prohibición de `DROP` para índices

- La regla aditiva prohíbe `DROP TABLE`, `DROP COLUMN`, `TRUNCATE` y `DELETE` de
  datos. **No prohíbe** retirar un objeto índice inválido o duplicado.
- `DROP INDEX CONCURRENTLY IF EXISTS <nombre>` se permite solo si:
  1. el índice está `indisvalid=false`/`indisready=false` o es duplicado
     exacto detectado por `pg_get_indexdef`;
  2. fue creado por esta migración, o existe autorización escrita del DBA y del
     responsable del plan para ese índice concreto;
  3. se registra el motivo, el nombre, la definición previa y la aprobación en
     el reporte de fase y en `os_translation_review` como evento de sistema;
  4. se ejecuta **fuera** de transacción y se recrea con `CONCURRENTLY`.
- Nunca se elimina un índice válido sin esa autorización; nunca se usa esta
  excepción para modificar tablas, columnas ni datos.

### D-35 — Integridad polimórfica bajo concurrencia

- El trigger de existencia **no equivale a una FK nativa**. Además:
  - `INSERT`/`UPDATE` en `os_localized_text` toma
    `pg_advisory_xact_lock(hashtext(entity_type || ':' || entity_id))` y, si
    aplica, `pg_advisory_xact_lock(hashtext('release:' || scope_release_id))`.
  - Los triggers `BEFORE DELETE` de las 12 entidades referenciadas toman el
    mismo lock antes de comprobar si existen traducciones y aplicar `RESTRICT`.
  - La comprobación de pertenencia del release al catálogo se hace dentro del
    mismo lock.
  - Dos inserciones simultáneas se arbitran además con el índice único
    parcial; `TRUNCATE` queda fuera del trigger de fila y se controla por
    privilegios o event trigger.
- La reconciliación periódica sigue siendo obligatoria.

### D-36 — Nullabilidad final de columnas nuevas

- Las columnas con valor semántico conocido se crean `NOT NULL` desde Fase 2 o 3
  con `DEFAULT` explícito: `provenance`, `review_status`, `language_evidence`,
  `updated_at`, `content_hash`, `actor_type`, `occurred_at`, además de las
  claves y `language_code` ya `NOT NULL` en el DDL real.
- Permanecen `NULL` permitido: `source_language_code`, `source_reference`,
  `reviewed_by`, `reviewed_at`, `valid_from`, `valid_to`, `scope_release_id`,
  `dialect_determined` cuando no hay evidencia, `previous_value` y
  `application_user_id`/`importer_run_id` según actor.
- **Fase 13 no introduce `NOT NULL` nuevos**: solo verifica este estado. Cualquier
  `SET NOT NULL` debe haberse previsto y aplicado en la fase de creación,
  después del backfill y con evidencia/valor por defecto.

### D-37 — CDT y nomencladores: tablas e identificadores reales

- `entity_type='nomenclador'` está reservado a `nomencladores_argentina`
  (`id SERIAL PK`, `codigo VARCHAR(30)`, `capitulo`, `descripcion`;
  `origen_catalog_engine.sql:7594-7609`). Sus `field_name` son `capitulo` y
  `descripcion`. **No se usa para CDT.**
- CDT conserva sus tablas nativas: `odontologia_cdt_categorias` (PK `codigo`
  VARCHAR, `nombre_en`/`nombre_es`), `odontologia_cdt_catalogo` (PK `codigo_cdt`
  VARCHAR(10), `descripcion_en`/`descripcion_es`) y
  `odontologia_prestaciones` (PK `id SERIAL`, `codigo_nomenclador` UNIQUE,
  `descripcion` española, `cdt_code`, `cdt_categoria_es`;
  `Argentina_dental_cdt_codes_2025.sql:28-33`, `:136-140`, `:4594-4601`).
  Por sus claves alfanuméricas, **no caben en `entity_id BIGINT`** y no se
  inventa una relación con `os_localized_text`.
- Rutas reales: `GET /v1/nomenclador` consulta `nomencladores_argentina`
  (`api/index.php:234-239`; `TerminologySearchService.php:1423-1442`);
  `GET /v1/search/odontologia` consulta `odontologia_prestaciones`
  (`TerminologySearchService.php:40`, `:256-278`);
  `GET /v1/odontologia/{id}` es el detalle (`api/index.php:439-444`).
  No se crea `/v1/cdt` ni se afirma que `/v1/nomenclador` sirve CDT.
- NN 2025 (`nomenclador_2025.codigo VARCHAR(20) PK`,
  `Nomenclador_Nacional_2025.sql:8-12`) **no tiene endpoint propio** y no se
  mapea a `os_*` en esta versión; su exposición futura sigue pendiente.

### D-38 — Cálculo preciso del contrato API

- `available_languages`: lista de `language_code` distintos con al menos un
  campo `approved` para el recurso/release. Cada entrada informa
  `selectable = os_language.is_active`. Incluye `es`/`es-MX` cuando están
  aprobados, marcados `selectable=false`.
- `effective_language`: idioma del candidato aprobado elegido **para cada
  campo**. A nivel `meta` solo se informa un `effective_language` si todos los
  campos comparten idioma; si hay mezcla, `meta.effective_language=null` y
  `field_languages` es la fuente de verdad.
- `field_languages`: mapa por campo con `effective_language`,
  `source_language`, `provenance`, `approval_state`, `fallback_applied`,
  `fallback_reason` y `untranslated`, calculado por el evaluador editorial
  (D-30). Un campo `null` por falta de aprobado tiene
  `effective_language=null` y `fallback_reason='no_approved_content'`.
- `Content-Language` solo se emite si todos los campos comparten idioma;
  `Vary: Accept-Language` siempre.

---

## 3. Matriz de coherencia entre documentos

| Tema | Auditoría | Modelo | Plan | Decisiones |
|---|---|---|---|---|
| Aprobación inicial `unknown`→`approved` | §1 h. 19, §6 | §2.3 | Fase 4, etapa 4.3 | D-19 |
| Dual-read sin eludir publicación | §1 h. 20 | §7.4, §9 | Fase 11 | D-20, D-30 |
| Seleccionable vs efectivo | §1 h. 27 | §5.1, §7.1 | Fases 7-9 | D-15, D-27, D-38 |
| Unicidad `os_field_review` | §1 h. 28 | §5.5 | Fase 2 | D-21, D-28 |
| Auditoría por fase | §1 h. 29 | §5.4 | Fases 2/3/5 | D-23, D-29 |
| Resolver vs editorial | §4.1 | §7.2-7.4 | Fases 8-9 | D-30 |
| Invalidación de aprobación | §1 h. 31 | §5.5 | Fase 4/11 | D-31, D-32 |
| LOINC prioridad centralizada | §3.5 | §4.4 | Fase 5 | D-08, D-33 |
| Excepción `DROP INDEX` | §3.1 | §5.3 | Fase 2 | D-16, D-24, D-34 |
| Concurrencia polimórfica | §3.1 | §5.3 | Fase 2 | D-14, D-35 |
| Nullabilidad final | §6 | §5.6 | Fases 2/3/13 | D-36 |
| CDT/NN reales | §3.6, §7 | §6 | Fase 10 | D-22, D-37 |
| Contrato API | §8 | §7.6 | Fase 9, pruebas | D-03, D-38 |

---

## 4. Decisiones pendientes

1. Aprobación formal de este registro y del modelo antes de cualquier DDL.
2. Ejecutar la etapa 4.3 de clasificación/aprobación inicial y firmar su matriz.
3. Definir destino de tags PMO y corregir `02_pmo_practicas.sql` (bloquea PMO).
4. Parametrizar idioma en importadores conservando `abbreviation→acronym` y la
   invalidación de D-31.
5. Confirmar en staging los códigos de prueba y las capas LOINC.
6. Confirmar `source_release` real de los CSV LOINC.
7. Elegir el mecanismo de identidad de aplicación y el rol propietario de
   auditoría.
8. Implementar `LanguageResolver`, evaluador editorial, API per-field y sitio.
9. Decidir el mapeo/endpoint futuro de NN 2025 y vocabulario FDI/caras.
10. Aprobar por escrito la excepción D-34 para cada índice inválido que aparezca.

---

## 5. Riesgos abiertos

- Sin aprobación inicial, la API pública quedaría sin contenido: mitigado por
  D-19 y por pruebas condicionadas.
- Dual-read mal implementado puede publicar texto no aprobado: mitigado por
  D-20 y D-30.
- Aprobaciones obsoletas tras cambio de texto: mitigado por D-31/D-32.
- Índices inválidos por reejecución: mitigado por D-24 y D-34.
- `es-AR` inferido de `es` o de `nombre_es`: mitigado por D-05, D-22 y D-27.
- Auditoría incompleta en operaciones masivas: mitigado por D-23, D-29 y D-32,
  con la limitación declarada de transacciones revertidas.
- CDT/NN mal mapeados a entidades o rutas inexistentes: mitigado por D-37.
- Capas LOINC ya sobrescritas; `observation` de PMO inexistente;
  `Accept-Language` no implementado; UI de búsqueda ausente.
- Cero ejecución y cero aprobación hasta la fecha: **todo sigue pendiente**.
