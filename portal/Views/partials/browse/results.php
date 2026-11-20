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
    <div class="mb-4 flex flex-wrap items-center justify-between gap-2 border-b border-line pb-3 browse-results-panel__head">
        <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('browse.results_title')) ?></h2>
        <?php if ($result['ok'] && $items !== []): ?>
            <span class="rounded-full bg-mint px-3 py-1 text-xs font-semibold text-teal-dark results-count"><?= e($countLabel) ?></span>
        <?php endif; ?>
    </div>

    <p class="mb-4 text-sm text-muted browse-results-panel__state" data-results-state>
        <?php if (!$result['ok']): ?>
            <?= e($t('browse.' . ($error !== '' ? $error : 'error_query'))) ?>
        <?php elseif ($query === ''): ?>
            <?= e($t('browse.empty_query')) ?>
        <?php else: ?>
            <?= e($t('browse.state_query', ['%query%' => $query])) ?>
        <?php endif; ?>
    </p>

    <?php if (!$result['ok'] || $query === '' || $items === []): ?>
        <div class="rounded-2xl border border-dashed border-line bg-paper px-4 py-10 text-center" role="status">
            <svg class="mx-auto size-8 text-muted/70" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
                <circle cx="11" cy="11" r="7"></circle><path d="m20 20-4-4"></path>
            </svg>
            <p class="mt-3 text-sm font-medium text-ink-soft">
                <?= e(!$result['ok']
                    ? $t('browse.' . ($error !== '' ? $error : 'error_query'))
                    : ($query === '' ? $t('browse.empty_query') : $t('browse.no_results'))) ?>
            </p>
        </div>
    <?php else: ?>
        <ul class="browse-results browse-results--explorer browse-result-list grid list-none gap-3 p-0 @container sm:grid-cols-2">
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
                $officialSystem = (string) ($entry['official_system'] ?? '');
                $officialCode = (string) ($entry['official_code'] ?? '');
                $officialLabel = $officialCode !== ''
                    ? ($officialSystem !== ''
                        ? $identifierSystemLabel($officialSystem) . ': ' . $officialCode
                        : $officialCode)
                    : '';
                ?>
                <li class="browse-result browse-result--selectable browse-result-row group min-w-0 border-0 bg-transparent p-0 shadow-none"
                    data-result-key="<?= e($key) ?>">
                    <div class="flex h-full flex-col rounded-2xl border p-4 transition <?= $selected ? 'border-teal bg-mint/70 shadow-card' : 'border-line bg-white hover:border-teal/60 hover:shadow-card' ?>">
                        <a class="browse-result-link browse-result-row__link block min-w-0 flex-1 border-0 bg-transparent p-0 no-underline hover:bg-transparent"
                           href="<?= e($href) ?>"
                           data-focus-url="<?= e($focusHref) ?>"
                           data-result-key="<?= e($key) ?>"
                           <?= $selected ? 'aria-current="true"' : '' ?>>
                            <span class="flex items-start justify-between gap-3">
                                <span class="browse-result-row__code min-w-0 break-words font-mono text-sm font-semibold text-teal-dark">
                                    <?= e($code) ?>
                                </span>
                                <?php if ($matchType === 'exact'): ?>
                                    <span class="shrink-0 rounded-full bg-teal px-2 py-0.5 text-[10px] font-bold text-white">
                                        <?= e($t('browse.match_exact')) ?>
                                    </span>
                                <?php elseif ($matchType === 'partial'): ?>
                                    <span class="shrink-0 rounded-full bg-paper px-2 py-0.5 text-[10px] font-semibold text-muted">
                                        <?= e($t('browse.match_partial')) ?>
                                    </span>
                                <?php endif; ?>
                            </span>
                            <span class="browse-result-row__term mt-2 block overflow-visible text-sm leading-6 font-medium whitespace-normal text-ink group-hover:text-teal-dark">
                                <?= e($term !== '' ? $term : $code) ?>
                            </span>
                            <span class="browse-result-row__meta mt-3 flex flex-wrap items-center gap-1.5 text-[11px] text-muted">
                                <?php if ($catalogCode !== ''): ?>
                                    <span class="rounded-full bg-mint px-2 py-0.5 font-semibold text-teal-dark"><?= e($catalogCode) ?></span>
                                <?php elseif ($itemDomain !== ''): ?>
                                    <span class="rounded-full bg-paper px-2 py-0.5 font-semibold text-ink-soft"><?= e($itemDomain) ?></span>
                                <?php endif; ?>
                                <?php if ($kind !== ''): ?>
                                    <span class="rounded-full bg-paper px-2 py-0.5"><?= e($kind) ?></span>
                                <?php endif; ?>
                                <?php if ($officialLabel !== ''): ?>
                                    <span class="rounded-full bg-paper px-2 py-0.5"><?= e($officialLabel) ?></span>
                                <?php endif; ?>
                                <?php if ($relationCount > 0): ?>
                                    <span class="rounded-full bg-paper px-2 py-0.5">
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
                                    <span class="font-semibold text-amber-700"><?= e($t('browse.fallback_applied')) ?></span>
                                <?php endif; ?>
                                <?php if (!empty($entry['untranslated'])): ?>
                                    <span class="font-semibold text-amber-700"><?= e($t('browse.untranslated')) ?></span>
                                <?php endif; ?>
                            </span>
                        </a>
                        <div class="browse-result-actions mx-0 mt-3 mb-0 border-t border-line pt-3">
                            <a class="browse-compare-link inline-flex items-center gap-1.5 rounded-lg px-2 py-1 text-xs font-semibold text-muted no-underline transition hover:bg-paper hover:text-teal-dark"
                               href="<?= e($compareHref) ?>"
                               data-compare-url="<?= e($compareHref) ?>"
                               data-compare-key="<?= e($key) ?>">
                                <svg class="size-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                                    <path d="M9 11l3 3L22 4"></path><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"></path>
                                </svg>
                                <?= e($t('browse.compare_add')) ?>
                            </a>
                        </div>
                    </div>
                </li>
            <?php endforeach; ?>
        </ul>

        <div class="browse-results-foot mt-4 flex flex-wrap items-center justify-between gap-3 border-t border-line px-0 pt-4 pb-0 text-xs text-muted">
            <?php if ($pages > 1): ?>
                <span><?= e($t('browse.page', ['%page%' => $page, '%total%' => $pages])) ?></span>
                <nav class="flex flex-wrap gap-2" aria-label="<?= e($t('browse.results_title')) ?>">
                    <?php if ($page > 1): ?>
                        <a class="inline-flex items-center rounded-xl border border-line bg-white px-3 py-1.5 font-semibold text-ink-soft no-underline transition hover:border-teal hover:text-teal-dark"
                           href="<?= e($pageUrl($page - 1)) ?>">
                            <?= e($t('browse.previous')) ?>
                        </a>
                    <?php endif; ?>
                    <?php if ($hasMore): ?>
                        <a class="inline-flex items-center rounded-xl bg-teal px-3 py-1.5 font-semibold text-white no-underline transition hover:bg-teal-dark"
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
