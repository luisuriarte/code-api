# Inventario de fuentes y artefactos OFTAR

**Fecha:** 2026-11-28  
**Método:** recorrido de solo lectura del repositorio. No se crearon ni modificaron fuentes, seeds, SQL de producción ni tests.

---

## 1. Clasificación general

| Clase | Fuentes principales | Fuentes complementarias | No fuentes / solo referencia |
|---|---|---|---|
| Procedimientos (OFTAR-PR) | Nomenclador Nacional 2025 · sección OFTALMOLOGIA; CAO; Regional NOA | SNOMED CT Argentina Edition, CIE-10-PCS, LOINC, CPT (sin importar masivamente) | PMO y LOINC pueden coincidir textualmente, pero no definen códigos OFTAR |
| Diagnósticos (OFTAR-DX) | CIE-10-ES 2026, capítulo H00-H59; ICD-10-CM 2027 para huecos idiomáticos | SNOMED CT Argentina Edition como mapeo opcional | CIE-10-PCS no genera diagnósticos |

**Regla verificada:** CAO y Regional publican su numeración histórica como códigos de catálogos de origen; OFTAR-PR/OFTAR-DX publican códigos permanentes propios. No se reutilizan retirados.

---

## 2. Fuentes clínicas en disco

### 2.1 Nomenclador Nacional 2025 (núcleo de OFTAR-PR)

| Artefacto | Uso | Estado verificado |
|---|---|---|
| `tools/sources/nn/Nomenclador_Nacional_2025.sql` | Fuente original; sección OFTALMOLOGIA desde ~L1555. | Contiene valores monetarios; no se copian. |
| `sql/03_oftar/fuente_nomenclador_oftar_pr.sql` | Copia acotada y reproducible de la sección OFTALMOLOGIA. | **154 tuplas** de 6 dígitos, todas únicas. Incluye `305111` (OCT). |
| `sql/06_nomencladores/01_nn_2025.sql` | Carga general del nomenclador. | Sección oftalmológica verificada en ~L1403, L1424, L1427. |
| `sql/03_oftar/importar_nomenclador_oftar_pr.sql` | Importa la fuente acotada a OFTAR-PR. | Genera `OFT-PR-NNNNNN`, mapeo `NOMENCLADOR-AR`, lateralidad y revisión de `preferred_term`. |

### 2.2 CAO · Consejo Argentino de Oftalmología

| Artefacto | Uso | Estado verificado |
|---|---|---|
| `tools/sources/oftalmologico/Concejo_Argentino_de_Oftalmologia-cao.csv` | Fuente original. Columnas `codigo;categoria;descripcion;valor`. | **143 filas**, 143 códigos únicos, 12 categorías. |
| `tools/generate_nomencladores_oftalmologicos_sql.py` | Generador del SQL. | Cita ruta legacy `tools/sources/oftar/cao.csv` (inexistente). |
| `sql/03_oftar/nomenclador_oftalmologico_cao.sql` | Catálogo de origen `nomenclador-oftalmologico-cao-ar`. | Espejo sin precios; 143 ítems; **91 propuestas** de mapeo; contiene `DELETE FROM` en el espejo. |

Categorías literales verificadas y cantidades:

| Categoría CAO | Filas |
|---|---:|
| EXAMEN ESPECIAL | 56 |
| CONSULTA OFTALMOLÓGICA | 13 |
| OPERACIÓN DE CÓRNEA UNILATERAL | 13 |
| OPERACIÓN POR TRAUMA OCULAR UNILATERAL | 12 |
| TRATAMIENTO CON LÁSER UNILATERAL (1 sesión) | 9 |
| OPERACIÓN DE PÁRPADO UNILATERAL | 9 |
| OPERACIÓN DE VÍAS LAGRIMALES | 9 |
| OPERACIÓN DE CONJUNTIVA UNILATERAL | 7 |
| OPERACIÓN DE IRIS Y CUERPO CILIAR UNILATERAL | 5 |
| TRATAMIENTO CON LÁSER UNILATERAL (2+ sesiones) | 4 |
| MÓDULO BAJA VISIÓN BILATERAL Y LENTES DE CONTACTO | 4 |
| OPERACIÓN DE MÚSCULO EXTRAOCULAR UNILATERAL | 2 |

### 2.3 Nomenclador Oftalmológico de Referencia Regional · NOA

| Artefacto | Uso | Estado verificado |
|---|---|---|
| `tools/sources/oftalmologico/Nomenclador-Oftalmologico-Regional-Abril-2026.csv` | Fuente original. Columnas `grupo;subgrupo;codigo;descripcion;honorario_medico;gasto;valor_total`. | **136 filas**, 136 códigos únicos. |
| `sql/03_oftar/nomenclador_oftalmologico_regional.sql` | Catálogo de origen `nomenclador-oftalmologico-regional-ar`. | Espejo sin precios; 136 ítems; **0 propuestas** de mapeo por texto exacto; contiene `DELETE FROM` en el espejo. |

