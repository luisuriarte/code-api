# Gestión UVR · modelo de datos real y propuesta aditiva

**Estado:** PROPUESTA DOCUMENTAL. **No implementada.**
**Depende de:** [`gobernanza-uvr-arquitectura.md`](gobernanza-uvr-arquitectura.md) §6 (conflictos C1–C3, C6, C7, C10).

> Este documento describe primero lo que **ya existe y está verificado** y
> después una propuesta **conceptual**. No contiene DDL definitivo, no crea
> tablas ni campos en base y no carga valores.

---

## 1. Modelo UVR implementado [REPO]

Fuente: `sql/08_arquitectura/fase6_uvr.sql` (nombre histórico; corresponde a la
**Fase 7** del §16, según `sql/08_arquitectura/README.md:45`).

| Tabla | Columnas y reglas relevantes | Evidencia |
|---|---|---|
| `os_uvr_eligible_catalog` | `catalog_code VARCHAR(60) PK`, `source_reference TEXT NOT NULL`, `is_active BOOLEAN NOT NULL DEFAULT TRUE`, `created_at TIMESTAMPTZ NOT NULL`. **Sin FK** a `os_catalog(code)`; la relación se valida por texto en el trigger. | `fase6_uvr.sql:66-71`, `:175-203` |
| `os_uvr_valuation` | `id`, `service_item_id INT NOT NULL → os_catalog_item(id) ON DELETE RESTRICT`, `release_id INT → os_catalog_release(id) ON DELETE SET NULL`, `version_tag VARCHAR(50) NOT NULL`, `methodology VARCHAR(120) NOT NULL`, `source_reference TEXT NOT NULL`, `evaluated_at DATE NOT NULL`, `calculated_by TEXT`, `review_status VARCHAR(30) NOT NULL DEFAULT 'unknown' → os_review_state(code)`, `valid_from`, `valid_to`, `created_at`. `UNIQUE(service_item_id, release_id, version_tag, methodology)`. | `fase6_uvr.sql:85-102` |
| `os_uvr_component` | `id`, `valuation_id BIGINT NOT NULL → os_uvr_valuation(id) ON DELETE CASCADE`, `component_type VARCHAR(40) NOT NULL CHECK (work, practice_expense, professional_liability)`, `value NUMERIC(12,4) NOT NULL CHECK (value >= 0)`, `calculation_note TEXT`, `UNIQUE(valuation_id, component_type)`. | `fase6_uvr.sql:104-113` |
| `os_uvr_conversion` | `id`, `uvr_value NUMERIC(14,6) NOT NULL CHECK (>0)`, `currency VARCHAR(5) NOT NULL DEFAULT 'ARS'`, `country_code VARCHAR(2)`, `jurisdiction VARCHAR(120)`, `payer VARCHAR(150)`, `contract VARCHAR(150)`, `period_start`, `period_end`, `index_reference TEXT`, `source_reference TEXT NOT NULL`, `license_reference TEXT`, `review_status`, `created_at`. `UNIQUE(uvr_value, currency, country_code, jurisdiction, payer, contract, period_start)`. | `fase6_uvr.sql:121-141` |
| `os_uvr_geo_index` | `id`, `component_type` con el mismo CHECK de tres valores, `jurisdiction VARCHAR(120) NOT NULL`, `index_value NUMERIC(12,6) NOT NULL DEFAULT 1.000000 CHECK (>0)`, `methodology VARCHAR(120)`, `source_reference TEXT NOT NULL`, `period_start`, `period_end`, `review_status`, `created_at`. `UNIQUE(component_type, jurisdiction, period_start, source_reference)`. | `fase6_uvr.sql:149-167` |

### 1.1 Vista derivada

`v_os_uvr_valuation_total` (`fase6_uvr.sql:208-230`) expone:

```
work_uvr                     = COALESCE(c_work.value, 0)
practice_expense_uvr         = COALESCE(c_practice.value, 0)
professional_liability_uvr   = COALESCE(c_liability.value, 0)
total_uvr                    = suma de los tres
```

El comentario de la vista declara que `total_uvr` no constituye arancel ni pago
oficial y que `estimated_payment` se calcula en la capa de presentación con
`uvr_value` (`fase6_uvr.sql:229-230`). El verificador comprueba explícitamente
que no existe columna `total_uvr` en `os_uvr_valuation`
(`verificacion_fase7.sql:82-86`).

### 1.2 Datos reales y regresiones

