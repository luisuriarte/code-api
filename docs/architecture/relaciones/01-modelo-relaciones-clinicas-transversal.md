# Modelo transversal de relaciones clínicas, anatómicas y funcionales

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** diseño obligatorio para DENTAR y OFTAR. (No autoriza ejecución ni aprobación clínica.)

---

## 1. Principio

**[P]** Una relación clínica es un vínculo gobernado entre **dos conceptos internos del motor**, independientemente de que pertenezcan al mismo catálogo, a catálogos distintos de una misma familia o a familias diferentes.

**[H]** `os_catalog_relation` ya modela dos extremos internos con `source_item_id` y `target_item_id` (`nomenclador_odontologico_nacional.sql:534-538`), dirección derivable, `context_text`, `provenance` y `review_status` (`:549-553`). Fase 3 añadió catálogos/releases de ambos extremos, vigencia y clasificación (`fase3_relaciones_mapeos.sql:60-73`).

**[P]** La relación clínica **no es** una correspondencia terminológica. Que un procedimiento y un diagnóstico estén clínicamente relacionados no significa que sus códigos sean equivalentes, ni que deban persistirse en `os_concept_mapping`.

---

## 2. Combinaciones admitidas

| Origen → destino | Ejemplo | Condición |
|---|---|---|
| PR → PR | `DENTAR-PR` → `DENTAR-PR`; `OFTAR-PR` → `OFTAR-PR` | Misma familia; ancla técnica/clínica en `context_text`. |
| DX → DX | `DENTAR-DX` → `DENTAR-DX`; `OFTAR-DX` → `OFTAR-DX` | Diferenciación, asociación, complicación, causalidad o jerarquía verificada. |
| PR → DX | `DENTAR-PR` → `DENTAR-DX`; `OFTAR-PR` → `OFTAR-DX` | justificación clínica explícita; nunca equivalencia. |
| PR/DX → ANAT/CL/FUNC | procedimiento o diagnóstico → estructura, hallazgo o área funcional | Sin propagación automática de jerarquías anatómicas. |
| DENTAR-PR → OFTAR-DX | Entre familias | Solo con justificación clínica documentada y revisión de ambas familias. |
| Otras familias | KINESIOLOGIA → SALUD_MENTAL, etc. | Solo cuando el perfil de dominio lo habilite y exista evidencia. |

**[H]** El esquema no impone que ambos extremos pertenezcan al mismo catálogo: los FKs apuntan a `os_catalog_item(id)` sin restricción de catálogo (`:536-537`). **[I]** La restricción debe estar en la política de dominio, no en una tabla nueva.

---

## 3. Clases de relaciones

Las clases son comunes; los códigos canónicos están en `03-diccionario-tipos-relacion-transversal.md`.

| Clase | Tipos cubiertos | Naturaleza |
|---|---|---|
| A · PR-PR | relacionado, complementario, alternativo, parte de, previo/posterior, combinado, requiere, secuencia | Asociativa o jerárquica; no equivalencia. |
| B · DX-DX | relacionado, asociado, diferencial, más amplio/más específico, manifestación, complicación, causa/etiología, coexistente | Jerarquía solo si es real y verificada. |
| C · PR-DX | diagnosticar, evaluar, tratar (terapéutico/intervencionista), seguimiento, control, preventivo, contraindicado, no recomendado | Dirección PR → DX; `justifying_diagnosis` en mapeo no la sustituye. |
| D · ANAT | afecta, evalúa, interviene, localiza, parte de, región anatómica, insumo/dispositivo | Una fila por estructura; sin expansión automática desde agrupaciones. |
| E · FUNC | compromete función, evalúa función, área funcional | No confundir `ANAT-*` con `AREA-*`. |

**[P]** «Procedimiento alternativo» no es `interchangeable_with` ni `equivalent`. «No recomendado» y «contraindicado» son juicios clínicos negativos con evidencia, no ausencia de mapeo.

---

## 4. Dirección, simetría y cardinalidad

1. **[H]** La dirección es `source_item_id → target_item_id`; la ficha calcula `outgoing`/`incoming` para presentación (`CatalogRepository.php:3069,3078-3082`).
2. **[P]** No se generan inversas automáticas. Solo se declara `inverse_code` cuando la inversa es semánticamente equivalente y ratificada (ej. `REL-DX-NARROW` ↔ `REL-DX-BROAD`).
3. **[P]** Las relaciones simétricas declaradas (p. ej. coexistencia) requieren **segunda fila explícita**; `dedupeRelations()` puede colapsarlas en pantalla sin borrar la fila (`CatalogRepository.php:3124-3164`).
4. **[P]** Cardinalidad: un concepto puede tener muchas relaciones salientes y entrantes, hacia la misma familia o hacia otras. La `UNIQUE` de siete columnas evita duplicados exactos (`nomenclador_odontologico_nacional.sql:556-558`).
5. **[P]** Si cambia el significado, se crea una nueva fila con nueva vigencia; no se reescribe una relación aprobada.

---

## 5. Puente actual y destino gobernado

**[H]** Hoy el `CHECK` de `relation_type` admite solo 15 valores heredados de CDT (`nomenclador_odontologico_nacional.sql:538-545`). Los tipos clínicos `REL-*` no caben en ese `CHECK` como valor directo.

**[P] Puente transitorio documentado:** `relation_type='referencia_literal'`, `source_system_code='OFTAR-CLINICAL'` o equivalente por familia, `source_field='notes'`, `source_value` con código corto, `context_text` y `provenance` obligatorios. Sirve para diseño y validación; **no es el modelo definitivo**.

**[P] Destino:** columna aditiva `relation_type_code VARCHAR(60)` con FK a `os_relation_type`, conservando `relation_type` legado intacto. Migración propuesta, **no ejecutada**. Requiere acta, backup y verificación de que las 603 relaciones documentadas y los tipos CDT no se alteran.

---

## 6. Reglas de validez clínica

- Toda fila publicable exige `review_status='approved'` y evidencia en `provenance`.
- `context_text` es obligatorio en el puente y en los tipos con ancla clínica; forma parte de la clave única.
- La jerarquía anatómica no propaga: `ANAT-UVE` no sustituye a `ANAT-COROID`, ni `ANAT-SUP` genera miembros automáticos.
- Un diagnóstico no se vuelve más específico por tener menos palabras; se exige criterio documentado.
- Una relación entre DENTAR y OFTAR se revisa por ambas familias y nunca se publica por similitud textual.

---

## 7. Ejemplos estructurales (no datos reales)

| Ejemplo | Extremos | Tipo propuesto | Estado |
|---|---|---|---|
| Procedimiento restaurador complementario | `DNT-PR-<id>` → `DNT-PR-<id>` | `REL-PR-COMP` | **[P]** ejemplo de forma, no fila cargada |
| Diagnóstico complicación | `DNT-DX-<id>` → `DNT-DX-<id>` | `REL-DX-COMPL` | **[P]** ejemplo de forma |
| Procedimiento utilizado para tratar | `OFT-PR-<id>` → `OFT-DX-<id>` | `REL-PRDX-TRAT` | **[P]** ejemplo de forma |
| Estructura afectada | `DENTAR/OFTAR` → `ANAT-*`/`DNT-AN-*` | `REL-ANAT-AFFECT` | **[P]** ejemplo de forma |

**[P]** Los marcadores `<id>` son posiciones de maquetación: no son códigos reales ni aprobaciones.
