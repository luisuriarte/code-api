<?php

declare(strict_types=1);

/** @var string $section */
$uvrTabs = [
    'A' => ['/admin/uvr', 'admin.uvr.a'],
    'B' => ['/admin/uvr/catalogs', 'admin.uvr.b'],
    'C' => ['/admin/uvr/proposals', 'admin.uvr.c'],
    'D' => ['/admin/uvr/tasks', 'admin.uvr.d'],
    'E' => ['/admin/uvr/compare', 'admin.uvr.e'],
    'F' => ['/admin/uvr/methodologies', 'admin.uvr.f'],
    'G' => ['/admin/uvr/monetary', 'admin.uvr.g'],
];
?>
<section class="admin-panel">
    <h1><?= e($t('admin.uvr.title')) ?></h1>
    <p class="admin-lead"><?= e($t('admin.uvr.lead')) ?></p>
    <nav class="admin-tabs" aria-label="<?= e($t('admin.uvr.nav')) ?>">
        <?php foreach ($uvrTabs as $code => $tab): ?>
            <a href="<?= e($tab[0]) ?>" class="<?= $section === $code ? 'active' : '' ?>"
               <?= $section === $code ? 'aria-current="page"' : '' ?>>
                <?= e($t($tab[1])) ?>
            </a>
        <?php endforeach; ?>
    </nav>
    <?php require dirname(__DIR__) . '/_flash.php'; ?>
