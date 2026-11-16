# REORGANIZACIÓN INTEGRAL ORIGEN SALUD - FASE 2: PLAN DE MIGRACIÓN

## OBJETIVO
Diseñar la nueva arquitectura de directorios y reorganizar los archivos existentes preservando toda la funcionalidad actual. Esta fase identifica cada archivo, determina su nueva ubicación y documenta las referencias que deben actualizarse.

---

## ELEMENTOS CLAVE DEL PLAN

### A. Inventario de Archivos Identificado

Según la auditoría (FASE 1), el proyecto contiene los siguientes grupos de archivos:

#### 1. Archivos SQL (`sql/`):
- `origen_catalog_engine.sql` - Motor canonical
- `pmo.sql` - Programa Médico Obligatorio
- `dentar_family.sql` - Familia DENTAR
- `dentar_core_and_diagnosis.sql` - Núcleo DENTAR
- `sync_dentar_to_os.sql` - Sincronización DENTAR→os_*
- `05_map_excel.sql` - NBU/GTIN loader
- `nomencladores_argentina.sql` - Legacy
- `Argentina_dental_cdt_codes_2025.sql` - CDT 2025
- `importar_loinc.sql` - LOINC

#### 2. Scripts PHP (`tools/php/`):
- `import_dentar_csv.php` - Importador DENTAR
- `convertir_excel_maps.php` - XLSX a TSV
- `import_nomenclador_csv.php` - Nomencladores argentinos
- `generar_carga_snomed.php` - RF2 ZIP loader
- `Rf2Importer.php` - Motor RF2
- `ImportOptions.php`, `ImportResult.php`

#### 3. Servicios API (`api/services/`):
- `CatalogEngineService.php`
- `TerminologySearchService.php`

#### 3. Documentación (`docs/`):
- `docs/dentar/README.md` - Familia DENTAR
- `docs/dentar/plantilla-dentar-pr.csv` - Plantilla PR
- `docs/dentar/plantilla-dentar-dx.csv` - Plantilla DX
- `docs/adopcion/PLANTILLA_INFORME_MENSUAL.md` - Informe mensual
- `docs/adopcion/README.md` - Guía adopción
- `sql/README.md` - Orden de carga
- `README.md` - Estructura general
- `README-API.md` - Ejemplos API

#### 4. Otros Archivos:
- `web/docs.php` - Documentación pública
- `.env.example`, `composer.json`, `bootstrap.php`

---

### B. Nueva Arquitectura de Directorios (Propuesta)

Basado en las reglas definidas, la nueva estructura será:

```
code-api/
├── sql/                          # SQL source of truth (estructura + ETL)
│   ├── 01_schema/                # Definiciones estructurales (CREATE TABLE, indexes)
│   ├── 02_catalogs/              # Catálogos y motor os_*
│   ├── 03_dentar/                # Scripts DENTAR específicos
│   ├── 04_pmo.sql                # PMO
│   ├── 05_loinc.sql              # LOINC
│   ├── 06_nomencladores/         # Nomencladores argentinos
│   └── README.md                 # Orden de carga
│
├── tools/                        # Herramientas de proceso
│   ├── php/                      # Importadores y conversores PHP
│   │   ├── importers/            # importadores por catálogo
│   │   ├── converters/           # Conversores de formato
│   │   ├── validators/           # Validadores de datos
│   │   └── common/               # Funciones PHP compartidas
│   ├── sh/                       # Scripts shell (sincronización, backups)
│   └── README.md
│
├── api/                        # Servicios API
│   ├── services/                 # Catálogo y búsqueda de terminología
│   ├── routes/                   # Definición de endpoints
│   └── index.php
│
├── docs/                       # Documentación técnica
│   ├── architecture/             # Arquitectura del sistema
│   ├── database/                # Arquitectura y migraciones DB
│   ├── imports/                 # Procesos ETL
│   ├── catalogs/                # Documentación de catálogos
│   ├── deployment/              # Despliegue VPS/Nginx
│   └── README.md
│
├── tests/                      # Pruebas (sintaxis, rutas, validaciones)
│   ├── api/                      # Tests de endpoints
│   ├── database/                 # Validación de esquemas
│   └── tools/                    # Tests de importadores
│
├── config/                     # Configuración centralizada
│   └── README.md
│
├── database/                   # Scripts SQL clasificados por función
│   ├── schema/                   # CREATE TABLE, indexes, triggers
│   ├── migrations/               # Migraciones incrementales documentadas
│   ├── staging/                  # Datos intermedios de staging
│   ├── catalogs/                 # Datos de referencia pequeños
│   ├── imports/                  # Scripts ETL por catálogo
│   │   ├── dentar/
│   │   │   ├── 01_load.sql
│   │   │   ├── 02_normalize.sql
│   │   │   ├── 03_validate.sql
│   │   │   ├── 04_publish.sql
│   │   │   └── 99_verify.sql
│   │   ├── snomed/
│   │   │   ├── 01_load.sql
│   │   │   ├── 02_transform.sql
│   │   │   ├── 03_validate.sql
│   │   │   └── 99_verify.sql
│   │   └── README.md
│   ├── staging/                  # Tablas intermedias
│   ├── maintenance/              # ANALYZE, VACUUM, índices
│   └── README.md
│
├── database/                   # Scripts SQL de bajo nivel (no versionados automáticamente)
│   └── README.md
│
├── tools/                      # Directorio legacy (mover o depurar)
│   └── README.md
│
├── config/                     # Configuración centralizada (.env, composer, etc.)
│   └── README.md
│
├── bootstrap.php
├── composer.json
├── composer.lock
├── .env.example
├── .gitignore
├── README.md
├── README-API.md
└── README-FHIR.md
```

