# Origen Salud · Guía de Interoperabilidad HL7® FHIR® R4

> **Servicio de Terminología Clínica Estándar (FHIR Terminology Service)**  
> Implementación de interoperabilidad conforme al estándar **HL7 FHIR Release 4 (R4)** para Historias Clínicas Electrónicas (HCE), Receta Digital y Facturación Odontológica.

> [!IMPORTANT]
> **Estado: contrato propuesto, no implementado.** En el código actual `api/index.php`
> no enruta ninguna ruta `/fhir/*`; todos los ejemplos de este documento son una
> especificación objetivo, no un servicio disponible. Además, la guardia de API
> Key cubre solo `/v1/*`, por lo que cualquier endpoint `/fhir/*` que se agregue
> debe incorporarse explícitamente a esa guardia antes de publicarse. Las URI
> canónicas y los ejemplos de respuesta son propuestas editoriales pendientes de
> aprobación formal, no hechos implementados. Los ejemplos usan códigos
> ilustrativos heredados (`DNT-000007`) que **deben reemplazarse** por códigos
> reales `DNT-PR-NNNNNN` antes de cualquier publicación; no deben interpretarse
> como identificadores válidos.

---

## 1. Introducción y Arquitectura FHIR

Origen Salud expone sus catálogos clínicos, terminologías y ontología odontológica bajo los estándares de **HL7 FHIR R4 Terminology Services**. Esto permite la integración directa con:

- Sistemas Hospitalarios y Clínicos (EHR / HCE) como Epic, Cerner, GNU Health u OpenEMR.
- Redes Nacionales y Provinciales de Salud Interoperable (Argentina Salud / Red Federal).
- Plataformas de Auditoría Odontológica y Facturación B2B.

### Endpoint Base FHIR
- **URL Base propuesta:** `https://api.origen.ar/fhir` (sin enrutar actualmente)
- **MIME Types previstos:**
  - `application/fhir+json; charset=utf-8`
  - `application/json; charset=utf-8`
- **Autenticación prevista:** cabecera HTTP `Authorization: Bearer <API_KEY>`; debe extenderse la guardia actual, que solo cubre `/v1/*`.

---

## 2. Sistemas Terminológicos Administrados (CodeSystems)

Para garantizar la interoperabilidad semántica, cada vocabulario y catálogo cuenta con su **URI Canónica universal**:

| Vocabulario / Dominio | URI Canónica (`system`) | OID / Autoridad |
|---|---|---|
| **SNOMED CT (Internacional y Edición AR)** | `http://snomed.info/sct` | `2.16.840.1.113883.6.96` |
| **CIE-10 (OMS / Clasificación Estadística)** | `http://hl7.org/fhir/sid/icd-10` | `2.16.840.1.113883.6.3` |
| **DENTAR (Procedimientos Odontológicos)** | `https://origen.ar/fhir/CodeSystem/dentar-procedures` | Origen Salud |
| **DENTAR (Diagnósticos Odontológicos)** | `https://origen.ar/fhir/CodeSystem/dentar-diagnoses` | Origen Salud |
| **ADA CDT 2025 (American Dental Association)**| `http://www.ada.org/cdt` | ADA |
| **Nomenclador Nacional Médico / PMO** | `https://origen.ar/fhir/CodeSystem/ar-nomenclador-nacional` | MSAL / PMO |
| **Nomenclador Bioquímico Único (NBU)** | `https://origen.ar/fhir/CodeSystem/ar-nbu` | CUBRA |
| **Nomenclador NHPGD (Hospitales Públicos)** | `https://origen.ar/fhir/CodeSystem/ar-nhpgd` | MSAL |
| **Nomenclador Discapacidad (ANDIS)** | `https://origen.ar/fhir/CodeSystem/ar-andis` | ANDIS |
| **Nomenclador Odontológico Argentino** | `https://origen.ar/fhir/CodeSystem/ar-nomenclador-odontologico` | C.O.R.A. / Obras Sociales |
| **Vademécum Comercial (Troquel/GTIN)** | `https://origen.ar/fhir/CodeSystem/ar-vademecum` | AlfaBeta / Kairos / GS1 |
| **LOINC (Laboratorio e Imágenes)** | `http://loinc.org` | `2.16.840.1.113883.6.1` |
| **Medicamentos ANMAT** | `https://origen.ar/fhir/CodeSystem/anmat-medicamentos` | ANMAT Argentina |

---

## 3. Declaración de Conformidad (`CapabilityStatement`)

### `GET /fhir/metadata`
Devuelve la declaración formal de capacidades del servidor terminológico de Origen Salud.

```bash
curl -s -X GET "https://api.origen.ar/fhir/metadata" \
  -H "Authorization: Bearer <TU_API_KEY>" \
  -H "Accept: application/fhir+json"
```

