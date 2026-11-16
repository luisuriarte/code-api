# ORIGEN SALUD
# Manual de carga, actualización y mantenimiento de catálogos

**Proyecto:** Origen Salud – API de terminologías y nomencladores sanitarios  
**Repositorio:** `code-api`  
**Base de datos:** PostgreSQL – `origen_salud`  
**Esquema:** `public`  
**Versión del documento:** 1.0  
**Estado:** Procedimiento operativo inicial

---

# 1. Objetivo

Este documento establece el procedimiento para:

1. Instalar inicialmente la estructura de la base de datos.
2. Incorporar los catálogos y terminologías sanitarias.
3. Actualizar los datos cuando se publiquen nuevas versiones.
4. Mantener un historial de versiones y procedencia de los datos.
5. Validar las importaciones antes de publicarlas en la API.
6. Recuperar la información ante una importación incorrecta.

El procedimiento comprende catálogos nacionales, internacionales, odontológicos, nomencladores de prestaciones, terminologías clínicas y datos de medicamentos.

**Principio general:** ningún catálogo debe actualizarse sin identificar su fuente, versión, fecha de publicación, fecha de incorporación y resultado de validación.

# 2. Arquitectura de almacenamiento

## 2.1. Base de datos

| Elemento | Valor |
|---|---|
| Motor | PostgreSQL |
| Base de datos | `origen_salud` |
| Esquema principal | `public` |
| Usuario web | `origen_med` |
| Usuario API | `origen_api` |

Las operaciones de instalación e importación deben realizarse con una cuenta que tenga los permisos necesarios para crear y modificar los objetos correspondientes.

No se debe utilizar automáticamente el usuario de lectura de la API para ejecutar importaciones o cambios estructurales.

## 2.2. Organización del repositorio

La estructura funcional del repositorio es:

```text
code-api/
│
├── api/
├── web/
│
├── sql/
│   ├── 01_schema/
│   ├── 02_catalogs/
│   ├── 03_dentar/
│   ├── 04_pmo/
│   ├── 05_loinc.sql/
│   └── 06_nomencladores/
│
├── tools/
│   └── php/
│       ├── import_dentar_csv.php
│       ├── import_nomenclador_csv.php
│       ├── convertir_excel_maps.php
│       ├── generar_carga_snomed.php
│       ├── Rf2Importer.php
│       ├── ImportOptions.php
│       └── ImportResult.php
│
├── docs/
├── bootstrap.php
├── .env.example
└── composer.json
```

La ubicación `sql/05_loinc.sql/` conserva su nombre actual. Puede normalizarse en una futura reorganización autorizada.

## 2.3. Almacenamiento externo de fuentes

Los archivos originales de terminologías y nomencladores deben conservarse fuera del repositorio Git.

Ubicación propuesta en el VPS:

```text
/opt/origen-salud-data/
│
├── sources/
│   ├── snomed/
│   ├── cie10/
│   ├── loinc/
│   ├── dentar/
│   ├── pmo/
│   ├── nomencladores/
│   ├── anmat/
│   └── medicamentos/
│
├── processed/
│
├── imports/
│
├── backups/
│
└── logs/
```

**Finalidad de los directorios:**

- `sources/`: archivos originales descargados de los organismos o proveedores.
- `processed/`: archivos convertidos, descomprimidos o normalizados.
- `imports/`: archivos preparados para cada ejecución.
- `backups/`: copias de seguridad y respaldos de las fuentes.
- `logs/`: resultados y registros de importación.

No sobrescribir los archivos originales cuando se descarga una nueva versión.

Cada versión debe conservarse en un directorio independiente.

Ejemplo:

```text
sources/snomed/
├── 2025-09/
├── 2026-03/
└── 2026-09/
```

La variable `ORIGEN_DATA_DIR` está declarada en `.env.example`, pero actualmente los importadores identificados no la consumen activamente. Por lo tanto, no debe suponerse que los scripts utilizan automáticamente esta estructura hasta implementar esa integración.

# 3. Catálogos y fuentes de información

Los catálogos se clasifican por naturaleza y finalidad.

