<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Admin\AdminGuard;
use OrigenSalud\Portal\Admin\Token;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\Services\Csrf;
use OrigenSalud\Portal\Services\Session;
use OrigenSalud\Portal\Services\Validator;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/** Flujo de autenticación del panel (Fase 1). */
final class AdminAuthController
{
    public static function login(): void
    {
        $flash = Session::pull('admin.flash');

        View::render('admin/login', [
            'pageTitle' => 'Acceso al panel | Origen Salud',
            'pageDescription' => 'Autenticación para colaboradores autorizados.',
            'locale' => I18n::locale(),
            'currentPath' => '/admin/login',
            'csrfToken' => Csrf::token(),
            'flash' => is_array($flash) ? $flash : null,
            'email' => is_array($flash) && is_string($flash['email'] ?? null) ? (string) $flash['email'] : '',
            'next' => self::nextTarget(),
        ], 'admin');
    }

    public static function loginSubmit(): void
    {
        $token = isset($_POST[Csrf::FIELD]) && is_string($_POST[Csrf::FIELD]) ? $_POST[Csrf::FIELD] : null;

        if (!Csrf::valid($token)) {
            self::fail('csrf', Validator::email($_POST['email'] ?? ''), self::nextTarget());

            return;
        }

        $email = Validator::email($_POST['email'] ?? '');
        $password = isset($_POST['password']) && is_string($_POST['password']) ? $_POST['password'] : '';
        $next = self::nextTarget();

        try {
            $result = AdminGuard::auth()->attempt($email, $password);
        } catch (RepositoryException) {
            self::fail('database', $email, $next);

            return;
        }

        if ($result['ok']) {
            header('Location: ' . $next, true, 303);
            exit;
        }

        self::fail((string) $result['error'], $email, $next);
    }

    public static function logout(): void
    {
        AdminGuard::auth()->logout();
        header('Location: /admin/login?logged_out=1', true, 303);
        exit;
    }

    public static function forgot(): void
    {
        $flash = Session::pull('admin.flash');

        View::render('admin/forgot', [
            'pageTitle' => 'Recuperar contraseña | Origen Salud',
            'pageDescription' => 'Solicitud de restablecimiento de contraseña.',
            'locale' => I18n::locale(),
            'currentPath' => '/admin/forgot',
            'csrfToken' => Csrf::token(),
            'flash' => is_array($flash) ? $flash : null,
        ], 'admin');
    }

    public static function forgotSubmit(): void
    {
        $token = isset($_POST[Csrf::FIELD]) && is_string($_POST[Csrf::FIELD]) ? $_POST[Csrf::FIELD] : null;

        if (!Csrf::valid($token)) {
            Session::set('admin.flash', ['error' => 'csrf', 'ok' => false]);
            header('Location: /admin/forgot', true, 303);
            exit;
        }

        try {
            AdminGuard::auth()->requestReset(Validator::email($_POST['email'] ?? ''));
        } catch (RepositoryException) {
            Session::set('admin.flash', ['ok' => false, 'error' => 'database']);
            header('Location: /admin/forgot', true, 303);
            exit;
        }

        Session::set('admin.flash', ['ok' => true, 'error' => null]);
        header('Location: /admin/forgot?sent=1', true, 303);
        exit;
    }

    public static function reset(): void
    {
        $token = isset($_GET['token']) && is_string($_GET['token']) ? $_GET['token'] : '';
        $flash = Session::pull('admin.flash');

        View::render('admin/reset', [
            'pageTitle' => 'Nueva contraseña | Origen Salud',
            'pageDescription' => 'Definir una contraseña nueva.',
            'locale' => I18n::locale(),
            'currentPath' => '/admin/reset',
            'csrfToken' => Csrf::token(),
            'token' => Token::isValidHex($token) ? $token : '',
            'invalidToken' => $token !== '' && !Token::isValidHex($token),
            'flash' => is_array($flash) ? $flash : null,
        ], 'admin');
    }

    public static function resetSubmit(): void
    {
        $token = isset($_POST['token']) && is_string($_POST['token']) ? $_POST['token'] : '';

        if (!Token::isValidHex($token)) {
            Session::set('admin.flash', ['ok' => false, 'error' => 'invalid']);
            header('Location: /admin/reset', true, 303);
            exit;
        }

        $csrf = isset($_POST[Csrf::FIELD]) && is_string($_POST[Csrf::FIELD]) ? $_POST[Csrf::FIELD] : null;

        if (!Csrf::valid($csrf)) {
            Session::set('admin.flash', ['ok' => false, 'error' => 'csrf', 'token' => $token]);
            header('Location: /admin/reset?token=' . rawurlencode($token), true, 303);
            exit;
        }

        $password = isset($_POST['password']) && is_string($_POST['password']) ? $_POST['password'] : '';

        try {
            $result = AdminGuard::auth()->reset($token, $password);
        } catch (RepositoryException) {
            Session::set('admin.flash', ['ok' => false, 'error' => 'database', 'token' => $token]);
            header('Location: /admin/reset?token=' . rawurlencode($token), true, 303);
            exit;
        }

        if ($result['ok']) {
            Session::set('admin.flash', ['ok' => true, 'error' => null]);
            header('Location: /admin/login?reset=1', true, 303);
            exit;
        }

        Session::set('admin.flash', ['ok' => false, 'error' => $result['error'], 'token' => $token]);
        header('Location: /admin/reset?token=' . rawurlencode($token), true, 303);
    }

    private static function fail(string $error, string $email, string $next): void
    {
        Session::set('admin.flash', [
            'ok' => false,
            'error' => $error,
            'email' => $email,
            'next' => $next,
        ]);
        header('Location: /admin/login?next=' . rawurlencode($next), true, 303);
        exit;
    }

    /** Evita redirecciones abiertas: solo rutas internas del panel. */
    private static function nextTarget(): string
    {
        $next = isset($_GET['next']) && is_string($_GET['next']) ? $_GET['next'] : '';

        if ($next === '' || !str_starts_with($next, '/admin/') || str_contains($next, '\\') || str_contains($next, '//')) {
            return '/admin';
        }

        return $next;
    }
}
