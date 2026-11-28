# Aprobación de la conciliación clínica de OFTAR-PR

**Fecha:** 2026-11-28
**Etapa:** tercera revisión — análisis y propuesta de aprobación.
**Estado:** **no aprobada para publicación**. Las 433 filas de la matriz siguen siendo `propuesta_no_publicada`.
**Convención:** `[H]` hecho verificado · `[I]` dictamen clínico documentado · `[P]` decisión propuesta sujeta a aprobación.

---

## 1. Alcance y regla de juicio

**[H]** Matriz evaluada: `docs/audit/matriz-conciliacion-clinica-oftar-pr.csv`, 433 filas (NN 2025 154, CAO 143, Regional NOA 136). Todas tienen `equivalencia_clinica_publicada=NO`, `equivalencia_facturacion_publicada=NO`, `importe_migrado=NO` y `estado=propuesta_no_publicada`.

**[I]** Criterio aplicado a las 38 filas marcadas como `equivalencia_clinica_exacta`: identidad de práctica, técnica, modalidad, lateralidad, región anatómica, alcance/sesiones y condiciones de realización (`revision-clinica-oftar-pr.md:61-70`). La coincidencia textual es solo pista.

**[I] Resultado:** **26 filas / 13 pares son sostenibles como exactas**; **12 filas / 6 pares no deben publicarse como exactas** sin corrección o degradación. El dictamen no cambia la matriz en esta etapa: solo documenta lo que debe aprobarse o corregirse antes de generar seeds.

---

## 2. Dictamen de las 38 equivalencias exactas

### 2.1 Pares que pueden aprobarse como `exact` — 13 pares / 26 filas

| Filas | Concepto OFTAR / núcleo | Contraparte | Justificación clínica verificable |
|---|---|---|---|
| L5 / L185 | NN `300107` Ejercicio ortoptico por sesión bilateral con sinoptoforo | CAO `460117` Ejercicio ortópico por sesión bilateral con sinoptóforo | Misma práctica, bilateral, por sesión y mismo equipo; solo ortografía. |
| L13 / L186 | NN `300120` Examen sensorio motor en estrabismo | CAO `460118` | Texto idéntico; sin diferencias dimensionales. |
| L25 / L339 | NN `306001` Retinografía bilateral - of | REG `305033` Retinografía / RG - Bilateral | Misma retinografía bilateral; `- of`/`RG` son sufijo y abreviatura. **[P]** confirmar editorialmente que `- of` no añade alcance. |
| L26 / L173 | NN `306002` RFG bilateral (no incluye fluoresceina, descartables, cardiologo ni anestesista) | CAO `460105` RFG bilateral (no incluye fluoresceína, descartables, cardiólogo ni anestesista) | Igual bilateralidad e iguales exclusiones. **[H]** la base escrita “con fluoresceína” es incorrecta: debe decir “no incluye fluoresceína”. |
| L27 / L203 | NN `306003` Examen de prematuros (hasta 120 días de vida, por consulta) | CAO `460137` | Condición etaria e identidad idénticas. |
| L28 / L205 | NN `306004` Ecobiometría de no contacto, de coherencia optica, unilateral | CAO `460139` | Solo diferencia de tilde; misma técnica y lateralidad. |
| L29 / L206 | NN `306005` Medida de poder corneal central unilateral | CAO `460140` | Región y lateralidad idénticas. |
| L30 / L207 | NN `306006` Recuento endotelial unilateral | CAO `460142` | Idéntica. |
| L41 / L222 | NN `306017` Test de sobrecarga hidrica | CAO `460159` Test de sobrecarga hídrica | Solo tilde. **[I]** no confundir con `300109` Curva tensional, que es `correspondencia_incierta`. |
| L42 / L223 | NN `306018` Extracción de cuerpo extraño subtarsal | CAO `460160` | Idéntica. |
| L180 / L336 | CAO `460112` Paquimetría bilateral | REG `305030` Paquimetría - Bilateral | Idéntica. |
| L181 / L351 | CAO `460113` Topografía corneal computada bilateral | REG `305046` | Idéntica. |
| L201 / L349 | CAO `460135` Angio OCT bilateral | REG `305044` OCT con angiografía (ANGIO-OCT) bilateral | Misma técnica; Regional desarrolla la sigla. |

### 2.2 Pares que no deben aprobarse como exactos — 6 pares / 12 filas

