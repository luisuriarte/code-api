<?php

declare(strict_types=1);

/** @var array<string, mixed>|null $item */
/** @var list<array<string, mixed>> $versions */
/** @var list<array<string, mixed>> $relations */
/** @var list<array<string, mixed>> $releases */
/** @var list<array<string, mixed>> $languages */
/** @var string $catalogCode */

require __DIR__ . '/_nav.php';

$catalogItem = is_array($item) ? $item : null;
$catalogItemId = $catalogItem === null ? 0 : (int) ($catalogItem['id'] ?? 0);
$catalogBack = '/admin/catalogs/' . rawurlencode($catalogCode);
$catalogUvrHref = '/admin/uvr/proposals?service_item_id=' . $catalogItemId;
$catalogLanguageOptions = ['es-AR', 'es', 'en', 'pt-BR'];
$catalogCoverage = ['original', 'complete', 'partial', 'planned', 'undetermined'];
?>
<?php if ($catalogItem === null): ?>
    <p><?= e($t('admin.catalogs.item_not_found')) ?></p>
<?php else: ?>
    <article class="admin-box">
        <h2><?= e($t('admin.catalogs.item_title')) ?></h2>
        <dl class="admin-details">
            <dt><?= e($t('admin.catalogs.col_code')) ?></dt>
            <dd><code><?= e((string) ($catalogItem['permanent_code'] ?? '')) ?></code></dd>
            <dt><?= e($t('admin.uvr.col_catalog')) ?></dt>
            <dd><code><?= e((string) ($catalogItem['catalog_code'] ?? $catalogCode)) ?></code></dd>
            <dt><?= e($t('admin.uvr.col_status')) ?></dt>
            <dd><code><?= e((string) ($catalogItem['status'] ?? '')) ?></code></dd>
        </dl>
        <p>
            <a class="button button-small" href="<?= e($catalogUvrHref) ?>"><?= e($t('admin.catalogs.uvr_button')) ?></a>
            <a class="button button-small" href="<?= e($catalogBack) ?>"><?= e($t('admin.catalogs.back_codes')) ?></a>
        </p>
    </article>

    <div class="admin-grid">
        <article class="admin-box">
            <h3><?= e($t('admin.catalogs.versions_title')) ?></h3>
            <?php if ($versions === []): ?>
                <p><?= e($t('admin.uvr.empty')) ?></p>
            <?php else: ?>
                <div class="admin-table-wrap">
                    <table class="admin-table">
                        <thead>
                        <tr>
                            <th><?= e($t('admin.catalogs.col_release')) ?></th>
                            <th><?= e($t('admin.catalogs.col_term')) ?></th>
                            <th><?= e($t('admin.catalogs.col_language')) ?></th>
                        </tr>
                        </thead>
                        <tbody>
                        <?php foreach ($versions as $version): ?>
                            <tr>
                                <td><?= e((string) ($version['version_tag'] ?? '')) ?></td>
                                <td><?= e((string) ($version['preferred_term'] ?? '')) ?></td>
                                <td><code><?= e((string) ($version['language_code'] ?? '')) ?></code></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </article>

        <article class="admin-box">
            <h3><?= e($t('admin.catalogs.relations_title')) ?></h3>
            <?php if ($relations === []): ?>
                <p><?= e($t('admin.uvr.empty')) ?></p>
            <?php else: ?>
                <div class="admin-table-wrap">
                    <table class="admin-table">
                        <thead>
                        <tr>
                            <th><?= e($t('admin.catalogs.col_target')) ?></th>
                            <th><?= e($t('admin.catalogs.col_relation')) ?></th>
                            <th><?= e($t('admin.catalogs.col_source_value')) ?></th>
                        </tr>
                        </thead>
                        <tbody>
                        <?php foreach ($relations as $relation): ?>
                            <tr>
                                <td><code><?= e((string) ($relation['target_code'] ?? $relation['target_item_id'] ?? '')) ?></code></td>
                                <td><code><?= e((string) ($relation['relation_type'] ?? '')) ?></code></td>
                                <td><?= e((string) ($relation['source_value'] ?? '')) ?></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </article>
    </div>

    <article class="admin-box">
        <h3><?= e($t('admin.catalogs.languages_title')) ?></h3>
        <?php if ($languages === []): ?>
            <p><?= e($t('admin.uvr.empty')) ?></p>
        <?php else: ?>
            <ul>
            <?php foreach ($languages as $language): ?>
                <li>
                    <code><?= e((string) ($language['language_code'] ?? '')) ?></code>
                    — <?= e((string) ($language['coverage_status'] ?? '')) ?>
                    <?= !empty($language['is_default']) ? '· ' . e($t('admin.catalogs.default')) : '' ?>
                </li>
            <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </article>

    <?php if ($catalogCanPropose): ?>
        <article class="admin-box">
            <h3><?= e($t('admin.catalogs.change_title')) ?></h3>
            <p><?= e($t('admin.catalogs.change_note')) ?></p>
            <form method="post" action="/admin/catalogs/proposals" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <input type="hidden" name="operation" value="update">
                <input type="hidden" name="code" value="<?= e($catalogCode) ?>">
                <input type="hidden" name="item_id" value="<?= $catalogItemId ?>">

                <fieldset>
                    <legend><?= e($t('admin.catalogs.group_item')) ?></legend>
                    <label><?= e($t('admin.catalogs.col_code')) ?>
                        <input type="text" name="permanent_code" maxlength="50"
                               value="<?= e((string) ($catalogItem['permanent_code'] ?? '')) ?>">
                    </label>
                    <label><?= e($t('admin.uvr.col_status')) ?>
                        <select name="status">
                            <?php foreach (['active', 'retired', 'superseded'] as $status): ?>
                                <option value="<?= e($status) ?>"
                                    <?= $status === (string) ($catalogItem['status'] ?? '') ? 'selected' : '' ?>><?= e($status) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                </fieldset>

                <fieldset>
                    <legend><?= e($t('admin.catalogs.group_release')) ?></legend>
                    <label><?= e($t('admin.catalogs.col_release')) ?>
                        <select name="release_id">
                            <option value=""><?= e($t('admin.select')) ?></option>
                            <?php foreach ($releases as $release): ?>
                                <option value="<?= (int) ($release['id'] ?? 0) ?>">
                                    <?= e((string) ($release['version_tag'] ?? '')) ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                    <label><?= e($t('admin.uvr.version_tag')) ?>
                        <input type="text" name="version_tag" maxlength="50">
                    </label>
                    <label><?= e($t('admin.uvr.valid_from')) ?>
                        <input type="date" name="valid_from">
                    </label>
                    <label><?= e($t('admin.uvr.valid_to')) ?>
                        <input type="date" name="valid_to">
                    </label>
                    <label><?= e($t('admin.uvr.col_status')) ?>
                        <select name="release_status">
                            <option value=""><?= e($t('admin.select')) ?></option>
                            <?php foreach (['draft', 'review', 'published', 'deprecated'] as $status): ?>
                                <option value="<?= e($status) ?>"><?= e($status) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                </fieldset>

                <fieldset>
                    <legend><?= e($t('admin.catalogs.group_version')) ?></legend>
                    <label><?= e($t('admin.catalogs.col_term')) ?>
                        <input type="text" name="preferred_term" maxlength="255">
                    </label>
                    <label><?= e($t('admin.catalogs.col_definition')) ?>
                        <textarea name="definition" rows="2" maxlength="4000"></textarea>
                    </label>
                    <label><?= e($t('admin.catalogs.col_criteria')) ?>
                        <textarea name="clinical_criteria" rows="2" maxlength="4000"></textarea>
                    </label>
                    <label><?= e($t('admin.catalogs.col_language')) ?>
                        <select name="language_code">
                            <?php foreach ($catalogLanguageOptions as $language): ?>
                                <option value="<?= e($language) ?>"><?= e($language) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                </fieldset>

                <fieldset>
                    <legend><?= e($t('admin.catalogs.group_relations')) ?></legend>
                    <label><?= e($t('admin.catalogs.col_target')) ?>
                        <input type="number" name="relations[0][target_item_id]" min="1">
                    </label>
                    <label><?= e($t('admin.catalogs.col_relation')) ?>
                        <select name="relations[0][relation_type]">
                            <?php foreach (['refer_to_details', 'used_in_combination_with', 'not_paid_separately', 'interchangeable_with'] as $type): ?>
                                <option value="<?= e($type) ?>"><?= e($type) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                    <label><?= e($t('admin.catalogs.col_source_field')) ?>
                        <select name="relations[0][source_field]">
                            <?php foreach (['description', 'procedure', 'notes', 'req'] as $field): ?>
                                <option value="<?= e($field) ?>"><?= e($field) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                    <label><?= e($t('admin.catalogs.col_source_value')) ?>
                        <input type="text" name="relations[0][source_value]" maxlength="20">
                    </label>
                    <label><?= e($t('admin.catalogs.col_provenance')) ?>
                        <input type="text" name="relations[0][provenance]" maxlength="2000">
                    </label>
                </fieldset>

                <fieldset>
                    <legend><?= e($t('admin.catalogs.group_languages')) ?></legend>
                    <label><?= e($t('admin.catalogs.col_language')) ?>
                        <select name="languages[0][language_code]">
                            <?php foreach ($catalogLanguageOptions as $language): ?>
                                <option value="<?= e($language) ?>"><?= e($language) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                    <label><?= e($t('admin.catalogs.apply_language')) ?>
                        <input type="checkbox" name="languages[0][enabled]" value="1">
                    </label>
                    <label><?= e($t('admin.catalogs.col_coverage')) ?>
                        <select name="languages[0][coverage_status]">
                            <?php foreach ($catalogCoverage as $coverage): ?>
                                <option value="<?= e($coverage) ?>"><?= e($coverage) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                </fieldset>

                <label><?= e($t('admin.uvr.col_source')) ?>
                    <textarea name="source_reference" required rows="2" maxlength="2000"><?= $catalogValue('source_reference') ?></textarea>
                </label>
                <button type="submit" class="button"><?= e($t('admin.catalogs.propose_submit')) ?></button>
            </form>
        </article>
    <?php endif; ?>
<?php endif; ?>
</section>
