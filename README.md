# Origen Salud

Plataforma B2B de **Terminología-as-a-Service (TaaS)** con dos frentes sobre la misma base de código:

| Frente | Dominio | Contenido |
| --- | --- | --- |
| Portal institucional | `med.origen.ar` | Sitio trilingüe con locales canónicos `es-AR`, `en` y `pt-BR` (alias de entrada `es` y `pt`), selector persistente y URLs `/{locale}/...`. |
| API REST | `api.origen.ar` | Búsqueda unificada de terminología clínica y catálogos: SNOMED-CT, CIE-10, ANMAT, laboratorio, vacunas, familia odontológica DENTAR (DENTAR-PR / DENTAR-DX / DENTAR-AN / DENTAR-CL, ADA CDT 2025), prestaciones, programas e imágenes. |

### Documentación de Acceso e Interoperabilidad
- 📖 [Documentación de la API REST (v1)](README-API.md) — Autenticación, endpoints unificados, catálogos nacionales y familia odontológica DENTAR (CDT / CIE-10 / SNOMED AR). Especificación: [`docs/api/openapi-3.1.yaml`](docs/api/openapi-3.1.yaml).
- 🏥 [Guía de Interoperabilidad HL7® FHIR® R4](README-FHIR.md) — **contrato propuesto, aún no implementado**: `CodeSystem`, `ValueSet`, `ConceptMap`, `$lookup`, `$expand`, `$translate` y modelado clínico (`Procedure`, `Condition`, `Claim`).
- 🏗️ [Propuesta de arquitectura de catálogos sanitarios](docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md) — diagnóstico, modelo objetivo, plan por etapas y decisiones pendientes.

### Estado real de DENTAR en `origen_codes`

| Catálogo | Ítems | Observaciones |
| --- | ---: | --- |
| `DENTAR-PR` | 844 | Procedimientos; códigos `DNT-PR-NNNNNN`. |
| `DENTAR-DX` | 223 | Diagnósticos; códigos `DNT-DX-NNNNNN`. |
| `DENTAR-AN` | 624 | Términos SNOMED AR RF2 en español; versión `en` publicada por trigger. |
| `DENTAR-CL` | 218 | Términos SNOMED AR RF2 en español; versión `en` publicada por trigger. |
| Relaciones CDT | 333 filas / 303 pares / 15 tipos | En `os_catalog_relation`, navegables desde Browse. |

`DENTAR-IN`, `DENTAR-PD` y `DENTAR-EQ` quedan **reservados**, sin datos cargados. El módulo UVR está diseñado pero **sin valores cargados**: no se publican conversaciones monetarias ni UVR inventados.

## Stack

- PHP 8.2+ nativo, sin framework.
- Composer 2 para dependencias y autoload PSR-4.
- `symfony/translation` + `symfony/yaml` para i18n.
- PostgreSQL 18 con PDO, consultas preparadas nativas y `pg_trgm`.
- `vlucas/phpdotenv` para variables de entorno.

## Estructura

