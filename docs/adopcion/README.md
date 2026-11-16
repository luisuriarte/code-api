# Adopción institucional de DENTAR

Seguimiento mensual de la adopción del catálogo DENTAR en instituciones
argentinas y latinoamericanas. El objetivo no es acumular contactos: es mostrar,
mes a mes y con evidencia, qué instituciones conocen el catálogo, lo validaron
técnicamente, lo probaron en un circuito real o lo adoptaron.

## Cadencia y archivos

| Elemento | Ubicación |
| --- | --- |
| Plantilla del informe | [`PLANTILLA_INFORME_MENSUAL.md`](PLANTILLA_INFORME_MENSUAL.md) |
| Informes publicados | `docs/adopcion/informes/AAAA-MM.md` (se crea al primer informe) |
| Comparación | cada informe referencia el archivo del mes anterior |

El informe se produce **todos los meses**, incluso si no hay novedades. En ese
caso se entrega igual, con la sección 2 marcada como "sin novedades
verificables". Un mes sin informe se interpreta como seguimiento interrumpido.

## Reglas de veracidad

1. **Nada se afirma sin fuente.** Cada hecho de las secciones 2, 4 y 5 lleva
   fecha, enlace o resolución. Una conversación informal no es una novedad
   verificada.
2. **No se inventan contactos, nombres, cargos ni acuerdos.** Si no hay vía
   pública, se escribe "sin vía de contacto pública identificada".
3. **Se distingue el nivel de evidencia**: interés declarado, validación
   técnica, piloto y adopción no son lo mismo y no se suman.
4. **No se repite lo viejo como nuevo.** Cada fila se marca `nuevo`,
   `actualizado` o `sin cambios` respecto del informe anterior.
5. **Los riesgos se documentan aunque incomoden**: resistencia al código nuevo,
   convivencia con el nomenclador vigente, requisitos de obras sociales, falta
   de mapeos en especialidades, dependencia de un proveedor de software.

## Circuito mensual sugerido

1. **Día 1-5**: revisar fuentes públicas (colegios, universidades, obras
   sociales, prepagas, hospitales, organismos, cámaras de software,
   convocatorias de interoperabilidad).
2. **Día 6-10**: actualizar el estado de las instituciones objetivo y registrar
   oportunidades nuevas.
3. **Día 11-15**: completar evidencia técnica y de uso; pedir métricas de API si
   hay clientes B2B activos.
4. **Día 16-20**: redactar el informe, compararlo con el mes anterior, definir
   las acciones del mes siguiente.
5. **Día 21-25**: publicar el archivo en `docs/adopcion/informes/` y archivar
   fuentes consultadas.

## Métricas técnicas

Si hay registro de requests por cliente, el informe incluye consultas por
cliente y por dominio en el período. Si no hay logs habilitados, se informa
"sin métricas de uso"; no se estiman números.

## Relación con el catálogo

El informe debe citar la versión publicada del catálogo (`os_catalog_release`)
y la cantidad de códigos publicados sobre el objetivo de 800. Un cambio de
versión del catálogo se explica en el resumen ejecutivo, porque puede afectar a
las instituciones que ya integran la API.
