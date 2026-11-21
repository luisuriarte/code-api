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

// 2b. Fase 2: los 17 desvíos del §13.2 quedan corregidos en la spec.
$specRaw = (string) file_get_contents($specPath);
$check(!str_contains($specRaw, 'format: uuid'), 'request_id no debe declararse UUID.');
$check(str_contains($specRaw, 'no es UUID'), 'La spec debe aclarar que request_id no es UUID.');
$check(!str_contains($specRaw, 'default: es-AR'), 'lang no debe usar es-AR como default; el real es es.');
$check(str_contains($specRaw, 'minLength: 2, maxLength: 80'), 'q debe declarar entre 2 y 80 caracteres.');
$check(str_contains($specRaw, '`OPTIONS` con `204`'), 'La spec debe documentar OPTIONS 204.');
$check(str_contains($specRaw, '`405` con `Allow'), 'La spec debe documentar 405 con Allow.');
$check(
    substr_count($specRaw, 'no se emite `404`') >= 3,
    'Las tres rutas de catálogos deben documentar 200 con data: [].'
);
$check(
    str_contains($specRaw, 'puede emitirse en cualquier operación'),
    'La spec debe documentar que 400 puede emitirse en más operaciones.'
);
$check(
    !str_contains($specRaw, 'enum: [troquel, alfabeta, kairos, gtin]'),
    'El sistema de identificador medicinal no debe restringirse a cuatro valores.'
);
$check(
    str_contains($specRaw, '^(?:[0-9]{2,6}|[0-9]{1,2}\\.[0-9]{1,2})$'),
    'La ruta PMO debe exigir al menos 2 dígitos cuando no lleva punto.'
);
$check(str_contains($specRaw, '^[A-Za-z][0-9]{2}'), 'CIE-10 debe admitir inicial en minúscula.');

$specSchemas = $spec['components']['schemas'] ?? [];
$specParams = $spec['components']['parameters'] ?? [];
$check(
    ($specParams['ConceptId']['name'] ?? null) === 'id',
    'El parámetro del alias /v1/concepts/{id} debe llamarse id, no sctid.'
);
$check(
    !isset($specSchemas['HealthEnvelope']['properties']['request_id']),
    'HealthEnvelope no debe incluir request_id en el body.'
);
$check(
    in_array('request_id', $specSchemas['ErrorEnvelope']['required'] ?? [], true),
    'ErrorEnvelope debe exigir request_id.'
);
$check(
    isset($specSchemas['Domain']['properties']['id'])
        && !isset($specSchemas['Domain']['properties']['code'])
        && !isset($specSchemas['Domain']['properties']['metadata']),
    'Domain debe usar id y label/description por idioma.'
);
$check(
    !isset($specSchemas['PaginationMeta']['properties']['total'])
        && isset($specSchemas['PaginationMeta']['properties']['page_counts']),
    'PaginationMeta no debe declarar total y sí page_counts.'
);
$check(
    !isset($specSchemas['SearchResult']['properties']['catalog'])
        && !isset($specSchemas['SearchResult']['properties']['effective_language'])
        && isset($specSchemas['SearchResult']['properties']['subtitle']),
    'SearchResult debe reflejar la salida real con domain/source/subtitle/kind.'
);
foreach ([
    'DomainQuery', 'AllFlag', 'Refset', 'Cie10Type', 'SnomedFilter', 'Cie10Filter',
    'Tipo', 'Alfabeta', 'Kairos', 'Gtin', 'Atc', 'Class', 'Status', 'System',
    'Capitulo', 'CoberturaCondicionada', 'Seccion',
] as $specParam) {
    $check(isset($specParams[$specParam]), 'Falta documentar el parámetro implementado ' . $specParam . '.');
}

// 2c. Segunda pasada de la Fase 2: parámetros por operación y textos derivados.
$check(
    !str_contains($specRaw, '`OPTIONS` con `204` y `Allow`'),
    'OPTIONS 204 no debe anunciar Allow: el código solo lo emite en 405.'
);
$check(
    ($specParams['Cie10Type']['schema']['enum'] ?? []) === ['diagnostico', 'procedimiento'],
    'cie10_type solo admite diagnostico o procedimiento.'
);
$operationParams = static function (string $path) use ($spec): array {
    $parameters = $spec['paths'][$path]['get']['parameters'] ?? [];
    $names = [];
    foreach ($parameters as $parameter) {
        if (is_array($parameter)) {
            $names[] = (string) ($parameter['$ref'] ?? $parameter['name'] ?? '');
        }
    }

    return $names;
};
foreach ([
    '/v1/pmo/practicas' => ['Q', 'Capitulo', 'CoberturaCondicionada', 'Limit', 'Offset'],
    '/v1/pmo/medicamentos' => ['Q', 'Atc', 'Limit', 'Offset'],
    '/v1/pmo/normativa' => ['Q', 'Seccion', 'Limit'],
    '/v1/concepts/search' => ['Refsets', 'Refset', 'Cie10Type'],
    '/v1/nomenclador' => ['Tipo'],
    '/v1/catalogs/{catalog_code}/items' => ['Offset'],
] as $operation => $requiredParams) {
    $presentParams = $operationParams($operation);
    foreach ($requiredParams as $requiredParam) {
        $check(
            in_array('#/components/parameters/' . $requiredParam, $presentParams, true)
                || in_array($requiredParam, $presentParams, true),
            'Falta documentar ' . $requiredParam . ' en ' . $operation . '.'
        );
    }
}
foreach (['es-AR', 'en', 'pt-BR'] as $locale) {
    $translationSource = (string) file_get_contents(
        $root . '/portal/translations/messages.' . $locale . '.yaml'
    );
    $deviationsStart = strpos($translationSource, 'divergences_title');
    $deviationsEnd = $deviationsStart === false
        ? false
        : strpos($translationSource, 'generate_title', $deviationsStart);
    $deviationsBlock = $deviationsStart !== false && $deviationsEnd !== false
        ? substr($translationSource, $deviationsStart, $deviationsEnd - $deviationsStart)
        : '';
    $check(
        $deviationsBlock !== ''
            && (str_contains($deviationsBlock, 'Fase 2') || str_contains($deviationsBlock, 'Phase 2'))
            && !str_contains($deviationsBlock, 'spec declara UUID')
            && !str_contains($deviationsBlock, 'spec declares UUID')
            && !str_contains($deviationsBlock, '200 caracteres')
            && !str_contains($deviationsBlock, '200 characters'),
        'Las traducciones de ' . $locale . ' deben reflejar los desvíos ya corregidos.'
    );
}

// 3. Artefactos SQL: sintaxis básica y prohibiciones del plan de migración.
$sqlDir = $root . '/sql/08_arquitectura';
$sqlFiles = array_values(array_filter(
    glob($sqlDir . '/*.sql') ?: [],
    static fn (string $f): bool => !str_contains(basename($f), 'verificacion_')
        && !str_contains(basename($f), 'correcion_')
        && !str_contains(basename($f), 'correccion_')
));
$check(
    count($sqlFiles) === 13,
    'Deben existir trece artefactos SQL propuestos (Fases 3, 8, 10, 11, gestión UVR, gestión de catálogos, U7-B y publicación legacy).'
);
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

// 3a. U7-B/C/D: migración preparada, vista pública y panel sin catálogo fijo.
$u7Sql = (string) file_get_contents($sqlDir . '/uvr_transversal_prestaciones.sql');
foreach ([
    'os_prestacion',
    'os_prestacion_codigo',
    'os_uvr_profile',
    'os_uvr_profile_component',
    'os_uvr_prestacion_valuation',
    'os_uvr_prestacion_component',
] as $u7Table) {
    $check(
        str_contains($u7Sql, 'CREATE TABLE IF NOT EXISTS public.' . $u7Table),
        'U7-B debe crear ' . $u7Table . '.'
    );
}
$check(
    str_contains($u7Sql, 'CREATE OR REPLACE VIEW public.v_os_uvr_prestacion_public'),
    'U7-B debe crear la vista pública filtrada.'
);
$check(str_contains($u7Sql, 'importe_referencial'), 'U7-B debe derivar el importe referencial.');
$check(!str_contains($u7Sql, 'estimated_payment'), 'U7-B no debe exponer estimated_payment.');
$check(
    str_contains($u7Sql, "to_regprocedure('public.os_uvr_audit_trigger()')"),
    'U7-B debe verificar la función de auditoría con to_regprocedure.'
);
$check(
    !str_contains($u7Sql, "to_regclass('public.os_uvr_audit_trigger')"),
    'U7-B no debe tratar la función de auditoría como una relación.'
);
$check(str_contains($u7Sql, 'FROM PUBLIC'), 'U7-B debe revocar privilegios a PUBLIC.');
$check(str_contains($u7Sql, "to_regrole('origen_med')"), 'U7-B debe conceder solo la vista al portal.');
$check(!preg_match('/\bGRANT\s+ALL\b/i', $u7Sql), 'U7-B no debe usar GRANT ALL.');
$u7Verify = (string) file_get_contents($sqlDir . '/verificacion_uvr_transversal.sql');
$check(
    str_contains($u7Verify, 'BEGIN READ ONLY;') && str_contains($u7Verify, 'ROLLBACK;'),
    'U7-B debe verificarse solo con BEGIN READ ONLY / ROLLBACK.'
);
$check(
    !str_contains($u7Verify, 'ORDER BY tabla::text'),
    'El verificador U7 no debe ordenar por un alias dentro de una expresión.'
);
$check(
    str_contains($u7Verify, 'ORDER BY conrelid::regclass::text'),
    'El verificador U7 debe ordenar usando la expresión de la columna.'
);
$u7PublicRepository = (string) file_get_contents(
    $root . '/portal/Repositories/UvrPublicRepository.php'
);
$check(
    str_contains($u7PublicRepository, 'public.v_os_uvr_prestacion_public'),
    'U7-D solo debe leer la vista pública.'
);
$check(
    str_contains($u7PublicRepository, 'to_regclass(:name)')
        && str_contains($u7PublicRepository, 'private static function hasView(string $view): bool'),
    'U7-D debe detectar cada vista antes de consultarla.'
);
$check(!str_contains($u7PublicRepository, 'estimated_payment'), 'U7-D no debe exponer estimated_payment.');
$check(
    str_contains($u7PublicRepository, '?string $externalCode = null')
    && str_contains($u7PublicRepository, 'btrim(external_code) = :external')
    && str_contains($u7PublicRepository, 'external_code, prestacion_code'),
    'U7-D debe resolver UVR también por external_code para procedimientos.'
);
$check(
    str_contains($u7PublicRepository, "preg_match('/^[a-z0-9][a-z0-9-]{1,49}$/', \$catalog) !== 1"),
    'U7-D debe validar el catálogo con la comparación correcta.'
);
$check(
    str_contains($u7PublicRepository, "implode(' AND ', \$conditions)")
    && !str_contains($u7PublicRepository, "WHERE catalog_code = '"),
    'U7-D debe armar las condiciones con parámetros ligados, nunca con literales.'
);
$browseServiceSource = (string) file_get_contents($root . '/portal/Services/BrowseService.php');
$check(
    str_contains($browseServiceSource, "\$item['official_code'] ?? \$item['code']")
    && str_contains($browseServiceSource, 'publishedForItem(')
    && str_contains($browseServiceSource, '$externalCode'),
    'El browser debe pasar el código externo al resolver UVR en procedimientos.'
);
$uvrProcedureVerifier = (string) file_get_contents(
    $root . '/sql/08_arquitectura/verificacion_uvr_procedimientos.sql'
);
$check(
    str_contains($uvrProcedureVerifier, 'BEGIN READ ONLY;')
    && str_contains($uvrProcedureVerifier, 'ROLLBACK;')
    && str_contains($uvrProcedureVerifier, 'btrim(external_code)'),
    'El verificador de UVR en procedimientos debe ser solo lectura y cubrir external_code.'
);
$u7Service = (string) file_get_contents($root . '/portal/Admin/UvrGovernanceService.php');
$check(!str_contains($u7Service, 'private const CATALOG_CODE'), 'U7-C no debe fijar un catálogo único.');
$check(str_contains($u7Service, 'LEGACY_CATALOG_CODE'), 'U7-C debe conservar el legado como fallback.');
$check(
    substr_count($u7Service, 'CatalogReferenceRepository::uvrCatalogs()') >= 2,
    'El selector y la validación de propuestas deben usar los catálogos UVR gobernados.'
);
$check(
    str_contains($u7Service, 'function isUvrCatalog('),
    'La validación legacy debe aceptar cualquier catálogo UVR gobernado.'
);
$u7ControllerSource = (string) file_get_contents($root . '/portal/Controllers/AdminUvrController.php');
$check(
    str_contains($u7ControllerSource, 'CatalogGovernanceRepository::catalogCodeForItem'),
    'El deep link histórico debe resolver el catálogo del código elegido.'
);
$u7CatalogRepo = (string) file_get_contents($root . '/portal/Repositories/CatalogReferenceRepository.php');
$check(
    str_contains($u7CatalogRepo, 'function uvrCatalogs()'),
    'Debe existir el listado gobernado de catálogos UVR.'
);
$check(
    str_contains($u7CatalogRepo, "'dentar-dx'") && str_contains($u7CatalogRepo, 'product_role ='),
    'El selector UVR debe excluir diagnósticos y catálogos no prestacionales.'
);
$u7ProposalViewSource = (string) file_get_contents($root . '/portal/Views/admin/uvr/proposals.php');
foreach (['extracted_values', 'new_values', 'select_item'] as $u7Key) {
    $check(
        str_contains($u7ProposalViewSource, 'admin.uvr.' . $u7Key),
        'La vista UVR debe usar la clave ' . $u7Key . '.'
    );
}
$check(
    str_contains($u7ProposalViewSource, 'selectedVersions')
    && str_contains($u7ProposalViewSource, 'onchange="this.form.submit()"'),
    'El listado UVR debe cargar los valores extraídos en el card derecho.'
);
$u7Controller = (string) file_get_contents($root . '/portal/Controllers/AdminUvrController.php');
$check(
    str_contains($u7Controller, "'selectedVersions' => \$selectedVersions"),
    'El controlador UVR debe propagar las versiones del código elegido.'
);
foreach ([
    'prestacion_id', 'profile_id', 'proposalCatalog',
    'visibleCatalogCodes', 'requireAnyCatalog', 'anyVisible',
    'UvrRepository::prestaciones() !== []', 'UvrRepository::profiles() !== []',
] as $u7ServiceToken) {
    $check(str_contains($u7Service, $u7ServiceToken), 'U7-C debe gestionar ' . $u7ServiceToken . '.');
}
$u7ProposalView = (string) file_get_contents($root . '/portal/Views/admin/uvr/proposals.php');
foreach (['service_item_id', 'prestacion_id', 'profile_id'] as $u7FormField) {
    $check(
        str_contains($u7ProposalView, 'name="' . $u7FormField . '"'),
        'U7-C debe enviar ' . $u7FormField . ' en la propuesta.'
    );
}

$uvrSql = (string) file_get_contents($sqlDir . '/fase6_uvr.sql');
$check(str_contains($uvrSql, "component_type IN (\n        'work', 'practice_expense', 'professional_liability'\n    )"), 'UVR debe conservar los tres componentes.');
$check(str_contains($uvrSql, 'total_uvr') || str_contains($uvrSql, 'COALESCE(c_work.value, 0)'), 'UVR debe derivar el total de los componentes.');
$check(!preg_match('/INSERT\s+INTO\s+os_uvr_(valuation|component|conversion|geo_index)/i', $uvrSql), 'No se deben cargar valores UVR.');

