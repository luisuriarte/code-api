# Rediseño integral de Browse Codes — Propuesta visual e implementación

**Estado: Etapa 1 aprobada; Etapa 2 implementada y verificada.**

Este documento cumple la Etapa 1 solicitada: auditar la implementación actual,
definir la nueva distribución, presentar una propuesta visual completa y
verificar su funcionamiento con los datos reales disponibles, documentando
antes las limitaciones. La sección 14 registra la implementación de la Etapa 2
sobre la vista real de Browse Codes.

Artefactos de esta etapa:

- Prototipo funcional: `docs/design/browse-codes-demo.html`
- Capturas: `docs/design/capturas/` (escritorio y móvil)
- Auditoría de frente actual: ver informe de auditoría adjunto al expediente
- Inventario de datos reales: ver informe de inventario adjunto al expediente

---

## 1. Principios rectores del rediseño

1. **Conservar identidad, cambiar composición.** Se mantienen la paleta, la
   tipografía, el logotipo y los criterios de accesibilidad del sitio. Se
   descartan los templates, tarjetas y bloques actuales de Browse.
2. **Explorador, no listado.** La página es un puesto de trabajo de consulta:
   búsqueda persistente a la izquierda, ficha contextual a la derecha.
3. **Un componente, todos los dominios.** La misma experiencia sirve para
   DENTAR, terminologías clínicas, clasificaciones diagnósticas, medicamentos,
   productos y futuros catálogos. El tratamiento lo define la clase del dato,
   no un diseño distinto por catálogo.
4. **Nada ficticio.** Todo registro, relación, versión, licencia o valor mostrado
   en el prototipo proviene de artefactos verificables del repositorio. Si el
   dato no existe, el campo se deja vacío o se muestra como "no disponible".
5. **Dominios separados.** Catálogo clínico, prestación/recurso, valoración UVR,
   financiador/cobertura y contrato/arancel son cinco responsabilidades
   distintas. La interfaz lo refleja.

---

## 2. Tokens visuales reales (sin paleta inventada)

Extraídos literalmente de `web/assets/css/app.css:1–17`:

| Token | Valor | Uso en la propuesta |
|---|---|---|
| `--ink` | `#0b2239` | Texto principal, cabecera del nodo central del diagrama |
| `--ink-soft` | `#33495e` | Texto secundario, etiquetas de tipo de catálogo |
| `--muted` | `#5b6d7e` | Metadatos, ayudas, fechas |
| `--teal` | `#0c7c86` | Selección, foco, líneas de relación, acentos |
| `--teal-dark` | `#075b63` | Códigos, enlaces, títulos de sección |
| `--mint` | `#e9f6f4` | Fila activa, pestaña activa, avisos de alcance |
| `--paper` | `#f6f9fb` | Fondo de controles y tablas |
| `--line` | `#dde6ec` | Separadores y bordes discretos |
| `--radius` | `18px` | Paneles principales |
| `--font-sans` | sistema | Texto de interfaz |
| `--font-mono` | monospace | Códigos e identificadores |

El prototipo **no introduce colores nuevos**: gradients, sombras y radios se
derivan de los mismos tokens (`--shadow-sm`, `--line`, `--mint`).

---

## 3. Auditoría técnica de partida (resumen)

### 3.1 Superficie real

- Vista principal `portal/Views/browse.php:1–162`; fragmentos
  `browse-fragment.php`, `browse-results-fragment.php` y `browse-detail.php`
  (este último **no es referenciado** por el controlador: `BrowseController.php:141–144`
  solo usa `browse`, `browse-fragment` y `browse-results-fragment`).
- Partials bajo `portal/Views/partials/browse/`: `context.php`, `results.php`,
  `detail.php`, `compare.php`, `history.php` y `detail/{concept,clinical,
  validity,trace,relations,values}.php`.
- Un único JS: `web/assets/js/browse-explorer.js:1–1096`. CSS: bloque
  `.browse-*` en `app.css:1163–1282` y `1874–2350`.
- Backend: `BrowseController.php`, `BrowseService.php`,
  `CatalogRepository.php:1–2542`, `Router.php:53–118`, `I18n.php`.

### 3.2 Composición y búsqueda

