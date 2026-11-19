<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Admin\AdminGuard;

/** Cambio de contexto activo: plataforma u organización (M2). */
final class AdminContextController
{
    public static function switch(): void
    {
        AdminForm::requirePost();
        AdminGuard::require();

        if (!AdminForm::validCsrf()) {
            AdminForm::fail(self::nextTarget(), 'csrf');

            return;
        }

        $raw = $_POST['organization_id'] ?? '';
        $requested = is_string($raw) && ctype_digit(trim($raw)) ? (int) $raw : null;

        if (!AdminGuard::auth()->switchContext($requested)) {
            AdminForm::fail(self::nextTarget(), 'permission');

            return;
        }

        AdminForm::success(self::nextTarget(), 'context_switched');
    }

    /** Evita redirecciones abiertas: solo rutas internas del panel. */
    private static function nextTarget(): string
    {
        $next = isset($_POST['next']) && is_string($_POST['next']) ? $_POST['next'] : '';

        if ($next === '' || !str_starts_with($next, '/admin/')
            || str_contains($next, '\\') || str_contains($next, '//')
        ) {
            return '/admin';
        }

        return $next;
    }
}
