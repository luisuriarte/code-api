# Datos ficticios — Etapa 4

> **Estado:** definición de datos sintéticos. **No cargados.**
> **Prohibido:** usar datos reales de clientes, contactos, CUIT real, correos corporativos reales, tokens reales ni facturas reales.

## 1. Reglas generales

1. Todos los correos usan `@example.invalid`, dominio reservado.
2. Los identificadores fiscales son inválidos a propósito.
3. Los nombres son genéricos y no identifican personas reales.
4. Ningún dato se envía a Invoice Ninja ni FreeScout.
5. Ninguna credencial demo funciona contra la API real.
6. Los valores se usan solo en base independiente de prueba.

## 2. Organizaciones ficticias

| Código | Razón social | Identificador fiscal | Tipo | Estado |
|---|---|---|---|---|
| `ORG-DEMO-001` | Cliente Ficticio Demo S.A. | `00-00000000-0` | Institución de prueba | `active` |
| `ORG-DEMO-002` | Clínica Demostrativa S.R.L. | `00-00000000-0` | Clínica ficticia | `active` |
| `ORG-DEMO-003` | Universidad Simulada | `00-00000000-0` | Universidad ficticia | `suspended` |

## 3. Usuarios ficticios

| Código | Nombre | Correo | Rol propuesto | Organización |
|---|---|---|---|---|
| `USR-DEMO-001` | Usuario Demo Uno | `usuario1@test.example.invalid` | `organization_owner` | `ORG-DEMO-001` |
| `USR-DEMO-002` | Usuario Demo Dos | `usuario2@test.example.invalid` | `technical_admin` | `ORG-DEMO-001` |
| `USR-DEMO-003` | Usuario Demo Tres | `usuario3@test.example.invalid` | `viewer` | `ORG-DEMO-002` |
| `USR-DEMO-004` | Usuario Demo Cuatro | `usuario4@test.example.invalid` | `developer` | `ORG-DEMO-002` |
| `USR-DEMO-005` | Usuario Demo Cinco | `usuario5@test.example.invalid` | `organization_owner` | `ORG-DEMO-003` |

**Contraseñas:** no predefinidas en texto plano. Si se cargan, se genera una contraseña aleatoria por usuario y se guarda solo el hash. El valor claro, si hace falta, se entrega al responsable por canal seguro y se descarta.

## 4. Servicios técnicos ficticios

| Código | Nombre | Descripción | Estado |
|---|---|---|---|
| `SVC-DEMO-SEARCH` | Consulta de catálogos | Servicio de prueba para `/v1/search`. | `available` |
| `SVC-DEMO-DOCS` | Documentación técnica | Acceso de prueba a documentación. | `available` |
| `SVC-DEMO-REPORT` | Informes simulados | Servicio suspendido para probar estados. | `suspended` |

## 5. Productos comerciales ficticios

| Código | Nombre | Precio | Origen |
|---|---|---|---|
| `PROD-DEMO-001` | Producto Simulado Básico | No local | Referencia simulada a Invoice Ninja; sin importe real. |
| `PROD-DEMO-002` | Producto Simulado Pro | No local | Referencia simulada a Invoice Ninja; sin importe real. |

**Regla:** el precio no se guarda en el portal de clientes. Si se necesita para una prueba, se simula en el adaptador de prueba, nunca en la tabla comercial real.

## 6. Credenciales demo — no funcionales

| Código | Valor | Uso |
|---|---|---|
| `CRED-DEMO-001` | `DEMO_ONLY_DO_NOT_USE_0001` | Prueba de visualización de metadatos. |
| `CRED-DEMO-002` | `DEMO_ONLY_DO_NOT_USE_0002` | Prueba de rotación simulada. |

**Regla:** no son API Keys válidas. No se insertan en `public.api_clients` real ni se usan contra `https://api.origen.ar`.

## 7. Casos de prueba de aislamiento

| Caso | Datos | Resultado esperado |
|---|---|---|
| Usuario de `ORG-DEMO-001` consulta `ORG-DEMO-002` por ID directo | `USR-DEMO-001` + `ORG-DEMO-002` | `403` o `404`, nunca datos. |
| Usuario con dos membresías cambia de contexto | A definir en Etapa 5 | Permisos recalculados. |
| Organización suspendida intenta acceso | `ORG-DEMO-003` | Sin servicios activos. |
| Invitación demo expirada | Correo `...@test.example.invalid` | Rechazada. |

## 8. Estado real

No se cargaron estos datos en ninguna base. No se crearon usuarios, organizaciones, servicios ni credenciales.
