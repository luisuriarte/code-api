<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

use OrigenSalud\CustomerPortal\Repositories\AuditRepository;
use OrigenSalud\CustomerPortal\Repositories\ContractRepository;
use OrigenSalud\CustomerPortal\Repositories\EntitlementRepository;
use OrigenSalud\CustomerPortal\Repositories\OperatorRepository;
use OrigenSalud\CustomerPortal\Repositories\OrganizationRepository;
use OrigenSalud\CustomerPortal\Repositories\ServiceCatalogRepository;
use OrigenSalud\CustomerPortal\Repositories\ServiceRequestRepository;

/**
 * Reglas de la Etapa 7.
 *
 * Pago confirmado y aprobación manual son dos hechos distintos: el primero se
 * registra en el contrato y el segundo es la decisión técnica sobre la
 * habilitación. Ninguno se dispara por factura, webhook ni pago automático.
 */
final class EntitlementService
{
    /** @param list<int> $serviceIds
     *  @return array{ok: bool, id: ?int, error: ?string}
     */
    public static function request(
        int $organizationId,
        int $userId,
        array $serviceIds,
        ?string $note
    ): array {
        $services = ServiceCatalogRepository::findAvailableByIds($serviceIds);
        if ($services === []) {
            return ['ok' => false, 'id' => null, 'error' => 'customer.service.invalid'];
        }

        $cleanNote = trim($note ?? '');
        if ($cleanNote !== '' && mb_strlen($cleanNote) > 2000) {
            return ['ok' => false, 'id' => null, 'error' => 'customer.service.invalid'];
        }

        $requestId = ServiceRequestRepository::create(
            $organizationId,
            $userId,
            array_keys($services),
            $cleanNote === '' ? null : $cleanNote
        );

        AuditRepository::record(
            $userId,
            $organizationId,
            'service.request.created',
            'service_request',
            (string) $requestId,
            'success',
            ['service_ids' => array_keys($services)]
        );

        return ['ok' => true, 'id' => $requestId, 'error' => null];
    }

    /** @return array{ok: bool, id: ?int, error: ?string} */
    public static function createPending(
        int $organizationId,
        int $serviceId,
        int $contractId,
        ?int $requestId,
        int $actorUserId
    ): array {
        if (!OperatorRepository::isSuperAdmin($actorUserId)) {
            AuditRepository::record(
                $actorUserId,
                null,
                'service.entitlement.creation_denied',
                'entitlement',
                null,
                'denied'
            );

            return ['ok' => false, 'id' => null, 'error' => 'customer.service.not_superadmin'];
        }

        $organization = OrganizationRepository::findById($organizationId);
        $service = ServiceCatalogRepository::findById($serviceId);
        $contract = ContractRepository::findById($contractId);
        if (
            $organization === null || ($organization['status'] ?? '') !== 'active'
            || $service === null || ($service['status'] ?? '') !== 'available'
            || $contract === null || (int) ($contract['organization_id'] ?? 0) !== $organizationId
        ) {
            return ['ok' => false, 'id' => null, 'error' => 'customer.service.invalid'];
        }

        $entitlementId = EntitlementRepository::create(
            $organizationId,
            $serviceId,
            $contractId,
            $requestId !== null && $requestId > 0 ? $requestId : null
        );

        AuditRepository::record(
            $actorUserId,
            $organizationId,
            'service.entitlement.created',
            'entitlement',
            (string) $entitlementId,
            'success',
            ['service_code' => (string) ($service['code'] ?? ''), 'contract_id' => $contractId]
        );

        return ['ok' => true, 'id' => $entitlementId, 'error' => null];
    }

    /** @return array{ok: bool, error: ?string} */
    public static function verifyPayment(int $contractId, int $actorUserId): array
    {
        if (!OperatorRepository::isSuperAdmin($actorUserId)) {
            AuditRepository::record(
                $actorUserId,
                null,
                'service.contract.payment_verification_denied',
                'contract',
                (string) $contractId,
                'denied'
            );

            return ['ok' => false, 'error' => 'customer.service.not_superadmin'];
        }

        $contract = ContractRepository::findById($contractId);
        if ($contract === null) {
            return ['ok' => false, 'error' => 'customer.service.invalid'];
        }

        if (!ContractRepository::markPaymentVerified($contractId, $actorUserId)) {
            AuditRepository::record(
                $actorUserId,
                (int) ($contract['organization_id'] ?? 0),
                'service.contract.payment_verification_failed',
                'contract',
                (string) $contractId,
                'failure',
                ['status' => (string) ($contract['status'] ?? '')]
            );

            return ['ok' => false, 'error' => 'customer.service.invalid'];
        }

        AuditRepository::record(
            $actorUserId,
            (int) ($contract['organization_id'] ?? 0),
            'service.contract.payment_verified',
            'contract',
            (string) $contractId,
            'success',
            ['condition' => 'payment_confirmed']
        );

        return ['ok' => true, 'error' => null];
    }

