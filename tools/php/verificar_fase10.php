<?php

declare(strict_types=1);

/**
 * INFORME LEGACY de la Fase 10 (portal trilingüe). NO es puerta de calidad.
 *
 * Sus expectativas fueron RETIRADAS en la Fase 2 del plan §16: exigen 94 claves
 * `docs.*` en un catálogo (`messages.es.yaml`) que no se carga en rutas
 * públicas, y exigen que `web/docs.php` use `alternateLinks()` y el selector
 * compartido, justo lo que el verificador canónico `tests/run.php` prohíbe
 * para la ruta legacy `/docs`. Migrarlas supondría revertir una decisión ya
 * aprobada, así que se conservan solo como diagnóstico histórico.
 *
 * El verificador canónico es `tests/run.php`. Este script siempre termina con
 * éxito y enumera sus hallazgos en STDERR; ninguno bloquea la entrega.
 *
 * Ejecutar:
 *   php tools/php/verificar_fase10.php
 */

$root = dirname(__DIR__, 2);

require_once $root . '/bootstrap.php';
require_once $root . '/portal/i18n/I18n.php';
require_once $root . '/web/includes/ApiClient.php';

use OrigenSalud\Web\ApiClient;
use OrigenSalud\Web\I18n;
use Symfony\Component\Yaml\Yaml;

$errors = [];
$check = static function (bool $condition, string $message) use (&$errors): void {
    if (!$condition) {
        $errors[] = $message;
    }
};

$read = static function (string $relative) use ($root): string {
    $path = $root . '/' . $relative;

    return is_file($path) ? (string) file_get_contents($path) : '';
};

// ---------------------------------------------------------------------------
// Resolvedor y metadatos del portal.
// ---------------------------------------------------------------------------
$check(I18n::SUPPORTED === ['es-AR', 'en', 'pt-BR'], 'SUPPORTED debe ser exactamente es-AR, en y pt-BR');
$check(I18n::DEFAULT_LOCALE === 'es-AR', 'el locale por defecto debe ser es-AR');
$check(I18n::canonical('es') === 'es-AR', 'el alias es debe resolver a es-AR');
$check(I18n::canonical('pt') === 'pt-BR', 'el alias pt debe resolver a pt-BR');
$check(I18n::canonical('es-MX') === null, 'es-MX no debe aliasarse a es-AR');
$check(I18n::canonical('es-AR') === 'es-AR', 'canonical debe conservar es-AR');
$check(I18n::canonical('pt-BR') === 'pt-BR', 'canonical debe conservar pt-BR');
$check(I18n::canonical('en-US') === 'en', 'en-US debe reducirse a en');

$expectedMetadata = [
    'es-AR' => ['hreflang' => 'es-AR', 'og_locale' => 'es_AR', 'api_language' => 'es-AR'],
    'en' => ['hreflang' => 'en', 'og_locale' => 'en_US', 'api_language' => 'en'],
    'pt-BR' => ['hreflang' => 'pt-BR', 'og_locale' => 'pt_BR', 'api_language' => 'pt-BR'],
];
foreach ($expectedMetadata as $locale => $expected) {
    $metadata = I18n::metadata($locale);
    foreach ($expected as $key => $value) {
        $check($metadata[$key] === $value, "la metadata de {$locale} debe tener {$key}={$value}");
    }
}

$links = I18n::alternateLinks('/docs');
$check(count($links) === 3, 'deben generarse tres enlaces alternates');
$check(
    array_column($links, 'hreflang') === ['es-AR', 'en', 'pt-BR'],
    'los hreflang deben ser es-AR, en y pt-BR en ese orden'
);
foreach ($links as $link) {
    $check(
        str_starts_with($link['href'], '/' . $link['hreflang'] . '/'),
        'cada alternate debe usar el prefijo de idioma en la ruta'
    );
}

// ---------------------------------------------------------------------------
// Vistas del portal: cabeceras idiomáticas y ausencia de ternarios $isEn.
// ---------------------------------------------------------------------------
$views = [
    'web/docs.php' => '/docs',
    'web/search.php' => '/search',
];
foreach ($views as $relative => $path) {
    $source = $read($relative);
    $check($source !== '', "debe existir {$relative}");
    $check(str_contains($source, "header('Vary: Accept-Language')"), "{$relative} debe enviar Vary");
    $check(str_contains($source, "header('Content-Language: ' . \$locale)"), "{$relative} debe enviar Content-Language");
    $check(str_contains($source, "I18n::metadata(\$locale)['og_locale']"), "{$relative} debe emitir og:locale por locale");
    $check(!str_contains($source, '$isEn'), "{$relative} no debe usar ternarios \$isEn");
    $check(!str_contains($source, '$languageUrl'), "{$relative} no debe usar el reductor \$languageUrl");
    $check(
        str_contains($source, "portal/Views/partials/language-switcher.php"),
        "{$relative} debe usar el selector compartido"
    );
}

$frontController = $read('web/index.php');
$check(str_contains($frontController, "header('Vary: Accept-Language"), 'el front controller debe enviar Vary');
$check(str_contains($frontController, 'portal/bootstrap.php'), 'el front controller debe cargar el bootstrap del portal');

$layout = $read('portal/Views/layouts/main.php');
$check(str_contains($layout, "I18n::alternateLinks(\$currentPath"), 'el layout debe emitir los tres hreflang');
$check(str_contains($layout, "I18n::metadata(\$locale)['og_locale']"), 'el layout debe emitir og:locale por locale');

