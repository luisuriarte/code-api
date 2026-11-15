# Origen Salud · Documentación de la API REST (v1)

> **Servicio de Terminología Clínica como Servicio (TaaS - Terminology-as-a-Service)**  
> Plataforma de interoperabilidad, catálogos médicos nacionales y ontología odontológica armonizada.

---

## 1. Información General y Acceso

- **URL Base:** `https://api.origen.ar/v1`
- **Health Check público:** `https://api.origen.ar/health`
- **Formato:** JSON (`application/json; charset=utf-8`)
- **Codificación:** UTF-8
- **Tiempos de respuesta:** Medidos en milisegundos (`took_ms` en `meta`).

### Cabeceras HTTP (Headers)

| Cabecera | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `Authorization` | Request | **Sí** | Token Bearer con la API Key: `Bearer <TU_API_KEY>` |
| `X-API-Key` | Request | Alternativo | Clave API enviada directamente: `<TU_API_KEY>` |
| `Accept` | Request | Recomendado | `application/json` |
| `Accept-Language` | Request | Opcional | `es` (default), `es-AR` o `en` |
| `X-Request-Id` | Response | Siempre | UUID único de trazabilidad para cada solicitud |

---

## 2. Autenticación y Seguridad

Todas las peticiones a la superficie `/v1/*` requieren una API Key B2B válida.

### Ejemplo de autenticación con `curl`

```bash
curl -s -X GET "https://api.origen.ar/v1/domains" \
  -H "Authorization: Bearer orig_live_xxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "Accept: application/json"
```

### Códigos de Estado HTTP

| Código | Significado | Motivo |
|---|---|---|
| `200 OK` | Éxito | La solicitud se completó correctamente. |
| `204 No Content` | Sin contenido | Respuestas pre-flight `OPTIONS` de CORS. |
| `400 Bad Request` | Petición inválida | Parámetros faltantes, tipos incorrectos o sintaxis errónea. |
| `401 Unauthorized` | No autenticado | API Key faltante, expirada o revocada. |
| `403 Forbidden` | Acceso denegado | Cuenta suspendida o cuota mensual excedida. |
| `404 Not Found` | No encontrado | El recurso, código o concepto no existe. |
| `405 Method Not Allowed`| Método no permitido | Se utilizó un método HTTP diferente a `GET` u `OPTIONS`. |
| `500 Internal Error`| Error interno | Error no recuperable del servidor (registrado en log). |
| `503 Service Unavailable`| Mantenimiento | Base de datos o servicio no disponible temporalmente. |

---

## 3. Catálogo de Dominios Clínicos

### `GET /v1/domains`
Devuelve la lista de dominios terminológicos disponibles en la plataforma y sus configuraciones.