#### Fragmento de respuesta:
```json
{
  "resourceType": "CapabilityStatement",
  "status": "active",
  "date": "2026-11-15T00:00:00Z",
  "publisher": "Origen Salud",
  "kind": "instance",
  "software": {
    "name": "Origen Salud Terminology Server",
    "version": "1.0.0"
  },
  "fhirVersion": "4.0.1",
  "format": ["application/fhir+json", "application/json"],
  "rest": [
    {
      "mode": "server",
      "resource": [
        {
          "type": "CodeSystem",
          "operation": [
            { "name": "lookup", "definition": "http://hl7.org/fhir/OperationDefinition/CodeSystem-lookup" }
          ]
        },
        {
          "type": "ValueSet",
          "operation": [
            { "name": "expand", "definition": "http://hl7.org/fhir/OperationDefinition/ValueSet-expand" },
            { "name": "validate-code", "definition": "http://hl7.org/fhir/OperationDefinition/ValueSet-validate-code" }
          ]
        },
        {
          "type": "ConceptMap",
          "operation": [
            { "name": "translate", "definition": "http://hl7.org/fhir/OperationDefinition/ConceptMap-translate" }
          ]
        }
      ]
    }
  ]
}
```

---

## 4. Operaciones Terminológicas Estándar

### 4.1. Operación `$lookup` (Inspección de Conceptos)

Devuelve información conceptual completa de un código: nombre preferido, designaciones bilingües y propiedades de auditoría (pieza requerida, radiografías, capítulo).

#### `GET /fhir/CodeSystem/$lookup?system={uri}&code={codigo}`

#### Ejemplo: Inspección de una prestación odontológica
```bash
curl -s -X GET "https://api.origen.ar/fhir/CodeSystem/\$lookup?system=https://origen.ar/fhir/CodeSystem/dentar-procedures&code=DNT-000007" \
  -H "Authorization: Bearer <TU_API_KEY>" \
  -H "Accept: application/fhir+json"
```

#### Respuesta `Parameters`:
```json
{
  "resourceType": "Parameters",
  "parameter": [
    { "name": "name", "valueString": "DENTAR Procedures" },
    { "name": "display", "valueString": "Restauración con amalgama - cavidad simple" },
    {
      "name": "designation",
      "part": [
        { "name": "language", "valueCode": "es-AR" },
        { "name": "use", "valueCoding": { "system": "http://snomed.info/sct", "code": "900000000000003001", "display": "Fully specified name" } },
        { "name": "value", "valueString": "Restauración con amalgama - cavidad simple" }
      ]
    },
    {
      "name": "property",
      "part": [
        { "name": "code", "valueCode": "nomenclador_ar" },
        { "name": "valueString", "valueString": "02.01" }
      ]
    },
    {
      "name": "property",
      "part": [
        { "name": "code", "valueCode": "cdt_code" },
        { "name": "valueString", "valueString": "D2140" }
      ]
    },
    {
      "name": "property",
      "part": [
        { "name": "code", "valueCode": "snomed_concept_id" },
        { "name": "valueString", "valueString": "424759004" }
      ]
    },
    {
      "name": "property",
      "part": [
        { "name": "code", "valueCode": "tooth_required" },
        { "name": "valueBoolean", "valueBoolean": true }
      ]
    },
    {
      "name": "property",
      "part": [
        { "name": "code", "valueCode": "pre_op_xray" },
        { "name": "valueBoolean", "valueBoolean": false }
      ]
    }
  ]
}
```

---

### 4.2. Operación `$expand` (Autocompletado de ValueSets)

Permite expandir conjuntos de valores para listas desplegables, búsqueda en tiempo real de términos clínicos y autocompletado en la Historia Clínica Electrónica.

#### `GET /fhir/ValueSet/$expand?url={valueset_url}&filter={termino}&count={n}`

#### ValueSets Odontológicos Disponibles:
- `https://api.origen.ar/fhir/ValueSet/dentar-procedures-all` (Todas las prestaciones)
- `https://api.origen.ar/fhir/ValueSet/dentar-endodontics` (Capítulo Endodoncia)
- `https://api.origen.ar/fhir/ValueSet/dentar-restorative` (Operatoria dental y restauradora)
- `https://api.origen.ar/fhir/ValueSet/dentar-diagnoses-caries` (Diagnósticos de caries K02)
- `https://api.origen.ar/fhir/ValueSet/dentar-diagnoses-perio` (Diagnósticos periodontales K05)

#### Ejemplo de llamada:
```bash
curl -s -X GET "https://api.origen.ar/fhir/ValueSet/\$expand?url=https://origen.ar/fhir/ValueSet/dentar-procedures-all&filter=amalgama&count=5" \
  -H "Authorization: Bearer <TU_API_KEY>" \
  -H "Accept: application/fhir+json"
```

