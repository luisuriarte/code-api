# Runbook de ejecución T-01…T-38

**Fecha:** 2026-11-28 · **Versión:** 1.0
**Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** preparado para ejecución por el responsable en el VPS `/var/www/html/origen.ar/code-api`.

---

## 1. Reglas

- No crear datos de prueba en producción.
- No ejecutar inserciones, actualizaciones ni borrados para forzar una prueba; las pruebas de constraint se verifican por existencia de la restricción.
- `SIN_DATOS` significa que el control es correcto pero no hay filas ratificadas para ese escenario. No equivale a `FAIL`.
- `FAIL` bloquea la publicación hasta corregirse.
- Guardar las salidas en `/tmp` y adjuntarlas al expediente.

---

## 2. Parte SQL — T-01…T-30, T-37, T-38

```bash
cd /var/www/html/origen.ar/code-api

sudo -u postgres psql -X -v ON_ERROR_STOP=1 -P pager=off -d origen_codes \
  -f sql/08_arquitectura/verificacion_T01_T38_relaciones_transversales.sql \
  2>&1 | tee /tmp/T01_T38_sql.log
```

El script es `BEGIN READ ONLY` / `ROLLBACK`, no escribe y devuelve una fila por prueba con `prueba`, `estado` y `detalle`.

Interpretación inicial esperada con el estado actual de datos:

- `PASS`: controles estructurales — T-14, T-21, T-22, T-24, T-25, T-26, T-27, T-30, T-37, T-38.
- `SIN_DATOS`: escenarios clínicos sin filas ratificadas — T-01…T-13, T-15…T-20, T-23, T-28, T-29.
- `VERIFICAR_API`: T-31…T-34.
- `VERIFICAR_UI`: T-35, T-36.

Si aparece `FAIL`, detener y corregir antes de continuar.

---

## 3. Parte API — T-31…T-34

Definir la clave en el shell sin imprimirla ni guardarla en el repositorio:

```bash
read -rsp 'API_KEY: ' API_KEY; export API_KEY; echo
BASE='https://api.origen.ar/v1'
```

### T-31: contrato aditivo en DENTAR y OFTAR

```bash
ITEM_DENTAR=$(curl -s -H "Authorization: Bearer $API_KEY" \
  "$BASE/catalogs/dentar-pr/items?limit=1" \
  | php -r '$d=json_decode(stream_get_contents(STDIN),true); echo $d["data"][0]["permanent_code"] ?? "";')

ITEM_OFTAR=$(curl -s -H "Authorization: Bearer $API_KEY" \
  "$BASE/catalogs/oftar-pr/items?limit=1" \
  | php -r '$d=json_decode(stream_get_contents(STDIN),true); echo $d["data"][0]["permanent_code"] ?? "";')

test -n "$ITEM_DENTAR" && test -n "$ITEM_OFTAR" || { echo 'FAIL: no se obtuvieron ítems'; exit 1; }

for SPEC in "dentar-pr:$ITEM_DENTAR" "oftar-pr:$ITEM_OFTAR"; do
  CAT="${SPEC%%:*}"
  ITEM="${SPEC#*:}"
  OUT="/tmp/T31_${CAT}.json"
  CODE=$(curl -s -o "$OUT" -w '%{http_code}' \
    -H "Authorization: Bearer $API_KEY" \
    "$BASE/catalogs/$CAT/items/$ITEM")
  echo "$CAT/$ITEM HTTP=$CODE"
  php -r '
    $d = json_decode(file_get_contents($argv[1]), true);
    $ok = ($d["data"]["relations"] ?? null) !== null
       && array_key_exists("clinical", $d["data"]["relations"])
       && array_key_exists("terminological", $d["data"]["relations"])
       && array_key_exists("mappings", $d["data"])
       && array_key_exists("related_codes", $d["data"])
       && array_key_exists("uvr", $d["data"]);
    echo $ok ? "OK contrato aditivo\n" : "FAIL contrato aditivo\n";
  ' "$OUT"
done
```

Esperado: `HTTP=200` y `OK contrato aditivo` para ambos catálogos.

