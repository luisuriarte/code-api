<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\Services\ContactService;
use OrigenSalud\Portal\Services\Csrf;
use OrigenSalud\Portal\Services\Session;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

final class ContactController
{
    public static function index(string $locale, string $currentPath): void
    {
        $t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
        $flash = Session::pull('contact.flash');

        View::render('contact', [
            'pageTitle' => $t('contact.title') . ' | Origen Salud',
            'pageDescription' => $t('contact.lead'),
            'locale' => $locale,
            'currentPath' => $currentPath,
            'csrfToken' => Csrf::token(),
            'form' => is_array($flash) && isset($flash['fields']) && is_array($flash['fields']) ? $flash['fields'] : [],
            'flash' => is_array($flash) ? $flash : null,
            'types' => ['commercial', 'technical', 'integration', 'catalogs', 'docs', 'other'],
            'contactEmail' => Config::contactEmail(),
        ]);
    }

    public static function submit(string $locale): void
    {
        $result = ContactService::submit($_POST, $locale);

        Session::set('contact.flash', [
            'ok' => $result['ok'],
            'error' => $result['error'],
            'fields' => $result['fields'],
            'reason' => $result['reason'] ?? null,
        ]);

        $target = I18n::localizedPath($locale, '/contact') . ($result['ok'] ? '?sent=1' : '?error=1');
        header('Location: ' . $target, true, 303);
        exit;
    }
}
