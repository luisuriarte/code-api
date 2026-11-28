# Hallazgo — visibilidad de los nomencladores oftalmológicos y sus relaciones

**Fecha:** 2026-11-28 · **Entorno:** producción `origen_codes` · **Estado:** diagnóstico ejecutado por el responsable; salida `/tmp/visibilidad_catalogos_oftar.log`.

**Convención:** `[H]` verificado en repositorio/documentación o en la salida del responsable · `[I]` inferencia · `[P]` propuesta.

---

## 1. Lo que el código ya permite

`[H]` Ambos nomencladores están en la whitelist del explorador (`portal/Repositories/CatalogRepository.php:42-52`) y en la lista de opciones de `browse.php:18-19`, con familias `oftar` y `nomenclador`. El `grep` en el VPS confirma que esas dos líneas están desplegadas. No hace falta agregarlos al código.

`[H]` En Browse Codes las opciones de catálogo se ocultan hasta que se elige una familia (`browse.php:88-103`, `web/assets/js/browse-explorer.js:980-986`). Para ver CAO y Regional hay que seleccionar familia **`oftar`** o **`nomenclador`** en el filtro `family`. Sin familia, el desplegable muestra dominios (SNOMED, CIE-10…), no catálogos.

`[H]` `GET /v1/catalogs` (`api/services/CatalogEngineService.php:27-58`) devuelve **todos** los catálogos con `is_active = TRUE`; no aplica whitelist de familia. Requiere API Key (`X-API-Key` o `Authorization: Bearer`).

`[H]` `GET /v1/catalogs/{code}/items` exige release `status='published'` y versión vigente (`:137-146`). `/v1/search?domains=oftar` usa `v_oftar_search_catalog`, que exige `cat.family_code='oftar'`, `cat.product_role='catalog'`, `cat.is_active=TRUE`, `item.status='active'` y `ver.review_status='approved'` (`sql/03_oftar/oftar_domain_search.sql:45-80`). El dominio `oftar` **no** está en `DEFAULT_DOMAINS`; hay que pedirlo explícitamente.

`[H]` `relationsForItem()` (`CatalogEngineService.php:824-947`) consulta `os_catalog_relation` con `source_item_id = :item OR target_item_id = :item`, filtra `review_status='approved'` y devuelve `direction` `outgoing`/`incoming`. La bidireccionalidad ya está soportada; la ficha del portal reutiliza el mismo contrato.

---

## 2. Resultado observado en producción

| Capa | Resultado | Conclusión |
|---|---|---|
| `os_catalog` | 4 filas activas: CAO 143, Regional 136, `oftar-pr` 154, `oftar-dx` 2678 ítems activos. | Los catálogos existen y están activos. |
| Releases | `NOM-CAO-AR-v1` y `NOM-OFTAL-REG-v1`, ambas `published`, `valid_from=2026-11-23`. | Publicación de origen conforme. |
| Versiones y `preferred_term` | 143 y 136 en `approved`. | La aprobación de texto ya se ejecutó. |
| `v_oftar_search_catalog` | 4 catálogos con filas (143 / 136 / 154 / 2678). | La visibilidad de datos está resuelta. |
| Permisos de la vista | `SELECT` para `origen_api`, `origen_admin` y `origen_med`. | No hay problema de GRANT. |
| `os_oftar_nomenclador_match` | CAO: 1 `approved`, 90 `proposed`. Regional: 0. | No hay masa crítica de pares aprobados. |
| H-02 | 91 `target_no_resuelve`, 0 `target_resuelve`. | Ningún `target_code` coincide con `permanent_code` de `oftar-pr`. |
| `os_catalog_relation` | 0 filas entre `oftar-pr` y los nomencladores, en ambos sentidos. | No hay relaciones publicadas. |
| `os_concept_mapping` | 0 filas para `NOMENCLADOR-CAO-AR` / `NOMENCLADOR-OFTAL-REG-AR`. | No hay mapeos terminológicos publicados. |
| curl sin credenciales | `401 unauthorized` en `/v1/catalogs` y `/v1/search`. | Falló la autenticación, no la consulta. |
| `git log` en el VPS | `not a git repository`. | El VPS no tiene `.git`; no afecta a `git apply`, sí a `git log`. |

