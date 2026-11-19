<?php

declare(strict_types=1);

require __DIR__ . '/partials/browse/context.php';

$mobileView = $focus !== '' ? 'detail' : 'results';

// Catálogos DENTAR publicados: único filtro de producto admitido por el backend.
$publishedCatalogs = [
    ['code' => 'dentar-pr', 'label' => $t('dentar.pr_badge'), 'tag' => 'browse.tag_own'],
    ['code' => 'dentar-dx', 'label' => $t('dentar.dx_badge'), 'tag' => 'browse.tag_own'],
    ['code' => 'nomenclador-odontologico-ar', 'label' => $t('dentar.nomenclador_badge'), 'tag' => 'browse.tag_source'],
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
$reservedCatalogs = array_merge($reservedDentar, $reservedOs);

// Agrupación por naturaleza del dato. Las etiquetas de dominio vienen del
// repositorio; este mapa solo define familia y etiqueta de procedencia.
$domainGroups = [
    ['label' => 'browse.group_own', 'tag' => 'browse.tag_own', 'codes' => ['odontologia']],
    ['label' => 'browse.group_clinical', 'tag' => 'browse.tag_standard', 'codes' => ['snomed', 'loinc']],
    ['label' => 'browse.group_classification', 'tag' => 'browse.tag_standard', 'codes' => ['cie10']],
    ['label' => 'browse.group_national', 'tag' => 'browse.tag_national', 'codes' => ['anmat', 'nomenclador']],
    ['label' => 'browse.group_laboratory', 'tag' => 'browse.tag_national', 'codes' => ['laboratorio', 'imagenes', 'vacunas']],
    ['label' => 'browse.group_services', 'tag' => 'browse.tag_national', 'codes' => ['prestaciones', 'programas', 'vademecum']],
];
$domainLabels = [];
foreach ($domains as $domainOption) {
    $domainLabels[(string) ($domainOption['code'] ?? '')] = (string) ($domainOption['label'] ?? '');
}

$facetSelects = [
    ['key' => 'family', 'label' => 'browse.family', 'options' => $facets['families']],
    ['key' => 'type', 'label' => 'browse.type', 'options' => $facets['types']],
    ['key' => 'category', 'label' => 'browse.category', 'options' => $facets['categories']],
    ['key' => 'version', 'label' => 'browse.version', 'options' => $facets['versions']],
    ['key' => 'status', 'label' => 'browse.status', 'options' => $facets['statuses']],
];
?>
<section class="section browse-section browse-page-head">
    <div class="container browse-page-head__inner">
        <div>
            <span class="eyebrow"><?= e($t('browse.head_eyebrow')) ?></span>
            <h1><?= e($t('browse.title')) ?></h1>
            <p class="browse-subtitle"><?= e($t('browse.subtitle')) ?></p>
            <p class="lead browse-page-head__lead"><?= e($t('browse.head_lead')) ?></p>
            <?php if ($catalogs !== []): ?>
                <div class="browse-dentar-banner">
                    <strong><?= e($t('browse.dentar_badge')) ?></strong>
                    <p><?= e($t('browse.dentar_intro', [
                        '%catalog%' => $t(match ($catalogs[0]) {
                            'dentar-dx' => 'dentar.dx_badge',
                            'nomenclador-odontologico-ar' => 'dentar.nomenclador_badge',
                            default => 'dentar.pr_badge',
                        }),
                    ])) ?></p>
                    <a class="dentar-text-link" href="<?= e($dentarUrl) ?>"><?= e($t('browse.dentar_back')) ?> →</a>
                </div>
            <?php endif; ?>
        </div>
        <div class="browse-page-head__meta">
            <div class="browse-page-stat">
                <strong><?= count($publishedCatalogs) ?></strong>
                <span><?= e($t('browse.stat_published')) ?></span>
            </div>
            <div class="browse-page-stat">
                <strong><?= count($reservedCatalogs) ?></strong>
                <span><?= e($t('browse.stat_reserved')) ?></span>
            </div>
            <div class="browse-page-head__links">
                <a href="#browse-catalogs"><?= e($t('browse.explore_title')) ?> →</a>
                <a href="<?= e($docsUrl) ?>"><?= e($t('browse.api_docs')) ?> →</a>
            </div>
        </div>
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
                <section class="browse-pane browse-pane--results browse-rail"
                         aria-label="<?= e($t('browse.explore_title')) ?>">
                    <form class="browse-form browse-rail-form" method="get" action="<?= e($baseBrowsePath) ?>"
                          data-catalogs="<?= e(implode(',', array_column($publishedCatalogs, 'code'))) ?>">
                        <div class="browse-rail__head">
                            <h2><?= e($t('browse.explore_title')) ?></h2>
                            <p><?= e($t('browse.explore_hint')) ?></p>
                            <div class="browse-search__row">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                                    <circle cx="11" cy="11" r="7"></circle><path d="m20 20-4-4"></path>
                                </svg>
                                <label class="sr-only" for="browse-q"><?= e($t('browse.search_label')) ?></label>
                                <input id="browse-q" name="q" type="search" maxlength="80"
                                       autocomplete="off"
                                       placeholder="<?= e($t('browse.search_placeholder')) ?>"
                                       value="<?= e($query) ?>">
                                <button class="button button-small" type="submit"><?= e($t('browse.button')) ?></button>
                            </div>
                            <p class="browse-search__hint"><?= e($t('browse.search_hint')) ?></p>
                        </div>

                        <div class="browse-rail__scroll">
                            <div class="browse-catalogs" id="browse-catalogs">
                                <div class="browse-catalogs__title"><?= e($t('browse.catalogs')) ?></div>
                                <a class="browse-cat browse-cat--all<?= $domain === '' ? ' is-active' : '' ?>"
                                   href="<?= e($domainUrl('')) ?>"
                                   data-domain-url="<?= e($domainUrl('')) ?>"
                                   data-domain-code=""
                                   <?= $domain === '' ? 'aria-current="true"' : '' ?>>
                                    <span class="browse-cat__name"><?= e($t('browse.domain_all')) ?></span>
                                </a>
                                <?php foreach ($domainGroups as $group): ?>
                                    <?php
                                    $groupCodes = array_values(array_filter(
                                        $group['codes'],
                                        static fn (string $code): bool => isset($domainLabels[$code])
                                    ));
                                    $isOwnGroup = $group['label'] === 'browse.group_own';
                                    if ($groupCodes === [] && !$isOwnGroup) {
                                        continue;
                                    }
                                    ?>
                                    <div class="browse-cat-group">
                                        <div class="browse-cat-group__title">
                                            <span><?= e($t($group['label'])) ?></span>
                                        </div>
                                        <?php foreach ($groupCodes as $code): ?>
                                            <a class="browse-cat<?= $domain === $code ? ' is-active' : '' ?>"
                                               href="<?= e($domainUrl($code)) ?>"
                                               data-domain-url="<?= e($domainUrl($code)) ?>"
                                               data-domain-code="<?= e($code) ?>"
                                               <?= $domain === $code ? 'aria-current="true"' : '' ?>>
                                                <span class="browse-cat__code"><?= e($code) ?></span>
                                                <span class="browse-cat__name"><?= e($domainLabels[$code]) ?></span>
                                                <span class="browse-cat__tag"><?= e($t($group['tag'])) ?></span>
                                            </a>
                                        <?php endforeach; ?>

                                        <?php if ($isOwnGroup): ?>
                                            <?php foreach ($publishedCatalogs as $option): ?>
                                                <?php $isChecked = in_array($option['code'], $catalogs, true); ?>
                                                <label class="browse-cat browse-cat--check<?= $isChecked ? ' is-active' : '' ?>">
                                                    <input type="checkbox" name="catalog[]"
                                                           value="<?= e($option['code']) ?>" <?= $isChecked ? 'checked' : '' ?>>
                                                    <span class="browse-cat__code"><?= e(strtoupper($option['code'])) ?></span>
                                                    <span class="browse-cat__name"><?= e($option['label']) ?></span>
                                                    <span class="browse-cat__tag browse-cat__tag--<?= $option['tag'] === 'browse.tag_source' ? 'source' : 'own' ?>"><?= e($t($option['tag'])) ?></span>
                                                </label>
                                            <?php endforeach; ?>
                                            <?php foreach ($reservedDentar as $option): ?>
                                                <span class="browse-cat browse-cat--proposed" aria-disabled="true">
                                                    <span class="browse-cat__code"><?= e($option['code']) ?></span>
                                                    <span class="browse-cat__tag browse-cat__tag--warn"><?= e($t($option['tag'])) ?></span>
                                                </span>
                                            <?php endforeach; ?>
                                        <?php endif; ?>
                                    </div>
                                <?php endforeach; ?>

                                <div class="browse-cat-group">
                                    <div class="browse-cat-group__title">
                                        <span><?= e($t('browse.group_reserved')) ?></span>
                                    </div>
                                    <?php foreach ($reservedOs as $option): ?>
                                        <span class="browse-cat browse-cat--proposed" aria-disabled="true">
                                            <span class="browse-cat__code"><?= e($option['code']) ?></span>
                                            <span class="browse-cat__tag browse-cat__tag--warn"><?= e($t($option['tag'])) ?></span>
                                        </span>
                                    <?php endforeach; ?>
                                    <p class="browse-catalogs__note"><?= e($t('browse.reserved_note')) ?></p>
                                </div>
                            </div>

                            <fieldset class="browse-filter-group browse-filters">
                                <legend><?= e($t('browse.filters')) ?></legend>
                                <div class="browse-filters__grid">
                                    <div class="field">
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
                                            <option value=""><?= e($t('browse.validity_all')) ?></option>
                                            <option value="current"
                                                <?= ($filters['validity'] ?? '') === 'current' ? 'selected' : '' ?>>
                                                <?= e($t('browse.validity_current')) ?>
                                            </option>
                                        </select>
                                    </div>
                                </div>
                                <div class="browse-filters__actions">
                                    <button class="button button-small" type="submit"><?= e($t('browse.button')) ?></button>
                                    <a class="browse-reset-link" href="<?= e($clearFiltersUrl()) ?>"><?= e($t('browse.reset_filters')) ?></a>
                                </div>
                                <p class="browse-filters__note"><?= e($t('browse.approved_note')) ?></p>
                            </fieldset>

                            <div class="browse-results-shell" data-pane="results"
                                 aria-label="<?= e($t('browse.results_panel')) ?>">
                                <?php require __DIR__ . '/partials/browse/results.php'; ?>
                            </div>
                        </div>
                    </form>
                </section>

                <section class="browse-pane browse-pane--detail browse-panel" data-pane="detail" tabindex="-1"
                         aria-label="<?= e($t('browse.detail_panel')) ?>">
                    <?php require __DIR__ . '/partials/browse/detail.php'; ?>
                </section>
            </div>

            <div class="browse-explorer__status" data-live-status role="status" aria-live="polite"></div>
        </div>
    </div>
</section>
