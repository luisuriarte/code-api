# Cobertura de OFTAR-DX

**Fecha:** 2026-11-28  
**Estado:** diagnóstico local. La cobertura real en PostgreSQL no fue consultada en esta auditoría.

---

## 1. Qué se considera OFTAR-DX

OFTAR-DX es el catálogo de **diagnósticos oftalmológicos** de la familia OFTAR. Su numeración permanente es `OFT-DX-NNNNNN`. El sistema externo obligatorio es CIE-10, rango **H00-H59** (ojo y anexos). No recibe UVR: la valoración corresponde a la prestación, no al diagnóstico.

Evidencia: `oftar_family.sql:61-64`, `oftar_core.sql:148-150,251`, `sync_oftar_dx_to_os.sql:17`, `UvrPublicRepository.php:37,96-107`.

---

## 2. Fuentes y conteos verificados

| Fuente | Archivo | Registros H | Uso |
|---|---|---:|---|
| CIE-10-ES 2026 (español) | `tools/sources/cie10/Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv` | **2.661** | Texto `es-AR`, códigos H00-H59. |
| ICD-10-CM 2027 (inglés) | `tools/sources/cie10/2027-code-descriptions-in-tabular-order.zip` | **2.677** | Texto `en`; 17 códigos no presentes en el CSV ES. |
| Intersección ES ∩ EN | cruce por código normalizado | **2.660** | Un mismo diagnóstico con texto en ambos idiomas. |
| Exclusivos ES | `H01.8` | **1** | Queda solo en `es-AR`; no se inventa texto inglés. |
| Exclusivos EN | p. ej. `H01.81`, `H01.82`, `H34.*`, `H35.*` | **17** | Quedan solo en `en`; no se inventa texto español. |
| **Unión esperada** | — | **2.678** | Diagnósticos OFTAR-DX esperados. |

**[H]** El CSV español contiene 74.260 diagnósticos en total; el filo H00-H59 tiene 2.661 filas, todas `Nodo_Final=1`.

**[H]** El archivo inglés principal contiene 23.292 códigos; al analizar el archivo con patrón laxo de separador, hay 2.677 códigos H y 2.660 coinciden con el CSV ES.

**[I]** La cifra 2.678 coincide con la documentada por `renombrar_codigos_oftar.sql:9` (2678 diagnósticos). Estado en producción: desconocido.

---

## 3. Proceso de importación verificado

`tools/sources/oftalmologico/oftar/importar_cie10_dx.sql`:

1. Exige `cie10_codes`, `cie10_descriptions` y `oftar_external_identity` (`L34-46`).
2. Normaliza el código externo con `oftar_normalize_external_code()` (`upper(btrim())` sin puntos, espacios ni guiones).
3. Usa `DISTINCT ON (código normalizado, idioma destino)` con precedencia `es → es-AR`, `en → en` y menor `id` en caso de duplicado (`L53-71`).
4. Asigna `OFT-DX-NNNNNN` con `lpad` sobre el máximo existente, en orden de código normalizado (`L105-117`). No reutiliza retirados.
5. Inserta `oftar_diagnosis`, versión en `draft`, términos preferidos y mapeo `CIE-10` con `mapping_type='equivalent'` (`L122-164`).
6. El trigger de identidad fija el dueño `oftar-dx`; CIE-10 no puede mapearse desde `oftar-pr` (`oftar_external_identity.sql:131-137`).

**[H]** Segunda ejecución: solo importa códigos ausentes en `oftar_external_identity` y en `oftar_diagnosis_mapping` (`L84-100`). No desplaza la numeración.

---

## 4. Proyección al motor canónico

`sql/03_oftar/sync_oftar_dx_to_os.sql`:

- Crea un ítem por diagnóstico con `permanent_code = d.code` (`L60-66`).
- Crea una versión por idioma disponible; **no rellena el idioma ausente** (`L71-84`).
- Usa identificador primario `system_name='CIE-10'` y mapeo con `relationship_role='observation_concept'` (`L122-161`).
- Deja `preferred_term`, `definition` y `external_display` en revisión `unknown` (`L163-219`).
- No crea UVR.

**[H]** `v_oftar_search_catalog` solo publica versiones `review_status='approved'` (`oftar_domain_search.sql:72-80`). Por eso la importación por sí sola no garantiza visibilidad pública: falta la aprobación de `preferred_term`.

---

## 5. Cobertura idiomática

| Situación | Cantidad | Tratamiento |
|---|---:|---|
| Códigos con texto ES y EN | 2.660 | Dos versiones; la vista prefiere `es-AR`. |
| Solo ES (`H01.8`) | 1 | Sin versión `en`; no se traduce automáticamente. |
| Solo EN | 17 | Sin versión `es-AR`; no se inventa traducción. |
| Total de versiones esperadas | 5.338 | 2.661 ES + 2.677 EN. |

**[H]** `oftar_core.sql:165-166` declara `pt-BR` como `planned`; no hay texto pt-BR cargado.

**[P]** La reconstrucción debe conservar los huecos idiomáticos como datos explícitos y resolverlos por gobernanza, no por traducción automática.

---

## 6. Lo que NO cubre OFTAR-DX

- No importa CIE-10-PCS `08*` como diagnóstico ni como código OFTAR.
- No crea UVR ni importes.
- No asigna categoría clínica distinta de `CLIN-DIAG` por defecto (`categorias_clinicas.sql:119,143`).
- No inventa equivalencias SNOMED CT: SNOMED queda como sistema opcional (`oftar_core.sql:252`).
- No reutiliza códigos retirados; la numeración crece por máximo + `row_number()`.

---

## 7. Verificación recomendada (solo lectura)

```sql
BEGIN READ ONLY;

-- A. Diagnósticos y versiones por idioma
SELECT count(*) AS diagnosticos FROM oftar_diagnosis;
SELECT language_code, count(*) AS versiones
  FROM oftar_diagnosis_term
 WHERE term_type = 'preferred'
 GROUP BY language_code ORDER BY language_code;

-- B. Dueño de CIE-10 y duplicados
SELECT system_code, owner_catalog, entity_kind, count(*) AS codigos
  FROM oftar_external_identity
 GROUP BY 1,2,3 ORDER BY 1,2;

SELECT count(*) AS duplicados
  FROM (
    SELECT system_code, code_normalized
      FROM oftar_external_identity
     GROUP BY 1,2 HAVING count(*) > 1
  ) d;

-- C. Rango y prefijo
SELECT count(*) AS fuera_de_rango
  FROM oftar_diagnosis_mapping
 WHERE system_code = 'CIE-10'
   AND external_code !~ '^H(0[0-9]|[1-5][0-9])';

SELECT count(*) AS prefijos_viejos
  FROM oftar_diagnosis WHERE code LIKE 'OFTAR-DX-%';

-- D. Proyección y visibilidad
SELECT language_code, count(*) AS versiones_os
  FROM os_catalog_item_version iv
  JOIN os_catalog_item i ON i.id = iv.item_id
  JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'oftar-dx'
 GROUP BY language_code ORDER BY language_code;

SELECT count(*) AS visibles
  FROM v_oftar_search_catalog WHERE catalogo = 'oftar-dx';

ROLLBACK;
```

Criterio de aceptación: 2.678 diagnósticos, 2.661 términos `es-AR`, 2.677 términos `en`, 0 duplicados de identidad, 0 códigos fuera de H00-H59, 0 prefijos viejos. La cantidad `visibles` dependerá de las aprobaciones editoriales vigentes y debe informarse, no asumirse.
