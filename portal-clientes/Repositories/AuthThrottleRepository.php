<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

final class AuthThrottleRepository
{
    /**
     * Registra un intento y devuelve el estado de la ventana.
     *
     * @return array{attempts: int, blocked_until: string|null, blocked: bool}
     */
    public static function hit(
        string $bucket,
        string $subjectHash,
        int $windowSeconds,
        int $limit,
        int $blockMinutes
    ): array {
        $window = max(60, $windowSeconds);
        $windowStart = gmdate('Y-m-d H:i:s', ((int) floor(time() / $window)) * $window) . '+00';

        $pdo = CustomerDatabase::connection();

        $statement = $pdo->prepare(
            'INSERT INTO os_customer.auth_throttle
                (bucket, subject_hash, attempts, window_started_at)
             VALUES
                (:bucket, :subject, 1, :window_start::timestamptz)
             ON CONFLICT (bucket, subject_hash, window_started_at) DO UPDATE
                SET attempts = os_customer.auth_throttle.attempts + 1,
                    updated_at = now()
             RETURNING attempts, blocked_until'
        );
        $statement->execute([
            ':bucket' => $bucket,
            ':subject' => $subjectHash,
            ':window_start' => $windowStart,
        ]);
        $row = $statement->fetch();
        $attempts = is_array($row) ? (int) ($row['attempts'] ?? 0) : 0;
        $blockedUntil = is_array($row) && is_string($row['blocked_until'] ?? null)
            ? (string) $row['blocked_until']
            : null;

        if ($attempts >= max(1, $limit) && $blockedUntil === null) {
            $update = $pdo->prepare(
                'UPDATE os_customer.auth_throttle
                    SET blocked_until = now() + (:minutes::int * interval \'1 minute\'),
                        updated_at = now()
                  WHERE bucket = :bucket
                    AND subject_hash = :subject
                    AND window_started_at = :window_start::timestamptz
                    AND blocked_until IS NULL'
            );
            $update->execute([
                ':minutes' => max(1, $blockMinutes),
                ':bucket' => $bucket,
                ':subject' => $subjectHash,
                ':window_start' => $windowStart,
            ]);

            $blockedUntil = date('Y-m-d H:i:sP', time() + max(1, $blockMinutes) * 60);
        }

        return [
            'attempts' => $attempts,
            'blocked_until' => $blockedUntil,
            'blocked' => $blockedUntil !== null,
        ];
    }

    public static function clear(string $bucket, string $subjectHash): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'DELETE FROM os_customer.auth_throttle
              WHERE bucket = :bucket AND subject_hash = :subject'
        );
        $statement->execute([':bucket' => $bucket, ':subject' => $subjectHash]);
    }
}