| Catálogo | Tipo | Uso |
|---|---|---|
| SNOMED CT | Terminología clínica | Conceptos, descripciones, relaciones y refsets |
| CIE-10 | Clasificación diagnóstica | Diagnósticos y codificación |
| LOINC | Terminología de observaciones | Laboratorio, estudios y observaciones clínicas |
| DENTAR | Catálogo odontológico | Prestaciones, diagnósticos y conceptos odontológicos |
| DENTAR-CDT | Nomenclador odontológico | Códigos de procedimientos odontológicos |
| NN / PMO | Nomenclador sanitario argentino | Prestaciones y cobertura |
| NBU | Nomenclador bioquímico | Prestaciones bioquímicas |
| NHPGD | Nomenclador hospitalario | Prestaciones y gastos hospitalarios |
| ANDIS | Normativa y prestaciones de discapacidad | Coberturas y prestaciones relacionadas |
| Kinesiología | Prestaciones | Procedimientos y prácticas |
| Salud Mental | Prestaciones | Procedimientos y prácticas |
| ANMAT | Información regulatoria | Productos y medicamentos autorizados |
| AlfaBeta / Kairos | Información farmacéutica | Presentaciones, marcas y datos comerciales |

La existencia de un catálogo en esta lista no significa que su importador esté implementado. El estado de cada uno se detalla en la sección 12.

# 4. Instalación inicial de la base de datos

La instalación inicial debe realizarse en un entorno vacío o específicamente preparado para la instalación.

No ejecutar este procedimiento directamente sobre una base de datos productiva que ya contenga información sin revisar previamente el impacto de cada script.

## 4.1. Preparación

Antes de comenzar:

1. Confirmar que PostgreSQL está operativo.
2. Confirmar que existe la base `origen_salud`.
3. Verificar los permisos de la cuenta que realizará la instalación.
4. Verificar la disponibilidad de los archivos SQL.
5. Realizar un respaldo previo si la base contiene información.
6. Registrar la fecha y la versión del repositorio utilizado.

## 4.2. Respaldo inicial

Ejemplo desde el VPS:

```bash
pg_dump -h localhost \
  -U USUARIO_ADMIN \
  -d origen_salud \
  -Fc \
  -f /opt/origen-salud-data/backups/origen_salud_pre_carga.dump
```

El usuario y las credenciales deben corresponder a una cuenta autorizada para realizar el respaldo.

## 4.3. Ejecución del esquema general

Archivo:

```text
sql/01_schema/design.sql
```

Este script establece los componentes generales y extensiones requeridas por el proyecto, incluyendo `pg_trgm` y tipos personalizados.

Ejecutar primero y comprobar que finalice correctamente.

Con `psql`:

```bash
psql -h localhost \
  -U USUARIO_ADMIN \
  -d origen_salud \
  -v ON_ERROR_STOP=1 \
  -f sql/01_schema/design.sql
```

No continuar si se producen errores.

## 4.4. Instalación del motor de catálogos

Archivo:

```text
sql/02_catalogs/origen_catalog_engine.sql
```

Este script implementa el motor central de catálogos y sus estructuras `os_*`.

Ejecutar después del esquema general:

```bash
psql -h localhost \
  -U USUARIO_ADMIN \
  -d origen_salud \
  -v ON_ERROR_STOP=1 \
  -f sql/02_catalogs/origen_catalog_engine.sql
```

Comprobar la creación de las tablas principales:

- `os_catalog`
- `os_catalog_release`
- `os_catalog_item_version`

También verificar las funciones, índices y triggers definidos por el script.

## 4.5. Instalación del catálogo DENTAR

Orden de ejecución:

**Primero:**

```text
sql/03_dentar/dentar_family.sql
```

**Segundo:**

```text
sql/03_dentar/dentar_core_and_diagnosis.sql
```

El primer script registra la familia y sus estructuras relacionadas.

El segundo incorpora el núcleo editorial, versiones, diagnósticos y datos iniciales.

La nomenclatura `dentar` y `dantar` debe conservarse tal como está definida en los scripts actuales hasta que exista una normalización formal.

## 4.6. Sincronización DENTAR con el motor central

Archivo:

```text
sql/03_dentar/sync_dentar_to_os.sql
```

