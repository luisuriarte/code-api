# Diccionario de tipos de relación de OFTAR

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** OFTAR v1.0 — Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada. (No autoriza ejecución.)
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta sujeta a aprobación explícita.
**Complemento:** `modelo-relaciones-clinicas-oftar.md` (principios, representación, gobernanza y ejemplos).

> Documento **solo de diseño**. No se ejecutó SQL, seed, migración ni consulta a PostgreSQL; las fuentes se verificaron por lectura. Los códigos de la tabla son propuestas sujetas a ratificación clínica y a la migración aditiva aprobada, no tipos ya persistidos.

---

## 1. Cómo leer la tabla

**[H]** El contenedor es `os_catalog_relation` (`sql/03_dentar/nomenclador_odontologico_nacional.sql:534-559`): `source_value VARCHAR(20) NOT NULL`, `source_field CHECK (description|procedure|notes|req)`, `relation_type` con 15 valores CDT (entre ellos `referencia_literal`) y `review_status CHECK (draft|reviewed|approved|deprecated)`. **[H]** `os_relation_type` admite `code VARCHAR(60)` y `inverse_code` FK (`sql/08_arquitectura/fase1_infraestructura.sql:60-68`); la Fase 3 añade `inverse_relation_type VARCHAR(60)` como columna aditiva (`fase3_relaciones_mapeos.sql:60-73`).

**[P]** Destino: cada código de la tabla será un `code` en `os_relation_type` con `relation_kind='clinical'` y `source='OFTAR-v1.0'`, enlazado desde `os_catalog_relation.relation_type_code` (columna nueva nullable con FK, **migración propuesta y no ejecutada**). El `relation_type` legado permanece intacto.

**[P]** Puente transitorio mientras se aprueba la migración: `relation_type='referencia_literal'`, `source_system_code='OFTAR-CLINICAL'`, `source_field='notes'`, `source_value` = código de la tabla (los 31 tienen ≤20 caracteres), `context_text` con condiciones/observaciones, `provenance` obligatoria y `review_status` con un valor real del esquema. Sin Fase 3 no hay `relation_kind` ni vigencia estructurada: el puente es insuficiente para el modelo definitivo.

**[P] Campo obligatorio:** en el puente significa `context_text`; en el modelo destino significa el campo gobernado equivalente (`clinical_rationale` o `source_reference` según la entidad). `provenance` es obligatoria **siempre**. La lateralidad nunca se escribe dentro de `source_value`: se registra como `ATTR-LATERALITY` con `OD`, `OI`, `AO` o `NA` (o `no_especificado` como decisión de gobernanza, nunca inventada).

**[P] Reglas de publicación (se combinan por fila):**

- **P1** — `review_status='approved'`, evidencia en `provenance` y `source_reference`, `content_hash` vigente de la revisión de campo/entidad gobernada y dos revisores humanos distintos; sin esto no se publica.
- **P2** — No equivalencia: `os_concept_mapping` queda reservado a sistemas externos; nunca se usa para relaciones internas OFTAR ni para PR↔DX.
- **P3** — Sin espejo, inversa ni propagación automáticos: la dirección es `source_item_id → target_item_id`; solo se admite la inversa declarada en la columna «Inversa sugerida».
- **P4** — Condiciones, lateralidad, alcance y sesiones como contexto/atributos gobernados, nunca como nuevos códigos ni duplicados del ítem.
- **P5** — `valid_from`/`valid_to` solo si Fase 3 está aplicada y la fuente declara vigencia; si no, vigencia desconocida y no inferida.
- **P6** — Sin facturación: no se usan los valores CDT `billed_in_conjunction_with`, `not_paid_separately`, `integral_to`, `denied_as_integral` ni afines para expresar una relación clínica.

**[I]** La lista canónico-obligatoria del encargo contiene **31 códigos** (7 PR-PR + 9 DX-DX + 9 PR-DX + 5 ANAT + 1 FUNC), no 36. El «~36» se interpreta como orden de magnitud: no se inventan cinco códigos adicionales para alcanzarlo.

---

## 2. Tabla única de códigos canónicos

