<?php

declare(strict_types=1);

namespace OrigenSalud\Web;

/**
 * Cliente del lado del servidor para el buscador público.
 *
 * La API Key nunca se envía al navegador: se lee del entorno del servidor
 * (WEB_API_KEY o WEB_API_TOKEN). Si no está configurada, el buscador informa
 * el estado en vez de fingir resultados.
 */
final class ApiClient
{
    private const DEFAULT_BASE_URL = 'https://api.origen.ar';
    private const TIMEOUT_SECONDS = 8;

    public static function configured(): bool
    {
        return self::apiKey() !== '';
    }

    /**
     * @param list<string> $domains
     *
     * @return array{ok: bool, status: int, payload: ?array<string, mixed>, error: ?string}
     */
    public static function search(string $query, string $locale, array $domains, int $limit): array
    {
        $apiKey = self::apiKey();

        if ($apiKey === '') {
            return ['ok' => false, 'status' => 503, 'payload' => null, 'error' => 'api_not_configured'];
        }

        $language = I18n::metadata($locale)['api_language'];
        $url = self::baseUrl() . '/v1/search?' . http_build_query([
            'q' => $query,
            'domains' => implode(',', $domains),
            'lang' => $language,
            'limit' => $limit,
        ], '', '&', PHP_QUERY_RFC3986);

        $headers = [
            'Authorization: Bearer ' . $apiKey,
            'Accept: application/json',
            'Accept-Language: ' . $language,
        ];

        if (function_exists('curl_init')) {
            return self::searchWithCurl($url, $headers);
        }

        return self::searchWithStreams($url, $headers);
    }

    private static function baseUrl(): string
    {
        $base = rtrim(trim((string) env('WEB_API_BASE_URL', self::DEFAULT_BASE_URL)), '/');

        if ($base === '') {
            $base = self::DEFAULT_BASE_URL;
        }

        if (str_ends_with($base, '/v1')) {
            $base = substr($base, 0, -3);
        }

        return $base;
    }

    private static function apiKey(): string
    {
        $key = env('WEB_API_KEY', env('WEB_API_TOKEN', ''));

        return is_string($key) ? trim($key) : '';
    }

    /** @param list<string> $headers */
    private static function searchWithCurl(string $url, array $headers): array
    {
        $handle = curl_init($url);

        if ($handle === false) {
            return ['ok' => false, 'status' => 500, 'payload' => null, 'error' => 'transport_unavailable'];
        }

        curl_setopt_array($handle, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_CONNECTTIMEOUT => self::TIMEOUT_SECONDS,
            CURLOPT_TIMEOUT => self::TIMEOUT_SECONDS,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
        ]);

        $body = curl_exec($handle);
        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        $error = curl_errno($handle) === 0 ? null : 'transport_error';
        curl_close($handle);

        return self::decode((string) $body, $status, $error);
    }

    /** @param list<string> $headers */
    private static function searchWithStreams(string $url, array $headers): array
    {
        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'header' => implode("\r\n", $headers) . "\r\n",
                'timeout' => self::TIMEOUT_SECONDS,
                'ignore_errors' => true,
            ],
            'ssl' => [
                'verify_peer' => true,
                'verify_peer_name' => true,
            ],
        ]);

        $body = @file_get_contents($url, false, $context);
        $status = 0;

        if (isset($http_response_header) && is_array($http_response_header)) {
            foreach ($http_response_header as $line) {
                if (preg_match('/^HTTP\/\S+\s+(\d{3})/', $line, $matches) === 1) {
                    $status = (int) $matches[1];
                }
            }
        }

        return self::decode($body === false ? '' : $body, $status, $body === false ? 'transport_error' : null);
    }

    /** @return array{ok: bool, status: int, payload: ?array<string, mixed>, error: ?string} */
    private static function decode(string $body, int $status, ?string $transportError): array
    {
        if ($transportError !== null) {
            return ['ok' => false, 'status' => $status, 'payload' => null, 'error' => $transportError];
        }

        $decoded = json_decode($body, true);

        if (!is_array($decoded)) {
            return ['ok' => false, 'status' => $status, 'payload' => null, 'error' => 'invalid_json'];
        }

        if ($status < 200 || $status >= 300) {
            return ['ok' => false, 'status' => $status, 'payload' => $decoded, 'error' => 'api_error'];
        }

        /** @var array<string, mixed> $decoded */
        return ['ok' => true, 'status' => $status, 'payload' => $decoded, 'error' => null];
    }
}
