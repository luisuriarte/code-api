<?php

declare(strict_types=1);

require __DIR__ . '/partials/browse/context.php';

$dentarFilter = in_array($catalog, ['dentar-pr', 'dentar-dx'], true);
$mobileView = $focus !== '' ? 'detail' : 'results';
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
                    '%catalog%' => $t('dentar.' . ($catalog === 'dentar-pr' ? 'pr_badge' : 'dx_badge')),
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
                <div class="field field-full">
                    <label for="browse-catalog"><?= e($t('browse.catalog')) ?></label>
                    <select id="browse-catalog" name="catalog">
                        <option value=""><?= e($t('browse.catalog_all')) ?></option>
                        <option value="dentar-pr" <?= $catalog === 'dentar-pr' ? 'selected' : '' ?>>
                            <?= e($t('dentar.pr_badge')) ?>
                        </option>
                        <option value="dentar-dx" <?= $catalog === 'dentar-dx' ? 'selected' : '' ?>>
                            <?= e($t('dentar.dx_badge')) ?>
                        </option>
                    </select>
                </div>
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