- El explorador ya reserva `minmax(0,35fr) minmax(0,65fr)` con scroll
  independiente (`app.css:1883–1905`), pero el buscador, el selector de catálogo
  y los filtros están en un formulario superior separado (`browse.php:45–117`).
  Al desplazarse por la ficha se pierde de vista la búsqueda.
- El selector solo ofrece `dentar-pr` y `dentar-dx` (`browse.php:9–12`).
- Parámetros GET: `fragment`, `q` (≤ 80), `domain`, `catalog[]`, cinco facetas,
  `validity`, `page`, `limit`, `focus`, `tab`, `rel_view`, `compare`, `history`
  (`BrowseController.php:33–56`). No hay POST ni llamadas `/v1/*` desde Browse.
- El JS aplica debounce de 350 ms, mínimo 2 caracteres y `AbortController`
  (`browse-explorer.js:867–949`), pero **los `<select>` de filtros no son
  reactivos**: requieren submit. Tampoco existe control de ordenamiento
  (`CatalogRepository.php:531–533` fija `score DESC, length(term) ASC, term ASC`).
- El repositorio unifica ramas SNOMED/CIE-10/ANMAT/LOINC/nativas/os_catalog
  (`CatalogRepository.php:698–723`) y produce `result_key` estable por dominio.
- Existen dos cachés: servidor TTL 60 s (`BrowseService.php:17–21`) y cliente
  TTL 300 s / 60 entradas (`browse-explorer.js:4–10`).

### 3.3 Ficha, relaciones e i18n

- Seis pestañas condicionales (`context.php:167–211`): `concept`, `relations`,
  `values`, `validity`, `clinical`, `trace`. La propuesta las consolida en cinco
  (**Concepto, Relaciones, Valores y valoración, Versiones, Fuentes y
  trazabilidad**) conservando la información: `validity` + `clinical` pasan a
  Concepto/Versiones según su naturaleza.
- Relaciones desde `os_concept_mapping` y `os_catalog_relation`
  (`CatalogRepository.php:2343–2451`), con tipos literales CDT y `result_key`
  navegable cuando valida (`2459–2480`). Ya hay tabla y diagrama
  (`relations.php:19–142`).
- Tres locales canónicos (`I18n.php:23–27`): `es-AR`, `en`, `pt-BR`. El bloque
  `browse.*` completo está en los tres archivos cargados
  (`messages.*.yaml:303–492`). `messages.es.yaml:246–324` es un bloque antiguo
  e incompleto que **no se carga**.
- Hay ARIA extendido (`tablist/tab/tabpanel`, `aria-current`, `aria-pressed`,
  `aria-live`, `aria-busy`, foco programático), pero **no hay patrón de teclado
  con flechas** para tablist ni para el selector móvil.

### 3.4 Problemas detectados que condicionan el rediseño

1. Variables `--dentar-*` se declaran solo bajo `.page-dentar`
   (`app.css:1345–1349`), pero Browse fija `bodyClass='page-browse'`
   (`BrowseController.php:114`): el banner DENTAR usa `var(--dentar-line)` sin
   resolver (`app.css:1827`).
2. Campos entregados por el repositorio y no renderizados: `catalog_name`,
   `kind`, `provenance`, `dialect_determined` en Concepto; `version_id`,
   `source_language`, `content_hash`, `item_status`, vigencias de versión en
   Vigencia; `uri`, `version`, `source_field`, `source_value` en Relaciones.
3. `has_more` se calcula (`BrowseService.php:100`) pero la vista usa `$pages > 1`
   para paginación y “cargar más” (`results.php:107,121`).
4. `detectHistoryStyle()` siempre devuelve `'csv'` aunque recibe dos argumentos
   (`browse-explorer.js:97–99`), y `appendResults()` no actualiza la URL ni la
   firma de resultados (`:813–865`).
5. El enlace “Documentación” apunta a `/docs`, una redirección legacy
   (`Router.php:61–65,131–139`).
6. El rate limit solo se aplica cuando `q !== ''` (`BrowseService.php:64–69`).
7. `$fakeRows` (`CatalogRepository.php:2049–2053`) es una estructura sintética
   para reutilizar helpers; **no simula registros en base de datos**.
8. `CatalogRepository::ALLOW_RESTRICTED_SELECTS = true` (`:41`) con SELECT sobre
   tablas restringidas según el propio comentario (`:35–40`).

El informe completo de auditoría, con rutas y números de línea, se entrega por
separado junto con este documento.

