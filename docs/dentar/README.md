# DENTAR · familia de catálogos odontológicos

DENTAR es la marca paraguas de los catálogos odontológicos argentinos de Origen
Salud. Cada producto es un catálogo **independiente**, con su propia identidad,
prefijo de código, reglas de mapeo y ciclo de versiones:

| Producto | Contenido | Código | Mapeos |
| --- | --- | --- | --- |
| **DENTAR-PR** | Procedimientos y prestaciones | `DNT-PR-NNNNNN` | Nomenclador Argentino (obligatorio), ADA CDT 2025, SNOMED CT |
| **DENTAR-DX** | Diagnósticos y condiciones bucomaxilofaciales | `DNT-DX-NNNNNN` | CIE-10 K00-K14 (obligatorio), SNOMED CT |
| **DENTAR-AN** | Anatomía dental | `DNT-AN-NNNNNN` | SNOMED AR RF2 (es-AR), versión `en` por trigger |
| **DENTAR-CL** | Hallazgos clínicos | `DNT-CL-NNNNNN` | SNOMED AR RF2 (es-AR), versión `en` por trigger |

La actividad de los cuatro productos en `origen_codes` quedó **verificada el
2026-11-19** con consultas de solo lectura (PostgreSQL 18.6) **[BD]**. Los
artefactos SQL versionados para AN/CL y CDT siguen rotulados "NO EJECUTADO"
**[REPO]**, pero ese rótulo describe al archivo, no a la base: los datos sí están
cargados. Ver el §1.6 de la
[propuesta arquitectónica](../architecture/propuesta-arquitectura-catalogos-sanitarios.md).
`DENTAR-IN`, `DENTAR-PD` y `DENTAR-EQ` quedan **reservados**: no tienen códigos
ni datos cargados. AN/CL no se cargan con `import_dentar_csv.php` (que solo
acepta PR/DX), sino con el artefacto SQL propio documentado más abajo.

