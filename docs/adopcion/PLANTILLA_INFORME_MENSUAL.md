# Seguimiento mensual de adopción de DENTAR

Plantilla del informe que se produce **todos los meses**, aunque no haya
novedades. Un archivo por mes: `docs/adopcion/informes/AAAA-MM.md`.

Reglas de producción:

- Sólo se afirma lo que se puede verificar con una fuente pública y fechada.
- Se distinguen explícitamente **hechos confirmados**, **oportunidades**
  (conversaciones o convocatorias abiertas) y **especulaciones**.
- No se inventan contactos, nombres ni acuerdos. Si no hay vía pública, se
  escribe "sin vía de contacto pública identificada".
- Se compara con el informe del mes anterior y se marcan los cambios
  (`nuevo`, `actualizado`, `sin cambios`) para no presentar lo mismo como
  novedad.
- Si no hay novedades verificables, el informe se entrega igual y lo dice.

---

# Informe de adopción DENTAR · AAAA-MM

**Período:** AAAA-MM-01 a AAAA-MM-DD
**Responsable:** _(nombre)_
**Versión del catálogo publicada:** DENTAR vX.Y (`os_catalog_release.version_tag`)
**Códigos publicados:** _(N)_ sobre 800 objetivo
**Comparación:** `docs/adopcion/informes/AAAA-MM-anterior.md`

## 1. Resumen ejecutivo

_(Máximo 5 líneas: qué cambió este mes y cuál es la acción más importante para
el mes siguiente.)_

## 2. Novedades verificadas

| Fecha | Institución | País / provincia | Hecho verificado | Fuente (enlace) |
| --- | --- | --- | --- | --- |
| AAAA-MM-DD |  |  |  |  |

> Sin novedades verificables este mes: _(marcar si corresponde)_

## 3. Instituciones objetivo prioritarias

Ordenadas por probabilidad de adopción × impacto. Se mantienen entre meses; se
actualiza el estado.

| Prioridad | Institución | Tipo | Provincia / país | Motivo de pertinencia | Estado | Último contacto | Próximo paso |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 |  | Colegio / Universidad / Obra social / Prepaidora / Hospital / Organismo / Software |  |  | `sin contacto` / `contacto inicial` / `reunión` / `piloto` / `adopción` |  |  |

Tipos de institución a cubrir cada mes: colegios y asociaciones odontológicas,
universidades y facultades de odontología, sociedades científicas y
especialistas, obras sociales y prepagas, financiadores, hospitales, organismos
públicos, proveedores de software odontológico e iniciativas de
interoperabilidad.

## 4. Oportunidades nuevas o modificadas

| Cambio | Institución | Oportunidad concreta | Evidencia | Vía de contacto pública | Próximo paso recomendado |
| --- | --- | --- | --- | --- | --- |
| `nuevo` / `actualizado` |  |  |  |  |  |

Incluye: convocatorias, jornadas, congresos, comités técnicos, mesas de
interoperabilidad, concursos de historia clínica digital, programas provinciales.

## 5. Evidencia de interés y adopción

Separar por nivel de evidencia:

| Nivel | Qué cuenta | Ejemplos del mes |
| --- | --- | --- |
| Interés declarado | respuesta institucional, invitación, pedido de información |  |
| Validación técnica | prueba de la API, revisión del catálogo, mapeo solicitado |  |
| Piloto | uso en un circuito real (facturación, autorización, historia clínica) |  |
| Adopción | uso en producción con contrato o resolución |  |

Métricas técnicas que acompañan el informe (si hay tabla de auditoría de
requests habilitada): cantidad de consultas por cliente B2B y por dominio en el
período. Si no hay logs activos, se informa "sin métricas de uso".

## 6. Riesgos y barreras

| Riesgo | Impacto | Evidencia | Mitigación propuesta |
| --- | --- | --- | --- |
|  |  |  |  |

Riesgos típicos a revisar: resistencia a un código nuevo, convivencia con el
nomenclador vigente, requisitos de las obras sociales, falta de mapeo CDT/SNOMED
en especialidades, dependencia de un proveedor de software dominante.

## 7. Acciones recomendadas para el próximo mes

1. _(Acción concreta, institución, responsable y fecha objetivo.)_
2. …

## 8. Anexo · fuentes consultadas

| Fuente | Tipo | Fecha de consulta | Enlace |
| --- | --- | --- | --- |
|  |  |  |  |

---

## Propuesta de valor a repetir en cada contacto

- Códigos **permanentes** para prestaciones: no cambian cuando cambia el
  arancel.
- **Convivencia** con los nomencladores vigentes (NN/PMO, NBU, NHPGD, ANDIS,
  CDT 2025): DENTAR no reemplaza, ordena y mapea.
- **Mapeos versionados** con SNOMED CT y CIE-10, auditables.
- **API** (`api.origen.ar`) para integrar en sistemas de obras sociales,
  colegios y software odontológico.
- **Comité editorial** con participación institucional: el catálogo no lo fija
  Origen Salud solo.
