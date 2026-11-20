<?php

declare(strict_types=1);

/** @var array<string, mixed> $current */
?>
<section class="space-y-6">
    <div class="ui-card ui-card-pad">
        <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
                <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-teal-dark"><?= e($t('admin.brand')) ?></p>
                <h1 class="ui-title"><?= e($t('admin.home.title')) ?></h1>
                <p class="ui-subtitle"><?= e($t('admin.home.welcome', ['%name%' => $current['user']['full_name']])) ?></p>
            </div>
            <span class="flex h-12 w-12 items-center justify-center rounded-2xl bg-mint text-teal-dark">
                <i data-lucide="layout-dashboard" class="h-6 w-6"></i>
            </span>
        </div>

        <?php if (!$m1Applied): ?>
        <div class="ui-alert mt-5 border-red-200 bg-red-50 text-red-800" role="alert">
            <div class="flex items-start gap-3">
                <i data-lucide="circle-alert" class="mt-0.5 h-4 w-4 shrink-0"></i>
                <p class="font-medium"><?= e($t('admin.home.m1_pending')) ?></p>
            </div>
        </div>
        <?php endif; ?>
    </div>

    <div class="ui-grid">
        <article class="ui-card ui-card-pad">
            <div class="mb-4 flex items-center gap-3">
                <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-mint text-teal-dark">
                    <i data-lucide="badge-check" class="h-4 w-4"></i>
                </span>
                <h2 class="text-base font-semibold text-ink"><?= e($t('admin.home.identity')) ?></h2>
            </div>
            <dl class="ui-dl">
                <dt class="ui-dt"><?= e($t('admin.email')) ?></dt>
                <dd class="ui-dd"><?= e($current['user']['email']) ?></dd>
                <dt class="ui-dt"><?= e($t('admin.home.status')) ?></dt>
                <dd class="ui-dd"><span class="ui-badge"><?= e($current['user']['status']) ?></span></dd>
            </dl>
        </article>

        <article class="ui-card ui-card-pad">
            <div class="mb-4 flex items-center gap-3">
                <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-mint text-teal-dark">
                    <i data-lucide="users" class="h-4 w-4"></i>
                </span>
                <h2 class="text-base font-semibold text-ink"><?= e($t('admin.home.roles')) ?></h2>
            </div>
            <?php if ($current['roles'] === []): ?>
            <p class="ui-empty"><?= e($t('admin.home.no_roles')) ?></p>
            <?php else: ?>
            <ul class="space-y-2">
                <?php foreach ($current['roles'] as $role): ?>
                <li class="flex items-center justify-between gap-3 rounded-lg bg-paper px-3 py-2 text-sm">
                    <span class="font-medium text-ink"><?= e($role['name']) ?></span>
                    <code class="ui-code"><?= e($role['code']) ?></code>
                </li>
                <?php endforeach; ?>
            </ul>
            <?php endif; ?>
        </article>

        <article class="ui-card ui-card-pad">
            <div class="mb-4 flex items-center gap-3">
                <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-mint text-teal-dark">
                    <i data-lucide="key-round" class="h-4 w-4"></i>
                </span>
                <h2 class="text-base font-semibold text-ink"><?= e($t('admin.home.permissions')) ?></h2>
            </div>
            <?php if ($current['permissions'] === []): ?>
            <p class="ui-empty"><?= e($t('admin.home.no_permissions')) ?></p>
            <?php else: ?>
            <div class="flex flex-wrap gap-2">
                <?php foreach ($current['permissions'] as $permission): ?>
                <code class="ui-code"><?= e($permission) ?></code>
                <?php endforeach; ?>
            </div>
            <?php endif; ?>
        </article>

        <article class="ui-card ui-card-pad">
            <div class="mb-4 flex items-center gap-3">
                <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-mint text-teal-dark">
                    <i data-lucide="library" class="h-4 w-4"></i>
                </span>
                <h2 class="text-base font-semibold text-ink"><?= e($t('admin.home.scope')) ?></h2>
            </div>
            <?php if ($current['grants'] === []): ?>
            <p class="ui-empty"><?= e($t('admin.home.no_grants')) ?></p>
            <?php else: ?>
            <ul class="space-y-2">
                <?php foreach ($current['grants'] as $grant): ?>
                <li class="flex flex-wrap items-center gap-2 rounded-lg bg-paper px-3 py-2 text-sm">
                    <code class="ui-code"><?= e($grant['catalog_code']) ?></code>
                    <span class="text-muted">·</span>
                    <span class="text-ink-soft"><?= e($grant['operation']) ?></span>
                    <span class="ml-auto <?= $grant['allowed'] ? 'text-teal-dark' : 'text-red-700' ?>">
                        <?= $grant['allowed'] ? e($t('admin.home.allowed')) : e($t('admin.home.denied')) ?>
                    </span>
                </li>
                <?php endforeach; ?>
            </ul>
            <?php endif; ?>
        </article>
    </div>

    <p class="rounded-xl border border-line bg-white px-4 py-3 text-sm text-muted">
        <i data-lucide="info" class="mr-2 inline h-4 w-4 align-[-2px] text-teal-dark"></i>
        <?= e($t('admin.home.next')) ?>
    </p>
</section>
