<?php

declare(strict_types=1);

/**
 * Verificación de la Etapa 11 del portal de clientes.
 *
 * Modo local (sin red):
 *   php tools/php/verificar_etapa11_portal_clientes.php
 *
 * Modo HTTP de solo lectura:
 *   php tools/php/verificar_etapa11_portal_clientes.php --site=https://med.origen.ar
 *
 * Caso negativo de CSRF (opt-in, no crea datos):
 *   php tools/php/verificar_etapa11_portal_clientes.php --site=https://med.origen.ar --post
 *
 * No ejecuta despliegue, no crea clientes, facturas ni pagos y no imprime secretos.
 */

use OrigenSalud\Portal\Services\HttpClient;

$root = dirname(__DIR__, 2);
require_once $root . '/portal/Services/HttpClient.php';

$failures = [];
$checks = 0;

$check = static function (bool $condition, string $message) use (&$failures, &$checks): void {
    $checks++;
    if (!$condition) {
        $failures[] = $message;
    }
};

$read = static function (string $relative) use ($root): string {
    $path = $root . '/' . $relative;

    return is_file($path) ? (string) file_get_contents($path) : '';
};

// ---------------------------------------------------------------------------
// T-00: autorización y documento de pruebas.
// ---------------------------------------------------------------------------
$acta = $read('docs/portal-clientes/acta-autorizacion-etapa-11.md');
$check(
    str_contains($acta, 'Etapa 11') && str_contains($acta, 'No incluye despliegue'),
    'T-00: debe existir el acta de la Etapa 11 y excluir expresamente el despliegue.'
);
$check(
    str_contains($acta, 'token') && str_contains($acta, 'No se crean clientes'),
    'T-00: el acta debe registrar token de prueba y prohibición de datos comerciales.'
);

$plan = $read('docs/portal-clientes/plan-pruebas-portal-clientes.md');
$check(
    str_contains($plan, 'autorizado para ejecución en entorno de prueba'),
    'T-00: el plan de pruebas debe reflejar la autorización de la Etapa 11.'
);
$check(
    str_contains($plan, 'Solicitud de Servicios') && preg_match('/\bcarrito\b/i', $plan) !== 1,
    'T-08: el plan debe hablar de Solicitud de Servicios, sin «carrito».'
);
$check(
    str_contains($plan, 'T-09') && str_contains($plan, 'No aplica'),
    'T-09: el plan debe declarar no aplicable la sección de consumo.'
);

// ---------------------------------------------------------------------------
// T-05 / T-07 / T-08: contrato estático del flujo.
// ---------------------------------------------------------------------------
$router = $read('portal/Router.php');
foreach (['solicitud', 'solicitud/agregar', 'solicitud/quitar', 'solicitud/restar', 'solicitud/enviar'] as $route) {
    $check(str_contains($router, "'" . $route . "'"), 'T-07: debe existir la ruta ' . $route . '.');
}
$check(!str_contains($router, "'/cart'"), 'T-06: no debe reintroducirse la ruta /cart.');

foreach (['header.php', 'footer.php', 'nav-links.php'] as $partial) {
    $source = $read('portal/Views/partials/' . $partial);
    $check(!str_contains($source, '/solicitud'), 'T-08: ' . $partial . ' no debe enlazar la Solicitud de Servicios.');
}

$config = $read('portal/Config.php');
$check(
    str_contains($config, "'request' => (int) env('RATE_REQUEST', '5')")
        && !str_contains($config, "'cart' =>"),
    'T-05: el límite de la solicitud debe llamarse request y no cart.'
);
$check(
    str_contains($config, 'INVOICE_NINJA_ALLOW_TEST_CALLS') && str_contains($config, 'https://'),
    'T-03: las consultas a Invoice Ninja requieren opt-in y HTTPS.'
);
$envExample = $read('.env.example');
$check(
    str_contains($config, "env('SERVICE_REQUEST_DB_DSN', '')")
        && str_contains($envExample, 'SERVICE_REQUEST_DB_DSN=')
        && !str_contains($envExample, 'SERVICE_REQUEST_DB_DSN=pgsql:'),
    'T-08: el DSN dedicado de la solicitud se configura solo en el servidor.'
);

$catalog = $read('portal/Services/InvoiceNinjaCatalogService.php');
$check(
    str_contains($catalog, "HttpClient::request(")
        && str_contains($catalog, "'GET'")
        && preg_match('/\b(POST|PUT|PATCH|DELETE)\b/', $catalog) !== 1,
    'T-03: el catálogo debe ser de solo lectura.'
);
$check(
    str_contains($catalog, "'X-Api-Token: '") && !str_contains($catalog, 'INVOICE_NINJA_API_TOKEN='),
    'T-03: el token viaja en cabecera y nunca se escribe en el código.'
);

$service = $read('portal/Services/ServiceRequestService.php');
$controller = $read('portal/Controllers/ServiceRequestController.php');
$check(
    str_contains($service, 'Csrf::valid') && str_contains($service, 'Csrf::rotate()'),
    'T-05: CSRF debe validarse y rotarse tras el envío.'
);
$check(
    str_contains($service, '$id = (string) $id;') && str_contains($service, '$current + $quantity'),
    'T-08: IDs numéricos se conservan y «Agregar» acumula cantidades.'
);
$check(
    str_contains($service, 'removeOneFromSelection')
        && str_contains($read('portal/Views/service-request.php'), 'service_request.remove_one'),
    'T-08: se puede quitar una unidad sin borrar el servicio completo.'
);
$check(
    str_contains($controller, 'FILTER_VALIDATE_INT'),
    'T-08: la cantidad enviada por el navegador se valida como entero.'
);
$check(
    str_contains($service, 'RateLimiter::hit') && str_contains($service, 'spam_error'),
    'T-05: rate limiting y anti-spam deben estar activos.'
);
$check(
    str_contains($service, 'hash(') && str_contains($service, 'duplicate_of'),
    'T-08: la deduplicación debe estar implementada en servidor.'
);

