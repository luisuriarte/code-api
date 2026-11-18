# Dry-run local · DENTAR-DX desde CIE-10 + SNOMED

Generado sin ejecutar SQL ni conectarse a la base. Fuentes leídas en modo solo lectura:

- CIE-10 ES 2026: `D:\docs\luis\Documentos\sitios\openemr\codigos\cie-10\Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv` → 202 códigos K00-K14.
- SNOMED AR 2026-08-20 refset `398711000221107` → 344 diagnósticos activos.
- Mapa extendido `447562003` → 361 filas dentales con destino K00-K14.
- Descripciones FSN `es` → 344 términos encontrados.
- Mapeos DENTAR existentes extraídos de `dentar_core_and_diagnosis.sql`.

Archivos:

- `dentar-dx-cie10-snomed.csv`: 202 filas candidatas.
- `dentar-dx-snomed-cie10-map.csv`: 361 filas de mapa SNOMED→CIE-10 con DNT asignado cuando existe.
- `dentar-dx-excepciones.csv`: 156 excepciones.

## Reglas aplicadas

1. El identificador obligatorio es CIE-10. El término preferido candidato es la descripción literal del CSV CIE-10 ES 2026; requiere revisión es-AR antes de publicación.
2. Los SCTID candidatos salen del refset odontológico de diagnósticos y del mapa extendido `447562003` con destino K00-K14.
3. Cuando un CIE-10 tiene varios SCTID, se elige determinísticamente el de menor `mapGroup`, `mapPriority` y SCTID; todos los términos reales se conservan en `sinonimos`.
4. Los DNT-DX ya mapeados en `dentar_core_and_diagnosis.sql` se reutilizan. Los nuevos se asignan correlativamente desde `000039` en orden alfabético de código CIE-10.
5. Los 8 diagnósticos DENTAR actuales con CIE-10 ausente del bloque dental de la edición 2026 (K07/K10, S02.5, S03.2, F45.8, Z01.2) se conservan como excepciones; no se les crea un DNT nuevo. Otros 13 usan códigos K que no existen textualmente en la edición 2026 y también quedan marcados.
6. No se usan `snomed-dental` ni CPT4 para PR/DX. `snomed-dental` queda como referencia para futuros DENTAR-AN / DENTAR-CL, previa confirmación del nombre del segundo producto.

## Recuentos

| Métrica | Valor |
|---|---:|
| CIE-10 K00-K14 | 202 |
| DNT-DX reutilizados | 17 |
| DNT-DX nuevos | 185 |
| Filas de mapa dental | 361 |
| CIE-10 con múltiples SCTID | 42 |
| CIE-10 sin mapa SNOMED | 135 |
| DX existentes con CIE-10 ausente en edición 2026 | 13 |
| Excepciones | 156 |

## Estado

No se ejecutó carga ni sincronización. Validación estructural: 202 CIE-10 únicos, 202 DNT-DX únicos, categoría `CAT-DX` y mapa con DNT resuelto cuando el CIE-10 existe en el CSV.
