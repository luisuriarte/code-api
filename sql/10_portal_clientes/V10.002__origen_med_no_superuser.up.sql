-- V10.002__origen_med_no_superuser.up.sql
-- Etapa 10: corrección autorizada de privilegios del rol de conexión pública.
-- Autorizado por docs/portal-clientes/acta-autorizacion-etapa-10.md (2026-11-26).
--
-- ATENCIÓN: ALTER ROLE es una operación CLUSTER-WIDE. Afecta a todas las bases
-- de PostgreSQL del cluster, incluida la base productiva origen_codes. La
-- guarda evita ejecutarla por accidente desde otra base, pero no aísla el
-- cambio: solo debe correrse desde origen_codes_portal_clientes_test y con
-- autorización explícita, como en este caso.
--
-- No crea ni borra tablas, filas, índices, grants ni funciones. Solamente
-- retira el atributo SUPERUSER de origen_med para que los ACL por objeto
-- otorgados en V10.001 pasen a ser los únicos privilegios efectivos.

BEGIN;

DO $guard$
BEGIN
    IF current_database() NOT LIKE 'origen_codes_portal_clientes%' THEN
        RAISE EXCEPTION 'Base no permitida para V10.002: %', current_database()
            USING ERRCODE = '42501';
    END IF;

    IF to_regrole('origen_med') IS NULL THEN
        RAISE EXCEPTION 'Falta el rol origen_med; no se modifica ningún rol.'
            USING ERRCODE = '42501';
    END IF;
END
$guard$;

ALTER ROLE origen_med NOSUPERUSER;

COMMIT;
