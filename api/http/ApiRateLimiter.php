<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Http;

/**
 * Limitador de solicitudes por cliente e IP de servidor.
 *
 * Usa una ventana fija de un segundo y archivos bloqueados con flock(), sin
 * dependencias nuevas. El sujeto se deriva del id de cliente autenticado y de
 * REMOTE_ADDR (nunca de X-Forwarded-For, que el cliente puede falsificar).
 *
 * Si el directorio de estado no se puede crear o escribir, el limitador falla
 * abierto y registra el evento: un problema de permisos del VPS no debe dejar
 * la API completamente caída. `rate_limit_per_second = 0` sí deniega siempre.
 */
final class ApiRateLimiter
{
    /**
     * @return array{allowed: bool, limit: int, remaining: int, retry_after: int}
     */
    public static function hit(int $clientId, int $perSecond): array
    {
        $limit = max(0, $perSecond);
        $now = time();
        $ip = (string) ($_SERVER['REMOTE_ADDR'] ?? '');
        $subject = hash('sha256', $clientId . "\0" . $ip);

        if ($limit === 0) {
            return ['allowed' => false, 'limit' => 0, 'remaining' => 0, 'retry_after' => 1];
        }

        $base = defined('BASE_PATH') ? (string) BASE_PATH : dirname(__DIR__, 2);
        $directory = $base . '/var/api-rate';

        if (!is_dir($directory) && !@mkdir($directory, 0770, true) && !is_dir($directory)) {
            error_log('api rate limiter: no se pudo crear el directorio de estado');

            return self::degraded($limit);
        }

        $file = $directory . '/' . $subject . '.json';
        $handle = @fopen($file, 'c+');

        if ($handle === false) {
            error_log('api rate limiter: no se pudo abrir el estado');

            return self::degraded($limit);
        }

        try {
            if (!flock($handle, LOCK_EX)) {
                error_log('api rate limiter: no se pudo bloquear el estado');

                return self::degraded($limit);
            }

            $raw = stream_get_contents($handle);
            $state = is_string($raw) ? json_decode($raw, true) : null;
            $window = is_array($state) && (int) ($state['window'] ?? 0) === $now
                ? (int) ($state['count'] ?? 0)
                : 0;

            $allowed = $window < $limit;
            $count = $allowed ? $window + 1 : $window;

            rewind($handle);
            ftruncate($handle, 0);
            fwrite($handle, json_encode(['window' => $now, 'count' => $count], JSON_THROW_ON_ERROR));
            fflush($handle);
            flock($handle, LOCK_UN);

            return [
                'allowed' => $allowed,
                'limit' => $limit,
                'remaining' => max(0, $limit - $count),
                'retry_after' => 1,
            ];
        } finally {
            fclose($handle);
        }
    }

    /** @return array{allowed: bool, limit: int, remaining: int, retry_after: int} */
    private static function degraded(int $limit): array
    {
        return ['allowed' => true, 'limit' => $limit, 'remaining' => $limit, 'retry_after' => 1];
    }
}
