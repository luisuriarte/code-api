<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $tasks */

require __DIR__ . '/_nav.php';
?>
<article class="ui-card ui-card-pad">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
        <div>
            <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.uvr.d')) ?></h2>
            <p class="ui-subtitle"><?= e($t('admin.uvr.tasks_note')) ?></p>
        </div>
        <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-mint text-teal-dark">
            <i data-lucide="list-todo" class="h-5 w-5"></i>
        </span>
    </div>

    <?php if ($tasks === []): ?>
        <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="ui-table-wrap">
            <table class="ui-table">
                <thead>
                <tr>
                    <th class="ui-th"><?= e($t('admin.uvr.col_id')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_subject')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_request_type')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_pending')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_actor')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_status')) ?></th>
                </tr>
                </thead>
                <tbody class="divide-y divide-line">
                <?php foreach ($tasks as $task): ?>
                    <tr class="transition hover:bg-paper/60">
                        <td class="ui-td">
                            <a href="/admin/uvr/proposals/<?= (int) $task['request_id'] ?>" class="font-semibold no-underline">
                                <?= (int) $task['request_id'] ?>
                            </a>
                        </td>
                        <td class="ui-td"><code class="ui-code"><?= e((string) ($task['subject_id'] ?? '')) ?></code></td>
                        <td class="ui-td"><?= e((string) ($task['request_type'] ?? '')) ?></td>
                        <td class="ui-td"><span class="ui-badge"><?= (int) $task['pending_reviews'] ?></span></td>
                        <td class="ui-td"><?= e((string) ($task['requested_by'] ?? '')) ?></td>
                        <td class="ui-td"><code class="ui-code"><?= e((string) ($task['review_status'] ?? '')) ?></code></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
