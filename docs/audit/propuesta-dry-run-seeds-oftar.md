# Propuesta de dry-run de seeds de OFTAR-PR y OFTAR-DX

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** OFTAR v1.0 — Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada. (No autoriza ejecución.)

**Convención:** `[H]` hecho verificado en repositorio · `[I]` inferencia · `[P]` propuesta. **Este documento es un diseño, no una ejecución.** No se generaron seeds, no se consultó PostgreSQL, no hay `psql` ni variables `DB_*`/`PG*`; `php tests/run.php` registró 4.068 comprobaciones en una ronda anterior, pero **no se ejecutaron pruebas en esta ronda**. Todos los números siguientes son **esperados y NO validados en esta ronda**.

## 1. Principios `[P]`

1. **Idempotencia:** clave natural por `(catálogo, identificador)` y operaciones `INSERT ... ON CONFLICT DO NOTHING`/`DO UPDATE` solo cuando hay `IS DISTINCT FROM`; repetir el manifiesto no duplica filas.
2. **Deterministicidad:** misma entrada + mismo hash ⇒ mismo manifiesto; orden estable por código original y línea de fuente; sin fecha de ejecución incrustada en claves.
3. **Sin sentencias destructivas:** 0 `DELETE`, `DROP`, `TRUNCATE`, `ALTER ... DROP` ni reescritura de versiones publicadas (`plan-reconstruccion-oftar.md:9-19,77-101`).
4. **Sin escritura en producción:** el dry-run solo simula y produce reportes; la generación simulada corresponde a la etapa 7 y la carga real exige autorización explícita en la etapa 10 del plan de 13 etapas (rector §14, §17.10).
5. **Gobernanza:** toda publicación futura requiere `review_status` real del objeto, dos revisores, `content_hash` vigente y traza en `os_audit_log`; el `approved` documental no basta.
6. **Trazabilidad:** sistema + edición + versión + release/fecha + código y descripción originales + idioma + procedencia + `source_reference` (archivo y línea) por fila (rector §12).

## 2. Inventario de entradas permitidas (conteos esperados, no validados)

| Entrada | Evidencia de origen | Conteo esperado |
|---|---|---:|
| Conciliación PR | `aprobacion-conciliacion-oftar-pr.md:13` (`matriz-conciliacion-clinica-oftar-pr.csv`) | 433 filas; NN 154, CAO 143, Regional 136; todas `propuesta_no_publicada` |
| Pares con justificación suficiente | `aprobacion-conciliacion-oftar-pr.md:17,23-41` | 13 pares / 26 filas (como `equivalent` solo tras firma) |
| Pares a degradar o corregir | `aprobacion-conciliacion-oftar-pr.md:43-54` | 6 pares / 12 filas |
| Registros CAO/Regional sin cobertura | `aprobacion-conciliacion-oftar-pr.md:89-132` | 48 (18 atributos, 8 variantes, 6 duplicados, 3 relacionados, 3 candidatos, 2 no incorporables, 8 pendientes) |
| Candidatos a concepto nuevo | `aprobacion-conciliacion-oftar-pr.md:106-112` | 3: CAO `460106`, Regional `305003`, Regional `305041` (sin alta automática) |
| CIE-10-ES 2026 H00-H59 finales | `universo-diagnosticos-oftar-dx.md:15,23` (74.260 filas CSV) | 2.661 |
| ICD-10-CM 2027 H00-H59 | `universo-diagnosticos-oftar-dx.md:16,23` (74.879 líneas) | 2.677 |
| Intersección / exclusivos | `universo-diagnosticos-oftar-dx.md:17-20` | 2.660 / 1 ES (`H01.8`) / 17 CM |
| Unión condicional | `universo-diagnosticos-oftar-dx.md:39` | 2.678 = 2.661 + 17, solo si se aprueba |
| Versiones DX documentadas | `universo-diagnosticos-oftar-dx.md:21` | 5.338 = 2.661 `es-AR` + 2.677 `en` |
| Referencias S05 fuera de H00-H59 | `universo-diagnosticos-oftar-dx.md:23,49-60` | 90 finales (no incorporación automática) |
| Manifestaciones sistémicas | `universo-diagnosticos-oftar-dx.md:70-75` | 9 códigos `H36.8*` finales dentro de H00-H59 (`AREA-SIST`) |
| SNOMED RF2 refset `447562003` | `universo-diagnosticos-oftar-dx.md:93-103` | 217.373 filas; 155.106 activas; 130.055 con `mapTarget`; 6.783 destino H00-H59; 6.538 conceptos únicos; 260 códigos destino |
| Estructura OFTAR | `oftar_core.sql:142-150`; `oftar_family.sql:57-64` | 1 familia (`oftar`), 2 catálogos (`oftar-pr`, `oftar-dx`), prefijos `OFT-PR`/`OFT-DX` |

