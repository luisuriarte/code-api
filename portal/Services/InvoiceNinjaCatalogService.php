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

    /** @var array{at: int, products: array<string, array<string, mixed>>}|null */
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

    /**
     * Productos publicados por Invoice Ninja, indexados por identificador opaco.
     *
     * @return array<string, array{id: string, key: string, label: string, price: ?float, modality: string}>
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
            $products[$id] = [
                'id' => $id,
                'key' => $key,
                'label' => $label,
                'price' => $price,
                'modality' => $price === null ? 'quote' : 'public',
            ];
        }

        self::$cache = ['at' => $now, 'products' => $products];

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