// 3b. Fase 1 del §16: infraestructura compartida y verificación SELECT-only.
$fase1Sql = (string) file_get_contents($sqlDir . '/fase1_infraestructura.sql');
foreach (['os_domain_registry', 'os_relation_kind', 'os_relation_type', 'os_review_state'] as $fase1Table) {
    $check(
        str_contains($fase1Sql, 'CREATE TABLE IF NOT EXISTS ' . $fase1Table),
        'Fase 1 debe crear ' . $fase1Table . '.'
    );
}
$fase1Domains = [
    'snomed', 'cie10', 'anmat', 'laboratorio', 'vacunas', 'odontologia',
    'prestaciones', 'programas', 'imagenes', 'nomenclador', 'vademecum', 'loinc',
];
$terminologySource = (string) file_get_contents($root . '/api/services/TerminologySearchService.php');
foreach ($fase1Domains as $fase1Domain) {
    $check(
        str_contains($fase1Sql, "('" . $fase1Domain . "',"),
        'Fase 1 debe sembrar el dominio ' . $fase1Domain . '.'
    );
    $check(
        str_contains($terminologySource, 'DOMAIN_' . strtoupper($fase1Domain)),
        'TerminologySearchService debe definir el dominio ' . $fase1Domain . '.'
    );
}
$check(
    substr_count($fase1Sql, 'TerminologySearchService::DOMAINS/DOMAIN_CATALOG') === 12
        && str_contains($fase1Sql, "mode IN ('full', 'catalog')"),
    'Fase 1 debe sembrar los 12 dominios reales conservando los modos full/catalog.'
);
$check(
    str_contains($fase1Sql, 'is_publication_allowed')
        && str_contains($fase1Sql, "('approved',") && str_contains($fase1Sql, "('published',"),
    'Fase 1 debe fijar qué estados de revisión permiten publicación.'
);
$check(
    str_contains($fase1Sql, "to_regclass('public.os_catalog_relation')")
        && str_contains($fase1Sql, 'SELECT DISTINCT r.relation_type'),
    'Fase 1 debe derivar los tipos de relación de la tabla real, sin inventar códigos.'
);
$check(
    str_contains($fase1Sql, 'REVOKE ALL PRIVILEGES')
        && str_contains($fase1Sql, 'FROM PUBLIC')
        && str_contains($fase1Sql, "to_regrole('origen_admin')"),
    'Fase 1 debe revocar los privilegios heredados del DEFAULT ACL de public.'
);
$fase1FixPath = $sqlDir . '/fase1_correcion_privilegios.sql';
$check(is_file($fase1FixPath), 'Debe existir el correctivo de privilegios de Fase 1.');
if (is_file($fase1FixPath)) {
    $fase1Fix = (string) file_get_contents($fase1FixPath);
    $check(
        str_contains($fase1Fix, 'REVOKE ALL PRIVILEGES')
            && str_contains($fase1Fix, 'FROM PUBLIC')
            && str_contains($fase1Fix, 'origen_admin'),
        'El correctivo debe revocar privilegios a origen_admin y PUBLIC.'
    );
}
$fase1VerifyPath = $sqlDir . '/verificacion_fase1.sql';
$check(is_file($fase1VerifyPath), 'Debe existir la verificación SELECT-only de Fase 1.');
if (is_file($fase1VerifyPath)) {
    $fase1Verify = (string) file_get_contents($fase1VerifyPath);
    $check(
        str_contains($fase1Verify, 'BEGIN READ ONLY;') && str_contains($fase1Verify, 'ROLLBACK;'),
        'La verificación de Fase 1 debe ser de solo lectura.'
    );
    $check(
        str_contains($fase1Verify, 'os_domain_registry')
            && str_contains($fase1Verify, 'os_catalog_relation')
            && str_contains($fase1Verify, "grantee = 'origen_admin'"),
        'La verificación de Fase 1 debe comprobar dominios, invariante CDT y privilegios.'
    );
    $check(
        str_contains($fase1Verify, '603') && str_contains($fase1Verify, '333 CDT'),
        'La verificación de Fase 1 debe reflejar 603 relaciones (333 CDT + 270 Fase 9).'
    );
}

// 3c. Fase 3 del §16: D-31 y sembrado derivado de os_catalog_language.
$fase3Path = $sqlDir . '/fase3_i18n.sql';
$fase3VerifyPath = $sqlDir . '/verificacion_fase3.sql';
$check(is_file($fase3Path), 'Debe existir la migración de i18n de la Fase 3.');
$check(is_file($fase3VerifyPath), 'Debe existir la verificación de i18n de la Fase 3.');
if (is_file($fase3Path)) {
    $fase3Sql = (string) file_get_contents($fase3Path);
    $check(
        str_contains($fase3Sql, 'trg_ocm_invalidate_fr')
            && str_contains($fase3Sql, 'CREATE OR REPLACE TRIGGER')
            && str_contains($fase3Sql, 'approval_invalidated'),
        'Fase 3 debe instalar el trigger D-31 con el evento de invalidación.'
    );
    $check(
        str_contains($fase3Sql, 'INSERT INTO os_catalog_language')
            && str_contains($fase3Sql, 'ON CONFLICT (catalog_id, language_code) DO NOTHING')
            && str_contains($fase3Sql, 'coverage_status')
            && str_contains($fase3Sql, "'undetermined'"),
        'Fase 3 debe sembrar os_catalog_language de forma idempotente y sin inventar cobertura.'
    );
    $check(
        str_contains($fase3Sql, 'os_catalog_item_version')
            && str_contains($fase3Sql, 'NOT idi.is_source_only')
            && str_contains($fase3Sql, "COALESCE(d.language_code, 'es-AR')")
            && str_contains($fase3Sql, "WHEN 'es-AR' THEN 0"),
        'Fase 3 debe derivar idiomas seleccionables, priorizar es-AR en empates y usarla si no hay versiones.'
    );
    $check(
        !str_contains($fase3Sql, 'INSERT INTO os_language')
            && !str_contains($fase3Sql, 'INSERT INTO os_language_alias')
            && !preg_match('/\bSET\s+OS_IMPORT_MODE\b/i', $fase3Sql),
        'Fase 3 no debe reejecutar la siembra base ni cambiar OS_IMPORT_MODE.'
    );
    $check(
        !str_contains($fase3Sql, "'es-MX'") && !str_contains($fase3Sql, "'pt-BR'"),
        'Fase 3 no debe sembrar idiomas source-only ni del portal como default.'
    );
}
if (is_file($fase3VerifyPath)) {
    $fase3Verify = (string) file_get_contents($fase3VerifyPath);
    $check(
        str_contains($fase3Verify, 'BEGIN READ ONLY;') && str_contains($fase3Verify, 'ROLLBACK;'),
        'La verificación de Fase 3 debe ser de solo lectura.'
    );
    $check(
        str_contains($fase3Verify, 'trg_ocm_invalidate_fr')
            && str_contains($fase3Verify, 'is_default')
            && str_contains($fase3Verify, 'is_fallback')
            && str_contains($fase3Verify, 'is_source_only')
            && str_contains($fase3Verify, 'default_esperado'),
        'La verificación de Fase 3 debe comprobar D-31, cardinalidad D-13, idiomas activos y preferencia es-AR.'
    );
}
$fase3FixPath = $sqlDir . '/fase3_correcion_idioma_default.sql';
$check(is_file($fase3FixPath), 'Debe existir el correctivo de desempate de idioma de la Fase 3.');
if (is_file($fase3FixPath)) {
    $fase3Fix = (string) file_get_contents($fase3FixPath);
    $check(
        substr_count($fase3Fix, 'ON CONFLICT (catalog_id, language_code) DO UPDATE') === 4
            && str_contains($fase3Fix, 'BEGIN;') && str_contains($fase3Fix, 'COMMIT;'),
        'El correctivo debe aplicar cuatro intercambios ordenados de flags en una transacción.'
    );
    $check(
        str_contains($fase3Fix, 'dentar-an') && str_contains($fase3Fix, 'dentar-cl'),
        'El correctivo debe documentar los catálogos detectados en la ejecución del 2026-11-19.'
    );
}
$sqlReadme = (string) file_get_contents($sqlDir . '/README.md');
$check(str_contains($sqlReadme, 'verificacion_fase3.sql'), 'El README SQL debe documentar la Fase 3.');
$check(str_contains($sqlReadme, 'diferimiento M7'), 'El README SQL debe registrar el levantamiento del diferimiento M7.');
$check(str_contains($sqlReadme, 'fase3_correcion_idioma_default.sql'), 'El README SQL debe documentar el correctivo de desempate.');

// 3d. Fase 4 del §16: relaciones y mapeos generales (nombre histórico fase3).
$fase4Path = $sqlDir . '/fase3_relaciones_mapeos.sql';
$fase4VerifyPath = $sqlDir . '/verificacion_fase4.sql';
$check(is_file($fase4Path), 'Debe existir la migración de relaciones de la Fase 4.');
$check(is_file($fase4VerifyPath), 'Debe existir la verificación de relaciones de la Fase 4.');
if (is_file($fase4Path)) {
    $fase4Sql = (string) file_get_contents($fase4Path);
    $check(
        substr_count($fase4Sql, 'ADD COLUMN IF NOT EXISTS') === 13,
        'Fase 4 debe añadir 13 columnas aditivas a os_catalog_relation.'
    );
    $check(
        str_contains($fase4Sql, 'fk_ocr_source_catalog')
            && str_contains($fase4Sql, 'fk_ocr_relation_kind')
            && str_contains($fase4Sql, 'ck_ocr_validity')
            && str_contains($fase4Sql, 'idx_ocr_validity')
            && str_contains($fase4Sql, 'idx_ocr_kind'),
        'Fase 4 debe crear los constraints y los índices nuevos de forma idempotente.'
    );
    $check(
        str_contains($fase4Sql, 'CREATE TABLE IF NOT EXISTS os_mapping_metadata')
            && str_contains($fase4Sql, 'CREATE TABLE IF NOT EXISTS os_terminology_system_alias')
            && str_contains($fase4Sql, 'ON CONFLICT (alias_table, alias_system_code) DO NOTHING'),
        'Fase 4 debe crear las dos tablas de mapeos sin duplicar alias.'
    );
    $check(
        str_contains($fase4Sql, "ALTER TABLE os_concept_mapping\n    ALTER COLUMN review_status SET DEFAULT 'draft'"),
        'Fase 4 debe fijar el DEFAULT draft sin reescribir filas existentes.'
    );
    $check(
        str_contains($fase4Sql, 'REVOKE ALL PRIVILEGES ON TABLE')
            && str_contains($fase4Sql, 'FROM PUBLIC')
            && str_contains($fase4Sql, 'FROM origen_admin')
            && str_contains($fase4Sql, 'public.os_mapping_metadata')
            && str_contains($fase4Sql, 'public.os_terminology_system_alias'),
        'Fase 4 debe revocar el DEFAULT ACL sobre sus dos tablas nuevas.'
    );
    $check(
        str_contains($fase4Sql, 'RAISE EXCEPTION')
            && !str_contains($fase4Sql, 'DROP TABLE')
            && !str_contains($fase4Sql, 'DELETE FROM'),
        'Fase 4 debe validar sus prerrequisitos y no destruir objetos ni datos.'
    );
}
if (is_file($fase4VerifyPath)) {
    $fase4Verify = (string) file_get_contents($fase4VerifyPath);
    $check(
        str_contains($fase4Verify, 'BEGIN READ ONLY;') && str_contains($fase4Verify, 'ROLLBACK;'),
        'La verificación de Fase 4 debe ser de solo lectura.'
    );
    $check(
        str_contains($fase4Verify, '603 relaciones')
            && str_contains($fase4Verify, 'count(DISTINCT relation_type)')
            && str_contains($fase4Verify, 'relaciones_huerfanas')
            && str_contains($fase4Verify, "grantee IN ('origen_admin', 'PUBLIC')"),
        'La verificación de Fase 4 debe comprobar integridad, navegabilidad y privilegios.'
    );
}
$check(str_contains($sqlReadme, 'verificacion_fase4.sql'), 'El README SQL debe documentar la verificación de Fase 4.');
$check(str_contains($sqlReadme, 'Decisión 10'), 'El README SQL debe registrar la decisión 10 aprobada.');
$check(str_contains($sqlReadme, 'Fase 4 cerrada en base'), 'El README SQL debe registrar el cierre en base de la Fase 4.');
$architectureRaw = (string) file_get_contents($root . '/docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md');
$check(
    str_contains($architectureRaw, 'Integración aprobada (Fase 4)')
        && str_contains($architectureRaw, 'Aprobada en Fase 4 (2026-11-19)'),
    'El documento de arquitectura debe registrar la decisión 10 como aprobada.'
);
$check(
    str_contains($architectureRaw, 'Fase 4 cerrada en base')
        && str_contains($architectureRaw, '603 de 603 relaciones resultaron')
        && str_contains($architectureRaw, 'navegables**, sin huérfanos'),
    'El documento de arquitectura debe registrar la ejecución y el cierre de Fase 4.'
);

// 3e. Fase 5 del §16: gestión, actores reales y auditoría append-only.
$fase5Path = $sqlDir . '/fase4_gobernanza.sql';
$fase5VerifyPath = $sqlDir . '/verificacion_fase5.sql';
$check(is_file($fase5Path), 'Debe existir la migración de gestión de la Fase 5.');
$check(is_file($fase5VerifyPath), 'Debe existir la verificación de gestión de la Fase 5.');
if (is_file($fase5Path)) {
    $fase5Sql = (string) file_get_contents($fase5Path);
    $check(
        str_contains($fase5Sql, 'CREATE TABLE IF NOT EXISTS os_governance_request')
            && str_contains($fase5Sql, 'CREATE TABLE IF NOT EXISTS os_governance_review')
            && str_contains($fase5Sql, 'CREATE TABLE IF NOT EXISTS os_governance_decision')
            && str_contains($fase5Sql, 'CREATE TABLE IF NOT EXISTS os_audit_log'),
        'Fase 5 debe crear las cuatro tablas de gestión sin sembrar datos.'
    );
    $check(
        substr_count($fase5Sql, 'BIGINT REFERENCES os_admin.app_user(id) ON DELETE SET NULL') === 4,
        'Fase 5 debe referenciar actores reales de os_admin.app_user en las cuatro tablas.'
    );
    $check(
        str_contains($fase5Sql, 'trg_os_audit_log_immutable')
            && str_contains($fase5Sql, 'BEFORE UPDATE OR DELETE ON os_audit_log')
            && str_contains($fase5Sql, 'RAISE EXCEPTION'),
        'Fase 5 debe hacer append-only la auditoría.'
    );
    $check(
        str_contains($fase5Sql, "NULLIF(current_setting('app.actor_id', TRUE), '')"),
        'Fase 5 debe tomar el actor real de app.actor_id, igual que D-31.'
    );
    $check(
        str_contains($fase5Sql, 'REVOKE ALL PRIVILEGES ON TABLE')
            && str_contains($fase5Sql, 'FROM PUBLIC')
            && str_contains($fase5Sql, 'FROM origen_admin')
            && substr_count($fase5Sql, 'public.os_governance_request') >= 2,
        'Fase 5 debe revocar el DEFAULT ACL sobre sus cuatro tablas nuevas.'
    );
    $check(
        str_contains($fase5Sql, 'evidence_reference TEXT NOT NULL')
            && str_contains($fase5Sql, "DEFAULT 'draft'")
            && str_contains($fase5Sql, "DEFAULT 'unreviewed'"),
        'Fase 5 debe exigir evidencia escrita y defaults editoriales seguros.'
    );
}
if (is_file($fase5VerifyPath)) {
    $fase5Verify = (string) file_get_contents($fase5VerifyPath);
    $check(
        str_contains($fase5Verify, 'BEGIN READ ONLY;') && str_contains($fase5Verify, 'ROLLBACK;'),
        'La verificación de Fase 5 debe ser de solo lectura.'
    );
    $check(
        str_contains($fase5Verify, "column_name = 'outcome'")
            && str_contains($fase5Verify, "column_name = 'review_status'"),
        'La verificación de Fase 5 debe comprobar review_status y outcome, no dos review_status.'
    );
    $check(
        str_contains($fase5Verify, 'confrelid = to_regclass(\'os_admin.app_user\')')
            && str_contains($fase5Verify, 'trg_os_audit_log_immutable')
            && str_contains($fase5Verify, "grantee IN ('origen_admin', 'PUBLIC')")
            && str_contains($fase5Verify, '(SELECT count(*) FROM os_catalog_relation)'),
        'La verificación de Fase 5 debe comprobar actores, auditoría, privilegios y regresión.'
    );
}
$check(str_contains($sqlReadme, 'verificacion_fase5.sql'), 'El README SQL debe documentar la verificación de Fase 5.');
$check(str_contains($sqlReadme, 'Fase 5 cerrada en base'), 'El README SQL debe registrar el cierre en base de la Fase 5.');
$check(
    str_contains($architectureRaw, 'Fase 5 cerrada en base')
        && str_contains($architectureRaw, '`os_audit_log` append-only')
        && str_contains($architectureRaw, '`REVOKE` por el `DEFAULT ACL`'),
    'El documento de arquitectura debe registrar la Fase 5 ejecutada y cerrada.'
);

