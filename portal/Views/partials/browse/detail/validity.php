<?php

declare(strict_types=1);

$validity = is_array($sections['validity'] ?? null) ? $sections['validity'] : [];
?>
<div class="browse-subsection">
    <p class="form-note"><?= e($t('browse.validity_note')) ?></p>
    <?php if ($validity === []): ?>
        <p class="browse-empty"><?= e($t('browse.no_validity')) ?></p>
    <?php else: ?>
        <div class="browse-table-wrap">
            <table class="browse-table">
                <thead>
                    <tr>
                        <th scope="col"><?= e($t('browse.validity_release')) ?></th>
                        <th scope="col"><?= e($t('browse.validity_version')) ?></th>
                        <th scope="col"><?= e($t('browse.validity_status')) ?></th>
                        <th scope="col"><?= e($t('browse.validity_from')) ?></th>
                        <th scope="col"><?= e($t('browse.validity_to')) ?></th>
                        <th scope="col"><?= e($t('browse.validity_language')) ?></th>
                        <th scope="col"><?= e($t('browse.approval_state')) ?></th>
                        <th scope="col"><?= e($t('browse.validity_norm')) ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($validity as $version): ?>
                        <?php if (!is_array($version)): ?>
                            <?php continue; ?>
                        <?php endif; ?>
                        <?php $current = $isCurrentValidity($version); ?>
                        <tr>
                            <td>
                                <span class="browse-badge <?= $current ? 'browse-badge--current' : 'browse-badge--historical' ?>">
                                    <?= e($current ? $t('browse.current') : $t('browse.historical')) ?>
                                </span>
                                <span><?= e((string) ($version['release_id'] ?? '')) ?></span>
                            </td>
                            <td><?= e((string) ($version['version'] ?? '')) ?></td>
                            <td><?= e((string) ($version['release_status'] ?? '')) ?></td>
                            <td><?= e((string) ($version['release_valid_from'] ?? '')) ?></td>
                            <td><?= e((string) ($version['release_valid_to'] ?? '')) ?></td>
                            <td><?= e((string) ($version['language'] ?? '')) ?></td>
                            <td><?= e($reviewLabel((string) ($version['review_status'] ?? ''))) ?></td>
                            <td><?= e((string) ($version['normative'] ?? '')) ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</div>
