# Carga de SNOMED CT Argentina en PostgreSQL

Réplica en PostgreSQL 18 del procedimiento del proyecto
[`luisuriarte/snomed_argentina`](https://github.com/luisuriarte/snomed_argentina),
que está pensado para OpenEMR sobre MariaDB. La lógica es la misma; cambia el
motor de carga:

| MariaDB / OpenEMR | PostgreSQL / Origen Salud |
| --- | --- |
| `LOAD DATA LOCAL INFILE` | `COPY` (servidor) o `\copy` (psql) |
| Tablas `sct2_*` sueltas | Esquema `sct2` |
| `TRUNCATE` + `LOAD DATA` en DBeaver | `01` → `02` → `03` → `99` con `psql` |
| `AUTO_INCREMENT`, `UNSIGNED` | `BIGINT`, `UUID`, `TEXT` |
| Índices al crear la tabla | Índices después del `COPY` |

Se carga **sólo `Snapshot/`**. Los archivos `Full/` y `Delta/` traen histórico y
duplican identificadores; el generador los ignora a propósito.

## Archivos

| Archivo | Qué hace | Modifica datos |
| --- | --- | --- |
| `01_esquema.sql` | Borra y recrea el esquema `sct2` con las 15 tablas RF2 (`UNLOGGED`, sin claves ni índices). | Sí (sólo `sct2`) |
| `02_carga.sql` | **Generado**. Un `COPY` por archivo, con lista explícita de columnas. | Sí |
| `03_postcarga.sql` | Claves, índices, integridad, tablas derivadas, vistas de refsets y publicación en `public`. | Sí |
| `04_codigos_opcional.sql` | **Opcional**. Publica los refsets filtrables en `public.snomed_refset_member` y `public.v_snomed_refset`. | Sí |
| `05_map_excel.sql` | **Opcional**. Carga los mapeos NBU y GTIN (`sct2.map_nbu`, `sct2.map_gtin`) desde los TSV del conversor. | Sí |
| `99_verificacion.sql` | Conteos, integridad, cobertura, publicación y artefactos opcionales. Sólo `SELECT`. | No |

El generador vive en `tools/php/generar_carga_snomed.php`. Se ejecuta en la PC
(o en el servidor) y **no se conecta a la base**: sólo escribe el `.sql`.

## Requisitos

- PostgreSQL 18 con `pg_trgm` (la crea `sql/design.sql` y la asegura
  `03_postcarga.sql`).
- PHP 8.2+ para el generador, con `zip` habilitado si se parte del ZIP oficial.
  Si `php_zip` no está disponible, descomprimir a mano y pasar la carpeta.
- Para los mapeos NBU/GTIN, PHP 8.2+ con `zlib`, `dom` y `xmlreader` (vienen
  habilitados en la mayoría de las instalaciones). El conversor no necesita
  `ext-zip`: lee el XLSX como ZIP con `gzinflate`.
- `psql` para el flujo recomendado. DBeaver sirve, con las salvedades de más
  abajo.
- Espacio en disco: la release de agosto de 2026 ocupa ~1,6 GB comprimida y
  ~6 GB extraída; el esquema `sct2` más los índices ronda los 15-20 GB.

## Puesta en marcha

```bash
# 1. Esquema de staging (destructivo sólo para sct2)
psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/01_esquema.sql

# 2. Generar el script de carga desde el ZIP oficial
php tools/php/generar_carga_snomed.php \
    "D:\sct\SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z.zip"

# 3. Cargar (leyendo los archivos en el servidor de base de datos)
psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/02_carga.sql

# 4. Índices, derivadas, vistas y publicación
psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/03_postcarga.sql

# 5. Opcional: refsets filtrables para la API
psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/04_codigos_opcional.sql

# 6. Opcional: mapeos NBU y GTIN (primero convertir los XLSX a TSV)
php tools/php/convertir_excel_maps.php "D:\sct\20260820\Resources"
# \copy lee los TSV en la máquina cliente, con nombres resueltos contra el
# directorio actual: hay que ejecutar psql parado en la carpeta de los TSV.
cd /ruta/al/20260820/Resources
sudo -u postgres psql -d origen_salud -v ON_ERROR_STOP=1 \
     -f /var/www/html/origen.ar/code-api/tools/sql/snomed/05_map_excel.sql

# 7. Controles
psql -d origen_salud -f tools/sql/snomed/99_verificacion.sql
```

Duración de referencia en un servidor de 8 GB y disco SSD: 15-30 minutos de
`COPY`, 20-40 minutos de índices y 2-5 minutos de publicación.

## El generador

```bash
php tools/php/generar_carga_snomed.php <zip|carpeta> [opciones]
```

| Opción | Efecto |
| --- | --- |
| `--salida=RUTA` | Archivo `.sql` a generar. Default: `tools/sql/snomed/02_carga.sql`. |
| `--destino=RUTA` | Carpeta donde extraer el ZIP. Default: `<carpeta del ZIP>/sct_carga_<AAAAMMDD>`. |
| `--ruta=RUTA` | Prefijo que se escribe en los `COPY`. Sirve para generar en la PC y ejecutar en el servidor. |
| `--cliente` | Genera `\copy` (psql lee los archivos en la máquina cliente) en vez de `COPY`. |
| `--sin-opcionales` | Omite stated, text definitions, identifier, concrete, association, mapas, medicinales y OWL. |
| `--con-stated` | Incluye relaciones declaradas aunque se use `--sin-opcionales`. |
| `--quiet` | No muestra el progreso. |
| `-h`, `--help` | Ayuda. |

Códigos de salida:

| Código | Significado |
| --- | --- |
| `0` | Script generado. |
| `1` | Error de archivo, cabecera o escritura. |
| `2` | Uso incorrecto de argumentos. |

Antes de escribir el SQL, el generador:

1. Detecta cada archivo por nombre (`sct2_Concept_Snapshot_*`,
   `der2_cRefset_LanguageSnapshot_*`, etc.).
2. Descarta todo lo que esté bajo `Full/` o `Delta/`.
3. Valida que la cabecera TSV coincida **en orden y cantidad** con la tabla
   destino. Si la release cambia el orden de columnas, falla en vez de cargar
   basura.
4. Verifica que existan conceptos, descripciones, relaciones y los tres refsets
   base (simple, language, attribute value).
5. Falla si hay dos archivos del mismo tipo (por ejemplo, dos releases
   mezcladas en la misma carpeta).

### `COPY` en el servidor o `\copy` en el cliente

| Modo | Cuándo usarlo | Requisito |
| --- | --- | --- |
| `COPY` (default) | Los archivos están en el mismo servidor que PostgreSQL. | Superusuario o `pg_read_server_files`; ruta absoluta del servidor. |
| `--cliente` | Se ejecuta con `psql` desde otra máquina (o los archivos están en la PC). | `psql -f`; los archivos viajan por la conexión. |

Con `COPY` y `--ruta`, generar en la PC y apuntar a la ruta del servidor:

```bash
php tools/php/generar_carga_snomed.php "D:\sct\20260820" --ruta=/opt/sct/20260820
scp -r "D:\sct\20260820" usuario@servidor:/opt/sct/
```

Con `--cliente`, el archivo generado tiene `\copy` y **debe** ejecutarse con
`psql -f`; DBeaver no interpreta comandos meta (`\copy`). No combines
`--cliente` con `--ruta`: en ese modo la ruta se resuelve en la máquina donde
corre `psql`, no en el servidor.

```bash
php tools/php/generar_carga_snomed.php "D:\sct\20260820" --cliente --salida=02_carga_cliente.sql
psql -h servidor -d origen_salud -v ON_ERROR_STOP=1 -f 02_carga_cliente.sql
```

## Qué hace cada script

### `01_esquema.sql`

- `DROP SCHEMA IF EXISTS sct2 CASCADE` y `CREATE SCHEMA sct2`. Es destructivo
  **sólo** para `sct2`; los catálogos y las tablas de la API están en `public`.
- Crea 15 tablas `UNLOGGED`, sin `PRIMARY KEY` y sin índices secundarios.
- Las tablas son `UNLOGGED` para acelerar el `COPY`. Contrapartida: si
  PostgreSQL se cae durante la carga, `sct2` se trunca y hay que repetir desde
  `01_esquema.sql`.
- `refset` usa `UUID` para el `id` del miembro y `BIGINT` para los SCTID.
- `term` es `TEXT`: la edición argentina tiene términos de más de 255
  caracteres.

### `02_carga.sql` (generado)

- `SET client_encoding = 'UTF8'` y timeouts en `0`.
- Un `COPY sct2.<tabla> (<columnas>) FROM '<ruta>' WITH (FORMAT csv, DELIMITER
  E'\t', QUOTE E'\b', ESCAPE E'\b', HEADER true, ENCODING 'UTF8')` por archivo.
- `QUOTE`/`ESCAPE` con backspace desactivan el entrecomillado: los términos se
  copian literales, con comas, comillas y saltos incluidos.
- En CSV un campo vacío se lee como `NULL`. Las columnas `NOT NULL` que RF2
  puede traer vacías (`mapTarget`, `mapRule`, `mapAdvice`) se marcan con
  `FORCE_NOT_NULL` para que queden como cadena vacía. Las columnas anulables
  del refset de productos medicinales quedan como `NULL`.
- El orden es el de dependencia lógica: conceptos → descripciones → relaciones
  → refsets.
- No hace `TRUNCATE`: `sct2` viene vacío de `01_esquema.sql`. Si se reejecuta
  sin recrear el esquema, fallan los índices únicos de `03_postcarga.sql`.

### `03_postcarga.sql`

1. Comprueba que `sct2.concept` exista y no esté vacía.
2. Crea los índices diferidos:
   - únicos por `id` en todas las tablas;
   - `sct2.description (concept_id)`, `(language_code, type_id)`;
   - `sct2.relationship (source_id, type_id)` y `(destination_id, type_id)`;
   - GIN trigram sobre `sct2.description.term` y
     `sct2.preferred_term.term`;
   - índices por `refset_id` / `referenced_component_id` en los refsets.
3. Valida integridad: descripciones y relaciones con concepto existente.
4. Construye las tablas derivadas:
   - `sct2.language_effective`: una fila por descripción. Prioridad preferida >
     aceptable, módulo argentino (`11000221109`) > internacional,
     `effective_time` más reciente, `id` como desempate.
   - `sct2.preferred_term`: un término por concepto activo. Español primero,
     luego inglés; sinónimo antes que FSN; el más corto como desempate.
   - `sct2.refset_summary`: miembros activos y totales por refset.
   - `sct2.generic_drug`: genéricos prescribibles del DNM (`574471000221107`,
     `574481000221105`) con unidad de presentación y forma farmacéutica
     (relación `411116001`).
   - `sct2.brand_generic`: marca comercial (`425071000221108`) → genérico
     (`116680003` cuando hay un único destino), comercializada
     (`574461000221103`), laboratorio (`774159003`), condición de expendio
     (`574941000221106`) y categoría de control (`579631000221106`).
5. Crea las vistas:
   - `sct2.v_search_term`: descripciones activas en español + término
     preferido. Reemplaza a la tabla `sct2_termino_busqueda` del proyecto
     MariaDB: en PostgreSQL el GIN de `sct2.description` ya resuelve el
     autocompletado sin duplicar 1,4 millones de filas.
   - `sct2.v_refset_member` y una vista por dominio: `v_lab_practice`,
     `v_imaging_practice`, `v_procedure`, `v_vaccine`, `v_dental_diagnosis`,
     `v_dental_procedure`, `v_notifiable_disease`, `v_device`.
   - RefSets argentinos nominados: `v_specialty` (`331151000221108`),
     `v_profession` (`2271000221108`), `v_occupation` (`331131000221104`),
     `v_remediar` (`349091000221101`), `v_sumar_diagnosis`
     (`371191000221103`), `v_sumar_procedure` (`371201000221100`),
     `v_sumar_scope` (`371221000221107`), `v_sumar_professional`
     (`371211000221102`) y `v_aboriginal_people` (`93491000221103`).
   - `v_nomivac` (`401211000221103`) y `v_cie10_map` (`447562003`).
   - `v_generic`, `v_brand`, `v_generic_brand` y `v_presentation` para el DNM.
6. Publica en las tablas de la API:
   - `snomed_concepts`: `UPSERT` + baja lógica de los que ya no están. No se
     borran para no romper `anmat_medicamentos` ni los catálogos locales.
   - `snomed_descriptions` y `snomed_relationships`: `TRUNCATE` + `INSERT`
     dentro de una transacción (mucho más rápido que 4 millones de `UPSERT`).
   - `map_snomed_cie10`: cruza `map_target` con `cie10_codes.codigo`
     normalizado (sin punto, mayúsculas).
7. Agrega a los catálogos locales las filas derivadas de los refsets
   argentinos. El código local es el SCTID. Las filas curadas con otro código
   **no se pisan**; las derivadas que salen del refset se dan de baja lógica.
8. `ANALYZE` de todas las tablas tocadas.

Refsets usados para los catálogos:

| Catálogo | Refset | Filas 2026-08-20 |
| --- | --- | --- |
| `laboratorio_practicas` | `537301000221103` | 1.007 |
| `vacunas_catalogo` | `2281000221106` | 407 |
| `odontologia_prestaciones` | `398711000221107`, `399211000221109` | 462 (344 + 118) |
| `prestaciones_medicas` | `577281000221100`, `371201000221100` | 2.143 + SUMAR |
| `imagenes_practicas` | `536561000221108` | 579 |

`imagenes_practicas.modalidad_dicom` se completa con `'OT'` (Other) porque RF2
no trae la modalidad DICOM. La institución puede ajustarla después.

`programas_sociales` y `anmat_medicamentos` **no** se autocompletan: son datos
curados y los números de certificado ANMAT no están en RF2.

### `04_codigos_opcional.sql`

Opcional. Es el equivalente PostgreSQL de `04_codigos_opcional.sql` del
proyecto MariaDB: allí los conceptos se publican en la tabla `codes` de OpenEMR
con tipos 201–206; acá se publican en una tabla propia para que la API pueda
filtrar sin conocer los SCTID de los refsets.

- Crea `public.snomed_refset_member` con una fila por miembro y
  `filter_code` (el nombre corto del catálogo).
- `filter_code` sale de `public.sct2_refset_catalog`. Los refsets con
  `filter_code = NULL` (idioma, mapas, refsets inactivos) no se publican.
- Incluye los refsets simples y los mapas simples (por ejemplo NOMIVAC, con su
  `map_target`). No incluye mapas extendidos.
- Reconstruye la tabla completa con `TRUNCATE`; es idempotente.
- Crea índices por `filter_code`, `concept_id`, `map_target` y GIN trigram sobre
  `term`, y la vista `public.v_snomed_refset` con nombre y categoría.

Códigos de filtro publicados:

| Categoría | `filter_code` |
| --- | --- |
| Medicamentos | `MARCAS`, `MARCAS_COMERCIALIZADAS`, `PRESENTACIONES`, `PRESENT_COMERCIALIZADAS`, `GENERICO_CON_UNIDAD`, `GENERICO_SIN_UNIDAD` |
| Prácticas | `PRESTACIONES`, `LABORATORIO`, `IMAGENES`, `SUMAR_PROC` |
| Programas | `SUMAR_DX`, `SUMAR_AMBITO`, `SUMAR_PROF`, `REMEDIAR` |
| Vacunas | `VACUNAS`, `NOMIVAC` |
| Odontología | `ODONTO_DX`, `ODONTO_PROC` |
| Otros | `ENO`, `DISPOSITIVOS`, `PUEBLOS`, `ESPECIALIDADES`, `PROFESIONES`, `OCUPACIONES` |

Consultar el catálogo completo:

```sql
SELECT refset_id, name, category, filter_code
  FROM public.sct2_refset_catalog
 WHERE filter_code IS NOT NULL
 ORDER BY category, name;
```

La tabla se reconstruye completa: si la API la está consultando, programar la
ejecución en la misma ventana de mantenimiento que `03_postcarga.sql`.

La API consume estos datos de dos formas: `GET /v1/refsets` lista los códigos
disponibles con sus conteos y `GET /v1/search?refset=VACUNAS,NOMIVAC` restringe
la rama SNOMED a los conceptos que pertenecen a alguno de esos refsets. Si la
tabla no existe, el parámetro responde `400` con la indicación de ejecutar este
script.

### `05_map_excel.sql`

Opcional. Carga los dos mapeos que la edición argentina distribuye como Excel
en `Resources/`:

| Mapeo | Archivo | Filas 2026-08-20 | Tabla |
| --- | --- | --- | --- |
| NBU | `Mapeo_NBU_SCT_Agosto26.xlsx` | ~425 | `sct2.map_nbu` |
| GTIN | `MAP_GTIN_a_RPCD_comercializadas_20260820.xlsx` | ~15.500 | `sct2.map_gtin` |

Primero se convierten a TSV con el conversor PHP (no requiere Python ni
`ext-zip`):

```bash
php tools/php/convertir_excel_maps.php "D:\sct\20260820\Resources" \
    --salida="D:\sct\20260820\Resources\tsv"
```

Luego se cargan con `psql`, porque el script usa `\copy`:

```bash
# \copy NO expande variables de psql (:ruta_nbu no sirve): los nombres de
# archivo del script son literales y se buscan en el directorio actual.
cd "D:/sct/20260820/Resources/tsv"
psql -d origen_salud -v ON_ERROR_STOP=1 \
     -f tools/sql/snomed/05_map_excel.sql
```

En Linux, con los archivos en otra ruta, se puede fijar la carpeta dentro del
script descomentando y editando la línea `\cd` de la sección 2:

```sql
\cd /root/SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z/Resources
```

El script corta con un `ERROR` explícito si alguna de las dos tablas queda en 0
filas, para no confundir un `\copy` que no encontró el archivo con una carga
exitosa.

- `sct2.map_nbu (sctid, codigo_nbu, determinacion)`.
- `sct2.map_gtin (gtin, condicion, rpcd_id, rpcd_fsn)`. El GTIN se guarda como
  texto para no perder ceros; para comparar con un EAN-13 usar
  `WHERE gtin = lpad(:ean13, 14, '0')`.
- Crea los índices por `codigo_nbu` y `rpcd_id`, las vistas `sct2.v_map_nbu` y
  `sct2.v_map_gtin`, y controles de huérfanos.
- Hace `TRUNCATE` + carga en cada ejecución; es idempotente.

Si los TSV están en el servidor de base de datos, el apéndice del script trae
la variante con `COPY` para ejecutar desde DBeaver.

### `99_verificacion.sql`

Sólo lectura. Devuelve una columna `estado` con `OK` o `REVISAR`:

1. Volumen por tabla contra la edición 2026-08-20.
2. Integridad del Snapshot (descripciones/relaciones huérfanas, términos vacíos,
   idiomas, conceptos activos sin descripción).
3. Tablas derivadas (conceptos sin término preferido, duplicados de idioma,
   refsets sin nombre) y coherencia de genéricos/marcas del DNM.
4. Publicación (`public` vs `sct2`), incluidos los mapeos CIE-10.
5. Mínimos de los catálogos derivados.
6. Existencia de los índices críticos.
7. Cobertura de todos los refsets nominados en `sct2_refset_catalog`.
8. Artefactos opcionales: miembros de `04` y filas/huérfanos de `05`. Si no se
   ejecutaron, se informan como `sin ejecutar`.
9. Resumen de refsets y muestra de términos para controlar acentos/UTF-8.

Los conteos esperados son de **Argentina 2026-08-20**. Si se carga otra
release, actualizar el bloque `expected` del punto 1; los demás controles no
dependen de la edición.

## Actualización trimestral

1. Programar una ventana de mantenimiento: la publicación hace `TRUNCATE` y
   toma un lock exclusivo sobre `snomed_descriptions` y
   `snomed_relationships`.
2. Deshabilitar escrituras de la API (las lecturas también se bloquean durante
   el `TRUNCATE`).
3. Ejecutar `01` → generar `02` → `02` → `03`.
4. Si se usan refsets filtrables, ejecutar `04`; si se usan los mapeos NBU/GTIN,
   convertir los XLSX y ejecutar `05`.
5. Ejecutar `99_verificacion.sql` y revisar que no queden `REVISAR` distintos de
   los conteos de la nueva release.
6. Rehabilitar la API.

`03_postcarga.sql` se puede volver a ejecutar sin recrear `sct2`; reconstruye
derivadas, vistas y catálogos sin duplicar filas. `04` también es reejecutable
(`TRUNCATE` + carga). `01_esquema.sql` no: borra todo `sct2`, así que después de
él hay que repetir `02`, `03` y, si se usaban, `05`.

## Permisos

El usuario que carga necesita, como mínimo:

```sql
GRANT CREATE ON DATABASE origen_salud TO origen_carga;
GRANT USAGE, CREATE ON SCHEMA public TO origen_carga;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public TO origen_carga;
```

Para `COPY` del lado del servidor, además:

```sql
-- Opción A: superusuario (lo más simple en una carga puntual)
-- Opción B: rol con lectura de archivos del servidor
GRANT pg_read_server_files TO origen_carga;
```

La ruta del `COPY` debe ser legible por el **proceso** de PostgreSQL, no por el
usuario del sistema que ejecuta `psql`.

La API sólo necesita lectura:

```sql
GRANT USAGE ON SCHEMA public TO origen_api;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO origen_api;
```

## DBeaver

- Ejecuta bien `01`, `03`, `04` y `99`.
- `02_carga.sql` en modo `COPY`: funciona si el archivo está en el servidor y
  el usuario tiene permiso. Activar *autocommit* y ejecutar todo el script.
- `02_carga.sql` en modo `--cliente`: **no funciona**, porque `\copy` es un
  comando meta de `psql`. Usar `psql -f`.
- `05_map_excel.sql`: **no funciona** en DBeaver porque usa `\copy` y `\if`.
  Usar `psql -f` o reemplazar la carga por el bloque `COPY` del apéndice (los
  TSV deben estar en el servidor).
- `99_verificacion.sql` abre varios resultados; ejecutarlo con *Execute script*
  (Alt+X) para verlos todos.

## Rendimiento y almacenamiento

- `03_postcarga.sql` fija `maintenance_work_mem = '512MB'` y
  `work_mem = '256MB'`. En un servidor con más RAM, subirlos (por ejemplo 2 GB
  y 512 MB) acelera bastante la creación de índices.
- El esquema `sct2` puede borrarse después de publicar si no se van a usar las
  vistas de refsets: `DROP SCHEMA sct2 CASCADE;`. Los catálogos de `public` y
  las tablas de la API quedan intactos.
- Si se conserva `sct2`, `VACUUM (FULL, ANALYZE)` sobre las tablas grandes
  reduce espacio, pero requiere el doble de disco y un lock exclusivo.

## Problemas frecuentes

| Síntoma | Causa / solución |
| --- | --- |
| `ERROR: could not open file ...` | La ruta del `COPY` no existe **en el servidor** o el usuario no tiene `pg_read_server_files`. Usar `--cliente` o copiar los archivos al servidor. |
| `ERROR: invalid input syntax for type date` | Se cargó un archivo que no es Snapshot o la release usa otro formato. Verificar que el generador haya validado la cabecera. |
| `ERROR: duplicate key value violates unique constraint` | Se reejecutó `02_carga.sql` sin recrear el esquema. Volver a `01_esquema.sql`. |
| `ERROR: invalid input syntax for type bigint: ""` | `02_carga.sql` se generó con una versión anterior del generador. Volver a generarlo: los campos vacíos de RF2 necesitan `FORCE_NOT_NULL` o ser anulables. |
| `ERROR: cabecera inválida` | El archivo no es RF2 o cambió el orden de columnas. Revisar el nombre y la primera línea. |
| `ERROR: hay dos archivos para ...` | Hay dos releases en la misma carpeta. Dejar una sola. |
| `ERROR: no existe la extensión zip` | Habilitar `php_zip` o descomprimir y pasar la carpeta. El conversor NBU/GTIN no usa `ext-zip`. |
| `ERROR: No se pudo descomprimir ...` en el conversor | El XLSX está dañado o usa ZIP64. Abrirlo y volver a guardarlo desde Excel/LibreOffice. |
| `ERROR: No se encontró la relación de la hoja` | El XLSX se generó con una herramienta que no escribe `xl/_rels/workbook.xml.rels`. Guardarlo de nuevo desde Excel. |
| `ERROR: could not open file` en `05` | `\copy` lee en la máquina donde corre `psql` y resuelve los nombres contra el directorio actual: ejecutar `psql` parado en la carpeta de los TSV o descomentar la línea `\cd` de la sección 2. Pasar `-v ruta_nbu` no sirve: `\copy` no expande variables de psql. |
| `ERROR: invalid input syntax for type bigint` en `05` | Se cargó un TSV viejo o editado a mano. Volver a generarlo con `convertir_excel_maps.php`; el conversor omite filas sin ID numérico. |
| Acentos rotos | Verificar `client_encoding = 'UTF8'` y que los `.txt` sean UTF-8 sin BOM. La release oficial lo es. |
| `REVISAR` en conteos | Es esperable si la release no es 2026-08-20. Actualizar `expected` en `99_verificacion.sql`. |
| La API no ve los cambios | Falta `GRANT SELECT` sobre las tablas nuevas o no se ejecutó `ANALYZE`. |

## Diferencias deliberadas con el proyecto MariaDB

- No se borran las descripciones en inglés: la API es bilingüe y el buscador
  acepta `language=es|en`. El proyecto de OpenEMR ofrece `--sin-ingles` porque
  allí el español es la única interfaz.
- No se crea `sct2_termino_busqueda`: sería una tabla de 1,4 millones de filas
  duplicada. El GIN trigram sobre `sct2.description.term` cumple la misma
  función.
- No se publica en `codes` de OpenEMR: se publica en `snomed_concepts`,
  `snomed_descriptions` y `snomed_relationships`, el contrato de la API. Los
  refsets filtrables se publican en `public.snomed_refset_member`
  (`04_codigos_opcional.sql`), no en una tabla de tipos de código.
- Los mapeos NBU/GTIN no se cargan desde Excel dentro de PostgreSQL: se
  convierten a TSV con PHP y se cargan con `\copy`/`COPY`.
- Los catálogos locales se pueblan desde los refsets, pero nunca se sobrescribe
  una fila curada por la institución.
