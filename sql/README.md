# SQL · Orden de carga y mapa de esquemas

Esta carpeta tiene scripts de orígenes y épocas distintas (PostgreSQL 18 actual,
más restos del proyecto MariaDB original). Acá queda fijado **qué archivo es la
fuente de verdad**, **en qué orden se ejecuta** y **qué no se debe ejecutar**.

## Regla de oro

| Archivo | Rol | ¿Ejecutar? |
| --- | --- | --- |
| `design.sql` | Base del proyecto: extensiones, tablas de la API (`snomed_*`, `cie10_*`, `anmat_*`, catálogos locales), `api_clients`, refsets. | **Sí, primero y una sola vez.** |
| `origen_catalog_engine.sql` | **Fuente de verdad de catálogos, nomencladores, aranceles, mapeos y vademécum** (`os_*`). Al final sincroniza las tablas planas `nomencladores_argentina` y `vademecum_comercial` que consulta la API. | **Sí.** Es el archivo canónico del Origen Catalog Engine. |
| `pmo.sql` | Programa Médico Obligatorio (prácticas, precios, formulario, normativa, odontología). | **Sí**, después del engine. |
| `dentar_family.sql` | Registro de la familia DENTAR (`dentar_catalog`), función `dentar_catalog_id()`, migración de códigos viejos y trigger de prefijo por catálogo. | **Sí**, antes del núcleo DENTAR. |
| `dentar_core_and_diagnosis.sql` | Núcleo editorial de DENTAR-PR y DENTAR-DX: categorías, conceptos permanentes, versiones, términos, mapeos (Nomenclador AR / CDT 2025 / SNOMED CT / CIE-10) y diagnósticos. | **Sí.** |
| `sync_dentar_to_os.sql` | Proyecta `dentar_*` al modelo publicado `os_*` que consume `/v1/catalogs`: DENTAR-PR y DENTAR-DX con releases independientes; marca las anteriores como `deprecated`. | Automático al importar CSV; manual si se edita DENTAR por SQL. |
| `Argentina_dental_cdt_codes_2025.sql` | Catálogo CDT 2025 y nomenclador odontológico argentino en tablas `odontologia_*`. | **Sí.** |
| `importar_loinc.sql` | LOINC 2.83 (`loinc`, `loinc_map`). Requiere los CSV/LOINC en la ruta que indica su cabecera. | Opcional. |
| `cargar_loinc_consumer_names.sql` | Nombres de consumo LOINC (`ConsumerName`). | Opcional, después de `importar_loinc.sql`. |
| `nomencladores_argentina.sql` | **Legacy**: crea sólo `nomencladores_argentina` + `vademecum_comercial`. Es un subconjunto del engine. | Sólo en bases creadas antes del engine. |
| `odontologico.sql` | **Legacy MySQL** (usa backticks). No es compatible con PostgreSQL. | **No.** Pendiente de portar o retirar. |

> `nomencladores_argentina` y `vademecum_comercial` aparecen definidas en
> `design.sql`, en `origen_catalog_engine.sql` y en `nomencladores_argentina.sql`.
> Las tres definiciones son equivalentes y usan `CREATE TABLE IF NOT EXISTS`, por
> lo que no se pisan: gana la primera que se ejecuta. **No agregar columnas nuevas
> en un solo archivo**: si hay que cambiar el esquema, se cambia en los tres o se
> elimina la definición duplicada.

## Orden de carga (base nueva)

```bash
# 0. Base y usuario (una sola vez, como postgres)
createdb -E UTF8 origen_salud

# 1. Esquema base de la API
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/design.sql

# 2. SNOMED CT Argentina (ver tools/sql/snomed/README.md o tools/sh/cargar_snomed.sh)
sudo -u postgres bash tools/sh/cargar_snomed.sh /ruta/al/SnomedCT_..._20260820T120000Z

# 3. Origen Catalog Engine (nomencladores, aranceles, DENTAR, vademécum)
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/origen_catalog_engine.sql

# 4. PMO
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/pmo.sql

# 5. Registro de la familia DENTAR (DENTAR-PR / DENTAR-DX)
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/dentar_family.sql

# 6. Núcleo editorial DENTAR + diagnósticos y mapeos
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/dentar_core_and_diagnosis.sql

# 7. CDT 2025 / nomenclador odontológico
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/Argentina_dental_cdt_codes_2025.sql

# 8. Opcional: LOINC
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/importar_loinc.sql
```

### Por qué ese orden

- Todo lo que tiene `snomed_concept_id` con FK **necesita SNOMED cargado antes**
  (`origen_catalog_engine.sql`, `pmo.sql`, `nomencladores_argentina.sql`).
- `origen_catalog_engine.sql` crea `os_*` y **después** sincroniza
  `nomencladores_argentina` / `vademecum_comercial`; por eso va antes de cualquier
  carga de nomencladores por CSV (`tools/php/import_nomenclador_csv.php`).
