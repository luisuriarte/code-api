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
foreach (['header.php', 'footer.php', 'nav-links.php'] as $partial) {
    $source = (string) file_get_contents($root . '/portal/Views/partials/' . $partial);
    $check(!str_contains($source, "'/cart'"), $partial . ' no debe enlazar a /cart.');
}
foreach (['footer.php', 'nav-links.php'] as $partial) {
    $source = (string) file_get_contents($root . '/portal/Views/partials/' . $partial);
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

// 8. UVR: metodología propuesta, página independiente e i18n equivalente.
$uvrSource = (string) file_get_contents($root . '/web/uvr.php');
$check(str_contains($uvrSource, "/uvr?lang='"), 'UVR debe canónizar y cambiar idioma por /uvr?lang=.');
$check(str_contains($uvrSource, 'data-lang-link'), 'UVR debe renderizar su propio selector de idioma.');
$check(!str_contains($uvrSource, 'language-switcher.php'), 'UVR no debe reutilizar el selector legacy.');
$check(!str_contains($uvrSource, 'I18n::alternateLinks'), 'UVR no debe usar alternateLinks() sobre la ruta legacy.');
$check(str_contains($uvrSource, 'uvr-search-input'), 'UVR debe incluir búsqueda interna.');
$check(str_contains($uvrSource, 'uvr-toc-list'), 'UVR debe incluir índice contextual.');
$check(str_contains($uvrSource, 'data-breadcrumb-article'), 'UVR debe incluir breadcrumbs dinámicos.');
$check(str_contains($uvrSource, 'data-formula'), 'UVR debe permitir copiar fórmulas.');
$check(str_contains($uvrSource, 'README-UVR.md'), 'UVR debe declarar README-UVR.md como fuente.');
$check(!str_contains($uvrSource, '/v1/uvr'), 'UVR no debe presentar endpoints inexistentes.');
$check(!str_contains($uvrSource, 'professioniabial'), 'UVR no debe reproducir el error tipográfico del README.');
$check(str_contains($docsSource, '/uvr?lang='), 'Docs debe enlazar a la metodología UVR.');

preg_match_all('/href="#([A-Za-z0-9_-]+)"/', $uvrSource, $uvrAnchors);
preg_match_all('/id="([A-Za-z0-9_-]+)"/', $uvrSource, $uvrIds);
preg_match_all("/renderSubhead\\('([A-Za-z0-9_-]+)'/", $uvrSource, $uvrSubheads);
preg_match_all("/renderFormula\\('[^']+', '([A-Za-z0-9_-]+)'/", $uvrSource, $uvrFormulas);
$uvrAvailableIds = array_merge($uvrIds[1], $uvrSubheads[1], $uvrFormulas[1]);
foreach (array_unique($uvrAnchors[1]) as $uvrAnchor) {
    $check(in_array($uvrAnchor, $uvrAvailableIds, true), 'UVR: ancla rota #' . $uvrAnchor . '.');
}
$check(count($uvrFormulas[1]) === 7, 'UVR debe publicar siete fórmulas copiables.');
$check(substr_count($uvrSource, 'data-article="') === 16, 'UVR debe publicar 16 secciones.');

$uvrFlat = [];
$uvrKeySets = [];
foreach (['es-AR', 'en', 'pt-BR'] as $locale) {
    $messages = Yaml::parseFile($root . '/portal/translations/messages.' . $locale . '.yaml');
    $uvrNode = $messages['uvr'] ?? [];
    $flat = [];
    $flattenUvr = static function (array $node, string $prefix) use (&$flattenUvr, &$flat): void {
        foreach ($node as $key => $value) {
            $path = $prefix === '' ? (string) $key : $prefix . '.' . $key;
            if (is_array($value)) {
                $flattenUvr($value, $path);
            } else {
                $flat[$path] = $value;
            }
        }
    };
    $flattenUvr(is_array($uvrNode) ? $uvrNode : [], '');
    $uvrFlat[$locale] = $flat;
    $uvrKeySets[$locale] = array_keys($flat);
    foreach ($flat as $key => $value) {
        $check(is_string($value) && trim($value) !== '', 'UVR ' . $locale . ': valor vacío en uvr.' . $key . '.');
    }
}
$uvrBaseKeys = $uvrKeySets['es-AR'];
sort($uvrBaseKeys);
foreach (['en', 'pt-BR'] as $locale) {
    $uvrLocaleKeys = $uvrKeySets[$locale];
    sort($uvrLocaleKeys);
    $check($uvrLocaleKeys === $uvrBaseKeys, 'UVR: paridad de claves entre es-AR y ' . $locale . '.');
}

preg_match_all("/'uvr\\.([A-Za-z0-9_.]+)'/", $uvrSource, $uvrUsedKeys);
$uvrSections = ['status', 'intro', 'concept', 'components', 'calculation', 'determination', 'scale', 'geographic', 'monetary', 'distinction', 'rvu', 'sources', 'traceability', 'governance', 'scope', 'roadmap'];
$uvrDynamicKeys = [];
foreach ($uvrSections as $uvrSection) {
    foreach (['title', 'lead', 'keywords'] as $uvrField) {
        $uvrDynamicKeys[] = 'article.' . $uvrSection . '.' . $uvrField;
    }
}
foreach (['foundation', 'model', 'operations'] as $uvrGroup) {
    $uvrDynamicKeys[] = 'nav.groups.' . $uvrGroup;
}
foreach (['es', 'en', 'pt'] as $uvrLanguage) {
    $uvrDynamicKeys[] = 'lang.' . $uvrLanguage;
}
foreach (array_unique(array_merge($uvrUsedKeys[1], $uvrDynamicKeys)) as $uvrKey) {
    if (str_ends_with($uvrKey, '.')) {
        continue;
    }
    $check(array_key_exists($uvrKey, $uvrFlat['es-AR']), 'UVR: falta la clave uvr.' . $uvrKey . '.');
}
$check(
    str_contains($uvrFlat['es-AR']['status.pending_text'], 'ningún endpoint de la API pública'),
    'UVR debe declarar que no hay endpoints de valoración.'
);
$check(
    str_contains($uvrFlat['es-AR']['common.illustrative'], 'No representa un arancel'),
    'UVR debe marcar los ejemplos como ilustrativos.'
);
$check(
    str_contains($uvrFlat['es-AR']['rvu.warning'], 'no son equivalentes'),
    'UVR debe negar la equivalencia con RVU de Medicare.'
);
$check(
    str_contains($uvrFlat['es-AR']['geographic.gradual_warning'], 'No se deberán inventar'),
    'UVR debe prohibir índices geográficos inventados.'
);
$check(
    $uvrFlat['es-AR']['calculation.formula'] === 'total_uvr = work_uvr + practice_expense_uvr + professional_liability_uvr',
    'UVR debe conservar la fórmula básica literal.'
);
$check(
    $uvrFlat['es-AR']['geographic.formula_liability'] === 'adjusted_professional_liability_uvr = professional_liability_uvr × uvr_geo_professional_liability_index',
    'UVR debe corregir la fórmula geográfica del README.'
);

// 6. Fase 1 / M1 — identidad, RBAC y auditoría de acceso.
$adminClasses = [
    '/portal/Admin/PasswordHasher.php',
    '/portal/Admin/Token.php',
    '/portal/Admin/Rbac.php',
];
foreach ($adminClasses as $adminClass) {
    $check(is_file($root . $adminClass), 'Falta la clase ' . $adminClass . '.');
}
require_once $root . '/portal/Admin/PasswordHasher.php';
require_once $root . '/portal/Admin/Token.php';
require_once $root . '/portal/Admin/Rbac.php';

use OrigenSalud\Portal\Admin\PasswordHasher;
use OrigenSalud\Portal\Admin\Rbac;
use OrigenSalud\Portal\Admin\Token;

$hasher = new PasswordHasher('pepper-de-prueba');
$hash = $hasher->hash('clave-segura-de-prueba');
$check($hash !== 'clave-segura-de-prueba', 'El hash no debe ser la contraseña en claro.');
$check($hasher->verify('clave-segura-de-prueba', $hash), 'verify() debe aceptar la contraseña correcta.');
$check(!$hasher->verify('otra-clave-de-prueba', $hash), 'verify() debe rechazar una contraseña distinta.');
$check(
    str_starts_with($hash, defined('PASSWORD_ARGON2ID') ? '$argon2id$' : '$2y$'),
    'El hash debe usar Argon2id (o bcrypt como reserva).'
);

$tokenA = Token::random();
$tokenB = Token::random();
$check(strlen($tokenA) === 64 && $tokenA !== $tokenB, 'Los tokens deben ser aleatorios de 64 hexadecimales.');
$check(Token::hash($tokenA) === hash('sha256', $tokenA), 'El token almacenado debe ser su hash SHA-256.');
$check(Token::verify($tokenA, Token::hash($tokenA)), 'Token::verify() debe aceptar el token correcto.');
$check(!Token::verify($tokenB, Token::hash($tokenA)), 'Token::verify() debe rechazar otro token.');
$check(Token::isValidHex($tokenA) && !Token::isValidHex('no-hex'), 'isValidHex() debe validar el formato.');

$check(Rbac::hasPermission(['catalog.view'], 'catalog.view'), 'RBAC debe reconocer un permiso otorgado.');
$check(!Rbac::hasPermission(['catalog.view'], 'catalog.publish'), 'RBAC debe negar un permiso no otorgado.');
$check(Rbac::hasPermission(['*'], 'catalog.publish'), 'El comodín debe otorgar todos los permisos.');
$check(!Rbac::hasPermission(['catalog.view'], 'permission.inexistente'), 'RBAC debe negar códigos desconocidos.');
$grants = [
    ['catalog_code' => 'dentar-pr', 'operation' => 'propose', 'allowed' => true],
    ['catalog_code' => 'dentar-pr', 'operation' => 'publish', 'allowed' => false],
];
$check(Rbac::canAccessCatalog($grants, 'dentar-pr', 'propose'), 'El grant explícito debe permitir la operación.');
$check(!Rbac::canAccessCatalog($grants, 'dentar-pr', 'publish'), 'Una denegación explícita debe ganar.');
$check(!Rbac::canAccessCatalog($grants, 'snomed', 'propose'), 'Sin grant no se permite el acceso.');
$check(Rbac::canAccessCatalog([], 'snomed', 'propose', ['*']), 'El superadministrador accede a todo.');
$check(
    Rbac::canApprove('7', '8', ['catalog.approve']),
    'La separación de funciones permite aprobar una propuesta ajena.'
);
$check(
    !Rbac::canApprove('7', '7', ['catalog.approve']),
    'Nadie debe aprobar su propia propuesta.'
);

$m1SqlPath = $root . '/sql/09_admin/fase1_identidad.sql';
$check(is_file($m1SqlPath), 'Debe existir la migración propuesta de M1.');
$m1Sql = is_file($m1SqlPath) ? (string) file_get_contents($m1SqlPath) : '';
$check(str_starts_with(ltrim($m1Sql), '--'), 'La migración M1 debe comenzar con el aviso de no ejecución.');
$check(str_contains($m1Sql, 'BEGIN;') && str_contains($m1Sql, 'COMMIT;'), 'M1 debe ser transaccional.');
$check(str_contains($m1Sql, 'CREATE SCHEMA IF NOT EXISTS os_admin'), 'M1 debe crear el esquema os_admin.');
$check(str_contains($m1Sql, 'os_admin.audit_log') && str_contains($m1Sql, 'trg_audit_log_immutable'), 'M1 debe crear la auditoría append-only.');
$check(str_contains($m1Sql, 'origen_admin'), 'M1 debe crear el rol de aplicación aislado.');
$check(
    preg_match('/GRANT\s+SELECT,\s*INSERT\s+ON\s+os_admin\.membership\s+TO\s+origen_admin/i', $m1Sql) === 1,
    'M1 debe permitir INSERT en membership para el bootstrap de roles.'
);
$check(!preg_match('/\bDROP\s+TABLE\b|\bDROP\s+COLUMN\b|\bTRUNCATE\b|\bDELETE\s+FROM\b/i', $m1Sql), 'M1 debe ser aditiva.');
$check(!preg_match('/\bGRANT\s+[^\n]+\bTO\s+PUBLIC\b/i', $m1Sql), 'M1 no debe otorgar privilegios a PUBLIC.');
$check(!preg_match('/\b(?:INSERT|UPDATE)\s+(?:INTO\s+)?(?:public\.)?os_catalog/i', $m1Sql), 'M1 no debe modificar os_catalog_*.');
$check(is_file($root . '/sql/09_admin/README.md'), 'Debe existir el README de M1.');
$check(is_file($root . '/sql/09_admin/verificacion.sql'), 'Debe existir la verificación SELECT-only de M1.');

$m1Files = [
    '/portal/Repositories/AdminDatabase.php',
    '/portal/Repositories/AuditRepository.php',
    '/portal/Repositories/UserRepository.php',
    '/portal/Repositories/SessionRepository.php',
    '/portal/Repositories/RbacRepository.php',
    '/portal/Repositories/AuthThrottleRepository.php',
    '/portal/Repositories/PasswordResetRepository.php',
    '/portal/Admin/AuditLogger.php',
    '/portal/Admin/AuthService.php',
    '/portal/Admin/AdminGuard.php',
    '/portal/Controllers/AdminAuthController.php',
    '/portal/Controllers/AdminHomeController.php',
    '/portal/Views/layouts/admin.php',
    '/portal/Views/admin/login.php',
    '/portal/Views/admin/forgot.php',
    '/portal/Views/admin/reset.php',
    '/portal/Views/admin/home.php',
    '/portal/Views/admin/audit.php',
    '/portal/Views/admin/denied.php',
    '/tools/php/admin_bootstrap.php',
];
foreach ($m1Files as $m1File) {
    $check(is_file($root . $m1File), 'Falta el artefacto de Fase 1: ' . $m1File . '.');
}

$configSource = (string) file_get_contents($root . '/portal/Config.php');
$check(str_contains($configSource, 'function adminDatabase()'), 'Config debe exponer la conexión acotada a os_admin.');
$check(str_contains($configSource, 'function adminAuth()'), 'Config debe exponer los parámetros de autenticación.');
$envExample = (string) file_get_contents($root . '/.env.example');
$check(str_contains($envExample, 'PORTAL_ADMIN_DB_DSN='), '.env.example debe documentar la DSN administrativa.');
$check(str_contains($envExample, 'ADMIN_PASSWORD_PEPPER='), '.env.example debe documentar el pepper.');

$routerSource = (string) file_get_contents($root . '/portal/Router.php');
$check(str_contains($routerSource, "'/admin'"), 'El router debe registrar las rutas del panel.');
$check(str_contains($routerSource, 'AdminGuard::requireSecure()'), 'Todas las rutas del panel deben exigir HTTPS configurable.');
$adminLayout = (string) file_get_contents($root . '/portal/Views/layouts/admin.php');
$check(!str_contains($adminLayout, 'nav-links.php'), 'El panel no debe usar la navegación pública.');
$authServiceSource = (string) file_get_contents($root . '/portal/Admin/AuthService.php');
$check(str_contains($authServiceSource, 'session_regenerate_id(true)'), 'El login debe regenerar el id de sesión.');
$check(str_contains($authServiceSource, 'AuthThrottleRepository::checkAndHit'), 'El login debe usar aceleración persistente.');
$check(!str_contains($authServiceSource, 'os_catalog'), 'AuthService no debe tocar tablas terminológicas.');

$adminKeys = [
    'admin/login/title', 'admin/login/lead', 'admin/login/submit',
    'admin/forgot/title', 'admin/reset/title', 'admin/home/title',
    'admin/audit/title', 'admin/denied/title', 'admin/logout',
];
$adminKeySets = [];
foreach (['es-AR', 'en', 'pt-BR', 'es'] as $adminLocale) {
    $adminMessages = Yaml::parseFile($root . '/portal/translations/messages.' . $adminLocale . '.yaml');
    $adminFlat = [];
    $flattenAdmin = static function (array $node, string $prefix) use (&$flattenAdmin, &$adminFlat): void {
        foreach ($node as $key => $value) {
            $path = $prefix === '' ? (string) $key : $prefix . '.' . (string) $key;
            if (is_array($value)) {
                $flattenAdmin($value, $path);
                continue;
            }
            $adminFlat[$path] = $value;
        }
    };
    $flattenAdmin(is_array($adminMessages['admin'] ?? null) ? $adminMessages['admin'] : [], '');
    foreach ($adminKeys as $adminKey) {
        $check(array_key_exists(str_replace('/', '.', substr($adminKey, 6)), $adminFlat), $adminLocale . ': falta la clave ' . $adminKey . '.');
    }
    $adminKeySets[$adminLocale] = array_keys($adminFlat);
}
sort($adminKeySets['es-AR']);
foreach (['en', 'pt-BR', 'es'] as $adminLocale) {
    $otherKeys = $adminKeySets[$adminLocale];
    sort($otherKeys);
    $check($otherKeys === $adminKeySets['es-AR'], 'Fase 1: paridad de claves admin entre es-AR y ' . $adminLocale . '.');
}

require_once $root . '/portal/i18n/I18n.php';
$adminWelcome = \OrigenSalud\Web\I18n::trans(
    'admin.home.welcome',
    ['%name%' => 'Prueba'],
    'es-AR'
);
$check(
    str_contains($adminWelcome, 'Prueba') && !str_contains($adminWelcome, '%Prueba%'),
    'El saludo del panel debe interpolar %name% sin dejar los signos.'
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
