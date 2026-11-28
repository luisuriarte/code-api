# Recomendaciones finales para la reconstrucción de OFTAR

**Fecha:** 2026-11-28  
**Estado:** propuesta para aprobación. **No se generaron seeds definitivos; no se ejecutaron migraciones, SQL, commit, push ni deploy.**  
**Contexto:** cierre de la segunda auditoría clínica, semántica y taxonómica. No repite los hallazgos técnicos de la primera auditoría; los da por documentados en `auditoria-oftar-actual.md`.

---

## 1. Resumen ejecutivo

**[I]** El modelo actual es apto como base: usa `os_catalog`, conserva `category`, agrega `clinical_category`, mantiene identidad externa y gobernanza por campos. El riesgo principal ya no es técnico, sino semántico: mezclar ediciones de CIE-10, tratar coincidencias textuales como equivalentes clínicas y convertir atributos en códigos nuevos.

**[P]** La reconstrucción debe aprobarse solo con tres decisiones previas:

1. Confirmar el núcleo diagnóstico: **CIE-10-ES 2026 H00-H59**.
2. Declarar los 17 códigos exclusivos como **ICD-10-CM 2027**, referencia externa separada.
3. Aceptar la matriz `matriz-conciliacion-clinica-oftar-pr.csv` como worklist de revisión humana, no como publicación automática.

---

## 2. Diez respuestas ejecutivas

### 2.1 ¿Qué conservar y qué corregir de OFTAR-PR?

**Conservar:** los 154 códigos del Nomenclador Nacional 2025 con numeración y descripción originales; los prefijos `OFT-PR-`; las categorías históricas `CONSULT, EXAM, DIAG, IMG, TER, CIR, OCUL, LAGR`; el contrato `category` + `clinical_category`; la lateralidad como atributo.

**Corregir:** no publicar coincidencias textuales como equivalencias clínicas; resolver el destino de mapeos por `os_catalog_identifier` (hallazgo técnico H-02 ya documentado); decidir qué variantes de CAO/Regional son atributos y cuáles conceptos nuevos.

### 2.2 ¿Qué procedimientos faltan?

**[I]** Candidatos a estudio, no altas automáticas: consulta neonatal/telemedicina de Regional, IPL, microexfoliación palpebral, termoterapia mecánica, DCR endoscópica, cirugía refractiva con excimer, implante faquico con exclusión de lente, YAG con paquete de dos sesiones y chalazión/resección de lesión cutánea.

**[H]** Códigos y descripciones originales están en la matriz clínica. **[P]** Cada uno requiere decisión de canonicidad y revisión antes de recibir `OFT-PR-NNNNNN`.

### 2.3 ¿Qué códigos son equivalentes y cuáles no?

**[H]** La matriz tiene 433 filas: 38 exactas propuestas, 165 aproximadas/parciales, 2 más amplios, 1 más específico, 30 relacionados, 22 diferentes, 169 inciertos y 6 sin correspondencia identificada.

**[I]** Son **propuestas de trabajo**, no equivalencias publicadas. Ejemplos de no equivalencia: `306008` Lancaster frente a `460123` mirada preferencial; `306012` Goldmann frente a `460103` computarizada; `460104` RG frente a `305032` recuento endotelial; `460125/460126` curva de presión frente a `300118` dilatación lacrimonasal; DCR endoscópica frente a HD Analyzer.

### 2.4 ¿Qué edición de CIE-10 es núcleo?

**[P]** **CIE-10-ES 2026**, H00-H59, 2.661 códigos, texto español. Es la base para mercado argentino. CIE-10 de referencia para Argentina debe declarar edición y procedencia concretas cuando se use.

### 2.5 ¿Cómo tratar los códigos exclusivos ICD-10-CM?

**[P]** Los 17 códigos quedan identificados como **ICD-10-CM 2027**, con descripción original inglesa y sin traducción inventada. No se incorporan automáticamente al conjunto CIE-10-ES. Pueden conservarse como referencia externa con identidad explícita de sistema, versión, release y procedencia.

### 2.6 ¿Cómo incorporar SNOMED CT?

