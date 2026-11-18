<?php

declare(strict_types=1);

require __DIR__ . '/partials/browse/context.php';

$dentarFilter = $catalogs !== [];
$mobileView = $focus !== '' ? 'detail' : 'results';
$catalogOptions = [
    ['code' => 'dentar-pr', 'label' => $t('dentar.pr_badge')],
    ['code' => 'dentar-dx', 'label' => $t('dentar.dx_badge')],
];
$facetSelects = [
    ['key' => 'family', 'label' => 'browse.family', 'options' => $facets['families']],
    ['key' => 'type', 'label' => 'browse.type', 'options' => $facets['types']],
    ['key' => 'category', 'label' => 'browse.category', 'options' => $facets['categories']],
    ['key' => 'version', 'label' => 'browse.version', 'options' => $facets['versions']],
    ['key' => 'status', 'label' => 'browse.status', 'options' => $facets['statuses']],
];
$hasFacetFilters = $filters !== [];
foreach ($facetSelects as $facetSelect) {
    if ($facetSelect['options'] !== []) {
        $hasFacetFilters = true;
        break;
    }
}
?>
<section class="section browse-section">
    <div class="container">
        <span class="eyebrow"><?= e($t('browse.eyebrow')) ?></span>
        <h1><?= e($t('browse.title')) ?></h1>
        <p class="browse-subtitle"><?= e($t('browse.subtitle')) ?></p>
        <p class="lead"><?= e($t('browse.lead')) ?></p>

        <?php if ($dentarFilter): ?>
            <div class="browse-dentar-banner">
                <strong><?= e($t('browse.dentar_badge')) ?></strong>
                <p><?= e($t('browse.dentar_intro', [
                    '%catalog%' => $t('dentar.' . ($catalogs[0] === 'dentar-dx' ? 'dx_badge' : 'pr_badge')),
                ])) ?></p>
                <a class="dentar-text-link" href="<?= e($dentarUrl) ?>"><?= e($t('browse.dentar_back')) ?> →</a>
            </div>
        <?php endif; ?>

        <form class="browse-form" method="get" action="<?= e($baseBrowsePath) ?>">
            <div class="form-grid">
                <div class="field field-full">
                    <label for="browse-q"><?= e($t('browse.search_label')) ?></label>
                    <input id="browse-q" name="q" type="search" maxlength="80"
                           placeholder="<?= e($t('browse.search_placeholder')) ?>"
                           value="<?= e($query) ?>">
                </div>
                <div class="field field-full">
                    <label for="browse-domain"><?= e($t('browse.domain_label')) ?></label>
                    <select id="browse-domain" name="domain">
                        <option value=""><?= e($t('browse.domain_all')) ?></option>
                        <?php foreach ($domains as $option): ?>
                            <option value="<?= e((string) $option['code']) ?>"
                                <?= $domain === (string) $option['code'] ? 'selected' : '' ?>>
                                <?= e((string) $option['label']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <fieldset class="field field-full browse-filter-group">
                    <legend><?= e($t('browse.catalogs')) ?></legend>
                    <div class="browse-check-grid">
                        <?php foreach ($catalogOptions as $option): ?>
                            <?php $isChecked = in_array($option['code'], $catalogs, true); ?>
                            <label class="browse-check">
                                <input type="checkbox" name="catalog[]"
                                       value="<?= e($option['code']) ?>" <?= $isChecked ? 'checked' : '' ?>>
                                <span><?= e($option['label']) ?></span>
                            </label>
                        <?php endforeach; ?>
                    </div>
                </fieldset>
                <?php if ($hasFacetFilters): ?>
                    <fieldset class="field field-full browse-filter-group">
                        <legend><?= e($t('browse.filters')) ?></legend>
                        <div class="browse-filter-grid">
                            <?php foreach ($facetSelects as $facetSelect): ?>
                                <?php if ($facetSelect['options'] === []) { continue; } ?>
                                <div class="field">
                                    <label for="browse-filter-<?= e($facetSelect['key']) ?>">
                                        <?= e($t($facetSelect['label'])) ?>
                                    </label>
                                    <select id="browse-filter-<?= e($facetSelect['key']) ?>"
                                            name="<?= e($facetSelect['key']) ?>">
                                        <option value=""><?= e($t('browse.filter_all')) ?></option>
                                        <?php foreach ($facetSelect['options'] as $option): ?>
                                            <?php $code = (string) ($option['code'] ?? ''); ?>
                                            <?php if ($code === '') { continue; } ?>
                                            <option value="<?= e($code) ?>"
                                                <?= ($filters[$facetSelect['key']] ?? '') === $code ? 'selected' : '' ?>>
                                                <?= e((string) ($option['label'] ?? $code)) ?>
                                            </option>
                                        <?php endforeach; ?>
                                    </select>
                                </div>
                            <?php endforeach; ?>
                            <div class="field">
                                <label for="browse-filter-validity"><?= e($t('browse.validity')) ?></label>
                                <select id="browse-filter-validity" name="validity">
                                    <option value=""><?= e($t('browse.filter_all')) ?></option>
                                    <option value="current"
                                        <?= ($filters['validity'] ?? '') === 'current' ? 'selected' : '' ?>>
                                        <?= e($t('browse.validity_current')) ?>
                                    </option>
                                </select>
                            </div>
                        </div>
                    </fieldset>
                <?php endif; ?>
            </div>
            <button class="button" type="submit"><?= e($t('browse.button')) ?></button>
        </form>

        <p class="form-note"><?= e($t('browse.approved_note')) ?></p>
    </div>
</section>

<section class="section section-alt browse-explorer-section">
    <div class="container browse-explorer-container">
        <div class="browse-explorer"
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
            <div class="browse-explorer__mobile" role="group" aria-label="<?= e($t('browse.detail_title')) ?>">
                <?php foreach (['results', 'detail'] as $view): ?>
                    <?php $isActive = $view === $mobileView; ?>
                    <button type="button"
                            class="browse-mobile-tab<?= $isActive ? ' is-active' : '' ?>"
                            data-mobile-view-target="<?= e($view) ?>"
                            aria-pressed="<?= $isActive ? 'true' : 'false' ?>">
                        <?= e($t('browse.view_' . $view)) ?>
                    </button>
                <?php endforeach; ?>
            </div>

            <div class="browse-explorer__layout">
                <section class="browse-pane browse-pane--results" data-pane="results"
                         aria-label="<?= e($t('browse.results_panel')) ?>">
                    <?php require __DIR__ . '/partials/browse/results.php'; ?>
                </section>
                <section class="browse-pane browse-pane--detail" data-pane="detail" tabindex="-1"
                         aria-label="<?= e($t('browse.detail_panel')) ?>">
                    <?php require __DIR__ . '/partials/browse/detail.php'; ?>
                </section>
            </div>

            <div class="browse-explorer__status" data-live-status role="status" aria-live="polite"></div>
        </div>
    </div>
</section>
