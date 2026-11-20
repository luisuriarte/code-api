<?php

declare(strict_types=1);

/** @var array<string, mixed>|null $proposal */
/** @var list<array<string, mixed>> $reviews */
/** @var list<array<string, mixed>> $decisions */
/** @var array<string, mixed> $current */

require __DIR__ . '/_nav.php';

$catalogPermissions = is_array($current['permissions'] ?? null) ? $current['permissions'] : [];
$catalogCanReview = \OrigenSalud\Portal\Admin\Rbac::hasPermission($catalogPermissions, 'catalog.review');
$catalogCanApprove = \OrigenSalud\Portal\Admin\Rbac::hasPermission($catalogPermissions, 'catalog.approve');
$catalogCanPublish = \OrigenSalud\Portal\Admin\Rbac::hasPermission($catalogPermissions, 'catalog.publish');
$catalogProposal = is_array($proposal) ? $proposal : null;
$catalogProposalId = $catalogProposal === null ? 0 : (int) ($catalogProposal['id'] ?? 0);
?>
<?php if ($catalogProposal === null): ?>
    <p><?= e($t('admin.catalogs.request_not_found')) ?></p>
<?php else: ?>
    <article class="admin-box">
        <h2><?= e($t('admin.catalogs.request_title')) ?></h2>
        <dl class="admin-details">
            <dt><?= e($t('admin.uvr.col_id')) ?></dt>
            <dd><?= $catalogProposalId ?></dd>
            <dt><?= e($t('admin.uvr.col_subject')) ?></dt>
            <dd><code><?= e((string) ($catalogProposal['subject_id'] ?? '')) ?></code></dd>
            <dt><?= e($t('admin.uvr.col_source')) ?></dt>
            <dd><?= e((string) ($catalogProposal['source_reference'] ?? '')) ?></dd>
            <dt><?= e($t('admin.uvr.col_status')) ?></dt>
            <dd><code><?= e((string) ($catalogProposal['review_status'] ?? '')) ?></code></dd>
            <dt><?= e($t('admin.catalogs.col_change')) ?></dt>
            <dd><code><?= e((string) ($catalogProposal['proposed_change'] ?? '')) ?></code></dd>
        </dl>
    </article>

    <article class="admin-box">
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

        <?php if ($catalogCanReview && count($reviews) < 2): ?>
            <h3><?= e($t('admin.uvr.review_title')) ?></h3>
            <form method="post" action="/admin/catalogs/proposals/<?= $catalogProposalId ?>/review" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <label><?= e($t('admin.uvr.col_role')) ?>
                    <select name="review_role" required>
                        <option value="clinical"><?= e($t('admin.uvr.role_clinical')) ?></option>
                        <option value="technical"><?= e($t('admin.catalogs.role_technical')) ?></option>
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
    </article>

    <?php if ($decisions !== []): ?>
        <article class="admin-box">
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
        </article>
    <?php endif; ?>

    <?php if ($catalogCanApprove && ($catalogProposal['review_status'] ?? '') !== 'approved'): ?>
        <article class="admin-box">
            <h3><?= e($t('admin.uvr.decide_title')) ?></h3>
            <form method="post" action="/admin/catalogs/proposals/<?= $catalogProposalId ?>/decide" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <label><?= e($t('admin.uvr.evidence_reference')) ?>
                    <textarea name="evidence_reference" required rows="2" maxlength="2000"></textarea>
                </label>
                <button type="submit" class="button"><?= e($t('admin.uvr.decide_submit')) ?></button>
            </form>
        </article>
    <?php endif; ?>

    <?php if ($catalogCanPublish && ($catalogProposal['review_status'] ?? '') === 'approved'): ?>
        <article class="admin-box">
            <h3><?= e($t('admin.catalogs.publish_title')) ?></h3>
            <p><?= e($t('admin.catalogs.publish_note')) ?></p>
            <form method="post" action="/admin/catalogs/proposals/<?= $catalogProposalId ?>/publish" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <button type="submit" class="button"><?= e($t('admin.uvr.publish')) ?></button>
            </form>
        </article>
    <?php endif; ?>
<?php endif; ?>
</section>
