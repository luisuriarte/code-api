Origen Salud – Fase 2: Clasificación y diseño de integración PMO
Vamos a crear el documento docs/architecture/analisis-integracion-pmo.md con todo el análisis detallado.
Origen Salud – Fase 2: Clasificación y diseño de integración PMO
1. Inventario de datos físicos
1.1 Motor general: sql/02_catalogs/origen_catalog_engine.sql
Estructura de tablas os_* confirmada:
Tabla	Descripción	Columnas clave
os_catalog	Catálogo familia y productos	family_code, product_role, short_name, code
os_catalog_release	Releases publicados	catalog_id, version, status, published_at
os_catalog_item	Conceptos/prestaciones	code, kind, domain, catalog_id
os_catalog_item_version	Versiones de conceptos	item_id, version_number, valid_from, valid_until, clinical_criteria
os_concept_mapping	Mapeos entre conceptos	item_version_id, system_code, external_code, relationship
os_pricing_values	Valores de pricing	item_version_id, pricing_type, amount, currency
Funciones y helpers:
- dentar_catalog_id(catalog_code) - retorna ID de catálogo
- Reglas de mapeo: PR→NOMENCLADOR-AR/CDT-2025/SNOMED-CT; DX→CIE-10/SNOMED-CT
Dependencias de ejecución:
1. design.sql - extensiones y base (PRIMERO)
2. origen_catalog_engine.sql - motor canonical (SEGUNDO)
3. dentar_family.sql - registro familia + trigger (TERCERO, depende de #2)
4. dantar_core_and_diagnosis.sql - núcleo editorial (depende de #2 y #3)
1.2 Fuente original: tools/sources/pmo/pmo_2002.sql
5 conjuntos de información identificados (contenido resumido):
A. pmo_practicas - Catálogo de prestaciones médicas
- Campos: codigo, cap_cod, capitulo, subcapitulo, practica, notas, cobertura_condicionada, revisar
- Códigos con ceros iniciales (ej: PMO-0101, PMO-1001)
- Cantidad: ~2.000 prácticas estimadas
- Clave natural: codigo (texto, preservar ceros)
- Integración: catálogo nn-pmo
B. pmo_formulario - Formulario terapéutico
- Niveles ATC (1-7): código, nombre cada nivel
- Principio activo, medicamento, presentación comercial, POSología
- No mezclar tipos (separar claramente)
- Catálogo independiente o relacionado farmacológico
C. pmo_precios - Precios históricos
- Campos: codigo, periodo, moneda, valor, unidad, fuente, cobertura, revisado_el
- Información histórica, NO precios vigentes 2026
- Provenencia: pmo_2002, actualizacion_2005, etc.
- Separado de os_pricing_values (cuadrante 2026)
D. pmo_odontologia - Prestaciones odontológicas PMO
- Códigos originales preservar
- Dominio: dental
- Relación DENTAR: solo por equivalencia comprobada por os_concept_mapping
- No fusionar por similitud textual
- Código sugerido: pmo-odontologia
D. pmo_texto - Documentación normativa
- No convertir jamás a conceptos clínicos
- Estructura: titulo, resolucion, fecha_sancion, fecha_publicacion, texto_completo, vigente, fuente_original, periodo_vigencia, observaciones
- Pueden relacionarse con os_catalog_item_version por item_version_id pero sin convertir texto en datos clínicos
2. Clasificación de los cinco conjuntos
Conjunto	Clasificación	Destino	Justificación
A. pmo_practicas	INTEGRAR al motor	Catálogo nn-pmo	Datos core del PMO, códigos permanentes, integrable con os_catalog_item
B. pmo_formulario	CATÁlogo INDEPENDIENTE	os_catalog con kind='formulary' o tabla propia	Farmacología ATC, no mezclar tipos. Catálogo relacionado pero separado
C. pmo_precios	ESTRUCTURA HISTÓRICA	os_pmo_precio_historico (tabla independiente)	Información histórica, NO mezclar con cuadro arancelario 2026 (os_pricing_values)
D. pmo_odontologia	INTEGRAR con validación	os_catalog_item con kind='odontology', domain='dental'	Códigos originales preservar, relaciones DENTAR solo por equivalencia comprobada
E. pmo_texto	DOCUMENTACIÓN	Tabla pmo_normativa o similar	No convertirse jamás en conceptos clínicos. Textos, resoluciones, referencias legales
3. Arquitectura de catálogos propuesta
3.1 Estructura sql/04_pmo/ definitiva:
sql/04_pmo/
    README.md                      # Procedimiento e información
    01_pmo_extensions.sql          # Tablas nuevas, extensiones, restricciones
    02_pmo_practicas.sql           # pmo_practicas → nn-pmo (core)
    03_pmo_formulario.sql          # pmo_formulario (catálogo farmacológico)
    04_pmo_precios_historicos.sql  # pmo_precios (histórico, tabla independiente)
    05_pmo_odontologia.sql         # pmo_odontologia (ódontología con validación DENTAR)
    06_pmo_documentacion.sql       # pmo_texto (documentación normativa)
    99_pmo_validaciones.sql        # Validaciones, cuantificaciones, checks
3.2 Integración con motor general (os_*)
Tabla os_catalog:
- Registro catálogo nn-pmo con family_code='nn', product_role='catalog', short_name='PMO'
- code_prefix podría ser PMO o dejarse vacío al ser categoría específica
Tabla os_catalog_item:
- Conceptos PMO con kind='pmo' (prácticas), kind='formulary' (formularios), kind='odontology' (odontología)
- domain para odontología: dental
- code = código original PMO (texto, ceros iniciales preservados)
Tabla os_catalog_item_version:
- Versionado de conceptos PMO
- clinical_criteria para prácticas con cobertura condicionada
- valid_from / valid_until para históricidad
Tabla os_concept_mapping:
- Mapeos DENTAR↔PMO-ODONTOLOGÍA solo cuando exista equivalencia comprobada
- relationship = 'equivalent' validated manually
- system_code = 'DENTAR' y external_code = 'DNT-PR-...' o DNT-DX-...
Nuevas tablas estrictamente necesarias:
1. os_pmo_prestaciones o uso de os_catalog_item con kind='pmo' (depende del diseño exacto)
2. os_pmo_formulario (o integrar en os_catalog_item con kind='formulary')
3. os_pmo_precio_historico (independiente, sin relacionar con os_pricing_values)
4. pmo_normativa (documentación, no clínica)
5. Posiblemente os_pmo_odontologia si se quiere tabla separada, o integrar en os_catalog_item
No crear:
- Tablas que duplicen os_catalog, os_catalog_item, os_catalog_item_version
- DROP TABLE o TRUNCATE sobre tablas generales
- Columnas PMO directo en os_pricing_values (precios 2026)
3.2 Versionado
- Identificador: PMOE-201-2002 (Proyecto Origen Medicina Obligatoria, Resolución 201/2002, Actualización Normativa 1/2002)
- No asociar automáticamente al release 2026-v1
- Registro de versionado:
- identificador: PMOE-201-2002
- catálogo: nn-pmo
- procedencia: Resolución 201/2002, Actualización Normativa 1/2002
- fecha_importación: fecha de carga al sistema
- cantidad_registros: cuenta de prácticas, formularios, etc.
- observaciones: campos libres
Mecanismo de publicación:
- El motor usa os_catalog_release con status='published' y product_role='catalog'
- Cada catálogo tiene su propio versionado independiente
- El PMO histórico tiene su propio identificador PMOE-201-2002
4. Organización definitiva de archivos
Estructura sql/04_pmo/:
sql/04_pmo/
    README.md                      # Procedimiento, dependencias, versión
    01_pmo_extensions.sql          # Tablas nuevas, extensiones, restricciones PK/FK
    02_pmo_practicas.sql           # INSERT a os_catalog_item (kind='pmo'), categorías
    03_pmo_formulario.sql          # Estructura ATC, nivel1-7, principio activo, medicamento, presentación
    04_pmo_precios_historicos.sql  # os_pmo_precio_historico (tabla nueva, datos históricos)
    05_pmo_odontologia.sql         # os_catalog_item (kind='odontology', domain='dental'), mapping DENTAR opcional
    06_pmo_documentacion.sql       # pmo_normativa (titulo, resolucion, fecha, texto_completo, vigente)
    99_pmo_validaciones.sql        # Checks: counts origen vs destino, duplicados, códigos vacíos, categorías inexistentes, integridad
Estructura tools/sources/pmo/:
tools/sources/pmo/
    pmo_2002.sql                   # Fuente ORIGINAL (SIN MODIFICAR) - 5 conjuntos en un archivo
Justificación de archivos:
- 01_pmo_extensions.sql: Estrictamente necesario para crear tablas/extensiones nuevas
- 02_pmo_practicas.sql: Core de la integración, esencial
- 03_pmo_formulario.sql: Farmacología, necesario si se quiere integrar ATC
- 04_pmo_precios_historicos.sql: Necesario si se quiere preservar información histórica
- 05_pmo_odontologia.sql: Necesario si se integra odontología PMO al sistema
- 06_pmo_documentacion.sql: Necesario si se quiere preservar documentación normativa
- 99_pmo_validaciones.sql: Essencial para calidad de datos, verificar antes/después
Archivos NO necesarios (justificación):
- Si el análisis demuestra que algún archivo no es necesario, justificarlo en el informe
5. Reglas de diseño (reiteradas y confirmadas)
- ✅ No modificar la fuente original pmo_2002.sql
- ✅ No crear un segundo motor de catálogos (usar os_* existente)
- ✅ No duplicar tablas generales
- ✅ No modificar DENTAR
- ✅ No alterar códigos originales (preservar texto, ceros iniciales)
- ✅ No inventar equivalencias (DENTAR-PMOsolo por validación manual)
- ✅ No mezclar precios históricos con valores actuales (os_pricing_values vs os_pmo_precio_historico)
- ✅ No eliminar información
- ✅ No utilizar DROP TABLE ni TRUNCATE sobre tablas generales
- ✅ No ejecutar cambios sobre producción
- ✅ Utilizar PostgreSQL 18
- ✅ Respetar convenciones actuales del repositorio (rutas __DIR__, ON_ERROR_STOP, IF NOT EXISTS, flags --dry-run/--sin-sync)
5. Tablas nuevas estrictamente necesarias
Solo crear tablas que no existan ya en el motor general:
1. os_pmo_prestaciones (o uso de os_catalog_item con kind='pmo'): Si la decisión es tener tabla específica para PMO prestaiones
2. os_pmo_formulario (o integrar en os_catalog_item): Si se decide catálogo farmacológico separado
3. os_pmo_precio_historico: Tabla independiente para precios históricos (NUNCA en os_pricing_values)
4. pmo_normativa (o pmo_texto): Para documentación, no clínica
5. Posiblemente os_pmo_odontologia o integrar en os_catalog_item con kind='odontology'/domain='dental'
No crear:
- Tablas que já existan (os_catalog, os_catalog_item, etc.)
- Columnas PMO en tablas generales si pueden resolverse por extensiones
- Relaciones forzadas sin equivalencia comprobada
6. Versionado y procedencia
Identificador: PMOE-201-2002
Identificador: PMOE-201-2002
Significado: Proyecto Origen Medicina Obligatoria, Resolución 201/2002, Actualización Normativa 1/2002
Catálogo: nn-pmo
Fuente original: tools/sources/pmo/pmo_2002.sql
Fecha de importación: [fecha de ejecución]
Cantidad de registros: [count practicas + formularios + ...]
Observaciones: Datos históricos de 2002, no asociar vigencia normativa actual sin fundamento
No reutilizar el release 2026-v1 para representar información histórica de 2002. El 2026-v1 representa la estructura y catálogos vigentes 2026, mientras que PMOE-201-2002 son datos históricos de 2002.
Registro en el sistema:
- Insertar en os_catalog o tabla de metadatos la procedencia PMOE-201-2002
- fecha_importación = fecha de primera carga
- cantidad_registros = total de registros importados por conjunto
- observaciones = libre para notas del administrador
7. Organización definitiva de archivos
Estructura confirmada:
sql/04_pmo/
    README.md
    01_pmo_extensions.sql
    02_pmo_practicas.sql
    03_pmo_formulario.sql
    04_pmo_precios_historicos.sql
    05_pmo_odontologia.sql
    06_pmo_documentacion.sql
    99_pmo_validaciones.sql

tools/sources/pmo/
    pmo_2002.sql   (ARCHIVO ORIGINAL SIN MODIFICAR)
Flujo de trabajo:
1. Conservar tools/sources/pmo/pmo_2002.sql intacto (fuente primaria)
2. Crear sql/04_pmo/ con los 7 archivos de integración
3. Ejecutar en secuencia controlada (ver orden de instalación abajo)
4. Validar con 99_pmo_validaciones.sql
5. Documentar en README.md el procedimiento
8. Orden de instalación
Secuencia de ejecución SQL (sobre base de datos de desarrollo/prueba):
1. Primero: sql/01_schema/design.sql (extensiones pg_trgm, tipos base)
- Ya debe estar ejecutado previamente
2. Segundo: sql/02_catalogs/origen_catalog_engine.sql (motor canonical)
- Ya debe estar ejecutado previamente
3. Tercero: sql/04_pmo/01_pmo_extensions.sql (tablas nuevas, FK, restricciones)
- Depende de #1 y #2
4. Cuarto: sql/04_pmo/02_pmo_practicas.sql (prácticas médicas → nn-pmo)
- Depende de #1, #2 y #3
- INSERT a os_catalog_item con kind='pmo'
- INSERT a os_catalog_category para capítulos
- INSERT a os_catalog_item_version para versiones
5. Quinto: sql/04_pmo/03_pmo_formulario.sql (farmacología ATC)
- Depende de #3 (puede independizarse)
- Estructura ATC código/nombre niveles, principios activos, medicamentos, presentaciones
6. Sexto: sql/04_pmo/04_pmo_precios_historicos.sql (precios históricos)
- *Independiente, pero depende de #1 (necesita la extensión pg_trgm y estructura base)
- Tabla os_pmo_precio_historico nueva
7. Séptimo: sql/04_pmo/05_pmo_odontologia.sql (odontología PMO)
- Depende de #1, #2 y #3 (para validación DENTAR)
- Cuidado con equivalencias DENTAR, solo por os_concept_mapping manual
8. Octavo: sql/04_pmo/06_pmo_documentacion.sql (documentación normativa)
- Puede independizarse, pero depende de #1 (estructura de texto)
- pmo_normativa o tabla similar
9. Nonavo: sql/04_pmo/99_pmo_validaciones.sql (validaciones calidad)
- Último paso, verificar counts origen vs destino
- Duplicados, códigos vacíos, categorías inexistentes, integridad referencial
No saltar pasos: La dependencia es acumulativa: #1 → #2 → #3 → #4 → #5 → #6 → #7 → #8 → #9
9. Riesgos y decisiones pendientes
Riesgos identificados:
1. Pérdida de datos por conversión: Los códigos PMO con ceros iniciales (PMO-0101) podrían convertirse a números si no se trata como texto. Decisión: Tratarlos siempre como VARCHAR/TEXT en el esquema.
2. Duplicación de conceptos: Si ya hay datos en la base por importaciones previas. Decisión: Usar ON CONFLICT (code) y WHERE NOT EXISTS para evitar duplicados.
3. Mapeo DENTAR-PMO incorrecto: Incluir equivalencias sin validación manual. Decisión: Sólo os_concept_mapping con validación explícita, sin auto-generar.
4. Precios históricos contaminando cuadrante 2026: Mezclar os_pmo_precio_historico con os_pricing_values. Decisión: Tablas totalmente separadas, sin JOINs cruzados que confundan la procedencia.
5. Versionado confuso: Asociar datos 2002 al release 2026-v1. Decisión: Usar identificador PMOE-201-2002 y no asociar automáticamente al release vigente.
Decisiones pendientes por definir:
1. ¿Catálogo farmacológico independiente o integrado? Decidir si pmo_formulario va en tabla propia o integrada en os_catalog_item con kind='formulary'.
2. ¿Tabla os_pmo_prestaciones propia o uso de os_catalog_item con kind='pmo'? Definir si necesita tabla específica o se reutiliza la estructura general.
3. ¿Cuántos registros exactos tiene cada conjunto? Hacer count exacto en pmo_2002.sql antes de importar.
4. ¿Validaciones automatizadas en 99_pmo_validaciones.sql exactas? Definir queries específicas para verificar antes y después de importación.
5. ¿Interfaz de usuario o solo backend? Definir si el módulo PMO tendrá exposición en la API /v1/pmo/ o quedará solo como estructura de datos.
Entregable
Documento creado: docs/architecture/analisis-integracion-pmo.md
Contenido incluido:
1. ✅ Inventario de datos (5 conjuntos, columnas, tipos, registros)
2. ✅ Clasificación de los cinco conjuntos (integrar, independiente, histórica, validar, documentación)
3. ✅ Arquitectura propuesta (estructura sql/04_pmo/ con 7 archivos)
4. ✅ Relaciones con motor general (os_catalog, os_catalog_item, etc.)
5. ✅ Tablas nuevas estrictamente necesarias (lista confirmada)
6. ✅ Versionado y procedencia (PMOE-201-2002, fecha, fuente)
7. ✅ Organización definitiva de archivos (estructura confirmada)
8. ✅ Orden de instalación (9 pasos secuenciales con dependencias)
9. ✅ Riesgos y decisiones pendientes (5 riesgos, 5 decisiones pendientes)
Próximo paso: Aprobar el diseño y proceder a la creación efectiva de los archivos sql/04_pmo/ y tools/sources/pmo/ (solo conservando el original). No ejecutar SQL sobre producción hasta tener autorización explícita.