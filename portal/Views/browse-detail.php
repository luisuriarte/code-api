<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$result = $result ?? ['ok' => false, 'error' => null, 'item' => null];
$item = is_array($result['item'] ?? null) ? $result['item'] : null;
$catalogCode = is_array($item) && isset($item['catalog_code'])
    ? (string) $item['catalog_code']
    : null;
$isDentar = in_array($catalogCode, ['dentar-pr', 'dentar-dx'], true);
$formatValue = static function (mixed $value): string {
    if (is_bool($value)) {
        return $value ? 'true' : 'false';
    }

    if (is_float($value)) {
        return number_format($value, 4, '.', '');
    }

    if (is_array($value)) {
        return implode(', ', array_map('strval', $value));
    }

    return is_scalar($value) ? (string) $value : '';
};
?>
<section class="section">
    <div class="container narrow">
        <a class="back-link" href="<?= e($backUrl) ?>">← <?= e($t('browse.back_results')) ?></a>
        <span class="eyebrow"><?= e($t('browse.detail_title')) ?></span>

        <?php if ($isDentar): ?>
            <div class="browse-dentar-banner">
                <strong><?= e($t('browse.dentar_badge')) ?> · <?= e(strtoupper((string) $catalogCode)) ?></strong>
                <p><?= e($t('browse.dentar_detail_note')) ?></p>
                <a class="dentar-text-link" href="<?= e(I18n::localizedPath($locale, '/dentar')) ?>">
                    <?= e($t('browse.dentar_back')) ?> →
                </a>
            </div>
        <?php endif; ?>

        <?php if ($item === null): ?>
            <div class="alert alert-warning" role="status">
                <p><?= e($t('browse.' . ($result['error'] ?? 'no_results'))) ?></p>
            </div>
        <?php else: ?>
            <?php
            $code = (string) ($item['code'] ?? '');
            $term = (string) ($item['term'] ?? '');
            $fallback = !empty($item['fallback_applied']);
            $untranslated = !empty($item['untranslated']);
            ?>
            <h1><?= e($term !== '' ? $term : ($code !== '' ? $code : $id)) ?></h1>

            <?php if ($fallback || $untranslated): ?>
                <div class="alert alert-warning" role="status">
                    <p><?= e($t('browse.translation_notice')) ?></p>
                </div>
            <?php endif; ?>

            <div class="detail-grid">
                <?php
                $rows = [
                    'code' => 'code',
                    'term' => 'term',
                    'description' => 'description',
                    'domain' => 'domain',
                    'catalog_code' => 'catalog',
                    'concept_id' => 'concept_id',
                    'score' => 'score',
                    'language' => 'language',
                    'effective_language' => 'effective_language',
                    'source_language' => 'source_language',
                    'provenance' => 'provenance',
                    'approval_state' => 'approval_state',
                    'dialect_determined' => 'dialect_determined',
                ];
                ?>
                <?php foreach ($rows as $key => $labelKey): ?>
                    <?php if (!array_key_exists($key, $item) || $item[$key] === '' || $item[$key] === null): ?>
                        <?php continue; ?>
                    <?php endif; ?>
                    <div class="detail-row">
                        <dt><?= e($t('browse.' . $labelKey)) ?></dt>
                        <dd><?= e($formatValue($item[$key])) ?></dd>
                    </div>
                <?php endforeach; ?>
            </div>

            <?php if (!empty($item['fallback_applied']) && !empty($item['fallback_reason'])): ?>
                <p class="form-note"><?= e($t('browse.fallback_reason')) ?>: <?= e((string) $item['fallback_reason']) ?></p>
            <?php endif; ?>
        <?php endif; ?>
    </div>
</section>