Este script sincroniza los elementos DENTAR con las estructuras del motor `os_*`.

Debe ejecutarse únicamente después de instalar el motor central y las estructuras DENTAR.

El importador DENTAR puede realizar esta sincronización automáticamente. No ejecutar manualmente la sincronización si el importador ya la realizó para esa misma carga, salvo que se esté realizando una resincronización deliberada.

## 4.7. Instalación de otros catálogos

Los scripts identificados como independientes pueden incorporarse después de la estructura general.

### LOINC

Directorio:

```text
sql/05_loinc.sql/
```

Archivos:

```text
importar_loinc.sql
cargar_loinc_consumer_names.sql
```

El procedimiento específico está desarrollado en la sección 7.

### Nomencladores argentinos

Archivo:

```text
sql/06_nomencladores/nomencladores_argentina.sql
```

Este script debe revisarse para determinar exactamente qué tablas crea y qué datos incorpora antes de ejecutarlo en producción.

### PMO

Directorio:

```text
sql/04_pmo/
```

Actualmente está vacío y reservado para desarrollo futuro.

No ejecutar ni considerar este directorio como una etapa obligatoria de instalación.

# 5. Procedimiento general de actualización de catálogos

Todas las actualizaciones deben seguir un ciclo controlado.

## 5.1. Identificar una nueva versión

Registrar:

- Nombre del catálogo.
- Organismo o proveedor de origen.
- Identificador de versión.
- Fecha de publicación.
- Fecha de descarga.
- URL o referencia documental.
- Licencia y condiciones de uso.
- Formato original.
- Hash SHA-256 del archivo original.

## 5.2. Conservar la versión anterior

Nunca reemplazar directamente el archivo de una versión anterior.

Ejemplo:

```text
sources/loinc/
├── 2.78/
├── 2.80/
└── 2.83/
```

Esto permite recuperar la fuente original y comparar diferencias.

## 5.3. Preparar los archivos

Cuando sea necesario:

- Descomprimir.
- Convertir formatos.
- Validar codificación UTF-8.
- Comprobar delimitadores.
- Validar columnas.
- Comprobar cantidad de registros.
- Identificar duplicados.
- Identificar códigos inexistentes o inválidos.

## 5.4. Ejecutar una importación de prueba

Siempre que el importador lo permita, utilizar su modalidad de simulación.

No publicar una versión nueva hasta que se hayan comprobado los resultados.

## 5.5. Ejecutar la importación definitiva

La importación debe registrar:

- Catálogo.
- Versión.
- Fuente.
- Fecha.
- Cantidad de registros leídos.
- Cantidad de registros incorporados.
- Cantidad de registros modificados.
- Cantidad de registros rechazados.
- Resultado final.

## 5.6. Validar y publicar

Antes de habilitar los datos en la API:

1. Verificar integridad.
2. Comparar cantidades con la fuente.
3. Revisar duplicados.
4. Verificar códigos y descripciones.
5. Comprobar relaciones y mapeos.
6. Realizar pruebas de búsqueda.
7. Confirmar la versión activa.

La publicación debe ser una operación controlada, separada de la carga de datos cuando el motor de catálogos lo permita.

# 6. SNOMED CT

## 6.1. Fuente

SNOMED CT se distribuye en formato RF2.

Los archivos pueden contener:

- Conceptos.
- Descripciones.
- Relaciones.
- Refsets.
- Información de versiones.
- Datos de lenguaje.

Se debe utilizar una distribución autorizada y respetar las condiciones de licencia correspondientes al territorio y al uso previsto.

## 6.2. Preparación de archivos

Conservar la distribución original sin modificar.

Ejemplo:

```text
sources/snomed/2026-09/
├── Full/
├── Snapshot/
├── Delta/
└── manifest.txt
```

La estructura exacta dependerá de la distribución recibida.

## 6.3. Importador

Herramientas identificadas:

```text
tools/php/generar_carga_snomed.php
tools/php/Rf2Importer.php
```

Antes de ejecutar:

```bash
php tools/php/generar_carga_snomed.php --help
```

Consultar también las opciones de `Rf2Importer.php` y los requisitos del importador.

Se han identificado parámetros como:

```text
--cliente
--desde
--sin-refsets
```

