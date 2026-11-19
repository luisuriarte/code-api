<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Admin;

/**
 * Tokens opacos para sesiones y reset de contraseña.
 *
 * El valor en claro viaja solo en la cookie/URL; en la base se guarda
 * únicamente su hash SHA-256. La comparación siempre es de tiempo constante.
 */
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

    /** Hash de dirección IP o user-agent: nunca se guarda el valor original. */
    public static function fingerprint(string $value, string $pepper): string
    {
        return hash('sha256', $value . "\0" . $pepper);
    }
}
