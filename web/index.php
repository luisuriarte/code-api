<?php

declare(strict_types=1);

/**
 * Front controller del portal med.origen.ar.
 *
 * Todo el código de aplicación vive en /portal, fuera del DocumentRoot.
 */

require_once dirname(__DIR__) . '/portal/bootstrap.php';

header('Content-Type: text/html; charset=UTF-8');
header('Vary: Accept-Language, Cookie');

(new OrigenSalud\Portal\Router())->dispatch();
