<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\Services\BrowseService;
use OrigenSalud\Portal\Services\Validator;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

final class BrowseController
{
    private const TABS = ['concept', 'relations', 'values', 'validity', 'clinical', 'trace'];
    private const REL_VIEWS = ['table', 'diagram'];
    private const FILTER_KEYS = ['family', 'type', 'category', 'status', 'version', 'validity'];

    public static function index(string $locale, string $currentPath): void
    {
        self::explorer($locale, $currentPath, null);
    }

    public static function detail(string $locale, string $currentPath, string $id): void
    {
        self::explorer($locale, $currentPath, rawurldecode($id));
    }

    private static function explorer(string $locale, string $currentPath, ?string $routeKey): void
    {
        $t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
        $apiLocale = I18n::metadata($locale)['api_language'];
        $fragmentMode = Validator::choice($_GET['fragment'] ?? '', ['detail', 'results']);
        $isDetailFragment = $fragmentMode === 'detail';
        $isResultsFragment = $fragmentMode === 'results';

        $query = Validator::text($_GET['q'] ?? '', 80);
        $domain = self::domainParam();
        $domainCodes = BrowseService::normalizeDomains($domain);
        $domain = implode(',', $domainCodes);
        $rawCatalog = self::catalogParam();
        $catalogs = BrowseService::normalizeCatalogs($rawCatalog);
        $catalog = implode(',', $catalogs);
        $filters = BrowseService::normalizeFilters(self::filtersParam());
        $facets = $fragmentMode === '' ? BrowseService::facets() : [];
        $page = self::pageParam();
        $limit = min(BrowseService::MAX_LIMIT, self::limitParam());

        $focus = $routeKey !== null
            ? BrowseService::normalizeResultKey($routeKey)
            : BrowseService::normalizeResultKey($_GET['focus'] ?? '');
        $tab = Validator::choice($_GET['tab'] ?? '', self::TABS);
        $tab = $tab === '' ? 'concept' : $tab;
        $relView = Validator::choice($_GET['rel_view'] ?? '', self::REL_VIEWS);
        $relView = $relView === '' ? 'table' : $relView;

        $compare = BrowseService::normalizeCompare($_GET['compare'] ?? '');
        $history = BrowseService::normalizeHistory($_GET['history'] ?? '');

        $result = $isDetailFragment
            ? self::emptySearch($page)
            : BrowseService::search($query, $domain, $apiLocale, $page, $limit, $rawCatalog, $filters);
        $domains = $fragmentMode !== '' ? [] : BrowseService::domains($locale);

        $detail = self::emptyDetail();
        if ($focus !== '' && !$isResultsFragment) {
            $detail = BrowseService::detail($focus, $apiLocale, $rawCatalog);
        }

        $compareItems = (!$isResultsFragment && count($compare) >= 2)
            ? BrowseService::compareItems(implode(',', $compare), $apiLocale, $rawCatalog)
            : [];

        $baseBrowsePath = I18n::localizedPath($locale, '/browse');
        $stablePath = $focus !== ''
            ? I18n::localizedPath($locale, '/browse/' . rawurlencode($focus))
            : $baseBrowsePath;

        $filterState = [];
        foreach (self::FILTER_KEYS as $key) {
            $filterState[$key] = $filters[$key] ?? null;
        }

        $state = array_filter(array_merge([
            'q' => $query,
            'domain' => $domain,
            'catalog' => $catalog,
        ], $filterState, [
            'page' => $page > 1 ? $page : null,
            'limit' => $limit !== BrowseService::DEFAULT_LIMIT ? $limit : null,
            'tab' => $tab !== 'concept' ? $tab : null,
            'rel_view' => $relView !== 'table' ? $relView : null,
            'compare' => $compare !== [] ? implode(',', $compare) : null,
            'history' => $history !== [] ? implode(',', $history) : null,
        ]), static fn ($value) => $value !== '' && $value !== null);

        $contentKeys = array_flip(array_merge(['q', 'domain', 'catalog'], self::FILTER_KEYS, ['page', 'limit']));
        $contentParams = array_intersect_key($state, $contentKeys);
        $canonicalQuery = $contentParams === []
            ? ''
            : '?' . http_build_query($contentParams, '', '&', PHP_QUERY_RFC3986);
        $canonicalPath = $stablePath . $canonicalQuery;

        $backUrl = $baseBrowsePath . $canonicalQuery;

        $structuredData = self::structuredData($detail, $stablePath);
        $title = $detail['ok'] && is_array($detail['item'])
            ? self::itemTitle($detail['item'])
            : $t('browse.title');

        $data = [
            'pageTitle' => $title . ' | Origen Salud',
            'pageDescription' => $t('browse.lead'),
            'locale' => $locale,
            'currentPath' => $canonicalPath,
            'bodyClass' => 'page-browse',
            'query' => $query,
            'domain' => $domain,
            'domainCodes' => $domainCodes,
            'catalog' => $catalog,
            'catalogs' => $catalogs,
            'filters' => $filters,
            'facets' => $facets,
            'domains' => $domains,
            'result' => $result,
            'detail' => $detail,
            'compareItems' => $compareItems,
            'focus' => $focus,
            'tab' => $tab,
            'relView' => $relView,
            'historyKeys' => $history,
            'state' => $state,
            'apiLocale' => $apiLocale,
            'baseBrowsePath' => $baseBrowsePath,
            'stablePath' => $stablePath,
            'backUrl' => $backUrl,
            'structuredData' => $structuredData,
        ];

        if ($fragmentMode === '') {
            $data['scripts'] = ['/assets/js/browse-explorer.js'];
        }

        $template = $isResultsFragment
            ? 'browse-results-fragment'
            : ($isDetailFragment ? 'browse-fragment' : 'browse');
        View::render($template, $data, $fragmentMode === '' ? 'main' : null);
    }

