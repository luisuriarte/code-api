<?php

declare(strict_types=1);

/**
 * Crea el primer superadministrador del panel (Fase 1 / M1).
 *
 * Ejecutar SOLO en el VPS, después de aplicar sql/09_admin/fase1_identidad.sql:
 *   php tools/php/admin_bootstrap.php
 *
 * Si una ejecución anterior creó el usuario pero falló antes de asignar roles
 * (por ejemplo, por permisos faltantes en os_admin.membership), se puede
 * completar sin tocar la contraseña:
 *   php tools/php/admin_bootstrap.php --repair-existing
 *
 * No se ejecuta automáticamente. No modifica catálogos ni la API pública.
 * La contraseña se lee de STDIN y se escribe solo como hash Argon2id.
 */

require_once dirname(__DIR__, 2) . '/portal/bootstrap.php';

use OrigenSalud\Portal\Admin\AuditLogger;
use OrigenSalud\Portal\Admin\PasswordHasher;
use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\Repositories\AdminDatabase;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\Repositories\UserRepository;
use OrigenSalud\Portal\Services\Validator;

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "Este script solo puede ejecutarse por CLI.\n");
    exit(1);
}

$ask = static function (string $prompt): string {
    fwrite(STDOUT, $prompt);
    $line = fgets(STDIN);

    return $line === false ? '' : rtrim($line, "\r\n");
};

if (!AdminDatabase::available()) {
    fwrite(STDERR, "PORTAL_ADMIN_DB_* no está configurado, o M1 no está aplicado.\n");
    exit(1);
}

$repairExisting = in_array('--repair-existing', $argv ?? [], true);
$email = Validator::email($ask('Email: '));

if ($email === '') {
    fwrite(STDERR, "Email inválido. No se creó ni modificó ningún usuario.\n");
    exit(1);
}

try {
    $existing = UserRepository::findByEmail($email);

    if ($existing !== null) {
        $userId = (int) $existing['id'];

        if ($existing['status'] !== 'active') {
            fwrite(STDERR, "El usuario existe (id {$userId}) pero no está activo. No se modificó.\n");
            exit(1);
        }

        if (!$repairExisting) {
            fwrite(STDERR, "El usuario ya existe (id {$userId}).\n");
            fwrite(STDERR, "Para completar roles y auditoría sin cambiar la contraseña, ejecutá:\n");
            fwrite(STDERR, "  php tools/php/admin_bootstrap.php --repair-existing\n");
            exit(1);
        }

        UserRepository::assignRole($userId, 'superadmin');
        UserRepository::assignRole($userId, 'viewer');

        AuditLogger::record('bootstrap_superadmin_roles_repaired', [
            'actor_user_id' => $userId,
            'actor_email' => (string) $existing['email'],
            'entity_type' => 'app_user',
            'entity_id' => (string) $userId,
            'reason' => 'bootstrap_repair_existing',
        ]);

        fwrite(STDOUT, "Usuario existente id {$userId}: roles y auditoría completados.\n");
        fwrite(STDOUT, "La contraseña no se modificó.\n");
        exit(0);
    }

    if ((string) Config::adminAuth()['pepper'] === '') {
        fwrite(STDERR, "ADMIN_PASSWORD_PEPPER está vacío. Definalo antes de crear usuarios.\n");
        exit(1);
    }

    $fullName = Validator::text($ask('Nombre completo: '), 180);
    $password = $ask('Contraseña (mínimo 12 caracteres): ');
    $confirm = $ask('Repita la contraseña: ');

    if ($fullName === '' || mb_strlen($password) < 12 || $password !== $confirm) {
        fwrite(STDERR, "Datos inválidos o contraseñas distintas. No se creó ningún usuario.\n");
        exit(1);
    }

    $hasher = new PasswordHasher((string) Config::adminAuth()['pepper']);
    $userId = UserRepository::create($email, $hasher->hash($password), $fullName);
    UserRepository::assignRole($userId, 'superadmin');
    UserRepository::assignRole($userId, 'viewer');

    AuditLogger::record('bootstrap_superadmin_created', [
        'actor_user_id' => $userId,
        'actor_email' => $email,
        'entity_type' => 'app_user',
        'entity_id' => (string) $userId,
    ]);
} catch (RepositoryException $exception) {
    // El código es estable y no contiene credenciales ni datos personales.
    fwrite(STDERR, "No se pudo completar el bootstrap. Código: " . $exception->getMessage() . "\n");
    fwrite(STDERR, "Verifique M1, los permisos de origen_admin y el estado del usuario.\n");
    exit(1);
}

fwrite(STDOUT, "Superadministrador creado con id {$userId}. No se imprimió la contraseña.\n");
