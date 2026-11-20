# Acta U0 · Gobernanza UVR — cierre de la compuerta 0

**Estado:** APROBADA.
**Fecha:** 2026-11-20.
**Autorización:** aprobación expresa del responsable del plan U0–U6 y respuestas
a las seis decisiones presentadas tras la revisión del plan.

Esta acta cierra los conflictos **C1–C12** registrados en
[`gobernanza-uvr-arquitectura.md`](gobernanza-uvr-arquitectura.md) §6 y permite
iniciar U1. No autoriza commits, push ni despliegue.

## 1. Decisiones aprobadas

| ID | Decisión aprobada | Consecuencia operativa |
|---|---|---|
| C1 | `total_uvr` permanece **derivado**, nunca columna almacenada. | Se conserva `v_os_uvr_valuation_total` y su verificador. |
| C7 | Nombre visible: **`importe_referencial`**. Interno/FHIR: `estimated_payment`. | Se documenta equivalencia; no se crea columna de importe. |
| C9 | Corregir §10/§11 y el typo `professioniabial_liability_uvr`. | Ya aplicado en `propuesta-arquitectura-catalogos-sanitarios.md` y `README-UVR.md`. |
| C2 | Precisión almacenada según SQL vigente; **presentación a 2 decimales**. | Regla de presentación en servicios y textos públicos. |
| C3 | `0` = medido; ausencia = marcador de **no aplicable**; negativos **con evidencia**. | Nueva columna de evidencia y CHECK revisado en U1. |
| C4 | Responsable, revisor y aprobador con **FK a `os_admin.app_user`**. | Columnas de actor con FK en U1. |
| C12 | Valoraciones publicadas se corrigen con **nueva fila**, sin `UPDATE`. | Trigger de inmutabilidad en U1. |
| C5 | **Dos revisiones independientes** con `catalog.review`, actores distintos, sin permiso nuevo. | Servicio UVR y vistas A–G. |
| C6 | Cuatro **planos lógicos**, sin dominios ni gobernanza paralela. | No se crean esquemas ni tablas de gobernanza UVR propias. |
| C8 | Autorizada conexión del panel con Fase 5 y construcción de **A–G** con permisos existentes. | Rutas, controladores, vistas y grants controlados. |
| C10 | Legado intacto; denominación visible **Responsabilidad profesional**; glosario de equivalencias. | No se renombran `malpractice_uvr`, `*_rvu` ni tablas heredadas. |
| C11 | API pública, OpenAPI, API keys, scopes y rate limit **sin cambios**. | No se crean `/v1/uvr` ni `/fhir/*`. |

## 2. Reglas derivadas para la implementación

1. El importe referencial es derivado y se calcula en la capa de servicio; si no
   existe conversión aprobada, el resultado es `null`, nunca `0` ni un valor
   estimado por defecto.
2. El redondeo a dos decimales ocurre solo en la capa de presentación; la base
   conserva la precisión `NUMERIC` original.
3. Un componente negativo requiere texto de evidencia no vacío; sin él, la base
   rechaza la fila.
4. Toda publicación exige: fuente, dos revisiones de actores distintos, decisión
   con `evidence_reference` y `os_review_state.is_publication_allowed = TRUE`.
5. El panel usa solo los 14 permisos existentes; `Rbac::canApprove()` se invoca
   en la capa de servicio, no solo en la UI.
6. Ninguna fase SQL se ejecuta por el agente: los archivos se preparan y el
   responsable los ejecuta con backup verificado.

## 3. Alcance autorizado a partir de esta acta

- U1: archivos SQL aditivos y su verificación `READ ONLY` (preparados, no ejecutados).
- U2: servicios y repositorios de gobernanza UVR.
- U3: vistas administrativas A–G y paridad trilingüe.
- U4: guardián de publicación y auditoría UVR.
- U5: cálculo derivado del importe referencial.
- U6: documentación de cierre y verificación final.

**No autorizado:** commits, push, despliegue, cambios en VPS, cambios en la API
pública, carga de valores UVR ni ejecución de migraciones por el agente.
