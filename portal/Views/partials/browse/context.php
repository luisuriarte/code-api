<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\BrowseService;
use OrigenSalud\Web\I18n;

require __DIR__ . '/../format.php';

$state = is_array($state ?? null) ? $state : [];
$focus = is_string($focus ?? null) ? $focus : '';
$tab = is_string($tab ?? null) && $tab !== '' ? $tab : 'concept';
$relView = is_string($relView ?? null) && $relView !== '' ? $relView : 'table';
$selectedKey = $focus;
$baseBrowsePath = is_string($baseBrowsePath ?? null) && $baseBrowsePath !== ''
    ? $baseBrowsePath
    : I18n::localizedPath($locale, '/browse');
$result = is_array($result ?? null) ? $result : [
    'ok' => false,
    'error' => null,
    'items' => [],
    'total' => 0,
    'page' => 1,
    'pages' => 1,
    'has_more' => false,
];
$detail = is_array($detail ?? null) ? $detail : [
    'ok' => false,
    'error' => null,
    'item' => null,
    'sections' => [],
];
$item = is_array($detail['item'] ?? null) ? $detail['item'] : null;
$sections = is_array($detail['sections'] ?? null) ? $detail['sections'] : [];
$compareItems = is_array($compareItems ?? null) ? $compareItems : [];
$historyKeys = is_array($historyKeys ?? null) ? $historyKeys : [];
$catalog = is_string($catalog ?? null) ? $catalog : '';
$catalogs = is_array($catalogs ?? null)
    ? BrowseService::normalizeCatalogs(implode(',', array_map('strval', $catalogs)))
    : BrowseService::normalizeCatalogs($catalog);
$domainCodes = is_array($domainCodes ?? null)
    ? BrowseService::normalizeDomains(implode(',', array_map('strval', $domainCodes)))
    : BrowseService::normalizeDomains($domain ?? '');
$filters = is_array($filters ?? null) ? BrowseService::normalizeFilters($filters) : [];
$facets = is_array($facets ?? null) ? $facets : [];
foreach (['families', 'types', 'categories', 'versions', 'statuses'] as $facetKey) {
    if (!isset($facets[$facetKey]) || !is_array($facets[$facetKey])) {
        $facets[$facetKey] = [];
    }
}
$query = is_string($query ?? null) ? $query : '';
$domains = is_array($domains ?? null) ? $domains : [];

$hasValue = static function (mixed $value) use (&$hasValue): bool {
    if (is_array($value)) {
        foreach ($value as $child) {
            if ($hasValue($child)) {
                return true;
            }
        }

        return false;
    }

    return $value !== null && $value !== '' && $value !== false;
};

$formatValue = static function (mixed $value): string {
    if (is_bool($value)) {
        return $value ? 'true' : 'false';
    }
    if (is_array($value)) {
        return implode(', ', array_map('strval', $value));
    }

    return is_scalar($value) ? (string) $value : '';
};

$paramsUrl = static function (array $params, string $path) use ($baseBrowsePath): string {
    $params = array_filter($params, static fn ($value) => $value !== null && $value !== '');

    return $path . ($params === [] ? '' : '?' . http_build_query($params, '', '&', PHP_QUERY_RFC3986));
};

$stateParams = static function (array $overrides = [], array $remove = []) use ($state): array {
    $params = $state;
    foreach ($remove as $key) {
        unset($params[$key]);
    }
    foreach ($overrides as $key => $value) {
        if ($value === null || $value === '') {
            unset($params[$key]);
        } else {
            $params[$key] = $value;
        }
    }

    return array_filter($params, static fn ($value) => $value !== null && $value !== '');
};

$pageUrl = static function (int $target) use ($stateParams, $paramsUrl, $baseBrowsePath): string {
    return $paramsUrl($stateParams(['page' => $target > 1 ? $target : null]), $baseBrowsePath);
};

$filterUrl = static function (string $key, ?string $value) use ($stateParams, $paramsUrl, $baseBrowsePath): string {
    return $paramsUrl($stateParams([$key => $value, 'page' => null]), $baseBrowsePath);
};

$resultsFragmentUrl = static function (int $target) use ($stateParams, $paramsUrl, $baseBrowsePath): string {
    $params = $stateParams(['page' => $target > 1 ? $target : null], ['fragment']);
    $params['fragment'] = 'results';

    return $paramsUrl($params, $baseBrowsePath);
};

