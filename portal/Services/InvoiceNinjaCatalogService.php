<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Services;

use OrigenSalud\Portal\Config;

/**
 * Catálogo comercial de solo lectura para la Solicitud de Servicios (Etapa 10).
 *
 * Reglas cumplidas aquí:
 * - Invoice Ninja es la fuente de verdad de productos y precios.
 * - Solo GET: nunca crea clientes, contactos, presupuestos, facturas ni pagos.
 * - El token de prueba viaja solo en cabecera, nunca en URL, HTML, logs ni errores.
 * - Los importes se calculan en servidor y no se guardan en PostgreSQL.
 * - Sin datos de prueba hardcodeados: si no hay consulta habilitada, el catálogo
 *   está vacío y la vista lo informa con un mensaje honesto.
 */
final class InvoiceNinjaCatalogService
{
    private const CACHE_TTL = 300;

    /** @var array{at: int, products: array<string, array<string, mixed>>, truncated: bool}|null */
    private static ?array $cache = null;

    /** @var array<string, mixed> */
    private array $config;

    private bool $enabled;

    public function __construct()
    {
        $this->config = Config::invoiceNinja();
        $this->enabled = Config::invoiceNinjaHttpEnabled();
    }

    public function mode(): string
    {
        return $this->enabled ? 'http-test' : 'disabled';
    }

    public function available(): bool
    {
        return $this->enabled;
    }

    /** El catálogo mostró solo la primera página de Invoice Ninja. */
    public function catalogTruncated(): bool
    {
        return is_array(self::$cache) && (bool) (self::$cache['truncated'] ?? false);
    }

    /**
     * Productos publicados por Invoice Ninja, indexados por identificador opaco.
     *
     * Las claves opcionales (currency, periodicity, tax, billing) solo se
     * incluyen cuando la versión instalada las devuelve; nunca se inventan.
     *
     * @return array<string, array<string, mixed>>
     */
    public function products(): array
    {
        if (!$this->enabled) {
            return [];
        }

        $now = time();
        if (is_array(self::$cache) && $now - self::$cache['at'] < self::CACHE_TTL) {
            return self::$cache['products'];
        }

        $response = $this->get('/products', ['per_page' => (int) $this->config['catalog_limit']]);
        if (!$response['ok'] || !is_array($response['data'])) {
            return [];
        }

        $rows = $response['data']['data'] ?? $response['data'];
        if (!is_array($rows)) {
            return [];
        }

        $products = [];
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }

            $id = trim((string) ($row['id'] ?? ''));
            if ($id === '' || ($row['is_deleted'] ?? false) === true || ($row['is_active'] ?? true) === false) {
                continue;
            }

            $key = trim((string) ($row['product_key'] ?? ''));
            $label = trim((string) ($row['notes'] ?? ''));
            if ($label === '') {
                $label = $key;
            }
            if ($label === '') {
                $label = $id;
            }

