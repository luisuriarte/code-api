<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Admin;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\View;

/**
 * Guardias del panel. Toda decisión se toma en backend.
 */
final class AdminGuard
{
    private static ?AuthService $auth = null;

    public static function auth(): AuthService
    {
        return self::$auth ??= AuthService::create();
    }

    /** HTTPS obligatorio en producción antes de procesar cualquier credencial. */
    public static function requireSecure(): void
    {
        if (!Config::adminAuth()['require_https'] || self::isHttps()) {
            return;
        }

        http_response_code(403);
        header('Content-Type: text/plain; charset=UTF-8');
        exit("El panel de administración requiere HTTPS.\n");
    }

    /**
     * @param array{permission?: string} $options
     * @return array<string, mixed>
     */
    public static function require(array $options = []): array
    {
        self::requireSecure();

        $current = self::auth()->current();

        if ($current === null) {
            $next = (string) ($_SERVER['REQUEST_URI'] ?? '/admin');
            $next = str_starts_with($next, '/admin') ? $next : '/admin';
            header('Location: /admin/login?next=' . rawurlencode($next), true, 302);
            exit;
        }

        $permission = $options['permission'] ?? null;

        if (is_string($permission) && !Rbac::hasPermission($current['permissions'], $permission)) {
            self::denied($current);
        }

        return $current;
    }

    /** @param array<string, mixed>|null $current */
    public static function denied(?array $current = null): void
    {
        http_response_code(403);
        View::render('admin/denied', [
            'pageTitle' => 'Acceso denegado | Origen Salud',
            'pageDescription' => 'Permisos insuficientes.',
            'currentPath' => '/admin',
            'adminUser' => $current['user'] ?? null,
        ], 'admin');
        exit;
    }

    private static function isHttps(): bool
    {
        $https = $_SERVER['HTTPS'] ?? '';

        return (is_string($https) && $https !== '' && strtolower($https) !== 'off')
            || strtolower((string) ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '')) === 'https';
    }
}
