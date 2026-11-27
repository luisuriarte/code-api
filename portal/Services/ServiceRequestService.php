<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Services;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\Repositories\PublicServiceRequestRepository;
use OrigenSalud\Portal\Repositories\RepositoryException;

/**
 * Flujo público de Solicitud de Servicios (Etapa 10).
 *
 * No crea cuentas técnicas, clientes comerciales, presupuestos, facturas ni
 * pagos. Los importes se validan contra Invoice Ninja en servidor y nunca se
 * guardan en PostgreSQL. Toda la interfaz usa claves i18n.
 */
final class ServiceRequestService
{
    private const SELECTION_KEY = 'service_request.selection';
    private const DUPLICATE_WINDOW_DAYS = 30;
    private const MAX_ITEMS = 20;
    private const MAX_QUANTITY = 20;

    /** @return array{ok: bool, error: ?string, reference: ?string, fields: array<string, string>, notification: ?string} */
    public static function submit(array $post, string $locale): array
    {
        $organization = Validator::text($post['organization'] ?? '', 160);
        $contactName = Validator::text($post['contact_name'] ?? '', 120);
        $email = Validator::email($post['email'] ?? '');
        $country = Validator::text($post['country'] ?? '', 100);
        $taxId = self::normalizeTaxId(Validator::text($post['tax_id'] ?? '', 64));
        $note = Validator::text($post['note'] ?? '', 2000);
        $website = Validator::text($post['website'] ?? '', 255);
        $createdAt = Validator::text($post['created_at'] ?? '', 64);
        $terms = isset($post['terms']) && (string) $post['terms'] === '1';

        $fields = [
            'organization' => $organization,
            'contact_name' => $contactName,
            'email' => $email,
            'country' => $country,
            'tax_id' => $taxId,
            'note' => $note,
        ];

        if (!Csrf::valid(isset($post[Csrf::FIELD]) && is_string($post[Csrf::FIELD]) ? $post[Csrf::FIELD] : null)) {
            return self::failure('csrf_error', $fields);
        }

        if ($website !== '' || $createdAt === '' || !ctype_digit($createdAt) || time() - (int) $createdAt < 3) {
            return self::failure('spam_error', $fields);
        }

        if ($organization === '' || $contactName === '' || $email === '' || !$terms) {
            return self::failure('validation_required', $fields);
        }

        $limits = Config::rateLimits();
        if (!RateLimiter::hit('request', (int) $limits['request'], (int) $limits['window'])) {
            return self::failure('rate_error', $fields);
        }

        $catalogService = new InvoiceNinjaCatalogService();
        if (!$catalogService->available()) {
            return self::failure('catalog_unavailable', $fields);
        }

        $products = $catalogService->products();
        $selection = self::selection();
        if ($selection === []) {
            return self::failure('invalid_selection', $fields);
        }

        $items = [];
        foreach ($selection as $id => $quantity) {
            if (!isset($products[$id]) || $quantity < 1 || $quantity > self::MAX_QUANTITY) {
                return self::failure('invalid_selection', $fields);
            }
            $items[] = [
                'id' => (string) $id,
                'label' => (string) $products[$id]['label'],
                'quantity' => $quantity,
                'price' => $products[$id]['price'],
                'currency' => $products[$id]['currency'] ?? null,
                'periodicity' => $products[$id]['periodicity'] ?? null,
                'tax' => $products[$id]['tax'] ?? null,
                'billing' => $products[$id]['billing'] ?? null,
            ];
            if (count($items) > self::MAX_ITEMS) {
                return self::failure('invalid_selection', $fields);
            }
        }

        if (!PublicServiceRequestRepository::available()) {
            return self::failure('database_unavailable', $fields);
        }

        $dedupeSource = $taxId !== ''
            ? $taxId
            : strtolower($organization . '|' . $email);
        $dedupeKey = hash('sha256', $dedupeSource);
        try {
            $duplicate = PublicServiceRequestRepository::findRecent($dedupeKey, self::DUPLICATE_WINDOW_DAYS);
        } catch (RepositoryException) {
            return self::failure('database_unavailable', $fields);
        }

        $clientMatch = $catalogService->findClients($taxId, $organization, $email);
        $ninjaStatus = (string) $clientMatch['status'];

        // Sin matching validado contra la versión instalada, ninguna
        // clasificación automática puede considerarse confiable.
        $status = 'received';
        if ($duplicate !== null || $ninjaStatus !== 'exact') {
            $status = 'needs_review';
        }

        $reference = 'SR-' . gmdate('Ymd') . '-' . strtoupper(substr(
            hash('sha256', $email . '|' . microtime(true) . '|' . bin2hex(random_bytes(8))),
            0,
            8
        ));

        try {
            $requestId = PublicServiceRequestRepository::create([
                'reference' => $reference,
                'locale' => $locale,
                'organization_name' => $organization,
                'contact_name' => $contactName,
                'contact_email' => $email,
                'country' => $country,
                'tax_id_normalized' => $taxId,
                'dedupe_key' => $dedupeKey,
                'note' => $note,
                'status' => $status,
                'ninja_client_status' => $ninjaStatus,
                'duplicate_of' => $duplicate['id'] ?? null,
            ]);
            foreach ($items as $item) {
                PublicServiceRequestRepository::addItem($requestId, (string) $item['id'], (int) $item['quantity']);
            }
        } catch (RepositoryException) {
            return self::failure('database_unavailable', $fields);
        }

        $notification = self::notify(
            $locale,
            $reference,
            $organization,
            $contactName,
            $email,
            $country,
            $taxId,
            $note,
            $items
        );

        // La solicitud ya quedó registrada: se limpia la selección y se rota el
        // token para evitar reenvíos duplicados, informando el estado real.
        self::clearSelection();
        Csrf::rotate();

        return [
            'ok' => true,
            'error' => null,
            'reference' => $reference,
            'fields' => [],
            'notification' => $notification,
        ];
    }

