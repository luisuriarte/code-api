<?php

declare(strict_types=1);

require __DIR__ . '/partials/browse/context.php';

$mobileView = $focus !== '' ? 'detail' : 'results';

// Catálogos publicados admitidos por el backend: DENTAR y OFTAR.
$publishedCatalogs = [
    ['code' => 'dentar-pr', 'label' => $t('dentar.pr_badge'), 'tag' => 'browse.tag_own', 'families' => ['dentar']],
    ['code' => 'dentar-dx', 'label' => $t('dentar.dx_badge'), 'tag' => 'browse.tag_own', 'families' => ['dentar']],
    ['code' => 'oftar-pr', 'label' => $t('oftar.pr_badge'), 'tag' => 'browse.tag_own', 'families' => ['oftar']],
    ['code' => 'oftar-dx', 'label' => $t('oftar.dx_badge'), 'tag' => 'browse.tag_own', 'families' => ['oftar']],
    // Los tres nomencladores de origen son opciones separadas, con etiqueta
    // explícita, y pertenecen además a la familia de su producto.
    ['code' => 'nomenclador-odontologico-ar', 'label' => $t('dentar.nomenclador_badge'), 'tag' => 'browse.tag_source', 'families' => ['dentar', 'nomenclador']],
    ['code' => 'nomenclador-oftalmologico-cao-ar', 'label' => $t('oftar.cao_badge'), 'tag' => 'browse.tag_source', 'families' => ['oftar', 'nomenclador']],
    ['code' => 'nomenclador-oftalmologico-regional-ar', 'label' => $t('oftar.regional_badge'), 'tag' => 'browse.tag_source', 'families' => ['oftar', 'nomenclador']],
];

// Catálogos en artefactos o propuestos. Ninguno se enlaza como consultable.
$reservedDentar = [
    ['code' => 'DENTAR-AN', 'tag' => 'browse.tag_unpublished'],
    ['code' => 'DENTAR-CL', 'tag' => 'browse.tag_unpublished'],
    ['code' => 'DENTAR-IN', 'tag' => 'browse.tag_proposed'],
    ['code' => 'DENTAR-PD', 'tag' => 'browse.tag_proposed'],
    ['code' => 'DENTAR-EQ', 'tag' => 'browse.tag_proposed'],
];
$reservedOs = [
    ['code' => 'OS-INS', 'tag' => 'browse.tag_proposed'],
    ['code' => 'OS-PROD', 'tag' => 'browse.tag_proposed'],
    ['code' => 'OS-MED', 'tag' => 'browse.tag_proposed'],
    ['code' => 'OS-DIS', 'tag' => 'browse.tag_proposed'],
    ['code' => 'OS-EQP', 'tag' => 'browse.tag_proposed'],
    ['code' => 'OS-IMPL', 'tag' => 'browse.tag_proposed'],
];

$domainLabels = [];
foreach ($domains as $domainOption) {
    $domainLabels[(string) ($domainOption['code'] ?? '')] = (string) ($domainOption['label'] ?? '');
}

$facetGroups = [
    ['key' => 'family', 'label' => 'browse.family', 'options' => $facets['families']],
    ['key' => 'type', 'label' => 'browse.type', 'options' => $facets['types']],
    ['key' => 'category', 'label' => 'browse.category', 'options' => $facets['categories']],
    ['key' => 'version', 'label' => 'browse.version', 'options' => $facets['versions']],
    ['key' => 'status', 'label' => 'browse.status', 'options' => $facets['statuses']],
];
$facetLabels = [];
foreach ($facetGroups as $group) {
    foreach ($group['options'] as $option) {
        $code = (string) ($option['code'] ?? '');
        if ($code !== '') {
            $label = (string) ($option['label'] ?? $code);
            if ($group['key'] === 'family' && $code === 'dentar') {
                $label = $t('browse.family_dentar');
            }
            if ($group['key'] === 'family' && $code === 'oftar') {
                $label = $t('browse.family_oftar');
            }
            $facetLabels[$group['key']][$code] = $label;
        }
    }
}

