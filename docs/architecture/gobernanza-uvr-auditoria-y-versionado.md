# Gestión UVR · auditoría, versionado e inmutabilidad

**Estado:** PROPUESTA DOCUMENTAL. **No implementada.**
**Depende de:** [`gobernanza-uvr-arquitectura.md`](gobernanza-uvr-arquitectura.md) §6 (C2, C4, C9, C12).

> No se modifica ningún trigger ni tabla de auditoría. Se documenta lo que ya
> existe, lo que falta y el protocolo de verificación que el responsable deberá
> ejecutar si aprueba fases SQL futuras.

---

## 1. Auditoría existente [REPO]

### 1.1 Panel administrativo

`os_admin.audit_log` (`sql/09_admin/fase1_identidad.sql:140-171`):

- Columnas: `actor_user_id`, `actor_email`, `action`, `entity_type`, `entity_id`,
  `catalog_code`, `before_state JSONB`, `after_state JSONB`, `reason`, `ip_hash`,
  `user_agent_hash`, `request_id`, `occurred_at`.
- `actor_user_id` **no tiene FK declarada**; el actor legible es `actor_email`.
- Trigger `trg_audit_log_immutable BEFORE UPDATE OR DELETE` lanza
  `os_admin.audit_log es append-only`.
- `origen_admin` solo tiene `SELECT, INSERT` (`fase1_identidad.sql:207-208`).
- `AuditLogger::record()` construye el evento, hashea IP y user-agent con pepper
  y sanitiza `request_id` con regex de 80 caracteres
  (`portal/Admin/AuditLogger.php:11-43`). La documentación interna exige
  *fail closed*: si falla la auditoría, falla la operación
  (`AuditLogger.php:14-16`).
- `AuditRepository` solo construye `INSERT`; `recent()` limita entre 1 y 100
  filas y no selecciona `before_state`/`after_state`
  (`portal/Repositories/AuditRepository.php:10-71`).
- La vista de auditoría exige `audit.view` y muestra 50 eventos
  (`portal/Controllers/AdminHomeController.php:32-50`).
- Eventos existentes: `login_*`, `logout`, `organization_*`, `invitation_*`,
  `membership_*`, `catalog_grant_*`, `password_reset_*`, cambio de contexto.

### 1.2 Gestión pública

`public.os_audit_log` (`sql/08_arquitectura/fase4_gobernanza.sql:120-227`):

- Columnas: `entity_type`, `entity_id`, `action`, `actor`, `actor_user_id` con FK
  a `os_admin.app_user ON DELETE SET NULL`, `request_id`, `before_state`,
  `after_state`, `occurred_at`.
- Trigger inmutable `trg_os_audit_log_immutable`.
- Triggers sobre `os_governance_request`, `os_governance_review` y
  `os_governance_decision`: capturan `INSERT/UPDATE/DELETE`.
- Resolución del actor: `approved_by` → `reviewer_actor` → `requested_by` →
  `app.actor_id` → `current_user` (`fase4_gobernanza.sql:192-203`).

### 1.3 Lo que falta para UVR

| Brecha | Evidencia |
|---|---|
| No hay trigger de auditoría sobre `os_uvr_valuation`, `os_uvr_component`, `os_uvr_conversion` ni `os_uvr_geo_index`. | `fase4_gobernanza.sql:217-227`; `fase6_uvr.sql:85-167` |
| `calculated_by TEXT` no es actor gobernado. | `fase6_uvr.sql:93` |
| No hay `reviewed_by_user_id`, `approved_by_user_id` ni `published_at` en UVR. | `fase6_uvr.sql:85-167` |
| No hay `GRANT` posterior a ningún rol de aplicación para gestión/UVR. | `fase4_gobernanza.sql:232-249`; `fase6_uvr.sql:235-254` |

## 2. Propuesta de auditoría UVR (sin DDL)

1. **Un solo destino.** Todo evento UVR se registra en `public.os_audit_log` o
   en `os_admin.audit_log` según el plano, sin crear un tercer log.
2. **Eventos mínimos:** `uvr_valuation_proposed`, `uvr_component_changed`,
   `uvr_review_clinical_recorded`, `uvr_review_economic_recorded`,
   `uvr_decision_recorded`, `uvr_published`, `uvr_retired`,
   `uvr_conversion_changed`, `uvr_geo_index_changed`.
3. **Actor obligatorio:** `actor_user_id` con FK; si no hay usuario de sesión,
   fallo cerrado. Nunca `current_user` como único actor en operaciones humanas.
4. **Antes/después:** `before_state`/`after_state` JSONB con solo campos
   gobernados; sin contraseñas, hashes, tokens, correos completos ni datos
   clínicos sensibles.
5. **Razón y evidencia:** `reason` y `evidence_reference` obligatorios para
   aprobar/retirar/publicar.
6. **Append-only:** ningún `UPDATE`/`DELETE`; los cambios se corrigen con un
   evento nuevo y, cuando aplique, una nueva fila de valoración.
7. **Sin secretos:** `app.actor_id` puede usarse solo como complemento; los
   tokens de invitación/reset jamás se escriben en auditoría
   (`tests/run.php:1548-1555`).

## 3. Versionado existente

