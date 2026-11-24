# Backup y rollback — Etapa 4

> **Estado:** procedimiento documentado. **No ejecutado.**
> **Aplica solo a entorno de prueba o base independiente autorizada.**

## 1. Reglas

1. Ninguna migración futura se aplica sin backup previo.
2. El backup se guarda fuera del repositorio y nunca se commitea.
3. El dump no contiene secretos en claro; si los contiene, se cifra o se guarda con permisos restringidos.
4. El rollback se ensaya primero en entorno de prueba.
5. Producción requiere autorización explícita adicional.
6. La auditoría append-only no se revierte mediante borrado.

## 2. Identificación previa

El responsable debe ejecutar, solo lectura:

```bash
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 -c \
"SELECT current_database(), current_user, version();"
```

Si la base de prueba aún no existe, **no crearla en esta etapa** sin decisión separada.

## 3. Backup lógico propuesto

Para ejecutar por el responsable, nunca por el asistente:

```bash
sudo -u postgres pg_dump -Fc \
  -d origen_codes_portal_clientes_test \
  -f /opt/origen-salud-data/backups/origen_codes_portal_clientes_test_YYYYMMDD_HHMMSS.dump
```

Verificación del dump:

```bash
sudo -u postgres pg_restore -l \
  /opt/origen-salud-data/backups/origen_codes_portal_clientes_test_YYYYMMDD_HHMMSS.dump \
  | head -20
```

Registrar en el acta de ejecución:

- fecha;
- base;
- ruta del dump;
- tamaño;
- hash SHA-256;
- actor que lo ejecutó.

No pegar el dump ni su contenido en el repositorio.

## 4. Restore de prueba

Solo en base independiente, nunca sobre producción:

```bash
sudo -u postgres createdb origen_codes_portal_clientes_restore_test
sudo -u postgres pg_restore -Fc \
  -d origen_codes_portal_clientes_restore_test \
  /opt/origen-salud-data/backups/origen_codes_portal_clientes_test_YYYYMMDD_HHMMSS.dump
```

Comprobación de solo lectura posterior:

```bash
sudo -u postgres psql -d origen_codes_portal_clientes_restore_test -v ON_ERROR_STOP=1 -c \
"SELECT current_database(), count(*) FROM pg_class WHERE relkind = 'r';"
```

Si la restauración falla, no avanzar a la Etapa 5.

## 5. Rollback de una migración futura

1. Detener escrituras de la aplicación de prueba.
2. Identificar la última migración aplicada y su archivo `down`.
3. Verificar que el `down` corresponde al `up` por número y hash.
4. Ejecutar el `down` en la misma base.
5. Verificar con `SELECT`-only.
6. Registrar resultado.
7. Si el `down` falla, usar el restore de prueba y documentar.

**No usar** `TRUNCATE`, `DROP SCHEMA CASCADE` ni borrado de auditoría como rollback genérico.

## 6. Criterios de decisión

| Situación | Acción |
|---|---|
| Backup no verificado | No aplicar migración. |
| Restore de prueba fallido | No avanzar. |
| Migración `up` falla en prueba | Ejecutar `down` si aplica; documentar. |
| Verificación posterior falla | Rollback y revisión. |
| Error en producción | Fuera de esta etapa; requiere autorización de incidente. |

## 7. Estado

No se ejecutaron `pg_dump`, `createdb`, `pg_restore`, migraciones ni restauraciones. Solo se documentó el procedimiento.
