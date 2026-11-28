<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\BrowseService;

$legacyRelations = is_array($sections['relations'] ?? null) ? $sections['relations'] : [];
$classified = is_array($sections['relations_by_class'] ?? null)
    ? $sections['relations_by_class']
    : ['clinical' => [], 'terminological' => []];
$clinicalRelations = array_values(is_array($classified['clinical'] ?? null) ? $classified['clinical'] : []);
$terminologicalRelations = array_values(is_array($classified['terminological'] ?? null) ? $classified['terminological'] : []);

// La lista plana sigue siendo el respaldo de datos históricos. Cuando existe
// la proyección separada, nunca se mezclan ambas clases en una sola sección.
if ($clinicalRelations === [] && $terminologicalRelations === [] && $legacyRelations !== []) {
    $classBlocks = ['all' => $legacyRelations];
} else {
    $classBlocks = [
        'clinical' => $clinicalRelations,
        'terminological' => $terminologicalRelations,
    ];
}

$allRelations = [];
$groups = [];
foreach ($classBlocks as $class => $classRelations) {
    foreach ($classRelations as $relation) {
        if (!is_array($relation)) {
            continue;
        }
        $allRelations[] = $relation;
        $system = (string) ($relation['system'] ?? '');
        $groups[$class][$system][] = $relation;
    }
}

$codeLabel = is_array($item) ? (string) ($item['code'] ?? '') : '';
$termLabel = is_array($item) ? (string) ($item['term'] ?? '') : '';
$relationTypes = [];
$relationSystems = [];
foreach ($allRelations as $relation) {
    $type = (string) ($relation['type'] ?? '');
    $system = (string) ($relation['system'] ?? '');
    if ($type !== '') {
        $relationTypes[$type] = $relationTypeLabel($type);
    }
    if ($system !== '') {
        $relationSystems[$system] = $identifierSystemLabel($system);
    }
}
asort($relationTypes);
ksort($relationSystems);
?>
<div class="browse-subsection">
    <?php if ($allRelations === []): ?>
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

        <?php if ($relationTypes !== [] || $relationSystems !== []): ?>
            <div class="browse-relfilter">
                <label for="browse-rel-filter-type"><?= e($t('browse.relation_filter_type')) ?></label>
                <select id="browse-rel-filter-type" data-rel-filter="type">
                    <option value=""><?= e($t('browse.relation_filter_all')) ?></option>
                    <?php foreach ($relationTypes as $type => $label): ?>
                        <option value="<?= e($type) ?>"><?= e($label) ?></option>
                    <?php endforeach; ?>
                </select>
                <label for="browse-rel-filter-system"><?= e($t('browse.relation_filter_system')) ?></label>
                <select id="browse-rel-filter-system" data-rel-filter="system">
                    <option value=""><?= e($t('browse.relation_filter_all')) ?></option>
                    <?php foreach ($relationSystems as $system => $label): ?>
                        <option value="<?= e($system) ?>"><?= e($label) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
        <?php endif; ?>
        <p class="browse-rel-note"><?= e($t('browse.relation_literal_note')) ?></p>

        <?php foreach ($classBlocks as $class => $classRelations): ?>
            <?php if ($classRelations === []): ?><?php continue; ?><?php endif; ?>
            <section class="browse-relation-class" data-relation-class="<?= e($class) ?>">
                <h3 class="browse-relation-class__title">
                    <?= e(isset($relationClassLabels[$class]) ? $relationClassLabel($class) : $t('browse.tab_relations')) ?>
                    <span class="browse-diagram__count"><?= count($classRelations) ?></span>
                </h3>

                <?php if ($relView === 'diagram'): ?>
                    <div class="browse-diagram browse-relations-diagram">
                        <div class="browse-diagram__node browse-diagram__node--center">
                            <strong><?= e($termLabel !== '' ? $termLabel : $codeLabel) ?></strong>
                            <?php if ($codeLabel !== ''): ?><span class="code-pill"><?= e($codeLabel) ?></span><?php endif; ?>
                        </div>
                        <div class="browse-diagram__groups">
                            <?php foreach ($groups[$class] ?? [] as $system => $entries): ?>
                                <details class="browse-diagram__group" <?= count($entries) <= 3 ? 'open' : '' ?>>
                                    <summary class="browse-diagram__system">
                                        <?= e($system !== '' ? $identifierSystemLabel((string) $system) : $t('browse.relation_system')) ?>
                                        <span class="browse-diagram__count"><?= count($entries) ?></span>
                                    </summary>
                                    <div class="browse-diagram__nodes">
                                    <?php foreach (array_slice($entries, 0, 5) as $relation): ?>
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
                                        <<?= $nodeTag ?> class="browse-diagram__node browse-rel-node"
                                            data-rel-class="<?= e($class) ?>"
                                            data-rel-type="<?= e($type) ?>"
                                            data-rel-system="<?= e($system) ?>"<?= $nodeAttrs ?>>
                                            <strong><?= e((string) ($relation['code'] ?? '')) ?></strong>
                                            <?php if (!empty($relation['display'])): ?>
                                                <span><?= e((string) $relation['display']) ?></span>
                                            <?php endif; ?>
                                            <?php if (!empty($relation['context_text'])): ?>
                                                <span class="browse-relation-context"><?= e((string) $relation['context_text']) ?></span>
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
                        <p class="browse-rel-note"><?= e($t('browse.relations_limited')) ?></p>
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
                                <?php foreach ($classRelations as $relation): ?>
                                    <?php if (!is_array($relation)): ?><?php continue; ?><?php endif; ?>
                                    <?php
                                    $status = (string) ($relation['review_status'] ?? '');
                                    $pending = in_array($status, $pendingReviews, true);
                                    $badgeClass = $pending
                                        ? 'browse-badge--pending'
                                        : ($status === 'approved' ? 'browse-badge--current' : 'browse-badge--neutral');
                                    $targetKey = BrowseService::normalizeResultKey($relation['result_key'] ?? '');
                                    ?>
                                    <tr class="browse-rel-row"
                                        data-rel-class="<?= e($class) ?>"
                                        data-rel-type="<?= e((string) ($relation['type'] ?? '')) ?>"
                                        data-rel-system="<?= e((string) ($relation['system'] ?? '')) ?>">
                                        <td>
                                            <?= e($identifierSystemLabel((string) ($relation['system'] ?? ''))) ?>
                                            <?php if (isset($relationClassLabels[$class])): ?>
                                                <span class="browse-badge browse-badge--class"><?= e($relationClassLabel($class)) ?></span>
                                            <?php endif; ?>
                                        </td>
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
                                        <td>
                                            <?= e((string) ($relation['display'] ?? '')) ?>
                                            <?php if (!empty($relation['context_text'])): ?>
                                                <span class="browse-relation-context"><?= e((string) $relation['context_text']) ?></span>
                                            <?php endif; ?>
                                        </td>
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
            </section>
        <?php endforeach; ?>
    <?php endif; ?>
</div>
