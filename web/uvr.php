<?php

declare(strict_types=1);

/**
 * Origen Salud - Metodología UVR / Sistema de Valoración Prestacional.
 *
 * Página independiente, trilingüe y de solo lectura. Describe la propuesta
 * metodológica documentada en README-UVR.md. No expone valores cargados,
 * índices publicados ni endpoints de la API pública.
 */

require_once dirname(__DIR__) . '/bootstrap.php';
require_once dirname(__DIR__) . '/portal/i18n/I18n.php';

use OrigenSalud\Web\I18n;

$locale = I18n::boot();

header('Content-Type: text/html; charset=UTF-8');
header('Vary: Accept-Language, Cookie');
header('Content-Language: ' . $locale);

$t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
$esc = static fn (string $value): string => e($value);
$raw = static fn (string $value): string => htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

$baseUrl = rtrim((string) env('WEB_BASE_URL', 'https://med.origen.ar'), '/');
if ($baseUrl === '') {
    $baseUrl = 'https://med.origen.ar';
}

$canonical = $baseUrl . '/uvr?lang=' . rawurlencode($locale);
$metadata = I18n::metadata($locale);
$year = date('Y');

$alternates = [];
foreach (I18n::SUPPORTED as $supported) {
    $info = I18n::metadata($supported);
    $suffix = $supported === 'es-AR' ? 'es' : ($supported === 'pt-BR' ? 'pt' : 'en');
    $alternates[] = [
        'hreflang' => $info['hreflang'],
        'href' => $baseUrl . '/uvr?lang=' . rawurlencode($supported),
        'short' => $info['short'],
        'label' => $t('uvr.lang.' . $suffix),
        'active' => $supported === $locale,
    ];
}

$homePath = I18n::localizedPath($locale, '/');
$docsPath = '/docs?lang=' . rawurlencode($locale);
$contactPath = I18n::localizedPath($locale, '/contact');
$accessMailto = 'mailto:contacto@origen.ar?subject=' . rawurlencode($t('nav.access_api'));
$contactMailto = 'mailto:contacto@origen.ar';
$legalMailto = 'mailto:legal@origen.ar?subject=' . rawurlencode($t('footer.legal'));
$privacyMailto = 'mailto:legal@origen.ar?subject=' . rawurlencode($t('footer.legal_privacy'));

$articles = [
    ['id' => 'status', 'key' => 'status', 'group' => 'foundation'],
    ['id' => 'intro', 'key' => 'intro', 'group' => 'foundation'],
    ['id' => 'concept', 'key' => 'concept', 'group' => 'foundation'],
    ['id' => 'components', 'key' => 'components', 'group' => 'model'],
    ['id' => 'calculation', 'key' => 'calculation', 'group' => 'model'],
    ['id' => 'determination', 'key' => 'determination', 'group' => 'model'],
    ['id' => 'scale', 'key' => 'scale', 'group' => 'model'],
    ['id' => 'geographic', 'key' => 'geographic', 'group' => 'model'],
    ['id' => 'monetary', 'key' => 'monetary', 'group' => 'model'],
    ['id' => 'distinction', 'key' => 'distinction', 'group' => 'model'],
    ['id' => 'rvu', 'key' => 'rvu', 'group' => 'model'],
    ['id' => 'sources', 'key' => 'sources', 'group' => 'operations'],
    ['id' => 'traceability', 'key' => 'traceability', 'group' => 'operations'],
    ['id' => 'governance', 'key' => 'governance', 'group' => 'operations'],
    ['id' => 'scope', 'key' => 'scope', 'group' => 'operations'],
    ['id' => 'roadmap', 'key' => 'roadmap', 'group' => 'operations'],
];

$articleIndex = [];
foreach ($articles as $index => $article) {
    $articleIndex[$article['id']] = $index;
}

$grouped = [];
foreach ($articles as $article) {
    $grouped[$article['group']][] = $article;
}

$renderSubhead = static function (string $id, string $label): void {
    echo '<h3 id="' . e($id) . '">' . e($label) . '</h3>';
};

$renderParagraph = static function (string $key) use ($t, $esc): void {
    echo '<p>' . $esc($t($key)) . '</p>';
};

$renderItemList = static function (string $key) use ($t, $esc): void {
    $items = array_values(array_filter(array_map('trim', explode(';', $t($key))), static fn (string $item): bool => $item !== ''));
    echo '<ul class="uvr-list">';
    foreach ($items as $item) {
        echo '<li>' . $esc($item) . '</li>';
    }
    echo '</ul>';
};

$renderCallout = static function (string $tone, string $title, string $text) use ($esc): void {
    ?>
    <div class="callout callout--<?= $esc($tone) ?>">
        <strong><?= $esc($title) ?></strong>
        <p><?= $esc($text) ?></p>
    </div>
    <?php
};

$renderFormula = static function (string $key, string $id) use ($t, $esc, $raw): void {
    $formula = $t($key);
    ?>
    <div class="formula" id="<?= $esc($id) ?>">
        <code><?= $raw($formula) ?></code>
        <button type="button" class="copy-formula" data-formula="<?= $esc($formula) ?>"
                aria-label="<?= $esc($t('uvr.a11y.copy_formula')) ?>"><?= $esc($t('uvr.a11y.copy_formula')) ?></button>
    </div>
    <?php
};

