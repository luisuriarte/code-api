# Sistema de Valoración Prestacional de Origen Salud (UVR)

## Metodología de Unidades de Valor Relativo (UVR)

**Documento metodológico — Origen Salud**

**Estado:** Propuesta metodológica  
**Ámbito:** Catálogos de prestaciones sanitarias y odontológicas  
**Unidad de valoración:** UVR — Unidad de Valor Relativo

---

## 1. Introducción

Origen Salud propone un Sistema de Valoración Prestacional (UVR) basado en Unidades de Valor Relativo (UVR), destinado a representar los recursos relativos necesarios para realizar una prestación sanitaria.

El objetivo es disponer de una metodología transparente, reproducible y adaptable a diferentes especialidades, instituciones, jurisdicciones y sistemas de financiación.

El sistema busca responder dos preguntas diferentes:

1. ¿Cuántos recursos relativos requiere una prestación en comparación con otras prestaciones?
2. ¿Cuál es el valor monetario que una institución o financiador asigna a esos recursos?

La primera pregunta se responde mediante las UVR. La segunda depende del valor monetario de referencia, del ámbito geográfico, del período de vigencia y de las condiciones contractuales.

Por lo tanto, **una UVR no representa una cantidad fija de dinero ni constituye por sí misma un arancel**.

## 2. Fundamento conceptual

El modelo toma como referencia conceptual los sistemas de valoración relativa de recursos utilizados internacionalmente, especialmente el Resource-Based Relative Value Scale (RBRVS) del sistema Medicare de Estados Unidos.

En el Physician Fee Schedule de Medicare, los Relative Value Units (RVU) se dividen en tres componentes:

- Physician Work RVU: trabajo profesional.
- Practice Expense RVU: gastos de funcionamiento de la práctica.
- Malpractice RVU: gastos relativos al seguro de responsabilidad profesional.

Origen Salud adopta esta estructura como referencia metodológica para su propuesta UVR, adaptándola a las características de los sistemas sanitarios y las prestaciones de los países donde se utilice.

Esto no implica equivalencia con los valores RVU estadounidenses, ni adopción de sus importes, criterios regulatorios o mecanismos de actualización.

## 3. Componentes de la valoración UVR

La valoración de cada prestación se compone de tres dimensiones independientes.

### 3.1. Trabajo profesional — `work_uvr`

Representa el esfuerzo profesional necesario para realizar una prestación.

Se consideran, entre otros, los siguientes factores:

- Tiempo efectivo de intervención.
- Tiempo de preparación y finalización directamente atribuible.
- Formación y experiencia profesional requeridas.
- Complejidad técnica.
- Habilidad manual y precisión necesarias.
- Esfuerzo físico y cognitivo.
- Responsabilidad en la toma de decisiones clínicas.
- Necesidad de supervisión o participación de otros profesionales.
- Complejidad de la atención y condiciones de ejecución.

El tiempo constituye una variable importante, pero no es el único determinante. Dos prestaciones de igual duración pueden requerir niveles muy diferentes de especialización, precisión y responsabilidad.

La valoración debe reflejar el trabajo profesional efectivamente requerido, evitando contabilizar dos veces tareas que ya estén incluidas en otra prestación.

### 3.2. Gastos de prestación — `practice_expense_uvr`

Representa los recursos materiales, tecnológicos y operativos necesarios para realizar una prestación.

Puede incluir:

- Personal auxiliar y administrativo directamente relacionado.
- Insumos y materiales de utilización habitual.
- Equipamiento médico u odontológico.
- Amortización y mantenimiento de equipos.
- Instrumental y elementos de protección.
- Instalaciones y espacios físicos.
- Servicios y gastos operativos.
- Esterilización, limpieza y acondicionamiento.
- Sistemas informáticos y recursos tecnológicos necesarios.

Los gastos deben distribuirse de manera razonable entre las prestaciones que utilizan esos recursos.

Cuando un material, medicamento o dispositivo se factura por separado, debe evitarse incluir nuevamente su costo completo dentro de la valoración de la prestación.

La metodología deberá diferenciar los gastos directos de los indirectos y establecer criterios de asignación para evitar duplicaciones.

### 3.3. Cobertura de responsabilidad profesional — `professional_liability_uvr`

Representa el costo relativo asociado a la cobertura de responsabilidad profesional necesaria para desarrollar una actividad.

Se pueden considerar:

