<?php

declare(strict_types=1);

/**
 * Bootstrap del portal (fuera del DocumentRoot).
 *
 * Reutiliza el bootstrap raíz (Composer, .env, helpers env()/e()) y registra
 * un autoloader PSR-4 liviano para OrigenSalud\Portal\ sin exigir composer dump.
 */

require_once dirname(__DIR__) . '/bootstrap.php';

spl_autoload_register(static function (string $class): void {
    $prefix = 'OrigenSalud\\Portal\\';

    if (!str_starts_with($class, $prefix)) {
        return;
    }

    $relative = substr($class, strlen($prefix));
    $path = __DIR__ . '/' . str_replace('\\', '/', $relative) . '.php';

    if (is_file($path)) {
        require_once $path;
    }
});

require_once __DIR__ . '/i18n/I18n.php';

OrigenSalud\Portal\Services\Session::start();
