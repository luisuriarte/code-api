# Plan de implementación controlada de OFTAR-PR y OFTAR-DX

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** OFTAR v1.0 — Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada. (No autoriza ejecución.)

**Convención:** `[H]` hecho verificado en repositorio · `[I]` inferencia · `[P]` propuesta. Secuencia específica del perfil OFTAR dentro del plan transversal `docs/architecture/relaciones/12-plan-implementacion-relaciones-transversales.md`. Las 13 etapas siguientes son la secuencia canónica solicitada. Suceden a las fases 0–6 de `plan-reconstruccion-oftar.md` y a la numeración operativa anterior de 10 etapas, sin reescribir el histórico. Responsable = quien ejecuta SQL, Git y deploy; asistente = solo diagnóstico, documentación y verificaciones. **Ninguna etapa se ejecutó en esta ronda; el plan se detiene antes de generar o ejecutar seeds.**

---

## Etapa 1 — Verificación del esquema actual y compatibilidad

- **Objetivo `[P]`:** convertir inferencias de código en hechos deProduction mediante un acta `READ ONLY`; verificar tipos, `CHECK`, vistas, privilegios, relaciones y datos existentes.
- **Archivos afectados:** `auditoria-oftar-actual.md`, `plan-reconstruccion-oftar.md`, `matriz-estados-publicacion-oftar.md`, acta nueva firmada.
- **Dependencias:** ninguna. Requiere credenciales autorizadas de solo lectura.
- **Riesgos:** estado runtime distinto del SQL versionado; vista sin `GRANT SELECT`; `target_code` (H-02) distinto del esperado.
- **Pruebas:** consultas A–F del plan histórico; `to_regclass`, `pg_constraint`, `pg_get_viewdef`, conteos por catálogo y estados.
- **Criterios de aceptación medibles:** 1 acta firmada; 0 escrituras; 0 desviaciones sin explicar frente a 154 PR / 143 CAO / 136 Regional / 2.661 H ES / 2.677 H CM; `relation_type` CDT-only confirmado; `review_status` real por entidad documentado.
- **Condición para avanzar:** acta completa; sin ella no se inicia la etapa 2.

## Etapa 2 — Cierre del modelo de conceptos

- **Objetivo `[P]`:** fijar identidad, campos canónicos, taxonomía y dimensiones anatómicas sin tocar datos.
- **Archivos afectados:** `modelo-funcional-canonico-oftar.md`, `taxonomia-oftar-final.md`, `clasificacion-anatomica-oftar-final.md`, `politica-identificacion-oftar-final.md`.
- **Dependencias:** etapa 1.
- **Riesgos:** reutilizar prefijos retirados; mezclar `domain_type` con familia; atribuir `ANAT-*`/`AREA-*` a `CLIN-*`.
- **Pruebas:** revisión estática de `OFT-PR-NNNNNN`/`OFT-DX-NNNNNN`, `os_catalog_identifier`, categorías 8 + `GRP-*` + `CAT-DX` + 12 `CLIN-*` y no propagación de agrupaciones.
- **Criterios de aceptación medibles:** 0 `domain_type='oftar'`; 0 catálogos `OFTAR-*`; 0 renombres de categorías históricas; 4 dimensiones separadas.
- **Condición para avanzar:** aprobación documental del responsable.

## Etapa 3 — Cierre del modelo de relaciones clínicas

- **Objetivo `[P]`:** ratificar diccionario, direccionalidad, simetría, jerarquía, cardinalidad y gobernanza de PR-PR, DX-DX, PR-DX, anatomía/función y contexto.
- **Archivos afectados:** `modelo-relaciones-clinicas-oftar.md`, `diccionario-tipos-relacion-oftar.md`, `integracion-os-catalog-oftar.md`.
- **Dependencias:** etapas 1–2.
- **Riesgos:** persistir relaciones PR↔DX en `os_concept_mapping`; inventar `relation_type` dentro del `CHECK` CDT; generar inversas automáticas no equivalentes; propagar `ANAT-UVE`/`ANAT-SUP`.
- **Pruebas:** `plan-pruebas-oftar.md` grupo B; validación de `source_value` ≤ 20 caracteres y unicidad de 7 columnas en `os_catalog_relation`.
- **Criterios de aceptación medibles:** 31/31 tipos documentados con dirección e inversa o ausencia justificada de inversa; 0 inversas automáticas; 0 relaciones clínicas en mapeos; 0 cambios en `CHECK`.
- **Condición para avanzar:** aprobación de arquitectura; la migración aditiva de `relation_type_code` queda propuesta y separada.

