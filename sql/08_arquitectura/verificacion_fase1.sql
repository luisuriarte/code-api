-- Verificación de la Fase 1 del §16 — SOLO LECTURA.
-- Ejecutar en psql contra origen_codes:
--   psql -d origen_codes -f sql/08_arquitectura/verificacion_fase1.sql
-- Envuelve la sesión en READ ONLY y hace ROLLBACK: no puede escribir.

BEGIN READ ONLY;

SELECT current_database() AS base, current_user AS usuario;

-- 1. Tablas de referencia creadas (deben aparecer las cuatro).
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
      'os_domain_registry', 'os_relation_kind', 'os_relation_type', 'os_review_state'
  )
ORDER BY table_name;

-- 2. Dominios sembrados: 12 filas, con las etiquetas y modos de DOMAIN_CATALOG.
SELECT code, label_es, label_en, mode, is_active, source_of_truth
FROM public.os_domain_registry
ORDER BY code;

-- 3. Deben ser 3 dominios 'full' y 9 'catalog'.
SELECT mode, count(*) AS cantidad
FROM public.os_domain_registry
GROUP BY mode
ORDER BY mode;

-- 4. Clasificaciones de relación (deben ser 7).
SELECT code, is_active FROM public.os_relation_kind ORDER BY code;

-- 5. Estados de revisión: solo 'approved' y 'published' permiten publicar.
SELECT code, is_publication_allowed
FROM public.os_review_state
ORDER BY code;

-- 6. Tipos de relación derivados de la tabla real (deben ser 15).
SELECT count(*) AS relation_types FROM public.os_relation_type;

-- 7. Invariante: 603 relaciones (333 CDT + 270 de la Fase 9) y 15 tipos.
SELECT count(*) AS relaciones, count(DISTINCT relation_type) AS tipos
FROM public.os_catalog_relation;

-- 8. origen_admin no debe tener privilegios sobre las tablas nuevas (0 filas).
-- El DEFAULT ACL de public puede concederlos automáticamente; en ese caso,
-- ejecutar fase1_correcion_privilegios.sql y repetir esta verificación.
SELECT table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE grantee = 'origen_admin'
  AND table_schema = 'public'
  AND table_name IN (
      'os_domain_registry', 'os_relation_kind', 'os_relation_type', 'os_review_state'
  )
GROUP BY table_name
ORDER BY table_name;

-- 8b. Inventario completo: solo debe aparecer el propietario de las tablas.
SELECT table_name, grantee,
       string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN (
      'os_domain_registry', 'os_relation_kind', 'os_relation_type', 'os_review_state'
  )
GROUP BY table_name, grantee
ORDER BY table_name, grantee;

ROLLBACK;
