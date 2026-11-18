<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use OrigenSalud\Portal\Config;
use PDO;
use PDOException;

/**
 * Conexión de solo lectura del portal a PostgreSQL.
 *
 * Usa el rol origen_med creado por el administrador. Todas las consultas son
 * parametrizadas y se ejecutan con un statement_timeout corto. Los errores de
 * PDO nunca se exponen al navegador: se traducen a un código estable.
 */
final class PortalDatabase
{
    private static ?PDO $pdo = null;

    public static function available(): bool
    {
        $config = Config::database();

        return $config['dsn'] !== '' && $config['pass'] !== '';
    }

    /** @throws RepositoryException */
    public static function connection(): PDO
    {
        if (self::$pdo instanceof PDO) {
            return self::$pdo;
        }

        $config = Config::database();

        if ($config['dsn'] === '' || $config['user'] === '') {
            throw new RepositoryException('database_not_configured');
        }

        try {
            $pdo = new PDO($config['dsn'], $config['user'], $config['pass'], [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::ATTR_PERSISTENT => false,
            ]);

            // PostgreSQL no permite parámetros ligados dentro de SET; set_config()
            // sí acepta el valor como texto y mantiene la consulta parametrizada.
            $statement = $pdo->prepare("SELECT set_config('statement_timeout', :timeout, false)");
            $statement->execute([':timeout' => (max(1, $config['timeout']) * 1000) . 'ms']);
        } catch (PDOException) {
            throw new RepositoryException('database_unavailable');
        }

        return self::$pdo = $pdo;
    }

    /** @throws RepositoryException */
    public static function reset(): void
    {
        self::$pdo = null;
    }
}
