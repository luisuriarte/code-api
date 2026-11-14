<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Config;

use InvalidArgumentException;
use PDO;
use PDOException;
use RuntimeException;
use Throwable;

/**
 * Conexión PDO centralizada a PostgreSQL 18.
 *
 * Se utiliza una única conexión por request (patrón singleton) con consultas
 * preparadas nativas, manejo de errores por excepción y timeouts defensivos.
 *
 * Ejemplo de uso:
 *   $pdo = \OrigenSalud\Api\Config\Database::connection();
 *
 * @see sql/design.sql para el esquema de base de datos.
 */
final class Database
{
    private static ?PDO $connection = null;

    /**
     * Devuelve la conexión PDO activa, creándola si es necesario.
     *
     * @throws RuntimeException si no es posible conectar o configurar la sesión.
     */
    public static function connection(): PDO
    {
        if (self::$connection instanceof PDO) {
            return self::$connection;
        }

        $host = trim((string) env('DB_HOST', '127.0.0.1'));
        $port = self::integerEnv('DB_PORT', 5432, 1, 65535);
        $database = trim((string) env('DB_NAME', 'origen_salud'));
        $user = (string) env('DB_USER', 'origen_api');
        $password = (string) env('DB_PASSWORD', '');
        $connectTimeout = self::integerEnv('DB_CONNECT_TIMEOUT', 5, 1, 30);

        $sslModes = ['disable', 'allow', 'prefer', 'require', 'verify-ca', 'verify-full'];
        $sslMode = strtolower(trim((string) env('DB_SSLMODE', 'prefer')));

        if (!in_array($sslMode, $sslModes, true)) {
            throw new InvalidArgumentException(
                'DB_SSLMODE inválido. Valores permitidos: ' . implode(', ', $sslModes) . '.'
            );
        }

        /*
         * El host puede ser un socket Unix (ej. /var/run/postgresql), un nombre
         * DNS o una dirección IPv6. Solo se rechazan caracteres que permitirían
         * inyectar parámetros adicionales en el DSN.
         */
        if ($host === '' || str_contains($host, ';')) {
            throw new InvalidArgumentException('DB_HOST inválido.');
        }

        if (preg_match('/^[A-Za-z0-9_.-]+$/', $database) !== 1) {
            throw new InvalidArgumentException('DB_NAME contiene caracteres no permitidos.');
        }

        $dsn = sprintf(
            'pgsql:host=%s;port=%d;dbname=%s;connect_timeout=%d;sslmode=%s',
            $host,
            $port,
            $database,
            $connectTimeout,
            $sslMode
        );

        try {
            $pdo = new PDO($dsn, $user, $password, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                // Preparaciones nativas en el servidor: evita interpolación local
                // y permite que PostgreSQL reutilice el plan de ejecución.
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::ATTR_STRINGIFY_FETCHES => false,
                PDO::ATTR_PERSISTENT => false,
            ]);
        } catch (PDOException $exception) {
            // El detalle se conserva como "previous" para el log interno,
            // pero nunca debe exponerse al cliente de la API.
            throw new RuntimeException('No fue posible conectar con PostgreSQL.', 0, $exception);
        }

        self::configureSession($pdo);

        return self::$connection = $pdo;
    }

    /**
     * Ejecuta un bloque de trabajo dentro de una transacción.
     *
     * Si el callback lanza una excepción se hace rollback y la excepción se
     * propaga sin alterar su tipo original. Útil para operaciones de escritura
     * o para lecturas que deben ver una foto consistente de varias tablas.
     *
     * @template T
     *
     * @param callable(PDO): T $callback
     *
     * @return T
     */
    public static function transaction(callable $callback): mixed
    {
        $pdo = self::connection();

        if ($pdo->inTransaction()) {
            // Las transacciones anidadas se resuelven con SAVEPOINT.
            $savepoint = 'sp_' . bin2hex(random_bytes(6));
            $pdo->exec('SAVEPOINT ' . $savepoint);

            try {
                $result = $callback($pdo);
                $pdo->exec('RELEASE SAVEPOINT ' . $savepoint);

                return $result;
            } catch (Throwable $exception) {
                $pdo->exec('ROLLBACK TO SAVEPOINT ' . $savepoint);
                throw $exception;
            }
        }

        $pdo->beginTransaction();

        try {
            $result = $callback($pdo);
            $pdo->commit();

            return $result;
        } catch (Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }

            throw $exception;
        }
    }

    /**
     * Descarta la conexión actual. Útil en tests o procesos de larga duración.
     */
    public static function disconnect(): void
    {
        self::$connection = null;
    }

    /**
     * Aplica configuración defensiva a la sesión de PostgreSQL.
     */
    private static function configureSession(PDO $pdo): void
    {
        $applicationName = mb_substr(trim((string) env('APP_NAME', 'Origen Salud')), 0, 63, 'UTF-8');
        $statementTimeout = self::integerEnv('DB_STATEMENT_TIMEOUT_MS', 5000, 100, 60000);

        $trgmThreshold = (float) env('DB_TRGM_THRESHOLD', 0.25);
        $trgmThreshold = max(0.05, min(0.95, $trgmThreshold));

        try {
            // Toda la plataforma trabaja en UTC y traduce en la capa de presentación.
            $pdo->exec("SET TIME ZONE 'UTC'");
            $pdo->exec('SET application_name = ' . $pdo->quote($applicationName));
            $pdo->exec('SET statement_timeout = ' . $statementTimeout);

            // Umbral usado por el operador de similitud (%) de pg_trgm.
            $pdo->exec(
                'SET pg_trgm.similarity_threshold = ' . number_format($trgmThreshold, 3, '.', '')
            );
        } catch (PDOException $exception) {
            throw new RuntimeException(
                'No fue posible configurar la sesión de PostgreSQL.',
                0,
                $exception
            );
        }
    }

    private static function integerEnv(string $key, int $default, int $min, int $max): int
    {
        $value = filter_var(env($key, $default), FILTER_VALIDATE_INT);

        if ($value === false) {
            return $default;
        }

        return max($min, min($max, (int) $value));
    }
}
