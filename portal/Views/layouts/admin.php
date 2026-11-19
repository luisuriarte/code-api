<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\Csrf;
use OrigenSalud\Web\I18n;

$adminAssetRoot = dirname(__DIR__, 3) . '/web';
$adminCss = '/assets/css/app.css';
$adminCssFile = $adminAssetRoot . $adminCss;
$adminCssVersion = is_file($adminCssFile) ? @filemtime($adminCssFile) : false;
$adminCssHref = $adminCssVersion === false
    ? $adminCss
    : $adminCss . '?v=' . $adminCssVersion;
?>
<!doctype html>
<html lang="<?= e($locale) ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title><?= e($pageTitle) ?></title>
    <meta name="description" content="<?= e($pageDescription) ?>">
    <link rel="stylesheet" href="<?= e($adminCssHref) ?>">
</head>
<body class="admin-body">
<a class="skip-link" href="#main"><?= e($t('a11y.skip')) ?></a>
<header class="admin-header">
    <div class="container admin-header-inner">
        <span class="admin-brand">Origen Salud <small><?= e($t('admin.brand')) ?></small></span>
        <?php if (!empty($adminUser)): ?>
        <nav class="admin-nav" aria-label="<?= e($t('admin.nav')) ?>">
            <a href="/admin"><?= e($t('admin.home.title')) ?></a>
            <a href="/admin/audit"><?= e($t('admin.audit.title')) ?></a>
        </nav>
        <form method="post" action="/admin/logout" class="admin-logout">
            <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e(Csrf::token()) ?>">
            <button type="submit" class="button button-small"><?= e($t('admin.logout')) ?></button>
        </form>
        <?php endif; ?>
        <div class="admin-langs" aria-label="<?= e($t('lang.label')) ?>">
            <?php
            $adminPath = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/admin'), PHP_URL_PATH);
            $adminPath = is_string($adminPath) && $adminPath !== '' ? $adminPath : '/admin';
            $adminQuery = $_GET;
            foreach (I18n::SUPPORTED as $adminLocale):
                $adminQuery['lang'] = $adminLocale;
                $adminHref = $adminPath . '?' . http_build_query($adminQuery, '', '&', PHP_QUERY_RFC3986);
            ?>
            <a href="<?= e($adminHref) ?>" hreflang="<?= e($adminLocale) ?>" <?= $adminLocale === $locale ? 'aria-current="true"' : '' ?>><?= e(strtoupper($adminLocale)) ?></a>
            <?php endforeach; ?>
        </div>
    </div>
</header>
<main id="main" class="admin-main container">
    <?= $content ?>
</main>
<footer class="admin-footer">
    <div class="container">Origen Salud — <?= e($t('admin.footer')) ?></div>
</footer>
</body>
</html>