La sintaxis completa y el significado de cada parámetro deben confirmarse con la ayuda del código vigente.

## 6.4. Actualizaciones

Para una actualización RF2:

- Identificar si se trata de una carga completa, Snapshot o Delta.
- Verificar la versión de origen.
- Confirmar la versión anterior instalada.
- Aplicar el procedimiento soportado por el importador.
- Validar conceptos, descripciones, relaciones y refsets.
- Registrar el resultado.

No importar un Delta como si fuera una distribución completa.

No mezclar componentes de distintas versiones sin un procedimiento de actualización compatible.

# 7. LOINC

## 7.1. Fuentes

LOINC puede incluir:

- Archivo principal `Loinc.csv`.
- Traducciones.
- Consumer Names.
- Otros archivos complementarios de la distribución.

Se debe conservar la distribución original y su versión.

## 7.2. Importación inicial

Script principal:

```text
sql/05_loinc.sql/importar_loinc.sql
```

Este script corresponde a la carga maestra de LOINC.

Según la auditoría, incorpora la tabla `loinc`, `loinc_map` y archivos de la distribución LOINC.

**Advertencia crítica:** contiene:

```sql
DROP TABLE IF EXISTS loinc CASCADE;
```

Esto puede eliminar la tabla existente y los objetos dependientes.

Por lo tanto:

- No ejecutarlo como actualización rutinaria.
- No ejecutarlo sobre producción sin respaldo.
- Revisar previamente todas las dependencias.
- Utilizarlo para una instalación inicial o una reconstrucción expresamente autorizada.

La ruta de los archivos de origen y las variables de ejecución deben comprobarse en el propio script.

Además, si utiliza comandos especiales de `psql`, debe ejecutarse con `psql` y no suponerse que DBeaver interpretará correctamente todas sus instrucciones.

## 7.3. Consumer Names

Script complementario:

```text
sql/05_loinc.sql/cargar_loinc_consumer_names.sql
```

Actualiza el campo `consumer_name` de la tabla `loinc` existente y crea un índice GIN trigram.

Debe ejecutarse después de la carga principal y cuando corresponda a la versión de LOINC instalada.

No reemplaza la importación maestra.

## 7.4. Actualización de LOINC

Antes de actualizar:

1. Descargar una nueva distribución.
2. Conservar la versión anterior.
3. Comparar la versión instalada con la nueva.
4. Respaldar la tabla y sus dependencias.
5. Revisar el impacto de la estrategia de actualización.
6. Ejecutar el procedimiento de actualización aprobado.
7. Validar cantidades, códigos y descripciones.

La estrategia de actualización incremental debe implementarse y probarse antes de considerarla disponible. El script de carga maestra actual no debe tratarse como un actualizador incremental.

# 8. DENTAR y catálogo odontológico

## 8.1. Componentes

DENTAR contempla:

- Familia de catálogo.
- Conceptos.
- Categorías.
- Diagnósticos.
- Versiones.
- Términos.
- Mapeos.
- Procedimientos odontológicos.

También deben considerarse los códigos CDT y las correspondencias con SNOMED CT y CIE-10.

## 8.2. Importador

Archivo:

```text
tools/php/import_dentar_csv.php
```

El importador admite, según la implementación auditada:

```text
--dry-run
--version=N
--sin-sync
```

Consultar siempre la ayuda del importador:

```bash
php tools/php/import_dentar_csv.php --help
```

La ruta de sincronización del importador apunta a:

```text
sql/03_dentar/sync_dentar_to_os.sql
```

## 8.3. Primera carga

Secuencia:

1. Instalar el motor central.
2. Ejecutar `dentar_family.sql`.
3. Ejecutar `dantar_core_and_diagnosis.sql`.
4. Preparar el CSV.
5. Ejecutar la validación o simulación disponible.
6. Corregir errores.
7. Realizar la importación.
8. Verificar la sincronización con `os_*`.
9. Probar búsquedas en la API.

## 8.4. Actualización

Toda nueva versión debe tener un identificador propio.

Ejemplo:

```text
DENTAR 1.0
DENTAR 1.1
DENTAR 1.2
```

No sobrescribir versiones anteriores sin una política de versionado explícita.

