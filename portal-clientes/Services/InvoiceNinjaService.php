<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

use OrigenSalud\CustomerPortal\Config;
use OrigenSalud\CustomerPortal\Repositories\AuditRepository;
use OrigenSalud\CustomerPortal\Repositories\InvoiceNinjaLinkRepository;
use OrigenSalud\CustomerPortal\Services\InvoiceNinja\HttpInvoiceNinjaTransport;
use OrigenSalud\CustomerPortal\Services\InvoiceNinja\MockInvoiceNinjaTransport;
use OrigenSalud\CustomerPortal\Services\InvoiceNinja\InvoiceNinjaTransport;

/**
 * Integración de solo lectura con Invoice Ninja (Etapa 6).
 *
 * Reglas cumplidas:
 * - Invoice Ninja sigue siendo la fuente de verdad comercial.
 * - No crea clientes, contactos, presupuestos, facturas ni pagos.
 * - No guarda precios, razones sociales ni correos en las tablas de vínculo.
 * - El correo nunca es criterio único de identidad.
 * - Ante coincidencia ambigua exige revisión administrativa.
 * - Modo `mock` por defecto: sin llamadas HTTP.
 */
final class InvoiceNinjaService
{
    private InvoiceNinjaTransport $transport;
    private bool $httpEnabled;

    public function __construct(?InvoiceNinjaTransport $transport = null)
    {
        $config = Config::invoiceNinja();
        $this->httpEnabled = Config::invoiceNinjaHttpEnabled();

        if ($transport instanceof InvoiceNinjaTransport) {
            $this->transport = $transport;
        } elseif ($this->httpEnabled) {
            $this->transport = new HttpInvoiceNinjaTransport(
                $config['base_url'],
                $config['api_prefix'],
                $config['token'],
                $config['timeout'],
                $config['retries']
            );
        } else {
            $this->transport = new MockInvoiceNinjaTransport();
        }
    }

    public function mode(): string
    {
        return $this->httpEnabled ? 'http' : 'mock';
    }

    /**
     * Busca candidatos y decide si existe un vínculo seguro.
     *
     * @param list<string> $contactEmails
     * @return array{
     *     status: string,
     *     candidates: list<array<string, mixed>>,
     *     reason: ?string,
     *     review_id: ?int,
     *     link_id: ?int
     * }
     */
    public function findMatches(
        int $organizationId,
        string $taxIdNormalized,
        string $legalName,
        array $contactEmails,
        ?int $actorUserId = null
    ): array {
        $empty = [
            'status' => 'error',
            'candidates' => [],
            'reason' => null,
            'review_id' => null,
            'link_id' => null,
        ];

        if (CustomerDatabase::available()) {
            $existing = InvoiceNinjaLinkRepository::findLink($organizationId);
            if (is_array($existing) && ($existing['status'] ?? '') === 'active') {
                return [
                    'status' => 'linked',
                    'candidates' => [],
                    'reason' => 'existing_link',
                    'review_id' => null,
                    'link_id' => (int) ($existing['id'] ?? 0),
                ];
            }
        }

        $queries = [];
        if ($taxIdNormalized !== '') {
            $queries['tax_id'] = $taxIdNormalized;
        }
        if ($legalName !== '') {
            $queries['legal_name'] = $legalName;
        }

        $emails = [];
        foreach ($contactEmails as $email) {
            $email = strtolower(trim($email));
            if (filter_var($email, FILTER_VALIDATE_EMAIL) !== false && count($emails) < 5) {
                $emails[hash('sha256', $email)] = $email;
            }
        }

        $candidates = [];
        $criteriaUsed = [];
        foreach ($queries as $key => $value) {
            $response = $this->transport->get('/clients', [$key => $value]);
            if (!$response['ok']) {
                return [
                    'status' => 'error',
                    'candidates' => [],
                    'reason' => (string) ($response['error'] ?? 'transport_error'),
                    'review_id' => null,
                    'link_id' => null,
                ];
            }
            $criteriaUsed[] = $key;
            $this->collect($response['data'] ?? [], $candidates, $key);
        }

        foreach ($emails as $email) {
            $response = $this->transport->get('/clients', ['email' => $email]);
            if (!$response['ok']) {
                $empty['reason'] = (string) ($response['error'] ?? 'transport_error');

                return $empty;
            }
            $criteriaUsed[] = 'contact_email';
            $this->collect($response['data'] ?? [], $candidates, 'contact');
        }

        if ($candidates === []) {
            return [
                'status' => 'none',
                'candidates' => [],
                'reason' => 'no_match',
                'review_id' => null,
                'link_id' => null,
            ];
        }

        $ids = array_keys($candidates);
        $decision = self::classify($candidates, $criteriaUsed);
        $ambiguous = $decision['status'] === 'needs_review';

        if (!$ambiguous && CustomerDatabase::available()) {
            $clientId = (string) ($candidates[$ids[0]]['id'] ?? '');
            if ($clientId !== '') {
                $link = InvoiceNinjaLinkRepository::createLink(
                    $organizationId,
                    $clientId,
                    (string) ($candidates[$ids[0]]['matched_by'] ?? 'manual'),
                    'exact',
                    $actorUserId
                );
                AuditRepository::record(
                    $actorUserId,
                    $organizationId,
                    'invoice_ninja.link_created',
                    'invoice_ninja_client_link',
                    $clientId,
                    'success',
                    ['criteria' => array_values(array_unique($criteriaUsed))]
                );

                return [
                    'status' => 'exact',
                    'candidates' => array_values($candidates),
                    'reason' => 'exact_match',
                    'review_id' => null,
                    'link_id' => is_array($link) ? (int) ($link['id'] ?? 0) : null,
                ];
            }
        }

        if ($ambiguous && CustomerDatabase::available()) {
            $review = InvoiceNinjaLinkRepository::createReview(
                $organizationId,
                count($ids) === 1 ? (string) ($candidates[$ids[0]]['id'] ?? '') : null,
                null,
                count($ids) > 1 ? 'manual' : 'contact_email',
                $actorUserId
            );
            AuditRepository::record(
                $actorUserId,
                $organizationId,
                'invoice_ninja.review_requested',
                'invoice_ninja_duplicate_review',
                is_array($review) ? (string) ($review['id'] ?? '') : null,
                'success',
                ['status' => 'needs_review', 'criteria' => array_values(array_unique($criteriaUsed)), 'candidate_count' => count($ids)]
            );

            return [
                'status' => 'needs_review',
                'candidates' => array_values($candidates),
                'reason' => $decision['reason'],
                'review_id' => is_array($review) ? (int) ($review['id'] ?? 0) : null,
                'link_id' => null,
            ];
        }

        return [
            'status' => $decision['status'],
            'candidates' => array_values($candidates),
            'reason' => CustomerDatabase::available() ? $decision['reason'] : 'database_unavailable',
            'review_id' => null,
            'link_id' => null,
        ];
    }

