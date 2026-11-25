<?php

declare(strict_types=1);

/**
 * Front controller del portal privado de clientes.
 *
 * Vive en su propio directorio para no alterar el router de /portal ni el
 * .htaccess raíz. El código de aplicación está fuera del DocumentRoot.
 */

require_once dirname(__DIR__, 2) . '/portal-clientes/bootstrap.php';

header('Content-Type: text/html; charset=UTF-8');
header('Vary: Accept-Language, Cookie');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: strict-origin-when-cross-origin');
// X-Frame-Options lo emite nginx mediante el map $portal_customer_frame_options.
// Emitirlo también aquí duplicaría la cabecera en todas las respuestas PHP.
header('Cache-Control: private, no-store');

try {
    (new OrigenSalud\CustomerPortal\Router())->dispatch();
} catch (OrigenSalud\CustomerPortal\Services\CustomerRepositoryException) {
    http_response_code(503);
    OrigenSalud\CustomerPortal\View::render('errors/unavailable', [
        'title' => OrigenSalud\CustomerPortal\I18n\CustomerI18n::t('customer.error.unavailable_title'),
    ]);
}
