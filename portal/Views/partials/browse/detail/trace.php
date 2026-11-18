<?php

declare(strict_types=1);

$trace = is_array($sections['trace'] ?? null) ? $sections['trace'] : [];
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
<div class="browse-subsection">
    <?php if ($trace === []): ?>
        <p class="browse-empty"><?= e($t('browse.no_trace')) ?></p>
    <?php else: ?>
        <div class="detail-grid browse-detail-grid">
            <?php $row('browse.trace_source', $trace['source'] ?? null); ?>
            <?php $row('browse.trace_system', $trace['system'] ?? null); ?>
            <?php $row('browse.trace_external_id', $trace['external_id'] ?? null); ?>
            <?php $row('browse.trace_version', $trace['version'] ?? null); ?>
            <?php $row('browse.trace_release_status', $trace['release_status'] ?? null); ?>
            <?php $row('browse.trace_normative', $trace['normative'] ?? null); ?>
            <?php $row('browse.trace_created_at', $trace['created_at'] ?? null); ?>
            <?php $row('browse.trace_provenance', $trace['provenance'] ?? null); ?>
            <?php $row('browse.trace_review_status', $trace['review_status'] ?? null); ?>
            <?php $row('browse.trace_content_hash', $trace['content_hash'] ?? null); ?>
        </div>
    <?php endif; ?>
</div>