$stableItemUrl = static function (string $key, array $overrides = []) use ($stateParams, $paramsUrl, $locale): string {
    $path = I18n::localizedPath($locale, '/browse/' . rawurlencode($key));

    return $paramsUrl($stateParams($overrides), $path);
};

$fragmentUrl = static function (string $key, array $overrides = []) use ($stateParams, $paramsUrl, $baseBrowsePath): string {
    $params = $stateParams($overrides, ['fragment']);
    $params['fragment'] = 'detail';
    $params['focus'] = $key;

    return $paramsUrl($params, $baseBrowsePath);
};

$tabUrl = static function (string $key) use ($focus, $stableItemUrl): string {
    return $focus !== '' ? $stableItemUrl($focus, ['tab' => $key]) : '';
};

$tabFragmentUrl = static function (string $key) use ($focus, $fragmentUrl): string {
    return $focus !== '' ? $fragmentUrl($focus, ['tab' => $key]) : '';
};

$relViewUrl = static function (string $view) use ($focus, $stableItemUrl): string {
    return $focus !== '' ? $stableItemUrl($focus, ['rel_view' => $view]) : '';
};

$relViewFragmentUrl = static function (string $view) use ($focus, $fragmentUrl): string {
    return $focus !== '' ? $fragmentUrl($focus, ['rel_view' => $view]) : '';
};

$compareUrl = static function (string $key) use ($state, $stableItemUrl, $focus): string {
    $raw = is_string($state['compare'] ?? null) ? $state['compare'] : '';
    $keys = $raw !== '' ? array_values(array_filter(explode(',', $raw), 'strlen')) : [];
    if ($focus !== '' && !in_array($focus, $keys, true)) {
        array_unshift($keys, $focus);
    }
    if (!in_array($key, $keys, true)) {
        $keys[] = $key;
    }
    $keys = array_slice($keys, 0, BrowseService::MAX_COMPARE);

    return $stableItemUrl($key, ['compare' => implode(',', $keys)]);
};

$removeCompareUrl = static function (string $key) use ($state, $stableItemUrl, $focus): string {
    $raw = is_string($state['compare'] ?? null) ? $state['compare'] : '';
    $keys = $raw !== '' ? array_values(array_filter(explode(',', $raw), 'strlen')) : [];
    $keys = array_values(array_filter($keys, static fn ($value) => $value !== $key));

    return $focus !== '' ? $stableItemUrl($focus, ['compare' => $keys === [] ? null : implode(',', $keys)]) : '';
};

$stableCurrentUrl = $focus !== ''
    ? $stableItemUrl($focus)
    : $paramsUrl($stateParams(), $baseBrowsePath);

// El selector de dominios es navegable sin JS y conserva el resto del contexto.
$domainUrl = static function (string $code) use ($stateParams, $paramsUrl, $baseBrowsePath): string {
    $overrides = ['domain' => $code !== '' ? $code : null, 'page' => null, 'focus' => null];
    if ($code !== '' && !in_array($code, ['odontologia', 'oftar'], true)) {
        // El backend solo admite filtro de catálogo en odontología y OFTAR.
        $overrides['catalog'] = null;
    }

    return $paramsUrl($stateParams($overrides), $baseBrowsePath);
};

// Quita un dominio de la selección múltiple y conserva el resto del contexto.
$domainRemoveUrl = static function (string $code) use ($stateParams, $paramsUrl, $baseBrowsePath, $domainCodes): string {
    $remaining = array_values(array_filter(
        $domainCodes,
        static fn (string $current): bool => $current !== $code
    ));

    return $paramsUrl($stateParams([
        'domain' => $remaining === [] ? null : implode(',', $remaining),
        'page' => null,
    ]), $baseBrowsePath);
};

$clearFiltersUrl = static function () use ($stateParams, $paramsUrl, $baseBrowsePath): string {
    $params = $stateParams();
    foreach (['q', 'domain', 'catalog', 'family', 'type', 'category', 'status', 'version', 'validity', 'page'] as $key) {
        unset($params[$key]);
    }

    return $paramsUrl($params, $baseBrowsePath);
};

// Cinco pestañas consolidadas. Las claves de URL se conservan por compatibilidad;
// `clinical` (pestaña retirada) se resuelve ahora dentro de Concepto.
$tabLabels = [
    'concept' => 'browse.tab_concept',
    'relations' => 'browse.tab_relations',
    'values' => 'browse.tab_values',
    'validity' => 'browse.tab_versions',
    'trace' => 'browse.tab_trace_sources',
];
$legacyTabs = ['clinical' => 'concept'];
if (isset($legacyTabs[$tab])) {
    $tab = $legacyTabs[$tab];
}