---

### C. Clasificación de Archivos y Nueva Ubicación

#### 1. ARCHIVOS SQL - CLASIFICACIÓN Y REUBICACIÓN

##### A. `sql/origen_catalog_engine.sql`
- **Función**: Motor canonical de catálogos, nomencladores, aranceles y vademécum (`os_*`)
- **Nueva ubicación**: `sql/02_catalogs/`
- **Referencias afectadas**: Ninguna (es el motor base)
- **Acción**: Mover y mantener como fuente de verdad

##### B. `sql/pmo.sql`
- **Función**: Programa Médico Obligatorio
- **Nueva ubicación**: `sql/04_pmo.sql`
- **Referencias afectadas**: `origen_catalog_engine.sql` lo llama implícitamente
- **Acción**: Mover y mantener orden después del engine

##### C. `sql/dentar_family.sql`
- **Función**: Registro familia DENTAR, migración de códigos, trigger `dentar_assert_catalog_code()`
- **Nueva ubicación**: `sql/03_dentar/`
- **Referencias afectadas**: `dentar_core_and_diagnosis.sql` lo requiere
- **Acción**: Mover antes de `dentar_core_and_diagnosis.sql`

##### D. `sql/dentar_core_and_diagnosis.sql`
- **Función**: Núcleo editorial DENTAR-PR y DENTAR-DX, seeds, versiones, mapeos
- **Nueva ubicación**: `sql/03_dentar/`
- **Referencias afectadas**: `dentar_family.sql` lo requiere; `sync_dentar_to_os.sql` lo usa
- **Acción**: Mover después de `dentar_family.sql`

##### E. `sql/sync_dentar_to_os.sql`
- **Función**: Sincroniza `dentar_*` → `os_*` (PR y DX independientes)
- **Nueva ubicación**: `sql/03_dentar/` o `sql/02_catalogs/`
- **Referencias afectadas**: `import_dentar_csv.php` lo ejecuta al final
- **Acción**: Mover junto con los scripts DENTAR

##### F. `sql/05_map_excel.sql`
- **Función**: Cargador NBU/GTIN con fallback TSV
- **Nueva ubicación**: `sql/02_catalogs/` o mantenimiento
- **Referencias afectadas**: `tools/sql/snomed/05_map_excel.sql`
- **Acción**: Mantener por compatibilidad, documentar

##### F. `sql/nomencladores_argentina.sql`
- **Función**: Legacy (subconjunto del engine)
- **Nueva ubicación**: `sql/06_nomencladores/` o depuración
- **Referencias afectadas**: `design.sql` lo creó
- **Acción**: Evaluar si mantener o depurar

##### F. `sql/Argentina_dental_cdt_codes_2025.sql`
- **Función**: CDT 2025 y nomenclador odontológico
- **Nueva ubicación**: `sql/03_dentar/` o `sql/catalogs/`
- **Referencias afectadas**: `dentar_core_and_diagnosis.sql` lo usa
- **Acción**: Mover con los scripts DENTAR

##### F. `sql/importar_loinc.sql`
- **Función**: Carga LOINC
- **Nueva ubicación**: `sql/06_loinc.sql` o `sql/loinc/`
- **Referencias afectadas**: Ninguna crítica
- **Acción**: Mover a sección de catálogos

#### 2. SCRIPTS PHP (`tools/php/`) - CLASIFICACIÓN

