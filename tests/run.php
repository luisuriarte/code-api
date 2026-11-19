<?php

declare(strict_types=1);

/**
 * Tests básicos sin dependencias externas (además del autoload de Symfony YAML,
 * ya presente en el proyecto).
 *
 * Uso: php tests/run.php
 */

use OrigenSalud\Api\Http\ApiException;
use Symfony\Component\Yaml\Yaml;

$root = dirname(__DIR__);
require $root . '/vendor/autoload.php';

$failures = [];
$checks = 0;

$check = static function (bool $condition, string $message) use (&$failures, &$checks): void {
    $checks++;
    if (!$condition) {
        $failures[] = $message;
    }
};

// 1. ApiException::internalError() existe y no expone mensajes internos.
$internal = ApiException::internalError();
$check($internal->status === 500, 'internalError() debe devolver HTTP 500.');
$check($internal->errorCode === 'internal_error', 'internalError() debe usar error_code internal_error.');
$check($internal->details === [], 'internalError() no debe incluir details.');
$check(
    !str_contains($internal->getMessage(), 'PDO') && !str_contains($internal->getMessage(), 'SQLSTATE'),
    'internalError() no debe filtrar mensajes de PDO/SQLSTATE.'
);

$serviceSource = (string) file_get_contents($root . '/api/services/TerminologySearchService.php');
$check(
    !str_contains($serviceSource, "internalError('Error al consultar el catálogo LOINC: '"),
    'La rama LOINC no debe concatenar $e->getMessage().'
);
$check(
    substr_count($serviceSource, 'ApiException::internalError()') === 7,
    'Deben existir siete ramas degradadas a internalError() sin argumentos.'
);

// 2. OpenAPI 3.1: YAML válido y todas las referencias internas resueltas.
$specPath = $root . '/docs/api/openapi-3.1.yaml';
$spec = Yaml::parseFile($specPath);
$check(($spec['openapi'] ?? null) === '3.1.0', 'La spec debe ser OpenAPI 3.1.0.');
$check(isset($spec['paths']['/health']), 'La spec debe documentar /health.');
$check(isset($spec['paths']['/v1/search']), 'La spec debe documentar /v1/search.');
$check(!isset($spec['paths']['/fhir/metadata']), 'La spec no debe documentar /fhir/* como implementado.');

$missingRefs = [];
$walk = static function ($node, string $path = '') use (&$walk, &$missingRefs, $spec): void {
    if (!is_array($node)) {
        return;
    }
    foreach ($node as $key => $value) {
        if ($key === '$ref' && is_string($value) && str_starts_with($value, '#/')) {
            $parts = array_slice(explode('/', $value), 1);
            $target = $spec;
            foreach ($parts as $part) {
                $part = str_replace('~1', '/', str_replace('~0', '~', $part));
                if (!is_array($target) || !array_key_exists($part, $target)) {
                    $missingRefs[] = $path . ' -> ' . $value;
                    continue 2;
                }
                $target = $target[$part];
            }
        }
        $walk($value, $path . '/' . $key);
    }
};
$walk($spec);
$check($missingRefs === [], 'Referencias OpenAPI sin resolver: ' . implode(', ', $missingRefs));

// 3. Artefactos SQL: sintaxis básica y prohibiciones del plan de migración.
$sqlDir = $root . '/sql/08_arquitectura';
$sqlFiles = glob($sqlDir . '/*.sql') ?: [];
$check(count($sqlFiles) === 5, 'Deben existir cinco artefactos SQL propuestos.');
foreach ($sqlFiles as $file) {
    $sql = (string) file_get_contents($file);
    $name = basename($file);
    $check(str_starts_with(ltrim($sql), '--'), $name . ' debe comenzar con el aviso de no ejecución.');
    $check(str_contains($sql, 'BEGIN;') && str_contains($sql, 'COMMIT;'), $name . ' debe ser transaccional.');
    $check(!preg_match('/\bDROP\s+TABLE\b/i', $sql), $name . ' no debe DROP TABLE.');
    $check(!preg_match('/\bDROP\s+COLUMN\b/i', $sql), $name . ' no debe DROP COLUMN.');
    $check(!preg_match('/\bTRUNCATE\b/i', $sql), $name . ' no debe TRUNCATE.');
    $check(!preg_match('/\bDELETE\s+FROM\b/i', $sql), $name . ' no debe DELETE FROM.');
}

