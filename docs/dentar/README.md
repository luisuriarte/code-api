# DENTAR · familia de catálogos odontológicos

DENTAR es la marca paraguas de los catálogos odontológicos argentinos de Origen
Salud. Cada producto es un catálogo **independiente**, con su propia identidad,
prefijo de código, reglas de mapeo y ciclo de versiones:

| Producto | Contenido | Código | Mapeos |
| --- | --- | --- | --- |
| **DENTAR-PR** | Procedimientos y prestaciones | `DNT-PR-NNNNNN` | Nomenclador Argentino (obligatorio), ADA CDT 2025, SNOMED CT |
| **DENTAR-DX** | Diagnósticos y condiciones bucomaxilofaciales | `DNT-DX-NNNNNN` | CIE-10 K00-K14 (obligatorio), SNOMED CT |
| DENTAR-AN | Anatomía dental (segunda etapa) | `DNT-AN-NNNNNN` | SNOMED CT, FDI |
| DENTAR-CL | Hallazgos clínicos (segunda etapa) | `DNT-CL-NNNNNN` | SNOMED CT |

`DENTAR-PR` y `DENTAR-DX` son los productos activos. `DENTAR-AN` y `DENTAR-CL`
están planificados: no tienen códigos ni tablas propias todavía.

La marca `DENTAR` no tiene códigos ni releases propias. En la API figura como
catálogo de rol `family`, con `family_code = null`; los productos declaran
`family_code = 'dentar'` y rol `catalog`.

## Estado actual

| Pieza | Estado |
| --- | --- |
| Registro de la familia | `sql/dentar_family.sql` → `dentar_catalog` |
| Esquema editorial (`dentar_*`) | `sql/dentar_core_and_diagnosis.sql` |
| Procedimientos cargados | **138** de los 800 del catálogo inicial (DENTAR-PR) |
| Diagnósticos cargados | **38** (DENTAR-DX) |
| Importador masivo | `tools/php/import_dentar_csv.php` |
| Sincronización con la API de catálogos | `sql/sync_dentar_to_os.sql` (automática) |
| API | `GET /v1/catalogs`, `GET /v1/catalogs/dentar-pr/items`, `GET /v1/catalogs/dentar-dx/items`, `GET /v1/odontologia/diagnosticos` |

El seed del SQL no escala a 800 códigos: editar cientos de bloques de `INSERT` a
mano es inviable y propenso a error. Por eso el catálogo se carga desde CSV con
el importador, que es idempotente y valida códigos, categorías y mapeos.

## Orden de carga

```bash
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/origen_catalog_engine.sql
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/pmo.sql
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/dentar_family.sql
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/dentar_core_and_diagnosis.sql
```

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
| `criterios_clinicos` | No | ambos | Criterios de uso o justificación clínica. |
| `ambito_clinico` | No | DENTAR-PR | Capítulo, ej. `Capítulo III - Endodoncia`. |
| `categoria` | No | ambos | Código de `dentar_category` del mismo catálogo. |
| `tipo_concepto` | No | DENTAR-PR | `procedure` (default), `service`, `evaluation`, `diagnostic_service`, `rehabilitation`. |
| `sinonimos` | No | ambos | Alternativas separadas por `|`. |
| `nomenclador_ar` | No | DENTAR-PR | Código del nomenclador odontológico argentino (ej. `03.01`). **Obligatorio para publicar.** |
| `cdt_2025` | No | DENTAR-PR | Código ADA CDT 2025 (ej. `D3310`). |
| `cie10` | No | DENTAR-DX | Código CIE-10 K00-K14 (ej. `K02.1`). **Obligatorio para publicar.** |
| `snomed_sctid` | No | ambos | SCTID del concepto en SNOMED CT Argentina. |

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

Al final de esa misma transacción ejecuta `sql/sync_dentar_to_os.sql`, que
proyecta cada producto a `os_catalog_item`, `os_catalog_item_version`,
`os_catalog_term`, `os_catalog_identifier` y `os_concept_mapping` — el modelo
que consumen `GET /v1/catalogs/dentar-pr/items` y
`GET /v1/catalogs/dentar-dx/items`.

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

## Hoja de ruta hacia los 800 códigos

El objetivo de 800 procedimientos no se completa inventando códigos. El
repositorio aporta la infraestructura; el contenido clínico lo aprueba el comité
editorial.

| Fase | Trabajo | Salida verificable |
| --- | --- | --- |
| 0. Auditoría del seed | Revisar los 138 procedimientos y 38 diagnósticos existentes: definición, categoría, mapeos faltantes o dudosos. | Informe de cobertura por capítulo y lista de mapeos a corregir. |
| 1. Candidatos | Relevar procedimientos faltantes desde ADA CDT 2025, nomenclador odontológico argentino y especialidades; diagnósticos faltantes desde CIE-10 K00-K14. | Planilla de candidatos sin código DENTAR asignado. |
| 2. Priorización | Ordenar por frecuencia de uso, impacto arancelario y demanda de obras sociales / colegios. | Lotes de 50-100 códigos por capítulo. |
| 3. Revisión clínica | El comité valida definición, criterios de auditoría, CIE-10 y equivalencia SNOMED CT / CDT. | Versiones `approved` en `dentar_concept_version` / `dentar_diagnosis_version`. |
| 4. Carga y publicación | Importar cada lote con `--dry-run`, corregir errores, cargar y sincronizar `os_*`. | Release `DENTAR-PR-vN` / `DENTAR-DX-vN` publicada y medible. |
| 5. Seguimiento | Informe mensual de adopción y de cobertura de la familia. | `docs/adopcion/informes/AAAA-MM.md`. |

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
