<?php

declare(strict_types=1);

$columns = is_array($compareItems) ? array_values($compareItems) : [];
?>
<section class="browse-compare" aria-label="<?= e($t('browse.compare_title')) ?>">
    <div class="browse-compare__head">
        <h3><?= e($t('browse.compare_title')) ?></h3>
        <p class="form-note"><?= e($t('browse.comparison_descriptive')) ?></p>
    </div>

    <?php if (count($columns) < 2): ?>
        <p class="browse-empty"><?= e($t('browse.compare_empty')) ?></p>
    <?php else: ?>
        <div class="browse-table-wrap">
            <table class="browse-table browse-compare-table">
                <thead>
                    <tr>
                        <th scope="col"><?= e($t('browse.compare_legend')) ?></th>
                        <?php foreach ($columns as $column): ?>
                            <?php
                            $columnItem = is_array($column['item'] ?? null) ? $column['item'] : [];
                            $columnKey = (string) ($column['key'] ?? '');
                            $columnCode = (string) ($columnItem['code'] ?? '');
                            $columnTerm = (string) ($columnItem['term'] ?? '');
                            ?>
                            <th scope="col">
                                <a href="<?= e($stableItemUrl($columnKey)) ?>">
                                    <?= e($columnTerm !== '' ? $columnTerm : $columnCode) ?>
                                </a>
                                <?php if ($columnCode !== ''): ?>
                                    <span class="code-pill"><?= e($columnCode) ?></span>
                                <?php endif; ?>
                                <a class="browse-compare-remove"
                                   href="<?= e($removeCompareUrl($columnKey)) ?>"
                                   title="<?= e($t('browse.compare_remove')) ?>"
                                   aria-label="<?= e($t('browse.compare_remove')) ?>">×</a>
                            </th>
                        <?php endforeach; ?>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($compareFields as $field): ?>
                        <tr>
                            <th scope="row"><?= e($t($field['label'])) ?></th>
                            <?php foreach ($columns as $column): ?>
                                <?php $columnItem = is_array($column['item'] ?? null) ? $column['item'] : []; ?>
                                <td><?= e($formatValue($columnItem[$field['key']] ?? '')) ?></td>
                            <?php endforeach; ?>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</section>
