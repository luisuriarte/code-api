<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

use OrigenSalud\CustomerPortal\Repositories\ApiCredentialRepository;
use OrigenSalud\CustomerPortal\Repositories\AuditRepository;
use PDOException;
use Throwable;

/**
 * Etapa 8: self-service de credenciales de /v1 con la Opción A del acta.
 *
 * La clave se genera en el servidor, se escribe en public.api_clients mediante
 * una única conexión operativa y se devuelve una sola vez al creador. Nunca se
 * guarda en metadatos, logs, URLs ni sesión. La API sigue sin hash, scopes,
 * expiración, último uso ni medición: no se ofrecen esas capacidades.
 */
final class ApiCredentialService
{
    /** 32 bytes => 64 caracteres hexadecimales; cabe en api_key VARCHAR(64). */
    private const KEY_BYTES = 32;

    public static function available(): bool
    {
        return CredentialDatabase::available();
    }

    /** @return list<array<string, mixed>> */
    public static function list(int $organizationId): array
    {
        return ApiCredentialRepository::findByOrganization($organizationId);
    }

    /**
     * @return array{ok: bool, id?: int, secret?: string, error?: string}
     */
    public static function create(
        int $organizationId,
        int $userId,
        string $institutionName
    ): array {
        $name = trim($institutionName);

        if (!self::available()) {
            self::audit($userId, $organizationId, 'credential.created', null, 'failure');

            return self::error('customer.credential.unavailable');
        }

        if ($name === '' || mb_strlen($name) > 150) {
            self::audit($userId, $organizationId, 'credential.created', null, 'failure');

            return self::error('customer.credential.invalid');
        }

        $secret = bin2hex(random_bytes(self::KEY_BYTES));

        try {
            $statement = CredentialDatabase::connection()->prepare(
                'INSERT INTO public.api_clients (institution_name, api_key, is_active)
                 VALUES (:institution_name, :api_key, TRUE)
                 RETURNING id'
            );
            $statement->execute([
                ':institution_name' => $name,
                ':api_key' => $secret,
            ]);
            $apiClientId = (int) $statement->fetchColumn();
        } catch (PDOException | CustomerRepositoryException) {
            self::audit($userId, $organizationId, 'credential.created', null, 'failure');

            return self::error('customer.credential.unavailable');
        }

        if ($apiClientId <= 0) {
            self::deactivate($apiClientId);
            self::audit($userId, $organizationId, 'credential.created', null, 'failure');

            return self::error('customer.credential.failed');
        }

        try {
            $id = ApiCredentialRepository::insert($organizationId, $apiClientId, $name, $userId);
        } catch (Throwable) {
            // El metadato no pudo escribirse: se compensa inactivando el
            // cliente recién creado para no dejar una credencial huérfana.
            self::deactivate($apiClientId);
            self::audit($userId, $organizationId, 'credential.created', null, 'failure');

            return self::error('customer.credential.failed');
        }

        self::audit(
            $userId,
            $organizationId,
            'credential.created',
            (string) $id,
            'success',
            ['api_client_id' => $apiClientId]
        );

        return ['ok' => true, 'id' => $id, 'secret' => $secret];
    }

    /**
     * @return array{ok: bool, id?: int, secret?: string, error?: string}
     */
    public static function rotate(int $id, int $organizationId, int $userId): array
    {
        $credential = ApiCredentialRepository::findOwned($id, $organizationId);

        if ($credential === null || ($credential['status'] ?? '') !== 'active') {
            self::audit($userId, $organizationId, 'credential.rotated', null, 'denied');

            return self::error('customer.credential.invalid');
        }

        if (!self::available()) {
            self::audit($userId, $organizationId, 'credential.rotated', (string) $id, 'failure');

            return self::error('customer.credential.unavailable');
        }

        $apiClientId = (int) $credential['api_client_id'];
        $secret = bin2hex(random_bytes(self::KEY_BYTES));

        try {
            $statement = CredentialDatabase::connection()->prepare(
                'UPDATE public.api_clients
                    SET api_key = :api_key
                  WHERE id = :id AND is_active = TRUE'
            );
            $statement->execute([
                ':api_key' => $secret,
                ':id' => $apiClientId,
            ]);
            $affected = $statement->rowCount();
        } catch (PDOException | CustomerRepositoryException) {
            self::audit($userId, $organizationId, 'credential.rotated', (string) $id, 'failure');

            return self::error('customer.credential.unavailable');
        }

        if ($affected !== 1) {
            self::audit($userId, $organizationId, 'credential.rotated', (string) $id, 'denied');

            return self::error('customer.credential.invalid');
        }

        ApiCredentialRepository::markRotated($id, $userId);
        self::audit(
            $userId,
            $organizationId,
            'credential.rotated',
            (string) $id,
            'success',
            ['api_client_id' => $apiClientId]
        );

        return ['ok' => true, 'id' => $id, 'secret' => $secret];
    }

    /**
     * @return array{ok: bool, id?: int, error?: string}
     */
    public static function revoke(int $id, int $organizationId, int $userId): array
    {
        $credential = ApiCredentialRepository::findOwned($id, $organizationId);

        if ($credential === null || ($credential['status'] ?? '') !== 'active') {
            self::audit($userId, $organizationId, 'credential.revoked', null, 'denied');

            return self::error('customer.credential.invalid');
        }

        if (!self::available()) {
            self::audit($userId, $organizationId, 'credential.revoked', (string) $id, 'failure');

            return self::error('customer.credential.unavailable');
        }

        $apiClientId = (int) $credential['api_client_id'];

        try {
            $statement = CredentialDatabase::connection()->prepare(
                'UPDATE public.api_clients
                    SET is_active = FALSE
                  WHERE id = :id AND is_active = TRUE'
            );
            $statement->execute([':id' => $apiClientId]);
        } catch (PDOException | CustomerRepositoryException) {
            self::audit($userId, $organizationId, 'credential.revoked', (string) $id, 'failure');

            return self::error('customer.credential.unavailable');
        }

        ApiCredentialRepository::markRevoked($id, $userId);
        self::audit(
            $userId,
            $organizationId,
            'credential.revoked',
            (string) $id,
            'success',
            ['api_client_id' => $apiClientId]
        );

        return ['ok' => true, 'id' => $id];
    }

    /** @param array<string, int> $context Solo identificadores; nunca la clave. */
    private static function audit(
        int $userId,
        int $organizationId,
        string $action,
        ?string $objectId,
        string $result,
        array $context = []
    ): void {
        try {
            AuditRepository::record($userId, $organizationId, $action, 'api_credential', $objectId, $result, $context);
        } catch (Throwable) {
            // La auditoría no debe convertir una operación válida en un 500;
            // el fallo queda registrado por el motor de base cuando corresponde.
        }
    }

    private static function deactivate(int $apiClientId): void
    {
        if ($apiClientId <= 0) {
            return;
        }

        try {
            $statement = CredentialDatabase::connection()->prepare(
                'UPDATE public.api_clients SET is_active = FALSE WHERE id = :id'
            );
            $statement->execute([':id' => $apiClientId]);
        } catch (Throwable) {
            // Compensación mejor esfuerzo; nunca se registra la clave.
        }
    }

    /** @return array{ok: false, error: string} */
    private static function error(string $key): array
    {
        return ['ok' => false, 'error' => $key];
    }
}
