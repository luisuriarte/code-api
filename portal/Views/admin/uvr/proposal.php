<?php

declare(strict_types=1);

/** @var array<string, mixed>|null $proposal */
/** @var list<array<string, mixed>> $reviews */
/** @var array<int, array<string, mixed>> $decisions */
/** @var array<string, mixed> $current */

require __DIR__ . '/_nav.php';

$uvrPermissions = is_array($current['permissions'] ?? null) ? $current['permissions'] : [];
$uvrCanReview = \OrigenSalud\Portal\Admin\Rbac::hasPermission($uvrPermissions, 'catalog.review');
$uvrCanApprove = \OrigenSalud\Portal\Admin\Rbac::hasPermission($uvrPermissions, 'catalog.approve');
$uvrProposal = is_array($proposal) ? $proposal : null;
$uvrId = $uvrProposal === null ? 0 : (int) ($uvrProposal['id'] ?? 0);
?>
<article class="admin-box">
    <h2><?= e($t('admin.uvr.proposal_title')) ?></h2>
    <?php if ($uvrProposal === null): ?>
        <p><?= e($t('admin.uvr.not_found')) ?></p>
    <?php else: ?>
        <dl class="admin-details">
            <dt><?= e($t('admin.uvr.col_subject')) ?></dt>
            <dd><code><?= e((string) ($uvrProposal['subject_id'] ?? '')) ?></code></dd>
            <dt><?= e($t('admin.uvr.col_source')) ?></dt>
            <dd><?= e((string) ($uvrProposal['source_reference'] ?? '')) ?></dd>
            <dt><?= e($t('admin.uvr.col_status')) ?></dt>
            <dd><code><?= e((string) ($uvrProposal['review_status'] ?? '')) ?></code></dd>
            <dt><?= e($t('admin.uvr.proposed_change')) ?></dt>
            <dd><code><?= e((string) ($uvrProposal['proposed_change'] ?? '')) ?></code></dd>
        </dl>

        <h3><?= e($t('admin.uvr.col_reviews')) ?></h3>
        <?php if ($reviews === []): ?>
            <p><?= e($t('admin.uvr.empty')) ?></p>
        <?php else: ?>
            <div class="admin-table-wrap">
                <table class="admin-table">
                    <thead>
                    <tr>
                        <th><?= e($t('admin.uvr.col_role')) ?></th>
                        <th><?= e($t('admin.uvr.col_actor')) ?></th>
                        <th><?= e($t('admin.uvr.col_outcome')) ?></th>
                        <th><?= e($t('admin.uvr.col_rationale')) ?></th>
                    </tr>
                    </thead>
                    <tbody>
                    <?php foreach ($reviews as $review): ?>
                        <tr>
                            <td><?= e((string) ($review['reviewer_role'] ?? '')) ?></td>
                            <td><?= e((string) ($review['reviewer_actor'] ?? '')) ?></td>
                            <td><code><?= e((string) ($review['outcome'] ?? '')) ?></code></td>
                            <td><?= e((string) ($review['rationale'] ?? '')) ?></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php endif; ?>

        <?php if ($uvrCanReview && count($reviews) < 2): ?>
            <h3><?= e($t('admin.uvr.review_title')) ?></h3>
            <form method="post" action="/admin/uvr/proposals/<?= $uvrId ?>/review" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <label><?= e($t('admin.uvr.col_role')) ?>
                    <select name="review_role" required>
                        <option value="clinical"><?= e($t('admin.uvr.role_clinical')) ?></option>
                        <option value="economic"><?= e($t('admin.uvr.role_economic')) ?></option>
                    </select>
                </label>
                <label><?= e($t('admin.uvr.col_outcome')) ?>
                    <select name="outcome" required>
                        <option value="approved"><?= e($t('admin.uvr.outcome_approved')) ?></option>
                        <option value="reviewed"><?= e($t('admin.uvr.outcome_reviewed')) ?></option>
                        <option value="unreviewed"><?= e($t('admin.uvr.outcome_unreviewed')) ?></option>
                    </select>
                </label>
                <label><?= e($t('admin.uvr.col_rationale')) ?>
                    <textarea name="rationale" required rows="3" maxlength="2000"></textarea>
                </label>
                <button type="submit" class="button"><?= e($t('admin.uvr.review_submit')) ?></button>
            </form>
        <?php endif; ?>

        <?php if ($decisions !== []): ?>
            <h3><?= e($t('admin.uvr.col_decisions')) ?></h3>
            <ul>
                <?php foreach ($decisions as $decision): ?>
                    <li>
                        <?= e((string) ($decision['decision_code'] ?? '')) ?>
                        — <?= e((string) ($decision['approved_by'] ?? '')) ?>
                        <?= e((string) ($decision['evidence_reference'] ?? '')) ?>
                    </li>
                <?php endforeach; ?>
            </ul>
        <?php endif; ?>

        <?php if ($uvrCanApprove && ($uvrProposal['review_status'] ?? '') !== 'approved'): ?>
            <h3><?= e($t('admin.uvr.decide_title')) ?></h3>
            <form method="post" action="/admin/uvr/proposals/<?= $uvrId ?>/decide" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <label><?= e($t('admin.uvr.evidence_reference')) ?>
                    <textarea name="evidence_reference" required rows="2" maxlength="2000"></textarea>
                </label>
                <button type="submit" class="button"><?= e($t('admin.uvr.decide_submit')) ?></button>
            </form>
        <?php endif; ?>
    <?php endif; ?>
</article>
</section>
