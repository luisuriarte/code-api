# Gestión UVR · plan de implementación propuesto

**Estado:** PLAN DOCUMENTAL. **No autorizado para ejecutar.**
**No incluye:** DDL/DML ejecutado, carga de valores, rutas de API, código,
commits, push ni despliegue.
**Requiere:** aprobación expresa y cerrar los conflictos C1–C12 de
[`gobernanza-uvr-arquitectura.md`](gobernanza-uvr-arquitectura.md) §6.

---

## 1. Punto de partida verificado

| Hecho | Evidencia |
|---|---|
| Fase 7 (§16) cerrada en base: 5 tablas UVR, 1 elegibilidad real (`dentar-pr`), 4 tablas vacías. | `sql/08_arquitectura/README.md:336-380` |
| `total_uvr` derivado en vista; ninguna columna almacenada. | `fase6_uvr.sql:206-230`; `verificacion_fase7.sql:82-86` |
| Gestión Fase 5 cerrada en base, vacía y sin conexión con el panel. | `sql/08_arquitectura/README.md:278-289`; `sql/09_admin/README.md:107-116` |
| M1/M2 de identidad aplicados; 8 roles, 14 permisos, grants por catálogo y auditoría append-only. | `sql/09_admin/README.md:3-29`; `portal/Admin/Rbac.php:17-59` |
| API pública solo `/v1/*` y `/health`; sin `/v1/uvr` ni `/fhir/*`. | `api/index.php:192-227`; `docs/architecture/fase12-fhir-contrato.md:19-33` |
| Portal UVR: metodología trilingüe, solo lectura, sin valores. | `web/uvr.php:5-10`; `tests/run.php:1160-1184` |
| Panel admin sin UVR ni flujo de propuestas/revisiones. | `portal/Router.php:145-363`; `portal/Views/layouts/admin.php:40-51` |
| Verificador canónico vigente. | `php tests/run.php` → `OK: 2883 comprobaciones` (estado previo conocido) |

## 2. Compuertas previas (Gate 0)

Antes de escribir cualquier archivo de implementación se requiere un acta que
cierre:

| ID | Decisión |
|---|---|
| C1 | Confirmar `total_uvr` derivado, nunca almacenado. |
| C2 | Precisión, escala y redondeo de componentes, total, conversión e importe. |
| C3 | Semántica de `0`, no aplicable y posibles ajustes negativos. |
| C4 | Responsable de cálculo y aprobador UVR; decisiones 7 y 11 del §15.2. |
| C5 | Independencia entre revisión clínica y revisión económica; ¿permiso propio? |
| C6 | Interpretación de los cuatro dominios/planos sin gestión paralela. |
| C7 | Nombre canónico del importe: `estimated_payment` o `importe_referencial`. |
| C8 | Autorización para conectar panel con Fase 5 y construir vistas A–G. |
| C9 | Corrección autorizada de §10/§11 y de nombres/typo detectados. |
| C10 | Glosario de equivalencias `malpractice` → Responsabilidad profesional sin renombrar legado. |
| C11 | Confirmar que API keys, scopes y rate limit quedan fuera de alcance. |
| C12 | Regla de inmutabilidad: nueva fila vs `UPDATE` en valoraciones publicadas. |

**Si alguna queda abierta, la fase correspondiente no comienza.**

## 3. Fases propuestas (numeración U, distinta del §16)

| Fase | Objetivo | Entregable del agente | Quién ejecuta | Verificación | Rollback |
|---|---|---|---|---|---|
| U0 · Acta y documentación | Cerrar C1–C12; corregir documentación aprobada solo si se autoriza. | Acta y propuestas de texto; sin SQL. | Responsable aprueba. | Revisión documental. | No aplica. |
| U1 · Modelo de datos | Ajustar metadatos de gestión UVR sin tocar legado. | Archivos SQL preparados + verificación read-only; **no ejecutados**. | Responsable con `sudo -u postgres` y backup. | `BEGIN READ ONLY`/`ROLLBACK`; conteos y constraints. | Script de corrección aditiva; nunca `DROP` de datos. |
| U2 · Backend de gestión | Repositorios/servicios para propuesta, revisión, decisión y worklist. | Código propuesto, no aplicado; sin rutas nuevas. | Responsable autoriza despliegue. | `php -l`, `php tests/run.php`, pruebas unitarias. | Revertir commit (si se autoriza commits). |
| U3 · Panel A–G | Vistas administrativas con permisos existentes y paridad i18n. | Vistas/controladores/plantillas preparados; conexión Fase 5 solo si C8. | Responsable autoriza. | `AdminGuard`, CSRF, Rbac, `tests/run.php`. | Retirar rutas/vistas; reforzar gobernanza. |
| U4 · Publicación controlada | Guardián de publicación y auditoría UVR. | SQL/código preparado; sin datos cargados. | Responsable ejecuta. | Verificación read-only de triggers y grants; auditoría append-only. | Desactivar trigger y documentar; no borrar eventos. |
| U5 · Conversión e importe derivado | Vista derivada de `uvr_value`/índices con rotulado de estimación. | Definición de vista, sin columnas nuevas. | Responsable aprueba. | Comprobar que no hay columna de importe; regresiones. | Retirar vista; no afecta tablas. |
| U6 · Cierre | Documentar estado final y regresiones. | Documentos de cierre y acta. | Responsable aprueba. | `603/22/0/0/3/7`, legado `9/10/10/40`, `tests/run.php`. | No aplica. |

## 4. Detalle por fase

### U0 · Acta y documentación

