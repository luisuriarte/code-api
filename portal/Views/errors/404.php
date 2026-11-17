<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

?>
<section class="section">
    <div class="container">
        <h1>404</h1>
        <p><?= e($pageDescription) ?></p>
        <a class="button" href="<?= e(I18n::localizedPath($locale, '/')) ?>"><?= e($t('nav.home')) ?></a>
    </div>
</section>