```bash
curl -s -X GET "https://api.origen.ar/v1/domains" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

#### Respuesta de ejemplo
```json
{
  "data": [
    {
      "code": "snomed",
      "label": "SNOMED CT",
      "description": "Terminología clínica integral internacional y edición argentina.",
      "mode": "full"
    },
    {
      "code": "cie10",
      "label": "CIE-10",
      "description": "Clasificación Internacional de Enfermedades, 10.ª revisión.",
      "mode": "full"
    },
    {
      "code": "odontologia",
      "label": "Odontología",
      "description": "Nomenclador de prestaciones odontológicas, ADA CDT 2025, DENTAR y vínculos SNOMED-CT.",
      "mode": "catalog"
    },
    {
      "code": "anmat",
      "label": "Medicamentos ANMAT",
      "description": "Vademécum nacional de especialidades medicinales con código SNOMED-CT.",
      "mode": "catalog"
    },
    {
      "code": "laboratorio",
      "label": "Laboratorio",
      "description": "Prácticas de laboratorio con códigos LOINC y SNOMED-CT.",
      "mode": "catalog"
    },
    {
      "code": "vacunas",
      "label": "Vacunas",
      "description": "Catálogo oficial de vacunas MSAL y calendarios de inmunización.",
      "mode": "catalog"
    },
    {
      "code": "prestaciones",
      "label": "Prestaciones Médicas",
      "description": "Nomenclador nacional de prestaciones médicas y PMO.",
      "mode": "catalog"
    },
    {
      "code": "imagenes",
      "label": "Diagnóstico por Imágenes",
      "description": "Estudios diagnósticos por imágenes con modalidad DICOM y LOINC.",
      "mode": "catalog"
    }
  ],
  "meta": {
    "domains": ["snomed", "cie10", "anmat", "laboratorio", "vacunas", "odontologia", "prestaciones", "programas", "imagenes"],
    "default_domains": ["snomed", "cie10", "odontologia"]
  },
  "request_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d"
}
```

---

## 3. Origen Catalog Engine: Nomencladores Argentinos y DENTAR

Origen Salud implementa el **Origen Catalog Engine 1.0**, una arquitectura desacoplada que separa la identidad de las prestaciones, los aranceles vigentes y las terminologías semánticas internacionales:

| Grupo | Catálogo (`code`) | Función |
|---|---|---|
| **Propio** | `dentar` | Sistema DENTAR: Prestaciones odontológicas armonizadas con ADA CDT 2025 y CIE-10. |
| **Argentina** | `nn-pmo` | Nomenclador Nacional de Prestaciones Médicas, Quirúrgicas y Sanatoriales (PMO). |
| **Argentina** | `nbu` | Nomenclador Bioquímico Único de CUBRA (con Unidades Bioquímicas y LOINC). |
| **Argentina** | `nhpgd` | Nomenclador de Hospitales Públicos de Gestión Descentralizada (recupero de costos). |
| **Argentina** | `andis` | Nomenclador de Prestaciones Básicas para Personas con Discapacidad (rehabilitación/módulos). |
| **Argentina** | `kinesiologia`| Nomenclador de Fisioterapia y Kinesiología (motriz, respiratoria, sesiones). |
| **Argentina** | `salud-mental`| Nomenclador de Psicología y Salud Mental (psicoterapia, psicodiagnóstico). |
| **Farmacia** | `vademecum` | Vademécum farmacéutico multicapa con Troquel, AlfaBeta, Kairos y GTIN. |

### 3.1. Listar Catálogos Registrados
#### `GET /v1/catalogs`
```bash
curl -s -X GET "https://api.origen.ar/v1/catalogs" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

### 3.2. Consultar Prestaciones de un Catálogo
#### `GET /v1/catalogs/{catalog_code}/items?q={query}&limit={n}`
```bash
# Buscar hemograma en NBU
curl -s -X GET "https://api.origen.ar/v1/catalogs/nbu/items?q=hemograma" \
  -H "Authorization: Bearer <TU_API_KEY>"

# Buscar consulta en Nomenclador Nacional
curl -s -X GET "https://api.origen.ar/v1/catalogs/nn-pmo/items?q=consulta" \
  -H "Authorization: Bearer <TU_API_KEY>"

# Buscar prestaciones en DENTAR
curl -s -X GET "https://api.origen.ar/v1/catalogs/dentar/items?q=conducto" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

### 3.3. Ficha Técnica de la Prestación con Aranceles y Mapeos
#### `GET /v1/catalogs/{catalog_code}/items/{code}`
Devuelve la identidad permanente, aranceles vigentes (UB, Galenos, Módulos o Pesos) y mapeos cruzados a **SNOMED-CT**, **CIE-10** y **LOINC**.

```bash
curl -s -X GET "https://api.origen.ar/v1/catalogs/nbu/items/660475" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

### 3.4. Motor de Mapeos y Equivalencias Semánticas
#### `GET /v1/mappings?system={system}&code={code}`
Permite encontrar qué prestaciones nacionales corresponden a un concepto internacional (o viceversa):
```bash
# ¿Qué prácticas corresponden al código LOINC 58410-2?
curl -s -X GET "https://api.origen.ar/v1/mappings?system=LOINC&code=58410-2" \
  -H "Authorization: Bearer <TU_API_KEY>"

# ¿Qué prestaciones tratan el diagnóstico CIE-10 K02.1?
curl -s -X GET "https://api.origen.ar/v1/mappings?system=CIE-10&code=K02.1" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

### 3.5. Farmacia: Consulta Directa por Troquel, AlfaBeta, Kairos o GTIN
#### `GET /v1/medicines/identifiers/{system}/{code}`
```bash
# Por Número de Troquel
curl -s -X GET "https://api.origen.ar/v1/medicines/identifiers/troquel/458921" \
  -H "Authorization: Bearer <TU_API_KEY>"

