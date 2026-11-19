<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Admin;

/**
 * Hash de contraseñas con Argon2id y pepper de aplicación.
 *
 * El pepper no se guarda en la base: se inyecta desde ADMIN_PASSWORD_PEPPER.
 * Cambiarlo invalida los hashes existentes, por eso debe tratarse como secreto
 * estable. bcrypt se usa solo como reserva en instalaciones sin Argon2id.
 */
final class PasswordHasher
{
    private string $pepper;

    public function __construct(string $pepper)
    {
        $this->pepper = $pepper;
    }

    public function hash(string $password): string
    {
        return password_hash(
            $password . $this->pepper,
            self::algorithm(),
            self::options()
        );
    }

    public function verify(string $password, string $hash): bool
    {
        if ($hash === '') {
            return false;
        }

        return password_verify($password . $this->pepper, $hash);
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