| Código (`source_value`) | Etiqueta es-AR | Clase | Direccionalidad | Naturaleza | Inversa sugerida | Campo obligatorio | Publicación |
|---|---|---|---|---|---|---|---|
| `REL-PR-REL` | Procedimiento relacionado | A · PR-PR | PR → PR | Asociativa, no equivalente | ninguna (simetría solo con fila explícita) | `context_text` con ancla clínica/técnica | P1 · P2 · P3 · P4 |
| `REL-PR-COMP` | Procedimiento complementario | A · PR-PR | PR → PR | Asociativa (complementariedad funcional) | ninguna | `context_text` con qué complementa | P1 · P2 · P3 · P4 · P6 |
| `REL-PR-ALT` | Alternativa clínica | A · PR-PR | PR → PR | Asociativa (sustitución no equivalente) | ninguna | `context_text` + `clinical_rationale` | P1 · P2 · P3 · P4 |
| `REL-PR-PART` | Procedimiento parte de | A · PR-PR | PR → PR | Jerárquica (parte → todo) | ninguna (no hay código «contiene» canónico) | `context_text` con alcance/sesiones | P1 · P2 · P3 · P4 |
| `REL-PR-COMB` | Procedimiento en combinación | A · PR-PR | PR → PR | Asociativa (ejecución conjunta) | ninguna | `context_text` con la combinación | P1 · P2 · P3 · P4 · P6 |
| `REL-PR-REQR` | Requiere procedimiento | A · PR-PR | PR → PR | Asociativa (dependencia) | ninguna (no hay «requerido por» canónico) | `context_text` con la condición | P1 · P2 · P3 · P4 |
| `REL-PR-SEQ` | Secuencia de procedimientos | A · PR-PR | PR → PR | Asociativa (orden temporal) | ninguna (no hay «precedido por» canónico) | `context_text` con el orden | P1 · P2 · P3 · P4 |
| `REL-DX-REL` | Diagnóstico relacionado | B · DX-DX | DX → DX | Asociativa, no equivalente | ninguna | `context_text` con ancla compartida | P1 · P2 · P3 · P4 |
| `REL-DX-ASSOC` | Diagnóstico asociado | B · DX-DX | DX → DX | Asociativa (asociación clínica) | ninguna | `context_text` con la asociación | P1 · P2 · P3 · P4 |
| `REL-DX-DIFF` | Diagnóstico diferencial de | B · DX-DX | DX → DX | Asociativa (contraste) | ninguna | `context_text` con criterios de diferenciación | P1 · P2 · P3 · P4 |
| `REL-DX-NARROW` | Diagnóstico más específico que | B · DX-DX | DX → DX | Jerárquica (específico → amplio) | `REL-DX-BROAD` | `context_text` con el criterio de especificidad | P1 · P2 · P3 · P5 |
| `REL-DX-BROAD` | Diagnóstico más amplio que | B · DX-DX | DX → DX | Jerárquica (amplio → específico) | `REL-DX-NARROW` | `context_text` con el criterio de amplitud | P1 · P2 · P3 · P5 |
| `REL-DX-MANIF` | Manifestación de | B · DX-DX | DX → DX | Asociativa (no subclase) | ninguna | `context_text` + `source_reference` | P1 · P2 · P3 · P4 |
| `REL-DX-COMPL` | Complicación de | B · DX-DX | DX → DX | Asociativa (complicación) | ninguna | `context_text` con la complicación | P1 · P2 · P3 · P4 |
| `REL-DX-ETIOL` | Etiología de | B · DX-DX | DX → DX | Asociativa (causal) | ninguna | `context_text` + `source_reference` | P1 · P2 · P3 · P4 |
| `REL-DX-COEX` | Coexistencia con | B · DX-DX | DX → DX | Asociativa (simétrica declarada) | ninguna (segunda fila explícita) | `context_text` con la coexistencia | P1 · P2 · P3 · P4 |
| `REL-PRDX-DIAG` | Prestación que establece el diagnóstico | C · PR-DX | PR → DX | Asociativa (justificación diagnóstica) | ninguna | `context_text` + `clinical_rationale` | P1 · P2 · P3 · P4 |
| `REL-PRDX-EVAL` | Prestación que evalúa el diagnóstico | C · PR-DX | PR → DX | Asociativa (evaluación) | ninguna | `context_text` + `clinical_rationale` | P1 · P2 · P3 · P4 |
| `REL-PRDX-TER` | Terapia no quirúrgica para el diagnóstico | C · PR-DX | PR → DX | Asociativa (terapéutica no invasiva) | ninguna | `context_text` + `clinical_rationale` | P1 · P2 · P3 · P4 |
| `REL-PRDX-TRAT` | Tratamiento intervencionista para el diagnóstico | C · PR-DX | PR → DX | Asociativa (terapéutica invasiva) | ninguna | `context_text` + `clinical_rationale` | P1 · P2 · P3 · P4 |
| `REL-PRDX-FUP` | Seguimiento del diagnóstico | C · PR-DX | PR → DX | Asociativa (longitudinal) | ninguna | `context_text` con el esquema de seguimiento | P1 · P2 · P3 · P4 |
| `REL-PRDX-CTRL` | Control evolutivo del diagnóstico | C · PR-DX | PR → DX | Asociativa (verificación de respuesta) | ninguna | `context_text` con el criterio de control | P1 · P2 · P3 · P4 |
| `REL-PRDX-PREV` | Prevención del diagnóstico | C · PR-DX | PR → DX | Asociativa (prevención) | ninguna | `context_text` + `clinical_rationale` | P1 · P2 · P3 · P4 |
| `REL-PRDX-CONTRA` | Contraindicado en el diagnóstico | C · PR-DX | PR → DX | Asociativa (restricción) | ninguna | `context_text` + `clinical_rationale` | P1 · P2 · P3 · P4 · P6 |
| `REL-PRDX-NOTREC` | No recomendado para el diagnóstico | C · PR-DX | PR → DX | Asociativa (recomendación negativa clínica) | ninguna | `context_text` + `clinical_rationale` | P1 · P2 · P3 · P4 · P6 |
| `REL-ANAT-AFFECT` | Afecta estructura anatómica | D · ANAT | Concepto clínico → `ANAT-*` | Asociativa (afectación) | ninguna | `context_text` + `source_reference` | P1 · P2 · P3 · P4 |
| `REL-ANAT-INTERV` | Interviene sobre estructura anatómica | D · ANAT | PR → `ANAT-*` | Asociativa (intervención) | ninguna | `context_text` con vía/acceso | P1 · P2 · P3 · P4 |
| `REL-ANAT-EVAL` | Evalúa estructura anatómica | D · ANAT | PR/DX → `ANAT-*` | Asociativa (evaluación) | ninguna | `context_text` con modalidad | P1 · P2 · P3 · P4 |
| `REL-ANAT-LOC` | Localizado en estructura anatómica | D · ANAT | DX/PR → `ANAT-*` | Asociativa (localización) | ninguna | `context_text` + `ATTR-LATERALITY` | P1 · P2 · P3 · P4 |
| `REL-ANAT-PART` | Estructura anatómica parte de | D · ANAT | `ANAT-*` → `ANAT-*` | Jerárquica (parte → agrupación) | ninguna (no hay «tiene parte» canónico) | `context_text` + `source_reference` | P1 · P2 · P3 · P4 |
| `REL-FUNC-IMPAIR` | Deterioro funcional asociado | E · FUNC | DX/PR → `AREA-*` funcional | Asociativa (función) | ninguna | `context_text` + `clinical_rationale` | P1 · P2 · P3 · P4 |

