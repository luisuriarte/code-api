# Plan de implementación controlada de OFTAR-PR y OFTAR-DX

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** Aprobada como base técnica para iniciar la implementación controlada (no autoriza ejecución).

**Convención:** `[H]` hecho verificado en repositorio · `[I]` inferencia · `[P]` propuesta. Esta numeración operativa (1–10) sucede a las fases 0–6 de `plan-reconstruccion-oftar.md` y al índice histórico del rector §14; el rector remite a este documento como plan canónico, sin reescribir el histórico. Responsable = quien ejecuta SQL, Git y deploy; asistente = solo diagnóstico, documentación y verificaciones.

## Etapa 1 — Acta `READ ONLY` y freeze

- **Objetivo:** convertir inferencias en hechos antes de cualquier cambio (`plan-reconstruccion-oftar.md:22-37`; rector §14).
- **Entradas:** consultas A–F de `auditoria-oftar-actual.md`; acta de la etapa previa si existe.
- **Trabajo permitido:** consultas de solo lectura ejecutadas por el responsable; documentación de resultados por el asistente; snapshot/hash de la configuración observada.
- **SALIDA verificable:** acta firmada con objetos, privilegios (incluido `GRANT SELECT` sobre `v_oftar_search_catalog`), valores reales de los `CHECK`, conteos por catálogo y estados de revisión.
- **Criterios de aceptación medibles:** 1 acta; 0 escrituras; desviaciones registradas frente a 154 PR / 143 CAO / 136 Regional / 2.661 H ES / 2.677 H CM; `target_code` documentado (H-02).
- **Gate de autorización:** acta completa; sin ella no se inicia la etapa 2.
- **Prohibido:** escribir en BD, ejecutar `psql` por el asistente, migraciones, seeds y publicación.

## Etapa 2 — Correcciones documentales y cierre de inconsistencias

- **Objetivo:** fijar la capa semántica sin tocar código ni fuentes (`plan-reconstruccion-oftar.md:41-54`).
- **Entradas:** `inconsistencias-resueltas-oftar.md` (11 filas); rector §0, §7, §9, §10.
- **Trabajo permitido:** crear los documentos nuevos y corregir la documentación existente ya auditada; marcar contradicciones históricas sin reescribir auditorías previas.
- **SALIDA verificable:** tabla de inconsistencias con resolución `[H]`/`[P]` y referencias estables por sección; correcciones aplicadas al rector §7, §9, §14 y a la arquitectura, registradas en el historial del rector.
- **Criterios de aceptación medibles:** 11/11 inconsistencias con evidencia citada; 0 cambios en SQL, PHP, seeds ni datos; correcciones documentales trazadas en el historial; 4 documentos nuevos creados.
- **Gate de autorización:** aprobación documental del responsable para cualquier cambio posterior de rutas.
- **Prohibido:** editar seeds, migraciones o fuentes originales; ejecutar generadores.

## Etapa 3 — Decisión clínica documentada de OFTAR-PR

- **Objetivo:** cerrar la conciliación sin publicar (`aprobacion-conciliacion-oftar-pr.md:17,148-150`).
- **Entradas:** 433 filas de la matriz; 13 pares / 26 filas propuestos; 6 pares / 12 filas a degradar o corregir; 48 registros y 3 candidatos (rector §2).
- **Trabajo permitido:** revisión humana, corrección documental de justificaciones (RFG) y fallo sobre cada registro; actualización de la matriz gobernada como worklist.
- **SALIDA verificable:** acta firmada con destino de los 13 pares, de los 6 pares y de las 48 filas, incluidos `460106`, `305003`, `305041`.
- **Criterios de aceptación medibles:** 13/13 pares con firma; 6/6 correcciones o degradaciones; 48/48 filas con destino; 0 equivalencias publicadas; 0 importes migrados.
- **Gate de autorización:** firma del comité clínico y del responsable de gobernanza.
- **Prohibido:** equivalencia automática por texto, altas automáticas de conceptos, asignación de UVR.

## Etapa 4 — Decisión de alcance de OFTAR-DX

- **Objetivo:** cerrar el universo y sus referencias externas (`universo-diagnosticos-oftar-dx.md:31-75`; rector §3).
- **Entradas:** 2.661 H00-H59 finales ES (74.260 filas), 2.677 H CM (74.879 líneas), intersección 2.660, 17 exclusivos CM, 1 exclusivo ES (`H01.8`), 90 S05, 9 `H36.8*`, refset SNOMED `447562003`.
- **Trabajo permitido:** acta de conjuntos, decisión sobre 2.661 frente a 2.678, sobre S05/T15/T26/T85/E11.\* y sobre `AREA-SIST`; definición del filtro SNOMED.
- **SALIDA verificable:** acta de universo con conjuntos numerados y regla de incorporación justificada.
- **Criterios de aceptación medibles:** 2.660 intersección, 17 CM, 1 ES; 6.783 mapeos H de 130.055 activos con `mapTarget` de 217.373 filas RF2; 0 usos de la cifra 23.292; 0 importaciones masivas.
- **Gate de autorización:** acta firmada del responsable de DX y del comité clínico.
- **Prohibido:** importar SNOMED completo o PCS como diagnóstico, traducir códigos CM inventando `es-AR`, publicar candidatos no aprobados.