## Etapa 4 — Cierre del modelo de relaciones terminológicas

- **Objetivo `[P]`:** ratificar dirección OFTAR→externo, las 8 clases de correspondencia, identidad por sistema/edición/release y gobernanza de SNOMED.
- **Archivos afectados:** `modelo-relaciones-terminologicas-oftar.md`, `integracion-os-concept-mapping-oftar.md`, `matriz-estados-publicacion-oftar.md`, `politica-identificacion-oftar-final.md`.
- **Dependencias:** etapas 1–2.
- **Riesgos:** tratar equivalencia parcial o asociativa como exacta; mezclar CIE-10-ES con ICD-10-CM; usar `exact`/`no_map`/`rejected` como valores de base.
- **Pruebas:** `plan-pruebas-oftar.md` grupos C y D; verificación de `mapping_nature` y de `MappingReviewReader`.
- **Criterios de aceptación medibles:** 8/8 clases mapeadas a valores reales; 0 `exact`; 0 códigos CM convertidos a CIE-10; 0 mapeos SNOMED sin refset `447562003`.
- **Condición para avanzar:** acta de ratificación de dirección y de sistemas/ediciones.

## Etapa 5 — Corrección de código e importadores

- **Objetivo `[P]`:** preparar correcciones de código **en el repositorio**, sin ejecutarlas contra producción: reglas de taxonomía, cierre RFG, resolver `target_code` por identificador y separación clínica/terminológica en lectura.
- **Archivos afectados:** generadores de PR/DX, `importar_nomenclador_oftar_pr.sql`, `sync_oftar_dx_to_os.sql`, `RelatedCodesResolver.php`, `CatalogRepository.php`, `CatalogEngineService.php`, `BrowseController.php`, vistas y tests asociados.
- **Dependencias:** etapas 3–4.
- **Riesgos:** romper contratos `/v1/*`, cambiar defaults de dominios o eliminar filtros históricos.
- **Pruebas:** `tests/run.php` en entorno controlado; diff revisado; comprobación de que `mappings`/`related_codes` siguen intactos.
- **Criterios de aceptación medibles:** 0 rutas renombradas; 0 parámetros históricos eliminados; 0 cambios en `GET /v1/mappings` `LIMIT 50`; diff firmado.
- **Condición para avanzar:** CI en verde y aprobación de código; ningún deploy.

## Etapa 6 — Preparación y normalización de fuentes

- **Objetivo `[P]`:** conservar fuentes originales independientes y normalizar metadatos sin reemplazar una fuente por otra.
- **Archivos afectados:** CSV/zip de NN 2025, CAO, Regional, CIE-10-ES 2026, ICD-10-CM 2027, RF2 de SNOMED; manifiesto de hashes; `tools/sources/...`.
- **Dependencias:** etapas 2 y 4.
- **Riesgos:** etiquetar CIE-10-ES como norma argentina; traducir automáticamente los 17 códigos CM; importar SNOMED completo; usar la cifra 23.292.
- **Pruebas:** conteos reproducibles 2.661 / 2.677 / 2.660 / 17 / 1; 6.783 mapeos H; 90 S05 y 9 `H36.8*`; 0 usos de 23.292.
- **Criterios de aceptación medibles:** cada fila conserva sistema, edición, versión, release, código, descripción original, idioma y procedencia; 0 fuentes fusionadas destructivamente.
- **Condición para avanzar:** acta de normalización firmada.

## Etapa 7 — Generación de seeds en modo `dry-run`

- **Objetivo `[P]`:** **solo diseñar y simular** la preparación de seeds; no generar el artefacto definitivo ni aplicarlo.
- **Archivos afectados:** `propuesta-dry-run-seeds-oftar.md`, manifiesto simulado, reporte de diferencias.
- **Dependencias:** etapas 1–6.
- **Riesgos:** idempotencia mal declarada; claves naturales ambiguas por código repetido; inclusión automática de los 3 candidatos o de las equivalencias no firmadas.
- **Pruebas:** simulación estática de `ON CONFLICT`, orden estable y hashes; comparación esperado vs observado en entorno aislado autorizado.
- **Criterios de aceptación medibles:** 1 familia `oftar`, 2 catálogos, 0 `domain_type='oftar'`, 0 seeds definitivos generados, 0 escrituras en producción; 13 pares y 6 pares marcados según gobernanza; 3 candidatos sin alta automática.
- **Condición para avanzar:** informe de dry-run sin bloqueantes; **su resultado no autoriza la carga**.

