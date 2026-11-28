# Cobertura de OFTAR-PR

**Fecha:** 2026-11-28  
**Estado:** diagnóstico local. La cobertura real en producción no fue consultada.

---

## 1. Qué se considera OFTAR-PR

OFTAR-PR es el catálogo de **procedimientos y prestaciones oftalmológicas** de la familia OFTAR. Su numeración permanente es `OFT-PR-NNNNNN`. Las fuentes de origen conservan su propia numeración y se vinculan solo por mapeo gobernado.

| Fuente | Rol | Código en el motor |
|---|---|---|
| Nomenclador Nacional 2025 · OFTALMOLOGIA | Núcleo de 154 procedimientos | `oftar-pr` |
| CAO | Catálogo de origen, 143 filas | `nomenclador-oftalmologico-cao-ar` |
| Regional NOA | Catálogo de origen, 136 filas | `nomenclador-oftalmologico-regional-ar` |

---

## 2. Cobertura esperada por contrato de carga

| Concepto | Cantidad | Origen de la cifra |
|---|---:|---|
| Procedimientos OFTAR-PR | **154** | `fuente_nomenclador_oftar_pr.sql`: 154 tuplas de 6 dígitos; `renombrar_codigos_oftar.sql:8` documenta 154. |
| Códigos CAO | **143** | CSV CAO; 143 únicos. |
| Códigos Regional | **136** | CSV Regional; 136 únicos. |
| Filas en matriz de equivalencias | **279** | 143 CAO + 136 Regional. |
| Candidatos textuales CAO ↔ NN | **91** | Normalización sin acentos, mayúsculas ni puntuación. |
| Candidatos textuales Regional ↔ NN | **0** | Ninguna descripción coincide exactamente tras normalizar. |

**[H]** Cobertura esperada = 154 ítems propios + 279 ítems de origen, conviviendo en la búsqueda OFTAR cuando sus versiones están aprobadas.

**[I]** Producción real: desconocida en esta auditoría; requiere la consulta A de `auditoria-oftar-actual.md`.

---

## 3. Categorías internas de OFTAR-PR

`oftar_categorias.csv` y `oftar_core.sql:86-101` definen cuatro raíces y ocho hojas:

| Capítulo fuente | Categoría clínica vigente |
|---|---|
| `GRP-EVAL` Evaluación y consulta | `CLIN-PROC` |
| `CONSULT`, `TER`, `CIR`, `OCUL`, `LAGR` | `CLIN-PROC` |
| `EXAM`, `DIAG`, `IMG` | `CLIN-EST` |
| `GRP-DIAG` Diagnóstico y estudios | `CLIN-DIAG` |
| `GRP-TER` Tratamiento y cirugía | `CLIN-PROC` |
| `GRP-OCUL` Oculoplastia y aparato lagrimal | `CLIN-ANAT` |

**[H]** `categorias_clinicas.sql:107-118` mapea cada categoría fuente a una categoría `CLIN-*`. La API conserva `category` y expone además `clinical_category`.

---

## 4. Clasificación propuesta de las fuentes de origen

La matriz `matriz-equivalencias-oftar-pr.csv` clasifica las 279 filas por **etiqueta literal de la fuente**, sin afirmar equivalencia clínica.

| Fuente | Categoría fuente | Categoría interna propuesta | Categoría clínica destino | Filas |
|---|---|---|---|---:|
| CAO | CONSULTA OFTALMOLÓGICA | `CONSULT` | `CLIN-PROC` | 13 |
| CAO | EXAMEN ESPECIAL | `EXAM` | `CLIN-EST` | 56 |
| CAO | TRATAMIENTO CON LÁSER (ambas variantes) | `TER` | `CLIN-PROC` | 13 |
| CAO | OPERACIÓN DE PÁRPADO / MÚSCULO EXTRAOCULAR | `OCUL` | `CLIN-PROC` | 11 |
| CAO | OPERACIÓN DE VÍAS LAGRIMALES | `LAGR` | `CLIN-PROC` | 9 |
| CAO | Resto de OPERACIÓN | `CIR` | `CLIN-PROC` | 37 |
| CAO | MÓDULO BAJA VISIÓN | `EXAM` | `CLIN-EST` | 4 |
| Regional | CONSULTAS | `CONSULT` | `CLIN-PROC` | 9 |
| Regional | PRACTICAS Y ESTUDIOS COMPLEMENTARIOS | `EXAM` | `CLIN-EST` | 47 |
| Regional | Subgrupos párpado/órbita/estrabismo | `OCUL` | `CLIN-PROC` | 26 |
| Regional | Subgrupo sistema lagrimal | `LAGR` | `CLIN-PROC` | 10 |
| Regional | Resto de PRACTICAS QUIRURGICAS | `CIR` | `CLIN-PROC` | 44 |

