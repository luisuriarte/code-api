<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Services;

use OrigenSalud\Portal\Config;
use OrigenSalud\Portal\Repositories\CatalogRepository;
use OrigenSalud\Portal\Repositories\RepositoryException;

/**
 * Orquesta la búsqueda del explorador: normaliza parámetros, aplica límites y
 * convierte errores de repositorio a códigos seguros para la vista.
 */
final class BrowseService
{
    public const DEFAULT_LIMIT = 20;
    public const MAX_LIMIT = 100;
    public const MAX_COMPARE = 4;
    public const MAX_HISTORY = 8;
    private const CACHE_TTL = 60;

    /** @var array<string, array{time: int, value: array<string, mixed>}> */
    private static array $searchCache = [];

    /** @var array<string, array{time: int, value: array<string, mixed>}> */
    private static array $facetCache = [];

    /** @var array<string, array{time: int, value: array<string, mixed>}> */
    private static array $detailCache = [];

    /** @return array{ok: bool, error: ?string, items: list<array<string, mixed>>, total: int, page: int, pages: int, has_more: bool} */
    public static function search(
        string $query,
        string $domain,
        string $language,
        int $page,
        int $limit,
        ?string $catalog = null,
        array $filters = []
    ): array {
        $limit = max(1, min(self::MAX_LIMIT, $limit));
        $page = max(1, $page);
        $offset = min(5000, ($page - 1) * $limit);
        $catalogs = CatalogRepository::normalizeCatalogs($catalog);
        $filters = CatalogRepository::normalizeFilters($filters);

        if ($domain !== '' && !CatalogRepository::isValidDomain($domain)) {
            return self::empty('invalid_domain', $page);
        }

        if (($catalog ?? '') !== '' && $catalogs === []) {
            return self::empty('invalid_catalog', $page);
        }

        if ($catalogs !== [] && $domain !== '' && $domain !== 'odontologia') {
            return self::empty('invalid_catalog', $page);
        }

        if (!CatalogRepository::available()) {
            return self::empty('not_configured', $page);
        }

        if ($query !== '') {
            $limits = Config::rateLimits();
            if (!RateLimiter::hit('browse', $limits['browse'], $limits['window'])) {
                return self::empty('error_query', $page);
            }
        }

        $cacheKey = self::cacheKey('search', [
            $query, $domain, $language, $page, $limit, $catalogs, $filters,
        ]);
        $cached = self::cacheRead(self::$searchCache, $cacheKey);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $result = CatalogRepository::search(
                $query,
                $domain,
                $language,
                $limit,
                $offset,
                implode(',', $catalogs),
                $filters
            );
        } catch (RepositoryException) {
            return self::empty('error_query', $page);
        }

        $response = [
            'ok' => true,
            'error' => null,
            'items' => $result['items'],
            'total' => $result['total'],
            'page' => $page,
            'pages' => max(1, (int) ceil($result['total'] / $limit)),
            'has_more' => $result['has_more'],
        ];
        self::$searchCache[$cacheKey] = ['time' => time(), 'value' => $response];

