<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Controllers;

use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Repositories\AuditRepository;
use OrigenSalud\CustomerPortal\Repositories\PasswordResetRepository;
use OrigenSalud\CustomerPortal\Services\AccessControl;
use OrigenSalud\CustomerPortal\Services\AuthService;
use OrigenSalud\CustomerPortal\Services\CustomerCsrf;
use OrigenSalud\CustomerPortal\Services\CustomerSession;
use OrigenSalud\CustomerPortal\Services\Http;
use OrigenSalud\CustomerPortal\Services\Token;
use OrigenSalud\CustomerPortal\View;

final class AuthController
{
    public static function login(): void
    {
        if (AccessControl::current() !== null) {
            Http::redirect(CustomerI18n::locale() . '/');
        }

        View::render('auth/login', [
            'title' => CustomerI18n::t('customer.login.title'),
            'error' => CustomerSession::pull('login_error'),
        ]);
    }

    public static function loginSubmit(): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }

        $post = Http::post();
        $result = AuthService::attemptLogin((string) ($post['email'] ?? ''), (string) ($post['password'] ?? ''));

        if (!$result['ok']) {
            CustomerSession::set('login_error', (string) ($result['error_key'] ?? 'customer.login.invalid'));
            Http::redirect(CustomerI18n::locale() . '/login');
        }

        CustomerCsrf::rotate();
        Http::redirect(CustomerI18n::locale() . '/');
    }

    public static function logoutSubmit(): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }

        AuthService::logout();
        Http::redirect(CustomerI18n::locale() . '/login');
    }

    public static function forgot(): void
    {
        View::render('auth/forgot', [
            'title' => CustomerI18n::t('customer.forgot.title'),
        ]);
    }

    public static function forgotSubmit(): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }

        $post = Http::post();
        $result = AuthService::requestReset((string) ($post['email'] ?? ''));

        CustomerSession::set('flash', [
            'key' => $result['key'],
            'params' => $result['link'] === null ? [] : ['%link%' => $result['link']],
        ]);
        Http::redirect(CustomerI18n::locale() . '/forgot');
    }

    public static function reset(string $token): void
    {
        $valid = Token::isValidHex($token) && PasswordResetRepository::findActiveByRawToken($token) !== null;

        View::render('auth/reset', [
            'title' => CustomerI18n::t('customer.reset.title'),
            'token' => $token,
            'valid' => $valid,
        ]);
    }

    public static function resetSubmit(string $token): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }

        $post = Http::post();
        $password = (string) ($post['password'] ?? '');

        if (mb_strlen($password) < 12) {
            CustomerSession::set('flash', ['key' => 'customer.reset.too_short', 'params' => []]);
            Http::redirect(CustomerI18n::locale() . '/reset/' . rawurlencode($token));
        }

        $ok = AuthService::resetPassword($token, $password);

        if (!$ok) {
            AuditRepository::record(null, null, 'password_reset.rejected', 'password_reset', null, 'denied');
        }

        CustomerSession::set('flash', [
            'key' => $ok ? 'customer.reset.done' : 'customer.reset.invalid',
            'params' => [],
        ]);
        Http::redirect(CustomerI18n::locale() . '/' . ($ok ? 'login' : 'reset/' . rawurlencode($token)));
    }
}
