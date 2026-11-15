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
use OrigenSalud\Api\Services\CatalogEngineService;
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

    // Origen Catalog Engine: Catálogos maestros (NN/PMO, NBU, NHPGD, ANDIS, Kinesiología, Salud Mental, DENTAR)
    if ($path === '/v1/catalogs') {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new CatalogEngineService($db))->listCatalogs();
        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    if (preg_match('#^/v1/catalogs/([a-z0-9\-]+)/releases$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new CatalogEngineService($db))->listReleases($matches[1]);
        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    if (preg_match('#^/v1/catalogs/([a-z0-9\-]+)/items$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new CatalogEngineService($db))->listItems($matches[1], $request);
        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    if (preg_match('#^/v1/catalogs/([a-z0-9\-]+)/items/([A-Za-z0-9\.\-_]+)$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new CatalogEngineService($db))->getItem($matches[1], $matches[2]);
        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Mapeos e interoperabilidad cruzada
    if ($path === '/v1/mappings') {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new CatalogEngineService($db))->searchMappings($request);
        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Unidades de valorización arancelaria
    if ($path === '/v1/pricing-units') {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new CatalogEngineService($db))->listPricingUnits();
        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Farmacia: Búsqueda por identificador comercial (Troquel, AlfaBeta, Kairos, GTIN)
    if (preg_match('#^/v1/medicines/identifiers/([A-Za-z0-9_\-]+)/([A-Za-z0-9\.\-_]+)$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new CatalogEngineService($db))->findMedicineByIdentifier($matches[1], $matches[2]);
        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Consulta directa de Nomencladores Argentinos (con filtros ?type=NN_PMO&q=...)
    if ($path === '/v1/nomenclador') {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->searchNomencladorArgentina($request);
        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Consulta directa de Vademécum Comercial (con filtros ?troquel=...&q=...)
    if ($path === '/v1/vademecum') {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->searchVademecum($request);
        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Consulta y búsqueda directa en LOINC (con filtros ?q=...&class=...&status=...&system=...)
    if ($path === '/v1/loinc') {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->searchLoinc($request);
        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Detalle específico de un código LOINC con sus mapeos MapTo y correlaciones
    if (preg_match('#^/v1/loinc/([0-9]{1,7}-[0-9])$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->findLoinc($matches[1], $request);
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

    // Búsqueda integral odontológica por código SNOMED-CT (prácticas y diagnósticos).
    if (preg_match('#^/v1/odontologia/snomed/([0-9]{6,18})$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->findDentalBySnomed($matches[1], $request);

        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Catálogo de diagnósticos odontológicos DENTAR (CIE-10 / SNOMED CT).
    if ($path === '/v1/odontologia/diagnosticos') {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->searchDentalDiagnoses($request);

        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Detalle de un diagnóstico odontológico y sus prestaciones indicadas.
    // Admite SCTID de SNOMED-CT, código CIE-10 (K02), código DNT-DX o ID.
    if (preg_match('#^/v1/odontologia/diagnosticos/([A-Za-z0-9\.\-]+)$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->findDentalDiagnosis($matches[1], $request);

        Response::json([
            'data' => $result['data'],
            'meta' => $result['meta'],
            'request_id' => $request->requestId,
        ], 200, ['X-Request-Id' => $request->requestId]);
    }

    // Diagnósticos asociados y justificación clínica de una prestación odontológica
    // Admite ID numérico, código de nomenclador (01.01), código DNT (DNT-000001), CDT (D0150) o SCTID SNOMED-CT.
    if (preg_match('#^/v1/odontologia/([A-Za-z0-9\.\-]+)/diagnosticos$#', $path, $matches) === 1) {
        if ($request->method !== 'GET') {
            throw ApiException::methodNotAllowed('GET, OPTIONS');
        }

        $result = (new TerminologySearchService($db))->findDentalDiagnoses($matches[1], $request);

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
