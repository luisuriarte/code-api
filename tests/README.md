# Tests

Tests básicos sin framework ni base de datos.

```bash
php tests/run.php
```

Cubren:

- existencia y comportamiento de `ApiException::internalError()` y las siete
  ramas degradadas de `TerminologySearchService`;
- validez del YAML de `docs/api/openapi-3.1.yaml` y resolución de todos sus
  `$ref`;
- invariantes de los artefactos SQL propuestos (transaccionales, sin
  `DROP TABLE`/`DROP COLUMN`/`TRUNCATE`/`DELETE FROM`, sin valores UVR cargados);
- cobertura de los 15 tipos reales de relación CDT en las cuatro locales;
- integración de `os_catalog_relation` en `CatalogRepository::itemRelations()`;
- alineación de READMEs con los recuentos reales y el estado de FHIR;
- navegación: el enlace roto `/cart` apunta a `#plataforma` y `web/sitemap.php`
  genera XML válido solo con rutas reales (sin `/cart`, AN/CL ni catálogos
  reservados).

No requieren `psql`, `.env` ni migraciones. Para verificar la base real,
ejecutar las consultas sugeridas al final de cada artefacto SQL en `origen_codes`.
