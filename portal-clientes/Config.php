<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal;

/**
 * Configuración del portal de clientes.
 *
 * Todos los valores sensibles se leen del entorno. Los defaults son
 * placeholders de prueba: nunca habilitan una conexión real ni envían correo.
 */
final class Config
{
    public static function baseUrl(): string
    {
        $base = rtrim(trim((string) env('PORTAL_CUSTOMER_BASE_URL', 'https://portal-clientes.test.example.invalid')), '/');

        return $base === '' ? 'https://portal-clientes.test.example.invalid' : $base;
    }

    /** @return array{dsn: string, user: string, pass: string, timeout: int} */
    public static function database(): array
    {
        return [
            'dsn' => (string) env('PORTAL_CUSTOMER_DB_DSN', ''),
            'user' => (string) env('PORTAL_CUSTOMER_DB_USER', 'origen_customer'),
            'pass' => (string) env('PORTAL_CUSTOMER_DB_PASS', ''),
            'timeout' => (int) env('PORTAL_CUSTOMER_DB_STATEMENT_TIMEOUT', '3'),
        ];
    }

    /**
     * @return array{
     *     password_pepper: string,
     *     token_pepper: string,
     *     session_ttl: int,
     *     login_limit: int,
     *     login_window: int,
     *     lock_minutes: int,
     *     reset_ttl: int,
     *     invite_ttl: int,
     *     require_https: bool
     * }
     */
    public static function auth(): array
    {
        return [
            'password_pepper' => (string) env('PORTAL_CUSTOMER_PASSWORD_PEPPER', ''),
            'token_pepper' => (string) env('PORTAL_CUSTOMER_TOKEN_PEPPER', ''),
            'session_ttl' => (int) env('PORTAL_CUSTOMER_SESSION_TTL', '43200'),
            'login_limit' => (int) env('PORTAL_CUSTOMER_LOGIN_LIMIT', '5'),
            'login_window' => (int) env('PORTAL_CUSTOMER_LOGIN_WINDOW', '900'),
            'lock_minutes' => (int) env('PORTAL_CUSTOMER_LOCK_MINUTES', '15'),
            'reset_ttl' => (int) env('PORTAL_CUSTOMER_RESET_TTL', '3600'),
            'invite_ttl' => (int) env('PORTAL_CUSTOMER_INVITE_TTL', '604800'),
            'require_https' => filter_var(env('PORTAL_CUSTOMER_REQUIRE_HTTPS', true), FILTER_VALIDATE_BOOL),
        ];
    }

    /**
     * Integración con Invoice Ninja (Etapa 6).
     *
     * El modo por defecto es `mock`: no realiza ninguna llamada HTTP.
     * Para consultar la instancia designada como de prueba se requieren tres
     * condiciones simultáneas: modo `http`, el opt-in explícito de llamadas de
     * prueba y un token de prueba configurado. El token real está prohibido por
     * el acta de autorización y nunca se registra ni se expone.
     *
     * @return array{
     *     mode: string,
     *     base_url: string,
     *     api_prefix: string,
     *     token: string,
     *     allow_test_calls: bool,
     *     timeout: int,
     *     retries: int
     * }
     */
    public static function invoiceNinja(): array
    {
        $mode = strtolower(trim((string) env('PORTAL_CUSTOMER_IN_MODE', 'mock')));
        if (!in_array($mode, ['mock', 'http'], true)) {
            $mode = 'mock';
        }

        $baseUrl = rtrim(trim((string) env(
            'PORTAL_CUSTOMER_IN_BASE_URL',
            'https://gestion.uriarte.ar'
        )), '/');
        if ($baseUrl === '' || !str_starts_with($baseUrl, 'https://')) {
            $baseUrl = 'https://gestion.uriarte.ar';
        }

        $prefix = trim((string) env('PORTAL_CUSTOMER_IN_API_PREFIX', '/api/v1'));
        if ($prefix === '' || !str_starts_with($prefix, '/')) {
            $prefix = '/api/v1';
        }

        $allow = filter_var(env('PORTAL_CUSTOMER_IN_ALLOW_TEST_CALLS', false), FILTER_VALIDATE_BOOL);
        $token = (string) env('PORTAL_CUSTOMER_IN_TOKEN', '');

        return [
            'mode' => $mode,
            'base_url' => $baseUrl,
            'api_prefix' => rtrim($prefix, '/'),
            'token' => $token,
            'allow_test_calls' => $allow,
            'timeout' => max(1, min(30, (int) env('PORTAL_CUSTOMER_IN_TIMEOUT', '8'))),
            'retries' => max(0, min(2, (int) env('PORTAL_CUSTOMER_IN_RETRIES', '1'))),
        ];
    }

    /** Indica si están dadas las tres condiciones para una llamada HTTP de prueba. */
    public static function invoiceNinjaHttpEnabled(): bool
    {
        $config = self::invoiceNinja();

        return $config['mode'] === 'http'
            && $config['allow_test_calls'] === true
            && $config['token'] !== '';
    }
}
