# CIE-10-ES para OpenEMR

Importación de la **Edición Española de CIE-10** (Clasificación Internacional de
Enfermedades, 10.ª Revisión, Modificación Clínica) en las tablas nativas de OpenEMR.

La edición de referencia es la **6.ª Edición (2026)** publicada por el
**Ministerio de Sanidad de España**.

---

## Índice

1. [Qué hace este proyecto](#1-qué-hace-este-proyecto)
2. [Fuente oficial](#2-fuente-oficial)
3. [Requisitos](#3-requisitos)
4. [Archivos del proyecto](#4-archivos-del-proyecto)
5. [Procedimiento de carga](#5-procedimiento-de-carga)
6. [Modelo de datos](#6-modelo-de-datos)
7. [Decisiones de diseño](#7-decisiones-de-diseño)
8. [Actualización anual](#8-actualización-anual)
9. [Verificación](#9-verificación)

---

## 1. Qué hace este proyecto

Carga los diagnósticos y procedimientos de CIE-10-ES en las tablas **nativas**
de OpenEMR:

- `icd10_dx_order_code` → 74.260 diagnósticos (edición 2026)
- `icd10_pcs_order_code` → 78.948 procedimientos (edición 2026)

Al usar los nombres de tabla nativos, el autocompletado de diagnósticos,
el módulo de recetas, los formularios clínicos y los reportes de OpenEMR
los reconocen **sin ningún parche**.

**No modifica ninguna tabla clínica de OpenEMR.**

---

## 2. Fuente oficial

| Recurso | URL |
|---|---|
| Descarga de tablas (xlsx/csv) | https://www.sanidad.gob.es/estadEstudios/estadisticas/normalizacion/home.htm |
| Consulta interactiva eCIEmaps | https://www.eciemaps.sanidad.gob.es/ |

Los archivos a descargar son:
- `Diagnosticos_Tabla_Referencia_CIE10ES_2026.xlsx` (o `.csv`)
- `Procedimientos_Tabla_Referencia_CIE10ES_2026.xlsx` (o `.csv`)

> Si el Ministerio publica solo el XLSX, hay que guardarlo como CSV (tab-separado,
> UTF-8) desde Excel o LibreOffice antes de ejecutar el generador.
> Ver [sección 7.1](#71-si-el-ministerio-solo-publica-xlsx) para los pasos exactos.

---

## 3. Requisitos

| Componente | Requisito |
|---|---|
| Base de datos | MySQL 8.0+ o MariaDB 10.4+ |
| `local_infile` | `SET GLOBAL local_infile = 1` |
| Cliente | DBeaver-CE o cliente `mysql` |
| PHP (para el generador) | PHP 7.4+ (sin extensiones adicionales) |

---

## 4. Archivos del proyecto

```
cie10_argentina/
├── readme.md
├── sql/
│   ├── 01_esquema.sql       ← crea las tablas (borra las anteriores)
│   ├── 02_carga.sql         ← GENERADO por scripts/generar_carga.php
│   ├── 03_postcarga.sql     ← índices y ANALYZE TABLE
│   └── 99_verificacion.sql  ← controles post-carga (solo SELECT)
└── scripts/
    └── generar_carga.php    ← genera sql/02_carga.sql a partir de los CSV
```

---

## 5. Procedimiento de carga

### Paso 0 — Obtener los CSV del Ministerio de Sanidad

1. Ir a: https://www.sanidad.gob.es/estadEstudios/estadisticas/normalizacion/home.htm
2. Descargar `Diagnosticos_Tabla_Referencia_CIE10ES_<AÑO>.xlsx`
3. Descargar `Procedimientos_Tabla_Referencia_CIE10ES_<AÑO>.xlsx`
4. Si bajaron como XLSX, convertir a CSV tab-separado:
   - Abrir en LibreOffice Calc → Guardar como → Texto CSV
   - Separador: **Tabulador**, Codificación: **UTF-8**
   - Nombre: `Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv`

### Paso 1 — Generar el script de carga

```bash
# En Windows (PowerShell):
cd D:\...\cie10_argentina
php scripts/generar_carga.php "D:\codigos\cie-10" --revision=3

# Si los CSV están en otra carpeta:
php scripts/generar_carga.php "D:\...\cie-10" --ruta="D:\...\cie-10"
```

El parámetro `--revision=N` es el número de edición (1=2022, 2=2024, 3=2026).

### Paso 2 — Ejecutar en DBeaver

1. Habilitar `allowLoadLocalInfile`:
   - Conexión → Editar → Propiedades del driver → Agregar propiedad
   - Nombre: `allowLoadLocalInfile` | Valor: `true`
2. `01_esquema.sql` → *Execute Script* (Ctrl+Shift+Enter)
3. `02_carga.sql` → *Execute Script* (tarda ~30 segundos)
4. `03_postcarga.sql` → *Execute Script*
5. `99_verificacion.sql` → *Execute Script* y verificar que todo diga `OK`

### Paso 3 — Verificar en OpenEMR

Ir a **Administración → Codificación → Tablas Estandarizadas** y buscar ICD10.
Los diagnósticos deben aparecer en el autocompletado de la consulta.

---

## 6. Modelo de datos

### `icd10_dx_order_code` — Diagnósticos

| Columna | Tipo | Descripción |
|---|---|---|
| `dx_id` | BIGINT AUTO_INCREMENT | PK interno |
| `dx_code` | VARCHAR(15) | Código con punto: `A00.0` |
| `formatted_dx_code` | VARCHAR(10) | Código sin punto: `A000` (usado por OpenEMR) |
| `valid_for_coding` | VARCHAR(50) | `1` = codificable (nodo hoja), `0` = categoría padre |
| `short_desc` | VARCHAR(60) | Descripción truncada a 60 chars |
| `long_desc` | TEXT | Descripción completa (hasta 251 chars en 2026) |
| `active` | TINYINT | `1` = activo |
| `revision` | INT | Número de edición cargada |

### `icd10_pcs_order_code` — Procedimientos

| Columna | Tipo | Descripción |
|---|---|---|
| `pcs_id` | BIGINT AUTO_INCREMENT | PK interno |
| `pcs_code` | VARCHAR(7) | Código de 7 caracteres: `0016070` |
| `valid_for_coding` | CHAR(1) | Siempre `1` |
| `short_desc` | VARCHAR(60) | Descripción truncada a 60 chars |
| `long_desc` | TEXT | Descripción completa (hasta 210 chars en 2026) |
| `active` | TINYINT | `1` = activo |
| `revision` | INT | Número de edición cargada |

---

## 7. Decisiones de diseño

### 7.1 Si el Ministerio solo publica XLSX

El portal del Ministerio publica los archivos principalmente en XLSX. Para
convertir a CSV tab-separado con LibreOffice Calc:

1. Abrir el XLSX
2. Archivo → Guardar como → Tipo: **Texto CSV (.csv)**
3. En el diálogo: Separador de campo = **Tab** | Conjunto de caracteres = **UTF-8**
4. Guardar con el nombre `Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv`

Con Excel de Windows: Guardar como → CSV UTF-8 (delimitado por comas) **no sirve**
porque usa coma y no tab. Usar "Otros formatos" o LibreOffice.

### 7.2 `dx_code` con punto, `formatted_dx_code` sin punto

El CSV del Ministerio usa el formato con punto (`A00.0`). OpenEMR internamente
usa `formatted_dx_code` sin punto para las búsquedas. El `LOAD DATA` genera
ambos campos automáticamente:

```sql
`dx_code`           = @dx_code,                    -- 'A00.0'
`formatted_dx_code` = REPLACE(@dx_code, '.', ''),  -- 'A000'
```

### 7.3 `short_desc` truncado a 60 caracteres

OpenEMR muestra `short_desc` en algunos listados con espacio limitado.
El LOAD DATA calcula `LEFT(@long_desc, 60)` directamente en MySQL.

### 7.4 `revision` como número de edición

El campo `revision` guarda el número de edición cargada (no el año):
- `1` → edición 2022
- `2` → edición 2024
- `3` → edición 2026

Permite saber qué versión está activa al consultar la tabla.

---

## 8. Actualización anual

La CIE-10-ES se actualiza aproximadamente cada año (2022, 2024, 2026...).
Para actualizar:

1. Descargar los nuevos CSV del Ministerio de Sanidad.
2. Regenerar el SQL:
   ```bash
   php scripts/generar_carga.php "D:\codigos\cie-10-nueva" --revision=4
   ```
3. Ejecutar `01_esquema.sql` (recrea las tablas), luego `02_carga.sql`, `03_postcarga.sql`.

> El `01_esquema.sql` hace `DROP TABLE IF EXISTS` antes de crear. Si hay datos
> clínicos en producción que referencian los códigos, hacer un respaldo previo:
>
> ```sql
> CREATE TABLE icd10_dx_order_code_bak SELECT * FROM icd10_dx_order_code;
> CREATE TABLE icd10_pcs_order_code_bak SELECT * FROM icd10_pcs_order_code;
> ```

---

## 9. Verificación

Valores esperados para la edición **CIE-10-ES 2026**:

| Tabla | Esperado |
|---|---|
| `icd10_dx_order_code` total | 74.260 |
| `icd10_dx_order_code` codificables (`valid_for_coding = 1`) | 74.258 |
| `icd10_pcs_order_code` total | 78.948 |

El script `99_verificacion.sql` comprueba estos conteos y la integridad
de los datos (códigos con/sin punto, largo de descripciones, campos vacíos).

