# Acta de ejecución — modelo transversal de relaciones

**Fecha:** 2026-11-28
**Estado:** **Ejecutada y verificada por el responsable en producción el 2026-11-28.** DDL y semillas aplicados en `origen_codes`; verificación posterior y regresión estática conformes. Quedan pendientes T-01…T-38, la publicación gobernada y el adjunto de salidas al expediente. **Este documento no autoriza por sí solo la ejecución.**
**Referencia:** `docs/architecture/relaciones/12-plan-implementacion-relaciones-transversales.md`, etapas 10–13.

---

## 1. Identificación

| Campo | Valor |
|---|---|
| Responsable de ejecución | Luis A. Uriarte |
| Responsable de firma clínica | Luis A. Uriarte |
| Responsable DBA | Luis A. Uriarte |
| Base de datos destino | `origen_codes` (confirmada por el responsable el 2026-11-28) |
| Entorno | Producción con acta |
| Rama de trabajo | `feat/relaciones-transversales` |
| Commit de partida | `07168a4` |

**[H]** La base destino quedó confirmada como `origen_codes`; no se infirió de `.env.example` ni de valores por defecto. Las credenciales autorizadas no se registran en el repositorio.

---

## 2. Puertas previas

| # | Puerta | Estado | Evidencia |
|---:|---|---|---|
| 1 | Documentación aprobada por el usuario | **[H] Sí** | Mensaje de aprobación del 2026-11-28. |
| 2 | Ratificación clínica cerrada | **[H] Declarada por el usuario** | Luis A. Uriarte; referencia de acta a adjuntar al expediente. |
| 3 | Backup verificado y restaurable | **[H] OK declarado** | ID `20261126`; fecha `2026-11-26`; prueba de restore declarada. |
| 4 | `to_regclass` y columnas vigentes de Fase 1/3/4 | **[H] OK declarado** | `SALIDA_READ_ONLY` a adjuntar al expediente. |
| 5 | Cliente PostgreSQL disponible y credenciales autorizadas | **[H] OK declarado** | Confirmado por el responsable; valores no registrados en el repositorio. |
| 6 | Conteo previo 333 CDT + 270 Nomenclador | **[H] OK declarado** | `CONTEO_PREVIO` a adjuntar al expediente. |
| 7 | Plan de rollback firmado | **[H] OK declarado** | `ROLLBACK_ID` a adjuntar al expediente. |

---

## 3. Secuencia autorizada

1. Ejecutar verificaciones `READ ONLY` de esquema, constraints y filas heredadas.
2. Confirmar backup y rollback.
3. Aplicar DDL **aditivo** (sin `DROP`, `DELETE` ni `TRUNCATE`).
4. Verificar que `relation_type` legado y las 603 relaciones quedan intactas.
5. Cargar únicamente filas derivadas de artefactos versionados y ratificados.
6. Ejecutar `php tests/run.php` y el plan T-01…T-38.
7. Publicar solo si todas las puertas están en verde.

---

## 4. Prohibiciones

- No ejecutar mientras falte backup, cliente PostgreSQL, credenciales o verificación de esquema.
- No borrar ni reescribir relaciones aprobadas.
- No convertir relaciones clínicas en mapeos.
- No aprobar equivalencias por coincidencia textual.
- No usar `23.292` ni catalogar CIE-10-ES como norma argentina.

---

## 5. Cierre

**[H]** Las siete puertas fueron declaradas en verde por Luis A. Uriarte y la base destino quedó confirmada como `origen_codes`. **[H]** La ejecución fue realizada por el responsable en el VPS `/var/www/html/origen.ar/code-api`; el agente no escribió en PostgreSQL. **[H]** Verificación corregida y `php tests/run.php` repetidos en el VPS con resultado `OK: 4110 comprobaciones`. **[P]** Quedan completar T-01…T-38 y publicar solo con gobernanza; no hay commit, push ni deploy registrados.

---

## 6. Ejecución registrada

**[H]** Salidas capturadas por el responsable el 2026-11-28:

| Paso | Resultado |
|---|---|
| Verificación previa | Falló en la consulta de `relation_type_code` porque la columna aún no existía. No hubo escritura: la transacción era `READ ONLY` y terminó sin `COMMIT`. El script fue corregido con `\if` para omitir esa consulta antes del DDL. |
| DDL `fase5_relaciones_transversales.sql` | `BEGIN / SET / SET / DO / ALTER TABLE / DO / COMMIT` correctos. |
| Semillas `fase5_semillas_tipos_relacion.sql` | `INSERT 0 31`, `UPDATE 2`, `COMMIT` correctos. |
| Verificación posterior | 603 relaciones, 15 tipos heredados, 0 con `relation_type_code`, 316 `referencia_literal`, 31 tipos `OFTAR-v1.0`, 2 inversas, 0 huérfanos, FK `fk_ocr_relation_type_code` presente. |
| Regresión estática inicial | `FALLOS (2 de 4110)`: sitemap esperaba 30 URLs/x-default; en producción `.env` habilita `/solicitud` y genera 33. No está relacionado con relaciones. |
| Corrección | `tests/run.php` fija `PORTAL_SERVICE_REQUEST_LINK_ENABLED=false` durante la generación del sitemap y restaura el valor previo. |
| Repetición en VPS | Verificación corregida conforme; `php tests/run.php` → **`OK: 4110 comprobaciones`**. Salidas: `/tmp/fase5_verificacion_post_corregida.log` y `/tmp/fase5_tests_corregido.log`. |

**[P]** Adjuntar al expediente `/tmp/fase5_verificacion_post_corregida.log` y `/tmp/fase5_tests_corregido.log`, ejecutar T-01…T-38 y decidir la publicación con gobernanza. No se cargaron relaciones clínicas por par.
