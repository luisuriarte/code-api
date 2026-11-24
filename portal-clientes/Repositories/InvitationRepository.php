<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

final class InvitationRepository
{
    public static function create(
        int $organizationId,
        string $email,
        string $roleCode,
        string $tokenHash,
        string $expiresAt,
        ?int $invitedBy
    ): int {
        $statement = CustomerDatabase::connection()->prepare(
            'INSERT INTO os_customer.invitation
                (organization_id, email, role_code, token_hash, expires_at, invited_by)
             VALUES
                (:org, :email, :role, :token, :expires_at, :invited_by)
             RETURNING id'
        );
        $statement->execute([
            ':org' => $organizationId,
            ':email' => trim($email),
            ':role' => $roleCode,
            ':token' => $tokenHash,
            ':expires_at' => $expiresAt,
            ':invited_by' => $invitedBy,
        ]);

        return (int) $statement->fetchColumn();
    }

    /** @return array<string, mixed>|null */
    public static function findPendingByHash(string $tokenHash): ?array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT i.*, o.legal_name AS organization_name
               FROM os_customer.invitation i
               JOIN os_customer.organization o ON o.id = i.organization_id
              WHERE i.token_hash = :token
                AND i.status = \'pending\'
                AND i.expires_at > now()'
        );
        $statement->execute([':token' => $tokenHash]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    /** @return list<array<string, mixed>> */
    public static function listForOrganization(int $organizationId): array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT i.id, i.email, i.role_code, i.status, i.expires_at, i.created_at,
                    u.email AS invited_by_email
               FROM os_customer.invitation i
               LEFT JOIN os_customer.app_user u ON u.id = i.invited_by
              WHERE i.organization_id = :org
              ORDER BY i.created_at DESC, i.id DESC'
        );
        $statement->execute([':org' => $organizationId]);
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    public static function markAccepted(int $id, int $userId): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.invitation
                SET status = \'accepted\', accepted_by = :user, accepted_at = now()
              WHERE id = :id AND status = \'pending\''
        );
        $statement->execute([':id' => $id, ':user' => $userId]);
    }

    public static function markExpired(int $id): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.invitation
                SET status = \'expired\'
              WHERE id = :id AND status = \'pending\''
        );
        $statement->execute([':id' => $id]);
    }
}