| Mecanismo | Evidencia |
|---|---|
| `os_review_state` con `is_publication_allowed`. | `sql/08_arquitectura/fase1_infraestructura.sql:85-102` |
| `os_domain_registry` con 12 dominios (`snomed`, `cie10`, `anmat`, `odontologia`, `prestaciones`, etc.). | `fase1_infraestructura.sql:12-38` |
| `os_catalog_release`: `version_tag`, `valid_from/to`, `status` y norma oficial. | `sql/02_catalogs/origen_catalog_engine.sql:42-52` |
| `os_catalog_item.permanent_code` y estados `active/retired/superseded`. | `origen_catalog_engine.sql:63-70` |
| Contenido versionado por `UNIQUE(item_id, release_id, language_code)`. | `origen_catalog_engine.sql:72-82` |
| `version_tag` + `methodology` en la unicidad de `os_uvr_valuation`. | `fase6_uvr.sql:85-102` |
| Vigencia en conversiones e índices (`period_start/period_end`). | `fase6_uvr.sql:121-167` |
| Revisión por campo `os_field_review`, D-19 y D-31. | `sql/07_multilingue/01_fase2_tablas.sql:122-134`; `15_d19...:28-95`; `18_fase11...:43-94` |

Ninguna tabla UVR usa `domain_code`: la elegibilidad es solo por
`catalog_code` texto (`fase6_uvr.sql:66-71`). La noción de «dominio UVR» del
documento del usuario no debe resolverse unilateralmente creando un dominio
nuevo o tablas propias (conflicto C6).

## 4. Inmutabilidad histórica

La arquitectura aprobada exige «nueva valoración = nueva fila, nunca `UPDATE`»
(`propuesta-arquitectura-catalogos-sanitarios.md:747`). En la base actual:

- La `UNIQUE` de `os_uvr_valuation` permite nuevas filas por `version_tag` y
  metodología.
- El trigger existente solo actúa en `INSERT` o `UPDATE OF service_item_id`
  para validar elegibilidad (`fase6_uvr.sql:200-203`).
- Por tanto, `UPDATE` de componentes, metodología, fuente o estado **está
  permitido hoy**.

**No se refuerza este comportamiento sin aprobación (C12).** Si se aprueba, la
regla propuesta es:

- Ninguna fila publicada se edita: corrección = nueva fila con nuevo
  `version_tag`/release y nueva decisión con evidencia.
- Se conserva el trigger de elegibilidad actual.
- Se añade un guardián que rechace `UPDATE` no aditivo sobre valoraciones
  publicadas, con mensaje explícito y registro en auditoría.
- Los borradores sí pueden editarse hasta que sean `approved`/`published`.

## 5. Protocolo de verificación SQL (para fases futuras)

El agente **solo prepara archivos y comandos**. El responsable los ejecuta en el
servidor como `sudo -u postgres`, con backup verificado.

Verificación previa, sin cambios:

```sql
BEGIN READ ONLY;
-- consultas de conteo, constraints, triggers, grants y regresiones
ROLLBACK;
```

Ejecución de migración aprobada (plantilla, **no ejecutada aquí**):

```bash
cd /var/www/html/origen.ar/code-api
sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/<archivo_aprobado>.sql
```

Reglas del protocolo:

- `BEGIN READ ONLY` / `ROLLBACK` para toda verificación; nunca `COMMIT` en
  consultas de comprobación.
- No reejecutar `sql/07_multilingue/01`–`15`; D-31 y `OS_IMPORT_MODE` están
  resueltos.
- Si hay tablas nuevas, aplicar `REVOKE ALL PRIVILEGES ... FROM PUBLIC` y,
  condicionado a `to_regrole('origen_admin')`, el `REVOKE` correspondiente.
  **No usar `ALTER DEFAULT PRIVILEGES` global**: afecta a otras tablas.
- Regresión a comprobar: `603 / 22 / 0 / 0 / 3 / 7`; legado farmacéutico
  `9 / 10 / 10 / 40`.
- `NOTICE: trigger ... does not exist, skipping` en `DROP TRIGGER IF EXISTS` es
  esperado en primera ejecución.
- Sin tokens ni contraseñas en claro en archivos ni en auditoría.
- Rollback documentado por fase: las verificaciones no escriben; las
  migraciones aprobadas deben incluir su propio criterio de reversión
  documental antes de ejecutarse.

## 6. Matriz de evidencia a conservar

| Hecho | Evidencia actual |
|---|---|
| Auditoría del panel es append-only. | `sql/09_admin/fase1_identidad.sql:160-171` |
| Auditoría pública es append-only. | `sql/08_arquitectura/fase4_gobernanza.sql:136-147` |
| Decisiones exigen evidencia escrita. | `fase4_gobernanza.sql:104,108-109` |
| Actores de gestión tienen FK a `app_user`. | `fase4_gobernanza.sql:67,85,101,126` |
| No hay auditoría sobre tablas UVR. | `fase6_uvr.sql:85-167` |
| `total_uvr` no se almacena. | `verificacion_fase7.sql:82-86` |
| No hay columna UVR con actor fuerte. | `fase6_uvr.sql:93` |
| Tokens no se auditan. | `tests/run.php:1548-1555` |
