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
        $fragment = Validator::choice($_GET['fragment'] ?? '', ['detail']) === 'detail';

        $query = Validator::text($_GET['q'] ?? '', 80);
        $domain = Validator::text($_GET['domain'] ?? '', 64);
        $catalog = self::catalogParam();
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

        $result = $fragment
            ? self::emptySearch($page)
            : BrowseService::search($query, $domain, $apiLocale, $page, $limit, $catalog);
        $domains = $fragment ? [] : BrowseService::domains($locale);

        $detail = self::emptyDetail();
        if ($focus !== '') {
            $detail = BrowseService::detail($focus, $apiLocale, $catalog);
        }

        $compareItems = count($compare) >= 2
            ? BrowseService::compareItems(implode(',', $compare), $apiLocale, $catalog)
            : [];

        $baseBrowsePath = I18n::localizedPath($locale, '/browse');
        $stablePath = $focus !== ''
            ? I18n::localizedPath($locale, '/browse/' . rawurlencode($focus))
            : $baseBrowsePath;
        $canonicalPath = $focus !== '' ? $stablePath : $currentPath;

        $state = array_filter([
            'q' => $query,
            'domain' => $domain,
            'catalog' => $catalog,
            'page' => $page > 1 ? $page : null,
            'limit' => $limit !== BrowseService::DEFAULT_LIMIT ? $limit : null,
            'tab' => $tab !== 'concept' ? $tab : null,
            'rel_view' => $relView !== 'table' ? $relView : null,
            'compare' => $compare !== [] ? implode(',', $compare) : null,
            'history' => $history !== [] ? implode(',', $history) : null,
        ], static fn ($value) => $value !== '' && $value !== null);

        $backParams = array_intersect_key($state, array_flip(['q', 'domain', 'catalog', 'page', 'limit']));
        $backUrl = $baseBrowsePath
            . ($backParams === [] ? '' : '?' . http_build_query($backParams, '', '&', PHP_QUERY_RFC3986));

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
            'catalog' => $catalog,
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

        if (!$fragment) {
            $data['scripts'] = ['/assets/js/browse-explorer.js'];
        }

        View::render($fragment ? 'browse-fragment' : 'browse', $data, $fragment ? null : 'main');
    }

    private static function catalogParam(): ?string
    {
        $raw = $_GET['catalog'] ?? '';
        $catalog = is_scalar($raw) ? Validator::text($raw, 32) : '';

        return $catalog === '' ? null : $catalog;
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
                'values' => [],
                'validity' => [],
                'clinical' => [],
                'trace' => [],
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
