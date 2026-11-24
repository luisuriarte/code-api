<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

use OrigenSalud\CustomerPortal\Config;
use OrigenSalud\CustomerPortal\I18n\CustomerI18n;

/** Utilidades de respuesta del portal de clientes. */
final class Http
{
    public static function redirect(string $path): void
    {
        $base = Config::baseUrl();
        $target = str_starts_with($path, 'http://') || str_starts_with($path, 'https://')
            ? $path
            : $base . '/' . ltrim($path, '/');

        header('Location: ' . $target, true, 302);
        exit;
    }

    public static function isPost(): bool
    {
        return strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET')) === 'POST';
    }

    public static function abort(int $status, string $view): void
    {
        http_response_code($status);
        \OrigenSalud\CustomerPortal\View::render($view, [
            'title' => CustomerI18n::t('customer.error.title'),
        ], 'customer');
        exit;
    }

    /** @return array<string, string> */
    public static function post(): array
    {
        $result = [];

        foreach ($_POST as $key => $value) {
            if (is_string($value)) {
                $result[$key] = $value;
            }
        }

        return $result;
    }
}