##### A. `tools/php/import_dentar_csv.php`
- **Función**: Importador masivo DENTAR-PR y DENTAR-DX, valida, sincroniza `os_*`
- **Nueva ubicación**: `tools/php/importers/dentar/`
- **Referencias afectadas**: `sql/sync_dentar_to_os.sql`, `sql/dentar_family.sql`, `sql/dentar_core_and_diagnosis.sql`
- **Acción**: Mover y actualizar rutas internas

##### B. `tools/php/convertir_excel_maps.php`
- **Función**: Convierte XLSX a TSV para NBU/GTIN
- **Nueva ubicación**: `tools/php/converters/`
- **Referencias afectadas**: `tools/sql/snomed/05_map_excel.sql`
- **Acción**: Mover a conversores

##### C. `tools/php/import_nomenclador_csv.php`
- **Función**: Importador nomencladores argentinos (NBU, PMO, etc.)
- **Nueva ubicación**: `tools/php/importers/nomencladores/`
- **Referencias afectadas**: Ninguna crítica
- **Acción**: Mover a importers

##### D. `tools/php/generar_carga_snomed.php`
- **Función**: Genera `02_carga.sql` desde ZIP RF2
- **Nueva ubicación**: `tools/php/importers/snomed/`
- **Referencias afectadas**: Estructura RF2
- **Acción**: Mover a importers/snomed

##### E. `tools/php/Rf2Importer.php`
- **Motor RF2 streaming**
- **Nueva ubicación**: `tools/php/importers/snomed/`
- **Acción**: Mover con el importador SNOMED

##### F. `tools/php/ImportOptions.php`, `ImportResult.php`
- **Opciones y resultados del importador**
- **Nueva ubicación**: `tools/php/common/`
- **Acción**: Mover a common

#### 3. SERVICIOS API (`api/services/`) - Mantener o Mover

##### A. `api/services/CatalogEngineService.php`
- **Función**: `/v1/catalogs`, metadatos familia, `getItem`, `clinical_criteria`
- **Nueva ubicación**: `api/services/` (mantener, es el core API)
- **Acción**: Mantener en ubicación actual (es núcleo de la API)

##### B. `api/services/TerminologySearchService.php`
- **Función**: Búsqueda detalle/por-SNOMED, diagnósticos, procedures
- **Nueva ubicación**: `api/services/` (mantener)
- **Acción**: Mantener en ubicación actual

#### 3. DOCUMENTACIÓN (`docs/`) - REORGANIZACIÓN

##### A. `docs/dentar/README.md`
- **Función**: Familia DENTAR, formato CSV, plantillas, load order, verification
- **Nueva ubicación**: `docs/catalogs/dentar/` o mantener `docs/dentar/`
- **Acción**: Mantener con mejora de contenido

##### B. `docs/dentar/plantilla-dentar-pr.csv` / `plantilla-dentar-dx.csv`
- **Función**: Plantillas de importación de prueba
- **Nueva ubicación**: `docs/catalogs/dentar/plantillas/`
- **Acción**: Mover con documentación

##### C. `docs/adopcion/PLANTILLA_INFORME_MENSUAL.md` / `README.md`
- **Función**: Informe mensual de adopción
- **Nueva ubicación**: `docs/adopción/` (mantener estructura)
- **Acción**: Mantener

##### C. `sql/README.md`
- **Función**: Orden de carga SQL
- **Nueva ubicación**: `sql/README.md` (mantener en sql/)
- **Acción**: Actualizar contenido con nueva estructura

##### D. `README.md` / `README-API.md`
- **Función**: Documentación general y de API
- **Nueva ubicación**: Raíz del proyecto (mantener)
- **Acción**: Mantener, actualizar referencias a nueva estructura

#### 4. ARCHIVOS DE CONFIGURACIÓN

##### A. `config/` - Crear nuevo
- **Función**: `.env.example`, configuración centralizada de rutas
- **Nueva ubicación**: `config/`
- **Acción**: Crear y migrar rutas absolutas a variables de entorno

##### B. `bootstrap.php`
- **Función**: Autoload, .env, errores y helpers globales
- **Nueva ubicación**: Raíz del proyecto (mantener)

##### C. `composer.json` / `composer.lock`
- **Función**: Dependencias PHP
- **Nueva ubicación**: Raíz (mantener)

##### C. `.env.example`, `.gitignore`
- **Nueva ubicación**: Raíz (mantener)

#### 5. ESTRUCTURA DE DIRECTORIO `database/`

Según las reglas definidas, los scripts SQL deben clasificarse en:

- `database/schema/`: Definiciones estructurales puas
- `database/migrations/`: Migraciones incrementales
- `database/staging/`: Tablas intermedias
- `database/catalogs/`: Datos de referencia pequeños
- `database/imports/`: Scripts ETL por catálogo
- `database/maintenance/`: ANALYZE, VACUUM, índices
- `database/security/`: Roles y permisos

---

### C. Pasos de Migración Identificados

#### PASO 1: PREPARACIÓN
1. Crear estructura de directorios definitiva
2. Copiar (no mover aún) todos los archivos a sus nuevas ubicaciones
3. Documentar todas las referencias cruzadas
4. Hacer backup de la configuración actual

#### PASO 2: ACTUALIZACIÓN DE RUTAS EN ARCHIVOS PHP
1. `tools/php/import_dentar_csv.php`: Actualizar ruta a `sql/sync_dentar_to_os.sql`
2. Actualizar cualquier `require`/`include` de PHP
3. Actualizar rutas relativas a absolutas o mediante `__DIR__`
4. Probar `php -l` en todos los archivos modificados

#### PASO 3: ACTUALIZACIÓN DE RUTAS EN ARCHIVOS SQL
1. Actualizar referencias cruzadas entre `origen_catalog_engine.sql`, `pmo.sql`, `dentar_family.sql`, `dentar_core_and_diagnosis.sql`
2. Verificar que `sync_dentar_to_os.sql` siga funcionando correctamente
3. Probar `psql -v ON_ERROR_STOP=1 -f` en cada uno

#### PASO 3: ACTUALIZACIÓN DE DOCUMENTACIÓN
1. `docs/dentar/README.md`: Actualizar load order con nueva estructura
2. `sql/README.md`: Reflejar nueva organización
3. `docs/adopcion/README.md`: Mantener actualizado
4. `README-API.md`: Verificar que ejemplos aún funcionan

#### PASO 4: VALIDACIÓN
1. Ejecutar `php -l` en todos los archivos PHP modificados
2. Verificar que `git diff --check` no tenga problemas de línea
3. Probar carga en entorno de pruebas (si existe)
4. Verificar que no haya referencias a rutas antiguas

#### PASO 5: LIMPIEZA FINAL
1. Actualizar `.gitignore` si es necesario
2. Verificar que no queden archivos huérfanos
3. Ejecutar `git status` para confirmar cambios
4. Preparar informe final

---

### D. Tabla de Clasificación de Archivos

| Archivo Actual | Nueva Ubicación | Función | Referencias Afectadas | Acción |
|---|---|---|---|---|
| `sql/origen_catalog_engine.sql` | `sql/02_catalogs/` | Motor canonical | Ninguna | Mover |
| `sql/pmo.sql` | `sql/04_pmo.sql` | PMO | `origen_catalog_engine.sql` | Mover |
| `sql/dentar_family.sql` | `sql/03_dentar/` | Familia DENTAR | `dentar_core_and_diagnosis.sql` | Mover |
| `sql/dentar_core_and_diagnosis.sql` | `sql/03_dentar/` | Núcleo DENTAR | `dentar_family.sql`, `sync_dentar_to_os.sql` | Mover |
| `sql/sync_dentar_to_os.sql` | `sql/03_dentar/` | Sincronización DENTAR→os_* | `import_dentar_csv.php` | Mover |
| `sql/05_map_excel.sql` | `sql/02_catalogs/` o mantenimiento | NBU/GTIN loader | `tools/sql/snomed/05_map_excel.sql` | Mantener |
| `sql/nomencladores_argentina.sql` | `sql/06_nomencladores/` o depuración | Legacy | `design.sql` | Evaluar |
| `sql/Argentina_dental_cdt_codes_2025.sql` | `sql/03_dentar/` o `catalogs/` | CDT 2025 | `dentar_core_and_diagnosis.sql` | Mover |
| `sql/importar_loinc.sql` | `sql/loinc/` o `06_loinc.sql` | LOINC | Ninguna crítica | Mover |
| `tools/php/import_dentar_csv.php` | `tools/php/importers/dentar/` | Importador DENTAR | `sync_dentar_to_os.sql`, `dentar_family.sql` | Mover y actualizar rutas |
| `tools/php/convertir_excel_maps.php` | `tools/php/converters/` | XLSX a TSV | `tools/sql/snomed/05_map_excel.sql` | Mover |
| `tools/php/import_nomenclador_csv.php` | `tools/php/importers/nomencladores/` | Nomencladores argentinos | Ninguna crítica | Mover |
| `tools/php/generar_carga_snomed.php` | `tools/php/importers/snomed/` | RF2 ZIP loader | Estructura RF2 | Mover |
| `tools/php/Rf2Importer.php` | `tools/php/importers/snomed/` | Motor RF2 streaming | Estructura RF2 | Mover |
| `tools/php/ImportOptions.php` | `tools/php/common/` | Opciones importador | Ninguna crítica | Mover |
| `tools/php/ImportResult.php` | `tools/php/common/` | Resultados importador | Ninguna crítica | Mover |
| `api/services/CatalogEngineService.php` | `api/services/` (mantener) | API catálogos | Ninguna crítica | Mantener |
| `api/services/TerminologySearchService.php` | `api/services/` (mantener) | Búsqueda terminología | Ninguna crítica | Mantener |
| `docs/dentar/README.md` | `docs/catalogs/dentar/` o mantener | Familia DENTAR | `sql/README.md` | Mejorar contenido |
| `docs/dentar/plantilla-dentar-pr.csv` | `docs/catalogs/denter/plantillas/` | Plantilla PR | `import_dentar_csv.php` | Mover |
| `docs/dentar/plantilla-dentar-dx.csv` | `docs/catalogs/denter/plantillas/` | Plantilla DX | `import_dentar_csv.php` | Mover |
| `docs/adopcion/PLANTILLA_INFORME_MENSUAL.md` | `docs/adopción/` | Informe mensual | Ninguna crítica | Mantener |
| `docs/adopcion/README.md` | `docs/adopción/` | Guía adopción | Ninguna crítica | Mantener |
| `sql/README.md` | `sql/README.md` | Orden de carga | Todos los SQL | Actualizar |
| `README.md` | Raíz proyecto | Estructura general | Ninguna crítica | Mantener, actualizar rutas |
| `README-API.md` | Raíz proyecto | Ejemplos API | Ninguna crítica | Mantener |

