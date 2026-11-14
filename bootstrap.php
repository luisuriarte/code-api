<?php

declare(strict_types=1);

/**
 * Bootstrap común de la plataforma Origen Salud.
 *
 * Responsabilidades:
 *  - Definir rutas base del proyecto.
 *  - Cargar el autoloader de Composer.
 *  - Cargar variables de entorno desde .env.
 *  - Configurar errores, zona horaria y helpers globales.
 *
 * Tanto api/index.php como web/index.php deben requerir este archivo.
 */

define('BASE_PATH', __DIR__);
define('API_PATH', BASE_PATH . DIRECTORY_SEPARATOR . 'api');
define('WEB_PATH', BASE_PATH . DIRECTORY_SEPARATOR . 'web');

$autoload = BASE_PATH . '/vendor/autoload.php';

if (!is_file($autoload)) {
    http_response_code(503);
    header('Content-Type: text/plain; charset=UTF-8');
    exit("Las dependencias no están instaladas. Ejecutá \"composer install\" en " . BASE_PATH . ".\n");
}

require $autoload;

/*
 * safeLoad() no falla si el archivo .env no existe: en producción es válido
 * inyectar las variables directamente desde el servidor web o el contenedor.
 */
if (class_exists(\Dotenv\Dotenv::class)) {
    \Dotenv\Dotenv::createImmutable(BASE_PATH)->safeLoad();
}

if (!function_exists('env')) {
    /**
     * Lee una variable de entorno con un valor por defecto.
     *
     * Soporta los valores booleanos "true"/"false" y "null" para facilitar
     * la configuración desde archivos .env.
     */
    function env(string $key, mixed $default = null): mixed
    {
        $value = $_ENV[$key] ?? $_SERVER[$key] ?? getenv($key);

        if ($value === false || $value === null) {
            return $default;
        }

        if (is_bool($value)) {
            return $value;
        }

        return match (strtolower(trim((string) $value))) {
            'true', '(true)' => true,
            'false', '(false)' => false,
            'null' => null,
            default => $value,
        };
    }
}

if (!function_exists('e')) {
    /**
     * Escapa un valor para insertarlo con seguridad en HTML.
     */
    function e(mixed $value): string
    {
        if ($value === null) {
            return '';
        }

        if (!is_scalar($value) && !$value instanceof \Stringable) {
            return '';
        }

        return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
}

$debug = filter_var(env('APP_DEBUG', false), FILTER_VALIDATE_BOOL);

error_reporting(E_ALL);
ini_set('display_errors', $debug ? '1' : '0');
ini_set('display_startup_errors', $debug ? '1' : '0');
ini_set('log_errors', '1');
ini_set('default_charset', 'UTF-8');

$timezone = (string) env('APP_TIMEZONE', 'UTC');

if (in_array($timezone, timezone_identifiers_list(), true)) {
    date_default_timezone_set($timezone);
}