$relationsByClass = is_array($sections['relations_by_class'] ?? null)
    ? $sections['relations_by_class']
    : ['clinical' => [], 'terminological' => []];
$hasClassifiedRelations = !empty($relationsByClass['clinical'])
    || !empty($relationsByClass['terminological']);
$tabs = ['concept' => $tabLabels['concept']];
if (!empty($sections['relations']) || $hasClassifiedRelations) {
    $tabs['relations'] = $tabLabels['relations'];
}
// La valoración UVR publicada vive en esta pestaña: aunque `values` esté
// vacío, la pestaña debe existir para que la tabla UVR sea alcanzable.
$uvrPublishedForTabs = is_array($sections['uvr'] ?? null) ? $sections['uvr'] : [];
if (!empty($sections['values']) || $uvrPublishedForTabs !== []) {
    $tabs['values'] = $tabLabels['values'];
}
if (!empty($sections['validity'])) {
    $tabs['validity'] = $tabLabels['validity'];
}
if (!empty($sections['trace'])) {
    $tabs['trace'] = $tabLabels['trace'];
}
if (!array_key_exists($tab, $tabs)) {
    $tab = array_key_first($tabs) ?? 'concept';
}
$activeTab = $tab;

$relationTypeLabels = [
    'equivalent' => 'browse.relation_equivalent',
    'narrower' => 'browse.relation_narrower',
    'broader' => 'browse.relation_broader',
    'related' => 'browse.relation_related',
    'unmatched' => 'browse.relation_unmatched',
    // Tipos literales de CDT-2025, conservados por os_catalog_relation.
    'alternate_benefit' => 'browse.relation_alternate_benefit',
    'billed_in_conjunction_with' => 'browse.relation_billed_in_conjunction_with',
    'concurrent_to' => 'browse.relation_concurrent_to',
    'denied_as_integral' => 'browse.relation_denied_as_integral',
    'frequency_limitations' => 'browse.relation_frequency_limitations',
    'integral_to' => 'browse.relation_integral_to',
    'interchangeable_with' => 'browse.relation_interchangeable_with',
    'not_paid_separately' => 'browse.relation_not_paid_separately',
    'not_to_be_used_with' => 'browse.relation_not_to_be_used_with',
    'paid_as_code' => 'browse.relation_paid_as_code',
    'procedure_code_not_used_for' => 'browse.relation_procedure_code_not_used_for',
    'refer_to_details' => 'browse.relation_refer_to_details',
    'referencia_literal' => 'browse.relation_referencia_literal',
    'shares_frequency_limitation_with' => 'browse.relation_shares_frequency_limitation_with',
    'used_in_combination_with' => 'browse.relation_used_in_combination_with',
];
$relationRoleLabels = [
    'procedure_concept' => 'browse.role_procedure_concept',
    'justifying_diagnosis' => 'browse.role_justifying_diagnosis',
    'observation_concept' => 'browse.role_observation_concept',
    'substance_concept' => 'browse.role_substance_concept',
    'outgoing' => 'browse.role_outgoing',
    'incoming' => 'browse.role_incoming',
];
$reviewLabels = [
    'approved' => 'browse.review_approved',
    'draft' => 'browse.review_draft',
    'reviewed' => 'browse.review_reviewed',
    'deprecated' => 'browse.review_deprecated',
];
$pendingReviews = ['draft', 'reviewed'];

$relationTypeLabel = static function (string $type) use ($t, $relationTypeLabels): string {
    return isset($relationTypeLabels[$type])
        ? $t($relationTypeLabels[$type])
        : str_replace('_', ' ', $type);
};
$relationRoleLabel = static function (string $role) use ($t, $relationRoleLabels): string {
    return isset($relationRoleLabels[$role])
        ? $t($relationRoleLabels[$role])
        : str_replace('_', ' ', $role);
};
$reviewLabel = static function (string $status) use ($t, $reviewLabels): string {
    return isset($reviewLabels[$status]) ? $t($reviewLabels[$status]) : $status;
};
$relationClassLabels = [
    'clinical' => 'browse.relation_class_clinical',
    'terminological' => 'browse.relation_class_terminological',
];
$relationClassLabel = static function (string $class) use ($t, $relationClassLabels): string {
    return isset($relationClassLabels[$class])
        ? $t($relationClassLabels[$class])
        : $class;
};

