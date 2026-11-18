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

        if ($catalog !== null && !CatalogRepository::isValidCatalog($catalog)) {
            return ['ok' => false, 'error' => 'invalid_catalog', 'item' => null, 'sections' => $emptySections];
        }

        if (!CatalogRepository::available()) {
            return ['ok' => false, 'error' => 'not_configured', 'item' => null, 'sections' => $emptySections];
        }

        try {
            $item = CatalogRepository::find(
                $id,
                $language,
                CatalogRepository::normalizeCatalog($catalog)
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
                CatalogRepository::normalizeCatalog($catalog)
            );
        } catch (RepositoryException) {
            // La ficha básica sigue siendo válida aunque fall una sección optativa.
            $sections = $emptySections;
        }

        return ['ok' => true, 'error' => null, 'item' => $item, 'sections' => $sections];
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
        if ($catalog !== null && !CatalogRepository::isValidCatalog($catalog)) {
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
                    CatalogRepository::normalizeCatalog($catalog)
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