# Por Código AlfaBeta o Kairos
curl -s -X GET "https://api.origen.ar/v1/medicines/identifiers/alfabeta/12045" \
  -H "Authorization: Bearer <TU_API_KEY>"

# Por Código de Barras EAN-13 / GTIN
curl -s -X GET "https://api.origen.ar/v1/medicines/identifiers/gtin/7791234567890" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

---

## 4. Búsqueda Unificada Multimodelo

### `GET /v1/search`
Permite buscar simultáneamente a través de múltiples vocabularios clínicos utilizando trigramas (`pg_trgm`), coincidencia fonética y búsqueda exacta con ponderación semántica.

#### Parámetros de consulta (Query Params)

| Parámetro | Tipo | Defecto | Descripción |
|---|---|---|---|
| `q` | `string` | **Requerido** | Término, código exacto o parte del nombre a buscar. |
| `domains` | `string` | `default` | Dominios separados por coma: `snomed,cie10,odontologia`. |
| `lang` | `string` | `es` | Idioma de las descripciones: `es` o `en`. |
| `limit` | `int` | `20` | Cantidad de resultados por página (máx. `100`). |
| `offset` | `int` | `0` | Desplazamiento para paginación. |
| `refsets` | `string` | `null` | Filtrado por RefSets de SNOMED CT (separados por coma). |
| `cie10_type`| `string` | `null` | Filtra CIE-10 por tipo: `4_caracteres`, `3_caracteres`, etc. |

#### Ejemplo de búsqueda
```bash
curl -s -X GET "https://api.origen.ar/v1/search?q=caries&domains=odontologia,snomed,cie10&limit=5" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

### `GET /v1/search/{domain}`
Atajo directo para buscar exclusivamente dentro de un dominio específico.
- `/v1/search/odontologia?q=conducto`
- `/v1/search/cie10?q=K02`
- `/v1/search/snomed?q=endodoncia`

---

## 5. Módulo Odontológico Armonizado (DENTAR / CDT / Nomenclador AR)

El módulo odontológico de Origen Salud unifica:
1. **DENTAR:** Ontología clínica con identificadores permanentes (`DNT-000001` a `DNT-000138`).
2. **ADA CDT 2025:** Estándar internacional de la Asociación Dental Americana (12 categorías, ej. `D0150`, `D2140`, `D3310`).
3. **Nomenclador Odontológico Argentino:** 11 capítulos de obras sociales y medicina prepaga (`01.01` a `11.02`).
4. **SNOMED CT:** Conceptos clínicos de procedimientos odontológicos y diagnósticos bucales.
5. **CIE-10 (K00–K14):** Diagnósticos bucomaxilofaciales y justificación clínica de auditoría.

---

### 5.1. Búsqueda y Catálogo de Diagnósticos Odontológicos

#### `GET /v1/odontologia/diagnosticos`
Permite listar o buscar en el catálogo clínico de diagnósticos odontológicos DENTAR vinculados con **CIE-10** y **SNOMED-CT**.

##### Parámetros opcionales:
- `q`: Búsqueda de texto libre en nombres de diagnósticos, códigos CIE-10 o SCTID.
- `snomed`: Filtro exacto por SCTID de SNOMED-CT (ej. `80967001`).
- `cie10`: Filtro por código CIE-10 (ej. `K02` o `K02.1`).

```bash
curl -s -X GET "https://api.origen.ar/v1/odontologia/diagnosticos?snomed=80967001" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

##### Respuesta:
```json
{
  "data": [
    {
      "code": "DNT-DX-0005",
      "clinical_name": "Caries limitada al esmalte (manchas blancas / cavitación incipiente)",
      "cie10": {
        "code": "K02.0",
        "description": "Caries limitada al esmalte"
      },
      "snomed_ct": {
        "concept_id": "80967001",
        "term": "Caries dental"
      }
    },
    {
      "code": "DNT-DX-0006",
      "clinical_name": "Caries de la dentina (cavitación simple, compuesta o compleja)",
      "cie10": {
        "code": "K02.1",
        "description": "Caries de la dentina"
      },
      "snomed_ct": {
        "concept_id": "80967001",
        "term": "Caries dental"
      }
    }
  ],
  "meta": {
    "total": 2,
    "snomed": "80967001",
    "language": "es",
    "took_ms": 1.45
  }
}
```

