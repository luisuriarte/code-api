<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\BrowseService;
use OrigenSalud\Web\I18n;

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

$tabLabels = [
    'concept' => 'browse.tab_concept',
    'relations' => 'browse.tab_relations',
    'values' => 'browse.tab_values',
    'validity' => 'browse.tab_validity',
    'clinical' => 'browse.tab_clinical',
    'trace' => 'browse.tab_trace',
];

$hasClinical = false;
foreach (['definition', 'clinical_criteria', 'short_definition', 'lay_terms', 'clinical_scope'] as $clinicalField) {
    if ($hasValue($sections['clinical'][$clinicalField] ?? null)) {
        $hasClinical = true;
        break;
    }
}

$hasTrace = false;
foreach ($sections['trace'] ?? [] as $traceValue) {
    if ($hasValue($traceValue)) {
        $hasTrace = true;
        break;
    }
}

$tabs = ['concept' => $tabLabels['concept']];
if (!empty($sections['relations'])) {
    $tabs['relations'] = $tabLabels['relations'];
}
if (!empty($sections['values'])) {
    $tabs['values'] = $tabLabels['values'];
}
if (!empty($sections['validity'])) {
    $tabs['validity'] = $tabLabels['validity'];
}
if ($hasClinical) {
    $tabs['clinical'] = $tabLabels['clinical'];
}
if ($hasTrace) {
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
];
$relationRoleLabels = [
    'procedure_concept' => 'browse.role_procedure_concept',
    'justifying_diagnosis' => 'browse.role_justifying_diagnosis',
    'observation_concept' => 'browse.role_observation_concept',
    'substance_concept' => 'browse.role_substance_concept',
];
$reviewLabels = [
    'approved' => 'browse.review_approved',
    'draft' => 'browse.review_draft',
    'reviewed' => 'browse.review_reviewed',
    'deprecated' => 'browse.review_deprecated',
];
$pendingReviews = ['draft', 'reviewed'];

$relationTypeLabel = static function (string $type) use ($t, $relationTypeLabels): string {
    return isset($relationTypeLabels[$type]) ? $t($relationTypeLabels[$type]) : $t('browse.relation_neutral');
};
$relationRoleLabel = static function (string $role) use ($t, $relationRoleLabels): string {
    return isset($relationRoleLabels[$role]) ? $t($relationRoleLabels[$role]) : $t('browse.role_neutral');
};
$reviewLabel = static function (string $status) use ($t, $reviewLabels): string {
    return isset($reviewLabels[$status]) ? $t($reviewLabels[$status]) : $status;
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