// 3f. Fase 6 del §16: productos, presentaciones e identificadores (nombre histórico fase5).
$fase6Path = $sqlDir . '/fase5_productos.sql';
$fase6VerifyPath = $sqlDir . '/verificacion_fase6.sql';
$check(is_file($fase6Path), 'Debe existir la migración de productos de la Fase 6.');
$check(is_file($fase6VerifyPath), 'Debe existir la verificación de productos de la Fase 6.');
if (is_file($fase6Path)) {
    $fase6Sql = (string) file_get_contents($fase6Path);
    $check(
        str_contains($fase6Sql, 'CREATE TABLE IF NOT EXISTS os_concept')
            && str_contains($fase6Sql, 'CREATE TABLE IF NOT EXISTS os_product')
            && str_contains($fase6Sql, 'CREATE TABLE IF NOT EXISTS os_product_presentation')
            && str_contains($fase6Sql, 'CREATE TABLE IF NOT EXISTS os_product_identifiers')
            && str_contains($fase6Sql, 'CREATE TABLE IF NOT EXISTS os_regulatory_records'),
        'Fase 6 debe crear el modelo vacío de concepto, producto, presentación e identificadores.'
    );
    $check(
        str_contains($fase6Sql, "('GTIN',")
            && str_contains($fase6Sql, "('UDI',")
            && str_contains($fase6Sql, "('MANUFACTURER',")
            && str_contains($fase6Sql, "('fabricante',")
            && str_contains($fase6Sql, "('titular',")
            && str_contains($fase6Sql, "('importador',")
            && str_contains($fase6Sql, "('distribuidor',")
            && !preg_match('/INSERT\s+INTO\s+os_(concept|product|product_presentation|manufacturer)\b/i', $fase6Sql),
        'Fase 6 debe sembrar solo tipos y roles documentados, nunca productos ni fabricantes.'
    );
    $check(
        str_contains($fase6Sql, 'UNIQUE (presentation_id, identifier_type, identifier_value, valid_from)')
            && str_contains($fase6Sql, 'ck_os_product_identifier_validity'),
        'Fase 6 debe hacer la unicidad de identificadores por presentación y validar vigencia.'
    );
    $check(
        str_contains($fase6Sql, 'REVOKE ALL PRIVILEGES ON TABLE')
            && str_contains($fase6Sql, 'FROM PUBLIC')
            && str_contains($fase6Sql, 'FROM origen_admin'),
        'Fase 6 debe revocar el DEFAULT ACL sobre sus nueve tablas nuevas.'
    );
    $check(
        str_contains($fase6Sql, 'os_domain_registry')
            && str_contains($fase6Sql, 'os_review_state')
            && !str_contains($fase6Sql, 'DROP TABLE')
            && !str_contains($fase6Sql, 'DELETE FROM'),
        'Fase 6 debe ser aditiva y depender solo de la Fase 1.'
    );
}
if (is_file($fase6VerifyPath)) {
    $fase6Verify = (string) file_get_contents($fase6VerifyPath);
    $check(
        str_contains($fase6Verify, 'BEGIN READ ONLY;') && str_contains($fase6Verify, 'ROLLBACK;'),
        'La verificación de Fase 6 debe ser de solo lectura.'
    );
    $check(
        str_contains($fase6Verify, "'os_product_identifier_type'")
            && str_contains($fase6Verify, "'os_manufacturer_role'")
            && str_contains($fase6Verify, "grantee IN ('origen_admin', 'PUBLIC')")
            && str_contains($fase6Verify, '(SELECT count(*) FROM os_catalog_relation)'),
        'La verificación de Fase 6 debe comprobar semillas, privilegios y regresión.'
    );
}
$check(str_contains($sqlReadme, 'verificacion_fase6.sql'), 'El README SQL debe documentar la verificación de Fase 6.');
$check(str_contains($sqlReadme, 'Operación de Fase 6'), 'El README SQL debe documentar la operación de Fase 6.');
$check(str_contains($sqlReadme, 'Fase 6 cerrada en base'), 'El README SQL debe registrar el cierre en base de la Fase 6.');
$check(
    str_contains($architectureRaw, 'Fase 6 cerrada en base')
        && str_contains($architectureRaw, 'regresión 603/22/0'),
    'El documento de arquitectura debe registrar la ejecución y el cierre de Fase 6.'
);

// 3g. Fase 7 del §16: módulo UVR sin valores inventados (nombre histórico fase6).
$fase7Path = $sqlDir . '/fase6_uvr.sql';
$fase7VerifyPath = $sqlDir . '/verificacion_fase7.sql';
$check(is_file($fase7Path), 'Debe existir la migración UVR de la Fase 7.');
$check(is_file($fase7VerifyPath), 'Debe existir la verificación UVR de la Fase 7.');
if (is_file($fase7Path)) {
    $fase7Sql = (string) file_get_contents($fase7Path);
    $check(
        str_contains($fase7Sql, 'CREATE TABLE IF NOT EXISTS os_uvr_eligible_catalog')
            && str_contains($fase7Sql, 'CREATE TABLE IF NOT EXISTS os_uvr_valuation')
            && str_contains($fase7Sql, 'CREATE TABLE IF NOT EXISTS os_uvr_component')
            && str_contains($fase7Sql, 'CREATE TABLE IF NOT EXISTS os_uvr_conversion')
            && str_contains($fase7Sql, 'CREATE TABLE IF NOT EXISTS os_uvr_geo_index'),
        'Fase 7 debe crear las cinco tablas UVR sin valores cargados.'
    );
    $check(
        str_contains($fase7Sql, "WHERE c.code = 'dentar-pr'")
            && str_contains($fase7Sql, "catalog_code = 'dentar-dx'") === false
            && str_contains($fase7Sql, 'trg_os_uvr_valuation_eligible')
            && str_contains($fase7Sql, 'RAISE EXCEPTION'),
        'Fase 7 debe sembrar solo la elegibilidad real de dentar-pr y bloquear ítems no elegibles.'
    );
    $check(
        str_contains($fase7Sql, 'v_os_uvr_valuation_total')
            && str_contains($fase7Sql, 'AS total_uvr')
            && !preg_match('/\btotal_uvr\s+(?:NUMERIC|NUMERIC\(|\d)/i', $fase7Sql),
        'Fase 7 debe derivar total_uvr en la vista, nunca como columna almacenada.'
    );
    $check(
        str_contains($fase7Sql, 'REVOKE ALL PRIVILEGES ON TABLE')
            && str_contains($fase7Sql, 'FROM PUBLIC')
            && str_contains($fase7Sql, 'FROM origen_admin'),
        'Fase 7 debe revocar el DEFAULT ACL sobre sus cinco tablas nuevas.'
    );
    $check(
        str_contains($fase7Sql, 'os_review_state')
            && str_contains($fase7Sql, 'source_reference TEXT NOT NULL')
            && preg_match('/^\s*(?:DROP\s+TABLE|DELETE\s+FROM|TRUNCATE)\b/im', $fase7Sql) !== 1,
        'Fase 7 debe ser aditiva, exigir fuentes verificables y no destruir datos.'
    );
}
if (is_file($fase7VerifyPath)) {
    $fase7Verify = (string) file_get_contents($fase7VerifyPath);
    $check(
        str_contains($fase7Verify, 'BEGIN READ ONLY;') && str_contains($fase7Verify, 'ROLLBACK;'),
        'La verificación de Fase 7 debe ser de solo lectura.'
    );
    $check(
        str_contains($fase7Verify, "catalog_code = 'dentar-dx'")
            && str_contains($fase7Verify, "column_name = 'total_uvr'")
            && str_contains($fase7Verify, "grantee IN ('origen_admin', 'PUBLIC')")
            && str_contains($fase7Verify, '(SELECT count(*) FROM os_catalog_relation)'),
        'La verificación de Fase 7 debe comprobar elegibilidad, vista derivada, privilegios y regresión.'
    );
}
$check(str_contains($sqlReadme, 'verificacion_fase7.sql'), 'El README SQL debe documentar la verificación de Fase 7.');
$check(str_contains($sqlReadme, 'Operación de Fase 7'), 'El README SQL debe documentar la operación de Fase 7.');
$check(str_contains($sqlReadme, 'Fase 7 cerrada en base'), 'El README SQL debe registrar el cierre en base de la Fase 7.');
$check(
    str_contains($architectureRaw, 'Fase 7 cerrada en base')
        && str_contains($architectureRaw, '0 valores UVR'),
    'El documento de arquitectura debe registrar la ejecución y el cierre de Fase 7.'
);

// 3h. Fase 8 del §16: catálogos DENTAR reservados IN/PD/EQ (nombre histórico fase7).
$fase8Path = $sqlDir . '/fase7_catalogos_reservados.sql';
$fase8VerifyPath = $sqlDir . '/verificacion_fase8.sql';
$check(is_file($fase8Path), 'Debe existir la migración de catálogos reservados de la Fase 8.');
$check(is_file($fase8VerifyPath), 'Debe existir la verificación de catálogos reservados de la Fase 8.');
if (is_file($fase8Path)) {
    $fase8Sql = (string) file_get_contents($fase8Path);
    $check(
        str_contains($fase8Sql, 'CREATE TABLE IF NOT EXISTS os_catalog_reservation')
            && str_contains($fase8Sql, "('dentar-in',")
            && str_contains($fase8Sql, "('dentar-pd',")
            && str_contains($fase8Sql, "('dentar-eq',"),
        'Fase 8 debe reservar solo los tres códigos documentados IN/PD/EQ.'
    );
    $check(
        str_contains($fase8Sql, "DEFAULT 'unreviewed'")
            && str_contains($fase8Sql, 'source_reference TEXT NOT NULL')
            && str_contains($fase8Sql, 'catalog_id INT REFERENCES os_catalog(id) ON DELETE SET NULL'),
        'Fase 8 debe exigir gestión y dejar catalog_id nulo hasta la aprobación.'
    );
    $check(
        !preg_match('/INSERT\s+INTO\s+os_catalog\b/i', $fase8Sql)
            && !preg_match('/INSERT\s+INTO\s+os_catalog_item\b/i', $fase8Sql)
            && !preg_match('/INSERT\s+INTO\s+os_catalog_release\b/i', $fase8Sql)
            && !str_contains($fase8Sql, 'DNT-IN-'),
        'Fase 8 no debe crear catálogos reales, ítems ni códigos inventados.'
    );
    $check(
        str_contains($fase8Sql, 'trg_os_catalog_reservation_publication')
            && str_contains($fase8Sql, 'is_publication_allowed')
            && str_contains($fase8Sql, 'RAISE EXCEPTION'),
        'Fase 8 debe impedir vincular un catálogo sin aprobación editorial.'
    );
    $check(
        str_contains($fase8Sql, 'REVOKE ALL PRIVILEGES ON TABLE public.os_catalog_reservation FROM PUBLIC')
            && str_contains($fase8Sql, 'FROM origen_admin'),
        'Fase 8 debe revocar el DEFAULT ACL sobre la tabla nueva.'
    );
}
if (is_file($fase8VerifyPath)) {
    $fase8Verify = (string) file_get_contents($fase8VerifyPath);
    $check(
        str_contains($fase8Verify, 'BEGIN READ ONLY;') && str_contains($fase8Verify, 'ROLLBACK;'),
        'La verificación de Fase 8 debe ser de solo lectura.'
    );
    $check(
        str_contains($fase8Verify, 'catalog_id IS NOT NULL')
            && str_contains($fase8Verify, 'trg_os_catalog_reservation_publication')
            && str_contains($fase8Verify, "grantee IN ('origen_admin', 'PUBLIC')")
            && str_contains($fase8Verify, '(SELECT count(*) FROM os_catalog_relation)'),
        'La verificación de Fase 8 debe comprobar reservas, guardián, privilegios y regresión.'
    );
}
$check(str_contains($sqlReadme, 'verificacion_fase8.sql'), 'El README SQL debe documentar la verificación de Fase 8.');
$check(str_contains($sqlReadme, 'Operación de Fase 8'), 'El README SQL debe documentar la operación de Fase 8.');
$check(str_contains($sqlReadme, 'Fase 8 cerrada en base'), 'El README SQL debe registrar el cierre en base de la Fase 8.');
$check(
    str_contains($architectureRaw, 'Fase 8 cerrada en base')
        && str_contains($architectureRaw, '0 catálogos reales'),
    'El documento de arquitectura debe registrar la ejecución y el cierre de Fase 8.'
);