`[H]` El único par aprobado no resuelve destino por `permanent_code`; H-02 está confirmado con datos reales. Por eso `aprobar_mapeo_nomencladores_oftar.sql`, aun ejecutado ahora, insertaría **0 relaciones**: la fila aprobada se descarta en el `JOIN` de `aprobar_mapeo_nomencladores_oftar.sql:163-165`.

`[H]` Las matrices clínicas `matriz-conciliacion-clinica-oftar-pr.csv` y `matriz-equivalencias-oftar-pr.csv` están íntegramente como `propuesta_no_publicada` (`verificacion-oftar-pr.md:14`). Publicar equivalencias clínicas por coincidencia textual está prohibido por el acta de ejecución.

---

## 3. Causa raíz

`[H]` **Browser:** no es falta de datos ni de código; es el comportamiento del filtro. Sin familia seleccionada, las opciones de catálogo están ocultas por diseño.

`[H]` **API:** las consultas se hicieron sin API Key. La respuesta `401` impide evaluar el contenido; hay que repetir con `Authorization: Bearer $API_KEY`.

`[H]` **Relaciones:** hay 1 par aprobado y 90 propuestos en CAO, 0 en Regional; el par aprobado no resuelve a `OFT-PR-NNNNNN` (H-02). El script de aprobación filtra `review_status='approved'` y hace `JOIN` por `permanent_code`, así que no genera enlaces. No hay equivalencias clínicas ratificadas que publicar.

---

## 4. Verificación complementaria en el VPS

```bash
cd /var/www/html/origen.ar/code-api

sudo -u postgres psql -X -v ON_ERROR_STOP=1 -P pager=off -d origen_codes \
  -f sql/03_oftar/verificacion_visibilidad_catalogos_oftar.sql \
  2>&1 | tee /tmp/visibilidad_catalogos_oftar_v2.log

read -rsp 'API_KEY: ' API_KEY; export API_KEY; echo
BASE='https://api.origen.ar/v1'

curl -s -H "Authorization: Bearer $API_KEY" "$BASE/catalogs" \
  | grep -o 'nomenclador-oftalmologico-[a-z-]*' | sort -u

curl -s -H "Authorization: Bearer $API_KEY" \
  "$BASE/search?domains=oftar&q=OFT" | head -c 2000

curl -s -H "Authorization: Bearer $API_KEY" \
  "$BASE/catalogs/nomenclador-oftalmologico-cao-ar/items?limit=1"
```

En el browser: elegir familia **`oftar`** y luego marcar los catálogos `NOM-CAO-AR` y `NOM-OFTAL-REG` en el desplegable «Código».

---

## 5. Criterio de cierre

| Condición confirmada | Acción |
|---|---|
| Catálogos activos, versiones aprobadas, vista con filas | **[H] Cerrado**: no requiere carga ni aprobación de texto. |
| Filtro `family` sin seleccionar | **[H] Cerrado**: es comportamiento de UI; seleccionar `oftar` o `nomenclador`. |
| curl sin API Key | **[H] Cerrado**: repetir con credencial; no es fallo de datos. |
| 1 par `approved`, 90 `proposed`, 0 en Regional | **[P]** Revisión humana gobernada antes de aprobar más pares; el agente no aprueba correspondencias. |
| H-02 confirmado (91/91 sin resolver) | **[P]** Corregir la resolución de destino por `os_catalog_identifier` (`system_name='NOMENCLADOR-AR'`) antes de publicar enlaces; repetir verificación. |
| Relaciones 0 en ambos sentidos | Conforme al estado actual: no se publican relaciones sin pares aprobados resolubles. No marcar `PASS`. |
| Equivalencias clínicas de las matrices | **[P]** Permanecen `propuesta_no_publicada` hasta acta clínica firmada. |

`[P]` Ninguna acción de escritura se ejecutó. La decisión de publicación gobernada sigue limitada al sostén técnico registrado en `docs/audit/acta-publicacion-relaciones-transversales.md`.
