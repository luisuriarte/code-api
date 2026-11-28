# Plan de implementación controlada del modelo transversal de relaciones

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** plan en ejecución controlada. Código, DDL y semillas del diccionario están preparados y versionados; **no se ejecutaron migraciones, seeds, importaciones ni escrituras en PostgreSQL desde esta sesión**.

---

## 1. Regla general

**[P]** Ninguna etapa posterior a la 10 puede ejecutarse sin autorización explícita, backup verificado y acta. Las semillas del diccionario están generadas pero no ejecutadas; las relaciones clínicas por par siguen sin semilla porque no hay filas ratificadas exportables sin inventar datos. Las etapas 1–9 son de documentación, verificación y preparación de código; no tocan datos.

---

## 2. Etapas

| # | Objetivo | Archivos afectados | Depende de | Riesgo principal | Prueba / verificación | Criterio de aceptación | Gate para avanzar |
|---:|---|---|---|---|---|---|---|
| 1 | Acta `READ ONLY` de esquema y privilegios | `docs/audit/plan-reconstruccion-oftar.md`; nueva acta en `docs/architecture/relaciones/` | Acceso de solo lectura | Estado real distinto del SQL versionado | Consultas A–F; `to_regclass` de Fase 1/4 | Inventario de columnas, CHECK, FKs y filas heredadas | Acta firmada |
| 2 | Ratificar arquitectura transversal y perfiles DENTAR/OFTAR | `00…04` de esta carpeta; rector general; rector OFTAR | Etapa 1 | Perfil incompleto | Revisión por comités | 0 modelos paralelos; sistemas por familia aprobados | Acta de arquitectura |
| 3 | Ratificar diccionario y reglas de dominio | `03-diccionario…`, `04-reglas-validez…`; `docs/audit/diccionario-tipos-relacion-oftar.md` | Etapa 2 | Tipos inválidos o inversas erróneas | Revisión clínica | 31 tipos + 3 ampliaciones pendientes decididos; 0 inversas automáticas | Firma clínica |
| 4 | Definir contrato API y UI compartida | `09…`, `10…`; `docs/audit/contratos-api-relaciones-oftar.md` | Etapa 2 | Romper contratos actuales | Revisión de PR | `mappings`/`related_codes` intactos; un solo componente | Aprobación API/portal |
| 5 | Preflight de migración aditiva (sin ejecutar) | `fase3_relaciones_mapeos.sql`; `fase5_relaciones_transversales.sql`; `verificacion_fase5_relaciones_transversales.sql` | Etapas 1, 3 | `CHECK` cerrado; FKs inválidas | `EXPLAIN`/validación estática y conteos | 0 filas reescritas; 603 relaciones conservadas | Acta DBA |
| 6 | Preparar cambios de código sin desplegar | `CatalogEngineService.php`, `CatalogRepository.php`, vistas, traducciones, `tests/run.php` | Etapa 4 | Mezcla de clases | `php tests/run.php` en entorno aislado | Tests en verde; sin endpoints duplicados | PR revisado |
| 7 | Dry-run de carga (sin escribir) | `docs/audit/propuesta-dry-run-seeds-oftar.md`; propuesta DENTAR | Etapas 3, 5, 6 | Carga de equivalencias falsas | Conteos y muestreo en staging temporal | 0 aprobaciones automáticas; 0 `01.01`→`0101` | Informe de dry-run |
| 8 | Verificar licencias y fuentes | `02-modelo-correspondencias…`, `06-integración…` | Etapa 2 | Uso indebido de CDT/SNOMED | Revisión documental | `license_reference` completo; 0 fuentes sin edición | Acta de terminología |
| 9 | Verificar firmas clínicas pendientes | `docs/audit/aprobacion-conciliacion-oftar-pr.md`, `cuestiones-pendientes-oftar.md` | Etapa 3 | Aprobaciones falsas | Cotejo de 13 pares, 6 correcciones, 48 registros, 3 candidatos | 0 pares sin firma publicados | Firma clínica |
| 10 | Backup y autorización final | runbook de backup; acta de ejecución | Etapas 1–9 | Pérdida de datos | Verificación de dump y rollback | Backup restaurable; autorización explícita | **Autorización de carga** |
| 11 | Aplicar migración aditiva aprobada | `fase5_relaciones_transversales.sql`; `verificacion_fase5_relaciones_transversales.sql` | Etapa 10 | Cambio silencioso de tipos CDT | Verificación post-DDL | `relation_type` legado intacto; 0 filas reescritas | Acta post-DDL |
| 12 | Cargar diccionario y relaciones autorizados | `fase5_semillas_tipos_relacion.sql`; artefactos ratificados por par | Etapas 10, 11 | Duplicados / equivalencias por texto | `11-plan-pruebas…` T-01…T-38 | 0 huérfanos; 0 equivalencias automáticas | Informe de carga |
| 13 | Ejecutar pruebas transversales y publicar | `11-plan-pruebas…`; API/portal | Etapa 12 | Regresión API | `php tests/run.php` + T-01…T-38 | Todo en verde; UI separada; traza completa | Autorización de publicación |
| 14 | Cierre y monitorización | acta final; `docs/audit/informe-final-relaciones-transversales.md` | Etapa 13 | Deriva posterior | Auditoría periódica | Historial inmutable; cambios por nueva propuesta | Cierre formal |

---

## 3. Prohibiciones durante el plan

- No ejecutar etapas 11–14 sin autorización explícita.
- No ejecutar seeds sin acta, backup y firma clínica; no generar relaciones por par sin evidencia ratificada.
- No importar códigos externos como equivalentes.
- No borrar ni reescribir relaciones aprobadas.
- No publicar relaciones o mapeos pendientes.
- No alterar `DNT-*`, `OFT-*`, `01.01`, códigos CDT/CAO/Regional.
- No usar `DELETE`, `DROP` ni `TRUNCATE` como mecanismo de corrección.

---

## 4. Estado actual

**[H]** Etapas 1–9: documentadas; etapa 6 con código preparado en el repositorio. **[P]** Etapa 10: autorización, puertas y base destino `origen_codes` registradas en `docs/audit/acta-ejecucion-relaciones-transversales.md`; falta ejecutar la verificación `READ ONLY` desde un entorno con cliente PostgreSQL y conectividad. Etapas 11–14: scripts preparados, **no ejecutados**. No se ha ejecutado SQL, migración, seed, importador, commit, push ni deploy desde esta sesión.