$uvrSql = (string) file_get_contents($sqlDir . '/fase6_uvr.sql');
$check(str_contains($uvrSql, "component_type IN (\n        'work', 'practice_expense', 'professional_liability'\n    )"), 'UVR debe conservar los tres componentes.');
$check(str_contains($uvrSql, 'total_uvr') || str_contains($uvrSql, 'COALESCE(c_work.value, 0)'), 'UVR debe derivar el total de los componentes.');
$check(!preg_match('/INSERT\s+INTO\s+os_uvr_(valuation|component|conversion|geo_index)/i', $uvrSql), 'No se deben cargar valores UVR.');

// 4. Relaciones CDT: cobertura de tipos en traducciones y en el repositorio.
$relationTypes = [
    'alternate_benefit', 'billed_in_conjunction_with', 'concurrent_to',
    'denied_as_integral', 'frequency_limitations', 'integral_to',
    'interchangeable_with', 'not_paid_separately', 'not_to_be_used_with',
    'paid_as_code', 'procedure_code_not_used_for', 'refer_to_details',
    'referencia_literal', 'shares_frequency_limitation_with',
    'used_in_combination_with',
];
foreach (['es-AR', 'en', 'pt-BR', 'es'] as $locale) {
    $messages = Yaml::parseFile($root . '/portal/translations/messages.' . $locale . '.yaml');
    $browse = $messages['browse'] ?? [];
    foreach ($relationTypes as $type) {
        $check(isset($browse['relation_' . $type]), $locale . ': falta relation_' . $type . '.');
    }
    $check(isset($browse['role_outgoing']), $locale . ': falta role_outgoing.');
    $check(isset($browse['role_incoming']), $locale . ': falta role_incoming.');
}

$repository = (string) file_get_contents($root . '/portal/Repositories/CatalogRepository.php');
$check(str_contains($repository, 'os_catalog_relation'), 'itemRelations() debe consultar os_catalog_relation.');
$check(str_contains($repository, "CASE WHEN r.source_item_id = ? THEN 'outgoing' ELSE 'incoming' END"), 'Debe distinguir relaciones salientes y entrantes.');
$check(
    str_contains($repository, 'item.permanent_code AS code'),
    'Los resultados DENTAR deben mostrar el código permanente DNT-PR/DNT-DX.'
);
$check(
    !str_contains($repository, 'coalesce(ident.value, item.permanent_code) AS code'),
    'El identificador externo (CIE-10/Nomenclador) no debe reemplazar al código DENTAR.'
);
$check(
    str_contains($repository, "'official_code', ident.value")
    && str_contains($repository, "'official_system', ident.system_name"),
    'El identificador externo debe conservarse como metadata secundaria.'
);
$resultsSource = (string) file_get_contents($root . '/portal/Views/partials/browse/results.php');
$check(
    str_contains($resultsSource, 'officialLabel')
    && str_contains($resultsSource, 'official_system'),
    'La fila debe mostrar el código DENTAR y, si existe, el identificador externo como badge.'
);

