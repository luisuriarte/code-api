<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

/** Token CSRF específico del portal de clientes. */
final class CustomerCsrf
{
    public const FIELD = '_csrf';

    public static function token(): string
    {
        $token = CustomerSession::get('csrf_token');

        if (!is_string($token) || $token === '') {
            $token = bin2hex(random_bytes(32));
            CustomerSession::set('csrf_token', $token);
        }

        return $token;
    }

    public static function valid(?string $token): bool
    {
        $expected = CustomerSession::get('csrf_token');

        if (!is_string($expected) || !is_string($token)) {
            return false;
        }

        return hash_equals($expected, $token);
    }

    public static function rotate(): void
    {
        CustomerSession::set('csrf_token', bin2hex(random_bytes(32)));
    }
}
