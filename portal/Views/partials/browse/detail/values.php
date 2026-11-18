<?php

declare(strict_types=1);

$values = is_array($sections['values'] ?? null) ? $sections['values'] : [];
?>
<div class="browse-subsection">
    <p class="form-note"><?= e($t('browse.values_note')) ?></p>
    <?php if ($values === []): ?>
        <p class="browse-empty"><?= e($t('browse.no_values')) ?></p>
    <?php else: ?>
        <div class="browse-table-wrap">
            <table class="browse-table">
                <thead>
                    <tr>
                        <th scope="col"><?= e($t('browse.value_schedule')) ?></th>
                        <th scope="col"><?= e($t('browse.value_unit')) ?></th>
                        <th scope="col"><?= e($t('browse.value_units')) ?></th>
                        <th scope="col"><?= e($t('browse.value_fixed_price')) ?></th>
                        <th scope="col"><?= e($t('browse.value_expenses')) ?></th>
                        <th scope="col"><?= e($t('browse.value_unit_value')) ?></th>
                        <th scope="col"><?= e($t('browse.value_currency')) ?></th>
                        <th scope="col"><?= e($t('browse.value_period')) ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($values as $value): ?>
                        <?php if (!is_array($value)): ?>
                            <?php continue; ?>
                        <?php endif; ?>
                        <tr>
                            <td><?= e((string) ($value['schedule'] ?? '')) ?></td>
                            <td>
                                <?php
                                $unit = trim(
                                    (string) ($value['unit_code'] ?? '') . ' ' . (string) ($value['unit_name'] ?? '')
                                );
                                ?>
                                <?= e($unit) ?>
                            </td>
                            <td><?= e((string) ($value['units'] ?? '')) ?></td>
                            <td><?= e((string) ($value['fixed_price'] ?? '')) ?></td>
                            <td><?= e((string) ($value['expenses'] ?? '')) ?></td>
                            <td><?= e((string) ($value['unit_monetary_value'] ?? '')) ?></td>
                            <td><?= e((string) ($value['currency'] ?? '')) ?></td>
                            <td>
                                <?php if (!empty($value['current'])): ?>
                                    <span class="browse-badge browse-badge--current"><?= e($t('browse.current')) ?></span>
                                <?php else: ?>
                                    <span class="browse-badge browse-badge--historical"><?= e($t('browse.historical')) ?></span>
                                <?php endif; ?>
                                <span><?= e(trim((string) ($value['valid_from'] ?? '') . ' — ' . (string) ($value['valid_to'] ?? ''))) ?></span>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</div>
