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
<article class="ui-card ui-card-pad">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
        <div>
            <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.catalogs.request_title')) ?></h2>
            <p class="ui-subtitle"><?= e($t('admin.catalogs.requests_note')) ?></p>
        </div>
        <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-mint text-teal-dark">
            <i data-lucide="file-search" class="h-5 w-5"></i>
        </span>
    </div>

    <?php if ($catalogProposal === null): ?>
        <p class="ui-empty"><?= e($t('admin.catalogs.request_not_found')) ?></p>
    <?php else: ?>
        <div class="space-y-8">
            <dl class="ui-dl rounded-xl border border-line bg-paper/70 p-4">
                <dt class="ui-dt"><?= e($t('admin.uvr.col_id')) ?></dt>
                <dd class="ui-dd"><?= $catalogProposalId ?></dd>
                <dt class="ui-dt"><?= e($t('admin.uvr.col_subject')) ?></dt>
                <dd class="ui-dd"><code class="ui-code"><?= e((string) ($catalogProposal['subject_id'] ?? '')) ?></code></dd>
                <dt class="ui-dt"><?= e($t('admin.uvr.col_source')) ?></dt>
                <dd class="ui-dd"><?= e((string) ($catalogProposal['source_reference'] ?? '')) ?></dd>
                <dt class="ui-dt"><?= e($t('admin.uvr.col_status')) ?></dt>
                <dd class="ui-dd"><code class="ui-code"><?= e((string) ($catalogProposal['review_status'] ?? '')) ?></code></dd>
                <dt class="ui-dt"><?= e($t('admin.catalogs.col_change')) ?></dt>
                <dd class="ui-dd"><code class="ui-code"><?= e((string) ($catalogProposal['proposed_change'] ?? '')) ?></code></dd>
            </dl>

            <section>
                <h3 class="mb-3 text-base font-semibold text-ink"><?= e($t('admin.uvr.col_reviews')) ?></h3>
                <?php if ($reviews === []): ?>
                    <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
                <?php else: ?>
                    <div class="ui-table-wrap">
                        <table class="ui-table">
                            <thead>
                            <tr>
                                <th class="ui-th"><?= e($t('admin.uvr.col_role')) ?></th>
                                <th class="ui-th"><?= e($t('admin.uvr.col_actor')) ?></th>
                                <th class="ui-th"><?= e($t('admin.uvr.col_outcome')) ?></th>
                                <th class="ui-th"><?= e($t('admin.uvr.col_rationale')) ?></th>
                            </tr>
                            </thead>
                            <tbody class="divide-y divide-line">
                            <?php foreach ($reviews as $review): ?>
                                <tr class="transition hover:bg-paper/60">
                                    <td class="ui-td"><?= e((string) ($review['reviewer_role'] ?? '')) ?></td>
                                    <td class="ui-td"><?= e((string) ($review['reviewer_actor'] ?? '')) ?></td>
                                    <td class="ui-td"><code class="ui-code"><?= e((string) ($review['outcome'] ?? '')) ?></code></td>
                                    <td class="ui-td"><?= e((string) ($review['rationale'] ?? '')) ?></td>
                                </tr>
                            <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>

                <?php if ($catalogCanReview && count($reviews) < 2): ?>
                    <form method="post" action="/admin/catalogs/proposals/<?= $catalogProposalId ?>/review" class="ui-fieldset mt-4">
                        <legend class="ui-legend"><?= e($t('admin.uvr.review_title')) ?></legend>
                        <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                               value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                        <div class="grid gap-4 sm:grid-cols-2">
                            <div>
                                <label for="catalog-review-role" class="ui-label"><?= e($t('admin.uvr.col_role')) ?></label>
                                <select id="catalog-review-role" name="review_role" required class="ui-input">
                                    <option value="clinical"><?= e($t('admin.uvr.role_clinical')) ?></option>
                                    <option value="technical"><?= e($t('admin.catalogs.role_technical')) ?></option>
                                </select>
                            </div>
                            <div>
                                <label for="catalog-review-outcome" class="ui-label"><?= e($t('admin.uvr.col_outcome')) ?></label>
                                <select id="catalog-review-outcome" name="outcome" required class="ui-input">
                                    <option value="approved"><?= e($t('admin.uvr.outcome_approved')) ?></option>
                                    <option value="reviewed"><?= e($t('admin.uvr.outcome_reviewed')) ?></option>
                                    <option value="unreviewed"><?= e($t('admin.uvr.outcome_unreviewed')) ?></option>
                                </select>
                            </div>
                            <div class="sm:col-span-2">
                                <label for="catalog-review-rationale" class="ui-label"><?= e($t('admin.uvr.col_rationale')) ?></label>
                                <textarea id="catalog-review-rationale" name="rationale" required rows="3" maxlength="2000"
                                          class="ui-input"></textarea>
                            </div>
                        </div>
                        <button type="submit" class="ui-btn">
                            <i data-lucide="check-check" class="h-4 w-4"></i>
                            <?= e($t('admin.uvr.review_submit')) ?>
                        </button>
                    </form>
                <?php endif; ?>
            </section>

            <?php if ($decisions !== []): ?>
                <section>
                    <h3 class="mb-3 text-base font-semibold text-ink"><?= e($t('admin.uvr.col_decisions')) ?></h3>
                    <ul class="space-y-2">
                        <?php foreach ($decisions as $decision): ?>
                            <li class="rounded-lg border border-line bg-paper px-3 py-2 text-sm text-ink-soft">
                                <code class="ui-code"><?= e((string) ($decision['decision_code'] ?? '')) ?></code>
                                <span class="mx-2 text-muted">—</span>
                                <span class="font-medium text-ink"><?= e((string) ($decision['approved_by'] ?? '')) ?></span>
                                <span class="block text-xs text-muted"><?= e((string) ($decision['evidence_reference'] ?? '')) ?></span>
                            </li>
                        <?php endforeach; ?>
                    </ul>
                </section>
            <?php endif; ?>

            <?php if ($catalogCanApprove && ($catalogProposal['review_status'] ?? '') !== 'approved'): ?>
                <form method="post" action="/admin/catalogs/proposals/<?= $catalogProposalId ?>/decide" class="ui-fieldset">
                    <legend class="ui-legend"><?= e($t('admin.uvr.decide_title')) ?></legend>
                    <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                           value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                    <div>
                        <label for="catalog-evidence" class="ui-label"><?= e($t('admin.uvr.evidence_reference')) ?></label>
                        <textarea id="catalog-evidence" name="evidence_reference" required rows="2" maxlength="2000"
                                  class="ui-input"></textarea>
                    </div>
                    <button type="submit" class="ui-btn">
                        <i data-lucide="gavel" class="h-4 w-4"></i>
                        <?= e($t('admin.uvr.decide_submit')) ?>
                    </button>
                </form>
            <?php endif; ?>

            <?php if ($catalogCanPublish && ($catalogProposal['review_status'] ?? '') === 'approved'): ?>
                <form method="post" action="/admin/catalogs/proposals/<?= $catalogProposalId ?>/publish" class="ui-fieldset border-teal/30 bg-mint/40">
                    <legend class="ui-legend text-teal-dark"><?= e($t('admin.catalogs.publish_title')) ?></legend>
                    <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                           value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                    <p class="text-sm text-ink-soft"><?= e($t('admin.catalogs.publish_note')) ?></p>
                    <button type="submit" class="ui-btn">
                        <i data-lucide="send" class="h-4 w-4"></i>
                        <?= e($t('admin.uvr.publish')) ?>
                    </button>
                </form>
            <?php endif; ?>
        </div>
    <?php endif; ?>
</article>
</section>