**[H]** Todos los códigos de la columna 1 tienen entre 12 y 16 caracteres, por lo que caben en `source_value VARCHAR(20)` (`nomenclador_odontologico_nacional.sql:548`). **[P]** El puente usa siempre `context_text` no nulo para que la clave única de siete columnas sea efectiva (`:556-558`).

---

## 3. Reglas de inversión

1. **[P]** «Inversa sugerida» significa **equivalencia semántica de la misma arista vista desde el otro extremo**. En este diccionario solo existe el par `REL-DX-NARROW` ↔ `REL-DX-BROAD`. Todos los demás códigos tienen `ninguna` en la columna.
2. **[P]** En el destino, la inversa equivalente se declara en `os_relation_type.inverse_code` (FK a `os_relation_type.code`, `fase1_infraestructura.sql:65`); `inverse_relation_type` de Fase 3 es una columna de texto aditiva (`fase3_relaciones_mapeos.sql:73`) y **no debe suponerse sincronizada** con ese FK sin una regla gobernada.
3. **[P]** En el puente no hay `inverse_code`. Si una relación es **simétrica por decisión clínica** (`REL-DX-COEX`, o `REL-PR-REL` cuando se acuerde), se persiste una **segunda fila explícita** con los ítems invertidos, el mismo `source_value` y contexto equivalente. No se genera la fila espejo automáticamente.
4. **[H]** `CatalogRepository.php:3069,3078-3082` calcula `outgoing`/`incoming` solo para la ficha, y `dedupeRelations()` (`:3124-3164`) puede colapsar espejos en la presentación prefiriendo la fila saliente. Ese comportamiento **no convierte** la dirección de visualización en una inversa semántica ni autoriza a borrar la fila inversa declarada.
5. **[P]** Jerárquicas: direccionales (`REL-PR-PART`, `REL-DX-NARROW`, `REL-DX-BROAD`). Asociativas: no equivalentes; en particular `REL-PR-ALT` **no** es `interchangeable_with` ni `equivalent`, y `REL-PRDX-*` **nunca** es equivalencia PR↔DX.
6. **[P]** Los valores CDT heredados (`alternate_benefit`, `interchangeable_with`, `used_in_combination_with`, etc.) conservan su significado de origen. No se reutilizan como sustitutos de los códigos `REL-*` sin decisión gobernada y sin el nuevo `relation_type_code`.

