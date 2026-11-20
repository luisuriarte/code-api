<?php

declare(strict_types=1);

namespace OrigenSalud\Portal;

use OrigenSalud\Portal\Admin\AdminGuard;
use OrigenSalud\Portal\Controllers\AboutController;
use OrigenSalud\Portal\Controllers\AdminAuthController;
use OrigenSalud\Portal\Controllers\AdminContextController;
use OrigenSalud\Portal\Controllers\AdminHomeController;
use OrigenSalud\Portal\Controllers\AdminInvitationController;
use OrigenSalud\Portal\Controllers\AdminMembershipController;
use OrigenSalud\Portal\Controllers\AdminOrganizationController;
use OrigenSalud\Portal\Controllers\AdminUvrController;
use OrigenSalud\Portal\Controllers\BrowseController;
use OrigenSalud\Portal\Controllers\ContactController;
use OrigenSalud\Portal\Controllers\DentarController;
use OrigenSalud\Portal\Controllers\HomeController;
use OrigenSalud\Web\I18n;

/**
 * Enrutador del portal. Resuelve /{locale}/{sección} y mantiene redirecciones
 * legacy mientras se migran las páginas existentes.
 */
final class Router
{
    public function dispatch(): void
    {
        $path = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH);
        $path = is_string($path) && $path !== '' ? $path : '/';

        // Fallback para instalaciones donde el rewrite de /docs y /uvr no está
        // activo: las páginas standalone se sirven igual desde el front controller.
        if ($path === '/docs' || $path === '/uvr') {
            $standalone = dirname(__DIR__) . '/web/' . ($path === '/docs' ? 'docs.php' : 'uvr.php');
            if (is_file($standalone)) {
                require $standalone;
                exit;
            }
        }

        // Panel de administración (Fase 1). Va antes del router localized:
        // /admin no lleva prefijo de idioma y tiene guardias propias.
        if ($path === '/admin' || str_starts_with($path, '/admin/')) {
            $this->admin($path);

            return;
        }

        if ($path === '/') {
            $this->redirect('/' . I18n::DEFAULT_LOCALE . '/');

            return;
        }

        if (preg_match('#^/([^/]+)(/.*)?$#', $path, $matches) !== 1) {
            $this->notFound();

            return;
        }

        $locale = I18n::canonical($matches[1]);

        if ($locale === null) {
            $this->notFound();

            return;
        }

        I18n::boot($locale);

        $section = trim((string) ($matches[2] ?? ''), '/');
        $currentPath = '/' . $locale . '/' . ($section === '' ? '' : $section);

