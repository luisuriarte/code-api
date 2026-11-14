<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Http;

/**
 * Emisión de respuestas JSON con headers de seguridad.
 *
 * Todos los métodos terminan la ejecución para que el Front Controller no
 * continúe procesando luego de enviar una respuesta.
 */
final class Response
{
    /**
     * @param array<string, mixed>  $payload
     * @param array<string, string> $headers
     */
    public static function json(array $payload, int $status = 200, array $headers = []): never
    {
        if (!headers_sent()) {
            http_response_code($status);
            header('Content-Type: application/json; charset=utf-8');
            header('X-Content-Type-Options: nosniff');
            header('Cache-Control: no-store');
            header('Referrer-Policy: no-referrer');

            foreach ($headers as $name => $value) {
                header($name . ': ' . $value);
            }
        }

        echo json_encode(
            $payload,
            JSON_UNESCAPED_UNICODE
            | JSON_UNESCAPED_SLASHES
            | JSON_INVALID_UTF8_SUBSTITUTE
            | JSON_THROW_ON_ERROR
        );

        exit;
    }

    /**
     * @param array<string, mixed>|null $details
     */
    public static function error(
        string $code,
        string $message,
        int $status,
        ?array $details = null,
        ?string $requestId = null
    ): never {
        $error = [
            'code' => $code,
            'message' => $message,
        ];

        if ($details !== null && $details !== []) {
            $error['details'] = $details;
        }

        $payload = ['error' => $error];

        if ($requestId !== null && $requestId !== '') {
            $payload['request_id'] = $requestId;
        }

        $headers = $requestId !== null && $requestId !== ''
            ? ['X-Request-Id' => $requestId]
            : [];

        self::json($payload, $status, $headers);
    }

    public static function noContent(): never
    {
        if (!headers_sent()) {
            http_response_code(204);
            header('Cache-Control: no-store');
        }

        exit;
    }
}
