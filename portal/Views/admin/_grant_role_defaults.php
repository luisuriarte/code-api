<?php

declare(strict_types=1);

/**
 * Preselección de grants por catálogo según el rol elegido.
 *
 * Los <option> de los select marcados con `data-grants-role` llevan en
 * `data-catalog-ops` las operaciones que el rol tiene en Rbac. Este script
 * marca esas casillas en el mismo formulario y limpia las denegaciones, que
 * siempre prevalecen sobre los permisos. El servidor sigue validando todo.
 */
?>
<script>
(function () {
    function applyRoleDefaults(select) {
        const form = select.form;
        if (!form) {
            return;
        }

        const option = select.options[select.selectedIndex];
        const raw = option && option.dataset.catalogOps ? option.dataset.catalogOps : '';
        const operations = new Set(raw.split(/\s+/).filter(Boolean));

        form.querySelectorAll('input[type="checkbox"][name="grant_allow[]"]').forEach(function (checkbox) {
            const parts = checkbox.value.split('|');
            checkbox.checked = parts.length === 2 && operations.has(parts[1]);
        });

        form.querySelectorAll('input[type="checkbox"][name="grant_deny[]"]').forEach(function (checkbox) {
            checkbox.checked = false;
        });
    }

    document.querySelectorAll('select[data-grants-role]').forEach(function (select) {
        select.addEventListener('change', function () {
            applyRoleDefaults(select);
        });

        if (select.dataset.applyOnLoad === '1') {
            applyRoleDefaults(select);
        }
    });
})();
</script>
