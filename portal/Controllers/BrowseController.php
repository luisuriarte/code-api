<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Services\BrowseService;
use OrigenSalud\Portal\Services\Validator;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

final class BrowseController
{
    public static function index(string $locale, string $currentPath): void
    {
        $t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
        $apiLocale = I18n::metadata($locale)['api_language'];

        $query = Validator::text($_GET['q'] ?? '', 200);
        $domain = Validator::text($_GET['domain'] ?? '', 64);
        $catalog = self::catalogParam();
        $page = self::pageParam();
        $limit = self::limitParam();

        $result = BrowseService::search($query, $domain, $apiLocale, $page, $limit, $catalog);
        $domains = BrowseService::domains($locale);

        View::render('browse', [
            'pageTitle' => $t('browse.title') . ' | Origen Salud',
            'pageDescription' => $t('browse.lead'),
            'locale' => $locale,
            'currentPath' => $currentPath,
            'query' => $query,
            'domain' => $domain,
            'catalog' => $catalog,
            'domains' => $domains,
            'result' => $result,
            'apiLocale' => $apiLocale,
            'baseBrowsePath' => I18n::localizedPath($locale, '/browse'),
        ]);
    }

    public static function detail(string $locale, string $currentPath, string $id): void
    {
        $t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);
        $apiLocale = I18n::metadata($locale)['api_language'];
        $id = Validator::text(rawurldecode($id), 200);
        $catalog = self::catalogParam();
        $backPage = self::pageParam();

        $result = BrowseService::detail($id, $apiLocale, $catalog);

        $backParams = array_filter([
            'q' => Validator::text($_GET['q'] ?? '', 200),
            'domain' => Validator::text($_GET['domain'] ?? '', 64),
            'catalog' => $catalog,
            'page' => $backPage > 1 ? $backPage : null,
        ], static fn ($value) => $value !== '' && $value !== null);
        $backPath = I18n::localizedPath($locale, '/browse');
        $backUrl = $backPath
            . ($backParams === [] ? '' : '?' . http_build_query($backParams, '', '&', PHP_QUERY_RFC3986));

        View::render('browse-detail', [
            'pageTitle' => ($result['item'] !== null ? self::itemTitle($result['item']) : $t('browse.detail_title'))
                . ' | Origen Salud',
            'pageDescription' => $t('browse.lead'),
            'locale' => $locale,
            'currentPath' => $currentPath,
            'id' => $id,
            'result' => $result,
            'apiLocale' => $apiLocale,
            'catalog' => $catalog,
            'backUrl' => $backUrl,
        ]);
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

    /** @param array<string, mixed> $item */
    private static function itemTitle(array $item): string
    {
        $term = $item['term'] ?? '';

        return is_string($term) && $term !== '' ? $term : (string) ($item['code'] ?? '');
    }
}
