# Clasificación anatómica y clínica definitiva de OFTAR

**Fecha:** 2026-11-28
**Etapa:** tercera revisión — solo análisis y documentación.
**Estado:** propuesta para aprobación. **No implementada; sin DDL ni datos nuevos.**
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta.

---

## 1. Dimensiones obligatoriamente separadas

| Dimensión | Qué identifica | Valor en OFTAR-DX | Dónde se modela |
|---|---|---|---|
| **A. Categoría clínica** | Naturaleza general del concepto | `diagnóstico` | `os_catalog_item_clinical_category` / `clinical_category` en API; `CLIN-DIAG` ya existe. |
| **B. Localización anatómica** | Estructura corporal afectada | Una o varias regiones | Atributo `ATTR-STRUCTURE` o atributo anatómico equivalente, con relaciones para multivaluado. |
| **C. Área clínica** | Campo de especialización o agrupación clínica | Glaucoma, neurooftalmología, etc. | Segundo atributo o relación_controlada; **no** `os_catalog_category`. |
| **D. Tipo de concepto** | Naturaleza del ítem | `diagnosis` en DX; `procedure`/`surgery`/`imaging` en PR | `oftar_catalog.concept_kind` / `concept_type`, ya existente. |

**[H]** `CAT-DX` es el capítulo fuente y `CLIN-DIAG` la categoría clínica por defecto de OFTAR-DX (`categorias_clinicas.sql`). La API conserva `category` y agrega `clinical_category`/`clinical_category_code` sin quitar el campo histórico (`CatalogEngineService.php`; `browse-y-categorias.md:60-63`).

**[I]** Mezclar estas dimensiones en una sola lista produciría códigos como “CLIN-GLAUCOMA” o “CLIN-RETINA”, que no son categorías del concepto sino atributos. Eso duplicaría la taxonomía y rompería la semántica del contrato.

**[P] Regla:** la categoría clínica es única por concepto; la localización anatómica y el área clínica pueden ser múltiples cuando clínicamente corresponda. No imponer uno a uno.

---

## 2. Tabla de clasificación propuesta

> Los identificadores `ANAT-*` y `AREA-*` son **valores de atributo estables propuestos**, no códigos OFTAR, no CIE-10 y no categorías `CLIN-*`. Deben aprobarse antes de usarse en seeds. Las descripciones son internacionalizables mediante los mecanismos `es-AR`/`en`/`pt-BR` existentes.

### 2.1 Localización anatómica — dimensión B

| Identificador | Nombre | Dimensión | Descripción | Ejemplos de uso |
|---|---|---|---|---|
| `ANAT-PAL` | Párpados | B · anatomía | Estructuras palpebrales y anexos cutáneos inmediatos. | H00-H02; blefaritis, chalazión. |
| `ANAT-LAG` | Aparato lagrimal | B · anatomía | Glándulas y vías lagrimales. | H04; dacriocistitis, obstrucción. |
| `ANAT-ORB` | Órbita | B · anatomía | Contenido orbitario y territorio orbitario. | H05; orbitopatía tiroidea. |
| `ANAT-CON` | Conjuntiva | B · anatomía | Membrana conjuntival. | H10-H11; conjuntivitis, pterigión. |
| `ANAT-COR` | Córnea | B · anatomía | Córnea, incluido endotelio. | H15-H18, H22; queratitis, edema. |
| `ANAT-ESCL` | Esclera | B · anatomía | Túnica escleral. | H15; escleritis, episcleritis. |
| `ANAT-CRY` | Cristalino | B · anatomía | Cristalino y cápsula. | H25-H28; catarata, subluxación. |
| `ANAT-UVE` | Úvea | B · anatomía | Iris, cuerpo ciliar y coroides como tractor uveal. | H20-H21; iridociclitis. |
| `ANAT-RET` | Retina | B · anatomía | Retina sensorial. | H30-H36; retinopatía, desprendimiento. |
| `ANAT-COROID` | Coroides | B · anatomía | Capa vascular coroidea, diferenciada de retina. | H31-H36; coroiditis, coroidopatía. |
| `ANAT-NEU` | Nervio óptico | B · anatomía / función | Nervio óptico y vía visual anterior. | H46-H47; neuritis óptica, atrofia. |
| `ANAT-MOT` | Músculos extraoculares | B · anatomía / función | Músculos extraoculares y control motor. | H49-H51; parálisis, estrabismo. |
| `ANAT-SUP` | Superficie ocular | B · anatomía funcional | Película lagrimal, córnea y conjuntiva como interfaz. | H16, H18.8; ojo seco, queratoconjuntivitis. |

### 2.2 Área clínica — dimensión C

