<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Http;

/**
 * Aplica la política CORS configurada en API_CORS_ORIGINS.
 *
 * El valor es una lista separada por comas. Ejemplo:
 *   API_CORS_ORIGINS=https://med.origen.ar,https://app.origen.ar
 *
 * Si la lista está vacía, no se emiten headers CORS (same-origin only).
 * El comodín `*` está prohibido: solo se aceptan orígenes explícitos.
 */
final class Cors
{
    public static function apply(Request $request): void
    {
        $origin = $request->header('origin');

        if ($origin === null || $origin === '') {
            return;
        }

        $configured = array_values(array_filter(
            array_map('trim', explode(',', (string) env('API_CORS_ORIGINS', ''))),
            static fn (string $value): bool => $value !== ''
        ));

        if ($configured === []) {
            return;
        }

        $allowed = array_values(array_filter(
            $configured,
            static fn (string $value): bool => $value !== '*'
                && preg_match('#^https://[^\s/]+$#', $value) === 1
        ));

        if (!in_array($origin, $allowed, true)) {
            return;
        }

        if (!headers_sent()) {
            header('Access-Control-Allow-Origin: ' . $origin);
            header('Vary: Origin');
            header('Access-Control-Allow-Methods: GET, OPTIONS');
            header('Access-Control-Allow-Headers: Content-Type, X-API-Key, Authorization, X-Request-Id');
            header('Access-Control-Max-Age: 86400');
        }
    }
}
