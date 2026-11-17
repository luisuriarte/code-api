# Plan de migración multilingüe — Origen Salud

> ⚠️ **ESTE DOCUMENTO ES UN PLAN, NO UNA EJECUCIÓN.**
> No se han ejecutado migraciones, no se ha modificado PostgreSQL, no se han
> borrado tablas/columnas/datos, no se han tocado fuentes originales, API, sitio
> web ni importadores. No se ha hecho commit ni push. No se ha operado sobre
> producción. Requiere aprobación explícita antes de cualquier implementación.
>
> La referencia de decisiones es
> [`decisiones-arquitectura-multilingue.md`](decisiones-arquitectura-multilingue.md).
> Complementa [`auditoria-internacionalizacion.md`](auditoria-internacionalizacion.md)
> y [`modelo-multilingue-propuesto.md`](modelo-multilingue-propuesto.md).
>
> Numeración de decisiones: **D-05 = SNOMED CT/CIE-10**, **D-09 = DENTAR**,
> **D-14 = `os_localized_text`**. Las aclaraciones finales **D-27 a D-38** y las
> precisiones **D-39 a D-41** son parte del plan y corrigen cualquier redacción
> anterior.

---

## 1. Objetivo y alcance

Migrar de un modelo mayoritariamente monolingüe (`es-AR` embebido) a un modelo
donde conceptos, definiciones, sinónimos, metadatos y textos de estándares
puedan consultarse en `es-AR`, `en` y `pt-BR`, sin duplicar catálogos ni
conceptos y sin perder la historia existente.

**Fuera de alcance:** ejecución real, DDL aplicado, carga de traducciones,
cambios de código en API/web/importadores, modificación de `tools/sources/**` y
las correcciones de PMO (§6, trabajo independiente y bloqueante para esa carga).

**Código de ejemplo verificado en SQL:** `DNT-PR-000001` existe en
`sql/02_catalogs/origen_catalog_engine.sql:399-410`; `01.01` es un identificador
DENTAR real. `010101` **no** es un código DENTAR válido. Para LOINC y SNOMED se
usan marcadores (`<loinc_con_capas>`, `<sctid_real>`) que deben resolverse
contra filas existentes en staging: no se inventan códigos (D-26).

---

## 2. Estrategia general

| Principio | Aplicación concreta |
|---|---|
| Aditiva | Solo `CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, `INSERT`, `UPDATE`. Sin `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, `DELETE` ni `ALTER COLUMN ... DROP` de datos existentes. Única excepción controlada: retirar un índice inválido/duplicado con autorización (D-34). |
| Idempotente | `IF NOT EXISTS`, `ON CONFLICT DO NOTHING/UPDATE`, guardas sobre `pg_constraint`/`pg_trigger` y verificación de `indisvalid`. |
| Sin evidencia, sin aprobación | `provenance='unknown'`, `review_status='unknown'`, `source_language_code=NULL`; nunca `official_source`/`approved` automáticos (§5). |
| Aprobación explícita | Etapa 4.3: la aprobación inicial se documenta y firma; no se deriva del backfill (D-19). |
| Backfill antes que lectura | Las tablas nuevas se pueblan antes de que la API las consulte. |
| Dual-read condicionado | Compatibilidad de esquema, **nunca** excepción a `review_status` (D-20). |
| Idioma ≠ editorial (D-30) | `LanguageResolver` produce candidatos; el evaluador editorial filtra por `approved`. El estado de `os_field_review` no selecciona idioma. |
| Invalidación transaccional (D-31/D-32) | Cambiar contenido recalcula `content_hash`, fuerza `unreviewed`, limpia revisión y escribe `approval_invalidated` en la misma transacción. |
| Ámbito del hash (D-41) | Aprobación compartida: un cambio invalida toda la fila (`row_shared`); revisión individual: un cambio invalida solo ese campo (`field_individual`). |
| Etiqueta vs. procedencia (D-39) | `is_source_only` solo para `es`/`es-MX`; LOINC `es-AR` conserva procedencia en la fila y sigue seleccionable. |
| Idioma de origen LOINC (D-40) | `source_language_code` se deriva con `loinc_source_language(...)`; no se almacena como columna nueva. |
| Auditoría por fase (D-29) | Fase 2: `os_field_review`; Fase 3: 7 tablas; Fase 5: se incorpora `loinc_localized_text` y completa 8. |
| Diferenciación transaccional | DDL y datos en transacción; índices concurrentes **fuera** de transacción. |
| Aprobación por fase | No se avanza sin validar la fase anterior. |

### 2.1 Operaciones transaccionales vs. concurrentes

