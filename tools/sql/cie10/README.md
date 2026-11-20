# Carga de CIE-10 en PostgreSQL (español + inglés)

Genera `tools/sql/cie10/02_carga.sql` a partir de los CSV/ZIP de CIE-10 y lo
carga en **`origen_codes`** (portal) y **`origen_salud`** (API).

## Requisito previo

Ambos generadores necesitan la extensión `zip` de PHP para leer los ZIP:

```bash
php -m | grep -i zip
```

Si no aparece, descomprimí los archivos a mano y pasá la ruta del CSV ya
extraído con `--diag-en=` / `--proced-en=` (o `--destino=` en el extractor de
SNOMED, aunque ahí también hace falta `zip`).

## Fuentes esperadas

El portal filtra `language_code = 'es'`, pero se cargan ambos idiomas:

| Tipo | Español | Inglés |
|---|---|---|
| Diagnósticos | `Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv` | ZIP con el CSV en inglés |
| Procedimientos | `Procedimientos_Tabla_Referencia_CIE10ES_2026.csv` | ZIP con el CSV en inglés |

## 1. Generar el SQL

Descubrimiento automático dentro de una carpeta:

```bash
cd /var/www/html/origen.ar/code-api
php tools/php/generar_carga_cie10_pg.php tools/sources/cie10 \
    --salida=tools/sql/cie10/02_carga.sql
```

Si los nombres no son reconocidos, pasar las rutas explícitas:

```bash
php tools/php/generar_carga_cie10_pg.php \
    --diag-es=/ruta/Diagnosticos_ES.csv \
    --proced-es=/ruta/Procedimientos_ES.csv \
    --diag-en=/ruta/Diagnosticos_EN.zip \
    --proced-en=/ruta/Procedimientos_EN.zip \
    --salida=tools/sql/cie10/02_carga.sql
```

El generador detecta tabulador, coma o punto y coma, quita BOM y acepta
cabeceras en español o inglés (`Código`/`Code`, `Descripción`/`Description`).

## 2. Ejecutar en ambas bases

```bash
psql -d origen_codes  -v ON_ERROR_STOP=1 -f tools/sql/cie10/02_carga.sql
psql -d origen_salud  -v ON_ERROR_STOP=1 -f tools/sql/cie10/02_carga.sql
```

La carga es idempotente: usa `ON CONFLICT (codigo)` para `cie10_codes` y un
`NOT EXISTS` por `(cie10_id, language_code, descripcion)` para las descripciones.

## 3. Verificación

```sql
SELECT language_code, count(*) AS filas
FROM cie10_descriptions
GROUP BY language_code
ORDER BY language_code;

SELECT count(*) AS codigos FROM cie10_codes;

SELECT count(*) AS infarto
FROM cie10_descriptions
WHERE descripcion ILIKE '%infarto%';
```

---

# SNOMED: ZIP combinado internacional + argentina

El ZIP traerá dos Snapshot por tipo de archivo. El generador oficial falla con
*“El ZIP trae dos archivos para …”*. Primero se filtra la edición argentina,
que incluye los conceptos internacionales y descripciones en `es` y `en`.

Antes de empezar, confirmá espacio: `sct2` + índices ocupa ~15-20 GB **por base**
y se carga en `origen_codes` y `origen_salud`.

```bash
df -h
```

```bash
cd /var/www/html/origen.ar/code-api

# 1) Extraer solo la edición argentina (mantiene es + en)
php tools/php/extraer_snomed_argentina.php \
    SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z.zip \
    --destino=/var/www/html/origen.ar/code-api/sct_argentina

# 2) Generar el \copy desde la carpeta extraída
#    (\copy lo ejecuta psql leyendo los archivos en el VPS; no necesita
#     pg_read_server_files. Si se usa COPY del servidor, sí hace falta.)
php tools/php/generar_carga_snomed.php \
    /var/www/html/origen.ar/code-api/sct_argentina \
    --cliente \
    --salida=tools/sql/snomed/02_carga.sql

# 3) Cargar en ambas bases (ORDEN IMPORTANTE)
psql -d origen_codes -v ON_ERROR_STOP=1 -f tools/sql/snomed/01_esquema.sql
psql -d origen_codes -v ON_ERROR_STOP=1 -f tools/sql/snomed/02_carga.sql
psql -d origen_codes -v ON_ERROR_STOP=1 -f tools/sql/snomed/03_postcarga.sql
psql -d origen_codes -f tools/sql/snomed/99_verificacion.sql

psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/01_esquema.sql
psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/02_carga.sql
psql -d origen_salud -v ON_ERROR_STOP=1 -f tools/sql/snomed/03_postcarga.sql
psql -d origen_salud -f tools/sql/snomed/99_verificacion.sql
```

`01_esquema.sql` destruye solo el esquema `sct2`. `03_postcarga.sql` hace
`TRUNCATE` de `public.snomed_descriptions` (hoy 0 filas en ambas bases).

## Verificación final en ambas bases

```sql
SELECT language_code, count(*) AS filas
FROM snomed_descriptions
GROUP BY language_code
ORDER BY language_code;

SELECT language_code, count(*) AS filas
FROM cie10_descriptions
GROUP BY language_code
ORDER BY language_code;

SELECT
  (SELECT count(*) FROM snomed_descriptions WHERE term ILIKE '%infarto%') AS snomed_infarto,
  (SELECT count(*) FROM cie10_descriptions WHERE descripcion ILIKE '%infarto%') AS cie10_infarto;
```
