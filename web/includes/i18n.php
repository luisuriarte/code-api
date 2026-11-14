<?php

declare(strict_types=1);

/**
 * Internacionalización del portal web (med.origen.ar).
 *
 * Usa el componente independiente symfony/translation con archivos YAML.
 * El idioma se resuelve en este orden:
 *   1. Parámetro ?lang=es|en
 *   2. Cookie persistente
 *   3. Header Accept-Language
 *   4. Idioma por defecto (WEB_DEFAULT_LOCALE)
 */

namespace OrigenSalud\Web {
    use Symfony\Component\Translation\Loader\YamlFileLoader;
    use Symfony\Component\Translation\Translator;

    final class I18n
    {
        public const SUPPORTED = ['es', 'en'];
        public const DEFAULT_LOCALE = 'es';
        public const COOKIE_NAME = 'origen_locale';

        private const COOKIE_TTL = 31536000; // 1 año
        private const DOMAIN = 'messages';

        private static ?string $locale = null;

        /** @var array<string, Translator> */
        private static array $translators = [];

        /**
         * Inicializa el locale de la petición y persiste la preferencia.
         */
        public static function boot(): string
        {
            $requested = isset($_GET['lang']) && is_string($_GET['lang'])
                ? $_GET['lang']
                : null;

            $locale = self::resolve($requested);
            self::$locale = $locale;
            self::remember($locale);

            return $locale;
        }

        public static function locale(): string
        {
            return self::$locale ?? self::DEFAULT_LOCALE;
        }

        /**
         * Resuelve el idioma aplicando la cadena de prioridades.
         */
        public static function resolve(?string $requested = null): string
        {
            $fromQuery = self::canonical($requested);

            if ($fromQuery !== null) {
                return $fromQuery;
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

        /**
         * Devuelve el Translator configurado para un locale.
         */
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

        /**
         * Traduce una clave con parámetros de sustitución.
         *
         * @param array<string, string|int|float> $parameters
         */
        public static function trans(
            string $key,
            array $parameters = [],
            ?string $locale = null
        ): string {
            $locale = self::canonical($locale) ?? self::locale();

            return self::translator($locale)->trans($key, $parameters, self::DOMAIN, $locale);
        }

        /**
         * Normaliza variantes regionales (es-AR, en-US) al locale base.
         */
        private static function canonical(?string $locale): ?string
        {
            if ($locale === null) {
                return null;
            }

            $primary = strtolower(explode('-', trim($locale))[0]);

            return in_array($primary, self::SUPPORTED, true) ? $primary : null;
        }

        /**
         * Negocia el idioma a partir de Accept-Language respetando los pesos q.
         */
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

        /**
         * Persiste el idioma en una cookie HttpOnly de un año.
         */
        private static function remember(string $locale): void
        {
            if (headers_sent()) {
                return;
            }

            $current = $_COOKIE[self::COOKIE_NAME] ?? null;

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
        /**
         * Helper global de traducción para las vistas.
         *
         * @param array<string, string|int|float> $parameters
         */
        function trans(string $key, array $parameters = [], ?string $locale = null): string
        {
            return \OrigenSalud\Web\I18n::trans($key, $parameters, $locale);
        }
    }
}
