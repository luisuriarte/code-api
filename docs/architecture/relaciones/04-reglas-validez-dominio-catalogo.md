# Reglas de validez por dominio, familia y catálogo

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** perfiles propuestos. (No autoriza relaciones nuevas ni publicación.)

---

## 1. Principio

**[P]** Que el esquema técnicamente admita una fila no la hace clínicamente válida. Cada perfil declara qué relaciones pueden existir, con qué extremos, con qué sistemas externos y bajo qué revisión.

**[H]** `os_catalog` dispone de `domain_type` con valores `dental|medical|biochemical|rehabilitation|mental_health|pharma|terminology`, además de `family_code` y `product_role` (`origen_catalog_engine.sql:12-40`). `os_domain_registry` enumera dominios expuestos (`fase1_infraestructura.sql:25-38`).

---

## 2. Perfil DENTAR

| Catálogo | Dominio | Destinos válidos | Sistemas pertinentes | Reglas |
|---|---|---|---|---|
| `dentar-pr` | `dental` | `dentar-pr`, `dentar-dx`, `dentar-an`, `dentar-cl`; con justificación, otras familias | CDT y ediciones, Nomenclador Nacional, nomencladores provinciales/regionales/institucionales, SNOMED CT AR | `DNT-PR-NNNNNN` es identidad permanente; códigos externos nunca maestros; conservar `01.01`. |
| `dentar-dx` | `dental` | `dentar-dx`, `dentar-pr` | CIE-10 y ediciones identificadas, SNOMED CT AR | Sin UVR ni facturación; no equivalencia por texto similar. |
| `dentar-an` | `dental` | PR/DX → ANAT; ANAT → ANAT | fuente anatómica documentada | Sin propagación automática desde agrupaciones. |
| `dentar-cl` | `dental` | PR/DX → CL | fuente clínica documentada | Publicación según decisión editorial (hoy «No publicado» en el acta documental). |

**[H]** El acta arquitectónica documenta `DNT-PR-NNNNNN`, `DNT-DX-NNNNNN`, `DNT-AN-NNNNNN`, `DNT-CL-NNNNNN` y 333 relaciones CDT (`propuesta-arquitectura-catalogos-sanitarios.md:440-456`). **[P]** Esa evidencia es de solo lectura; este documento no modifica esos datos.

### 2.1 Validez específica de fuentes DENTAR

- **CDT:** corresponde a `DENTAR-PR`; a `DENTAR-DX` solo con justificación; a SNOMED cuando corresponda. Registrar edición/año, categoría/subcategoría y cambios entre ediciones. No asumir equivalencia exacta.
- **Nomenclador Nacional:** corresponde a `DENTAR-PR`. Verificar documentalmente fuente, edición y vigencia antes de incorporarlo. Conservar separadores y normas particulares.
- **Nomencladores institucionales:** cada institución conserva identidad independiente. No mezclar sus códigos con `NOMENCLADOR-AR`. Aranceles y cobertura se registran aparte de la identidad clínica.
- **CIE-10 / SNOMED:** pertinentes para `DENTAR-DX` y, SNOMED, también para `DENTAR-PR`; siempre con edición y licencia.
- **Brechas verificadas [H]:** sin licencia ADA en los artefactos CDT del repositorio, sin diff multi-edición, sin vigencia normativa declarada en el Nomenclador Nacional y sin artefactos odontológicos provinciales/regionales/institucionales. **[P]** No se inventan esos datos; bloquean la publicación hasta acta documental.

---

## 3. Perfil OFTAR

| Catálogo | Dominio | Destinos válidos | Sistemas pertinentes | Reglas |
|---|---|---|---|---|
| `oftar-pr` | `medical` (`family_code='oftar'`) | `oftar-pr`, `oftar-dx`; con justificación, DENTAR u otras familias | Nomenclador Nacional, CAO, Regional NOA, SNOMED CT AR | `OFT-PR-NNNNNN` es maestro; 3 candidatos sin alta automática; RFG sin fluoresceína. |
| `oftar-dx` | `medical` (`family_code='oftar'`) | `oftar-dx`, `oftar-pr` | CIE-10-ES 2026, ICD-10-CM 2027, SNOMED CT AR | 2.661 ES frente a unión 2.678 condicional; CIE-10-ES no norma argentina; CM referencia. |

**[H]** `oftar` es dominio funcional de búsqueda y `family_code`, no valor de `domain_type` (`arquitectura-tecnica-oftar-final.md:48`; `origen_catalog_engine.sql:18-19`).

---

## 4. Perfiles futuros

| Familia | `domain_type` propuesto | Observación |
|---|---|---|
| NN-PMO | `medical` o `terminology` según rol confirmado | **[I]** requiere acta; no asignar automáticamente. |
| NBU | `medical` | **[I]** pendiente de confirmación documental. |
| NHPGD | `pharma` o `terminology` | **[I]** pendiente de confirmación. |
| ANDIS | `medical` | **[I]** pendiente de confirmación. |
| KINESIOLOGIA | `rehabilitation` | **[I]** coherente con el `CHECK` existente; pendiente de ratificación. |
| SALUD_MENTAL | `mental_health` | **[I]** coherente con el `CHECK` existente; pendiente de ratificación. |

**[P]** No se crean dominios nuevos ni valores de `domain_type` nuevos sin migración aprobada. Las familias se incorporan como datos con `family_code` y catálogos con `product_role='catalog'`.

---

## 5. Matriz de combinaciones

| Origen → destino | Válido | Condición |
|---|---|---|
| DENTAR-PR → DENTAR-DX | Sí | Relación clínica, no mapeo. |
| DENTAR-PR → CDT | Sí | Correspondencia terminológica; sistema+edición+licencia. |
| DENTAR-DX → CIE-10 | Sí | Edición identificada. |
| DENTAR → SNOMED CT AR | Sí | Refset/versión y justificación. |
| OFTAR-PR → OFTAR-DX | Sí | Relación clínica, nunca equivalencia PR↔DX. |
| OFTAR → CAO / Nomenclador Nacional | Sí | Correspondencia; códigos inmutables. |
| OFTAR → CIE-10-ES / ICD-10-CM | Sí | Edición declarada; CM como referencia externa. |
| DENTAR-PR → OFTAR-DX | Condicional | Justificación clínica documentada y revisión de ambas familias. |
| Cualquier concepto → cualquier sistema externo | No | Solo sistemas pertinentes al perfil. |
| Similitud textual → equivalencia | No | Requiere ancla clínica y aprobación. |
| Valor arancelario → equivalencia | No | Plano económico separado. |

---

## 6. Verificación antes de crear una fila

1. ¿Existen ambos extremos como ítems activos o como sistema+edición registrados?
2. ¿El tipo está en el diccionario y es válido para ambos perfiles?
3. ¿La dirección y la inversa están declaradas sin automatismo?
4. ¿Hay `context_text`/`clinical_rationale`, `provenance` y fuente documental?
5. ¿La revisión exigida está `approved` y la vigencia es coherente?
6. ¿Se conserva el código original sin normalizar?
7. ¿La publicación respeta la distinción Clínica vs Terminológica?

**[P]** Si alguna respuesta es negativa, la fila queda en vista editorial o no se crea. Nunca se completa con datos inventados.