// 4b. Nomenclador Odontológico Nacional: catálogo propio + identificador secundario.
$nomencladorSqlPath = $root . '/sql/03_dentar/nomenclador_odontologico_nacional.sql';
$check(is_file($nomencladorSqlPath), 'Debe existir el artefacto del Nomenclador Odontológico Nacional.');
$nomencladorSql = is_file($nomencladorSqlPath) ? (string) file_get_contents($nomencladorSqlPath) : '';
$check(str_contains($nomencladorSql, 'nomenclador-odontologico-ar'), 'El artefacto debe registrar el catálogo propio.');
$check(str_contains($nomencladorSql, "'NOMENCLADOR_AR'"), 'DENTAR-PR debe conservar el identificador de origen.');
$syncSql = (string) file_get_contents($root . '/sql/03_dentar/sync_dentar_to_os.sql');
$check(
    str_contains($syncSql, "SELECT x.item_id, 'NOMENCLADOR_AR', x.external_code, FALSE"),
    'El sync no debe marcar el identificador del nomenclador como principal.'
);
$check(str_contains($nomencladorSql, 'referencia_literal'), 'El vínculo entre nomenclador y DENTAR-PR debe ser literal.');
$check(
    str_contains($nomencladorSql, 'sin juicio de equivalencia clínica'),
    'El artefacto no debe declarar equivalencias clínicas asumidas.'
);
$check(
    str_contains($nomencladorSql, "    ('01.01', 'Examen-Diagnóstico")
    && str_contains($nomencladorSql, "    ('11.02', 'Relleno óseo")
    && substr_count($nomencladorSql, "    ('") >= 135,
    'El artefacto debe conservar las 135 filas del dump MariaDB.'
);
$check(
    str_contains($repository, "'nomenclador-odontologico-ar'"),
    'El repositorio debe admitir el catálogo del nomenclador en la whitelist.'
);
$check(
    str_contains($repository, 'FROM os_catalog_identifier ki')
    && str_contains($repository, 'FROM os_catalog_identifier pi'),
    'La búsqueda debe consultar cualquier identificador real, no solo el principal.'
);
$check(
    str_contains($resultsSource, '$identifierSystemLabel($officialSystem)'),
    'El badge secundario debe usar la etiqueta pública del sistema de identificadores.'
);
$conceptSource = (string) file_get_contents($root . '/portal/Views/partials/browse/detail/concept.php');
$check(
    str_contains($conceptSource, "concept['source_attributes']")
    && str_contains($conceptSource, '$sourceAttributeLabel($attribute)'),
    'La ficha debe mostrar los campos literales del nomenclador cuando existan.'
);
$nomencladorKeys = [
    'identifier_system_nomenclador', 'identifier_system_dentar_dx',
    'source_attributes', 'source_attributes_note',
    'source_attribute_agrupamiento', 'yes', 'no', 'tag_source',
];
foreach (['es-AR', 'en', 'pt-BR', 'es'] as $locale) {
    $messages = Yaml::parseFile($root . '/portal/translations/messages.' . $locale . '.yaml');
    $browse = $messages['browse'] ?? [];
    foreach ($nomencladorKeys as $key) {
        $check(isset($browse[$key]), $locale . ': falta browse.' . $key . '.');
    }
    $dentarMessages = $messages['dentar'] ?? [];
    $check(isset($dentarMessages['nomenclador_badge']), $locale . ': falta dentar.nomenclador_badge.');
}

// 5. Documentación alineada con el estado real.
$dentarReadme = (string) file_get_contents($root . '/docs/dentar/README.md');
foreach (['844', '223', '624', '218', 'origen_codes', 'DENTAR-IN'] as $needle) {
    $check(str_contains($dentarReadme, $needle), 'docs/dentar/README.md debe mencionar ' . $needle . '.');
}
$apiReadme = (string) file_get_contents($root . '/README-API.md');
$check(!str_contains($apiReadme, 'DNT-000007'), 'README-API.md no debe usar el código inventado DNT-000007.');
$check(str_contains($apiReadme, 'DNT-PR-NNNNNN'), 'README-API.md debe documentar DNT-PR-NNNNNN.');
$fhirReadme = (string) file_get_contents($root . '/README-FHIR.md');
$check(str_contains($fhirReadme, 'contrato propuesto, no implementado'), 'README-FHIR.md debe declarar el estado no implementado.');

// 6. Navegación: enlace /cart roto resuelto y sitemap real.
foreach (['header.php', 'footer.php'] as $partial) {
    $source = (string) file_get_contents($root . '/portal/Views/partials/' . $partial);
    $check(!str_contains($source, "'/cart'"), $partial . ' no debe enlazar a /cart.');
    $check(str_contains($source, "#plataforma"), $partial . ' debe enlazar Servicios a #plataforma.');
}
$homeSource = (string) file_get_contents($root . '/portal/Views/home.php');
$check(!str_contains($homeSource, '/cart'), 'home.php no debe conservar la ruta rota /cart.');

