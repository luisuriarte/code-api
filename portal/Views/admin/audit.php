<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $events */
?>
<section class="space-y-6">
    <div class="ui-card ui-card-pad">
        <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
                <h1 class="ui-title"><?= e($t('admin.audit.title')) ?></h1>
                <p class="ui-subtitle"><?= e($t('admin.audit.lead')) ?></p>
            </div>
            <span class="flex h-12 w-12 items-center justify-center rounded-2xl bg-mint text-teal-dark">
                <i data-lucide="scroll-text" class="h-6 w-6"></i>
            </span>
        </div>
    </div>

    <article class="ui-card ui-card-pad">
        <?php if ($events === []): ?>
            <p class="ui-empty"><?= e($t('admin.audit.empty')) ?></p>
        <?php else: ?>
            <div class="ui-table-wrap">
                <table class="ui-table">
                    <thead>
                    <tr>
                        <th class="ui-th"><?= e($t('admin.audit.when')) ?></th>
                        <th class="ui-th"><?= e($t('admin.audit.actor')) ?></th>
                        <th class="ui-th"><?= e($t('admin.audit.action')) ?></th>
                        <th class="ui-th"><?= e($t('admin.audit.detail')) ?></th>
                    </tr>
                    </thead>
                    <tbody class="divide-y divide-line">
                    <?php foreach ($events as $event): ?>
                        <tr class="transition hover:bg-paper/60">
                            <td class="ui-td text-xs"><?= e((string) ($event['occurred_at'] ?? '')) ?></td>
                            <td class="ui-td"><?= e((string) ($event['actor_email'] ?? '')) ?></td>
                            <td class="ui-td"><code class="ui-code"><?= e((string) ($event['action'] ?? '')) ?></code></td>
                            <td class="ui-td"><?= e((string) ($event['reason'] ?? ($event['catalog_code'] ?? ''))) ?></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php endif; ?>
    </article>
</section>
