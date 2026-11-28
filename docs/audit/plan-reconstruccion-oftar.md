# Plan de reconstrucción de OFTAR-PR y OFTAR-DX

**Fecha:** 2026-11-28  
**Estado:** propuesta. **No ejecutado. No modifica seeds, PostgreSQL ni migraciones.**  
**Ejecución:** el responsable ejecuta SQL, Git y deploy. El asistente solo prepara diagnóstico, documentación y verificaciones.

---

## 0. Restricciones que rigen el plan

- No `DROP`, `TRUNCATE` ni `DELETE`.
- No modificar seeds existentes ni fuentes originales.
- No modificar PostgreSQL directamente; toda escritura futura pasa por gobernanza con dos revisiones.
- No ejecutar migraciones.
- No asignar UVR a diagnósticos ni convertir importes CAO/Regional a UVR.
- No crear motor paralelo ni duplicar `os_catalog`.
- No importar SNOMED CT ni CIE-10-PCS completos.
- No automatizar equivalencias clínicas por texto; no inventar códigos retirados.

---

## 1. Fase 0 — Validación de estado real (solo lectura)

**Objetivo:** convertir inferencias en hechos antes de tocar nada.

El usuario ejecuta en `origen_codes` las verificaciones A–F de `auditoria-oftar-actual.md`. Resultados esperados y acciones:

| Consulta | Resultado esperado | Si difiere |
|---|---|---|
| A. Cobertura por catálogo | 154 `oftar-pr`, 2.678 `oftar-dx`, 143 CAO, 136 Regional | Registrar brecha; no asumir cobertura publicada. |
| B. Prefijos | `OFT-PR`, `OFT-DX` | Detener: no reutilizar prefijos retirados. |
| C. Estado del mapeo | 91 propuestas CAO, 0 Regional, estados documentados | Revisar antes de aprobar. |
| D. Resolución de `target_code` | `targets_resueltos > 0` para las filas a publicar | Confirma H-02; resolver por `os_catalog_identifier`, no por `permanent_code`. |
| E. Vista de búsqueda | Conteos coherentes por catálogo | Revisar `review_status` y `GRANT SELECT`. |
| F. Categorías clínicas | 12 categorías, mapas/defaults vigentes | Verificar que `categorias_clinicas.sql` esté aplicado. |

**Criterio de salida:** acta de verificación con los conteos reales. Sin este acta no se pasa a la Fase 1.

---

## 2. Fase 1 — Corrección documental y de rutas (propuesta, no aplicada)

**Objetivo:** eliminar la anomalía H-01 sin alterar seeds ni fuentes.

Cambios propuestos, a aprobar por separado:

1. `tools/generate_nomencladores_oftalmologicos_sql.py`: apuntar `SOURCES` a `tools/sources/oftalmologico/` y usar los nombres reales de los CSV.
2. Encabezados de `sql/03_oftar/nomenclador_oftalmologico_cao.sql` y `..._regional.sql`: actualizar las rutas citadas.
3. `tests/run.php:2789` y `:3424`: reemplazar `tools/sources/oftar/importar_cie10_dx.sql` por `tools/sources/oftalmologico/oftar/importar_cie10_dx.sql`.
4. Regresión actual a documentar: `php tests/run.php` → `FALLOS (4 de 4088)`.

**Restricción:** mientras rija “no implementar”, estos archivos quedan intactos. La corrección es una propuesta de implementación futura.

**Criterio de salida:** aprobación explícita para tocar esas tres rutas; `php tests/run.php` sin los 4 fallos.

---

## 3. Fase 2 — Gobernanza de la correspondencia CAO → OFTAR-PR

**Objetivo:** resolver H-02 sin publicar nada automáticamente.

Pasos propuestos:

1. Mantener `os_oftar_nomenclador_match` como tabla de propuestas: `proposed`, `approved` o `rejected`.
2. Resolver el destino por identificador externo:
   `os_catalog_identifier.value = m.target_code` con `system_name = 'NOMENCLADOR-AR'` e `item.catalog_id = oftar_pr`.
3. Escribir en el registro gobernado el `permanent_code` `OFT-PR-NNNNNN` resultante, sin alterar el `target_code` histórico de la fuente ni el catálogo de origen.
4. Publicar solo pares con `review_status='approved'`, dos revisores distintos y decisión con evidencia (`catalogos_gestion_gobernada.sql:94-113`).
5. Conservar `match_basis='texto_identico_normalizado'`; la coincidencia es candidato, no equivalencia clínica ni de facturación.

**Verificación:** consultas C y D de la Fase 0 más `verificacion_post_aprobacion_nomencladores_oftar.sql`.

**Criterio de salida:** 91 pares CAO revisados; `target_item_id` no nulo para los aprobados; 0 relaciones publicadas sin revisión.

---

## 4. Fase 3 — Espejos de origen sin sentencias destructivas

**Objetivo:** preservar CAO y Regional como catálogos de origen inmutables por release.

Sustituir, en una futura implementación aprobada, el patrón actual `DELETE FROM os_source_oftar_*` por:

```sql
INSERT INTO public.os_source_oftar_cao (...)
VALUES (...)
ON CONFLICT (codigo) DO UPDATE
   SET descripcion = EXCLUDED.descripcion,
       categoria   = EXCLUDED.categoria,
       subcategoria = EXCLUDED.subcategoria
 WHERE os_source_oftar_cao.descripcion IS DISTINCT FROM EXCLUDED.descripcion
    OR os_source_oftar_cao.categoria   IS DISTINCT FROM EXCLUDED.categoria;
```

Reglas:

- La clave natural es el código histórico de la fuente.
- No se copian importes: `valor`, `honorario_medico`, `gasto`, `valor_total` quedan fuera del espejo canónico.
- Un cambio de texto crea una nueva versión; nunca sobrescribe una versión publicada.
- Los SQL vigentes no se ejecutan ni se editan en esta etapa de diagnóstico.

**Criterio de salida:** generador propuesto sin `DELETE`; 143 y 136 filas estables; 0 importes migrados.

---

## 5. Fase 4 — Reconstrucción aditiva de OFTAR-PR y OFTAR-DX

**Objetivo:** completar cobertura sin reemplazar lo existente.

### OFTAR-PR

- Mantener los 154 ítems del Nomenclador Nacional 2025 como núcleo.
- Usar `OFT-PR-NNNNNN` validado por trigger; no reutilizar retirados.
- Lateralidad OD/OI/AO/NA como atributo, no como código nuevo.
- Categorías fuente y clínica separadas según `modelo-canonico-oftar-propuesto.md`.
- CAO y Regional siguen siendo catálogos de origen con su numeración; se vinculan por relaciones gobernadas.

### OFTAR-DX

- Mantener 2.678 diagnósticos esperados: 2.661 del CSV ES + 17 exclusivos del archivo EN.
- Usar `OFT-DX-NNNNNN`; dueño CIE-10 y rango H00-H59.
- 5.338 versiones esperadas: 2.661 `es-AR` + 2.677 `en`; conservar 1 hueco ES y 17 huecos EN.
- Sin UVR, sin PCS como diagnóstico y sin traducción inventada.

### Textos

- `preferred_term` se aprueba por campo con hash; `definition` y `external_display` quedan pendientes o NULL.
- `v_oftar_search_catalog` publica solo versiones aprobadas.

**Criterio de salida:** conteos de la Fase 0 alcanzados; 0 duplicados de identidad; 0 prefijos viejos; 0 UVR en DX.

---

## 6. Fase 5 — Verificación y publicación gobernada

Orden sugerido para el usuario, sin ejecución por el asistente:

1. `BEGIN READ ONLY` con las consultas de `auditoria-oftar-actual.md`, `cobertura-oftar-pr.md` y `cobertura-oftar-dx.md`.
2. Verificaciones específicas ya presentes, en orden:
   `verificacion_oftar.sql`, `verificacion_oftar_cie10.sql`, `verificacion_sync_oftar_dx.sql`, `verificacion_aprobacion_oftar_dx.sql`, `verificacion_nomencladores_oftar.sql`, `verificacion_post_aprobacion_nomencladores_oftar.sql`, `verificacion_oftar_pr_carga.sql`, `revision_pares_nomencladores_oftar.sql`.
3. Aprobación editorial de `preferred_term` con `aprobar_preferred_term_oftar_dx.sql` y `aprobar_mapeo_nomencladores_oftar.sql` **solo si** hay dos revisiones y evidencia.
4. Comprobación de API: `/v1/domains` incluye `oftar`; `/v1/catalogs/oftar-pr/items` y `/v1/catalogs/oftar-dx/items` responden `category` y `clinical_category`.
5. Comprobación de portal: `/es-AR/oftar`, `/en/oftar`, `/pt-BR/oftar` sin 5xx; selector “Todos” = sin filtro; deep links con `category` histórico siguen funcionando.
6. `php tests/run.php` sin regresiones (después de la Fase 1 si se autoriza).

**Criterio de salida:** informe de verificación con evidencia; rollback = restaurar dump previo, no borrado de tablas.

---

## 7. Fase 6 — Cierre documental

Actualizar, solo tras aprobación e implementación:

- `docs/audit/informe-final-oftar.md` con actas, conteos y hashes.
- `docs/audit/browse-y-categorias.md` con cualquier cambio de selector/fallback.
- `README` y `docs/api/openapi-3.1.yaml` si el contrato de categorías clínicas cambia.
- Matriz `matriz-equivalencias-oftar-pr.csv` con el estado final de cada par revisado.

---

## 8. Matriz de riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Publicar una equivalencia clínica no revisada | Solo `texto_identico_normalizado` como candidato; dos revisiones + evidencia. |
| Perder numeración histórica | Catálogos de origen inmutables; códigos OFTAR nunca reutilizados. |
| Romper deep links | `category` histórico conservado; `clinical_category` aditivo. |
| Borrar datos al regenerar espejos | `ON CONFLICT DO UPDATE`, sin `DELETE`. |
| Asignar valor a diagnósticos | Exclusión explícita en `oftar-dx` y `UvrPublicRepository.php`. |
| Publicar texto sin revisar | `review_status` y hash en `os_field_review`; vista solo `approved`. |
| Dependencia de migración no aplicada | Verificar Fase 0 F y `catalogos_gestion_gobernada.sql` antes de publicar. |
| Regresión de tests por rutas | Fase 1, sujeta a autorización separada. |

---

## 9. Criterios de aceptación finales

- [ ] Conteos reales confirmados en VPS: 154 PR / 2.678 DX / 143 CAO / 136 Regional.
- [ ] Prefijos `OFT-PR` y `OFT-DX` vigentes; 0 códigos `OFTAR-*`.
- [ ] 91 candidatos CAO revisados; 0 equivalencias automáticas publicadas.
- [ ] Categoría del concepto y catálogo de origen separados en API y portal.
- [ ] 0 importes CAO/Regional convertidos a UVR; 0 UVR en OFTAR-DX.
- [ ] 0 `DROP`/`TRUNCATE`/`DELETE` en la reconstrucción propuesta.
- [ ] Sin motor paralelo, sin seeds modificados y sin migraciones ejecutadas por el asistente.
- [ ] `php tests/run.php` verde tras la corrección de rutas autorizada.