| Tipo | Operaciones | Regla |
|---|---|---|
| Transaccionales (`BEGIN`/`COMMIT`, `ON_ERROR_STOP=1`) | `CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, `ADD CONSTRAINT`, backfill, triggers, `COMMENT`, `ANALYZE` | Cualquier error hace `ROLLBACK`. |
| No transaccionales | `CREATE INDEX CONCURRENTLY`, `CREATE UNIQUE INDEX CONCURRENTLY` | **No pueden ir dentro de `BEGIN`/`COMMIT`**. Sentencias independientes con verificación de `pg_index.indisvalid`. |
| No transaccional, excepción (D-34) | `DROP INDEX CONCURRENTLY IF EXISTS <nombre>` | Solo para índices inválidos o duplicados exactos creados por esta migración o autorizados por escrito; motivo y definición previa registrados; fuera de transacción; recrear con `CONCURRENTLY`. Nunca para tablas/columnas/datos. |
| Nullabilidad (D-36) | `VALIDATE CONSTRAINT` | Las columnas con semántica conocida se crean `NOT NULL DEFAULT` en Fases 2/3. Fase 13 **solo verifica**; no introduce `SET NOT NULL` nuevos. |

### 2.2 Backups, restauración y checksums reproducibles

Antes de **cada** fase: `pg_dump` en desarrollo/staging con SHA-256. La
restauración de prueba se hace en una **base de datos independiente**, no solo
en un esquema temporal (D-25), para verificar extensiones, roles, dependencias,
funciones, triggers, secuencias y permisos sin interferir con la original.

Checksum reproducible por tabla: columnas explícitas en orden fijo, `ORDER BY`
por PK, representación determinista de `NULL`, sin recortes ni normalizaciones
ocultas, registrando versión de PostgreSQL, codificación y collation. Se guarda
la consulta exacta usada. Inventario de conteos y checksums de `os_catalog`,
`os_catalog_release`, `os_catalog_category`, `os_catalog_item`,
`os_catalog_item_version`, `os_catalog_term`, `os_catalog_identifier`,
`os_concept_mapping`, `os_fee_schedule`, `os_pricing_values`,
`snomed_descriptions`, `cie10_descriptions`, `loinc`,
`nomencladores_argentina`, `vademecum_comercial`; 0 huérfanos en FK, 0
duplicados que violen UNIQUE y congelación temporal de importadores. Después de
cada fase: repetir conteos y checksums; las tablas originales deben estar
inalteradas.

---

## 3. Fases (propuestas, no ejecutadas)

### Fase 1 — Inventario y backup

- **Objetivo:** fijar el punto de partida verificable y el inventario lingüístico.
- **Archivos afectados:** ninguno de código; se generan artefactos de
  documentación/reporte. Fuentes consultadas: `sql/01_schema/design.sql`,
  `sql/02_catalogs/origen_catalog_engine.sql`, `sql/03_dentar/*`,
  `sql/04_pmo/*`, `sql/05_loinc.sql/importar_loinc.sql`, `tools/sql/snomed/*`,
  `tools/sources/**`, `api/**`, `web/**`.
- **Dependencias:** ninguna.
- **Operaciones previstas:** verificar versión de PostgreSQL y `pg_trgm`;
  `pg_dump` + SHA-256; restauración en base independiente (D-25); conteos y
  checksums canónicos; inventario de idiomas reales: `os_*` todo `es-AR`;
  SNOMED `es`/`en` (ISO-639-1, sin tag dialectal en `sct2.description`); CIE-10
  según carga; LOINC sin `language_code` (capas EN→es-MX→es-AR→ConsumerName);
  CDT con sufijos `nombre_en/nombre_es`; NN 2025 sin idioma. Confirmar que
  `os_catalog_item.observation` no existe.
- **Validaciones:** backup restaurable en base separada; checksums registrados;
  inventario firmado; 0 operaciones de escritura.
- **Criterios de aceptación:** inventario reproducible; riesgo PMO registrado
  como bloqueante de PMO, no de esta migración.
- **Riesgos:** pérdida del estado previo si el backup no es restaurable;
  confundir Fase 4 del proyecto original (PMO) con la Fase 6 de este plan
  (DENTAR).
- **Condición para avanzar:** backup verificado en base independiente y
  aprobación firmada.

### Fase 2 — Creación de estructuras lingüísticas

- **Objetivo:** crear el catálogo de idiomas y las tablas nuevas de metadatos,
  auditoría y procedencia por campo.
- **Archivos afectados:** propuesta de DDL nuevo (no aplicado): `os_language`,
  `os_language_alias`, `os_catalog_language`, `os_localized_text`,
  `os_translation_review`, `os_field_review`.
- **Dependencias:** Fase 1.
- **Operaciones previstas:** crear `os_language` con `is_active`
  (**seleccionable por el cliente**) e `is_source_only` (solo `es`/`es-MX`: no
  pedibles como `lang`, pero válidas como `effective_language` aprobada): activas
  `es-AR`/`en`/`pt-BR` con `is_source_only=false`, etiquetas de origen inactivas
  `es`/`es-MX` (D-15, D-27, D-39). **No se marca `es-AR` como source-only**
  aunque exista una capa LOINC en ese idioma: la procedencia se guarda en la fila
  de contenido, no en `os_language`; aliases `es→es-AR`, `pt→pt-BR` (sin
  `es-MX`);
  `scope_release_id ... ON DELETE RESTRICT` (nunca `SET NULL`); trigger de
  existencia polimórfica con validación de `field_name` por `entity_type`,
  inmutabilidad de `entity_type`/`entity_id`, RESTRICT en borrado de entidad y
  comprobación de pertenencia del release al catálogo; locks
  `pg_advisory_xact_lock` para entidad y release en INSERT/UPDATE y en los
  `BEFORE DELETE` de las 12 entidades (D-35), sin presentar el trigger como FK
  nativa; control de `TRUNCATE` y cambios de mapeo mediante privilegios o event
  trigger. Definir `os_field_review` como **estado vigente por campo** con
  `content_hash` y **dos índices únicos parciales** (`uq_fr_global` para
  `scope_release_id IS NULL`, `uq_fr_scoped` para `IS NOT NULL`), no una PK de
  cuatro columnas (D-21, D-28); precedencia release solicitado > global > fila >
  `unknown`. Definir `os_translation_review` como historial con eventos
  `content_changed`, `approval_invalidated`, `approval_granted`,
  `review_state_changed`, `new_translation`, `new_official_publication`,
  `editorial_correction`, `deprecate` y actor de aplicación/`importer_run_id`
  (D-10, D-32). Crear columnas con semántica conocida como `NOT NULL DEFAULT`
  (`provenance`, `review_status`, `language_evidence`, `content_hash`,
  `actor_type`, `occurred_at`); dejar `NULL` las declaradas en D-36. La
  **auditoría activa en esta fase es solo `os_field_review`** (D-29). Índices
  únicos parciales `uq_olt_global`/`uq_olt_scoped`, `uq_fr_global`/`uq_fr_scoped`
  y GIN, creados con `CONCURRENTLY` fuera de transacción.
- **Validaciones:** 3 idiomas activos; `is_bridge` **opcional** (0 o 1 por
  catálogo, nunca más de uno; `is_default` e `is_fallback` exactamente 1);
  0 filas huérfanas; `indisvalid=true` y sin índices duplicados (D-24);
  ambos pares de índices parciales presentes; locks exercitados en prueba de
  concurrencia; triggers presentes; auditoría protegida contra el rol de
  aplicación; `es`/`es-MX` no seleccionables pero aceptados como
  `effective_language` si hay fila aprobada.
- **Criterios de aceptación:** ninguna tabla existente alterada; ningún trigger
  presentado como FK nativa; `SET NULL` ausente; ausencia de PK con
  `scope_release_id` opcional; auditoría activa solo sobre `os_field_review`;
  nullabilidad final conforme a D-36.
- **Riesgos:** trigger polimórfico insuficiente ante `TRUNCATE` o cambios de
  mapeo; empates de concurrencia resueltos por índice único; olvidar el rol
  propietario de la auditoría; índice inválido preexistente que haga omitir la
  creación con `IF NOT EXISTS`.
- **Condición para avanzar:** validaciones de integridad, índices y permisos
  aprobadas.

**Procedimiento de índices concurrentes (D-24, D-34):** antes de crear, consultar
`pg_class`/`pg_index` por nombre y verificar `indisvalid`/`indisready`; comparar
definiciones con `pg_get_indexdef` para detectar duplicados; en índices únicos,
detectar duplicados de datos. Si existe índice inválido o duplicado exacto, se
permite `DROP INDEX CONCURRENTLY IF EXISTS <nombre>` solo como **excepción
controlada**: índice creado por esta migración o autorización escrita del DBA y
del responsable del plan para ese nombre concreto; motivo, definición previa y
aprobación registrados en el reporte de fase y en `os_translation_review` como
evento de sistema; ejecución fuera de transacción y recreación con
`CONCURRENTLY`. Nunca se aplica a tablas, columnas ni datos. Reintentar con
nombre nuevo si hace falta; verificar `indisvalid=true` al final. El índice
único parcial **no reemplaza** las validaciones del trigger polimórfico ni los
locks de D-35.

### Fase 3 — Ampliación de las estructuras existentes

- **Objetivo:** agregar columnas aditivas a tablas reales sin borrar nada.
- **Archivos afectados:** `os_catalog_item_version`, `os_catalog_term`,
  `snomed_descriptions`, `cie10_descriptions`, `os_concept_mapping`.
- **Dependencias:** Fase 2.
- **Operaciones previstas:** `ADD COLUMN IF NOT EXISTS` según modelo §4:
  `source_language_code` (sin FK), `language_evidence`, `provenance`,
  `review_status`, `source_reference`, `reviewed_by`, `reviewed_at`,
  `content_hash`, `updated_at`, `valid_from`, `valid_to`; campos clínicos
  `short_definition`/`lay_terms`/`clinical_scope`; `rf2_language_tag`,
  `dialect_determined` en SNOMED; `source_language_code_display` en mapeos
  (justificación: `external_display` llega en inglés desde el estándar, p. ej.
  `'ADA CDT 2025'`, y debe informarse sin alterar `language_code` del concepto;
  si difiere por campo, prevalece `os_field_review`, sin duplicar su función).
  Las columnas con semántica conocida se crean `NOT NULL DEFAULT`
  (`provenance`, `review_status`, `language_evidence`, `content_hash`,
  `updated_at`); las de D-36 permanecen nullable. Triggers de consistencia de
  idioma en `os_catalog_term` y de invalidación de aprobación por cambio de
  `content_hash` en todas las tablas de contenido (D-31/D-32). El trigger de
  `os_catalog_item_version` distingue el ámbito D-41: si los seis campos
  comparten fuente/estado, el hash agregado de la fila cubre los seis y un
  cambio en cualquiera invalida la aprobación compartida (`row_shared`); si un
  campo tiene fila en `os_field_review`, su hash individual solo invalida esa
  revisión (`field_individual`). Crear/deprecar una fila individual recalcula el
  agregado e invalida una vez la aprobación compartida. El evento registra el
  ámbito y los campos afectados. Instalar la
  auditoría sobre **7 de las 8 tablas** de la matriz D-23: en esta fase quedan
  cubiertas `os_catalog_item_version`, `os_catalog_term`, `os_localized_text`,
  `os_field_review`, `snomed_descriptions`, `cie10_descriptions` y
  `os_concept_mapping`. **`loinc_localized_text` se incorpora en Fase 5**, no
  aquí (D-29).
- **Validaciones:** nullabilidad final conforme a D-36, sin `SET NOT NULL`
  diferido a Fase 13; conteos de tablas base inalterados; columnas originales
  sin cambios; 0 triggers duplicados; auditoría activa sobre exactamente 7
  tablas, cubriendo INSERT/UPDATE/DELETE confirmados y operaciones masivas con
  límite de lote; `loinc_localized_text` aún sin auditoría.
- **Criterios de aceptación:** DDL aditivo e idempotente; `provenance` y
  `review_status` separados; `unknown` permitido; sexta tabla
  (`os_localized_text`) identificada explícitamente y octava diferida a Fase 5.
- **Riesgos:** tres definiciones divergentes de `nomencladores_argentina` y
  `vademecum_comercial` (`design.sql`, engine, script específico); agregar
  `NOT NULL` prematuramente; intentos revertidos que no generan fila de
  auditoría (se registran en log de aplicación, D-23).
- **Condición para avanzar:** verificación de la definición vigente y aprobación
  del DDL.

### Fase 4 — Backfill controlado y aprobación inicial

- **Objetivo:** poblar las columnas y tablas nuevas sin inventar procedencia,
  estado ni idioma, y dejar registrada la aprobación editorial inicial.
- **Archivos afectados:** tablas de la Fase 3 y `os_localized_text`,
  `os_field_review`; reportes de reconciliación y la matriz de aprobación
  (artefactos, no tablas nuevas).
- **Dependencias:** Fases 2 y 3.
- **Operaciones previstas:** ver §5. Asignar valores solo con evidencia
  declarada por tabla/campo/fuente. Sin evidencia → `provenance='unknown'`,
  `review_status='unknown'`, `source_language_code=NULL`,
  `language_evidence='undetermined'`. Backfill de metadatos desde columnas
  originales sin borrarlas. Registro por campo en `os_field_review` cuando los
  seis campos clínicos no compartan fuente/estado.
- **4.3 Clasificación y aprobación inicial (D-19):** etapa explícita y firmada.
  (a) **Aprobación por autoridad demostrable:** solo registros cuya fuente
  oficial, versión y ámbito puedan probarse; se registra tabla, campo, idioma,
  release, fuente, motivo, revisor y fecha. **No** aprobar automáticamente todo
  lo oficial. (b) **Pendiente editorial:** mantener `unknown`/`unreviewed` hasta
  revisión real; mientras tanto no publicable. Si no hay aprobación
  documentada, las pruebas 1-3 no pueden esperar texto aprobado: el resultado
  esperado pasa a ser `null` + `untranslated=true` (prueba 26).
- **4.4 CDT (D-22, D-37):** `nombre_en` → `language_code='en'`,
  `source_language_code='en'`; `nombre_es` → `language_code='es'` (fila
  `is_source_only` de `os_language`), `source_language_code='es'`,
  `dialect_determined=false`. Igual criterio para `descripcion_es`. **No**
  convertir `es` en `es-AR` sin evidencia regional adicional. CDT **permanece en
  sus tablas nativas** (`odontologia_cdt_categorias`, `odontologia_cdt_catalogo`,
  `odontologia_prestaciones`; `Argentina_dental_cdt_codes_2025.sql:28-33`,
  `:136-140`, `:4594-4601`): sus claves VARCHAR no caben en `entity_id BIGINT`
  y no se escribe en `os_localized_text`. `entity_type='nomenclador'` queda
  reservado a `nomencladores_argentina`. Las rutas reales son
  `/v1/search/odontologia` y `/v1/odontologia/{id}`, no `/v1/cdt` ni
  `/v1/nomenclador` (que consulta `nomencladores_argentina`).
- **Validaciones:** 0 filas con `official_source` o `approved` sin evidencia;
  0 `source_language_code` inferido; 0 conversiones `es→es-AR` desde
  `nombre_es`; cada fila nueva verificable por `(tabla, campo, idioma, fuente)`;
  matriz de aprobación firmada; conteos base inalterados.
- **Criterios de aceptación:** reporte de reconciliación completo con filas
  afectadas y checksums antes/después; `unknown` explícitamente no publicable;
  la ausencia de aprobación se traduce en respuesta vacía declarada, no en
  contenido servido.
- **Riesgos:** asignación global `es-AR`/`approved` por comodidad; deriva entre
  columna original y copia localizada; lotes grandes sin triggers (se exige
  reconciliación posterior); presión para aprobar todo lo oficial sin revisión.
- **Condición para avanzar:** reporte y matriz de aprobación revisados y
  firmados.

### Fase 5 — Migración de LOINC

- **Objetivo:** separar las capas que hoy se sobrescriben y fijar prioridad
  determinista.
- **Archivos afectados:** tabla nueva `loinc_localized_text`; fuentes leídas
  `tools/sources/loinc/{Loinc.csv,esMX28LinguisticVariant.csv,
  esAR7LinguisticVariant.csv,ConsumerName.csv}` (solo lectura); importador
  `sql/05_loinc.sql/importar_loinc.sql` **no se modifica en esta fase**.
- **Dependencias:** Fase 4.
- **Operaciones previstas:** crear tabla con `content_hash` y clave
  `(loinc_code, language_code, field_name, source_file, source_release,
  version_last_changed_normalizada)`; la normalización (incluido `NULL` →
  centinela documentado) se aplica en el trigger de carga. Backfill desde la
  tabla `loinc` actual como `language_code='en'`, `source_file='Loinc.csv'`,
  `source_release` a confirmar contra el archivo real (el valor `2.83` aparece
  en `importar_loinc.sql:2-5`, pero debe verificarse antes de escribirse; D-08),
  sin marcar `approved`. `source_priority` se calcula con la función central
  `loinc_source_priority(language_code, source_file, field_name)` y se
  materializa en la columna (D-33); no se reparte la regla entre importadores.
  **`source_language_code` no se almacena como columna** (D-40): se deriva al
  construir la respuesta con `loinc_source_language(language_code, source_file)`
  para `meta.source_language` y `field_languages[].source_language`; si el
  archivo no corresponde al idioma, devuelve `NULL` con
  `language_evidence='undetermined'` y la fila no se publica. `es-AR` permanece
  como idioma activo y seleccionable en `os_language` (D-39); la capa LOINC se
  acredita con `source_file`/`provenance`. Las capas es-MX/es-AR originales
  **no se recuperan desde la BD** (fueron
  sobrescritas por `ON CONFLICT DO UPDATE` en `:170-182` y `:218-230`): su
  reincorporación requiere reimportar CSV en un cambio de importador aprobado.
  Duplicados exactos con `ON CONFLICT DO NOTHING`; valores distintos bajo la
  misma clave se marcan conflicto a reconciliar y no se publican. Índices,
  incluido GIN, con `CONCURRENTLY` y verificación D-24/D-34.
- **Prioridad determinista por campo, idioma y fuente:**

  | Idioma | `source_file` | `source_priority` | Ámbito |
  |---|---|---|---|
  | `en` | `Loinc.csv` | 10 | todos los campos, incluido `definition_description` |
  | `en` | `ConsumerName.csv` | 20 | **solo** `consumer_name` |
  | `es-MX` | `esMX28LinguisticVariant.csv` | 10 | campos de la capa MX |
  | `es-AR` | `esAR7LinguisticVariant.csv` | 10 | campos de la capa AR |

  Desempate para `(loinc_code, language_code, field_name, source_release)`:
  mayor `source_priority` → menor `source_file` (alfabético) →
  `version_last_changed` más reciente → si persiste, conflicto a reconciliar;
  **nunca** orden de inserción. Los empates 10/10 entre MX y AR se resuelven
  por `source_file`, no por sobrescritura. El `id` no interviene en el desempate.
  En esta fase se activa la auditoría de `loinc_localized_text` y la matriz D-29
  pasa de 7 a **8 tablas**.
- **Validaciones:** 0 códigos huérfanos; conviven `en`, `es-MX` y `es-AR` cuando
  haya datos; `definition_description` solo en `en` desde `Loinc.csv`;
  resolución por prioridad repetible y calculada siempre por la misma función;
  0 conflictos sin marcar; auditoría activa sobre la tabla nueva (D-23, D-29).
- **Criterios de aceptación:** ninguna variante sobrescribe a otra; procedencia
  conservada; conteos de `loinc` inalterados.
- **Riesgos:** capas ya perdidas en la BD actual; empates de prioridad;
  `ConsumerName.csv` aplicado erróneamente a variantes españolas;
  `source_release` asumido sin confirmar.
- **Condición para avanzar:** política de prioridad y `source_release`
  confirmados, y validación de unicidad correcta.

### Fase 6 — Adaptación de DENTAR (D-09)

- **Objetivo:** publicar los campos clínicos omitidos y corregir términos sin
  duplicar el mapeo existente.
- **Archivos afectados:** `os_catalog_item_version`, `os_catalog_term`,
  `os_field_review`, `os_localized_text`; fuentes leídas
  `sql/03_dentar/dentar_core_and_diagnosis.sql`,
  `sql/03_dentar/sync_dentar_to_os.sql`, `tools/php/import_dentar_csv.php`.
- **Dependencias:** Fase 4.
- **Operaciones previstas:** publicar `short_definition`, `lay_terms`,
  `clinical_scope` desde `dentar_concept_version` (`:256-276`);
  `dentar_diagnosis.clinical_name` como `preferred_term` del ítem `dentar-dx`;
  `dentar_category_version.name/description` a `os_localized_text` con idioma
  1:1; términos a `os_catalog_term` conservando `abbreviation→acronym`
  (`sync_dentar_to_os.sql:305-312`, `:427-434`) y la exclusión de `preferred`
  (`:324`, `:445`); `language_code` del término = idioma de la versión padre;
  `UNIQUE (item_version_id, language_code, term, term_type)`; registrar en
  `os_field_review` si las fuentes difieren.
- **Validaciones:** 0 términos `preferred` ni `abbreviation`; 0 idiomas de
  término distintos del padre; `preferred_term` obligatorio **solo para ítems
  con denominación clínica** (procedimientos DENTAR-PR y diagnósticos
  DENTAR-DX), no para ítems administrativos o de catálogo sin esa semántica;
  campos clínicos publicados; sin nuevos literales `'es-AR'` en el sync.
- **Criterios de aceptación:** mapeo `abbreviation→acronym` conservado, no
  duplicado; procedencia de cada campo trazable.
- **Riesgos:** el sync actual fuerza `language='es-AR'` y escribe literal
  `'es-AR'` (`:312`, `:323`); campos monoidioma sin versión editorial; ruptura
  de la UNIQUE existente si se insertan versiones duplicadas.
- **Condición para avanzar:** validaciones de términos y campos clínicos
  aprobadas.

### Fase 7 — Conservación de SNOMED y CIE-10 (D-05)

- **Objetivo:** conservar la semántica RF2 sin inventar dialectos.
- **Archivos afectados:** `snomed_descriptions`, `cie10_descriptions`;
  fuentes leídas `tools/sql/snomed/01_esquema.sql`, `03_postcarga.sql`,
  `sql/01_schema/design.sql`.
- **Dependencias:** Fase 3.
- **Operaciones previstas:** backfill de `rf2_language_tag` desde el valor
  **real** presente en `sct2.description.language_code` (`es`/`en`, ver
  `01_esquema.sql:72-87`); si no hay tag dialectal, conservar `es` con
  `dialect_determined=false`; `language_evidence` acorde. No modificar
  `03_postcarga.sql`: `split_part(language_code,'-',1)` en `:692` es una
  normalización defensiva, no una fuente de `es-AR`. Conservar refsets en
  `sct2.refset_language`/`sct2.language_effective` (`:119-124`, `:199-219`) y
  el refset `450828004` "Español de América Latina" (`:418`). CIE-10: solo
  procedencia documentada, sin `effective_time` inventado. La consulta y la
  búsqueda respetan la distinción: `v_search_term` filtra hoy solo `es`
  (`:466-476`); la API no mezcla descripciones `es` con traducciones regionales
  sin declararlo.
- **Validaciones:** 0 filas con `es-AR` inferido; `effective_time`, `module_id`,
  `type_id`, `case_significance_id` inalterados; conteos inalterados; búsqueda
  por SNOMED no genera resultados con `effective_language='es-AR'` cuando el
  origen es `es`; un cliente `es-AR` recibe `effective_language='es'` con
  `fallback_reason='rf2_dialect_undetermined'` (D-27).
- **Criterios de aceptación:** `es` declarado como dialecto no determinado y
  servido como idioma efectivo sin reescritura; procedencia de refset expuesta;
  sin `DELETE`; búsqueda coherente con D-05.
- **Riesgos:** presión para "normalizar" `es` a `es-AR`; ausencia de
  `sct2.description` en staging; mezcla involuntaria en `v_search_term`.
- **Condición para avanzar:** decisión D-05 aceptada y validaciones aprobadas.

### Fase 8 — Implementación de `LanguageResolver`

- **Objetivo:** centralizar por separado la resolución de idioma y la
  evaluación editorial, y fijar el contrato de salida.
- **Archivos afectados:** propuesta de clase compartida nueva en `api/`;
  `api/http/Request.php`, `api/http/Cors.php`, `api/http/Response.php`
  (nombres a confirmar en aprobación); `.env.example` solo como documentación
  de `API_DEFAULT_LANG`.
- **Dependencias:** Fases 2, 4 y 7.
- **Operaciones previstas:**
  1. **`LanguageResolver` (solo idioma, D-30):** `lang` → alias →
     `Accept-Language` con `q` → `API_DEFAULT_LANG`; descartar `q=0`; si
     **todas** las entradas son `q=0`, aplicar default con
     `fallback_reason='no_acceptable_language'` y `q_zero_only=true`. Validar
     contra `os_language.is_active` y `os_catalog_language`. Rechazo de
     `es-MX` como alias (se mantiene como etiqueta de origen). Produce solo una
     **lista ordenada de idiomas candidatos**; **no consulta** `os_field_review`,
     `review_status` ni contenido.
  2. **Evaluador editorial (solo publicación, D-30):** para cada campo toma la lista seleccionable del resolvedor y la amplía con el idioma de origen declarado y los configurados del catálogo (incluidas etiquetas `is_source_only` como `es`), y recorre la lista ampliada
     en este orden: `requested_language` → idioma de origen declarado →
     `is_fallback` → `is_bridge` (si existe) → `is_default` → `es-AR` global.
     Para cada candidato aplica la precedencia release solicitado > global >
     valores de fila bajo D-07 > `unknown`, descarta todo estado distinto de
     `approved` y elige el primer aprobado. Verifica `content_hash`: si el texto
     cambió, la aprobación quedó invalidada en la misma transacción (D-31). Sin
     aprobado → `null` + `untranslated=true` +
     `fallback_reason='no_approved_content'`. Campos sin registro editorial
     **no** caen a columna original.
  3. **Contrato (D-27, D-38, D-39, D-40):** `requested_language`, `available_languages` con
     `selectable = os_language.is_active` (etiquetas `is_source_only` `es`/`es-MX` → `selectable=false`; LOINC `es-AR` → `selectable=true`;
     solo para contenido aprobado), `effective_language` por campo y
     `null` en `meta` si hay mezcla, `field_languages` siempre presente,
     `source_language` (derivado con `loinc_source_language(...)`, D-40), `provenance`, `approval_state`, `fallback_applied`,
     `fallback_reason`, `untranslated`, `dialect_determined`. Un contenido
     `es` aprobado se devuelve como `effective_language='es'`, nunca reescrito.
     `Content-Language` solo si todos los campos comparten idioma;
     `Vary: Accept-Language` siempre.
- **Validaciones:** todas las pruebas de la §7 pasan en staging; `lang=es`
  sigue resolviendo a `es-AR` como entrada; el resolvedor no consulta tablas de
  contenido; `field_languages` explica cada campo; una fila `is_source_only`
  aprobada aparece como efectiva y como `selectable=false`; una fila LOINC
  `es-AR` aparece como `effective_language='es-AR'` con `selectable=true` y su
  procedencia, sin marcar `es-AR` como source-only (D-39).
- **Criterios de aceptación:** dos componentes con responsabilidades
  separadas; una sola implementación de cada uno; sin duplicar lógica en
  controladores; API pública nunca consulta estados no aprobados.
- **Riesgos:** `Accept-Language` hoy documentado pero no leído; default
  `API_DEFAULT_LANG='es'`; campos `meta` inexistentes hoy; confundir alias `es`
  con etiqueta de origen `es`.
- **Condición para avanzar:** resolver aprobado con matriz de pruebas verde.

### Fase 9 — Adaptación de API

- **Objetivo:** aplicar el resolvedor y el contrato per-field a los endpoints.
- **Archivos afectados:** `api/index.php`, `api/services/CatalogEngineService.php`,
  `api/services/TerminologySearchService.php`, `api/controllers/ConceptController.php`,
  `README-API.md`.
- **Dependencias:** Fase 8.
- **Operaciones previstas:** filtrar `language_code` en `os_catalog_item_version`
  y quitar el `LIMIT 1` de `CatalogEngineService.php:207`; resolver metadatos
  desde `os_localized_text` y sinónimos desde `os_catalog_term`; sustituir los
  15 literales `'es-AR'` de `TerminologySearchService`; búsqueda por código
  independiente del idioma (`01.01`); búsqueda por término con sinónimos del
  idioma efectivo; `ConceptController::show()` respeta `lang` y expone
  `rf2_language_tag` y `dialect_determined`; separar endpoints públicos
  (`approved`-only) de administración (`unreviewed`/`draft`/`in_review` con
  estado y procedencia). La búsqueda SNOMED no mezcla `es` con traducciones
  regionales sin declararlo.
- **Validaciones:** §7 completa; sin `Content-Language` engañoso; respuestas
  multiidioma declaran `field_languages`; `meta.effective_language=null` cuando
  hay mezcla; `available_languages` distingue `selectable`; sin contenido
  publicado sin la aprobación de la etapa 4.3; un cambio de texto invalida la
  aprobación y deja rastro en `os_translation_review`.
- **Criterios de aceptación:** `null` + `untranslated=true` cuando no hay
  aprobado; original `unreviewed` nunca servido públicamente.
- **Riesgos:** regresión en clientes `lang=es`; mezcla involuntaria de sinónimos
  de idiomas distintos; `meta` inconsistente entre recursos.
- **Condición para avanzar:** aprobación de la matriz de pruebas y del contrato.

### Fase 10 — Adaptación del sitio web y exposición CDT/NN

- **Objetivo:** propagar el locale, ofrecer los tres idiomas y precisar el
  destino de CDT/NN.
- **Archivos afectados:** `web/includes/i18n.php`, `web/index.php`,
  `web/docs.php`, assets de `web/**`; documentación de rutas existentes.
- **Dependencias:** Fase 9.
- **Operaciones previstas:** `SUPPORTED=['es-AR','en','pt-BR']`; `canonical()`
  conserva variantes; selector con `hreflang`/`og:locale`; implementar el
  navegador/buscador hoy inexistente consumiendo la API con `lang` y
  `Accept-Language`; mostrar `meta.effective_language` cuando no sea `null`, usar `field_languages` por campo y avisar el fallback;
  migrar los ~99 ternarios `$isEn` de `docs.php`. Según D-37, CDT permanece en
  sus tablas nativas y se consulta por `GET /v1/search/odontologia` (ruta
  genérica `/v1/search/{domain}` en `api/index.php:115-129`, dominio
  `odontologia` en `TerminologySearchService.php:40`, tabla
  `odontologia_prestaciones` en `:256-278`) y por
  `GET /v1/odontologia/{id}` (`api/index.php:439-444`). No se crea `/v1/cdt`.
  `GET /v1/nomenclador` consulta `nomencladores_argentina`
  (`api/index.php:234-239`; `TerminologySearchService.php:1423-1442`), que es el
  único `entity_type='nomenclador'`. NN 2025 permanece en `nomenclador_2025`,
  sin endpoint propio ni mapeo a `os_*`; su exposición futura es decisión
  pendiente. Ninguna ruta asigna `es-AR`/`approved` automáticos.
- **Validaciones:** cambio de locale reflejado en peticiones y textos; sin
  texto español cuando el efectivo es `en`/`pt-BR` salvo fallback declarado;
  CDT `es` no se presenta como `es-AR`.
- **Criterios de aceptación:** `?lang=es|en` sigue funcionando; se suman
  `es-AR` y `pt-BR`; CDT/NN localizables sin inventar dialectos.
- **Riesgos:** página hoy estática sin `fetch`; ejemplos/JSON que quedan en
  español; pérdida de compatibilidad con enlaces antiguos; exposición NN sin
  idioma declarado.
- **Condición para avanzar:** revisión visual y funcional aprobada.

### Fase 11 — Dual-read y dual-write condicionados

- **Objetivo:** transición segura sin borrar columnas originales ni eludir la
  política de publicación.
- **Archivos afectados:** servicios de API e importadores
  (`tools/php/import_dentar_csv.php`, `tools/php/import_nomenclador_csv.php`,
  scripts de sincronización), sin modificar `tools/sources/**`.
- **Dependencias:** Fases 4-10.
- **Operaciones previstas:** la lectura prefiere tablas nuevas. La caída a
  columna original solo se permite si (a) el campo tiene registro vigente
  `approved` en `os_field_review` o en la versión bajo la condición de fuente
  común de D-07 **y** el endpoint aplica la política pública; o (b) el endpoint
  es de administración y declara estado y procedencia. Si no hay registro
  aprobado, **no se cae** a la columna original en la API pública: se devuelve
  `null` + `untranslated=true`. Escritura dual original + nueva; auditoría con
  identidad de proceso importador (`importer_run_id`); monitoreo de
  divergencias. Todo `UPDATE` o `ON CONFLICT DO UPDATE` que cambie texto
  recalcula `content_hash`, fuerza `unreviewed`, limpia revisor/fecha y registra
  `content_changed` + `approval_invalidated` en la misma transacción (D-31),
  con el ámbito `row_shared`/`field_individual` de D-41: un cambio bajo
  aprobación compartida retira toda la fila, un cambio con revisión individual
  retira solo ese campo. Todo cambio de estado en `os_field_review` registra `review_state_changed` o
  `approval_granted` con el actor de aplicación/`importer_run_id` (D-32).
- **Validaciones:** 0 divergencias no explicadas entre original y copia;
  0 respuestas públicas servidas desde columna original sin `approved`
  vigente; 0 aprobaciones conservadas tras cambio de contenido; auditoría cubre
  100 % de escrituras confirmadas; latencia aceptable.
- **Criterios de aceptación:** rollback aún posible desde backups de fases
  anteriores; sin `DELETE`.
- **Riesgos:** confundir compatibilidad de esquema con excepción editorial;
  escrituras nuevas no reconstruibles desde columnas originales; triggers de
  más sobre tablas grandes; importadores masivos sin límite de lote.
- **Condición para avanzar:** periodo de observación y reconciliación limpia.

### Fase 12 — Validación y reconciliación

- **Objetivo:** demostrar que la migración es completa y verificable.
- **Archivos afectados:** reportes de validación; sin cambios de código.
- **Dependencias:** Fase 11.
- **Operaciones previstas:** ejecutar la matriz §7; comparar conteos/checksums
  canónicos con el inventario de Fase 1; verificar por `(tabla, campo, idioma,
  fuente)`; comprobar `indisvalid`, integridad polimórfica, pertenencia de
  releases, prioridad LOINC centralizada, dialecto SNOMED y contrato per-field;
  verificar precedencia global/release de `os_field_review`, locks de D-35,
  excepciones D-34 registradas, nulabilidad D-36, rutas reales CDT/NN y que
  `effective_language` respete etiquetas `is_source_only` aprobadas; revisar la
  matriz de auditoría acumulada de 8 tablas (7 desde Fase 3 + LOINC en Fase 5);
  verificar que la matriz de aprobación de 4.3 es la única fuente de contenido
  público y que los cambios de contenido invalidaron aprobaciones con rastro.
- **Validaciones:** 0 hallazgos críticos; todos los reportes firmados.
- **Criterios de aceptación:** aprobación final independiente de los cuatro
  documentos y de los resultados.
- **Riesgos:** hallazgos tardíos que obliguen a repetir backfill; empates LOINC;
  datos `unknown` que el negocio quiera reclasificar sin evidencia.
- **Condición para avanzar:** aprobación formal para el corte.

### Fase 13 — Corte controlado

- **Objetivo:** pasar de dual a escritura nueva sin destruir historia y
  **verificar** el estado final de nullabilidad (D-36).
- **Archivos afectados:** importadores y servicios; documentación operativa.
- **Dependencias:** Fase 12.
- **Operaciones previstas:** dual-write → write-only a tablas nuevas; retirar
  avisos de compatibilidad; actualizar documentación. **Fase 13 no introduce
  `NOT NULL` nuevos.** Solo comprueba que ya son `NOT NULL DEFAULT`:
  `provenance`, `review_status`, `language_evidence`, `content_hash`,
  `updated_at`, `actor_type`, `occurred_at`, además de claves y `language_code`
  ya `NOT NULL` en el DDL real. Comprueba que siguen nullable
  `source_language_code`, `source_reference`, `reviewed_by`, `reviewed_at`,
  `valid_from`/`valid_to`, `scope_release_id`, `dialect_determined` sin
  evidencia, `previous_value` y `application_user_id`/`importer_run_id` según
  actor. Cualquier `SET NOT NULL` debió aplicarse en Fases 2/3 con valor por
  defecto y evidencia; si falta, se corrige el DDL de esa fase y se repite su
  validación antes del corte, no se improvisa aquí. No se agrega `NOT NULL` a
  columnas originales ni se borran.
- **Validaciones:** conteos base iguales o mayores; auditoría intacta;
  `information_schema.columns.is_nullable` coincide con D-36; pruebas §7
  repetidas tras el corte.
- **Criterios de aceptación:** sistema operativo sin leer columnas originales
  para contenido nuevo; rollback explícitamente aprobado disponible.
- **Riesgos:** pérdida de reversibilidad automática; dependencia de la auditoría
  para reconstruir; cambio de default no aprobado; `NOT NULL` aplicado a
  columnas sin evidencia.
- **Condición para avanzar:** ventana de corte autorizada y backup final sellado.

### Fase 14 — Plan de rollback

- **Objetivo:** definir la reversión verificable antes de necesitarla.
- **Archivos afectados:** documentación operativa y procedimiento aprobado; no
  se ejecuta nada.
- **Dependencias:** Fase 1 (puntos de restauración) y Fase 13 (estado final).
- **Operaciones previstas:** ver §8. Antes del corte: restauración del backup de
  fase verificado en base independiente + columnas originales intactas. Después
  del corte: restauración + reproceso de importadores originales + comparación
  de conteos/checksums. Cada fase conserva su propio punto; nunca se
  sobrescribe el backup anterior.
- **Validaciones:** simulacro en staging; confirmación de que
  `os_catalog_item_version`, `os_catalog_term` y tablas nativas recuperan sus
  valores exactos.
- **Criterios de aceptación:** procedimiento firmado, con responsables y tiempos.
- **Riesgos:** traducciones y auditoría nuevas no reconstruibles; falso
  optimismo sobre reversibilidad automática.
- **Condición para avanzar:** cierre del plan; **no hay fase posterior**.

---

## 4. Matriz de campos traducibles cubiertos

| Campo | Destino | Fase |
|---|---|---|
| `preferred_term`, `definition`, `clinical_criteria` | `os_catalog_item_version` (+ `os_field_review` si difiere) | 3 / 4 / 6 |
| `short_definition`, `lay_terms`, `clinical_scope` | columnas nuevas en `os_catalog_item_version` | 3 / 6 |
| `clinical_name` (`dentar_diagnosis`) | `os_catalog_item_version.preferred_term` (ítem `dentar-dx`) | 6 |
| `term` (`dentar_term`, `dentar_diagnosis_term`) | `os_catalog_term` | 6 |
| Sinónimos/acrónimos/variantes | `os_catalog_term` | 6 |
| Catálogo, categoría, release, arancel, unidad, sistema, mapping, farmacia | `os_localized_text` (12 `entity_type`) | 2 / 4 |
| SNOMED `term`, tag real, `effective_time` | `snomed_descriptions` (nativo) | 3 / 7 |
| CIE-10 `descripcion` | `cie10_descriptions` (nativo) | 3 / 7 |
| LOINC campos por capa | `loinc_localized_text` con `source_file`/prioridad | 5 |
| CDT `nombre_en/nombre_es` | Tablas nativas `odontologia_cdt_*`/`odontologia_prestaciones`, `en`/`es`, sin `es-AR` inferido; rutas `/v1/search/odontologia` y `/v1/odontologia/{id}` | 4 / 10 |
| NN 2025 `descripcion`, `categoria` | Se conserva en `nomenclador_2025`; sin endpoint propio ni mapeo a `os_*` | 4 / 10 |

---

## 5. Backfill controlado (reglas de las Fases 4 y 4.3)

**Prohibiciones absolutas:**

- Asignar `provenance='official_source'` sin evidencia documentada por fuente.
- Asignar `review_status='approved'` sin revisión demostrable y firma (4.3).
- Asignar `source_language_code` por inferencia del idioma de destino.
- Usar `es-AR` como valor por defecto para todo el backfill.
- Convertir `es` en `es-AR` a partir de `nombre_es` o de tags RF2.

**Valores ante ausencia de evidencia:** `provenance='unknown'`,
`review_status='unknown'`, `source_language_code=NULL`,
`language_evidence='undetermined'`. Estos valores **no son publicables** en la
API pública.

**Evidencia aceptable:** literal declarado en el script fuente; sufijo de
columna (`nombre_en`→`en`, `nombre_es`→`es`, **no** `es-AR`); valor de
`language_code` en la tabla original cuando exista; tag real de
`sct2.description`; `source_file` del CSV de LOINC.

**Reconciliación:** por cada fase se genera un reporte con clave
`(tabla, campo, idioma, fuente)`, número de filas afectadas, valores `unknown`
y checksums antes/después. Es un artefacto de revisión, **no** una tabla nueva.

---

## 6. Trabajo PMO: independiente y bloqueante para su carga

No forma parte de las 14 fases. Debe resolverse antes de ejecutar cualquier
carga de `sql/04_pmo/`:

| Hallazgo | Evidencia | Acción pendiente |
|---|---|---|
| `os_catalog_item.observation` no existe | DDL en `origen_catalog_engine.sql`; scripts de Fase 4 PMO | Definir destino estructurado para `FORMULARIO:`, `PRECIO:`, `ODONTOLOGICO`, `NORMATIVA:` |
| `tmp.codigo` usado como categoría | `sql/04_pmo/02_pmo_practicas.sql` | Usar `tmp.capitulo` como `code`/`name`; eliminar `'Sin descripción'` |
| Release histórica inexistente | `PMOE-201-2002` solo en comentario (`:192`); release real `2026-v1` | No crear la release ficticia |
| Texto PMO en español sin columna de idioma | fuente `pmo_practicas` | Declarar idioma real al migrar; sin `approved` automático |

---

## 7. Pruebas de aceptación obligatorias

Ejecutar en staging tras la Fase 9; repetir tras el corte. **Antes de usar
cualquier código como caso de aceptación hay que verificarlo en staging (D-26):**
que el catálogo y el ítem existan, que tengan versión vigente, que el texto
`es-AR` esté aprobado y que `en`/`pt-BR` tengan el comportamiento esperado. Si
no cumple, se elige otro código real y se documenta. Igual criterio para
`<loinc_con_capas>` y `<sctid_real>`.

| # | Caso | Resultado esperado |
|---|---|---|
| 1 | `?lang=es-AR` en `GET /v1/catalogs/dentar-pr/items/DNT-PR-000001` | Si la etapa 4.3 aprobó el contenido: texto `approved` en `es-AR`; `requested_language='es-AR'`; `effective_language='es-AR'`. Si no hay aprobación: `null` + `untranslated=true` (ver 26). |
| 2 | `?lang=en` en el mismo recurso | Texto `approved` en `en` o fallback declarado con `fallback_reason`; sin aprobación → `null` + `untranslated=true`. |
| 3 | `?lang=pt-BR` en el mismo recurso | Igual que (2); `available_languages` coherente. |
| 4 | Alias `?lang=es` | Se resuelve a `es-AR`; compatibilidad con clientes actuales (`README.md`, `.env.example:33`). No se confunde con la etiqueta de origen `es`. |
| 5 | Alias `?lang=pt` | Se resuelve a `pt-BR`. |
| 6 | `?lang=es-MX` | **Rechazado como alias**; no se convierte en `es-AR`. Si es etiqueta de origen LOINC, se trata como variante. |
| 7 | `Accept-Language: es-AR;q=0.5,en;q=0.9,pt-BR;q=0.9` | Gana `en` por `q` y, en empate, por orden de aparición. |
| 8 | `Accept-Language: es-AR;q=0,en;q=0.7` | `es-AR` se descarta (`q=0`); gana `en`. |
| 9 | Idioma inexistente (`?lang=xx-YY`) | No resuelve: se aplica `API_DEFAULT_LANG`; se declara el motivo. |
| 10 | Catálogo sin traducción | Campos de texto `null` + `untranslated=true` + `no_approved_content`. |
| 11 | Traducción existente no aprobada (`draft`/`in_review`/`machine`) | No se sirve en API pública. Admin sí la muestra con estado y procedencia. |
| 12 | Texto original `approved` | Se sirve con `approval_state='approved'`, sin fallback engañoso. |
| 13 | Texto original no aprobado | API pública devuelve `null` + `untranslated=true`; no se sirve el original `unreviewed` ni por dual-read (D-20). |
| 14 | Fallback a idioma puente (`is_bridge='en'`) | `effective_language='en'`, `fallback_reason='bridge_language'`. |
| 15 | Fallback a idioma predeterminado (`is_default`) | `effective_language=<default>`, motivo declarado. |
| 16 | SNOMED con tag original `es` y cliente `es-AR` | Se sirve `language_code='es'` con `effective_language='es'`, `dialect_determined=false`, `rf2_language_tag` expuesto. **No** se declara `es-AR`. |
| 17 | LOINC `es-MX` vs `es-AR` en `<loinc_con_capas>` | Conviven como filas distintas por `source_file`; gana la prioridad determinista; sin sobrescritura. |
| 18 | Términos/sinónimos con idiomas distintos | Cada sinónimo se filtra por el idioma de su versión padre; no se mezclan sin declararlo. |
| 19 | Releases históricos | La versión devuelta corresponde al `release_id` solicitado/vigente; la historia anterior sigue accesible; `scope_release_id` impide borrado silencioso. |
| 20 | Cambio editorial y auditoría | `previous_value`/`new_value`, actor de aplicación o `importer_run_id`, tabla/registro/campo/idioma/acción/fecha/procedencia/estado presentes; transaccional; cobertura de las 8 tablas. |
| 21 | Búsqueda por código con `lang` distinto | Mismo resultado para `01.01` en `es-AR`, `en`, `pt-BR`; sin fallback idiomático. |
| 22 | Búsqueda por término y sinónimos | Encuentra términos `approved` del idioma efectivo y sus sinónimos del mismo idioma. |
| 23 | Respuesta con idiomas efectivos distintos por campo | `meta.field_languages` describe cada campo; `Content-Language` omitido; nunca se afirma un único idioma para toda la respuesta. |
| 24 | Compatibilidad `lang=es` en endpoints actuales | Misma semántica que antes de la migración, ahora con alias declarado. |
| 25 | `Accept-Language` con **solo** `q=0` (`es-AR;q=0,en;q=0`) | No se elige `es-AR` ni `en` silenciosamente: `API_DEFAULT_LANG`, `fallback_reason='no_acceptable_language'`, `q_zero_only=true`. |
| 26 | Contenido sin aprobación inicial (4.3) | Pruebas 1-3 con resultado `null` + `untranslated=true`; la aprobación documentada es prerrequisito para esperar texto. |
| 27 | CDT `nombre_es` | Se expone con `language_code='es'`, `source_language_code='es'`, `dialect_determined=false`; **nunca** `es-AR` sin evidencia regional. |
| 28 | Búsqueda SNOMED `es` | Los resultados declaran `effective_language='es'`; no se mezclan con traducciones regionales sin declaración. |
| 29 | Índice inválido preexistente | El procedimiento D-24 detecta `indisvalid=false`, lo repara con la excepción autorizada D-34 y verifica `indisvalid=true`; no se omite la creación por `IF NOT EXISTS`. |
| 30 | Contenido aprobado con etiqueta `is_source_only` (`es` SNOMED/CDT) | Cliente `es-AR` recibe `effective_language='es'`; `available_languages` lo marca `selectable=false`; nunca se reescribe a `es-AR` (D-27/D-38). |
| 31 | Unicidad de `os_field_review` | Un registro global y uno del release solicitado coexisten; dos globales o dos del mismo release fallan por `uq_fr_global`/`uq_fr_scoped`; precedencia release > global (D-28). |
| 32 | Auditoría por fase | Al cierre de Fase 2 solo `os_field_review`; Fase 3 exactamente 7 tablas; Fase 5 se incorpora `loinc_localized_text` y completa 8 (D-29). |
| 33 | Separación resolver/evaluador | El resolvedor devuelve candidatos sin consultar `os_field_review`; el evaluador descarta `draft`/`in_review` y elige el primer `approved` (D-30). |
| 34 | Cambio de contenido sobre texto aprobado | `UPDATE`/`ON CONFLICT DO UPDATE` cambia `content_hash`, deja `review_status='unreviewed'`, limpia revisor/fecha y registra `content_changed` + `approval_invalidated` en la misma transacción; la API deja de servirlo hasta re-aprobación (D-31). |
| 35 | Trazabilidad de estado y contenido | `os_translation_review` contiene actor de aplicación o `importer_run_id`, tabla, campo, idioma, valores, acción y `transaction_id`; no usa `SESSION_USER` como autor (D-32). |
| 36 | Prioridad LOINC y duplicados | Dos capas con la misma clave pero `value` distinto se marcan conflicto y no se publican; la prioridad sale de la función central y el `id` no desempata (D-33). |
| 37 | `DROP INDEX` sin autorización | El procedimiento se niega a retirar un índice válido; solo actúa sobre inválido/duplicado con autorización escrita, registro y recreación `CONCURRENTLY` (D-34). |
| 38 | Concurrencia polimórfica | Dos INSERT simultáneos sobre la misma entidad se serializan por lock y por índice único; un DELETE concurrente de la entidad queda bloqueado por el lock y aplica RESTRICT (D-35). |
| 39 | Nullabilidad final | Fase 13 solo verifica: columnas de D-36 conservan su estado; no se ejecuta ningún `SET NOT NULL` nuevo y las columnas con semántica conocida ya eran `NOT NULL DEFAULT`. |
| 40 | Rutas y entidades CDT/NN | `entity_type='nomenclador'` solo resuelve `nomencladores_argentina`; CDT responde por `/v1/search/odontologia` y `/v1/odontologia/{id}`; `/v1/cdt` no existe; NN 2025 no tiene endpoint ni mapeo (D-37). |
| 41 | Contrato API con mezcla de campos | `available_languages` informa `selectable`; `meta.effective_language=null` si hay mezcla; `field_languages` describe cada campo; `Content-Language` se omite y `Vary: Accept-Language` se emite (D-38). |
| 42 | LOINC `es-AR` frente a `is_source_only` | `os_language.es-AR` sigue `is_active=true, is_source_only=false`; la fila LOINC conserva `source_file='esAR7LinguisticVariant.csv'`/`provenance`; la respuesta declara `effective_language='es-AR'` y `available_languages[es-AR].selectable=true`. Ningún tag se marca source-only por procedencia (D-39). |
| 43 | `source_language_code` de LOINC | No existe columna nueva: `meta.source_language` y `field_languages[].source_language` salen de `loinc_source_language(language_code, source_file)`; con `language_code='es-AR'` y ese `source_file` devuelve `es-AR`; con archivo no coincidente devuelve `null`, `language_evidence='undetermined'` y la fila no se publica (D-40). |
| 44 | Ámbito de invalidación `content_hash` | Si cambia `definition` bajo aprobación compartida, se invalida toda la fila (`row_shared`) y los seis campos dejan de servirse hasta re-aprobación; si cambia un campo con fila en `os_field_review`, solo se invalida esa revisión (`field_individual`) y los demás siguen `approved`; crear/deprecar una fila individual recalcula el agregado e invalida una vez la aprobación compartida. El evento registra ámbito y campos (D-41). |

---

## 8. Rollback verificable (sin reversibilidad automática)

- **Antes del corte (Fases 1-12):** restauración desde el backup verificado de
  la fase en **base independiente**; columnas originales intactas. Retirar
  objetos nuevos solo con procedimiento aprobado, nunca por defecto.
- **Después del corte (Fases 13-14):** existen escrituras nuevas
  (`os_localized_text`, `loinc_localized_text`, `os_translation_review`,
  `os_field_review`, columnas de procedencia) no reconstruibles solo desde las
  originales. **No se promete reversibilidad automática.** Procedimiento:
  1. restaurar el backup verificado de la fase correspondiente en base separada;
  2. reprocesar únicamente importadores originales;
  3. repetir conteos y checksums canónicos y comparar con el inventario de Fase 1;
  4. confirmar valores exactos de `os_catalog_item_version`, `os_catalog_term` y
     tablas nativas de estándares.
- Cada fase guarda su punto de restauración; nunca se sobrescribe el anterior.
- La auditoría se restaura junto con la base: no se reconstruye a posteriori.

---

## 9. Compatibilidad

- **Esquema:** aditivo; ninguna columna/tabla existente se elimina.
- **Datos:** conteos base no disminuyen; las traducciones nuevas suman filas.
- **API:** rutas estables; `meta` y cabeceras se amplían; default `es` se mantiene
  hasta aprobación de cambio a `es-AR`.
- **Web:** `?lang=es|en` sigue funcionando; se suman `es-AR` y `pt-BR`.
- **Importadores:** escriben columnas originales durante la transición; la
  identidad de códigos y la historia de publicaciones se preservan.
- **PostgreSQL 18:** compatible con la sintaxis propuesta; índices parciales y
  `CONCURRENTLY` según §2.1 y D-24.

---

## 10. Estado actual

**Plan diseñado. CERO migraciones ejecutadas.** Los únicos archivos creados en
esta tarea son los cuatro entregables de documentación:

- `docs/architecture/auditoria-internacionalizacion.md`
- `docs/architecture/modelo-multilingue-propuesto.md`
- `docs/architecture/plan-migracion-multilingue.md`
- `docs/architecture/decisiones-arquitectura-multilingue.md`

No se modificó PostgreSQL, API, sitio web, importadores ni fuentes originales.
No se realizó commit ni push. La aprobación de la dirección arquitectónica no
implica aprobación de DDL, cambios de código ni ejecución en producción.
