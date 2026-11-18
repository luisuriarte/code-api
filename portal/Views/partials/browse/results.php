<?php

declare(strict_types=1);

$items = is_array($result['items'] ?? null) ? $result['items'] : [];
$page = (int) ($result['page'] ?? 1);
$pages = max(1, (int) ($result['pages'] ?? 1));
$hasMore = !empty($result['has_more']);
$error = is_string($result['error'] ?? null) ? (string) $result['error'] : '';
$countLabel = $result['total'] === 1
    ? $t('browse.result_count_one')
    : $t('browse.result_count', ['%count%' => $result['total']]);
?>
<div class="browse-results-panel">
    <div class="browse-pane-head browse-results-panel__head">
        <h2><?= e($t('browse.results_title')) ?></h2>
        <?php if ($result['ok'] && $items !== []): ?>
            <span class="results-count"><?= e($countLabel) ?></span>
        <?php endif; ?>
    </div>

    <p class="browse-results-panel__state" data-results-state>
        <?php if (!$result['ok']): ?>
            <?= e($t('browse.' . ($error !== '' ? $error : 'error_query'))) ?>
        <?php elseif ($query === ''): ?>
            <?= e($t('browse.empty_query')) ?>
        <?php else: ?>
            <?= e($t('browse.state_query', ['%query%' => $query])) ?>
        <?php endif; ?>
    </p>

    <?php if (!$result['ok'] || $query === '' || $items === []): ?>
        <div class="browse-empty" role="status">
            <p><?= e(!$result['ok']
                ? $t('browse.' . ($error !== '' ? $error : 'error_query'))
                : ($query === '' ? $t('browse.empty_query') : $t('browse.no_results'))) ?></p>
        </div>
    <?php else: ?>
        <ul class="browse-results browse-results--explorer browse-result-list">
            <?php foreach ($items as $entry): ?>
                <?php
                $key = (string) ($entry['id'] ?? '');
                if ($key === '') {
                    continue;
                }
                $code = (string) ($entry['code'] ?? '');
                $term = (string) ($entry['term'] ?? '');
                $itemDomain = (string) ($entry['domain'] ?? '');
                $catalogCode = (string) ($entry['catalog_code'] ?? '');
                $kind = (string) ($entry['kind'] ?? '');
                $effective = (string) ($entry['effective_language'] ?? '');
                $selected = $key === $selectedKey;
                $href = $stableItemUrl($key);
                $focusHref = $fragmentUrl($key);
                $compareHref = $compareUrl($key);
                $matchType = (string) ($entry['match_type'] ?? '');
                $relationCount = max(0, (int) ($entry['relation_count'] ?? 0));
                ?>
                <li class="browse-result browse-result--selectable browse-result-row<?= $selected ? ' is-selected' : '' ?>"
                    data-result-key="<?= e($key) ?>">
                    <a class="browse-result-link browse-result-row__link<?= $selected ? ' is-selected' : '' ?>"
                       href="<?= e($href) ?>"
                       data-focus-url="<?= e($focusHref) ?>"
                       data-result-key="<?= e($key) ?>"
                       <?= $selected ? 'aria-current="true"' : '' ?>>
                        <span class="browse-result-row__top">
                            <span class="browse-result-row__code"><?= e($code) ?></span>
                            <span class="browse-result-row__term"><?= e($term !== '' ? $term : $code) ?></span>
                        </span>
                        <span class="browse-result-row__meta">
                            <?php if ($catalogCode !== ''): ?>
                                <span class="browse-badge browse-badge--current"><?= e($catalogCode) ?></span>
                            <?php elseif ($itemDomain !== ''): ?>
                                <span class="browse-badge"><?= e($itemDomain) ?></span>
                            <?php endif; ?>
                            <?php if ($kind !== ''): ?>
                                <span class="browse-badge browse-badge--neutral"><?= e($kind) ?></span>
                            <?php endif; ?>
                            <?php if ($matchType === 'exact' || $matchType === 'partial'): ?>
                                <span class="browse-badge <?= $matchType === 'exact' ? 'browse-badge--current' : 'browse-badge--neutral' ?>">
                                    <?= e($t('browse.match_' . $matchType)) ?>
                                </span>
                            <?php endif; ?>
                            <?php if ($relationCount > 0): ?>
                                <span class="browse-badge browse-badge--neutral">
                                    <?= e($relationCount === 1
                                        ? $t('browse.relations_count_one')
                                        : $t('browse.relations_count', ['%count%' => $relationCount])) ?>
                                </span>
                            <?php endif; ?>
                            <?php if ($effective !== ''): ?>
                                <span><?= e($effective) ?></span>
                            <?php endif; ?>
                            <?php if (!empty($entry['status'])): ?>
                                <span><?= e((string) $entry['status']) ?></span>
                            <?php endif; ?>
                            <?php if (!empty($entry['fallback_applied'])): ?>
                                <span class="flag-warn"><?= e($t('browse.fallback_applied')) ?></span>
                            <?php endif; ?>
                            <?php if (!empty($entry['untranslated'])): ?>
                                <span class="flag-warn"><?= e($t('browse.untranslated')) ?></span>
                            <?php endif; ?>
                        </span>
                    </a>
                    <div class="browse-result-actions">
                        <a class="button button-small button-ghost browse-compare-link"
                           href="<?= e($compareHref) ?>"
                           data-compare-url="<?= e($compareHref) ?>"
                           data-compare-key="<?= e($key) ?>">
                            <?= e($t('browse.compare_add')) ?>
                        </a>
                    </div>
                </li>
            <?php endforeach; ?>
        </ul>

        <div class="browse-results-foot">
            <?php if ($pages > 1): ?>
                <span><?= e($t('browse.page', ['%page%' => $page, '%total%' => $pages])) ?></span>
                <nav class="browse-pagination" aria-label="<?= e($t('browse.results_title')) ?>">
                    <?php if ($page > 1): ?>
                        <a class="button button-small button-ghost" href="<?= e($pageUrl($page - 1)) ?>">
                            <?= e($t('browse.previous')) ?>
                        </a>
                    <?php endif; ?>
                    <?php if ($hasMore): ?>
                        <a class="button button-small button-ghost"
                           href="<?= e($pageUrl($page + 1)) ?>"
                           data-load-more
                           data-load-more-url="<?= e($resultsFragmentUrl($page + 1)) ?>">
                            <?= e($t('browse.load_more')) ?>
                        </a>
                    <?php endif; ?>
                </nav>
            <?php endif; ?>
        </div>
    <?php endif; ?>
</div>
