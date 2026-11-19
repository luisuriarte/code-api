<?php

declare(strict_types=1);

/** @var array<string, mixed> $current */
?>
<section class="admin-panel">
    <h1><?= e($t('admin.home.title')) ?></h1>
    <p class="admin-lead"><?= e($t('admin.home.welcome', ['name' => $current['user']['full_name']])) ?></p>

    <?php if (!$m1Applied): ?>
    <p class="admin-error" role="alert"><?= e($t('admin.home.m1_pending')) ?></p>
    <?php endif; ?>

    <div class="admin-grid">
        <article class="admin-box">
            <h2><?= e($t('admin.home.identity')) ?></h2>
            <dl class="admin-list">
                <dt><?= e($t('admin.email')) ?></dt><dd><?= e($current['user']['email']) ?></dd>
                <dt><?= e($t('admin.home.status')) ?></dt><dd><?= e($current['user']['status']) ?></dd>
            </dl>
        </article>

        <article class="admin-box">
            <h2><?= e($t('admin.home.roles')) ?></h2>
            <?php if ($current['roles'] === []): ?>
            <p><?= e($t('admin.home.no_roles')) ?></p>
            <?php else: ?>
            <ul>
                <?php foreach ($current['roles'] as $role): ?>
                <li><?= e($role['name']) ?> <code><?= e($role['code']) ?></code></li>
                <?php endforeach; ?>
            </ul>
            <?php endif; ?>
        </article>

        <article class="admin-box">
            <h2><?= e($t('admin.home.permissions')) ?></h2>
            <?php if ($current['permissions'] === []): ?>
            <p><?= e($t('admin.home.no_permissions')) ?></p>
            <?php else: ?>
            <ul>
                <?php foreach ($current['permissions'] as $permission): ?>
                <li><code><?= e($permission) ?></code></li>
                <?php endforeach; ?>
            </ul>
            <?php endif; ?>
        </article>

        <article class="admin-box">
            <h2><?= e($t('admin.home.scope')) ?></h2>
            <?php if ($current['grants'] === []): ?>
            <p><?= e($t('admin.home.no_grants')) ?></p>
            <?php else: ?>
            <ul>
                <?php foreach ($current['grants'] as $grant): ?>
                <li><code><?= e($grant['catalog_code']) ?></code> · <?= e($grant['operation']) ?>
                    (<?= $grant['allowed'] ? e($t('admin.home.allowed')) : e($t('admin.home.denied')) ?>)</li>
                <?php endforeach; ?>
            </ul>
            <?php endif; ?>
        </article>
    </div>

    <p class="admin-help"><?= e($t('admin.home.next')) ?></p>
</section>