```text
.
├── bootstrap.php              # Autoload, .env, errores y helpers globales
├── composer.json
├── .env.example
├── sql/
│   ├── README.md              # Orden de carga y mapa de esquemas
│   ├── design.sql             # Esquema base y extensiones de PostgreSQL
│   ├── origen_catalog_engine.sql  # Catálogos, nomencladores, aranceles y familia DENTAR
│   ├── pmo.sql                # Programa Médico Obligatorio
│   ├── dentar_family.sql      # Registro DENTAR-PR / DENTAR-DX y migración de códigos
│   ├── dentar_core_and_diagnosis.sql  # Núcleo editorial DENTAR-PR y DENTAR-DX
│   ├── sync_dentar_to_os.sql  # Publica DENTAR-PR y DENTAR-DX en el Catalog Engine (os_*)
│   ├── Argentina_dental_cdt_codes_2025.sql
│   ├── importar_loinc.sql
│   └── nomencladores_argentina.sql    # Legacy (subconjunto del engine)
├── docs/
│   ├── dentar/                # Familia DENTAR: formato CSV, plantillas e importación
│   └── adopcion/              # Informe mensual de adopción institucional
├── tools/
│   ├── php/
│   │   ├── generar_carga_snomed.php   # Genera 02_carga.sql (COPY) desde el ZIP RF2
│   │   ├── convertir_excel_maps.php   # Convierte los XLSX de NBU/GTIN a TSV
│   │   ├── import_dentar_csv.php      # Ingesta masiva de DENTAR-PR y DENTAR-DX
│   │   ├── import_nomenclador_csv.php # Ingesta CSV de nomencladores argentinos
│   │   ├── import_snomed_rf2.php      # CLI de ingesta RF2 por lotes
│   │   ├── Rf2Importer.php           # Motor de importación (streaming + UPSERT)
│   │   ├── ImportOptions.php
│   │   └── ImportResult.php
│   ├── sh/
│   │   └── cargar_snomed.sh   # Carga SNOMED completa (01..99) en el VPS
│   └── sql/
│       ├── README.md
│       ├── snomed/
│       │   ├── README.md              # Procedimiento de carga masiva
│       │   ├── 01_esquema.sql         # Esquema de staging sct2
│       │   ├── 02_carga.sql           # Generado (COPY); no se versiona
│       │   ├── 03_postcarga.sql       # Índices, derivadas, vistas y publicación
│       │   ├── 04_codigos_opcional.sql # RefSets filtrables para la API (opcional)
│       │   ├── 05_map_excel.sql       # Mapeos NBU y GTIN (opcional)
│       │   └── 99_verificacion.sql    # Conteos, integridad y publicación
│       ├── verify_snomed_import.sql
│       └── post_import_maintenance.sql
├── api/
│   ├── index.php              # Front Controller / enrutador REST
│   ├── config/
│   │   └── database.php       # Conexión PDO centralizada y transacciones
│   ├── controllers/
│   │   └── ConceptController.php
│   ├── services/
│   │   └── TerminologySearchService.php  # Búsqueda unificada multimodelo
│   ├── http/
│   │   ├── ApiException.php
│   │   ├── ApiKeyAuthenticator.php
│   │   ├── Cors.php
│   │   ├── Request.php
│   │   └── Response.php
│   └── .htaccess
└── web/
    ├── index.php              # Portal bilingüe
    ├── includes/
    │   └── i18n.php           # Translator de Symfony + helper trans()
    ├── translations/
    │   ├── messages.es.yaml
    │   └── messages.en.yaml
    ├── assets/css/app.css
    └── .htaccess
```

## Puesta en marcha

### 1. Requisitos

- PHP 8.2 o superior con `pdo_pgsql`, `mbstring` y `json`. Para importar el ZIP
  oficial de SNOMED CT conviene tener también `zip` (si falta, descomprimir a mano).
  Para convertir los Excel de NBU/GTIN alcanza con `zlib`, `dom` y `xmlreader`.
- PostgreSQL 18 con la extensión `pg_trgm` (la crea `sql/design.sql`).
- Composer 2.

### 2. Dependencias y entorno

```bash
composer install
cp .env.example .env      # Windows PowerShell: Copy-Item .env.example .env
```

Editá `.env` con las credenciales reales. En producción las variables también pueden inyectarse directamente desde el servidor web o el contenedor; `safeLoad()` no falla si no existe `.env`.

### 3. Base de datos

```bash
createdb -E UTF8 origen_salud
psql -d origen_salud -f sql/design.sql
```

El usuario de la API solo necesita permisos de lectura:

```sql
GRANT CONNECT ON DATABASE origen_salud TO origen_api;
GRANT USAGE ON SCHEMA public TO origen_api;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO origen_api;
```

`sql/design.sql` solo crea el esquema base. El resto de los catálogos
(nomencladores argentinos, PMO, familia DENTAR, LOINC) se cargan en un orden
específico: ver [`sql/README.md`](sql/README.md).

### 4. Crear un cliente B2B

```bash
php -r "echo bin2hex(random_bytes(32)), PHP_EOL;"
```

```sql
INSERT INTO api_clients (institution_name, api_key)
VALUES ('Cliente Demo', 'PEGAR_LA_CLAVE_GENERADA');
```

### 5. Importar SNOMED-CT (RF2)

