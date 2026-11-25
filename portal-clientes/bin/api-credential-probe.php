<?php

declare(strict_types=1);

/**
 * Prueba HTTP real acotada de la Etapa 8 (acta-autorizacion-etapa-8.md, punto 7).
 *
 * Solo GET contra https://api.origen.ar. Nunca imprime la clave, el cuerpo de
 * la respuesta ni datos clínicos. La clave se lee del entorno del servidor.
 *
 * Uso en el VPS, antes de revocar:
 *   PORTAL_CUSTOMER_API_TEST_KEY=<clave-de-prueba> \
 *   php portal-clientes/bin/api-credential-probe.php
 *
 * Después de revocar la credencial de prueba:
 *   PORTAL_CUSTOMER_API_TEST_KEY=<clave-de-prueba> \
 *   PORTAL_CUSTOMER_API_TEST_EXPECT=401 \
 *   php portal-clientes/bin/api-credential-probe.php
 */

require_once dirname(__DIR__, 2) . '/bootstrap.php';

if (PHP_SAPI !== 'cli') {
    exit(1);
}

$key = (string) env('PORTAL_CUSTOMER_API_TEST_KEY', '');
if ($key === '' || strlen($key) > 128 || preg_match('/^[\x21-\x7E]+$/', $key) !== 1) {
    fwrite(STDERR, "FAIL: configure PORTAL_CUSTOMER_API_TEST_KEY solo en el servidor.\n");
    exit(2);
}

$base = rtrim((string) env('PORTAL_CUSTOMER_API_TEST_BASE_URL', 'https://api.origen.ar'), '/');
$parts = parse_url($base);
if (!is_array($parts) || ($parts['scheme'] ?? '') !== 'https' || ($parts['host'] ?? '') !== 'api.origen.ar') {
    fwrite(STDERR, "FAIL: la prueba real solo se permite contra https://api.origen.ar.\n");
    exit(2);
}

$expect = (string) env('PORTAL_CUSTOMER_API_TEST_EXPECT', '200');
if (!in_array($expect, ['200', '401'], true)) {
    fwrite(STDERR, "FAIL: PORTAL_CUSTOMER_API_TEST_EXPECT debe ser 200 o 401.\n");
    exit(2);
}

if (!function_exists('curl_init')) {
    fwrite(STDERR, "FAIL: falta la extensión curl de PHP.\n");
    exit(2);
}

$failed = false;
foreach (['/health', '/v1/domains'] as $path) {
    $handle = curl_init($base . $path);
    if ($handle === false) {
        fwrite(STDERR, "FAIL: no se pudo iniciar la solicitud a " . $path . ".\n");
        $failed = true;
        continue;
    }

    curl_setopt_array($handle, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPGET => true,
        CURLOPT_TIMEOUT => 8,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_HTTPHEADER => ['X-API-Key: ' . $key, 'Accept: application/json'],
    ]);

    // El cuerpo se descarta: la prueba solo comprueba códigos de respuesta.
    curl_exec($handle);
    $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    $error = curl_error($handle);
    curl_close($handle);

    if ($error !== '') {
        echo 'FAIL ' . $path . " => error de red\n";
        $failed = true;
        continue;
    }

    $ok = $status === (int) $expect;
    echo ($ok ? 'OK' : 'FAIL') . ' ' . $path . ' => ' . $status . ' (esperado ' . $expect . ")\n";
    if (!$ok) {
        $failed = true;
    }
}

exit($failed ? 1 : 0);