// Etiquetas de sistemas de identificadores. El valor crudo de la base nunca
// se traduce como terminología clínica: solo se muestra con su nombre público.
$identifierSystemLabels = [
    'NOMENCLADOR_AR' => 'browse.identifier_system_nomenclador',
    'NOMENCLADOR-AR' => 'browse.identifier_system_nomenclador',
    'CIE-10' => 'browse.identifier_system_cie10',
    'CDT-2025' => 'browse.identifier_system_cdt',
    'SNOMED-CT' => 'browse.identifier_system_snomed',
    'DENTAR-PR' => 'browse.identifier_system_dentar_pr',
    'dentar-pr' => 'browse.identifier_system_dentar_pr',
    'dentar-dx' => 'browse.identifier_system_dentar_dx',
    'nomenclador-odontologico-ar' => 'browse.identifier_system_nomenclador',
    'OFTAR-PR' => 'browse.identifier_system_oftar_pr',
    'oftar-pr' => 'browse.identifier_system_oftar_pr',
    'OFTAR-DX' => 'browse.identifier_system_oftar_dx',
    'oftar-dx' => 'browse.identifier_system_oftar_dx',
    'NOMENCLADOR_CAO_AR' => 'browse.identifier_system_cao',
    'NOMENCLADOR-CAO-AR' => 'browse.identifier_system_cao',
    'nomenclador-oftalmologico-cao-ar' => 'browse.identifier_system_cao',
    'NOMENCLADOR_OFTAL_REG_AR' => 'browse.identifier_system_oftal_reg',
    'NOMENCLADOR-OFTAL-REG-AR' => 'browse.identifier_system_oftal_reg',
    'nomenclador-oftalmologico-regional-ar' => 'browse.identifier_system_oftal_reg',
];
$identifierSystemLabel = static function (string $system) use ($t, $identifierSystemLabels): string {
    return isset($identifierSystemLabels[$system]) ? $t($identifierSystemLabels[$system]) : $system;
};

$sourceAttributeLabels = [
    'factura' => 'browse.source_attribute_factura',
    'ficha_odontolog' => 'browse.source_attribute_ficha_odontolog',
    'ficha_periodontal' => 'browse.source_attribute_ficha_periodontal',
    'pieza' => 'browse.source_attribute_pieza',
    'caras' => 'browse.source_attribute_caras',
    'rx_pre' => 'browse.source_attribute_rx_pre',
    'rx_post' => 'browse.source_attribute_rx_post',
    'material' => 'browse.source_attribute_material',
    'maxilar' => 'browse.source_attribute_maxilar',
    'agrupamiento' => 'browse.source_attribute_agrupamiento',
];
$sourceAttributeLabel = static function (array $attribute) use ($t, $sourceAttributeLabels): string {
    $code = (string) ($attribute['code'] ?? '');

    return isset($sourceAttributeLabels[$code])
        ? $t($sourceAttributeLabels[$code])
        : ((string) ($attribute['label'] ?? $code));
};

$isCurrentValidity = static function (array $row): bool {
    if (($row['release_status'] ?? '') !== 'published') {
        return false;
    }
    $today = gmdate('Y-m-d');
    $from = $row['release_valid_from'] ?? null;
    $to = $row['release_valid_to'] ?? null;

    return ($from === null || (string) $from <= $today) && ($to === null || (string) $to >= $today);
};

$compareFields = [
    ['label' => 'browse.code', 'key' => 'code'],
    ['label' => 'browse.term', 'key' => 'term'],
    ['label' => 'browse.domain', 'key' => 'domain'],
    ['label' => 'browse.catalog', 'key' => 'catalog_code'],
    ['label' => 'browse.catalog_name', 'key' => 'subtitle'],
    ['label' => 'browse.concept_type', 'key' => 'kind'],
    ['label' => 'browse.description', 'key' => 'description'],
    ['label' => 'browse.effective_language', 'key' => 'effective_language'],
    ['label' => 'browse.approval_state', 'key' => 'approval_state'],
    ['label' => 'browse.provenance', 'key' => 'provenance'],
    ['label' => 'browse.concept_id', 'key' => 'concept_id'],
];

$historyDisplay = $historyKeys;
if ($focus !== '' && !in_array($focus, $historyDisplay, true)) {
    $historyDisplay[] = $focus;
}

$dentarUrl = I18n::localizedPath($locale, '/dentar');
$docsUrl = I18n::localizedPath($locale, '/docs');