    /**
     * Decisión pura, sin acceso a base ni a red. El correo nunca basta por sí solo.
     *
     * @param array<string, array<string, mixed>> $candidates
     * @param list<string> $criteriaUsed
     * @return array{status: string, reason: string}
     */
    public static function classify(array $candidates, array $criteriaUsed): array
    {
        if ($candidates === []) {
            return ['status' => 'none', 'reason' => 'no_match'];
        }

        $ids = array_keys($candidates);
        $onlyEmail = $criteriaUsed === ['contact_email'];

        if (count($ids) > 1) {
            return ['status' => 'needs_review', 'reason' => 'multiple_candidates'];
        }
        if ($onlyEmail) {
            return ['status' => 'needs_review', 'reason' => 'email_only_match'];
        }

        return ['status' => 'exact', 'reason' => 'exact_match'];
    }

    /**
     * @param array<string, mixed> $response
     * @param array<string, array<string, mixed>> $candidates
     */
    private function collect(array $response, array &$candidates, string $matchedBy): void
    {
        $rows = $response['data'] ?? [];
        if (!is_array($rows)) {
            return;
        }

        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }
            $id = (string) ($row['id'] ?? '');
            if ($id === '') {
                continue;
            }
            if (!isset($candidates[$id])) {
                $candidates[$id] = [
                    'id' => $id,
                    'tax_id_normalized' => (string) ($row['tax_id_normalized'] ?? ''),
                    'legal_name' => (string) ($row['legal_name'] ?? ''),
                    'matched_by' => $matchedBy,
                ];
            }
        }
    }

    /**
     * Resuelve una revisión pendiente. No crea clientes ni facturas.
     *
     * @return array<string, mixed>|null
     */
    public function resolveReview(
        int $reviewId,
        string $decision,
        ?int $reviewerUserId,
        ?string $note
    ): ?array {
        if (!in_array($decision, ['approved', 'rejected', 'discarded'], true)) {
            return null;
        }
        if (!CustomerDatabase::available()) {
            return null;
        }

        $resolved = InvoiceNinjaLinkRepository::resolveReview($reviewId, $decision, $reviewerUserId, $note);
        if (is_array($resolved)) {
            AuditRepository::record(
                $reviewerUserId,
                (int) ($resolved['organization_id'] ?? 0),
                'invoice_ninja.review_resolved',
                'invoice_ninja_duplicate_review',
                (string) $reviewId,
                $decision === 'approved' ? 'success' : 'denied',
                ['decision' => $decision]
            );
        }

        return $resolved;
    }
}