        $this->route($locale, $section, $currentPath);
    }

    private function route(string $locale, string $section, string $currentPath): void
    {
        if ($section === '') {
            HomeController::index($locale, $currentPath);

            return;
        }

        if ($section === 'docs') {
            $this->legacy('/docs', $locale);

            return;
        }

        if ($section === 'dentar') {
            DentarController::index($locale, $currentPath);

            return;
        }

        if ($section === 'browse') {
            BrowseController::index($locale, $currentPath);

            return;
        }

        if (str_starts_with($section, 'browse/')) {
            $id = substr($section, strlen('browse/'));

            if ($id === '' || str_contains($id, '/')) {
                $this->notFound($locale, $currentPath);

                return;
            }

            BrowseController::detail($locale, $currentPath, $id);

            return;
        }

        if ($section === 'about') {
            AboutController::index($locale, $currentPath);

            return;
        }

        if ($section === 'contact') {
            $this->contact($locale, $currentPath);

            return;
        }

        if ($section === 'contact/send') {
            if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
                $this->notFound($locale, $currentPath);

                return;
            }

            ContactController::submit($locale);

            return;
        }

        $this->notFound($locale, $currentPath);
    }

    /** Rutas del panel: /admin, /admin/login, /admin/forgot, /admin/reset, /admin/audit, /admin/logout. */
    private function admin(string $path): void
    {
        AdminGuard::requireSecure();
        I18n::boot();

        $section = trim(substr($path, strlen('/admin')), '/');
        $method = strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'));

        if ($section === '') {
            if ($method !== 'GET') {
                $this->notFound(I18n::locale(), $path);

                return;
            }

            // El panel exige sesión válida; AdminGuard redirige a /admin/login.
            AdminHomeController::index();

            return;
        }

        if ($section === 'login') {
            if ($method === 'POST') {
                AdminAuthController::loginSubmit();

                return;
            }

            AdminAuthController::login();

            return;
        }

        if ($section === 'logout') {
            if ($method !== 'POST') {
                $this->notFound(I18n::locale(), $path);

                return;
            }

            AdminAuthController::logout();

            return;
        }

        if ($section === 'forgot') {
            if ($method === 'POST') {
                AdminAuthController::forgotSubmit();

                return;
            }

            AdminAuthController::forgot();

            return;
        }

        if ($section === 'reset') {
            if ($method === 'POST') {
                AdminAuthController::resetSubmit();

                return;
            }

            AdminAuthController::reset();

            return;
        }

        if ($section === 'audit' && $method === 'GET') {
            AdminHomeController::audit();

            return;
        }

        // Gobernanza (M2): rutas con identificadores y acciones.
        $segments = $section === '' ? [] : explode('/', $section);

        if ($this->governance($segments, $method, $path)) {
            return;
        }

        $this->notFound(I18n::locale(), $path);
    }

    /**
     * @param list<string> $segments
     */
    private function governance(array $segments, string $method, string $path): bool
    {
        $count = count($segments);
        $first = $segments[0] ?? '';
        $id = isset($segments[1]) && ctype_digit($segments[1]) ? (int) $segments[1] : 0;

        if ($this->uvr($segments, $method)) {
            return true;
        }

        if ($first === 'organizations' && $id > 0) {
            if ($count === 2) {
                if ($method === 'GET') {
                    AdminOrganizationController::show($id);

                    return true;
                }

                if ($method === 'POST') {
                    AdminOrganizationController::update($id);

                    return true;
                }

                return false;
            }

            if ($count === 3 && $method === 'POST') {
                $action = $segments[2];

                if ($action === 'deactivate') {
                    AdminOrganizationController::deactivate($id);

                    return true;
                }

                if ($action === 'reactivate') {
                    AdminOrganizationController::reactivate($id);

                    return true;
                }

                if ($action === 'members') {
                    AdminOrganizationController::assignMember($id);

                    return true;
                }
            }

            return false;
        }

        if ($first === 'organizations' && $count === 1) {
            if ($method === 'GET') {
                AdminOrganizationController::index();

                return true;
            }

            if ($method === 'POST') {
                AdminOrganizationController::store();

                return true;
            }

            return false;
        }

        if ($first === 'invitations' && $id > 0 && $count === 3 && $method === 'POST') {
            if ($segments[2] === 'resend') {
                AdminInvitationController::resend($id);

                return true;
            }

            if ($segments[2] === 'revoke') {
                AdminInvitationController::revoke($id);

                return true;
            }

            return false;
        }

        if ($first === 'invitations' && $count === 1) {
            if ($method === 'GET') {
                AdminInvitationController::index();

                return true;
            }

            if ($method === 'POST') {
                AdminInvitationController::store();

                return true;
            }

            return false;
        }

        if ($first === 'invite' && $count === 1 && $method === 'GET') {
            AdminInvitationController::showAccept();

            return true;
        }

        if ($first === 'invite' && $count === 2 && $segments[1] === 'accept' && $method === 'POST') {
            AdminInvitationController::accept();

            return true;
        }

        if ($first === 'memberships' && $id > 0 && $count === 3
            && $segments[2] === 'status' && $method === 'POST'
        ) {
            AdminMembershipController::status($id);

            return true;
        }

        if ($first === 'grants' && $id > 0 && $count === 2 && $method === 'POST') {
            AdminMembershipController::grant($id);

            return true;
        }

        if ($first === 'context' && $count === 1 && $method === 'POST') {
            AdminContextController::switch();

            return true;
        }

        return false;
    }

    /**
     * Gobernanza UVR (vistas A–G). Todas las rutas cuelgan de /admin y pasan
     * por AdminGuard en el controlador; no se crean rutas /v1 ni /fhir.
     *
     * @param list<string> $segments
     */
    private function uvr(array $segments, string $method): bool
    {
        $count = count($segments);

        if (($segments[0] ?? '') !== 'uvr') {
            return false;
        }

        $second = $segments[1] ?? '';
        $third = $segments[2] ?? '';
        $fourth = $segments[3] ?? '';
        $secondId = ctype_digit($second) ? (int) $second : 0;
        $thirdId = ctype_digit($third) ? (int) $third : 0;

        if ($count === 1 && $method === 'GET') {
            AdminUvrController::index();

            return true;
        }

        $staticViews = [
            'catalogs' => 'catalogs',
            'tasks' => 'tasks',
            'compare' => 'compare',
            'methodologies' => 'methodologies',
            'monetary' => 'monetary',
        ];

        if ($count === 2 && $method === 'GET' && isset($staticViews[$second])) {
            $action = $staticViews[$second];
            AdminUvrController::$action();

            return true;
        }

        if ($second === 'proposals') {
            if ($count === 2) {
                if ($method === 'GET') {
                    AdminUvrController::proposals();

                    return true;
                }

                if ($method === 'POST') {
                    AdminUvrController::propose();

                    return true;
                }

                return false;
            }

            if ($thirdId > 0 && $count === 3 && $method === 'GET') {
                AdminUvrController::proposal($thirdId);

                return true;
            }

            if ($thirdId > 0 && $count === 4 && $method === 'POST') {
                if ($fourth === 'review') {
                    AdminUvrController::review($thirdId);

                    return true;
                }

                if ($fourth === 'decide') {
                    AdminUvrController::decide($thirdId);

                    return true;
                }
            }

            return false;
        }

        if ($second === 'valuations' && $thirdId > 0 && $count === 4
            && $fourth === 'publish' && $method === 'POST'
        ) {
            AdminUvrController::publish($thirdId);

            return true;
        }

        return false;
    }

    private function contact(string $locale, string $currentPath): void
    {
        if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
            ContactController::submit($locale);

            return;
        }

        ContactController::index($locale, $currentPath);
    }

    /** Redirección temporal a las vistas legacy aún no migradas. */
    private function legacy(string $target, string $locale): void
    {
        $query = $_GET;
        $query['lang'] = $locale;
        $suffix = http_build_query($query, '', '&', PHP_QUERY_RFC3986);

        $this->redirect($target . ($suffix === '' ? '' : '?' . $suffix));
    }

    private function redirect(string $target, int $status = 302): void
    {
        header('Location: ' . $target, true, $status);
        exit;
    }

    private function notFound(?string $locale = null, string $currentPath = '/'): void
    {
        $locale ??= I18n::DEFAULT_LOCALE;

        if (I18n::locale() !== $locale) {
            I18n::boot($locale);
        }

        http_response_code(404);
        View::render('errors/404', [
            'locale' => $locale,
            'currentPath' => $currentPath,
            'pageTitle' => 'Página no encontrada',
            'pageDescription' => 'La página solicitada no existe.',
        ]);
    }
}
