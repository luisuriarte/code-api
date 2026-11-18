<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$result = $result ?? ['ok' => false, 'error' => null, 'items' => [], 'total' => 0, 'page' => 1, 'pages' => 1, 'has_more' => false];
$items = is_array($result['items'] ?? null) ? $result['items'] : [];
$page = (int) ($result['page'] ?? 1);
$pages = (int) ($result['pages'] ?? 1);
$catalog = $catalog ?? null;
$dentarFilter = in_array($catalog, ['dentar-pr', 'dentar-dx'], true);

$queryParams = static function (int $targetPage = 1) use ($query, $domain, $catalog, $apiLocale): array {
    return array_filter([
        'q' => $query,
        'domain' => $domain,
        'catalog' => $catalog,
        'lang' => $apiLocale === 'es-AR' || $apiLocale === 'en' || $apiLocale === 'pt-BR' ? null : $apiLocale,
        'page' => $targetPage > 1 ? $targetPage : null,
    ], static fn ($value) => $value !== '' && $value !== null);
};

$pageUrl = static function (int $targetPage) use ($baseBrowsePath, $queryParams): string {
    $params = $queryParams($targetPage);

    return $baseBrowsePath . ($params === [] ? '' : '?' . http_build_query($params, '', '&', PHP_QUERY_RFC3986));
};

$itemUrl = static function (array $item) use ($locale, $queryParams, $page): string {
    $code = (string) ($item['id'] ?? $item['code'] ?? '');
    $params = $queryParams($page);
    $path = I18n::localizedPath($locale, '/browse/' . rawurlencode($code));

    return $path . ($params === [] ? '' : '?' . http_build_query($params, '', '&', PHP_QUERY_RFC3986));
};
?>
<section class="section">
    <div class="container">
        <span class="eyebrow"><?= e($t('browse.eyebrow')) ?></span>
        <h1><?= e($t('browse.title')) ?></h1>
        <p class="lead"><?= e($t('browse.lead')) ?></p>

        <?php if ($dentarFilter): ?>
            <div class="browse-dentar-banner">
                <strong><?= e($t('browse.dentar_badge')) ?></strong>
                <p><?= e($t('browse.dentar_intro', [
                    '%catalog%' => $t('dentar.' . ($catalog === 'dentar-pr' ? 'pr_badge' : 'dx_badge')),
                ])) ?></p>
                <a class="dentar-text-link" href="<?= e(I18n::localizedPath($locale, '/dentar')) ?>">
                    <?= e($t('browse.dentar_back')) ?> →
                </a>
            </div>
        <?php endif; ?>

        <form class="browse-form" method="get" action="<?= e($baseBrowsePath) ?>">
            <input type="hidden" name="lang" value="<?= e($apiLocale) ?>">
            <div class="form-grid">
                <div class="field field-full">
                    <label for="browse-q"><?= e($t('browse.search_label')) ?></label>
                    <input id="browse-q" name="q" type="search" maxlength="200"
                           placeholder="<?= e($t('browse.search_placeholder')) ?>"
                           value="<?= e($query) ?>">
                </div>
                <div class="field field-full">
                    <label for="browse-domain"><?= e($t('browse.domain_label')) ?></label>
                    <select id="browse-domain" name="domain">
                        <option value=""><?= e($t('browse.domain_all')) ?></option>
                        <?php foreach ($domains as $option): ?>
                            <option value="<?= e($option['code']) ?>" <?= $domain === $option['code'] ? 'selected' : '' ?>>
                                <?= e($option['label']) ?>
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

<section class="section section-alt">
    <div class="container">
        <h2><?= e($t('browse.results_title')) ?></h2>

        <?php if (!$result['ok']): ?>
            <div class="alert alert-warning" role="status">
                <p><?= e($t('browse.' . ($result['error'] ?? 'error_query'))) ?></p>
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
            <p class="results-count">
                <?= e($result['total'] === 1
                    ? $t('browse.result_count_one')
                    : $t('browse.result_count', ['%count%' => $result['total']])) ?>
            </p>

            <ul class="browse-results">
                <?php foreach ($items as $item): ?>
                    <?php
                    $code = (string) ($item['code'] ?? '');
                    $term = (string) ($item['term'] ?? '');
                    $itemDomain = (string) ($item['domain'] ?? '');
                    $effective = (string) ($item['effective_language'] ?? '');
                    $fallback = !empty($item['fallback_applied']);
                    $untranslated = !empty($item['untranslated']);
                    ?>
                    <li class="browse-result">
                        <div class="browse-result-head">
                            <a href="<?= e($itemUrl($item)) ?>"><strong><?= e($term !== '' ? $term : $code) ?></strong></a>
                            <?php if ($code !== ''): ?><span class="code-pill"><?= e($code) ?></span><?php endif; ?>
                        </div>
                        <div class="browse-result-meta">
                            <?php if ($itemDomain !== ''): ?><span><?= e($t('browse.domain')) ?>: <?= e($itemDomain) ?></span><?php endif; ?>
                            <?php if ($effective !== ''): ?><span><?= e($t('browse.effective_language')) ?>: <?= e($effective) ?></span><?php endif; ?>
                            <?php if ($fallback): ?><span class="flag-warn"><?= e($t('browse.fallback_applied')) ?></span><?php endif; ?>
                            <?php if ($untranslated): ?><span class="flag-warn"><?= e($t('browse.untranslated')) ?></span><?php endif; ?>
                        </div>
                    </li>
                <?php endforeach; ?>
            </ul>

            <?php if ($pages > 1): ?>
                <nav class="pagination" aria-label="<?= e($t('browse.results_title')) ?>">
                    <?php if ($page > 1): ?>
                        <a class="button button-small button-ghost" href="<?= e($pageUrl($page - 1)) ?>"><?= e($t('browse.previous')) ?></a>
                    <?php endif; ?>
                    <span><?= e($t('browse.page', ['%page%' => $page, '%total%' => $pages])) ?></span>
                    <?php if ($page < $pages): ?>
                        <a class="button button-small button-ghost" href="<?= e($pageUrl($page + 1)) ?>"><?= e($t('browse.next')) ?></a>
                    <?php endif; ?>
                </nav>
            <?php endif; ?>
        <?php endif; ?>
    </div>
</section>