Hay dos vías. La recomendada para una release completa es la carga masiva con
`COPY`, que replica en PostgreSQL el procedimiento del proyecto
[`snomed_argentina`](https://github.com/luisuriarte/snomed_argentina) para
MariaDB: sólo `Snapshot/`, listas explícitas de columnas, índices recién al
final y publicación en las tablas de la API.

#### 5.1 Carga masiva (recomendada)

```bash
# 1. Esquema de staging sct2 (destructivo sólo para sct2)
psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/01_esquema.sql

# 2. Generar 02_carga.sql desde el ZIP oficial
php tools/php/generar_carga_snomed.php \
    "D:\sct\SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z.zip"

# 3. Cargar los archivos (el servidor los lee desde su disco)
psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/02_carga.sql

# 4. Índices, tablas derivadas, vistas y publicación
psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/03_postcarga.sql

# 5. Opcional: refsets filtrables para la API
psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/04_codigos_opcional.sql

# 6. Opcional: mapeos NBU y GTIN
php tools/php/convertir_excel_maps.php "D:\sct\20260820\Resources"
# 05_map_excel.sql usa \copy: los nombres de los TSV son literales y se
# resuelven contra el directorio actual de psql, así que hay que pararse
# en la carpeta que los contiene (no se pasan -v ruta_nbu / -v ruta_gtin).
cd /ruta/al/20260820/Resources
sudo -u postgres psql -d origen_salud -v ON_ERROR_STOP=1 \
     -f /var/www/html/origen.ar/code-api/tools/sql/snomed/05_map_excel.sql

# 7. Verificación
psql -d origen_salud -f tools/sql/snomed/99_verificacion.sql
```

Si los archivos están en la PC y no en el servidor:

```bash
php tools/php/generar_carga_snomed.php "D:\sct\20260820" --cliente
psql -h servidor -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/02_carga.sql
```

Opciones del generador:

| Opción | Descripción |
| --- | --- |
| `--salida=RUTA` | Archivo `.sql` de salida (default `tools/sql/snomed/02_carga.sql`). |
| `--destino=RUTA` | Carpeta donde extraer el ZIP. |
| `--ruta=RUTA` | Prefijo de ruta que se escribe en los `COPY` (para generar en la PC y ejecutar en el servidor). |
| `--cliente` | Genera `\copy` (psql lee los archivos en la máquina cliente). |
| `--sin-opcionales` | Omite stated, text definitions, identifier, concrete, association, mapas, medicinales y OWL. |
| `--con-stated` | Incluye relaciones declaradas aunque se use `--sin-opcionales`. |
| `--quiet` | Oculta el progreso. |

El generador valida la cabecera RF2 antes de escribir el SQL, descarta `Full/` y
`Delta/`, y falla si hay dos releases mezcladas. El detalle del procedimiento,
permisos, ventana de mantenimiento y problemas frecuentes está en
[`tools/sql/snomed/README.md`](tools/sql/snomed/README.md).

`03_postcarga.sql` deja armados los refsets clínicos argentinos (laboratorio,
vacunas, odontología, prestaciones, imágenes, ENO, dispositivos, especialidades,
profesiones, ocupaciones, Remediar, SUMAR, pueblos originarios y NOMIVAC), las
tablas derivadas de genéricos/marcas del DNM y las vistas de consulta. Después:

- `04_codigos_opcional.sql` publica los refsets filtrables en
  `public.snomed_refset_member` con un `filter_code` estable
  (`LABORATORIO`, `VACUNAS`, `MARCAS`, `ESPECIALIDADES`, etc.). La API los
  expone en `GET /v1/refsets` y en el parámetro `refset` de `/v1/search`.
- `05_map_excel.sql` carga los mapeos NBU y GTIN desde los TSV que genera
  `tools/php/convertir_excel_maps.php` (PHP puro, sin Python ni `ext-zip`). Usa
  `\copy`, que lee los archivos en la máquina donde corre `psql`: hay que
  ejecutarlo parado en la carpeta de los TSV, o descomentar la línea `\cd` del
  script. `\copy` no expande variables de psql, así que no acepta `-v ruta_...`.

#### 5.2 Importador PHP por lotes (alternativa)

Para pruebas, cargas parciales o archivos sueltos. Procesa los `.txt` en
streaming, valida la cabecera y escribe por lotes con `UPSERT`.

```bash
# Orden obligatorio: conceptos -> descripciones -> relaciones
php tools/php/import_snomed_rf2.php ./rf2/sct2_Concept_Full_INT_20240131.txt concept
php tools/php/import_snomed_rf2.php ./rf2/sct2_Description_Full-es_INT_20240131.txt description
php tools/php/import_snomed_rf2.php ./rf2/sct2_Relationship_Full_INT_20240131.txt relationship
```

Opciones útiles:

| Opción | Descripción |
| --- | --- |
| `--batch-size=N` | Filas por transacción (default 2000). |
| `--limit=N` | Procesa solo las primeras N filas (útil para pruebas). |
| `--language=es` | Importa solo descripciones de ese idioma. |
| `--delimiter=,` | Cambia el separador (default: tabulador). |
| `--skip-invalid` | Omite filas inválidas en lugar de abortar el lote. |
| `--dry-run` | Valida y cuenta sin conectarse a PostgreSQL. |
| `--quiet` | Oculta el progreso por lote. |

Cada lote se confirma en su propia transacción: si el proceso se interrumpe, lo
ya importado queda consistente y la corrida se retoma reejecutando el archivo.
Un fallo de clave foránea indica que falta importar el archivo de conceptos.
El detalle de opciones y códigos de salida está en
`php tools/php/import_snomed_rf2.php --help`.

Después de la carga, ejecutar los scripts de `tools/sql/`:

```text
tools/sql/post_import_maintenance.sql   # ANALYZE / VACUUM (con autocommit)
tools/sql/verify_snomed_import.sql      # conteos e integridad
```


### 6. Servidores de desarrollo

```bash
# Portal: http://127.0.0.1:8000
php -S 127.0.0.1:8000 -t web

# API: http://127.0.0.1:8001
php -S 127.0.0.1:8001 -t api api/index.php
```

## API

### Autenticación

Todas las rutas `/v1/*` requieren una API Key activa:

```http
X-API-Key: <clave>
```

o bien:

```http
Authorization: Bearer <clave>
```

### `GET /v1/domains`

Devuelve el catálogo de dominios clínicos soportados y el modo de resolución de cada uno.

```bash
curl 'https://api.origen.ar/v1/domains' \
  --header 'X-API-Key: YOUR_API_KEY'
```

| Dominio | Tabla / fuente | Descripción |
| --- | --- | --- |
| `snomed` | `snomed_*` | Ontología clínica completa. |
| `cie10` | `cie10_*` | Diagnósticos y procedimientos con descripciones ES/EN. |
| `anmat` | `anmat_medicamentos` | Medicamentos, nombre comercial/genérico y laboratorio. |
| `laboratorio` | `laboratorio_practicas` | Prácticas de laboratorio con código LOINC y unidad. |
| `vacunas` | `vacunas_catalogo` | Vacunas e inmunizaciones con código MSAL y esquema. |
| `odontologia` | `odontologia_prestaciones` | Nomenclador odontológico y especificación de cara. |
| `prestaciones` | `prestaciones_medicas` | Nomenclador PMO agrupado por categoría. |
| `programas` | `programas_sociales` | Programas, coberturas y atributos poblacionales. |
| `imagenes` | `imagenes_practicas` | Prácticas de imágenes con modalidad DICOM y LOINC. |

Los catálogos locales exponen `mode: "catalog"` en `/v1/domains`; SNOMED-CT, CIE-10 y ANMAT usan `mode: "full"`. Cada catálogo devuelve en `metadata` su código oficial y, cuando existe, el `snomed_concept_id` y el `snomed_term` vinculado en el idioma solicitado. La tabla operativa `imagenes_estudios_pacs` no forma parte del buscador porque registra estudios de pacientes (PHI), no terminología.

Agregar un catálogo nuevo requiere una sola entrada en `TerminologySearchService::CATALOG_SOURCES`: la proyección, el contrato de respuesta y el enrutador se reutilizan.

### `GET /v1/search`

Búsqueda unificada sobre uno o más dominios. Cada resultado incluye `domain`, `source`, `id`, `code`, `term`, `subtitle`, `language`, `kind`, `score` y `metadata` específica de la fuente. `code` puede ser `null` cuando el catálogo no define un código oficial (por ejemplo, una práctica de laboratorio sin LOINC); en ese caso `id` sigue siendo la clave para el endpoint de detalle.

Los catálogos locales son de Argentina y sus textos están en español (`language: "es"`); el parámetro `lang` aplica a SNOMED-CT, CIE-10 y al término SNOMED vinculado que se devuelve en `metadata`.

| Parámetro | Obligatorio | Descripción |
| --- | --- | --- |
| `q` | Sí | Texto de 2 a 80 caracteres. También acepta códigos CIE-10 (`J18.9`, `J189`) y códigos de catálogo (`LOINC-2345-7`, `NOMIVAC-01`, etc.). |
| `domains` | No | Lista separada por comas o `all`. Default: `snomed,cie10,anmat`. |
| `domain` | No | Alias singular de `domains`. |
| `lang` | No | `es` (default) o `en`. Acepta variantes como `es-AR`. |
| `limit` | No | 1 a 50 (configurable con `API_PAGE_LIMIT_MAX`), default 20. |
| `offset` | No | 0 a 5000, default 0. |
| `cie10_type` | No | `diagnostico` o `procedimiento`; filtra solo la rama CIE-10. |
| `refset` | No | Uno o más `filter_code` separados por coma (máximo 10). Filtra solo la rama SNOMED: el concepto debe pertenecer a alguno de esos refsets. Requiere `snomed` en `domains` y que se haya ejecutado `04_codigos_opcional.sql`. |

```bash
curl --get 'https://api.origen.ar/v1/search' \
  --data-urlencode 'q=infarto' \
  --data 'domains=snomed,cie10,anmat' \
  --data 'lang=es' \
  --data 'limit=10' \
  --header 'X-API-Key: YOUR_API_KEY'
```

Respuesta:

```json
{
  "data": [
    {
      "domain": "snomed",
      "source": "snomed",
      "id": "22298006",
      "code": "22298006",
      "term": "Infarto agudo de miocardio",
      "subtitle": null,
      "language": "es",
      "kind": "synonym",
      "score": 0.9871,
      "metadata": {
        "description_id": "1002",
        "concept_id": "22298006",
        "type_id": "900000000000013009",
        "term_type": "synonym"
      }
    },
    {
      "domain": "cie10",
      "source": "cie10",
      "id": "2",
      "code": "I21.9",
      "term": "Infarto agudo de miocardio, no especificado",
      "subtitle": "diagnostico",
      "language": "es",
      "kind": "diagnosis",
      "score": 0.9,
      "metadata": {
        "cie10_id": "2",
        "code": "I21.9",
        "type": "diagnostico",
        "language": "es"
      }
    }
  ],
  "meta": {
    "query": "infarto",
    "language": "es",
    "domains": ["snomed", "cie10", "anmat"],
    "cie10_type": null,
    "refsets": [],
    "limit": 10,
    "offset": 0,
    "returned": 2,
    "has_more": false,
    "next_offset": null,
    "page_counts": {"snomed": 1, "cie10": 1},
    "took_ms": 12.4
  },
  "request_id": "7f3c9a1e8b2d4f60"
}
```

Variantes útiles:

```bash
# Un solo dominio de catálogo
curl --get 'https://api.origen.ar/v1/search/imagenes' \
  --data-urlencode 'q=tomografía' \
  --header 'X-API-Key: YOUR_API_KEY'

# CIE-10 restringido a procedimientos
curl --get 'https://api.origen.ar/v1/search/cie10' \
  --data-urlencode 'q=ecografía' \
  --data 'cie10_type=procedimiento' \
  --header 'X-API-Key: YOUR_API_KEY'

# Todos los dominios en una sola consulta
curl --get 'https://api.origen.ar/v1/search' \
  --data-urlencode 'q=vacuna' \
  --data 'domains=all' \
  --header 'X-API-Key: YOUR_API_KEY'

# Sólo conceptos de los refsets VACUNAS o NOMIVAC
curl --get 'https://api.origen.ar/v1/search' \
  --data-urlencode 'q=antigripal' \
  --data 'domains=snomed' \
  --data 'refset=VACUNAS,NOMIVAC' \
  --header 'X-API-Key: YOUR_API_KEY'

# Catálogo de refsets disponibles para el filtro
curl 'https://api.origen.ar/v1/refsets' \
  --header 'X-API-Key: YOUR_API_KEY'
```

Resultado de un catálogo local (nótese el vínculo SNOMED ya resuelto en `metadata`):

```json
{
  "domain": "laboratorio",
  "source": "laboratorio",
  "id": "1",
  "code": "LOINC-2345-7",
  "term": "Glucosa en sangre",
  "subtitle": "mg/dL",
  "language": "es",
  "kind": "lab_test",
  "score": 0.92,
  "metadata": {
    "loinc_code": "LOINC-2345-7",
    "unit": "mg/dL",
    "snomed_concept_id": "12345001",
    "snomed_term": "Glucosa en suero"
  }
}
```

> Los dominios son ortogonales: pedir `all` incluye tanto la ontología SNOMED-CT como cada catálogo local, y cada resultado se etiqueta con su `domain`. No hay ramas duplicadas que deduplicar.

### `GET /v1/refsets`

Lista los refsets que el parámetro `refset` acepta, con su categoría y cantidad de miembros publicados. Requiere haber ejecutado `03_postcarga.sql` y `04_codigos_opcional.sql`; si faltan, devuelve `data: []` y `meta.available: false`.

```bash
curl 'https://api.origen.ar/v1/refsets' \
  --header 'X-API-Key: YOUR_API_KEY'
```

```json
{
  "data": [
    {
      "filter_code": "VACUNAS",
      "refset_id": "2281000221106",
      "name": "Inmunizaciones de Argentina",
      "category": "vacunas",
      "description": "Vacunas del calendario nacional",
      "active_members": 42,
      "total_members": 42
    }
  ],
  "meta": {"available": true, "published": true, "count": 24},
  "request_id": "7f3c9a1e8b2d4f60"
}
```

### `GET /v1/snomed/{sctid}`

Detalle de un concepto SNOMED-CT: descripciones agrupadas por idioma, padres e hijos directos (`Is-A`) y códigos CIE-10 mapeados.

```bash
curl 'https://api.origen.ar/v1/snomed/22298006?lang=es' \
  --header 'X-API-Key: YOUR_API_KEY'
```

### `GET /v1/cie10/{codigo}`

Detalle de un código CIE-10 con descripciones bilingües y conceptos SNOMED-CT mapeados. Acepta el código con o sin punto (`J18.9` o `J189`).

```bash
curl 'https://api.origen.ar/v1/cie10/J18.9?lang=es' \
  --header 'X-API-Key: YOUR_API_KEY'
```

### `GET /v1/anmat/{id}`

Detalle de un medicamento ANMAT con su vínculo opcional a SNOMED-CT.

```bash
curl 'https://api.origen.ar/v1/anmat/1?lang=es' \
  --header 'X-API-Key: YOUR_API_KEY'
```

### `GET /v1/{catalogo}/{id}`

Detalle de un registro de los catálogos locales. Devuelve la misma forma que un resultado de búsqueda (sin `score`) más `snomed_concept`, con el término resuelto en el idioma pedido.

Catálogos disponibles: `laboratorio`, `vacunas`, `odontologia`, `prestaciones`, `programas` e `imagenes`.

```bash
curl 'https://api.origen.ar/v1/laboratorio/1?lang=es' \
  --header 'X-API-Key: YOUR_API_KEY'
```

```json
{
  "data": {
    "domain": "laboratorio",
    "source": "laboratorio",
    "id": "1",
    "code": "LOINC-2345-7",
    "term": "Glucosa en sangre",
    "subtitle": "mg/dL",
    "language": "es",
    "kind": "lab_test",
    "metadata": {
      "loinc_code": "LOINC-2345-7",
      "unit": "mg/dL",
      "snomed_concept_id": "12345001",
      "snomed_term": "Glucosa en suero"
    },
    "snomed_concept": {
      "concept_id": "12345001",
      "term": "Glucosa en suero"
    }
  },
  "meta": {
    "language": "es",
    "took_ms": 4.1
  },
  "request_id": "7f3c9a1e8b2d4f60"
}
```

Solo se devuelven registros con `activo = TRUE`; un identificador inactivo o inexistente responde `404 not_found`.

### Alias compatibles

- `GET /v1/concepts/search`: búsqueda SNOMED-CT con el contrato anterior.
- `GET /v1/concepts/{id}`: alias de `/v1/snomed/{id}`.

### `GET /health`

Endpoint público para monitoreo. Verifica la conexión a PostgreSQL.

### Formato de errores

```json
{
  "error": {
    "code": "bad_request",
    "message": "El término de búsqueda debe tener entre 2 y 80 caracteres.",
    "details": {
      "q": "Longitud recibida: 1."
    }
  },
  "request_id": "7f3c9a1e8b2d4f60"
}
```

Códigos usados: `bad_request`, `unauthorized`, `not_found`, `method_not_allowed`, `internal_error`, `service_unavailable`.

### Catálogos, nomencladores y familia DENTAR

Endpoints del Origen Catalog Engine. Requieren los scripts de
[`sql/README.md`](sql/README.md) cargados (`origen_catalog_engine.sql`,
`pmo.sql`, `dentar_family.sql`, `dentar_core_and_diagnosis.sql`); si faltan,
responden `not_found` con la indicación del script a ejecutar.

| Endpoint | Parámetros | Devuelve |
| --- | --- | --- |
| `GET /v1/catalogs` | — | Catálogos publicados (`nn-pmo`, `nbu`, `nhpgd`, `andis`, `dentar-pr`, `dentar-dx`, …) con organización, tipo de dominio y metadatos de familia (`role`, `family`, `short_name`). |
| `GET /v1/catalogs/{code}/releases` | — | Versiones del catálogo con vigencia y estado. |
| `GET /v1/catalogs/{code}/items` | `q`, `category`, `limit` (1-100), `offset` | Ítems publicados con código oficial, término preferido, categoría y arancel vigente. |
| `GET /v1/catalogs/{code}/items/{item}` | — | Detalle de un ítem por código permanente, oficial o término, con `clinical_criteria` y familia. |
| `GET /v1/mappings` | `system`, `code`, `catalog` | Mapeos cruzados (`SNOMED-CT`, `CIE-10`, `CDT-2025`, `LOINC`) con tipo de relación. |
| `GET /v1/pricing-units` | — | Unidades arancelarias (UB, Galeno, Módulo, Sesión, Pesos). |
| `GET /v1/nomenclador` | `type` (`NN_PMO`, `NBU`, `NHPGD`, `ANDIS`, `KINESIOLOGIA`, `SALUD_MENTAL`), `q`, `limit` | Nomencladores argentinos unificados (`nomencladores_argentina`). |
| `GET /v1/vademecum` | `troquel`, `q`, `limit` | Vademécum comercial (Troquel / AlfaBeta / Kairos / GTIN / monodroga). |
| `GET /v1/medicines/identifiers/{system}/{code}` | — | Producto medicinal por identificador (`troquel`, `alfabeta`, `kairos`, `gtin`). |
| `GET /v1/odontologia/diagnosticos` | `q`, `limit` | Diagnósticos DENTAR-DX con CIE-10, SNOMED CT, categoría y criterios clínicos. |
| `GET /v1/odontologia/diagnosticos/{code}` | — | Diagnóstico por código DENTAR-DX (`DNT-DX-NNNNNN`), CIE-10 (`K02`) o SCTID. |
| `GET /v1/odontologia/{code}/diagnosticos` | — | Diagnósticos que justifican una prestación (código DENTAR-PR, nomenclador, CDT o SCTID). |

`GET /v1/catalogs` distingue la marca paraguas (`dentar`, `role: family`) de sus
productos (`dentar-pr` y `dentar-dx`, `role: catalog`, `family: dentar`). Cada
producto publica su propia release y se consulta por separado.

```bash
# Nomenclador bioquímico
curl -s -H "X-API-Key: $KEY" \
  "https://api.origen.ar/v1/nomenclador?type=NBU&q=660475"

# Vademécum por troquel
curl -s -H "X-API-Key: $KEY" \
  "https://api.origen.ar/v1/vademecum?troquel=458921"

# Procedimientos DENTAR-PR con arancel
curl -s -H "X-API-Key: $KEY" \
  "https://api.origen.ar/v1/catalogs/dentar-pr/items?q=endodoncia&limit=10"

# Diagnósticos DENTAR-DX con CIE-10 y SNOMED CT
curl -s -H "X-API-Key: $KEY" \
  "https://api.origen.ar/v1/catalogs/dentar-dx/items?q=caries&limit=10"

# Mapeos de un código a SNOMED CT y CIE-10
curl -s -H "X-API-Key: $KEY" \
  "https://api.origen.ar/v1/mappings?code=D3310"

# Justificación clínica de una prestación odontológica
curl -s -H "X-API-Key: $KEY" \
  "https://api.origen.ar/v1/odontologia/DNT-PR-000007/diagnosticos"
```

La familia DENTAR se carga y versiona desde CSV:
[`docs/dentar/README.md`](docs/dentar/README.md); el importador publica los
cambios de cada producto en el Origen Catalog Engine (`os_*`) en la misma
transacción. El seguimiento de adopción institucional tiene plantilla mensual en
[`docs/adopcion/PLANTILLA_INFORME_MENSUAL.md`](docs/adopcion/PLANTILLA_INFORME_MENSUAL.md).

## i18n

`web/includes/i18n.php` resuelve el idioma en este orden:

1. `?lang=es|en`
2. Cookie `origen_locale` (HttpOnly, SameSite=Lax, 1 año)
3. Header `Accept-Language`
4. `WEB_DEFAULT_LOCALE`

Para agregar un idioma:

1. Sumarlo a `I18n::SUPPORTED`.
2. Crear `web/translations/messages.<locale>.yaml`.
3. Agregar el enlace en el selector de `web/index.php`.

Las claves nuevas se agregan a todos los YAML; si falta una traducción, Symfony usa el fallback `es`.

## Producción

### DocumentRoot

Apuntar cada virtual host a su carpeta, nunca a la raíz del proyecto:

- `api.origen.ar` → `/ruta/proyecto/api`
- `med.origen.ar` → `/ruta/proyecto/web`

### Apache

Los `.htaccess` incluidos bloquean el acceso HTTP a `config/`, `controllers/`, `http/`, `includes/` y `translations/`, y redirigen la API al Front Controller. Requiere `mod_rewrite` y `AllowOverride All`.

### Nginx

```nginx
server {
    listen 443 ssl http2;
    server_name api.origen.ar;
    root /var/www/origen-salud/api;
    index index.php;

    location / {
        try_files $uri /index.php?$query_string;
    }

    location ~ ^/(config|controllers|http)/ {
        deny all;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param HTTP_PROXY "";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
}

server {
    listen 443 ssl http2;
    server_name med.origen.ar;
    root /var/www/origen-salud/web;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ ^/(includes|translations)/ {
        deny all;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param HTTP_PROXY "";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
}
```

### Checklist de seguridad

- **API Keys:** `sql/design.sql` las guarda en texto plano. Antes de producción, migrar a un hash SHA-256 con *pepper* y comparar con `hash_equals()`.
- **Rate limiting:** `api_clients.rate_limit_per_second` ya existe, pero no se aplica en PHP. Aplicarlo en el gateway (Nginx, Kong, Cloudflare) o con Redis; un límite en memoria por proceso no es confiable.
- **HTTPS obligatorio** y HSTS a nivel de servidor.
- **CORS:** definir solo los orígenes reales en `API_CORS_ORIGINS`.
- **Logs:** el Front Controller registra `request_id`, ruta y excepción, pero no el término de búsqueda ni datos clínicos.
- **Base de datos:** usuario de solo lectura, `DB_STATEMENT_TIMEOUT_MS` para cortar consultas costosas y backups verificados.
- **Secretos:** `.env` fuera de Git y con permisos restringidos.
- **Errores:** en producción `APP_DEBUG=false`; el cliente nunca recibe el detalle interno.

### Rendimiento

Los índices GIN con trigramas de `sql/design.sql` cubren `snomed_descriptions.term`, `anmat_medicamentos.nombre_comercial` y `nombre_generico`. Ajustar `DB_TRGM_THRESHOLD` según los datos y validar con:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT ...
```

Para búsquedas sin acentos, evaluar `unaccent` con una función `IMMUTABLE` y un índice de expresión; no se incluye por defecto porque requiere una migración adicional.
