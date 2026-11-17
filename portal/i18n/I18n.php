<?php

declare(strict_types=1);

/**
 * Internacionalización del portal web (med.origen.ar).
 *
 * Idiomas seleccionables: es-AR (por defecto), en y pt-BR.
 * El idioma se resuelve en este orden:
 *   1. Segmento de la URL (/es-AR/, /en/, /pt-BR/)
 *   2. Parámetro legacy ?lang=
 *   3. Cookie persistente
 *   4. Header Accept-Language
 *   5. WEB_DEFAULT_LOCALE
 *
 * Las URLs canónicas llevan prefijo de idioma; el selector ya no genera ?lang=.
 */

namespace OrigenSalud\Web {
    use Symfony\Component\Translation\Loader\YamlFileLoader;
    use Symfony\Component\Translation\Translator;

    final class I18n
    {
        public const SUPPORTED = ['es-AR', 'en', 'pt-BR'];
        public const DEFAULT_LOCALE = 'es-AR';
        public const COOKIE_NAME = 'origen_locale';

        /** Alias de entrada. No se aplican a etiquetas de origen como es-MX. */
        private const ALIASES = [
            'es' => 'es-AR',
            'pt' => 'pt-BR',
        ];

        /** @var array<string, array{hreflang: string, og_locale: string, label: string, short: string, api_language: string}> */
        private const METADATA = [
            'es-AR' => [
                'hreflang' => 'es-AR',
                'og_locale' => 'es_AR',
                'label' => 'Español (Argentina)',
                'short' => 'ES',
                'api_language' => 'es-AR',
            ],
            'en' => [
                'hreflang' => 'en',
                'og_locale' => 'en_US',
                'label' => 'English',
                'short' => 'EN',
                'api_language' => 'en',
            ],
            'pt-BR' => [
                'hreflang' => 'pt-BR',
                'og_locale' => 'pt_BR',
                'label' => 'Português (Brasil)',
                'short' => 'PT',
                'api_language' => 'pt-BR',
            ],
        ];

        private const COOKIE_TTL = 31536000;
        private const DOMAIN = 'messages';

        private static ?string $locale = null;

        /** @var array<string, Translator> */
        private static array $translators = [];

        /**
         * Inicializa el locale de la petición. El locale de la URL tiene prioridad.
         */
        public static function boot(?string $routeLocale = null): string
        {
            $requested = $routeLocale;

            if ($requested === null && isset($_GET['lang']) && is_string($_GET['lang'])) {
                $requested = $_GET['lang'];
            }

            $locale = self::resolve($requested);
            self::$locale = $locale;
            self::remember($locale);

            return $locale;
        }

        public static function locale(): string
        {
            return self::$locale ?? self::DEFAULT_LOCALE;
        }

        /** @return list<string> */
        public static function supported(): array
        {
            return self::SUPPORTED;
        }

        public static function canonical(?string $locale): ?string
        {
            if ($locale === null) {
                return null;
            }

            $tag = strtolower(trim($locale));

            if ($tag === '') {
                return null;
            }

            if (isset(self::ALIASES[$tag])) {
                return self::ALIASES[$tag];
            }

            foreach (self::SUPPORTED as $supported) {
                if (strtolower($supported) === $tag) {
                    return $supported;
                }
            }

            return str_starts_with($tag, 'en-') ? 'en' : null;
        }

        /** @return array{hreflang: string, og_locale: string, label: string, short: string, api_language: string} */
        public static function metadata(?string $locale = null): array
        {
            $canonical = self::canonical($locale) ?? self::locale();

            return self::METADATA[$canonical] ?? self::METADATA[self::DEFAULT_LOCALE];
        }

        /**
         * Construye una ruta canónica con prefijo de idioma.
         */
        public static function localizedPath(string $locale, string $path = '/'): string
        {
            $canonical = self::canonical($locale) ?? self::DEFAULT_LOCALE;
            $suffix = self::stripLocalePrefix($path);

            return '/' . $canonical . '/' . ($suffix === '' ? '' : ltrim($suffix, '/'));
        }

        /**
         * @return list<array{hreflang: string, href: string, label: string, short: string, active: bool}>
         */
        public static function alternateLinks(string $currentPath, string $baseUrl = ''): array
        {
            $active = self::locale();
            $suffix = self::stripLocalePrefix($currentPath);
            $prefix = rtrim($baseUrl, '/');
            $links = [];

            foreach (self::SUPPORTED as $supported) {
                $metadata = self::METADATA[$supported];
                $links[] = [
                    'hreflang' => $metadata['hreflang'],
                    'href' => $prefix . self::localizedPath($supported, $suffix),
                    'label' => $metadata['label'],
                    'short' => $metadata['short'],
                    'active' => $supported === $active,
                ];
            }

            return $links;
        }

