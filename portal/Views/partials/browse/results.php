<?php

declare(strict_types=1);

$items = is_array($result['items'] ?? null) ? $result['items'] : [];
$page = (int) ($result['page'] ?? 1);
$pages = max(1, (int) ($result['pages'] ?? 1));
$error = is_string($result['error'] ?? null) ? (string) $result['error'] : '';
?>
<div class="browse-results-panel">
    <div class="browse-pane-head">
        <h2><?= e($t('browse.results_panel')) ?></h2>
        <?php if ($result['ok'] && $items !== []): ?>
            <span class="results-count">
                <?= e($result['total'] === 1
                    ? $t('browse.result_count_one')
                    : $t('browse.result_count', ['%count%' => $result['total']])) ?>
            </span>
        <?php endif; ?>
    </div>

    <?php if (!$result['ok']): ?>
        <div class="alert alert-warning" role="status">
            <p><?= e($t('browse.' . ($error !== '' ? $error : 'error_query'))) ?></p>
        </div>
    <?php elseif ($query === ''): ?>
        <div class="alert alert-warning" role="status">
            <p><?= e($t('browse.empty_query')) ?></p>
        </div>
    <?php elseif ($items === []): ?>
        <div class="alert alert-warning" role="status">
            <p><?= e($t('browse.no_results')) ?></p>
        </div>
    <?php else: ?>
        <ul class="browse-results browse-results--explorer">
            <?php foreach ($items as $entry): ?>
                <?php
                $key = (string) ($entry['id'] ?? '');
                if ($key === '') {
                    continue;
                }
                $code = (string) ($entry['code'] ?? '');
                $term = (string) ($entry['term'] ?? '');
                $itemDomain = (string) ($entry['domain'] ?? '');
                $effective = (string) ($entry['effective_language'] ?? '');
                $selected = $key === $selectedKey;
                $href = $stableItemUrl($key);
                $focusHref = $fragmentUrl($key);
                $compareHref = $compareUrl($key);
                ?>
                <li class="browse-result browse-result--selectable<?= $selected ? ' is-selected' : '' ?>"
                    data-result-key="<?= e($key) ?>">
                    <a class="browse-result-link<?= $selected ? ' is-selected' : '' ?>"
                       href="<?= e($href) ?>"
                       data-focus-url="<?= e($focusHref) ?>"
                       data-result-key="<?= e($key) ?>"
                       <?= $selected ? 'aria-current="true"' : '' ?>>
                        <span class="browse-result-head">
                            <strong><?= e($term !== '' ? $term : $code) ?></strong>
                            <?php if ($code !== ''): ?>
                                <span class="code-pill"><?= e($code) ?></span>
                            <?php endif; ?>
                        </span>
                        <span class="browse-result-meta">
                            <?php if ($itemDomain !== ''): ?>
                                <span><?= e($t('browse.domain')) ?>: <?= e($itemDomain) ?></span>
                            <?php endif; ?>
                            <?php if ($effective !== ''): ?>
                                <span><?= e($t('browse.effective_language')) ?>: <?= e($effective) ?></span>
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

        <?php if ($pages > 1): ?>
            <nav class="pagination" aria-label="<?= e($t('browse.results_title')) ?>">
                <?php if ($page > 1): ?>
                    <a class="button button-small button-ghost" href="<?= e($pageUrl($page - 1)) ?>">
                        <?= e($t('browse.previous')) ?>
                    </a>
                <?php endif; ?>
                <span><?= e($t('browse.page', ['%page%' => $page, '%total%' => $pages])) ?></span>
                <?php if ($page < $pages): ?>
                    <a class="button button-small button-ghost" href="<?= e($pageUrl($page + 1)) ?>">
                        <?= e($t('browse.next')) ?>
                    </a>
                <?php endif; ?>
            </nav>
        <?php endif; ?>
    <?php endif; ?>
</div>