Los cambios deben distinguir:

- Conceptos nuevos.
- Conceptos modificados.
- Conceptos retirados.
- Cambios de descripción.
- Cambios de categoría.
- Cambios de diagnóstico.
- Cambios de mapeo.

Los mapeos con SNOMED CT y CIE-10 deben conservar su trazabilidad y estado de validación.

# 9. CIE-10

## 9.1. Fuente y alcance

CIE-10 debe manejarse como una clasificación diagnóstica independiente.

No debe confundirse con SNOMED CT:

- CIE-10 clasifica diagnósticos.
- SNOMED CT representa conceptos clínicos con mayor granularidad y relaciones semánticas.

## 9.2. Carga

Antes de implementar una importación, identificar:

- Fuente oficial.
- Edición.
- Idioma.
- Adaptación nacional, si corresponde.
- Formato.
- Licencia.
- Estructura de códigos y jerarquías.

El procedimiento de carga debe contemplar:

- Código.
- Descripción.
- Categoría.
- Jerarquía.
- Vigencia.
- Versión.
- Fuente.

**Estado:** el importador específico de CIE-10 no está confirmado en el inventario actual del repositorio. No se debe utilizar un importador de SNOMED o DENTAR para cargar CIE-10 sin una adaptación específica.

# 10. Nomencladores argentinos

## 10.1. Catálogos contemplados

El proyecto contempla incorporar:

- NN / PMO.
- NBU.
- NHPGD.
- ANDIS.
- Kinesiología.
- Salud Mental.
- Prestaciones odontológicas.

No todos representan el mismo tipo de información.

Es necesario diferenciar:

- Prestaciones.
- Clasificaciones.
- Normativas.
- Aranceles.
- Condiciones de cobertura.
- Reglas de autorización.

No deben combinarse todos estos conceptos en una única tabla sin conservar su naturaleza y procedencia.

## 10.2. Importador de nomencladores

Archivo:

```text
tools/php/import_nomenclador_csv.php
```

Consultar las opciones disponibles:

```bash
php tools/php/import_nomenclador_csv.php --help
```

El importador admite configuración por parámetros y una ruta de entrada opcional, según la auditoría.

La sintaxis exacta debe obtenerse del código actual antes de ejecutar la importación.

## 10.3. Conversión de Excel

Herramienta identificada:

```text
tools/php/convertir_excel_maps.php
```

Se utiliza para convertir archivos Excel a un formato de intercambio, como TSV, cuando el procedimiento del catálogo lo requiere.

La ubicación de trabajo y los parámetros deben confirmarse antes de utilizarla.

## 10.4. Actualización de nomencladores

Para cada actualización:

1. Descargar el archivo oficial o autorizado.
2. Registrar organismo y resolución.
3. Registrar vigencia desde y hasta.
4. Conservar el archivo original.
5. Convertir al formato esperado.
6. Validar códigos y descripciones.
7. Comparar contra la versión anterior.
8. Identificar altas, modificaciones y bajas.
9. Importar la nueva versión.
10. Verificar que los aranceles y las reglas de cobertura no se hayan mezclado con la descripción del procedimiento.

## 10.5. Aranceles

Un código de prestación no equivale necesariamente a un precio.

Se deben separar:

- Código de prestación.
- Unidad de valoración.
- Valor unitario.
- Moneda.
- Fecha de vigencia.
- Financiador.
- Fuente del valor.

Una actualización de aranceles no debería requerir modificar la identidad del código de prestación.

# 11. ANMAT y medicamentos

## 11.1. Información regulatoria

ANMAT debe tratarse como fuente regulatoria.

Es necesario distinguir:

- Productos autorizados.
- Principios activos.
- Presentaciones.
- Titulares.
- Laboratorios.
- Registros.
- Estado regulatorio.

## 11.2. Fuentes comerciales

AlfaBeta y Kairos pueden aportar información farmacéutica y comercial complementaria.

No deben considerarse automáticamente fuentes regulatorias oficiales.

La información comercial debe conservar:

- Proveedor.
- Versión.
- Fecha de actualización.
- Condiciones de licencia.
- Identificador original.
- Correspondencia con el registro regulatorio, cuando exista.