$check(is_file($root . '/web/sitemap.php'), 'Debe existir web/sitemap.php para ^sitemap\\.xml$.');
ob_start();
require $root . '/web/sitemap.php';
$sitemapXml = (string) ob_get_clean();
$sitemapDoc = new DOMDocument();
$check($sitemapDoc->loadXML($sitemapXml), 'El sitemap generado debe ser XML válido.');
$check($sitemapDoc->getElementsByTagName('url')->length === 18, 'El sitemap debe tener 18 URLs (3 locales × 6 rutas).');
$check(!str_contains($sitemapXml, '/cart'), 'El sitemap no debe incluir /cart.');
$check(
    !str_contains($sitemapXml, 'dentar-an') && !str_contains($sitemapXml, 'dentar-cl'),
    'El sitemap no debe publicar AN/CL sin aprobación explícita.'
);
$check(
    !str_contains($sitemapXml, 'dentar-in') && !str_contains($sitemapXml, 'dentar-pd')
    && !str_contains($sitemapXml, 'dentar-eq'),
    'El sitemap no debe incluir catálogos reservados.'
);

// 7. Docs: página independiente, i18n equivalente y contrato real.
$docsSource = (string) file_get_contents($root . '/web/docs.php');
$check(str_contains($docsSource, "/docs?lang='"), 'Docs debe canónizar y cambiar idioma por /docs?lang=.');
$check(str_contains($docsSource, 'data-lang-link'), 'Docs debe renderizar su propio selector de idioma.');
$check(!str_contains($docsSource, 'I18n::alternateLinks'), 'Docs no debe usar alternateLinks() sobre la ruta legacy.');
$check(!str_contains($docsSource, 'language-switcher.php'), 'Docs no debe reutilizar el selector que genera /{locale}/docs.');
$check(str_contains($docsSource, 'docs-search-input'), 'Docs debe incluir búsqueda interna.');
$check(str_contains($docsSource, 'docs-toc-list'), 'Docs debe incluir índice contextual por artículo.');
$check(str_contains($docsSource, 'data-breadcrumb-article'), 'Docs debe incluir breadcrumbs dinámicos.');
$check(str_contains($docsSource, 'nomenclador-odontologico-ar'), 'Docs debe documentar el Nomenclador Odontológico Nacional.');
$check(str_contains($docsSource, 'dentar-pr'), 'Docs debe usar el catálogo real dentar-pr en los ejemplos.');
$check(str_contains($docsSource, 'DNT-PR-000001'), 'Docs debe usar ejemplos de código DENTAR coherentes.');
$check(!str_contains($docsSource, 'DNT-XXXXXX'), 'Docs no debe conservar el formato inventado DNT-XXXXXX.');
$check(!str_contains($docsSource, 'api.origen.ar/fhir'), 'Docs no debe publicar /fhir como entorno disponible.');
$check(!str_contains($docsSource, 'tab-btn active'), 'Docs no debe conservar el estado roto de pestañas del bloque LOINC.');
foreach (['$lookup', '$expand', '$translate'] as $fhirOperation) {
    $check(!str_contains($docsSource, $fhirOperation), 'Docs no debe documentar ' . $fhirOperation . ' como operación disponible.');
}
$check(substr_count($docsSource, '"request_id"') >= 4, 'Los envelopes de ejemplo deben incluir request_id.');

preg_match_all('/href="#([A-Za-z0-9_-]+)"/', $docsSource, $docsAnchors);
preg_match_all('/id="([A-Za-z0-9_-]+)"/', $docsSource, $docsIds);
preg_match_all("/renderSubhead\\('([A-Za-z0-9_-]+)'/", $docsSource, $docsSubheads);
$docsAvailableIds = array_merge($docsIds[1], $docsSubheads[1]);
foreach (array_unique($docsAnchors[1]) as $docsAnchor) {
    $check(in_array($docsAnchor, $docsAvailableIds, true), 'Docs: ancla rota #' . $docsAnchor . '.');
}