- Primas de seguros de responsabilidad profesional.
- Diferencias de cobertura según especialidad.
- Riesgo asegurado asociado a determinados procedimientos.
- Costos de cobertura relacionados con la actividad profesional.
- Diferencias justificadas por jurisdicción o condiciones de aseguramiento.

Este componente representa un costo relativo de cobertura de responsabilidad profesional. No debe confundirse con una puntuación general de riesgo clínico ni con la gravedad potencial de una complicación.

La valoración deberá basarse, cuando sea posible, en información verificable de aseguradoras, coberturas y costos de responsabilidad profesional.

Cuando no existan datos suficientes, el valor deberá identificarse como estimado o pendiente de validación.

## 4. Cálculo de la valoración total

La valoración relativa total de una prestación se obtiene sumando sus tres componentes:

**Fórmula básica**

`total_uvr = work_uvr + practice_expense_uvr + professional_liability_uvr`

Cada componente representa una parte de los recursos relativos asociados a la prestación.

### Ejemplo ilustrativo

Los siguientes valores son ficticios y se utilizan exclusivamente para explicar el cálculo.

| Componente | Valor UVR |
|---|---:|
| Trabajo profesional | 2,50 |
| Gastos de práctica | 1,20 |
| Responsabilidad profesional | 0,30 |
| **Total** | **4,00** |

La prestación tiene una valoración de 4,00 UVR.

Esto significa que, de acuerdo con la metodología de valoración adoptada, requiere cuatro unidades relativas de recursos. No significa que su importe sea cuatro pesos, cuatro dólares ni una cantidad monetaria determinada.

### Precisión y valores especiales (decisión gestionada)

- Los componentes se almacenan con la precisión del modelo (`NUMERIC(12,4)`), la conversión con `NUMERIC(14,6)` y los índices con `NUMERIC(12,6)`.
- La **presentación pública y administrativa redondea a dos decimales**; el redondeo se aplica al mostrar, nunca sobrescribiendo el valor almacenado.
- `0` significa «medido cero». La ausencia del componente se representa con un marcador explícito de **no aplicable**, no con `0`.
- Un ajuste **negativo** solo es admisible cuando existe evidencia escrita que lo justifique y queda registrado en la auditoría. Sin esa evidencia, el componente se rechaza.
- El importe referencial (`importe_referencial`; `estimated_payment` en el contrato FHIR) se deriva del total por `uvr_value` y se rotula siempre como estimación, nunca como arancel.

## 5. Cómo se determinan los valores UVR

La asignación de valores no debe realizarse arbitrariamente ni basarse únicamente en la opinión de una persona.

Origen Salud propone un procedimiento de valoración sustentado en evidencia, análisis de recursos y validación profesional.

### 5.1. Recolección de información

Para cada prestación se procurará reunir información sobre:

- Tiempo promedio de realización.
- Tiempo de preparación y finalización.
- Perfil profesional requerido.
- Complejidad técnica.
- Personal participante.
- Insumos y materiales utilizados.
- Equipamiento necesario.
- Costos de funcionamiento.
- Costos de cobertura de responsabilidad profesional.
- Condiciones habituales de ejecución.

Las fuentes podrán incluir estudios de costos, relevamientos institucionales, registros de tiempos, información de proveedores, datos de aseguradoras y documentación técnica.

### 5.2. Análisis de trabajo profesional

El componente `work_uvr` podrá estimarse a partir de estudios de tiempos y actividades, análisis de complejidad y evaluación profesional estructurada.

Se considerarán especialmente:

- Tiempo total de trabajo atribuible.
- Intensidad del esfuerzo.
- Complejidad técnica.
- Habilidades requeridas.
- Responsabilidad profesional.
- Participación de otros integrantes del equipo.

No se recomienda establecer una relación exclusivamente lineal entre duración y valor. El tiempo debe combinarse con los demás factores para representar adecuadamente la carga de trabajo.

### 5.3. Análisis de gastos de práctica

El componente `practice_expense_uvr` se determinará mediante la identificación y distribución de los recursos necesarios.

Se procurará utilizar costos observables y documentados, diferenciando:

- Costos directos por prestación.
- Costos indirectos asignables.
- Costos de equipamiento y amortización.
- Costos de personal auxiliar.
- Costos de instalaciones y funcionamiento.

La asignación deberá ser consistente entre prestaciones de una misma especialidad.

### 5.4. Análisis de responsabilidad profesional

El componente `professional_liability_uvr` se establecerá considerando información disponible sobre costos de cobertura y diferencias justificadas entre actividades profesionales.

