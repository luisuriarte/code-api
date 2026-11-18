<?php

declare(strict_types=1);
?>
<section class="browse-history" aria-label="<?= e($t('browse.history_title')) ?>">
    <h3><?= e($t('browse.history_title')) ?></h3>
    <?php if ($historyDisplay === []): ?>
        <p class="browse-empty"><?= e($t('browse.history_empty')) ?></p>
    <?php else: ?>
        <ul class="browse-history-list">
            <?php foreach ($historyDisplay as $historyKey): ?>
                <?php
                $historyKey = (string) $historyKey;
                if ($historyKey === '') {
                    continue;
                }
                $isCurrent = $historyKey === $focus;
                ?>
                <li>
                    <a class="browse-history-link<?= $isCurrent ? ' is-current' : '' ?>"
                       href="<?= e($stableItemUrl($historyKey)) ?>"
                       <?= $isCurrent ? 'aria-current="true"' : '' ?>>
                        <?= e($historyKey) ?>
                    </a>
                </li>
            <?php endforeach; ?>
        </ul>
    <?php endif; ?>
</section>
