<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Http;

use RuntimeException;

/**
 * Excepción controlada que se traduce a una respuesta HTTP concreta.
 *
 * Cualquier otro Throwable se considera un error interno y no se expone
 * al cliente.
 */
final class ApiException extends RuntimeException
{
    /**
     * @param array<string, mixed> $details
     */
    public function __construct(
        public readonly int $status,
        public readonly string $errorCode,
        string $message,
        public readonly array $details = [],
    ) {
        parent::__construct($message);
    }

    /**
     * @param array<string, mixed> $details
     */
    public static function badRequest(string $message, array $details = []): self
    {
        return new self(400, 'bad_request', $message, $details);
    }

    public static function unauthorized(string $message): self
    {
        return new self(401, 'unauthorized', $message);
    }

    /**
     * @param array<string, mixed> $details
     */
    public static function tooManyRequests(int $retryAfter, array $details = []): self
    {
        return new self(
            429,
            'rate_limit_exceeded',
            'Se superó el límite de solicitudes. Intentá nuevamente en unos instantes.',
            array_merge(['retry_after' => max(1, $retryAfter)], $details)
        );
    }

    public static function notFound(string $message = 'El recurso solicitado no existe.'): self
    {
        return new self(404, 'not_found', $message);
    }

    public static function methodNotAllowed(string $allow): self
    {
        return new self(
            405,
            'method_not_allowed',
            'El método HTTP no está permitido para este recurso.',
            ['allow' => $allow]
        );
    }

    public static function internalError(): self
    {
        return new self(
            500,
            'internal_error',
            'Ocurrió un error interno. Intente nuevamente más tarde.'
        );
    }
}