Totales por categoría interna propuesta: `EXAM` 107, `CIR` 81, `OCUL` 37, `CONSULT` 22, `LAGR` 19, `TER` 13.  
Totales por categoría clínica destino propuesta: `CLIN-PROC` 172, `CLIN-EST` 107.

**[I]** La clasificación de estudios complementarios en `EXAM` es conservadora: una revisión humana podría refinar algunas filas a `DIAG` o `IMG`. Ese refinamiento **no está implementado** y en la matriz figura como `candidato` con base literal.

**[H]** La categoría clínica asignada por defecto a los catálogos de origen CAO y Regional es `CLIN-PREST` (`categorias_clinicas.sql:144-145`). La columna `categoria_concepto_destino_propuesta` de la matriz describe el destino `oftar-pr` sugerido, no una sobrescritura del catálogo fuente.

---

## 5. Correspondencias textuales

De los 143 códigos CAO, 91 tienen descripción idéntica tras normalizar a un texto del Nomenclador Nacional 2025. Ejemplos verificados:

| CAO | NN 2025 | Descripción normalizada |
|---|---|---|
| `460105` | `306002` | RFG bilateral |
| `460118` | `300120` | Examen sensorio motor en estrabismo |
| `460137` | `306003` | Examen de prematuros |
| `460154` | `306013` | Electroretinograma |

**[H]** Son propuestas en `os_oftar_nomenclador_match` con `match_basis='texto_identico_normalizado'` y `review_status='proposed'`. No afirman equivalencia clínica ni de facturación.

**[I]** H-02: el `target_code` sembrado es el código de 6 dígitos del NN, mientras el ítem `oftar-pr` tiene `permanent_code='OFT-PR-NNNNNN'`. Si no se resolvió por identificador, la aprobación no publica relaciones. Ver consulta D en `auditoria-oftar-actual.md`.

---

## 6. Lo que NO cubre OFTAR-PR

- No copia importes: `valor`, `honorario_medico`, `gasto` y `valor_total` quedan fuera del espejo (`generate_nomencladores_oftalmologicos_sql.py:201-203`).
- No crea códigos OFTAR para CIE-10-PCS `08*` ni para CPT.
- No declara equivalencia clínica automática por similitud de texto.
- No genera códigos nuevos por lateralidad: OD/OI/AO/NA son atributos (`importar_nomenclador_oftar_pr.sql:110-117`, `:160-170`).
- No crea UVR por diagnóstico ni convierte importes a UVR.

---

## 7. Verificación recomendada (solo lectura)

```sql
BEGIN READ ONLY;

SELECT c.code AS catalogo, count(i.id) AS items
  FROM os_catalog c
  LEFT JOIN os_catalog_item i ON i.catalog_id = c.id
 WHERE c.code IN ('oftar-pr','nomenclador-oftalmologico-cao-ar',
                  'nomenclador-oftalmologico-regional-ar')
 GROUP BY c.code ORDER BY c.code;

SELECT source_catalog_code, review_status, count(*) AS pares
  FROM os_oftar_nomenclador_match
 GROUP BY 1,2 ORDER BY 1,2;

SELECT m.source_code, m.target_code,
       t.id AS target_item_id, t.permanent_code
  FROM os_oftar_nomenclador_match m
  LEFT JOIN os_catalog tc ON tc.code = m.target_catalog_code
  LEFT JOIN os_catalog_item t
         ON t.catalog_id = tc.id AND t.permanent_code = m.target_code
 WHERE m.source_catalog_code = 'nomenclador-oftalmologico-cao-ar'
 ORDER BY m.source_code
 LIMIT 20;

ROLLBACK;
```

Criterio de aceptación: 154 ítems propios, 143 CAO, 136 Regional; 91 propuestas CAO `proposed`/`approved` según revisión; `target_item_id` no nulo para las propuestas que deban publicarse.
