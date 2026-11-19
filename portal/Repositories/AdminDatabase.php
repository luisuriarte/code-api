<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use OrigenSalud\Portal\Config;
use PDO;
use PDOException;

/**
 * Conexión acotada al esquema os_admin (M1).
 *
 * Es independiente de la conexión pública de solo lectura: el rol origen_admin
 * no tiene privilegios sobre os_catalog_* ni sobre la API pública. Los errores
 * de PDO se traducen a códigos estables y nunca llegan al navegador.
 */
final class AdminDatabase
{
    private static ?PDO $pdo = null;

    public static function available(): bool
    {
        $config = Config::adminDatabase();

        return $config['dsn'] !== '' && $config['user'] !== '' && $config['pass'] !== '';
    }

    /** @throws RepositoryException */
    public static function connection(): PDO
    {
        if (self::$pdo instanceof PDO) {
            return self::$pdo;
        }

        $config = Config::adminDatabase();

        if ($config['dsn'] === '' || $config['user'] === '' || $config['pass'] === '') {
            throw new RepositoryException('admin_database_not_configured');
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
            throw new RepositoryException('admin_database_unavailable');
        }

        return self::$pdo = $pdo;
    }

    public static function reset(): void
    {
        self::$pdo = null;
    }
}
