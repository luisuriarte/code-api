<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Services;

/**
 * Cliente HTTP interno basado en cURL, con timeout fijo y sin redirecciones.
 *
 * @return array{ok: bool, status: int, body: string, content_type: string, error: ?string}
 */
final class HttpClient
{
    public static function request(
        string $method,
        string $url,
        array $headers = [],
        ?string $body = null,
        int $timeout = 8
    ): array {
        if (!function_exists('curl_init')) {
            return ['ok' => false, 'status' => 0, 'body' => '', 'content_type' => '', 'error' => 'curl_unavailable'];
        }

        $handle = curl_init($url);
        if ($handle === false) {
            return ['ok' => false, 'status' => 0, 'body' => '', 'content_type' => '', 'error' => 'curl_init_failed'];
        }

        $responseHeaders = [];
        $options = [
            CURLOPT_CUSTOMREQUEST => strtoupper($method),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HEADERFUNCTION => static function ($curl, string $line) use (&$responseHeaders): int {
                $parts = explode(':', $line, 2);
                if (count($parts) === 2) {
                    $responseHeaders[strtolower(trim($parts[0]))][] = trim($parts[1]);
                }

                return strlen($line);
            },
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_CONNECTTIMEOUT => max(1, $timeout),
            CURLOPT_TIMEOUT => max(1, $timeout),
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_MAXREDIRS => 0,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
        ];

        if ($body !== null) {
            $options[CURLOPT_POSTFIELDS] = $body;
        }

        curl_setopt_array($handle, $options);
        $response = curl_exec($handle);
        $error = curl_error($handle);
        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        curl_close($handle);

        if ($response === false) {
            return [
                'ok' => false,
                'status' => $status,
                'body' => '',
                'content_type' => '',
                'error' => $error !== '' ? 'http_request_failed' : 'http_empty_response',
            ];
        }

        $contentTypes = $responseHeaders['content-type'] ?? [];

        return [
            'ok' => $status >= 200 && $status < 300,
            'status' => $status,
            'body' => (string) $response,
            'content_type' => (string) (end($contentTypes) ?: ''),
            'error' => null,
        ];
    }
}