        return $response;
    }

    /**
     * Ficha integral del concepto. Las secciones sin datos reales quedan vacías
     * para que la vista omita la pestaña correspondiente.
     *
     * @return array{ok: bool, error: ?string, item: ?array<string, mixed>, sections: array<string, mixed>}
     */
    public static function detail(string $id, string $language, ?string $catalog = null): array
    {
        $catalog = ($catalog ?? '') !== '' ? $catalog : null;
        $emptySections = self::emptySections();

        if ($catalog !== null && self::normalizeCatalogs($catalog) === []) {
            return ['ok' => false, 'error' => 'invalid_catalog', 'item' => null, 'sections' => $emptySections];
        }

        if (!CatalogRepository::available()) {
            return ['ok' => false, 'error' => 'not_configured', 'item' => null, 'sections' => $emptySections];
        }

        $catalogs = self::normalizeCatalogs($catalog);
        $cacheKey = self::cacheKey('detail', [$id, $language, $catalogs]);
        $cached = self::cacheRead(self::$detailCache, $cacheKey);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $item = CatalogRepository::find(
                $id,
                $language,
                implode(',', $catalogs)
            );
        } catch (RepositoryException) {
            return ['ok' => false, 'error' => 'error_query', 'item' => null, 'sections' => $emptySections];
        }

        if ($item === null) {
            return ['ok' => false, 'error' => 'no_results', 'item' => null, 'sections' => $emptySections];
        }

        try {
            $sections = CatalogRepository::detailSections(
                $id,
                $language,
                implode(',', $catalogs)
            );
        } catch (RepositoryException) {
            // La ficha básica sigue siendo válida aunque fall una sección optativa.
            $sections = $emptySections;
        }

        $response = ['ok' => true, 'error' => null, 'item' => $item, 'sections' => $sections];
        self::$detailCache[$cacheKey] = ['time' => time(), 'value' => $response];

        return $response;
    }

    /**
     * @return list<array{key: string, item: array<string, mixed>}>
     */
    public static function compareItems(string $keys, string $language, ?string $catalog = null): array
    {
        $normalized = self::normalizeCompare($keys);
        if (count($normalized) < 2) {
            return [];
        }

        $catalog = ($catalog ?? '') !== '' ? $catalog : null;
        $catalogs = self::normalizeCatalogs($catalog);
        if (($catalog ?? '') !== '' && $catalogs === []) {
            return [];
        }
        if (!CatalogRepository::available()) {
            return [];
        }

        $items = [];
        try {
            foreach ($normalized as $key) {
                $item = CatalogRepository::find(
                    $key,
                    $language,
                    implode(',', $catalogs)
                );
                if ($item !== null) {
                    $items[] = ['key' => $key, 'item' => $item];
                }
            }
        } catch (RepositoryException) {
            return [];
        }

        return $items;
    }

    /** @return list<array{code: string, label: string}> */
    public static function domains(string $locale): array
    {
        if (!CatalogRepository::available()) {
            return [];
        }

        try {
            return CatalogRepository::domains($locale);
        } catch (RepositoryException) {
            return [];
        }
    }

    /**
     * Opciones reales de los filtros. Se cachean porque cambian con mucha
     * menos frecuencia que los resultados de búsqueda.
     *
     * @return array{families: list<array{code: string, label: string}>, types: list<array{code: string, label: string}>, categories: list<array{code: string, label: string}>, versions: list<array{code: string, label: string}>, statuses: list<array{code: string, label: string}>}
     */
    public static function facets(): array
    {
        $empty = ['families' => [], 'types' => [], 'categories' => [], 'versions' => [], 'statuses' => []];
        if (!CatalogRepository::available()) {
            return $empty;
        }

        $cacheKey = self::cacheKey('facets', []);
        $cached = self::cacheRead(self::$facetCache, $cacheKey);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $facets = CatalogRepository::catalogFacets();
        } catch (RepositoryException) {
            return $empty;
        }

        self::$facetCache[$cacheKey] = ['time' => time(), 'value' => $facets];

        return $facets;
    }

    /** @param array<string, mixed> $parts */
    private static function cacheKey(string $prefix, array $parts): string
    {
        return $prefix . ':' . md5((string) json_encode($parts, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }

    /**
     * @param array<string, array{time: int, value: array<string, mixed>}> $store
     *
     * @return array<string, mixed>|null
     */
    private static function cacheRead(array &$store, string $key): ?array
    {
        $entry = $store[$key] ?? null;
        if ($entry === null || time() - $entry['time'] >= self::CACHE_TTL) {
            unset($store[$key]);

            return null;
        }

        return $entry['value'];
    }

    /** @return list<string> */
    public static function normalizeCatalogs(?string $catalog): array
    {
        return CatalogRepository::normalizeCatalogs($catalog);
    }

    /**
     * @param array<string, mixed> $filters
     *
     * @return array<string, string>
     */
    public static function normalizeFilters(array $filters): array
    {
        return CatalogRepository::normalizeFilters($filters);
    }

    /** Valida una clave de resultado sin normalizar el código que contiene. */
    public static function normalizeResultKey(mixed $value): string
    {
        $value = Validator::text(is_string($value) ? rawurldecode($value) : '', 200);

        if (preg_match('/^([a-z0-9_]+):([A-Za-z0-9_.:-]{1,100})$/', $value, $matches) !== 1) {
            return '';
        }

        return CatalogRepository::isValidDomain($matches[1]) ? $value : '';
    }

    /** @return list<string> */
    public static function normalizeCompare(mixed $raw): array
    {
        return self::normalizeKeyList($raw, self::MAX_COMPARE);
    }

    /** @return list<string> */
    public static function normalizeHistory(mixed $raw): array
    {
        return self::normalizeKeyList($raw, self::MAX_HISTORY);
    }

    /** @return array<string, list<array<string, mixed>>> */
    private static function emptySections(): array
    {
        return [
            'concept' => [],
            'relations' => [],
            'values' => [],
            'validity' => [],
            'clinical' => [],
            'trace' => [],
        ];
    }

    /** @return list<string> */
    private static function normalizeKeyList(mixed $raw, int $max): array
    {
        if (!is_scalar($raw)) {
            return [];
        }

        $keys = [];
        foreach (explode(',', (string) $raw) as $piece) {
            $key = self::normalizeResultKey($piece);
            if ($key === '' || in_array($key, $keys, true)) {
                continue;
            }
            $keys[] = $key;
            if (count($keys) >= $max) {
                break;
            }
        }

        return $keys;
    }

    /** @return array{ok: bool, error: ?string, items: list<array<string, mixed>>, total: int, page: int, pages: int, has_more: bool} */
    private static function empty(string $error, int $page): array
    {
        return [
            'ok' => false,
            'error' => $error,
            'items' => [],
            'total' => 0,
            'page' => $page,
            'pages' => 1,
            'has_more' => false,
        ];
    }
}