### T-32: 200 con arrays vacíos

Obtener un ítem sin relaciones ni mapeos aprobados:

```bash
ITEM_VACIO=$(sudo -u postgres psql -X -Atq -d origen_codes -c "
SELECT i.permanent_code
  FROM os_catalog_item i
  JOIN os_catalog c ON c.id = i.catalog_id
 WHERE c.code = 'dentar-pr'
   AND NOT EXISTS (SELECT 1 FROM os_catalog_relation r
                    WHERE r.source_item_id = i.id OR r.target_item_id = i.id)
   AND NOT EXISTS (SELECT 1 FROM os_concept_mapping m WHERE m.item_id = i.id)
 LIMIT 1;")

test -n "$ITEM_VACIO" || { echo 'SIN_DATOS: no hay ítem sin relaciones ni mapeos'; exit 0; }

curl -s -o /tmp/T32.json -w 'HTTP=%{http_code}\n' \
  -H "Authorization: Bearer $API_KEY" \
  "$BASE/catalogs/dentar-pr/items/$ITEM_VACIO"

php -r '
  $d = json_decode(file_get_contents("/tmp/T32.json"), true);
  $r = $d["data"]["relations"] ?? [];
  $ok = is_array($r["clinical"] ?? null) && is_array($r["terminological"] ?? null)
     && count($r["clinical"]) === 0 && count($r["terminological"]) === 0;
  echo $ok ? "OK arrays vacíos\n" : "FAIL arrays vacíos\n";
'
```

### T-33: sin rutas por familia

```bash
for PATH_TEST in \
  '/v1/relations' \
  '/v1/dentar/relations' \
  '/v1/oftar/relations'
do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $API_KEY" \
    "https://api.origen.ar$PATH_TEST")
  echo "$PATH_TEST HTTP=$CODE"
done
```

Esperado: ninguna ruta devuelve `200`.

### T-34: cabeceras y `request_id`

```bash
curl -s -D /tmp/T34_headers.txt -o /tmp/T34_body.json \
  -H "Authorization: Bearer $API_KEY" \
  -H 'Accept-Language: pt-BR' \
  "$BASE/catalogs/$CAT/items/$ITEM"

grep -iE '^(Vary|Content-Language|X-Request-Id):' /tmp/T34_headers.txt

php -r '
  $d = json_decode(file_get_contents("/tmp/T34_body.json"), true);
  echo isset($d["meta"]["request_id"]) && $d["meta"]["request_id"] !== ""
     ? "OK request_id\n" : "FAIL request_id\n";
'
```

---

## 4. Parte UI — T-35, T-36

```bash
cd /var/www/html/origen.ar/code-api

php tests/run.php | tee /tmp/T35_T36_estatico.log

grep -n "relations_by_class" portal/Repositories/CatalogRepository.php
grep -n "data-relation-class\|scope=\"col\"\|aria-pressed" \
  portal/Views/partials/browse/detail/relations.php
grep -n "relation_class_clinical\|relation_class_terminological" \
  portal/translations/messages.es-AR.yaml \
  portal/translations/messages.en.yaml \
  portal/translations/messages.pt-BR.yaml \
  portal/translations/messages.es.yaml
```

Verificación manual en el navegador:

1. Abrir una ficha DENTAR-PR y una OFTAR-PR.
2. Confirmar las insignias **Clínica** y **Terminológica** en la pestaña Relaciones.
3. Alternar tabla/diagrama y comprobar `aria-pressed`.
4. Recorrer la tabla con teclado y comprobar encabezados `scope="col"`.

Registrar resultado en `/tmp/T35_T36_manual.log`.

---

## 5. Cierre

Con las cuatro salidas — `/tmp/T01_T38_sql.log`, `/tmp/T31_*.json`, `/tmp/T32.json`, `/tmp/T34_headers.txt`, `/tmp/T35_T36_estatico.log` y `/tmp/T35_T36_manual.log` — completar `docs/audit/resultado-T01-T38-relaciones-transversales.md` y después aplicar `docs/audit/acta-publicacion-relaciones-transversales.md`.
