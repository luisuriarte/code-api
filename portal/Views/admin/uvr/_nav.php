<?php

declare(strict_types=1);

require dirname(__DIR__, 2) . '/partials/format.php';

/** @var string $section */
$uvrTabs = [
    'A' => ['/admin/uvr', 'admin.uvr.a', 'table-properties'],
    'B' => ['/admin/uvr/catalogs', 'admin.uvr.b', 'library'],
    'C' => ['/admin/uvr/proposals', 'admin.uvr.c', 'file-plus-2'],
    'D' => ['/admin/uvr/tasks', 'admin.uvr.d', 'list-todo'],
    'E' => ['/admin/uvr/compare', 'admin.uvr.e', 'git-compare-arrows'],
    'F' => ['/admin/uvr/methodologies', 'admin.uvr.f', 'book-open'],
    'G' => ['/admin/uvr/monetary', 'admin.uvr.g', 'circle-dollar-sign'],
];
?>
<section class="space-y-6">
    <div class="ui-card ui-card-pad">
        <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
                <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-teal-dark">UVR</p>
                <h1 class="ui-title"><?= e($t('admin.uvr.title')) ?></h1>
                <p class="ui-subtitle"><?= e($t('admin.uvr.lead')) ?></p>
            </div>
            <span class="ui-badge">A — G</span>
        </div>

        <nav class="mt-6 flex gap-1 overflow-x-auto border-b border-line"
             aria-label="<?= e($t('admin.uvr.nav')) ?>">
            <?php foreach ($uvrTabs as $code => $tab): ?>
                <?php $active = $section === $code; ?>
                <a href="<?= e($tab[0]) ?>"
                   class="flex shrink-0 items-center gap-2 border-b-2 px-3 py-2.5 text-sm font-medium no-underline transition <?= $active ? 'border-teal text-teal-dark' : 'border-transparent text-muted hover:border-line hover:text-ink' ?>"
                   <?= $active ? 'aria-current="page"' : '' ?>>
                    <i data-lucide="<?= e($tab[2]) ?>" class="h-4 w-4"></i>
                    <?= e($t($tab[1])) ?>
                </a>
            <?php endforeach; ?>
        </nav>
    </div>

    <?php require dirname(__DIR__) . '/_flash.php'; ?>
