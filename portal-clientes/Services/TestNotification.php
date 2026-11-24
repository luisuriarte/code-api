<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

use OrigenSalud\CustomerPortal\Config;
use OrigenSalud\CustomerPortal\I18n\CustomerI18n;

/**
 * Entregador de prueba: NO envía correo ni usa SMTP real.
 *
 * En la Etapa 5 las invitaciones y los resets se entregan como link visible al
 * administrador que ejecuta la prueba. El link apunta siempre a la base URL
 * configurada, nunca al Host de la petición.
 */
final class TestNotification
{
    /** @return array{kind: string, link: string, delivered: bool} */
    public static function prepare(string $kind, string $rawToken): array
    {
        $route = $kind === 'invitation' ? 'invitations' : 'reset';

        return [
            'kind' => $kind,
            'link' => Config::baseUrl() . '/' . CustomerI18n::locale() . '/' . $route . '/' . rawurlencode($rawToken),
            'delivered' => false,
        ];
    }
}
