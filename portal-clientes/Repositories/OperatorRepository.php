<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Repositories;

use OrigenSalud\CustomerPortal\Services\CustomerDatabase;

/** Operadores internos de Origen Salud. No comparte identidad con os_admin. */
final class OperatorRepository
{
    public static function isSuperAdmin(int $userId): bool
    {
        if ($userId <= 0) {
            return false;
        }

        $statement = CustomerDatabase::connection()->prepare(
            'SELECT 1
               FROM os_customer.operator
              WHERE user_id = :user
                AND role_code = \'superadmin\'
                AND status = \'active\''
        );
        $statement->execute([':user' => $userId]);

        return $statement->fetchColumn() !== false;
    }
}