/**
 * @param list<string> $headers
 * @param list<list<string>> $rows
 */
$renderTable = static function (array $headers, array $rows) use ($esc): void {
    ?>
    <div class="table-wrap">
        <table class="uvr-table">
            <thead>
                <tr>
                    <?php foreach ($headers as $header): ?>
                        <th scope="col"><?= $esc($header) ?></th>
                    <?php endforeach; ?>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($rows as $row): ?>
                    <tr>
                        <?php foreach ($row as $cell): ?>
                            <td><?= $esc($cell) ?></td>
                        <?php endforeach; ?>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php
};

$renderArticleNav = static function (string $id) use ($articles, $articleIndex, $t, $esc): void {
    $index = $articleIndex[$id];
    $prev = $articles[$index - 1] ?? null;
    $next = $articles[$index + 1] ?? null;
    ?>
    <nav class="article-nav" aria-label="<?= $esc($t('uvr.a11y.next')) ?>">
        <?php if ($prev !== null): ?>
            <a class="article-nav__link article-nav__link--prev" href="#<?= $esc($prev['id']) ?>">
                <span><?= $esc($t('uvr.a11y.previous')) ?></span>
                <strong><?= $esc($t('uvr.article.' . $prev['key'] . '.title')) ?></strong>
            </a>
        <?php else: ?>
            <span></span>
        <?php endif; ?>
        <?php if ($next !== null): ?>
            <a class="article-nav__link article-nav__link--next" href="#<?= $esc($next['id']) ?>">
                <span><?= $esc($t('uvr.a11y.next')) ?></span>
                <strong><?= $esc($t('uvr.article.' . $next['key'] . '.title')) ?></strong>
            </a>
        <?php endif; ?>
    </nav>
    <?php
};
?>
<!doctype html>
<html lang="<?= $esc($locale) ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= $esc($t('uvr.meta.title')) ?></title>
    <meta name="description" content="<?= $esc($t('uvr.meta.description')) ?>">
    <meta property="og:type" content="website">
    <meta property="og:title" content="<?= $esc($t('uvr.meta.title')) ?>">
    <meta property="og:description" content="<?= $esc($t('uvr.meta.description')) ?>">
    <meta property="og:locale" content="<?= $esc($metadata['og_locale']) ?>">
    <meta property="og:url" content="<?= $esc($canonical) ?>">
    <meta name="twitter:card" content="summary">
    <meta name="twitter:title" content="<?= $esc($t('uvr.meta.title')) ?>">
    <meta name="twitter:description" content="<?= $esc($t('uvr.meta.description')) ?>">
    <link rel="canonical" href="<?= $esc($canonical) ?>">
    <?php foreach ($alternates as $alternate): ?>
        <link rel="alternate" hreflang="<?= $esc($alternate['hreflang']) ?>" href="<?= $esc($alternate['href']) ?>">
    <?php endforeach; ?>
    <link rel="stylesheet" href="assets/css/app.css?v=uvr-v1">
    <style>
        .uvr-shell { display: grid; grid-template-columns: 248px minmax(0, 1fr) 190px; gap: 32px; align-items: start; padding: 32px 0 72px; }
        .uvr-sidebar, .uvr-toc { position: sticky; top: 20px; max-height: calc(100vh - 40px); overflow-y: auto; }
        .uvr-sidebar { padding: 18px; border: 1px solid var(--line); border-radius: var(--radius); background: var(--paper); }
        .uvr-sidebar__title { margin: 0 0 12px; font-size: .8rem; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
        .uvr-search { position: relative; margin-bottom: 16px; }
        .uvr-search input { width: 100%; padding: 9px 34px 9px 12px; border: 1px solid var(--line); border-radius: 8px; background: var(--white); color: var(--ink); font: inherit; font-size: .88rem; }
        .uvr-search__clear { position: absolute; right: 6px; top: 50%; transform: translateY(-50%); border: 0; background: transparent; color: var(--muted); cursor: pointer; padding: 4px 6px; font-size: 1rem; }
        .uvr-search__empty { display: none; margin: 8px 2px; font-size: .82rem; color: var(--muted); }
        .uvr-nav-group { margin-bottom: 18px; }
        .uvr-nav-group h3 { margin: 0 0 6px; font-size: .72rem; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
        .uvr-nav-group ul { list-style: none; padding: 0; margin: 0; }
        .uvr-nav-group a { display: block; padding: 6px 9px; border-radius: 6px; color: var(--ink-soft); font-size: .88rem; line-height: 1.35; text-decoration: none; }
        .uvr-nav-group a:hover, .uvr-nav-group a.is-active { background: var(--white); color: var(--teal-dark); box-shadow: var(--shadow-sm); }
        .uvr-main { min-width: 0; }
        .uvr-intro { margin-bottom: 28px; padding-bottom: 22px; border-bottom: 1px solid var(--line); }
        .uvr-intro__badge { display: inline-block; margin-bottom: 10px; padding: 4px 10px; border-radius: 999px; background: var(--mint); color: var(--teal-dark); font-size: .75rem; font-weight: 700; letter-spacing: .04em; }
        .uvr-intro h1 { margin: 0 0 10px; font-size: clamp(1.8rem, 4vw, 2.6rem); line-height: 1.1; color: var(--ink); }
        .uvr-intro p { margin: 0; max-width: 76ch; color: var(--ink-soft); font-size: 1.05rem; }
        .uvr-status-banner { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-top: 16px; padding: 12px 14px; border-left: 4px solid #d97706; border-radius: 10px; background: #fff8e8; }
        .uvr-status-banner p { margin: 0; flex: 1 1 420px; font-size: .9rem; }
        .badge { padding: 3px 8px; border-radius: 999px; font-size: .7rem; font-weight: 700; white-space: nowrap; }
        .badge--ok { background: var(--mint); color: var(--teal-dark); }
        .badge--get { background: var(--mint); color: var(--teal-dark); }
        .badge--pending { background: #fff2d9; color: #8a5a00; }
        .breadcrumb ol { display: flex; flex-wrap: wrap; gap: 6px; list-style: none; padding: 0; margin: 0 0 18px; font-size: .82rem; color: var(--muted); }
        .breadcrumb li + li::before { content: "/"; margin-right: 6px; color: var(--line); }
        .breadcrumb a { color: var(--teal-dark); }
        .breadcrumb [aria-current="page"] { color: var(--ink); font-weight: 600; }
        .uvr-toc { padding: 16px; border-left: 2px solid var(--mint); font-size: .84rem; }
        .uvr-toc h2 { margin: 0 0 8px; font-size: .72rem; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
        .uvr-toc ol { list-style: none; padding: 0; margin: 0; }
        .uvr-toc a { display: block; padding: 4px 0; color: var(--ink-soft); text-decoration: none; }
        .uvr-toc a:hover, .uvr-toc a.is-active { color: var(--teal-dark); font-weight: 600; }
        .uvr-section { margin-bottom: 56px; scroll-margin-top: 24px; }
        .uvr-section > h2 { margin: 0 0 10px; padding-bottom: 8px; border-bottom: 2px solid var(--mint); font-size: 1.6rem; color: var(--ink); }
        .uvr-section > p.lead { margin: 0 0 22px; color: var(--ink-soft); font-size: 1.02rem; }
        .uvr-section h3 { margin: 30px 0 10px; scroll-margin-top: 24px; font-size: 1.2rem; color: var(--ink); }
        .uvr-section p { color: var(--ink-soft); }
        .uvr-list { margin: 10px 0 18px; padding-left: 1.2rem; color: var(--ink-soft); }
        .uvr-list li { margin-bottom: 5px; }
        .table-wrap { width: 100%; overflow-x: auto; margin: 14px 0 22px; }
        .uvr-table { width: 100%; min-width: 520px; border-collapse: collapse; font-size: .9rem; }
        .uvr-table th, .uvr-table td { padding: 9px 12px; text-align: left; border-bottom: 1px solid var(--line); vertical-align: top; }
        .uvr-table th { background: var(--paper); color: var(--ink); font-weight: 700; }
        .uvr-table code, .formula code { font-family: var(--font-mono); }
        .formula { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 10px; margin: 14px 0 22px; padding: 12px 14px; border: 1px solid rgba(255, 255, 255, .12); border-radius: 10px; background: #061522; color: #d7f1f7; }
        .formula code { flex: 1 1 340px; overflow-wrap: anywhere; font-size: .86rem; line-height: 1.5; }
        .copy-formula { border: 1px solid rgba(255, 255, 255, .2); border-radius: 6px; background: rgba(255, 255, 255, .08); color: inherit; padding: 5px 9px; cursor: pointer; font: inherit; font-size: .74rem; }
        .copy-formula:hover { background: rgba(255, 255, 255, .16); }
        .callout { margin: 18px 0; padding: 14px 16px; border-left: 4px solid var(--teal); border-radius: 10px; background: var(--mint); }
        .callout p { margin: 6px 0 0; }
        .callout--warning { border-color: #d97706; background: #fff8e8; }
        .callout--danger { border-color: #b91c1c; background: #fef2f2; }
        .callout--pending { border-color: #8a5a00; background: #fff9e8; }
        .article-nav { display: flex; justify-content: space-between; gap: 12px; margin-top: 34px; padding-top: 18px; border-top: 1px solid var(--line); }
        .article-nav__link { display: grid; gap: 2px; max-width: 46%; padding: 10px 14px; border: 1px solid var(--line); border-radius: 10px; color: var(--ink-soft); text-decoration: none; }
        .article-nav__link span { font-size: .72rem; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); }
        .article-nav__link strong { color: var(--teal-dark); font-size: .9rem; }
        .article-nav__link--next { text-align: right; margin-left: auto; }
        .uvr-lang-switch { display: flex; align-items: center; gap: 5px; }
        .uvr-lang-switch a { padding: 4px 7px; border-radius: 5px; color: var(--ink-soft); font-size: .78rem; font-weight: 700; text-decoration: none; }
        .uvr-lang-switch a[aria-current="true"] { background: var(--mint); color: var(--teal-dark); }
        a:focus-visible, button:focus-visible, input:focus-visible { outline: 3px solid #7dd3fc; outline-offset: 2px; }
        @media (max-width: 1180px) { .uvr-shell { grid-template-columns: 232px minmax(0, 1fr); } .uvr-toc { display: none; } }
        @media (max-width: 860px) {
            .uvr-shell { grid-template-columns: 1fr; gap: 24px; padding-top: 22px; }
            .uvr-sidebar, .uvr-toc { position: static; max-height: none; }
            .article-nav { flex-direction: column; }
            .article-nav__link { max-width: none; margin-left: 0 !important; text-align: left !important; }
        }
        @media (prefers-reduced-motion: reduce) { * { scroll-behavior: auto !important; transition: none !important; } }
        @media print { .uvr-sidebar, .uvr-toc, .article-nav, .copy-formula, .site-header, .site-footer { display: none !important; } .uvr-shell { display: block; } }
    </style>
</head>
<body>
<a class="skip-link" href="#main"><?= $esc($t('uvr.a11y.skip')) ?></a>

<header class="site-header">
    <div class="container header-inner">
        <a class="brand" href="<?= $esc($homePath) ?>" aria-label="Origen Salud">
            <svg class="brand-mark" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                <rect width="40" height="40" rx="12" fill="currentColor"/>
                <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
            </svg>
            <span class="brand-name">Origen<span>Salud</span></span>
        </a>

        <nav class="site-nav" aria-label="<?= $esc($t('nav.label')) ?>">
            <?php $activeNav = 'uvr'; require dirname(__DIR__) . '/portal/Views/partials/nav-links.php'; ?>
        </nav>

        <div class="header-actions">
            <div class="uvr-lang-switch" role="group" aria-label="<?= $esc($t('uvr.lang.label')) ?>">
                <?php foreach ($alternates as $alternate): ?>
                    <a href="<?= $esc($alternate['href']) ?>" hreflang="<?= $esc($alternate['hreflang']) ?>"
                       lang="<?= $esc($alternate['hreflang']) ?>"
                       <?= $alternate['active'] ? 'aria-current="true"' : '' ?>
                       data-lang-link title="<?= $esc($alternate['label']) ?>"><?= $esc($alternate['short']) ?></a>
                <?php endforeach; ?>
            </div>
            <a class="button button-small button-management" href="/admin/login"><?= $esc($t('nav.management')) ?></a>
            <a class="button button-small" href="<?= $esc($accessMailto) ?>"><?= $esc($t('nav.access')) ?></a>
        </div>
    </div>
</header>

<main id="main">
    <div class="container uvr-shell">
        <aside class="uvr-sidebar" aria-label="<?= $esc($t('uvr.nav.index')) ?>">
            <p class="uvr-sidebar__title"><?= $esc($t('uvr.nav.index')) ?></p>
            <div class="uvr-search" role="search" aria-label="<?= $esc($t('uvr.nav.search')) ?>">
                <label class="sr-only" for="uvr-search-input"><?= $esc($t('uvr.a11y.search_label')) ?></label>
                <input id="uvr-search-input" type="search" autocomplete="off"
                       placeholder="<?= $esc($t('uvr.a11y.search_placeholder')) ?>">
                <button type="button" class="uvr-search__clear" id="uvr-search-clear"
                        aria-label="<?= $esc($t('uvr.a11y.search_clear')) ?>">&times;</button>
            </div>
            <p class="uvr-search__empty" id="uvr-search-empty"><?= $esc($t('uvr.a11y.search_no_results')) ?></p>

            <nav aria-label="<?= $esc($t('uvr.nav.label')) ?>">
                <?php foreach ($grouped as $group => $groupArticles): ?>
                    <div class="uvr-nav-group">
                        <h3><?= $esc($t('uvr.nav.groups.' . $group)) ?></h3>
                        <ul>
                            <?php foreach ($groupArticles as $article): ?>
                                <?php
                                $articleKey = 'uvr.article.' . $article['key'];
                                $searchText = $t($articleKey . '.title') . ' ' . $t($articleKey . '.lead') . ' ' . $t($articleKey . '.keywords');
                                ?>
                                <li>
                                    <a href="#<?= $esc($article['id']) ?>" data-nav-link
                                       data-search="<?= $esc(mb_strtolower($searchText, 'UTF-8')) ?>"><?= $esc($t($articleKey . '.title')) ?></a>
                                </li>
                            <?php endforeach; ?>
                        </ul>
                    </div>
                <?php endforeach; ?>
            </nav>
        </aside>

        <div class="uvr-main">
            <div class="uvr-intro">
                <span class="uvr-intro__badge"><?= $esc($t('uvr.header.eyebrow')) ?></span>
                <h1><?= $esc($t('uvr.header.title')) ?></h1>
                <p><?= $esc($t('uvr.header.lead')) ?></p>
                <div class="uvr-status-banner">
                    <span class="badge badge--pending"><?= $esc($t('uvr.common.proposal')) ?></span>
                    <span class="badge badge--get"><?= $esc($t('uvr.header.badge')) ?></span>
                    <p><?= $esc($t('uvr.header.status_text')) ?></p>
                </div>
            </div>

            <nav class="breadcrumb" aria-label="<?= $esc($t('uvr.a11y.breadcrumb_label')) ?>">
                <ol>
                    <li><a href="<?= $esc($homePath) ?>"><?= $esc($t('uvr.breadcrumb.home')) ?></a></li>
                    <li><a href="<?= $esc($docsPath) ?>"><?= $esc($t('uvr.breadcrumb.docs')) ?></a></li>
                    <li data-breadcrumb-group><?= $esc($t('uvr.nav.groups.foundation')) ?></li>
                    <li aria-current="page" data-breadcrumb-article><?= $esc($t('uvr.article.status.title')) ?></li>
                </ol>
            </nav>

            <section id="status" class="uvr-section" data-article="status">
                <h2><?= $esc($t('uvr.status.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.status.lead')) ?></p>

                <?php $renderSubhead('status-exists', $t('uvr.status.exists_title')); ?>
                <?php $renderParagraph('uvr.status.exists_text'); ?>

                <?php $renderSubhead('status-pending', $t('uvr.status.pending_title')); ?>
                <?php $renderParagraph('uvr.status.pending_text'); ?>
                <span class="badge badge--pending"><?= $esc($t('uvr.common.not_implemented')) ?></span>

                <?php $renderSubhead('status-artifact', $t('uvr.status.artifact_title')); ?>
                <?php $renderParagraph('uvr.status.artifact_text'); ?>
                <?php $renderCallout('warning', $t('uvr.header.status_title'), $t('uvr.header.status_text')); ?>
                <?php $renderArticleNav('status'); ?>
            </section>

            <section id="intro" class="uvr-section" data-article="intro">
                <h2><?= $esc($t('uvr.intro.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.intro.lead')) ?></p>
                <?php $renderParagraph('uvr.intro.goal'); ?>

                <?php $renderSubhead('intro-questions', $t('uvr.intro.questions_title')); ?>
                <ol class="uvr-list">
                    <li><?= $esc($t('uvr.intro.q1')) ?></li>
                    <li><?= $esc($t('uvr.intro.q2')) ?></li>
                </ol>
                <?php $renderParagraph('uvr.intro.answer'); ?>
                <?php $renderCallout('', $t('uvr.common.note'), $t('uvr.intro.key_message')); ?>
                <?php $renderArticleNav('intro'); ?>
            </section>

            <section id="concept" class="uvr-section" data-article="concept">
                <h2><?= $esc($t('uvr.concept.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.concept.lead')) ?></p>

                <?php $renderSubhead('concept-rvu', $t('uvr.concept.rvu_title')); ?>
                <ul class="uvr-list">
                    <li><?= $esc($t('uvr.concept.rvu_work')) ?></li>
                    <li><?= $esc($t('uvr.concept.rvu_expense')) ?></li>
                    <li><?= $esc($t('uvr.concept.rvu_malpractice')) ?></li>
                </ul>
                <?php $renderParagraph('uvr.concept.adaptation'); ?>
                <?php $renderCallout('warning', $t('uvr.common.warning'), $t('uvr.concept.no_equivalence')); ?>
                <?php $renderArticleNav('concept'); ?>
            </section>

            <section id="components" class="uvr-section" data-article="components">
                <h2><?= $esc($t('uvr.components.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.components.lead')) ?></p>

                <?php $renderSubhead('components-work', $t('uvr.components.work_title')); ?>
                <?php $renderParagraph('uvr.components.work_text'); ?>
                <?php $renderItemList('uvr.components.work_items'); ?>
                <?php $renderCallout('warning', $t('uvr.common.warning'), $t('uvr.components.work_warning')); ?>

                <?php $renderSubhead('components-expense', $t('uvr.components.expense_title')); ?>
                <?php $renderParagraph('uvr.components.expense_text'); ?>
                <?php $renderItemList('uvr.components.expense_items'); ?>
                <?php $renderCallout('warning', $t('uvr.common.warning'), $t('uvr.components.expense_warning')); ?>

                <?php $renderSubhead('components-liability', $t('uvr.components.liability_title')); ?>
                <?php $renderParagraph('uvr.components.liability_text'); ?>
                <?php $renderItemList('uvr.components.liability_items'); ?>
                <?php $renderCallout('warning', $t('uvr.common.warning'), $t('uvr.components.liability_warning')); ?>
                <?php $renderArticleNav('components'); ?>
            </section>

            <section id="calculation" class="uvr-section" data-article="calculation">
                <h2><?= $esc($t('uvr.calculation.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.calculation.lead')) ?></p>

                <?php $renderFormula('uvr.calculation.formula', 'calculation-formula'); ?>

                <?php $renderSubhead('calculation-example', $t('uvr.calculation.example_title')); ?>
                <?php $renderParagraph('uvr.calculation.example_intro'); ?>
                <?php $renderTable(
                    [$t('uvr.common.component'), $t('uvr.common.value')],
                    [
                        [$t('uvr.calculation.example_work'), $t('uvr.calculation.example_value_work')],
                        [$t('uvr.calculation.example_expense'), $t('uvr.calculation.example_value_expense')],
                        [$t('uvr.calculation.example_liability'), $t('uvr.calculation.example_value_liability')],
                        [$t('uvr.calculation.example_total'), $t('uvr.calculation.example_value_total')],
                    ]
                ); ?>
                <?php $renderParagraph('uvr.calculation.example_meaning'); ?>
                <?php $renderCallout('pending', $t('uvr.common.note'), $t('uvr.common.illustrative')); ?>
                <?php $renderArticleNav('calculation'); ?>
            </section>

            <section id="determination" class="uvr-section" data-article="determination">
                <h2><?= $esc($t('uvr.determination.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.determination.lead')) ?></p>

                <?php $renderSubhead('determination-collection', $t('uvr.determination.collection_title')); ?>
                <?php $renderParagraph('uvr.determination.collection_text'); ?>
                <?php $renderParagraph('uvr.determination.collection_sources'); ?>

                <?php $renderSubhead('determination-work', $t('uvr.determination.work_title')); ?>
                <?php $renderParagraph('uvr.determination.work_text'); ?>

                <?php $renderSubhead('determination-expense', $t('uvr.determination.expense_title')); ?>
                <?php $renderParagraph('uvr.determination.expense_text'); ?>

                <?php $renderSubhead('determination-liability', $t('uvr.determination.liability_title')); ?>
                <?php $renderParagraph('uvr.determination.liability_text'); ?>

                <?php $renderSubhead('determination-validation', $t('uvr.determination.validation_title')); ?>
                <?php $renderParagraph('uvr.determination.validation_text'); ?>
                <p class="uvr-steps"><?= $esc($t('uvr.determination.steps')) ?></p>
                <?php $renderParagraph('uvr.determination.delphi'); ?>
                <?php $renderArticleNav('determination'); ?>
            </section>

            <section id="scale" class="uvr-section" data-article="scale">
                <h2><?= $esc($t('uvr.scale.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.scale.lead')) ?></p>

                <?php $renderSubhead('scale-identify', $t('uvr.scale.identify_title')); ?>
                <?php $renderItemList('uvr.scale.identify_items'); ?>
                <?php $renderParagraph('uvr.scale.reference'); ?>
                <?php $renderCallout('warning', $t('uvr.common.warning'), $t('uvr.scale.warning')); ?>
                <?php $renderArticleNav('scale'); ?>
            </section>

            <section id="geographic" class="uvr-section" data-article="geographic">
                <h2><?= $esc($t('uvr.geographic.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.geographic.lead')) ?></p>

                <?php $renderSubhead('geographic-factors', $t('uvr.geographic.factors_title')); ?>
                <?php $renderItemList('uvr.geographic.factors'); ?>

                <?php $renderSubhead('geographic-gpci', $t('uvr.geographic.gpci_title')); ?>
                <?php $renderParagraph('uvr.geographic.gpci_text'); ?>

                <?php $renderSubhead('geographic-indexes', $t('uvr.geographic.proposed_title')); ?>
                <ul class="uvr-list">
                    <li><code><?= $esc($t('uvr.geographic.index_work')) ?></code></li>
                    <li><code><?= $esc($t('uvr.geographic.index_expense')) ?></code></li>
                    <li><code><?= $esc($t('uvr.geographic.index_liability')) ?></code></li>
                </ul>
                <?php $renderFormula('uvr.geographic.formula_work', 'geographic-formula-work'); ?>
                <?php $renderFormula('uvr.geographic.formula_expense', 'geographic-formula-expense'); ?>
                <?php $renderFormula('uvr.geographic.formula_liability', 'geographic-formula-liability'); ?>
                <?php $renderFormula('uvr.geographic.formula_total', 'geographic-formula-total'); ?>
                <?php $renderParagraph('uvr.geographic.interpretation'); ?>

                <?php $renderSubhead('geographic-gradual', $t('uvr.geographic.gradual_title')); ?>
                <?php $renderParagraph('uvr.geographic.gradual_text'); ?>
                <?php $renderCallout('warning', $t('uvr.common.warning'), $t('uvr.geographic.gradual_warning')); ?>
                <?php $renderArticleNav('geographic'); ?>
            </section>

            <section id="monetary" class="uvr-section" data-article="monetary">
                <h2><?= $esc($t('uvr.monetary.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.monetary.lead')) ?></p>

                <?php $renderSubhead('monetary-value', $t('uvr.monetary.uvr_value')); ?>
                <?php $renderParagraph('uvr.monetary.uvr_value_text'); ?>
                <?php $renderFormula('uvr.monetary.formula_plain', 'monetary-formula-plain'); ?>
                <?php $renderFormula('uvr.monetary.formula_adjusted', 'monetary-formula-adjusted'); ?>

                <?php $renderSubhead('monetary-example', $t('uvr.monetary.example_title')); ?>
                <?php $renderParagraph('uvr.monetary.example_text'); ?>
                <?php $renderCallout('pending', $t('uvr.common.note'), $t('uvr.common.illustrative')); ?>

                <?php $renderSubhead('monetary-determination', $t('uvr.monetary.determination_title')); ?>
                <?php $renderParagraph('uvr.monetary.determination_text'); ?>
                <?php $renderParagraph('uvr.monetary.variation'); ?>
                <?php $renderArticleNav('monetary'); ?>
            </section>

            <section id="distinction" class="uvr-section" data-article="distinction">
                <h2><?= $esc($t('uvr.distinction.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.distinction.lead')) ?></p>

                <?php $renderSubhead('distinction-uvr', $t('uvr.distinction.uvr_title')); ?>
                <?php $renderParagraph('uvr.distinction.uvr_text'); ?>

                <?php $renderSubhead('distinction-money', $t('uvr.distinction.money_title')); ?>
                <?php $renderParagraph('uvr.distinction.money_text'); ?>
                <?php $renderCallout('', $t('uvr.common.note'), $t('uvr.distinction.rule')); ?>
                <?php $renderArticleNav('distinction'); ?>
            </section>

            <section id="rvu" class="uvr-section" data-article="rvu">
                <h2><?= $esc($t('uvr.rvu.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.rvu.lead')) ?></p>

                <?php $renderTable(
                    [$t('uvr.common.characteristic'), $t('uvr.rvu.col_uvr'), $t('uvr.rvu.col_rvu')],
                    [
                        [$t('uvr.rvu.row_work'), $t('uvr.rvu.val_work'), 'Work RVU'],
                        [$t('uvr.rvu.row_expense'), $t('uvr.rvu.val_expense'), 'Practice Expense RVU'],
                        [$t('uvr.rvu.row_liability'), $t('uvr.rvu.val_liability'), 'Malpractice RVU'],
                        [$t('uvr.rvu.row_total'), $t('uvr.rvu.val_total'), 'Total RVU'],
                        [$t('uvr.rvu.row_geo'), $t('uvr.rvu.val_geo'), 'GPCI'],
                        [$t('uvr.rvu.row_conversion'), $t('uvr.rvu.val_conversion'), 'Conversion Factor'],
                        [$t('uvr.rvu.row_scope'), $t('uvr.rvu.val_scope'), 'Medicare (Estados Unidos)'],
                    ]
                ); ?>
                <?php $renderCallout('warning', $t('uvr.common.warning'), $t('uvr.rvu.warning')); ?>
                <?php $renderArticleNav('rvu'); ?>
            </section>

            <section id="sources" class="uvr-section" data-article="sources">
                <h2><?= $esc($t('uvr.sources.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.sources.lead')) ?></p>
                <?php $renderItemList('uvr.sources.items'); ?>
                <?php $renderParagraph('uvr.sources.external'); ?>
                <?php $renderCallout('warning', $t('uvr.common.warning'), $t('uvr.sources.warning')); ?>
                <?php $renderArticleNav('sources'); ?>
            </section>

            <section id="traceability" class="uvr-section" data-article="traceability">
                <h2><?= $esc($t('uvr.traceability.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.traceability.lead')) ?></p>
                <?php $renderItemList('uvr.traceability.fields'); ?>
                <?php $renderParagraph('uvr.traceability.history'); ?>
                <?php $renderParagraph('uvr.traceability.independent'); ?>
                <?php $renderArticleNav('traceability'); ?>
            </section>

            <section id="governance" class="uvr-section" data-article="governance">
                <h2><?= $esc($t('uvr.governance.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.governance.lead')) ?></p>
                <?php $renderItemList('uvr.governance.items'); ?>
                <?php $renderCallout('', $t('uvr.common.note'), $t('uvr.governance.rule')); ?>
                <?php $renderArticleNav('governance'); ?>
            </section>

            <section id="scope" class="uvr-section" data-article="scope">
                <h2><?= $esc($t('uvr.scope.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.scope.lead')) ?></p>

                <?php $renderSubhead('scope-not', $t('uvr.scope.not_title')); ?>
                <?php $renderItemList('uvr.scope.not_items'); ?>
                <?php $renderParagraph('uvr.scope.rule'); ?>
                <?php $renderParagraph('uvr.scope.purpose'); ?>
                <?php $renderCallout('warning', $t('uvr.common.warning'), $t('uvr.status.pending_text')); ?>
                <?php $renderArticleNav('scope'); ?>
            </section>

            <section id="roadmap" class="uvr-section" data-article="roadmap">
                <h2><?= $esc($t('uvr.roadmap.title')) ?></h2>
                <p class="lead"><?= $esc($t('uvr.roadmap.lead')) ?></p>
                <?php $renderItemList('uvr.roadmap.areas'); ?>
                <?php $renderParagraph('uvr.roadmap.principles'); ?>
                <?php $renderParagraph('uvr.roadmap.goal'); ?>
                <?php $renderArticleNav('roadmap'); ?>
            </section>
        </div>

        <aside class="uvr-toc" id="uvr-toc" aria-label="<?= $esc($t('uvr.a11y.toc_label')) ?>">
            <h2><?= $esc($t('uvr.a11y.toc_label')) ?></h2>
            <ol id="uvr-toc-list"></ol>
        </aside>
    </div>
</main>

<footer class="site-footer">
    <div class="container footer-inner">
        <div>
            <a href="<?= $esc($legalMailto) ?>" class="footer-link"><?= $esc($t('footer.legal')) ?></a>
            <a href="<?= $esc($privacyMailto) ?>" class="footer-link"><?= $esc($t('footer.legal_privacy')) ?></a>
        </div>
        <p><?= $esc(str_replace('%year%', (string) $year, $t('footer.rights'))) ?></p>
        <p><small><?= $esc($t('uvr.footer.disclaimer')) ?></small></p>
        <p><small><?= $esc($t('footer.disclaimer')) ?></small></p>
    </div>
</footer>

<script>
(function () {
    'use strict';

    var searchInput = document.getElementById('uvr-search-input');
    var searchClear = document.getElementById('uvr-search-clear');
    var searchEmpty = document.getElementById('uvr-search-empty');
    var navLinks = Array.prototype.slice.call(document.querySelectorAll('[data-nav-link]'));
    var sections = Array.prototype.slice.call(document.querySelectorAll('[data-article]'));
    var articleMap = {};
    sections.forEach(function (section) { articleMap[section.id] = section; });

    var articleData = {};
    navLinks.forEach(function (link) {
        articleData[link.getAttribute('href').slice(1)] = {
            link: link,
            title: link.textContent.trim()
        };
    });

    function filterDocs() {
        var term = (searchInput.value || '').trim().toLocaleLowerCase();
        var visible = 0;
        navLinks.forEach(function (link) {
            var haystack = link.getAttribute('data-search') || '';
            var match = term === '' || haystack.indexOf(term) !== -1;
            link.parentElement.hidden = !match;
            if (match) { visible++; }
        });
        searchEmpty.style.display = visible === 0 ? 'block' : 'none';
    }

    if (searchInput) {
        searchInput.addEventListener('input', filterDocs);
        searchClear.addEventListener('click', function () {
            searchInput.value = '';
            filterDocs();
            searchInput.focus();
        });
    }

    document.addEventListener('keydown', function (event) {
        var tag = (event.target.tagName || '').toLowerCase();
        var typing = tag === 'input' || tag === 'textarea' || event.target.isContentEditable;
        if ((event.key === '/' && !typing) || ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k')) {
            event.preventDefault();
            if (searchInput) { searchInput.focus(); }
        }
    });

    function copyText(text, button, doneLabel) {
        function finish() {
            var old = button.textContent;
            button.textContent = doneLabel;
            window.setTimeout(function () { button.textContent = old; }, 1600);
        }
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).then(finish).catch(function () { fallback(); });
        } else {
            fallback();
        }
        function fallback() {
            var area = document.createElement('textarea');
            area.value = text;
            area.setAttribute('readonly', '');
            area.style.position = 'fixed';
            area.style.opacity = '0';
            document.body.appendChild(area);
            area.select();
            try { document.execCommand('copy'); finish(); } catch (error) { /* sin portapapeles */ }
            document.body.removeChild(area);
        }
    }

    document.addEventListener('click', function (event) {
        var button = event.target.closest('[data-formula]');
        if (!button) { return; }
        copyText(button.getAttribute('data-formula'), button, <?= json_encode($t('uvr.a11y.copied'), JSON_UNESCAPED_UNICODE) ?>);
    });

    var breadcrumbGroup = document.querySelector('[data-breadcrumb-group]');
    var breadcrumbArticle = document.querySelector('[data-breadcrumb-article]');
    var tocList = document.getElementById('uvr-toc-list');
    var activeId = 'status';

    function renderToc(section) {
        if (!tocList || !section) { return; }
        tocList.innerHTML = '';
        var headings = Array.prototype.slice.call(section.querySelectorAll('h3[id]'));
        headings.forEach(function (heading) {
            var li = document.createElement('li');
            var link = document.createElement('a');
            link.href = '#' + heading.id;
            link.textContent = heading.textContent;
            link.setAttribute('data-toc-link', heading.id);
            li.appendChild(link);
            tocList.appendChild(li);
        });
    }

    function activate(id) {
        if (!articleMap[id]) { return; }
        if (id === activeId && breadcrumbArticle.textContent) {
            renderToc(articleMap[id]);
            return;
        }
        activeId = id;
        var data = articleData[id];
        navLinks.forEach(function (link) { link.classList.toggle('is-active', link.getAttribute('href') === '#' + id); });
        if (data && breadcrumbArticle) {
            breadcrumbArticle.textContent = data.title;
            var group = articleMap[id].getAttribute('data-group-label');
            if (group && breadcrumbGroup) { breadcrumbGroup.textContent = group; }
        }
        renderToc(articleMap[id]);
    }

    sections.forEach(function (section) {
        var index = articleData[section.id];
        if (index) {
            var groupHeading = index.link.closest('.uvr-nav-group').querySelector('h3');
            section.setAttribute('data-group-label', groupHeading ? groupHeading.textContent : '');
        }
    });

    if ('IntersectionObserver' in window) {
        var observer = new IntersectionObserver(function (entries) {
            var best = null;
            entries.forEach(function (entry) {
                if (entry.isIntersecting && (!best || entry.intersectionRatio > best.intersectionRatio)) { best = entry; }
            });
            if (best) { activate(best.target.id); }
        }, { rootMargin: '-15% 0px -70% 0px', threshold: [0, 0.25, 0.5, 1] });
        sections.forEach(function (section) { observer.observe(section); });
    }

    window.addEventListener('hashchange', function () {
        var id = window.location.hash.slice(1);
        if (articleMap[id]) { activate(id); }
    });
    if (window.location.hash) {
        var initial = window.location.hash.slice(1);
        if (articleMap[initial]) { activate(initial); }
    } else {
        activate('status');
    }

    document.querySelectorAll('[data-lang-link]').forEach(function (link) {
        if (window.location.hash) { link.href += window.location.hash; }
    });
}());
</script>
</body>
</html>
