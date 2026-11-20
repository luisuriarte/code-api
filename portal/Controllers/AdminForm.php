<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Admin\GovernanceException;
use OrigenSalud\Portal\Admin\UvrGovernanceException;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\Services\Csrf;
use OrigenSalud\Portal\Services\Session;

/** Utilidades comunes de formularios del panel (PRG + flash + CSRF). */
final class AdminForm
{
    public static function requirePost(): void
    {
        if (strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET')) !== 'POST') {
            http_response_code(404);
            exit;
        }
    }

    public static function validCsrf(): bool
    {
        $token = isset($_POST[Csrf::FIELD]) && is_string($_POST[Csrf::FIELD])
            ? $_POST[Csrf::FIELD]
            : null;

        return Csrf::valid($token);
    }

    public static function fail(string $redirect, string $error, array $values = []): void
    {
        Session::set('admin.flash', [
            'ok' => false,
            'error' => $error,
            'values' => $values,
        ]);
        self::redirect($redirect);
    }

    public static function exception(string $redirect, \Throwable $exception, array $values = []): void
    {
        if ($exception instanceof GovernanceException) {
            self::fail($redirect, $exception->errorCode, $values);

            return;
        }

        if ($exception instanceof UvrGovernanceException) {
            self::fail($redirect, $exception->getMessage(), $values);

            return;
        }

        if ($exception instanceof RepositoryException) {
            self::fail($redirect, 'database', $values);

            return;
        }

        self::fail($redirect, 'invalid', $values);
    }

    public static function success(string $redirect, string $key): void
    {
        Session::set('admin.flash', [
            'ok' => true,
            'message' => $key,
            'values' => [],
        ]);
        self::redirect($redirect);
    }

    /** @return array{ok: bool, error: ?string, message: ?string, values: array<string, mixed>}|null */
    public static function pull(): ?array
    {
        $flash = Session::pull('admin.flash');

        if (!is_array($flash)) {
            return null;
        }

        return [
            'ok' => (bool) ($flash['ok'] ?? false),
            'error' => is_string($flash['error'] ?? null) ? $flash['error'] : null,
            'message' => is_string($flash['message'] ?? null) ? $flash['message'] : null,
            'values' => is_array($flash['values'] ?? null) ? $flash['values'] : [],
        ];
    }

    private static function redirect(string $target): void
    {
        header('Location: ' . $target, true, 303);
        exit;
    }
}
