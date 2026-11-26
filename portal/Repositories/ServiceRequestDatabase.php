<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use OrigenSalud\Portal\Config;
use PDO;
use PDOException;

/**
 * Conexión de escritura de la Solicitud de Servicios (Etapa 10).
 *
 * Es independiente de `PortalDatabase`: el sitio público lee desde
 * `PORTAL_DB_DSN` y la solicitud se registra en la base aislada indicada por
 * `SERVICE_REQUEST_DB_DSN`. Nunca expone detalles de PDO al navegador.
 */
final class ServiceRequestDatabase
{
    private static ?PDO $pdo = null;

    public static function available(): bool
    {
        $config = Config::serviceRequestDatabase();

        return $config['dsn'] !== '' && $config['user'] !== '' && $config['pass'] !== '';
    }

    /** @throws RepositoryException */
    public static function connection(): PDO
    {
        if (self::$pdo instanceof PDO) {
            return self::$pdo;
        }

        $config = Config::serviceRequestDatabase();

        if ($config['dsn'] === '' || $config['user'] === '' || $config['pass'] === '') {
            throw new RepositoryException('database_not_configured');
        }

        try {
            $pdo = new PDO($config['dsn'], $config['user'], $config['pass'], [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::ATTR_PERSISTENT => false,
            ]);

            $statement = $pdo->prepare("SELECT set_config('statement_timeout', :timeout, false)");
            $statement->execute([':timeout' => (max(1, $config['timeout']) * 1000) . 'ms']);
        } catch (PDOException) {
            throw new RepositoryException('database_unavailable');
        }

        return self::$pdo = $pdo;
    }

    public static function reset(): void
    {
        self::$pdo = null;
    }
}
