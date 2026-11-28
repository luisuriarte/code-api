# Revisión clínica de OFTAR-PR

**Fecha:** 2026-11-28  
**Alcance:** segunda auditoría clínica, semántica y taxonómica, previa a aprobación de nuevos seeds.  
**Estado:** propuesta documentada. **No implementada; no publicada; no se generaron seeds definitivos.**  
**Convención:** `[H]` hecho verificado en repositorio · `[I]` inferencia clínica documentada · `[P]` propuesta sujeta a aprobación y revisión humana.

---

## 1. Fuentes analizadas individualmente

### 1.1 Nomenclador Nacional 2025 · sección OFTALMOLOGIA

**[H]** `sql/03_oftar/fuente_nomenclador_oftar_pr.sql` contiene **154 códigos únicos de seis dígitos**. Es el núcleo actual de OFTAR-PR y conserva numeración y descripción original.

**[H]** La numeración permanente vigente es `OFT-PR-NNNNNN`; los prefijos retirados no se reutilizan.

**[I]** El núcleo es quirúrgicamente incompleto frente a CAO/Regional: existen conceptos de otras fuentes con técnica, lateralidad, modalidad o condición de realización que no aparecen en los 154. Antes de declarar “procedimientos faltantes” debe decidirse si son conceptos canónicos nuevos o variantes de atributo de un concepto existente.

### 1.2 CAO · Concejo Argentino de Oftalmología

**[H]** `tools/sources/oftalmologico/Concejo_Argentino_de_Oftalmologia-cao.csv` contiene **143 códigos únicos**, con descripción literal y categoría original. Sus categorías incluyen consultas, exámenes, tratamiento con láser, cirugía de párpado, vías lagrimales, conjuntiva, iris/cuerpo ciliar, córnea y trauma ocular.

**[I]** CAO es más granular que el núcleo en varios ejes: unilateral/bilateral, por sesión frente a tratamiento completo, “no incluye” insumos, instrumento concreto y vía de abordaje. Esas diferencias no deben borrarse al crear relaciones.

### 1.3 Nomenclador Oftalmológico Regional · NOA

**[H]** `tools/sources/oftalmologico/Nomenclador-Oftalmologico-Regional-Abril-2026.csv` contiene **136 códigos únicos**, con grupos, subgrupos y descripción literal.

**[H]** La coincidencia textual exacta normalizada Regional ↔ NN es **0**. Eso no significa ausencia de relación clínica: significa que el texto no puede usarse como atajo.

**[I]** Regional aporta conceptos y variantes ausentes del núcleo: consulta neonatal y pediátrica con rangos etarios explícitos, telemedicina, DCR endoscópica/externa, implante faquico, corrección refractiva con excimer, IPL, termoterapia palpebral y microexfoliación del borde palpebral.

### 1.4 SNOMED CT Argentina Edition

**[H]** El refset `der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt` tiene 217.373 filas y columnas RF2 `id,effectiveTime,active,moduleId,refsetId,referencedComponentId,mapGroup,mapPriority,mapRule,mapAdvice,mapTarget,correlationId,mapCategoryId`.

**[I]** SNOMED CT no sustituye la numeración de OFTAR-PR ni la de los nomencladores argentinos. Su valor está en la semántica clínica y en los mapas oficiales hacia CIE-10; cualquier asignación a un procedimiento OFTAR debe estar verificada y revisada.

### 1.5 CIE-10-PCS

**[H]** `tools/sources/cie10/Procedimientos_Tabla_Referencia_CIE10ES_2026.csv` contiene **1.212 códigos `08*`** correspondientes a procedimientos oftalmológicos.

**[I]** CIE-10-PCS puede apoyar la descripción semántica de técnicas quirúrgicas, pero no debe importarse masivamente como código OFTAR-PR ni usarse para afirmar equivalencia factual sin revisión.

---

## 2. Reglas aplicadas para clasificar relaciones