---

### 5.2. Detalle de Diagnóstico y Procedimientos Indicados

#### `GET /v1/odontologia/diagnosticos/{identificador}`
Permite consultar un diagnóstico odontológico y obtener **todas las prestaciones que lo tratan o resuelven clínicamente**.

##### Identificadores admitidos:
- **SCTID de SNOMED-CT:** ej. `80967001` (Caries dental), `71738007` (Pulpitis), `110463002` (Periodontitis).
- **Código CIE-10:** ej. `K02`, `K02.1`, `K04.0`.
- **Código DENTAR-DX:** ej. `DNT-DX-0006`.
- **ID numérico interno:** ej. `6`.

```bash
curl -s -X GET "https://api.origen.ar/v1/odontologia/diagnosticos/K02.1" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

##### Respuesta:
```json
{
  "data": {
    "diagnosis": {
      "dentar_diagnosis_code": "DNT-DX-0006",
      "clinical_name": "Caries de la dentina (cavitación simple, compuesta o compleja)",
      "cie10": {
        "code": "K02.1",
        "description": "Caries de la dentina"
      },
      "snomed_ct": {
        "concept_id": "80967001",
        "term": "Caries dental"
      }
    },
    "indicated_procedures": [
      {
        "dentar_code": "DNT-000007",
        "name": "Restauración con amalgama - cavidad simple",
        "nomenclador_argentino": "02.01",
        "cdt_code": "D2140",
        "snomed_concept_id": "424759004",
        "relationship_type": "indicacion_habitual",
        "clinical_rationale": "Caries oclusal o proximal que compromete dentina y requiere restauración definitiva"
      },
      {
        "dentar_code": "DNT-000010",
        "name": "Restauración con composite / resina fotocurable - cavidad simple",
        "nomenclador_argentino": "02.04",
        "cdt_code": "D2330",
        "snomed_concept_id": "424759004",
        "relationship_type": "indicacion_habitual",
        "clinical_rationale": "Caries dental activa con compromiso estético o funcional"
      }
    ]
  },
  "meta": {
    "total_indicated_procedures": 2,
    "language": "es",
    "took_ms": 2.10
  }
}
```

---

### 5.3. Justificación Clínica de Prestaciones (Matriz de Auditoría)

#### `GET /v1/odontologia/{identificador}/diagnosticos`
Devuelve los diagnósticos médicos y justificaciones que fundamentan una práctica odontológica para auditoría y facturación.

##### Identificadores admitidos:
- **Código Nomenclador Argentino:** ej. `01.01`, `02.01`, `03.01`.
- **Código ADA CDT 2025:** ej. `D0150`, `D2140`, `D3310`.
- **Código DENTAR:** ej. `DNT-000001`, `DNT-000007`.
- **SCTID SNOMED-CT de la práctica:** ej. `424759004`.
- **ID numérico de la tabla `odontologia_prestaciones`:** ej. `1`.

```bash
curl -s -X GET "https://api.origen.ar/v1/odontologia/02.01/diagnosticos" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

##### Respuesta:
```json
{
  "data": {
    "procedure": {
      "dentar_code": "DNT-000007",
      "name": "Restauración con amalgama - cavidad simple",
      "nomenclador_argentino": "02.01",
      "cdt_code": "D2140",
      "category": "Operatoria Dental y Restauradora"
    },
    "clinical_justifications": [
      {
        "dentar_diagnosis_code": "DNT-DX-0006",
        "name": "Caries de la dentina (cavitación simple, compuesta o compleja)",
        "cie10": {
          "code": "K02.1",
          "description": "Caries de la dentina"
        },
        "snomed_ct": {
          "concept_id": "80967001"
        },
        "relationship_type": "indicacion_habitual",
        "clinical_rationale": "Caries oclusal o proximal que compromete dentina y requiere restauración definitiva"
      },
      {
        "dentar_diagnosis_code": "DNT-DX-0009",
        "name": "Abrasión y atrición dentaria patológica",
        "cie10": {
          "code": "K03.1",
          "description": "Abrasión de los dientes"
        },
        "snomed_ct": {
          "concept_id": "47444005"
        },
        "relationship_type": "indicacion_posible",
        "clinical_rationale": "Pérdida de sustancia dentaria por atrición oclusal severa"
      }
    ]
  },
  "meta": {
    "total_diagnoses": 2,
    "language": "es",
    "took_ms": 1.85
  }
}
```