---

## 4. Distribución propuesta

### 4.1 Encabezado propio

- Eyebrow: terminología clínica · interoperabilidad.
- Título: **Browse Codes**.
- Descripción bilingüe conceptual: *"Explore clinical codes, procedures,
  diagnoses, products and healthcare terminology from multiple coding systems."*
- Indicadores: catálogos con datos verificados y catálogos reservados/propuestos.
- Accesos: documentación, sistemas de codificación y guía de uso.
- Buscador destacado, con búsqueda por código exacto, descripción, sinónimos,
  identificadores externos e idiomas disponibles en la fuente.

### 4.2 Columna izquierda (38 %)

Contenida en un panel con scroll propio:

1. Selector de catálogos agrupado por familias:
   catálogos propios de Origen Salud, odontológicos, terminologías clínicas,
   clasificaciones diagnósticas, medicamentos y productos, dispositivos e
   insumos, otros sistemas externos.
2. Distinción visual por naturaleza: propio, estándar internacional,
   nomenclador nacional, sistema externo, clasificación regulatoria.
3. Filtros contextuales derivados de campos reales del catálogo activo.
4. Lista compacta de resultados: código monoespacio, denominación preferida,
   catálogo, estado y tipo de concepto. Sin tarjetas grandes.
5. Contador, estado de búsqueda, paginación/carga progresiva y mensaje de
   ausencia de resultados sin registros ficticios.

**DENTAR conserva identidad destacada** mediante familia propia, etiqueta de
catálogo propio y color de acento institucional, sin ocultar otras familias.

Los códigos `DENTAR-IN`, `DENTAR-PD`, `DENTAR-EQ`, `OS-INS`, `OS-PROD`,
`OS-MED`, `OS-DIS`, `OS-EQP` y `OS-IMPL` se muestran como **reservados /
propuestos**, deshabilitados y con etiqueta explícita. Nunca como disponibles.

### 4.3 Columna derecha (62 %)

Panel dinámico con:

- Ruta de navegación con catálogo y código, y acceso al concepto anterior
  cuando se navega desde una relación.
- Cabecera con código, denominación preferida, descripción corta y datos
  fundamentales: catálogo, estado, versión, vigencia, identificador de concepto
  e idioma efectivo.
- Acciones reales: copiar código, copiar identificador, copiar ficha, compartir
  enlace y abrir documentación. No se incluyen botones sin funcionalidad.
- Aviso permanente de separación de dominios: la ficha describe el concepto
  clínico; no contiene requisitos de financiadores, autorizaciones, aranceles,
  copagos ni límites de frecuencia.
- Pestañas descritas en la sección 5.

Al seleccionar un resultado o un nodo relacionado, la ficha se actualiza sin
perder la búsqueda ni los filtros. La vista completa por ruta queda prevista
para compartir un concepto de manera independiente (Etapa 2).

---

## 5. Pestañas de la ficha

| Pestaña | Contenido | Regla de datos |
|---|---|---|
| Concepto | Identificación, definición, clasificación, capítulo, sección, especialidad, términos alternativos y observaciones | Solo campos presentes en la fuente |
| Relaciones | Tabla filtrable y diagrama limitado | Tipos literales de la fuente; nunca "equivalente" por similitud |
| Valores y valoración | Componentes UVR y total derivado | Solo prestaciones; sin UVR en DX, medicamentos ni productos |
| Versiones | Vigente, anteriores, fechas, estado, cambios | Historial real; sin fechas estimadas |
| Fuentes y trazabilidad | Origen, versión, importación, actualización, responsable, licencia, referencias | Campos vacíos si la fuente no los declara |

### 5.1 Relaciones

- **Vista tabla:** tipo literal, código navegable, descripción, sistema,
  estado de revisión y texto de contexto de la fuente.
- **Vista gráfica:** nodo central, hasta cinco nodos, profundidad 1, filtro por
  tipo y sistema. Cada nodo permite abrir su ficha y volver al anterior.
- El diagrama es una representación de relaciones **declaradas**, no una
  inferencia semántica.

### 5.2 Valoración UVR

Si existen valores verificados para una prestación, se muestra:

```
total_uvr = work_uvr + practice_expense_uvr + professional_liability_uvr
```

