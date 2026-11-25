<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

/**
 * Metadatos de credenciales en os_customer.api_credential.
 *
 * Nunca escribe la clave API: esta vive solo en la respuesta de
 * creación/rotación y en public.api_clients a través de CredentialDatabase.
 */
final class ApiCredentialRepository
{
    /** @return list<array<string, mixed>> */
    public static function findByOrganization(int $organizationId): array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT id, api_client_id, institution_name, environment, status,
                    created_at, rotated_at, revoked_at
               FROM os_customer.api_credential
              WHERE organization_id = :organization_id
              ORDER BY id DESC'
        );
        $statement->execute([':organization_id' => $organizationId]);
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    /** @return array<string, mixed>|null */
    public static function findOwned(int $id, int $organizationId): ?array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT id, organization_id, api_client_id, institution_name, environment,
                    status, created_at, rotated_at, revoked_at
               FROM os_customer.api_credential
              WHERE id = :id AND organization_id = :organization_id'
        );
        $statement->execute([
            ':id' => $id,
            ':organization_id' => $organizationId,
        ]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    public static function insert(
        int $organizationId,
        int $apiClientId,
        string $institutionName,
        int $createdByUserId
    ): int {
        $statement = CustomerDatabase::connection()->prepare(
            'INSERT INTO os_customer.api_credential
                (organization_id, api_client_id, institution_name, created_by_user_id)
             VALUES
                (:organization_id, :api_client_id, :institution_name, :created_by_user_id)
             RETURNING id'
        );
        $statement->execute([
            ':organization_id' => $organizationId,
            ':api_client_id' => $apiClientId,
            ':institution_name' => $institutionName,
            ':created_by_user_id' => $createdByUserId,
        ]);

        return (int) $statement->fetchColumn();
    }

    public static function markRotated(int $id, int $userId): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.api_credential
                SET rotated_by_user_id = :user_id, rotated_at = now()
              WHERE id = :id AND status = \'active\''
        );
        $statement->execute([
            ':id' => $id,
            ':user_id' => $userId,
        ]);
    }

    public static function markRevoked(int $id, int $userId): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.api_credential
                SET status = \'revoked\', revoked_by_user_id = :user_id, revoked_at = now()
              WHERE id = :id AND status = \'active\''
        );
        $statement->execute([
            ':id' => $id,
            ':user_id' => $userId,
        ]);
    }
}
