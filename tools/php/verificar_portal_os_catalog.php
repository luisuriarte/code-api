<?php

declare(strict_types=1);

require dirname(__DIR__, 2) . '/portal/bootstrap.php';

use OrigenSalud\Portal\Repositories\CatalogRepository;

$check = static function (bool $condition, string $message): void {
    if (!$condition) {
        throw new RuntimeException($message);
    }
};

$reflection = new ReflectionClass(CatalogRepository::class);
$mapConstant = $reflection->getReflectionConstant('OS_CATALOG_DOMAIN_TYPES');
$check($mapConstant !== false, 'Falta OS_CATALOG_DOMAIN_TYPES en CatalogRepository.');
$map = $mapConstant->getValue();

$validDomains = CatalogRepository::DOMAINS;
foreach (array_keys($map) as $domain) {
    $check(in_array($domain, $validDomains, true), "Dominio no aprobado en el mapeo: {$domain}");
}

$engineSql = file_get_contents(dirname(__DIR__, 2) . '/sql/02_catalogs/origen_catalog_engine.sql');
$check($engineSql !== false, 'No se pudo leer el SQL del motor os_catalog.');
foreach (['dental', 'biochemical', 'medical', 'mental_health', 'rehabilitation', 'pharma'] as $type) {
    $check(str_contains($engineSql, "'{$type}'"), "domain_type no documentado: {$type}");
}

$method = $reflection->getMethod('osCatalogBranch');
$method->setAccessible(true);

foreach ($map as $domain => $types) {
    foreach ([false, true] as $byKey) {
        [$sql, $params] = $method->invoke(
            null,
            'p0',
            $domain,
            $types,
            'glucemia',
            'es',
            'es-AR',
            $byKey,
            'os_catalog:dentar-pr:1'
        );
        $sqlWithoutLiterals = preg_replace("/'(?:''|[^'])*'/", "''", $sql);
        preg_match_all('/:([a-z0-9_]+)/i', (string) $sqlWithoutLiterals, $matches);
        $used = array_unique($matches[1]);
        $bound = array_map(static fn (string $name): string => ltrim($name, ':'), array_keys($params));
        $check(
            array_diff($used, $bound) === [] && array_diff($bound, $used) === [],
            "Parámetros SQL incompletos en {$domain} byKey=" . ($byKey ? 'yes' : 'no')
        );
    }
}

$permissions = file_get_contents(dirname(__DIR__, 2) . '/sql/portal/01_origen_med_permisos.sql');
$check($permissions !== false, 'No se pudo leer el script de permisos del portal.');
foreach (['os_catalog', 'os_catalog_item', 'os_catalog_item_version', 'os_catalog_term', 'os_field_review'] as $table) {
    $check(str_contains($permissions, 'public.' . $table), "Falta GRANT para {$table}");
}

echo "Portal os_catalog: verificaciones OK\n";
