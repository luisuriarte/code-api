<?php

declare(strict_types=1);

namespace OrigenSalud\Portal;

/**
 * Configuración del portal. Todas las credenciales se leen del entorno.
 */
final class Config
{
    public static function baseUrl(): string
    {
        $base = rtrim(trim((string) env('WEB_BASE_URL', 'https://med.origen.ar')), '/');

        return $base === '' ? 'https://med.origen.ar' : $base;
    }

    /** @return array{dsn: string, user: string, pass: string, timeout: int} */
    public static function database(): array
    {
        return [
            'dsn' => (string) env('PORTAL_DB_DSN', ''),
            'user' => (string) env('PORTAL_DB_USER', 'origen_med'),
            'pass' => (string) env('PORTAL_DB_PASS', ''),
            'timeout' => (int) env('PORTAL_DB_STATEMENT_TIMEOUT', '3'),
        ];
    }

    /** @return array{base_url: string, token: string, timeout: int} */
    public static function invoiceNinja(): array
    {
        return [
            'base_url' => rtrim(trim((string) env('INVOICE_NINJA_BASE_URL', 'https://gestion.uriarte.ar')), '/'),
            'token' => (string) env('INVOICE_NINJA_API_TOKEN', ''),
            'timeout' => (int) env('INVOICE_NINJA_TIMEOUT', '8'),
        ];
    }

    /** @return array{url: string, key: string, session: string, timeout: int} */
    public static function openWa(): array
    {
        return [
            'url' => rtrim(trim((string) env('OPENWA_API_URL', '')), '/'),
            'key' => (string) env('OPENWA_API_KEY', ''),
            'session' => (string) env('OPENWA_SESSION_ID', ''),
            'timeout' => (int) env('OPENWA_TIMEOUT', '10'),
        ];
    }

    /** @return array{host: string, port: int, user: string, pass: string, from: string, from_name: string} */
    public static function smtp(): array
    {
        return [
            'host' => (string) env('SMTP_HOST', ''),
            'port' => (int) env('SMTP_PORT', '587'),
            'user' => (string) env('SMTP_USER', ''),
            'pass' => (string) env('SMTP_PASS', ''),
            'from' => (string) env('CONTACT_EMAIL', 'contacto@origen.ar'),
            'from_name' => (string) env('CONTACT_NAME', 'Origen Salud'),
        ];
    }

    public static function contactEmail(): string
    {
        return (string) env('CONTACT_EMAIL', 'contacto@origen.ar');
    }

    /** @return array{contact: int, cart: int, browse: int, window: int} */
    public static function rateLimits(): array
    {
        return [
            'contact' => (int) env('RATE_CONTACT', '5'),
            'cart' => (int) env('RATE_CART', '5'),
            'browse' => (int) env('RATE_BROWSE', '120'),
            'window' => (int) env('RATE_WINDOW', '3600'),
        ];
    }
}
