<?php

declare(strict_types=1);

/**
 * Bootstrap del portal privado de clientes (/portal-clientes).
 *
 * Vive fuera del DocumentRoot, al igual que /portal, pero usa un namespace,
 * sesión, base y pepper propios. No comparte guardias ni identidad con
 * /admin ni con el portal público.
 */

require_once dirname(__DIR__) . '/bootstrap.php';
require_once dirname(__DIR__) . '/portal/i18n/I18n.php';

spl_autoload_register(static function (string $class): void {
    $prefix = 'OrigenSalud\\CustomerPortal\\';

    if (!str_starts_with($class, $prefix)) {
        return;
    }

    $relative = substr($class, strlen($prefix));
    $path = __DIR__ . '/' . str_replace('\\', '/', $relative) . '.php';

    if (is_file($path)) {
        require_once $path;
    }
});

OrigenSalud\CustomerPortal\Services\CustomerSession::start();