Las ocho clases usadas en `matriz-conciliacion-clinica-oftar-pr.csv` son:

1. `equivalencia_clinica_exacta`
2. `equivalencia_clinica_aproximada_parcial`
3. `concepto_mas_amplio`
4. `concepto_mas_especifico`
5. `procedimientos_relacionados`
6. `procedimientos_diferentes`
7. `correspondencia_incierta`
8. `sin_correspondencia_identificada`

**[I]** Reglas de uso:

- La coincidencia textual normalizada es **solo una pista**; aparece en la columna `candidato_textual_normalizado` y en `coincidencia_textual_exacta`, nunca como base suficiente de equivalencia.
- Para equivalencia exacta se exige coincidencia de ancla clínica, modalidad, región anatómica, lateralidad, técnica, cantidad de sesiones y condiciones de realización, o una explicación explícita de por qué una diferencia no cambia el concepto.
- Lateralidad distinta impide equivalencia exacta. Si un lado no especifica lateralidad, la relación se clasifica como aproximada, más amplia o más específica según el caso.
- Cambio de instrumento o técnica (Goldmann frente a computarizada, tres espejos frente a OBI, láser frente a crioterapia, abordaje endoscópico frente a externo) impide equivalencia exacta.
- “Tratamiento completo”, “por sesión” y “2 o más sesiones” son dimensiones de alcance, no simple redacción.
- Modalidad diagnóstica, terapéutica, láser, inyección o quirúrgica se trata como eje separado.
- Condiciones “bajo anestesia general/local”, “no incluye insumos”, “en quirófano”, “por presupuesto” y rangos etarios se registran como atributos condicionales.
- Ante duda razonable se usa `correspondencia_incierta`; ante ausencia de ancla compartida se usa `sin_correspondencia_identificada`.

---

## 3. Conteos de la matriz clínica

**[H]** La matriz contiene **433 filas**: 154 del NN, 143 de CAO y 136 de Regional.

| Clase de relación | Filas |
|---|---:|
| equivalencia_clinica_exacta | 38 |
| equivalencia_clinica_aproximada_parcial | 165 |
| concepto_mas_amplio | 2 |
| concepto_mas_especifico | 1 |
| procedimientos_relacionados | 30 |
| procedimientos_diferentes | 22 |
| correspondencia_incierta | 169 |
| sin_correspondencia_identificada | 6 |

**[H]** Hay **188 filas con algún candidato textual normalizado** y **108 filas marcadas como posibles variantes de atributo**. Estos números son pistas de worklist, no equivalencias publicadas.

**[H]** El número elevado de `correspondencia_incierta` (169) es intencional: cuando no hay validación clínica explícita, la auditoría no eleva automáticamente una coincidencia de ancla a equivalencia. Las 38 equivalencias exactas son las que tienen justificación dimensional o revisión clínica documentada.

**[H]** Las filas con `equivalencia_clinica_publicada=NO`, `equivalencia_facturacion_publicada=NO`, `importe_migrado=NO` y `estado=propuesta_no_publicada` son la totalidad de la matriz.

---

## 4. Ejemplos por clase de relación

### 4.1 Equivalencia clínica exacta

| Fuente A | Fuente B | Base clínica |
|---|---|---|
| NN `300107` Ejercicio ortoptico por sesión bilateral con sinoptoforo | CAO `460117` Ejercicio ortópico por sesión bilateral con sinoptóforo | Mismo ejercicio, bilateral, por sesión y con el mismo tipo de equipo. |
| NN `306002` RFG bilateral | CAO `460105` RFG bilateral | Misma retinografía con fluoresceína, bilateral, con exclusiones equivalentes. |
| NN `306005` Medida de poder corneal central unilateral | CAO `460140` | Misma medición, lateralidad y región. |
| CAO `460014` Informes/resúmenes de historia clínica | Regional `425008` | Mismo acto documental, sin diferencia de modalidad ni alcance. |

