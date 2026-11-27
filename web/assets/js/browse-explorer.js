(function () {
    'use strict';

    var MAX_HISTORY = 8;
    var MAX_COMPARE = 4;
    var HISTORY_PARAM = 'history';
    var CONTEXT_PARAMS = ['tab', 'rel_view'];
    var CACHE_TTL_MS = 300000;
    var CACHE_MAX_ENTRIES = 60;
    var fragmentCache = Object.create(null);

    function ready(fn) {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', fn);
        } else {
            fn();
        }
    }

    function parseUrl(value) {
        return new URL(value || window.location.href, window.location.href);
    }

    function paramsFrom(input) {
        var value;

        if (typeof URLSearchParams !== 'undefined' && input instanceof URLSearchParams) {
            return input;
        }

        if (input === undefined || input === null) {
            value = window.location.search;
        } else if (typeof input === 'string') {
            value = input;
        } else {
            value = String(input || '');
        }

        if (value.indexOf('?') !== -1 || value.indexOf('/') !== -1 || /^[a-z][a-z0-9+.-]*:/i.test(value)) {
            return parseUrl(value).searchParams;
        }

        return new URLSearchParams(value);
    }

    function serializeLike(original, url) {
        var absolute = /^[a-z][a-z0-9+.-]*:/i.test(original) || original.indexOf('//') === 0;

        if (absolute) {
            return url.href;
        }

        if (original.charAt(0) === '?') {
            return url.search + url.hash;
        }

        return url.pathname + url.search + url.hash;
    }

    function dedupe(values) {
        var seen = Object.create(null);
        var out = [];

        (values || []).forEach(function (value) {
            var key = String(value == null ? '' : value).trim();

            if (key && !seen[key]) {
                seen[key] = true;
                out.push(key);
            }
        });

        return out;
    }

    function splitValues(value, out) {
        String(value == null ? '' : value).split(',').forEach(function (part) {
            out.push(part);
        });
    }

    function readValues(params, name) {
        var values = [];

        params.getAll(name).forEach(function (value) {
            splitValues(value, values);
        });

        return dedupe(values);
    }

    function readHistory(search) {
        return readValues(paramsFrom(search === undefined ? window.location.search : search), HISTORY_PARAM);
    }

    // El portal serializa history y compare como listas separadas por comas.
    function detectHistoryStyle() {
        return 'csv';
    }

    function setHistoryOnParams(params, list, style) {
        params.delete(HISTORY_PARAM);
        params.delete('history');

        if (!list || !list.length) {
            return;
        }

        if (style === 'csv') {
            params.set('history', list.join(','));
        } else if (style === 'plain') {
            list.forEach(function (value) {
                params.append('history', value);
            });
        } else {
            list.forEach(function (value) {
                params.append(HISTORY_PARAM, value);
            });
        }
    }

    function withHistory(url, list, style) {
        var parsed = parseUrl(url);

        setHistoryOnParams(parsed.searchParams, list, style || detectHistoryStyle(parsed.searchParams, ''));

        return serializeLike(url, parsed);
    }

    function copyContextParams(params) {
        var current = new URLSearchParams(window.location.search);

        CONTEXT_PARAMS.forEach(function (name) {
            if (current.has(name)) {
                params.set(name, current.get(name));
            }
        });
    }

    function cacheFragment(key, html) {
        var now = Date.now ? Date.now() : new Date().getTime();
        var keys = Object.keys(fragmentCache);

        keys.forEach(function (cachedKey) {
            if (now - fragmentCache[cachedKey].time >= CACHE_TTL_MS) {
                delete fragmentCache[cachedKey];
            }
        });

        keys = Object.keys(fragmentCache);
        while (keys.length >= CACHE_MAX_ENTRIES && keys.length > 0) {
            delete fragmentCache[keys.shift()];
        }

        fragmentCache[key] = { time: now, html: html };
    }

    function fetchHtml(url, options) {
        var settings = options || {};
        var key = String(url || '');
        var now = Date.now ? Date.now() : new Date().getTime();
        var cached = fragmentCache[key];
        var fetchOptions = {
            headers: { 'X-Requested-With': 'fetch' },
            credentials: 'same-origin'
        };

        if (settings.signal) {
            fetchOptions.signal = settings.signal;
        }

        if (!settings.skipCache && cached && now - cached.time < CACHE_TTL_MS) {
            return Promise.resolve(cached.html);
        }

        if (cached) {
            delete fragmentCache[key];
        }

        if (typeof window.fetch !== 'function') {
            return Promise.reject(new Error('fetch unavailable'));
        }

        return window.fetch.call(window, key, fetchOptions).then(function (response) {
            if (!response.ok) {
                throw new Error('HTTP ' + response.status);
            }

            return response.text();
        }).then(function (html) {
            if (!settings.skipCache && !(settings.signal && settings.signal.aborted)) {
                cacheFragment(key, html);
            }

            return html;
        });
    }

    function buildFragmentUrl(source, settings) {
        var options = settings || {};
        var parsed = parseUrl(source);

        parsed.searchParams.set('fragment', 'detail');

        if (options.focus) {
            parsed.searchParams.set('focus', options.focus);
        }

        if (options.history) {
            setHistoryOnParams(
                parsed.searchParams,
                options.history,
                options.historyStyle || detectHistoryStyle(parsed.searchParams, '') || 'bracket'
            );
        }

        copyContextParams(parsed.searchParams);

        return serializeLike(source, parsed);
    }

    function focusFromUrl(value) {
        var parsed = parseUrl(value);
        var focus = parsed.searchParams.get('focus');
        var match;

        if (focus) {
            return focus;
        }

        match = parsed.pathname.match(/\/browse\/([^/]+)\/?$/);

        if (match) {
            try {
                return decodeURIComponent(match[1]);
            } catch (err) {
                return match[1];
            }
        }

        return '';
    }

    function setFocus(root, focus, detail) {
        var key = focus || '';

        root.dataset.focus = key;

        if (detail) {
            detail.dataset.focus = key;
        }
    }

    function updateSelection(root, focus) {
        var items = root.querySelectorAll('.browse-result[data-result-key]');

        Array.prototype.forEach.call(items, function (item) {
            var selected = !!focus && item.getAttribute('data-result-key') === focus;
            var link = item.querySelector('.browse-result-link');

            item.classList.toggle('is-selected', selected);

            if (!link) {
                return;
            }

            if (selected) {
                link.setAttribute('aria-current', 'true');
            } else {
                link.removeAttribute('aria-current');
            }
        });
    }

    function rewriteAttribute(element, attribute, mutator) {
        var original = element.getAttribute(attribute);
        var parsed;

        if (!original) {
            return;
        }

        parsed = parseUrl(original);
        mutator(parsed.searchParams);
        element.setAttribute(attribute, serializeLike(original, parsed));
    }

    function setCompareParam(params, key) {
        if (key) {
            params.set('compare', key);
        } else {
            params.delete('compare');
        }
    }

    function updateResultLinks(root, historyList, previousKey, currentKey) {
        var style = 'csv';
        var list = (historyList || []).slice();
        var baseCompare = readValues(paramsFrom(window.location.search), 'compare');

        if (previousKey) {
            baseCompare.push(previousKey);
        }
        if (currentKey) {
            baseCompare.push(currentKey);
        }
        baseCompare = dedupe(baseCompare);

        Array.prototype.forEach.call(root.querySelectorAll('.browse-result-link'), function (link) {
            rewriteAttribute(link, 'href', function (params) {
                var item;
                var key;

                setHistoryOnParams(params, list, style);

                if (params.has('focus')) {
                    item = link.closest('.browse-result');
                    key = link.getAttribute('data-result-key') || (item && item.getAttribute('data-result-key')) || currentKey;

                    if (key) {
                        params.set('focus', key);
                    }
                }
            });
        });

        Array.prototype.forEach.call(root.querySelectorAll('.browse-result-link[data-focus-url]'), function (link) {
            rewriteAttribute(link, 'data-focus-url', function (params) {
                setHistoryOnParams(params, list, style);
                params.set('fragment', 'detail');

                if (link.getAttribute('data-result-key') || currentKey) {
                    params.set('focus', link.getAttribute('data-result-key') || currentKey);
                }

                copyContextParams(params);
            });
        });

        Array.prototype.forEach.call(root.querySelectorAll('.browse-compare-link'), function (link) {
            var compareKey = link.getAttribute('data-compare-key') || '';
            var compareList = dedupe(baseCompare.concat([compareKey])).slice(0, MAX_COMPARE);

            rewriteAttribute(link, 'href', function (params) {
                setHistoryOnParams(params, list, style);
                setCompareParam(params, compareList.join(','));
            });

            if (link.hasAttribute('data-compare-url')) {
                rewriteAttribute(link, 'data-compare-url', function (params) {
                    setHistoryOnParams(params, list, style);
                    setCompareParam(params, compareList.join(','));
                });
            }
        });
    }

    function setMobileView(root, view) {
        var buttons;

        if (!view) {
            return;
        }

        root.dataset.mobileView = view;
        buttons = root.querySelectorAll('[data-mobile-view-target]');

        Array.prototype.forEach.call(buttons, function (button) {
            var active = button.getAttribute('data-mobile-view-target') === view;

            button.classList.toggle('is-active', active);
            button.setAttribute('aria-pressed', active ? 'true' : 'false');
        });
    }

    function isMobileView() {
        if (typeof window.matchMedia === 'function') {
            return window.matchMedia('(max-width: 900px)').matches;
        }

        return window.innerWidth <= 900;
    }

    function applyRelationFilters(root) {
        var detail = root.querySelector('.browse-detail');
        var selects;
        var type = '';
        var system = '';

        if (!detail) {
            return;
        }

        selects = Array.prototype.slice.call(detail.querySelectorAll('[data-rel-filter]'));
        if (!selects.length) {
            return;
        }

        selects.forEach(function (select) {
            if (select.getAttribute('data-rel-filter') === 'type') {
                type = select.value;
            } else if (select.getAttribute('data-rel-filter') === 'system') {
                system = select.value;
            }
        });

        function visible(node) {
            return (!type || node.getAttribute('data-rel-type') === type)
                && (!system || node.getAttribute('data-rel-system') === system);
        }

        Array.prototype.forEach.call(detail.querySelectorAll('.browse-rel-row'), function (row) {
            row.hidden = !visible(row);
        });

        Array.prototype.forEach.call(detail.querySelectorAll('.browse-rel-node'), function (node) {
            node.hidden = !visible(node);
        });
    }

    function announce(root, text) {
        var status = root.querySelector('[data-live-status]');

        if (status) {
            status.textContent = text;
        }
    }

    function message(root, key, fallback) {
        return root.getAttribute('data-msg-' + key) || fallback;
    }

    function clearFetchError(pane) {
        if (!pane) {
            return;
        }

        var alertBox = pane.querySelector('[data-fetch-error]');
        var stale = pane.querySelector('[data-stale-notice]');

        pane.removeAttribute('data-stale');
        pane.removeAttribute('data-fetch-retry-attempted');
        if (alertBox) {
            alertBox.hidden = true;
        }
        if (stale) {
            stale.hidden = true;
        }
    }

    // UX-02: un único punto para avisar del fallo, conservar los resultados
    // anteriores como "última actualización exitosa" y ofrecer reintento.
    function handleFetchError(root, settings) {
        var config = settings || {};
        var pane = root.querySelector('[data-pane="results"]');
        var alertBox;
        var stale;
        var retry;
        var fallback;

        if (!pane) {
            return;
        }

        pane.removeAttribute('aria-busy');
        alertBox = pane.querySelector('[data-fetch-error]');
        stale = pane.querySelector('[data-stale-notice]');

        if (!alertBox) {
            alertBox = document.createElement('div');
            alertBox.setAttribute('data-fetch-error', '');
            alertBox.setAttribute('role', 'alert');
            alertBox.className = 'mb-4 rounded-2xl border border-line bg-paper px-4 py-3 text-sm leading-6 text-ink-soft';
            alertBox.innerHTML = '<p></p><button type="button" class="button button-small button-ghost mt-2" data-fetch-retry></button>';
            pane.insertBefore(alertBox, pane.firstChild);
        }

        alertBox.hidden = false;
        alertBox.setAttribute('role', 'alert');
        alertBox.querySelector('p').textContent = message(root, 'fetch-error', 'No se pudieron actualizar los resultados.');
        if (stale) {
            stale.textContent = message(root, 'stale-results', 'Los resultados visibles pueden estar desactualizados.');
            stale.hidden = false;
        }
        pane.setAttribute('data-stale', 'true');
        announce(root, message(root, 'fetch-error', 'No se pudieron actualizar los resultados.'));

        retry = alertBox.querySelector('[data-fetch-retry]');
        if (retry) {
            retry.textContent = message(root, 'retry', 'Reintentar');
            fallback = config.url || window.location.href;
            retry.onclick = function () {
                var attempted = pane.getAttribute('data-fetch-retry-attempted') === '1';

                if (typeof config.retry !== 'function' || attempted) {
                    window.location.assign(fallback);
                    return;
                }

                alertBox.hidden = true;
                if (stale) {
                    stale.hidden = true;
                }
                pane.setAttribute('data-fetch-retry-attempted', '1');
                config.retry();
            };
        }
    }

    function focusPane(root) {
        var pane = root.querySelector('[data-pane="detail"]');

        if (!pane) {
            return;
        }

        try {
            pane.focus({ preventScroll: true });
        } catch (err) {
            pane.focus();
        }
    }

    function syncTabs(root, url) {
        var detail = root.querySelector('.browse-detail');
        var tabs;
        var active;
        var selected;

        if (!detail) {
            return;
        }

        tabs = Array.prototype.slice.call(detail.querySelectorAll('[data-tab]'));
        active = paramsFrom(url).get('tab');

        if (!active && !tabs.length) {
            return;
        }

        if (!active) {
            selected = tabs.filter(function (tab) {
                return tab.getAttribute('aria-selected') === 'true';
            })[0];

            active = selected
                ? selected.getAttribute('data-tab')
                : (tabs[0] ? tabs[0].getAttribute('data-tab') : '');
        }

        // Una URL antigua puede pedir una pestaña consolidada (p. ej. clinical).
        if (!tabs.some(function (tab) { return tab.getAttribute('data-tab') === active; })) {
            active = tabs[0] ? tabs[0].getAttribute('data-tab') : '';
        }

        tabs.forEach(function (tab) {
            var isActive = tab.getAttribute('data-tab') === active;

            tab.setAttribute('aria-selected', isActive ? 'true' : 'false');
            tab.setAttribute('tabindex', isActive ? '0' : '-1');
            tab.classList.toggle('is-active', isActive);
        });

        Array.prototype.forEach.call(detail.querySelectorAll('[data-tab-panel]'), function (panel) {
            panel.hidden = panel.getAttribute('data-tab-panel') !== active;
        });
    }

    function syncRelView(root, url) {
        var detail = root.querySelector('.browse-detail');
        var links;
        var active;
        var pressed;

        if (!detail) {
            return;
        }

        links = Array.prototype.slice.call(detail.querySelectorAll('[data-rel-view]'));

        if (!links.length) {
            return;
        }

        active = paramsFrom(url).get('rel_view');

        if (!active) {
            pressed = links.filter(function (link) {
                return link.getAttribute('aria-pressed') === 'true' || link.classList.contains('is-active');
            })[0];

            active = pressed ? pressed.getAttribute('data-rel-view') : 'table';
        }

        links.forEach(function (link) {
            var isActive = link.getAttribute('data-rel-view') === active;

            link.setAttribute('aria-pressed', isActive ? 'true' : 'false');
            link.classList.toggle('is-active', isActive);
        });

        Array.prototype.forEach.call(detail.querySelectorAll('.browse-relations-table'), function (table) {
            table.hidden = active !== 'table';
        });

        Array.prototype.forEach.call(detail.querySelectorAll('.browse-relations-diagram'), function (diagram) {
            diagram.hidden = active !== 'diagram';
        });
    }

    function requestFragment(root, fragmentUrl, stableUrl, options) {
        var settings = options || {};
        var fallback = stableUrl || fragmentUrl || window.location.href;

        if (typeof window.fetch !== 'function') {
            window.location.assign(fallback);
            return;
        }

        fetchHtml(fragmentUrl).then(function (html) {
            var pane = root.querySelector('[data-pane="detail"]');
            var detail;
            var focus;

            if (!pane) {
                window.location.assign(fallback);
                return;
            }

            pane.innerHTML = html;
            detail = pane.querySelector('.browse-detail');
            focus = settings.focus !== undefined
                ? settings.focus
                : (focusFromUrl(fragmentUrl) || root.dataset.focus || '');

            setFocus(root, focus, detail);
            updateSelection(root, focus);

            if (settings.history) {
                updateResultLinks(root, settings.history, settings.previousFocus, focus);
            }

            syncTabs(root, fragmentUrl);
            syncRelView(root, fragmentUrl);
            applyRelationFilters(root);

            if (settings.focusTab) {
                Array.prototype.forEach.call(root.querySelectorAll('[data-tab]'), function (tab) {
                    if (tab.getAttribute('data-tab') === settings.focusTab) {
                        tab.focus();
                    }
                });
            }

            // En escritorio ambas columnas están visibles; forzar la vista
            // móvil aquí ocultaría los resultados tras cada consulta.
            if (isMobileView()) {
                setMobileView(root, 'detail');
            }

            if (settings.push !== false) {
                window.history.pushState({}, '', fallback);
            }

            if (settings.focusPane !== false && !settings.focusTab) {
                focusPane(root);
            }

            if (!settings.silent) {
                announce(root, message(root, settings.messageKey || 'updated', 'Ficha actualizada'));
            }
        }).catch(function () {
            window.location.assign(fallback);
        });
    }

    function isPlainClick(event) {
        if (typeof event.button === 'number' && event.button !== 0) {
            return false;
        }

        return !(event.metaKey || event.ctrlKey || event.shiftKey || event.altKey);
    }

    function closestFromEvent(event, selector, root) {
        var target = event.target;
        var match;

        if (!target) {
            return null;
        }

        if (target.nodeType !== 1) {
            target = target.parentElement;
        }

        if (!target || !root.contains(target)) {
            return null;
        }

        match = target.closest(selector);

        return match && root.contains(match) ? match : null;
    }

    function onResultClick(root, link) {
        var item = link.closest('.browse-result');
        var key = link.getAttribute('data-result-key')
            || (item && item.getAttribute('data-result-key'))
            || focusFromUrl(link.getAttribute('href') || link.href);
        var stableHref;
        var fragmentSource;
        var previousFocus;
        var currentHistory;
        var nextHistory;
        var style;
        var stableUrl;
        var fragmentStyle;
        var fragmentUrl;

        if (!key) {
            return;
        }

        stableHref = link.getAttribute('href') || link.href;
        fragmentSource = link.getAttribute('data-focus-url') || stableHref;
        previousFocus = root.dataset.focus || '';
        currentHistory = readHistory(window.location.search);
        nextHistory = dedupe(currentHistory.slice());

        if (previousFocus && previousFocus !== key) {
            nextHistory.unshift(previousFocus);
        }

        nextHistory = dedupe(nextHistory).slice(0, MAX_HISTORY);
        style = detectHistoryStyle(window.location.search, '')
            || detectHistoryStyle(stableHref, '')
            || detectHistoryStyle(fragmentSource, '')
            || 'bracket';
        stableUrl = withHistory(stableHref, nextHistory, style);
        fragmentStyle = detectHistoryStyle(fragmentSource, '') || style;
        fragmentUrl = buildFragmentUrl(fragmentSource, {
            focus: key,
            history: nextHistory,
            historyStyle: fragmentStyle
        });

        requestFragment(root, fragmentUrl, stableUrl, {
            focus: key,
            history: nextHistory,
            previousFocus: previousFocus,
            messageKey: 'updated'
        });
    }

    function onCompareClick(root, link) {
        var stableHref = link.getAttribute('data-compare-url');
        var focus;
        var currentHistory;
        var style;
        var stableUrl;
        var fragmentUrl;

        if (!stableHref) {
            return;
        }

        focus = focusFromUrl(stableHref) || root.dataset.focus || focusFromUrl(window.location.href);
        currentHistory = readHistory(window.location.search);
        style = detectHistoryStyle(stableHref, '')
            || detectHistoryStyle(window.location.search, '')
            || 'bracket';
        stableUrl = currentHistory.length ? withHistory(stableHref, currentHistory, style) : stableHref;
        fragmentUrl = buildFragmentUrl(stableUrl, {
            focus: focus,
            history: currentHistory,
            historyStyle: style
        });

        requestFragment(root, fragmentUrl, stableUrl, {
            focus: focus,
            messageKey: 'compared'
        });
    }

    function onFragmentLink(root, link) {
        var fragmentUrl = link.getAttribute('data-url');
        var stableUrl;
        var focus;

        if (!fragmentUrl) {
            return;
        }

        stableUrl = link.getAttribute('data-stable-url') || link.getAttribute('href') || fragmentUrl;
        focus = root.dataset.focus || focusFromUrl(fragmentUrl) || focusFromUrl(stableUrl);

        requestFragment(root, fragmentUrl, stableUrl, {
            focus: focus,
            focusTab: link.getAttribute('data-tab') || '',
            messageKey: 'view'
        });
    }

    function copyToClipboard(value) {
        if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
            return navigator.clipboard.writeText(value);
        }

        return Promise.reject(new Error('clipboard unavailable'));
    }

    function legacyCopy(value) {
        var textarea = document.createElement('textarea');
        var copied = false;

        textarea.value = value;
        textarea.setAttribute('readonly', '');
        textarea.style.position = 'fixed';
        textarea.style.top = '-9999px';

        document.body.appendChild(textarea);
        textarea.select();

        try {
            copied = document.execCommand('copy');
        } catch (err) {
            copied = false;
        }

        document.body.removeChild(textarea);

        return copied;
    }

    function copyValue(root, value) {
        copyToClipboard(value).then(function () {
            announce(root, message(root, 'copied', 'Copiado'));
        }).catch(function () {
            if (legacyCopy(value)) {
                announce(root, message(root, 'copied', 'Copiado'));
            } else {
                announce(root, message(root, 'copy-error', 'No se pudo copiar'));
            }
        });
    }

    function onCopy(root, button) {
        copyValue(root, button.getAttribute('data-copy') || '');
    }

    function onCopyRecord(root, button) {
        var detail = button.closest('.browse-detail') || root.querySelector('.browse-detail');
        if (!detail) {
            return;
        }
        copyValue(root, (detail.innerText || detail.textContent || '').replace(/\n{3,}/g, '\n\n').trim());
    }

    var RESULT_PARAMS = [
        'q', 'domain', 'catalog', 'family', 'type', 'category', 'status', 'version', 'validity', 'page'
    ];

    function resultsSignature(params) {
        var values = params || new URLSearchParams(window.location.search);

        return RESULT_PARAMS.map(function (name) {
            return name + '=' + (values.get(name) || '');
        }).join('&');
    }

    function signatureFromUrl(value) {
        try {
            return resultsSignature(parseUrl(value).searchParams);
        } catch (err) {
            return resultsSignature(new URLSearchParams());
        }
    }

    function searchUrls(form) {
        var params = new URLSearchParams();
        var current = new URLSearchParams(window.location.search);
        var base = form.getAttribute('action') || window.location.pathname;
        var data = new FormData(form);
        var catalogValues = [];
        var domainValues = [];

        data.forEach(function (value, key) {
            var clean = String(value).trim();
            if (key === 'catalog' || key === 'catalog[]') {
                splitValues(clean, catalogValues);
                return;
            }
            if (key === 'domain' || key === 'domain[]') {
                splitValues(clean, domainValues);
                return;
            }
            if (clean !== '') {
                params.set(key, clean);
            }
        });

        // Canonicalización antes de validar: dedupe + whitelist + orden estable
        // y una sola familia. Las whitelists vienen del servidor.
        var familySelect = form.querySelector('select[name="family"]');
        var family = familySelect ? familySelect.value : '';
        var codeDropdown = form.querySelector('[data-code-dropdown]');
        var catalogFamilies = Object.create(null);
        var allowed = (form.getAttribute('data-catalogs') || 'dentar-pr,dentar-dx,nomenclador-odontologico-ar,oftar-pr,oftar-dx,nomenclador-oftalmologico-cao-ar,nomenclador-oftalmologico-regional-ar')
            .split(',').map(function (code) { return code.trim(); }).filter(Boolean);
        var allowedDomains = (form.getAttribute('data-domains') || '')
            .split(',').map(function (code) { return code.trim(); }).filter(Boolean);
        var root = form.closest ? form.closest('[data-browse-explorer]') : null;

        if (codeDropdown) {
            Array.prototype.forEach.call(codeDropdown.querySelectorAll('[data-code-input]'), function (input) {
                if (input.getAttribute('data-code-kind') === 'catalog') {
                    catalogFamilies[input.value] = (input.getAttribute('data-families') || '').split(',');
                }
            });
        }

        var catalogs = dedupe(catalogValues).filter(function (code) {
            return allowed.indexOf(code) !== -1
                && family !== ''
                && (!catalogFamilies[code] || catalogFamilies[code].indexOf(family) !== -1);
        }).sort();
        var domains = dedupe(domainValues).filter(function (code) {
            return allowedDomains.indexOf(code) !== -1;
        }).sort();

        var hadBoth = catalogs.length > 0 && domains.length > 0;

        if (family !== '') {
            domains = [];
        } else if (hadBoth) {
            catalogs = [];
        }

        if (hadBoth && root) {
            announce(root, message(root, 'invalid-combination', 'Elegí una sola familia.'));
        }
        if (catalogs.length > 0) {
            params.set('catalog', catalogs.join(','));
        }
        if (domains.length > 0) {
            params.set('domain', domains.join(','));
        }

        params.delete('page');
        ['history', 'compare', 'tab', 'rel_view'].forEach(function (name) {
            if (current.has(name)) {
                params.set(name, current.get(name));
            }
        });

        var query = params.toString();
        var fragment = new URLSearchParams(query);
        fragment.set('fragment', 'results');

        return {
            stable: base + (query === '' ? '' : '?' + query),
            fragment: base + '?' + fragment.toString(),
            signature: resultsSignature(params)
        };
    }

    function resultsFragmentFromUrl(url) {
        var parsed = parseUrl(url);
        parsed.searchParams.delete('fragment');
        parsed.searchParams.set('fragment', 'results');

        return serializeLike(url, parsed);
    }

    // El selector "Código" es un desplegable de casillas. Sin familia muestra
    // dominios; con DENTAR/OFTAR muestra solo los catálogos de esa familia.
    // Las opciones no compatibles se ocultan, pero la selección por familia se
    // conserva para que cambiar de familia no borre lo ya elegido.
    function codeInputMatches(input, family) {
        var kind = input.getAttribute('data-code-kind');
        if (kind === 'domain') {
            return family === '';
        }
        var optionFamilies = (input.getAttribute('data-families') || '').split(',');
        return family !== '' && optionFamilies.indexOf(family) !== -1;
    }

    function checkedCodeInputs(dropdown) {
        var inputs = [];
        if (!dropdown) {
            return inputs;
        }
        Array.prototype.forEach.call(dropdown.querySelectorAll('[data-code-input]'), function (input) {
            if (input.checked && !input.disabled) {
                inputs.push(input);
            }
        });

        return inputs;
    }

    function updateCodeSummary(dropdown, allChecked, count) {
        var summary = dropdown ? dropdown.querySelector('[data-code-summary]') : null;
        if (!summary) {
            return;
        }
        var template;
        if (allChecked) {
            template = dropdown.getAttribute('data-msg-all') || 'Todos';
            summary.textContent = template;
            return;
        }
        template = dropdown.getAttribute('data-msg-selected') || '%count% códigos seleccionados';
        summary.textContent = template.replace('%count%', String(count));
    }

    function updateCodeHidden(form, dropdown) {
        if (!form || !dropdown) {
            return;
        }
        var domains = [];
        var catalogs = [];
        var familySelect = form.querySelector('select[name="family"]');
        var family = familySelect ? familySelect.value : '';

        checkedCodeInputs(dropdown).forEach(function (input) {
            if (input.getAttribute('data-code-kind') === 'domain') {
                domains.push(input.value);
            } else if (input.getAttribute('data-code-kind') === 'catalog') {
                catalogs.push(input.value);
            }
        });

        // Regla única de la interfaz: dominios sin familia, catálogos con
        // familia. Nunca se publican ambos campos en la misma consulta.
        if (family !== '') {
            domains = [];
        } else {
            catalogs = [];
        }

        var hiddenDomain = form.querySelector('[data-code-hidden-domain]');
        var hiddenCatalog = form.querySelector('[data-code-hidden-catalog]');
        if (hiddenDomain) {
            hiddenDomain.value = domains.join(',');
        }
        if (hiddenCatalog) {
            hiddenCatalog.value = catalogs.join(',');
        }

        var allOption = dropdown.querySelector('[data-code-select-all]');
        var allChecked = domains.length === 0 && catalogs.length === 0;
        if (allOption) {
            allOption.checked = allChecked;
        }
        updateCodeSummary(dropdown, allChecked, domains.length + catalogs.length);
    }

    function syncCodeDropdown(form, family) {
        var dropdown = form ? form.querySelector('[data-code-dropdown]') : null;
        if (!dropdown) {
            return;
        }

        var store = form.__browseCodeSelections || (form.__browseCodeSelections = Object.create(null));
        var previous = dropdown.getAttribute('data-code-family') || '';
        store[previous] = checkedCodeInputs(dropdown).map(function (input) { return input.value; });
        dropdown.setAttribute('data-code-family', family);

        var restore = store[family] || [];
        Array.prototype.forEach.call(dropdown.querySelectorAll('[data-code-input]'), function (input) {
            var label = input.closest ? input.closest('[data-code-option]') : input.parentNode;
            var match = codeInputMatches(input, family);
            if (label) {
                label.hidden = !match;
            }
            input.disabled = !match;
            input.checked = match && restore.indexOf(input.value) !== -1;
        });
        updateCodeHidden(form, dropdown);
    }

    function syncDomainForm(form, code) {
        syncCodeDropdown(form, '');
        var dropdown = form ? form.querySelector('[data-code-dropdown]') : null;
        if (!dropdown) {
            return;
        }
        Array.prototype.forEach.call(dropdown.querySelectorAll('[data-code-input]'), function (input) {
            input.checked = input.getAttribute('data-code-kind') === 'domain' && input.value === code;
        });
        updateCodeHidden(form, dropdown);
    }

    function initCodeDropdown(dropdown) {
        if (!dropdown || dropdown.__browseCodeReady) {
            return;
        }
        dropdown.__browseCodeReady = true;

        var trigger = dropdown.querySelector('[data-code-trigger]');
        var panel = dropdown.querySelector('[data-code-panel]');
        if (!trigger || !panel) {
            return;
        }

        function setOpen(open) {
            panel.hidden = !open;
            trigger.setAttribute('aria-expanded', open ? 'true' : 'false');
        }

        trigger.addEventListener('click', function () {
            setOpen(panel.hidden);
        });
        panel.addEventListener('change', function (event) {
            var target = event.target;
            if (target && target.hasAttribute('data-code-select-all') && target.checked) {
                Array.prototype.forEach.call(panel.querySelectorAll('[data-code-input]'), function (input) {
                    input.checked = false;
                });
            }
        });
        document.addEventListener('click', function (event) {
            if (!dropdown.contains(event.target)) {
                setOpen(false);
            }
        });
        document.addEventListener('keydown', function (event) {
            if (event.key === 'Escape') {
                setOpen(false);
            }
        });

        updateCodeHidden(dropdown.closest ? dropdown.closest('form') : null, dropdown);
    }

    function clearFocusFragment(source) {
        var parsed = parseUrl(source);

        parsed.searchParams.delete('focus');
        parsed.searchParams.delete('fragment');
        parsed.searchParams.set('fragment', 'detail');

        return serializeLike(source, parsed);
    }

    function fetchResults(root, fragmentUrl, stableUrl, push) {
        if (typeof window.fetch !== 'function') {
            if (stableUrl) {
                window.location.assign(stableUrl);
            }
            return;
        }

        var pane = root.querySelector('[data-pane="results"]');
        if (pane) {
            pane.setAttribute('aria-busy', 'true');
        }

        fetchHtml(fragmentUrl).then(function (html) {
            var resultsPane = root.querySelector('[data-pane="results"]');
            if (!resultsPane) {
                return;
            }
            resultsPane.innerHTML = html;
            resultsPane.removeAttribute('aria-busy');
            clearFetchError(resultsPane);
            updateSelection(root, root.dataset.focus);
            if (push && stableUrl) {
                window.history.pushState({}, '', stableUrl);
            }
            root.__browseResultsSignature = stableUrl
                ? signatureFromUrl(stableUrl)
                : resultsSignature();
            announce(root, message(root, 'results-updated', 'Resultados actualizados.'));
        }).catch(function () {
            handleFetchError(root, {
                url: stableUrl || window.location.href,
                retry: function () {
                    fetchResults(root, fragmentUrl, stableUrl, push);
                }
            });
        });
    }

    function replaceResults(root, stableUrl, fragmentUrl, push) {
        if (root.dataset.focus) {
            requestFragment(root, clearFocusFragment(stableUrl), stableUrl, {
                focus: '',
                push: false,
                focusPane: false,
                silent: true,
                messageKey: 'restored'
            });
        }

        fetchResults(root, fragmentUrl, stableUrl, push);
    }

    function appendResults(root, fragmentUrl, link) {
        var pane = root.querySelector('[data-pane="results"]');
        var list;
        var doc;
        var nextLoad;
        var currentFoot;
        var nextFoot;
        var stableUrl = link ? (link.getAttribute('href') || fragmentUrl) : fragmentUrl;

        if (typeof window.fetch !== 'function' || typeof window.DOMParser !== 'function') {
            window.location.assign(stableUrl);
            return;
        }

        list = pane ? pane.querySelector('.browse-results--explorer') : null;
        if (!pane || !list) {
            window.location.assign(stableUrl);
            return;
        }

        pane.setAttribute('aria-busy', 'true');
        fetchHtml(fragmentUrl).then(function (html) {
            doc = new window.DOMParser().parseFromString(html, 'text/html');
            Array.prototype.forEach.call(
                doc.querySelectorAll('.browse-results--explorer > li'),
                function (node) {
                    list.appendChild(document.importNode(node, true));
                }
            );

            nextLoad = doc.querySelector('[data-load-more]');
            currentFoot = pane.querySelector('.browse-results-foot');
            nextFoot = doc.querySelector('.browse-results-foot');
            if (currentFoot && currentFoot.parentNode && nextFoot) {
                currentFoot.parentNode.replaceChild(document.importNode(nextFoot, true), currentFoot);
            }

            pane.removeAttribute('aria-busy');
            clearFetchError(pane);
            updateSelection(root, root.dataset.focus);
            if (typeof window.history.pushState === 'function') {
                window.history.pushState({}, '', stableUrl);
            }
            root.__browseResultsSignature = signatureFromUrl(stableUrl);
            announce(root, message(root, 'results-updated', 'Resultados actualizados.'));
            if (nextLoad) {
                var replacement = pane.querySelector('[data-load-more]');
                if (replacement && typeof replacement.focus === 'function') {
                    replacement.focus();
                }
            }
        }).catch(function () {
            handleFetchError(root, {
                url: stableUrl,
                retry: function () {
                    appendResults(root, fragmentUrl, link);
                }
            });
        });
    }

    function initReactiveSearch(root, form) {
        var input = form.querySelector('input[name="q"]');
        if (!input || typeof window.fetch !== 'function') {
            return;
        }

        var timer = null;
        var controller = null;
        var lastQuery = (new URLSearchParams(window.location.search).get('q') || '').trim();
        root.__browseResultsSignature = resultsSignature();

        input.addEventListener('input', function () {
            var value = input.value.trim();
            if (value === lastQuery) {
                return;
            }

            if (timer !== null) {
                window.clearTimeout(timer);
                timer = null;
            }
            if (controller) {
                controller.abort();
                controller = null;
            }
            lastQuery = value;

            if (value.length < 2 || value.length > 80) {
                return;
            }

            timer = window.setTimeout(function () {
                var urls;
                var options;
                timer = null;
                urls = searchUrls(form);
                if (urls.signature === root.__browseResultsSignature) {
                    return;
                }

                options = {};
                if (typeof window.AbortController === 'function') {
                    controller = new window.AbortController();
                    options.signal = controller.signal;
                }
                if (root.querySelector('[data-pane="results"]')) {
                    root.querySelector('[data-pane="results"]').setAttribute('aria-busy', 'true');
                }
                fetchHtml(urls.fragment, options).then(function (html) {
                    var pane = root.querySelector('[data-pane="results"]');
                    if (!pane) {
                        return;
                    }
                    if (root.dataset.focus) {
                        requestFragment(root, clearFocusFragment(urls.stable), urls.stable, {
                            focus: '',
                            push: false,
                            focusPane: false,
                            silent: true,
                            messageKey: 'restored'
                        });
                    }
                    pane.innerHTML = html;
                    pane.removeAttribute('aria-busy');
                    clearFetchError(pane);
                    updateSelection(root, root.dataset.focus);
                    window.history.pushState({}, '', urls.stable);
                    root.__browseResultsSignature = urls.signature;
                    announce(root, message(root, 'results-updated', 'Resultados actualizados.'));
                    controller = null;
                }).catch(function (error) {
                    if (!error || error.name !== 'AbortError') {
                        controller = null;
                        handleFetchError(root, {
                            url: urls.stable,
                            retry: function () {
                                fetchResults(root, urls.fragment, urls.stable, true);
                            }
                        });
                    }
                });
            }, 350);
        });

        form.addEventListener('submit', function (event) {
            var urls;

            if (timer !== null) {
                window.clearTimeout(timer);
                timer = null;
            }
            if (controller) {
                controller.abort();
                controller = null;
            }

            updateCodeHidden(form, form.querySelector('[data-code-dropdown]'));
            urls = searchUrls(form);
            if (event && typeof event.preventDefault === 'function') {
                event.preventDefault();
            }
            replaceResults(root, urls.stable, urls.fragment, true);
            root.__browseResultsSignature = urls.signature;
        });
    }

    function handlePopState() {
        var form = document.querySelector('form.browse-form');
        var signature = resultsSignature();

        Array.prototype.forEach.call(document.querySelectorAll('[data-browse-explorer]'), function (root) {
            var key = focusFromUrl(window.location.href);

            if (signature !== root.__browseResultsSignature && form) {
                fetchResults(root, resultsFragmentFromUrl(window.location.href), null, false);
                root.__browseResultsSignature = signature;
            }

            if (key && key !== root.dataset.focus) {
                requestFragment(root, buildFragmentUrl(window.location.href, { focus: key }), window.location.href, {
                    focus: key,
                    push: false,
                    messageKey: 'restored'
                });
            } else if (!key && root.dataset.focus) {
                requestFragment(root, buildFragmentUrl(window.location.href), window.location.href, {
                    focus: '',
                    push: false,
                    messageKey: 'restored',
                    focusPane: false
                });
            }
        });
    }

    function init() {
        var roots = document.querySelectorAll('[data-browse-explorer]');
        var initialParams = new URLSearchParams(window.location.search);

        Array.prototype.forEach.call(roots, function (root) {
            var initialFocus;

            if (root.__browseExplorerReady) {
                return;
            }

            root.__browseExplorerReady = true;
            initialFocus = root.dataset.focus || '';
            if (root.__browseResultsSignature === undefined) {
                root.__browseResultsSignature = signatureFromUrl(window.location.href);
            }

            setFocus(root, initialFocus, root.querySelector('.browse-detail'));
            updateSelection(root, initialFocus);

            if (initialParams.has('tab')) {
                syncTabs(root, window.location.href);
            }

            if (initialParams.has('rel_view')) {
                syncRelView(root, window.location.href);
            }
            applyRelationFilters(root);

            var form = root.querySelector('form.browse-form');
            if (form) {
                initReactiveSearch(root, form);
                initCodeDropdown(form.querySelector('[data-code-dropdown]'));

                form.addEventListener('change', function (event) {
                    var target = event.target;
                    var urls;

                    if (!target || form.contains(target) === false) {
                        return;
                    }

                    var isCodeControl = target.hasAttribute
                        && (target.hasAttribute('data-code-input')
                            || target.hasAttribute('data-code-select-all'));

                    if (!isCodeControl && !target.name) {
                        return;
                    }

                    if (target.name === 'family') {
                        syncCodeDropdown(form, target.value);
                    }
                    if (isCodeControl) {
                        updateCodeHidden(form, form.querySelector('[data-code-dropdown]'));
                    }

                    if (!isCodeControl && RESULT_PARAMS.indexOf(target.name) === -1) {
                        return;
                    }

                    urls = searchUrls(form);
                    if (urls.signature === root.__browseResultsSignature) {
                        return;
                    }

                    replaceResults(root, urls.stable, urls.fragment, true);
                });
            }

            root.addEventListener('change', function (event) {
                var target = event.target;

                if (target && target.hasAttribute && target.hasAttribute('data-rel-filter')) {
                    applyRelationFilters(root);
                }
            });

            root.addEventListener('keydown', function (event) {
                var tab;
                var tabs;
                var index;
                var next;
                var mobileButton;
                var mobileButtons;

                if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight'
                    && event.key !== 'Home' && event.key !== 'End') {
                    return;
                }

                tab = closestFromEvent(event, '[role="tab"][data-tab]', root);
                if (tab) {
                    tabs = Array.prototype.slice.call(tab.closest('.browse-tabs').querySelectorAll('[role="tab"][data-tab]'));
                    index = tabs.indexOf(tab);
                    if (event.key === 'Home') {
                        next = 0;
                    } else if (event.key === 'End') {
                        next = tabs.length - 1;
                    } else {
                        next = index + (event.key === 'ArrowRight' ? 1 : -1);
                    }
                    if (next >= 0 && next < tabs.length && tabs[next] !== tab) {
                        event.preventDefault();
                        onFragmentLink(root, tabs[next]);
                    }
                    return;
                }

                mobileButton = closestFromEvent(event, '[data-mobile-view-target]', root);
                if (mobileButton) {
                    mobileButtons = Array.prototype.slice.call(
                        mobileButton.parentNode.querySelectorAll('[data-mobile-view-target]')
                    );
                    index = mobileButtons.indexOf(mobileButton);
                    next = event.key === 'Home' ? 0 : (event.key === 'End' ? mobileButtons.length - 1 : index + (event.key === 'ArrowRight' ? 1 : -1));
                    if (next >= 0 && next < mobileButtons.length) {
                        event.preventDefault();
                        setMobileView(root, mobileButtons[next].getAttribute('data-mobile-view-target'));
                        mobileButtons[next].focus();
                    }
                }
            });

            root.addEventListener('click', function (event) {
                var domainLink;
                var domainCode;
                var domainSelect;
                var stableUrl;
                var mobileButton;
                var copyButton;
                var copyRecordButton;
                var compareLink;
                var fragmentLink;
                var loadMoreLink;
                var resultLink;
                var diagramLink;

                if (!isPlainClick(event)) {
                    return;
                }

                domainLink = closestFromEvent(event, '[data-domain-url][data-domain-code]', root);
                if (domainLink) {
                    event.preventDefault();
                    domainCode = domainLink.getAttribute('data-domain-code') || '';
                    stableUrl = domainLink.getAttribute('data-domain-url') || domainLink.getAttribute('href') || '';
                    domainSelect = form ? form.querySelector('select[name="domain"]') : null;

                    if (domainSelect) {
                        domainSelect.value = domainCode;
                    }
                    if (form) {
                        syncDomainForm(form, domainCode);
                    }
                    if (stableUrl !== '') {
                        replaceResults(root, stableUrl, resultsFragmentFromUrl(stableUrl), true);
                    }
                    return;
                }

                mobileButton = closestFromEvent(event, '[data-mobile-view-target]', root);
                if (mobileButton) {
                    event.preventDefault();
                    setMobileView(root, mobileButton.getAttribute('data-mobile-view-target'));
                    return;
                }

                copyButton = closestFromEvent(event, '[data-copy]', root);
                if (copyButton) {
                    event.preventDefault();
                    onCopy(root, copyButton);
                    return;
                }

                copyRecordButton = closestFromEvent(event, '[data-copy-record]', root);
                if (copyRecordButton) {
                    event.preventDefault();
                    onCopyRecord(root, copyRecordButton);
                    return;
                }

                compareLink = closestFromEvent(event, '.browse-compare-link[data-compare-url]', root);
                if (compareLink) {
                    event.preventDefault();
                    onCompareClick(root, compareLink);
                    return;
                }

                fragmentLink = closestFromEvent(event, '[data-tab][data-url], [data-rel-view][data-url]', root);
                if (fragmentLink) {
                    event.preventDefault();
                    onFragmentLink(root, fragmentLink);
                    return;
                }

                loadMoreLink = closestFromEvent(event, '[data-load-more][data-load-more-url]', root);
                if (loadMoreLink) {
                    event.preventDefault();
                    appendResults(
                        root,
                        loadMoreLink.getAttribute('data-load-more-url'),
                        loadMoreLink
                    );
                    return;
                }

                resultLink = closestFromEvent(
                    event,
                    '.browse-result-link[data-focus-url], .browse-relations-link[data-focus-url]',
                    root
                );
                if (resultLink) {
                    event.preventDefault();
                    onResultClick(root, resultLink);
                    return;
                }

                diagramLink = closestFromEvent(event, 'a.browse-diagram__node[data-focus-url]', root);
                if (diagramLink) {
                    event.preventDefault();
                    onResultClick(root, diagramLink);
                }
            });
        });

        if (!window.__browseExplorerPopstateReady) {
            window.__browseExplorerPopstateReady = true;
            window.addEventListener('popstate', handlePopState);
        }
    }

    ready(init);
})();