---

### 5.4. Búsqueda Integral por SNOMED-CT

#### `GET /v1/odontologia/snomed/{sctid}`
Permite consultar cualquier código SNOMED-CT y obtener de inmediato su contraparte en odontología (tanto si es una práctica como si es un diagnóstico).

```bash
curl -s -X GET "https://api.origen.ar/v1/odontologia/snomed/80967001" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

##### Respuesta:
```json
{
  "data": {
    "snomed_concept_id": "80967001",
    "has_procedures": false,
    "has_diagnoses": true,
    "procedures": [],
    "diagnoses": [
      {
        "dentar_diagnosis_code": "DNT-DX-0005",
        "clinical_name": "Caries limitada al esmalte (manchas blancas / cavitación incipiente)",
        "cie10": {
          "code": "K02.0",
          "description": "Caries limitada al esmalte"
        },
        "snomed_ct": {
          "concept_id": "80967001",
          "term": "Caries dental"
        }
      },
      {
        "dentar_diagnosis_code": "DNT-DX-0006",
        "clinical_name": "Caries de la dentina (cavitación simple, compuesta o compleja)",
        "cie10": {
          "code": "K02.1",
          "description": "Caries de la dentina"
        },
        "snomed_ct": {
          "concept_id": "80967001",
          "term": "Caries dental"
        }
      }
    ]
  },
  "meta": {
    "procedures_count": 0,
    "diagnoses_count": 2,
    "language": "es",
    "took_ms": 1.25
  }
}
```

---

### 5.5. Detalle de Prestación Odontológica y Reglas de Auditoría

#### `GET /v1/odontologia/{id}`
Obtiene la ficha técnica completa de una prestación por su ID interno con todas sus exigencias de auditoría médica.

```bash
curl -s -X GET "https://api.origen.ar/v1/odontologia/1" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

##### Respuesta:
```json
{
  "data": {
    "domain": "odontologia",
    "id": "1",
    "code": "01.01",
    "term": "Consulta de diagnóstico, fichado y plan de tratamiento",
    "subtitle": "Capítulo I - Consultas",
    "kind": "dental_procedure",
    "metadata": {
      "nomenclator_code": "01.01",
      "cdt_code": "D0150",
      "cdt_category": "Diagnostic",
      "cdt_category_name": "Diagnóstico y Evaluaciones Clínicas",
      "chapter": "Capítulo I - Consultas",
      "tooth_specification": false,
      "face_specification": false,
      "pre_op_xray": false,
      "post_op_xray": false,
      "dental_chart_required": true,
      "periodontal_chart_required": false,
      "material": null,
      "jaw": null,
      "audit_rules": "Requiere confección de odontograma completo firmado por el paciente."
    },
    "snomed_concept": {
      "concept_id": "424759004",
      "term": "Examen de la cavidad bucal"
    }
  },
  "meta": {
    "language": "es",
    "took_ms": 1.10
  }
}
```

---

## 6. Endpoints SNOMED CT

### `GET /v1/concepts/{id}` o `GET /v1/snomed/{id}`
Devuelve el detalle del concepto SNOMED-CT, sus descripciones FSN y sinónimos, relaciones jerárquicas directas (padres e hijos), mapeos a CIE-10, y el bloque `"dental"` enriquecido automáticamente si el concepto tiene vínculos odontológicos.

