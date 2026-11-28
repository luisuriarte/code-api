# Plan de pruebas del modelo transversal de relaciones

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** plan en ejecución. Runbook operativo en `13-runbook-ejecucion-T01-T38.md`; resultados a registrar en `docs/audit/resultado-T01-T38-relaciones-transversales.md`. La verificación SQL y la regresión estática ya están conformes; T-01…T-38 con datos y API/UI quedan a la espera de su ejecución registrada.

**Convención:** `PENDIENTE` = diseñada pero no ejecutada. `LECTURA` = verificada por inspección de archivos en rondas anteriores; no equivale a ejecución.

---

## 1. Matriz de pruebas

| ID | Prueba | Datos/entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| T-01 | DENTAR-PR → DENTAR-PR | Relación clínica de procedimiento | `class=clinical`, tipo `REL-PR-*`, sin equivalencia | PENDIENTE |
| T-02 | DENTAR-PR → DENTAR-DX | `REL-PRDX-*` justificada | Dirección PR→DX; `justifying_diagnosis` no la sustituye | PENDIENTE |
| T-03 | DENTAR-PR → CDT | system `CDT-<edición>` | `class=terminological`, edición y licencia visibles; no `equivalent` automático | PENDIENTE |
| T-04 | DENTAR-PR → Nomenclador Nacional | código `01.01` | separador conservado; capítulo/normas/vigencia presentes | PENDIENTE |
| T-05 | DENTAR-PR → nomenclador institucional | dos instituciones | dos filas independientes; arancel fuera de identidad clínica | PENDIENTE |
| T-06 | DENTAR-DX → CIE-10 | edición explícita | `class=terminological`; sin subtipo genérico | PENDIENTE |
| T-07 | DENTAR-PR/DX → SNOMED CT AR | refset/versión | justificación conservada; no equivalencia por texto | PENDIENTE |
| T-08 | OFTAR-PR → OFTAR-DX | `OFT-PR-*`, `OFT-DX-*` | `class=clinical`; nunca mapeo PR↔DX | PENDIENTE |
| T-09 | OFTAR → CAO / Regional / NN | códigos inmutables | numeración original; 3 candidatos sin alta automática | PENDIENTE |
| T-10 | OFTAR-DX → CIE-10-ES 2026 | `H01.8` | edición española declarada; no norma argentina | PENDIENTE |
| T-11 | OFTAR-DX → ICD-10-CM 2027 | 17 exclusivos | referencia externa; sin traducción automática | PENDIENTE |
| T-12 | OFTAR → SNOMED CT AR | refset `447562003` | `mapping_type='related'` con justificación | PENDIENTE |
| T-13 | DENTAR-PR → OFTAR-DX justificada | evidencia documentada | visible solo si ambas familias aprueban | PENDIENTE |
| T-14 | DENTAR ↔ OFTAR sin justificación | sin evidencia | rechazo técnico; sin fila pública | PENDIENTE |
| T-15 | Equivalencia exacta | ancla + doble revisión | `equivalent`+`univocal`; texto visible | PENDIENTE |
| T-16 | Equivalencia aproximada | diferencia documentada | `related`+`approximate`; nunca `equivalent` | PENDIENTE |
| T-17 | Correspondencia parcial | jerarquía no verificada | `related`+`partial`; sin `broader`/`narrower` | PENDIENTE |
| T-18 | Correspondencia más amplia / específica | jerarquía verificada | dirección propio→externo uniforme | PENDIENTE |
| T-19 | Asociativa justificada | `clinical_rationale` | `related`, no equivalencia | PENDIENTE |
| T-20 | Sin correspondencia | sin ancla | `unmatched`+`not_mappable`; solo editorial | PENDIENTE |
| T-21 | Pendiente | `review_status='draft'` | oculto en público; sin `pending_review` | PENDIENTE |
| T-22 | Direccionalidad | fila saliente/entrante | `outgoing`/`incoming`; sin inversa automática | PENDIENTE |
| T-23 | Simetría declarada | `REL-DX-COEX` | segunda fila explícita; `dedupe` solo visual | PENDIENTE |
| T-24 | Integridad referencial | FKs de extremos | 0 huérfanos; catálogo/ítem existentes | PENDIENTE |
| T-25 | `UNIQUE` de relación | duplicado exacto | rechazo por constraint; sin `DELETE` | PENDIENTE |
| T-26 | `UNIQUE` de mapeo | mismo item+sistema+código+rol | una fila; sin reinserción de aprobada | PENDIENTE |
| T-27 | Vigencia | `valid_from > valid_to` | rechazo por CHECK | PENDIENTE |
| T-28 | Cambio de edición CDT/SNOMED/CIE-10 | nueva edición | nueva fila; identidad interna intacta; historial conservado | PENDIENTE |
| T-29 | Trazabilidad | revisión de campo | hash vigente; `untranslated` coherente | PENDIENTE |
| T-30 | Publicación | fila `draft`/`deprecated` | ausente en público; visible en editorial autorizado | PENDIENTE |
| T-31 | API transversal | `/v1/catalogs/{catalog_code}/items/{item}` DENTAR y OFTAR | `data.relations{clinical,terminological}`; `mappings`/`related_codes` intactos | PENDIENTE |
| T-32 | API sin relaciones | concepto válido | 200 con arrays vacíos | PENDIENTE |
| T-33 | Contrato sin parámetros nuevos | ambas clases en la misma respuesta | clases separadas; sin endpoints por familia; paginación histórica intacta | PENDIENTE |
| T-34 | Cabeceras | `Accept-Language` | `Vary`, `Content-Language`, `request_id` presentes | PENDIENTE |
| T-35 | UI reutilizable | fichas DENTAR y OFTAR | mismos componentes; grupos adaptados; insignias distintas | PENDIENTE |
| T-36 | Accesibilidad | tabla/diagrama | `aria-pressed`, `scope="col"`, teclado | PENDIENTE |
| T-37 | No influencia de texto | descripción similar sin ancla | 0 equivalencias creadas | PENDIENTE |
| T-38 | Arancel/cobertura | valor institucional distinto | no cambia identidad ni equivalencia | PENDIENTE |

---

## 2. Pruebas de regresión

- `php tests/run.php` ejecutado sobre el repositorio tras la implementación: **`OK: 4110 comprobaciones`**. Debe repetirse en el entorno autorizado antes de publicar; no equivale a T-01…T-38 con datos.
- Verificar que las 333 relaciones CDT y 270 del Nomenclador documentadas siguen navegables y sin huérfanos.
- Verificar que `mappings` y `related_codes` no cambian de forma.

---

## 3. Evidencia exigida

Cada prueba debe registrar: ID, fecha, entorno, consulta/request, filas afectadas, resultado, responsable y referencia de acta. La ausencia de evidencia equivale a `PENDIENTE`.

---

## 4. Límite

**[P]** No se crean datos de prueba en PostgreSQL ni se usan inserciones inválidas para forzar un constraint. Las pruebas destructivas se sustituyen por verificación de la restricción. La ejecución es `READ ONLY` y se realiza bajo el acta autorizada.