// La familia activa decide qué opciones se muestran en "Código": sin familia
// se listan dominios (SNOMED, CIE-10, LOINC…); con DENTAR/OFTAR, sus catálogos.
$codeFamily = (string) ($filters['family'] ?? '');
$codeAllSelected = $domainCodes === [] && $catalogs === [];
$activeFilterCount = count($domainCodes) + count($catalogs) + count($filters);

$catalogRemoveUrl = static function (string $code) use ($stateParams, $paramsUrl, $baseBrowsePath, $catalogs): string {
    $remaining = array_values(array_filter(
        $catalogs,
        static fn (string $current): bool => $current !== $code
    ));

    return $paramsUrl($stateParams([
        'catalog' => $remaining === [] ? null : implode(',', $remaining),
        'page' => null,
    ]), $baseBrowsePath);
};

$chips = [];
foreach ($domainCodes as $domainCode) {
    $chips[] = [
        'label' => $t('browse.domain_label') . ': ' . ($domainLabels[$domainCode] ?? $domainCode),
        'url' => $domainRemoveUrl($domainCode),
    ];
}
foreach ($catalogs as $catalogCode) {
    $label = $catalogCode;
    foreach ($publishedCatalogs as $option) {
        if ($option['code'] === $catalogCode) {
            $label = $option['label'];
            break;
        }
    }
    $chips[] = ['label' => $t('browse.catalogs') . ': ' . $label, 'url' => $catalogRemoveUrl($catalogCode)];
}
$facetTitles = [];
foreach ($facetGroups as $group) {
    $facetTitles[$group['key']] = $group['label'];
}
foreach ($filters as $key => $code) {
    $label = $key === 'validity' ? $t('browse.validity') : $t($facetTitles[$key] ?? 'browse.filters');
    $value = $key === 'validity'
        ? $t('browse.validity_current')
        : ($facetLabels[$key][$code] ?? $code);
    $chips[] = ['label' => $label . ': ' . $value, 'url' => $filterUrl($key, null)];
}
?>
<section class="browse-explorer group mt-0 bg-paper/70 py-6 sm:py-8"
         data-browse-explorer
         data-mobile-view="<?= e($mobileView) ?>"
         data-focus="<?= e($focus) ?>"
         data-msg-updated="<?= e($t('browse.updated')) ?>"
         data-msg-compared="<?= e($t('browse.compared')) ?>"
         data-msg-view="<?= e($t('browse.view')) ?>"
         data-msg-restored="<?= e($t('browse.restored')) ?>"
         data-msg-results-updated="<?= e($t('browse.results_updated')) ?>"
         data-msg-copied="<?= e($t('browse.copied')) ?>"
         data-msg-copy-error="<?= e($t('browse.copy_error')) ?>">
    <div class="mx-auto w-full max-w-[1700px] px-4 sm:px-6">
        <header class="mb-6 flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
            <div class="max-w-3xl">
                <span class="inline-flex items-center gap-2 rounded-full bg-mint px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-teal-dark">
                    <span class="size-1.5 rounded-full bg-teal"></span>
                    <?= e($t('browse.head_eyebrow')) ?>
                </span>
                <h1 class="mt-3 text-3xl font-semibold tracking-tight text-ink sm:text-4xl lg:text-5xl">
                    <?= e($t('browse.title')) ?>
                </h1>
                <p class="mt-2 text-base leading-7 text-ink-soft sm:text-lg"><?= e($t('browse.subtitle')) ?></p>
                <p class="mt-1 hidden text-sm text-muted sm:block"><?= e($t('browse.head_lead')) ?></p>
            </div>
            <div class="flex flex-wrap items-center gap-3">
                <div class="rounded-2xl border border-line bg-white px-4 py-2.5 shadow-card">
                    <span class="block text-2xl font-semibold leading-none text-ink"><?= count($publishedCatalogs) ?></span>
                    <span class="mt-1 block text-xs text-muted"><?= e($t('browse.stat_published')) ?></span>
                </div>
                <div class="rounded-2xl border border-line bg-white px-4 py-2.5 shadow-card">
                    <span class="block text-2xl font-semibold leading-none text-ink"><?= count($reservedDentar) + count($reservedOs) ?></span>
                    <span class="mt-1 block text-xs text-muted"><?= e($t('browse.stat_reserved')) ?></span>
                </div>
                <a class="inline-flex items-center gap-1.5 rounded-xl px-3 py-2 text-sm font-semibold text-teal-dark transition hover:bg-mint"
                   href="<?= e($docsUrl) ?>">
                    <?= e($t('browse.api_docs')) ?>
                    <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                        <path d="M5 12h14m-6-6 6 6-6 6"></path>
                    </svg>
                </a>
            </div>
        </header>

        <form class="browse-form" method="get" action="<?= e($baseBrowsePath) ?>"
              data-catalogs="<?= e(implode(',', array_column($publishedCatalogs, 'code'))) ?>"
              data-domains="<?= e(implode(',', array_column($domains, 'code'))) ?>">
            <div class="sticky top-0 z-30 -mx-4 border-y border-line/80 bg-white/85 px-4 py-3 shadow-[0_10px_30px_-24px_rgba(11,34,57,0.5)] backdrop-blur-xl sm:-mx-6 sm:px-6">
                <div class="flex items-center gap-2">
                    <div class="relative min-w-0 flex-1">
                        <svg class="pointer-events-none absolute top-1/2 left-4 size-5 -translate-y-1/2 text-muted"
                             viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                            <circle cx="11" cy="11" r="7"></circle><path d="m20 20-4-4"></path>
                        </svg>
                        <label class="sr-only" for="browse-q"><?= e($t('browse.search_label')) ?></label>
                        <input id="browse-q" name="q" type="search" maxlength="80"
                               autocomplete="off"
                               placeholder="<?= e($t('browse.search_placeholder')) ?>"
                               value="<?= e($query) ?>"
                               class="peer h-13 w-full rounded-2xl border border-line bg-paper/80 pr-20 pl-12 text-base text-ink shadow-sm outline-none transition placeholder:text-muted focus:border-teal focus:bg-white focus:ring-4 focus:ring-teal/15 sm:text-lg">
                        <kbd class="pointer-events-none absolute top-1/2 right-4 hidden -translate-y-1/2 rounded-md border border-line bg-white px-2 py-0.5 font-mono text-[11px] text-muted peer-focus:hidden sm:block">/</kbd>
                    </div>
                    <button type="submit"
                            class="inline-flex h-13 shrink-0 items-center rounded-2xl bg-teal px-4 text-sm font-semibold text-white shadow-sm transition hover:bg-teal-dark focus:outline-none focus:ring-4 focus:ring-teal/25 sm:px-6">
                        <span class="hidden sm:inline"><?= e($t('browse.button')) ?></span>
                        <svg class="size-5 sm:hidden" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                            <path d="m5 12h14m-6-6 6 6-6 6"></path>
                        </svg>
                    </button>
                </div>
                <div class="browse-filter-bar mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
                    <label class="block min-w-0">
                        <span class="block text-[11px] font-semibold uppercase tracking-wider text-muted"><?= e($t('browse.family')) ?></span>
                        <select name="family"
                                class="mt-1 h-10 w-full rounded-xl border border-line bg-white px-3 text-sm text-ink outline-none transition focus:border-teal focus:ring-4 focus:ring-teal/15">
                            <option value=""><?= e($t('browse.filter_all')) ?></option>
                            <?php foreach ($facets['families'] as $option): ?>
                                <?php $code = (string) ($option['code'] ?? ''); ?>
                                <?php if ($code === '') { continue; } ?>
                                <option value="<?= e($code) ?>" <?= ($filters['family'] ?? '') === $code ? 'selected' : '' ?>>
                                    <?= e($facetLabels['family'][$code] ?? ($option['label'] ?? $code)) ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </label>

                    <label class="block min-w-0">
                        <span class="block text-[11px] font-semibold uppercase tracking-wider text-muted"><?= e($t('browse.code')) ?></span>
                        <select id="browse-code" multiple size="4"
                                data-code-select
                                name="<?= $codeFamily === '' ? 'domain[]' : 'catalog[]' ?>"
                                class="browse-code-select mt-1 w-full rounded-xl border border-line bg-white px-3 py-1 text-sm text-ink outline-none transition focus:border-teal focus:ring-4 focus:ring-teal/15">
                                            <option value="__all__" data-code-kind="all" data-code-select-all
                                    <?= $codeAllSelected ? 'selected' : '' ?>>
                                <?= e($t('browse.filter_all')) ?>
                            </option>
                            <?php foreach ($domains as $option): ?>
                                <?php $code = (string) ($option['code'] ?? ''); ?>
                                <?php if ($code === '' || ($codeFamily === '' && $code === 'nomenclador')) { continue; } ?>
                                <option value="<?= e($code) ?>"
                                        data-code-kind="domain"
                                        <?= $codeFamily === '' ? '' : 'hidden disabled' ?>
                                        <?= in_array($code, $domainCodes, true) ? 'selected' : '' ?>>
                                    <?= e((string) ($option['label'] ?? $code)) ?>
                                </option>
                            <?php endforeach; ?>
                            <?php foreach ($publishedCatalogs as $option): ?>
                                <?php $showCatalog = $codeFamily === '' || in_array($codeFamily, $option['families'], true); ?>
                                <option value="<?= e($option['code']) ?>"
                                        data-code-kind="catalog"
                                        data-families="<?= e(implode(',', $option['families'])) ?>"
                                        <?= $showCatalog ? '' : 'hidden disabled' ?>
                                        <?= in_array($option['code'], $catalogs, true) ? 'selected' : '' ?>>
                                    <?= e($option['label']) ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                        <input type="hidden" name="domain" value="<?= e($domain) ?>" data-code-hidden-domain>
                        <input type="hidden" name="catalog" value="<?= e($catalog) ?>" data-code-hidden-catalog>
                        <span class="mt-1 block text-[11px] leading-5 text-muted"><?= e($t('browse.code_multi_hint')) ?></span>
                    </label>

                    <label class="block min-w-0">
                        <span class="block text-[11px] font-semibold uppercase tracking-wider text-muted"><?= e($t('browse.type')) ?></span>
                        <select name="type"
                                class="mt-1 h-10 w-full rounded-xl border border-line bg-white px-3 text-sm text-ink outline-none transition focus:border-teal focus:ring-4 focus:ring-teal/15">
                            <option value=""><?= e($t('browse.filter_all')) ?></option>
                            <?php foreach ($facets['types'] as $option): ?>
                                <?php $code = (string) ($option['code'] ?? ''); ?>
                                <?php if ($code === '') { continue; } ?>
                                <option value="<?= e($code) ?>" <?= ($filters['type'] ?? '') === $code ? 'selected' : '' ?>>
                                    <?= e($facetLabels['type'][$code] ?? ($option['label'] ?? $code)) ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </label>

                    <label class="block min-w-0">
                        <span class="block text-[11px] font-semibold uppercase tracking-wider text-muted"><?= e($t('browse.category')) ?></span>
                        <select name="category"
                                class="mt-1 h-10 w-full rounded-xl border border-line bg-white px-3 text-sm text-ink outline-none transition focus:border-teal focus:ring-4 focus:ring-teal/15">
                            <option value=""><?= e($t('browse.filter_all')) ?></option>
                            <?php foreach ($facets['categories'] as $option): ?>
                                <?php $code = (string) ($option['code'] ?? ''); ?>
                                <?php if ($code === '') { continue; } ?>
                                <option value="<?= e($code) ?>" <?= ($filters['category'] ?? '') === $code ? 'selected' : '' ?>>
                                    <?= e($facetLabels['category'][$code] ?? ($option['label'] ?? $code)) ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                </div>

                <?php foreach (['status', 'version', 'validity'] as $hiddenFilter): ?>
                    <?php if (($filters[$hiddenFilter] ?? '') !== ''): ?>
                        <input type="hidden" name="<?= e($hiddenFilter) ?>" value="<?= e($filters[$hiddenFilter]) ?>">
                    <?php endif; ?>
                <?php endforeach; ?>

                <?php if ($chips !== []): ?>
                    <div class="mt-3 flex flex-wrap items-center gap-2">
                        <span class="text-[11px] font-semibold uppercase tracking-wider text-muted"><?= e($t('browse.active_filters')) ?></span>
                        <?php foreach ($chips as $chip): ?>
                            <a href="<?= e($chip['url']) ?>"
                               class="inline-flex items-center gap-1.5 rounded-full border border-teal/25 bg-mint px-3 py-1 text-xs font-medium text-teal-dark transition hover:border-teal hover:bg-white">
                                 <?= e($chip['label']) ?>
                                 <svg class="size-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
                                     <path d="M18 6 6 18M6 6l12 12"></path>
                                 </svg>
                            </a>
                        <?php endforeach; ?>
                        <a href="<?= e($clearFiltersUrl()) ?>"
                           class="ml-1 text-xs font-semibold text-muted underline decoration-dotted underline-offset-4 transition hover:text-teal-dark">
                            <?= e($t('browse.reset_filters')) ?>
                        </a>
                    </div>
                <?php endif; ?>

                <div class="mt-2 flex flex-wrap items-center justify-between gap-2">
                    <p class="text-[11px] text-muted"><?= e($t('browse.explore_hint')) ?></p>
                    <a href="<?= e($clearFiltersUrl()) ?>"
                       class="text-xs font-semibold text-muted underline decoration-dotted underline-offset-4 transition hover:text-teal-dark">
                        <?= e($t('browse.reset_filters')) ?>
                    </a>
                </div>
            </div>
        </form>

        <div class="mt-5 flex gap-2 lg:hidden" role="group" aria-label="<?= e($t('browse.detail_title')) ?>">
            <?php foreach (['results', 'detail'] as $view): ?>
                <?php $isActive = $view === $mobileView; ?>
                <button type="button"
                        data-mobile-view-target="<?= e($view) ?>"
                        aria-pressed="<?= $isActive ? 'true' : 'false' ?>"
                        class="flex-1 rounded-xl border px-4 py-2.5 text-sm font-semibold transition <?= $isActive ? 'border-teal bg-teal text-white' : 'border-line bg-white text-ink-soft' ?> [&.is-active]:border-teal [&.is-active]:bg-teal [&.is-active]:text-white">
                    <?= e($t('browse.view_' . $view)) ?>
                </button>
            <?php endforeach; ?>
        </div>

        <div class="mt-5 grid items-start gap-5 lg:grid-cols-[minmax(0,1.15fr)_minmax(0,0.85fr)] xl:grid-cols-[minmax(0,1.25fr)_minmax(0,0.75fr)]">
            <section class="min-w-0 max-lg:group-data-[mobile-view=detail]:hidden"
                     data-pane="results"
                     aria-label="<?= e($t('browse.results_panel')) ?>">
                <div class="rounded-3xl border border-line bg-white p-4 shadow-card sm:p-5">
                    <?php require __DIR__ . '/partials/browse/results.php'; ?>
                </div>
            </section>

            <section class="min-w-0 rounded-3xl border border-line bg-white p-4 shadow-card sm:p-5 lg:sticky lg:top-24 lg:max-h-[calc(100dvh-7.5rem)] lg:overflow-y-auto max-lg:group-data-[mobile-view=results]:hidden"
                     data-pane="detail"
                     tabindex="-1"
                     aria-label="<?= e($t('browse.detail_panel')) ?>">
                <?php require __DIR__ . '/partials/browse/detail.php'; ?>
            </section>
        </div>

        <div class="mt-4 min-h-5 text-xs text-muted" data-live-status role="status" aria-live="polite"></div>
    </div>
</section>
