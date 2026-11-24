<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

/** Tokens opacos y hashes de huellas; el valor en claro nunca se guarda en base. */
final class Token
{
    public static function random(int $bytes = 32): string
    {
        return bin2hex(random_bytes($bytes));
    }

    public static function hash(string $raw): string
    {
        return hash('sha256', $raw);
    }

    public static function verify(string $raw, string $hash): bool
    {
        return hash_equals($hash, self::hash($raw));
    }

    public static function isValidHex(string $value, int $bytes = 32): bool
    {
        return preg_match('/^[0-9a-f]{' . ($bytes * 2) . '}$/i', $value) === 1;
    }

    public static function fingerprint(string $value, string $pepper): string
    {
        return hash('sha256', $value . "\0" . $pepper);
    }
}