**Prohibido como entrada:** la cifra 23.292 (no reproducible, rector §16); CIE-10-ES etiquetada como norma argentina (`tools/sources/cie10_argentina/readme.md:3-7`); SNOMED completo o CIE-10-PCS como diagnóstico; traducciones automáticas; `domain_type='oftar'`; `mapping_type` distinto de `equivalent|narrower|broader|related|unmatched` (`origen_catalog_engine.sql:125-126`).

## 3. Formato propuesto de manifiesto `[P]`

```yaml
manifest_id: dryrun-oftar-20261128-001          # determinista, derivado del hash de entradas
mode: dry_run_only                              # nunca apply
target_environment: aislado_no_produccion
source_documents:
  - path: docs/audit/aprobacion-conciliacion-oftar-pr.md
    sha256: <hash>
  - path: docs/audit/universo-diagnosticos-oftar-dx.md
    sha256: <hash>
expected_counts: {pr_pairs: 13, pr_rows: 26, pr_fix_rows: 12,
                  unmatched_registry_rows: 48, new_candidates: 3,
                  dx_es: 2661, dx_cm: 2677, snomed_rf2_rows: 217373}
operations:
  - table: os_catalog / os_catalog_item / os_catalog_item_version
    key: (catalog_id, permanent_code)
    strategy: INSERT ... ON CONFLICT DO NOTHING
    destructive: false
  - table: os_concept_mapping
    key: (item_id, terminology_system_id, external_code, relationship_role)
    strategy: INSERT ... ON CONFLICT DO UPDATE WHERE IS DISTINCT FROM
    allowed_mapping_type: [equivalent, narrower, broader, related, unmatched]
blocked_operations: [DELETE, DROP, TRUNCATE, UPDATE_public_version, UVR_on_dx]
idempotency_key: sha256(manifest_id + sorted_source_lines)
```

## 4. Formato propuesto de reporte de diferencias `[P]`

| clave | esperado | observado | delta | severidad | acción |
|---|---|---|---|---|---|
| `PR:306116↔461302` | corregir a `306113↔461302` y `306116↔461306` | <por completar en el dry-run> | — | bloqueante | no avanzar hasta firma |

Bloques obligatorios del reporte: `ALTAS` (filas que se crearían), `DIFERENCIAS` (texto/código/edición), `OMITIDOS` (S05/T/E11, candidatos no aprobados) y `BLOQUEANTES` (cualquier desviación de conteo o valor de `CHECK`). El reporte incluye el hash del manifiesto, entorno, fecha de simulación y firma de quien la ejecuta; no modifica BD.

## 5. Verificaciones READ ONLY posteriores `[P]`

Ejecutar solo tras autorización de entorno aislado; comparar contra el acta de la etapa 1 del plan.