#### Respuesta `ValueSet`:
```json
{
  "resourceType": "ValueSet",
  "status": "active",
  "expansion": {
    "timestamp": "2026-11-15T12:00:00Z",
    "total": 3,
    "contains": [
      {
        "system": "https://origen.ar/fhir/CodeSystem/dentar-procedures",
        "code": "DNT-000007",
        "display": "Restauración con amalgama - cavidad simple"
      },
      {
        "system": "https://origen.ar/fhir/CodeSystem/dentar-procedures",
        "code": "DNT-000008",
        "display": "Restauración con amalgama - cavidad compuesta"
      },
      {
        "system": "https://origen.ar/fhir/CodeSystem/dentar-procedures",
        "code": "DNT-000009",
        "display": "Restauración con amalgama - cavidad compleja"
      }
    ]
  }
}
```

---

### 4.3. Operación `$translate` (Traducción y Mapeo Cruzado)

Permite traducir conceptos entre diferentes vocabularios clínicos o vincular una prestación con sus diagnósticos justificantes.

#### `GET /fhir/ConceptMap/$translate?code={code}&system={system}&target={targetSystem}`

#### Casos de Uso:
1. **Nomenclador Argentino a ADA CDT 2025:**  
   `code=02.01` + `system=.../ar-nomenclador-odontologico` + `target=http://www.ada.org/cdt`  
   -> Devuelve `D2140` (Amalgam - one surface).
2. **Prestación a Diagnósticos Justificantes (CIE-10):**  
   `code=DNT-000007` + `target=http://hl7.org/fhir/sid/icd-10`  
   -> Devuelve `K02.1` (Caries de la dentina) con equivalencia `equivalent` y fundamentación clínica.

#### Respuesta `Parameters`:
```json
{
  "resourceType": "Parameters",
  "parameter": [
    { "name": "result", "valueBoolean": true },
    { "name": "message", "valueString": "Mapeo encontrado satisfactoriamente" },
    {
      "name": "match",
      "part": [
        { "name": "equivalence", "valueCode": "equivalent" },
        {
          "name": "concept",
          "valueCoding": {
            "system": "http://www.ada.org/cdt",
            "code": "D2140",
            "display": "Amalgam - one surface, primary or permanent"
          }
        }
      ]
    }
  ]
}
```

---

## 5. Ejemplos de Recursos Clínicos HL7 FHIR R4

### 5.1. Recurso `Procedure` (Intervención Odontológica)

Representa una intervención realizada en el paciente, codificada con DENTAR y CDT, especificando la pieza dental mediante el sistema **FDI (ISO 3950)** en el atributo `bodySite`.

```json
{
  "resourceType": "Procedure",
  "id": "proc-dental-example-01",
  "status": "completed",
  "category": {
    "coding": [
      {
        "system": "http://snomed.info/sct",
        "code": "387713003",
        "display": "Procedimiento quirúrgico"
      }
    ],
    "text": "Odontología Restauradora"
  },
  "code": {
    "coding": [
      {
        "system": "https://origen.ar/fhir/CodeSystem/dentar-procedures",
        "code": "DNT-000007",
        "display": "Restauración con amalgama - cavidad simple"
      },
      {
        "system": "http://www.ada.org/cdt",
        "code": "D2140",
        "display": "Amalgam - one surface"
      },
      {
        "system": "https://origen.ar/fhir/CodeSystem/ar-nomenclador-odontologico",
        "code": "02.01",
        "display": "Amalgama cavidad simple"
      }
    ],
    "text": "Restauración oclusal pieza 36"
  },
  "subject": {
    "reference": "Patient/100234",
    "display": "Juan Pérez"
  },
  "performedDateTime": "2026-11-15T10:30:00-03:00",
  "reasonReference": [
    {
      "reference": "Condition/diag-caries-01",
      "display": "Caries de la dentina (K02.1)"
    }
  ],
  "bodySite": [
    {
      "coding": [
        {
          "system": "http://snomed.info/sct",
          "code": "245404008",
          "display": "Estructura del primer molar inferior izquierdo permanente (Pieza 36)"
        }
      ],
      "text": "Pieza 36 (FDI)"
    }
  ]
}
```

---

### 5.2. Recurso `Condition` (Diagnóstico Odontológico)

Representa el diagnóstico o problema de salud bucal identificado por el odontólogo, combinando **CIE-10** (para reporte epidemiológico y cobertura) y **SNOMED-CT** (para precisión clínica).

