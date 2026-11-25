<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Controllers;

use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Repositories\AuditRepository;
use OrigenSalud\CustomerPortal\Repositories\ContractRepository;
use OrigenSalud\CustomerPortal\Repositories\EntitlementRepository;
use OrigenSalud\CustomerPortal\Repositories\OrganizationRepository;
use OrigenSalud\CustomerPortal\Repositories\ServiceCatalogRepository;
use OrigenSalud\CustomerPortal\Repositories\ServiceRequestRepository;
use OrigenSalud\CustomerPortal\Services\AccessControl;
use OrigenSalud\CustomerPortal\Services\CustomerCsrf;
use OrigenSalud\CustomerPortal\Services\CustomerSession;
use OrigenSalud\CustomerPortal\Services\EntitlementService;
use OrigenSalud\CustomerPortal\Services\Http;
use OrigenSalud\CustomerPortal\View;

/** Etapa 7: catálogo, solicitudes y habilitaciones administradas. */
final class ServiceController
{
    public static function index(): void
    {
        $current = AccessControl::requireUser();
        $userId = (int) $current['user_id'];
        $organizationId = AccessControl::organizationId($current);
        $isSuperAdmin = AccessControl::isSuperAdmin($userId);

        $data = [
            'title' => CustomerI18n::t('customer.service.title'),
            'catalog' => ServiceCatalogRepository::available(),
            'is_super_admin' => $isSuperAdmin,
            'organization_id' => $organizationId,
            'entitlements' => [],
            'requests' => [],
            'pending' => [],
            'operator_entitlements' => [],
            'organizations' => [],
            'can_request' => false,
        ];

        if ($organizationId !== null) {
            $data['entitlements'] = EntitlementRepository::findByOrganization($organizationId);
            $data['requests'] = ServiceRequestRepository::findByOrganization($organizationId);
            $data['can_request'] = AccessControl::can('service.request', $organizationId, $current);
        }

        if ($isSuperAdmin) {
            $data['pending'] = EntitlementRepository::findPending();
            $data['operator_entitlements'] = EntitlementRepository::findForOperator();
            $data['organizations'] = OrganizationRepository::findAllActive();
        }

        View::render('services', $data);
    }

    public static function requestSubmit(): void
    {
        self::assertPost();

        $context = AccessControl::requirePermission('service.request');
        $post = Http::post();
        // Http::post() solo devuelve escalares; los checkbox llegan como array en $_POST.
        $rawIds = $_POST['service_ids'] ?? [];
        $serviceIds = [];
        if (is_array($rawIds)) {
            foreach ($rawIds as $raw) {
                if (is_string($raw) || is_int($raw)) {
                    $serviceIds[] = (int) $raw;
                }
            }
        }

        $result = EntitlementService::request(
            $context['organization_id'],
            (int) $context['user']['user_id'],
            $serviceIds,
            isset($post['note']) && is_string($post['note']) ? $post['note'] : null
        );

        CustomerSession::set('flash', ['key' => $result['ok'] ? 'customer.service.created' : (string) $result['error'], 'params' => []]);
        Http::redirect(CustomerI18n::locale() . '/servicios');
    }

    public static function contractSubmit(): void
    {
        self::assertPost();
        $current = AccessControl::requireSuperAdmin();
        $post = Http::post();

        $organizationId = (int) ($post['organization_id'] ?? 0);
        $organization = $organizationId > 0 ? OrganizationRepository::findById($organizationId) : null;
        $clientRef = self::ref($post['client_ref'] ?? null);
        $itemRef = self::ref($post['item_ref'] ?? null);

        if ($organization === null || ($organization['status'] ?? '') !== 'active') {
            CustomerSession::set('flash', ['key' => 'customer.service.invalid', 'params' => []]);
            Http::redirect(CustomerI18n::locale() . '/servicios');
        }

        $contractId = ContractRepository::create($organizationId, $clientRef, $itemRef);
        AuditRepository::record(
            (int) $current['user_id'],
            $organizationId,
            'service.contract.created',
            'contract',
            (string) $contractId,
            'success'
        );
        CustomerSession::set('flash', ['key' => 'customer.service.contract_created', 'params' => []]);
        Http::redirect(CustomerI18n::locale() . '/servicios');
    }

    public static function entitlementSubmit(): void
    {
        self::assertPost();
        $current = AccessControl::requireSuperAdmin();
        $post = Http::post();

        $result = EntitlementService::createPending(
            (int) ($post['organization_id'] ?? 0),
            (int) ($post['service_id'] ?? 0),
            (int) ($post['contract_id'] ?? 0),
            isset($post['request_id']) && (int) $post['request_id'] > 0 ? (int) $post['request_id'] : null,
            (int) $current['user_id']
        );

        CustomerSession::set('flash', ['key' => $result['ok'] ? 'customer.service.entitlement_created' : (string) $result['error'], 'params' => []]);
        Http::redirect(CustomerI18n::locale() . '/servicios');
    }

    public static function verifyPaymentSubmit(): void
    {
        self::assertPost();
        $current = AccessControl::requireSuperAdmin();
        $contractId = (int) (Http::post()['contract_id'] ?? 0);
        $result = EntitlementService::verifyPayment($contractId, (int) $current['user_id']);

        CustomerSession::set('flash', ['key' => $result['ok'] ? 'customer.service.payment_verified' : (string) $result['error'], 'params' => []]);
        Http::redirect(CustomerI18n::locale() . '/servicios');
    }

    public static function activateSubmit(): void
    {
        self::assertPost();
        $current = AccessControl::requireSuperAdmin();
        $entitlementId = (int) (Http::post()['entitlement_id'] ?? 0);
        $result = EntitlementService::activate($entitlementId, (int) $current['user_id']);

        CustomerSession::set('flash', ['key' => $result['ok'] ? 'customer.service.activated' : (string) $result['error'], 'params' => []]);
        Http::redirect(CustomerI18n::locale() . '/servicios');
    }

    public static function statusSubmit(): void
    {
        self::assertPost();
        $current = AccessControl::requireSuperAdmin();
        $post = Http::post();
        $entitlementId = (int) ($post['entitlement_id'] ?? 0);
        $action = is_string($post['action'] ?? null) ? (string) $post['action'] : '';
        $reason = is_string($post['reason'] ?? null) ? $post['reason'] : null;
        $result = EntitlementService::changeStatus($entitlementId, $action, (int) $current['user_id'], $reason);

        CustomerSession::set('flash', ['key' => $result['ok'] ? 'customer.service.status_changed' : (string) $result['error'], 'params' => []]);
        Http::redirect(CustomerI18n::locale() . '/servicios');
    }

    private static function assertPost(): void
    {
        if (!Http::isPost() || !CustomerCsrf::valid(Http::post()['_csrf'] ?? null)) {
            Http::abort(400, 'errors/denied');
        }
    }

    private static function ref(mixed $value): ?string
    {
        if (!is_string($value)) {
            return null;
        }
        $value = trim($value);
        if ($value === '' || preg_match('/^[A-Za-z0-9_.:-]{1,64}$/', $value) !== 1) {
            return null;
        }

        return $value;
    }
}