Grupos verificados: `PRACTICAS QUIRURGICAS` 80, `PRACTICAS Y ESTUDIOS COMPLEMENTARIOS` 47, `CONSULTAS` 9. Subgrupos quirúrgicos: córnea/refractivas 15, párpados 13, retina/vítreo 11, órbita 10, sistema lagrimal 10, cristalino 7, iris/cuerpo ciliar 7, conjuntiva 4, estrabismo 3.

### 2.4 CIE-10 / CIE-10-PCS

| Artefacto | Uso en OFTAR | Estado verificado |
|---|---|---|
| `tools/sources/cie10/Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv` | Base de diagnósticos H00-H59. | 74.260 filas totales; **2.661 H00-H59**. |
| `tools/sources/cie10/2027-code-descriptions-in-tabular-order.zip` | Textos en inglés; cubre huecos del CSV español. | 74.879 líneas en el archivo principal de descripciones; 2.677 H; **17 H exclusivos** frente al CSV ES. La cifra 23.292 es no reproducible y está retirada. |
| `tools/sources/cie10/Procedimientos_Tabla_Referencia_CIE10ES_2026.csv` | CIE-10-PCS / procedimientos. | 78.948 filas; **1.212 `08*`**. No se importan como códigos OFTAR nuevos. |
| `tools/sources/cie10/zip-file-3-2027-icd-10-pcs-codes-file.zip` | ICD-10-PCS 2027 en inglés. | Fuente cruda complementaria. |
| `tools/sources/cie10_argentina/sql/01_esquema.sql`, `02_carga.sql`, `03_postcarga.sql`, `99_verificacion.sql` | Carga OpenEMR CIE-10-ES. | No es el camino usado por el importador OFTAR; referencia de la edición. |
| `tools/php/generar_carga_cie10_pg.php` | Genera `cie10_codes` + `cie10_descriptions` en PostgreSQL. | Requiere extensión `zip` de PHP para los ZIP. |
| `tools/sources/oftalmologico/oftar/importar_cie10_dx.sql` | Importa H00-H59 a OFTAR-DX. | Usa `DISTINCT ON`, normalización, `OFT-DX-NNNNNN`, sin UVR y sin PCS. Ruta citada de forma obsoleta en tests. |

### 2.5 SNOMED CT Argentina Edition

| Artefacto | Uso en OFTAR | Estado verificado |
|---|---|---|
| `tools/sources/snomed_argentina/01_esquema.sql` … `99_verificacion.sql` | Esquema RF2 y carga canónica. | Tablas `sct2_*`, refsets, terminos preferidos. |
| `der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt` | Mapa oficial SNOMED → CIE-10. | Usado por `sql/05_maps/01_map_snomed_cie10.sql`. |
| `sql/01_schema/design.sql` | Define `snomed_concepts`, `snomed_descriptions`, `cie10_codes`, `cie10_descriptions`, `map_snomed_cie10`. | Base canónica de interoperabilidad. |
| `sql/03_oftar/oftar_core.sql` | Declara `SNOMED-CT` como sistema permitido, no obligatorio. | `oftar_catalog_mapping_rule`: obligatorio NN para PR y CIE-10 para DX; SNOMED opcional en ambos. |

**[H]** No hay importación automática de SNOMED completo ni equivalencias SNOMED inventadas para OFTAR.

---

## 3. SQL de modelo, importación y verificación

### 3.1 Modelo OFTAR

| Archivo | Contenido |
|---|---|
| `sql/03_oftar/oftar_family.sql` | `oftar_catalog`, `oftar_catalog_id()`, validador de prefijo, GRANTs. |
| `sql/03_oftar/oftar_core.sql` | Releases, categorías, terminologías, reglas de mapeo, atributos, conceptos/diagnósticos y sus versiones/terms/mapeos. |
| `sql/03_oftar/oftar_external_identity.sql` | Normalización `upper(btrim())` sin puntos/espacios/guiones; `UNIQUE (system_code, code_normalized)`; dueño por sistema. |
| `sql/03_oftar/oftar_domain_search.sql` | Dominio `oftar` y vista `v_oftar_search_catalog` (solo `approved`). |
| `sql/03_oftar/grant_oftar_search_api.sql` | Repara `GRANT SELECT ... TO origen_api` sobre la vista. |
| `sql/08_arquitectura/categorias_clinicas.sql` | Taxonomía `CLIN-*`, mapas y defaults; separa categoría del concepto de catálogo. |

### 3.2 Carga y publicación