```json
{
  "resourceType": "Condition",
  "id": "diag-caries-01",
  "clinicalStatus": {
    "coding": [
      {
        "system": "http://terminology.hl7.org/CodeSystem/condition-clinical",
        "code": "active"
      }
    ]
  },
  "verificationStatus": {
    "coding": [
      {
        "system": "http://terminology.hl7.org/CodeSystem/condition-ver-status",
        "code": "confirmed"
      }
    ]
  },
  "category": [
    {
      "coding": [
        {
          "system": "http://terminology.hl7.org/CodeSystem/condition-category",
          "code": "encounter-diagnosis",
          "display": "Diagnóstico de consulta"
        }
      ]
    }
  ],
  "code": {
    "coding": [
      {
        "system": "http://hl7.org/fhir/sid/icd-10",
        "code": "K02.1",
        "display": "Caries de la dentina"
      },
      {
        "system": "http://snomed.info/sct",
        "code": "80967001",
        "display": "Caries dental"
      },
      {
        "system": "https://origen.ar/fhir/CodeSystem/dentar-diagnoses",
        "code": "DNT-DX-0006",
        "display": "Caries de la dentina (cavitación simple, compuesta o compleja)"
      }
    ],
    "text": "Caries activa de dentina en molar inferior"
  },
  "subject": {
    "reference": "Patient/100234",
    "display": "Juan Pérez"
  },
  "onsetDateTime": "2026-11-15"
}
```

---

### 5.3. Recurso `Claim` (Facturación Odontológica y Auditoría)

Estructura FHIR para el envío de facturación a Obras Sociales y Prepagas con vinculación obligatoria entre el procedimiento odontológico y la justificación diagnóstica.

```json
{
  "resourceType": "Claim",
  "status": "active",
  "type": {
    "coding": [
      {
        "system": "http://terminology.hl7.org/CodeSystem/claim-type",
        "code": "oral",
        "display": "Dental"
      }
    ]
  },
  "use": "claim",
  "patient": {
    "reference": "Patient/100234"
  },
  "created": "2026-11-15T11:00:00Z",
  "provider": {
    "reference": "Practitioner/odontologo-567"
  },
  "priority": {
    "coding": [
      {
        "code": "normal"
      }
    ]
  },
  "diagnosis": [
    {
      "sequence": 1,
      "diagnosisCodeableConcept": {
        "coding": [
          {
            "system": "http://hl7.org/fhir/sid/icd-10",
            "code": "K02.1",
            "display": "Caries de la dentina"
          }
        ]
      }
    }
  ],
  "item": [
    {
      "sequence": 1,
      "diagnosisSequence": [1],
      "productOrService": {
        "coding": [
          {
            "system": "https://origen.ar/fhir/CodeSystem/ar-nomenclador-odontologico",
            "code": "02.01",
            "display": "Amalgama cavidad simple"
          },
          {
            "system": "http://www.ada.org/cdt",
            "code": "D2140"
          }
        ]
      },
      "bodySite": {
        "coding": [
          {
            "system": "http://snomed.info/sct",
            "code": "245404008",
            "display": "Pieza 36"
          }
        ]
      },
      "subSite": [
        {
          "coding": [
            {
              "system": "http://terminology.hl7.org/CodeSystem/tooth-surface",
              "code": "O",
              "display": "Oclusal"
            }
          ]
        }
      ]
    }
  ]
}
```

---

## 6. Guía de Adaptación: API REST (`/v1/*`) a Recursos FHIR R4

Para clientes que consumen la API REST directa de Origen Salud (`api.origen.ar/v1/`) pero necesitan construir o poblar recursos FHIR internamente, utilice la siguiente matriz de correspondencia:

| Endpoint Origen Salud REST | Atributo REST | Recurso FHIR R4 Destino | Propiedad FHIR R4 |
|---|---|---|---|
| `/v1/odontologia/{id}` | `code` (`01.01`) | `Procedure.code` | `coding[system='.../ar-nomenclador-odontologico']` |
| `/v1/odontologia/{id}` | `metadata.cdt_code` (`D0150`) | `Procedure.code` | `coding[system='http://www.ada.org/cdt']` |
| `/v1/odontologia/{id}` | `snomed_concept.concept_id` | `Procedure.code` | `coding[system='http://snomed.info/sct']` |
| `/v1/odontologia/{id}/diagnosticos` | `cie10.code` (`K02.1`) | `Condition.code` | `coding[system='http://hl7.org/fhir/sid/icd-10']` |
| `/v1/odontologia/diagnosticos/{id}` | `indicated_procedures` | `ConceptMap.group.element` | `target[equivalence='equivalent']` |
| `/v1/snomed/{id}` | `concept_id` | `CodeableConcept` | `coding[system='http://snomed.info/sct']` |
| `/v1/cie10/{code}` | `code` | `CodeableConcept` | `coding[system='http://hl7.org/fhir/sid/icd-10']` |
| `/v1/laboratorio/{id}` | `metadata.loinc_code` | `Observation.code` | `coding[system='http://loinc.org']` |
| `/v1/anmat/{id}` | `certificate` / `generic_name` | `Medication.code` | `coding[system='https://origen.ar/fhir/...']` |
