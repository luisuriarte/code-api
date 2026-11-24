-- V7.001__services_entitlements.down.sql
-- Reversión de la Etapa 7. Conserva las tablas de V5 y V6, incluida audit_log.
-- Autorizado por docs/portal-clientes/acta-autorizacion-etapa-7.md.
-- SOLO entorno de prueba/base independiente. NO ejecutar en producción.

BEGIN;

DELETE FROM os_customer.role_permission
WHERE permission_id IN (
    SELECT id FROM os_customer.permission
    WHERE code IN ('service.request','service.activate','service.suspend','service.revoke')
);

DELETE FROM os_customer.role
WHERE code = 'origen_superadmin';

DELETE FROM os_customer.permission
WHERE code IN ('service.request','service.activate','service.suspend','service.revoke');

DROP TABLE IF EXISTS os_customer.operator;
DROP TABLE IF EXISTS os_customer.entitlement;
DROP TABLE IF EXISTS os_customer.contract;
DROP TABLE IF EXISTS os_customer.service_request_item;
DROP TABLE IF EXISTS os_customer.service_request;
DROP TABLE IF EXISTS os_customer.service_item;
DROP TABLE IF EXISTS os_customer.service;

COMMIT;