            $price = $this->price($row['price'] ?? null);
            $products[$id] = array_merge([
                'id' => $id,
                'key' => $key,
                'label' => $label,
                'price' => $price,
                'modality' => $price === null ? 'quote' : 'public',
            ], self::priceDetail($row));
        }

        self::$cache = [
            'at' => $now,
            'products' => $products,
            'truncated' => self::isTruncated($response['data'], count($rows)),
        ];

        return $products;
    }

    /**
     * Busca coincidencias comerciales para evitar clientes duplicados.
     * Nunca crea nada: solo informa si hay 0, 1 o varias coincidencias.
     *
     * @return array{status: string, matches: int}
     */
    public function findClients(string $taxId, string $legalName, string $email): array
    {
        if (!$this->enabled) {
            return ['status' => 'unavailable', 'matches' => 0];
        }

        // Los filtros /clients no fueron validados contra la versión instalada:
        // no se clasifican clientes y toda solicitud pasa a revisión humana.
        if (!Config::invoiceNinjaClientMatchingEnabled()) {
            return ['status' => 'not_checked', 'matches' => 0];
        }

        $query = [];
        if ($taxId !== '') {
            $query['tax_id'] = $taxId;
        }
        if ($legalName !== '') {
            $query['legal_name'] = $legalName;
        }
        if ($email !== '') {
            $query['email'] = $email;
        }
        if ($query === []) {
            return ['status' => 'none', 'matches' => 0];
        }

        $response = $this->get('/clients', $query);
        if (!$response['ok'] || !is_array($response['data'])) {
            return ['status' => 'unavailable', 'matches' => 0];
        }

        $rows = $response['data']['data'] ?? $response['data'];
        if (!is_array($rows)) {
            return ['status' => 'unavailable', 'matches' => 0];
        }

        $matches = count($rows);
        if ($matches === 0) {
            return ['status' => 'none', 'matches' => 0];
        }

        return ['status' => $matches === 1 ? 'exact' : 'ambiguous', 'matches' => $matches];
    }

    /** @return array{ok: bool, status: int, data: ?array<string, mixed>, error: ?string} */
    private function get(string $path, array $query = []): array
    {
        if (!str_starts_with($path, '/') || str_contains($path, '://') || str_contains($path, '\\')) {
            return ['ok' => false, 'status' => 0, 'data' => null, 'error' => 'invalid_path'];
        }

        $url = (string) $this->config['base_url'] . (string) $this->config['api_prefix'] . $path;
        if ($query !== []) {
            $url .= '?' . http_build_query($query);
        }

        $attempts = 0;
        $retries = (int) $this->config['retries'];
        $lastStatus = 0;

        do {
            $attempts++;
            $response = HttpClient::request(
                'GET',
                $url,
                [
                    'Accept: application/json',
                    'X-Api-Token: ' . (string) $this->config['token'],
                ],
                null,
                (int) $this->config['timeout']
            );
            $lastStatus = $response['status'];

            if ($response['ok']) {
                break;
            }
        } while ($attempts <= $retries && in_array($response['status'], [429, 500, 502, 503, 504], true));

        if (!$response['ok']) {
            return [
                'ok' => false,
                'status' => $lastStatus,
                'data' => null,
                'error' => is_string($response['error'] ?? null) ? $response['error'] : 'http_error_status',
            ];
        }

        if (!str_contains(strtolower($response['content_type']), 'json')) {
            return ['ok' => false, 'status' => $lastStatus, 'data' => null, 'error' => 'unexpected_content_type'];
        }

        try {
            $decoded = json_decode($response['body'], true, 32, JSON_THROW_ON_ERROR);
        } catch (\JsonException) {
            return ['ok' => false, 'status' => $lastStatus, 'data' => null, 'error' => 'invalid_json'];
        }

        if (!is_array($decoded)) {
            return ['ok' => false, 'status' => $lastStatus, 'data' => null, 'error' => 'invalid_json_shape'];
        }

        return ['ok' => true, 'status' => $lastStatus, 'data' => $decoded, 'error' => null];
    }

    /**
     * Extrae solo los atributos comerciales que Invoice Ninja realmente envía.
     *
     * @param array<string, mixed> $row
     * @return array<string, string>
     */
    private static function priceDetail(array $row): array
    {
        $detail = [];

        $currency = self::firstString($row, ['currency_code', 'currency']);
        if ($currency !== null && preg_match('/^[A-Z]{3}$/', $currency) === 1) {
            $detail['currency'] = $currency;
        }

        $periodicity = self::firstString($row, ['frequency', 'billing_frequency', 'interval']);
        if ($periodicity !== null && preg_match('/^[\p{L}\p{N} _-]{1,40}$/u', $periodicity) === 1) {
            $detail['periodicity'] = $periodicity;
        }

        $taxName = self::firstString($row, ['tax_name1']);
        $taxRate = $row['tax_rate1'] ?? null;
        if ($taxName !== null && (is_int($taxRate) || is_float($taxRate) || is_string($taxRate))) {
            $rate = trim((string) $taxRate);
            if (is_numeric($rate) && (float) $rate > 0) {
                $detail['tax'] = $taxName . ' ' . rtrim(rtrim($rate, '0'), '.') . '%';
            }
        }

        foreach (['is_recurring', 'recurring'] as $key) {
            if (array_key_exists($key, $row) && is_bool($row[$key])) {
                $detail['billing'] = $row[$key] ? 'recurring' : 'one_time';
                break;
            }
        }

        return $detail;
    }

    /** @param array<string, mixed> $row @return list<string> */
    private static function firstString(array $row, array $keys): ?string
    {
        foreach ($keys as $key) {
            if (isset($row[$key]) && is_string($row[$key]) && trim($row[$key]) !== '') {
                return trim($row[$key]);
            }
        }

        return null;
    }

    /** Compare el total informado por Invoice Ninja con las filas mostradas. */
    private static function isTruncated(array $data, int $shown): bool
    {
        $meta = $data['meta'] ?? $data;
        if (!is_array($meta)) {
            return false;
        }

        if (isset($meta['pagination']) && is_array($meta['pagination'])) {
            $meta = $meta['pagination'];
        }

        foreach (['total', 'total_results'] as $key) {
            if (isset($meta[$key]) && is_numeric($meta[$key])) {
                return (int) $meta[$key] > $shown;
            }
        }

        return false;
    }

    private function price(mixed $raw): ?float
    {
        if (is_int($raw) || is_float($raw)) {
            $value = (float) $raw;
        } elseif (is_string($raw) && is_numeric(trim($raw))) {
            $value = (float) trim($raw);
        } else {
            return null;
        }

        return $value > 0 ? round($value, 2) : null;
    }
}
