<?php

declare(strict_types=1);

$uvrPublished = is_array($sections['uvr'] ?? null) ? $sections['uvr'] : [];
?>
<div class="browse-subsection browse-uvr-published">
    <h3 class="browse-subsection__title"><?= e($t('browse.uvr_published_title')) ?></h3>
    <p class="form-note"><?= e($t('browse.uvr_published_note')) ?></p>
    <div class="browse-table-wrap">
        <table class="browse-table">
            <thead>
            <tr>
                <th scope="col"><?= e($t('browse.uvr_published_profile')) ?></th>
                <th scope="col"><?= e($t('browse.uvr_published_components')) ?></th>
                <th scope="col"><?= e($t('browse.uvr_published_total')) ?></th>
                <th scope="col"><?= e($t('browse.uvr_published_importe')) ?></th>
                <th scope="col"><?= e($t('browse.uvr_published_validity')) ?></th>
            </tr>
            </thead>
            <tbody>
            <?php foreach ($uvrPublished as $valuation): ?>
                <?php if (!is_array($valuation)) { continue; } ?>
                <?php
                $importe = $valuation['importe_referencial'] ?? null;
                $currency = trim((string) ($valuation['currency'] ?? ''));
                $validFrom = trim((string) ($valuation['valid_from'] ?? ''));
                $validTo = trim((string) ($valuation['valid_to'] ?? ''));
                // El modelo transversal muestra el código de prestación y el
                // legacy el permanente del ítem (DNT-PR-000001).
                $uvrCode = trim((string) ($valuation['prestacion_code'] ?? ''));
                if ($uvrCode === '') {
                    $uvrCode = trim((string) ($valuation['external_code'] ?? ''));
                }
                if ($uvrCode === '') {
                    $uvrCode = trim((string) ($valuation['profile_code'] ?? ''));
                }
                ?>
                <tr>
                    <td>
                        <span class="browse-badge browse-badge--current">
                            <?= e($uvrCode) ?>
                            <?= (string) ($valuation['version_tag'] ?? '') !== ''
                                ? ' · ' . e((string) $valuation['version_tag'])
                                : '' ?>
                        </span>
                        <?php if ((string) ($valuation['methodology'] ?? '') !== ''): ?>
                            <span class="form-note">
                                <?= e((string) $valuation['methodology']) ?>
                            </span>
                        <?php endif; ?>
                    </td>
                    <td>
                        <span class="block text-xs">
                            <?= e($t('browse.uvr_work')) ?>: <?= e($formatNumber($valuation['work_uvr'] ?? 0)) ?>
                            · <?= e($t('browse.uvr_practice')) ?>: <?= e($formatNumber($valuation['practice_expense_uvr'] ?? 0)) ?>
                            · <?= e($t('browse.uvr_liability')) ?>: <?= e($formatNumber($valuation['professional_liability_uvr'] ?? 0)) ?>
                        </span>
                    </td>
                    <td><strong><?= e($formatNumber($valuation['total_uvr'] ?? 0)) ?></strong></td>
                    <td>
                        <?php if ($importe === null || $importe === ''): ?>
                            <span class="text-muted"><?= e($t('browse.uvr_published_no_conversion')) ?></span>
                        <?php else: ?>
                            <span><?= e($formatNumber($importe) . ($currency !== '' ? ' ' . $currency : '')) ?></span>
                        <?php endif; ?>
                    </td>
                    <td><?= e(trim($validFrom . ' — ' . $validTo)) ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
