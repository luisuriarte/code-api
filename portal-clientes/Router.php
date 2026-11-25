<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal;

use OrigenSalud\CustomerPortal\Controllers\AuthController;
use OrigenSalud\CustomerPortal\Controllers\CredentialController;
use OrigenSalud\CustomerPortal\Controllers\HomeController;
use OrigenSalud\CustomerPortal\Controllers\InvitationController;
use OrigenSalud\CustomerPortal\Controllers\MemberController;
use OrigenSalud\CustomerPortal\Controllers\OrganizationController;
use OrigenSalud\CustomerPortal\Controllers\ServiceController;
use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Services\Http;
use OrigenSalud\Web\I18n;

/** Enrutador de /portal-clientes. Prefijo de idioma propio, sin /admin. */
final class Router
{
    private const PREFIX = '/portal-clientes';

    public function dispatch(): void
    {
        $path = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH);
        $path = is_string($path) && $path !== '' ? $path : '/';

        if ($path === self::PREFIX || $path === self::PREFIX . '/') {
            Http::redirect(I18n::DEFAULT_LOCALE . '/');

            return;
        }

        if (!str_starts_with($path, self::PREFIX . '/')) {
            Http::abort(404, 'errors/404');

            return;
        }

        $relative = '/' . trim(substr($path, strlen(self::PREFIX)), '/');

        if (preg_match('#^/([^/]+)(/.*)?$#', $relative, $matches) !== 1) {
            Http::abort(404, 'errors/404');

            return;
        }

        $locale = CustomerI18n::canonical($matches[1]);

        if ($locale === null) {
            Http::abort(404, 'errors/404');

            return;
        }

        CustomerI18n::boot($locale);

        $section = trim((string) ($matches[2] ?? ''), '/');
        $method = strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'));

        $this->route($section, $method);
    }

    private function route(string $section, string $method): void
    {
        if ($section === '') {
            if ($method !== 'GET') {
                Http::abort(404, 'errors/404');

                return;
            }

            HomeController::index();

            return;
        }

        if ($section === 'login') {
            $method === 'POST' ? AuthController::loginSubmit() : AuthController::login();

            return;
        }

        if ($section === 'logout') {
            if ($method !== 'POST') {
                Http::abort(404, 'errors/404');

                return;
            }

            AuthController::logoutSubmit();

            return;
        }

        if ($section === 'forgot') {
            $method === 'POST' ? AuthController::forgotSubmit() : AuthController::forgot();

            return;
        }

        if (preg_match('#^reset/([^/]+)$#', $section, $m) === 1) {
            $token = (string) $m[1];
            $method === 'POST' ? AuthController::resetSubmit($token) : AuthController::reset($token);

            return;
        }

        if (preg_match('#^invitations/([^/]+)$#', $section, $m) === 1) {
            $token = (string) $m[1];
            $method === 'POST' ? InvitationController::acceptSubmit($token) : InvitationController::show($token);

            return;
        }

        if ($section === 'organizations') {
            if ($method !== 'GET') {
                Http::abort(404, 'errors/404');

                return;
            }

            OrganizationController::index();

            return;
        }

        if ($section === 'organizations/switch') {
            if ($method !== 'POST') {
                Http::abort(404, 'errors/404');

                return;
            }

            OrganizationController::switchSubmit();

            return;
        }

        if ($section === 'organizations/update') {
            if ($method !== 'POST') {
                Http::abort(404, 'errors/404');

                return;
            }

            OrganizationController::updateSubmit();

            return;
        }

        if ($section === 'members') {
            if ($method !== 'GET') {
                Http::abort(404, 'errors/404');

                return;
            }

            MemberController::index();

            return;
        }

        if ($section === 'members/invite') {
            if ($method !== 'POST') {
                Http::abort(404, 'errors/404');

                return;
            }

            MemberController::inviteSubmit();

            return;
        }

        if ($section === 'members/role') {
            if ($method !== 'POST') {
                Http::abort(404, 'errors/404');

                return;
            }

            MemberController::roleSubmit();

            return;
        }

        if ($section === 'members/revoke') {
            if ($method !== 'POST') {
                Http::abort(404, 'errors/404');

                return;
            }

            MemberController::revokeSubmit();

            return;
        }

        if ($section === 'credentials') {
            if ($method !== 'GET') {
                Http::abort(404, 'errors/404');

                return;
            }

            CredentialController::index();

            return;
        }

        $credentialActions = [
            'credentials/create' => 'createSubmit',
            'credentials/rotate' => 'rotateSubmit',
            'credentials/revoke' => 'revokeSubmit',
        ];
        if (isset($credentialActions[$section])) {
            if ($method !== 'POST') {
                Http::abort(404, 'errors/404');

                return;
            }

            CredentialController::{$credentialActions[$section]}();

            return;
        }

        if ($section === 'servicios') {
            if ($method !== 'GET') {
                Http::abort(404, 'errors/404');

                return;
            }

            ServiceController::index();

            return;
        }

        $serviceActions = [
            'servicios/request' => 'requestSubmit',
            'servicios/contrato' => 'contractSubmit',
            'servicios/entitlement' => 'entitlementSubmit',
            'servicios/payment' => 'verifyPaymentSubmit',
            'servicios/activate' => 'activateSubmit',
            'servicios/status' => 'statusSubmit',
        ];
        if (isset($serviceActions[$section])) {
            if ($method !== 'POST') {
                Http::abort(404, 'errors/404');

                return;
            }

            ServiceController::{$serviceActions[$section]}();

            return;
        }

        Http::abort(404, 'errors/404');
    }
}
