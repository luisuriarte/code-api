-- Corrección de la Fase 1 — Revocar privilegios heredados del DEFAULT ACL.
-- Ejecutar SOLO si la verificación de Fase 1 devolvió filas en el apartado 8.
-- No elimina datos: solo retira privilegios concedidos automáticamente por el
-- DEFAULT ACL preexistente en public (visible en el dump como
-- "DEFAULT PRIVILEGES FOR TABLES postgres").
-- Idempotente: puede ejecutarse varias veces sin efecto adicional.
-- No modifica el DEFAULT ACL global, porque afectaría a tablas de otras fases.

BEGIN;

REVOKE ALL PRIVILEGES ON TABLE
    public.os_domain_registry,
    public.os_relation_kind,
    public.os_relation_type,
    public.os_review_state
FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE
            public.os_domain_registry,
            public.os_relation_kind,
            public.os_relation_type,
            public.os_review_state
            FROM origen_admin';
    END IF;
END $$;

COMMIT;

-- Comprobación rápida (debe devolver 0 filas):
-- SELECT table_name, grantee
-- FROM information_schema.role_table_grants
-- WHERE table_schema = 'public'
--   AND table_name IN ('os_domain_registry', 'os_relation_kind',
--                      'os_relation_type', 'os_review_state')
--   AND grantee IN ('origen_admin', 'PUBLIC');