No deberá asignarse automáticamente un valor elevado por el solo hecho de que una prestación sea clínicamente compleja. La valoración debe guardar relación con los costos de responsabilidad profesional que se pretende representar.

### 5.5. Validación por especialistas

Los valores propuestos deberán someterse a revisión de profesionales con experiencia en las especialidades correspondientes.

Origen Salud propone un proceso de revisión que contemple:

1. Elaboración de una valoración preliminar.
2. Revisión técnica por especialistas.
3. Comparación con prestaciones similares.
4. Identificación de diferencias y posibles inconsistencias.
5. Ajuste documentado de los valores.
6. Aprobación editorial y publicación de la versión.

La revisión podrá utilizar metodologías de consenso estructurado, como rondas Delphi, cuando resulte apropiado.

## 6. Escala relativa y prestaciones de referencia

Para que las UVR sean comparables entre prestaciones, es necesario establecer una escala de referencia.

Origen Salud deberá seleccionar prestaciones de referencia dentro de cada ámbito profesional y utilizarlas como puntos de comparación.

La asignación de valores debe permitir identificar:

- Prestaciones de baja complejidad.
- Prestaciones de complejidad intermedia.
- Prestaciones de alta complejidad.
- Prestaciones que requieren equipamiento o recursos especiales.
- Prestaciones con una carga significativa de trabajo profesional.

Una prestación de referencia podrá recibir un valor de 1,00 UVR en una dimensión o en el total, según el método de normalización que se adopte.

Los valores de las demás prestaciones se establecerán en relación con esa referencia.

La escala deberá mantener coherencia interna y no deberá interpretarse como una escala universal de complejidad clínica.

## 7. Ajuste geográfico de los costos

Los costos de realizar una prestación pueden variar entre ciudades, provincias y países.

Entre los factores que pueden presentar diferencias geográficas se encuentran:

- Remuneraciones profesionales.
- Salarios del personal auxiliar.
- Alquileres e instalaciones.
- Servicios y costos operativos.
- Disponibilidad y costo de insumos.
- Equipamiento y mantenimiento.
- Primas de seguros de responsabilidad profesional.

Por este motivo, el modelo UVR contempla la posibilidad de incorporar índices geográficos.

### 7.1. Referencia al modelo GPCI

El sistema Medicare de Estados Unidos utiliza Geographic Practice Cost Indices (GPCI) para ajustar los tres componentes de sus RVU.

Cada componente tiene su propio índice:

- Work GPCI.
- Practice Expense GPCI.
- Malpractice GPCI.

Los índices reflejan diferencias geográficas relativas de costos. No representan un mecanismo general de actualización por inflación.

Origen Salud toma esta separación como referencia conceptual, pero no adopta automáticamente los índices estadounidenses ni sus valores.

### 7.2. Propuesta de índices geográficos UVR

En una etapa de desarrollo posterior, podrán definirse los siguientes indicadores:

- `uvr_geo_work_index`
- `uvr_geo_practice_expense_index`
- `uvr_geo_professional_liability_index`

La valoración geográficamente ajustada se calcularía de la siguiente manera:

`adjusted_work_uvr = work_uvr × uvr_geo_work_index`

`adjusted_practice_expense_uvr = practice_expense_uvr × uvr_geo_practice_expense_index`

`adjusted_professional_liability_uvr = professional_liability_uvr × uvr_geo_professional_liability_index`

Por lo tanto:

`adjusted_total_uvr = adjusted_work_uvr + adjusted_practice_expense_uvr + adjusted_professional_liability_uvr`

Los índices deberán estar referidos a una jurisdicción, una metodología, una fuente de datos y un período de vigencia.

Un índice de 1,00 representa el nivel de referencia. Un valor superior a 1,00 representa costos relativos mayores y uno inferior a 1,00 representa costos relativos menores.

### 7.3. Implementación gradual

La existencia de diferencias geográficas no significa que deban aplicarse índices desde el primer día.

Para implementar ajustes geográficos será necesario disponer de:

- Datos comparables entre jurisdicciones.
- Fuentes estadísticas confiables.
- Criterios uniformes de relevamiento.
- Una metodología de cálculo publicada.
- Una frecuencia de actualización definida.
- Procedimientos de revisión y auditoría.

Mientras no exista información suficiente, los índices podrán mantenerse en 1,00, utilizando una valoración nacional uniforme.

No se deberán inventar índices regionales ni asignar porcentajes arbitrarios.

## 8. Conversión de UVR a valores monetarios

Las UVR expresan recursos relativos, no importes monetarios.