    /** @return array{ok: bool, error: ?string} */
    public static function activate(int $entitlementId, int $actorUserId): array
    {
        if (!OperatorRepository::isSuperAdmin($actorUserId)) {
            AuditRepository::record(
                $actorUserId,
                null,
                'service.entitlement.activation_denied',
                'entitlement',
                (string) $entitlementId,
                'denied'
            );

            return ['ok' => false, 'error' => 'customer.service.not_superadmin'];
        }

        $entitlement = EntitlementRepository::findById($entitlementId);
        if ($entitlement === null) {
            return ['ok' => false, 'error' => 'customer.service.invalid'];
        }

        if (($entitlement['status'] ?? '') !== 'pending_activation') {
            return ['ok' => false, 'error' => 'customer.service.invalid'];
        }

        if (!ContractRepository::paymentVerified(isset($entitlement['contract_id']) ? (int) $entitlement['contract_id'] : null)) {
            AuditRepository::record(
                $actorUserId,
                (int) ($entitlement['organization_id'] ?? 0),
                'service.entitlement.activation_blocked',
                'entitlement',
                (string) $entitlementId,
                'denied',
                ['reason' => 'payment_not_verified']
            );

            return ['ok' => false, 'error' => 'customer.service.payment_required'];
        }

        if (!EntitlementRepository::activate($entitlementId, $actorUserId)) {
            AuditRepository::record(
                $actorUserId,
                (int) ($entitlement['organization_id'] ?? 0),
                'service.entitlement.activation_failed',
                'entitlement',
                (string) $entitlementId,
                'failure'
            );

            return ['ok' => false, 'error' => 'customer.service.invalid'];
        }

        AuditRepository::record(
            $actorUserId,
            (int) ($entitlement['organization_id'] ?? 0),
            'service.entitlement.activated',
            'entitlement',
            (string) $entitlementId,
            'success',
            ['service_code' => (string) ($entitlement['service_code'] ?? '')]
        );

        return ['ok' => true, 'error' => null];
    }

    /** @return array{ok: bool, error: ?string} */
    public static function changeStatus(
        int $entitlementId,
        string $action,
        int $actorUserId,
        ?string $reason
    ): array {
        if (!in_array($action, ['suspend', 'revoke', 'expire'], true)) {
            return ['ok' => false, 'error' => 'customer.service.invalid'];
        }

        if (!OperatorRepository::isSuperAdmin($actorUserId)) {
            AuditRepository::record(
                $actorUserId,
                null,
                'service.entitlement.status_denied',
                'entitlement',
                (string) $entitlementId,
                'denied',
                ['action' => $action]
            );

            return ['ok' => false, 'error' => 'customer.service.not_superadmin'];
        }

        $entitlement = EntitlementRepository::findById($entitlementId);
        if ($entitlement === null) {
            return ['ok' => false, 'error' => 'customer.service.invalid'];
        }

        $target = ['suspend' => 'suspended', 'revoke' => 'revoked', 'expire' => 'expired'][$action];
        $cleanReason = trim($reason ?? '');
        if ($cleanReason !== '' && mb_strlen($cleanReason) > 1000) {
            return ['ok' => false, 'error' => 'customer.service.invalid'];
        }

        if (!EntitlementRepository::changeStatus(
            $entitlementId,
            (string) ($entitlement['status'] ?? ''),
            $target,
            $actorUserId,
            $cleanReason === '' ? null : $cleanReason
        )) {
            AuditRepository::record(
                $actorUserId,
                (int) ($entitlement['organization_id'] ?? 0),
                'service.entitlement.status_failed',
                'entitlement',
                (string) $entitlementId,
                'failure',
                ['action' => $action]
            );

            return ['ok' => false, 'error' => 'customer.service.invalid'];
        }

        AuditRepository::record(
            $actorUserId,
            (int) ($entitlement['organization_id'] ?? 0),
            'service.entitlement.status_changed',
            'entitlement',
            (string) $entitlementId,
            'success',
            ['action' => $action, 'status' => $target]
        );

        return ['ok' => true, 'error' => null];
    }
}
