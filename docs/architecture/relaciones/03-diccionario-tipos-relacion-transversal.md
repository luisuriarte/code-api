# Diccionario transversal de tipos de relación

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** inventario canónico de trabajo. (No autoriza persistir códigos ni aprobar relaciones.)

---

## 1. Principio de reutilización

**[P]** No se crea un diccionario por catálogo. Los 31 códigos `REL-*` documentados para OFTAR pasan a ser el **núcleo común del motor** y se reutilizan en DENTAR cuando la semántica sea idéntica. Las particularidades se resuelven con perfil de dominio, `context_text` y evidencia, no con códigos duplicados.

**[H]** Los códigos tienen 12–16 caracteres y caben en `source_value VARCHAR(20)` (`nomenclador_odontologico_nacional.sql:548`). El detalle completo de inversas, campos obligatorios y reglas P1–P6 está en `docs/audit/diccionario-tipos-relacion-oftar.md:37-104`.

---

## 2. Núcleo común (31 códigos)

| Clase | Códigos |
|---|---|
| A · PR-PR | `REL-PR-REL`, `REL-PR-COMP`, `REL-PR-ALT`, `REL-PR-PART`, `REL-PR-COMB`, `REL-PR-REQR`, `REL-PR-SEQ` |
| B · DX-DX | `REL-DX-REL`, `REL-DX-ASSOC`, `REL-DX-DIFF`, `REL-DX-NARROW`, `REL-DX-BROAD`, `REL-DX-MANIF`, `REL-DX-COMPL`, `REL-DX-ETIOL`, `REL-DX-COEX` |
| C · PR-DX | `REL-PRDX-DIAG`, `REL-PRDX-EVAL`, `REL-PRDX-TER`, `REL-PRDX-TRAT`, `REL-PRDX-FUP`, `REL-PRDX-CTRL`, `REL-PRDX-PREV`, `REL-PRDX-CONTRA`, `REL-PRDX-NOTREC` |
| D · ANAT | `REL-ANAT-AFFECT`, `REL-ANAT-INTERV`, `REL-ANAT-EVAL`, `REL-ANAT-LOC`, `REL-ANAT-PART` |
| E · FUNC | `REL-FUNC-IMPAIR` |

**[P]** Los 31 permanecen como propuesta cerrada. Cualquier adición requiere nueva versión de este diccionario, ratificación clínica y migración aprobada.

---

## 3. Correspondencia con los ejemplos obligatorios

| Solicitud | Código de trabajo | Observación |
|---|---|---|
| Procedimiento relacionado | `REL-PR-REL` | Implementable con el núcleo. |
| Procedimiento complementario | `REL-PR-COMP` | Implementable. |
| Procedimiento alternativo | `REL-PR-ALT` | **No** equivale a `interchangeable_with`. |
| Procedimiento que forma parte de otro | `REL-PR-PART` | Jerárquica parte → todo. |
| Procedimiento previo / posterior | `REL-PR-SEQ` + `context_text` con orden | Si se requiere tipación separada, ampliación `REL-PR-BEFORE`/`REL-PR-AFTER` **[P] pendiente**, no persistida. |
| Procedimiento combinado | `REL-PR-COMB` | Implementable. |
| Diagnóstico relacionado / asociado / diferencial | `REL-DX-REL` / `REL-DX-ASSOC` / `REL-DX-DIFF` | Implementables. |
| Diagnóstico más amplio / más específico | `REL-DX-BROAD` / `REL-DX-NARROW` | Único par con inversa semántica declarada. |
| Manifestación de / complicación de / causa de | `REL-DX-MANIF` / `REL-DX-COMPL` / `REL-DX-ETIOL` | «Causa de» se interpreta como etiología documentada. |
| Condición coexistente | `REL-DX-COEX` | Simétrica solo con segunda fila explícita. |
| Utilizado para diagnosticar / evaluar | `REL-PRDX-DIAG` / `REL-PRDX-EVAL` | Dirección PR → DX. |
| Utilizado para tratar | `REL-PRDX-TER` (no quirúrgica) o `REL-PRDX-TRAT` (intervencionista) | Elegir según naturaleza; no ambos por defecto. |
| Seguimiento / control | `REL-PRDX-FUP` / `REL-PRDX-CTRL` | Diferenciar longitudinalidad de verificación de respuesta. |
| Preventivo relacionado con | `REL-PRDX-PREV` | Requiere justificación. |
| Contraindicado en / no recomendado en | `REL-PRDX-CONTRA` / `REL-PRDX-NOTREC` | Juicio clínico negativo con evidencia. |
| Afecta / evalúa / interviene estructura | `REL-ANAT-AFFECT` / `REL-ANAT-EVAL` / `REL-ANAT-INTERV` | Una fila por estructura. |
| Se localiza en / región anatómica | `REL-ANAT-LOC` | «Región anatómica» se resuelve con el mismo código cuando el destino es región; no propagar agrupaciones. |
| Compromete función | `REL-FUNC-IMPAIR` | Función, no anatomía. |
| Evalúa función | `REL-FUNC-EVAL` **[P] pendiente** | Ampliación solicitada, no incluida en los 31; requiere ratificación. |
| Relacionado con insumo o dispositivo | `REL-RES-DEVICE` **[P] pendiente** | Ampliación solicitada, no incluida en los 31; requiere ratificación y perfil de dominio. |

**[P]** Las tres filas marcadas como pendientes son **etiquetas de trabajo para tipos explícitamente solicitados**, no códigos aprobados ni filas cargadas. No se inventan relaciones para completar registros.

---

## 4. Tipos heredados

**[H]** Los 15 valores CDT del `CHECK` (`alternate_benefit`, `billed_in_conjunction_with`, `concurrent_to`, `denied_as_integral`, `frequency_limitations`, `integral_to`, `interchangeable_with`, `not_paid_separately`, `not_to_be_used_with`, `paid_as_code`, `procedure_code_not_used_for`, `refer_to_details`, `referencia_literal`, `shares_frequency_limitation_with`, `used_in_combination_with`) permanecen intactos (`nomenclador_odontologico_nacional.sql:538-545`).

**[P]** Se tratan como **procedencia**, no como sustitutos de los códigos `REL-*`. La conversión a `relation_type_code` gobernado debe decidirse por acta y conservar el valor original.

---

## 5. Reglas de inversión

1. Solo `REL-DX-NARROW` ↔ `REL-DX-BROAD` tiene inversa semántica equivalente ratificable.
2. `REL-DX-COEX` y cualquier simetría declarada requieren segunda fila explícita.
3. `CatalogRepository::dedupeRelations()` puede ocultar espejos en pantalla; no autoriza borrarlos (`CatalogRepository.php:3124-3164`).
4. `inverse_relation_type` de Fase 3 es texto aditivo; no se supone sincronizado con `os_relation_type.inverse_code` (`fase1_infraestructura.sql:65`; `fase3_relaciones_mapeos.sql:73`).
