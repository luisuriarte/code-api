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

    /** @return array{ok: bool, error: ?string, items: list<array<string, mixed>>, total: int, page: int, pages: int, has_more: bool} */
    public static function search(
        string $query,
        string $domain,
        string $language,
        int $page,
        int $limit,
        ?string $catalog = null
    ): array {
        $limit = max(1, min(self::MAX_LIMIT, $limit));
        $page = max(1, $page);
        $offset = min(5000, ($page - 1) * $limit);
        $catalog = ($catalog ?? '') !== '' ? $catalog : null;

        if ($domain !== '' && !CatalogRepository::isValidDomain($domain)) {
            return self::empty('invalid_domain', $page);
        }

        if ($catalog !== null) {
            if (!CatalogRepository::isValidCatalog($catalog)) {
                return self::empty('invalid_catalog', $page);
            }
            if ($domain !== '' && $domain !== 'odontologia') {
                return self::empty('invalid_catalog', $page);
            }
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

        try {
            $result = CatalogRepository::search(
                $query,
                $domain,
                $language,
                $limit,
                $offset,
                CatalogRepository::normalizeCatalog($catalog)
            );
        } catch (RepositoryException) {
            return self::empty('error_query', $page);
        }

        return [
            'ok' => true,
            'error' => null,
            'items' => $result['items'],
            'total' => $result['total'],
            'page' => $page,
            'pages' => max(1, (int) ceil($result['total'] / $limit)),
            'has_more' => $result['has_more'],
        ];
    }

    /** @return array{ok: bool, error: ?string, item: ?array<string, mixed>} */
    public static function detail(string $id, string $language, ?string $catalog = null): array
    {
        $catalog = ($catalog ?? '') !== '' ? $catalog : null;

        if ($catalog !== null && !CatalogRepository::isValidCatalog($catalog)) {
            return ['ok' => false, 'error' => 'invalid_catalog', 'item' => null];
        }

        if (!CatalogRepository::available()) {
            return ['ok' => false, 'error' => 'not_configured', 'item' => null];
        }

        try {
            $item = CatalogRepository::find(
                $id,
                $language,
                CatalogRepository::normalizeCatalog($catalog)
            );
        } catch (RepositoryException) {
            return ['ok' => false, 'error' => 'error_query', 'item' => null];
        }

        return ['ok' => $item !== null, 'error' => $item === null ? 'no_results' : null, 'item' => $item];
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