**Estado:** no se ha confirmado en el inventario actual un importador operativo de ANMAT, AlfaBeta o Kairos. Su incorporación requiere un procedimiento específico y verificar las condiciones de uso y redistribución.

# 12. Estado de implementación de los importadores

Esta tabla distingue las herramientas identificadas de las cargas que aún necesitan desarrollo o verificación.

| Catálogo / herramienta | Estado según auditoría |
|---|---|
| Motor central `os_*` | SQL identificado |
| DENTAR | SQL e importador PHP identificados |
| SNOMED CT RF2 | Importador PHP identificado |
| LOINC | SQL de carga maestra identificado |
| Consumer Names LOINC | SQL complementario identificado |
| Nomencladores argentinos | SQL e importador PHP identificados |
| Conversión Excel | Herramienta PHP identificada |
| CIE-10 | Importador específico no confirmado |
| PMO | Directorio SQL vacío |
| NBU | Carga específica no confirmada |
| NHPGD | Carga específica no confirmada |
| ANDIS | Carga específica no confirmada |
| Kinesiología | Carga específica no confirmada |
| Salud Mental | Carga específica no confirmada |
| ANMAT | Importador no confirmado |
| AlfaBeta / Kairos | Importador no confirmado |

La presencia de un archivo SQL o una herramienta PHP no garantiza que el procedimiento haya sido validado contra una base PostgreSQL real.

# 13. Validaciones posteriores a cada importación

Toda carga debe superar las siguientes comprobaciones.

## 13.1. Integridad

- No existen códigos duplicados dentro de la misma versión cuando no están permitidos.
- No existen códigos vacíos.
- No existen descripciones vacías.
- Las referencias entre tablas son válidas.
- Las relaciones jerárquicas no contienen referencias inexistentes.
- Las versiones están correctamente identificadas.

## 13.2. Comparación de registros

Registrar como mínimo:

| Indicador | Descripción |
|---|---|
| Total fuente | Registros del archivo original |
| Total procesado | Registros leídos por el importador |
| Nuevos | Registros incorporados |
| Modificados | Registros actualizados |
| Sin cambios | Registros idénticos |
| Rechazados | Registros con errores |
| Total final | Registros disponibles en la base |

Las diferencias deben quedar justificadas.

## 13.3. Pruebas API

Después de la importación:

- Comprobar que el catálogo aparece en los listados.
- Consultar su versión.
- Buscar códigos conocidos.
- Buscar descripciones.
- Comprobar paginación.
- Verificar filtros.
- Verificar mapeos.
- Comprobar que la versión publicada es la esperada.

La publicación de una nueva versión no debe realizarse si las búsquedas o los listados presentan errores.

# 14. Respaldo y recuperación

Antes de una actualización importante, realizar un respaldo.

Ejemplo:

```bash
pg_dump -h localhost \
  -U USUARIO_ADMIN \
  -d origen_salud \
  -Fc \
  -f /opt/origen-salud-data/backups/origen_salud_ANTES_ACTUALIZACION.dump
```

Para restaurar un respaldo completo en una base preparada:

```bash
pg_restore \
  -h localhost \
  -U USUARIO_ADMIN \
  -d origen_salud \
  --clean \
  --if-exists \
  /opt/origen-salud-data/backups/origen_salud_ANTES_ACTUALIZACION.dump
```

**Atención:** la restauración con `--clean` elimina los objetos que correspondan antes de recrearlos. Debe utilizarse únicamente con autorización, sobre la base correcta y después de verificar el respaldo.

La recuperación debe probarse previamente en un entorno de pruebas.

# 15. Registro de importaciones

Se recomienda mantener un registro histórico de cada operación.

Campos sugeridos:

| Campo | Descripción |
|---|---|
| catalog_code | Identificador del catálogo |
| release_version | Versión incorporada |
| source_name | Organismo o proveedor |
| source_file | Archivo original |
| source_sha256 | Hash SHA-256 |
| publication_date | Fecha de publicación |
| import_date | Fecha de importación |
| imported_by | Responsable |
| records_read | Registros leídos |
| records_inserted | Registros nuevos |
| records_updated | Registros modificados |
| records_rejected | Registros rechazados |
| status | Resultado |
| notes | Observaciones |