- `dentar_family.sql` crea `dentar_catalog` y `dentar_catalog_id()`. El núcleo
  editorial lo exige y falla con un mensaje explícito si falta.
- `dentar_core_and_diagnosis.sql` referencia `dentar_catalog`, `dentar_category` y
  `dentar_terminology_system`; los mapeos a `SNOMED-CT` sólo se pueden validar
  con SNOMED presente.
- `Argentina_dental_cdt_codes_2025.sql` usa `odontologia_prestaciones`, ya creada
  por `design.sql`; si se ejecuta solo (sin `design.sql`) también la crea.

## Nomencladores por CSV

```bash
php tools/php/import_nomenclador_csv.php archivos/nbu_2026.csv NBU
php tools/php/import_nomenclador_csv.php archivos/nn_pmo.csv   NN_PMO
php tools/php/import_nomenclador_csv.php archivos/nhpgh.csv    NHPGD
php tools/php/import_nomenclador_csv.php archivos/andis.csv    ANDIS
```

Tipos válidos: `NN_PMO`, `NBU`, `NHPGD`, `ANDIS`, `KINESIOLOGIA`, `SALUD_MENTAL`,
`VADEMECUM`. Columnas reconocidas: `codigo`, `descripcion` (o `nombre`),
`capitulo`, `unidad_tipo`, `unidad_valor`, `gastos_valor`, `snomed_concept_id`,
`codigo_loinc`. El importador es idempotente (`ON CONFLICT` por
`tipo_nomenclador + codigo`).

`VADEMECUM` no escribe en `nomencladores_argentina`: va a
`vademecum_comercial`, con `troquel` como clave. Columnas: `troquel`
(obligatoria), `nombre_comercial`, `monodroga`, `presentacion` (obligatorias) y
opcionales `codigo_alfabeta`, `codigo_kairos`, `codigo_barras_gtin`,
`laboratorio`, `accion_farmacologica`, `tipo_venta`, `anmat_certificado`.

## DENTAR

La familia DENTAR vive en `dentar_*` y se publica en `os_*`:

| Producto | Tablas editoriales | Código | Release |
| --- | --- | --- | --- |
| DENTAR-PR | `dentar_concept*` | `DNT-PR-NNNNNN` | `2026-v1`, después `DENTAR-PR-vN` |
| DENTAR-DX | `dentar_diagnosis*` | `DNT-DX-NNNNNN` | `2026-v1`, después `DENTAR-DX-vN` |

La marca `dentar` es un catálogo de rol `family` en `os_catalog`: no tiene
códigos, releases ni aranceles propios. El seed de
`dentar_core_and_diagnosis.sql` trae 138 procedimientos y 38 diagnósticos sobre
un objetivo de 800 procedimientos. Para escalar sin editar cientos de bloques de
SQL a mano:

```bash
php tools/php/import_dentar_csv.php docs/dentar/plantilla-dentar-pr.csv --dry-run
php tools/php/import_dentar_csv.php docs/dentar/catalogo-pr.csv
php tools/php/import_dentar_csv.php docs/dentar/catalogo-dx.csv
```

Al terminar, el importador ejecuta `sync_dentar_to_os.sql` dentro de la misma
transacción y publica ambos productos en `os_*`, que es lo que leen
`GET /v1/catalogs/dentar-pr/items` y `GET /v1/catalogs/dentar-dx/items`. Con
`--sin-sync` se omite (por ejemplo, para cargar DENTAR antes de tener el engine).
El script también se puede ejecutar a mano y es idempotente:

```bash
psql -d origen_salud -v ON_ERROR_STOP=1 -f sql/sync_dentar_to_os.sql
```

Ver [`docs/dentar/README.md`](../docs/dentar/README.md).

## Comprobaciones rápidas

```sql
-- Catálogos cargados
SELECT 'nomencladores_argentina' AS tabla, count(*) FROM nomencladores_argentina
UNION ALL SELECT 'vademecum_comercial', count(*) FROM vademecum_comercial
UNION ALL SELECT 'os_catalog_item',     count(*) FROM os_catalog_item
UNION ALL SELECT 'dentar_concept',      count(*) FROM dentar_concept
UNION ALL SELECT 'dentar_diagnosis',    count(*) FROM dentar_diagnosis
UNION ALL SELECT 'pmo_practicas',       count(*) FROM pmo_practicas;

-- Mapeos DENTAR por sistema
SELECT system_code, count(*) FROM dentar_concept_mapping GROUP BY 1 ORDER BY 2 DESC;

-- Procedimientos DENTAR sin mapeo a SNOMED CT (debería tender a 0)
SELECT count(*) FROM dentar_concept c
 WHERE NOT EXISTS (
     SELECT 1 FROM dentar_concept_version cv
       JOIN dentar_concept_mapping m ON m.concept_version_id = cv.id
      WHERE cv.concept_id = c.id AND m.system_code = 'SNOMED-CT'
 );
```
