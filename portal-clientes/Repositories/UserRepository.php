<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

final class UserRepository
{
    /** @return array<string, mixed>|null */
    public static function findByEmail(string $email): ?array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT * FROM os_customer.app_user WHERE lower(email) = lower(:email)'
        );
        $statement->execute([':email' => trim($email)]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    /** @return array<string, mixed>|null */
    public static function findById(int $id): ?array
    {
        $statement = CustomerDatabase::connection()->prepare(
            'SELECT * FROM os_customer.app_user WHERE id = :id'
        );
        $statement->execute([':id' => $id]);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    public static function createActive(string $email, string $fullName, string $passwordHash): int
    {
        $statement = CustomerDatabase::connection()->prepare(
            'INSERT INTO os_customer.app_user
                (email, full_name, password_hash, status, email_verified_at)
             VALUES
                (:email, :full_name, :password_hash, \'active\', now())
             RETURNING id'
        );
        $statement->execute([
            ':email' => trim($email),
            ':full_name' => trim($fullName),
            ':password_hash' => $passwordHash,
        ]);

        return (int) $statement->fetchColumn();
    }

    public static function activate(int $id, string $passwordHash): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.app_user
                SET status = \'active\',
                    password_hash = :password_hash,
                    email_verified_at = now(),
                    failed_logins = 0,
                    locked_until = NULL,
                    updated_at = now()
              WHERE id = :id'
        );
        $statement->execute([':id' => $id, ':password_hash' => $passwordHash]);
    }

    public static function updatePassword(int $id, string $passwordHash): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.app_user
                SET password_hash = :password_hash,
                    failed_logins = 0,
                    locked_until = NULL,
                    updated_at = now()
              WHERE id = :id'
        );
        $statement->execute([':id' => $id, ':password_hash' => $passwordHash]);
    }

    public static function touchLogin(int $id): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.app_user
                SET last_login_at = now(), failed_logins = 0, updated_at = now()
              WHERE id = :id'
        );
        $statement->execute([':id' => $id]);
    }

    public static function registerFailure(int $id, ?string $lockedUntil): void
    {
        $statement = CustomerDatabase::connection()->prepare(
            'UPDATE os_customer.app_user
                SET failed_logins = failed_logins + 1,
                    locked_until = CASE WHEN :locked_null IS NULL THEN locked_until ELSE :locked_value::timestamptz END,
                    updated_at = now()
              WHERE id = :id'
        );
        $statement->execute([
            ':id' => $id,
            ':locked_null' => $lockedUntil,
            ':locked_value' => $lockedUntil,
        ]);
    }
}
