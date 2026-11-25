<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

use OrigenSalud\CustomerPortal\Config;
use PDO;
use PDOException;

/**
 * Conexión operativa de servidor para la Etapa 8 (Opción A).
 *
 * Es privada, no se expone al navegador y solo se usa para INSERT en
 * public.api_clients y UPDATE de api_key / is_active. El código de la Etapa 8
 * no construye SQL dinámico con entradas del usuario.
 */
final class CredentialDatabase
{
    private static ?PDO $pdo = null;

    public static function available(): bool
    {
        $config = Config::apiCredentials();

        return $config['dsn'] !== '' && $config['user'] !== '' && $config['pass'] !== '';
    }

    public static function connection(): PDO
    {
        if (self::$pdo instanceof PDO) {
            return self::$pdo;
        }

        $config = Config::apiCredentials();

        if ($config['dsn'] === '' || $config['user'] === '' || $config['pass'] === '') {
            throw new CustomerRepositoryException('customer_credential_database_not_configured');
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
            throw new CustomerRepositoryException('customer_credential_database_unavailable');
        }

        return self::$pdo = $pdo;
    }

    public static function reset(): void
    {
        self::$pdo = null;
    }
}