con versión, vigencia y fuente metodológica. La conversión monetaria se
presenta separadamente y solo si hay una tasa y una jurisdicción verificables.
Hoy el repositorio no contiene valores UVR cargados: la pestaña muestra el
estado vacío y jamás números estimados.

### 5.3 Acceso futuro a financiación

Se reserva un acceso contextual *"Consultar cobertura y condiciones de
financiación"* hacia un módulo independiente. No se implementa en este
rediseño y no se muestran obras sociales, planes ni aranceles.

---

## 6. Responsive y accesibilidad

- **Escritorio / notebook:** dos columnas, búsqueda visible, scroll
  independiente, densidad alta sin sacrificar legibilidad.
- **Tablet / móvil:** selector Results / Ficha; los resultados se muestran
  primero, la ficha abre como vista independiente y conserva filtros, término y
  posición al volver.
- Foco visible con `--teal`, roles ARIA en tablist/tab/tabpanel, `aria-current`
  en la fila activa, `aria-live` en estados y mensajes, etiquetas en todos los
  controles y navegación por teclado completa.

---

## 7. Internacionalización

La interfaz usa los tres locales canónicos vigentes: `es-AR`, `en`, `pt-BR`
(alias `es`, `pt`). Todos los textos de la interfaz —títulos, etiquetas,
filtros, pestañas, estados, mensajes, acciones y descripciones generales— se
traducen mediante los archivos `portal/translations/messages.*.yaml`. Los
códigos y las denominaciones originales de las fuentes no se traducen
artificialmente: se muestran las traducciones disponibles en los datos.

---

## 8. Rendimiento

- Debounce en el buscador.
- Resultados paginados y carga progresiva; nunca se cargan todos los conceptos
  al iniciar.
- Ficha inicial con datos esenciales; relaciones y diagrama se cargan solo al
  abrir la pestaña.
- Caché de catálogos y facetas derivadas del registro, no constantes en PHP.
- Sin consultas de relaciones de todo el catálogo.

---

## 9. Verificación con datos reales

### 9.1 Alcance de la verificación

**No fue posible consultar `origen_codes` en vivo.** Comprobaciones exactas:
`Get-Command psql` sin resultado, `where.exe psql` sin coincidencias, sin `.env`
(solo `.env.example`), sin variables `DB_*`/`PORTAL_DB_*`/`PG*`, `Test-NetConnection
127.0.0.1 -Port 5432` → `False`, y PHP 8.2.12 sin extensión `pdo_pgsql`
(`pdo_mysql` y `pdo_sqlite` sí). No se instaló nada ni se creó un `.env`.

Por lo tanto, la verificación se hizo contra **artefactos versionados y
auditados del repositorio**, no contra la base en producción.

### 9.2 Fuentes utilizadas

| Dominio | Artefacto | Uso en el demo |
|---|---|---|
| DENTAR-PR | `docs/dentar/generado/dentar-pr-cdt-2025.csv` (805 filas) | 8 conceptos con categoría, CDT-2025 y nomenclador AR |
| DENTAR-DX | `docs/dentar/generado/dentar-dx-cie10-snomed.csv` (202 filas) | 6 conceptos con CIE-10 y SCTID |
| DENTAR-AN / CL | `docs/dentar/generado/dentar-an-candidatos.csv` (624) y `dentar-cl-candidatos.csv` (218) | 4 + 4 términos es-AR con SCTID y fuente SNOMED AR 2026-08-20 |
| Relaciones | `docs/dentar/generado/dentar-cdt-relaciones-propuerto.sql` (333 relaciones) | 15 tipos literales con `source_field` y `context_text` |
| Procedencia | `docs/dentar/generado/RESUMEN.md`, `RESUMEN_DX.md`, `RESUMEN_AN_CL.md` | Licencias, versiones y reglas de derivación |

Muestras literales verificadas (ejemplos): `DNT-PR-000113 · radiografía
panorámica · CDT D0330 · Nomenclador AR 09.02.04`
(`dentar-pr-cdt-2025.csv:27`); `DNT-DX-000039 · Anodoncia · CIE-10 K00.0 ·
SNOMED 26624006` (`dentar-dx-cie10-snomed.csv:2`); `DNT-AN-000001 · estructura
de la apófisis coronoides de la mandíbula (estructura corporal) · 124002`
(`dentar-an-candidatos.csv:2`); `DNT-CL-000001 · recesión gingival (trastorno) ·
4356008` (`dentar-cl-candidatos.csv:2`). Los 15 tipos de relación se
transcriben literalmente, incluidos `referencia_literal`,
`billed_in_conjunction_with`, `denied_as_integral`, `integral_to`,
`paid_as_code`, `not_paid_separately`, `interchangeable_with`,
`frequency_limitations` y `used_in_combination_with`.