El **Nomenclador Odontológico Nacional** (`nomenclador-odontologico-ar`) quedó
desplegado el 2026-11-19 **[BD]** con 135 ítems, 135 versiones `es-AR`, 270
relaciones `referencia_literal` hacia/desde DENTAR-PR y las 333 relaciones CDT
preexistentes intactas. Se consulta en
`/browse?catalog=nomenclador-odontologico-ar`. Su código nacional es
**secundario**: el visible sigue siendo `DNT-PR-NNNNNN`. Procedimiento,
backup y verificación en el [§5.2 de la propuesta arquitectónica](../architecture/propuesta-arquitectura-catalogos-sanitarios.md#52-nomenclador-odontologico-nacional).

La marca `DENTAR` no tiene códigos ni releases propias. En la API figura como
catálogo de rol `family`, con `family_code = null`; los productos declaran
`family_code = 'dentar'` y rol `catalog`.

## Estado actual

> Los conteos están verificados en base **[BD]** el 2026-11-19. El SQL versionado
> contiene 138 PR y 38 DX **[REPO]**: es un seed parcial, no el estado real.
> Detalle en el §1.6 de la
> [propuesta arquitectónica](../architecture/propuesta-arquitectura-catalogos-sanitarios.md).

| Pieza | Estado |
| --- | --- |
| Registro de la familia | `sql/03_dentar/dentar_family.sql` → `dentar_catalog` |
| Esquema editorial (`dentar_*`) | `sql/03_dentar/dentar_core_and_diagnosis.sql` |
| Base correcta [BD] | `origen_codes` (`origen_salud` es la vieja y solo conserva restos aislados) |
| Procedimientos [BD] | **844** (DENTAR-PR) |
| Diagnósticos [BD] | **223** (DENTAR-DX) |
| Anatomía [BD] | **624** (DENTAR-AN), sin exposición pública por decisión editorial |
| Hallazgos clínicos [BD] | **218** (DENTAR-CL), sin exposición pública por decisión editorial |
| Relaciones CDT [BD] | **333 filas / 303 pares / 15 tipos** en `os_catalog_relation` (tabla presente en base, ausente del motor canónico versionado; aún no navegable) |
| Importador masivo | `tools/php/import_dentar_csv.php` (solo PR/DX) |
| Sincronización con la API de catálogos | `sql/03_dentar/sync_dentar_to_os.sql` (ejecutar con `psql -1`) |
| API | `GET /v1/catalogs`, `GET /v1/catalogs/dentar-pr/items`, `GET /v1/catalogs/dentar-dx/items`, `GET /v1/odontologia/diagnosticos` |

El seed del SQL no escala a 800 códigos: editar cientos de bloques de `INSERT` a
mano es inviable y propenso a error. Por eso el catálogo se carga desde CSV con
el importador, que es idempotente y valida códigos, categorías y mapeos.

## Orden de carga

> Secuencia documentada **[DOC]**; el resultado final está verificado **[BD]**,
> pero esta auditoría **no ejecutó ninguno** de estos comandos. Los artefactos
> generados siguen rotulados "NO EJECUTADO" **[REPO]**. No volver a ejecutar nada
> de lo siguiente sin aprobación explícita y backup verificado: los importadores
> y el sync son idempotentes en parte, pero `sync_dentar_to_os.sql` borra y
> reinserta mapeos.

```bash
# Esquema base (solo en una instalación nueva)
psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/02_catalogs/origen_catalog_engine.sql
psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/04_pmo/pmo.sql
psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/03_dentar/dentar_family.sql
psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/03_dentar/dentar_core_and_diagnosis.sql

# PR/DX (importador masivo) → sincronización
psql -d origen_codes -v ON_ERROR_STOP=1 -1 -f sql/03_dentar/sync_dentar_to_os.sql

# AN/CL y relaciones CDT: artefactos generados (resultado ya cargado en base [BD])
psql -d origen_codes -v ON_ERROR_STOP=1 -f docs/dentar/generado/dentar-an-cl-propuerto.sql
psql -d origen_codes -v ON_ERROR_STOP=1 -1 -f sql/03_dentar/sync_dentar_to_os.sql
psql -d origen_codes -v ON_ERROR_STOP=1 -f docs/dentar/generado/dentar-cdt-relaciones-propuerto.sql
```

Orden propuesto: **AN/CL → `sync_dentar_to_os.sql` → relaciones CDT**.
No ejecutar `Argentina_dental_cdt_codes_2025_postgres.corregido.sql` como carga
final: el artefacto propuesto ya crea los sistemas, identificadores y relaciones
con claves únicas corregidas. `sync_dentar_to_os.sql` elimina y reinserta
mapeos; por eso debe correrse dentro de una única transacción (`-1`).

`dentar_family.sql` crea el registro `dentar_catalog` y la función
`dentar_catalog_id()`. El núcleo editorial exige ese registro y falla con un
mensaje explícito si no se ejecutó antes. En bases creadas con la versión
anterior del catálogo, `dentar_family.sql` migra los códigos:

| Antes | Después |
| --- | --- |
| `DNT-000001` … `DNT-000138` | `DNT-PR-000001` … `DNT-PR-000138` |
| `DNT-DX-0001` … `DNT-DX-0038` | `DNT-DX-000001` … `DNT-DX-000038` |

La migración es idempotente y aborta si detecta códigos viejos y nuevos
conviviendo en la misma tabla.

## Formato del CSV

Encabezado obligatorio, orden libre, separador `,`, `;` o tabulación. El
importador reconoce las filas de ambos catálogos en un mismo archivo.

| Columna | Obligatoria | Catálogo | Contenido |
| --- | --- | --- | --- |
| `codigo` | Sí | ambos | `DNT-PR-NNNNNN` o `DNT-DX-NNNNNN`. No se reutiliza ni se renombra. |
| `catalogo` | No | ambos | `PR`, `DX`, `dentar-pr` o `dentar-dx`. Si falta se infiere del prefijo y se valida contra él. |
| `termino` | Sí | ambos | Término preferido en `es-AR`. |
| `definicion` | No | ambos | Definición. Default: el término. |
| `short_definition` | No | ambos | Descripción abreviada (máx. 255 chars) para listados y resumidos. |
| `global_period` | No | ambos | Período global de días (0 = ninguno, 10, 30, 90, NULL = no definido). |
| `work_rvu` | No | ambos | Columna heredada del CSV; el importador la escribe en `work_uvr`. **No hay valores UVR cargados todavía.** |
| `practice_expense_rvu` | No | ambos | Columna heredada; destino `practice_expense_uvr`. |
| `malpractice_rvu` | No | ambos | Columna heredada; destino `professional_liability_uvr`. |
| `total_rvu` | No | ambos | Columna heredada; destino `total_uvr`, siempre calculado como suma de las tres anteriores. |
| `estimated_payment` | No | ambos | Pago estimado de referencia (ARS, solo orientativo). |
| `criterios_clinicos` | No | ambos | Criterios de uso o justificación clínica. |
| `lay_terms` | No | ambos | Descripción comprensible para pacientes (resumida). |
| `chapter_section` | No | DENTAR-PR | Capítulo del nomenclador (ej. "Capítulo I - Consultas"). |
| `specialty` | No | DENTAR-PR | Especialidad odontológica (ej. "Operatoria Dental"). |
| `modifiers_allowed` | No | DENTAR-PR | Indica si el código admite modificadores. |
| `units` | No | DENTAR-PR | Unidad de prestación (ej. "por pieza dentaria"). |
| `clinical_indications` | No | ambos | Indicaciones clínicas detalladas. |
| `exclusions` | No | ambos | Condiciones o situaciones en las que no aplicar. |
| `documentation_requirements` | No | ambos | Requisitos de documentación para facturación. |
| `editorial_notes` | No | ambos | Notas internas del comité editorial. |
| `ambito_clinico` | No | DENTAR-PR | Capítulo, ej. `Capítulo III - Endodoncia`. |
| `categoria` | No | ambos | Código de `dentar_category` del mismo catálogo. |
| `tipo_concepto` | No | DENTAR-PR | `procedure` (default), `service`, `evaluation`, `diagnostic_service`, `rehabilitation`. |
| `sinonimos` | No | ambos | Alternativas separadas por `|`. |
| `nomenclador_ar` | No | DENTAR-PR | Código del nomenclador odontológico argentino (ej. `03.01`). **Obligatorio para publicar.** |
| `cdt_2025` | No | DENTAR-PR | Código ADA CDT 2025 (ej. `D3310`). |
| `cie10` | No | DENTAR-DX | Código CIE-10 K00-K14 (ej. `K02.1`). **Obligatorio para publicar.** |
| `snomed_sctid` | No | ambos | SCTID del concepto en SNOMED CT Argentina. |

> **UVR:** el modelo distingue valoración relativa y conversión monetaria. La
> relación vigente es `total_uvr = work_uvr + practice_expense_uvr +
> professional_liability_uvr`. El módulo está diseñado pero **sin datos
> cargados**; no se publican valores, factores de conversión ni pagos estimados
> como datos reales. No se asigna UVR a diagnósticos, productos ni insumos por
> defecto.

Plantillas de ejemplo con códigos reservados para pruebas:

- [`plantilla-dentar-pr.csv`](plantilla-dentar-pr.csv) — procedimientos `DNT-PR-9000xx`.
- [`plantilla-dentar-dx.csv`](plantilla-dentar-dx.csv) — diagnósticos `DNT-DX-9000xx`.

Esos códigos no deben quedar en producción: usarlos sólo en un `--dry-run` o
retirarlos después.

## Uso

```bash
# 1. Validar sin escribir nada
php tools/php/import_dentar_csv.php docs/dentar/plantilla-dentar-pr.csv --dry-run
php tools/php/import_dentar_csv.php docs/dentar/plantilla-dentar-dx.csv --dry-run

# 2. Carga real (un archivo por lote o la familia completa)
php tools/php/import_dentar_csv.php docs/dentar/catalogo-pr.csv
php tools/php/import_dentar_csv.php docs/dentar/catalogo-dx.csv

# 3. Nueva versión editorial de los conceptos existentes de un producto
php tools/php/import_dentar_csv.php docs/dentar/catalogo-pr-v2.csv --version=2
php tools/php/import_dentar_csv.php docs/dentar/catalogo-dx-v2.csv --version=2
```

El importador crea/actualiza, según el catálogo de cada fila:

- **DENTAR-PR**: `dentar_concept`, `dentar_concept_version`, término preferido y
  sinónimos en `dentar_term`, vínculo a `dentar_category` y mapeos en
  `dentar_concept_mapping` (`NOMENCLADOR-AR`, `CDT-2025`, `SNOMED-CT`).
- **DENTAR-DX**: `dentar_diagnosis`, `dentar_diagnosis_version`,
  `dentar_diagnosis_term`, categoría `CAT-DX` y mapeos en
  `dentar_diagnosis_mapping` (`CIE-10`, `SNOMED-CT`).

Todo corre en una transacción: si alguna fila falla, se revierte completo.

Al final de esa misma transacción ejecuta `sql/03_dentar/sync_dentar_to_os.sql`,
que proyecta cada producto a `os_catalog_item`, `os_catalog_item_version`,
`os_catalog_term`, `os_catalog_identifier` y `os_concept_mapping` — el modelo
que consumen `GET /v1/catalogs/dentar-pr/items` y
`GET /v1/catalogs/dentar-dx/items`.

### Carga de AN/CL y relaciones CDT

`import_dentar_csv.php` solo acepta `PR`/`DX`. AN y CL se cargan con
`docs/dentar/generado/dentar-an-cl-propuerto.sql`, que respeta la fuente SNOMED
AR RF2 y sus conversiones. Detalles y exclusiones están en
[`RESUMEN_AN_CL.md`](generado/RESUMEN_AN_CL.md).

- Los términos de AN/CL se publican en `es-AR` con el texto de la fuente. El
  inglés se publica como versión `language_code='en'` mediante el trigger §4.2,
  **no** como sinónimo dentro de `es-AR`.
- Las relaciones CDT se cargaron con
  `docs/dentar/generado/dentar-cdt-relaciones-propuerto.sql` **[BD]**: 333 filas,
  303 pares únicos y 15 tipos en `os_catalog_relation`, con `context_text` en la
  clave única. El rótulo "NO EJECUTADO" del artefacto [REPO] no refleja la base.
- **Pendiente de integración [REPO]:** `CatalogRepository::itemRelations()` no
  consulta `os_catalog_relation`, por lo que la pestaña Relaciones de Browse no
  muestra hoy ese contenido. La afirmación contraria era documentación previa no
  verificada. Ver la decisión pendiente 10 del §15.2 de la propuesta
  arquitectónica.

Cada producto calcula su propia release:

| Versión editorial | Release DENTAR-PR | Release DENTAR-DX |
| --- | --- | --- |
| 1 | `2026-v1` | `2026-v1` |
| 2 | `DENTAR-PR-v2` | `DENTAR-DX-v2` |
| N | `DENTAR-PR-vN` | `DENTAR-DX-vN` |

Las releases anteriores del mismo producto quedan en `deprecated`. La marca
`dentar` nunca recibe releases. `--sin-sync` omite la publicación.

Los `snomed_sctid` se validan contra `snomed_concepts`: si el SCTID no existe se
emite un **aviso** (no se aborta), para poder cargar el catálogo antes de
terminar la carga SNOMED.

## Reglas editoriales

1. **Código permanente y por producto**: un `DNT-PR-` o `DNT-DX-` no se renumera,
   no se reutiliza y no cambia de catálogo. Un trigger
   (`dentar_assert_catalog_code`) rechaza cualquier código con el prefijo de otro
   producto. Un concepto retirado pasa a `retired`.
2. **Capítulos y especialidades son atributos**: no forman parte del código.
   Cambiar de categoría no cambia la identidad del concepto.
3. **Un procedimiento = un código facturable**, con unidades y cobertura
   definidas en el arancel correspondiente (`os_fee_schedule`), no en el concepto.
4. **Mapeos obligatorios**: Nomenclador Argentino para DENTAR-PR y CIE-10 para
   DENTAR-DX. CDT 2025 y SNOMED CT se agregan cuando existe equivalente. Los no
   mapeables se documentan como `not_mappable`; no se fuerza un código que no
   corresponde.
5. **Diagnósticos y procedimientos no comparten tabla ni identidad**: el CIE-10
   vive en `dentar_diagnosis_mapping`, nunca en los procedimientos.
6. **Comité editorial**: todo cambio de definición o mapeo genera una nueva
   `version_number` con `approval_status` (`draft` → `review` → `approved`).

## Estado de la hoja de ruta y pasos pendientes

El objetivo inicial de 800 procedimientos se resolvió con fuentes auditadas
(CDT 2025 y nomenclador argentino), no inventando códigos. El contenido clínico
sigue siendo responsabilidad del comité editorial.

| Fase | Estado | Salida verificable |
| --- | --- | --- |
| 0. Auditoría del seed | Cerrada [BD] | 844 PR y 223 DX verificados en `origen_codes`. |
| 1. Candidatos | Cerrada para la carga actual [DOC] | Origen: `docs/dentar/generado/dentar-pr-cdt-2025.csv` y mapeos DX. |
| 2. Priorización | Ejecutada [BD] | Secuencia AN/CL → sync → relaciones CDT, reflejada en la base. |
| 3. Revisión clínica | Parcial [BD] | AN/CL y CDT cargados; 419 aprobaciones D-19 sobre mapeos. Falta el acta formal de D-01…D-41. |
| 4. Carga y publicación | Cargada [BD]; publicación pendiente | 805 identificadores `CDT-2025`; 333 relaciones presentes pero **no navegables** en Browse. |
| 5. Gestión UVR | Pendiente | Definir responsable de aprobación y factores de conversión antes de cargar cualquier valor. |
| 6. FHIR | Pendiente | Contrato documentado en `README-FHIR.md`, sin enrutamiento ni guardia de auth. |

Las decisiones D-01…D-41 del documento de arquitectura están **pendientes de
aprobación formal**: su publicación no debe interpretarse como aprobación
organizativa.

## Verificación

```sql
-- Productos de la familia y códigos cargados
SELECT * FROM v_dentar_catalogo_familia ORDER BY code;

-- Cobertura de mapeos de DENTAR-PR
SELECT count(DISTINCT c.id) AS conceptos,
       count(DISTINCT c.id) FILTER (WHERE m.system_code = 'SNOMED-CT') AS con_snomed,
       count(DISTINCT c.id) FILTER (WHERE m.system_code = 'CDT-2025') AS con_cdt,
       count(DISTINCT c.id) FILTER (WHERE m.system_code = 'NOMENCLADOR-AR') AS con_nomenclador
  FROM dentar_concept c
  JOIN dentar_concept_version cv ON cv.concept_id = c.id
  LEFT JOIN dentar_concept_mapping m ON m.concept_version_id = cv.id;

-- Cobertura de mapeos de DENTAR-DX
SELECT count(DISTINCT d.id) AS diagnosticos,
       count(DISTINCT d.id) FILTER (WHERE m.system_code = 'CIE-10') AS con_cie10,
       count(DISTINCT d.id) FILTER (WHERE m.system_code = 'SNOMED-CT') AS con_snomed
  FROM dentar_diagnosis d
  LEFT JOIN dentar_diagnosis_mapping m ON m.diagnosis_id = d.id;

-- Vista unificada de la familia
SELECT catalog, concept_kind, count(*) AS codigos
  FROM v_dentar_family_concept
 GROUP BY catalog, concept_kind
 ORDER BY catalog;
```

Para la API, verificar que cada producto tenga una sola release publicada:

```sql
SELECT c.code, r.version_tag, r.status
  FROM os_catalog c
  JOIN os_catalog_release r ON r.catalog_id = c.id
 WHERE c.family_code = 'dentar'
 ORDER BY c.code, r.valid_from DESC;
```
