<?php

declare(strict_types=1);

$clinical = is_array($sections['clinical'] ?? null) ? $sections['clinical'] : [];
$concept = is_array($sections['concept'] ?? null) ? $sections['concept'] : [];
$alreadyInConcept = [];
foreach (['definition', 'short_definition'] as $conceptField) {
    if ($hasValue($concept[$conceptField] ?? null)) {
        $alreadyInConcept[$conceptField] = true;
    }
}
$clinicalFields = [
    'clinical_criteria' => 'browse.clinical_criteria',
    'clinical_scope' => 'browse.clinical_scope',
    'short_definition' => 'browse.short_definition',
    'lay_terms' => 'browse.lay_terms',
    'definition' => 'browse.definition',
];
$rendered = 0;
?>
<div class="browse-subsection">
    <p class="form-note"><?= e($t('browse.coverage_note')) ?></p>
    <?php foreach ($clinicalFields as $field => $labelKey): ?>
        <?php
        $entry = $clinical[$field] ?? null;
        if (isset($alreadyInConcept[$field])) {
            continue;
        }
        if (!is_array($entry) || !$hasValue($entry['value'] ?? null)) {
            continue;
        }
        $rendered++;
        ?>
        <div class="browse-clinical-field">
            <h3><?= e($t($labelKey)) ?></h3>
            <p><?= e((string) $entry['value']) ?></p>
            <p class="form-note">
                <?php if (!empty($entry['language'])): ?>
                    <?= e($t('browse.clinical_language')) ?>: <?= e((string) $entry['language']) ?> ·
                <?php endif; ?>
                <?php if (!empty($entry['provenance'])): ?>
                    <?= e($t('browse.clinical_provenance')) ?>: <?= e((string) $entry['provenance']) ?> ·
                <?php endif; ?>
                <?= e($t('browse.clinical_review')) ?>: <?= e($reviewLabel((string) ($entry['review_status'] ?? 'approved'))) ?>
            </p>
        </div>
    <?php endforeach; ?>
    <?php if ($rendered === 0): ?>
        <p class="browse-empty"><?= e($t('browse.no_clinical')) ?></p>
    <?php endif; ?>
</div>