## Etapa 8 — Validación de integridad, trazabilidad y duplicados

- **Objetivo `[P]`:** verificar que el manifiesto simulado no rompe unicidad, vigencia, historial ni separación de relational classes.
- **Archivos afectados:** `plan-pruebas-oftar.md`, `modelo-trazabilidad-versionado-oftar.md`, verificaciones `verificacion_*.sql`.
- **Dependencias:** etapa 7.
- **Riesgos:** duplicados por `UNIQUE` mal elegido (4 columnas en mapeos, 7 en relaciones); sobrescritura de versiones publicadas; pérdida de `mapAdvice`/`mapRule`.
- **Pruebas:** grupos A, B, C, D y E del plan de pruebas; comprobación de `os_audit_log` append-only.
- **Criterios de aceptación medibles:** 0 duplicados; 0 relaciones huérfanas; 0 cambios silenciosos por edición; 100% de filas con procedencia y hash cuando corresponda.
- **Condición para avanzar:** 0 fallos bloqueantes y acta de validación firmada.

## Etapa 9 — Revisión editorial y clínica

- **Objetivo `[P]`:** completar las dos revisiones humanas, cerrar las 12 filas a corregir, decidir los 3 conceptos nuevos y aprobar o degradar las equivalencias.
- **Archivos afectados:** `aprobacion-conciliacion-oftar-pr.md`, `revision-clinica-oftar-pr.md`, `revision-clinica-oftar-dx.md`, `os_field_review`, `os_governance_review/decision`.
- **Dependencias:** etapas 3, 4 y 8.
- **Riesgos:** llamar «aprobación clínica» a un dictamen documental; publicar antes de la firma; usar `rejected` como valor de base.
- **Pruebas:** verificación de hash vigente, dos revisores distintos y traza en `os_audit_log`.
- **Criterios de aceptación medibles:** 13/13 pares con firma o degradación; 6/6 correcciones; 48/48 registros con destino; 3/3 candidatos decididos; 0 equivalencias publicadas aún.
- **Condición para avanzar:** firma profesional responsable y del responsable de gobernanza.

## Etapa 10 — Backup y autorización explícita

- **Objetivo `[P]`:** emitir la autorización expresa que hoy no existe y verificar el punto de restauración.
- **Archivos afectados:** acta de autorización, dump verificado, `cuestiones-pendientes-oftar.md` con gates cerrados.
- **Dependencias:** etapas 1–9.
- **Riesgos:** autorización ambigua; backup no restaurable; pendientes abiertos que afecten el alcance.
- **Pruebas:** verificación de solo lectura del dump y del hash de manifiestos; revisión de gates P-01…P-15.
- **Criterios de aceptación medibles:** 1 acta firmada con alcance, responsables, entorno y hash; 0 pendientes bloqueantes abiertos; 0 seeds generados o ejecutados hasta esta etapa.
- **Condición para avanzar:** firma del responsable; sin firma, el plan se detiene.

## Etapa 11 — Carga aditiva y transaccional

- **Objetivo `[P]`:** ejecutar futura carga gobernada, aditiva y transaccional, sin borrar ni reescribir histórico.
- **Archivos afectados:** seeds autorizados, `os_catalog_apply_governed_change`, migración aditiva aprobada de `relation_type_code`, tablas de gobernanza.
- **Dependencias:** etapa 10.
- **Riesgos:** ejecución parcial; columnas nuevas no presentes; privilegios insuficientes; reversión por `DELETE`/`DROP`.
- **Pruebas:** transacción con verificación posterior de conteos, `CHECK`, FKs y `os_audit_log`.
- **Criterios de aceptación medibles:** 0 `DELETE`/`DROP`/`TRUNCATE`; 0 filas existentes modificadas fuera del mecanismo gobernado; rollback probado sobre dump, nunca sobre datos vivos.
- **Condición para avanzar:** commit verificado y acta de carga; cualquier desviación detiene el plan.

## Etapa 12 — Pruebas de búsqueda y API

