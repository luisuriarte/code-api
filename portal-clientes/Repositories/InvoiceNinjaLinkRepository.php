<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

/** Persistencia de vínculos y revisiones. Solo identificadores y metadatos técnicos. */
final class InvoiceNinjaLinkRepository
{
    /** @return array<string, mixed>|null */
    public static function findLink(int $organizationId): ?array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT * FROM os_customer.invoice_ninja_client_link
              WHERE organization_id = :org'
        );
        $statement->execute([':org' => $organizationId]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    /** @return array<string, mixed>|null */
    public static function createLink(
        int $organizationId,
        string $clientId,
        string $matchedBy,
        string $confidence,
        ?int $actorUserId
    ): ?array {
        $statement = CustomerDatabase::connection()->prepare(
            'INSERT INTO os_customer.invoice_ninja_client_link
                (organization_id, invoice_ninja_client_id, status, matched_by,
                 match_confidence, created_by, reviewed_by, reviewed_at)
             VALUES
                (:org, :client, \'active\', :matched_by, :confidence, :actor, NULL, NULL)
             ON CONFLICT (organization_id) DO NOTHING
             RETURNING *'
        );
        $statement->execute([
            ':org' => $organizationId,
            ':client' => $clientId,
            ':matched_by' => $matchedBy,
            ':confidence' => $confidence,
            ':actor' => $actorUserId,
        ]);
        $row = $statement->fetch();

        return is_array($row) ? $row : self::findLink($organizationId);
    }

    public static function deactivateLink(int $linkId, ?int $actorUserId): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.invoice_ninja_client_link
                SET status = \'inactive\', reviewed_by = :actor, reviewed_at = now()
              WHERE id = :id'
        );
        $statement->execute([':id' => $linkId, ':actor' => $actorUserId]);
    }

    /** @return array<string, mixed>|null */
    public static function createReview(
        int $organizationId,
        ?string $candidateClientId,
        ?string $candidateContactId,
        string $matchReason,
        ?int $actorUserId
    ): ?array {
        $statement = CustomerDatabase::connection()->prepare(
            'INSERT INTO os_customer.invoice_ninja_duplicate_review
                (organization_id, candidate_client_id, candidate_contact_id,
                 match_reason, status, requested_by)
             VALUES
                (:org, :client, :contact, :reason, \'pending\', :actor)
             RETURNING *'
        );
        $statement->execute([
            ':org' => $organizationId,
            ':client' => $candidateClientId,
            ':contact' => $candidateContactId,
            ':reason' => $matchReason,
            ':actor' => $actorUserId,
        ]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    /** @return list<array<string, mixed>> */
    public static function pendingReviews(int $organizationId): array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT * FROM os_customer.invoice_ninja_duplicate_review
              WHERE organization_id = :org AND status = \'pending\'
              ORDER BY id DESC'
        );
        $statement->execute([':org' => $organizationId]);
        $rows = $statement->fetchAll();

        return is_array($rows) ? $rows : [];
    }

    /** @return array<string, mixed>|null */
    public static function resolveReview(
        int $reviewId,
        string $status,
        ?int $reviewerUserId,
        ?string $note
    ): ?array {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.invoice_ninja_duplicate_review
                SET status = :status,
                    reviewed_by = :reviewer,
                    reviewed_at = now(),
                    resolution_note = :note
              WHERE id = :id AND status = \'pending\'
             RETURNING *'
        );
        $statement->execute([
            ':id' => $reviewId,
            ':status' => $status,
            ':reviewer' => $reviewerUserId,
            ':note' => $note,
        ]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }
}
