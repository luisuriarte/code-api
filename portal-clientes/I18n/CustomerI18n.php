<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\I18n;

use OrigenSalud\Web\I18n;

/**
 * Reutiliza el mecanismo i18n existente (Symfony Translator + YAML) con un
 * dominio separado para el portal de clientes. No modifica los catálogos del
 * portal público ni de gobernanza.
 */
final class CustomerI18n
{
    private const DOMAIN = 'customer_portal';

    private static bool $loaded = false;

    public static function boot(?string $routeLocale = null): string
    {
        return I18n::boot($routeLocale);
    }

    public static function locale(): string
    {
        return I18n::locale();
    }

    public static function canonical(?string $locale): ?string
    {
        return I18n::canonical($locale);
    }

    /** @return list<string> */
    public static function supported(): array
    {
        return I18n::supported();
    }

    /** @param array<string, string|int|float> $parameters */
    public static function t(string $key, array $parameters = []): string
    {
        self::loadResources();

        $locale = self::locale();

        return I18n::translator($locale)->trans($key, $parameters, self::DOMAIN, $locale);
    }

    private static function loadResources(): void
    {
        if (self::$loaded) {
            return;
        }

        $directory = dirname(__DIR__) . '/translations';

        foreach (self::supported() as $locale) {
            $file = $directory . '/messages.' . $locale . '.yaml';

            if (is_file($file)) {
                I18n::translator($locale)->addResource('yaml', $file, $locale, self::DOMAIN);
            }
        }

        self::$loaded = true;
    }
}