**No se usaron** `docs/dentar/plantilla-*.csv` (códigos `900001` / `900002` con
términos `Ejemplo - …`) ni los valores `4,00 / 2,00 / 1,50 / 0,50 UVR` del
`Ejemplo ilustrativo` de `README-UVR.md:116–127`, que el propio texto declara
ficticios.

### 9.3 Qué demuestra el prototipo

- Selector por familias con distinción de naturaleza (propio, internacional,
  nacional, externo) y bloqueo de catálogos sin datos.
- Filtros derivados de columnas reales (`CAT-DIAG`, `CAT-PREV`, `CAT-ENDO`,
  `CIE-10`, `SNOMED CT`, fuente SNOMED AR 2026-08-20).
- Búsqueda por código, término e identificador externo con debounce de 250 ms,
  contador y estado vacío sin registros inventados.
- Ficha con cabecera completa, cinco pestañas, acciones con funcionalidad real en
  el demo (copiar código/ID/ficha y enlace) y aviso de separación de dominios.
- Relaciones en tabla y diagrama: se navega al **otro extremo** de la relación,
  se conserva el término de búsqueda y se puede volver al concepto anterior.
  Los 19 códigos de contexto cuyo término no está verificado se muestran con la
  leyenda “Denominación no incluida en la muestra reducida”.
- UVR: estado vacío explícito en prestaciones y “no aplica” en diagnósticos,
  anatomía y clínica. No aparece ningún número de valoración.
- AN/CL: seleccionables solo dentro del prototipo y marcados como
  **NO PUBLICADO · requiere aprobación**; en la implementación real no se
  enlazarían públicamente.

### 9.4 Verificación técnica del demo

Chrome headless (`C:\Program Files\Google\Chrome\Application\chrome.exe`):

- Carga sin errores: el DOM contiene los estados renderizados y no aparecen
  `Uncaught`, `SyntaxError`, `ReferenceError` ni `TypeError`.
- Escenario `?catalog=dentar-pr&item=pr-113&tab=relations`: el título de la
  ficha es `radiografía panorámica` y la tabla muestra `referencia_literal` y
  `alternate_benefit` con su `context_text` literal.
- Escenario `?catalog=dentar-pr&item=pr-113&tab=concept&view=detail` con
  ventana 390×844: `data-view="detail"`. Durante la verificación se detectó y
  corrigió un bug real: el clic en una pestaña burbujeaba hasta `#workspace` y
  forzaba la vista móvil a `results`.
- Capturas generadas en `docs/design/capturas/`: `01-escritorio-concepto.png`,
  `02-escritorio-relaciones-tabla.png`, `03-escritorio-relaciones-grafico.png`,
  `04-escritorio-valoracion-pr.png`, `05-escritorio-valoracion-dx.png`,
  `06-movil-resultados.png`, `07-movil-ficha.png`.

### 9.5 Recuentos: documento versus artefactos

Los recuentos habituales (PR 844, DX 223, AN 624, CL 218; 805 identificadores
CDT; 333 relaciones / 303 pares / 15 tipos) están documentados en
`docs/dentar/README.md:30–34` y coinciden con el tamaño de los CSV derivados,
**pero no pudieron confirmarse en la BD**. Existe una contradicción
documental: `docs/dentar/README.md:34,55–61,226–230` afirma que AN/CL, los
identificadores y las relaciones están “cargados y verificados”, mientras los
artefactos que los generarían dicen `NO EJECUTADO`
(`dentar-an-cl-propuerto.sql:5`, `dentar-cdt-relaciones-propuerto.sql:5`) y los
resúmenes afirman que nunca se conectaron a la base. `engine.sql:268` además
indica que AN y CL quedan para una segunda etapa. Sin DSN no es posible
dirimirlo; el rediseño no asume ninguna de las dos versiones como cierta.

---

## 10. Limitaciones documentadas antes de implementar