| Archivo | Contenido |
|---|---|
| `sql/03_oftar/fuente_nomenclador_oftar_pr.sql` | Seed acotado NN 2025. |
| `sql/03_oftar/importar_nomenclador_oftar_pr.sql` | Carga OFTAR-PR y proyección `os_*`; lateralidad como atributo. |
| `sql/03_oftar/nomencladores_oftar_mapping.sql` | Tabla gobernada de propuestas CAO/Regional → OFTAR-PR. |
| `sql/03_oftar/nomenclador_oftalmologico_cao.sql` | Catálogo de origen CAO, sin precios. |
| `sql/03_oftar/nomenclador_oftalmologico_regional.sql` | Catálogo de origen Regional, sin precios. |
| `sql/03_oftar/importar_cie10_dx.sql` | Fuente CIE-10 → OFTAR-DX (en `tools/sources/...`, referenciado aquí). |
| `sql/03_oftar/sync_oftar_dx_to_os.sql` | Proyección de diagnósticos al motor canónico. |
| `sql/03_oftar/aprobar_preferred_term_oftar_dx.sql` | Aprobación de texto por campo con hash. |
| `sql/03_oftar/aprobar_mapeo_nomencladores_oftar.sql` | Publicación de solo pares aprobados; crea `os_catalog_relation`. |
| `sql/03_oftar/renombrar_codigos_oftar.sql` | Prefijos vigentes `OFT-PR`/`OFT-DX`. |
| `sql/03_oftar/uvr_ejemplo_oct_oftar_pr_u7b.sql` | Ejemplo editorial U7-B para OCT; no es conversión monetaria. |

### 3.3 Verificación (solo lectura)

`preflight_oftar_pr.sql`, `verificacion_oftar.sql`, `verificacion_oftar_cie10.sql`, `verificacion_sync_oftar_dx.sql`, `verificacion_aprobacion_oftar_dx.sql`, `verificacion_nomencladores_oftar.sql`, `verificacion_post_aprobacion_nomencladores_oftar.sql`, `verificacion_oftar_pr_carga.sql`, `revision_pares_nomencladores_oftar.sql`, `diagnostico_api_oftar.sql`, `diagnostico_busqueda_retina_oftar.sql`, `diagnostico_codigos_oftar.sql`, `diagnostico_visibilidad_oftar_dx.sql`, `comparar_bases_oftar.sql`, `comparar_bases_admin.sql`.

---

## 4. Artefactos de aplicación y contrato

| Capa | Archivos |
|---|---|
| API | `api/index.php` rutas `/v1/domains`, `/v1/search`, `/v1/catalogs`; `api/services/CatalogEngineService.php`; `api/services/TerminologySearchService.php`; `docs/api/openapi-3.1.yaml` (enum `DomainPath` con `oftar`). |
| Portal | `portal/Controllers/OftarController.php`; `portal/Views/oftar.php`; `portal/Router.php`; `portal/Repositories/CatalogRepository.php`; `portal/Repositories/CatalogReferenceRepository.php`; `portal/Repositories/UvrPublicRepository.php`; `portal/Services/BrowseService.php`; `portal/Views/browse.php`; `portal/Views/partials/browse/context.php`. |
| Web | `web/search.php`, `web/sitemap.php`, `web/docs.php`, `web/assets/js/browse-explorer.js`, `web/assets/css/app.css`, `web/assets/css/public.css`. |
| Identidad visual | `web/assets/logos/oftar-logo0.{png,svg}`, `oftar-logo1.{png,svg}` y copias en `images/logos/`. |
| i18n | `portal/translations/messages.es-AR.yaml`, `messages.en.yaml`, `messages.pt-BR.yaml`, `messages.es.yaml`. No hay columnas `name_en`/`name_pt`. |
| Servicio API / cliente | `sql/09_admin/crear_cliente_api_verificacion_oftar.sql`; `sql/10_portal_clientes/V7.002__dentar_oftar_services.{up,down,verify,verify_rollback}.sql`; `tools/rotar_clave_api.sh`. |
| Tests | `tests/run.php`: bloque OFTAR L2787-3443; adenda V7.002 L3952-4006; regresión actual en L2789 y L3424. |

---

## 5. Fuentes que no deben confundirse con OFTAR

| Fuente | Razón |
|---|---|
| `tools/sources/pmo/PMO.csv`, `pmo_2002.sql` | Coincidencias textuales con prestaciones oftalmológicas; pertenece al dominio de prestaciones, no genera códigos OFTAR. |
| `tools/sources/loinc/esAR7LinguisticVariant.csv` | Observaciones/informes; no identifica prestaciones OFTAR. |
| `tools/sources/snomed-dental/*` | Extensión odontológica; modelo para DENTAR, no fuente clínica de OFTAR. |
| `tools/sources/oftalmologico/oftar/oftar_categorias.csv` | Semilla de categorías internas, no catálogo de prestaciones. |
| `sql/08_arquitectura/catalogos_gestion_gobernada.sql` | Aplicador gobernada propuesto; ejecución en producción no confirmada. |

---

## 6. Observación final de inventario

El ecosistema OFTAR está completo y distribuido entre modelo SQL, fuentes clínicas, API, portal, i18n, assets y documentación. El inventario no encontró un motor paralelo ni una fuente oculta que reemplace a `os_catalog`; la única anomalía estructural de rutas es la ya documentada en `auditoria-oftar-actual.md` (H-01).