// 3i. Fase 10 del §16: catálogos generales OS-* con familia OS-PRODUCTS.
$fase10Path = $sqlDir . '/fase10_catalogos_os.sql';
$fase10VerifyPath = $sqlDir . '/verificacion_fase10.sql';
$check(is_file($fase10Path), 'Debe existir la migración OS-PRODUCTS de la Fase 10.');
$check(is_file($fase10VerifyPath), 'Debe existir la verificación OS-PRODUCTS de la Fase 10.');
if (is_file($fase10Path)) {
    $fase10Sql = (string) file_get_contents($fase10Path);
    $check(
        str_contains($fase10Sql, 'CREATE TABLE IF NOT EXISTS os_product_class')
            && str_contains($fase10Sql, 'CREATE TABLE IF NOT EXISTS os_product_family_reservation')
            && str_contains($fase10Sql, "('consumable'),")
            && str_contains($fase10Sql, "('medicine'),")
            && str_contains($fase10Sql, "('device'),")
            && str_contains($fase10Sql, "('equipment'),")
            && str_contains($fase10Sql, "('implant')"),
        'Fase 10 debe crear la familia OS-PRODUCTS con las cinco clases documentadas.'
    );
    $check(
        str_contains($fase10Sql, "('OS-PRODUCTS', 'family'")
            && str_contains($fase10Sql, "('OS-INS',")
            && str_contains($fase10Sql, "('OS-PROD',")
            && str_contains($fase10Sql, "('OS-MED',")
            && str_contains($fase10Sql, "('OS-DIS',")
            && str_contains($fase10Sql, "('OS-EQP',")
            && str_contains($fase10Sql, "('OS-IMPL',"),
        'Fase 10 debe registrar la familia y las seis etiquetas OS-* reservadas.'
    );
    $check(
        str_contains($fase10Sql, "DEFAULT 'unreviewed'")
            && str_contains($fase10Sql, 'source_reference TEXT NOT NULL')
            && str_contains($fase10Sql, 'catalog_id INT REFERENCES os_catalog(id) ON DELETE SET NULL')
            && str_contains($fase10Sql, 'trg_os_product_family_reservation_publication')
            && str_contains($fase10Sql, 'is_publication_allowed'),
        'Fase 10 debe exigir gestión e impedir catálogos sin aprobación.'
    );
    $check(
        !preg_match('/INSERT\s+INTO\s+os_catalog\b/i', $fase10Sql)
            && !preg_match('/INSERT\s+INTO\s+os_catalog_item\b/i', $fase10Sql)
            && !preg_match('/INSERT\s+INTO\s+os_catalog_release\b/i', $fase10Sql),
        'Fase 10 no debe crear catálogos reales, ítems ni releases.'
    );
    $check(
        str_contains($fase10Sql, 'REVOKE ALL PRIVILEGES ON TABLE')
            && str_contains($fase10Sql, 'public.os_product_class')
            && str_contains($fase10Sql, 'public.os_product_family_reservation')
            && str_contains($fase10Sql, 'FROM PUBLIC')
            && str_contains($fase10Sql, 'FROM origen_admin'),
        'Fase 10 debe revocar el DEFAULT ACL sobre sus dos tablas nuevas.'
    );
}
if (is_file($fase10VerifyPath)) {
    $fase10Verify = (string) file_get_contents($fase10VerifyPath);
    $check(
        str_contains($fase10Verify, 'BEGIN READ ONLY;') && str_contains($fase10Verify, 'ROLLBACK;'),
        'La verificación de Fase 10 debe ser de solo lectura.'
    );
    $check(
        str_contains($fase10Verify, 'os_catalog_reservation')
            && str_contains($fase10Verify, "c.code LIKE 'OS-%'")
            && str_contains($fase10Verify, "grantee IN ('origen_admin', 'PUBLIC')")
            && str_contains($fase10Verify, '(SELECT count(*) FROM os_catalog_relation)'),
        'La verificación de Fase 10 debe comprobar no duplicados, privilegios y regresión.'
    );
}
$check(str_contains($sqlReadme, 'verificacion_fase10.sql'), 'El README SQL debe documentar la verificación de Fase 10.');
$check(str_contains($sqlReadme, 'Operación de Fase 10'), 'El README SQL debe documentar la operación de Fase 10.');
$check(str_contains($sqlReadme, 'Fase 10 cerrada en base'), 'El README SQL debe registrar el cierre en base de la Fase 10.');
$check(
    str_contains($architectureRaw, 'Fase 10 cerrada en base')
        && str_contains($architectureRaw, '0 duplicados'),
    'El documento de arquitectura debe registrar la ejecución y el cierre de Fase 10.'
);

// 3j. Fase 11 del §16: integración farmacéutica sin cargar datos.
$fase11Path = $sqlDir . '/fase11_integracion_farmacia.sql';
$fase11VerifyPath = $sqlDir . '/verificacion_fase11.sql';
$check(is_file($fase11Path), 'Debe existir la migración de integración farmacéutica de la Fase 11.');
$check(is_file($fase11VerifyPath), 'Debe existir la verificación de integración farmacéutica de la Fase 11.');
if (is_file($fase11Path)) {
    $fase11Sql = (string) file_get_contents($fase11Path);
    $check(
        str_contains($fase11Sql, 'CREATE TABLE IF NOT EXISTS os_pharma_source')
            && str_contains($fase11Sql, 'CREATE TABLE IF NOT EXISTS os_pharma_import_batch')
            && str_contains($fase11Sql, 'CREATE TABLE IF NOT EXISTS os_pharma_import_row'),
        'Fase 11 debe crear fuentes, lotes y staging sin cargar datos.'
    );
    $check(
        !preg_match('/INSERT\s+INTO\s+(?:os_pharma_source|os_pharma_import_batch|os_pharma_import_row)\b/i', $fase11Sql)
            && !preg_match('/INSERT\s+INTO\s+(?:os_concept|os_product|os_product_presentation|os_regulatory_records)\b/i', $fase11Sql),
        'Fase 11 no debe sembrar fuentes ni migrar filas al modelo de la Fase 6.'
    );
    $check(
        str_contains($fase11Sql, 'source_reference TEXT NOT NULL')
            && str_contains($fase11Sql, "DEFAULT 'unreviewed'")
            && str_contains($fase11Sql, 'os_admin.app_user')
            && str_contains($fase11Sql, 'raw_payload JSONB NOT NULL')
            && str_contains($fase11Sql, 'target_entity VARCHAR(60) NOT NULL CHECK'),
        'Fase 11 debe exigir fuente, gestión, actores reales y staging tipificado.'
    );
    $check(
        str_contains($fase11Sql, 'trg_os_pharma_import_row_review')
            && str_contains($fase11Sql, 'v_review_allows IS DISTINCT FROM TRUE')
            && str_contains($fase11Sql, 'v_os_pharma_reconciliation'),
        'Fase 11 debe validar aprobaciones y exponer conciliación sin transferir datos.'
    );
    $check(
        str_contains($fase11Sql, 'REVOKE ALL PRIVILEGES ON TABLE')
            && str_contains($fase11Sql, 'public.os_pharma_source')
            && str_contains($fase11Sql, 'public.os_pharma_import_batch')
            && str_contains($fase11Sql, 'public.os_pharma_import_row')
            && str_contains($fase11Sql, 'FROM PUBLIC')
            && str_contains($fase11Sql, 'FROM origen_admin'),
        'Fase 11 debe revocar el DEFAULT ACL sobre sus tres tablas nuevas.'
    );
}
if (is_file($fase11VerifyPath)) {
    $fase11Verify = (string) file_get_contents($fase11VerifyPath);
    $check(
        str_contains($fase11Verify, 'BEGIN READ ONLY;') && str_contains($fase11Verify, 'ROLLBACK;'),
        'La verificación de Fase 11 debe ser de solo lectura.'
    );
    $check(
        !str_contains($fase11Verify, 'ORDER BY tabla::text'),
        'La verificación de Fase 11 no debe ordenar por un alias dentro de una expresión.'
    );
    $check(
        str_contains($fase11Verify, "FROM os_substance")
            && str_contains($fase11Verify, 'v_os_pharma_reconciliation')
            && str_contains($fase11Verify, "grantee IN ('origen_admin', 'PUBLIC')")
            && str_contains($fase11Verify, '(SELECT count(*) FROM os_catalog_relation)'),
        'La verificación de Fase 11 debe comprobar legado intacto, conciliación, privilegios y regresión.'
    );
}
$check(str_contains($sqlReadme, 'verificacion_fase11.sql'), 'El README SQL debe documentar la verificación de Fase 11.');
$check(str_contains($sqlReadme, 'Operación de Fase 11'), 'El README SQL debe documentar la operación de Fase 11.');
$check(str_contains($sqlReadme, 'Fase 11 cerrada en base'), 'El README SQL debe registrar el cierre en base de la Fase 11.');
$check(
    str_contains($architectureRaw, 'Fase 11 cerrada en base')
        && str_contains($architectureRaw, 'legado intacto'),
    'El documento de arquitectura debe registrar la ejecución y el cierre de Fase 11.'
);

// 3k. Fase 12 del §16: contrato FHIR documental, sin endpoints ni cambios en la guardia.
$fase12Path = $root . '/docs/architecture/fase12-fhir-contrato.md';
$check(is_file($fase12Path), 'Debe existir el contrato FHIR de la Fase 12.');
$fhirContract = is_file($fase12Path) ? (string) file_get_contents($fase12Path) : '';
$check(
    str_contains($fhirContract, 'Estado:** PREPARADA (contrato documental). **No implementada.**')
        && str_contains($fhirContract, 'No incluye:** DDL/DML'),
    'El contrato FHIR debe declarar su estado no implementado y sin cambios en base.'
);
$check(
    str_contains($fhirContract, '| `CodeSystem` |')
        && str_contains($fhirContract, '| `ConceptMap` |')
        && str_contains($fhirContract, '| `Medication` |')
        && str_contains($fhirContract, '| `Device` / `DeviceDefinition` |')
        && str_contains($fhirContract, '| `ChargeItem` / `ChargeItemDefinition` |'),
    'El contrato FHIR debe mapear los recursos del §14.2 desde el modelo interno.'
);
$check(
    str_contains($fhirContract, 'catalog_id = NULL')
        && str_contains($fhirContract, 'Fase 8')
        && str_contains($fhirContract, 'Fase 10')
        && str_contains($fhirContract, 'no se proyectan'),
    'El contrato FHIR debe excluir de la proyección las reservas DENTAR y OS.'
);
$check(
    str_contains($fhirContract, 'nunca un arancel oficial')
        && str_contains($fhirContract, 'importe estimado y derivado')
        && str_contains($fhirContract, 'total_uvr'),
    'El contrato FHIR debe declarar el importe UVR como estimado, nunca arancel oficial.'
);
$check(
    str_contains($fhirContract, 'no enrutada')
        && str_contains($fhirContract, 'no crea rutas ni modifica la guardia')
        && str_contains($fhirContract, '0 instancias'),
    'El contrato FHIR debe dejar las operaciones sin enrutar y el modelo vacío.'
);
$apiRouterSource = (string) file_get_contents($root . '/api/index.php');
$check(!str_contains($apiRouterSource, '/fhir'), 'El enrutador no debe contener rutas /fhir.');
$check(
    str_contains($apiRouterSource, "str_starts_with(\$path, '/v1/')"),
    'La guardia de autenticación debe seguir cubriendo solo /v1/*.'
);
$fhirReadmeContracto = (string) file_get_contents($root . '/README-FHIR.md');
$check(
    str_contains($fhirReadmeContracto, 'fase12-fhir-contrato.md')
        && str_contains($fhirReadmeContracto, 'contrato propuesto, no implementado'),
    'README-FHIR debe referenciar el contrato y mantener el aviso de no implementado.'
);
$check(!isset($spec['paths']['/fhir/metadata']), 'La OpenAPI no debe declarar /fhir como implementado.');
$check(str_contains($architectureRaw, 'Preparada el 2026-11-20 como contrato'), 'El documento de arquitectura debe registrar la Fase 12 preparada.');

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

// Resumen UVR visible en la ficha, sin inventar datos ni exponer estimated_payment.
$detailSource = (string) file_get_contents($root . '/portal/Views/partials/browse/detail.php');
$uvrTableSource = (string) file_get_contents($root . '/portal/Views/partials/browse/detail/uvr.php');
$check(
    !str_contains($detailSource, 'browse-dentar-banner')
    && !str_contains($detailSource, 'browse.dentar_detail_note')
    && !str_contains($detailSource, 'browse.dentar_back'),
    'Las fichas de códigos no deben mostrar el banner informativo de DENTAR.'
);
$contextSource = (string) file_get_contents($root . '/portal/Views/partials/browse/context.php');
$check(
    str_contains($detailSource, 'browse.uvr_published_title')
    && str_contains($detailSource, "['total_uvr']")
    && str_contains($detailSource, "['work_uvr']")
    && str_contains($detailSource, "['practice_expense_uvr']")
    && str_contains($detailSource, "['professional_liability_uvr']"),
    'La ficha debe mostrar componentes UVR y Total UVR en un bloque visible.'
);
$check(
    !str_contains($detailSource, 'estimated_payment')
    && !str_contains($uvrTableSource, 'estimated_payment'),
    'La ficha pública no debe exponer estimated_payment.'
);
$check(
    str_contains($contextSource, "sections['uvr']")
    && str_contains($contextSource, "\$tabs['values']"),
    'La pestaña Valores debe existir cuando hay UVR publicada aunque values esté vacío.'
);
foreach (['es-AR', 'en', 'pt-BR', 'es'] as $uvrLocale) {
    $uvrMessages = Yaml::parseFile($root . '/portal/translations/messages.' . $uvrLocale . '.yaml');
    $uvrBrowse = $uvrMessages['browse'] ?? [];
    foreach ([
        'uvr_published_title', 'uvr_published_note', 'uvr_work',
        'uvr_practice', 'uvr_liability', 'uvr_published_total',
        'uvr_published_importe',
    ] as $uvrKey) {
        $check(
            isset($uvrBrowse[$uvrKey]) && trim((string) $uvrBrowse[$uvrKey]) !== '',
            $uvrLocale . ': falta la clave UVR browse.' . $uvrKey . '.'
        );
    }
}
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

// 4c. Code Browser rediseñado: barra full-width, drawer de filtros y sin rail izquierdo.
$browseView = (string) file_get_contents($root . '/portal/Views/browse.php');
$check(
    str_contains($browseView, 'popovertarget="browse-filters"')
    && str_contains($browseView, 'popover="auto"')
    && str_contains($browseView, 'browse-filter-drawer'),
    'Los filtros deben abrirse en un drawer nativo en el borde derecho.'
);
$check(
    !str_contains($browseView, 'browse-rail')
    && !str_contains($browseView, 'browse-catalogs'),
    'El listado lateral de catálogos/códigos debe desaparecer del browser.'
);
$check(
    str_contains($browseView, 'data-pane="results"')
    && str_contains($browseView, 'data-pane="detail"')
    && str_contains($browseView, 'group-data-[mobile-view=detail]:hidden'),
    'Los resultados y la ficha deben conservar los hooks del explorador AJAX.'
);
$check(
    !str_contains($browseView, 'array_merge($reservedDentar, $reservedOs)')
    && str_contains($browseView, "count(\$group['options']) < 2"),
    'El drawer no debe mostrar etiquetas no consultables ni facetas con una sola opción.'
);
$check(
    str_contains($resultsSource, 'browse-results--explorer')
    && str_contains($resultsSource, 'sm:grid-cols-2')
    && str_contains($resultsSource, 'data-focus-url'),
    'Los resultados deben renderizarse como tarjetas responsive sin perder la navegación AJAX.'
);
$publicCssSource = (string) file_get_contents($root . '/resources/css/public.css');
$check(
    str_contains($publicCssSource, 'layer(legacy)')
    && str_contains($publicCssSource, '../../web/assets/css/app.css'),
    'El CSS público debe conservar la ficha histórica en una capa legacy.'
);
$publicCssBuilt = $root . '/web/assets/css/public.css';
$check(is_file($publicCssBuilt), 'Debe existir el build público de Tailwind.');
if (is_file($publicCssBuilt)) {
    $publicCss = (string) file_get_contents($publicCssBuilt);
    $check(str_contains($publicCss, ':popover-open'), 'El build debe incluir el estado open del Popover API.');
    $check(str_contains($publicCss, 'has(:checked)'), 'El build debe incluir el estado has-checked de los filtros.');
    $check(str_contains($publicCss, '@layer legacy') && str_contains($publicCss, '@layer utilities'), 'El build debe mantener el orden de capas.');
}
$layoutSource = (string) file_get_contents($root . '/portal/Views/layouts/main.php');
$check(
    str_contains($layoutSource, '/assets/css/public.css')
    && !str_contains($layoutSource, '/assets/css/app.css')
    && str_contains($layoutSource, 'legacy'),
    'Todas las páginas públicas deben cargar el build Tailwind; app.css queda en la capa legacy.'
);
$packageRaw = (string) file_get_contents($root . '/package.json');
$check(str_contains($packageRaw, 'build:css:public'), 'El build debe generar el CSS público.');
foreach (['es-AR', 'en', 'pt-BR', 'es'] as $locale) {
    $messages = Yaml::parseFile($root . '/portal/translations/messages.' . $locale . '.yaml');
    $browse = $messages['browse'] ?? [];
    foreach (['active_filters', 'close_filters', 'family_dentar'] as $key) {
        $check(isset($browse[$key]), $locale . ': falta browse.' . $key . '.');
    }
}

// "Todos" del browser debe incluir odontología; la API mantiene su default acotado.
$portalRepoSource = (string) file_get_contents($root . '/portal/Repositories/CatalogRepository.php');
require_once $root . '/portal/Repositories/CatalogRepository.php';
$portalDomains = \OrigenSalud\Portal\Repositories\CatalogRepository::DOMAINS;
$check(in_array('odontologia', $portalDomains, true), 'El browser debe publicar el dominio odontología.');
$check(
    str_contains($portalRepoSource, "\$domains = \$domain === '' ? self::DOMAINS : [\$domain];"),
    'Sin filtros, el browser debe consultar todas las fuentes, no solo las tres núcleo.'
);
$check(
    str_contains($serviceSource, 'return self::DEFAULT_DOMAINS;'),
    'La API debe conservar su default acotado por coste.'
);

