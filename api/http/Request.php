<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Http;

/**
 * Representación inmutable de la petición HTTP actual.
 *
 * Aísla al resto de la aplicación de las superglobales de PHP y normaliza
 * el path para que el enrutador funcione tanto en la raíz del dominio como
 * en un subdirectorio (por ejemplo, /api).
 */
final class Request
{
    /**
     * @param array<string, mixed>  $query
     * @param array<string, string> $headers Nombres en minúscula.
     */
    public function __construct(
        public readonly string $method,
        public readonly string $path,
        public readonly array $query,
        public readonly array $headers,
        public readonly string $requestId,
    ) {
    }

    public static function fromGlobals(): self
    {
        $method = strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'));
        $path = self::normalizePath((string) ($_SERVER['REQUEST_URI'] ?? '/'));
        $headers = self::collectHeaders();

        $requestId = self::validRequestId($headers['x-request-id'] ?? null)
            ?? bin2hex(random_bytes(16));

        return new self($method, $path, $_GET, $headers, $requestId);
    }

    public function header(string $name): ?string
    {
        return $this->headers[strtolower($name)] ?? null;
    }

    /**
     * Extrae el token de "Authorization: Bearer <token>".
     */
    public function bearerToken(): ?string
    {
        $authorization = $this->header('authorization');

        if ($authorization === null) {
            return null;
        }

        if (preg_match('/^Bearer\s+(\S+)$/i', trim($authorization), $matches) !== 1) {
            return null;
        }

        return $matches[1];
    }

    /**
     * @param array<string, string> $headers
     */
    private static function normalizePath(string $uri): string
    {
        $path = parse_url($uri, PHP_URL_PATH);

        if (!is_string($path) || $path === '') {
            $path = '/';
        }

        $path = rawurldecode($path);

        if (str_contains($path, "\0")) {
            return '/';
        }

        // Colapsa barras duplicadas para tolerar URLs como //v1//concepts.
        $path = preg_replace('#/+#', '/', $path) ?? '/';

        $scriptName = str_replace('\\', '/', (string) ($_SERVER['SCRIPT_NAME'] ?? ''));

        /*
         * Algunos servidores de desarrollo (php -S) informan en SCRIPT_NAME la
         * ruta solicitada cuando contiene un punto, por ejemplo
         * "/v1/cie10/J18.9". Solo se descuenta el prefijo cuando SCRIPT_NAME
         * corresponde realmente a un archivo PHP del front controller.
         */
        $basePath = str_ends_with(strtolower($scriptName), '.php')
            ? rtrim(str_replace('\\', '/', dirname($scriptName)), '/')
            : '';

        if ($basePath !== '' && $basePath !== '/') {
            if ($path === $basePath) {
                $path = '/';
            } elseif (str_starts_with($path, $basePath . '/')) {
                $path = substr($path, strlen($basePath));
            }
        }

        $path = '/' . trim($path, '/');

        return $path === '/' ? '/' : rtrim($path, '/');
    }

    /**
     * @return array<string, string>
     */
    private static function collectHeaders(): array
    {
        $headers = [];

        foreach ($_SERVER as $key => $value) {
            if (!is_string($value)) {
                continue;
            }

            if (str_starts_with($key, 'HTTP_')) {
                $name = strtolower(str_replace('_', '-', substr($key, 5)));
                $headers[$name] = trim($value);
            }
        }

        foreach (['CONTENT_TYPE' => 'content-type', 'CONTENT_LENGTH' => 'content-length'] as $serverKey => $headerName) {
            if (isset($_SERVER[$serverKey]) && is_string($_SERVER[$serverKey])) {
                $headers[$headerName] = trim($_SERVER[$serverKey]);
            }
        }

        return $headers;
    }

    private static function validRequestId(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $value = trim($value);

        return preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]{7,63}$/', $value) === 1
            ? $value
            : null;
    }
}