- Entrada: este paquete de seis documentos.
- Salida: acta con C1–C12 resueltos.
- Límites: no SQL, no código, no base, no despliegue.
- Criterio: cada decisión tiene responsable, fecha y texto aprobado.

### U1 · Modelo de datos

- Entrada: acta U0 y modelo descrito en `gobernanza-uvr-modelo-datos.md`.
- Salida: archivos bajo `sql/08_arquitectura/` con numeración nueva acordada,
  siguiendo el patrón de `fase11_integracion_farmacia.sql` (comentarios de
  intención, `source_reference`, `REVOKE`, verificación separada).
- Prohibiciones: no `DROP`, `TRUNCATE`, `DELETE`, no renombrar legado, no cargar
  valores UVR, no `ALTER DEFAULT PRIVILEGES` global.
- Ejecución: solo por el responsable, con backup verificado.
- Verificación: `BEGIN READ ONLY;` → conteos, FKs, triggers, grants →
  `ROLLBACK;`. Regresión `603/22/0/0/3/7` y legado `9/10/10/40`.

### U2 · Backend

- Entrada: esquema U1 aprobado y acta C4/C5/C12.
- Salida: servicios que enlacen `os_governance_*` con valoraciones UVR;
  `Rbac::canApprove()` invocado en la capa de servicio.
- Límites: **ninguna ruta `/v1/uvr`**, ninguna ruta `/fhir/*`, ningún cambio en
  la guardia de API Key (`api/index.php:223-227`).
- Verificación: `php -l`, `php tests/run.php` y pruebas de separación de
  funciones; sin exponer secretos en logs.

### U3 · Panel A–G

- Entrada: U2 y autorización C8.
- Salida: vistas A–G con `AdminGuard`, CSRF, RBAC y claves `admin:`/`uvr:` en
  `es-AR`, `en` y `pt-BR`.
- Patrones: `portal/Views/admin/`, `portal/Views/partials/browse/`,
  `web/assets/css/app.css`.
- Límites: no publicar reservas DENTAR/OS ni valores no aprobados; no crear
  catálogos nuevos.
- Verificación: paridad de claves (`tests/run.php:1186-1215,1379-1408`) y
  regresión de rutas existentes.

### U4 · Publicación controlada

- Entrada: U1–U3 y decisión C12.
- Salida: guardián único basado en `os_review_state.is_publication_allowed`,
  fuente verificable y evidencia; auditoría append-only de eventos UVR.
- Límites: no `UPDATE` destructivo sobre valoraciones publicadas; sin datos
  nuevos cargados.
- Verificación: triggers activos, 0 grantees no deseados, eventos auditados.

### U5 · Conversión e importe derivado

- Entrada: decisión C7.
- Salida: vista derivada; importe rotulado como estimación, nunca arancel.
- Límites: no columna `estimated_payment`/`importe_referencial`; no consumir
  `os_pricing_values` ni `os_fee_item` como fuente UVR.
- Verificación: ausencia de columna, separación valoración/conversión.

### U6 · Cierre

- Salida: acta de cierre, documentación actualizada bajo aprobación y
  comprobación de regresiones.
- No despliegue sin autorización nueva.

## 5. Protocolo operativo para SQL

El agente **prepara**; el responsable **ejecuta**.

```bash
cd /var/www/html/origen.ar/code-api
# Verificación previa (solo lectura)
sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/verificacion_<fase>.sql

# Migración aprobada, solo tras backup verificado
sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/<archivo_aprobado>.sql
```

Reglas obligatorias:

1. Toda verificación usa `BEGIN READ ONLY;` y `ROLLBACK;`.
2. No reejecutar `sql/07_multilingue/01`–`15`; D-31 y `OS_IMPORT_MODE` ya están
   resueltos.
3. `REVOKE ALL PRIVILEGES ... FROM PUBLIC` y `REVOKE` condicionado a
   `origen_admin` para cada tabla nueva; sin `ALTER DEFAULT PRIVILEGES` global.
4. `NOTICE: trigger ... does not exist, skipping` es esperado en primera
   ejecución de `DROP TRIGGER IF EXISTS`.
5. Sin secretos en claro; sin correos completos ni tokens en auditoría.
6. Regresión y legado se comprueban antes y después.
7. Rollback documentado por fase; ante duda, `ROLLBACK` y alto.

## 6. Criterios globales de aceptación

- [ ] C1–C12 cerrados por acta.
- [ ] `total_uvr` e importe siguen siendo derivados.
- [ ] No hay `/v1/uvr`, `/fhir/*` ni cambios en la guardia de API Key.
- [ ] API pública y OpenAPI intactas.
- [ ] Catálogos reservados DENTAR/OS siguen sin `catalog_id` real.
- [ ] Legado `rvu`/`malpractice_uvr` intacto; DENTAR, OS-* y farmacéutico sin migrar.
- [ ] M1/M2, contexto activo, último `superadmin` y revocación por membership intactos.
- [ ] Auditoría append-only; sin tokens/contraseñas; `audit.view` para lectura.
- [ ] Vistas A–G, si se autorizan, usan permisos existentes y paridad trilingüe.
- [ ] `php tests/run.php` y verificaciones SQL read-only sin regresiones.
- [ ] Sin commits, push ni despliegue sin autorización nueva.

## 7. Estado actual de este plan

**Este documento no autoriza ninguna de las fases U0–U6.** Es la propuesta que
el responsable debe aprobar o ajustar. Hasta que exista aprobación expresa, el
repositorio permanece exactamente como estaba: UVR como metodología pública y
estructura SQL vacía; gestión genérica preparada; API y portal sin cambios.