1. **Sin acceso a la BD real.** No hay `psql`, `.env`, variables de entorno de
   BD, `pdo_pgsql` ni servicio en 5432. Toda verificación es contra artefactos
   versionados; los recuentos de la BD no son confirmables aquí.
2. **Contradicción documental sobre AN/CL.** Unas fuentes los dan por cargados
   y otros artefactos por no ejecutados. El prototipo usa sus términos solo como
   muestra y los marca NO PUBLICADO; no resuelve la contradicción.
3. **No existen datos** de DENTAR-IN/PD/EQ ni de las familias `OS-*`. Aparecen
   deshabilitados “sin datos verificados”.
4. **Fuentes externas.** SNOMED CT, CIE-10, LOINC, ANMAT y CDT tienen versión y
   licencia propias; Origen Salud no es su autor. Los `context_text` de CDT que
   mencionan planes/coberturas son texto literal de la fuente, no datos de
   financiadores de Origen Salud.
5. **Sin valoración económica.** No hay valores UVR cargados, conversiones
   monetarias ni datos de financiadores o contratos. El ejemplo ficticio de
   `README-UVR.md` quedó excluido.
6. **Relaciones no confirmables en vivo.** `os_catalog_relation` no está en
   `sql/02_catalogs/origen_catalog_engine.sql`; solo la crean artefactos
   propuestos. La UI ya soporta la tabla, pero su contenido real depende de
   aprobación y ejecución.
7. **Historial parcial.** La pestaña Versiones depende de
   `os_catalog_item_version` y de campos hoy no renderizados (`version_id`,
   `source_language`, `content_hash`, `item_status`). Donde no haya fechas
   verificadas se muestra el estado vacío.
8. **Deuda técnica detectada.** `--dentar-*` no resuelve en Browse
   (`page-browse` vs `.page-dentar`); `/docs` es legacy; no hay navegación por
   flechas en tablist; `has_more` no gobierna la paginación; `detectHistoryStyle()`
   siempre devuelve `'csv'`; hay dos cachés concurrentes y el rate limit no
   cubre búsquedas vacías. Estos puntos deben resolverse en la Etapa 2.
9. **Sin cambios de contrato.** La vista completa por ruta, la carga diferida
   real y la exportación requieren trabajo posterior y, si aplica, endpoints
   nuevos. No se modificarán contratos `/v1` existentes sin aprobación.
10. **Sin inferencias semánticas.** El diagrama se limita a relaciones
    declaradas; nunca produce equivalencias por similitud de nombres.

---

## 11. Endpoints y datos requeridos (pendientes)

| Necesidad | Origen actual | Estado |
|---|---|---|
| Dominios y catálogos | `GET /v1/domains`, `GET /v1/catalogs` (`api/index.php:230,284`) | Existen; revisar exposición de AN/CL |
| Búsqueda paginada y facetas | `GET /v1/search`, `/v1/search/{domain}` (`api/index.php:260–264`) y `CatalogRepository` | Existen; reutilizar sin romper contrato |
| Detalle por código | `GET /v1/catalogs/{catalog}/items/{code}` (`api/index.php:323`) | Existe; verificar campos reales |
| Relaciones | `CatalogRepository::itemRelations()` (`CatalogRepository.php:2396–2451`) | Consulta implementada; UI ya soporta tabla/diagrama |
| Mapeos | `GET /v1/mappings` (`api/index.php:337`) | Existe; no sustituye a relaciones literales |
| Versiones | `os_catalog_item_version`, `/v1/catalogs/{catalog}/releases` (`api/index.php:297`) | Sin vista de historial por ítem |
| Valoración UVR | `GET /v1/pricing-units` (`api/index.php:351`), módulo diseñado sin datos | No publicar hasta cargar y aprobar |
| Cobertura / contratos | Módulo futuro (`payer_*`) | Fuera de alcance |

---

## 12. Plan de implementación posterior (requiere aprobación)

- **Etapa 2:** interfaz de dos columnas, selector, filtros, resultados, ficha,
  pestañas, navegación entre relaciones y adaptación móvil.
- **Etapa 3:** integración con endpoints existentes, estados vacíos y de error,
  documentación de endpoints faltantes.
- **Etapa 4:** tabla y diagrama interactivo de relaciones, trazabilidad.
- **Etapa 5:** verificación de búsqueda exacta/parcial, selección, relaciones,
  pestañas, versiones, idiomas, escritorio, móvil, rendimiento y accesibilidad.

