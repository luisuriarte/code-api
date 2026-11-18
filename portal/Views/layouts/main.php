<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

?>
<!doctype html>
<html lang="<?= e($locale) ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($pageTitle) ?></title>
    <meta name="description" content="<?= e($pageDescription) ?>">
    <link rel="canonical" href="<?= e($baseUrl . $currentPath) ?>">
    <?php foreach (I18n::alternateLinks($currentPath, $baseUrl) as $alternate): ?>
    <link rel="alternate" hreflang="<?= e($alternate['hreflang']) ?>" href="<?= e($alternate['href']) ?>">
    <?php endforeach; ?>
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="Origen Salud">
    <meta property="og:url" content="<?= e($baseUrl . $currentPath) ?>">
    <meta property="og:title" content="<?= e($pageTitle) ?>">
    <meta property="og:description" content="<?= e($pageDescription) ?>">
    <meta property="og:locale" content="<?= e(I18n::metadata($locale)['og_locale']) ?>">
    <meta name="twitter:card" content="summary">
    <meta name="twitter:title" content="<?= e($pageTitle) ?>">
    <meta name="twitter:description" content="<?= e($pageDescription) ?>">
    <?php if (!empty($structuredData)): ?>
    <script type="application/ld+json"><?= json_encode($structuredData, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?></script>
    <?php endif; ?>
    <?php
    // Cache busting por fecha de modificación: evita que un CSS/JS viejo quede
    // sirviéndose desde el navegador o la CDN después de publicar cambios.
    $assetRoot = dirname(__DIR__, 3) . '/web';
    $assetUrl = static function (string $path) use ($assetRoot): string {
        $file = $assetRoot . $path;
        $version = is_file($file) ? @filemtime($file) : false;

        if ($version === false) {
            return $path;
        }

        return $path . (strpos($path, '?') === false ? '?' : '&') . 'v=' . $version;
    };
    ?>
    <link rel="stylesheet" href="<?= e($assetUrl('/assets/css/app.css')) ?>">
    <?php foreach ((array) ($scripts ?? []) as $script): ?>
    <script src="<?= e($assetUrl((string) $script)) ?>" defer></script>
    <?php endforeach; ?>
</head>
<body<?= isset($bodyClass) && $bodyClass !== '' ? ' class="' . e($bodyClass) . '"' : '' ?>>
<a class="skip-link" href="#main"><?= e($t('a11y.skip')) ?></a>
<?php require __DIR__ . '/../partials/header.php'; ?>
<main id="main">
    <?= $content ?>
</main>
<?php require __DIR__ . '/../partials/footer.php'; ?>
</body>
</html>