```bash
curl -s -X GET "https://api.origen.ar/v1/snomed/80967001?lang=es" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

#### Respuesta de ejemplo:
```json
{
  "data": {
    "concept_id": "80967001",
    "active": true,
    "effective_time": "20240131",
    "module_id": "900000000000207008",
    "definition_status_id": "900000000000073002",
    "descriptions": {
      "es": [
        {
          "description_id": "136932014",
          "term": "caries dental",
          "term_type": "synonym",
          "type_id": "900000000000013009"
        }
      ]
    },
    "parents": [
      {
        "concept_id": "275298006",
        "term": "trastorno del diente",
        "active": true
      }
    ],
    "children": [
      {
        "concept_id": "64969001",
        "term": "caries de la dentina",
        "active": true
      }
    ],
    "cie10_codes": [
      {
        "code": "K02.9",
        "type": "4_caracteres",
        "description": "Caries dental, no especificada"
      }
    ],
    "dental": {
      "procedures": [],
      "diagnoses": [
        {
          "dentar_diagnosis_code": "DNT-DX-0005",
          "clinical_name": "Caries limitada al esmalte (manchas blancas / cavitación incipiente)",
          "cie10": {
            "code": "K02.0",
            "description": "Caries limitada al esmalte"
          }
        }
      ]
    }
  },
  "meta": {
    "language": "es",
    "took_ms": 3.80
  }
}
```

---

## 7. Endpoints CIE-10

### `GET /v1/cie10/{codigo}`
Detalle de un código CIE-10 oficial de la OMS. Acepta códigos con punto (`K02.1`) o sin punto (`K021`).

```bash
curl -s -X GET "https://api.origen.ar/v1/cie10/K02.1" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

#### Respuesta:
```json
{
  "data": {
    "code": "K02.1",
    "type": "4_caracteres",
    "descriptions": {
      "es": [
        "Caries de la dentina"
      ],
      "en": [
        "Caries of dentine"
      ]
    },
    "snomed_mappings": [
      {
        "concept_id": "80967001",
        "term": "caries dental"
      }
    ]
  },
  "meta": {
    "language": "es",
    "took_ms": 1.60
  }
}
```

---

## 8. Catálogo Internacional LOINC (Laboratorio y Observaciones Clínicas)

Origen Salud integra la versión completa y oficial de **LOINC 2.83** con más de **112.400 conceptos clínicos** armonizados con sus capas lingüísticas en español (México y Argentina).

### 8.1. Búsqueda y filtrado en LOINC
#### `GET /v1/loinc`

##### Parámetros de consulta:
| Parámetro | Tipo | Descripción |
|---|---|---|
| `q` | `string` | Término libre o código LOINC (ej. `hemograma`, `58410-2`, `glucosa`). |
| `class` | `string` | Filtro por tipo de clase (ej. `HEM/BC`, `CHEM`, `MICRO`, `SERO`). |
| `status` | `string` | Filtro por estado: `ACTIVE`, `DEPRECATED`, `DISCOURAGED`. |
| `system` | `string` | Filtro por muestra o espécimen: `Ser/Plas`, `Bld`, `Urine`, `Pt`. |
| `limit` | `int` | Límite de resultados (defecto: `20`, máx: `100`). |
| `offset` | `int` | Paginación (defecto: `0`). |

```bash
curl -s -X GET "https://api.origen.ar/v1/loinc?q=hemograma&limit=5" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

##### Respuesta:
```json
{
  "data": [
    {
      "code": "58410-2",
      "long_common_name": "CBC panel - Blood by Automated count",
      "display_name": "Recuento sanguíneo completo con recuento diferencial automatizado en sangre",
      "component": "Hemograma completo",
      "property": "Contenido numérico",
      "time_aspect": "Punto en el tiempo",
      "system": "Sangre",
      "scale": "Cuantitativo",
      "method": "Contador automatizado",
      "class": "HEM/BC",
      "status": "ACTIVE",
      "shortname": "CBC pnl Auto Bld",
      "example_units": null,
      "example_ucum_units": "10*3/uL",
      "order_obs": "Both"
    }
  ],
  "meta": {
    "query": "hemograma",
    "class": null,
    "status": null,
    "system": null,
    "limit": 5,
    "offset": 0,
    "returned": 1,
    "language": "es",
    "took_ms": 1.45
  }
}
```

### 8.2. Ficha Técnica y Mapeos de un Concepto LOINC
#### `GET /v1/loinc/{code}`

Devuelve todos los atributos clínicos, fórmulas, unidades UCUM, tabla de mapeos `MapTo` y su correlación con los nomencladores oficiales de Argentina (NBU, NN/PMO).

```bash
curl -s -X GET "https://api.origen.ar/v1/loinc/58410-2" \
  -H "Authorization: Bearer <TU_API_KEY>"
