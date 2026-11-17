<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Services;

/**
 * Token CSRF por sesión, comparado en tiempo constante.
 */
final class Csrf
{
    public const FIELD = '_csrf';

    public static function token(): string
    {
        $token = Session::get('csrf_token');

        if (!is_string($token) || $token === '') {
            $token = bin2hex(random_bytes(32));
            Session::set('csrf_token', $token);
        }

        return $token;
    }

    public static function valid(?string $token): bool
    {
        $expected = Session::get('csrf_token');

        if (!is_string($expected) || !is_string($token)) {
            return false;
        }

        return hash_equals($expected, $token);
    }

    public static function rotate(): void
    {
        Session::set('csrf_token', bin2hex(random_bytes(32)));
    }
}