preg_match_all("/^\s+'(curl|php|python|java|javascript|csharp)' =>/m", $docsSource, $docsCodeLangs);
$docsExpectedLangs = ['csharp', 'curl', 'java', 'javascript', 'php', 'python'];
sort($docsExpectedLangs);
$docsActualLangs = array_values(array_unique($docsCodeLangs[1]));
sort($docsActualLangs);
$check($docsActualLangs === $docsExpectedLangs, 'Docs debe ofrecer exactamente los seis lenguajes de ejemplo acordados.');
$check(str_contains($docsSource, 'data-code-pane="'), 'Cada lenguaje de ejemplo debe tener un panel de código.');
$check(str_contains($docsSource, 'foreach ($snippets as $lang => $code)'), 'Los paneles de código deben derivarse del mismo conjunto de ejemplos.');

$docsFlat = [];
$docsKeySets = [];
foreach (['es-AR', 'en', 'pt-BR'] as $locale) {
    $messages = Yaml::parseFile($root . '/portal/translations/messages.' . $locale . '.yaml');
    $docsNode = $messages['docs'] ?? [];
    $flat = [];
    $flattenDocs = static function (array $node, string $prefix) use (&$flattenDocs, &$flat): void {
        foreach ($node as $key => $value) {
            $path = $prefix === '' ? (string) $key : $prefix . '.' . $key;
            if (is_array($value)) {
                $flattenDocs($value, $path);
            } else {
                $flat[$path] = $value;
            }
        }
    };
    $flattenDocs(is_array($docsNode) ? $docsNode : [], '');
    $docsFlat[$locale] = $flat;
    $docsKeySets[$locale] = array_keys($flat);
    foreach ($flat as $key => $value) {
        $check(is_string($value) && trim($value) !== '', 'Docs ' . $locale . ': valor vacío en docs.' . $key . '.');
    }
}
$docsBaseKeys = $docsKeySets['es-AR'];
sort($docsBaseKeys);
foreach (['en', 'pt-BR'] as $locale) {
    $localeKeys = $docsKeySets[$locale];
    sort($localeKeys);
    $check($localeKeys === $docsBaseKeys, 'Docs: paridad de claves entre es-AR y ' . $locale . '.');
}

preg_match_all("/\\\$t\\('([^']+)'/", $docsSource, $docsUsedKeys);
$docsArticles = ['overview', 'auth', 'conventions', 'quickstart', 'search', 'catalogs', 'mappings', 'clinical', 'dental', 'pending', 'openapi', 'support'];
$docsDynamicKeys = [];
foreach ($docsArticles as $docsArticle) {
    foreach (['title', 'lead', 'keywords'] as $docsField) {
        $docsDynamicKeys[] = 'docs.article.' . $docsArticle . '.' . $docsField;
    }
}
foreach (['start', 'core', 'domain', 'operations'] as $docsGroup) {
    $docsDynamicKeys[] = 'docs.nav.groups.' . $docsGroup;
}
foreach (['es', 'en', 'pt'] as $docsLanguage) {
    $docsDynamicKeys[] = 'docs.lang.' . $docsLanguage;
}
foreach (array_unique(array_merge($docsUsedKeys[1], $docsDynamicKeys)) as $docsKey) {
    if (!str_starts_with($docsKey, 'docs.') || str_ends_with($docsKey, '.')) {
        continue;
    }
    $check(array_key_exists(substr($docsKey, 5), $docsFlat['es-AR']), 'Docs: falta la clave ' . $docsKey . '.');
}
$check(
    str_contains($docsFlat['es-AR']['pending.fhir_text'], 'No existe ninguna ruta /fhir'),
    'Docs debe declarar FHIR como no implementado.'
);
$check(
    str_contains($docsFlat['es-AR']['dental.codes_text'], 'DNT-PR-NNNNNN')
    && str_contains($docsFlat['es-AR']['dental.codes_text'], 'DNT-DX-NNNNNN'),
    'Docs debe usar los formatos reales de códigos DENTAR-PR y DENTAR-DX.'
);

// Resultado.
if ($failures !== []) {
    fwrite(STDERR, "FALLOS (" . count($failures) . " de $checks):\n");
    foreach ($failures as $failure) {
        fwrite(STDERR, ' - ' . $failure . "\n");
    }
    exit(1);
}

echo "OK: $checks comprobaciones.\n";
