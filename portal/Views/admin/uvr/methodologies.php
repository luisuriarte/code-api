<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $methodologies */

require __DIR__ . '/_nav.php';
?>
<article class="admin-box">
    <h2><?= e($t('admin.uvr.f')) ?></h2>
    <p><?= e($t('admin.uvr.methodologies_note')) ?></p>
    <?php if ($methodologies === []): ?>
        <p><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead>
                <tr>
                    <th><?= e($t('admin.uvr.methodology')) ?></th>
                    <th><?= e($t('admin.uvr.version_tag')) ?></th>
                    <th><?= e($t('admin.uvr.col_valuations')) ?></th>
                    <th><?= e($t('admin.uvr.col_source')) ?></th>
                    <th><?= e($t('admin.uvr.col_status')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($methodologies as $methodology): ?>
                    <tr>
                        <td><?= e((string) $methodology['methodology']) ?></td>
                        <td><?= e((string) $methodology['version_tag']) ?></td>
                        <td><?= (int) $methodology['count'] ?></td>
                        <td><?= e((string) $methodology['source_reference']) ?></td>
                        <td><code><?= e((string) $methodology['review_status']) ?></code></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
