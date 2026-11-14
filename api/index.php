<?php

declare(strict_types=1);

/**
 * Origen Salud - API REST (api.origen.ar)
 *
 * Front Controller único. Responsabilidades:
 *  - Normalizar la petición y aplicar CORS.
 *  - Autenticar clientes B2B mediante API Key.
 *  - Enrutar los endpoints /v1/*.
 *  - Traducir excepciones a respuestas JSON consistentes.
 *
 * El detalle de los errores internos se registra en el log del servidor,
 * nunca se envía al cliente.
 */

use OrigenSalud\Api\Config\Database;
use OrigenSalud\Api\Controllers\ConceptController;
use OrigenSalud\Api\Http\ApiException;
use OrigenSalud\Api\Http\ApiKeyAuthenticator;
use OrigenSalud\Api\Http\Cors;
use OrigenSalud\Api\Http\Request;
use OrigenSalud\Api\Http\Response;
use OrigenSalud\Api\Services\TerminologySearchService;

require_once dirname(__DIR__) . '/bootstrap.php';

$request = Request::fromGlobals();

if (!headers_sent()) {
    header('X-Request-Id: ' . $request->requestId);
    header('X-Content-Type-Options: nosniff');
    header('Referrer-Policy: no-referrer');
}

Cors::apply($request);

if ($request->method === 'OPTIONS') {
    Response::noContent();
}

try {
    $path = $request->path;

    // Health check público para balanceadores y monitoreo.
    if ($path === '/health') {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $db = api_database($request);

        try {
            $db->query('SELECT 1');
        } catch (Throwable $exception) {
            log_api_exception($exception, $request);

            Response::error(
                'service_unavailable',
                'El servicio de datos no está disponible temporalmente.',
                503,
                null,
                $request->requestId
            );
        }

        Response::json([
            'status' => 'ok',
            'service' => 'origen-salud-api',
            'version' => (string) env('APP_VERSION', '1.0.0'),
            'time' => gmdate('c'),
            'checks' => ['database' => 'ok'],
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Toda la superficie /v1 requiere API Key y, por lo tanto, base de datos.
    if (str_starts_with($path, '/v1/')) {
        $db = api_database($request);
        (new ApiKeyAuthenticator($db))->authenticate($request);
    }

    // Catálogo de dominios clínicos disponibles.
    if ($path === '/v1/domains') {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        Response::json([
            'data' => TerminologySearchService::catalog(),
            'meta' => [
                'domains' => TerminologySearchService::DOMAINS,
                'default_domains' => TerminologySearchService::DEFAULT_DOMAINS,
            ],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Catálogo de refsets filtrables (requiere 04_codigos_opcional.sql).
    if ($path === '/v1/refsets') {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->refsetCatalog();

        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Búsqueda unificada: /v1/search y /v1/search/{domain}.
    $searchDomain = null;
    $isUnifiedSearch = $path === '/v1/search';

    if (!$isUnifiedSearch && preg_match('#^/v1/search/([a-z0-9]+)$#', $path, $searchMatches) === 1) {
        $isUnifiedSearch = true;
        $searchDomain = $searchMatches[1];
    }

    if ($isUnifiedSearch) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->search($request, $searchDomain);

        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Detalle CIE-10 con descripciones bilingües y mapeo a SNOMED-CT.
    if (preg_match('#^/v1/cie10/([A-Za-z][0-9]{2}(?:\.[0-9A-Za-z]{1,4}|[0-9A-Za-z]{0,3}))$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->findCie10($matches[1], $request);

        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Detalle ANMAT con vínculo opcional al concepto SNOMED.
    if (preg_match('#^/v1/anmat/([0-9]{1,12})$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->findAnmat((int) $matches[1], $request);

        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Detalle de los catálogos locales (laboratorio, vacunas, odontología,
    // prestaciones, programas e imágenes), con vínculo SNOMED-CT opcional.
    if (preg_match('#^/v1/(laboratorio|vacunas|odontologia|prestaciones|programas|imagenes)/([0-9]{1,12})$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->findCatalog($matches[1], (int) $matches[2], $request);

        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Alias directo del detalle SNOMED-CT.
    if (preg_match('#^/v1/snomed/([0-9]{6,18})$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new ConceptController($db))->show($matches[1], $request);

        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Alias compatible de búsqueda SNOMED-CT.
    if ($path === '/v1/concepts/search') {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new ConceptController($db))->search($request);

        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    if (preg_match('#^/v1/concepts/([0-9]{6,18})$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new ConceptController($db))->show($matches[1], $request);

        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    throw ApiException::notFound('La ruta solicitada no existe.');
} catch (ApiException $exception) {
    if ($exception->status === 401 && !headers_sent()) {
        header('WWW-Authenticate: Bearer realm="origen-salud-api"');
    }

    if (isset($exception->details['allow']) && !headers_sent()) {
        header('Allow: ' . $exception->details['allow']);
    }

    Response::error(
        $exception->errorCode,
        $exception->getMessage(),
        $exception->status,
        $exception->details,
        $request->requestId
    );
} catch (Throwable $exception) {
    log_api_exception($exception, $request);

    Response::error(
        'internal_error',
        'Ocurrió un error inesperado. Intentá nuevamente en unos instantes.',
        500,
        null,
        $request->requestId
    );
}

/**
 * Abre la conexión a PostgreSQL o responde 503 sin exponer el detalle.
 */
function api_database(Request $request): PDO
{
    try {
        return Database::connection();
    } catch (Throwable $exception) {
        log_api_exception($exception, $request);

        Response::error(
            'service_unavailable',
            'El servicio de datos no está disponible temporalmente.',
            503,
            null,
            $request->requestId
        );
    }
}

/**
 * Registra el error sin incluir términos de búsqueda ni datos clínicos.
 */
function log_api_exception(Throwable $exception, Request $request): void
{
    $context = sprintf(
        '[origen-api] request_id=%s method=%s path=%s exception=%s message=%s at %s:%d',
        $request->requestId,
        $request->method,
        $request->path,
        $exception::class,
        $exception->getMessage(),
        $exception->getFile(),
        $exception->getLine()
    );

    $previous = $exception->getPrevious();

    if ($previous !== null) {
        $context .= sprintf(' previous=%s: %s', $previous::class, $previous->getMessage());
    }

    if (filter_var(env('APP_DEBUG', false), FILTER_VALIDATE_BOOL)) {
        $context .= PHP_EOL . $exception->getTraceAsString();
    }

    error_log($context);
}