## Etapa 5 — Migración aditiva independiente de `review_status` (solo propuesta)

- **Objetivo:** diseñar cambios estructurales sin ejecutarlos (rector §17.5).
- **Entradas:** actas de etapas 1 y 4; `origen_catalog_engine.sql:18,49,67,119-133`; `04_fase3_columnas.sql:24-37`; `fase3_relaciones_mapeos.sql:177-184`.
- **Trabajo permitido:** redactar propuesta de metadatos de edición/versión/release/provenance, independiente de cualquier cambio en `review_status`; proponer por separado el `CHECK` aditivo de `review_status` (P-08) con preflight de solo lectura.
- **SALIDA verificable:** archivo SQL propuesto con encabezado de no ejecución, lista de preflights y plan de rollback; 0 sentencias aplicadas.
- **Criterios de aceptación medibles:** 0 `DROP`/`TRUNCATE`/`DELETE`; 0 cambios de DEFAULT sin autorización; todos los objetos usan `CREATE ... IF NOT EXISTS`/`ADD COLUMN IF NOT EXISTS` o equivalente aditivo.
- **Gate de autorización:** aprobación formal de arquitectura + DBA; ejecución futura en acto separado.
- **Prohibido:** ejecutar migración, modificar filas existentes, asumir que el `CHECK` cambió el estado de las filas.

## Etapa 6 — Seeds de estructura, familia y catálogos (diseño)

- **Objetivo:** preparar, no generar, la carga aditiva de la estructura (`oftar_core.sql:142-150`; `oftar_family.sql:57-64`).
- **Entradas:** decisiones de etapas 4 y 5; prefijos `OFT-PR`/`OFT-DX`; dominios `ANAT-*`/`AREA-*` propuestos (rector §6).
- **Trabajo permitido:** redactar manifiesto y reglas `INSERT ... ON CONFLICT` idempotentes para 1 familia y 2 catálogos; documentar dominios de atributos como pendientes de siembra.
- **SALIDA verificable:** manifiesto de estructura con claves naturales, conteos esperados y hashes de entrada.
- **Criterios de aceptación medibles:** 1 familia `oftar`, 2 catálogos (`oftar-pr`, `oftar-dx`), 0 `domain_type='oftar'`, 0 catálogos `OFTAR-*`, 0 sentencias destructivas.
- **Gate de autorización:** etapas 1, 4 y 5 firmadas.
- **Prohibido:** ejecutar el generador, escribir en BD, crear motor paralelo, sembrar UVR en DX.

## Etapa 7 — Seeds de conceptos PR (diseño)

- **Objetivo:** preparar la reconciliación corregida de procedimientos (`aprobacion-conciliacion-oftar-pr.md:89-132`).
- **Entradas:** 154 NN 2025, 143 CAO, 136 Regional; 13 pares firmados, 6 corregidos, 48 filas clasificadas y 3 candidatos (etapa 3).
- **Trabajo permitido:** diseñar cargas gobernadas por `os_catalog_identifier`, `os_field_review` y `os_concept_mapping`; conservar numeración original y descripciones.
- **SALIDA verificable:** manifiesto PR con pares, atributos, variantes, duplicados y candidatos marcados como no automáticos.
- **Criterios de aceptación medibles:** 154/143/136 filas de origen; 26 filas de 13 pares; 12 filas corregidas; 48/48 clasificadas; 3 candidatos sin alta automática; 0 importes convertidos.
- **Gate de autorización:** etapa 3 firmada y etapa 6 aprobada.
- **Prohibido:** publicar `mapping_type` no permitido por el `CHECK` real, publicar pares sin dos revisiones, inventar equivalencias de facturación.

## Etapa 8 — Seeds de conceptos DX y mapeos (diseño)

- **Objetivo:** preparar diagnósticos y vinculación SNOMED filtrada (`universo-diagnosticos-oftar-dx.md:91-117`).
- **Entradas:** 2.661 códigos H ES finales; 2.677 H CM; 17 exclusivos CM; 90 S05 y 9 `H36.8*` como referencias; 6.783 mapeos RF2 destino H.
- **Trabajo permitido:** diseñar cargas con identidad por sistema+edición+versión+release+idioma+procedencia; `mapping_type='related'` y `review_status='draft'` para SNOMED, conservando `mapRule`/`mapAdvice` en `clinical_rationale`.
- **SALIDA verificable:** manifiesto DX con conjuntos, versiones esperadas y criterios de no incorporación.
- **Criterios de aceptación medibles:** 2.661 base; 2.661+17=2.678 solo si se aprueba; 5.338 versiones esperadas documentadas (2.661 `es-AR` + 2.677 `en`); 0 UVR; 0 usos de 23.292.
- **Gate de autorización:** etapa 4 firmada y etapa 6 aprobada.
- **Prohibido:** importar SNOMED completo, publicar textos sin revisión, reetiquetar códigos CM como CIE-10-ES, crear categorías `CLIN-*` para S05/T/E11.