$repository = $read('portal/Repositories/PublicServiceRequestRepository.php');
$serviceDatabase = $read('portal/Repositories/ServiceRequestDatabase.php');
$check(
    str_contains($repository, 'INSERT INTO os_customer.public_service_request')
        && !preg_match('/\b(UPDATE|DELETE\s+FROM)\b/i', $repository),
    'T-08: el repositorio solo inserta y consulta solicitudes.'
);
$check(
    str_contains($serviceDatabase, 'Config::serviceRequestDatabase()')
        && str_contains($serviceDatabase, 'new PDO'),
    'T-08: debe existir una conexión dedicada para la Solicitud de Servicios.'
);
$check(
    str_contains($repository, 'ServiceRequestDatabase::available()')
        && str_contains($repository, 'ServiceRequestDatabase::connection()')
        && !str_contains($repository, 'PortalDatabase::connection()'),
    'T-08: la solicitud debe escribir en el DSN dedicado, no en el DSN público.'
);
$check(
    preg_match('/findRecent\([^;]+;\s*}\s*catch \(RepositoryException\)/s', $service) === 1,
    'T-08: un fallo de BD al buscar duplicados debe responder localizado, sin 500.'
);
$check(
    !preg_match('/\b(price|amount|total|invoice|payment|currency)\b/i', $repository),
    'T-08: el repositorio no puede guardar importes ni datos comerciales.'
);

// ---------------------------------------------------------------------------
// Etapa 10 / T-10: migraciones y verificación de base.
// ---------------------------------------------------------------------------
foreach (['up', 'verify'] as $step) {
    $check(
        is_file($root . '/sql/10_portal_clientes/V10.001__public_service_requests.' . $step . '.sql'),
        'T-10: debe existir V10.001 ' . $step . '.'
    );
    $check(
        is_file($root . '/sql/10_portal_clientes/V10.002__origen_med_no_superuser.' . $step . '.sql'),
        'T-10: debe existir V10.002 ' . $step . '.'
    );
}
$requestCheck = $read('sql/10_portal_clientes/ETAPA11__verificacion_solicitudes.sql');
$check(
    str_contains($requestCheck, "current_database() NOT LIKE 'origen_codes_portal_clientes%'")
        && str_contains($requestCheck, 'columnas_prohibidas')
        && !preg_match('/\b(contact_email|tax_id_normalized)\b/', $requestCheck),
    'T-08: la verificación SQL debe ser SELECT-only, estar acotada y no exponer datos personales.'
);

// ---------------------------------------------------------------------------
// Modo HTTP opcional, de solo lectura salvo el caso --post.
// ---------------------------------------------------------------------------
$site = null;
$allowPost = false;
foreach (array_slice($argv, 1) as $argument) {
    if (str_starts_with($argument, '--site=')) {
        $site = rtrim((string) substr($argument, strlen('--site=')), '/');
    } elseif ($argument === '--post') {
        $allowPost = true;
    } else {
        fwrite(STDERR, 'Opción desconocida: ' . $argument . PHP_EOL);
        exit(2);
    }
}

if ($site !== null) {
    $check(
        str_starts_with($site, 'https://'),
        'T-05: la URL de pruebas debe usar HTTPS.'
    );

    if (str_starts_with($site, 'https://')) {
        $pages = [
            ['/es-AR/solicitud', 'Solicitud de Servicios', 'T-07/T-08'],
            ['/en/solicitud', 'Service Request', 'T-07'],
            ['/pt-BR/solicitud', 'Solicitação de Serviços', 'T-07'],
        ];
        foreach ($pages as [$path, $needle, $case]) {
            $response = HttpClient::request('GET', $site . $path, ['Accept: text/html'], null, 8);
            $check(
                $response['ok'] && str_contains($response['body'], $needle),
                $case . ': ' . $path . ' debe responder 200 con el texto localizado.'
            );
            $check(
                !str_contains($response['body'], 'X-Api-Token')
                    && !str_contains($response['body'], 'INVOICE_NINJA_API_TOKEN'),
                'T-03/T-05: ' . $path . ' no debe exponer secretos en HTML.'
            );
        }

        $home = HttpClient::request('GET', $site . '/es-AR', ['Accept: text/html'], null, 8);
        $check(
            $home['ok'] && !str_contains($home['body'], '/solicitud'),
            'T-08: la home no debe exponer la ruta de la Solicitud de Servicios.'
        );

        if ($allowPost) {
            $post = HttpClient::request(
                'POST',
                $site . '/es-AR/solicitud/enviar',
                ['Content-Type: application/x-www-form-urlencoded'],
                'organization=prueba-sin-csrf',
                8
            );
            $check(
                $post['status'] === 303,
                'T-05: un POST sin CSRF debe redirigir con 303, no aceptarse.'
            );
            $check($post['status'] < 500, 'T-05: un POST sin CSRF no debe provocar 5xx.');
        } else {
            echo "Nota: caso negativo de CSRF HTTP omitido; usar --post para habilitarlo.\n";
        }
    }
}

if ($failures !== []) {
    fwrite(STDERR, 'FALLOS (' . count($failures) . ' de ' . $checks . '):' . PHP_EOL);
    foreach ($failures as $failure) {
        fwrite(STDERR, ' - ' . $failure . PHP_EOL);
    }
    exit(1);
}

echo 'OK: ' . $checks . ' comprobaciones de la Etapa 11.' . PHP_EOL;