Para obtener un importe estimado es necesario establecer un valor monetario de conversión.

Origen Salud denomina a este parámetro:

`uvr_value`

Representa el valor monetario asignado a una UVR para una jurisdicción, un sistema de financiación y un período determinado.

### 8.1. Fórmula sin ajuste geográfico

Cuando se utiliza una valoración uniforme:

`estimated_payment = total_uvr × uvr_value`

### 8.2. Fórmula con ajuste geográfico

Cuando se utilizan índices geográficos por componente:

`estimated_payment = adjusted_total_uvr × uvr_value`

### 8.3. Ejemplo ilustrativo

Supongamos una prestación con:

- Valoración total: 4,00 UVR.
- Valor monetario de referencia: $1.000 por UVR.
- Índices geográficos: 1,00 para los tres componentes.

El resultado será:

`4,00 × $1.000 = $4.000`

El importe estimado es de $4.000.

Este ejemplo no representa un arancel vigente ni un valor recomendado para ninguna prestación. Es una demostración del mecanismo de conversión.

### 8.4. Determinación del valor monetario

El valor monetario de la UVR podrá establecerse mediante diferentes mecanismos:

- Acuerdos entre prestadores y financiadores.
- Convenios institucionales.
- Tablas arancelarias.
- Resoluciones o disposiciones aplicables, cuando corresponda.
- Modelos de actualización económica definidos por cada entidad.

El valor podrá variar según país, provincia, financiador, contrato y período.

La metodología de actualización deberá identificar expresamente el índice económico o mecanismo utilizado, su fuente y la fecha de aplicación.

No debe confundirse la actualización monetaria de la UVR con la revisión de los valores relativos de una prestación.

## 9. Diferencia entre valoración relativa y actualización monetaria

Es importante distinguir dos procesos independientes.

**Actualización de la valoración UVR**

Se produce cuando cambia la estimación de los recursos necesarios para realizar una prestación.

Puede deberse a cambios tecnológicos, modificaciones de técnicas, nuevos insumos, cambios en los tiempos de trabajo o nueva evidencia de costos.

**Actualización del valor monetario de la UVR**

Se produce cuando cambia el importe económico asignado a cada unidad relativa.

Puede responder a inflación, acuerdos contractuales, variaciones de costos, políticas de financiación o condiciones económicas de una jurisdicción.

Una actualización monetaria no debería modificar automáticamente las UVR de todas las prestaciones.

De igual manera, una revisión de la complejidad o los recursos de una prestación no debería modificar automáticamente el valor monetario de la unidad.

## 10. Relación con el sistema RVU de Medicare

La metodología UVR de Origen Salud comparte con el modelo RBRVS de Medicare la utilización de tres componentes de recursos.

| Característica | UVR — Origen Salud | RVU — Medicare |
|---|---|---|
| Trabajo profesional | `work_uvr` | Work RVU |
| Gastos de práctica | `practice_expense_uvr` | Practice Expense RVU |
| Responsabilidad profesional | `professional_liability_uvr` | Malpractice RVU |
| Valor total | `total_uvr` | Total RVU ajustado según las reglas aplicables |
| Ajuste geográfico | Índices UVR propuestos | GPCI |
| Conversión monetaria | `uvr_value` | Conversion Factor |
| Ámbito de aplicación | Propuesta de Origen Salud, adaptable por jurisdicción | Programa Medicare de Estados Unidos |

La similitud es conceptual y estructural. Los valores UVR no son equivalentes a los RVU de Medicare y no deben obtenerse mediante una conversión directa.

### Glosario de equivalencias (decisión gestionada)

Los nombres legados se conservan sin renombrar. Esta tabla solo relaciona la
terminología visible con los campos existentes; no declara equivalencia
metodológica entre UVR y RVU.

| Denominación visible | Campo UVR vigente | Campos legados intactos |
|---|---|---|
| Trabajo profesional | `work_uvr` | `work_rvu` (`sql/02_catalogs/origen_catalog_engine.sql`) |
| Gastos de prestación | `practice_expense_uvr` | `practice_expense_rvu` (ídem) |
| Responsabilidad profesional | `professional_liability_uvr` | `malpractice_rvu` (ídem) y `malpractice_uvr` (`sql/03_dentar/dentar_core_and_diagnosis.sql`) |
| Total UVR (derivado) | `total_uvr` en `v_os_uvr_valuation_total` | `total_rvu` (ídem, legado) |
| Importe referencial | `importe_referencial` (visible) / `estimated_payment` (interno y FHIR) | Sin campo legado; siempre derivado |

