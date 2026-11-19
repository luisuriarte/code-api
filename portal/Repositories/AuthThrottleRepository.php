<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use PDO;
use PDOException;

/**
 * Aceleración de intentos de login por clave hash(email|IP).
 *
 * Bloquea por ventana y persiste en base, a diferencia del RateLimiter de
 * sesión: un atacante no puede evadirlo abriendo nuevas sesiones.
 */
final class AuthThrottleRepository
{
    public static function checkAndHit(string $keyHash, int $limit, int $windowSeconds): bool
    {
        $pdo = AdminDatabase::connection();
        $limit = max(1, $limit);
        $window = max(1, $windowSeconds);
        $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));

        try {
            $pdo->beginTransaction();

            $statement = $pdo->prepare(
                'SELECT attempts, window_started_at, blocked_until
                   FROM os_admin.auth_throttle WHERE key_hash = :key FOR UPDATE'
            );
            $statement->execute([':key' => $keyHash]);
            $row = $statement->fetch();

            if ($row === false) {
                $insert = $pdo->prepare(
                    'INSERT INTO os_admin.auth_throttle (key_hash, attempts, window_started_at)
                     VALUES (:key, 1, :now)'
                );
                $insert->execute([':key' => $keyHash, ':now' => $now->format(DateTimeInterface::ATOM)]);
                $pdo->commit();

                return true;
            }

            $blockedUntil = $row['blocked_until'] === null
                ? null
                : new DateTimeImmutable((string) $row['blocked_until']);

            if ($blockedUntil !== null && $blockedUntil > $now) {
                $pdo->commit();

                return false;
            }

            $windowStart = new DateTimeImmutable((string) $row['window_started_at']);
            $attempts = (int) $row['attempts'];

            if ($windowStart < $now->modify('-' . $window . ' seconds')) {
                $attempts = 0;
                $windowStart = $now;
            }

            $allowed = $attempts < $limit;
            $attempts++;
            $blocked = $allowed
                ? null
                : $now->modify('+' . $window . ' seconds');

            $update = $pdo->prepare(
                'UPDATE os_admin.auth_throttle
                    SET attempts = :attempts, window_started_at = :window,
                        blocked_until = :blocked
                  WHERE key_hash = :key'
            );
            $update->execute([
                ':attempts' => $attempts,
                ':window' => $windowStart->format(DateTimeInterface::ATOM),
                ':blocked' => $blocked?->format(DateTimeInterface::ATOM),
                ':key' => $keyHash,
            ]);

            $pdo->commit();

            return $allowed;
        } catch (PDOException) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }

            throw new RepositoryException('admin_database_unavailable');
        }
    }
}
