<?php

declare(strict_types=1);

/**
 * Buscador público del portal (med.origen.ar/search).
 *
 * Consume GET /v1/search desde el servidor, propagando lang y Accept-Language.
 * La API Key se mantiene fuera del navegador. Muestra el contrato idiomático
 * de Fase 9: requested_language, effective_language, field_languages y fallback.
 */

require_once dirname(__DIR__) . '/bootstrap.php';
require_once dirname(__DIR__) . '/portal/i18n/I18n.php';
require_once __DIR__ . '/includes/ApiClient.php';

use OrigenSalud\Web\ApiClient;
use OrigenSalud\Web\I18n;

$locale = I18n::boot();

header('Content-Type: text/html; charset=UTF-8');
header('Vary: Accept-Language, Cookie');
header('Content-Language: ' . $locale);

$t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);

$requestPath = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/search'), PHP_URL_PATH);
$currentPath = is_string($requestPath) && $requestPath !== '' ? $requestPath : '/search';
$apiLocale = I18n::metadata($locale)['api_language'];

$baseUrl = rtrim((string) env('WEB_BASE_URL', 'https://med.origen.ar'), '/');
if ($baseUrl === '') {
    $baseUrl = 'https://med.origen.ar';
}

$domains = [
    'snomed', 'cie10', 'odontologia', 'anmat', 'laboratorio',
    'vacunas', 'prestaciones', 'programas', 'imagenes', 'loinc', 'oftar',
];
$requestedDomains = isset($_GET['domains']) && is_string($_GET['domains'])
    ? array_values(array_filter(array_map('trim', explode(',', $_GET['domains'])), static fn (string $item): bool => in_array($item, $domains, true)))
    : [];
if ($requestedDomains === []) {
    $requestedDomains = ['snomed', 'cie10', 'odontologia'];
}

$query = isset($_GET['q']) && is_string($_GET['q']) ? trim($_GET['q']) : '';
$limit = isset($_GET['limit']) && is_numeric($_GET['limit']) ? (int) $_GET['limit'] : 10;
$limit = max(1, min(20, $limit));

$result = $query === ''
    ? null
    : ApiClient::search($query, $locale, $requestedDomains, $limit);

$payload = $result !== null && $result['ok'] && is_array($result['payload']) ? $result['payload'] : null;
$meta = is_array($payload['meta'] ?? null) ? $payload['meta'] : [];
$items = is_array($payload['data'] ?? null) && array_is_list($payload['data']) ? $payload['data'] : [];
$fields = is_array($meta['field_languages'] ?? null) ? $meta['field_languages'] : [];
$available = is_array($meta['available_languages'] ?? null) ? $meta['available_languages'] : [];

$asBool = static function (mixed $value): bool {
    return $value === true || $value === 1 || $value === '1' || $value === 'true';
};
$asString = static function (mixed $value): ?string {
    return is_string($value) && $value !== '' ? $value : null;
};
$pick = static function (array $row, array $keys) use ($asString): ?string {
    foreach ($keys as $key) {
        $value = $asString($row[$key] ?? null);
        if ($value !== null) {
            return $value;
        }
    }

    return null;
};
$fallbackApplied = isset($meta['fallback_applied']) && $asBool($meta['fallback_applied']);
$effective = $asString($meta['effective_language'] ?? null);
$reason = $asString($meta['fallback_reason'] ?? null);
$hasFieldNotices = false;

foreach ($fields as $field) {
    if (!is_array($field)) {
        continue;
    }
    if ($asBool($field['fallback_applied'] ?? false) || $asBool($field['untranslated'] ?? false)) {
        $hasFieldNotices = true;
    }
}
?>
<!doctype html>
<html lang="<?= e($locale) ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($t('search.title')) ?> | Origen Salud</title>
    <meta name="description" content="<?= e($t('search.lead')) ?>">
    <link rel="canonical" href="<?= e($baseUrl . $currentPath) ?>">
    <!-- SEO-04: /search es una página legacy no indexable; no se publican alternates que resuelvan a rutas inexistentes. -->
    <meta name="robots" content="noindex,follow">
    <meta property="og:type" content="website">
    <meta property="og:title" content="<?= e($t('search.title')) ?>">
    <meta property="og:description" content="<?= e($t('search.lead')) ?>">
    <meta property="og:locale" content="<?= e(I18n::metadata($locale)['og_locale']) ?>">
    <link rel="stylesheet" href="assets/css/app.css">
</head>
<body>
<a class="skip-link" href="#main"><?= e($t('a11y.skip')) ?></a>