---

## 13. Criterios de aceptación de la Etapa 1

- [x] Prototipo con tokens reales del proyecto (`app.css:1–17`).
- [x] Demo funcional cargado sin errores en Chrome headless.
- [x] Verificación con muestras literales de datos reales (PR, DX, AN, CL y 15
      tipos de relación CDT).
- [x] Capturas de escritorio y móvil en `docs/design/capturas/`.
- [x] Documentación de limitaciones, contradicción documental y dependencias.
- [x] Sin cambios estructurales en Browse Codes ni migraciones: solo se crearon
      `docs/design/browse-codes-demo.html`, `docs/design/capturas/*` y este
      documento.
- [x] Sin commits, push ni deploy.

---

## 14. Etapa 2 — implementación verificada

La Etapa 2 se implementó reutilizando el contrato HTTP existente. No se
modificaron `BrowseController`, `BrowseService`, `CatalogRepository`, la base de
datos ni el OpenAPI ya publicado.

### 14.1 Cambios aplicados

- `portal/Views/browse.php`: encabezado propio, buscador persistente, selector
  agrupado por naturaleza de la fuente, catálogos publicados/reservados,
  filtros, resultados y ficha en dos columnas.
- `portal/Views/partials/browse/context.php`: URLs de dominio que limpian
  `catalog` al salir de odontología, URL para limpiar filtros, cinco pestañas
  consolidadas y alias de `tab=clinical` a `concept`.
- `portal/Views/partials/browse/results.php`: filas compactas, estado de
  búsqueda, selección visible, comparación y carga progresiva gobernada por
  `has_more`.
- `portal/Views/partials/browse/detail.php`: ruta de contexto, datos
  fundamentales, herramientas, aviso de alcance, comparación, historial y
  pestañas. La clínica se integró en Concepto sin duplicar definiciones ya
  visibles allí; Valores incluye la nota UVR sin importes estimados.
- `portal/Views/partials/browse/detail/relations.php`: filtros locales por tipo
  y sistema, tipos literales de la fuente, atributos para filtrado y diagrama
  limitado a 5 nodos.
- `web/assets/js/browse-explorer.js`: pestañas navegables con flechas, Home y
  End; selector móvil con teclado; filtros y dominios reactivos; corrección de
  la firma de resultados y de la URL tras “Cargar más”; cambio de vista móvil
  solo cuando el viewport es móvil; filtros de relaciones reaplicados tras
  intercambiar fragmentos.
- `web/assets/css/app.css`: bloque scoped `.browse-*` al final del archivo, con
  los tokens institucionales existentes y media queries para 900 px y 640 px.
- `portal/translations/messages.{es-AR,en,pt-BR}.yaml`: claves nuevas
  sincronizadas en los tres idiomas canónicos.

### 14.2 Verificación

- `php -l` sin errores en los cinco PHP modificados.
- `node --check web/assets/js/browse-explorer.js` sin errores.
- Tres archivos YAML parseados con 224 claves `browse.*` cada uno, sin
  diferencias de claves entre idiomas.
- `php tests/run.php` → `OK: 135 comprobaciones.`
- Render local con Chrome headless: sin errores JavaScript; columnas medidas en
  434 px y 708 px (38/62) sobre 1440 px; desplazamiento independiente de la
  columna izquierda; pestañas móviles ocultas en escritorio y visibles a
  390 px; conmutación Results ↔ Detail confirmada en móvil.
- Capturas: `docs/design/capturas/browse-stage2-desktop.png` y
  `docs/design/capturas/browse-stage2-mobile.png`.
- Fragmentos `results` y `detail` responden HTTP 200 con su marcado esperado.
- DENTAR-AN/CL, DENTAR-IN/PD/EQ y OS-* se renderizan como texto no enlazado;
  11 nodos reservados y 0 enlaces reservados en el DOM verificado.
- No aparecen registros ficticios ni importes UVR estimados.

### 14.3 Límites que permanecen

Sin conexión a `origen_codes` en el entorno de verificación, por lo que no se
pudieron confirmar en vivo recuentos, vigencias ni el detalle de conceptos. La
interfaz muestra los estados vacíos y de error del contrato actual sin inventar
resultados. Siguen pendientes las decisiones formales listadas en la sección
11 y cualquier migración, aprobación de UVR o exposición pública de AN/CL.