Ninguno de estos campos legados se migra, renombra ni expone en la API pública.
El importe referencial es una estimación, nunca un arancel ni un pago oficial.

Los valores estadounidenses tampoco deben trasladarse automáticamente a la realidad económica, profesional o sanitaria de otros países.

## 11. Fuentes de información y documentación

La metodología de valoración deberá sustentarse en fuentes identificables y verificables.

Entre las fuentes admisibles podrán incluirse:

- Estudios de tiempos y movimientos.
- Relevamientos de costos institucionales.
- Estudios económicos del sector sanitario.
- Información de equipamiento, insumos y materiales.
- Datos de remuneraciones profesionales y del personal auxiliar.
- Información de aseguradoras de responsabilidad profesional.
- Publicaciones científicas y técnicas.
- Evaluaciones de especialistas y sociedades científicas.
- Documentación de organismos públicos.
- Nomencladores y sistemas de valoración existentes, utilizados como referencias comparativas.

Cuando se utilice un nomenclador externo, deberá documentarse su procedencia, versión, alcance y condiciones de uso.

La existencia de un código equivalente o relacionado en otro sistema no implica que sus valores económicos sean transferibles.

## 12. Versionado y trazabilidad

Cada valoración UVR deberá poder reconstruirse y auditarse.

Para ello, Origen Salud propone registrar:

- Código de la prestación.
- Versión del catálogo.
- Valores de los tres componentes.
- Valor total calculado.
- Metodología aplicada.
- Fuentes utilizadas.
- Fecha de evaluación.
- Fecha de entrada en vigencia.
- Fecha de finalización de vigencia, cuando corresponda.
- Responsable de la revisión.
- Estado de aprobación.
- Observaciones y justificación de cambios.

Los valores históricos deberán conservarse para permitir la reproducción de cálculos realizados en períodos anteriores.

Una nueva valoración no deberá sobrescribir ni eliminar los registros históricos.

Los índices geográficos y los valores monetarios también deberán contar con versiones y períodos de vigencia independientes.

## 13. Gestión y revisión

El Sistema de Valoración Prestacional de Origen Salud deberá evolucionar mediante un proceso documentado de revisión.

Se propone contemplar:

- Revisión técnica por especialidad.
- Participación de profesionales y entidades del sector.
- Revisión de evidencia y fuentes.
- Evaluación de consistencia entre prestaciones.
- Registro de observaciones y cambios.
- Publicación de versiones y fechas de vigencia.

La incorporación de nuevos valores o modificaciones deberá quedar documentada y ser reproducible.

Los valores pendientes de validación deberán identificarse claramente y no presentarse como valores definitivos.

## 14. Alcance y limitaciones

El sistema UVR constituye una metodología de valoración relativa propuesta por Origen Salud.

No constituye por sí mismo:

- Un arancel oficial.
- Una tarifa obligatoria.
- Una regulación de honorarios profesionales.
- Un valor monetario universal.
- Un reemplazo automático de nomencladores existentes.
- Una decisión de cobertura de un financiador.
- Una garantía de reconocimiento o pago de una prestación.

Cada institución o financiador podrá establecer sus propios valores monetarios, condiciones contractuales y reglas de reconocimiento, respetando las disposiciones que resulten aplicables.

La finalidad del SVP es ofrecer una base metodológica transparente para comparar recursos prestacionales y facilitar la construcción de modelos de valoración económica.

## 15. Objetivo a largo plazo

Origen Salud busca desarrollar un sistema de valoración que pueda aplicarse progresivamente a diferentes áreas de la atención sanitaria:

- Odontología.
- Medicina.
- Diagnóstico por imágenes.
- Laboratorio.
- Kinesiología y fisiatría.
- Psicología y salud mental.
- Rehabilitación.
- Otras especialidades y servicios sanitarios.

La metodología deberá permitir adaptaciones justificadas por especialidad y jurisdicción, manteniendo principios comunes de transparencia, trazabilidad, consistencia y revisión técnica.

El propósito es facilitar la interoperabilidad entre catálogos de prestaciones, sistemas de información sanitaria, instituciones y financiadores.

---

**Origen Salud**  
Sistema de Valoración Prestacional (UVR)  
**UVR — Unidad de Valor Relativo**

*Documento metodológico de referencia. Los valores, índices y ejemplos incluidos tienen carácter ilustrativo cuando no se identifica expresamente una fuente y una versión aprobada.*
