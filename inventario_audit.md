# REORGANIZACIÓN INTEGRAL ORIGEN SALUD - FASE 1: AUDITORÍA

> **Histórico — superado por Etapas 12-13 / auditoría 2026-11-26:** el estado vigente está en el [informe final](docs/audit/informe-final.md). El contenido histórico se conserva sin modificarlo.

## ESTRUCTURA ACTUAL IDENTIFICADA

### Archivos SQL (sql/):
- origen_catalog_engine.sql - Motor canonical de catálogos, nomencladores, aranceles y vademécum
- pmo.sql - Programa Médico Obligatorio
- dentar_family.sql - Registro familia DENTAR, migración de códigos, trigger de prefijo
- dentar_core_and_diagnosis.sql - Núcleo editorial DENTAR-PR y DENTAR-DX
- sync_dentar_to_os.sql - Sincronización DENTAR-* → os_* (PR y DX independientes)
- 05_map_excel.sql - Cargador NBU/GTIN (fallback TSV)
- nomencladores_argentina.sql - Legacy
- Argentina_dental_cdt_codes_2025.sql - CDT 2025
- importar_loinc.sql - LOINC

### Archivos PHP (tools/php/):
- import_dentar_csv.php - Importador masivo DENTAR-PR y DENTAR-DX
- convertir_excel_maps.php - Convierte XLSX a TSV
- import_nomenclador_csv.php - Importador nomencladores argentinos
- generar_carga_snomed.php - Genera 02_carga.sql desde ZIP RF2
- Rf2Importer.php - Motor RF2 streaming
- ImportOptions.php, ImportResult.php

#### Servicios API (api/services/):
- CatalogEngineService.php - /v1/catalogs, metadatos familia
- TerminologySearchService.php - Búsqueda detalle/por-SNOMED

#### Documentación (docs/):
- docs/dentar/README.md - Familia DENTAR, formato CSV, plantillas
- docs/dentar/plantilla-dentar-pr.csv - Plantilla PR
- docs/dentar/plantilla-dentar-dx.csv - Plantilla DX
- docs/adopcion/PLANTILLA_INFORME_MENSUAL.md - Informe mensual
- docs/adopcion/README.md - Guía adopción
- sql/README.md - Orden de carga SQL
- README.md - Estructura general
- README-API.md - Ejemplos API

### Catálogos y Fuentes de Datos

#### DENTAR (Prioritario activo):
- 138 procedimientos (DNT-PR-000001 a DNT-PR-000138)
- 38 diagnósticos (DNT-DX-000001 a DNT-DX-000038)
- Objetivo: 800 códigos
- Carga: CSV → dentar_* tables → sync_dentar_to_os.sql → os_*

#### SNOMED CT:
- Release 2026-08-20 (~600K conceptos)

#### Nomencladores Argentinos:
- NBU, PMO, ANDIS, KINESIOLOGÍA, SALUD MENTAL

### 3. PROBLEMAS DETECTADOS

1. Dispersión de scripts SQL entre directorios
2. Referencias antiguas DNT-00000X → DNT-PR/DX-NNNNNN (parcheado)
3. Campos por mejorar: UVR vs RVU
4. Documentación pending en varios README
5. Sin entorno local (sin psql/bash/Docker)
6. **SIN EJECUTAR EN VPS**: Scripts SQL y PHP aún no aplicados en VPS

### 4. SOLICITUD ACTUAL

Reorganización integral del repositorio Git con arquitectura profesional, consistente, mantenible y escalable. Prioridad: preservar todo lo que funciona.