```

##### Respuesta:
```json
{
  "data": {
    "code": "58410-2",
    "long_common_name": "CBC panel - Blood by Automated count",
    "display_name": "Recuento sanguíneo completo con recuento diferencial automatizado en sangre",
    "component": "Hemograma completo",
    "property": "Contenido numérico",
    "time_aspect": "Punto en el tiempo",
    "system": "Sangre",
    "scale": "Cuantitativo",
    "method": "Contador automatizado",
    "class": "HEM/BC",
    "status": "ACTIVE",
    "shortname": "CBC pnl Auto Bld",
    "example_ucum_units": "10*3/uL",
    "order_obs": "Both",
    "consumer_name": "Hemograma completo automatizado",
    "definition": "Panel de recuento celular hematológico completo...",
    "mappings_map_to": [],
    "argentine_nomenclators": [
      {
        "nomenclator": "NBU",
        "code": "660475",
        "description": "Hemograma completo (recuento de hematíes, leucocitos, fórmula leucocitaria, Hb y Hto)",
        "unit_type": "UB",
        "unit_value": 3.8000
      }
    ]
  },
  "meta": {
    "took_ms": 0.85
  }
}
```

---

## 9. Programa Médico Obligatorio (PMO / PMOE - Res. 201/2002)

Servicio normativo y arancelario de la canasta básica de cobertura obligatoria de Argentina (Res. 201/2002 y Actualización 1/2002).

### 9.1 Búsqueda de Prácticas Médicas PMO

```http
GET /v1/pmo/practicas?q={termino}&capitulo={codigo_o_nombre}&cobertura_condicionada={bool}
```

```bash
curl -s -H "X-API-Key: TU_API_KEY" \
  "https://api.origen.ar/v1/pmo/practicas?q=craneotomia"
```

### 9.2 Detalle de Práctica PMO por Código

```http
GET /v1/pmo/practicas/{codigo}
```

```bash
curl -s -H "X-API-Key: TU_API_KEY" \
  "https://api.origen.ar/v1/pmo/practicas/010101"
```

### 9.3 Medicamentos y Precios de Referencia PMO

```http
GET /v1/pmo/medicamentos?q={droga_o_presentacion}&atc={codigo_atc}
```

```bash
curl -s -H "X-API-Key: TU_API_KEY" \
  "https://api.origen.ar/v1/pmo/medicamentos?q=amoxicilina"
```

### 9.4 Textos y Resoluciones Normativas PMO

```http
GET /v1/pmo/normativa?q={termino}&seccion={seccion}
```

```bash
curl -s -H "X-API-Key: TU_API_KEY" \
  "https://api.origen.ar/v1/pmo/normativa?q=materno"
```

---

## 10. Medicamentos ANMAT y Catálogos Locales

| Endpoint | Descripción | Identificador |
|---|---|---|
| `GET /v1/anmat/{id}` | Vademécum ANMAT con certificado y nombre genérico | ID de registro |
| `GET /v1/laboratorio/{id}` | Prácticas bioquímicas con código LOINC y SNOMED | ID de registro |
| `GET /v1/vacunas/{id}` | Inmunizaciones MSAL con esquemas de vacunación | ID de registro |
| `GET /v1/prestaciones/{id}` | Prestaciones médicas generales / PMO | ID de registro |
| `GET /v1/imagenes/{id}` | Estudios de imágenes con modalidad DICOM y LOINC | ID de registro |
| `GET /v1/programas/{id}` | Planes de cobertura social y atributos poblacionales | ID de registro |

---

## 11. Monitoreo y Health Check

### `GET /health`
Endpoint público diseñado para balanceadores de carga, monitoreo de uptime y Kubernetes probes. **No requiere autenticación**.

```bash
curl -s -X GET "https://api.origen.ar/health"
```

```json
{
  "status": "ok",
  "service": "origen-salud-api",
  "version": "1.0.0",
  "time": "2026-11-15T14:45:00Z",
  "checks": {
    "database": "ok"
  }
}
```
Si la base de datos no responde, devuelve código HTTP `503 Service Unavailable`.
