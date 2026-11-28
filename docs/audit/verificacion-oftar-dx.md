# Verificación de OFTAR-DX — universo diagnóstico y vinculación SNOMED

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** Aprobada como base técnica para iniciar la implementación controlada (no autoriza ejecución; NO equivale a aprobación clínica).

**Convención:** [H] hecho verificado en repositorio/documentación Auditable · [I] inferencia · [P] propuesta.

Alcance documental: sin `psql` ni variables `DB_*`/`PG*`; no se consultó PostgreSQL, no se ejecutaron SQL, migraciones, seeds, importadores ni pruebas. El detalle completo está en `universo-diagnosticos-oftar-dx.md`; aquí solo se consolida lo verificable.

## 1. Universo verificado

[H] CIE-10-ES 2026: 2.661 códigos H00-H59 finales (CSV de 74.260 filas). ICD-10-CM 2027: 2.677 códigos H00-H59 (74.879 líneas; 3.330 códigos `H*`). Intersección normalizada: 2.660. Exclusivo ES: `H01.8` (1). Exclusivos CM: 17. Unión condicional: 2.678.

[I] La cifra 23.292 no es reproducible con el conteo directo del archivo inglés (74.879 líneas); NO usarla. Sí son reproducibles 2.661 y 2.677.

[H] CIE-10-ES 2026 es la 6.ª edición publicada por el Ministerio de Sanidad de España; NO es normativa argentina. La edición argentina está pendiente de acta. ICD-10-CM 2027 es un sistema estadounidense independiente. SNOMED CT Argentina Edition es terminología complementaria; el refset oficial usado es `447562003`.

## 2. SNOMED, alcance y estados

[H] RF2 verificado: 217.373 filas; 155.106 activas; 130.055 activas con `mapTarget`; 6.783 con destino CIE-10 H00-H59; 6.538 conceptos SNOMED únicos; 260 códigos H destino únicos.

[H] Hay 90 códigos S05 finales fuera de H00-H59, 9 códigos `H36.8*` finales dentro y `H48` final 0. [P] S05/T15/T26/T85/E11.\* son referencias externas candidatas: solo incorporación justificada y revisada, NO importación masiva. `H36.8*` se navega con `AREA-SIST` sin duplicar el diagnóstico.

[P] Cadena de vinculación: SNOMED → `mapTarget` → `OFT-DX-NNNNNN` → `os_catalog_item`/`os_concept_mapping`, con `mapping_type='related'` inicial (NO `equivalent` por similitud) y `review_status='draft'` hasta revisión humana. No usar SNOMED para equivalencias de procedimientos.

[H] `os_concept_mapping.review_status` = `draft|reviewed|approved|deprecated`; la versión y la revisión de campo/traducción no tienen `CHECK` y default `unknown` (los scripts OFTAR ponen `approved`); `os_catalog_release.status` = `draft|review|published|deprecated`. No existen `pending_review` ni `rejected` en esas columnas; `rejected` existe solo en `os_oftar_nomenclador_match.review_status` (`proposed|approved|rejected`).

## 3. No incorporar

[P] No incorporar: los 17 códigos CM como CIE-10; CIE-10-ES como norma argentina; todos los H00-H59 sin juicio de pertinencia; SNOMED de forma masiva.

## 4. Tabla de verificación

| Afirmación | Evidencia | Resultado | Riesgo |
|---|---|---|---|
| 2.661 ES / 2.677 CM / 2.660 intersección / 2.678 unión | `universo-diagnosticos-oftar-dx.md:13-23` | verificado | Mezclar sistemas, ediciones o idiomas |
| Cifra 23.292 no reproducible | `universo-diagnosticos-oftar-dx.md` §3; `especificacion-definitiva-reconstruccion-oftar.md` §16 | verificado | Difundir un conteo falso |
| CIE-10-ES 6.ª edición, Ministerio de Sanidad de España | `tools/sources/cie10_argentina/readme.md:3-7`; rector §4 | verificado | Presentarla como norma argentina |
| Edición CIE-10 argentina | sin acta local; rector §4 y §16 | pendiente de acta | Inventar organismo, versión o release |
| Métricas del refset SNOMED `447562003` | `universo-diagnosticos-oftar-dx.md:93-102` | verificado | Importación masiva o mapeo sin filtrar `active=1` |
| 90 S05, 9 H36.8\*, H48 final 0 | `universo-diagnosticos-oftar-dx.md:49-74`; rector §3 | verificado | Duplicar diagnósticos o alterar el rango H |
| Incorporación de S05/T/E11 | `universo-diagnosticos-oftar-dx.md:38,62-64` | pendiente de acta | Decisión de alcance no tomada |
| Vinculación inicial `related` + `draft` | `universo-diagnosticos-oftar-dx.md:104-117` | pendiente de acta | Equivalencia automática por similitud |
| SNOMED no genera equivalencias de procedimientos | `aprobacion-conciliacion-oftar-pr.md:140-142` | verificado | Contaminar OFTAR-PR con diagnósticos |
| Sin PostgreSQL ni pruebas ejecutadas | alcance documental de este informe | verificado | Afirmar validación en base o ejecución de pruebas |

[P] Este informe consolida la base técnica para la implementación controlada y para las decisiones de gobernanza pendientes. No autoriza ejecución, importación, publicación ni aprobación clínica.
