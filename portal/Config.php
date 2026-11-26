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

    /**
     * Base del panel de administración (M2).
     *
     * Puede vivir en un host distinto del portal público. Los vínculos de
     * invitación y recuperación se construyen con esta base, nunca con el host
     * de la petición, para evitar host header injection.
     */
    public static function adminBaseUrl(): string
    {
        $configurado = rtrim(trim((string) env('ADMIN_BASE_URL', '')), '/');

        return $configurado !== '' ? $configurado : self::baseUrl();
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
        // Postfix (y otros MTA) rechazan el sobre si MAIL FROM no coincide con
        // el usuario autenticado (reject_sender_login_mismatch). Por defecto
        // se usa SMTP_USER; SMTP_FROM permite override explícito.
        $from = trim((string) env('SMTP_FROM', ''));

        if ($from === '') {
            $from = (string) env('SMTP_USER', '');
        }

        if ($from === '') {
            $from = (string) env('CONTACT_EMAIL', 'contacto@origen.ar');
        }

        return [
            'host' => (string) env('SMTP_HOST', ''),
            'port' => (int) env('SMTP_PORT', '587'),
            'user' => (string) env('SMTP_USER', ''),
            'pass' => (string) env('SMTP_PASS', ''),
            'from' => $from,
            'from_name' => (string) env('CONTACT_NAME', 'Origen Salud'),
        ];
    }

    public static function contactEmail(): string
    {
        return (string) env('CONTACT_EMAIL', 'contacto@origen.ar');
    }

    /**
     * Copias ocultas del formulario de contacto.
     * Acepta varias direcciones separadas por coma o punto y coma.
     * `REPLY_TO` se conserva como alias, aunque no altera la cabecera Reply-To.
     *
     * @return list<string>
     */
    public static function contactBcc(): array
    {
        $raw = trim((string) env('CONTACT_BCC', ''));

        if ($raw === '') {
            $raw = trim((string) env('REPLY_TO', ''));
        }

        if ($raw === '') {
            return [];
        }

        $emails = [];

        foreach (preg_split('/[,;]/', $raw) ?: [] as $candidate) {
            $email = strtolower(trim($candidate));

            if ($email === '' || filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
                continue;
            }

            if (count($emails) >= 20 || in_array($email, $emails, true)) {
                continue;
            }

            $emails[] = $email;
        }

        return $emails;
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

    /**
     * Conexión de escritura acotada al esquema os_admin (M1).
     *
     * Es distinta de la conexión pública de solo lectura: el rol origen_admin
     * no tiene permisos sobre os_catalog_* ni sobre la API pública.
     *
     * @return array{dsn: string, user: string, pass: string, timeout: int}
     */
    public static function adminDatabase(): array
    {
        return [
            'dsn' => (string) env('PORTAL_ADMIN_DB_DSN', ''),
            'user' => (string) env('PORTAL_ADMIN_DB_USER', 'origen_admin'),
            'pass' => (string) env('PORTAL_ADMIN_DB_PASS', ''),
            'timeout' => (int) env('PORTAL_ADMIN_DB_STATEMENT_TIMEOUT', '3'),
        ];
    }

    /** @return array{pepper: string, session_lifetime: int, login_limit: int, login_window: int, lock_minutes: int, reset_ttl: int, invite_ttl: int, invite_max_ttl: int, invite_resend_min: int, require_https: bool} */
    public static function adminAuth(): array
    {
        return [
            'pepper' => (string) env('ADMIN_PASSWORD_PEPPER', ''),
            'session_lifetime' => (int) env('ADMIN_SESSION_LIFETIME', '43200'),
            'login_limit' => (int) env('ADMIN_LOGIN_LIMIT', '5'),
            'login_window' => (int) env('ADMIN_LOGIN_WINDOW', '900'),
            'lock_minutes' => (int) env('ADMIN_LOCK_MINUTES', '15'),
            'reset_ttl' => (int) env('ADMIN_RESET_TTL', '3600'),
            'invite_ttl' => (int) env('ADMIN_INVITE_TTL', '604800'),
            'invite_max_ttl' => (int) env('ADMIN_INVITE_MAX_TTL', '2592000'),
            'invite_resend_min' => (int) env('ADMIN_INVITE_RESEND_MIN', '300'),
            'require_https' => filter_var(env('ADMIN_REQUIRE_HTTPS', true), FILTER_VALIDATE_BOOL),
        ];
    }
}
