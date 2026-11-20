<?php

declare(strict_types=1);

use OrigenSalud\Portal\Admin\Rbac;
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
        <?php
        $adminPermissions = is_array($current['permissions'] ?? null) ? $current['permissions'] : [];
        $adminContexts = is_array($current['contexts'] ?? null) ? $current['contexts'] : [];
        $adminActiveOrg = $current['active_org_id'] ?? null;
        $adminNext = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/admin'), PHP_URL_PATH);
        $adminNext = is_string($adminNext) && $adminNext !== '' ? $adminNext : '/admin';
        ?>
        <nav class="admin-nav" aria-label="<?= e($t('admin.nav')) ?>">
            <a href="/admin"><?= e($t('admin.home.title')) ?></a>
            <?php if (Rbac::hasPermission($adminPermissions, 'catalog.view')): ?>
            <a href="/admin/uvr"><?= e($t('admin.uvr.title')) ?></a>
            <?php endif; ?>
            <?php if (Rbac::hasPermission($adminPermissions, 'admin.orgs.manage')): ?>
            <a href="/admin/organizations"><?= e($t('admin.orgs.title')) ?></a>
            <?php endif; ?>
            <?php if (Rbac::hasPermission($adminPermissions, 'admin.invites.manage')): ?>
            <a href="/admin/invitations"><?= e($t('admin.invites.title')) ?></a>
            <?php endif; ?>
            <?php if (Rbac::hasPermission($adminPermissions, 'audit.view')): ?>
            <a href="/admin/audit"><?= e($t('admin.audit.title')) ?></a>
            <?php endif; ?>
        </nav>
        <?php if (count($adminContexts) > 1): ?>
        <form method="post" action="/admin/context" class="admin-context">
            <label for="admin-context-select"><?= e($t('admin.context.label')) ?></label>
            <select id="admin-context-select" name="organization_id"
                    onchange="this.form.submit()">
                <?php foreach ($adminContexts as $context): ?>
                    <option value="<?= $context['id'] === null ? '' : (int) $context['id'] ?>"
                        <?= $context['id'] === $adminActiveOrg ? 'selected' : '' ?>>
                        <?= e((string) $context['name']) ?>
                    </option>
                <?php endforeach; ?>
            </select>
            <input type="hidden" name="next" value="<?= e($adminNext) ?>">
            <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e(Csrf::token()) ?>">
            <button type="submit" class="button button-small"><?= e($t('admin.context.switch')) ?></button>
        </form>
        <?php endif; ?>
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
