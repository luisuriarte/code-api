<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\BrowseService;

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
                        <details class="browse-diagram__group" <?= count($entries) <= 3 ? 'open' : '' ?>>
                            <summary class="browse-diagram__system">
                                <?= e($system !== '' ? (string) $system : $t('browse.relation_system')) ?>
                                <span class="browse-diagram__count"><?= count($entries) ?></span>
                            </summary>
                            <div class="browse-diagram__nodes">
                            <?php foreach ($entries as $relation): ?>
                                <?php
                                $type = (string) ($relation['type'] ?? '');
                                $status = (string) ($relation['review_status'] ?? '');
                                $pending = in_array($status, $pendingReviews, true);
                                $targetKey = BrowseService::normalizeResultKey($relation['result_key'] ?? '');
                                $nodeTag = $targetKey !== '' ? 'a' : 'div';
                                $nodeAttrs = $targetKey !== ''
                                    ? ' href="' . e($stableItemUrl($targetKey)) . '" data-focus-url="' . e($fragmentUrl($targetKey)) . '"'
                                    : '';
                                ?>
                                <<?= $nodeTag ?> class="browse-diagram__node"<?= $nodeAttrs ?>>
                                    <strong><?= e((string) ($relation['code'] ?? '')) ?></strong>
                                    <?php if (!empty($relation['display'])): ?>
                                        <span><?= e((string) $relation['display']) ?></span>
                                    <?php endif; ?>
                                    <span class="browse-badge<?= $pending ? ' browse-badge--pending' : ' browse-badge--neutral' ?>">
                                        <?= e($relationTypeLabel($type)) ?>
                                    </span>
                                </<?= $nodeTag ?>>
                            <?php endforeach; ?>
                            </div>
                        </details>
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
                            $targetKey = BrowseService::normalizeResultKey($relation['result_key'] ?? '');
                            ?>
                            <tr>
                                <td><?= e((string) ($relation['system'] ?? '')) ?></td>
                                <td>
                                    <?php if ($targetKey !== ''): ?>
                                        <a class="browse-relations-link"
                                           href="<?= e($stableItemUrl($targetKey)) ?>"
                                           data-focus-url="<?= e($fragmentUrl($targetKey)) ?>"
                                           data-result-key="<?= e($targetKey) ?>">
                                            <strong><?= e((string) ($relation['code'] ?? '')) ?></strong>
                                        </a>
                                    <?php else: ?>
                                        <strong><?= e((string) ($relation['code'] ?? '')) ?></strong>
                                    <?php endif; ?>
                                </td>
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