<header class="site-header">
    <div class="container header-inner">
        <a class="brand" href="/" aria-label="Origen Salud">
            <svg class="brand-mark" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                <rect width="40" height="40" rx="12" fill="currentColor"/>
                <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
            </svg>
            <span class="brand-name">Origen<span>Salud</span></span>
        </a>

        <nav class="site-nav" aria-label="<?= e($t('nav.label')) ?>">
            <a href="/#plataforma"><?= e($t('nav.platform')) ?></a>
            <a href="/#snomed"><?= e($t('nav.snomed')) ?></a>
            <a href="/#anmat"><?= e($t('nav.anmat')) ?></a>
            <a href="/#api"><?= e($t('nav.api')) ?></a>
            <a href="/search" aria-current="page" class="is-active"><?= e($t('nav.search')) ?></a>
            <a href="/docs"><?= e($t('nav.docs')) ?></a>
        </nav>

        <div class="header-actions">
            <?php require dirname(__DIR__) . '/portal/Views/partials/language-switcher.php'; ?>
            <a class="button button-small button-management" href="/admin/login"><?= e($t('nav.management')) ?></a>
        </div>
    </div>
</header>

<main id="main">
    <section class="section search-page">
        <div class="container">
            <span class="eyebrow"><?= e($t('api.eyebrow')) ?></span>
            <h1><?= e($t('search.title')) ?></h1>
            <p class="lead"><?= e($t('search.lead')) ?></p>

            <form class="search-form search-form-page" action="/search" method="get">
                <div class="search-field">
                    <label for="q"><?= e($t('search.query_label')) ?></label>
                    <input id="q" name="q" type="search" required
                           value="<?= e($query) ?>"
                           placeholder="<?= e($t('search.query_placeholder')) ?>">
                </div>
                <div class="search-field">
                    <label for="domains"><?= e($t('search.domain_label')) ?></label>
                    <select id="domains" name="domains">
                        <option value=""><?= e($t('search.domain_all')) ?></option>
                        <?php foreach ($domains as $domain): ?>
                            <option value="<?= e($domain) ?>" <?= in_array($domain, $requestedDomains, true) ? 'selected' : '' ?>>
                                <?= e($domain) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <input type="hidden" name="lang" value="<?= e($apiLocale) ?>">
                <button class="button" type="submit"><?= e($t('search.button')) ?></button>
            </form>

            <?php if ($query === ''): ?>
                <div class="alert-box"><p><?= e($t('search.empty_query')) ?></p></div>
            <?php elseif ($result === null || !$result['ok']): ?>
                <div class="alert-box alert-warning">
                    <p><?= e($t($result['error'] === 'api_not_configured' ? 'search.error_not_configured' : 'search.error_request')) ?></p>
                </div>
            <?php else: ?>
                <div class="language-summary" aria-label="<?= e($t('search.field_languages')) ?>">
                    <dl class="api-meta language-meta">
                        <div>
                            <dt><?= e($t('search.requested_language')) ?></dt>
                            <dd><code><?= e($asString($meta['requested_language'] ?? null) ?? '—') ?></code></dd>
                        </div>
                        <div>
                            <dt><?= e($t('search.effective_language')) ?></dt>
                            <dd>
                                <?php if ($effective !== null): ?>
                                    <code><?= e($effective) ?></code>
                                <?php else: ?>
                                    <span><?= e($t('search.mixed_languages')) ?></span>
                                <?php endif; ?>
                            </dd>
                        </div>
                        <div>
                            <dt><?= e($t('search.fallback_applied')) ?></dt>
                            <dd><?= e($fallbackApplied ? $t('search.fallback_yes') : $t('search.fallback_no')) ?></dd>
                        </div>
                        <div>
                            <dt><?= e($t('search.fallback_reason')) ?></dt>
                            <dd><code><?= e($reason ?? '—') ?></code></dd>
                        </div>
                    </dl>

                    <?php if ($fallbackApplied || $hasFieldNotices): ?>
                        <div class="alert-box alert-warning">
                            <p><?= e($t('search.fallback_notice')) ?></p>
                        </div>
                    <?php endif; ?>

                    <?php if ($available !== []): ?>
                        <h2><?= e($t('search.available_languages')) ?></h2>
                        <ul class="available-languages">
                            <?php foreach ($available as $language): ?>
                                <?php if (!is_array($language)) { continue; } ?>
                                <li>
                                    <code><?= e($asString($language['code'] ?? null) ?? '—') ?></code>
                                    <span><?= e($asBool($language['selectable'] ?? false) ? $t('search.selectable') : '—') ?></span>
                                </li>
                            <?php endforeach; ?>
                        </ul>
                    <?php endif; ?>

                    <?php if ($fields !== []): ?>
                        <h2><?= e($t('search.field_languages')) ?></h2>
                        <div class="table-scroll">
                            <table class="param-table field-table">
                                <thead>
                                    <tr>
                                        <th><?= e($t('search.field')) ?></th>
                                        <th><?= e($t('search.effective_language')) ?></th>
                                        <th><?= e($t('search.source_language')) ?></th>
                                        <th><?= e($t('search.provenance')) ?></th>
                                        <th><?= e($t('search.approval_state')) ?></th>
                                        <th><?= e($t('search.fallback_applied')) ?></th>
                                        <th><?= e($t('search.untranslated')) ?></th>
                                        <th><?= e($t('search.dialect_determined')) ?></th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($fields as $fieldName => $field): ?>
                                        <?php if (!is_array($field)) { continue; } ?>
                                        <tr>
                                            <td><code><?= e((string) $fieldName) ?></code></td>
                                            <td><?= e($asString($field['effective_language'] ?? null) ?? '—') ?></td>
                                            <td><?= e($asString($field['source_language'] ?? null) ?? '—') ?></td>
                                            <td><?= e($asString($field['provenance'] ?? null) ?? '—') ?></td>
                                            <td><?= e($asString($field['approval_state'] ?? null) ?? '—') ?></td>
                                            <td><?= e($asBool($field['fallback_applied'] ?? false) ? $t('search.fallback_yes') : $t('search.fallback_no')) ?></td>
                                            <td><?= e($asBool($field['untranslated'] ?? false) ? $t('search.fallback_yes') : $t('search.fallback_no')) ?></td>
                                            <td><?= e($asBool($field['dialect_determined'] ?? false) ? $t('search.fallback_yes') : $t('search.fallback_no')) ?></td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    <?php endif; ?>
                </div>

                <h2><?= e($t('search.results_title')) ?></h2>
                <?php if ($items === []): ?>
                    <div class="alert-box"><p><?= e($t('search.no_results')) ?></p></div>
                <?php else: ?>
                    <ul class="search-results">
                        <?php foreach ($items as $item): ?>
                            <?php if (!is_array($item)) { continue; } ?>
                            <?php $term = $pick($item, ['term', 'display', 'description', 'label', 'name', 'title']); ?>
                            <li class="search-result">
                                <div class="search-result-head">
                                    <strong><?= e($term ?? $t('search.no_results')) ?></strong>
                                    <?php $code = $pick($item, ['code', 'concept_id', 'id', 'loinc_num', 'sctid']); ?>
                                    <?php if ($code !== null): ?>
                                        <span class="result-code"><?= e($t('search.code')) ?>: <code><?= e($code) ?></code></span>
                                    <?php endif; ?>
                                </div>
                                <div class="search-result-meta">
                                    <?php $domain = $pick($item, ['domain', 'source', 'catalog_code']); ?>
                                    <?php if ($domain !== null): ?>
                                        <span><?= e($t('search.domain')) ?>: <code><?= e($domain) ?></code></span>
                                    <?php endif; ?>
                                    <?php $language = $pick($item, ['effective_language', 'language', 'language_code']); ?>
                                    <?php if ($language !== null): ?>
                                        <span><?= e($t('search.language')) ?>: <code><?= e($language) ?></code></span>
                                    <?php endif; ?>
                                    <?php $snomedMeta = is_array($item['metadata'] ?? null) ? ($item['metadata']['snomed_concept_id'] ?? null) : null; ?>
                                    <?php if ($snomedMeta !== null && $snomedMeta !== ''): ?>
                                        <span>SNOMED: <code><?= e((string) $snomedMeta) ?></code></span>
                                    <?php endif; ?>
                                </div>
                                <?php if (!empty($item['related_codes']) && is_array($item['related_codes'])): ?>
                                    <div class="search-result-meta">
                                        <?php foreach (array_slice($item['related_codes'], 0, 5) as $rel): ?>
                                            <?php if (!is_array($rel)) { continue; } ?>
                                            <span><code><?= e((string) ($rel['system'] ?? '')) ?>: <?= e((string) ($rel['code'] ?? '')) ?></code></span>
                                        <?php endforeach; ?>
                                    </div>
                                <?php endif; ?>
                            </li>
                        <?php endforeach; ?>
                    </ul>
                <?php endif; ?>
            <?php endif; ?>

            <p class="search-links">
                <a href="/"><?= e($t('search.back_home')) ?></a>
                <a href="/docs"><?= e($t('search.docs_link')) ?></a>
            </p>
        </div>
    </section>
</main>

<footer class="site-footer">
    <div class="container footer-bottom">
        <p><?= e($t('footer.rights', ['%year%' => date('Y')])) ?></p>
        <p class="disclaimer"><?= e($t('footer.disclaimer')) ?></p>
    </div>
</footer>
</body>
</html>
