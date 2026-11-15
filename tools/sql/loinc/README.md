# Carga de LOINC y Variantes Lingüísticas (es-MX y es-AR) en PostgreSQL 18

Este procedimiento migra el flujo histórico de OpenEMR sobre MariaDB (`LOAD DATA LOCAL INFILE`) a **PostgreSQL 18** sobre **Origen Salud** (`\copy` / `COPY`).

---

## 1. Comparativa de Arquitectura: MariaDB vs PostgreSQL

| Característica | MariaDB / OpenEMR | PostgreSQL 18 / Origen Salud |
| :--- | :--- | :--- |
| **Comando de Carga** | `LOAD DATA LOCAL INFILE` | `\copy` (cliente `psql`) o `COPY` (servidor) |
| **Identificadores** | `AUTO_INCREMENT` | `BIGSERIAL` / `BIGINT` |
| **Strings vacíos vs NULL** | Convierte cadenas vacías a NULL en tipos numéricos implícitamente | Requiere `FORCE_NULL (classtype, common_test_rank, common_order_rank)` en CSV con comillas dobles |
| **Manejo de conflictos** | `ON DUPLICATE KEY UPDATE` | `ON CONFLICT (loinc) DO UPDATE SET` |
| **Preservación de traducciones** | Sobrescribe incondicionalmente con `VALUES(...)`, borrando textos válidos si la variante viene vacía | `COALESCE(NULLIF(EXCLUDED.campo, ''), loinc.campo)` actualiza si hay traducción y preserva si viene vacía |
| **Indexación** | FullText / B-tree antes de la carga | B-tree + Trigram GIN (`gin_trgm_ops`) creados **después** de la carga |

---

## 2. Archivos Requeridos

En la carpeta `Loinc_Importar`:
- `Loinc.csv` (109.325 registros · Base oficial internacional en Inglés)
- `MapTo.csv` (4.657 registros · Mapeos de códigos discontinuados o sinónimos)
- `esMX28LinguisticVariant.csv` (83.231 registros · Capa lingüística México)
- `esAR7LinguisticVariant.csv` (38.293 registros · Capa lingüística Argentina)

---

## 3. Precedencia Lingüística

1. **Inglés Oficial (`Loinc.csv`)**: Inicializa la tabla con los 109.325 conceptos completos.
2. **Español México (`esMX28LinguisticVariant.csv`)**: Aplica la traducción más extensa disponible en idioma español (83.231 conceptos).
3. **Español Argentina (`esAR7LinguisticVariant.csv`)**: Sobrescribe los términos con la terminología local argentina (38.293 conceptos). Gracias a `COALESCE(NULLIF(EXCLUDED.col, ''), loinc.col)`, los conceptos que en el archivo argentino no tienen `LONG_COMMON_NAME` conservan intacta la traducción de México o el inglés en lugar de quedar en blanco.

---

## 4. Ejecución

### Opción A: Desde el servidor VPS (Recomendada)
Si los archivos están en el servidor (ej. `/tmp/Loinc_Importar`):
```bash
sudo -u postgres psql -d origen_salud -f /var/www/html/origen.ar/code-api/tools/sql/loinc/importar_loinc_postgresql.sql
```

### Opción B: Desde Windows por `psql` (Streaming cliente)
```bash
psql -h <HOST_VPS> -U postgres -d origen_salud -f D:\docs\luis\Documentos\sitios\openemr\codigos\Importar_loinc_postgresql.sql
```
