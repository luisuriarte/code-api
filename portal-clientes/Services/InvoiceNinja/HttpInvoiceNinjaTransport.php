<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services\InvoiceNinja;

use InvalidArgumentException;

/**
 * Transporte HTTP de solo lectura hacia la instancia designada como de prueba.
 *
 * Requisitos cumplidos aquí:
 * - HTTPS obligatorio y verificación de certificado.
 * - Sin redirecciones.
 * - Token solo en cabecera, nunca en URL, HTML, logs ni mensajes de error.
 * - Timeouts acotados y reintentos controlados solo en respuestas transitorias.
 * - Validación estricta del JSON devuelto.
 */
final class HttpInvoiceNinjaTransport implements InvoiceNinjaTransport
{
    private int $attempts = 0;

    public function __construct(
        private readonly string $baseUrl,
        private readonly string $apiPrefix,
        private readonly string $token,
        private readonly int $timeout = 8,
        private readonly int $retries = 1
    ) {
        if (!str_starts_with($baseUrl, 'https://')) {
            throw new InvalidArgumentException('invoice_ninja_requires_https');
        }
    }

    public function get(string $path, array $query = []): array
    {
        if (!str_starts_with($path, '/') || str_starts_with($path, '//')
            || str_contains($path, '://') || str_contains($path, '\\')) {
            return ['ok' => false, 'status' => 0, 'data' => null, 'error' => 'invalid_path'];
        }

        $url = $this->baseUrl . $this->apiPrefix . $path;
        if ($query !== []) {
            $url .= '?' . http_build_query($query);
        }

        $this->attempts = 0;
        $lastStatus = 0;

        for ($attempt = 0; $attempt <= $this->retries; $attempt++) {
            $this->attempts++;
            $response = $this->requestOnce($url);
            $lastStatus = $response['status'];

            if ($response['ok'] || !in_array($response['status'], [429, 500, 502, 503, 504], true)) {
                return $response;
            }

            if ($attempt < $this->retries) {
                usleep(100000 * ($attempt + 1));
            }
        }

        return [
            'ok' => false,
            'status' => $lastStatus,
            'data' => null,
            'error' => 'retry_limit_reached',
        ];
    }

    public function attempts(): int
    {
        return $this->attempts;
    }

    /** @return array{ok: bool, status: int, data: ?array<string, mixed>, error: ?string} */
    private function requestOnce(string $url): array
    {
        if (!function_exists('curl_init')) {
            return ['ok' => false, 'status' => 0, 'data' => null, 'error' => 'curl_unavailable'];
        }

        $handle = curl_init($url);
        if ($handle === false) {
            return ['ok' => false, 'status' => 0, 'data' => null, 'error' => 'curl_init_failed'];
        }

        curl_setopt_array($handle, [
            CURLOPT_CUSTOMREQUEST => 'GET',
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_MAXREDIRS => 0,
            CURLOPT_CONNECTTIMEOUT => $this->timeout,
            CURLOPT_TIMEOUT => $this->timeout,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_HTTPHEADER => [
                'Accept: application/json',
                'X-Api-Token: ' . $this->token,
            ],
        ]);

        $body = curl_exec($handle);
        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        $contentType = (string) curl_getinfo($handle, CURLINFO_CONTENT_TYPE);
        $error = curl_error($handle);
        curl_close($handle);

        if (!is_string($body)) {
            return [
                'ok' => false,
                'status' => $status,
                'data' => null,
                'error' => $error !== '' ? 'http_request_failed' : 'http_empty_response',
            ];
        }

        if ($status < 200 || $status >= 300) {
            return ['ok' => false, 'status' => $status, 'data' => null, 'error' => 'http_error_status'];
        }

        if (!str_contains(strtolower($contentType), 'json')) {
            return ['ok' => false, 'status' => $status, 'data' => null, 'error' => 'unexpected_content_type'];
        }

        try {
            $decoded = json_decode($body, true, 32, JSON_THROW_ON_ERROR);
        } catch (\JsonException) {
            return ['ok' => false, 'status' => $status, 'data' => null, 'error' => 'invalid_json'];
        }

        if (!is_array($decoded)) {
            return ['ok' => false, 'status' => $status, 'data' => null, 'error' => 'invalid_json_shape'];
        }

        return ['ok' => true, 'status' => $status, 'data' => $decoded, 'error' => null];
    }
}