// 5. Documentación alineada con el estado real.
$dentarReadme = (string) file_get_contents($root . '/docs/dentar/README.md');
foreach (['844', '223', '624', '218', 'origen_codes', 'DENTAR-IN'] as $needle) {
    $check(str_contains($dentarReadme, $needle), 'docs/dentar/README.md debe mencionar ' . $needle . '.');
}
$apiReadme = (string) file_get_contents($root . '/README-API.md');
$check(!str_contains($apiReadme, 'DNT-000007'), 'README-API.md no debe usar el código inventado DNT-000007.');
$check(str_contains($apiReadme, 'DNT-PR-NNNNNN'), 'README-API.md debe documentar DNT-PR-NNNNNN.');
$check(!str_contains($apiReadme, 'pendiente de aprobación'), 'README-API.md no debe declarar pendiente la corrección ya aplicada.');
$check(str_contains($apiReadme, 'Fase 2'), 'README-API.md debe registrar la reconciliación de la Fase 2.');
$check(str_contains($apiReadme, 'no es UUID'), 'README-API.md debe aclarar que request_id no es UUID.');
$check(!str_contains($apiReadme, '4_caracteres'), 'README-API.md no debe usar valores inventados en cie10_type.');
$check(str_contains($apiReadme, '`diagnostico` o `procedimiento`'), 'README-API.md debe documentar los valores reales de cie10_type.');
$check(!str_contains($apiReadme, '{identificador}'), 'README-API.md debe usar {code} en odontología.');
$check(!str_contains($apiReadme, 'items/{code}'), 'README-API.md debe usar {item} en el detalle de catálogos.');
foreach (['/v1/refsets', '/v1/catalogs/{catalog_code}/releases', '/v1/pricing-units'] as $documentedRoute) {
    $check(str_contains($apiReadme, $documentedRoute), 'README-API.md debe documentar ' . $documentedRoute . '.');
}
$mainReadme = (string) file_get_contents($root . '/README.md');
$check(!str_contains($mainReadme, 'aún no navegables'), 'README.md debe reflejar que las relaciones CDT son navegables.');
$check(str_contains($mainReadme, 'navegables desde Browse'), 'README.md debe afirmar la navegabilidad real de las relaciones CDT.');
$legacyVerifier = (string) file_get_contents($root . '/tools/php/verificar_fase10.php');
$check(str_contains($legacyVerifier, 'INFORME LEGACY'), 'El verificador Fase 10 debe declararse como informe no vinculante.');
$check(str_contains($legacyVerifier, 'no bloquea'), 'El verificador Fase 10 no debe bloquear la entrega.');
$fhirReadme = (string) file_get_contents($root . '/README-FHIR.md');
$check(str_contains($fhirReadme, 'contrato propuesto, no implementado'), 'README-FHIR.md debe declarar el estado no implementado.');

// 6. Navegación: enlace /cart roto resuelto y sitemap real.
foreach (['header.php', 'footer.php', 'nav-links.php'] as $partial) {
    $source = (string) file_get_contents($root . '/portal/Views/partials/' . $partial);
    $check(!str_contains($source, "'/cart'"), $partial . ' no debe enlazar a /cart.');
}
$footerNavSource = (string) file_get_contents($root . '/portal/Views/partials/footer.php');
$check(str_contains($footerNavSource, '#plataforma'), 'footer.php debe enlazar Servicios a #plataforma.');
$topNavSource = (string) file_get_contents($root . '/portal/Views/partials/nav-links.php');
$check(!str_contains($topNavSource, 'nav.services'), 'El menú principal no debe incluir Servicios.');
$homeSource = (string) file_get_contents($root . '/portal/Views/home.php');
$check(!str_contains($homeSource, '/cart'), 'home.php no debe conservar la ruta rota /cart.');

// 6b. Rediseño Tailwind de la home y del shell público.
foreach (['id="buscador"', 'id="plataforma"', 'id="api"', 'id="contacto"'] as $homeAnchor) {
    $check(str_contains($homeSource, $homeAnchor), 'La home debe conservar el ancla ' . $homeAnchor . '.');
}
foreach (['rounded-3xl', 'lg:grid-cols-4', 'shadow-panel', 'focus-visible:ring-4'] as $homeUtility) {
    $check(str_contains($homeSource, $homeUtility), 'La home debe usar utilidades Tailwind (' . $homeUtility . ').');
}
$check(
    str_contains($homeSource, 'max-h-[24rem]')
    && str_contains($homeSource, 'code-scroll')
    && str_contains($homeSource, 'min-h-0 flex-1 overflow-auto'),
    'El card de la respuesta API debe tener altura limitada y scroll interno.'
);
$check(
    str_contains((string) file_get_contents($root . '/resources/css/public.css'), '.code-scroll'),
    'El CSS público debe definir el scroll fino del card de la API.'
);
$headerSource = (string) file_get_contents($root . '/portal/Views/partials/header.php');
$check(
    str_contains($headerSource, 'sticky top-0')
    && str_contains($headerSource, 'backdrop-blur-xl')
    && str_contains($headerSource, 'lg:hidden'),
    'El header público debe ser sticky, translúcido y con menú móvil.'
);
$footerSource = (string) file_get_contents($root . '/portal/Views/partials/footer.php');
$check(
    str_contains($footerSource, "t('footer.rights'")
    && str_contains($footerSource, 'lg:grid-cols-[1.4fr_repeat(3,1fr)]'),
    'El footer debe conservar los derechos y usar la grid Tailwind de cuatro columnas.'
);
$navSource = (string) file_get_contents($root . '/portal/Views/partials/nav-links.php');
$check(
    str_contains($navSource, 'lg:rounded-full')
    && str_contains($navSource, 'aria-current="page"'),
    'La navegación debe adaptarse al menu móvil sin perder aria-current.'
);
foreach (['es-AR', 'en', 'pt-BR'] as $homeLocale) {
    $homeMessages = Yaml::parseFile($root . '/portal/translations/messages.' . $homeLocale . '.yaml');
    foreach ([
        ['hero', 'badge'], ['hero', 'title'], ['hero', 'lead'], ['hero', 'primary'],
        ['hero', 'secondary'], ['hero', 'note'], ['hero', 'card_title'],
        ['stats', 'label'], ['stats', 'concepts_value'], ['search', 'title'],
        ['search', 'lead'], ['search', 'query_label'], ['search', 'button'],
        ['services', 'eyebrow'], ['services', 'title'], ['api', 'endpoint_label'],
        ['api', 'example_query'], ['cta', 'title'], ['cta', 'button'],
    ] as [$homeSection, $homeKey]) {
        $check(
            isset($homeMessages[$homeSection][$homeKey])
            && is_string($homeMessages[$homeSection][$homeKey])
            && trim($homeMessages[$homeSection][$homeKey]) !== '',
            $homeLocale . ': falta la clave de home ' . $homeSection . '.' . $homeKey . '.'
        );
    }
}

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
$check(
    str_contains($docsSource, '/assets/css/public.css')
    && str_contains($docsSource, 'sticky top-0 z-40')
    && str_contains($docsSource, 'lg:hidden')
    && str_contains($docsSource, 'nav-links.php'),
    'Docs debe usar el build Tailwind y el mismo menú sticky de las páginas públicas.'
);
$check(str_contains($docsSource, 'docs-search-input'), 'Docs debe incluir búsqueda interna.');
$check(str_contains($docsSource, 'docs-toc-list'), 'Docs debe incluir índice contextual por artículo.');
$check(str_contains($docsSource, 'data-breadcrumb-article'), 'Docs debe incluir breadcrumbs dinámicos.');
$check(!str_contains($docsSource, '{identifier}'), 'Docs debe usar {code} como en la spec y en el enrutador.');
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
$check(
    str_contains($uvrSource, '/assets/css/public.css')
    && str_contains($uvrSource, 'sticky top-0 z-40')
    && str_contains($uvrSource, 'lg:hidden')
    && str_contains($uvrSource, 'nav-links.php'),
    'UVR debe usar el build Tailwind y el mismo menú sticky de las páginas públicas.'
);
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
$adminLoginSource = (string) file_get_contents($root . '/portal/Views/admin/login.php');
$check(
    str_contains($adminLoginSource, "I18n::localizedPath(\$locale, '/')")
    && str_contains($adminLoginSource, "e(\$t('admin.login.back_site'))"),
    'El login del panel debe ofrecer un enlace localizado de vuelta al sitio público.'
);
$authServiceSource = (string) file_get_contents($root . '/portal/Admin/AuthService.php');
$check(str_contains($authServiceSource, 'session_regenerate_id(true)'), 'El login debe regenerar el id de sesión.');
$check(str_contains($authServiceSource, 'AuthThrottleRepository::checkAndHit'), 'El login debe usar aceleración persistente.');
$check(!str_contains($authServiceSource, 'os_catalog'), 'AuthService no debe tocar tablas terminológicas.');