    /** @return array<string, int> Identificador de producto => cantidad. */
    public static function selection(): array
    {
        $stored = Session::get(self::SELECTION_KEY, []);
        if (!is_array($stored)) {
            return [];
        }

        $selection = [];
        foreach ($stored as $id => $quantity) {
            // Los identificadores numéricos de Invoice Ninja llegan como claves
            // enteras en PHP; se normalizan a string para no perderlos.
            $id = (string) $id;
            if ($id === '') {
                continue;
            }
            $selection[$id] = max(1, min(self::MAX_QUANTITY, (int) $quantity));
        }

        return $selection;
    }

    public static function addToSelection(string $id, int $quantity): void
    {
        if ($id === '' || strlen($id) > 64 || $quantity < 1) {
            return;
        }

        $selection = self::selection();
        if (!isset($selection[$id]) && count($selection) >= self::MAX_ITEMS) {
            return;
        }

        $current = isset($selection[$id]) ? (int) $selection[$id] : 0;
        // «Agregar» suma al producto ya seleccionado, con tope por producto.
        $selection[$id] = max(1, min(self::MAX_QUANTITY, $current + $quantity));

        Session::set(self::SELECTION_KEY, $selection);
    }

    public static function removeFromSelection(string $id): void
    {
        $selection = self::selection();
        unset($selection[$id]);
        Session::set(self::SELECTION_KEY, $selection);
    }

    public static function removeOneFromSelection(string $id): void
    {
        $selection = self::selection();
        if (!isset($selection[$id])) {
            return;
        }

        $selection[$id]--;
        if ($selection[$id] < 1) {
            unset($selection[$id]);
        }

        Session::set(self::SELECTION_KEY, $selection);
    }

    public static function clearSelection(): void
    {
        Session::set(self::SELECTION_KEY, []);
    }