El registro debe permitir reconstruir qué versión estaba instalada en una fecha determinada.

# 16. Frecuencia de actualización

La frecuencia depende del organismo de origen y de la publicación de nuevas versiones.

| Catálogo | Seguimiento recomendado |
|---|---|
| SNOMED CT | En cada nueva publicación oficial |
| CIE-10 | Según nuevas ediciones o adaptaciones oficiales |
| LOINC | En cada nueva versión oficial |
| DENTAR | Cuando se aprueben modificaciones del catálogo |
| NN / PMO | Ante nuevas resoluciones o modificaciones |
| NBU | Ante nuevas publicaciones de CUBRA |
| NHPGD | Según publicaciones oficiales |
| ANDIS | Ante modificaciones normativas |
| Kinesiología | Según actualizaciones de los nomencladores aplicables |
| Salud Mental | Según actualizaciones de los nomencladores aplicables |
| ANMAT | Según disponibilidad y periodicidad de la fuente |
| AlfaBeta / Kairos | Según actualización y licencia del proveedor |

La descarga de una nueva fuente no implica automáticamente su publicación en producción.

# 17. Reglas operativas obligatorias

1. No modificar manualmente los datos originales importados sin dejar trazabilidad.
2. No sobrescribir las fuentes originales.
3. No mezclar versiones de distintos catálogos.
4. No eliminar versiones históricas sin una política de retención.
5. No publicar una versión sin validación.
6. No ejecutar scripts destructivos sin respaldo.
7. No ejecutar importaciones directamente en producción durante las pruebas.
8. No confundir código clínico, prestación, arancel y medicamento.
9. No publicar datos sujetos a licencias sin verificar sus condiciones.
10. Registrar siempre quién realizó la carga y cuándo.

# 18. Procedimiento resumido de operación

## Primera instalación

1. Preparar PostgreSQL.
2. Crear o verificar `origen_salud`.
3. Ejecutar `01_schema/design.sql`.
4. Ejecutar `02_catalogs/origen_catalog_engine.sql`.
5. Ejecutar `03_dentar/dentar_family.sql`.
6. Ejecutar `03_dentar/dantar_core_and_diagnosis.sql`.
7. Ejecutar la sincronización DENTAR cuando corresponda.
8. Incorporar LOINC y nomencladores según sus procedimientos específicos.
9. Incorporar SNOMED CT mediante su importador.
10. Validar datos.
11. Probar la API.
12. Registrar las versiones instaladas.

## Actualización periódica

1. Detectar nueva versión.
2. Descargar y conservar la fuente original.
3. Calcular SHA-256.
4. Identificar la versión actualmente instalada.
5. Preparar y validar los archivos.
6. Realizar respaldo.
7. Ejecutar importación de prueba.
8. Revisar diferencias y errores.
9. Ejecutar importación definitiva.
10. Validar integridad y búsquedas.
11. Publicar la versión.
12. Registrar el resultado.

---

# 19. Pendientes para completar el procedimiento operativo

Antes de considerar este manual una guía ejecutable de extremo a extremo, se deben completar estas tareas:

- Documentar los parámetros exactos de cada importador PHP.
- Confirmar el formato y las rutas esperadas de los archivos de origen.
- Verificar la carga completa de SNOMED CT y sus actualizaciones RF2.
- Definir un procedimiento incremental para LOINC que no requiera eliminar la tabla existente.
- Confirmar el procedimiento de actualización de DENTAR.
- Confirmar qué catálogos argentinos están efectivamente implementados.
- Desarrollar los importadores específicos que falten.
- Integrar `ORIGEN_DATA_DIR` con los importadores que deban utilizar fuentes externas.
- Verificar la gestión de versiones y publicación en el motor `os_*`.
- Probar todos los procedimientos en una base PostgreSQL de desarrollo antes de utilizarlos en producción.

**Criterio de finalización:** cada catálogo debe disponer de un procedimiento documentado de instalación, actualización, validación y recuperación, con fuente identificada y versión trazable.

---

**Origen Salud – Gestión centralizada de terminologías, catálogos y nomencladores sanitarios.**