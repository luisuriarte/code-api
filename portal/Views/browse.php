<?php

declare(strict_types=1);

require __DIR__ . '/partials/browse/context.php';

$mobileView = $focus !== '' ? 'detail' : 'results';

// Catálogos publicados admitidos por el backend: DENTAR y OFTAR.
$publishedCatalogs = [
    ['code' => 'dentar-pr', 'label' => $t('dentar.pr_badge'), 'tag' => 'browse.tag_own'],
    ['code' => 'dentar-dx', 'label' => $t('dentar.dx_badge'), 'tag' => 'browse.tag_own'],
    ['code' => 'nomenclador-odontologico-ar', 'label' => $t('dentar.nomenclador_badge'), 'tag' => 'browse.tag_source'],
    ['code' => 'oftar-pr', 'label' => $t('oftar.pr_badge'), 'tag' => 'browse.tag_own'],
    ['code' => 'oftar-dx', 'label' => $t('oftar.dx_badge'), 'tag' => 'browse.tag_own'],
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

$activeFilterCount = ($domain !== '' ? 1 : 0) + count($catalogs) + count($filters);

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
if ($domain !== '') {
    $chips[] = [
        'label' => $t('browse.domain_label') . ': ' . ($domainLabels[$domain] ?? $domain),
        'url' => $domainUrl(''),
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
              data-catalogs="<?= e(implode(',', array_column($publishedCatalogs, 'code'))) ?>">
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
                    <button type="button"
                            popovertarget="browse-filters"
                            aria-label="<?= e($t('browse.filters')) ?>"
                            class="relative inline-flex h-13 shrink-0 items-center gap-2 rounded-2xl border border-line bg-white px-3 text-sm font-semibold text-ink shadow-sm transition hover:border-teal hover:text-teal-dark focus:outline-none focus:ring-4 focus:ring-teal/15 sm:px-4">
                        <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                            <path d="M4 6h16M7 12h10m-7 6h4"></path>
                        </svg>
                        <span class="hidden sm:inline"><?= e($t('browse.filters')) ?></span>
                        <?php if ($activeFilterCount > 0): ?>
                            <span class="grid size-5 place-items-center rounded-full bg-teal text-[11px] font-bold text-white">
                                <?= $activeFilterCount ?>
                            </span>
                        <?php endif; ?>
                    </button>
                    <button type="submit"
                            class="inline-flex h-13 shrink-0 items-center rounded-2xl bg-teal px-4 text-sm font-semibold text-white shadow-sm transition hover:bg-teal-dark focus:outline-none focus:ring-4 focus:ring-teal/25 sm:px-6">
                        <span class="hidden sm:inline"><?= e($t('browse.button')) ?></span>
                        <svg class="size-5 sm:hidden" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                            <path d="m5 12h14m-6-6 6 6-6 6"></path>
                        </svg>
                    </button>
                </div>
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
            </div>

            <div id="browse-filters"
                 popover="auto"
                 aria-label="<?= e($t('browse.filters')) ?>"
                 class="browse-filter-drawer m-0 inset-y-0 start-auto end-0 h-dvh w-[min(30rem,100vw)] max-w-full translate-x-full rounded-none border-l border-line bg-white p-0 text-ink opacity-0 shadow-panel open:translate-x-0 open:opacity-100 backdrop:bg-ink/40 backdrop:backdrop-blur-sm">
                <div class="flex h-full flex-col">
                    <div class="flex items-start justify-between gap-4 border-b border-line px-5 py-4">
                        <div>
                            <h2 class="text-lg font-semibold tracking-tight"><?= e($t('browse.filters')) ?></h2>
                            <p class="mt-0.5 text-xs text-muted"><?= e($t('browse.explore_hint')) ?></p>
                        </div>
                        <button type="button"
                                popovertarget="browse-filters"
                                popovertargetaction="hide"
                                aria-label="<?= e($t('browse.close_filters')) ?>"
                                class="grid size-9 shrink-0 place-items-center rounded-xl border border-line text-muted transition hover:border-teal hover:text-teal-dark focus:outline-none focus:ring-4 focus:ring-teal/15">
                            <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                                <path d="M18 6 6 18M6 6l12 12"></path>
                            </svg>
                        </button>
                    </div>

                    <div class="min-h-0 flex-1 space-y-6 overflow-y-auto px-5 py-5">
                        <fieldset class="space-y-2">
                            <legend class="mb-2 text-xs font-semibold uppercase tracking-wider text-muted"><?= e($t('browse.domain_label')) ?></legend>
                            <label class="flex cursor-pointer items-center gap-3 rounded-xl border border-line px-3 py-2.5 text-sm transition has-checked:border-teal has-checked:bg-mint has-checked:text-teal-dark hover:border-teal/60">
                                <input class="peer sr-only" type="radio" name="domain" value="" <?= $domain === '' ? 'checked' : '' ?>>
                                <span class="grid size-4 shrink-0 place-items-center rounded-full border border-line peer-checked:border-teal peer-checked:bg-teal"></span>
                                <span class="font-medium"><?= e($t('browse.domain_all')) ?></span>
                            </label>
                            <?php foreach ($domains as $option): ?>
                                <?php $code = (string) ($option['code'] ?? ''); ?>
                                <?php if ($code === '') { continue; } ?>
                                <label class="flex cursor-pointer items-center gap-3 rounded-xl border border-line px-3 py-2.5 text-sm transition has-checked:border-teal has-checked:bg-mint has-checked:text-teal-dark hover:border-teal/60">
                                    <input class="peer sr-only" type="radio" name="domain" value="<?= e($code) ?>" <?= $domain === $code ? 'checked' : '' ?>>
                                    <span class="grid size-4 shrink-0 place-items-center rounded-full border border-line peer-checked:border-teal peer-checked:bg-teal"></span>
                                    <span class="min-w-0 flex-1 truncate font-medium"><?= e((string) ($option['label'] ?? $code)) ?></span>
                                    <code class="text-[11px] text-muted"><?= e($code) ?></code>
                                </label>
                            <?php endforeach; ?>
                        </fieldset>

                        <fieldset class="space-y-2">
                            <legend class="mb-2 text-xs font-semibold uppercase tracking-wider text-muted"><?= e($t('browse.catalogs')) ?></legend>
                            <?php foreach ($publishedCatalogs as $option): ?>
                                <?php $isChecked = in_array($option['code'], $catalogs, true); ?>
                                <label class="flex cursor-pointer items-center gap-3 rounded-xl border border-line px-3 py-2.5 text-sm transition has-checked:border-teal has-checked:bg-mint has-checked:text-teal-dark hover:border-teal/60">
                                    <input class="peer sr-only" type="checkbox" name="catalog[]" value="<?= e($option['code']) ?>" <?= $isChecked ? 'checked' : '' ?>>
                                    <span class="grid size-4 shrink-0 place-items-center rounded-md border border-line text-white peer-checked:border-teal peer-checked:bg-teal">
                                        <svg class="size-3 opacity-0 peer-checked:opacity-100" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" aria-hidden="true">
                                            <path d="m5 13 4 4L19 7"></path>
                                        </svg>
                                    </span>
                                    <span class="min-w-0 flex-1 truncate font-medium"><?= e($option['label']) ?></span>
                                    <span class="rounded-full bg-paper px-2 py-0.5 text-[10px] font-semibold text-muted"><?= e($t($option['tag'])) ?></span>
                                </label>
                            <?php endforeach; ?>
                            <p class="pt-1 text-[11px] leading-5 text-muted"><?= e($t('browse.reserved_note')) ?></p>
                        </fieldset>

                        <?php foreach ($facetGroups as $group): ?>
                            <?php if (count($group['options']) < 2) { continue; } ?>
                            <fieldset class="space-y-2">
                                <legend class="mb-2 text-xs font-semibold uppercase tracking-wider text-muted"><?= e($t($group['label'])) ?></legend>
                                <label class="flex cursor-pointer items-center gap-3 rounded-xl border border-line px-3 py-2 text-sm transition has-checked:border-teal has-checked:bg-mint has-checked:text-teal-dark hover:border-teal/60">
                                    <input class="peer sr-only" type="radio" name="<?= e($group['key']) ?>" value="" <?= ($filters[$group['key']] ?? '') === '' ? 'checked' : '' ?>>
                                    <span class="grid size-4 shrink-0 place-items-center rounded-full border border-line peer-checked:border-teal peer-checked:bg-teal"></span>
                                    <span class="font-medium"><?= e($t('browse.filter_all')) ?></span>
                                </label>
                                <?php foreach ($group['options'] as $option): ?>
                                    <?php
                                    $code = (string) ($option['code'] ?? '');
                                    if ($code === '') { continue; }
                                    ?>
                                    <label class="flex cursor-pointer items-center gap-3 rounded-xl border border-line px-3 py-2 text-sm transition has-checked:border-teal has-checked:bg-mint has-checked:text-teal-dark hover:border-teal/60">
                                        <input class="peer sr-only" type="radio" name="<?= e($group['key']) ?>" value="<?= e($code) ?>" <?= ($filters[$group['key']] ?? '') === $code ? 'checked' : '' ?>>
                                        <span class="grid size-4 shrink-0 place-items-center rounded-full border border-line peer-checked:border-teal peer-checked:bg-teal"></span>
                                        <span class="min-w-0 flex-1 truncate"><?= e((string) ($option['label'] ?? $code)) ?></span>
                                    </label>
                                <?php endforeach; ?>
                            </fieldset>
                        <?php endforeach; ?>

                        <fieldset class="space-y-2">
                            <legend class="mb-2 text-xs font-semibold uppercase tracking-wider text-muted"><?= e($t('browse.validity')) ?></legend>
                            <label class="flex cursor-pointer items-center gap-3 rounded-xl border border-line px-3 py-2.5 text-sm transition has-checked:border-teal has-checked:bg-mint has-checked:text-teal-dark hover:border-teal/60">
                                <input class="peer sr-only" type="radio" name="validity" value="" <?= ($filters['validity'] ?? '') === '' ? 'checked' : '' ?>>
                                <span class="grid size-4 shrink-0 place-items-center rounded-full border border-line peer-checked:border-teal peer-checked:bg-teal"></span>
                                <span class="font-medium"><?= e($t('browse.validity_all')) ?></span>
                            </label>
                            <label class="flex cursor-pointer items-center gap-3 rounded-xl border border-line px-3 py-2.5 text-sm transition has-checked:border-teal has-checked:bg-mint has-checked:text-teal-dark hover:border-teal/60">
                                <input class="peer sr-only" type="radio" name="validity" value="current" <?= ($filters['validity'] ?? '') === 'current' ? 'checked' : '' ?>>
                                <span class="grid size-4 shrink-0 place-items-center rounded-full border border-line peer-checked:border-teal peer-checked:bg-teal"></span>
                                <span class="font-medium"><?= e($t('browse.validity_current')) ?></span>
                            </label>
                        </fieldset>
                    </div>

                    <div class="flex items-center justify-between gap-3 border-t border-line bg-paper/70 px-5 py-4">
                        <a href="<?= e($clearFiltersUrl()) ?>"
                           class="text-sm font-semibold text-muted underline decoration-dotted underline-offset-4 transition hover:text-teal-dark">
                            <?= e($t('browse.reset_filters')) ?>
                        </a>
                        <button type="submit"
                                class="inline-flex items-center gap-2 rounded-xl bg-teal px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-teal-dark focus:outline-none focus:ring-4 focus:ring-teal/25">
                            <?= e($t('browse.button')) ?>
                            <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                                <path d="M5 12h14m-6-6 6 6-6 6"></path>
                            </svg>
                        </button>
                    </div>
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