$adminKeys = [
    'admin/login/title', 'admin/login/lead', 'admin/login/submit', 'admin/login/back_site',
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

// 7. Fase 2 / M2 — gestión: organizaciones, invitaciones y memberships.
$m2Files = [
    '/sql/09_admin/fase2_gobernanza.sql',
    '/sql/09_admin/verificacion_fase2.sql',
    '/docs/architecture/fase2-organizaciones-invitaciones.md',
    '/portal/Admin/GovernanceException.php',
    '/portal/Admin/GovernanceService.php',
    '/portal/Repositories/OrganizationRepository.php',
    '/portal/Repositories/MembershipRepository.php',
    '/portal/Repositories/InvitationRepository.php',
    '/portal/Repositories/CatalogGrantRepository.php',
    '/portal/Repositories/CatalogReferenceRepository.php',
    '/portal/Controllers/AdminForm.php',
    '/portal/Controllers/AdminOrganizationController.php',
    '/portal/Controllers/AdminInvitationController.php',
    '/portal/Controllers/AdminMembershipController.php',
    '/portal/Controllers/AdminContextController.php',
    '/portal/Views/admin/organizations.php',
    '/portal/Views/admin/organization.php',
    '/portal/Views/admin/invitations.php',
    '/portal/Views/admin/invite.php',
    '/portal/Views/admin/_flash.php',
    '/portal/Views/admin/_grant_choices.php',
];
foreach ($m2Files as $m2File) {
    $check(is_file($root . $m2File), 'Falta el artefacto M2 ' . $m2File . '.');
}

$m2Sql = (string) file_get_contents($root . '/sql/09_admin/fase2_gobernanza.sql');
$check(str_starts_with(ltrim($m2Sql), '--'), 'La migración M2 debe comenzar con el aviso de no ejecución.');
$check(
    str_contains($m2Sql, 'BEGIN;') && str_contains($m2Sql, 'COMMIT;'),
    'La migración M2 debe ser transaccional.'
);
$m2SqlSinComentarios = (string) preg_replace('/^\s*--.*$/m', '', $m2Sql);
foreach (['DROP TABLE', 'DROP COLUMN', 'DROP SCHEMA', 'TRUNCATE', 'DELETE FROM'] as $forbiddenSql) {
    $check(
        !preg_match('/\b' . str_replace(' ', '\s+', $forbiddenSql) . '\b/i', $m2SqlSinComentarios),
        'La migración M2 no debe contener ' . $forbiddenSql . '.'
    );
}
foreach (['os_admin.invitation', 'os_admin.invitation_grant', 'token_hash', 'membership_id'] as $sqlPiece) {
    $check(str_contains($m2Sql, $sqlPiece), 'La migración M2 debe incluir ' . $sqlPiece . '.');
}
$check(
    str_contains($m2Sql, 'uq_catalog_grant_global') && str_contains($m2Sql, 'uq_catalog_grant_membership'),
    'M2 debe separar los grants globales de los grants por membership con índices parciales.'
);
$check(
    str_contains($m2Sql, 'trg_catalog_grant_membership_user'),
    'M2 debe impedir grants de membership de otro usuario.'
);
foreach (['admin.orgs.manage', 'admin.invites.manage', 'admin.memberships.manage', 'admin.grants.manage'] as $newPermission) {
    $check(str_contains($m2Sql, $newPermission), 'La migración M2 debe crear el permiso ' . $newPermission . '.');
    $check(array_key_exists($newPermission, \OrigenSalud\Portal\Admin\Rbac::PERMISSIONS), 'RBAC debe exponer ' . $newPermission . '.');
}
$m2Verify = (string) file_get_contents($root . '/sql/09_admin/verificacion_fase2.sql');
$check(str_contains($m2Verify, 'BEGIN READ ONLY'), 'La verificación M2 debe usar BEGIN READ ONLY.');
$check(str_contains($m2Verify, 'ROLLBACK'), 'La verificación M2 debe finalizar con ROLLBACK.');

// Regresión: M2 no agregó updated_by_user_id a membership (solo a organization).
// El repositorio debe usar exactamente el esquema aplicado; de lo contrario la
// asignación de miembros falla con "El servicio no está disponible".
$membershipRepoSource = (string) file_get_contents($root . '/portal/Repositories/MembershipRepository.php');
$check(
    !str_contains($membershipRepoSource, 'updated_by_user_id'),
    'membership no tiene la columna updated_by_user_id; el repositorio no debe referenciarla.'
);
$check(
    str_contains($membershipRepoSource, 'created_by_user_id')
        && str_contains($membershipRepoSource, 'updated_at = now()'),
    'membership debe conservar creador y fecha de actualización usando columnas existentes.'
);

$check(
    \OrigenSalud\Portal\Admin\Rbac::canGrantRole(['*'], ['superadmin'], 'superadmin'),
    'El superadministrador puede otorgar cualquier rol.'
);
$check(
    !\OrigenSalud\Portal\Admin\Rbac::canGrantRole(['admin.view'], ['editor'], 'superadmin'),
    'Nadie sin comodín puede otorgar superadmin.'
);
$check(
    !\OrigenSalud\Portal\Admin\Rbac::canGrantRole(['admin.view'], ['editor'], 'reviewer'),
    'El techo de permisos impide otorgar un rol con permisos ausentes.'
);
$check(
    !\OrigenSalud\Portal\Admin\Rbac::canGrantRole(['*'], ['superadmin'], 'rol_inexistente'),
    'No se pueden otorgar roles inexistentes.'
);
$check(\OrigenSalud\Portal\Admin\Rbac::isValidOrganizationType('health_center'), 'health_center debe ser un tipo válido.');
$check(!\OrigenSalud\Portal\Admin\Rbac::isValidOrganizationType('otro'), 'Un tipo arbitrario debe ser rechazado.');
$check(\OrigenSalud\Portal\Admin\Rbac::isValidOperation('propose'), 'propose debe ser una operación válida.');
$check(!\OrigenSalud\Portal\Admin\Rbac::isValidOperation('drop'), 'La operación drop debe ser rechazada.');

$configSource = (string) file_get_contents($root . '/portal/Config.php');
$check(str_contains($configSource, 'function adminBaseUrl()'), 'Config debe exponer la URL base del panel.');
$check(str_contains($configSource, "'invite_ttl'"), 'Config debe exponer el TTL de invitaciones.');
$check(str_contains($configSource, "'invite_max_ttl'"), 'Config debe exponer el tope de TTL de invitaciones.');
$envSource = (string) file_get_contents($root . '/.env.example');
foreach (['ADMIN_BASE_URL=', 'ADMIN_INVITE_TTL=', 'ADMIN_INVITE_MAX_TTL=', 'ADMIN_INVITE_RESEND_MIN='] as $envKey) {
    $check(str_contains($envSource, $envKey), '.env.example debe documentar ' . $envKey . '.');
}
$check(
    str_contains($envSource, 'WEB_BASE_URL=https://med.origen.ar')
        && str_contains($envSource, 'ADMIN_BASE_URL=https://med.origen.ar'),
    '.env.example debe apuntar el panel al host web, no al host de la API.'
);
$check(str_contains($envSource, 'SMTP_FROM='), '.env.example debe documentar SMTP_FROM.');

$routerSource = (string) file_get_contents($root . '/portal/Router.php');
foreach (['organizations', 'invitations', 'invite', 'memberships', 'context'] as $m2Route) {
    $check(
        str_contains($routerSource, "'" . $m2Route . "'"),
        'El router debe registrar el segmento ' . $m2Route . ' bajo /admin.'
    );
}
$m2Layout = (string) file_get_contents($root . '/portal/Views/layouts/admin.php');
$check(str_contains($m2Layout, "action=\"/admin/context\""), 'El panel debe ofrecer el selector de contexto activo.');
$check(str_contains($m2Layout, "Rbac::hasPermission"), 'La navegación debe ocultarse según permisos.');

$governanceSource = (string) file_get_contents($root . '/portal/Admin/GovernanceService.php');
foreach ([
    'organization_created', 'invitation_created', 'invitation_resent', 'invitation_revoked',
    'invitation_accepted', 'invitation_accept_failed', 'membership_created', 'membership_suspended',
    'membership_revoked', 'catalog_grant_updated', 'organization_context_switched',
] as $auditEvent) {
    $check(
        str_contains($governanceSource . $routerSource . (string) file_get_contents($root . '/portal/Admin/AuthService.php'), $auditEvent),
        'M2 debe auditar el evento ' . $auditEvent . '.'
    );
}
$check(
    !str_contains($governanceSource, 'AuditLogger::record($token'),
    'El token de invitación nunca debe enviarse a la auditoría.'
);
$smtpMailerSource = (string) file_get_contents($root . '/portal/Services/SmtpMailer.php');
$check(
    str_contains($smtpMailerSource, "return self::fail('smtp_rcpt_failed', \$rcpt);")
        && str_contains($smtpMailerSource, "private static function fail(string \$error, string \$detail = '')")
        && str_contains($smtpMailerSource, 'mb_substr($detail, 0, 300)'),
    'El cliente SMTP debe capturar y acotar la respuesta del servidor en cada fallo.'
);
$check(
    str_contains($governanceSource, "isset(\$mail['detail'])")
        && str_contains($governanceSource, "\$reason .= ' | ' . \$detail;")
        && str_contains($governanceSource, "'reason' => mb_substr(\$reason, 0, 500)"),
    'El fallo de mail debe auditar el motivo detallado del servidor SMTP.'
);
$portalConfigSource = (string) file_get_contents($root . '/portal/Config.php');
$check(
    str_contains($portalConfigSource, "env('SMTP_FROM'")
        && str_contains($portalConfigSource, "env('SMTP_USER'")
        && str_contains($portalConfigSource, "'from' => \$from"),
    'El remitente SMTP debe alinearse con el usuario autenticado, con SMTP_FROM como override.'
);
$check(
    str_contains($smtpMailerSource, "'MAIL FROM:<' . \$config['from'] . '>'")
        && str_contains($smtpMailerSource, "'From: ' . \$from"),
    'El sobre y la cabecera From deben usar el mismo remitente configurado.'
);
$i18nSource = (string) file_get_contents($root . '/portal/i18n/I18n.php');
$check(
    str_contains($i18nSource, 'public const DEFAULT_LOCALE = \'es-AR\'')
        && str_contains($i18nSource, 'self::$resolvedFrom = \'config\'')
        && str_contains($i18nSource, 'self::$resolvedFrom !== \'header\''),
    'es-AR debe ser el default efectivo y no persistirse una preferencia del navegador.'
);
$adminFormSource = (string) file_get_contents($root . '/portal/Controllers/AdminForm.php');
$inviteControllerSource = (string) file_get_contents($root . '/portal/Controllers/AdminInvitationController.php');
$loginViewSource = (string) file_get_contents($root . '/portal/Views/admin/login.php');
$check(
    str_contains($adminFormSource, 'public static function success(string $redirect, string $key, array $values = [])')
        && str_contains($adminFormSource, '\'email\' => is_string($values[\'email\'] ?? null)'),
    'El flash de éxito debe poder transportar el correo para precargar el login.'
);
$check(
    str_contains($inviteControllerSource, '\'email\' => (string) ($accepted[\'email\'] ?? \'\')')
        && str_contains($governanceSource, 'return [\'ok\' => true, \'user_id\' => $userId, \'email\' => $email]'),
    'Tras aceptar la invitación se debe devolver el correo al redirect de login.'
);
$check(
    str_contains($loginViewSource, 'value="<?= e($email) ?>"')
        && preg_match('/name="password"[^>]*\bvalue=/s', $loginViewSource) !== 1,
    'El login debe precargar el correo y nunca la contraseña.'
);
$check(
    str_contains($governanceSource, 'Token::hash($token)'),
    'Solo el hash del token debe persistirse.'
);
$check(
    str_contains($governanceSource, 'countActiveGlobalSuperadmins') && str_contains($governanceSource, 'last_superadmin'),
    'M2 debe proteger al último superadministrador global.'
);
$check(
    str_contains($governanceSource, 'CatalogReferenceRepository::exists') && !str_contains($m2Sql, 'REFERENCES public.os_catalog'),
    'El código de catálogo se valida con la conexión pública, sin FK desde os_admin.'
);

$m2I18nKeys = [
    'admin.orgs.title', 'admin.invites.title', 'admin.members.title', 'admin.context.label',
    'admin.invite.title', 'admin.grants.hint', 'admin.messages.invite_accepted',
    'admin.errors.last_superadmin', 'admin.errors.grant_required',
    'admin.grants.title', 'admin.grants.allow', 'admin.grants.deny',
    'admin.grants.deny_title', 'admin.grants.deny_help', 'admin.grants.member_title',
    'admin.grants.role_auto', 'admin.grants.all', 'admin.grants.none',
    'admin.grants.catalog_toggle_title',
    'admin.grants.ops.view', 'admin.grants.ops.propose', 'admin.grants.ops.edit_draft',
    'admin.grants.ops.review', 'admin.grants.ops.approve', 'admin.grants.ops.publish',
    'admin.roles.org_type.health_center',
];

// Los grants se eligen con casillas: sin campos de texto libres para catalog_code.
$grantChoicesView = (string) file_get_contents($root . '/portal/Views/admin/_grant_choices.php');
$check(str_contains($grantChoicesView, "'grant_allow'"), 'El selector debe ofrecer casillas de permiso.');
$check(str_contains($grantChoicesView, "'grant_deny'"), 'El selector debe ofrecer casillas de denegación.');
$check(
    str_contains($grantChoicesView, 'Rbac::CATALOG_OPERATIONS')
        && str_contains($grantChoicesView, '<details class="admin-grants-deny">'),
    'El selector debe usar operaciones válidas y mantener las denegaciones plegadas.'
);
$check(
    !str_contains($grantChoicesView, 'admin-grant-grid') && !str_contains($grantChoicesView, 'aria-hidden'),
    'El selector no debe usar la grilla densa ni símbolos duplicados por casilla.'
);
$check(
    str_contains($grantChoicesView, 'data-grant-toggle-op')
        && str_contains($grantChoicesView, 'data-label-all')
        && str_contains($grantChoicesView, 'data-label-none')
        && str_contains($grantChoicesView, 'admin.grants.all')
        && str_contains($grantChoicesView, 'admin.grants.none'),
    'El selector debe ofrecer Todo/Ninguno por operación.'
);
$check(
    str_contains($grantChoicesView, 'data-grant-toggle-catalog')
        && str_contains($grantChoicesView, "field === 'grant_allow'")
        && str_contains($grantChoicesView, 'admin.grants.catalog_toggle_title'),
    'Cada catálogo debe tener su propio Todo/Ninguno junto a Publicar.'
);
foreach (['/portal/Views/admin/organization.php', '/portal/Views/admin/invitations.php'] as $m2GrantView) {
    $grantViewSource = (string) file_get_contents($root . $m2GrantView);
    $check(
        str_contains($grantViewSource, "_grant_choices.php") && !str_contains($grantViewSource, 'name="grants"'),
        $m2GrantView . ' debe usar el selector de casillas en lugar del campo de texto de grants.'
    );
}
$rbacSource = (string) file_get_contents($root . '/portal/Admin/Rbac.php');
$check(
    str_contains($rbacSource, 'function catalogOperationsForRole')
        && str_contains($rbacSource, "in_array('catalog.' . \$operation, \$permissions, true)")
        && str_contains($rbacSource, 'return self::CATALOG_OPERATIONS'),
    'Las operaciones de catálogo por rol deben derivarse de ROLE_PERMISSIONS, con superadmin completas.'
);
$grantRoleDefaultsScript = (string) file_get_contents($root . '/portal/Views/admin/_grant_role_defaults.php');
$check(
    str_contains($grantRoleDefaultsScript, 'select[data-grants-role]')
        && str_contains($grantRoleDefaultsScript, 'grant_allow[]')
        && str_contains($grantRoleDefaultsScript, 'grant_deny[]')
        && str_contains($grantRoleDefaultsScript, 'dataset.catalogOps')
        && str_contains($grantRoleDefaultsScript, 'data-grant-toggle-op')
        && str_contains($grantRoleDefaultsScript, 'data-grant-toggle-catalog')
        && str_contains($grantRoleDefaultsScript, 'function boxesForCatalog')
        && str_contains($grantRoleDefaultsScript, 'function syncAll')
        && str_contains($grantRoleDefaultsScript, 'dataset.labelNone'),
    'Los controles de grants deben preseleccionar por rol y alternar Todo/Ninguno por operación y por catálogo.'
);
foreach (['/portal/Views/admin/organization.php', '/portal/Views/admin/invitations.php'] as $roleGrantView) {
    $roleGrantSource = (string) file_get_contents($root . $roleGrantView);
    $check(
        str_contains($roleGrantSource, 'data-grants-role')
            && str_contains($roleGrantSource, 'data-catalog-ops')
            && str_contains($roleGrantSource, 'Rbac::catalogOperationsForRole')
            && str_contains($roleGrantSource, "_grant_role_defaults.php")
            && str_contains($roleGrantSource, "admin.grants.role_auto"),
        $roleGrantView . ' debe preseleccionar los grants según el rol elegido.'
    );
}
$catalogRepoSource = (string) file_get_contents($root . '/portal/Repositories/CatalogReferenceRepository.php');
$check(
    str_contains($catalogRepoSource, 'public.os_catalog')
        && str_contains($catalogRepoSource, 'is_active = true')
        && str_contains($catalogRepoSource, 'function all()'),
    'El listado de catálogos debe ser de solo lectura y limitarse a los activos.'
);
$check(
    str_contains($governanceSource, 'grantsFromSelection')
        && str_contains($governanceSource, "'grant_allow'")
        && str_contains($governanceSource, "'grant_deny'")
        && str_contains($governanceSource, 'grant_required'),
    'El servicio debe validar los grants elegidos con casillas.'
);
foreach (['es-AR', 'en', 'pt-BR', 'es'] as $m2Locale) {
    $m2Messages = Yaml::parseFile($root . '/portal/translations/messages.' . $m2Locale . '.yaml');
    $m2Flat = [];
    $flattenM2 = static function (array $node, string $prefix) use (&$flattenM2, &$m2Flat): void {
        foreach ($node as $key => $value) {
            $path = $prefix === '' ? (string) $key : $prefix . '.' . (string) $key;
            if (is_array($value)) {
                $flattenM2($value, $path);
            } else {
                $m2Flat[$path] = $value;
            }
        }
    };
    $flattenM2(is_array($m2Messages['admin'] ?? null) ? $m2Messages['admin'] : [], '');
    foreach ($m2I18nKeys as $m2Key) {
        $m2Relative = substr($m2Key, strlen('admin.'));
        $check(array_key_exists($m2Relative, $m2Flat), $m2Locale . ': falta la clave ' . $m2Key . '.');
    }
}

// Gestión UVR (Acta U0 y plan U0–U6).
$uvrArtifacts = [
    '/docs/architecture/gobernanza-uvr-acta-u0.md',
    '/docs/architecture/gobernanza-uvr-acta-verificacion.md',
    '/docs/architecture/gobernanza-uvr-cierre.md',
    '/sql/08_arquitectura/uvr_gobernanza_datos.sql',
    '/sql/08_arquitectura/verificacion_uvr_gobernanza.sql',
    '/portal/Admin/UvrGovernanceService.php',
    '/portal/Admin/UvrGovernanceException.php',
    '/portal/Admin/UvrImporteService.php',
    '/portal/Repositories/UvrRepository.php',
    '/portal/Controllers/AdminUvrController.php',
    '/portal/Views/admin/uvr/_nav.php',
    '/portal/Views/admin/uvr/index.php',
    '/portal/Views/admin/uvr/catalogs.php',
    '/portal/Views/admin/uvr/proposals.php',
    '/portal/Views/admin/uvr/proposal.php',
    '/portal/Views/admin/uvr/tasks.php',
    '/portal/Views/admin/uvr/compare.php',
    '/portal/Views/admin/uvr/methodologies.php',
    '/portal/Views/admin/uvr/monetary.php',
];
foreach ($uvrArtifacts as $uvrArtifact) {
    $check(is_file($root . $uvrArtifact), 'Falta el artefacto UVR ' . $uvrArtifact . '.');
}

$uvrActa = (string) file_get_contents($root . '/docs/architecture/gobernanza-uvr-acta-u0.md');
for ($uvrConflict = 1; $uvrConflict <= 12; $uvrConflict++) {
    $check(str_contains($uvrActa, 'C' . $uvrConflict), 'El acta U0 debe cerrar C' . $uvrConflict . '.');
}
$check(str_contains($uvrActa, 'APROBADA') && str_contains($uvrActa, 'importe_referencial'), 'El acta U0 debe aprobar el nombre del importe.');
$uvrActaU7 = (string) file_get_contents($root . '/docs/architecture/gobernanza-uvr-acta-u7.md');
foreach ([
    'APROBADA',
    'Sistema de Gobernanza y Valoración de Prestaciones Sanitarias',
    'os_prestacion',
    'os_uvr_profile',
    'equivalencia económica',
    'U7-B',
] as $uvrU7Piece) {
    $check(str_contains($uvrActaU7, $uvrU7Piece), 'El acta U7 debe registrar ' . $uvrU7Piece . '.');
}
$uvrSqlReadme = (string) file_get_contents($root . '/sql/08_arquitectura/README.md');
$check(
    str_contains($uvrSqlReadme, 'gobernanza-uvr-acta-u7.md') && str_contains($uvrSqlReadme, 'U7-B'),
    'El README SQL debe referenciar U7 sin autorizar su migración.'
);
$uvrActaVerificacion = (string) file_get_contents($root . '/docs/architecture/gobernanza-uvr-acta-verificacion.md');
foreach (['COMMIT', 'ROLLBACK', '603 | 22 | 0 | 0 | 9 | 10 | 10 | 40', 'U1 cerrado en base', '0 grantees `PUBLIC`'] as $uvrEvidencia) {
    $check(str_contains($uvrActaVerificacion, $uvrEvidencia), 'El acta de verificación debe registrar ' . $uvrEvidencia . '.');
}
$check(
    str_contains($uvrActaVerificacion, 'No ejecutada.') || str_contains($uvrActaVerificacion, '**No ejecutada.**'),
    'El acta de verificación debe dejar la opción de mínimo privilegio como no ejecutada.'
);
$uvrReadme = (string) file_get_contents($root . '/README-UVR.md');
$check(
    str_contains($uvrReadme, 'Glosario de equivalencias')
        && str_contains($uvrReadme, 'malpractice_uvr')
        && str_contains($uvrReadme, 'Responsabilidad profesional'),
    'README-UVR debe publicar el glosario de equivalencias sin renombrar el legado.'
);

$uvrMigration = (string) file_get_contents($root . '/sql/08_arquitectura/uvr_gobernanza_datos.sql');
$uvrMigrationSinComentarios = (string) preg_replace('/^\s*--.*$/m', '', $uvrMigration);
$check(str_contains($uvrMigration, 'BEGIN;') && str_contains($uvrMigration, 'COMMIT;'), 'La migración UVR debe ser transaccional.');
foreach (['DROP TABLE', 'DROP COLUMN', 'DROP SCHEMA', 'TRUNCATE', 'DELETE FROM'] as $uvrForbidden) {
    $check(
        !preg_match('/\b' . str_replace(' ', '\s+', $uvrForbidden) . '\b/i', $uvrMigrationSinComentarios),
        'La migración UVR no debe contener ' . $uvrForbidden . '.'
    );
}
$check(!str_contains($uvrMigration, 'ALTER DEFAULT PRIVILEGES'), 'La migración UVR no debe modificar el DEFAULT ACL global.');
foreach (['REVOKE ALL PRIVILEGES', 'ADD COLUMN IF NOT EXISTS', 'calculated_by_user_id', 'approved_by_user_id', 'is_not_applicable', 'negative_adjustment_evidence', 'os_uvr_assert_publication_ready', 'os_uvr_audit_trigger'] as $uvrSqlPiece) {
    $check(str_contains($uvrMigration, $uvrSqlPiece), 'La migración UVR debe incluir ' . $uvrSqlPiece . '.');
}
$check(
    str_contains($uvrMigrationSinComentarios, 'GRANT USAGE, SELECT ON SEQUENCE')
        && str_contains($uvrMigrationSinComentarios, 'public.os_governance_request_id_seq')
        && str_contains($uvrMigrationSinComentarios, 'public.os_uvr_valuation_id_seq')
        && str_contains($uvrMigrationSinComentarios, 'public.os_uvr_component_id_seq')
        && str_contains($uvrMigrationSinComentarios, 'public.os_governance_review_id_seq')
        && str_contains($uvrMigrationSinComentarios, 'public.os_governance_decision_id_seq')
        && str_contains($uvrMigrationSinComentarios, 'public.os_uvr_conversion_id_seq')
        && str_contains($uvrMigrationSinComentarios, 'public.os_uvr_geo_index_id_seq')
        && str_contains($uvrMigrationSinComentarios, 'public.os_audit_log_id_seq')
        && str_contains($uvrMigrationSinComentarios, 'GRANT SELECT, INSERT ON TABLE public.os_audit_log'),
    'La migración UVR debe conceder USAGE sobre las secuencias y INSERT en os_audit_log.'
);
$check(
    !preg_match('/ADD\s+COLUMN[^\n]*total_uvr/i', $uvrMigration),
    'total_uvr no debe almacenarse como columna.'
);
$check(
    str_contains($uvrMigration, 'is_publication_allowed'),
    'El guardián debe comprobar os_review_state.is_publication_allowed.'
);
$uvrVerify = (string) file_get_contents($root . '/sql/08_arquitectura/verificacion_uvr_gobernanza.sql');
$check(str_contains($uvrVerify, 'BEGIN READ ONLY;'), 'La verificación UVR debe ser de solo lectura.');
$check(str_contains($uvrVerify, 'ROLLBACK;'), 'La verificación UVR debe finalizar con ROLLBACK.');
$uvrProposalVerify = (string) file_get_contents(
    $root . '/sql/08_arquitectura/verificacion_propuesta_uvr.sql'
);
$check(
    str_contains($uvrProposalVerify, 'BEGIN READ ONLY;')
    && str_contains($uvrProposalVerify, 'ROLLBACK;')
    && str_contains($uvrProposalVerify, "has_table_privilege('origen_admin'")
    && str_contains($uvrProposalVerify, "has_sequence_privilege('origen_admin'")
    && str_contains($uvrProposalVerify, 'public.os_audit_log')
    && str_contains($uvrProposalVerify, 'public.os_audit_log_id_seq')
    && str_contains($uvrProposalVerify, 'prosecdef')
    && str_contains($uvrProposalVerify, 'os_uvr_assert_eligible_service')
    && !preg_match('/^\s*(INSERT|UPDATE|DELETE|TRUNCATE)\b/im', $uvrProposalVerify),
    'El diagnosticador de propuestas UVR debe ser solo lectura y revisar permisos de origen_admin.'
);
$uvrSequenceFix = (string) file_get_contents(
    $root . '/sql/08_arquitectura/uvr_correccion_secuencias_panel.sql'
);
$check(
    str_contains($uvrSequenceFix, 'BEGIN;')
    && str_contains($uvrSequenceFix, 'COMMIT;')
    && str_contains($uvrSequenceFix, 'REVOKE ALL PRIVILEGES ON SEQUENCE')
    && str_contains($uvrSequenceFix, 'FROM PUBLIC;')
    && str_contains($uvrSequenceFix, "to_regrole('origen_admin')")
    && str_contains($uvrSequenceFix, 'GRANT USAGE, SELECT ON SEQUENCE')
    && str_contains($uvrSequenceFix, 'GRANT SELECT, INSERT ON TABLE public.os_audit_log')
    && str_contains($uvrSequenceFix, 'public.os_audit_log_id_seq')
    && !str_contains($uvrSequenceFix, 'ALTER DEFAULT PRIVILEGES')
    && !preg_match('/^\s*(INSERT|UPDATE|DELETE|TRUNCATE)\b/im', $uvrSequenceFix),
    'El corrector de secuencias UVR debe usar REVOKE/GRANT por secuencia, sin DEFAULT ACL global ni SQL de datos.'
);
foreach ([
    'os_governance_request_id_seq',
    'os_governance_review_id_seq',
    'os_governance_decision_id_seq',
    'os_uvr_valuation_id_seq',
    'os_uvr_component_id_seq',
    'os_uvr_conversion_id_seq',
    'os_uvr_geo_index_id_seq',
    'os_audit_log_id_seq',
] as $sequence) {
    $check(
        str_contains($uvrProposalVerify, $sequence) && str_contains($uvrSequenceFix, $sequence),
        'La secuencia ' . $sequence . ' debe aparecer en el diagnóstico y en el corrector UVR.'
    );
}
$uvrTriggerFix = (string) file_get_contents(
    $root . '/sql/08_arquitectura/uvr_correccion_trigger_elegibilidad.sql'
);
$check(
    str_contains($uvrTriggerFix, 'SECURITY DEFINER')
    && str_contains($uvrTriggerFix, 'SET search_path = public, pg_temp')
    && str_contains($uvrTriggerFix, 'public.os_catalog_item')
    && str_contains($uvrTriggerFix, 'REVOKE ALL PRIVILEGES ON FUNCTION')
    && str_contains($uvrTriggerFix, 'GRANT EXECUTE ON FUNCTION')
    && !preg_match('/GRANT\s+(SELECT|ALL)[^;]*os_catalog/i', $uvrTriggerFix)
    && !preg_match('/^\s*(INSERT|UPDATE|DELETE|TRUNCATE)\b/im', $uvrTriggerFix),
    'El corrector de triggers UVR debe usar SECURITY DEFINER sin conceder privilegios sobre catálogos.'
);
foreach ([
    'fase6_uvr.sql' => 'os_uvr_assert_eligible_service',
    'uvr_gobernanza_datos.sql' => 'os_uvr_assert_publication_ready',
] as $uvrMigrationName => $uvrFunction) {
    $uvrMigrationSource = (string) file_get_contents($root . '/sql/08_arquitectura/' . $uvrMigrationName);
    $check(
        str_contains($uvrMigrationSource, 'SECURITY DEFINER')
            && str_contains($uvrMigrationSource, $uvrFunction),
        $uvrMigrationName . ' debe definir ' . $uvrFunction . ' como SECURITY DEFINER.'
    );
}
$check(
    str_contains($uvrVerify, 'FROM information_schema.role_table_grants')
        && str_contains($uvrVerify, 'table_name AS objeto')
        && !str_contains($uvrVerify, 'relname AS objeto'),
    'La verificación UVR debe usar table_name en information_schema.role_table_grants.'
);
$check(str_contains($uvrVerify, '\pset pager off'), 'La verificación UVR debe desactivar el paginador de psql.');

$uvrServiceSource = (string) file_get_contents($root . '/portal/Admin/UvrGovernanceService.php');
$uvrControllerSource = (string) file_get_contents($root . '/portal/Controllers/AdminUvrController.php');
$uvrRepoSource = (string) file_get_contents($root . '/portal/Repositories/UvrRepository.php');
$check(count(\OrigenSalud\Portal\Admin\Rbac::PERMISSIONS) === 14, 'La gestión UVR no debe crear permisos nuevos.');
$check(str_contains($uvrServiceSource, 'Rbac::canApprove('), 'La decisión debe usar Rbac::canApprove() en servicio.');
$check(str_contains($uvrServiceSource, 'UvrImporteService::calcular'), 'El importe debe derivarse en servicio.');
$check(str_contains($uvrServiceSource, 'clinical') && str_contains($uvrServiceSource, 'economic'), 'Debe haber dos revisiones independientes.');
$check(str_contains($uvrRepoSource, "set_config('app.actor_id'"), 'La auditoría debe tomar el actor de la sesión.');
$check(
    str_contains($uvrRepoSource, 'function beginWrite()')
        && str_contains($uvrRepoSource, 'function commitWrite()')
        && str_contains($uvrRepoSource, 'function rollBackWrite()')
        && str_contains($uvrServiceSource, 'UvrRepository::beginWrite()')
        && str_contains($uvrServiceSource, 'UvrRepository::commitWrite()')
        && str_contains($uvrServiceSource, 'UvrRepository::rollBackWrite()')
        && str_contains($uvrServiceSource, 'catch (\Throwable $exception)'),
    'La propuesta UVR debe ser atómica: todas las escrituras en una transacción con rollback.'
);
$check(
    substr_count($uvrRepoSource, "'t' : 'f'") === 2
        && !str_contains($uvrRepoSource, "':not_applicable' => (bool)"),
    'Los componentes UVR deben enlazar is_not_applicable como t/f para evitar boolean vacío.'
);
$check(str_contains($uvrControllerSource, 'AdminGuard::require'), 'Las vistas UVR deben pasar por AdminGuard.');
$check(substr_count($uvrControllerSource, 'AdminForm::validCsrf()') >= 4, 'Los formularios UVR deben validar CSRF.');
$check(
    !str_contains($uvrControllerSource, '/v1/uvr') && !str_contains($uvrControllerSource, '/fhir/'),
    'El panel no debe anunciar rutas de API inexistentes.'
);
$uvrProposalViewSource = (string) file_get_contents($root . '/portal/Views/admin/uvr/proposals.php');
foreach ([
    'name="catalog"',
    'name="q"',
    'name="service_item_id"',
    'admin.catalogs.select_title',
    'admin.catalogs.search_title',
] as $uvrFlowPiece) {
    $check(str_contains($uvrProposalViewSource, $uvrFlowPiece), 'La propuesta UVR debe incluir ' . $uvrFlowPiece . '.');
}
$check(
    str_contains($uvrServiceSource, 'proposalCatalogs(') && str_contains($uvrServiceSource, 'catalog_item_not_found'),
    'El servicio debe exponer los catálogos elegibles y validar el código propuesto.'
);
$check(
    str_contains($uvrControllerSource, 'proposalCatalogs(') && str_contains($uvrControllerSource, 'new CatalogGovernanceService()'),
    'El controlador debe resolver catálogo y código antes de proponer.'
);

$uvrImporte = \OrigenSalud\Portal\Admin\UvrImporteService::calcular(
    ['work_uvr' => 2.5, 'practice_expense_uvr' => 1.2, 'professional_liability_uvr' => 0.3],
    ['uvr_value' => 100, 'currency' => 'ARS', 'review_status' => 'approved']
);
$check(is_array($uvrImporte), 'Una conversión aprobada debe producir importe derivado.');
$check(($uvrImporte['importe_referencial'] ?? null) === '400.00', 'El importe referencial debe redondearse a dos decimales.');
$check(($uvrImporte['total_uvr'] ?? null) === '4.00', 'El total UVR presentado debe redondearse a dos decimales.');
$check(($uvrImporte['estimated_payment'] ?? null) === ($uvrImporte['importe_referencial'] ?? null), 'estimated_payment es el alias interno del importe referencial.');
$check(
    \OrigenSalud\Portal\Admin\UvrImporteService::calcular(
        ['work_uvr' => 1],
        ['uvr_value' => 10, 'currency' => 'ARS', 'review_status' => 'draft']
    ) === null,
    'Sin conversión aprobada no debe mostrarse importe.'
);
$check(
    \OrigenSalud\Portal\Admin\UvrImporteService::calcular(['work_uvr' => 1], null) === null,
    'Sin conversión no debe inventarse importe.'
);

$uvrDecimal = static fn (mixed $raw): ?float => \OrigenSalud\Portal\Admin\UvrImporteService::decimal($raw);
foreach ([
    ['1.5', 1.5],
    ['1,5', 1.5],
    ['12.75', 12.75],
    ['12,75', 12.75],
    ['1.234,56', 1234.56],
    ['1,234.56', 1234.56],
    ['1 234,56', 1234.56],
    ["1\u{00A0}234,56", 1234.56],
    ['1.234.567', 1234567.0],
    ['1,234,567', 1234567.0],
    ['-1,5', -1.5],
    ['0', 0.0],
    [7, 7.0],
] as $uvrDecimalCase) {
    $check(
        abs(($uvrDecimal($uvrDecimalCase[0]) ?? NAN) - $uvrDecimalCase[1]) < 0.000001,
        'UVR debe interpretar el decimal ' . var_export($uvrDecimalCase[0], true) . ' como ' . $uvrDecimalCase[1] . '.'
    );
}
foreach (['', 'abc', '1,2,3x', '1.2.3,4,5', '1e999'] as $badDecimal) {
    $check(
        $uvrDecimal($badDecimal) === null,
        'UVR debe rechazar el decimal inválido ' . var_export($badDecimal, true) . '.'
    );
}
$check(
    str_contains($uvrServiceSource, 'UvrImporteService::decimal('),
    'La propuesta UVR debe normalizar los decimales con punto o coma.'
);
$check(
    str_contains($uvrProposalViewSource, 'type="text" inputmode="decimal"')
        && str_contains($uvrProposalViewSource, 'admin.uvr.decimal_hint'),
    'El formulario UVR debe permitir escribir coma decimal y mostrar la ayuda.'
);

foreach (['es-AR', 'en', 'pt-BR', 'es'] as $uvrLocale) {
    $uvrMessages = Yaml::parseFile($root . '/portal/translations/messages.' . $uvrLocale . '.yaml');
    $uvrNode = is_array($uvrMessages['admin']['uvr'] ?? null) ? $uvrMessages['admin']['uvr'] : [];
    foreach (['title', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'derived_note', 'col_importe', 'decimal_hint'] as $uvrKey) {
        $check(is_string($uvrNode[$uvrKey] ?? null) && trim($uvrNode[$uvrKey]) !== '', $uvrLocale . ': falta admin.uvr.' . $uvrKey . '.');
    }
    foreach (['uvr_proposed', 'uvr_reviewed', 'uvr_decided', 'uvr_published', 'uvr_self_approval_denied'] as $uvrMessageKey) {
        $check(is_string($uvrMessages['admin']['messages'][$uvrMessageKey] ?? null) || is_string($uvrMessages['admin']['errors'][$uvrMessageKey] ?? null), $uvrLocale . ': falta la clave UVR ' . $uvrMessageKey . '.');
    }
}

// Gestión de catálogos y códigos (C0–C6).
$catalogArtifacts = [
    '/sql/08_arquitectura/catalogos_gestion_gobernada.sql',
    '/sql/08_arquitectura/verificacion_catalogos_gestion.sql',
    '/portal/Admin/CatalogGovernanceService.php',
    '/portal/Repositories/CatalogGovernanceRepository.php',
    '/portal/Controllers/AdminCatalogController.php',
    '/portal/Views/admin/catalogs/_nav.php',
    '/portal/Views/admin/catalogs/index.php',
    '/portal/Views/admin/catalogs/item.php',
    '/portal/Views/admin/catalogs/proposals.php',
    '/portal/Views/admin/catalogs/proposal.php',
    '/docs/architecture/gestion-catalogos-codigos.md',
];
foreach ($catalogArtifacts as $catalogArtifact) {
    $check(is_file($root . $catalogArtifact), 'Falta el artefacto de gestión de catálogos ' . $catalogArtifact . '.');
}

$catalogRepoSource = (string) file_get_contents($root . '/portal/Repositories/CatalogGovernanceRepository.php');
$check(
    str_contains($catalogRepoSource, 'COALESCE(v.preferred_term'),
    'El buscador de códigos debe encontrar también por término preferido.'
);
$check(
    str_contains($catalogRepoSource, 'JOIN LATERAL'),
    'El término preferido debe resolverse con la versión canónica del ítem.'
);
$check(
    str_contains($portalRepoSource, 'ORDER BY c.name ASC, c.code ASC')
    && str_contains($portalRepoSource, "if (!isset(\$categoryOptions[\$label]))")
    && str_contains($portalRepoSource, 'catcat.name = ('),
    'Las categorías del browser deben agruparse por nombre de capítulo y filtrar por ese nombre.'
);

$catalogMigration = (string) file_get_contents($root . '/sql/08_arquitectura/catalogos_gestion_gobernada.sql');
$catalogVerify = (string) file_get_contents($root . '/sql/08_arquitectura/verificacion_catalogos_gestion.sql');
$check(str_contains($catalogMigration, 'BEGIN;') && str_contains($catalogMigration, 'COMMIT;'), 'La migración de catálogos debe ser transaccional.');
$check(str_contains($catalogMigration, 'SECURITY DEFINER'), 'El aplicador de cambios debe ser SECURITY DEFINER.');
$check(str_contains($catalogMigration, 'REVOKE ALL PRIVILEGES ON FUNCTION'), 'El aplicador debe revocar PUBLIC de forma explícita.');
$check(!str_contains($catalogMigration, 'ALTER DEFAULT PRIVILEGES'), 'La migración de catálogos no debe modificar el DEFAULT ACL global.');
$check(
    !preg_match('/\bGRANT\s+(SELECT\s*,\s*)?(INSERT|UPDATE|DELETE)\b/i', (string) preg_replace('/^\s*--.*$/m', '', $catalogMigration)),
    'No se deben conceder escrituras directas sobre catálogos.'
);
$check(str_contains($catalogVerify, 'BEGIN READ ONLY;') && str_contains($catalogVerify, 'ROLLBACK;'), 'La verificación de catálogos debe ser de solo lectura.');
$check(str_contains($catalogVerify, 'routine_privileges') && str_contains($catalogVerify, 'role_table_grants'), 'La verificación debe comprobar privilegios de función y tabla.');

$catalogServiceSource = (string) file_get_contents($root . '/portal/Admin/CatalogGovernanceService.php');
$catalogControllerSource = (string) file_get_contents($root . '/portal/Controllers/AdminCatalogController.php');
$catalogRouterSource = (string) file_get_contents($root . '/portal/Router.php');
$catalogHeaderSource = (string) file_get_contents($root . '/portal/Views/partials/header.php');
$catalogUvrViewSource = (string) file_get_contents($root . '/portal/Views/admin/uvr/proposals.php');
$check(str_contains($catalogServiceSource, 'Rbac::canApprove('), 'La decisión de catálogo debe usar Rbac::canApprove().');
$check(str_contains($catalogServiceSource, 'os_catalog_apply_governed_change') === false, 'El servicio no debe nombrar SQL interno de la función.');
$check(str_contains($catalogControllerSource, 'AdminGuard::require'), 'Las vistas de catálogos deben pasar por AdminGuard.');
$check(substr_count($catalogControllerSource, 'AdminForm::validCsrf()') >= 4, 'Los formularios de catálogos deben validar CSRF.');
$check(
    !str_contains($catalogControllerSource, '/v1/') && !str_contains($catalogControllerSource, '/fhir/'),
    'El panel de catálogos no debe anunciar rutas de API inexistentes.'
);
$check(str_contains($catalogRouterSource, 'private function catalogs('), 'El router debe exponer las rutas de gestión de catálogos.');
$check(
    str_contains($catalogRouterSource, '$itemId = ctype_digit($fourth)'),
    'El router debe tomar el id del detalle de código desde el cuarto segmento.'
);
$check(str_contains($catalogHeaderSource, 'nav.management') && str_contains($catalogHeaderSource, 'href="/admin/login"'), 'El header público debe ofrecer el acceso Management.');
foreach (['/web/docs.php', '/web/uvr.php', '/web/search.php'] as $catalogHeaderFile) {
    $catalogStandaloneHeader = (string) file_get_contents($root . $catalogHeaderFile);
    $check(
        str_contains($catalogStandaloneHeader, 'nav.management') && str_contains($catalogStandaloneHeader, 'href="/admin/login"'),
        $catalogHeaderFile . ': falta el botón Management en el header.'
    );
}
$check(str_contains($catalogUvrViewSource, 'service_item_id'), 'El botón UVR debe precargar el código elegido en la propuesta UVR.');

foreach (['es-AR', 'en', 'pt-BR', 'es'] as $catalogLocale) {
    $catalogMessages = \Symfony\Component\Yaml\Yaml::parseFile($root . '/portal/translations/messages.' . $catalogLocale . '.yaml');
    $check(is_string($catalogMessages['nav']['management'] ?? null) && trim($catalogMessages['nav']['management']) !== '', $catalogLocale . ': falta nav.management.');
    $catalogNode = is_array($catalogMessages['admin']['catalogs'] ?? null) ? $catalogMessages['admin']['catalogs'] : [];
    foreach (['title', 'lead', 'tab_codes', 'tab_requests', 'col_code', 'uvr_button', 'propose_submit'] as $catalogKey) {
        $check(is_string($catalogNode[$catalogKey] ?? null) && trim($catalogNode[$catalogKey]) !== '', $catalogLocale . ': falta admin.catalogs.' . $catalogKey . '.');
    }
    foreach (['catalog_proposed', 'catalog_published'] as $catalogMessageKey) {
        $check(is_string($catalogMessages['admin']['messages'][$catalogMessageKey] ?? null), $catalogLocale . ': falta el mensaje ' . $catalogMessageKey . '.');
    }
    foreach (['catalog_permission_denied', 'catalog_grant_denied', 'catalog_evidence_required'] as $catalogErrorKey) {
        $check(is_string($catalogMessages['admin']['errors'][$catalogErrorKey] ?? null), $catalogLocale . ': falta el error ' . $catalogErrorKey . '.');
    }
}

// 17. Calendarios del panel: inputs nativos con estilo Tailwind reutilizable.
$adminDateInputs = [
    '/portal/Views/admin/catalogs/item.php' => ['catalog-item-valid-from', 'catalog-item-valid-to'],
    '/portal/Views/admin/catalogs/index.php' => ['edit-valid-from', 'edit-valid-to', 'catalog-valid-from'],
    '/portal/Views/admin/uvr/proposals.php' => ['uvr-evaluated', 'uvr-valid-from', 'uvr-valid-to'],
];
$adminDateCount = 0;
foreach ($adminDateInputs as $adminDateFile => $adminDateIds) {
    $adminDateSource = (string) file_get_contents($root . $adminDateFile);
    $check(substr_count($adminDateSource, 'type="date"') === count($adminDateIds), $adminDateFile . ': cambió la cantidad de campos de fecha.');
    foreach ($adminDateIds as $adminDateId) {
        $adminDatePosition = strpos($adminDateSource, 'id="' . $adminDateId . '"');
        $adminDateTag = $adminDatePosition === false ? '' : substr($adminDateSource, $adminDatePosition, 320);
        $adminDateCount += (int) str_contains($adminDateTag, 'type="date"');
        $check(
            str_contains($adminDateTag, 'ui-date') && !str_contains($adminDateTag, 'class="ui-input"'),
            $adminDateFile . ': ' . $adminDateId . ' debe usar la utilidad ui-date.'
        );
    }
}
$check($adminDateCount === 8, 'Los 8 calendarios del panel deben conservar el calendario nativo.');

$adminCssSource = (string) file_get_contents($root . '/resources/css/admin.css');
$check(str_contains($adminCssSource, '@utility ui-date'), 'Debe existir la utilidad ui-date en el CSS de administración.');
$check(
    str_contains($adminCssSource, '::-webkit-calendar-picker-indicator')
    && str_contains($adminCssSource, 'scheme-light'),
    'La utilidad ui-date debe estilizar el indicador y fijar el esquema claro.'
);
$adminCssBuilt = $root . '/web/assets/css/admin.css';
$check(is_file($adminCssBuilt), 'Debe existir el build compilado del CSS de administración.');
if (is_file($adminCssBuilt)) {
    $adminCssCompiled = (string) file_get_contents($adminCssBuilt);
    $check(str_contains($adminCssCompiled, '.ui-date'), 'El build admin debe incluir la utilidad ui-date.');
    $check(str_contains($adminCssCompiled, '.ui-date::-webkit-calendar-picker-indicator'), 'El build admin debe incluir el ícono de calendario clicable.');
}

// 18. LOINC: la rama pública resuelve capas por idioma desde la tabla editable.
require_once $root . '/portal/Repositories/CatalogRepository.php';
$loincReflection = new ReflectionClass(OrigenSalud\Portal\Repositories\CatalogRepository::class);
$loincChainMethod = $loincReflection->getMethod('loincLanguageChain');
$loincChainMethod->setAccessible(true);
$loincBranchMethod = $loincReflection->getMethod('loincBranch');
$loincBranchMethod->setAccessible(true);
foreach ([
    'es-AR' => ['es-AR', 'es-MX', 'en'],
    'es' => ['es-AR', 'es-MX', 'en'],
    'en' => ['en', 'es-AR', 'es-MX'],
    'pt-BR' => ['es-AR', 'es-MX', 'en'],
] as $loincRequested => $loincExpectedChain) {
    $check(
        $loincChainMethod->invoke(null, $loincRequested) === $loincExpectedChain,
        'LOINC: cadena de idiomas incorrecta para ' . $loincRequested . '.'
    );
}
foreach ([['infarto', 'es-AR'], ['infarction', 'en']] as $loincCase) {
    [$loincSql, $loincParams] = $loincBranchMethod->invoke(null, 'p0', $loincCase[0], $loincCase[1], false, null);
    $check(str_contains($loincSql, 'loinc_localized_text'), 'LOINC: la rama debe resolver desde loinc_localized_text.');
    $check(!str_contains($loincSql, "'es' AS language"), 'LOINC: no debe fijar el idioma a es.');
    $check(str_contains($loincSql, 'AS language'), 'LOINC: debe devolver el idioma resuelto.');
    $check(str_contains($loincSql, 'source_priority DESC'), 'LOINC: debe aplicar la prioridad D-33.');
    $check(
        !str_starts_with(ltrim($loincSql), 'WITH'),
        'LOINC: la rama no debe empezar con WITH; al ir después de UNION ALL rompe la consulta completa.'
    );
    $loincUnion = "SELECT 1 AS domain UNION ALL\n" . $loincSql;
    $check(
        !preg_match('/UNION ALL\s+WITH\b/i', $loincUnion),
        'LOINC: ninguna WITH puede quedar como operando de UNION ALL.'
    );
    foreach (['_l1', '_l2', '_l3'] as $loincSuffix) {
        $check(isset($loincParams[':p0' . $loincSuffix]), 'LOINC: falta el parámetro :p0' . $loincSuffix . '.');
    }
    $check(
        !str_contains($loincSql, 'SELECT t.loinc FROM loinc t'),
        'LOINC: un término de texto no debe recorrer loinc buscando códigos.'
    );
}
[$loincCodeSql] = $loincBranchMethod->invoke(null, 'p0', '58258-5', 'es-AR', false, null);
$check(
    str_contains($loincCodeSql, 'SELECT t.loinc FROM loinc t'),
    'LOINC: una búsqueda con dígitos sí debe incluir la rama por código.'
);

// UVR publicado sobre códigos de catálogo también debe llegar a Browse Codes.
$legacyPublicSqlPath = $root . '/sql/08_arquitectura/uvr_publicacion_legacy_browse.sql';
$check(is_file($legacyPublicSqlPath), 'Debe existir el SQL que publica UVR legacy hacia Browse Codes.');
$legacyPublicSql = is_file($legacyPublicSqlPath) ? (string) file_get_contents($legacyPublicSqlPath) : '';
$check(
    str_contains($legacyPublicSql, 'CREATE OR REPLACE VIEW public.v_os_uvr_valuation_public')
        && str_contains($legacyPublicSql, "g.review_status = 'published'")
        && str_contains($legacyPublicSql, 'i.permanent_code AS external_code')
        && str_contains($legacyPublicSql, 'money.importe_referencial')
        && !str_contains($legacyPublicSql, 'estimated_payment')
        && !str_contains($legacyPublicSql, 'ALTER DEFAULT PRIVILEGES')
        && str_contains($legacyPublicSql, "c.code <> 'dentar-dx'"),
    'La vista legacy debe exponer solo publicadas, código e importe referencial, sin estimated_payment.'
);
$check(
    str_contains($legacyPublicSql, 'GRANT SELECT ON TABLE public.v_os_uvr_valuation_public TO origen_med')
        && str_contains($legacyPublicSql, 'REVOKE ALL PRIVILEGES ON TABLE public.v_os_uvr_valuation_public FROM PUBLIC'),
    'La vista legacy debe revocar a PUBLIC y conceder solo SELECT a origen_med.'
);
$uvrPublicSource = (string) file_get_contents($root . '/portal/Repositories/UvrPublicRepository.php');
$check(
    str_contains($uvrPublicSource, "private const VIEW_PRESTACION = 'public.v_os_uvr_prestacion_public'")
        && str_contains($uvrPublicSource, "private const VIEW_LEGACY = 'public.v_os_uvr_valuation_public'")
        && str_contains($uvrPublicSource, 'foreach ([self::VIEW_PRESTACION, self::VIEW_LEGACY] as $view)'),
    'Browse debe consultar tanto la vista transversal como la legacy.'
);
$uvrServiceSource = (string) file_get_contents($root . '/portal/Admin/UvrGovernanceService.php');
$check(
    str_contains($uvrServiceSource, 'private function withSubjectCodes(array $rows, string $idField = \'subject_id\')')
        && str_contains($uvrServiceSource, 'CatalogGovernanceRepository::permanentCodes(')
        && str_contains($uvrServiceSource, "return \$this->withSubjectCodes(\$rows, 'valuation_id')"),
    'Los listados y detalles UVR deben resolver el código permanente del asunto.'
);
foreach (['proposals.php', 'proposal.php', 'tasks.php', 'index.php', 'compare.php'] as $uvrView) {
    $check(
        str_contains((string) file_get_contents($root . '/portal/Views/admin/uvr/' . $uvrView), 'subject_code'),
        'La vista del panel ' . $uvrView . ' debe mostrar el código visible.'
    );
}
$check(
    str_contains(
        (string) file_get_contents($root . '/portal/Views/partials/browse/detail/uvr.php'),
        "trim((string) (\$valuation['external_code'] ?? ''))"
    ),
    'La ficha pública debe mostrar el código permanente cuando no hay perfil.'
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