    /**
     * El selector múltiple envía `domain[]`/`catalog[]`; los campos ocultos y
     * las URLs canónicas usan `domain`/`catalog`. Se combinan ambos canales.
     *
     * @return list<string>
     */
    private static function paramValues(string $key): array
    {
        $values = [];
        foreach ([$key, $key . '[]'] as $name) {
            $raw = $_GET[$name] ?? null;
            if ($raw === null) {
                continue;
            }
            $items = is_array($raw) ? $raw : [$raw];
            foreach ($items as $item) {
                if (!is_scalar($item)) {
                    continue;
                }
                foreach (explode(',', (string) $item) as $value) {
                    $code = Validator::text($value, 64);
                    // "Todos" es la ausencia de filtro. Nunca debe llegar como
                    // código: normalizeDomains() lo descartaría y la búsqueda
                    // devolvería invalid_domain sin resultados.
                    if ($code !== '' && $code !== '__all__') {
                        $values[$code] = true;
                    }
                }
            }
        }

        return array_keys($values);
    }

    private static function domainParam(): string
    {
        return implode(',', self::paramValues('domain'));
    }

    private static function catalogParam(): ?string
    {
        // Los siete catálogos publicados separados por coma ocupan 136 caracteres.
        // Un tope de 64 recortaba "…regional-ar" y descartaba el NOA al combinarlo
        // con CAO, aunque ambos estuvieran en la whitelist.
        $values = self::paramValues('catalog');
        $catalog = implode(',', $values);

        return $catalog === '' ? null : $catalog;
    }

    /** @return array<string, string> */
    private static function filtersParam(): array
    {
        $filters = [];
        foreach (self::FILTER_KEYS as $key) {
            $value = $_GET[$key] ?? '';
            if (!is_scalar($value)) {
                continue;
            }
            $text = Validator::text($value, 64);
            if ($text !== '') {
                $filters[$key] = $text;
            }
        }

        return $filters;
    }

    private static function pageParam(): int
    {
        $raw = $_GET['page'] ?? 1;

        return is_scalar($raw) && ctype_digit((string) $raw) ? max(1, (int) $raw) : 1;
    }

    private static function limitParam(): int
    {
        $raw = $_GET['limit'] ?? BrowseService::DEFAULT_LIMIT;

        return is_scalar($raw) && ctype_digit((string) $raw)
            ? max(1, (int) $raw)
            : BrowseService::DEFAULT_LIMIT;
    }

    /**
     * @return array{ok: bool, error: ?string, item: ?array<string, mixed>, sections: array<string, mixed>}
     */
    private static function emptyDetail(): array
    {
        return [
            'ok' => false,
            'error' => null,
            'item' => null,
            'sections' => [
                'concept' => [],
                'relations' => [],
                'relations_by_class' => [
                    'clinical' => [],
                    'terminological' => [],
                ],
                'values' => [],
                'validity' => [],
                'clinical' => [],
                'trace' => [],
                'uvr' => [],
            ],
        ];
    }

    /** @return array{ok: bool, error: ?string, items: list<array<string, mixed>>, total: int, page: int, pages: int, has_more: bool} */
    private static function emptySearch(int $page): array
    {
        return [
            'ok' => true,
            'error' => null,
            'items' => [],
            'total' => 0,
            'page' => $page,
            'pages' => 1,
            'has_more' => false,
        ];
    }

    /** @param array<string, mixed> $detail */
    private static function structuredData(array $detail, string $stablePath): ?array
    {
        if (!$detail['ok'] || !is_array($detail['item'] ?? null)) {
            return null;
        }

        $item = $detail['item'];
        $code = is_string($item['code'] ?? null) ? trim($item['code']) : '';
        $term = is_string($item['term'] ?? null) ? trim($item['term']) : '';
        $name = $term !== '' ? $term : $code;
        if ($name === '' || $code === '') {
            return null;
        }

        $data = [
            '@context' => 'https://schema.org',
            '@type' => 'DefinedTerm',
            'name' => $name,
            'identifier' => $code,
            'url' => Config::baseUrl() . $stablePath,
        ];

        $catalogName = $item['subtitle'] ?? null;
        if (is_string($catalogName) && $catalogName !== '') {
            $data['inDefinedTermSet'] = [
                '@type' => 'DefinedTermSet',
                'name' => $catalogName,
            ];
        }

        return $data;
    }

    /** @param array<string, mixed> $item */
    private static function itemTitle(array $item): string
    {
        $term = $item['term'] ?? '';

        return is_string($term) && $term !== '' ? $term : (string) ($item['code'] ?? '');
    }
}