        public static function resolve(?string $requested = null): string
        {
            $fromRoute = self::canonical($requested);

            if ($fromRoute !== null) {
                return $fromRoute;
            }

            $cookie = $_COOKIE[self::COOKIE_NAME] ?? null;
            $fromCookie = is_string($cookie) ? self::canonical($cookie) : null;

            if ($fromCookie !== null) {
                return $fromCookie;
            }

            $fromHeader = self::fromAcceptLanguage(
                isset($_SERVER['HTTP_ACCEPT_LANGUAGE']) && is_string($_SERVER['HTTP_ACCEPT_LANGUAGE'])
                    ? $_SERVER['HTTP_ACCEPT_LANGUAGE']
                    : null
            );

            if ($fromHeader !== null) {
                return $fromHeader;
            }

            $configured = self::canonical((string) env('WEB_DEFAULT_LOCALE', self::DEFAULT_LOCALE));

            return $configured ?? self::DEFAULT_LOCALE;
        }

        public static function translator(?string $locale = null): Translator
        {
            $locale = self::canonical($locale) ?? self::locale();

            if (isset(self::$translators[$locale])) {
                return self::$translators[$locale];
            }

            $translator = new Translator($locale);
            $translator->setFallbackLocales([self::DEFAULT_LOCALE]);
            $translator->addLoader('yaml', new YamlFileLoader());

            $translationsDirectory = dirname(__DIR__) . '/translations';

            foreach (self::SUPPORTED as $supportedLocale) {
                $file = $translationsDirectory . '/messages.' . $supportedLocale . '.yaml';

                if (is_file($file)) {
                    $translator->addResource('yaml', $file, $supportedLocale, self::DOMAIN);
                }
            }

            return self::$translators[$locale] = $translator;
        }

        /** @param array<string, string|int|float> $parameters */
        public static function trans(
            string $key,
            array $parameters = [],
            ?string $locale = null
        ): string {
            $locale = self::canonical($locale) ?? self::locale();

            return self::translator($locale)->trans($key, $parameters, self::DOMAIN, $locale);
        }

        private static function stripLocalePrefix(string $path): string
        {
            $path = '/' . ltrim($path, '/');

            if ($path === '/') {
                return '';
            }

            foreach (self::SUPPORTED as $locale) {
                if ($path === '/' . $locale) {
                    return '';
                }

                if (str_starts_with($path, '/' . $locale . '/')) {
                    return substr($path, strlen($locale) + 2);
                }
            }

            return ltrim($path, '/');
        }

        private static function fromAcceptLanguage(?string $header): ?string
        {
            if ($header === null || trim($header) === '') {
                return null;
            }

            $bestLocale = null;
            $bestQuality = 0.0;

            foreach (explode(',', $header) as $entry) {
                $parts = array_map('trim', explode(';', $entry));
                $tag = $parts[0] ?? '';

                if ($tag === '') {
                    continue;
                }

                $quality = 1.0;

                foreach (array_slice($parts, 1) as $parameter) {
                    if (str_starts_with($parameter, 'q=')) {
                        $quality = (float) substr($parameter, 2);
                        break;
                    }
                }

                if ($quality <= 0.0) {
                    continue;
                }

                $locale = self::canonical($tag);

                if ($locale !== null && $quality > $bestQuality) {
                    $bestLocale = $locale;
                    $bestQuality = $quality;
                }
            }

            return $bestLocale;
        }

        private static function remember(string $locale): void
        {
            if (headers_sent()) {
                return;
            }

            $current = isset($_COOKIE[self::COOKIE_NAME]) && is_string($_COOKIE[self::COOKIE_NAME])
                ? self::canonical($_COOKIE[self::COOKIE_NAME])
                : null;

            if ($current === $locale) {
                return;
            }

            setcookie(self::COOKIE_NAME, $locale, [
                'expires' => time() + self::COOKIE_TTL,
                'path' => '/',
                'secure' => self::isHttps(),
                'httponly' => true,
                'samesite' => 'Lax',
            ]);

            $_COOKIE[self::COOKIE_NAME] = $locale;
        }

        private static function isHttps(): bool
        {
            $https = $_SERVER['HTTPS'] ?? '';

            if ($https !== '' && strtolower((string) $https) !== 'off') {
                return true;
            }

            return ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https';
        }
    }
}

namespace {
    if (!function_exists('trans')) {
        /** @param array<string, string|int|float> $parameters */
        function trans(string $key, array $parameters = [], ?string $locale = null): string
        {
            return \OrigenSalud\Web\I18n::trans($key, $parameters, $locale);
        }
    }
}
