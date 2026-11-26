<?php

declare(strict_types=1);

/**
 * Verificación de la Etapa 12 (despliegue del portal de clientes).
 *
 * Modo local, sin red:
 *   php tools/php/verificar_etapa12_despliegue.php
 *
 * Modo HTTP de solo lectura:
 *   php tools/php/verificar_etapa12_despliegue.php --site=https://med.origen.ar
 *
 * Caso negativo de CSRF (opt-in, no crea datos):
 *   php tools/php/verificar_etapa12_despliegue.php --site=https://med.origen.ar --post
 *
 * No ejecuta commit, push, deploy, migraciones ni operaciones comerciales.
 * No imprime secretos.
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
// T-10: autorización, plan, manifiesto e informe.
// ---------------------------------------------------------------------------
$acta = $read('docs/portal-clientes/acta-autorizacion-etapa-12.md');
$check(
    str_contains($acta, 'Etapa 12') && str_contains($acta, 'AUTORIZADA'),
    'T-10: debe existir el acta autorizada de la Etapa 12.'
);
$check(
    str_contains($acta, 'no hace commit, push ni deploy')
        && str_contains($acta, 'origen_codes` **no recibe cambios de esquema ni datos**'),
    'T-10: el acta debe excluir commit/deploy del asistente y cambios en producción.'
);

$plan = $read('docs/portal-clientes/plan-despliegue-etapa-12.md');
$check(
    str_contains($plan, 'Backup previo') && str_contains($plan, '## 7. Rollback'),
    'T-10: el plan debe incluir backup previo y rollback.'
);
$check(
    str_contains($plan, 'No se ejecuta ninguna migración `V*` contra `origen_codes`'),
    'T-10: el plan debe prohibir migraciones en producción.'
);

$manifiesto = $read('docs/portal-clientes/manifiesto-despliegue-etapa-12.md');
$check(
    str_contains($manifiesto, '21940dd')
        && str_contains($manifiesto, 'No ejecutar ninguno contra `origen_codes`'),
    'T-10: el manifiesto debe fijar el commit y excluir SQL de producción.'
);
$check(
    !str_contains($manifiesto, '/cart') && preg_match('/\bcarrito\b/i', $manifiesto) !== 1,
    'T-10: el manifiesto no debe usar «cart» ni «carrito».'
);

$informe = $read('docs/portal-clientes/informe-ejecucion-etapa-12.md');
$check(
    str_contains($informe, '> **Estado:** en ejecución') && str_contains($informe, '## 6. Rollback'),
    'T-10: debe existir el informe de ejecución con estado y rollback.'
);

$etapa11 = $read('docs/portal-clientes/informe-ejecucion-etapa-11.md');
$check(
    str_contains($etapa11, '> **Estado:** cerrada.'),
    'T-10: la Etapa 11 debe estar cerrada antes de desplegar.'
);

// ---------------------------------------------------------------------------
// T-10: guardas SQL y cambios cluster-wide.
// ---------------------------------------------------------------------------
foreach (['up.sql', 'down.sql', 'verify.sql', 'verify_rollback.sql'] as $step) {
    $sql = $read('sql/10_portal_clientes/V10.001__public_service_requests.' . $step);
    $check(
        str_contains($sql, "current_database() NOT LIKE 'origen_codes_portal_clientes%'"),
        'T-10: V10.001 ' . $step . ' debe rechazar producción.'
    );
}
$v10up = $read('sql/10_portal_clientes/V10.002__origen_med_no_superuser.up.sql');
$v10down = $read('sql/10_portal_clientes/V10.002__origen_med_no_superuser.down.sql');
$check(
    str_contains($v10up, 'CLUSTER-WIDE') && str_contains($v10up, 'NOSUPERUSER'),
    'T-10: V10.002 up debe documentar el cambio cluster-wide ya aplicado.'
);
$check(
    str_contains($v10down, 'SUPERUSER')
        && str_contains($v10down, 'No forma parte del flujo')
        && str_contains($v10down, 'normal de rollback'),
    'T-10: V10.002 down no debe formar parte del rollback habitual.'
);

// ---------------------------------------------------------------------------
// T-10: contrato estático de código y secretos.
// ---------------------------------------------------------------------------
$router = $read('portal/Router.php');
foreach (['solicitud', 'solicitud/agregar', 'solicitud/quitar', 'solicitud/restar', 'solicitud/enviar'] as $route) {
    $check(str_contains($router, "'" . $route . "'"), 'T-10: debe existir la ruta ' . $route . '.');
}
$check(!str_contains($router, "'/cart'"), 'T-10: no debe reintroducirse /cart.');

$config = $read('portal/Config.php');
$customerConfig = $read('portal-clientes/Config.php');
$envExample = $read('.env.example');
$check(
    str_contains($config, "env('SERVICE_REQUEST_DB_DSN', '')")
        && str_contains($envExample, 'SERVICE_REQUEST_DB_DSN=')
        && !str_contains($envExample, 'SERVICE_REQUEST_DB_DSN=pgsql:'),
    'T-10: el DSN de la solicitud se configura solo en el servidor.'
);
$check(
    str_contains($customerConfig, "PORTAL_CUSTOMER_BILLING_URL")
        && str_contains($customerConfig, '^https://')
        && str_contains($envExample, 'PORTAL_CUSTOMER_BILLING_URL='),
    'T-10: la URL de facturación es opcional, solo https y se configura en el servidor.'
);

$billingView = $read('portal-clientes/Views/billing.php');
$check(
    str_contains($billingView, 'target="_blank"')
        && str_contains($billingView, 'rel="noopener noreferrer"'),
    'T-10: el enlace de facturación abre en pestaña nueva con rel seguro.'
);

$catalog = $read('portal/Services/InvoiceNinjaCatalogService.php');
$check(
    str_contains($catalog, "'GET'") && preg_match('/\b(POST|PUT|PATCH|DELETE)\b/', $catalog) !== 1,
    'T-10: Invoice Ninja se consulta solo con GET.'
);

$service = $read('portal/Services/ServiceRequestService.php');
$check(
    str_contains($service, 'removeOneFromSelection')
        && str_contains($service, '$current + $quantity'),
    'T-10: la selección acumula cantidades y permite quitar una unidad.'
);

$runtimeSources = implode("\n", [
    $config,
    $catalog,
    $service,
    $read('portal/Views/service-request.php'),
    $billingView,
]);
$check(
    preg_match('/(INVOICE_NINJA_API_TOKEN|SMTP_PASS|PORTAL_DB_PASS|SERVICE_REQUEST_DB_PASS)=[^\s\#]+/', $runtimeSources) !== 1,
    'T-10: no debe haber secretos con valor en el código de ejecución.'
);
$envBackups = glob($root . '/.env.bak.*') ?: [];
$check(
    $envBackups === [],
    'T-10: no debe haber copias de .env con secretos dentro del web root.'
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
    $check(str_starts_with($site, 'https://'), 'T-10: la URL de despliegue debe usar HTTPS.');

    if (str_starts_with($site, 'https://')) {
        $pages = [
            ['/es-AR', 'Origen Salud'],
            ['/docs?lang=es-AR', 'Documentaci'],
            ['/es-AR/dentar', 'DENTAR'],
            ['/es-AR/oftar', 'OFTAR'],
            ['/es-AR/sitemap', ''],
            ['/es-AR/portal', ''],
            ['/es-AR/portal-clientes', ''],
            ['/es-AR/solicitud', 'Solicitud de Servicios'],
            ['/en/solicitud', 'Service Request'],
            ['/pt-BR/solicitud', 'Solicita'],
        ];

        foreach ($pages as [$path, $needle]) {
            $response = HttpClient::request('GET', $site . $path, ['Accept: text/html'], null, 10);
            $check($response['status'] < 500, 'T-10: ' . $path . ' no debe responder 5xx.');
            if ($needle !== '') {
                $check(
                    $response['ok'] && str_contains($response['body'], $needle),
                    'T-10: ' . $path . ' debe contener el texto localizado esperado.'
                );
            }
            $check(
                !str_contains($response['body'], 'X-Api-Token')
                    && !str_contains($response['body'], 'INVOICE_NINJA_API_TOKEN')
                    && !str_contains($response['body'], 'SMTP_PASS'),
                'T-10: ' . $path . ' no debe exponer secretos en HTML.'
            );
            if ($path === '/es-AR') {
                $check(
                    !str_contains($response['body'], '/solicitud'),
                    'T-10: la home no debe enlazar la Solicitud de Servicios.'
                );
            }
        }

        $docsAlias = HttpClient::request('GET', $site . '/es-AR/docs', ['Accept: text/html'], null, 10);
        $check(
            $docsAlias['status'] === 302,
            'T-10: /es-AR/docs debe redirigir al centro de documentación canónico.'
        );

        $api = HttpClient::request('GET', $site . '/v1', ['Accept: application/json'], null, 10);
        $check($api['status'] < 500, 'T-10: la API pública no debe responder 5xx.');

        if ($allowPost) {
            $post = HttpClient::request(
                'POST',
                $site . '/es-AR/solicitud/enviar',
                ['Content-Type: application/x-www-form-urlencoded'],
                'organization=sin-csrf',
                10
            );
            $check($post['status'] === 303, 'T-10: POST sin CSRF debe redirigir con 303.');
            $check($post['status'] < 500, 'T-10: POST sin CSRF no debe provocar 5xx.');
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

echo 'OK: ' . $checks . ' comprobaciones de la Etapa 12.' . PHP_EOL;
