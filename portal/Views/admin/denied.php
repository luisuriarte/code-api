<?php

declare(strict_types=1);
?>
<section class="mx-auto flex min-h-[70vh] max-w-lg flex-col justify-center py-6">
    <div class="ui-card ui-card-pad text-center">
        <span class="mx-auto mb-5 flex h-14 w-14 items-center justify-center rounded-2xl bg-red-50 text-red-700">
            <i data-lucide="lock-keyhole" class="h-7 w-7"></i>
        </span>
        <h1 class="ui-title"><?= e($t('admin.denied.title')) ?></h1>
        <p class="ui-subtitle"><?= e($t('admin.denied.text')) ?></p>
        <a href="/admin" class="ui-btn mt-6">
            <i data-lucide="arrow-left" class="h-4 w-4"></i>
            <?= e($t('admin.home.title')) ?>
        </a>
    </div>
</section>
