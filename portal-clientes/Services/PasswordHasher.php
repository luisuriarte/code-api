<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

/** Hash de contraseñas con pepper exclusivo del portal de clientes. */
final class PasswordHasher
{
    private string $pepper;

    public function __construct(string $pepper)
    {
        $this->pepper = $pepper;
    }

    public function hash(string $password): string
    {
        return password_hash($password . $this->pepper, self::algorithm(), self::options());
    }

    public function verify(string $password, string $hash): bool
    {
        return $hash !== '' && password_verify($password . $this->pepper, $hash);
    }

    public function needsRehash(string $hash): bool
    {
        return password_needs_rehash($hash, self::algorithm(), self::options());
    }

    private static function algorithm(): string
    {
        return defined('PASSWORD_ARGON2ID') ? PASSWORD_ARGON2ID : PASSWORD_BCRYPT;
    }

    /** @return array<string, int> */
    private static function options(): array
    {
        if (self::algorithm() === PASSWORD_BCRYPT) {
            return ['cost' => 12];
        }

        return ['memory_cost' => 65536, 'time_cost' => 4, 'threads' => 1];
    }
}
