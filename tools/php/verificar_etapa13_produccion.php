<?php

declare(strict_types=1);

/**
 * Verificación de la Etapa 13 (producción real del portal de clientes).
 *
 * Modo local, sin red:
 *   php tools/php/verificar_etapa13_produccion.php
 *
 * Modo HTTP antes de activar enlaces:
 *   php tools/php/verificar_etapa13_produccion.php --site=https://med.origen.ar
 *
 * Modo HTTP después de activar enlaces:
 *   php tools/php/verificar_etapa13_produccion.php --site=https://med.origen.ar --links-enabled
 *
 * No ejecuta SQL, no cambia archivos, no imprime secretos.
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
// Autorización y procedimiento.
// ---------------------------------------------------------------------------
$acta = $read('docs/portal-clientes/acta-autorizacion-etapa-13.md');
$check(
    str_contains($acta, '> **Estado:** AUTORIZADA')
        && str_contains($acta, 'Token real de Invoice Ninja prohibido'),
    'T-13: debe existir el acta con la excepción explícita del token real.'
);
$check(
    str_contains($acta, 'PORTAL_SERVICE_REQUEST_LINK_ENABLED=true')
        && str_contains($acta, '**No recibe cambios de esquema ni datos.**'),
    'T-13: el acta debe autorizar enlaces y prohibir cambios en origen_codes.'
);
$check(
    str_contains($acta, 'no hace commit, push ni deploy'),
    'T-13: el acta debe excluir commit/deploy del asistente.'
);

$plan = $read('docs/portal-clientes/plan-etapa-13-produccion.md');
$check(
    str_contains($plan, 'origen_codes_portal_clientes')
        && str_contains($plan, 'No ejecutar `V10.002`'),
    'T-13: el plan debe crear la base operativa y no reejecutar V10.002.'
);
$check(
    str_contains($plan, '## 3. Backup previo') && str_contains($plan, '## 9. Rollback'),
    'T-13: el plan debe incluir backup previo y rollback.'
);

$manifiesto = $read('docs/portal-clientes/manifiesto-etapa-13-produccion.md');
$check(
    str_contains($manifiesto, 'INVOICE_NINJA_ALLOW_LIVE_CALLS=true')
        && str_contains($manifiesto, 'PORTAL_SERVICE_REQUEST_LINK_ENABLED=false'),
    'T-13: el manifiesto debe documentar los flags de producción y de enlaces.'
);

$informe = $read('docs/portal-clientes/informe-ejecucion-etapa-13.md');
$check(
    (str_contains($informe, '> **Estado:** pendiente de ejecución')
        || str_contains($informe, '> **Estado:** cerrada'))
        && str_contains($informe, '## 6. Rollback'),
    'T-13: debe existir el informe con estado y rollback.'
);

// ---------------------------------------------------------------------------
// SQL: guardas estrictas y sin datos personales.
// ---------------------------------------------------------------------------
foreach (['ETAPA13__preflight.sql', 'ETAPA13__verificacion_produccion.sql'] as $sqlFile) {
    $sql = $read('sql/10_portal_clientes/' . $sqlFile);
    $check(
        str_contains($sql, "current_database() <> 'origen_codes_portal_clientes'"),
        'T-13: ' . $sqlFile . ' debe exigir la base operativa exacta.'
    );
    $check(
        str_contains($sql, 'BEGIN READ ONLY') && str_contains($sql, 'ROLLBACK'),
        'T-13: ' . $sqlFile . ' debe ser SELECT-only.'
    );
}
$verificationSql = $read('sql/10_portal_clientes/ETAPA13__verificacion_produccion.sql');
$check(
    str_contains($verificationSql, 'permisos_solicitud_ok')
        && str_contains($verificationSql, 'columnas_prohibidas'),
    'T-13: la verificación debe cubrir permisos y columnas prohibidas.'
);

foreach (['up.sql', 'down.sql'] as $step) {
    foreach (['V5.001__os_customer_identity', 'V6.001__invoice_ninja_links'] as $migration) {
        $sql = $read('sql/10_portal_clientes/' . $migration . '.' . $step);
        $check(
            str_contains($sql, "current_database() NOT LIKE 'origen_codes_portal_clientes%'"),
            'T-13: ' . $migration . ' ' . $step . ' debe rechazar origen_codes.'
        );
    }
}
$devReset = $read('sql/10_portal_clientes/DEV_ONLY__reset_os_customer.sql');
$check(
    str_contains($devReset, "current_database() = 'origen_codes'"),
    'T-13: el reseteo de desarrollo debe seguir prohibiendo origen_codes.'
);

// ---------------------------------------------------------------------------
// Configuración y enlaces.
// ---------------------------------------------------------------------------
$config = $read('portal/Config.php');
$check(
    str_contains($config, "env('INVOICE_NINJA_ALLOW_LIVE_CALLS', false)")
        && str_contains($config, 'invoiceNinjaLiveEnabled'),
    'T-13: debe existir el opt-in de producción y su comprobación.'
);
$check(
    str_contains($config, 'allow_test_calls\'] === true && $config[\'allow_live_calls\'] === true')
        && str_contains($config, 'return false;'),
    'T-13: los dos modos activos a la vez deben deshabilitar las llamadas.'
);
$check(
    str_contains($config, "env('PORTAL_SERVICE_REQUEST_LINK_ENABLED', false)")
        && str_contains($config, 'serviceRequestLinkEnabled'),
    'T-13: los enlaces deben depender de un flag del servidor.'
);

$nav = $read('portal/Views/partials/nav-links.php');
$footer = $read('portal/Views/partials/footer.php');
$home = $read('portal/Views/home.php');
foreach (['nav' => $nav, 'footer' => $footer, 'home' => $home] as $name => $source) {
    $check(
        str_contains($source, 'Config::serviceRequestLinkEnabled()')
            && str_contains($source, '/solicitud'),
        'T-13: ' . $name . ' debe mostrar el enlace solo tras opt-in.'
    );
}
$check(
    !str_contains($read('portal/Views/partials/header.php'), '/solicitud'),
    'T-13: el header no debe exponer la Solicitud de Servicios.'
);

$catalog = $read('portal/Services/InvoiceNinjaCatalogService.php');
$check(
    str_contains($catalog, "'GET'") && preg_match('/\b(POST|PUT|PATCH|DELETE)\b/', $catalog) !== 1,
    'T-13: Invoice Ninja se consulta solo con GET.'
);

$envExample = $read('.env.example');
$check(
    str_contains($envExample, 'INVOICE_NINJA_ALLOW_LIVE_CALLS=false')
        && str_contains($envExample, 'PORTAL_SERVICE_REQUEST_LINK_ENABLED=false'),
    'T-13: .env.example debe documentar ambos flags en false.'
);
$check(
    preg_match('/(PORTAL_CUSTOMER_DB_PASS|PORTAL_CUSTOMER_CREDENTIAL_DB_PASS|SERVICE_REQUEST_DB_PASS|INVOICE_NINJA_API_TOKEN|SMTP_PASS|PORTAL_DB_PASS)=[^\s\#]+/', $envExample) !== 1
        && preg_match('/PORTAL_CUSTOMER_API_TEST_KEY=[^\s\#]+/', $envExample) !== 1,
    'T-13: .env.example no debe contener valores secretos.'
);
$check(
    str_contains($envExample, 'dbname=origen_codes_portal_clientes_test'),
    'T-13: el ejemplo debe seguir apuntando a la base de prueba, nunca a secretos de producción.'
);

$documents = $acta . $plan . $manifiesto . $informe;
$check(
    !str_contains($documents, '/cart') && preg_match('/\bcarrito\b/i', $documents) !== 1,
    'T-13: la documentación no debe usar «cart» ni «carrito».'
);

// ---------------------------------------------------------------------------
// Modo HTTP opcional.
// ---------------------------------------------------------------------------
$site = null;
$linksEnabled = false;
foreach (array_slice($argv, 1) as $argument) {
    if (str_starts_with($argument, '--site=')) {
        $site = rtrim((string) substr($argument, strlen('--site=')), '/');
    } elseif ($argument === '--links-enabled') {
        $linksEnabled = true;
    } else {
        fwrite(STDERR, 'Opción desconocida: ' . $argument . PHP_EOL);
        exit(2);
    }
}

if ($site !== null) {
    $check(str_starts_with($site, 'https://'), 'T-13: la URL de despliegue debe usar HTTPS.');

    if (str_starts_with($site, 'https://')) {
        $pages = [
            ['/es-AR/', 'Origen Salud'],
            ['/docs?lang=es-AR', 'Documentaci'],
            ['/dentar?lang=es-AR', ''],
            ['/oftar?lang=es-AR', ''],
            ['/sitemap?lang=es-AR', ''],
            ['/portal-clientes/es-AR', ''],
            ['/es-AR/solicitud', 'Solicitud de Servicios'],
            ['/en/solicitud', 'Service Request'],
            ['/pt-BR/solicitud', 'Solicita'],
        ];

        foreach ($pages as [$path, $needle]) {
            $response = HttpClient::request('GET', $site . $path, ['Accept: text/html'], null, 10);
            $check($response['status'] < 500, 'T-13: ' . $path . ' no debe responder 5xx.');
            if ($needle !== '') {
                $check(
                    $response['ok'] && str_contains($response['body'], $needle),
                    'T-13: ' . $path . ' debe contener el texto localizado esperado.'
                );
            }
            $check(
                !str_contains($response['body'], 'INVOICE_NINJA_API_TOKEN')
                    && !str_contains($response['body'], 'SMTP_PASS')
                    && !str_contains($response['body'], 'X-Api-Token'),
                'T-13: ' . $path . ' no debe exponer secretos en HTML.'
            );
        }

        $home = HttpClient::request('GET', $site . '/es-AR/', ['Accept: text/html'], null, 10);
        if ($linksEnabled) {
            $check(
                str_contains($home['body'], '/es-AR/solicitud'),
                'T-13: con el flag activo, la home debe enlazar la Solicitud de Servicios.'
            );
        } else {
            $check(
                !str_contains($home['body'], '/solicitud'),
                'T-13: con el flag inactivo, la home no debe enlazar la Solicitud de Servicios.'
            );
            echo "Nota: enlaces comprobados como ocultos; usar --links-enabled tras activarlos.\n";
        }

        $api = HttpClient::request('GET', $site . '/v1', ['Accept: application/json'], null, 10);
        $check($api['status'] < 500, 'T-13: la API pública no debe responder 5xx.');
    }
} else {
    echo "Nota: comprobaciones HTTP omitidas; usar --site=... .\n";
}

if ($failures !== []) {
    fwrite(STDERR, 'FALLOS (' . count($failures) . ' de ' . $checks . '):' . PHP_EOL);
    foreach ($failures as $failure) {
        fwrite(STDERR, ' - ' . $failure . PHP_EOL);
    }
    exit(1);
}

echo 'OK: ' . $checks . ' comprobaciones de la Etapa 13.' . PHP_EOL;