### 4.2 Equivalencia aproximada/parcial

| Fuente A | Fuente B | Razón de la parcialidad |
|---|---|---|
| NN `306007` Exoftalmometría con Heartel | CAO `460143` Exoftalmometría con Heartel | Coincide instrumento y finalidad, pero no se documenta identidad exacta de alcance. |
| NN `306013` Electroretinograma | CAO `460154` Electroretinograma | CAO no declara el subtipo que NN distingue en otros códigos. |
| CAO `460001` Primera consulta | Regional `425001` Consulta de adultos desde 15 años | Regional acota la edad; CAO no la declara. |
| Regional `305012` Ejercicios ortópticos por sesión | CAO `460117` Ejercicio ortóptico bilateral con sinoptóforo | Regional no declara bilateralidad ni equipo. |

### 4.3 Concepto más amplio / más específico

| Concepto | Relación | Justificación |
|---|---|---|
| NN `306065` Trabeculectomía-trabeculotomía-viscocanalostomía | `concepto_mas_amplio` frente a CAO `460603` | El NN incluye trabeculotomía; CAO describe un subconjunto. |
| NN `306014` Electroretinograma multifocal | `concepto_mas_especifico` frente a CAO `460154` | Es una variedad electrofisiológica concreta, no el ERG genérico. |

### 4.4 Procedimientos relacionados

| Fuente A | Fuente B | Razón |
|---|---|---|
| NN `300122` Exoftalmología | CAO `460143` Exoftalmometría con Heartel | Comparten objetivo de medir proptosis, pero difieren en especificidad instrumental. |
| NN `306009` Test de ducciones pasivas | CAO `460123` Mirada preferencial | Pertenecen a evaluación sensorio-motriz, pero miden funciones distintas. |

### 4.5 Procedimientos diferentes — no equivalencias

| Fuente A | Fuente B | Razón clínica |
|---|---|---|
| NN `300109` Curva tensional | CAO `460159` Test de sobrecarga hídrica | **[I]** Protocolos potencialmente distintos dentro de presión ocular/glaucoma; marcado como `correspondencia_incierta`, no como equivalencia. |
| NN `306008` Test de Lancaster unilateral | CAO `460123` Mirada preferencial unilateral | Lancaster evalúa desviación/diplopía; mirada preferencial estima agudeza en pacientes no colaboradores. |
| NN `306012` Campimetría dinámica Goldmann bilateral | CAO `460103` Campimetría computarizada bilateral | Técnica cinética/manual frente a automatizada. |
| CAO `460104` RG bilateral | Regional `305032` Recuento endotelial bilateral | Retinografía frente a evaluación del endotelio corneal; comparten solo la sigla "RG". |
| CAO `460125`/`460126` Curva diaria de presión ocular | NN `300118` Dilatación lacrimonasal con intubación | Estudio funcional frente a procedimiento intervencionista de vía lagrimal. |
| CAO `460130` Fondo con lente de tres espejos | NN `306130` Oftalmoscopia binocular indirecta | Instrumento y técnica distintos. |
| CAO `460131` Aberrometría bilateral | Regional `305015` Mapa endotelial corneal bilateral | Óptica/refracción frente a morfología endotelial. |
| Regional `025203` DCR endoscópica | NN `306011` HD Analyzer de película lagrimal | Cirugía de vía lagrimal frente a estudio diagnóstico de superficie ocular. |

**[H]** Estos pares están explicados individualmente en la columna `base_clinica_de_la_relacion` de la matriz.

---

## 5. Conceptos canónicos frente a atributos/variantes

### 5.1 Deben conservarse como conceptos canónicos independientes