---

## 4. No propagación de `ANAT-UVE` ni `ANAT-SUP`

**[H]** El rector §6 fija que `ANAT-UVE` es agrupación y `ANAT-COROID` estructura miembro; `ANAT-SUP` es agrupación funcional de córnea, conjuntiva y película lagrimal, no una estructura nueva; `ANAT-NEU` es el nervio óptico y `ANAT-MOT` los músculos extraoculares, mientras que motilidad y visión binocular son `AREA-ESTRAB`. El criterio 11 de §15.3 exige que `ANAT-UVE` no sustituya a `ANAT-COROID` y que `ANAT-SUP` no genere `ANAT-COR` + `ANAT-CON` (`especificacion-definitiva-reconstruccion-oftar.md:144,268,282`).

**[P] Reglas operativas:**

- `REL-ANAT-PART` se registra **solo para el vínculo explícitamente soportado** por `source_reference`. No se expande desde `ANAT-UVE` a `ANAT-COROID` ni desde `ANAT-SUP` a cada miembro.
- `ANAT-SUP` no genera `REL-ANAT-AFFECT`, `REL-ANAT-LOC` ni `REL-ANAT-EVAL` automáticos hacia córnea, conjuntiva o película lagrimal.
- La multi-estructura se documenta con una fila por estructura y evidencia clínica; **no se duplica el código OFTAR** ni se crean códigos nuevos por combinación anatómica (rector §15.3, criterio 12).
- `ANAT-NEU` y `ANAT-MOT` no se usan como áreas funcionales; motilidad/visión binocular se navegan con `AREA-ESTRAB` y, si hay evidencia, con `REL-FUNC-IMPAIR`.
- `AREA-SIST` sobre `H36.8*` es navegación aditiva, no una relación anatómica ni un diagnóstico duplicado (rector §3 y §15.3).

---

## 5. Cierre

**[P]** Estos 31 códigos son una propuesta cerrada: cualquier tipo adicional requiere nueva versión de este diccionario, ratificación clínica y migración aprobada. La publicación de cualquier fila exige P1 y el cumplimiento de las reglas P2–P6 que le correspondan. La gobernanza usa los cuatro valores reales de `os_catalog_relation.review_status`; `rejected` y `pending_review` no existen como valores persistibles y el rechazo se documenta como decisión sin borrar historial, con traza en `os_audit_log` append-only. Nada de lo aquí escrito autoriza ejecutar migraciones, seeds ni escrituras en PostgreSQL.
