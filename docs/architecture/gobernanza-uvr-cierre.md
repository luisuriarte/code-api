# Gestión UVR · cierre de la implementación U0–U6

**Estado:** U0–U6 completos; migración U1 ejecutada y **verificada en base** el
2026-11-20 (`COMMIT` + verificación de diez apartados con `ROLLBACK` final).
**Fecha:** 2026-11-20.
**Autorización:** plan U0–U6 aprobado y acta
[`gobernanza-uvr-acta-u0.md`](gobernanza-uvr-acta-u0.md) con C1–C12 cerrados.

> **Ampliación posterior:** el acta
> [`gobernanza-uvr-acta-u7.md`](gobernanza-uvr-acta-u7.md) declara la gobernanza
> transversal de prestaciones. No modifica este cierre. Las fases U7-B/C/D
> fueron aprobadas el 2026-11-20: U7-B fue **aplicado y verificado por el
> responsable** el mismo día, con backup verificado; U7-C y U7-D están
> implementados en código con detección de esquema y **no desplegados**. La
> aprobación no habilitó al agente a aplicar SQL ni a publicar cambios.

---

## 1. Lo que quedó cerrado

| Fase | Resultado |
|---|---|
| U0 | Acta U0 aprobada. C1–C12 resueltos por el responsable, no por el agente. Correcciones documentales aplicadas en `propuesta-arquitectura-catalogos-sanitarios.md` §10/§11 y en `README-UVR.md` (typo `professioniabial_liability_uvr`). |
| U1 | `uvr_gobernanza_datos.sql` ejecutado con `COMMIT`; `verificacion_uvr_gobernanza.sql` completado con `ROLLBACK`. Detalle en [`gobernanza-uvr-acta-verificacion.md`](gobernanza-uvr-acta-verificacion.md). |
| U2 | Servicios y repositorio: `UvrGovernanceService`, `UvrGovernanceException`, `UvrImporteService`, `UvrRepository`. Decisiones y auditoría en backend. |
| U3 | Vistas A–G bajo `/admin/uvr`, controlador `AdminUvrController`, rutas, `AdminGuard`, CSRF, RBAC de 14 permisos existentes y paridad `es-AR`/`en`/`pt-BR`/`es`. |
| U4 | Trigger de inmutabilidad y auditoría append-only de las cuatro tablas UVR, con actor desde `app.actor_id`. |
| U5 | Importe referencial derivado en `UvrImporteService`; `null` sin conversión aprobada; redondeo a dos decimales solo en presentación. |
| U6 | Este documento, actualización del README de SQL y verificación canónica. |

## 2. Decisiones gestionadas vigentes

- `total_uvr` e `importe_referencial` son **derivados**, nunca columnas.
- Precisión almacenada según el modelo; presentación a **dos decimales**.
- `0` = medido; ausencia = marcador **no aplicable**; negativo **solo con evidencia**.
- Responsable, revisor y aprobador con **FK a `os_admin.app_user`**.
- **Dos revisiones** clínica y económica, con actores distintos y `catalog.review`.
- Cuatro **planos lógicos**, sin esquemas ni gestión paralela.
- Valoración aprobada/publicada se corrige con **nueva fila/versión**.
- Legado y denominación visible «Responsabilidad profesional» intactos; API
  pública, OpenAPI, API keys y scopes **sin cambios**.
- No existen `/v1/uvr` ni `/fhir/*`; la página pública `/uvr` sigue siendo
  metodológica y trilingüe.

## 3. Gerencias y pantallas

| Ruta | Vista | Permiso |
|---|---|---|
| `/admin/uvr` | A · Valoraciones e importe derivado | `catalog.view` |
| `/admin/uvr/catalogs` | B · Catálogos editables | `catalog.view` |
| `/admin/uvr/proposals` | C · Propuestas y alta gestionada | `catalog.view` / `catalog.propose` |
| `/admin/uvr/proposals/{id}` | C · Detalle, revisiones y decisión | `catalog.view` / `catalog.review` / `catalog.approve` |
| `/admin/uvr/tasks` | D · Cola derivada | `catalog.review` |
| `/admin/uvr/compare` | E · Comparación de versiones | `catalog.view` |
| `/admin/uvr/methodologies` | F · Metodologías y vigencia | `catalog.view` |
| `/admin/uvr/monetary` | G · Conversión e índices | `catalog.view` |

La separación de funciones se comprueba en servicio con `Rbac::canApprove()`:
quien propone no aprueba. Las denegaciones explícitas por grant prevalecen.

## 4. Verificación

- Migración ejecutada por el responsable: `COMMIT` sin errores. Los `NOTICE:
  trigger ... does not exist, skipping` son esperados en primera ejecución.
- Verificación definitiva: diez apartados sin errores y `ROLLBACK` final.
  Registro completo en [`gobernanza-uvr-acta-verificacion.md`](gobernanza-uvr-acta-verificacion.md).
- Modelo: 12 objetos presentes; 5 columnas gestionadas; 0 columnas `total_uvr`;
  6 FK a `os_admin.app_user`; 3 CHECK; 8 triggers; 0 grantees `PUBLIC`.
- Datos: 8 tablas UVR/de gestión en 0 salvo `os_uvr_eligible_catalog = 1`.
- Regresión observada: `603 | 22 | 0 | 0 | 9 | 10 | 10 | 40`. Los valores
  heredados `3 | 7` se comprueban en `verificacion_fase7.sql` §8.
- `php -l` sobre todos los archivos PHP nuevos y modificados → sin errores.
- `php tests/run.php` → **`OK: 3023 comprobaciones`**, incluida la regresión
  del acta de verificación.

## 5. Pendiente de autorización

1. Commit/push de los cambios locales: el agente no los realiza.
2. Despliegue del panel A–G y habilitación del enlace para roles con
   `catalog.view`: los permisos SQL ya están concedidos a `origen_admin`.
3. Opcional y no ejecutado: reducir a `SELECT` los privilegios heredados por las
   dos vistas en `origen_admin` (detalle en el acta de verificación, §3).


**El agente no ejecuta SQL, no carga valores UVR, no hace commit, push ni
despliegue.**

## 6. Límites no cruzados

No se tocaron importadores, fuentes originales, catálogos publicados, DENTAR,
la arquitectura multilingüe aprobada, el portal público, dependencias ni VPS.
No se reejecutaron las migraciones `sql/07_multilingue/01`–`15`. D-31 y
`OS_IMPORT_MODE` permanecen como estaban.
