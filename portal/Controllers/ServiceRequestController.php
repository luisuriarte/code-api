<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Services\Csrf;
use OrigenSalud\Portal\Services\InvoiceNinjaCatalogService;
use OrigenSalud\Portal\Services\ServiceRequestService;
use OrigenSalud\Portal\Services\Session;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/**
 * Solicitud de Servicios pública: selección, resumen y envío.
 * No requiere cuenta y no crea accesos técnicos ni operaciones comerciales.
 */
final class ServiceRequestController
{
    public static function index(string $locale, string $currentPath): void
    {
        $t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
        $flash = Session::pull('service_request.flash');
        $catalogService = new InvoiceNinjaCatalogService();
        $products = $catalogService->products();

        View::render('service-request', [
            'pageTitle' => $t('service_request.title') . ' | Origen Salud',
            'pageDescription' => $t('service_request.lead'),
            'locale' => $locale,
            'currentPath' => $currentPath,
            'csrfToken' => Csrf::token(),
            'products' => array_values($products),
            'catalogAvailable' => $catalogService->available() && $products !== [],
            'selection' => ServiceRequestService::selection(),
            'form' => is_array($flash) && isset($flash['fields']) && is_array($flash['fields'])
                ? $flash['fields']
                : [],
            'flash' => is_array($flash) ? $flash : null,
        ]);
    }

    public static function add(string $locale): void
    {
        $catalogService = new InvoiceNinjaCatalogService();
        $products = $catalogService->products();
        $id = isset($_POST['product_id']) && is_string($_POST['product_id'])
            ? $_POST['product_id']
            : '';
        $quantity = filter_var(
            isset($_POST['quantity']) ? (string) $_POST['quantity'] : '1',
            FILTER_VALIDATE_INT,
            ['options' => ['min_range' => 1, 'max_range' => 20]]
        );
        $quantity = $quantity === false ? 1 : (int) $quantity;

        if (Csrf::valid(isset($_POST[Csrf::FIELD]) && is_string($_POST[Csrf::FIELD]) ? $_POST[Csrf::FIELD] : null)
            && isset($products[$id])) {
            ServiceRequestService::addToSelection($id, $quantity);
        }

        self::redirect($locale);
    }

    public static function remove(string $locale): void
    {
        $id = isset($_POST['product_id']) && is_string($_POST['product_id'])
            ? $_POST['product_id']
            : '';

        if (Csrf::valid(isset($_POST[Csrf::FIELD]) && is_string($_POST[Csrf::FIELD]) ? $_POST[Csrf::FIELD] : null)
            && $id !== '') {
            ServiceRequestService::removeFromSelection($id);
        }

        self::redirect($locale);
    }

    public static function send(string $locale): void
    {
        $result = ServiceRequestService::submit($_POST, $locale);

        Session::set('service_request.flash', [
            'ok' => $result['ok'],
            'error' => $result['error'],
            'reference' => $result['reference'],
            'fields' => $result['fields'],
            'notification' => $result['notification'],
        ]);

        self::redirect($locale, $result['ok'] ? '?sent=1' : '?error=1');
    }

    private static function redirect(string $locale, string $query = ''): void
    {
        header('Location: ' . I18n::localizedPath($locale, '/solicitud') . $query, true, 303);
        exit;
    }
}