| Objeto | Estado | Evidencia |
|---|---|---|
| `os_uvr_eligible_catalog` | 1 fila derivada de `os_catalog(code='dentar-pr')`. | `fase6_uvr.sql:58-60,73-77` |
| `dentar-dx` | Explícitamente excluido de elegibilidad UVR. | `fase6_uvr.sql:19,79-80`; `verificacion_fase7.sql:32-34` |
| `os_uvr_valuation`, `os_uvr_component`, `os_uvr_conversion`, `os_uvr_geo_index` | 0 filas. | `sql/08_arquitectura/README.md:373-380` |
| Relaciones / idiomas / solicitudes / valoraciones / reservas DENTAR / reservas OS | `603 / 22 / 0 / 0 / 3 / 7`. | `sql/08_arquitectura/README.md:373-380` |
| Legado farmacéutico | `os_substance=9`, `os_medicinal_product=10`, `os_product_package=10`, `os_product_identifier=40`. | `sql/08_arquitectura/README.md:330-334` |

## 2. Lo que el modelo actual ya resuelve

| Requisito del documento del usuario | Implementación existente |
|---|---|
| Tres componentes y total aditivo | `os_uvr_component` con los tres `component_type` y la vista derivada. |
| `total_uvr` no inventado ni editable | Vista `v_os_uvr_valuation_total`; verificador prohíbe la columna. |
| Valoración separada de conversión | Tablas físicas distintas; comentario explícito en `fase6_uvr.sql:143-144`. |
| Índices geográficos separados | `os_uvr_geo_index`, vacía, sin default inventado en datos (solo default de columna). |
| Solo prestaciones | Trigger `trg_os_uvr_valuation_eligible`. |
| Fuente obligatoria | `source_reference NOT NULL` en las cuatro tablas de valoración/conversión/índice y en elegibilidad. |
|Sin valores inventados | Estructura vacía; única semilla derivada de catálogo real. |

## 3. Brechas de modelo

| Brecha | Consecuencia | Evidencia |
|---|---|---|
| No hay catálogo de metodologías con versión, criterios ni aprobación; `methodology` es texto libre. | No se puede demostrar qué metodología se aprobó ni versionarla. | `fase6_uvr.sql:90,156` |
| No hay registro de fuente con autoridad, versión, licencia, fecha de obtención ni estado; `license_reference` solo existe en conversión. | La procedencia no es verificable más allá de una cadena de texto. | `fase6_uvr.sql:68,91,132-133,157` |
| `calculated_by TEXT` anulable y sin FK a `os_admin.app_user`. | Responsable no gestionado con identidad fuerte. | `fase6_uvr.sql:93` |
| No hay `reviewed_by_user_id`, `approved_by_user_id`, `published_at` ni `assigned_to_user_id` en UVR. | No se puede auditar quién revisó/aprobó/publicó. | `fase6_uvr.sql:85-167` |
| Ninguna tabla UVR usa `domain_code` ni FK a `os_domain_registry`. | No hay dominio UVR declarado en el registro central de dominios. | `fase1_infraestructura.sql:12-38`; `fase6_uvr.sql:66-167` |
| No hay vista que consuma `os_uvr_conversion` ni `os_uvr_geo_index`; no hay `adjusted_*` ni importe derivado. | No se puede demostrar separación ni calcular referencia monetaria. | `fase6_uvr.sql:208-227` |
| No hay trigger que impida `UPDATE` sobre valoraciones, componentes o conversiones. | La regla «nueva valoración = nueva fila» no está forzada. | `fase6_uvr.sql:200-203`; `propuesta-arquitectura-catalogos-sanitarios.md:747` |
| Cuatro modelos de valoración conviven sin reconciliación: `dentar_concept_version.*_uvr`, `os_pricing_values.*_rvu`, `os_fee_item`, `nomencladores_argentina.unidad_*`. | Riesgo de tomar un arancel o RVU como UVR. | `propuesta-arquitectura-catalogos-sanitarios.md:755-768` |

## 4. Propuesta conceptual de cuatro planos (sin DDL)

Los «dominios» del documento del usuario se interpretan como **planos lógicos de
responsabilidad**, no como esquemas, catálogos nuevos ni tablas de gestión
paralelas. Esta interpretación está sujeta al conflicto C6.

| Plano | Datos existentes que lo representan | Tratamiento propuesto | Estado |
|---|---|---|---|
| Clínico / terminológico | `os_catalog`, `os_catalog_item`, `os_catalog_release`, `os_field_review`, D-19/D-31 | El ítem y su release siguen siendo la única entrada; la revisión clínica se registra en la cadena de gestión existente, no en una tabla nueva. | Propuesta |
| Valoración UVR | `os_uvr_valuation`, `os_uvr_component` | Añadir metadatos de gestión solo si se aprueban: identificador de metodología, actor responsable con FK, marcador de aplicabilidad Por componente y fecha de aprobación. **Nombres definitivos pendientes.** | Propuesta — requiere C2/C3/C4 |
| Económico / conversión | `os_uvr_conversion`, `os_uvr_geo_index` | Permanecen físicamente separados. El importe referencial se deriva en vista/capa de presentación; nunca se guarda. | Propuesta — requiere C7 |
| Publicación | `os_review_state`, `os_governance_decision`, `os_audit_log` | Guardián único: fuente + evidencia + `is_publication_allowed = TRUE`. Sin estado publicable, no se expone valor. | Propuesta |

