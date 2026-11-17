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
    <meta property="og:title" content="<?= e($pageTitle) ?>">
    <meta property="og:description" content="<?= e($pageDescription) ?>">
    <meta property="og:locale" content="<?= e(I18n::metadata($locale)['og_locale']) ?>">
    <link rel="stylesheet" href="/assets/css/app.css">
</head>
<body>
<a class="skip-link" href="#main"><?= e($t('a11y.skip')) ?></a>
<?php require __DIR__ . '/../partials/header.php'; ?>
<main id="main">
    <?= $content ?>
</main>
<?php require __DIR__ . '/../partials/footer.php'; ?>
</body>
</html>
