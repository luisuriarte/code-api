<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Services;

use OrigenSalud\Portal\Config;

/**
 * Cliente para OpenWA (open-wa/wa-automate v5, Easy API).
 *
 * Contrato usado:
 *   GET  /health                 → disponibilidad
 *   POST /api/messages/sendText  → X-API-Key, {to, content, options:{}}
 *
 * El id de sesión no reemplaza a la clave API. El número de destino debe
 * normalizarse a numero@c.us.
 */
final class OpenWaClient
{
    public static function configured(): bool
    {
        $config = Config::openWa();

        return $config['url'] !== '' && $config['key'] !== '' && self::destination() !== '';
    }

    /** @return array{ok: bool, error: ?string} */
    public static function notify(string $message): array
    {
        $config = Config::openWa();

        if (!self::configured()) {
            return ['ok' => false, 'error' => 'openwa_not_configured'];
        }

        $destination = self::destination();
        $health = HttpClient::request(
            'GET',
            $config['url'] . '/health',
            ['Accept: application/json'],
            null,
            min(5, $config['timeout'])
        );

        if (!$health['ok']) {
            return ['ok' => false, 'error' => 'openwa_unavailable'];
        }

        $payload = json_encode([
            'to' => $destination,
            'content' => mb_substr($message, 0, 4000),
            'options' => [],
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        if (!is_string($payload)) {
            return ['ok' => false, 'error' => 'openwa_payload_failed'];
        }

        $headers = [
            'Content-Type: application/json',
            'Accept: application/json',
            'X-API-Key: ' . $config['key'],
        ];

        if ($config['session'] !== '') {
            $headers[] = 'X-Session-Id: ' . $config['session'];
        }

        $response = HttpClient::request(
            'POST',
            $config['url'] . '/api/messages/sendText',
            $headers,
            $payload,
            $config['timeout']
        );

        if (!$response['ok']) {
            return ['ok' => false, 'error' => 'openwa_send_failed'];
        }

        return ['ok' => true, 'error' => null];
    }

    private static function destination(): string
    {
        $raw = trim((string) env('WHATSAPP_NOTIFY_TO', ''));
        if ($raw === '') {
            return '';
        }

        $raw = preg_replace('/[^0-9]/', '', $raw) ?? '';
        if ($raw === '') {
            return '';
        }

        if (strlen($raw) === 10) {
            $raw = '54' . $raw;
        }

        return ltrim($raw, '0') . '@c.us';
    }
}