---

### E. Procedimiento de Migración Paso a Paso

#### PASO 1: Crear Estructura de Directorios
Ejecutar en el repositorio:
```bash
mkdir -p sql/01_schema
mkdir -p sql/02_catalogs
mkdir -p sql/03_dentar
mkdir -p sql/04_pmo.sql
mkdir -p sql/05_loinc.sql
mkdir -p sql/06_nomencladores
mkdir -p sql/06_loinc.sql
mkdir -p tools/php/importers
mkdir -p tools/php/converters
mkdir -p tools/php/common
mkdir -p tools/php/importers/snomed
mkdir -p docs/catalogs
mkdir -p docs/adopción
mkdir -p docs/architecture
mkdir -p docs/database
mkdir -p docs/imports
mkdir -p docs/deployment
mkdir -p tests/api
mkdir -p tests/database
mkdir -p tests/tools
mkdir -p config
```

#### PASO 2: Mover Archivos SQL
Mover cada archivo a su nueva ubicación y actualizar referencias internas.

#### PASO 3: Mover Scripts PHP
Mover y actualizar rutas internas en cada importador.

#### PASO 3: Actualizar Referencias Cruzadas
Verificar que todos los `include`, `require`, y referencias en SQL funcionen con la nueva estructura.

#### PASO 4: Probar en Entorno Local
Si disponible, ejecutar pruebas sintácticas.

#### PASO 5: Documentar Cambios
Actualizar `migration-plan.md` con lo realmente ejecutado.

#### PASO 6: Validación Final
Ejecutar `git status`, `php -l` en todos los archivos, y verificar que la aplicación web y API sigan respondiendo correctamente (sin modificar producción).

---

### F. Próximos Pasos Después de la Migración

1. **FASE 3: Ejecución** - Mover realmente los archivos
2. **FASE 4: Validación** - Probar que todo funciona
3. **FASE 5: Documentación Final** - `migration-plan.md` completado
4. **FASE 6: Entrega** - Informe con estructura, archivos movidos, y guía de uso

---

## 7. REGLAS DE ORO PARA ESTA MIGRACIÓN

1. **Nunca ejecutar sobre producción** sin autorización explícita
2. **Nunca modificar datos existentes** durante la reorganización
3. **Siempre documentar** la ubicación de cada archivo movido
4. **Siempre probar `php -l`** después de mover scripts PHP
5. **Siempre verificar `git status`** antes y después
6. **Nunca eliminar archivos** sin haber documentado su funcionalidad
7. **Nunca cambiar la estructura de tablas PostgreSQL** sin autorización
8. **Siempre mantener respaldo** antes de mover archivos críticos

---

**FIN DE LA FASE 2: PLAN DE MIGRACIÓN**