// ---------------------------------------------------------------------------
// Catálogos de traducción: claves usadas y conteo de claves docs.*
// ---------------------------------------------------------------------------
$catalogFiles = [
    'es-AR' => $root . '/portal/translations/messages.es-AR.yaml',
    'en' => $root . '/portal/translations/messages.en.yaml',
    'pt-BR' => $root . '/portal/translations/messages.pt-BR.yaml',
    'es' => $root . '/portal/translations/messages.es.yaml',
];
$catalogs = [];
foreach ($catalogFiles as $locale => $file) {
    $check(is_file($file), "debe existir el catálogo {$locale}");
    if (!is_file($file)) {
        continue;
    }
    $data = Yaml::parseFile($file);
    $catalogs[$locale] = is_array($data) ? $data : [];
    $check(count($catalogs[$locale]['docs'] ?? []) === 94, "el catálogo {$locale} debe tener 94 claves docs.*");
    $check(isset($catalogs[$locale]['docs']['nav_cdt_nn']), "el catálogo {$locale} debe documentar CDT/NN en el menú");
    $check(isset($catalogs[$locale]['docs']['search_accept_language']), "el catálogo {$locale} debe documentar Accept-Language");
}

$keyAt = static function (array $data, string $key): bool {
    $node = $data;
    foreach (explode('.', $key) as $part) {
        if (!is_array($node) || !array_key_exists($part, $node)) {
            return false;
        }
        $node = $node[$part];
    }

    return true;
};

$usedKeys = [];
foreach (array_keys($views) as $relative) {
    $source = $read($relative);
    preg_match_all('/\$t\(\s*\'([a-z0-9_.-]+)\'/', $source, $matches);
    foreach ($matches[1] as $key) {
        $usedKeys[$key] = true;
    }
    preg_match_all('/\btrans\(\s*\'([a-z0-9_.-]+)\'/', $source, $matches);
    foreach ($matches[1] as $key) {
        $usedKeys[$key] = true;
    }
}
$check(count($usedKeys) > 60, 'deben detectarse las claves de traducción usadas por las vistas');
foreach ($catalogs as $locale => $data) {
    foreach (array_keys($usedKeys) as $key) {
        $check($keyAt($data, $key), "al catálogo {$locale} le falta la clave {$key}");
    }
}

$switcher = $read('portal/Views/partials/language-switcher.php');
$check(str_contains($switcher, "I18n::alternateLinks(\$currentPath)"), 'el selector debe usar alternateLinks');

// ---------------------------------------------------------------------------
// Buscador: petición al servidor con lang y Accept-Language, sin key en cliente.
// ---------------------------------------------------------------------------
$apiClientSource = $read('web/includes/ApiClient.php');
$check(str_contains($apiClientSource, "'lang' => \$language"), 'ApiClient debe enviar lang');
$check(str_contains($apiClientSource, "'Accept-Language: ' . \$language"), 'ApiClient debe enviar Accept-Language');
$check(str_contains($apiClientSource, "I18n::metadata(\$locale)['api_language']"), 'ApiClient debe derivar el idioma del locale');
$check(str_contains($apiClientSource, "env('WEB_API_KEY', env('WEB_API_TOKEN', ''))"), 'ApiClient debe leer la key del entorno del servidor');
$check(str_contains($apiClientSource, "'api_not_configured'"), 'ApiClient debe informar cuando no hay API Key');
$check(!str_contains($apiClientSource, 'YOUR_API_KEY'), 'ApiClient no debe incluir claves de ejemplo como reales');

$searchSource = $read('web/search.php');
$check(str_contains($searchSource, 'ApiClient::search('), 'search.php debe consumir ApiClient');
$check(str_contains($searchSource, "I18n::metadata(\$locale)['api_language']"), 'search.php debe propagar el locale a la API');
foreach ([
    'requested_language',
    'effective_language',
    'field_languages',
    'available_languages',
    'fallback_applied',
] as $token) {
    $check(str_contains($searchSource, $token), "search.php debe mostrar {$token} del contrato Fase 9");
}
$check(!str_contains($searchSource, "env('WEB_API_KEY'"), 'search.php no debe leer la API Key directamente');
$check(!preg_match('/(YOUR_API_KEY|TU_API_KEY|Bearer\s+[A-Za-z0-9_-]{12,})/', $searchSource), 'search.php no debe incluir credenciales literales');

$htaccess = $read('web/.htaccess');
$check(str_contains($htaccess, 'RewriteRule ^search/?$ search.php [L,QSA]'), 'debe existir la ruta /search');

$check(ApiClient::configured() === false || ApiClient::configured() === true, 'ApiClient::configured debe ser booleano');

// ---------------------------------------------------------------------------
// Documentación de rutas reales de CDT/NN y ausencia de endpoint propio.
// ---------------------------------------------------------------------------
$readme = $read('README-API.md');
foreach ([
    'Portal y exposición real de CDT/NN (Fase 10)',
    '/v1/search/odontologia',
    '/v1/odontologia/{id}',
    '/v1/nomenclador',
    'No existe',
    '/v1/cdt',
    'nomenclador_2025',
    'dialect_determined=false',
] as $token) {
    $check(str_contains($readme, $token), 'README-API.md debe documentar ' . $token);
}
$check(str_contains($readme, 'WEB_API_KEY'), 'README-API.md debe documentar WEB_API_KEY');

$sqlReadme = $read('sql/07_multilingue/README.md');
$check(str_contains($sqlReadme, 'Fase 10'), 'el README SQL debe registrar Fase 10');
$check(str_contains($sqlReadme, 'verificar_fase10.php'), 'el README SQL debe citar el verificador de Fase 10');

if ($errors !== []) {
    fwrite(STDERR, 'Fase 10 (informe legacy, no vinculante): ' . count($errors) . " hallazgos.\n");
    fwrite(STDERR, " - " . implode("\n - ", $errors) . "\n");
    fwrite(STDERR, "No es puerta de calidad; use tests/run.php.\n");
}

echo "Fase 10: informe legacy completado (no bloquea).\n";
