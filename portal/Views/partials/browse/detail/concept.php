<?php

declare(strict_types=1);

$concept = is_array($sections['concept'] ?? null) ? $sections['concept'] : [];
$row = static function (string $labelKey, mixed $value) use ($t, $formatValue, $hasValue): void {
    if (!$hasValue($value)) {
        return;
    }
    ?>
    <div class="detail-row">
        <dt><?= e($t($labelKey)) ?></dt>
        <dd><?= e($formatValue($value)) ?></dd>
    </div>
    <?php
};
?>
<div class="detail-grid browse-detail-grid">
    <?php $row('browse.code', $item['code'] ?? null); ?>
    <?php $row('browse.term', $item['term'] ?? null); ?>
    <?php $row('browse.catalog', $item['catalog_code'] ?? null); ?>
    <?php $row('browse.domain', $item['domain'] ?? null); ?>
    <?php $row('browse.description', $item['description'] ?? null); ?>
    <?php $row('browse.definition', $concept['definition'] ?? null); ?>
    <?php $row('browse.short_definition', $concept['short_definition'] ?? null); ?>
    <?php $row('browse.language', $item['language'] ?? null); ?>
    <?php $row('browse.effective_language', $item['effective_language'] ?? null); ?>
    <?php $row('browse.source_language', $item['source_language'] ?? null); ?>
    <?php $row('browse.approval_state', $item['approval_state'] ?? null); ?>
    <?php $row('browse.untranslated', $item['untranslated'] ?? null); ?>
    <?php $row('browse.fallback_applied', $item['fallback_applied'] ?? null); ?>
    <?php $row('browse.dialect_determined', $item['dialect_determined'] ?? null); ?>
</div>

<?php
$definitionStatus = (string) ($concept['definition_review_status'] ?? '');
?>
<?php if ($hasValue($concept['definition'] ?? null) && $definitionStatus !== '' && $definitionStatus !== 'approved'): ?>
    <p class="form-note mt-1"><?= e($t('browse.definition_review_note')) ?></p>
<?php endif; ?>

<?php
// Los criterios clínicos viven al final de Concepto. El acceso directo evita
// que parezcan ausentes cuando la ficha es larga.
$clinicalCriteria = is_array($sections['clinical']['clinical_criteria'] ?? null)
    ? $sections['clinical']['clinical_criteria']
    : [];
?>
<?php if ($hasValue($clinicalCriteria['value'] ?? null)): ?>
    <p class="mt-1"><a href="#browse-clinical-criteria"><?= e($t('browse.clinical_criteria')) ?></a></p>
<?php endif; ?>

<?php if (!empty($concept['synonyms']) && is_array($concept['synonyms'])): ?>
    <div class="browse-subsection">
        <h3><?= e($t('browse.synonyms')) ?></h3>
        <ul class="browse-inline-list">
            <?php foreach ($concept['synonyms'] as $synonym): ?>
                <?php if (!is_array($synonym) || !$hasValue($synonym['term'] ?? null)): ?>
                    <?php continue; ?>
                <?php endif; ?>
                <li>
                    <?= e((string) $synonym['term']) ?>
                    <?php if (!empty($synonym['language'])): ?>
                        <span class="browse-badge browse-badge--neutral"><?= e((string) $synonym['language']) ?></span>
                    <?php endif; ?>
                    <?php if (!empty($synonym['type'])): ?>
                        <span class="browse-badge browse-badge--neutral"><?= e((string) $synonym['type']) ?></span>
                    <?php endif; ?>
                </li>
            <?php endforeach; ?>
        </ul>
    </div>
<?php endif; ?>

<?php if (!empty($concept['identifiers']) && is_array($concept['identifiers'])): ?>
    <div class="browse-subsection">
        <h3><?= e($t('browse.identifiers')) ?></h3>
        <ul class="browse-inline-list">
            <?php foreach ($concept['identifiers'] as $identifier): ?>
                <?php if (!is_array($identifier) || !$hasValue($identifier['value'] ?? null)): ?>
                    <?php continue; ?>
                <?php endif; ?>
                <li>
                    <?php if (!empty($identifier['system'])): ?>
                        <?= e($identifierSystemLabel((string) $identifier['system'])) ?>:
                    <?php endif; ?>
                    <strong><?= e((string) $identifier['value']) ?></strong>
                    <?php if (!empty($identifier['primary'])): ?>
                        <span class="browse-badge browse-badge--current"><?= e($t('browse.identifier_primary')) ?></span>
                    <?php endif; ?>
                </li>
            <?php endforeach; ?>
        </ul>
    </div>
<?php endif; ?>

<?php if (!empty($concept['source_attributes']) && is_array($concept['source_attributes'])): ?>
    <div class="browse-subsection">
        <h3><?= e($t('browse.source_attributes')) ?></h3>
        <p class="form-note"><?= e($t('browse.source_attributes_note')) ?></p>
        <dl class="detail-grid browse-detail-grid">
            <?php foreach ($concept['source_attributes'] as $attribute): ?>
                <?php if (!is_array($attribute) || !$hasValue($attribute['value'] ?? null)) { continue; } ?>
                <div class="detail-row">
                    <dt><?= e($sourceAttributeLabel($attribute)) ?></dt>
                    <dd>
                        <?php if (!empty($attribute['boolean'])): ?>
                            <?= e($t((string) $attribute['value'] === '1' ? 'browse.yes' : 'browse.no')) ?>
                        <?php else: ?>
                            <?= e((string) $attribute['value']) ?>
                        <?php endif; ?>
                    </dd>
                </div>
            <?php endforeach; ?>
        </dl>
    </div>
<?php endif; ?>
