<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

/**
 * Destino del portal privado de clientes, con el idioma canónico del sitio.
 * La ruta es relativa al mismo host; no se construye con el header Host.
 */
$customerPortalHref = '/portal-clientes/' . (I18n::canonical($locale) ?? I18n::DEFAULT_LOCALE) . '/';