| Filas | Par evaluado | Decisión propuesta | Razón y dimensión afectada |
|---|---|---|---|
| L35 / L215 | NN `306011` ↔ CAO `460151` HD Analizer unilateral de película lagrimal | `correspondencia_incierta` o aproximada hasta revisión | Aunque el texto coincide, ambas filas tienen `ancla_clinica=sin_ancla_verificada` y `categoria_clinica_propuesta=SIN_CLASIFICAR`. **Dimensión:** ancla/clasificación. |
| L55 / L255 | NN `306031` ↔ CAO `460213` Láser femto asociado a cualquier práctica | No publicar como concepto exacto; decidir si es atributo de práctica | `SIN_CLASIFICAR`, sin ancla; la modalidad “asociada a cualquier práctica” depende del acto principal y de empaquetamiento. **Dimensión:** modalidad/alcance. |
| L138 / L284 | NN `306116` Herida perforante con lesión de córnea, esclera, iris y cristalino ↔ CAO `461302` Extracción de cuerpo extraño intracorneal | **Corregir el par**, no degradar solo | Práctica, técnica, región y alcance distintos. `[H]` el texto normalizado apunta a `CAO:461306`, no a `461302`. **[P]** par correcto: `306113 ↔ 461302`; `306116 ↔ 461306`. **Dimensión:** práctica/código. |
| L151 / L179 | NN `306129` Tonometría de aires unilateral-neumotonometría ↔ CAO `460111` Neumotonometría unilateral | Resolver destino antes de aprobar | `[H]` `candidato_textual_normalizado=CAO:460144` pero `candidato_codigo=460111`; CAO contiene ambos (`CAO CSV:25` y `:55`). **Dimensión:** modalidad/código. |
| L168 / L306 | CAO `460014` ↔ REG `425008` Realización de informes y/o resúmenes de historia clínica | `no_incorporable` o par documental, sin alta como prestación | Texto idéntico, pero es acto documental no claramente prestación oftalmológica canónica. **Dimensión:** naturaleza del concepto. |
| L194 / L310 | CAO `460127` Refractometría con autorefractómetro digital bilateral ↔ REG `305004` Autorefractometría bilateral | Degradar a aproximada/parcial | CAO declara instrumento **digital**; Regional no lo declara. **Dimensión:** instrumento/modalidad. |

**[P]** Regla de corrección: el dictamen se aplica en el futuro generador de seeds y en la matriz gobernada, nunca sobre writes directos a PostgreSQL en esta etapa.

---

## 3. Flujo editorial de revisión

**[P] Estados obligatorios y su persistencia real:**

| Estado editorial | Valor persistido | Significado |
|---|---|---|
| Pendiente | `review_status='draft'` | Creado; sin revisión asignada. |
| En revisión | `review_status='pending_review'` | Asignado; evidencia abierta. |
| Aprobado | `review_status='approved'` | Dos revisiones favorables, hash vigente. Solo entonces publicable. |
| Rechazado | `review_status='rejected'` | Decisión negativa con justificación; conservado como histórico. |
| Requiere información | `draft`/`pending_review` + nota en `os_field_review` | Falta evidencia; no equivale a aprobación. |

**[H]** `os_concept_mapping.review_status` tiene `CHECK(draft|pending_review|approved|rejected)` (`origen_catalog_engine.sql:119-134`, con default `draft` desde `fase3_relaciones_mapeos.sql:27-36`). `os_catalog_item_version.review_status` usa `draft|review|published|deprecated`.

**[P] Datos que debe registrar cada revisión:**

| Dato | Destino sugerido |
|---|---|
| Responsable | `os_governance_review` / `reviewed_by` |
| Fecha | `created_at` de la revisión y `effectiveTime` cuando la fuente lo provea |
| Justificación | `os_field_review` / `clinical_rationale` |
| Fuente de evidencia | `source_reference` con archivo, fila/línea y sistema+edición |
| Decisión | `review_status` + `os_governance_decision` |
| Vigencia | `valid_from`/`valid_to` |
| Integridad | `content_hash` vigente |
| Trazabilidad | `os_audit_log` (append-only) |

**[P]** Publicar solo pares `approved` con dos revisores distintos, evidencia trazable y hash coincidente. Las equivalencias no aprobadas permanecen como propuestas y **no** se publican como correspondencias definitivas.

---

## 4. Registros de CAO y Regional sin cobertura en el núcleo NN 2025

**[H]** Corte `fuente ∈ {CAO, REGIONAL-NOA}` y `candidato_fuente ≠ NN`: **48 filas** (25 CAO, 23 Regional); 42 con candidato cruzado CAO↔Regional y 6 sin candidato. Ninguna está publicada.

**[I] Clasificación resultado:**

