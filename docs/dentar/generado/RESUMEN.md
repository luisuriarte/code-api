# Dry-run local · DENTAR-PR desde CDT 2025

Generado sin ejecutar SQL ni conectarse a la base. Archivos:

- `Argentina_dental_cdt_codes_2025_postgres.corregido.sql`: copia del fuente con dos cambios exactos (`,` en línea 422 y `D7111` en línea 1712). El original no fue modificado.
- `dentar-pr-cdt-2025.csv`: 805 filas candidatas.
- `dentar-pr-cdt-relaciones.csv`: 333 relaciones únicas (338 menciones crudas).
- `dentar-pr-excepciones.csv`: 8 filas excluidas.

## Reglas aplicadas

1. Se corrigió el error sintáctico y el `cdt_code` del id 557.
2. Se conservaron las filas vacías y duplicadas en el SQL corregido, pero se excluyeron del CSV por no tener un código CDT inequívoco.
3. Para códigos CDT ya presentes en `dentar_core_and_diagnosis.sql` se reutilizó su `DNT-PR`; para el resto se asignó el siguiente correlativo libre desde `DNT-PR-000139`, en orden de `id` CDT.
4. `termino` y `definicion` salen de `description`; `criterios_clinicos` concatena `procedure`, `notes` y `req` con etiquetas.
5. `categoria` se derivó sólo de `service_type` cuando existe categoría DENTAR equivalente. PRÓTESIS MAXILOFACIAL queda sin categoría porque no hay categoría exacta.
6. `nomenclador_ar` se copia sólo desde mapeos DENTAR existentes; no se inventa para los CDT nuevos.
7. `snomed_sctid` queda vacío: las fuentes SCTID actuales no son verificables contra los refsets odontológicos y este lote no debe inventarlos.
8. Las relaciones se extraen de tokens literales `D\d{4}` en `description`, `procedure`, `notes` y `req`. No se expanden rangos. El tipo se detecta por frase literal; la frase completa se conserva en `contexto`.

## Recuentos

| Métrica | Valor |
|---|---:|
| Filas CDT parseadas | 813 |
| Filas elegibles para CSV | 805 |
| DNT-PR reutilizados | 99 |
| DNT-PR nuevos | 706 |
| Filas con `nomenclador_ar` | 99 |
| Excepciones | 8 |
| Relaciones crudas | 338 |
| Relaciones únicas | 333 |
| Relaciones con destino CDT resuelto | 333 |

## Mapeos DENTAR-PR existentes no reconciliados

Dos códigos CDT usados por el seed DENTAR no aparecen en el CDT corregido:

| DNT-PR | CDT |
|---|---|
| DNT-PR-000082 | D8050 |
| DNT-PR-000091 | D2970 |

Se conservan en la base; este lote no los renombra ni los fuerza.

## Excepciones por motivo

- duplicado_de_codigo: 6
- cdt_code_vacio: 2

## Tipos de relación detectados

- denied_as_integral: 85
- alternate_benefit: 74
- refer_to_details: 73
- referencia_literal: 46
- billed_in_conjunction_with: 13
- not_to_be_used_with: 11
- frequency_limitations: 6
- interchangeable_with: 5
- used_in_combination_with: 4
- integral_to: 4
- not_paid_separately: 4
- paid_as_code: 3
- concurrent_to: 3
- shares_frequency_limitation_with: 1
- procedure_code_not_used_for: 1

## Categorías sin equivalente exacto

- 'PRÓTESIS MAXILOFACIAL': 43

## Estado

No se ejecutó `psql`, ni el importador contra base de datos, ni `sync_dentar_to_os.sql`.
La validación fue estructural: CSV parseable, DNT únicos, CDT únicos, categorías válidas y relaciones apuntando a DNT generados.
