<?php

declare(strict_types=1);

/**
 * Controles rápidos del selector de grants.
 *
 * 1. Preselecciona las operaciones del rol elegido en los <select> marcados
 *    con `data-grants-role`, leyendo `data-catalog-ops` de cada <option>.
 * 2. Los botones `data-grant-toggle-op` marcan o desmarcan esa operación en
 *    todos los catálogos del formulario (barra inferior de Todo/Ninguno).
 * 3. Los botones `data-grant-toggle-catalog` hacen lo mismo para todas las
 *    operaciones de un catálogo (botón al lado de Publicar en cada fila).
 *
 * Las denegaciones se limpian al aplicar un rol, al marcar "Todo" por
 * operación o al marcar "Todo" por catálogo. El servidor sigue validando.
 */
?>
<script>
(function () {
    function boxesFor(form, field, matcher) {
        const selector = 'input[type="checkbox"][name="' + field + '[]"]';
        return Array.prototype.filter.call(
            form.querySelectorAll(selector),
            function (checkbox) {
                return matcher(checkbox.value.split('|'));
            }
        );
    }

    function boxesForOperation(form, field, operation) {
        return boxesFor(form, field, function (parts) {
            return parts[1] === operation;
        });
    }

    function boxesForCatalog(form, field, catalog) {
        return boxesFor(form, field, function (parts) {
            return parts[0] === catalog;
        });
    }

    function syncButton(button, boxes) {
        const allSelected = boxes.length > 0 && boxes.every(function (checkbox) {
            return checkbox.checked;
        });
        const label = button.querySelector('[data-grant-toggle-label]');

        button.dataset.allSelected = allSelected ? '1' : '0';
        button.setAttribute('aria-pressed', allSelected ? 'true' : 'false');

        if (label) {
            label.textContent = allSelected ? button.dataset.labelNone : button.dataset.labelAll;
        }
    }

    function syncAll(form) {
        form.querySelectorAll('button[data-grant-toggle-op]').forEach(function (button) {
            syncButton(button, boxesForOperation(form, 'grant_allow', button.dataset.grantToggleOp));
        });

        form.querySelectorAll('button[data-grant-toggle-catalog]').forEach(function (button) {
            syncButton(button, boxesForCatalog(form, 'grant_allow', button.dataset.grantToggleCatalog));
        });
    }

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

        syncAll(form);
    }

    const forms = new Set();

    document.querySelectorAll(
        'button[data-grant-toggle-op], button[data-grant-toggle-catalog]'
    ).forEach(function (button) {
        const form = button.form;
        if (!form) {
            return;
        }
        forms.add(form);

        button.addEventListener('click', function () {
            const operation = button.dataset.grantToggleOp;
            const catalog = button.dataset.grantToggleCatalog;
            const shouldCheck = button.dataset.allSelected !== '1';

            if (operation) {
                boxesForOperation(form, 'grant_allow', operation).forEach(function (checkbox) {
                    checkbox.checked = shouldCheck;
                });

                if (shouldCheck) {
                    boxesForOperation(form, 'grant_deny', operation).forEach(function (checkbox) {
                        checkbox.checked = false;
                    });
                }
            }

            if (catalog) {
                boxesForCatalog(form, 'grant_allow', catalog).forEach(function (checkbox) {
                    checkbox.checked = shouldCheck;
                });

                if (shouldCheck) {
                    boxesForCatalog(form, 'grant_deny', catalog).forEach(function (checkbox) {
                        checkbox.checked = false;
                    });
                }
            }

            syncAll(form);
        });
    });

    forms.forEach(function (form) {
        form.addEventListener('change', function (event) {
            if (event.target.matches('input[type="checkbox"][name="grant_allow[]"]')) {
                syncAll(form);
            }
        });
        syncAll(form);
    });

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