| Clasificación | Filas | Criterio |
|---|---:|---|
| `atributo_concepto_existente` | 18 | Solo cambia lateralidad, rango etario, lugar/condición, “por sesión” o exclusión declarada. |
| `variante_concepto_existente` | 8 | Mismo acto con instrumento, técnica o alcance que no debe borrarse. |
| `duplicado` | 6 | Mismo acto entre CAO y Regional; no genera concepto nuevo. |
| `relacion_con_otro_concepto` | 3 | Comparten dominio, pero miden/tratan estructuras o funciones distintas. |
| `nuevo_concepto_canonico` | 3 | Técnica o modalidad ausente del núcleo; requiere aprobación. |
| `no_incorporable` | 2 | Acto documental no prestacional. |
| `pendiente_revision` | 8 | Sin ancla verificable o con pista no validada. |
| **Total** | **48** | — |

### 4.1 Candidatos a nuevo concepto canónico — no altas automáticas

| Fuente | Código | Descripción original | Justificación de la propuesta |
|---|---|---|---|
| CAO | `460106` | RG digital unilateral sin descartables | Modalidad digital, unilateralidad y exclusión declaradas; no cubiertas literalmente por el núcleo. |
| Regional | `305003` | Autofluorescencia - Bilateral | Modalidad de imagen ausente en los 154. |
| Regional | `305041` | Test sensibilidad al contraste - Bilateral | Estudio funcional distinto. |

### 4.2 Atributos de conceptos existentes — 18 registros

CAO: `460001` primera consulta; `460004` consulta a domicilio con traslado de aparatos; `460006` consulta pediátrica hasta 14 años; `460007` interconsulta en internación con equipos; `460012` consulta por vía electrónica; `460108` ecografía A o B unilateral; `460121` test de citología de impresión sin anatomopatólogo; `460129` UBM unilateral; `460138` HRT unilateral.

Regional: `425001` consulta de adultos desde 15 años; `425003` consulta oftalmopediátrica 121 días a 14 años; `425004` consulta a domicilio o otra institución; `425005` consulta en internación misma institución; `425006` consulta por vía electrónica/telemedicina; `305010` ecografía ocular/orbitaria bilateral; `305035` citología de impresión bilateral; `305042` HRT bilateral; `305048` UBM bilateral.

### 4.3 Variantes de concepto existente — 8 registros

CAO: `460114` visión cromática Fansworth/Roth; `460127` refractometría con autorefractómetro digital; `460128` FDT perimetría doble frecuencia unilateral; `460136` Angio OCT de campo amplio.
Regional: `305004` autorefractometría bilateral; `305012` ejercicios ortópticos por sesión; `305036` test de visión cromática Ishihara/Farnsworth; `305043` OCT de cámara anterior y/o posterior bilateral.

### 4.4 Duplicados, relacionados, no incorporables y pendientes

- **Duplicados (6):** CAO `460112`/`460113`/`460135` y Regional `305030`/`305046`/`305044`, respectivamente.
- **Relacionados, no equivalentes (3):** CAO `460104` RG bilateral y `460131` Aberrometría bilateral; Regional `305015` mapa endotelial corneal bilateral.
- **No incorporables (2):** CAO `460014` y Regional `425008`, informes/resúmenes de historia clínica.
- **Pendientes de revisión (8):** CAO `460008`, `460101`, `460301`, `460406`, `460328`; Regional `305016`, `305017`, `305047`.

**[P]** `460301` (chalazón, resección de lesiones de piel) debe revisarse contra la escisión palpebral del núcleo; `460328` (anillos intracorneales) tiene exclusiones complejas; `305047` (Pentacam/Galilei/Orbscan) requiere decisión sobre técnica.

---

## 5. Fuentes complementarias

**[H]** La matriz tiene `snomed_ct_referencia=NO_ASIGNADA_SIN_CODIGO_VERIFICADO` y `cie10_pcs_referencia=NO_ASIGNADA_SIN_CODIGO_VERIFICADO` en las 433 filas.

**[I]** SNOMED CT Argentina Edition no puede usarse para afirmar equivalencias de procedimientos por similitud; su refset oficial aporta mapeos a diagnósticos CIE-10 (`universo-diagnosticos-oftar-dx.md`). CIE-10-PCS es referencia de técnicas quirúrgicas y solo puede citarse cuando la correspondencia clínica sea válida y revisada.

**[P]** Mantener ambas columnas sin asignar hasta que exista evidencia verificada y revisión humana. No rellenarlas automáticamente.

---

## 6. Cierre

**[P]** La conciliación queda **pre-aprobada solo en el sentido documental**: 13 pares sostenibles y 6 pares a degradar/corregir; 48 registros de CAO/Regional clasificados con 3 candidatos a concepto nuevo. Ninguna equivalencia se publica sin `review_status='approved'`.

**[P]** Condición de aprobación final: que el responsable firme este dictamen, corrija las 12 filas señaladas y decida los 3 conceptos canónicos nuevos antes de autorizar seeds.