```sql
-- Dominio real de mapeos (esperado: 0)
SELECT count(*) AS mapping_type_fuera_de_check
FROM public.os_concept_mapping
WHERE mapping_type NOT IN ('equivalent','narrower','broader','related','unmatched');

-- Prefijos y duplicados (esperado: 0 duplicados, 0 prefijos retirados)
SELECT permanent_code, count(*) AS n
FROM public.os_catalog_item
WHERE permanent_code LIKE 'OFT-%' OR permanent_code LIKE 'OFTAR-%'
GROUP BY permanent_code HAVING count(*) > 1;

-- Cobertura por catálogo OFTAR (esperado según acta: PR/ DX)
SELECT c.code, count(i.id) AS items
FROM public.os_catalog c
LEFT JOIN public.os_catalog_item i ON i.catalog_id = c.id
WHERE c.code IN ('oftar-pr','oftar-dx') AND c.family_code = 'oftar'
GROUP BY c.code;

-- Visibilidad de búsqueda: la vista solo publica versión aprobada (esperado: 0)
SELECT count(*) AS versiones_no_aprobadas_en_vista
FROM public.v_oftar_search_catalog WHERE estado_revision <> 'approved';

-- Privilegio de lectura de la vista (esperado: TRUE para el rol de API)
SELECT has_table_privilege(current_user, 'public.v_oftar_search_catalog', 'SELECT') AS puede_leer;

-- Referencias externas no incorporadas automáticamente (esperado según acta: 90 S05, 9 H36.8*)
SELECT count(*) FILTER (WHERE value ~ '^S05')   AS s05,
       count(*) FILTER (WHERE value ~ '^H36\.8') AS h368
FROM public.os_catalog_identifier;

-- Aislamiento de dominio (esperado: 0 en ambas consultas)
SELECT count(*) AS dominio_oftar_invalido
FROM public.os_catalog WHERE domain_type = 'oftar';

SELECT count(*) AS codigos_heredados
FROM public.os_catalog WHERE code LIKE 'OFTAR-%';

-- Mapeos SNOMED publicados sin revision vigente (esperado: 0)
SELECT count(*) AS snomed_no_draft
FROM public.os_concept_mapping m
JOIN public.os_terminology_system ts ON ts.id = m.terminology_system_id
WHERE ts.code = 'SNOMED' AND m.review_status <> 'draft';
```

La verificación de las cifras RF2 (217.373 / 155.106 / 130.055 / 6.783) se hace sobre el archivo `der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt` y se registra en el acta; solo se consulta en BD si el acta de la etapa 1 confirma la tabla de proyección.

## 6. Umbrales de aceptación `[P]`

| Verificación | Umbral |
|---|---|
| Conteos de entradas | Diferencia 0 frente a la tabla §2, salvo decisión firmada en etapa 3 o 4 |
| Inconsistencias resueltas | 11/11 con evidencia; 0 valores fuera del `CHECK` real |
| Conciliación PR | 13/13 pares firmados; 6/6 corregidos; 48/48 con destino; 3 candidatos sin alta automática |
| DX | 2.661 base; 2.678 solo con acta; 0 usos de 23.292; 0 importación masiva |
| Identidad | 0 códigos duplicados `OFT-*`, 0 prefijos `OFTAR-*`, 0 `domain_type='oftar'` |
| Gobernanza | 0 filas publicadas con `review_status` distinto del permitido por objeto; 0 textos sin hash vigente |
| i18n | 100% `es-AR` publicable; huecos `en`/`pt-BR` informados como `untranslated`, no tratados como paridad |
| UVR | 0 UVR en `oftar-dx`; 0 importes CAO/Regional convertidos |
| API/Browse | Contratos `/v1/*` y filtros históricos sin cambios; vista con `family_code='oftar'` y versión `approved` |
| Bloqueantes | 0 para cerrar la etapa 7 y 0 para autorizar la etapa 10; cualquier bloqueante detiene el plan |

## 7. Declaración de alcance

**[I]** Los conteos son **esperados**, derivados de documentos y archivos leídos en esta ronda; **no fueron validados contra PostgreSQL ni contra una ejecución de seeds**. Ninguna consulta de la sección 5 se ejecutó aquí. El dry-run propuesto no autoriza applying, publicación, despliegue ni `git push`.

## 8. No hacer

- No ejecutar seeds, migraciones, importadores, generadores ni `php tests/run.php` en esta ronda.
- No usar `psql`, variables `DB_*`/`PG*` ni conexión a producción.
- No `DELETE`, `DROP`, `TRUNCATE`, ni sobrescribir versiones publicadas.
- No generar ni publicar equivalencias clínicas por similitud textual; no inventar códigos, traducciones ni ediciones.
- No asignar UVR a `oftar-dx`, no convertir importes CAO/Regional y no importar SNOMED o PCS completos.
- No modificar archivos existentes ni seeds; este documento solo propone diseño y verificaciones.