- **Objetivo `[P]`:** comprobar búsqueda, detalle, Browse y contratos propuestos tras la carga autorizada.
- **Archivos afectados:** `TerminologySearchService.php`, `CatalogEngineService.php`, `MappingReviewReader.php`, `CatalogRepository.php`, `plan-pruebas-oftar.md` grupo F, tests automatizados.
- **Dependencias:** etapa 11.
- **Riesgos:** relaciones no publicadas visibles; mezcla de clases clínica/terminológica; paginación sin tope; pérdida de `Vary`/envelope.
- **Pruebas:** ejecución real de `tests/run.php` y consultas HTTP controladas; comparación con el acta de etapa 1.
- **Criterios de aceptación medibles:** `oftar` en `DOMAINS` y no en `DEFAULT_DOMAINS`; vista con familia/catálogo/ítem/versión correctos; 0 relaciones `draft`/`deprecated` en público; 0 cambios de rutas; paginación con tope.
- **Condición para avanzar:** 0 fallos bloqueantes y evidencia adjunta.

## Etapa 13 — Publicación controlada

- **Objetivo `[P]`:** publicar solo lo aprobado, en release `published`, con traza y posibilidad de retiro gobernado.
- **Archivos afectados:** `os_catalog_release`, `os_field_review`, `os_audit_log`, acta de publicación.
- **Dependencias:** etapas 10–12.
- **Riesgos:** publicar equivalencias documentales como clínicas; publicar `en` sin `es-AR` aprobado; asignar UVR a DX.
- **Pruebas:** verificación de estados por entidad, hash vigente, dos revisores y reglas de visibilidad de la matriz de estados.
- **Criterios de aceptación medibles:** 100% de conceptos publicados con `es-AR` aprobado; 0 UVR en `oftar-dx`; 0 pendientes visibles en público; 1 acta de publicación.
- **Condición para avanzar:** cierre del acta; cualquier cambio posterior crea nueva versión/release sin borrar historial.

---

## Trazabilidad etapa → documento → gate

| Etapa | Documento de origen | Gate |
|---:|---|---|
| 1 | `plan-reconstruccion-oftar.md`, `arquitectura-tecnica-oftar-final.md` §7 | Acta `READ ONLY` firmada |
| 2 | `modelo-funcional-canonico-oftar.md`, `taxonomia-oftar-final.md`, `clasificacion-anatomica-oftar-final.md` | Aprobación documental |
| 3 | `modelo-relaciones-clinicas-oftar.md`, `diccionario-tipos-relacion-oftar.md` | Arquitectura de relaciones aprobada |
| 4 | `modelo-relaciones-terminologicas-oftar.md`, `integracion-os-concept-mapping-oftar.md` | Acta de dirección y sistemas |
| 5 | Código y generadores del repositorio | CI en verde, sin deploy |
| 6 | Fuentes originales y `politica-identificacion-oftar-final.md` | Acta de normalización |
| 7 | `propuesta-dry-run-seeds-oftar.md` | Informe de simulación, sin seeds definitivos |
| 8 | `plan-pruebas-oftar.md`, `modelo-trazabilidad-versionado-oftar.md` | 0 fallos bloqueantes |
| 9 | `aprobacion-conciliacion-oftar-pr.md`, `universo-diagnosticos-oftar-dx.md` | Firma clínica y de gobernanza |
| 10 | `cuestiones-pendientes-oftar.md` | Autorización explícita y backup |
| 11 | Migración aditiva y seeds autorizados | Commit verificado |
| 12 | `contratos-api-relaciones-oftar.md`, `diseno-interfaz-consulta-oftar.md` | Pruebas API/Browse en verde |
| 13 | `matriz-estados-publicacion-oftar.md` | Acta de publicación |

## Regla de rollback y parada `[P]`

- Ante cualquier diferencia con el acta de la etapa 1, escritura no gobernada, valor fuera de los `CHECK` reales o pendiente sin gate, se detiene la etapa y se documenta el bloqueante; no se avanza.
- Rollback futuro = restaurar el dump previo verificado, nunca `DELETE`, `TRUNCATE` ni `DROP`; `os_audit_log` es append-only y no se reescribe.
- Las relaciones y mapeos se sustituyen creando una nueva fila vigente con `valid_from`/`valid_to` y traza, sin borrar la anterior.
- **El plan termina en esta etapa de diseño: no se generaron seeds, no se ejecutaron seeds, no se modificó PostgreSQL, no se hizo commit, push ni deploy.** Queda a la espera de autorización explícita del responsable.