| Identificador | Nombre | Dimensión | Descripción | Ejemplos de uso |
|---|---|---|---|---|
| `AREA-GLA` | Glaucoma | C · área clínica | Presión intraocular, ángulo y neuropatía glaucoma. | H40, H42; no es una estructura anatómica. |
| `AREA-NEURO` | Neurooftalmología | C · área clínica | Vía visual, nervio óptico y manifestaciones neurológicas. | H46-H47; neuritis, diplopía neurogénica. |
| `AREA-ESTRAB` | Estrabismo y motilidad ocular | C · área clínica | Alineación, motilidad y visión binocular. | H49-H51; esotropía, paresia. |
| `AREA-REF` | Refracción y acomodación | C · área clínica | Error refractivo y acomodación. | H52; miopía, presbicia. |
| `AREA-RET-MED` | Retina médica | C · área clínica | Retinopatías no quirúrgicas. | H30-H35; retinopatía diabética. |
| `AREA-RET-QX` | Retina quirúrgica | C · área clínica | Cirugía vitreorretiniana y desprendimiento. | H33; desprendimiento, vitrectomía. |
| `AREA-OCULOPLASTIA` | Oculoplastia | C · área clínica | Párpado, órbita y vía lagrimal. | H00-H05; reconstructivo, orbitopatía. |
| `AREA-PED` | Oftalmología pediátrica | C · área clínica | Cuadros oftalmológicos de la infancia. | H49-H51, H52; estrabismo infantil, ambliopía. |
| `AREA-TRAUMA` | Traumatología ocular | C · área clínica | Lesiones traumáticas del globo y anexos. | S05, H21.1, H26.8; fuera y dentro de H00-H59. |
| `AREA-INF` | Enfermedades infecciosas e inflamatorias | C · área clínica | Procesos infecciosos e inflamatorios oculares. | H00-H02, H10, H15-H22; conjuntivitis, uveítis. |
| `AREA-SIST` | Manifestaciones oculares de enfermedades sistémicas | C · área clínica | Afectación ocular secundaria a enfermedad general. | H36.8\*; retinopatía diabética, vasculopatía. |

**[H]** En `Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv` hay **90 códigos S05**, todos `Nodo_Final=1`; **9 códigos H36.8\***, todos finales; y **0 códigos H48** como nodo final. Los códigos S05 están fuera del rango H00-H59; H36.8\* está dentro.

**[I]** `AREA-TRAUMA` puede marcar navegación sobre códigos H dentro del núcleo, pero los códigos S05 requieren una decisión de alcance separada (ver `universo-diagnosticos-oftar-dx.md`). `AREA-SIST` es navegación aditiva sobre H36.8\*, no un nuevo diagnóstico.

---

## 3. Representación en el modelo actual

| Necesidad | Modelo existente | ¿Migración? |
|---|---|---|
| Una región principal | Atributo `ATTR-STRUCTURE` o equivalente, con valor de dominio gobernado | No: carga de datos en tablas existentes. |
| Un área clínica principal | Segundo atributo controlado | No |
| Varias regiones/áreas por diagnóstico | Relación desde `os_catalog_relation` o estructura multivaluada ya disponible | **A evaluar**: si no hay soporte limpio, ampliación futura. |
| Mantener `category` y `clinical_category` | Contrato actual de API | No |
| Derivar capítulo CIE-10 | Desde `os_catalog_identifier.value` / `external_code` | No |
| Filtros `?anatomy=` y `?clinical_area=` | Cambio en la capa de lectura, sin tocar el contrato existente | No |
| Descripciones `es-AR`/`en`/`pt-BR` | Terminología multilingüe existente | No |

**[H]** `ATTR-STRUCTURE` y `ATTR-MODALITY` están definidos en `oftar_core.sql`; `ATTR-LATERALITY` ya tiene valores sembrados. Cargar dominios es inserción de datos, no cambio estructural.

---

## 4. Reglas

1. No mezclar anatomía con especialidad: `ANAT-*` describe estructura; `AREA-*` describe práctica clínica.
2. No duplicar categorías clínicas: no crear `CLIN-*` nuevos para OFTAR.
3. No crear catálogos de catálogo para navegación: las regiones son valores de atributo, no `os_catalog`.
4. No imponer cardinalidad uno a uno: un diagnóstico puede afectar retina y coroides, o pertenecer a retina médica y enfermedad sistémica.
5. Identificadores estables y descripciones internacionalizables: los códigos de trabajo se ratifican por gobernanza; las etiquetas se traducen sin alterar el identificador.
6. Compatibilidad: la navegación secundaria es aditiva; si no hay atributos cargados, la API y el frontend siguen funcionando con el facet histórico.

---

## 5. Cierre

**[I]** La propuesta anterior cubría 8 regiones y 6 áreas; esta incorpora esclera, coroides, músculos extraoculares, superficie ocular y áreas de especialidad adicionales, sin convertirlas en categorías.

**[P]** Queda resuelto el modelo de cuatro dimensiones y la tabla de navegación. Queda pendiente de aprobación la ratificación de los identificadores `ANAT-*` / `AREA-*` y la decisión de soporte multivaluado.