**Regla de oro:** `prestación ≠ valoración ≠ conversión ≠ arancel ≠ convenio`.
Los convenios arancelarios complejos quedan **fuera de etapa**, como pide el
documento del usuario.

### 4.1 Cambios candidatos (no autorizados)

Se enumeran para decisión, **no se ejecutan ni se fijan como definitivos**:

1. Extender la cadena de gestión para que `subject_type`/`subject_id`
   identifiquen una valoración UVR y sus componentes.
2. Sustituir o complementar `calculated_by TEXT` por un actor con FK a
   `os_admin.app_user`.
3. Registrar revisor clínico y revisor económico como actores distintos en
   `os_governance_review`, con `reviewer_role` controlado.
4. Añadir un marcador de aplicabilidad por componente para distinguir
   `0`, «no aplicable» y «pendiente».
5. Crear vistas derivadas de conversión/ajuste/importe sin columnas nuevas.
6. Reforzar inmutabilidad de valoraciones publicadas mediante trigger, sin
   impedir correcciones controladas mediante nueva fila.

Cada uno necesita aprobación explícita y archivo SQL preparado por el agente,
ejecutado por el responsable con backup verificado.

## 5. Precisión, escala, nulos y negativos

La documentación metodológica no define reglas de precisión ni redondeo
(`README-UVR.md:106-129`, `295-317`), mientras el SQL ya fija escalas:
`NUMERIC(12,4)` para componentes, `NUMERIC(14,6)` para `uvr_value` y
`NUMERIC(12,6)` para índices (`fase6_uvr.sql:110,123,155`). Los ejemplos públicos
usan coma decimal (`2,50`, `1,20`, `0,30`, `4,00`).

**No se adopta ninguna regla nueva.** Se solicita decisión sobre:

| Tema | Estado actual | Decisión requerida |
|---|---|---|
| Decimales visibles de componentes y total | Hasta 4 en componentes; total hereda escala de la suma. | Escala canónica y redondeo. |
| Decimales de `uvr_value` e índices | Hasta 6. | Escala y momento del redondeo del importe. |
| Formato de presentación | Ejemplos con coma decimal. | Formato en `es-AR`, `en`, `pt-BR`. |
| Componente ausente | `COALESCE(...,0)`. | ¿Ausencia = 0, no aplicable o pendiente? |
| Componente negativo | `CHECK (value >= 0)` lo prohíbe. | ¿Se permite ajuste negativo con evidencia? |
| Conversión/índice | Deben ser > 0. | Confirmar regla. |

## 6. Nombres canónicos y legado

| Uso | Nombre canónico | Situación |
|---|---|---|
| Componentes | `work_uvr`, `practice_expense_uvr`, `professional_liability_uvr` | Coinciden con la vista SQL (`fase6_uvr.sql:215-217`). |
| Total | `total_uvr` | Derivado, nunca columna. |
| Conversión | `uvr_value` | Columna existente en `os_uvr_conversion`. |
| Importe | `estimated_payment` en SQL/FHIR; `importe_referencial` en el documento del usuario | Conflicto C7: requiere nombre visible aprobado. |
| Índices | `uvr_geo_*_index`, `adjusted_*` | Documentados en `README-UVR.md:252-272`; no implementados. |
| Nomenclatura visible | **Responsabilidad profesional** | No usar `malpractice` en textos nuevos. |
| Heredado, intocable | `dentar_concept_version.malpractice_uvr`, `os_pricing_values.*_rvu`, `malpractice_rvu` en CSV | No renombrar; documentar equivalencia. |
| Typo detectado | `professioniabial_liability_uvr` en `README-UVR.md:268` | Corrección pendiente de aprobación (C9). |

## 7. Prohibiciones de modelo

- No `DROP TABLE`, `DROP COLUMN`, `TRUNCATE` ni `DELETE` de datos.
- No mover ni migrar el legado farmacéutico ni los modelos `rvu`.
- No crear catálogos reales para reservas DENTAR/OS ni duplicar DENTAR.
- No almacenar `total_uvr`, `estimated_payment` ni importe referencial.
- No cargar valores, conversiones, índices ni metodologías sin fuente y aprobación.
- No reejecutar `sql/07_multilingue/01`–`15`; D-31 y `OS_IMPORT_MODE` ya están resueltos.
