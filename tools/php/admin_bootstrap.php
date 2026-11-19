<?php

declare(strict_types=1);

/**
 * Crea el primer superadministrador del panel (Fase 1 / M1).
 *
 * Ejecutar SOLO en el VPS, después de aplicar sql/09_admin/fase1_identidad.sql:
 *   php tools/php/admin_bootstrap.php
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

if ((string) Config::adminAuth()['pepper'] === '') {
    fwrite(STDERR, "ADMIN_PASSWORD_PEPPER está vacío. Definalo antes de crear usuarios.\n");
    exit(1);
}

$email = Validator::email($ask('Email: '));
$fullName = Validator::text($ask('Nombre completo: '), 180);
$password = $ask('Contraseña (mínimo 12 caracteres): ');
$confirm = $ask('Repita la contraseña: ');

if ($email === '' || $fullName === '' || mb_strlen($password) < 12 || $password !== $confirm) {
    fwrite(STDERR, "Datos inválidos o contraseñas distintas. No se creó ningún usuario.\n");
    exit(1);
}

try {
    if (UserRepository::findByEmail($email) !== null) {
        fwrite(STDERR, "El usuario ya existe. No se modificó.\n");
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
} catch (RepositoryException) {
    fwrite(STDERR, "No se pudo crear el usuario. Verifique M1 y los permisos de origen_admin.\n");
    exit(1);
}

fwrite(STDOUT, "Superadministrador creado con id {$userId}. No se imprimió la contraseña.\n");