    private static function normalizeTaxId(string $value): string
    {
        return strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $value) ?? '');
    }

    /**
     * @param list<array<string, mixed>> $items
     * @return string `sent`, `partial` o `failed`
     */
    private static function notify(
        string $locale,
        string $reference,
        string $organization,
        string $contactName,
        string $email,
        string $country,
        string $taxId,
        string $note,
        array $items
    ): string {
        $t = static fn (string $key): string => trans('service_request.email_' . $key, [], $locale);
        $subject = $t('subject') . ' — ' . $reference . ' (' . $locale . ')';

        $currencies = array_values(array_unique(array_filter(
            array_column($items, 'currency'),
            static fn (mixed $value): bool => is_string($value) && $value !== ''
        )));
        $currency = count($currencies) === 1 ? (string) $currencies[0] : null;

        $lines = [
            $t('reference') . ': ' . $reference,
            $t('organization') . ': ' . $organization,
            $t('contact') . ': ' . $contactName,
            $t('email') . ': ' . $email,
            $t('country') . ': ' . ($country !== '' ? $country : '-'),
            $t('tax_id') . ': ' . ($taxId !== '' ? $taxId : '-'),
            '',
            $t('items') . ':',
        ];
        $total = 0.0;
        foreach ($items as $item) {
            $price = $item['price'];
            $priceText = $price === null
                ? $t('quote_only')
                : number_format((float) $price, 2, ',', '.') . ($currency !== null ? ' ' . $currency : '');
            if ($price !== null) {
                $total += (float) $price * (int) $item['quantity'];
            }

            $line = '- ' . (string) $item['quantity'] . ' × ' . (string) $item['label'] . ' — ' . $priceText;
            $details = [];
            $billing = $item['billing'] ?? null;
            if ($billing === 'one_time' || $billing === 'recurring') {
                $details[] = trans('service_request.billing_' . $billing, [], $locale);
            }
            foreach (['periodicity', 'tax'] as $key) {
                $value = $item[$key] ?? null;
                if (is_string($value) && $value !== '') {
                    $details[] = $value;
                }
            }
            if ($details !== []) {
                $line .= ' (' . implode('; ', $details) . ')';
            }
            $lines[] = $line;
        }
        $lines[] = $t('estimated_total') . ': ' . number_format($total, 2, ',', '.')
            . ($currency !== null ? ' ' . $currency : '');
        $lines[] = $t('total_note');
        $lines[] = '';
        $lines[] = $t('notes') . ': ' . ($note !== '' ? $note : '-');

        $textBody = implode("\n", $lines);
        $htmlBody = nl2br(e($textBody), false);

        $internal = SmtpMailer::send(
            Config::contactEmail(),
            $subject,
            $textBody,
            $htmlBody,
            $email,
            Config::contactBcc()
        );

        $confirmationText = trans('service_request.email_confirmation_text', ['%reference%' => $reference], $locale);
        $confirmation = SmtpMailer::send(
            $email,
            trans('service_request.email_confirmation_subject', ['%reference%' => $reference], $locale),
            $confirmationText,
            nl2br(e($confirmationText), false)
        );

        if ($internal['ok'] && $confirmation['ok']) {
            return 'sent';
        }

        $reason = $internal['ok'] ? 'confirmation' : 'internal';
        error_log('service request mail failed (' . $reason . '): reference=' . $reference
            . ' error=' . (string) ($internal['ok'] ? ($confirmation['error'] ?? 'unknown') : ($internal['error'] ?? 'unknown')));

        return $internal['ok'] || $confirmation['ok'] ? 'partial' : 'failed';
    }

    /**
     * @param array<string, string> $fields
     * @return array{ok: bool, error: ?string, reference: ?string, fields: array<string, string>, notification: ?string}
     */
    private static function failure(string $error, array $fields): array
    {
        return [
            'ok' => false,
            'error' => $error,
            'reference' => null,
            'fields' => $fields,
            'notification' => null,
        ];
    }
}
