<?php

declare(strict_types=1);

$catalogCode = is_array($item) && isset($item['catalog_code']) ? (string) $item['catalog_code'] : '';
$isDentar = in_array($catalogCode, ['dentar-pr', 'dentar-dx'], true);
$code = is_array($item) ? (string) ($item['code'] ?? '') : '';
$term = is_array($item) ? (string) ($item['term'] ?? '') : '';
$domainLabel = is_array($item) ? (string) ($item['subtitle'] ?? $item['domain'] ?? '') : '';
$uvrPublished = is_array($sections['uvr'] ?? null) ? $sections['uvr'] : [];
?>
<div class="browse-detail" data-focus="<?= e($focus) ?>">
    <div class="browse-panel__crumb">
        <a class="browse-crumb__back" href="<?= e($backUrl) ?>">← <?= e($t('browse.back_results')) ?></a>
        <?php if ($item !== null): ?>
            <span aria-hidden="true">›</span>
            <span><?= e($domainLabel !== '' ? $domainLabel : $t('browse.detail_title')) ?></span>
            <?php if ($code !== ''): ?>
                <span aria-hidden="true">›</span>
                <span class="mono"><?= e($code) ?></span>
            <?php endif; ?>
        <?php endif; ?>
    </div>

    <?php if ($item === null): ?>
        <div class="browse-empty browse-panel__empty">
            <span class="eyebrow"><?= e($t('browse.detail_title')) ?></span>
            <h2><?= e($t('browse.select_result')) ?></h2>
            <p><?= e($t('browse.select_result_hint')) ?></p>
            <?php if (!empty($detail['error'])): ?>
                <div class="alert alert-warning" role="status">
                    <p><?= e($t('browse.' . (string) $detail['error'])) ?></p>
                </div>
            <?php endif; ?>
        </div>
    <?php else: ?>
        <?php if ($isDentar): ?>
            <div class="browse-dentar-banner">
                <strong><?= e($t('browse.dentar_badge')) ?> · <?= e(strtoupper($catalogCode)) ?></strong>
                <p><?= e($t('browse.dentar_detail_note')) ?></p>
                <a class="dentar-text-link" href="<?= e($dentarUrl) ?>"><?= e($t('browse.dentar_back')) ?> →</a>
            </div>
        <?php endif; ?>

        <div class="browse-panel__head">
            <span class="eyebrow"><?= e($t('browse.detail_title')) ?></span>
            <h2 class="browse-detail__title" data-detail-title><?= e($term !== '' ? $term : ($code !== '' ? $code : $focus)) ?></h2>
            <?php if ($code !== ''): ?>
                <span class="browse-detail__code mono"><?= e($code) ?></span>
            <?php endif; ?>
            <?php if ($domainLabel !== ''): ?>
                <p class="browse-panel__intro"><?= e($domainLabel) ?></p>
            <?php endif; ?>
        </div>

        <dl class="browse-facts">
            <?php
            $facts = [
                ['browse.catalog', $item['catalog_code'] ?? null],
                ['browse.domain', $item['domain'] ?? null],
                ['browse.approval_state', $item['approval_state'] ?? null],
                ['browse.concept_type', $item['kind'] ?? null],
                ['browse.concept_id', $item['concept_id'] ?? null],
                ['browse.effective_language', $item['effective_language'] ?? null],
            ];
            ?>
            <?php foreach ($facts as $fact): ?>
                <?php if (!$hasValue($fact[1])) { continue; } ?>
                <div class="browse-fact">
                    <dt><?= e($t($fact[0])) ?></dt>
                    <dd><?= e($formatValue($fact[1])) ?></dd>
                </div>
            <?php endforeach; ?>
        </dl>

        <?php if (!empty($item['fallback_applied']) || !empty($item['untranslated'])): ?>
            <div class="alert alert-warning" role="status">
                <p><?= e($t('browse.translation_notice')) ?></p>
                <?php if (!empty($item['fallback_reason'])): ?>
                    <p class="form-note"><?= e($t('browse.fallback_reason')) ?>: <?= e((string) $item['fallback_reason']) ?></p>
                <?php endif; ?>
            </div>
        <?php endif; ?>

        <div class="browse-detail__tools">
            <?php if ($code !== ''): ?>
                <button type="button" class="button button-small button-ghost"
                        data-copy="<?= e($code) ?>"><?= e($t('browse.copy_code')) ?></button>
            <?php endif; ?>
            <?php if (($item['concept_id'] ?? '') !== ''): ?>
                <button type="button" class="button button-small button-ghost"
                        data-copy="<?= e((string) $item['concept_id']) ?>"><?= e($t('browse.copy_identifier')) ?></button>
            <?php endif; ?>
            <button type="button" class="button button-small button-ghost"
                    data-copy-record><?= e($t('browse.copy_record')) ?></button>
            <button type="button" class="button button-small button-ghost"
                    data-copy="<?= e($stableCurrentUrl) ?>"><?= e($t('browse.copy_link')) ?></button>
            <a class="button button-small button-ghost" href="<?= e($stableCurrentUrl) ?>">
                <?= e($t('browse.stable_link')) ?>
            </a>
            <a class="button button-small button-ghost" href="<?= e($docsUrl) ?>">
                <?= e($t('browse.api_docs')) ?>
            </a>
        </div>

        <p class="browse-scope"><strong><?= e($t('browse.scope_title')) ?></strong> <?= e($t('browse.scope_notice')) ?></p>

        <?php if (count($compareItems) > 1): ?>
            <?php require __DIR__ . '/compare.php'; ?>
        <?php endif; ?>

        <?php if ($historyDisplay !== []): ?>
            <?php require __DIR__ . '/history.php'; ?>
        <?php endif; ?>

        <div class="browse-tabs" role="tablist" aria-label="<?= e($t('browse.detail_title')) ?>">
            <?php foreach ($tabs as $tabKey => $labelKey): ?>
                <?php $isActive = $tabKey === $activeTab; ?>
                <a class="browse-tab<?= $isActive ? ' is-active' : '' ?>"
                   role="tab"
                   id="browse-tab-<?= e($tabKey) ?>"
                   href="<?= e($tabUrl($tabKey)) ?>"
                   data-tab="<?= e($tabKey) ?>"
                   data-url="<?= e($tabFragmentUrl($tabKey)) ?>"
                   data-stable-url="<?= e($tabUrl($tabKey)) ?>"
                   aria-selected="<?= $isActive ? 'true' : 'false' ?>"
                   aria-controls="browse-panel-<?= e($tabKey) ?>"
                   tabindex="<?= $isActive ? '0' : '-1' ?>"><?= e($t($labelKey)) ?></a>
            <?php endforeach; ?>
        </div>

        <div class="browse-panel__scroll">
            <?php foreach ($tabs as $tabKey => $labelKey): ?>
                <?php $isActive = $tabKey === $activeTab; ?>
                <div class="browse-tabpanel"
                     role="tabpanel"
                     id="browse-panel-<?= e($tabKey) ?>"
                     aria-labelledby="browse-tab-<?= e($tabKey) ?>"
                     data-tab-panel="<?= e($tabKey) ?>"
                     <?= $isActive ? '' : 'hidden' ?>>
                    <?php require __DIR__ . '/detail/' . $tabKey . '.php'; ?>
                    <?php if ($tabKey === 'concept'): ?>
                        <div class="browse-clinical">
                            <?php require __DIR__ . '/detail/clinical.php'; ?>
                        </div>
                    <?php endif; ?>
                    <?php if ($tabKey === 'values'): ?>
                        <div class="browse-uvr-note">
                            <p class="form-note"><?= e($t('browse.uvr_formula')) ?></p>
                            <?php if ($uvrPublished !== []): ?>
                                <?php require __DIR__ . '/detail/uvr.php'; ?>
                            <?php elseif (empty($sections['values'])): ?>
                                <p class="browse-empty"><?= e($t('browse.uvr_empty')) ?></p>
                            <?php endif; ?>
                            <p class="browse-scope"><strong><?= e($t('browse.uvr_scope_title')) ?></strong> <?= e($t('browse.uvr_scope_notice')) ?></p>
                        </div>
                    <?php endif; ?>
                </div>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>