**[P]** Como sistema complementario de semántica y mapas, usando SNOMED CT Argentina Edition 20260820 y sus datos RF2 (`effectiveTime`, `moduleId`, `refsetId`, `mapTarget`). No sustituye CIE-10-ES, no genera códigos OFTAR por similitud de texto y no se publica sin revisión humana.

### 2.7 ¿Cómo organizar los diagnósticos por anatomía?

**[P]** Mantener `CAT-DX` y `CLIN-DIAG`; derivar el prefijo CIE-10 del identificador externo; agregar navegación secundaria por atributos de región anatómica y área clínica. No crear catálogos ni códigos `CLIN-*` por región. Evaluar explícitamente párpados/lagrimal, conjuntiva, córnea, cristalino, úvea, retina/coroides, glaucoma, nervio óptico, motilidad, órbita, refracción/visión, traumatismos y manifestaciones sistémicas.

### 2.8 ¿Qué cambios de modelo hacen falta?

**[I]** El modelo actual ya cubre catálogo, categoría clínica, identificador externo, mapeos y revisión. falta **gobernanza más estricta**, no un motor paralelo:

- distinguir edición/versión/release/procedencia de forma estructurada;
- usar `os_mapping_metadata` para parcial, aproximado, amplio, específico y no mappable;
- conservar permanentemente `category` y agregar solo atributos/relaciones para anatomía y área clínica.

### 2.9 ¿Qué puede implementarse sin migraciones?

| Acción | Vía |
|---|---|
| Mantener `category` y `clinical_category` | Contrato actual de la API |
| Cargar dominio de atributos anatómicos y modalidad | Filas en tablas existentes |
| Publicar pares revisados como `referencia_literal` o mapeos gobernados | `os_catalog_relation`, `os_concept_mapping`, `os_field_review` |
| Clasificar regiones/áreas DX | `os_catalog_source_attribute` / atributos existentes |
| Derivar prefijo CIE-10 | Desde `os_catalog_identifier.value` |
| Resolver destinos CAO/Regional | Por `os_catalog_identifier`, sin DDL |
| Filtros por anatomía/área | Cambio de código de lectura de la API |

**[I]** Sin migración no significa sin revisión: requiere evidencia y dos aprobaciones.

### 2.10 ¿Qué requiere cambios estructurales?

| Necesidad | Cambio |
|---|---|
| Distinción explícita de `edition/version/release/provenance` en identidad externa | Extensión de esquema o tabla de identidad versionada |
| Múltiples regiones/áreas por diagnóstico de forma nativa | Relación multivaluada o columna dedicada |
| Rol `diagnosis_concept` en `os_concept_mapping.relationship_role` | Ampliar `CHECK` |
| `not_mappable` directo en `oftar_diagnosis_mapping.mapping_type` | Ampliar `CHECK` |
| Nuevos tipos semánticos de `relation_type` | Solo si no pueden representarse con `os_concept_mapping` |

**[P]** Evitar los tres últimos mientras las alternativas sin DDL sean suficientes.

---

## 3. Secuencia de aprobación propuesta

1. **Aprobación del usuario** de esta propuesta y de los documentos de segunda auditoría.
2. Revisión humana de la matriz clínica; firma de pares exactos, parciales y no equivalentes.
3. Decisión formal sobre los 17 códigos ICD-10-CM 2027.
4. Decisión sobre conceptos canónicos nuevos frente a atributos.
5. Solo entonces preparar seeds y verificaciones para que el usuario ejecute SQL y deploy.

---

## 4. Entregables de la segunda auditoría

- `revision-clinica-oftar-pr.md`
- `revision-clinica-oftar-dx.md`
- `matriz-conciliacion-clinica-oftar-pr.csv`
- `clasificacion-anatomica-oftar-dx.md`
- `politica-sistemas-identificacion-oftar.md`
- `taxonomia-oftar-propuesta.md`
- `recomendaciones-finales-reconstruccion-oftar.md` (este documento)

---

## 5. Cierre

**[I]** La reconstrucción no necesita un nuevo motor ni una nueva nomenclatura. Necesita decisiones clínicas explícitas, identidad por edición y release, y gobernanza que impida publicar equivalencias no revisadas.

**[P]** Este informe cierra la segunda auditoría como propuesta. No autoriza seeds, migraciones ni publicación.
