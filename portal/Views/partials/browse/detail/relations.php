<?php

declare(strict_types=1);

$relations = is_array($sections['relations'] ?? null) ? $sections['relations'] : [];
$groups = [];
foreach ($relations as $relation) {
    if (!is_array($relation)) {
        continue;
    }
    $system = (string) ($relation['system'] ?? '');
    $groups[$system][] = $relation;
}
$codeLabel = is_array($item) ? (string) ($item['code'] ?? '') : '';
$termLabel = is_array($item) ? (string) ($item['term'] ?? '') : '';
?>
<div class="browse-subsection">
    <?php if ($relations === []): ?>
        <p class="browse-empty"><?= e($t('browse.no_relations')) ?></p>
    <?php else: ?>
        <div class="browse-relswitch" role="group" aria-label="<?= e($t('browse.tab_relations')) ?>">
            <?php foreach (['table', 'diagram'] as $view): ?>
                <?php $isActive = $view === $relView; ?>
                <a class="browse-relswitch__link<?= $isActive ? ' is-active' : '' ?>"
                   href="<?= e($relViewUrl($view)) ?>"
                   data-rel-view="<?= e($view) ?>"
                   data-url="<?= e($relViewFragmentUrl($view)) ?>"
                   data-stable-url="<?= e($relViewUrl($view)) ?>"
                   aria-pressed="<?= $isActive ? 'true' : 'false' ?>">
                    <?= e($t('browse.rel_' . $view)) ?>
                </a>
            <?php endforeach; ?>
        </div>

        <?php if ($relView === 'diagram'): ?>
            <div class="browse-diagram browse-relations-diagram">
                <div class="browse-diagram__node browse-diagram__node--center">
                    <strong><?= e($termLabel !== '' ? $termLabel : $codeLabel) ?></strong>
                    <?php if ($codeLabel !== ''): ?><span class="code-pill"><?= e($codeLabel) ?></span><?php endif; ?>
                </div>
                <div class="browse-diagram__groups">
                    <?php foreach ($groups as $system => $entries): ?>
                        <div class="browse-diagram__group">
                            <div class="browse-diagram__system">
                                <?= e($system !== '' ? (string) $system : $t('browse.relation_system')) ?>
                            </div>
                            <?php foreach ($entries as $relation): ?>
                                <?php
                                $type = (string) ($relation['type'] ?? '');
                                $status = (string) ($relation['review_status'] ?? '');
                                $pending = in_array($status, $pendingReviews, true);
                                ?>
                                <div class="browse-diagram__node">
                                    <strong><?= e((string) ($relation['code'] ?? '')) ?></strong>
                                    <?php if (!empty($relation['display'])): ?>
                                        <span><?= e((string) $relation['display']) ?></span>
                                    <?php endif; ?>
                                    <span class="browse-badge<?= $pending ? ' browse-badge--pending' : ' browse-badge--neutral' ?>">
                                        <?= e($relationTypeLabel($type)) ?>
                                    </span>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    <?php endforeach; ?>
                </div>
            </div>
        <?php else: ?>
            <div class="browse-table-wrap browse-relations-table">
                <table class="browse-table">
                    <thead>
                        <tr>
                            <th scope="col"><?= e($t('browse.relation_system')) ?></th>
                            <th scope="col"><?= e($t('browse.relation_code')) ?></th>
                            <th scope="col"><?= e($t('browse.relation_display')) ?></th>
                            <th scope="col"><?= e($t('browse.relation_type')) ?></th>
                            <th scope="col"><?= e($t('browse.relation_role')) ?></th>
                            <th scope="col"><?= e($t('browse.relation_review')) ?></th>
                            <th scope="col"><?= e($t('browse.relation_provenance')) ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($relations as $relation): ?>
                            <?php if (!is_array($relation)): ?>
                                <?php continue; ?>
                            <?php endif; ?>
                            <?php
                            $status = (string) ($relation['review_status'] ?? '');
                            $pending = in_array($status, $pendingReviews, true);
                            $badgeClass = $pending
                                ? 'browse-badge--pending'
                                : ($status === 'approved' ? 'browse-badge--current' : 'browse-badge--neutral');
                            ?>
                            <tr>
                                <td><?= e((string) ($relation['system'] ?? '')) ?></td>
                                <td><strong><?= e((string) ($relation['code'] ?? '')) ?></strong></td>
                                <td><?= e((string) ($relation['display'] ?? '')) ?></td>
                                <td><?= e($relationTypeLabel((string) ($relation['type'] ?? ''))) ?></td>
                                <td><?= e($relationRoleLabel((string) ($relation['role'] ?? ''))) ?></td>
                                <td>
                                    <span class="browse-badge <?= e($badgeClass) ?>">
                                        <?= e($status !== '' ? $reviewLabel($status) : $t('browse.review_pending')) ?>
                                    </span>
                                </td>
                                <td><?= e((string) ($relation['provenance'] ?? '')) ?></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php endif; ?>
    <?php endif; ?>
</div>
