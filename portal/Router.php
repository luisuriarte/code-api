<?php

declare(strict_types=1);

namespace OrigenSalud\Portal;

use OrigenSalud\Portal\Controllers\AboutController;
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