## Etapa 9 — Verificación API/Browse/i18n y dry-run

- **Objetivo:** comprobar que el diseño preserva contratos antes de cualquier aplicación (`plan-reconstruccion-oftar.md:133-146`; rector §9.3 y §13).
- **Entradas:** manifiestos de etapas 6–8; `propuesta-dry-run-seeds-oftar.md`; `TerminologySearchService.php:49,52-68,76-80,417-432`; `CatalogEngineService.php:126-146`; `CatalogRepository.php:2197-2381`.
- **Trabajo permitido:** simulación estática del manifiesto, reporte de diferencias y consultas de solo lectura en entorno autorizado que no sea producción.
- **SALIDA verificable:** informe de dry-run con conteos esperados vs observados, checks de API/Browse/i18n y lista de bloqueantes.
- **Criterios de aceptación medibles:** `oftar` en `DOMAINS` y ausente en `DEFAULT_DOMAINS`; vista con `family_code='oftar'`, `product_role='catalog'`, ítem `active`, versión `approved`; 100% `es-AR` publicable; 0 bloqueantes; 0 escrituras en producción.
- **Gate de autorización:** aprobación explícita para ejecutar el dry-run en entorno aislado; su resultado no autoriza seeds.
- **Prohibido:** aplicar manifiestos en producción, ejecutar `php tests/run.php` en esta ronda, publicar, desplegar.

## Etapa 10 — Autorización de seeds y publicación controlada posterior

- **Objetivo:** emitir la autorización explícita que hoy no existe (rector §14, §17.10).
- **Entradas:** actas de etapas 1–9; manifiestos con hash; regla de rollback; `cuestiones-pendientes-oftar.md` con gates cerrados.
- **Trabajo permitido:** firma de un acta de autorización con alcance, responsables, entorno, hash de manifiestos y condiciones de parada. La publicación gobernada queda para un acto posterior.
- **SALIDA verificable:** acta de autorización; registro de 0 seeds generados y 0 seeds ejecutados por este plan.
- **Criterios de aceptación medibles:** 1 acta firmada por el responsable; 0 pendientes P-01…P-15 abiertas que afecten el alcance autorizado; 0 writes posteriores a la firma en esta ronda.
- **Gate de autorización:** firma expresa del responsable; sin firma, el plan se detiene.
- **Prohibido:** generar seeds, ejecutar seeds, ejecutar migraciones/importadores, publicar, hacer `git push`, desplegar.

## Trazabilidad etapa → documento → gate

| Etapa | Documento de origen | Gate |
|---:|---|---|
| 1 | `plan-reconstruccion-oftar.md:22-37`; rector §14, §16 | Acta `READ ONLY` firmada |
| 2 | `inconsistencias-resueltas-oftar.md`; rector §0, §7 | Aprobación documental |
| 3 | `aprobacion-conciliacion-oftar-pr.md:17,148-150` | Firma clínica + corrección de 12 filas |
| 4 | `universo-diagnosticos-oftar-dx.md:31-75`; rector §3 | Acta de universo DX |
| 5 | Rector §17.5; `origen_catalog_engine.sql:119-133` | Aprobación de arquitectura/DBA (sin ejecución) |
| 6 | `oftar_core.sql:142-150`; `oftar_family.sql:57-64` | Etapas 1, 4 y 5 cerradas |
| 7 | `aprobacion-conciliacion-oftar-pr.md:89-132` | Etapa 3 firmada |
| 8 | `universo-diagnosticos-oftar-dx.md:91-117` | Etapas 4 y 6 cerradas |
| 9 | `propuesta-dry-run-seeds-oftar.md`; rector §9.3, §13 | Autorización de entorno aislado |
| 10 | Rector §14, §17.10 | Firma explícita de autorización de seeds |

## Regla de rollback y parada `[P]`

- Ante cualquier diferencia con el acta de la etapa 1, cualquier escritura no gobernada, un valor fuera de los `CHECK` reales o un pendiente sin gate, se detiene la etapa en curso y se documenta el bloqueante; no se avanza a la siguiente.
- Rollback futura = restaurar el dump previo verificado (`plan-reconstruccion-oftar.md:145`), nunca `DELETE`, `TRUNCATE` ni `DROP`; `os_audit_log` es append-only y no se reescribe.
- El plan termina aquí, **antes de generar o ejecutar seeds**. La etapa 10 es únicamente la autorización; ninguna etapa de este documento ejecuta cambios.