- **Técnicas quirúrgicas distintas:** LASIK, PRK, cirugía con excimer/femtosegundo, queratoplastia penetrante/laminar/endotelial.
- **Abordajes distintos:** DCR externa, endoscópica y con láser.
- **Estudios funcionales distintos:** curva tensional/sobrecarga hídrica, test de Lancaster, mirada preferencial, campo Goldmann/campimetría computarizada.
- **Modalidades de imagen distintas:** OCT, angio-OCT, HRT, retinografía/RFG, autofluorescencia, ecobiometría.
- **Tratamientos con condiciones distintas:** tratamiento completo frente a por sesión; anestesia general frente a local; con/sin intubación; con/sinsumos.

### 5.2 Deben tratarse como atributos/variantes cuando no cambien el acto

- Lateralidad: unilateral, bilateral, por ojo, ambos ojos.
- Unidad de facturación: por sesión, tratamiento completo, 2 o más sesiones.
- Condición: bajo anestesia general, con o sin traslado de aparatos, consultorio/quirófano, en internación, telemedicina.
- Exclusiones declaradas: “no incluye fármacos/insumos/dispositivo/descartables”.
- Rango etario cuando la esencia del acto no cambia: neonatal, pediátrico, adulto.

**[I]** La decisión de atributo debe hacerse por concepto clínico, no por conveniencia de reducir filas. Un atributo no puede borrar una técnica o una vía de abordaje.

---

## 6. Procedimientos que parecen faltar en el núcleo de 154

**[I]** Candidatos a estudio, **no altas automáticas**:

| Origen | Código original | Descripción original | Por qué requiere decisión |
|---|---|---|---|
| Regional | `425002` | Consulta oftalmoneonatologia o hasta 120 dias de vida inclusive | El NN tiene examen de prematuros hasta 120 días, pero no esta consulta neonatal etiquetada como tal. |
| Regional | `425006` | Consulta por vía electrónica o Telemedicina | Modalidad no declarada en el núcleo. |
| Regional | `025105` | IPL - Luz Pulsada Intensa - Por sesión | Terapia palpebral ausente en el núcleo. |
| Regional | `025106` | Microexfoliación del borde palpebral - Unilateral | Técnica específica ausente. |
| Regional | `025112` | Termoterapia mecánica palpebral (Ilux o lipid flow o similar) Por sesión | Modalidad terapéutica adicional. |
| Regional | `025203` | Dacriocistorrinostomía endoscópica con o sin intubación - Unilateral | Vía endoscópica versus la externa del núcleo. |
| Regional | `025601` | Cirugía refractiva con EXCIMER-Laser - Unilateral | El núcleo trata LASIK/PRK por separado; debe decidirse si excimer es contenedor o variante. |
| Regional | `025606` | Implante de lente intraocular fáquico - Unilateral | El núcleo tiene implante faquico, pero la condición “no incluye lente” debe evaluarse como atributo o concepto. |
| CAO | `460204` | YAG Láser (capsulotomía posterior 2 sesiones incluidas) - tratamiento completo | El núcleo tiene YAG/suturolisis; cambia indicación y paquete de sesiones. |
| CAO | `460301` | Chalazón, resección de lesiones de piel | Debe revisarse si ya está cubierto por escisión de lesión palpebral. |

**[H]** Estos códigos y descripciones se conservan literalmente en la matriz. **[P]** Ninguno debe convertirse en `OFT-PR-NNNNNN` sin decisión editorial sobre canonicidad, atributos y revisión de correspondencias.

---

## 7. Cierre de la revisión clínica

**[I]** El núcleo de 154 es clínicamente válido como base, pero no agota el universo de prestaciones de las fuentes argentinas. La reconstrucción debe conservar los conceptos del núcleo, enriquecer atributos y decidir explícitamente qué variantes merecen concepto canónico propio.

**[P]** Publicar solo después de: (1) revisión humana de la matriz, (2) firma de equivalencias y no equivalencias, (3) resolución de `target_code` por identificador de origen, y (4) aprobación del usuario. Esta auditoría no ejecuta seeds ni cambios de base.
